package app_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

const (
	phoneA   = "09121234567"
	e164A    = "+989121234567"
	persianA = "۰۹۱۲۱۲۳۴۵۶۷"
)

func (e *env) otp(u tuser, phone string) (int, map[string]any) {
	return e.call("POST", "/v1/auth/phone/otp", u.token, map[string]any{"phone": phone}, "")
}

func (e *env) verifyOTP(u tuser, challenge, code string) (int, map[string]any) {
	return e.call("POST", "/v1/auth/phone/verify", u.token, map[string]any{"challenge_id": challenge, "code": code}, "")
}

func TestPhoneLinkWithPersianDigitsAndWrongCodes(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-ph1")
	st, m := e.otp(u, persianA)
	if st != 200 || m["retry_after_s"].(float64) != 60 {
		t.Fatalf("otp: %d %v", st, m)
	}
	code := e.sms.code(e300(e164A))
	if len(code) != 5 {
		t.Fatalf("code %q (normalized number must be %s)", code, e164A)
	}
	ch := m["challenge_id"].(string)
	wrong := "00000"
	if code == wrong {
		wrong = "11111"
	}
	if st, m := e.verifyOTP(u, ch, wrong); st != 400 || errCode(m) != "OTP_INVALID" {
		t.Fatalf("wrong code: %d %v", st, m)
	}
	st, m = e.verifyOTP(u, ch, code)
	if st != 200 || m["merged"] != false || m["user_id"] != u.id {
		t.Fatalf("verify: %d %v", st, m)
	}
	if st, me := e.call("GET", "/v1/me", u.token, nil, ""); st != 200 || me["phone_linked"] != true {
		t.Fatalf("phone_linked: %d %v", st, me)
	}
	// The challenge is single-use.
	if st, m := e.verifyOTP(u, ch, code); st != 400 || errCode(m) != "OTP_INVALID" {
		t.Fatalf("reuse: %d %v", st, m)
	}
	// Stored encrypted + hashed; only the last 4 digits are readable.
	var enc []byte
	var hash, last4 string
	if err := e.pool.QueryRow(context.Background(), `select phone_enc, phone_hash, phone_last4 from users where id=$1`, u.id).Scan(&enc, &hash, &last4); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(enc, []byte("9121234567")) || strings.Contains(hash, "9121234567") || last4 != "4567" {
		t.Fatalf("phone storage: enc=%x hash=%s last4=%s", enc, hash, last4)
	}
	// Admin sees only the last four digits.
	st, adm := e.adm("GET", "/admin/v1/users/"+u.id, nil)
	if st != 200 || adm["phone_last4"] != "4567" || strings.Contains(strings.ReplaceAll(strings.ToLower(toJSON(adm)), " ", ""), "9121234567") {
		t.Fatalf("admin view: %d %v", st, adm)
	}
}

func e300(s string) string { return s } // readability: the SMS recorder is keyed by E.164

func toJSON(v any) string {
	var b bytes.Buffer
	_ = jsonEncoder(&b, v)
	return b.String()
}

