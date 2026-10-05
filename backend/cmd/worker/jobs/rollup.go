package jobs

import (
	"context"
	"time"
)

// Roller recomputes daily metrics (analytics.Service implements it).
type Roller interface {
	RollupRecent(ctx context.Context, days int) error
}

// RollupInterval is how often rollup_daily runs.
const RollupInterval = 24 * time.Hour

// RollupDaily returns the job: the last two complete UTC days (the older one catches late events).
func RollupDaily(r Roller) func(context.Context) error {
	return func(ctx context.Context) error { return r.RollupRecent(ctx, 2) }
}
