// Package bazaar verifies purchases against the Cafe Bazaar developer API.
//
// [نیاز به راستی‌آزمایی] V1/V2: the endpoints, field names and OAuth flow below follow the
// publicly documented Bazaar "Pardakht" developer API as remembered when this adapter was written;
// the official docs could not be reached from the build environment. The adapter is disabled unless
// BILLING_BAZAAR_ENABLED=true and must be validated against a real test purchase before enabling.
package bazaar

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
)

// DefaultBaseURL is the (unverified) API host.
const DefaultBaseURL = "https://pardakht.cafebazaar.ir"

// Config holds credentials (env BAZAAR_*).
type Config struct {
	BaseURL      string
	PackageName  string
	ClientID     string
	ClientSecret string
	RefreshToken string
	// SubscriptionSKUs lists SKUs to be validated as subscriptions rather than in-app items.
	SubscriptionSKUs map[string]bool
}

// Adapter implements billing.MarketVerifier.
type Adapter struct {
	cfg  Config
	http *http.Client
	clk  clock.Clock

	mu      sync.Mutex
	access  string
	expires time.Time
}

// New builds an adapter; client may be nil.
func New(cfg Config, client *http.Client, clk clock.Clock) *Adapter {
	if cfg.BaseURL == "" {
		cfg.BaseURL = DefaultBaseURL
	}
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	return &Adapter{cfg: cfg, http: client, clk: clk}
}

func (a *Adapter) accessToken(ctx context.Context) (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.access != "" && a.clk.Now().Before(a.expires.Add(-time.Minute)) {
		return a.access, nil
	}
	form := url.Values{"grant_type": {"refresh_token"}, "client_id": {a.cfg.ClientID},
		"client_secret": {a.cfg.ClientSecret}, "refresh_token": {a.cfg.RefreshToken}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.cfg.BaseURL+"/devapi/v2/auth/token/", strings.NewReader(form.Encode()))
	if err != nil {
		return "", fmt.Errorf("bazaar token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	body, status, err := a.do(req)
	if err != nil || status != http.StatusOK {
		return "", fmt.Errorf("bazaar token: status %d: %w", status, billing.ErrMarketUnavailable)
	}
	var tr struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tr); err != nil || tr.AccessToken == "" {
		return "", fmt.Errorf("bazaar token decode: %w", billing.ErrMarketUnavailable)
	}
	a.access, a.expires = tr.AccessToken, a.clk.Now().Add(time.Duration(tr.ExpiresIn)*time.Second)
	return a.access, nil
}

func (a *Adapter) do(req *http.Request) ([]byte, int, error) {
	resp, err := a.http.Do(req)
	if err != nil {
		return nil, 0, fmt.Errorf("%w: %v", billing.ErrMarketUnavailable, err) // #nosec -- message only
	}
	defer func() { _ = resp.Body.Close() }()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, resp.StatusCode, fmt.Errorf("%w: read body", billing.ErrMarketUnavailable)
	}
	return b, resp.StatusCode, nil
}

// Verify implements billing.MarketVerifier.
func (a *Adapter) Verify(ctx context.Context, sku, token string) (billing.MarketPurchase, error) {
	at, err := a.accessToken(ctx)
	if err != nil {
		return billing.MarketPurchase{}, err
	}
	sub := a.cfg.SubscriptionSKUs[sku]
	var path string
	if sub {
		path = fmt.Sprintf("/devapi/v2/api/applications/%s/subscriptions/%s/purchases/%s/", a.cfg.PackageName, url.PathEscape(sku), url.PathEscape(token))
	} else {
		path = fmt.Sprintf("/devapi/v2/api/validate/%s/inapp/%s/purchases/%s/", a.cfg.PackageName, url.PathEscape(sku), url.PathEscape(token))
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.cfg.BaseURL+path+"?access_token="+url.QueryEscape(at), nil)
	if err != nil {
		return billing.MarketPurchase{}, fmt.Errorf("bazaar request: %w", err)
	}
	body, status, err := a.do(req)
	if err != nil {
		return billing.MarketPurchase{}, err
	}
	return ParseResponse(status, body, sub)
}

// ParseResponse maps a Bazaar HTTP response to a MarketPurchase (exported for golden tests).
func ParseResponse(status int, body []byte, subscription bool) (billing.MarketPurchase, error) {
	switch {
	case status == http.StatusNotFound || status == http.StatusBadRequest || status == http.StatusForbidden:
		return billing.MarketPurchase{State: billing.MarketInvalid}, nil
	case status >= 500 || status == http.StatusTooManyRequests || status == http.StatusUnauthorized:
		return billing.MarketPurchase{}, fmt.Errorf("bazaar status %d: %w", status, billing.ErrMarketUnavailable)
	case status != http.StatusOK:
		return billing.MarketPurchase{}, fmt.Errorf("bazaar unexpected status %d: %w", status, billing.ErrMarketUnavailable)
	}
	var r struct {
		PurchaseState       *int   `json:"purchaseState"`
		PurchaseTime        int64  `json:"purchaseTime"`
		OrderID             string `json:"orderId"`
		AutoRenewing        bool   `json:"autoRenewing"`
		InitiationTimestamp int64  `json:"initiationTimestampMsec"`
		ValidUntilTimestamp int64  `json:"validUntilTimestampMsec"`
		DeveloperPayload    string `json:"developerPayload"`
		ConsumptionState    int    `json:"consumptionState"`
		Kind                string `json:"kind"`
	}
	if err := json.Unmarshal(body, &r); err != nil {
		return billing.MarketPurchase{}, errors.Join(billing.ErrMarketUnavailable, fmt.Errorf("bazaar decode: %w", err))
	}
	mp := billing.MarketPurchase{State: billing.MarketValid, OrderID: r.OrderID, AutoRenewing: r.AutoRenewing}
	if subscription {
		mp.PurchasedAt = time.UnixMilli(r.InitiationTimestamp).UTC()
		mp.ExpiresAt = time.UnixMilli(r.ValidUntilTimestamp).UTC()
	} else {
		mp.PurchasedAt = time.UnixMilli(r.PurchaseTime).UTC()
		if r.PurchaseState != nil && *r.PurchaseState != 0 {
			mp.State = billing.MarketRefunded // 1 = canceled/refunded
		}
	}
	mp.Raw, _ = json.Marshal(map[string]any{"purchaseState": r.PurchaseState, "consumptionState": r.ConsumptionState, "kind": r.Kind})
	return mp, nil
}
