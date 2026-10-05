// Package alertrelay turns Alertmanager webhooks into SMS alerts (decision D-5: no Telegram/Bale).
// It throttles per alert (one firing SMS per 30 minutes) and overall (20 SMS per day); a "resolved"
// message is sent only for alerts that actually produced a firing SMS.
package alertrelay

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
)

// Sender delivers one SMS text to all on-call phones (smsir.Adapter implements it).
type Sender interface {
	SendAlert(ctx context.Context, phones []string, text string) error
}

// Config tunes the relay. Zero values use the documented defaults.
type Config struct {
	Phones      []string
	Token       string        // optional shared secret (Authorization: Bearer <token>)
	PerAlert    time.Duration // default 30 min
	MaxPerDay   int           // default 20
	MaxTextRune int           // default 160
}

// Relay is the http.Handler for POST /alert.
type Relay struct {
	cfg    Config
	sender Sender
	clk    clock.Clock

	mu       sync.Mutex
	lastSent map[string]time.Time // fingerprint -> last firing SMS
	active   map[string]bool      // fingerprint -> a firing SMS was sent and not yet resolved
	day      string
	sentDay  int
}

// New builds a Relay.
func New(cfg Config, sender Sender, clk clock.Clock) *Relay {
	if cfg.PerAlert == 0 {
		cfg.PerAlert = 30 * time.Minute
	}
	if cfg.MaxPerDay == 0 {
		cfg.MaxPerDay = 20
	}
	if cfg.MaxTextRune == 0 {
		cfg.MaxTextRune = 160
	}
	return &Relay{cfg: cfg, sender: sender, clk: clk, lastSent: map[string]time.Time{}, active: map[string]bool{}}
}

type webhook struct {
	Status string `json:"status"`
	Alerts []struct {
		Status      string            `json:"status"`
		Labels      map[string]string `json:"labels"`
		Annotations map[string]string `json:"annotations"`
		Fingerprint string            `json:"fingerprint"`
	} `json:"alerts"`
}

// ServeHTTP implements http.Handler.
func (r *Relay) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if r.cfg.Token != "" {
		got := strings.TrimPrefix(req.Header.Get("Authorization"), "Bearer ")
		if subtle.ConstantTimeCompare([]byte(got), []byte(r.cfg.Token)) != 1 {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
	}
	body, err := io.ReadAll(io.LimitReader(req.Body, 1<<20))
	if err != nil {
		http.Error(w, "bad body", http.StatusBadRequest)
		return
	}
	var wh webhook
	if err := json.Unmarshal(body, &wh); err != nil {
		http.Error(w, "bad json", http.StatusBadRequest)
		return
	}
	sent := 0
	for _, a := range wh.Alerts {
		ok, err := r.handle(req.Context(), a.Status, a.Fingerprint, a.Labels, a.Annotations)
		if err != nil {
			slog.Error("alert sms failed", "alert", a.Labels["alertname"], "err", err.Error())
			http.Error(w, "send failed", http.StatusBadGateway) // Alertmanager retries
			return
		}
		if ok {
			sent++
		}
	}
	slog.Info("alerts processed", "alerts", len(wh.Alerts), "sms", sent)
	w.WriteHeader(http.StatusOK)
}

func (r *Relay) handle(ctx context.Context, status, fp string, labels, ann map[string]string) (bool, error) {
	name := labels["alertname"]
	if fp == "" {
		fp = name
	}
	now := r.clk.Now()
	r.mu.Lock()
	defer r.mu.Unlock()
	if day := now.UTC().Format("2006-01-02"); day != r.day {
		r.day, r.sentDay = day, 0
	}
	resolved := status == "resolved"
	if resolved {
		if !r.active[fp] {
			return false, nil // nobody was told about it firing
		}
	} else if last, ok := r.lastSent[fp]; ok && now.Sub(last) < r.cfg.PerAlert {
		return false, nil
	}
	if r.sentDay >= r.cfg.MaxPerDay {
		return false, nil
	}
	text := format(status, name, ann["summary"], r.cfg.MaxTextRune)
	if err := r.sender.SendAlert(ctx, r.cfg.Phones, text); err != nil {
		return false, err
	}
	r.sentDay++
	if resolved {
		delete(r.active, fp)
	} else {
		r.lastSent[fp] = now
		r.active[fp] = true
	}
	return true, nil
}

func format(status, name, summary string, maxRunes int) string {
	tag := "ALERT"
	if status == "resolved" {
		tag = "OK"
	}
	t := fmt.Sprintf("[%s] %s", tag, name)
	if summary != "" {
		t += ": " + summary
	}
	if r := []rune(t); len(r) > maxRunes {
		t = string(r[:maxRunes-1]) + "…"
	}
	return t
}
