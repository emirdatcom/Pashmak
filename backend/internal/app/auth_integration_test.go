package app_test

import (
	"bytes"
	"compress/gzip"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"
	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/app"
	"golang.org/x/crypto/bcrypt"

	"github.com/emirdatcom/pashmak/backend/internal/modules/admin"
	"github.com/emirdatcom/pashmak/backend/internal/modules/analytics"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth"
	"github.com/emirdatcom/pashmak/backend/internal/modules/backup"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing/fake"
	"github.com/emirdatcom/pashmak/backend/internal/modules/content"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/modules/remoteconfig"
	"github.com/emirdatcom/pashmak/backend/internal/modules/user"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
	"github.com/emirdatcom/pashmak/backend/internal/testutil"
)

type env struct {
	h    http.Handler
	clk  *clock.Fake
	t    *testing.T
	doc  *openapi3.T
	pool *db.Pool
	ent  *entitlement.Service
	bill *billing.Service
	fake *fake.Adapter
	sink *recordingSink
	an   *analytics.Service
	sms  *recordingSMS
}

// recordingSMS captures OTP codes instead of sending them.
type recordingSMS struct {
	mu    sync.Mutex
	last  map[string]string // e164 -> code
	count int
	fail  bool
}

func (r *recordingSMS) SendOTP(_ context.Context, phone, code string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.fail {
		return fmt.Errorf("provider down")
	}
	if r.last == nil {
		r.last = map[string]string{}
	}
	r.last[phone] = code
	r.count++
	return nil
}

func (r *recordingSMS) code(phone string) string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.last[phone]
}

const (
	configDataDir = "../../../config-data"
	adminPass     = "s3cret-pass"
	adminIP       = "10.200.1.1"
)

type recordingSink struct {
	mu     sync.Mutex
	events []string
}

func (r *recordingSink) Emit(_ context.Context, name string, _ uuid.UUID, _ map[string]any) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, name)
	return nil
}

