package app_test

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

// adm calls an admin endpoint from the allowed IP with Basic Auth.
func (e *env) adm(method, path string, body any) (int, map[string]any) {
	e.t.Helper()
	st, _, m := e.callH(method, path, "", body, adminIP, map[string]string{"Authorization": basic("admin", adminPass)})
	return st, m
}

func basic(u, p string) string {
	return "Basic " + b64([]byte(u+":"+p))
}

func b64(b []byte) string {
	const tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	var out strings.Builder
	for i := 0; i < len(b); i += 3 {
		var n uint32
		rem := len(b) - i
		for j := 0; j < 3; j++ {
			n <<= 8
			if i+j < len(b) {
				n |= uint32(b[i+j])
			}
		}
		out.WriteByte(tbl[n>>18&63])
		out.WriteByte(tbl[n>>12&63])
		if rem > 1 {
			out.WriteByte(tbl[n>>6&63])
		} else {
			out.WriteByte('=')
		}
		if rem > 2 {
			out.WriteByte(tbl[n&63])
		} else {
			out.WriteByte('=')
		}
	}
	return out.String()
}

func defaultConfig(t *testing.T) map[string]any {
	t.Helper()
	raw, err := os.ReadFile(configDataDir + "/config/default.json")
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func (e *env) publishConfig(cfg map[string]any, activate bool) int {
	e.t.Helper()
	st, m := e.adm("POST", "/admin/v1/config", map[string]any{"payload": cfg, "activate": activate})
	if st != 201 {
		e.t.Fatalf("publish config: %d %v", st, m)
	}
	return int(m["version"].(float64))
}

func TestConfigPublishValidationActivateAnd304(t *testing.T) {
	e := newEnv(t)
	// No active config yet.
	if st, _ := e.call("GET", "/v1/config", "", nil, ""); st != 404 {
		t.Fatalf("no config: %d", st)
	}
	// Invalid config is rejected with a precise message.
	bad := defaultConfig(t)
	bad["limits"].(map[string]any)["free_active_habits"] = "three"
	st, m := e.adm("POST", "/admin/v1/config", map[string]any{"payload": bad})
	if st != 400 || !strings.Contains(fmt.Sprint(m), "/limits/free_active_habits") {
		t.Fatalf("invalid config: %d %v", st, m)
	}
	delete(bad, "limits")
	if st, m := e.adm("POST", "/admin/v1/config", map[string]any{"payload": bad}); st != 400 {
		t.Fatalf("missing group: %d %v", st, m)
	}

	v1 := e.publishConfig(defaultConfig(t), true)
	inst := uuid.NewString()
	hdr := map[string]string{"X-Install-Id": inst, "X-Market": "bazaar", "X-App-Version": "1.0.0", "Accept-Encoding": "gzip"}
	st, h, body := e.callH("GET", "/v1/config?known_version=0", "", nil, "", hdr)
	if st != 200 || h.Get("ETag") == "" || h.Get("Content-Encoding") != "gzip" || int(body["version"].(float64)) != v1 {
		t.Fatalf("config: %d %v %v", st, h, body)
	}
	etag := h.Get("ETag")
	hdr["If-None-Match"] = etag
	if st, _, _ := e.callH("GET", "/v1/config", "", nil, "", hdr); st != 304 {
		t.Fatalf("second request must be 304, got %d", st)
	}

	// New version + rollback by activating the old one.
	cfg2 := defaultConfig(t)
	cfg2["limits"].(map[string]any)["free_active_habits"] = 5
	v2 := e.publishConfig(cfg2, true)
	delete(hdr, "If-None-Match")
	_, _, body = e.callH("GET", "/v1/config", "", nil, "", hdr)
	if int(body["version"].(float64)) != v2 || body["payload"].(map[string]any)["limits"].(map[string]any)["free_active_habits"] != 5.0 {
		t.Fatalf("v2 not served: %v", body)
	}
	if st, _ := e.adm("POST", fmt.Sprintf("/admin/v1/config/%d/activate", v1), nil); st != 200 {
		t.Fatalf("rollback: %d", st)
	}
	if st, _ := e.adm("POST", "/admin/v1/config/999/activate", nil); st != 404 {
		t.Fatalf("unknown version: %d", st)
	}
	hdr["If-None-Match"] = etag
	if st, _, _ := e.callH("GET", "/v1/config", "", nil, "", hdr); st != 304 {
		t.Fatalf("after rollback the old ETag matches again, got %d", st)
	}
	// Old apps still get 200 (the client shows force-update itself).
	hdr["X-App-Version"] = "0.0.1"
	delete(hdr, "If-None-Match")
	if st, _, _ := e.callH("GET", "/v1/config", "", nil, "", hdr); st != 200 {
		t.Fatalf("old app: %d", st)
	}
}

func TestExperimentOverridesAndAudience(t *testing.T) {
	e := newEnv(t)
	e.publishConfig(defaultConfig(t), true)
	// An experiment that produces an invalid config is rejected at publish time.
	st, m := e.adm("PUT", "/admin/v1/experiments/broken", map[string]any{"status": "running",
		"variants": []any{map[string]any{"name": "a", "weight": 1, "overrides": map[string]any{"trial.days": "seven"}},
			map[string]any{"name": "b", "weight": 1, "overrides": map[string]any{}}}})
	if st != 400 {
		t.Fatalf("broken experiment: %d %v", st, m)
	}
	// 100%-to-b experiment for myket only.
	st, m = e.adm("PUT", "/admin/v1/experiments/paywall_layout", map[string]any{"status": "running",
		"audience": map[string]any{"markets": []string{"myket"}},
		"variants": []any{map[string]any{"name": "a", "weight": 1, "overrides": map[string]any{}},
			map[string]any{"name": "b", "weight": 1000000, "overrides": map[string]any{"paywall.variant": "b"}}}})
	if st != 204 {
		t.Fatalf("put experiment: %d %v", st, m)
	}
	get := func(market string) map[string]any {
		_, _, body := e.callH("GET", "/v1/config", "", nil, "", map[string]string{"X-Install-Id": uuid.NewString(), "X-Market": market, "X-App-Version": "1.0.0"})
		return body
	}
	// The experiment cache lives 30s; PutExperiment invalidates it, so the change is visible immediately.
	my := get("myket")
	if my["experiments"].(map[string]any)["paywall_layout"] != "b" || my["payload"].(map[string]any)["paywall"].(map[string]any)["variant"] != "b" {
		t.Fatalf("myket should get override: %v", my)
	}
	bz := get("bazaar")
	if len(bz["experiments"].(map[string]any)) != 0 || bz["payload"].(map[string]any)["paywall"].(map[string]any)["variant"] != "a" {
		t.Fatalf("bazaar must not get override: %v", bz)
	}
	// Anonymous caller without install id gets no experiments; ETags differ between arms.
	_, h1, _ := e.callH("GET", "/v1/config", "", nil, "", map[string]string{"X-Install-Id": uuid.NewString(), "X-Market": "myket"})
	_, h2, _ := e.callH("GET", "/v1/config", "", nil, "", map[string]string{"X-Market": "myket"})
	if h1.Get("ETag") == h2.Get("ETag") {
		t.Fatal("ETag must reflect experiment assignment")
	}
	// Authenticated user: stable variant.
	u := e.newUser("hw-exp")
	_, _, a1 := e.callH("GET", "/v1/config", u.token, nil, "", map[string]string{"X-Market": "myket"})
	_, _, a2 := e.callH("GET", "/v1/config", u.token, nil, "", map[string]string{"X-Market": "myket"})
	if fmt.Sprint(a1["experiments"]) != fmt.Sprint(a2["experiments"]) {
		t.Fatal("variant must be stable")
	}
	// Stopped experiments stop applying.
	e.adm("PUT", "/admin/v1/experiments/paywall_layout", map[string]any{"status": "stopped",
		"variants": []any{map[string]any{"name": "a", "weight": 1}, map[string]any{"name": "b", "weight": 1}}})
	if my := get("myket"); len(my["experiments"].(map[string]any)) != 0 {
		t.Fatalf("stopped experiment still applied: %v", my)
	}
}

func packDoc(t *testing.T, name string, version int, minV string) map[string]any {
	t.Helper()
	raw, err := os.ReadFile(configDataDir + "/content/" + name + ".json")
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	_ = json.Unmarshal(raw, &m)
	m["version"] = version
	m["min_app_version"] = minV
	return m
}

func TestContentPublishManifestAndImmutablePacks(t *testing.T) {
	e := newEnv(t)
	st, m := e.adm("POST", "/admin/v1/content/packs", packDoc(t, "brand", 1, "1.0.0"))
	if st != 201 {
		t.Fatalf("publish brand v1: %d %v", st, m)
	}
	// Re-publishing the same version is refused (immutability).
	if st, _ := e.adm("POST", "/admin/v1/content/packs", packDoc(t, "brand", 1, "1.0.0")); st != 400 {
		t.Fatalf("duplicate version: %d", st)
	}
	// Invalid pack (bad schema) is rejected.
	bad := packDoc(t, "shop_items", 1, "1.0.0")
	bad["entries"].([]any)[0].(map[string]any)["price_coins"] = -1
	if st, m := e.adm("POST", "/admin/v1/content/packs", bad); st != 400 || !strings.Contains(fmt.Sprint(m), "schema") {
		t.Fatalf("bad pack: %d %v", st, m)
	}
	e.adm("POST", "/admin/v1/content/packs", packDoc(t, "brand", 2, "2.0.0")) // needs a newer app
	e.adm("POST", "/admin/v1/content/packs", packDoc(t, "copy_fa", 1, "1.0.0"))

	manifest := func(appVersion string) []any {
		_, _, body := e.callH("GET", "/v1/content/manifest", "", nil, "", map[string]string{"X-App-Version": appVersion})
		return body["packs"].([]any)
	}
	old := manifest("1.0.0")
	if len(old) != 2 {
		t.Fatalf("1.0.0 sees brand v1 + copy_fa v1: %v", old)
	}
	for _, p := range old {
		pm := p.(map[string]any)
		if pm["pack_key"] == "brand" && pm["version"].(float64) != 1 {
			t.Fatalf("old app must not see brand v2: %v", pm)
		}
	}
	newer := manifest("2.0.0")
	for _, p := range newer {
		pm := p.(map[string]any)
		if pm["pack_key"] == "brand" && pm["version"].(float64) != 2 {
			t.Fatalf("2.0.0 should see brand v2: %v", pm)
		}
	}
	// ETag + 304 on the manifest.
	_, h, _ := e.callH("GET", "/v1/content/manifest", "", nil, "", map[string]string{"X-App-Version": "1.0.0"})
	if st, _, _ := e.callH("GET", "/v1/content/manifest", "", nil, "", map[string]string{"X-App-Version": "1.0.0", "If-None-Match": h.Get("ETag")}); st != 304 {
		t.Fatalf("manifest 304: %d", st)
	}

	// Pack download: gzip-capable, immutable caching, sha256 matches the manifest.
	var entry map[string]any
	for _, p := range old {
		if p.(map[string]any)["pack_key"] == "copy_fa" {
			entry = p.(map[string]any)
		}
	}
	st, h, _ = e.callH("GET", entry["url"].(string), "", nil, "", map[string]string{"Accept-Encoding": "gzip"})
	if st != 200 || h.Get("Cache-Control") != "public, max-age=31536000, immutable" || h.Get("Content-Encoding") != "gzip" {
		t.Fatalf("pack headers: %d %v", st, h)
	}
	if st, _ := e.call("GET", "/v1/content/packs/copy_fa/99", "", nil, ""); st != 404 {
		t.Fatalf("missing pack: %d", st)
	}
	if st, _ := e.call("GET", "/v1/content/packs/copy_fa/abc", "", nil, ""); st != 404 {
		t.Fatalf("bad version: %d", st)
	}
	// The served bytes hash to the manifest's sha256 (no Accept-Encoding => identity bytes).
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, httptest.NewRequest("GET", entry["url"].(string), nil))
	sum := sha256.Sum256(rec.Body.Bytes())
	if hex.EncodeToString(sum[:]) != entry["sha256"] || rec.Header().Get("ETag") != `"`+entry["sha256"].(string)+`"` {
		t.Fatalf("sha256 mismatch: manifest %v, body %s, etag %s", entry["sha256"], hex.EncodeToString(sum[:]), rec.Header().Get("ETag"))
	}
	if int(entry["size"].(float64)) != rec.Body.Len() {
		t.Fatalf("manifest size %v != body %d", entry["size"], rec.Body.Len())
	}
}

