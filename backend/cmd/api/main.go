// Command api runs the HTTP server.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/app"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/config"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}
	slog.SetDefault(plog.New(os.Stdout, cfg.LogLevel))

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := db.Open(ctx, cfg.DatabaseURL, cfg.DBMaxConns)
	if err != nil {
		return err
	}
	defer pool.Close()

	m := metrics.New()
	m.RegisterDBPool(func() metrics.DBStats { return pool.Stat() })
	clk := clock.Real{}
	svc, err := app.BuildServices(ctx, cfg, pool, clk, m, app.BuildOptions{NeedSigners: true})
	if err != nil {
		return err
	}
	_, handler := app.Handler(svc.Deps(pool, m, clk))

	api := &http.Server{Addr: cfg.HTTPAddr, Handler: handler, ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout: 15 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second}
	mux := http.NewServeMux()
	mux.Handle("GET /metrics", m.Handler())
	msrv := &http.Server{Addr: cfg.MetricsAddr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}

	errc := make(chan error, 2)
	go func() { errc <- api.ListenAndServe() }()
	go func() { errc <- msrv.ListenAndServe() }()
	slog.Info("api started", "addr", cfg.HTTPAddr, "metrics_addr", cfg.MetricsAddr, "env", cfg.AppEnv)

	select {
	case err := <-errc:
		if !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("server: %w", err)
		}
	case <-ctx.Done():
	}
	sctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = msrv.Shutdown(sctx)
	if err := api.Shutdown(sctx); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	slog.Info("api stopped")
	return nil
}
