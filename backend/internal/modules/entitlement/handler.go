package entitlement

import (
	"net/http"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts GET /v1/entitlements and POST /v1/trial/start.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware) {
	r.HandleFunc("GET /v1/entitlements", s.handleState, requireAuth)
	r.HandleFunc("POST /v1/trial/start", s.handleTrial, requireAuth)
}

func (s *Service) handleState(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	st, err := s.State(r.Context(), p.UserID, p.DeviceID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, st)
}

func (s *Service) handleTrial(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in struct {
		ProvisionalStartedAt *string `json:"provisional_started_at"`
	}
	if r.ContentLength != 0 {
		if err := httpx.DecodeJSON(r, &in); err != nil {
			httpx.WriteErr(w, r, err)
			return
		}
	}
	var prov *time.Time
	if in.ProvisionalStartedAt != nil {
		t, err := time.Parse(time.RFC3339, *in.ProvisionalStartedAt)
		if err != nil {
			httpx.WriteError(w, r, httpx.CodeInvalidInput, "provisional_started_at must be RFC3339")
			return
		}
		prov = &t
	}
	st, err := s.StartTrial(r.Context(), p.UserID, p.DeviceID, prov)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, st)
}