func insertEvent(t *testing.T, e *env, name string, actor uuid.UUID, at time.Time, props, session string) {
	t.Helper()
	if _, err := e.pool.Exec(context.Background(), `select ensure_events_partition($1::date)`, at); err != nil {
		t.Fatal(err)
	}
	if _, err := e.pool.Exec(context.Background(),
		`insert into events (id, install_id, name, props, client_ts, received_at, session_id) values ($1,$2,$3,$4::jsonb,$5,$5,$6)`,
		uuid.New(), actor, name, props, at, session); err != nil {
		t.Fatal(err)
	}
}

func TestIngestRules(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-ev")
	id := uuid.NewString()
	ts := e.clk.Now().Format(time.RFC3339)
	mk := func(name string, props map[string]any) map[string]any {
		return map[string]any{"event_id": uuid.NewString(), "name": name, "ts": ts, "session_id": "s1", "props": props}
	}
	dup := map[string]any{"event_id": id, "name": "app_opened", "ts": ts, "session_id": "s1", "props": map[string]any{"source": "launcher"}}
	st, res := e.call("POST", "/v1/events", u.token, map[string]any{"sent_at": ts, "events": []any{
		mk("habit_completed", map[string]any{"template_key": "water", "source": "app", "habit_title": "private"}),
		mk("no_such_event", nil),
		mk("checkin_completed", map[string]any{"has_note": true, "mood_level": 2}),
		mk("subscription_canceled", map[string]any{"product_id": "x"}),
		dup, dup,
	}}, "")
	if st != 200 || res["accepted"].(float64) != 3 || res["rejected"].(float64) != 3 {
		t.Fatalf("ingest: %d %v", st, res)
	}
	reasons := res["rejected_reasons"].(map[string]any)
	if reasons["unknown_event"] != 1.0 || reasons["forbidden_prop"] != 1.0 || reasons["server_only"] != 1.0 {
		t.Fatalf("reasons: %v", reasons)
	}
	var n int
	var props string
	_ = e.pool.QueryRow(context.Background(), `select count(*) from events where id=$1`, id).Scan(&n)
	if n != 1 {
		t.Fatalf("duplicate event_id must produce one row, got %d", n)
	}
	_ = e.pool.QueryRow(context.Background(), `select props::text from events where name='habit_completed' and user_id=$1`, u.id).Scan(&props)
	if strings.Contains(props, "habit_title") || !strings.Contains(props, "water") {
		t.Fatalf("props whitelist: %s", props)
	}
	// A resend of the same batch changes nothing.
	e.call("POST", "/v1/events", u.token, map[string]any{"events": []any{dup}}, "")
	_ = e.pool.QueryRow(context.Background(), `select count(*) from events where id=$1`, id).Scan(&n)
	if n != 1 {
		t.Fatalf("resend: %d", n)
	}
	// Limits and auth.
	if st, _ := e.call("POST", "/v1/events", "", map[string]any{"events": []any{dup}}, ""); st != 401 {
		t.Fatalf("auth: %d", st)
	}
	many := make([]any, 201)
	for i := range many {
		many[i] = mk("app_opened", nil)
	}
	if st, _ := e.call("POST", "/v1/events", u.token, map[string]any{"events": many}, ""); st != 400 {
		t.Fatalf("201 events must be refused, got %d", st)
	}
	// Account deletion anonymizes events but keeps them.
	e.call("DELETE", "/v1/me", u.token, nil, "")
	var withUser, total int
	_ = e.pool.QueryRow(context.Background(), `select count(*) filter (where user_id is not null), count(*) from events where name='habit_completed'`).Scan(&withUser, &total)
	if withUser != 0 || total != 1 {
		t.Fatalf("after deletion: with_user=%d total=%d", withUser, total)
	}
}

