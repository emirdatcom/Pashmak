// Package kavenegar sends OTP codes through Kavenegar's verify/lookup API.
//
// [نیاز به راستی‌آزمایی] V6: the endpoint shape below is written from memory of the public Kavenegar
// docs (GET {base}/v1/{apikey}/verify/lookup.json?receptor=&token=&template=) and could not be
// checked from the build environment. A pre-approved template (پترن) and a service line are
// required by the provider. Validate against a real test SMS before enabling in prod.
package kavenegar

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultBaseURL is the (unverified) API host.
const DefaultBaseURL = "https://api.kavenegar.com"

// Config configures the adapter (env KAVENEGAR_API_KEY, KAVENEGAR_TEMPLATE).
type Config struct {
	BaseURL  string
	APIKey   string
	Template string
}

// Adapter implements auth.SMSSender.
type Adapter struct {
	cfg  Config
	http *http.Client
}

// New builds the adapter; client may be nil.
func New(cfg Config, client *http.Client) *Adapter {
	if cfg.BaseURL == "" {
		cfg.BaseURL = DefaultBaseURL
	}
	if client == nil {
		client = &http.Client{Timeout: 8 * time.Second}
	}
	return &Adapter{cfg: cfg, http: client}
}

// SendOTP implements auth.SMSSender. phone is E.164 ("+98912…"); Kavenegar wants "0912…".
func (a *Adapter) SendOTP(ctx context.Context, phone, code string) error {
	receptor := "0" + strings.TrimPrefix(phone, "+98")
	q := url.Values{"receptor": {receptor}, "token": {code}, "template": {a.cfg.Template}}
	u := fmt.Sprintf("%s/v1/%s/verify/lookup.json?%s", a.cfg.BaseURL, url.PathEscape(a.cfg.APIKey), q.Encode())
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return fmt.Errorf("kavenegar request: %w", err)
	}
	resp, err := a.http.Do(req) // #nosec G107 -- base URL is operator config
	if err != nil {
		return fmt.Errorf("kavenegar request failed") // never include the URL: it holds the API key and code
	}
	defer func() { _ = resp.Body.Close() }()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	var r struct {
		Return struct {
			Status int `json:"status"`
		} `json:"return"`
	}
	if resp.StatusCode != http.StatusOK || json.Unmarshal(body, &r) != nil || r.Return.Status != 200 {
		return fmt.Errorf("kavenegar rejected the request (http %d, status %d)", resp.StatusCode, r.Return.Status)
	}
	return nil
}
