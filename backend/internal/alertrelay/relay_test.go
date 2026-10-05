package alertrelay

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
)

type fakeSender struct {
	texts  []string
	phones [][]string
	err    error
}

func (f *fakeSender) SendAlert(_ context.Context, phones []string, text string) error {
	if f.err != nil {
		return f.err
	}
	f.texts = append(f.texts, text)
	f.phones = append(f.phones, phones)
	return nil
}

func hook(status, name, fp, summary string) string {
	return `{"status":"` + status + `","alerts":[{"status":"` + status + `","fingerprint":"` + fp + `","labels":{"alertname":"` + name + `"},"annotations":{"summary":"` + summary + `"}}]}`
}

func post(t *testing.T, r *Relay, body, auth string) int {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/alert", strings.NewReader(body))
	if auth != "" {
		req.Header.Set("Authorization", auth)
	}
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec.Code
}

func TestThrottlePerAlertAndResolved(t *testing.T) {
	clk := clock.NewFake(time.Date(2026, 10, 5, 8, 0, 0, 0, time.UTC))
	s := &fakeSender{}
	r := New(Config{Phones: []string{"+989121111111", "+989122222222"}}, s, clk)

	if c := post(t, r, hook("firing", "High5xx", "f1", "5xx above 2%"), ""); c != 200 {
		t.Fatal(c)
	}
	post(t, r, hook("firing", "High5xx", "f1", "5xx above 2%"), "") // repeated by Alertmanager: throttled
	clk.Advance(10 * time.Minute)
	post(t, r, hook("firing", "High5xx", "f1", ""), "")
	if len(s.texts) != 1 || s.texts[0] != "[ALERT] High5xx: 5xx above 2%" || len(s.phones[0]) != 2 {
		t.Fatalf("after throttle: %v", s.texts)
	}
	post(t, r, hook("firing", "DiskFull", "f2", "disk"), "") // a different alert is independent
	clk.Advance(31 * time.Minute)
	post(t, r, hook("firing", "High5xx", "f1", ""), "")
	if len(s.texts) != 3 {
		t.Fatalf("after 30 min the alert may fire again: %v", s.texts)
	}
	post(t, r, hook("resolved", "High5xx", "f1", ""), "")
	if got := s.texts[len(s.texts)-1]; got != "[OK] High5xx" {
		t.Fatalf("resolved message: %q", got)
	}
	n := len(s.texts)
	post(t, r, hook("resolved", "Unknown", "f9", ""), "") // never fired → no SMS
	if len(s.texts) != n {
		t.Fatal("resolved without a firing SMS must be silent")
	}
}

func TestDailyCapAndNewDay(t *testing.T) {
	clk := clock.NewFake(time.Date(2026, 10, 5, 0, 5, 0, 0, time.UTC))
	s := &fakeSender{}
	r := New(Config{Phones: []string{"1"}, MaxPerDay: 3}, s, clk)
	for i := 0; i < 6; i++ {
		post(t, r, hook("firing", "A"+string(rune('a'+i)), "fp"+string(rune('a'+i)), ""), "")
	}
	if len(s.texts) != 3 {
		t.Fatalf("cap: %d", len(s.texts))
	}
	clk.Advance(24 * time.Hour)
	post(t, r, hook("firing", "Next", "fpz", ""), "")
	if len(s.texts) != 4 {
		t.Fatal("the counter resets on a new day")
	}
}

func TestAuthAndErrors(t *testing.T) {
	clk := clock.NewFake(time.Now())
	s := &fakeSender{}
	r := New(Config{Phones: []string{"1"}, Token: "secret"}, s, clk)
	if c := post(t, r, hook("firing", "A", "f", ""), ""); c != http.StatusUnauthorized {
		t.Fatal(c)
	}
	if c := post(t, r, hook("firing", "A", "f", ""), "Bearer secret"); c != 200 {
		t.Fatal(c)
	}
	if c := post(t, r, "not json", "Bearer secret"); c != http.StatusBadRequest {
		t.Fatal(c)
	}
	s.err = errors.New("boom")
	if c := post(t, r, hook("firing", "B", "g", ""), "Bearer secret"); c != http.StatusBadGateway {
		t.Fatalf("a failed SMS must make Alertmanager retry: %d", c)
	}
	s.err = nil
	if c := post(t, r, hook("firing", "B", "g", ""), "Bearer secret"); c != 200 || len(s.texts) != 2 {
		t.Fatalf("a failed send must not count as sent: %d %v", c, s.texts)
	}
}

func TestLongTextIsCut(t *testing.T) {
	clk := clock.NewFake(time.Now())
	s := &fakeSender{}
	r := New(Config{Phones: []string{"1"}}, s, clk)
	post(t, r, hook("firing", "X", "f", strings.Repeat("خ", 400)), "")
	if n := len([]rune(s.texts[0])); n != 160 {
		t.Fatalf("runes=%d", n)
	}
}