func TestRollupMetrics(t *testing.T) {
	e := newEnv(t)
	now := e.clk.Now().UTC()
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -1)
	at := func(daysBack int, h int) time.Time {
		return day.AddDate(0, 0, -daysBack).Add(time.Duration(h) * time.Hour)
	}
	A, B, C, D, E, F, G, H := uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New(), uuid.New()
	// D1 cohort (installed the day before `day`): A,B,C,D; A and B come back on `day`.
	for _, x := range []uuid.UUID{A, B, C, D} {
		insertEvent(t, e, "app_installed", x, at(1, 9), "{}", "")
	}
	// D7 cohort: E,F; E comes back.
	for _, x := range []uuid.UUID{E, F} {
		insertEvent(t, e, "app_installed", x, at(7, 9), "{}", "")
	}
	for _, x := range []uuid.UUID{A, B, E, G} {
		insertEvent(t, e, "app_opened", x, at(0, 10), `{"source":"launcher"}`, "")
	}
	insertEvent(t, e, "adventure_started", A, at(0, 11), "{}", "")
	insertEvent(t, e, "adventure_started", B, at(0, 11), "{}", "")
	// onboarding: G and H; G starts a trial and completes a habit within 24h.
	insertEvent(t, e, "onboarding_completed", G, at(0, 12), "{}", "")
	insertEvent(t, e, "onboarding_completed", H, at(0, 12), "{}", "")
	insertEvent(t, e, "trial_started", G, at(0, 12), "{}", "")
	insertEvent(t, e, "habit_completed", G, at(0, 13), "{}", "")
	// paywall: s1 converts, s2 does not.
	insertEvent(t, e, "paywall_viewed", G, at(0, 14), `{"trigger":"fourth_habit","variant":"a"}`, "s1")
	insertEvent(t, e, "purchase_completed", G, at(0, 14).Add(time.Minute), `{"product_id":"premium_3m"}`, "s1")
	insertEvent(t, e, "paywall_viewed", H, at(0, 15), `{"trigger":"fourth_habit","variant":"a"}`, "s2")

	if err := e.an.RollupDay(context.Background(), day); err != nil {
		t.Fatal(err)
	}
	// Idempotent.
	if err := e.an.RollupDay(context.Background(), day); err != nil {
		t.Fatal(err)
	}
	d := day.Format("2006-01-02")
	st, res := e.adm("GET", "/admin/v1/metrics/daily?from="+d+"&to="+d, nil)
	if st != 200 {
		t.Fatalf("metrics: %d %v", st, res)
	}
	got := map[string]float64{}
	for _, r := range res["metrics"].([]any) {
		m := r.(map[string]any)
		key := m["metric"].(string)
		if dims, _ := json.Marshal(m["dims"]); string(dims) != "{}" {
			if m["dims"].(map[string]any)["trigger"] != nil {
				key += ":" + m["dims"].(map[string]any)["trigger"].(string) + ":" + m["dims"].(map[string]any)["variant"].(string)
			}
		}
		if _, dup := got[key]; dup {
			t.Fatalf("duplicate metric row %s", key)
		}
		got[key] = m["value"].(float64)
	}
	want := map[string]float64{
		"dau": 4, "retention_d1": 0.5, "retention_d7": 0.5, "core_loop_completion": 0.5,
		"trial_start_rate": 0.5, "activation_rate": 0.5,
		"paywall_views:fourth_habit:a": 2, "paywall_cvr:fourth_habit:a": 0.5, "new_installs": 0,
	}
	for k, v := range want {
		if got[k] != v {
			t.Errorf("%s = %v, want %v (all: %v)", k, got[k], v, got)
		}
	}
	if got["mau"] < 4 || got["wau"] < 4 {
		t.Errorf("wau/mau: %v", got)
	}
	if got["stickiness"] <= 0 || got["stickiness"] > 1 {
		t.Errorf("stickiness: %v", got["stickiness"])
	}
}