func TestOTPAttemptsExpiryAndRateLimits(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-ph2")
	if st, m := e.otp(u, "12345"); st != 400 || errCode(m) != "PHONE_INVALID" {
		t.Fatalf("invalid phone: %d %v", st, m)
	}
	_, m := e.otp(u, phoneA)
	ch := m["challenge_id"].(string)
	code := e.sms.code(e164A)
	// Resend cooldown, then the hourly cap of 3 per number.
	if st, m := e.otp(u, phoneA); st != 429 || errCode(m) != "RATE_LIMITED" {
		t.Fatalf("cooldown: %d %v", st, m)
	}
	// 5 wrong attempts kill the challenge even if the next try has the right code.
	wrong := "00000"
	if code == wrong {
		wrong = "11111"
	}
	for i := 0; i < 5; i++ {
		if st, _ := e.verifyOTP(u, ch, wrong); st != 400 {
			t.Fatalf("attempt %d: %d", i, st)
		}
	}
	if st, m := e.verifyOTP(u, ch, code); st != 400 || errCode(m) != "OTP_INVALID" {
		t.Fatalf("after 5 wrong attempts the right code must fail: %d %v", st, m)
	}
	for i := 0; i < 2; i++ {
		e.clk.Advance(61 * time.Second)
		if st, m := e.otp(u, phoneA); st != 200 {
			t.Fatalf("request %d: %d %v", i+2, st, m)
		}
	}
	e.clk.Advance(61 * time.Second)
	if st, m := e.otp(u, phoneA); st != 429 {
		t.Fatalf("4th request in an hour must be limited: %d %v", st, m)
	}
	// Expiry: a fresh challenge is dead after 2 minutes.
	e.clk.Advance(2 * time.Hour)
	e.relogin(&u)
	_, m = e.otp(u, phoneA)
	code = e.sms.code(e164A)
	e.clk.Advance(2*time.Minute + time.Second)
	if st, m := e.verifyOTP(u, m["challenge_id"].(string), code); st != 400 || errCode(m) != "OTP_EXPIRED" {
		t.Fatalf("expired: %d %v", st, m)
	}
	// Another user cannot use my challenge.
	other := e.newUser("hw-ph3")
	e.clk.Advance(time.Hour)
	e.relogin(&u)
	e.relogin(&other)
	_, m = e.otp(u, phoneA)
	if st, m2 := e.verifyOTP(other, m["challenge_id"].(string), e.sms.code(e164A)); st != 400 || errCode(m2) != "OTP_INVALID" {
		t.Fatalf("foreign challenge: %d %v", st, m2)
	}
	// Provider outage: SMS_UNAVAILABLE and the user is not penalized.
	e.sms.fail = true
	e.clk.Advance(time.Hour)
	e.relogin(&u)
	if st, m := e.otp(u, phoneA); st != 503 || errCode(m) != "SMS_UNAVAILABLE" {
		t.Fatalf("outage: %d %v", st, m)
	}
}

func put(e *env, u tuser, blob []byte, schema string, sha string, kdf string) (int, map[string]any) {
	st, _, m := e.callH("PUT", "/v1/backup", u.token, blob, "", map[string]string{
		"X-Backup-Schema": schema, "X-Backup-Sha256": sha, "X-Kdf-Params": kdf})
	return st, m
}

func sum(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}

const kdfOK = `{"alg":"argon2id","m":65536,"t":3,"p":1,"salt":"c2FsdA"}`

func TestBackupPutGetDeleteAndLimits(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-bk")
	blob := bytes.Repeat([]byte{0xAB, 0xCD}, 1000)
	if st, m := put(e, u, blob, "3", "deadbeef", kdfOK); st != 400 || errCode(m) != "INVALID_INPUT" {
		t.Fatalf("bad sha: %d %v", st, m)
	}
	if st, m := put(e, u, blob, "3", sum(blob), `{"alg":"md5"}`); st != 400 {
		t.Fatalf("bad kdf: %d %v", st, m)
	}
	if st, m := put(e, u, blob, "0", sum(blob), kdfOK); st != 400 {
		t.Fatalf("bad schema: %d %v", st, m)
	}
	if st, m := e.call("GET", "/v1/backup", u.token, nil, ""); st != 404 {
		t.Fatalf("no backup yet: %d %v", st, m)
	}
	st, m := put(e, u, blob, "3", sum(blob), kdfOK)
	if st != 200 || m["updated_at"] == nil {
		t.Fatalf("put: %d %v", st, m)
	}
	// Byte-exact round trip with metadata headers.
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/v1/backup", nil)
	req.Header.Set("Authorization", "Bearer "+u.token)
	e.h.ServeHTTP(rec, req)
	if rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), blob) || rec.Header().Get("X-Backup-Schema") != "3" ||
		rec.Header().Get("X-Backup-Sha256") != sum(blob) || !strings.Contains(rec.Header().Get("X-Kdf-Params"), "argon2id") {
		t.Fatalf("get: %d %v", rec.Code, rec.Header())
	}
	// Only the latest version is kept.
	blob2 := []byte("second snapshot")
	if st, _ := put(e, u, blob2, "3", sum(blob2), kdfOK); st != 200 {
		t.Fatal("second put")
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from backups where user_id=$1`, u.id).Scan(&n)
	if n != 1 {
		t.Fatalf("rows=%d", n)
	}
	// Too large: 413 BACKUP_TOO_LARGE (checked from Content-Length before reading).
	big := bytes.Repeat([]byte{1}, 5<<20+1)
	if st, m := put(e, u, big, "3", sum(big), kdfOK); st != 413 || errCode(m) != "BACKUP_TOO_LARGE" {
		t.Fatalf("too large: %d %v", st, m)
	}
	// Exactly 5 MB (the default BACKUP_MAX_BYTES) is fine.
	limit := bytes.Repeat([]byte{2}, 5<<20)
	if st, m := put(e, u, limit, "3", sum(limit), kdfOK); st != 200 {
		t.Fatalf("5MB: %d %v", st, m)
	}
	// DELETE is idempotent.
	for i := 0; i < 2; i++ {
		if st, _ := e.call("DELETE", "/v1/backup", u.token, nil, ""); st != 204 {
			t.Fatalf("delete #%d", i)
		}
	}
	if st, _ := e.call("GET", "/v1/backup", u.token, nil, ""); st != 404 {
		t.Fatal("deleted backup must 404")
	}
	// Auth required.
	if st, _ := e.call("GET", "/v1/backup", "", nil, ""); st != 401 {
		t.Fatal("auth")
	}
}

func TestBackupDailyLimitAndAccountDeletion(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-bk2")
	blob := []byte("x")
	for i := 0; i < 20; i++ {
		if st, m := put(e, u, blob, "1", sum(blob), kdfOK); st != 200 {
			t.Fatalf("put %d: %d %v", i, st, m)
		}
	}
	if st, m := put(e, u, blob, "1", sum(blob), kdfOK); st != 429 || errCode(m) != "RATE_LIMITED" {
		t.Fatalf("21st put: %d %v", st, m)
	}
	if st, _ := e.call("DELETE", "/v1/me", u.token, nil, ""); st != 204 {
		t.Fatal("delete account")
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from backups where user_id=$1`, u.id).Scan(&n)
	if n != 0 {
		t.Fatalf("backup must be deleted with the account, rows=%d", n)
	}
}

