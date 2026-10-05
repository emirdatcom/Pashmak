package httpx

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

func TestStatusMapCoversAllCodes(t *testing.T) {
	want := map[Code]int{
		"INVALID_INPUT": 400, "UNAUTHENTICATED": 401, "TOKEN_INVALID": 401, "TOKEN_REUSED": 401,
		"FORBIDDEN": 403, "NOT_FOUND": 404, "TRIAL_ALREADY_USED": 409, "TRIAL_DISABLED": 409,
		"PURCHASE_ALREADY_CLAIMED": 409, "PURCHASE_INVALID": 422, "PAYLOAD_TOO_LARGE": 413,
		"BACKUP_TOO_LARGE": 413, "RATE_LIMITED": 429, "UPGRADE_REQUIRED": 426,
		"MARKET_UNAVAILABLE": 503, "INTERNAL": 500,
	}
	for code, st := range want {
		rec := httptest.NewRecorder()
		WriteError(rec, httptest.NewRequest("GET", "/", nil), code, "m")
		if rec.Code != st {
			t.Errorf("%s: got %d want %d", code, rec.Code, st)
		}
		var b errorBody
		if err := json.Unmarshal(rec.Body.Bytes(), &b); err != nil || b.Error.Code != code {
			t.Errorf("%s: bad body %s", code, rec.Body.String())
		}
	}
}

func TestCodeOfWrapped(t *testing.T) {
	c, _ := CodeOf(wrap(NewError(CodeTrialAlreadyUsed, "x")))
	if c != CodeTrialAlreadyUsed {
		t.Fatal(c)
	}
	if c, _ := CodeOf(http.ErrAbortHandler); c != CodeInternal {
		t.Fatal(c)
	}
}

type wrapped struct{ err error }

func (w wrapped) Error() string { return "wrapped: " + w.err.Error() }
func (w wrapped) Unwrap() error { return w.err }
func wrap(e error) error        { return wrapped{e} }

func TestDecodeJSONRejectsUnknownFields(t *testing.T) {
	var dst struct{ A int }
	r := httptest.NewRequest("POST", "/", strings.NewReader(`{"A":1,"B":2}`))
	if err := DecodeJSON(r, &dst); err == nil {
		t.Fatal("expected error")
	}
	r = httptest.NewRequest("POST", "/", strings.NewReader(`{"A":1}`))
	if err := DecodeJSON(r, &dst); err != nil || dst.A != 1 {
		t.Fatal(err)
	}
}

func TestRateLimitFakeClock(t *testing.T) {
	clk := clock.NewFake(time.Unix(0, 0))
	l := NewRateLimiter(clk, 2, 3600) // 1 token/s
	first, second, third := l.Allow("a"), l.Allow("a"), l.Allow("a")
	if !first || !second || third {
		t.Fatal("burst of 2 expected")
	}
	if !l.Allow("b") {
		t.Fatal("keys independent")
	}
	clk.Advance(1500 * time.Millisecond)
	if !l.Allow("a") || l.Allow("a") {
		t.Fatal("one token should have refilled")
	}
}

func TestMiddlewareChain(t *testing.T) {
	m := metrics.New()
	r := NewRouter()
	r.HandleFunc("GET /boom", func(http.ResponseWriter, *http.Request) { panic("kaboom") })
	r.HandleFunc("POST /echo", func(w http.ResponseWriter, req *http.Request) {
		var v map[string]any
		if err := DecodeJSON(req, &v); err != nil {
			WriteErr(w, req, err)
			return
		}
		WriteJSON(w, 200, v)
	})
	h := Chain(r, RequestID(), Recover(), Logging(), Metrics(m), BodyLimit(1024))

	// RequestID generated and panic recovered without leaking details.
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/boom", nil))
	if rec.Code != 500 || rec.Header().Get("X-Request-Id") == "" || strings.Contains(rec.Body.String(), "kaboom") {
		t.Fatalf("recover: %d %s", rec.Code, rec.Body.String())
	}
	var b errorBody
	_ = json.Unmarshal(rec.Body.Bytes(), &b)
	if b.Error.Code != CodeInternal || b.Error.RequestID != rec.Header().Get("X-Request-Id") {
		t.Fatalf("body: %+v", b)
	}

	// Incoming request id is propagated.
	req := httptest.NewRequest("GET", "/boom", nil)
	req.Header.Set("X-Request-Id", "my-request-id-1")
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Header().Get("X-Request-Id") != "my-request-id-1" {
		t.Fatal("request id not propagated")
	}

	// Oversized body -> 413 with standard body (Content-Length known).
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("POST", "/echo", bytes.NewReader(make([]byte, 2048))))
	if rec.Code != 413 || !strings.Contains(rec.Body.String(), "PAYLOAD_TOO_LARGE") {
		t.Fatalf("limit: %d %s", rec.Code, rec.Body.String())
	}

	// Unknown route -> JSON 404.
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/nope", nil))
	if rec.Code != 404 || !strings.Contains(rec.Body.String(), "NOT_FOUND") {
		t.Fatalf("404: %d %s", rec.Code, rec.Body.String())
	}
}
