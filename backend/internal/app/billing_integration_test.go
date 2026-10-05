package app_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

type tuser struct {
	token   string
	id      string
	refresh string
}

// relogin rotates the refresh token (needed after advancing the fake clock past the 1h access TTL).
func (e *env) relogin(u *tuser) {
	e.t.Helper()
	st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": u.refresh}, "")
	if st != 200 {
		e.t.Fatalf("relogin: %d %v", st, m)
	}
	u.token, u.refresh = m["access_token"].(string), m["refresh_token"].(string)
}

// newUser registers a fresh install on the hardware identified by raw.
func (e *env) newUser(raw string) tuser {
	e.t.Helper()
	b := deviceBody(uuid.NewString())
	b["device_hash_raw"] = raw
	st, m := e.call("POST", "/v1/auth/device", "", b, "10.1."+uuid.NewString()[:3]+".1")
	if st != 200 {
		e.t.Fatalf("register: %d %v", st, m)
	}
	return tuser{token: m["access_token"].(string), id: m["user_id"].(string), refresh: m["refresh_token"].(string)}
}

func (e *env) state(u tuser) (entitlement.State, map[string]any) {
	e.t.Helper()
	st, m := e.call("GET", "/v1/entitlements", u.token, nil, "")
	if st != 200 {
		e.t.Fatalf("entitlements: %d %v", st, m)
	}
	return e.parseState(m), m
}

func (e *env) parseState(m map[string]any) entitlement.State {
	e.t.Helper()
	b, _ := json.Marshal(m)
	var s entitlement.State
	if err := json.Unmarshal(b, &s); err != nil {
		e.t.Fatal(err)
	}
	if err := e.ent.VerifyState(s); err != nil {
		e.t.Fatalf("signature does not verify: %v", err)
	}
	return s
}

