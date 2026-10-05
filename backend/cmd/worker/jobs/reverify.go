// Package jobs holds the worker's scheduled jobs.
package jobs

import (
	"context"
	"time"
)

// Reverifier re-checks subscription purchases (billing.Service implements it).
type Reverifier interface {
	ReverifySubscriptions(ctx context.Context) error
}

// ReverifyInterval is how often reverify_subscriptions runs (docs/10 §8).
const ReverifyInterval = 6 * time.Hour

// Reverify returns the job function.
func Reverify(r Reverifier) func(context.Context) error { return r.ReverifySubscriptions }
