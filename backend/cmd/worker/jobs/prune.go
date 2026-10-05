package jobs

import (
	"context"
	"time"
)

// Pruner deletes expired raw events (analytics.Service implements it).
type Pruner interface {
	Prune(ctx context.Context) error
}

// PruneInterval is how often prune_events runs.
const PruneInterval = 24 * time.Hour

// PruneEvents returns the job.
func PruneEvents(p Pruner) func(context.Context) error { return p.Prune }
