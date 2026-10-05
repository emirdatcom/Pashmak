package app_test

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/modules/support"
)

type testSupportCfg struct {
	mu sync.Mutex
	c  support.Config
}

func (t *testSupportCfg) Support(context.Context) support.Config {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.c
}

func (t *testSupportCfg) set(f func(*support.Config)) {
	t.mu.Lock()
	defer t.mu.Unlock()
	f(&t.c)
}

const opIP = "10.200.0.5"

type opSession struct{ cookie, csrf string }

func (e *env) addOperator(username, role string) {
	e.t.Helper()
	if err := support.AddOperator(context.Background(), e.pool, e.clk, username, "correct-horse-battery", "سارا از تیم پشمک", role); err != nil {
		e.t.Fatal(err)
	}
}

func (e *env) opLogin(username, password string) (int, opSession) {
	e.t.Helper()
	st, hdr, m := e.callH("POST", "/admin/v1/support/login", "", map[string]any{"username": username, "password": password}, opIP, nil)
	if st != 200 {
		return st, opSession{}
	}
	var cookie string
	for _, c := range hdr.Values("Set-Cookie") {
		if strings.HasPrefix(c, "op_session=") {
			cookie = strings.SplitN(strings.SplitN(c, ";", 2)[0], "=", 2)[1]
		}
	}
	return st, opSession{cookie: cookie, csrf: m["csrf"].(string)}
}

func (e *env) opCall(s opSession, method, path string, body any) (int, map[string]any) {
	e.t.Helper()
	st, _, m := e.callH(method, path, "", body, opIP, map[string]string{"Cookie": "op_session=" + s.cookie, "X-CSRF-Token": s.csrf})
	return st, m
}

func (e *env) userSend(u tuser, body string, clientID uuid.UUID, meta bool) (int, map[string]any) {
	return e.call("POST", "/v1/support/messages", u.token, map[string]any{"client_msg_id": clientID.String(), "body": body, "include_device_meta": meta}, "")
}

func (e *env) onlineHours() {
	e.scfg.set(func(c *support.Config) {
		c.Hours = nil
		for w := 0; w <= 6; w++ {
			c.Hours = append(c.Hours, support.Hours{Weekday: w, From: "00:00", To: "24:00"})
		}
	})
}

