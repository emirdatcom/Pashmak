package support

import (
	"net/http"
	"strconv"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts the user-facing endpoints (docs/10 §6.3). POST /messages is limited to 20 per 10 minutes per user.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware, auth Authenticator, clk clock.Clock) {
	send := httpx.RateLimitUser(httpx.NewRateLimiter(clk, 20, 120))
	r.HandleFunc("GET /v1/support/conversation", s.handleConversation, requireAuth)
	r.HandleFunc("GET /v1/support/messages", s.handleMessages, requireAuth)
	r.HandleFunc("POST /v1/support/messages", s.handleSend, requireAuth, send)
	r.HandleFunc("POST /v1/support/read", s.handleRead, requireAuth)
	r.HandleFunc("DELETE /v1/support/conversation", s.handleDelete, requireAuth)
	r.HandleFunc("GET /v1/support/ws", s.userSocket(auth))
}

func principal(w http.ResponseWriter, r *http.Request) (httpx.Principal, bool) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
	}
	return p, ok
}

func (s *Service) handleConversation(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	info, err := s.UserConversation(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	if !s.cfg.Support(r.Context()).Enabled {
		httpx.WriteErr(w, r, disabled())
		return
	}
	httpx.WriteJSON(w, http.StatusOK, info)
}

func cursor(r *http.Request, name string) (*uuid.UUID, error) {
	v := r.URL.Query().Get(name)
	if v == "" {
		return nil, nil
	}
	id, err := uuid.Parse(v)
	if err != nil {
		return nil, invalid(name + " must be a message id")
	}
	return &id, nil
}

func (s *Service) handleMessages(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	after, err1 := cursor(r, "after")
	before, err2 := cursor(r, "before")
	if err1 != nil || err2 != nil || (after != nil && before != nil) {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "use either after or before, with a message id")
		return
	}
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			httpx.WriteError(w, r, httpx.CodeInvalidInput, "limit must be 1..100")
			return
		}
		limit = n
	}
	msgs, more, err := s.UserMessages(r.Context(), p.UserID, after, before, limit)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"messages": msgs, "has_more": more})
}

func (s *Service) handleSend(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	var in struct {
		ClientMsgID       uuid.UUID `json:"client_msg_id"`
		Body              string    `json:"body"`
		IncludeDeviceMeta bool      `json:"include_device_meta"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	var meta *DeviceMeta
	if in.IncludeDeviceMeta {
		// Technical facts only, taken from request headers the app already sends; consent is the flag itself.
		meta = &DeviceMeta{AppVersion: r.Header.Get("X-App-Version"), Market: r.Header.Get("X-Market"),
			OSVersion: r.Header.Get("X-OS-Version"), Model: r.Header.Get("X-Device-Model"), IsPremium: r.Header.Get("X-Is-Premium") == "true"}
	}
	m, err := s.UserSend(r.Context(), p.UserID, in.ClientMsgID, in.Body, meta)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, m)
}

func (s *Service) handleRead(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	var in struct {
		UpTo uuid.UUID `json:"up_to_message_id"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil || in.UpTo == uuid.Nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "up_to_message_id is required")
		return
	}
	if err := s.UserRead(r.Context(), p.UserID, in.UpTo); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleDelete(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	if err := s.UserDelete(r.Context(), p.UserID); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
