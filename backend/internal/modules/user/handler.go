package user

import (
	"net/http"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts /v1/me routes behind requireAuth.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware) {
	r.HandleFunc("GET /v1/me", s.handleGet, requireAuth)
	r.HandleFunc("DELETE /v1/me", s.handleDelete, requireAuth)
}

type meResponse struct {
	UserID      string `json:"user_id"`
	CreatedAt   string `json:"created_at"`
	PhoneLinked bool   `json:"phone_linked"`
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	a, err := s.Get(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, meResponse{
		UserID: a.ID.String(), CreatedAt: a.CreatedAt.UTC().Format(time.RFC3339), PhoneLinked: a.PhoneLinked,
	})
}

func (s *Service) handleDelete(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	if err := s.Delete(r.Context(), p.UserID); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
