package jobs

import (
	"context"
	"time"
)

// SupportPruner deletes support conversations closed more than 12 months ago (support.Service implements it).
type SupportPruner interface {
	Prune(ctx context.Context) error
}

// SupportPruneInterval is how often prune_support runs.
const SupportPruneInterval = 24 * time.Hour

// PruneSupport returns the job.
func PruneSupport(p SupportPruner) func(context.Context) error { return p.Prune }
