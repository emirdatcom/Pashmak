// Package support implements the in-app support chat (decision D-2): one open conversation per user,
// AES-GCM encrypted message bodies, real-time delivery through WebSocket + Postgres LISTEN/NOTIFY and an HTTP
// cursor fallback. Message text never appears in logs, metrics or analytics.
package support

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Message is a decrypted chat message.
type Message struct {
	ID                  uuid.UUID  `json:"id"`
	ConversationID      uuid.UUID  `json:"conversation_id,omitempty"`
	Sender              string     `json:"sender"`
	Body                string     `json:"body"`
	CreatedAt           time.Time  `json:"created_at"`
	ReadAt              *time.Time `json:"read_at"`
	OperatorDisplayName string     `json:"operator_display_name,omitempty"`
	ClientMsgID         *uuid.UUID `json:"client_msg_id,omitempty"`
}

// DeviceMeta is the technical info a user may attach (explicit consent only).
type DeviceMeta struct {
	AppVersion string `json:"app_version"`
	Market     string `json:"market"`
	OSVersion  string `json:"os_version"`
	Model      string `json:"model"`
	IsPremium  bool   `json:"is_premium"`
}

// ConversationInfo is what the app shows above the chat.
type ConversationInfo struct {
	ConversationID      *uuid.UUID `json:"conversation_id,omitempty"`
	Status              string     `json:"status"`
	UnreadCount         int        `json:"unread_count"`
	OperatorDisplayName string     `json:"operator_display_name,omitempty"`
	Online              bool       `json:"online"`
	NextOnlineAt        *time.Time `json:"next_online_at,omitempty"`
}

// Observer receives operational metrics (all optional).
type Observer struct {
	FirstResponse func(seconds float64)
}

// Service is the chat core.
type Service struct {
	pool *db.Pool
	clk  clock.Clock
	box  *crypt.Box
	cfg  ConfigReader
	hub  *Hub
	obs  Observer
}

// NewService builds a Service.
func NewService(pool *db.Pool, clk clock.Clock, box *crypt.Box, cfg ConfigReader, hub *Hub, obs Observer) *Service {
	return &Service{pool: pool, clk: clk, box: box, cfg: cfg, hub: hub, obs: obs}
}

// Hub exposes the fan-out hub (sockets subscribe to it).
func (s *Service) Hub() *Hub { return s.hub }

// Config returns the current support config.
func (s *Service) Config(ctx context.Context) Config { return s.cfg.Support(ctx) }

func invalid(msg string) error { return httpx.NewError(httpx.CodeInvalidInput, msg) }

func disabled() error {
	return httpx.NewError(httpx.CodeSupportDisabled, "support is currently unavailable")
}

func (s *Service) toMessage(id, conv uuid.UUID, sender string, enc []byte, created time.Time, read *time.Time, op *string, client uuid.NullUUID) (Message, error) {
	body, err := open(s.box, enc)
	if err != nil {
		return Message{}, err
	}
	m := Message{ID: id, ConversationID: conv, Sender: sender, Body: body, CreatedAt: created, ReadAt: read}
	if op != nil {
		m.OperatorDisplayName = *op
	}
	if client.Valid {
		c := client.UUID
		m.ClientMsgID = &c
	}
	return m, nil
}

// ---- user side -------------------------------------------------------------------------------

// UserConversation returns the conversation summary (no conversation yet ⇒ status "none").
func (s *Service) UserConversation(ctx context.Context, userID uuid.UUID) (ConversationInfo, error) {
	cfg := s.cfg.Support(ctx)
	online, next := cfg.Status(s.clk.Now())
	info := ConversationInfo{Status: "none", Online: online, NextOnlineAt: next}
	q := dbgen.New(s.pool)
	c, err := q.GetOpenConversationByUser(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		// a closed conversation still has history and unread replies
		if lc, lerr := q.GetLatestConversationByUser(ctx, userID); lerr == nil {
			info.ConversationID, info.Status, info.UnreadCount = &lc.ID, lc.Status, int(lc.UserUnreadCount)
		}
		return info, nil
	}
	if err != nil {
		return info, fmt.Errorf("get conversation: %w", err)
	}
	info.ConversationID, info.Status, info.UnreadCount = &c.ID, c.Status, int(c.UserUnreadCount)
	if c.AssignedOperatorID.Valid {
		if op, err := q.GetOperator(ctx, c.AssignedOperatorID.UUID); err == nil {
			info.OperatorDisplayName = op.DisplayName
		}
	}
	return info, nil
}

