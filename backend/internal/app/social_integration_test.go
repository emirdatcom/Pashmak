package app_test

import (
	"context"
	"strings"
	"testing"
)

func TestSocialFriendsAndVibes(t *testing.T) {
	e := newEnv(t)
	a, b, c := e.newUser("soc-a"), e.newUser("soc-b"), e.newUser("soc-c")

	st, me := e.call("GET", "/v1/social/me", a.token, nil, "")
	codeA, _ := me["friend_code"].(string)
	if st != 200 || len(codeA) != 8 {
		t.Fatalf("me: %d %v", st, me)
	}
	if _, again := e.call("GET", "/v1/social/me", a.token, nil, ""); again["friend_code"] != codeA {
		t.Fatalf("friend code must be stable: %v", again)
	}
	if st, m := e.call("PUT", "/v1/social/me", a.token, map[string]any{"nickname": "سارا", "cat_name": "پشمک", "cat_fur": "smokeGray", "cat_stage": "young", "cat_hue": 40}, ""); st != 200 || m["cat_fur"] != "smokeGray" {
		t.Fatalf("update: %d %v", st, m)
	}
	if st, m := e.call("PUT", "/v1/social/me", a.token, map[string]any{"nickname": "x", "cat_name": "y", "cat_fur": "gold", "cat_stage": "young", "cat_hue": 0}, ""); st != 400 || errCode(m) != "INVALID_INPUT" {
		t.Fatalf("bad fur: %d %v", st, m)
	}

	// unknown code, own code
	if st, m := e.call("POST", "/v1/social/friends", b.token, map[string]any{"code": "ZZZZZZZZ"}, ""); st != 404 || errCode(m) != "FRIEND_CODE_INVALID" {
		t.Fatalf("unknown code: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/social/friends", a.token, map[string]any{"code": codeA}, ""); st != 404 || errCode(m) != "FRIEND_CODE_INVALID" {
		t.Fatalf("own code: %d %v", st, m)
	}
	// b adds a (lower case, dashes): mutual and idempotent
	messy := strings.ToLower(codeA[:4]) + "-" + codeA[4:]
	if st, m := e.call("POST", "/v1/social/friends", b.token, map[string]any{"code": messy}, ""); st != 200 || m["nickname"] != "سارا" || m["cat_name"] != "پشمک" {
		t.Fatalf("add: %d %v", st, m)
	}
	if st, _ := e.call("POST", "/v1/social/friends", b.token, map[string]any{"code": codeA}, ""); st != 200 {
		t.Fatalf("add again: %d", st)
	}
	_, fa := e.call("GET", "/v1/social/friends", a.token, nil, "")
	if l := fa["friends"].([]any); len(l) != 1 {
		t.Fatalf("a's friends: %v", fa)
	}
	_, meB := e.call("GET", "/v1/social/me", b.token, nil, "")
	codeB := meB["friend_code"].(string)

	// vibes: only to friends, once per day
	_, meC := e.call("GET", "/v1/social/me", c.token, nil, "")
	if st, m := e.call("POST", "/v1/social/vibes", a.token, map[string]any{"to": meC["friend_code"], "kind": "hug"}, ""); st != 403 || errCode(m) != "FORBIDDEN" {
		t.Fatalf("vibe to a stranger: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/social/vibes", a.token, map[string]any{"to": codeB, "kind": "rocket"}, ""); st != 400 {
		t.Fatalf("bad kind: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/social/vibes", a.token, map[string]any{"to": codeB, "kind": "hug"}, ""); st != 204 {
		t.Fatalf("send: %d %v", st, m)
	}
	if st, m := e.call("POST", "/v1/social/vibes", a.token, map[string]any{"to": codeB, "kind": "sun"}, ""); st != 409 || errCode(m) != "VIBE_ALREADY_SENT" {
		t.Fatalf("second vibe same day: %d %v", st, m)
	}
	_, fa = e.call("GET", "/v1/social/friends", a.token, nil, "")
	if f := fa["friends"].([]any)[0].(map[string]any); f["vibed_today"] != true || f["friend_code"] != codeB {
		t.Fatalf("vibed_today: %v", f)
	}
	_, vb := e.call("GET", "/v1/social/vibes", b.token, nil, "")
	v := vb["vibes"].([]any)
	if len(v) != 1 || v[0].(map[string]any)["kind"] != "hug" || v[0].(map[string]any)["unread"] != true || v[0].(map[string]any)["from_code"] != codeA {
		t.Fatalf("inbox: %v", vb)
	}
	if st, _ := e.call("POST", "/v1/social/vibes/read", b.token, nil, ""); st != 204 {
		t.Fatalf("read: %d", st)
	}
	if _, vb := e.call("GET", "/v1/social/vibes", b.token, nil, ""); vb["vibes"].([]any)[0].(map[string]any)["unread"] != false {
		t.Fatalf("after read: %v", vb)
	}
	// a vibe from yesterday (Tehran day) does not block today's
	if _, err := e.pool.Exec(context.Background(), `update vibes set day = day - 1`); err != nil {
		t.Fatal(err)
	}
	if st, m := e.call("POST", "/v1/social/vibes", a.token, map[string]any{"to": codeB, "kind": "tea"}, ""); st != 204 {
		t.Fatalf("next day: %d %v", st, m)
	}

	// remove: both sides lose the friendship, vibes stop
	if st, _ := e.call("DELETE", "/v1/social/friends/"+codeA, b.token, nil, ""); st != 204 {
		t.Fatalf("remove: %d", st)
	}
	if _, fa := e.call("GET", "/v1/social/friends", a.token, nil, ""); len(fa["friends"].([]any)) != 0 {
		t.Fatalf("removed on both sides: %v", fa)
	}

	// account deletion wipes the profile; the code then no longer resolves
	e.call("POST", "/v1/social/friends", c.token, map[string]any{"code": codeA}, "")
	if st, _ := e.call("DELETE", "/v1/me", a.token, nil, ""); st != 204 {
		t.Fatalf("delete account: %d", st)
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select (select count(*) from social_profiles where friend_code=$1) + (select count(*) from friendships) + (select count(*) from vibes)`, codeA).Scan(&n)
	if n != 0 {
		t.Fatalf("social rows left after deletion: %d", n)
	}
	if st, m := e.call("POST", "/v1/social/friends", b.token, map[string]any{"code": codeA}, ""); st != 404 || errCode(m) != "FRIEND_CODE_INVALID" {
		t.Fatalf("deleted user's code: %d %v", st, m)
	}
}