func productsJSON(t *testing.T) []byte {
	t.Helper()
	b, err := os.ReadFile("../../../config-data/products.json")
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func newEnv(t *testing.T) *env {
	t.Helper()
	pool := testutil.NewDB(t)
	dir := t.TempDir()
	if err := signer.Generate(dir, "at-1"); err != nil {
		t.Fatal(err)
	}
	sg, err := signer.LoadWithPrefix(dir, "at-")
	if err != nil {
		t.Fatal(err)
	}
	clk := clock.NewFake(time.Now().UTC().Truncate(time.Second))
	a := auth.NewService(auth.NewPGStore(pool), sg, clk, "salt")
	if err := signer.Generate(dir, "ent-1"); err != nil {
		t.Fatal(err)
	}
	entSigner, err := signer.LoadWithPrefix(dir, "ent-")
	if err != nil {
		t.Fatal(err)
	}
	ent := entitlement.NewService(pool, entSigner, clk, nil)
	u := user.NewService(user.NewPGStore(pool), a, clk, ent)
	if _, err := billing.SeedProducts(context.Background(), pool, productsJSON(t)); err != nil {
		t.Fatal(err)
	}
	f := fake.New(clk)
	sink := &recordingSink{}
	bs, err := billing.NewService(billing.Options{Pool: pool, Entitle: ent, Registry: billing.Registry{"bazaar": f, "myket": f},
		Clock: clk, EncKey: bytes.Repeat([]byte{7}, 32), Sink: sink, Backoff: []time.Duration{0, 0},
		Sleep: func(context.Context, time.Duration) {}, MarketCall: 200 * time.Millisecond})
	if err != nil {
		t.Fatal(err)
	}
	sch, err := schemas.Load(configDataDir)
	if err != nil {
		t.Fatal(err)
	}
	cat, err := schemas.LoadCatalog(configDataDir)
	if err != nil {
		t.Fatal(err)
	}
	an := analytics.NewService(pool, cat, clk)
	rc := remoteconfig.NewService(pool, sch, clk)
	ct := content.NewService(pool, sch, clk)
	hash, _ := bcrypt.GenerateFromPassword([]byte(adminPass), bcrypt.MinCost)
	adm, err := admin.New(admin.Options{Pool: pool, Config: rc, Content: ct, Grants: ent, Clock: clk,
		User: "admin", PasswordHash: string(hash), Allowlist: []string{"10.200.0.0/16"}})
	if err != nil {
		t.Fatal(err)
	}
	box, err := crypt.New(bytes.Repeat([]byte{9}, 32))
	if err != nil {
		t.Fatal(err)
	}
	sms := &recordingSMS{}
	ph := auth.NewPhoneService(pool, a, box, sms, clk, bs)
	bk := backup.NewService(pool, clk, nil)
	u.AddHook(bk)
	_, h := app.Handler(app.Deps{DB: pool, Metrics: metrics.New(), Clock: clk, Auth: a, User: u, Entitle: ent, Billing: bs,
		RemoteConfig: rc, Content: ct, Analytics: an, Admin: adm, Phone: ph, Backup: bk})
	doc, err := openapi3.NewLoader().LoadFromFile("../../api/openapi.yaml")
	if err != nil {
		t.Fatal(err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		t.Fatalf("openapi invalid: %v", err)
	}
	u.AddHook(an)
	return &env{h: h, clk: clk, t: t, doc: doc, pool: pool, ent: ent, bill: bs, fake: f, sink: sink, an: an, sms: sms}
}

// call performs a request, validates the response against openapi.yaml and returns status + body.
func (e *env) call(method, path, token string, body any, ip string) (int, map[string]any) {
	st, _, m := e.callH(method, path, token, body, ip, nil)
	return st, m
}

// callH is call with extra request headers; it also returns the response headers.
func (e *env) callH(method, path, token string, body any, ip string, hdr map[string]string) (int, http.Header, map[string]any) {
	e.t.Helper()
	var rdr *bytes.Reader
	if raw, isRaw := body.([]byte); isRaw {
		rdr = bytes.NewReader(raw)
	} else if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	} else {
		rdr = bytes.NewReader(nil)
	}
	req := httptest.NewRequest(method, path, rdr)
	req.Header.Set("Content-Type", "application/json")
	if _, isRaw := body.([]byte); isRaw {
		req.Header.Set("Content-Type", "application/octet-stream")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if ip != "" {
		req.RemoteAddr = ip + ":1234"
	}
	for k, v := range hdr {
		if k == "Authorization" {
			req.Header.Set(k, v)
			continue
		}
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)

	router, err := gorillamux.NewRouter(e.doc)
	if err != nil {
		e.t.Fatal(err)
	}
	vreq := httptest.NewRequest(method, "http://example.com"+path, bytes.NewReader(nil))
	route, params, err := router.FindRoute(vreq)
	if err != nil {
		e.t.Errorf("%s %s is not described in openapi.yaml: %v", method, path, err)
	} else {
		in := &openapi3filter.ResponseValidationInput{
			RequestValidationInput: &openapi3filter.RequestValidationInput{Request: vreq, PathParams: params, Route: route,
				Options: &openapi3filter.Options{AuthenticationFunc: openapi3filter.NoopAuthenticationFunc}},
			Status: rec.Code, Header: rec.Header(), Options: &openapi3filter.Options{IncludeResponseStatus: true},
		}
		vb := rec.Body.Bytes()
		if rec.Header().Get("Content-Encoding") == "gzip" {
			if zr, err := gzip.NewReader(bytes.NewReader(vb)); err == nil {
				vb, _ = io.ReadAll(zr)
			}
		}
		in.SetBodyBytes(vb)
		if verr := openapi3filter.ValidateResponse(context.Background(), in); verr != nil {
			e.t.Errorf("%s %s -> %d violates openapi: %v\nbody=%s", method, path, rec.Code, verr, rec.Body)
		}
	}
	var out map[string]any
	rb := rec.Body.Bytes()
	if rec.Header().Get("Content-Encoding") == "gzip" {
		if zr, err := gzip.NewReader(bytes.NewReader(rb)); err == nil {
			rb, _ = io.ReadAll(zr)
		}
	}
	_ = json.Unmarshal(rb, &out)
	return rec.Code, rec.Header(), out
}

func deviceBody(install string) map[string]any {
	return map[string]any{"install_id": install, "device_hash_raw": "android-id", "market": "myket",
		"app_version": "1.0.0", "os_version": "13", "model": "Pixel"}
}

func errCode(m map[string]any) string {
	if e, ok := m["error"].(map[string]any); ok {
		s, _ := e["code"].(string)
		return s
	}
	return ""
}

func TestAuthFlow(t *testing.T) {
	e := newEnv(t)
	install := uuid.NewString()
	st, a := e.call("POST", "/v1/auth/device", "", deviceBody(install), "10.0.0.1")
	if st != 200 {
		t.Fatalf("device: %d %v", st, a)
	}
	_, b := e.call("POST", "/v1/auth/device", "", deviceBody(install), "10.0.0.1")
	if a["user_id"] != b["user_id"] {
		t.Fatal("same install_id must map to the same user")
	}
	_, c := e.call("POST", "/v1/auth/device", "", deviceBody(uuid.NewString()), "10.0.0.1")
	if c["user_id"] == a["user_id"] {
		t.Fatal("new install_id must be a new user")
	}

	// /me
	token := b["access_token"].(string)
	if st, me := e.call("GET", "/v1/me", token, nil, ""); st != 200 || me["user_id"] != b["user_id"] || me["phone_linked"] != false {
		t.Fatalf("me: %d %v", st, me)
	}
	if st, m := e.call("GET", "/v1/me", "", nil, ""); st != 401 || errCode(m) != "UNAUTHENTICATED" {
		t.Fatalf("no token: %d %v", st, m)
	}

	// Refresh rotation + reuse.
	old := b["refresh_token"].(string)
	st, r1 := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": old}, "")
	if st != 200 {
		t.Fatalf("refresh: %d %v", st, r1)
	}
	if st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": old}, ""); st != 401 || errCode(m) != "TOKEN_REUSED" {
		t.Fatalf("reuse: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": r1["refresh_token"]}, ""); st != 401 || errCode(m) != "TOKEN_REUSED" {
		t.Fatalf("family revoked: %d %v", st, m)
	}

	// Expiry.
	e.clk.Advance(61 * time.Minute)
	if st, _ := e.call("GET", "/v1/me", token, nil, ""); st != 401 {
		t.Fatalf("expired access: %d", st)
	}
}

func TestDeleteAccount(t *testing.T) {
	e := newEnv(t)
	install := uuid.NewString()
	_, s := e.call("POST", "/v1/auth/device", "", deviceBody(install), "10.0.0.2")
	token, refresh := s["access_token"].(string), s["refresh_token"].(string)
	if st, _ := e.call("DELETE", "/v1/me", token, nil, ""); st != 204 {
		t.Fatalf("delete: %d", st)
	}
	if st, _ := e.call("GET", "/v1/me", token, nil, ""); st != 401 {
		t.Fatalf("after delete: %d", st)
	}
	if st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": refresh}, ""); st != 401 || errCode(m) != "TOKEN_INVALID" {
		t.Fatalf("refresh after delete: %d %v", st, m)
	}
	// Reinstall with same install_id → fresh user.
	_, n := e.call("POST", "/v1/auth/device", "", deviceBody(install), "10.0.0.2")
	if n["user_id"] == s["user_id"] {
		t.Fatal("deleted user must not be resurrected")
	}
}