func (s *Service) userConv(ctx context.Context, q *dbgen.Queries, userID uuid.UUID) (*dbgen.SupportConversation, error) {
	c, err := q.GetOpenConversationByUser(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		c, err = q.GetLatestConversationByUser(ctx, userID)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
	}
	if err != nil {
		return nil, fmt.Errorf("get conversation: %w", err)
	}
	return &c, nil
}

// MessagesPage returns up to [limit] messages in chronological order. after/before are message-id cursors
// (at most one). With neither, the latest page is returned.
func (s *Service) messagesPage(ctx context.Context, convID uuid.UUID, after, before *uuid.UUID, limit int) ([]Message, bool, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	q := dbgen.New(s.pool)
	var out []Message
	conv := func(id uuid.UUID, sender string, enc []byte, created time.Time, read *time.Time, op *string, client uuid.NullUUID) error {
		m, err := s.toMessage(id, convID, sender, enc, created, read, op, client)
		if err != nil {
			return err
		}
		out = append(out, m)
		return nil
	}
	var more bool
	switch {
	case after != nil:
		rows, err := q.ListMessagesAfter(ctx, dbgen.ListMessagesAfterParams{ConversationID: convID, ID: *after, Limit: int32(limit + 1)}) // #nosec G115
		if err != nil {
			return nil, false, fmt.Errorf("list messages: %w", err)
		}
		if more = len(rows) > limit; more {
			rows = rows[:limit]
		}
		for _, r := range rows {
			if err := conv(r.ID, r.Sender, r.BodyEnc, r.CreatedAt, r.ReadAt, r.OperatorDisplayName, r.ClientMsgID); err != nil {
				return nil, false, err
			}
		}
	case before != nil:
		rows, err := q.ListMessagesBefore(ctx, dbgen.ListMessagesBeforeParams{ConversationID: convID, ID: *before, Limit: int32(limit + 1)}) // #nosec G115
		if err != nil {
			return nil, false, fmt.Errorf("list messages: %w", err)
		}
		if more = len(rows) > limit; more {
			rows = rows[:limit]
		}
		for i := len(rows) - 1; i >= 0; i-- {
			r := rows[i]
			if err := conv(r.ID, r.Sender, r.BodyEnc, r.CreatedAt, r.ReadAt, r.OperatorDisplayName, r.ClientMsgID); err != nil {
				return nil, false, err
			}
		}
	default:
		rows, err := q.ListMessagesLatest(ctx, dbgen.ListMessagesLatestParams{ConversationID: convID, Limit: int32(limit + 1)}) // #nosec G115
		if err != nil {
			return nil, false, fmt.Errorf("list messages: %w", err)
		}
		if more = len(rows) > limit; more {
			rows = rows[:limit]
		}
		for i := len(rows) - 1; i >= 0; i-- {
			r := rows[i]
			if err := conv(r.ID, r.Sender, r.BodyEnc, r.CreatedAt, r.ReadAt, r.OperatorDisplayName, r.ClientMsgID); err != nil {
				return nil, false, err
			}
		}
	}
	return out, more, nil
}

// UserMessages lists the user's messages (history stays readable even while support is switched off).
func (s *Service) UserMessages(ctx context.Context, userID uuid.UUID, after, before *uuid.UUID, limit int) ([]Message, bool, error) {
	c, err := s.userConv(ctx, dbgen.New(s.pool), userID)
	if err != nil || c == nil {
		return []Message{}, false, err
	}
	msgs, more, err := s.messagesPage(ctx, c.ID, after, before, limit)
	if msgs == nil {
		msgs = []Message{}
	}
	return msgs, more, err
}

