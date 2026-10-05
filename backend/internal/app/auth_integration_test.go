package app_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/getkin/kin-openapi/routers/gorillamux"
	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/app"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth"
	"github.com/emirdatcom/pashmak/backend/internal/modules/user"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
	"github.com/emirdatcom/pashmak/backend/internal/testutil"
)

type env struct {
	h   http.Handler
	clk *clock.Fake
	t   *testing.T
	doc *openapi3.T
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
	u := user.NewService(user.NewPGStore(pool), a, clk)
	_, h := app.Handler(app.Deps{DB: pool, Metrics: metrics.New(), Clock: clk, Auth: a, User: u})
	doc, err := openapi3.NewLoader().LoadFromFile("../../api/openapi.yaml")
	if err != nil {
		t.Fatal(err)
	}
	if err := doc.Validate(context.Background()); err != nil {
		t.Fatalf("openapi invalid: %v", err)
	}
	return &env{h: h, clk: clk, t: t, doc: doc}
}

// call performs a request, validates the response against openapi.yaml and returns status + body.
func (e *env) call(method, path, token string, body any, ip string) (int, map[string]any) {
	e.t.Helper()
	var rdr *bytes.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	} else {
		rdr = bytes.NewReader(nil)
	}
	req := httptest.NewRequest(method, path, rdr)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if ip != "" {
		req.RemoteAddr = ip + ":1234"
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)

	router, err := gorillamux.NewRouter(e.doc)
	if err != nil {
		e.t.Fatal(err)
	}
	vreq := httptest.NewRequest(method, "http://example.com"+path, bytes.NewReader(nil))
	route, params, err := router.FindRoute(vreq)
	if err == nil {
		in := &openapi3filter.ResponseValidationInput{
			RequestValidationInput: &openapi3filter.RequestValidationInput{Request: vreq, PathParams: params, Route: route,
				Options: &openapi3filter.Options{AuthenticationFunc: openapi3filter.NoopAuthenticationFunc}},
			Status: rec.Code, Header: rec.Header(), Options: &openapi3filter.Options{IncludeResponseStatus: true},
		}
		in.SetBodyBytes(rec.Body.Bytes())
		if verr := openapi3filter.ValidateResponse(context.Background(), in); verr != nil {
			e.t.Errorf("%s %s -> %d violates openapi: %v\nbody=%s", method, path, rec.Code, verr, rec.Body)
		}
	}
	var out map[string]any
	_ = json.Unmarshal(rec.Body.Bytes(), &out)
	return rec.Code, out
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