func TestNewDeviceRestoreFlowMergesAccounts(t *testing.T) {
	e := newEnv(t)
	// Old phone: account A links its number, owns a purchase and a backup.
	a := e.newUser("hw-old")
	_, m := e.otp(a, phoneA)
	e.verifyOTP(a, m["challenge_id"].(string), e.sms.code(e164A))
	e.verify(a, "premium_3m", "test_valid_old_phone")
	blob := []byte("A's encrypted snapshot")
	if st, _ := put(e, a, blob, "2", sum(blob), kdfOK); st != 200 {
		t.Fatal("backup")
	}

	// New phone: fresh anonymous user B starts a trial and buys coins, then verifies A's number.
	b := e.newUser("hw-new")
	if st, _ := e.call("POST", "/v1/trial/start", b.token, nil, ""); st != 200 {
		t.Fatal("B trial")
	}
	e.clk.Advance(2 * time.Minute) // OTP cooldown is per number
	_, m = e.otp(b, phoneA)
	st, res := e.verifyOTP(b, m["challenge_id"].(string), e.sms.code(e164A))
	if st != 200 || res["merged"] != true || res["user_id"] != a.id {
		t.Fatalf("merge verify: %d %v", st, res)
	}
	asA := tuser{token: res["access_token"].(string), id: a.id}
	// Requests are now A: backup visible, purchase kept, trial NOT transferred from B.
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/v1/backup", nil)
	req.Header.Set("Authorization", "Bearer "+asA.token)
	e.h.ServeHTTP(rec, req)
	if rec.Code != 200 || !bytes.Equal(rec.Body.Bytes(), blob) {
		t.Fatalf("restore blob: %d", rec.Code)
	}
	s, _ := e.state(asA)
	var sources []string
	for _, en := range s.Entitlements {
		sources = append(sources, en.Source)
	}
	if len(sources) != 1 || sources[0] != "pass" {
		t.Fatalf("A must keep its purchase and not receive B's trial: %v", sources)
	}
	// The old B tokens are dead, the refresh token for A works, B is retired.
	if st, _ := e.call("GET", "/v1/me", b.token, nil, ""); st != 401 {
		t.Fatalf("B's old access token must stop working once B is retired: %d", st)
	}
	if st, _ := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": res["refresh_token"]}, ""); st != 200 {
		t.Fatalf("A's refresh: %d", st)
	}
	var status string
	_ = e.pool.QueryRow(context.Background(), `select status from users where id=$1`, b.id).Scan(&status)
	if status != "deleted" {
		t.Fatalf("B should be retired, status=%s", status)
	}
}

