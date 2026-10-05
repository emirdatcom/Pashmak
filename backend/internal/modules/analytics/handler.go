package analytics

import (
	"net/http"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts POST /v1/events.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware) {
	r.HandleFunc("POST /v1/events", s.handleEvents, requireAuth)
}

func (s *Service) handleEvents(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in struct {
		Events []Event `json:"events"`
		SentAt string  `json:"sent_at"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	ci := httpx.ClientFrom(r.Context())
	var install uuid.NullUUID
	if id, err := uuid.Parse(ci.InstallID); err == nil {
		install = uuid.NullUUID{UUID: id, Valid: true}
	}
	market := ci.Market
	if market != "bazaar" && market != "myket" {
		market = ""
	}
	res, err := s.Ingest(r.Context(), p.UserID, install, ci.AppVersion, market, in.Events)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, res)
}