func TestPartitionsAndPrune(t *testing.T) {
	e := newEnv(t)
	ctx := context.Background()
	count := func() int {
		var n int
		_ = e.pool.QueryRow(ctx, `select count(*) from pg_inherits i join pg_class p on p.oid=i.inhparent where p.relname='events'`).Scan(&n)
		return n
	}
	before := count()
	if before < 2 {
		t.Fatalf("migration must create current + next month partitions, got %d", before)
	}
	if err := e.an.EnsurePartitions(ctx, 3); err != nil {
		t.Fatal(err)
	}
	if err := e.an.EnsurePartitions(ctx, 3); err != nil { // idempotent
		t.Fatal(err)
	}
	if count() < 4 {
		t.Fatalf("ensure ahead=3 should give >=4 partitions, got %d", count())
	}
	// A partition older than 18 months is dropped by Prune; recent ones stay.
	old := e.clk.Now().AddDate(-2, 0, 0)
	if _, err := e.pool.Exec(ctx, `select ensure_events_partition($1::date)`, old); err != nil {
		t.Fatal(err)
	}
	n := count()
	if err := e.an.Prune(ctx); err != nil {
		t.Fatal(err)
	}
	if count() != n-1 {
		t.Fatalf("prune should drop exactly the old partition: %d -> %d", n, count())
	}
}