func TestMergeTransfersBPurchasesToA(t *testing.T) {
	e := newEnv(t)
	a := e.newUser("hw-ma")
	_, m := e.otp(a, phoneA)
	e.verifyOTP(a, m["challenge_id"].(string), e.sms.code(e164A))
	b := e.newUser("hw-mb")
	e.verify(b, "premium_1m", "test_valid_b_bought")
	e.clk.Advance(2 * time.Minute)
	_, m = e.otp(b, phoneA)
	_, res := e.verifyOTP(b, m["challenge_id"].(string), e.sms.code(e164A))
	asA := tuser{token: res["access_token"].(string), id: a.id}
	if s, _ := e.state(asA); len(s.Entitlements) != 1 || s.Entitlements[0].Source != "pass" {
		t.Fatalf("B's purchase should move to A: %+v", s)
	}
	var n int
	_ = e.pool.QueryRow(context.Background(), `select count(*) from purchases where user_id=$1`, a.id).Scan(&n)
	if n != 1 {
		t.Fatalf("purchases of A: %d", n)
	}
}

func jsonEncoder(b *bytes.Buffer, v any) error { return json.NewEncoder(b).Encode(v) }

// One device of a two-device account moves to another account by phone: only that device's sessions end.
func TestMergeKeepsTheOtherDevicesOfTheLeavingAccountSignedIn(t *testing.T) {
	e := newEnv(t)
	const phoneX, e164X = "09125550001", "+989125550001"
	const phoneZ, e164Z = "09125550002", "+989125550002"
	// X owns phoneX on device 1; device 2 (a new install) joins X by verifying phoneX.
	x := e.newUser("hw-x1")
	_, m := e.otp(x, phoneX)
	e.verifyOTP(x, m["challenge_id"].(string), e.sms.code(e164X))
	d2 := e.newUser("hw-x2")
	e.clk.Advance(2 * time.Minute)
	_, m = e.otp(d2, phoneX)
	st, joined := e.verifyOTP(d2, m["challenge_id"].(string), e.sms.code(e164X))
	if st != 200 || joined["merged"] != true || joined["user_id"] != x.id {
		t.Fatalf("device 2 joins X: %d %v", st, joined)
	}
	d2refresh := joined["refresh_token"].(string)
	// Z owns phoneZ; device 1 (still X) verifies phoneZ and moves to Z.
	z := e.newUser("hw-z")
	_, m = e.otp(z, phoneZ)
	e.verifyOTP(z, m["challenge_id"].(string), e.sms.code(e164Z))
	e.clk.Advance(2 * time.Minute)
	_, m = e.otp(x, phoneZ)
	if st, res := e.verifyOTP(x, m["challenge_id"].(string), e.sms.code(e164Z)); st != 200 || res["merged"] != true || res["user_id"] != z.id {
		t.Fatalf("device 1 moves to Z: %d %v", st, res)
	}
	// Device 2 still belongs to X and keeps its session; device 1's old X refresh token is dead.
	if st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": d2refresh}, ""); st != 200 {
		t.Fatalf("device 2 must stay signed in: %d %v", st, m)
	}
	if st, _ := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": x.refresh}, ""); st != 401 {
		t.Fatalf("device 1's old session must end: %d", st)
	}
}

// One account cannot fan OTP codes out to many different numbers.
func TestOTPPerAccountCapAcrossNumbers(t *testing.T) {
	e := newEnv(t)
	u := e.newUser("hw-fan")
	for i := 0; i < 6; i++ {
		if st, m := e.otp(u, fmt.Sprintf("0912777000%d", i)); st != 200 {
			t.Fatalf("code %d: %d %v", i, st, m)
		}
	}
	if st, m := e.otp(u, "09127770009"); st != 429 || errCode(m) != "RATE_LIMITED" {
		t.Fatalf("7th number in an hour must be limited: %d %v", st, m)
	}
	e.clk.Advance(61 * time.Minute)
	// the 1h access token has expired too: refresh the session first
	st, m := e.call("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": u.refresh}, "")
	if st != 200 {
		t.Fatalf("refresh: %d %v", st, m)
	}
	u.token = m["access_token"].(string)
	if st, _ := e.otp(u, "09127770009"); st != 200 {
		t.Fatalf("allowed again after an hour: %d", st)
	}
}
