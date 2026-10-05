package jobs

import (
	"context"
	"time"
)

// PartitionCreator ensures event partitions exist (analytics.Service implements it).
type PartitionCreator interface {
	EnsurePartitions(ctx context.Context, ahead int) error
}

// PartitionsInterval is how often create_partitions runs.
const PartitionsInterval = 24 * time.Hour

// CreatePartitions returns the job: current month plus two months ahead.
func CreatePartitions(p PartitionCreator) func(context.Context) error {
	return func(ctx context.Context) error { return p.EnsurePartitions(ctx, 2) }
}
