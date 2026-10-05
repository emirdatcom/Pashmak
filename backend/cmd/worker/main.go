// Command worker runs scheduled background jobs.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"os"
	"os/signal"
	"syscall"
	"time"

	jobspkg "github.com/emirdatcom/pashmak/backend/cmd/worker/jobs"
	"github.com/emirdatcom/pashmak/backend/internal/app"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/config"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
)

// Job is a periodic task. Later prompts (04, 05) register more jobs in run().
type Job struct {
	Name     string
	Interval time.Duration
	Run      func(ctx context.Context) error
}

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
	clk := clock.Real{}

	// The worker never signs states; entitlement.Service only needs grant methods here.
	var entSign entitlement.Signer
	if s, serr := signer.LoadWithPrefix(cfg.SigningKeysDir, "ent-"); serr == nil {
		entSign = s
	}
	entSvc := entitlement.NewService(pool, entSign, clk, nil)
	billingSvc, err := app.NewBilling(cfg, pool, clk, nil, entSvc, nil)
	if err != nil {
		return fmt.Errorf("billing: %w", err)
	}

	jobs := []Job{
		{Name: "reverify_subscriptions", Interval: jobspkg.ReverifyInterval, Run: jobspkg.Reverify(billingSvc)},
	}
	slog.Info("worker started", "jobs", len(jobs))
	for _, j := range jobs {
		go loop(ctx, j)
	}
	<-ctx.Done()
	slog.Info("worker stopped")
	return nil
}

// loop runs j every Interval with up to 10% jitter.
func loop(ctx context.Context, j Job) {
	for {
		jitter := time.Duration(rand.Int64N(int64(j.Interval/10) + 1)) // #nosec G404 -- jitter only
		select {
		case <-ctx.Done():
			return
		case <-time.After(j.Interval + jitter):
		}
		if err := j.Run(ctx); err != nil {
			slog.Error("job failed", "job", j.Name, "err", err)
		}
	}
}
