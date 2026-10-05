// Package app wires the HTTP handler tree shared by cmd/api and tests.
package app

import (
	"context"
	"net/http"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/modules/admin"
	"github.com/emirdatcom/pashmak/backend/internal/modules/analytics"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth"
	"github.com/emirdatcom/pashmak/backend/internal/modules/backup"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/modules/content"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/modules/remoteconfig"
	"github.com/emirdatcom/pashmak/backend/internal/modules/user"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

// MaxBodyBytes is the default request body limit (docs/10 §12).
const MaxBodyBytes = 256 * 1024

// MaxBackupBytes is the body limit of PUT /v1/backup (docs/10 §6.1).
const MaxBackupBytes = 10 << 20

func bodyLimit(r *http.Request) (int64, httpx.Code) {
	if r.Method == http.MethodPut && r.URL.Path == "/v1/backup" {
		return MaxBackupBytes, httpx.CodeBackupTooLarge
	}
	return MaxBodyBytes, httpx.CodePayloadTooLarge
}

// Pinger checks database liveness.
type Pinger interface {
	Ping(ctx context.Context) error
}

// Deps are the handler dependencies.
type Deps struct {
	DB      Pinger
	Metrics *metrics.Metrics
	Clock   clock.Clock
	Auth    *auth.Service // optional in health-only tests
	User    *user.Service
	Entitle *entitlement.Service
	Billing *billing.Service

	RemoteConfig *remoteconfig.Service
	Content      *content.Service
	Analytics    *analytics.Service
	Admin        *admin.Service
	Phone        *auth.PhoneService // nil unless an SMS provider is configured
	Backup       *backup.Service
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
	if d.Auth != nil {
		auth.Register(r, d.Auth, d.Clock)
		requireAuth := d.Auth.RequireAuth()
		if d.User != nil {
			user.Register(r, d.User, requireAuth)
		}
		if d.Entitle != nil {
			entitlement.Register(r, d.Entitle, requireAuth)
		}
		if d.Billing != nil {
			billing.Register(r, d.Billing, requireAuth, d.Clock)
		}
		if d.RemoteConfig != nil {
			remoteconfig.Register(r, d.RemoteConfig, d.Auth.OptionalAuth())
		}
		if d.Analytics != nil {
			analytics.Register(r, d.Analytics, requireAuth)
		}
		if d.Phone != nil {
			auth.RegisterPhone(r, d.Phone, requireAuth, d.Clock)
		}
		if d.Backup != nil {
			backup.Register(r, d.Backup, requireAuth, d.Clock)
		}
	}
	if d.Content != nil {
		content.Register(r, d.Content)
	}
	if d.Admin != nil {
		admin.Register(r, d.Admin)
	}
	// Generous global per-IP limit; stricter per-route limits are added by modules.
	global := httpx.NewRateLimiter(d.Clock, 120, 6000)
	h := httpx.Chain(r,
		httpx.RequestID(), httpx.Recover(), httpx.Logging(), httpx.Metrics(d.Metrics),
		httpx.BodyLimitFunc(bodyLimit), httpx.RateLimit(global))
	return r, h
}
