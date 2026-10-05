// Package billing verifies market purchases and turns them into grants (docs/10 §8, docs/60).
package billing

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// MarketState is the market's view of a purchase.
type MarketState string

// Market states.
const (
	MarketValid    MarketState = "valid"
	MarketRefunded MarketState = "refunded"
	MarketCanceled MarketState = "canceled" // immediate cancellation (not just auto-renew off)
	MarketExpired  MarketState = "expired"
	MarketInvalid  MarketState = "invalid" // unknown / forged token
)

// MarketPurchase is what an adapter reports.
type MarketPurchase struct {
	State        MarketState
	OrderID      string
	PurchasedAt  time.Time
	ExpiresAt    time.Time // zero for non-subscriptions
	AutoRenewing bool
	Raw          []byte // sanitized JSON from the market (no secrets); stored as raw_response
}

// ErrMarketUnavailable marks transient failures (network, 5xx, timeout, not configured).
var ErrMarketUnavailable = errors.New("billing: market unavailable")

// MarketVerifier is implemented per market (bazaar, myket, fake).
type MarketVerifier interface {
	Verify(ctx context.Context, sku, token string) (MarketPurchase, error)
}

// ServerEventSink receives server-side analytics events (analytics module implements it in prompt 04).
type ServerEventSink interface {
	Emit(ctx context.Context, name string, userID uuid.UUID, props map[string]any) error
}

// NoopSink discards events.
type NoopSink struct{}

// Emit implements ServerEventSink.
func (NoopSink) Emit(context.Context, string, uuid.UUID, map[string]any) error { return nil }

// Registry maps market names to verifiers. Missing markets are "not enabled".
type Registry map[string]MarketVerifier
