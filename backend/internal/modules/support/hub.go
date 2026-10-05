package support

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

// Channel is the Postgres LISTEN/NOTIFY channel. Payloads carry ids only, never message text.
const Channel = "support_events"

// Event is what is NOTIFY-ed and fanned out.
type Event struct {
	Kind           string    `json:"kind"` // message.new | message.read | conversation.status
	ConversationID uuid.UUID `json:"conversation_id"`
	MessageID      uuid.UUID `json:"message_id,omitempty"`
}

type sub struct {
	ch     chan Event
	userID uuid.UUID // zero for operator subscribers
}

// Hub fans NOTIFY events out to connected sockets (users by user id, operators all). It works across several
// api instances because the events travel through Postgres.
type Hub struct {
	pool *db.Pool

	mu    sync.Mutex
	subs  map[*sub]struct{}
	owner map[uuid.UUID]uuid.UUID // conversation id → user id (small cache)
	conns int
	onChg func(n int) // gauge hook
}

// NewHub builds a Hub.
func NewHub(pool *db.Pool) *Hub {
	return &Hub{pool: pool, subs: map[*sub]struct{}{}, owner: map[uuid.UUID]uuid.UUID{}}
}

// OnConnections registers a gauge callback (support_ws_connections).
func (h *Hub) OnConnections(f func(int)) { h.onChg = f }

// SubscribeUser returns a channel with the events of one user's conversation plus a cancel func.
func (h *Hub) SubscribeUser(u uuid.UUID) (<-chan Event, func()) { return h.subscribe(u) }

// SubscribeOperator returns all conversation events.
func (h *Hub) SubscribeOperator() (<-chan Event, func()) { return h.subscribe(uuid.Nil) }

func (h *Hub) subscribe(u uuid.UUID) (<-chan Event, func()) {
	s := &sub{ch: make(chan Event, 64), userID: u}
	h.mu.Lock()
	h.subs[s] = struct{}{}
	n := len(h.subs)
	h.mu.Unlock()
	if h.onChg != nil {
		h.onChg(n)
	}
	return s.ch, func() {
		h.mu.Lock()
		delete(h.subs, s)
		n := len(h.subs)
		h.mu.Unlock()
		if h.onChg != nil {
			h.onChg(n)
		}
	}
}

func (h *Hub) userOf(ctx context.Context, conv uuid.UUID) (uuid.UUID, bool) {
	h.mu.Lock()
	u, ok := h.owner[conv]
	h.mu.Unlock()
	if ok {
		return u, true
	}
	c, err := dbgen.New(h.pool).GetConversation(ctx, conv)
	if err != nil {
		return uuid.Nil, false
	}
	h.mu.Lock()
	if len(h.owner) > 10000 {
		h.owner = map[uuid.UUID]uuid.UUID{}
	}
	h.owner[conv] = c.UserID
	h.mu.Unlock()
	return c.UserID, true
}

func (h *Hub) dispatch(ctx context.Context, e Event) {
	user, ok := h.userOf(ctx, e.ConversationID)
	h.mu.Lock()
	defer h.mu.Unlock()
	for s := range h.subs {
		if s.userID != uuid.Nil && !(ok && s.userID == user) {
			continue
		}
		select {
		case s.ch <- e:
		default: // slow consumer: drop; the client resyncs through the HTTP fallback
		}
	}
}

// Run listens until ctx ends, reconnecting with backoff.
func (h *Hub) Run(ctx context.Context) {
	backoff := time.Second
	for ctx.Err() == nil {
		err := h.listen(ctx)
		if ctx.Err() != nil {
			return
		}
		slog.Warn("support listener stopped; retrying", "err", err)
		select {
		case <-time.After(backoff):
		case <-ctx.Done():
			return
		}
		if backoff < 30*time.Second {
			backoff *= 2
		}
	}
}

func (h *Hub) listen(ctx context.Context) error {
	conn, err := h.pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	if _, err := conn.Exec(ctx, "LISTEN "+Channel); err != nil {
		return err
	}
	for {
		n, err := conn.Conn().WaitForNotification(ctx)
		if err != nil {
			return err
		}
		var e Event
		if json.Unmarshal([]byte(n.Payload), &e) == nil {
			h.dispatch(ctx, e)
		}
	}
}

// notify publishes e inside tx so it is delivered only if the transaction commits.
func notify(ctx context.Context, tx pgx.Tx, e Event) error {
	b, _ := json.Marshal(e)
	_, err := tx.Exec(ctx, "SELECT pg_notify($1, $2)", Channel, string(b))
	return err
}
