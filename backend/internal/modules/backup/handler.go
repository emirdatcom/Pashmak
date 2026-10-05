package backup

import (
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Register mounts /v1/backup. PUT is limited to 20 per day per user.
func Register(r *httpx.Router, s *Service, requireAuth httpx.Middleware, clk clock.Clock) {
	putLimit := httpx.RateLimitUser(httpx.NewRateLimiter(clk, 20, 20.0/24))
	r.HandleFunc("PUT /v1/backup", s.handlePut, requireAuth, putLimit)
	r.HandleFunc("GET /v1/backup", s.handleGet, requireAuth)
	r.HandleFunc("DELETE /v1/backup", s.handleDelete, requireAuth)
}

func (s *Service) handlePut(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	data, err := io.ReadAll(io.LimitReader(r.Body, MaxBlobBytes+1))
	if err != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "could not read the body")
		return
	}
	schema, _ := strconv.Atoi(r.Header.Get("X-Backup-Schema"))
	at, err := s.Put(r.Context(), p.UserID, schema, r.Header.Get("X-Backup-Sha256"), r.Header.Get("X-Kdf-Params"), data)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]string{"updated_at": at.UTC().Format(time.RFC3339)})
}

func (s *Service) handleGet(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	m, data, err := s.Get(r.Context(), p.UserID)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "application/octet-stream")
	h.Set("Cache-Control", "no-store")
	h.Set("X-Backup-Schema", strconv.Itoa(m.SchemaVersion))
	h.Set("X-Backup-Sha256", m.SHA256)
	h.Set("X-Kdf-Params", string(m.KDFParams))
	h.Set("X-Backup-Updated-At", m.UpdatedAt.UTC().Format(time.RFC3339))
	h.Set("Content-Length", strconv.Itoa(len(data)))
	_, _ = w.Write(data) // #nosec G705 -- opaque encrypted bytes served as application/octet-stream
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