func TestSupportUserFlowIdempotencyAndEncryption(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("sup-1")
	e.addOperator("sara", "agent")
	_, op := e.opLogin("sara", "correct-horse-battery")

	if st, m := e.call("GET", "/v1/support/conversation", u.token, nil, ""); st != 200 || m["status"] != "none" || m["online"] != false {
		t.Fatalf("empty conversation: %d %v", st, m)
	}
	id := uuid.New()
	secret := "سلام، شماره سفارش ۹۸۷۶۵۴ مشکل داره"
	st, m := e.userSend(u, secret, id, false)
	if st != 200 || m["body"] != secret || m["sender"] != "user" {
		t.Fatalf("send: %d %v", st, m)
	}
	// duplicate delivery (retry after a network cut): same message, one row
	st2, m2 := e.userSend(u, secret, id, false)
	if st2 != 200 || m2["id"] != m["id"] {
		t.Fatalf("idempotent resend: %d %v vs %v", st2, m2, m)
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_messages`).Scan(&n)
	if n != 1 {
		t.Fatalf("rows=%d", n)
	}
	// stored encrypted: no plaintext in the table
	var enc []byte
	_ = e.pool.QueryRow(context.Background(), `select body_enc from support_messages`).Scan(&enc)
	if bytes.Contains(enc, []byte("۹۸۷۶۵۴")) || bytes.Contains(enc, []byte("سفارش")) {
		t.Fatal("message body is readable in the database")
	}

	st, q := e.opCall(op, "GET", "/admin/v1/support/conversations", nil)
	items := q["conversations"].([]any)
	if st != 200 || len(items) != 1 || items[0].(map[string]any)["status"] != "open" || items[0].(map[string]any)["operator_unread"] != float64(1) {
		t.Fatalf("queue: %d %v", st, q)
	}
	convID := items[0].(map[string]any)["id"].(string)
	// operator replies → waiting_user, user unread 1
	if st, r := e.opCall(op, "POST", "/admin/v1/support/conversations/"+convID+"/messages", map[string]any{"body": "سلام! الان بررسی می‌کنم."}); st != 200 || r["operator_display_name"] != "سارا از تیم پشمک" {
		t.Fatalf("reply: %d %v", st, r)
	}
	_, info := e.call("GET", "/v1/support/conversation", u.token, nil, "")
	if info["status"] != "waiting_user" || info["unread_count"] != float64(1) || info["operator_display_name"] != "سارا از تیم پشمک" {
		t.Fatalf("conversation after reply: %v", info)
	}
	st, page := e.call("GET", "/v1/support/messages", u.token, nil, "")
	msgs := page["messages"].([]any)
	if st != 200 || len(msgs) != 2 || msgs[0].(map[string]any)["sender"] != "user" || msgs[1].(map[string]any)["sender"] != "operator" {
		t.Fatalf("history order: %d %v", st, page)
	}
	// cursor paging: after the first id → only the reply
	first := msgs[0].(map[string]any)["id"].(string)
	if _, p2 := e.call("GET", "/v1/support/messages?after="+first, u.token, nil, ""); len(p2["messages"].([]any)) != 1 {
		t.Fatalf("after cursor: %v", p2)
	}
	// read receipts both ways
	last := msgs[1].(map[string]any)["id"].(string)
	if st, _ := e.call("POST", "/v1/support/read", u.token, map[string]any{"up_to_message_id": last}, ""); st != 204 {
		t.Fatal(st)
	}
	if _, info := e.call("GET", "/v1/support/conversation", u.token, nil, ""); info["unread_count"] != float64(0) {
		t.Fatalf("unread after read: %v", info)
	}
	// a new user message re-opens the conversation
	e.userSend(u, "یه سؤال دیگه", uuid.New(), false)
	if _, info := e.call("GET", "/v1/support/conversation", u.token, nil, ""); info["status"] != "open" {
		t.Fatalf("status after new message: %v", info)
	}
	// closing: next message starts a fresh conversation
	if st, _ := e.opCall(op, "POST", "/admin/v1/support/conversations/"+convID+"/close", map[string]any{}); st != 204 {
		t.Fatal(st)
	}
	e.userSend(u, "بعد از بسته شدن", uuid.New(), false)
	var convs int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_conversations`).Scan(&convs)
	if convs != 2 {
		t.Fatalf("conversations=%d", convs)
	}
	// validation
	for name, body := range map[string]string{"empty": "   ", "too long": strings.Repeat("آ", 2001)} {
		if st, m := e.userSend(u, body, uuid.New(), false); st != 400 || errCode(m) != "INVALID_INPUT" {
			t.Fatalf("%s: %d %v", name, st, m)
		}
	}
	if st, m := e.call("POST", "/v1/support/messages", u.token, map[string]any{"client_msg_id": uuid.Nil.String(), "body": "x"}, ""); st != 400 {
		t.Fatalf("nil client id: %d %v", st, m)
	}
}

