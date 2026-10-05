// Package app wires the HTTP handler tree shared by cmd/api and tests.
package app

import (
	"context"
	"net/http"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

// MaxBodyBytes is the default request body limit (docs/10 §12).
const MaxBodyBytes = 256 * 1024

// Pinger checks database liveness.
type Pinger interface {
	Ping(ctx context.Context) error
}

// Deps are the handler dependencies.
type Deps struct {
	DB      Pinger
	Metrics *metrics.Metrics
	Clock   clock.Clock
}

// Handler builds the router with the global middleware chain:
// RequestID → Recover → Logging → Metrics → BodyLimit → RateLimit.
// Module routes (auth etc.) are added later through the returned Router's Handle.
func Handler(d Deps) (*httpx.Router, http.Handler) {
	r := httpx.NewRouter()
	r.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	r.HandleFunc("GET /readyz", func(w http.ResponseWriter, req *http.Request) {
		ctx, cancel := context.WithTimeout(req.Context(), 2*time.Second)
		defer cancel()
		if err := d.DB.Ping(ctx); err != nil {
			httpx.WriteJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable", "db": "down"})
			return
		}
		httpx.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok", "db": "ok"})
	})
	// Generous global per-IP limit; stricter per-route limits are added by modules.
	global := httpx.NewRateLimiter(d.Clock, 120, 6000)
	h := httpx.Chain(r,
		httpx.RequestID(), httpx.Recover(), httpx.Logging(), httpx.Metrics(d.Metrics),
		httpx.BodyLimit(MaxBodyBytes), httpx.RateLimit(global))
	return r, h
}
