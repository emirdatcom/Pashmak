// Package fake is a MarketVerifier for dev/staging/tests. It is never registered in prod.
//
// Token conventions: test_valid_[<N>d_]*, test_refunded_*, test_invalid_*, test_timeout_* (transient
// failure), test_slow_* (blocks until the context ends). Override(token, state) simulates later
// market-side changes (refund, cancellation) for re-verification tests.
package fake

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
)

// Adapter implements billing.MarketVerifier.
type Adapter struct {
	clk       clock.Clock
	mu        sync.Mutex
	firstSeen map[string]time.Time
	state     map[string]billing.MarketState
	noRenew   map[string]bool
	Calls     int
}

// New builds a fake adapter.
func New(clk clock.Clock) *Adapter {
	return &Adapter{clk: clk, firstSeen: map[string]time.Time{}, state: map[string]billing.MarketState{}, noRenew: map[string]bool{}}
}

// Override forces the market state returned for token from now on.
func (a *Adapter) Override(token string, st billing.MarketState) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.state[token] = st
}

// DisableAutoRenew makes the subscription report auto_renewing=false.
func (a *Adapter) DisableAutoRenew(token string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.noRenew[token] = true
}

// Verify implements billing.MarketVerifier.
func (a *Adapter) Verify(ctx context.Context, sku, token string) (billing.MarketPurchase, error) {
	a.mu.Lock()
	a.Calls++
	override, hasOverride := a.state[token]
	noRenew := a.noRenew[token]
	first, seen := a.firstSeen[token]
	if !seen {
		first = a.clk.Now()
		a.firstSeen[token] = first
	}
	a.mu.Unlock()

	var st billing.MarketState
	switch {
	case strings.HasPrefix(token, "test_slow_"):
		<-ctx.Done()
		return billing.MarketPurchase{}, fmt.Errorf("fake slow: %w", ctx.Err())
	case strings.HasPrefix(token, "test_timeout_"):
		return billing.MarketPurchase{}, fmt.Errorf("fake: %w", billing.ErrMarketUnavailable)
	case strings.HasPrefix(token, "test_valid_"):
		st = billing.MarketValid
	case strings.HasPrefix(token, "test_refunded_"):
		st = billing.MarketRefunded
	default:
		st = billing.MarketInvalid
	}
	if hasOverride {
		st = override
	}
	days := 30
	if rest, ok := strings.CutPrefix(token, "test_valid_"); ok {
		if n, _, ok := strings.Cut(rest, "d_"); ok {
			if v, err := strconv.Atoi(n); err == nil && v > 0 {
				days = v
			}
		}
	}
	raw, _ := json.Marshal(map[string]string{"fake": "1", "sku": sku})
	return billing.MarketPurchase{
		State: st, OrderID: "fake-order-" + token[:min(len(token), 24)], PurchasedAt: first,
		ExpiresAt: first.Add(time.Duration(days) * 24 * time.Hour), AutoRenewing: !noRenew, Raw: raw,
	}, nil
}
