// Package myket is the Myket market adapter.
//
// [نیاز به راستی‌آزمایی] V3: the Myket server-to-server purchase verification API could not be
// checked from the build environment, so this adapter only fixes the interface. Verify always
// reports ErrMarketUnavailable ("not implemented") and the adapter is registered only when
// BILLING_MYKET_ENABLED=true. TODO: implement against the official Myket docs, add golden tests
// like bazaar/adapter_test.go, then flip the flag in staging.
package myket

import (
	"context"
	"fmt"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
)

// Config holds credentials (env MYKET_*).
type Config struct {
	PackageName string
	AccessToken string
}

// Adapter implements billing.MarketVerifier.
type Adapter struct{ cfg Config }

// New builds the adapter.
func New(cfg Config) *Adapter { return &Adapter{cfg: cfg} }

// Verify implements billing.MarketVerifier.
func (a *Adapter) Verify(context.Context, string, string) (billing.MarketPurchase, error) {
	return billing.MarketPurchase{}, fmt.Errorf("myket verification not implemented: %w", billing.ErrMarketUnavailable)
}
