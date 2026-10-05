package support

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Authenticator validates an access token (auth.Service implements it).
type Authenticator interface {
	Authenticate(ctx context.Context, token string) (httpx.Principal, error)
}

// Close codes used by the sockets.
const (
	CloseUnauthorized = websocket.StatusCode(4401)
	CloseDisabled     = websocket.StatusCode(4503)
	pingEvery         = 25 * time.Second
	authTimeout       = 5 * time.Second
)

type frame struct {
	Type    string          `json:"type"`
	Token   string          `json:"token,omitempty"`
	Message *Message        `json:"message,omitempty"`
	UpTo    *uuid.UUID      `json:"up_to,omitempty"`
	Status  string          `json:"status,omitempty"`
	Conv    *uuid.UUID      `json:"conversation_id,omitempty"`
	Raw     json.RawMessage `json:"-"`
}

func writeFrame(ctx context.Context, c *websocket.Conn, f frame) error {
	b, _ := json.Marshal(f)
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	return c.Write(ctx, websocket.MessageText, b)
}

// frameFor turns a hub event into the frame the client receives (full message for message.new).
func (s *Service) frameFor(ctx context.Context, e Event) (frame, bool) {
	switch e.Kind {
	case "message.new":
		m, err := dbgen.New(s.pool).GetMessage(ctx, e.MessageID)
		if err != nil {
			return frame{}, false
		}
		var name *string
		if m.OperatorID.Valid {
			if op, err := dbgen.New(s.pool).GetOperator(ctx, m.OperatorID.UUID); err == nil {
				name = &op.DisplayName
			}
		}
		msg, err := s.toMessage(m.ID, m.ConversationID, m.Sender, m.BodyEnc, m.CreatedAt, m.ReadAt, name, m.ClientMsgID)
		if err != nil {
			return frame{}, false
		}
		return frame{Type: "message.new", Message: &msg, Conv: &e.ConversationID}, true
	case "message.read":
		return frame{Type: "message.read", UpTo: &e.MessageID, Conv: &e.ConversationID}, true
	case "conversation.status":
		c, err := dbgen.New(s.pool).GetConversation(ctx, e.ConversationID)
		if err != nil {
			return frame{}, false
		}
		return frame{Type: "conversation.status", Status: c.Status, Conv: &e.ConversationID}, true
	}
	return frame{}, false
}

// pump runs the read/ping/event loops until the socket ends. [accept] filters events per socket.
func (s *Service) pump(ctx context.Context, c *websocket.Conn, events <-chan Event, accept func(Event) bool) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	go func() { // reader: JSON ping/pong and detects client close
		defer cancel()
		for {
			_, data, err := c.Read(ctx)
			if err != nil {
				return
			}
			var f frame
			if json.Unmarshal(data, &f) == nil && f.Type == "ping" {
				if writeFrame(ctx, c, frame{Type: "pong"}) != nil {
					return
				}
			}
		}
	}()
	tick := time.NewTicker(pingEvery)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
			pctx, pc := context.WithTimeout(ctx, 10*time.Second)
			err := c.Ping(pctx)
			pc()
			if err != nil {
				return
			}
		case e := <-events:
			if accept != nil && !accept(e) {
				continue
			}
			if f, ok := s.frameFor(ctx, e); ok {
				if writeFrame(ctx, c, f) != nil {
					return
				}
			}
		}
	}
}

// Pump streams hub events to an already accepted socket (used by the operator panel).
func (s *Service) Pump(ctx context.Context, c *websocket.Conn, events <-chan Event) {
	c.SetReadLimit(4096)
	s.pump(ctx, c, events, nil)
}

// userSocket is GET /v1/support/ws. The token travels in the first frame, never in the URL.
func (s *Service) userSocket(auth Authenticator) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true}) // native app: no browser Origin to check
		if err != nil {
			return // Accept already replied
		}
		defer func() { _ = c.CloseNow() }()
		c.SetReadLimit(4096)
		actx, cancel := context.WithTimeout(r.Context(), authTimeout)
		_, data, err := c.Read(actx)
		cancel()
		var f frame
		if err != nil || json.Unmarshal(data, &f) != nil || f.Type != "auth" || f.Token == "" {
			_ = c.Close(CloseUnauthorized, "unauthorized")
			return
		}
		p, err := auth.Authenticate(r.Context(), f.Token)
		if err != nil {
			_ = c.Close(CloseUnauthorized, "unauthorized")
			return
		}
		if !s.cfg.Support(r.Context()).Enabled {
			_ = c.Close(CloseDisabled, "support disabled")
			return
		}
		events, unsub := s.hub.SubscribeUser(p.UserID)
		defer unsub()
		if err := writeFrame(r.Context(), c, frame{Type: "ready"}); err != nil {
			return
		}
		s.pump(r.Context(), c, events, nil)
		if !errors.Is(r.Context().Err(), context.Canceled) {
			slog.DebugContext(r.Context(), "support socket closed")
		}
		_ = c.Close(websocket.StatusNormalClosure, "")
	}
}