func TestSupportDeviceMetaOnlyWithConsentAndOperatorPermissions(t *testing.T) {
	e := newEnv(t)
	u1, u2 := e.newUser("sup-m1"), e.newUser("sup-m2")
	e.addOperator("agent1", "agent")
	e.addOperator("boss", "admin")
	_, agent := e.opLogin("agent1", "correct-horse-battery")
	_, boss := e.opLogin("boss", "correct-horse-battery")

	hdr := map[string]string{"X-App-Version": "1.2.3", "X-Market": "bazaar", "X-OS-Version": "14", "X-Device-Model": "Pixel 7"}
	send := func(u tuser, meta bool) {
		st, _, _ := e.callH("POST", "/v1/support/messages", u.token, map[string]any{"client_msg_id": uuid.NewString(), "body": "سلام", "include_device_meta": meta}, "", hdr)
		if st != 200 {
			t.Fatalf("send: %d", st)
		}
	}
	send(u1, false)
	send(u2, true)
	var withMeta, without int
	_ = e.pool.QueryRow(context.Background(), `select count(*) filter (where device_meta is not null), count(*) filter (where device_meta is null) from support_conversations`).Scan(&withMeta, &without)
	if withMeta != 1 || without != 1 {
		t.Fatalf("device_meta stored without consent? with=%d without=%d", withMeta, without)
	}
	var cid string
	_ = e.pool.QueryRow(context.Background(), `select id from support_conversations where device_meta is not null`).Scan(&cid)
	st, d := e.opCall(agent, "GET", "/admin/v1/support/conversations/"+cid, nil)
	meta, _ := d["device_meta"].(map[string]any)
	if st != 200 || meta["model"] != "Pixel 7" || meta["market"] != "bazaar" {
		t.Fatalf("detail: %d %v", st, d)
	}
	if ent, _ := d["entitlement"].(map[string]any); ent["premium"] != false {
		t.Fatalf("entitlement: %v", d["entitlement"])
	}
	// the agent cannot grant promos or edit canned replies; the admin can; everything is audited
	grant := map[string]any{"days": 7, "reason": "purchase glitch"}
	uid := d["user_id"].(string)
	if st, m := e.opCall(agent, "POST", "/admin/v1/support/users/"+uid+"/grant", grant); st != 403 || errCode(m) != "FORBIDDEN" {
		t.Fatalf("agent grant: %d %v", st, m)
	}
	if st, _ := e.opCall(agent, "PUT", "/admin/v1/support/canned/x", map[string]any{"title": "t", "body": "b"}); st != 403 {
		t.Fatalf("agent canned: %d", st)
	}
	if st, m := e.opCall(boss, "POST", "/admin/v1/support/users/"+uid+"/grant", grant); st != 201 {
		t.Fatalf("admin grant: %d %v", st, m)
	}
	if _, d2 := e.opCall(boss, "GET", "/admin/v1/support/conversations/"+cid, nil); d2["entitlement"].(map[string]any)["premium"] != true {
		t.Fatalf("grant not visible: %v", d2["entitlement"])
	}
	if st, _ := e.opCall(boss, "PUT", "/admin/v1/support/canned/extra", map[string]any{"title": "عنوان", "body": "متن {market}"}); st != 204 {
		t.Fatalf("admin canned put: %d", st)
	}
	if _, c := e.opCall(agent, "GET", "/admin/v1/support/canned", nil); len(c["canned"].([]any)) < 7 {
		t.Fatalf("canned (6 seeds + 1): %v", c)
	}
	e.opCall(agent, "POST", "/admin/v1/support/conversations/"+cid+"/messages", map[string]any{"body": "جواب"})
	rows, _ := e.pool.Query(context.Background(), `select actor, action, payload::text from admin_audit where actor like 'operator:%' order by id`)
	defer rows.Close()
	var actions []string
	for rows.Next() {
		var actor, action, payload string
		_ = rows.Scan(&actor, &action, &payload)
		actions = append(actions, actor+" "+action)
		if strings.Contains(payload, "جواب") {
			t.Fatalf("audit payload leaks the message text: %s", payload)
		}
	}
	for _, want := range []string{"operator:agent1 support.login", "operator:boss support.grant.promo", "operator:boss support.canned.put", "operator:agent1 support.reply"} {
		found := false
		for _, a := range actions {
			found = found || a == want
		}
		if !found {
			t.Fatalf("audit is missing %q in %v", want, actions)
		}
	}
}