// UserSend stores a user message (idempotent on clientMsgID) and notifies the operators.
func (s *Service) UserSend(ctx context.Context, userID, clientMsgID uuid.UUID, body string, meta *DeviceMeta) (Message, error) {
	cfg := s.cfg.Support(ctx)
	if !cfg.Enabled {
		return Message{}, disabled()
	}
	body = strings.TrimSpace(body)
	if body == "" {
		return Message{}, invalid("message must not be empty")
	}
	if n := utf8.RuneCountInString(body); n > cfg.MaxMessageChars {
		return Message{}, invalid(fmt.Sprintf("message is longer than %d characters", cfg.MaxMessageChars))
	}
	if clientMsgID == uuid.Nil {
		return Message{}, invalid("client_msg_id is required")
	}
	enc, err := seal(s.box, body)
	if err != nil {
		return Message{}, err
	}
	var metaJSON []byte
	if meta != nil {
		metaJSON, _ = json.Marshal(meta)
	}
	now := s.clk.Now()
	var out Message
	err = s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		conv, err := q.GetOpenConversationByUser(ctx, userID)
		if errors.Is(err, pgx.ErrNoRows) {
			// a closed conversation is replaced by a fresh one (a new message re-opens the topic)
			conv, err = q.CreateConversation(ctx, dbgen.CreateConversationParams{ID: uuid.Must(uuid.NewV7()), UserID: userID, LastMessageAt: now})
		}
		if err != nil {
			return fmt.Errorf("conversation: %w", err)
		}
		if existing, err := q.GetMessageByClientID(ctx, dbgen.GetMessageByClientIDParams{ConversationID: conv.ID, ClientMsgID: uuid.NullUUID{UUID: clientMsgID, Valid: true}}); err == nil {
			out, err = s.toMessage(existing.ID, conv.ID, existing.Sender, existing.BodyEnc, existing.CreatedAt, existing.ReadAt, nil, existing.ClientMsgID)
			return err // duplicate delivery: same stored message, nothing is notified twice
		}
		m, err := q.InsertMessage(ctx, dbgen.InsertMessageParams{ID: uuid.Must(uuid.NewV7()), ConversationID: conv.ID, Sender: "user",
			ClientMsgID: uuid.NullUUID{UUID: clientMsgID, Valid: true}, BodyEnc: enc, CreatedAt: now})
		if err != nil {
			return fmt.Errorf("insert message: %w", err)
		}
		if err := q.ConversationUserMessage(ctx, dbgen.ConversationUserMessageParams{ID: conv.ID, LastMessageAt: now, DeviceMeta: metaJSON}); err != nil {
			return fmt.Errorf("update conversation: %w", err)
		}
		out, err = s.toMessage(m.ID, conv.ID, "user", m.BodyEnc, m.CreatedAt, nil, nil, m.ClientMsgID)
		if err != nil {
			return err
		}
		return notify(ctx, tx, Event{Kind: "message.new", ConversationID: conv.ID, MessageID: m.ID})
	})
	return out, err
}

// UserRead marks operator/system messages up to upTo as read.
func (s *Service) UserRead(ctx context.Context, userID, upTo uuid.UUID) error {
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		c, err := s.userConv(ctx, q, userID)
		if err != nil || c == nil {
			return err
		}
		if err := q.MarkOperatorMessagesRead(ctx, dbgen.MarkOperatorMessagesReadParams{ConversationID: c.ID, ID: upTo, ReadAt: ptr(s.clk.Now())}); err != nil {
			return err
		}
		if err := q.SetUserUnread(ctx, c.ID); err != nil {
			return err
		}
		return notify(ctx, tx, Event{Kind: "message.read", ConversationID: c.ID, MessageID: upTo})
	})
}

