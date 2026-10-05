// Command alert-relay receives Alertmanager webhooks and sends SMS through sms.ir (decision D-5).
// Env: ALERT_RELAY_ADDR (default :9095), ALERT_RELAY_TOKEN (optional), ALERT_PHONES,
// SMSIR_API_KEY, SMSIR_LINE_NUMBER.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/alertrelay"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth/sms/smsir"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
)

func main() {
	var phones []string
	for _, p := range strings.Split(os.Getenv("ALERT_PHONES"), ",") {
		if p = strings.TrimSpace(p); p != "" {
			phones = append(phones, p)
		}
	}
	if len(phones) == 0 || os.Getenv("SMSIR_API_KEY") == "" {
		slog.Error("ALERT_PHONES and SMSIR_API_KEY are required")
		os.Exit(1)
	}
	sender := smsir.New(smsir.Config{APIKey: os.Getenv("SMSIR_API_KEY"), LineNumber: os.Getenv("SMSIR_LINE_NUMBER")}, nil)
	relay := alertrelay.New(alertrelay.Config{Phones: phones, Token: os.Getenv("ALERT_RELAY_TOKEN")}, sender, clock.Real{})
	mux := http.NewServeMux()
	mux.Handle("POST /alert", relay)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	addr := os.Getenv("ALERT_RELAY_ADDR")
	if addr == "" {
		addr = ":9095"
	}
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("alert-relay stopped", "err", err)
			os.Exit(1)
		}
	}()
	slog.Info("alert-relay started", "addr", addr, "phones", len(phones))
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdown)
}
