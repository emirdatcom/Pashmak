package social

import (
	"net/http"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts /v1/social. Adding friends is limited to 30 attempts per hour per user (friend codes cannot be
// guessed by brute force); vibes are limited by the once-a-day rule.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware, clk clock.Clock) {
	addLimit := httpx.RateLimitUser(httpx.NewRateLimiter(clk, 30, 30))
	r.HandleFunc("GET /v1/social/me", s.handleMe, requireAuth)
	r.HandleFunc("PUT /v1/social/me", s.handleUpdateMe, requireAuth)
	r.HandleFunc("GET /v1/social/friends", s.handleFriends, requireAuth)
	r.HandleFunc("POST /v1/social/friends", s.handleAdd, requireAuth, addLimit)
	r.HandleFunc("DELETE /v1/social/friends/{code}", s.handleRemove, requireAuth)
	r.HandleFunc("GET /v1/social/vibes", s.handleVibes, requireAuth)
	r.HandleFunc("POST /v1/social/vibes", s.handleSend, requireAuth)
	r.HandleFunc("POST /v1/social/vibes/read", s.handleRead, requireAuth)
}

func principal(w http.ResponseWriter, r *http.Request) (httpx.Principal, bool) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
	}
	return p, ok
}

func (s *Service) handleMe(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	me, err := s.Me(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, me)
}

func (s *Service) handleUpdateMe(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	var in ProfileInput
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	me, err := s.UpdateMe(r.Context(), p.UserID, in)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, me)
}

func (s *Service) handleFriends(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	list, err := s.Friends(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"friends": list})
}

func (s *Service) handleAdd(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	var in struct {
		Code string `json:"code"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	f, err := s.AddFriend(r.Context(), p.UserID, in.Code)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, f)
}

func (s *Service) handleRemove(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	if err := s.RemoveFriend(r.Context(), p.UserID, r.PathValue("code")); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleVibes(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	list, err := s.Vibes(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"vibes": list})
}

func (s *Service) handleSend(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	var in struct {
		To   string `json:"to"`
		Kind string `json:"kind"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	if err := s.SendVibe(r.Context(), p.UserID, in.To, in.Kind); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleRead(w http.ResponseWriter, r *http.Request) {
	p, ok := principal(w, r)
	if !ok {
		return
	}
	if err := s.MarkRead(r.Context(), p.UserID); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
