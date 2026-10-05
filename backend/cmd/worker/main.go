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

	"github.com/emirdatcom/pashmak/backend/internal/platform/config"
	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
)

// Job is a periodic task. Later prompts (03, 04, 05) register jobs here.
type Job struct {
	Name     string
	Interval time.Duration
	Run      func(ctx context.Context) error
}

var jobs []Job // intentionally empty in the foundation step

func main() {
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintln(os.Stderr, "fatal: config:", err)
		os.Exit(1)
	}
	slog.SetDefault(plog.New(os.Stdout, cfg.LogLevel))
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	slog.Info("worker started", "jobs", len(jobs))
	for _, j := range jobs {
		go loop(ctx, j)
	}
	<-ctx.Done()
	slog.Info("worker stopped")
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
