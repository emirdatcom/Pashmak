package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net"
	"net/http"
	"regexp"
	"runtime/debug"
	"strconv"
	"sync"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

// Middleware wraps a handler.
type Middleware func(http.Handler) http.Handler

// Chain applies middleware so the first one is outermost.
func Chain(h http.Handler, mw ...Middleware) http.Handler {
	for i := len(mw) - 1; i >= 0; i-- {
		h = mw[i](h)
	}
	return h
}

// ClientInfo carries the client headers (docs/10 §6).
type ClientInfo struct {
	AppVersion string
	Market     string
	InstallID  string
}

type clientKey struct{}

// ClientFrom returns the client headers stored by RequestID.
func ClientFrom(ctx context.Context) ClientInfo {
	c, _ := ctx.Value(clientKey{}).(ClientInfo)
	return c
}

var reqIDRe = regexp.MustCompile(`^[A-Za-z0-9._-]{8,64}$`)

func newRequestID() string {
	var b [12]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}

// RequestID assigns/propagates X-Request-Id and records client headers in the context.
func RequestID() Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			id := r.Header.Get("X-Request-Id")
			if !reqIDRe.MatchString(id) {
				id = newRequestID()
			}
			w.Header().Set("X-Request-Id", id)
			ctx := plog.WithFields(r.Context(), plog.Fields{RequestID: id})
			ctx = context.WithValue(ctx, clientKey{}, ClientInfo{
				AppVersion: r.Header.Get("X-App-Version"),
				Market:     r.Header.Get("X-Market"),
				InstallID:  r.Header.Get("X-Install-Id"),
			})
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// Recover converts panics into 500 INTERNAL, logging the stack (never in the response).
func Recover() Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if v := recover(); v != nil {
					slog.ErrorContext(r.Context(), "panic recovered", "panic", v, "stack", string(debug.Stack()))
					WriteError(w, r, CodeInternal, "internal error")
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(c int) {
	s.status = c
	s.ResponseWriter.WriteHeader(c)
}

func routeOf(r *http.Request) string {
	if r.Pattern != "" {
		return r.Pattern
	}
	return "unmatched"
}

// Logging logs one JSON line per request.
func Logging() Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(sw, r)
			slog.InfoContext(r.Context(), "request",
				"route", routeOf(r), "method", r.Method, "status", sw.status,
				"latency_ms", time.Since(start).Milliseconds())
		})
	}
}

// Metrics records request count and latency.
func Metrics(m *metrics.Metrics) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(sw, r)
			route := routeOf(r)
			m.HTTPRequests.WithLabelValues(route, strconv.Itoa(sw.status)).Inc()
			m.HTTPDuration.WithLabelValues(route).Observe(time.Since(start).Seconds())
		})
	}
}

// BodyLimit rejects bodies larger than max with 413 PAYLOAD_TOO_LARGE.
func BodyLimit(limit int64) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.ContentLength > limit {
				WriteError(w, r, CodePayloadTooLarge, "request body too large")
				return
			}
			r.Body = http.MaxBytesReader(w, r.Body, limit)
			next.ServeHTTP(w, r)
		})
	}
}

// RateLimiter is an in-memory token bucket keyed by string.
type RateLimiter struct {
	clk      clock.Clock
	rate     float64 // tokens per second
	burst    float64
	mu       sync.Mutex
	buckets  map[string]*bucket
	lastSwep time.Time
}

type bucket struct {
	tokens float64
	last   time.Time
}

// NewRateLimiter allows `burst` requests at once, refilling `perHour` tokens per hour.
func NewRateLimiter(clk clock.Clock, burst int, perHour float64) *RateLimiter {
	return &RateLimiter{clk: clk, rate: perHour / 3600, burst: float64(burst), buckets: map[string]*bucket{}}
}

// Allow consumes a token for key, reporting whether the request may proceed.
func (l *RateLimiter) Allow(key string) bool {
	now := l.clk.Now()
	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.lastSwep) > time.Hour {
		for k, b := range l.buckets {
			if now.Sub(b.last) > time.Hour {
				delete(l.buckets, k)
			}
		}
		l.lastSwep = now
	}
	b, ok := l.buckets[key]
	if !ok {
		b = &bucket{tokens: l.burst, last: now}
		l.buckets[key] = b
	}
	b.tokens += now.Sub(b.last).Seconds() * l.rate
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// ClientIP returns the remote IP (the reverse proxy is trusted to set it as RemoteAddr via Caddy).
func ClientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// RateLimit limits by client IP. Usable globally or per route.
func RateLimit(l *RateLimiter) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !l.Allow(ClientIP(r)) {
				w.Header().Set("Retry-After", "60")
				WriteError(w, r, CodeRateLimited, "too many requests")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RateLimitUser limits by authenticated user id (falls back to IP). Use after the auth middleware.
func RateLimitUser(l *RateLimiter) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := ClientIP(r)
			if p, ok := PrincipalFrom(r.Context()); ok {
				key = "u:" + p.UserID.String()
			}
			if !l.Allow(key) {
				w.Header().Set("Retry-After", "60")
				WriteError(w, r, CodeRateLimited, "too many requests")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
