package app

import (
	"fmt"
	"log/slog"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing/bazaar"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing/fake"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing/myket"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/config"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
)

// devEncKey is used only outside prod when DATA_ENC_KEY is unset (config requires it in prod).
var devEncKey = []byte("dev-only-purchase-token-key-0001")

// NewBilling builds the billing service with the market registry selected by config flags.
func NewBilling(cfg config.Config, pool *db.Pool, clk clock.Clock, m *metrics.Metrics,
	ent *entitlement.Service, sink billing.ServerEventSink) (*billing.Service, error) {
	reg := billing.Registry{}
	if cfg.BillingBazaarEnabled {
		reg["bazaar"] = bazaar.New(bazaar.Config{PackageName: cfg.BazaarPackageName, ClientID: cfg.BazaarClientID,
			ClientSecret: cfg.BazaarClientSecret, RefreshToken: cfg.BazaarRefreshToken}, nil, clk)
	}
	if cfg.BillingMyketEnabled {
		reg["myket"] = myket.New(myket.Config{PackageName: cfg.MyketPackageName, AccessToken: cfg.MyketAccessToken})
	}
	if cfg.BillingFakeEnabled && !cfg.IsProd() {
		f := fake.New(clk)
		for _, mk := range []string{"bazaar", "myket"} {
			if _, taken := reg[mk]; !taken {
				reg[mk] = f
			}
		}
		slog.Warn("fake billing adapter enabled (non-prod only)")
	}
	key := cfg.DataEncKey
	if key == nil {
		if cfg.IsProd() {
			return nil, fmt.Errorf("DATA_ENC_KEY is required")
		}
		key = devEncKey
	}
	opts := billing.Options{Pool: pool, Entitle: ent, Registry: reg, Clock: clk, EncKey: key, Sink: sink}
	if m != nil {
		opts.Observe = func(market, result string) { m.MarketVerify.WithLabelValues(market, result).Inc() }
	}
	return billing.NewService(opts)
}