func TestDeviceRateLimitAndValidation(t *testing.T) {
	e := newEnv(t)
	for i := 0; i < 10; i++ {
		if st, m := e.call("POST", "/v1/auth/device", "", deviceBody(uuid.NewString()), "10.9.9.9"); st != 200 {
			t.Fatalf("req %d: %d %v", i, st, m)
		}
	}
	if st, m := e.call("POST", "/v1/auth/device", "", deviceBody(uuid.NewString()), "10.9.9.9"); st != 429 || errCode(m) != "RATE_LIMITED" {
		t.Fatalf("11th: %d %v", st, m)
	}
	bad := deviceBody("not-a-uuid")
	if st, m := e.call("POST", "/v1/auth/device", "", bad, "10.8.8.8"); st != 400 || errCode(m) != "INVALID_INPUT" {
		t.Fatalf("bad input: %d %v", st, m)
	}
	// Unknown field rejected.
	extra := deviceBody(uuid.NewString())
	extra["x"] = 1
	if st, _ := e.call("POST", "/v1/auth/device", "", extra, "10.8.8.8"); st != 400 {
		t.Fatalf("unknown field: %d", st)
	}
}

func TestDeviceHashStoredNotRaw(t *testing.T) {
	pool := testutil.NewDB(t)
	dir := t.TempDir()
	_ = signer.Generate(dir, "at-1")
	sg, _ := signer.LoadWithPrefix(dir, "at-")
	clk := clock.Real{}
	a := auth.NewService(auth.NewPGStore(pool), sg, clk, "salt")
	in := auth.DeviceInput{InstallID: uuid.NewString(), DeviceHashRaw: "RAW-ANDROID-ID", Market: "bazaar", AppVersion: "1", OSVersion: "1", Model: "m"}
	if _, err := a.RegisterDevice(context.Background(), in); err != nil {
		t.Fatal(err)
	}
	in.InstallID = uuid.NewString()
	if _, err := a.RegisterDevice(context.Background(), in); err != nil {
		t.Fatal(err)
	}
	var n, raw int
	_ = pool.QueryRow(context.Background(), `select count(distinct device_hash), count(*) filter (where device_hash like '%RAW%') from devices`).Scan(&n, &raw)
	if n != 1 || raw != 0 {
		t.Fatalf("distinct hashes=%d raw=%d", n, raw)
	}
}