func TestOperatorAuthSessionCSRFAndIPGuard(t *testing.T) {
	e := newEnv(t)
	e.addOperator("sara", "agent")
	if st, _ := e.opLogin("sara", "wrong-password-here"); st != 401 {
		t.Fatalf("wrong password: %d", st)
	}
	if st, _ := e.opLogin("nobody", "correct-horse-battery"); st != 401 {
		t.Fatalf("unknown user: %d", st)
	}
	if st, _, _ := e.callH("POST", "/admin/v1/support/login", "", map[string]any{"username": "sara", "password": "correct-horse-battery"}, "8.8.8.8", nil); st != 403 {
		t.Fatalf("outside the allowlist: %d", st)
	}
	st, s := e.opLogin("sara", "correct-horse-battery")
	if st != 200 || s.cookie == "" || s.csrf == "" {
		t.Fatalf("login: %d %+v", st, s)
	}
	// cookie flags (HttpOnly, SameSite=Strict)
	_, hdr, _ := e.callH("POST", "/admin/v1/support/login", "", map[string]any{"username": "sara", "password": "correct-horse-battery"}, opIP, nil)
	ck := strings.Join(hdr.Values("Set-Cookie"), ";")
	if !strings.Contains(ck, "HttpOnly") || !strings.Contains(ck, "SameSite=Strict") {
		t.Fatalf("cookie flags: %s", ck)
	}
	// no session → 401; state-changing call without/with a wrong CSRF token → 403; GET needs none
	if st, _, _ := e.callH("GET", "/admin/v1/support/me", "", nil, opIP, nil); st != 401 {
		t.Fatalf("no session: %d", st)
	}
	if st, _, _ := e.callH("POST", "/admin/v1/support/logout", "", nil, opIP, map[string]string{"Cookie": "op_session=" + s.cookie}); st != 403 {
		t.Fatalf("missing csrf: %d", st)
	}
	if st, _ := e.opCall(opSession{cookie: s.cookie, csrf: "wrong"}, "POST", "/admin/v1/support/logout", nil); st != 403 {
		t.Fatalf("wrong csrf: %d", st)
	}
	if st, _, m := e.callH("GET", "/admin/v1/support/me", "", nil, opIP, map[string]string{"Cookie": "op_session=" + s.cookie}); st != 200 || m["role"] != "agent" {
		t.Fatalf("me: %d %v", st, m)
	}
	// logout kills the session; a disabled operator's sessions die too
	if st, _ := e.opCall(s, "POST", "/admin/v1/support/logout", nil); st != 204 {
		t.Fatal(st)
	}
	if st, _ := e.opCall(s, "GET", "/admin/v1/support/me", nil); st != 401 {
		t.Fatalf("after logout: %d", st)
	}
	_, s2 := e.opLogin("sara", "correct-horse-battery")
	if err := support.SetOperatorActive(context.Background(), e.pool, e.clk, "sara", false); err != nil {
		t.Fatal(err)
	}
	if st, _ := e.opCall(s2, "GET", "/admin/v1/support/me", nil); st != 401 {
		t.Fatalf("disabled operator keeps a session: %d", st)
	}
	if st, _ := e.opLogin("sara", "correct-horse-battery"); st != 401 {
		t.Fatalf("disabled operator can log in: %d", st)
	}
	// expiry
	_ = support.SetOperatorActive(context.Background(), e.pool, e.clk, "sara", true)
	_, s3 := e.opLogin("sara", "correct-horse-battery")
	e.clk.Advance(13 * time.Hour)
	if st, _ := e.opCall(s3, "GET", "/admin/v1/support/me", nil); st != 401 {
		t.Fatalf("expired session: %d", st)
	}
	// brute force: the login limiter kicks in
	limited := false
	for i := 0; i < 15 && !limited; i++ {
		st, _ := e.opLogin("sara", "bad-password-attempt")
		limited = st == 429
	}
	if !limited {
		t.Fatal("login attempts are not rate limited")
	}
	// static panel: strict CSP, no external resources
	req := httptest.NewRequest("GET", "/admin/support/", nil)
	req.RemoteAddr = opIP + ":1"
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 200 || !strings.Contains(rec.Header().Get("Content-Security-Policy"), "default-src 'self'") {
		t.Fatalf("panel page: %d csp=%q", rec.Code, rec.Header().Get("Content-Security-Policy"))
	}
	if body := rec.Body.String(); strings.Contains(body, "http://") || strings.Contains(body, "https://") || strings.Contains(body, "<style") {
		t.Fatalf("panel page references external or inline resources")
	}
	req = httptest.NewRequest("GET", "/admin/support/", nil)
	req.RemoteAddr = "8.8.8.8:1"
	rec = httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	if rec.Code != 403 {
		t.Fatalf("panel outside allowlist: %d", rec.Code)
	}
}

