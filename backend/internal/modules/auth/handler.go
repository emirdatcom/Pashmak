package auth

import (
	"net/http"
	"strings"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

type sessionResponse struct {
	UserID          string `json:"user_id"`
	AccessToken     string `json:"access_token"`
	AccessExpiresAt string `json:"access_expires_at"`
	RefreshToken    string `json:"refresh_token"`
}

func toResponse(s Session) sessionResponse {
	return sessionResponse{UserID: s.UserID.String(), AccessToken: s.AccessToken,
		AccessExpiresAt: s.AccessExpiresAt.UTC().Format(time.RFC3339), RefreshToken: s.RefreshToken}
}

// Register mounts /v1/auth routes. /auth/device is limited to 10 per hour per IP.
func Register(r *httpx.Router, s *Service, clk clock.Clock) {
	deviceLimit := httpx.RateLimit(httpx.NewRateLimiter(clk, 10, 10))
	r.HandleFunc("POST /v1/auth/device", s.handleDevice, deviceLimit)
	r.HandleFunc("POST /v1/auth/refresh", s.handleRefresh)
}

func (s *Service) handleDevice(w http.ResponseWriter, r *http.Request) {
	var in DeviceInput
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	sess, err := s.RegisterDevice(r.Context(), in)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, toResponse(sess))
}

func (s *Service) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	sess, err := s.Refresh(r.Context(), in.RefreshToken)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, toResponse(sess))
}

// RequireAuth validates the Bearer token and puts the Principal in the context.
func (s *Service) RequireAuth() httpx.Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h := r.Header.Get("Authorization")
			tok, ok := strings.CutPrefix(h, "Bearer ")
			if !ok || tok == "" {
				httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
				return
			}
			p, err := s.Authenticate(r.Context(), tok)
			if err != nil {
				httpx.WriteErr(w, r, err)
				return
			}
			ctx := httpx.WithPrincipal(r.Context(), p)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// OptionalAuth is RequireAuth that lets anonymous requests (no Authorization header) through.
// A present but invalid token is still rejected so clients refresh it.
func (s *Service) OptionalAuth() httpx.Middleware {
	require := s.RequireAuth()
	return func(next http.Handler) http.Handler {
		authed := require(next)
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Authorization") == "" {
				next.ServeHTTP(w, r)
				return
			}
			authed.ServeHTTP(w, r)
		})
	}
}
