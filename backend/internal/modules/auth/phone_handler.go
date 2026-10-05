package auth

import (
	"net/http"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// RegisterPhone mounts the phone-linking endpoints (phase 2). OTP requests are limited to
// 10/hour/IP here and 3/hour/number inside the service.
func RegisterPhone(r *httpx.Router, s *PhoneService, requireAuth httpx.Middleware, clk clock.Clock) {
	ipLimit := httpx.RateLimit(httpx.NewRateLimiter(clk, 10, 10))
	r.HandleFunc("POST /v1/auth/phone/otp", s.handleOTP, ipLimit, requireAuth)
	r.HandleFunc("POST /v1/auth/phone/verify", s.handleVerify, requireAuth)
}

func (s *PhoneService) handleOTP(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in struct {
		Phone string `json:"phone"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	id, retry, err := s.RequestOTP(r.Context(), p, in.Phone)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"challenge_id": id.String(), "retry_after_s": retry})
}

func (s *PhoneService) handleVerify(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.PrincipalFrom(r.Context())
	if !ok {
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "authentication required")
		return
	}
	var in struct {
		ChallengeID string `json:"challenge_id"`
		Code        string `json:"code"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	res, err := s.VerifyOTP(r.Context(), p, in.ChallengeID, in.Code)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{
		"user_id": res.Session.UserID.String(), "access_token": res.Session.AccessToken,
		"access_expires_at": res.Session.AccessExpiresAt.UTC().Format(time.RFC3339),
		"refresh_token":     res.Session.RefreshToken, "merged": res.Merged})
}