func TestAdminGuardAndAudit(t *testing.T) {
	e := newEnv(t)
	// Outside the allowlist: 403 even with right credentials.
	st, _, m := e.callH("GET", "/admin/v1/metrics/daily", "", nil, "203.0.113.9", map[string]string{"Authorization": basic("admin", adminPass)})
	if st != 403 || errCode(m) != "FORBIDDEN" {
		t.Fatalf("ip: %d %v", st, m)
	}
	// Wrong password / no credentials: 401.
	st, _, m = e.callH("GET", "/admin/v1/metrics/daily", "", nil, adminIP, map[string]string{"Authorization": basic("admin", "nope")})
	if st != 401 {
		t.Fatalf("bad password: %d %v", st, m)
	}
	if st, _, _ := e.callH("GET", "/admin/v1/metrics/daily", "", nil, adminIP, nil); st != 401 {
		t.Fatalf("no credentials: %d", st)
	}
	// Operations are audited (including failures).
	e.adm("POST", "/admin/v1/config", map[string]any{"payload": map[string]any{"x": 1}})
	e.publishConfig(defaultConfig(t), true)
	u := e.newUser("hw-adm")
	st, m = e.adm("POST", "/admin/v1/users/"+u.id+"/grants", map[string]any{"days": 30, "reason": "support case 17"})
	if st != 201 {
		t.Fatalf("grant: %d %v", st, m)
	}
	if st, _ := e.adm("POST", "/admin/v1/users/"+u.id+"/grants", map[string]any{"days": 30}); st != 400 {
		t.Fatalf("grant without reason: %d", st)
	}
	if st, _ := e.adm("POST", "/admin/v1/users/"+uuid.NewString()+"/grants", map[string]any{"days": 30, "reason": "x"}); st != 404 {
		t.Fatalf("grant for unknown user: %d", st)
	}
	if s, _ := e.state(u); len(s.Entitlements) != 1 || s.Entitlements[0].Source != "promo" {
		t.Fatalf("promo grant not visible: %+v", s)
	}
	st, m = e.adm("GET", "/admin/v1/users/"+u.id, nil)
	if st != 200 || m["user_id"] != u.id || m["grants"] == nil {
		t.Fatalf("user view: %d %v", st, m)
	}
	rows, err := e.pool.Query(context.Background(), `select action, payload->>'result' from admin_audit order by id`)
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var seen []string
	for rows.Next() {
		var a, r string
		_ = rows.Scan(&a, &r)
		seen = append(seen, a+":"+r)
	}
	for _, want := range []string{"config.publish:error:INVALID_INPUT", "config.publish:ok", "grant.promo:ok", "grant.promo:error:INVALID_INPUT", "user.view:ok"} {
		found := false
		for _, s := range seen {
			if s == want {
				found = true
			}
		}
		if !found {
			t.Errorf("audit missing %q in %v", want, seen)
		}
	}
	// No password or credentials leak into the audit table.
	var leaked int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from admin_audit where payload::text ilike '%'||$1||'%'`, adminPass).Scan(&leaked)
	if leaked != 0 {
		t.Fatal("audit payload leaks credentials")
	}
}