// UserDelete removes the user's conversations (messages cascade). Allowed even when support is disabled.
func (s *Service) UserDelete(ctx context.Context, userID uuid.UUID) error {
	if err := dbgen.New(s.pool).DeleteConversationsByUser(ctx, userID); err != nil {
		return fmt.Errorf("delete conversation: %w", err)
	}
	return nil
}

// OnUserDeleted implements user.DeletionHook (DELETE /v1/me removes the whole conversation).
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	return s.UserDelete(ctx, userID)
}

func ptr[T any](v T) *T { return &v }

// ---- operator side ---------------------------------------------------------------------------

// QueueItem is one row of the operator queue.
type QueueItem struct {
	ID                 uuid.UUID  `json:"id"`
	Status             string     `json:"status"`
	LastMessageAt      time.Time  `json:"last_message_at"`
	AwaitingSince      *time.Time `json:"awaiting_since"`
	OperatorUnread     int        `json:"operator_unread"`
	AssignedTo         string     `json:"assigned_to,omitempty"`
	AssignedOperatorID *uuid.UUID `json:"assigned_operator_id,omitempty"`
	UserID             uuid.UUID  `json:"user_id"`
	HasDeviceMeta      bool       `json:"has_device_meta"`
}

// Queue lists conversations (oldest unanswered first). status "" = all.
func (s *Service) Queue(ctx context.Context, status string, limit int) ([]QueueItem, error) {
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	rows, err := dbgen.New(s.pool).ListQueue(ctx, dbgen.ListQueueParams{Column1: status, Limit: int32(limit)}) // #nosec G115
	if err != nil {
		return nil, fmt.Errorf("list queue: %w", err)
	}
	out := make([]QueueItem, 0, len(rows))
	for _, r := range rows {
		it := QueueItem{ID: r.ID, Status: r.Status, LastMessageAt: r.LastMessageAt, AwaitingSince: r.AwaitingSince,
			OperatorUnread: int(r.OperatorUnread), UserID: r.UserID, HasDeviceMeta: len(r.DeviceMeta) > 0}
		if r.AssignedOperatorID.Valid {
			id := r.AssignedOperatorID.UUID
			it.AssignedOperatorID = &id
		}
		if r.OperatorDisplayName != nil {
			it.AssignedTo = *r.OperatorDisplayName
		}
		out = append(out, it)
	}
	return out, nil
}

// Conversation returns one conversation (operator view, includes device_meta when consented).
func (s *Service) Conversation(ctx context.Context, id uuid.UUID) (dbgen.SupportConversation, error) {
	c, err := dbgen.New(s.pool).GetConversation(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, httpx.NewError(httpx.CodeNotFound, "conversation not found")
	}
	return c, err
}

// OperatorMessages pages a conversation for the panel and marks the conversation as seen.
func (s *Service) OperatorMessages(ctx context.Context, convID uuid.UUID, after, before *uuid.UUID, limit int) ([]Message, bool, error) {
	if _, err := s.Conversation(ctx, convID); err != nil {
		return nil, false, err
	}
	msgs, more, err := s.messagesPage(ctx, convID, after, before, limit)
	if msgs == nil {
		msgs = []Message{}
	}
	return msgs, more, err
}

