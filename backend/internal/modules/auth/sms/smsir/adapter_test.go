package smsir

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
)

func golden(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestSendOTPContract(t *testing.T) {
	var got map[string]any
	var key, ctype string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/v1/send/verify" {
			t.Errorf("unexpected %s %s", r.Method, r.URL.Path)
		}
		key, ctype = r.Header.Get("x-api-key"), r.Header.Get("Content-Type")
		_ = json.NewDecoder(r.Body).Decode(&got)
		_, _ = w.Write(golden(t, "verify_ok.json"))
	}))
	defer srv.Close()
	a := New(Config{BaseURL: srv.URL, APIKey: "k-123", TemplateID: "100001"}, nil)
	if err := a.SendOTP(context.Background(), "+989123456789", "12345"); err != nil {
		t.Fatal(err)
	}
	if key != "k-123" || ctype != "application/json" {
		t.Fatalf("headers: key=%q type=%q", key, ctype)
	}
	if got["mobile"] != "09123456789" || got["templateId"] != float64(100001) {
		t.Fatalf("body: %v", got)
	}
	ps := got["parameters"].([]any)[0].(map[string]any)
	if ps["name"] != "CODE" || ps["value"] != "12345" {
		t.Fatalf("parameters: %v", ps)
	}
}

func TestProviderErrorsMapToUnavailableWithoutLeaks(t *testing.T) {
	for name, handler := range map[string]http.HandlerFunc{
		"5xx":       func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(502) },
		"api error": func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write(golden(t, "error_invalid_key.json")) },
		"bad json":  func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("<html>")) },
	} {
		srv := httptest.NewServer(handler)
		a := New(Config{BaseURL: srv.URL, APIKey: "SECRET-KEY", TemplateID: "1"}, nil)
		err := a.SendOTP(context.Background(), "+989123456789", "98765")
		srv.Close()
		if !errors.Is(err, ErrUnavailable) {
			t.Fatalf("%s: want ErrUnavailable, got %v", name, err)
		}
		for _, secret := range []string{"SECRET-KEY", "98765", "09123456789", "9123456789"} {
			if strings.Contains(err.Error(), secret) {
				t.Fatalf("%s: error leaks %q: %v", name, secret, err)
			}
		}
	}
}

func TestNetworkErrorRetriesOnce(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if atomic.AddInt32(&calls, 1) == 1 {
			hj, _ := w.(http.Hijacker)
			c, _, _ := hj.Hijack()
			_ = c.Close() // transport failure
			return
		}
		_, _ = w.Write(golden(t, "verify_ok.json"))
	}))
	defer srv.Close()
	a := New(Config{BaseURL: srv.URL, APIKey: "k", TemplateID: "1"}, nil)
	if err := a.SendOTP(context.Background(), "+989123456789", "1"); err != nil {
		t.Fatalf("the single retry should succeed: %v", err)
	}
	if calls != 2 {
		t.Fatalf("calls=%d", calls)
	}
	// a provider answer is never retried
	calls = 0
	bad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { atomic.AddInt32(&calls, 1); w.WriteHeader(500) }))
	defer bad.Close()
	if err := New(Config{BaseURL: bad.URL, APIKey: "k", TemplateID: "1"}, nil).SendOTP(context.Background(), "+989123456789", "1"); err == nil || calls != 1 {
		t.Fatalf("err=%v calls=%d", err, calls)
	}
}

func TestSendAlertBulk(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/send/bulk" {
			t.Errorf("path %s", r.URL.Path)
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
		_, _ = w.Write(golden(t, "verify_ok.json"))
	}))
	defer srv.Close()
	a := New(Config{BaseURL: srv.URL, APIKey: "k", LineNumber: "30007732"}, nil)
	if err := a.SendAlert(context.Background(), []string{"+989121111111", "09122222222"}, "ALERT x"); err != nil {
		t.Fatal(err)
	}
	m := got["mobiles"].([]any)
	if len(m) != 2 || m[0] != "09121111111" || m[1] != "09122222222" || got["messageText"] != "ALERT x" || got["lineNumber"] != float64(30007732) {
		t.Fatalf("body: %v", got)
	}
	if err := New(Config{BaseURL: srv.URL, APIKey: "k"}, nil).SendAlert(context.Background(), []string{"0912"}, "x"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("missing line number must fail: %v", err)
	}
	if err := a.SendAlert(context.Background(), nil, "x"); err != nil {
		t.Fatalf("no phones is a no-op: %v", err)
	}
}
