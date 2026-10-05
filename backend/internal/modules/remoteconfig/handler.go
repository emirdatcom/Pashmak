package remoteconfig

import (
	"net/http"
	"strconv"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts GET /v1/config. optionalAuth sets the principal when a valid Bearer token is sent.
func Register(r *httpx.Router, s *Service, optionalAuth httpx.Middleware) {
	r.HandleFunc("GET /v1/config", s.handleConfig, optionalAuth, httpx.Gzip())
}

func (s *Service) handleConfig(w http.ResponseWriter, r *http.Request) {
	if kv := r.URL.Query().Get("known_version"); kv != "" {
		if _, err := strconv.Atoi(kv); err != nil {
			httpx.WriteError(w, r, httpx.CodeInvalidInput, "known_version must be an integer")
			return
		}
	}
	ci := httpx.ClientFrom(r.Context())
	sub := Subject{Market: ci.Market, AppVersion: ci.AppVersion, InstallAgeDays: -1}
	if p, ok := httpx.PrincipalFrom(r.Context()); ok {
		sub.ID = p.UserID.String()
		sub.InstallAgeDays = s.InstallAgeDays(r.Context(), p.UserID)
	} else if id, err := uuid.Parse(ci.InstallID); err == nil {
		sub.ID = id.String()
	}
	if sub.Market != "bazaar" && sub.Market != "myket" {
		sub.Market = ""
	}
	resp, err := s.Resolve(r.Context(), sub)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	h := w.Header()
	h.Set("ETag", resp.ETag)
	h.Set("Cache-Control", "private, no-cache")
	h.Add("Vary", "Authorization")
	h.Add("Vary", "X-Install-Id")
	h.Add("Vary", "X-App-Version")
	h.Add("Vary", "X-Market")
	if httpx.ETagMatches(r.Header.Get("If-None-Match"), resp.ETag) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	if resp.Experiments == nil {
		resp.Experiments = map[string]string{}
	}
	httpx.WriteJSON(w, http.StatusOK, resp)
}