// OperatorSend stores an operator reply, flips the conversation to waiting_user and records the first-response time.
func (s *Service) OperatorSend(ctx context.Context, operatorID, convID uuid.UUID, body string) (Message, error) {
	body = strings.TrimSpace(body)
	cfg := s.cfg.Support(ctx)
	if body == "" {
		return Message{}, invalid("message must not be empty")
	}
	if utf8.RuneCountInString(body) > cfg.MaxMessageChars {
		return Message{}, invalid("message is too long")
	}
	enc, err := seal(s.box, body)
	if err != nil {
		return Message{}, err
	}
	now := s.clk.Now()
	var out Message
	var awaited *time.Time
	err = s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		c, err := q.GetConversationForUpdate(ctx, convID)
		if errors.Is(err, pgx.ErrNoRows) {
			return httpx.NewError(httpx.CodeNotFound, "conversation not found")
		}
		if err != nil {
			return err
		}
		awaited = c.AwaitingSince
		m, err := q.InsertMessage(ctx, dbgen.InsertMessageParams{ID: uuid.Must(uuid.NewV7()), ConversationID: convID, Sender: "operator",
			OperatorID: uuid.NullUUID{UUID: operatorID, Valid: true}, BodyEnc: enc, CreatedAt: now})
		if err != nil {
			return fmt.Errorf("insert message: %w", err)
		}
		if err := q.ConversationOperatorMessage(ctx, dbgen.ConversationOperatorMessageParams{ID: convID, LastMessageAt: now, AssignedOperatorID: uuid.NullUUID{UUID: operatorID, Valid: true}}); err != nil {
			return err
		}
		var name *string
		if op, err := q.GetOperator(ctx, operatorID); err == nil {
			name = &op.DisplayName
		}
		out, err = s.toMessage(m.ID, convID, "operator", m.BodyEnc, m.CreatedAt, nil, name, m.ClientMsgID)
		if err != nil {
			return err
		}
		return notify(ctx, tx, Event{Kind: "message.new", ConversationID: convID, MessageID: m.ID})
	})
	if err == nil && awaited != nil && s.obs.FirstResponse != nil {
		s.obs.FirstResponse(now.Sub(*awaited).Seconds())
	}
	return out, err
}

// OperatorRead marks the user's messages as read by an operator and clears the unread counter.
func (s *Service) OperatorRead(ctx context.Context, convID, upTo uuid.UUID) error {
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		if err := q.MarkUserMessagesRead(ctx, dbgen.MarkUserMessagesReadParams{ConversationID: convID, ID: upTo, ReadAt: ptr(s.clk.Now())}); err != nil {
			return err
		}
		if err := q.ClearOperatorUnread(ctx, convID); err != nil {
			return err
		}
		return notify(ctx, tx, Event{Kind: "message.read", ConversationID: convID, MessageID: upTo})
	})
}

// Assign sets the assigned operator.
func (s *Service) Assign(ctx context.Context, convID, operatorID uuid.UUID) error {
	if _, err := s.Conversation(ctx, convID); err != nil {
		return err
	}
	return dbgen.New(s.pool).AssignConversation(ctx, dbgen.AssignConversationParams{ID: convID, AssignedOperatorID: uuid.NullUUID{UUID: operatorID, Valid: true}})
}

// Close closes the conversation; the next user message opens a new one.
func (s *Service) Close(ctx context.Context, convID uuid.UUID) error {
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		if _, err := s.Conversation(ctx, convID); err != nil {
			return err
		}
		if err := dbgen.New(tx).CloseConversation(ctx, dbgen.CloseConversationParams{ID: convID, ClosedAt: ptr(s.clk.Now())}); err != nil {
			return err
		}
		return notify(ctx, tx, Event{Kind: "conversation.status", ConversationID: convID})
	})
}

// OldestUnanswered returns the age of the longest-waiting user message (0 when none or outside working hours).
// It feeds the support_oldest_unanswered_seconds gauge used by the SupportUnanswered alert.
func (s *Service) OldestUnanswered(ctx context.Context) time.Duration {
	now := s.clk.Now()
	if online, _ := s.cfg.Support(ctx).Status(now); !online {
		return 0
	}
	t, err := dbgen.New(s.pool).OldestAwaitingSince(ctx)
	if err != nil || t == nil {
		return 0
	}
	return now.Sub(*t)
}

// OpenConversations counts non-closed conversations (gauge support_open_conversations).
func (s *Service) OpenConversations(ctx context.Context) int {
	n, err := dbgen.New(s.pool).CountOpenConversations(ctx)
	if err != nil {
		return 0
	}
	return int(n)
}
