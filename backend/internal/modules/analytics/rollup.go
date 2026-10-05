package analytics

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

const (
	retentionMonths = 18
	dedupeDays      = 7
)

// utcDay truncates t to 00:00 UTC.
func utcDay(t time.Time) time.Time {
	t = t.UTC()
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// RollupDay recomputes all daily metrics for the UTC day (idempotent: the day is cleared first).
func (s *Service) RollupDay(ctx context.Context, day time.Time) error {
	d := utcDay(day)
	end := d.AddDate(0, 0, 1)
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		if err := q.DeleteDailyMetrics(ctx, d); err != nil {
			return fmt.Errorf("clear day: %w", err)
		}
		for _, w := range []struct {
			metric string
			days   int
		}{{"dau", 1}, {"wau", 7}, {"mau", 30}} {
			if err := q.RollupActiveUsers(ctx, dbgen.RollupActiveUsersParams{Day: d, Metric: w.metric,
				WindowStart: end.AddDate(0, 0, -w.days), WindowEnd: end}); err != nil {
				return fmt.Errorf("rollup %s: %w", w.metric, err)
			}
		}
		if err := q.RollupStickiness(ctx, d); err != nil {
			return fmt.Errorf("rollup stickiness: %w", err)
		}
		if err := q.RollupNewInstalls(ctx, dbgen.RollupNewInstallsParams{Day: d, WindowStart: d, WindowEnd: end}); err != nil {
			return fmt.Errorf("rollup installs: %w", err)
		}
		for _, n := range []int{1, 7, 30} {
			cohort := d.AddDate(0, 0, -n)
			if err := q.RollupRetention(ctx, dbgen.RollupRetentionParams{Day: d, Metric: fmt.Sprintf("retention_d%d", n),
				CohortDay: cohort.Format("2006-01-02"), CohortStart: cohort, CohortEnd: cohort.AddDate(0, 0, 1),
				WindowStart: d, WindowEnd: end}); err != nil {
				return fmt.Errorf("rollup retention d%d: %w", n, err)
			}
		}
		if err := q.RollupTrialStartRate(ctx, dbgen.RollupTrialStartRateParams{Day: d, WindowStart: d, WindowEnd: end}); err != nil {
			return fmt.Errorf("rollup trial rate: %w", err)
		}
		if err := q.RollupActivation(ctx, dbgen.RollupActivationParams{Day: d, WindowStart: d, WindowEnd: end}); err != nil {
			return fmt.Errorf("rollup activation: %w", err)
		}
		if err := q.RollupPaywall(ctx, dbgen.RollupPaywallParams{Day: d, WindowStart: d, WindowEnd: end}); err != nil {
			return fmt.Errorf("rollup paywall: %w", err)
		}
		if err := q.RollupCoreLoop(ctx, dbgen.RollupCoreLoopParams{Day: d, WindowStart: d, WindowEnd: end}); err != nil {
			return fmt.Errorf("rollup core loop: %w", err)
		}
		return nil
	})
}

// RollupRecent recomputes the last `days` complete UTC days (late events are picked up on re-runs).
func (s *Service) RollupRecent(ctx context.Context, days int) error {
	today := utcDay(s.clk.Now())
	for i := 1; i <= days; i++ {
		if err := s.RollupDay(ctx, today.AddDate(0, 0, -i)); err != nil {
			return err
		}
	}
	return nil
}

// Prune drops partitions that lie entirely beyond the retention window and old dedupe rows.
func (s *Service) Prune(ctx context.Context) error {
	q := dbgen.New(s.pool)
	now := s.clk.Now()
	n, err := q.DropEventPartitionsBefore(ctx, utcDay(now).AddDate(0, -retentionMonths, 0))
	if err != nil {
		return fmt.Errorf("drop old partitions: %w", err)
	}
	rows, err := q.PruneEventsDedupe(ctx, now.AddDate(0, 0, -dedupeDays))
	if err != nil {
		return fmt.Errorf("prune dedupe: %w", err)
	}
	slog.InfoContext(ctx, "events pruned", "partitions_dropped", n, "dedupe_rows", rows)
	return nil
}