func TestSupportHoursKillSwitchAndDeletion(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("sup-d1")
	// outside hours: the message is accepted, the app is told when support is back
	e.scfg.set(func(c *support.Config) {
		c.Hours = []support.Hours{{Weekday: 0, From: "09:00", To: "21:00"}}
	})
	_, info := e.call("GET", "/v1/support/conversation", u.token, nil, "")
	if _, has := info["next_online_at"]; info["online"] != false || !has {
		t.Fatalf("outside hours: %v", info)
	}
	if st, _ := e.userSend(u, "پیام خارج از ساعت", uuid.New(), false); st != 200 {
		t.Fatalf("outside hours must still accept messages: %d", st)
	}
	e.onlineHours()
	if _, info := e.call("GET", "/v1/support/conversation", u.token, nil, ""); info["online"] != true {
		t.Fatalf("online: %v", info)
	}
	// kill switch
	e.scfg.set(func(c *support.Config) { c.Enabled = false })
	if st, m := e.userSend(u, "x", uuid.New(), false); st != 503 || errCode(m) != "SUPPORT_DISABLED" {
		t.Fatalf("disabled send: %d %v", st, m)
	}
	if st, m := e.call("GET", "/v1/support/conversation", u.token, nil, ""); st != 503 || errCode(m) != "SUPPORT_DISABLED" {
		t.Fatalf("disabled conversation: %d %v", st, m)
	}
	// "clear conversation" works even when disabled
	if st, _ := e.call("DELETE", "/v1/support/conversation", u.token, nil, ""); st != 204 {
		t.Fatal(st)
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_messages`).Scan(&n)
	if n != 0 {
		t.Fatalf("messages left after delete: %d", n)
	}
	// account deletion removes the conversation too
	e.scfg.set(func(c *support.Config) { c.Enabled = true })
	e.userSend(u, "قبل از حذف حساب", uuid.New(), true)
	if st, _ := e.call("DELETE", "/v1/me", u.token, nil, ""); st != 204 {
		t.Fatal(st)
	}
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_conversations`).Scan(&n)
	if n != 0 {
		t.Fatalf("conversations left after DELETE /v1/me: %d", n)
	}
	// retention: closed conversations older than 12 months are pruned, recent ones stay
	u2 := e.newUser("sup-d2")
	e.addOperator("sara", "agent")
	_, op := e.opLogin("sara", "correct-horse-battery")
	e.userSend(u2, "قدیمی", uuid.New(), false)
	var cid string
	_ = e.pool.QueryRow(context.Background(), `select id from support_conversations`).Scan(&cid)
	e.opCall(op, "POST", "/admin/v1/support/conversations/"+cid+"/close", map[string]any{})
	if err := e.sup.Prune(context.Background()); err != nil {
		t.Fatal(err)
	}
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_conversations`).Scan(&n)
	if n != 1 {
		t.Fatalf("a fresh closed conversation must not be pruned: %d", n)
	}
	e.clk.Advance(13 * 30 * 24 * time.Hour)
	if err := e.sup.Prune(context.Background()); err != nil {
		t.Fatal(err)
	}
	_ = e.pool.QueryRow(context.Background(), `select count(*) from support_conversations`).Scan(&n)
	if n != 0 {
		t.Fatalf("old closed conversation survived retention: %d", n)
	}
}

func (e *env) server() *httptest.Server {
	if e.srv == nil {
		e.srv = httptest.NewServer(e.h)
		e.t.Cleanup(e.srv.Close)
	}
	return e.srv
}

func wsURL(s *httptest.Server, path string) string {
	return "ws" + strings.TrimPrefix(s.URL, "http") + path
}

func readFrame(t *testing.T, ctx context.Context, c *websocket.Conn) map[string]any {
	t.Helper()
	rctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	_, data, err := c.Read(rctx)
	if err != nil {
		t.Fatalf("read frame: %v", err)
	}
	var m map[string]any
	_ = json.Unmarshal(data, &m)
	return m
}

func TestSupportRealtimeWebSocketBothDirections(t *testing.T) {
	e := newEnv(t)
	e.onlineHours()
	u := e.newUser("sup-ws1")
	other := e.newUser("sup-ws2")
	e.addOperator("sara", "agent")
	_, op := e.opLogin("sara", "correct-horse-battery")
	ctx := context.Background()
	srv := e.server()

	// bad / missing auth → close 4401 (the token is never in the URL)
	bad, _, err := websocket.Dial(ctx, wsURL(srv, "/v1/support/ws"), nil)
	if err != nil {
		t.Fatal(err)
	}
	_ = bad.Write(ctx, websocket.MessageText, []byte(`{"type":"auth","token":"nope"}`))
	_, _, err = bad.Read(ctx)
	if websocket.CloseStatus(err) != support.CloseUnauthorized {
		t.Fatalf("bad token close status = %v (%v)", websocket.CloseStatus(err), err)
	}

	dial := func(token string) *websocket.Conn {
		c, _, err := websocket.Dial(ctx, wsURL(srv, "/v1/support/ws"), nil)
		if err != nil {
			t.Fatal(err)
		}
		_ = c.Write(ctx, websocket.MessageText, []byte(`{"type":"auth","token":"`+token+`"}`))
		if f := readFrame(t, ctx, c); f["type"] != "ready" {
			t.Fatalf("expected ready, got %v", f)
		}
		t.Cleanup(func() { _ = c.CloseNow() })
		return c
	}
	userWS, otherWS := dial(u.token), dial(other.token)

	// operator panel socket (cookie auth, same origin)
	hdr := http.Header{"Cookie": {"op_session=" + op.cookie}}
	opWS, _, err := websocket.Dial(ctx, wsURL(srv, "/admin/v1/support/ws"), &websocket.DialOptions{HTTPHeader: hdr})
	if err != nil {
		t.Fatalf("operator ws: %v", err)
	}
	defer opWS.CloseNow()

	// user → operator, well under 2 seconds
	start := time.Now()
	e.userSend(u, "پیام زنده از کاربر", uuid.New(), false)
	f := readFrame(t, ctx, opWS)
	msg := f["message"].(map[string]any)
	if f["type"] != "message.new" || msg["body"] != "پیام زنده از کاربر" || msg["sender"] != "user" {
		t.Fatalf("operator frame: %v", f)
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("user→operator latency %v", d)
	}
	convID := f["conversation_id"].(string)

	// operator → user
	start = time.Now()
	e.opCall(op, "POST", "/admin/v1/support/conversations/"+convID+"/messages", map[string]any{"body": "جواب زنده"})
	uf := readFrame(t, ctx, userWS)
	if m0 := uf["message"].(map[string]any); m0["sender"] == "user" {
		uf = readFrame(t, ctx, userWS) // the user's own message is echoed first (other devices of the same user see it)
	}
	if m := uf["message"].(map[string]any); uf["type"] != "message.new" || m["body"] != "جواب زنده" || m["sender"] != "operator" {
		t.Fatalf("user frame: %v", uf)
	}
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("operator→user latency %v", d)
	}
	// the other user never sees this conversation's events
	rctx, cancel := context.WithTimeout(ctx, 400*time.Millisecond)
	defer cancel()
	if _, _, err := otherWS.Read(rctx); err == nil {
		t.Fatal("a different user received someone else's chat event")
	}
	// JSON ping → pong
	_ = userWS.Write(ctx, websocket.MessageText, []byte(`{"type":"ping"}`))
	if f := readFrame(t, ctx, userWS); f["type"] != "pong" {
		t.Fatalf("pong: %v", f)
	}
	// kill switch closes new sockets with 4503
	e.scfg.set(func(c *support.Config) { c.Enabled = false })
	c, _, _ := websocket.Dial(ctx, wsURL(srv, "/v1/support/ws"), nil)
	_ = c.Write(ctx, websocket.MessageText, []byte(`{"type":"auth","token":"`+u.token+`"}`))
	_, _, err = c.Read(ctx)
	if websocket.CloseStatus(err) != support.CloseDisabled {
		t.Fatalf("disabled close status = %v", websocket.CloseStatus(err))
	}
	// the operator socket rejects cross-origin browsers
	_, resp, err := websocket.Dial(ctx, wsURL(srv, "/admin/v1/support/ws"), &websocket.DialOptions{HTTPHeader: http.Header{"Cookie": hdr["Cookie"], "Origin": {"https://evil.example"}}})
	if err == nil || resp == nil || resp.StatusCode != 403 {
		t.Fatalf("cross-origin operator socket must be refused: err=%v resp=%v", err, resp)
	}
}

type captureHandler struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

func (c *captureHandler) Enabled(context.Context, slog.Level) bool { return true }
func (c *captureHandler) Handle(_ context.Context, r slog.Record) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.buf.WriteString(r.Message)
	r.Attrs(func(a slog.Attr) bool { c.buf.WriteString(" " + a.Key + "=" + a.Value.String()); return true })
	c.buf.WriteString("\n")
	return nil
}
func (c *captureHandler) WithAttrs([]slog.Attr) slog.Handler { return c }
func (c *captureHandler) WithGroup(string) slog.Handler      { return c }

func TestSupportNeverLogsMessageText(t *testing.T) {
	cap := &captureHandler{}
	prev := slog.Default()
	slog.SetDefault(slog.New(cap))
	t.Cleanup(func() { slog.SetDefault(prev) })

	e := newEnv(t)
	u := e.newUser("sup-log")
	e.addOperator("sara", "agent")
	_, op := e.opLogin("sara", "correct-horse-battery")
	secretUser, secretOp := "رمز-خیلی-محرمانه-کاربر-۴۲", "پاسخ-محرمانه-اپراتور-۷۷"
	e.userSend(u, secretUser, uuid.New(), false)
	_, q := e.opCall(op, "GET", "/admin/v1/support/conversations", nil)
	cid := q["conversations"].([]any)[0].(map[string]any)["id"].(string)
	e.opCall(op, "POST", "/admin/v1/support/conversations/"+cid+"/messages", map[string]any{"body": secretOp})
	e.opCall(op, "GET", "/admin/v1/support/conversations/"+cid+"/messages", nil)
	e.call("GET", "/v1/support/messages", u.token, nil, "")
	e.userSend(u, strings.Repeat("آ", 3000), uuid.New(), false) // an error path, too
	time.Sleep(150 * time.Millisecond)
	cap.mu.Lock()
	logs := cap.buf.String()
	cap.mu.Unlock()
	for _, s := range []string{secretUser, secretOp, "correct-horse-battery"} {
		if strings.Contains(logs, s) {
			t.Fatalf("server logs contain %q", s)
		}
	}
	if !strings.Contains(logs, "request") {
		t.Fatal("log capture did not work (no request lines)")
	}
}
