// Package smsir sends OTP codes and operational alerts through sms.ir (decision D-4).
//
// [نیاز به راستی‌آزمایی] V6 (محدود به sms.ir): the contract below follows the public sms.ir REST API as
// documented (https://api.sms.ir, header `x-api-key`):
//
//	POST /v1/send/verify  {"mobile":"0912…","templateId":N,"parameters":[{"name":"CODE","value":"12345"}]}
//	POST /v1/send/bulk    {"lineNumber":N,"messageText":"…","mobiles":["0912…"],"sendDateTime":null}
//	response              {"status":1,"message":"…","data":{…}}   (status 1 = accepted)
//
// It could not be checked against the live service from the build environment; golden responses in
// testdata/ document the assumed shape. Validate with a real test SMS (approved template + service line)
// before enabling in prod.
package smsir

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// DefaultBaseURL is the sms.ir API host.
const DefaultBaseURL = "https://api.sms.ir"

// ErrUnavailable wraps every provider/network failure; callers map it to SMS_UNAVAILABLE.
var ErrUnavailable = errors.New("sms.ir unavailable")

// Config configures the adapter (env SMSIR_API_KEY, SMSIR_OTP_TEMPLATE_ID, SMSIR_OTP_PARAM_NAME, SMSIR_LINE_NUMBER).
type Config struct {
	BaseURL    string
	APIKey     string
	TemplateID string
	ParamName  string // default CODE
	LineNumber string // service line for alerts (SendAlert)
}

// Adapter implements auth.SMSSender and the alert sender.
type Adapter struct {
	cfg  Config
	http *http.Client
}

// New builds the adapter; client may be nil (8 s timeout).
func New(cfg Config, client *http.Client) *Adapter {
	if cfg.BaseURL == "" {
		cfg.BaseURL = DefaultBaseURL
	}
	if cfg.ParamName == "" {
		cfg.ParamName = "CODE"
	}
	if client == nil {
		client = &http.Client{Timeout: 8 * time.Second}
	}
	return &Adapter{cfg: cfg, http: client}
}

// local converts E.164 "+98912…" to the "0912…" form sms.ir expects.
func local(phone string) string {
	p := strings.TrimPrefix(strings.TrimSpace(phone), "+98")
	if !strings.HasPrefix(p, "0") {
		p = "0" + p
	}
	return p
}

// SendOTP implements auth.SMSSender. Neither the code nor the number is ever logged or put in an error.
func (a *Adapter) SendOTP(ctx context.Context, phone, code string) error {
	tid, err := strconv.Atoi(a.cfg.TemplateID)
	if err != nil {
		return fmt.Errorf("%w: invalid template id", ErrUnavailable)
	}
	body := map[string]any{
		"mobile":     local(phone),
		"templateId": tid,
		"parameters": []map[string]string{{"name": a.cfg.ParamName, "value": code}},
	}
	return a.post(ctx, "/v1/send/verify", body)
}

// SendAlert sends [text] to every phone (operational alerts, D-5). Needs SMSIR_LINE_NUMBER.
func (a *Adapter) SendAlert(ctx context.Context, phones []string, text string) error {
	if len(phones) == 0 {
		return nil
	}
	line, err := strconv.ParseInt(a.cfg.LineNumber, 10, 64)
	if err != nil {
		return fmt.Errorf("%w: SMSIR_LINE_NUMBER is not set", ErrUnavailable)
	}
	mobiles := make([]string, len(phones))
	for i, p := range phones {
		mobiles[i] = local(p)
	}
	return a.post(ctx, "/v1/send/bulk", map[string]any{"lineNumber": line, "messageText": text, "mobiles": mobiles, "sendDateTime": nil})
}

func (a *Adapter) post(ctx context.Context, path string, payload any) error {
	raw, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("%w: encode", ErrUnavailable)
	}
	// One retry, only for transport errors (never for provider answers: a 4xx would just repeat).
	var resp *http.Response
	for attempt := 0; attempt < 2; attempt++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, a.cfg.BaseURL+path, bytes.NewReader(raw))
		if err != nil {
			return fmt.Errorf("%w: request", ErrUnavailable)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "application/json")
		req.Header.Set("x-api-key", a.cfg.APIKey)
		resp, err = a.http.Do(req) // #nosec G107 -- base URL is operator config
		if err == nil {
			break
		}
		if attempt == 1 || ctx.Err() != nil {
			return fmt.Errorf("%w: network", ErrUnavailable) // never include the URL/body: they hold the key and code
		}
	}
	defer func() { _ = resp.Body.Close() }()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	var r struct {
		Status int `json:"status"`
	}
	if resp.StatusCode != http.StatusOK || json.Unmarshal(body, &r) != nil || r.Status != 1 {
		return fmt.Errorf("%w: http %d, status %d", ErrUnavailable, resp.StatusCode, r.Status)
	}
	return nil
}