func parse(t *testing.T, s string) time.Time {
	t.Helper()
	v, err := time.Parse(time.RFC3339, s)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

func (e *env) verify(u tuser, product, token string) (int, map[string]any) {
	return e.call("POST", "/v1/purchases/verify", u.token, map[string]any{
		"market": "bazaar", "product_id": product, "market_sku": product, "purchase_token": token, "order_id": "o1"}, "")
}

func premiumEnd(t *testing.T, s entitlement.State) time.Time {
	t.Helper()
	var end time.Time
	for _, en := range s.Entitlements {
		if v := parse(t, en.EndsAt); v.After(end) {
			end = v
		}
	}
	return end
}

func TestTrial(t *testing.T) {
	e := newEnv(t)
	a := e.newUser("hw-1")
	s0, _ := e.state(a)
	if !s0.Trial.Eligible || s0.Trial.Used || len(s0.Entitlements) != 0 {
		t.Fatalf("fresh state: %+v", s0)
	}
	st, m := e.call("POST", "/v1/trial/start", a.token, nil, "")
	if st != 200 {
		t.Fatalf("start: %d %v", st, m)
	}
	s1 := e.parseState(m)
	if len(s1.Entitlements) != 1 || s1.Entitlements[0].Source != "trial" || s1.Trial.Eligible || !s1.Trial.Used {
		t.Fatalf("after start: %+v", s1)
	}
	now := e.clk.Now()
	if d := parse(t, s1.Entitlements[0].EndsAt).Sub(now); d < 7*24*time.Hour-time.Minute || d > 7*24*time.Hour+time.Minute {
		t.Fatalf("trial length %v", d)
	}
	// Idempotent for the same user (outbox retry).
	if st, _ := e.call("POST", "/v1/trial/start", a.token, nil, ""); st != 200 {
		t.Fatalf("retry: %d", st)
	}
	// New user on the same hardware: one trial per device.
	b := e.newUser("hw-1")
	if st, m := e.call("POST", "/v1/trial/start", b.token, nil, ""); st != 409 || errCode(m) != "TRIAL_ALREADY_USED" {
		t.Fatalf("same device: %d %v", st, m)
	}
	if sb, _ := e.state(b); sb.Trial.Eligible || !sb.Trial.Used {
		t.Fatalf("b should not be eligible: %+v", sb)
	}
	// Different hardware is fine.
	c := e.newUser("hw-2")
	if st, _ := e.call("POST", "/v1/trial/start", c.token, nil, ""); st != 200 {
		t.Fatalf("other device: %d", st)
	}
}

func TestTrialProvisional(t *testing.T) {
	e := newEnv(t)
	now := e.clk.Now()
	a, b := e.newUser("hw-a"), e.newUser("hw-b")
	prov := now.Add(-24 * time.Hour)
	_, m := e.call("POST", "/v1/trial/start", a.token, map[string]any{"provisional_started_at": prov.Format(time.RFC3339)}, "")
	if end := premiumEnd(t, e.parseState(m)); !end.Equal(prov.Add(7 * 24 * time.Hour)) {
		t.Fatalf("24h-old provisional: ends %v want %v", end, prov.Add(7*24*time.Hour))
	}
	old := now.Add(-72 * time.Hour)
	_, m = e.call("POST", "/v1/trial/start", b.token, map[string]any{"provisional_started_at": old.Format(time.RFC3339)}, "")
	if end := premiumEnd(t, e.parseState(m)); !end.Equal(now.Add(7 * 24 * time.Hour)) {
		t.Fatalf("72h-old provisional must be ignored: ends %v", end)
	}
	if st, _ := e.call("POST", "/v1/trial/start", b.token, map[string]any{"provisional_started_at": "yesterday"}, ""); st != 400 {
		t.Fatalf("bad time: %d", st)
	}
}

func TestPassPurchaseAccumulatesAndIdempotent(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-p")
	now := e.clk.Now()
	st, m := e.verify(u, "premium_3m", "test_valid_one")
	if st != 200 || m["purchase_state"] != "verified" || m["coins_granted"].(float64) != 0 {
		t.Fatalf("verify: %d %v", st, m)
	}
	s1 := e.parseState(m["entitlement_state"].(map[string]any))
	if end := premiumEnd(t, s1); !end.Equal(now.Add(90 * 24 * time.Hour)) {
		t.Fatalf("first pass ends %v", end)
	}
	// Same token again: same purchase, no extra time.
	_, m2 := e.verify(u, "premium_3m", "test_valid_one")
	if m2["purchase_id"] != m["purchase_id"] {
		t.Fatal("idempotent verify must return the same purchase")
	}
	if end := premiumEnd(t, e.parseState(m2["entitlement_state"].(map[string]any))); !end.Equal(now.Add(90 * 24 * time.Hour)) {
		t.Fatalf("idempotent verify extended grant to %v", end)
	}
	// Second purchase accumulates to 180 days.
	_, m3 := e.verify(u, "premium_3m", "test_valid_two")
	if end := premiumEnd(t, e.parseState(m3["entitlement_state"].(map[string]any))); !end.Equal(now.Add(180 * 24 * time.Hour)) {
		t.Fatalf("accumulated end %v want %v", end, now.Add(180*24*time.Hour))
	}
	// Another user on other hardware cannot claim the token; invalid and unknown inputs are rejected.
	other := e.newUser("hw-other")
	if st, m := e.verify(other, "premium_3m", "test_valid_one"); st != 409 || errCode(m) != "PURCHASE_ALREADY_CLAIMED" {
		t.Fatalf("claimed: %d %v", st, m)
	}
	if st, m := e.verify(u, "premium_3m", "test_invalid_x"); st != 422 || errCode(m) != "PURCHASE_INVALID" {
		t.Fatalf("invalid: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/purchases/verify", u.token, map[string]any{"market": "bazaar", "product_id": "premium_3m",
		"market_sku": "wrong", "purchase_token": "test_valid_z"}, ""); st != 400 || errCode(m) != "INVALID_INPUT" {
		t.Fatalf("sku mismatch: %d %v", st, m)
	}
}

func TestPurchaseTransferSameDevice(t *testing.T) {
	e := newEnv(t)
	old := e.newUser("hw-t")
	e.verify(old, "premium_3m", "test_valid_transfer")
	reinstall := e.newUser("hw-t") // new install, same hardware ⇒ same device_hash
	st, m := e.verify(reinstall, "premium_3m", "test_valid_transfer")
	if st != 200 || len(e.parseState(m["entitlement_state"].(map[string]any)).Entitlements) != 1 {
		t.Fatalf("transfer: %d %v", st, m)
	}
	if s, _ := e.state(old); len(s.Entitlements) != 0 {
		t.Fatalf("old account must lose the grant: %+v", s)
	}
}

func TestMarketUnavailable(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-m")
	if st, m := e.verify(u, "premium_1m", "test_timeout_a"); st != 503 || errCode(m) != "MARKET_UNAVAILABLE" {
		t.Fatalf("timeout: %d %v", st, m)
	}
	if st, m := e.verify(u, "premium_1m", "test_slow_a"); st != 503 || errCode(m) != "MARKET_UNAVAILABLE" {
		t.Fatalf("slow: %d %v", st, m)
	}
	if s, _ := e.state(u); len(s.Entitlements) != 0 {
		t.Fatal("no grant on market failure")
	}
}

func TestConsumableCoins(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-c")
	st, m := e.verify(u, "coins_small", "test_valid_coins1")
	if st != 200 || m["coins_granted"].(float64) != 200 {
		t.Fatalf("coins: %d %v", st, m)
	}
	if len(e.parseState(m["entitlement_state"].(map[string]any)).Entitlements) != 0 {
		t.Fatal("coins must not create a grant")
	}
	// Consumables are never transferable between accounts.
	r := e.newUser("hw-c")
	if st, m := e.verify(r, "coins_small", "test_valid_coins1"); st != 409 {
		t.Fatalf("coins claim: %d %v", st, m)
	}
}

func TestRestore(t *testing.T) {
	e := newEnv(t)
	a := e.newUser("hw-r1")
	e.verify(a, "premium_6m", "test_valid_restore")
	b := e.newUser("hw-r1") // reinstall
	body := map[string]any{"market": "bazaar", "purchases": []map[string]any{
		{"product_id": "premium_6m", "market_sku": "premium_6m", "purchase_token": "test_valid_restore"},
		{"product_id": "premium_6m", "market_sku": "premium_6m", "purchase_token": "test_invalid_zzz"}}}
	st, m := e.call("POST", "/v1/purchases/restore", b.token, body, "")
	if st != 200 || len(e.parseState(m).Entitlements) != 1 {
		t.Fatalf("restore: %d %v", st, m)
	}
	// A stranger restoring someone else's token only gets PURCHASE_ALREADY_CLAIMED.
	x := e.newUser("hw-r9")
	body["purchases"] = body["purchases"].([]map[string]any)[:1]
	if st, m := e.call("POST", "/v1/purchases/restore", x.token, body, ""); st != 409 || errCode(m) != "PURCHASE_ALREADY_CLAIMED" {
		t.Fatalf("restore claimed: %d %v", st, m)
	}
}

func TestReverifyRefundAndCancel(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	q := dbgen.New(e.pool)
	for _, mk := range []string{"bazaar", "myket"} {
		d := int32(30)
		ent := "premium"
		if err := q.UpsertProduct(ctx, dbgen.UpsertProductParams{ID: "premium_sub", Market: mk, Kind: "subscription",
			Entitlement: &ent, DurationDays: &d, MarketSku: "premium_sub", Active: true}); err != nil {
			t.Fatal(err)
		}
	}
	u := e.newUser("hw-s")
	if st, m := e.verify(u, "premium_sub", "test_valid_30d_sub"); st != 200 {
		t.Fatalf("sub verify: %d %v", st, m)
	}
	if s, _ := e.state(u); len(s.Entitlements) != 1 || s.Entitlements[0].Source != "subscription" {
		t.Fatalf("sub grant: %+v", s)
	}
	// Auto-renew turned off: grant stays, an event is emitted once.
	e.fake.DisableAutoRenew("test_valid_30d_sub")
	if err := e.bill.ReverifySubscriptions(ctx); err != nil {
		t.Fatal(err)
	}
	if s, _ := e.state(u); len(s.Entitlements) != 1 {
		t.Fatal("grant must stay until the period ends")
	}
	// Refund: grant revoked.
	e.fake.Override("test_valid_30d_sub", billing.MarketRefunded)
	if err := e.bill.ReverifySubscriptions(ctx); err != nil {
		t.Fatal(err)
	}
	if s, _ := e.state(u); len(s.Entitlements) != 0 {
		t.Fatalf("refunded sub must be revoked: %+v", s)
	}
	e.sink.mu.Lock()
	defer e.sink.mu.Unlock()
	// one event when auto-renew flipped off, one for the refund
	if len(e.sink.events) != 2 || e.sink.events[0] != "subscription_canceled" || e.sink.events[1] != "subscription_canceled" {
		t.Fatalf("events: %v", e.sink.events)
	}
}

func TestDeleteAccountRevokesGrantsKeepsPurchases(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-d")
	e.verify(u, "premium_1m", "test_valid_del")
	if st, _ := e.call("DELETE", "/v1/me", u.token, nil, ""); st != 204 {
		t.Fatal("delete")
	}
	var grants, purchases int
	_ = e.pool.QueryRow(context.Background(), `select count(*) filter (where revoked_at is null) from entitlement_grants where user_id=$1`, u.id).Scan(&grants)
	_ = e.pool.QueryRow(context.Background(), `select count(*) from purchases where user_id=$1`, u.id).Scan(&purchases)
	if grants != 0 || purchases != 1 {
		t.Fatalf("grants=%d purchases=%d", grants, purchases)
	}
}
