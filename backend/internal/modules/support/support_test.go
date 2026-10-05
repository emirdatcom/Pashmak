package support

import (
	"bytes"
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/testutil"
)

func TestStatusHoursTehran(t *testing.T) {
	c := DefaultConfig() // Saturday..Thursday 09:00-21:00 Asia/Tehran, Friday closed
	loc, _ := time.LoadLocation("Asia/Tehran")
	at := func(y int, m time.Month, d, h, min int) time.Time { return time.Date(y, m, d, h, min, 0, 0, loc).UTC() }
	// 2026-10-03 is a Saturday, 2026-10-09 a Friday
	cases := []struct {
		name   string
		now    time.Time
		online bool
		next   time.Time
	}{
		{"saturday 10:00", at(2026, 10, 3, 10, 0), true, time.Time{}},
		{"saturday 08:59 → opens 09:00", at(2026, 10, 3, 8, 59), false, at(2026, 10, 3, 9, 0)},
		{"saturday 21:00 sharp is closed", at(2026, 10, 3, 21, 0), false, at(2026, 10, 4, 9, 0)},
		{"thursday evening → saturday morning (friday closed)", at(2026, 10, 8, 22, 0), false, at(2026, 10, 10, 9, 0)},
		{"friday noon", at(2026, 10, 9, 12, 0), false, at(2026, 10, 10, 9, 0)},
	}
	for _, tc := range cases {
		online, next := c.Status(tc.now)
		if online != tc.online {
			t.Errorf("%s: online=%v", tc.name, online)
		}
		if !tc.online && (next == nil || !next.Equal(tc.next)) {
			t.Errorf("%s: next=%v want %v", tc.name, next, tc.next)
		}
	}
	if online, next := (Config{Timezone: "Asia/Tehran"}).Status(time.Now()); online || next != nil {
		t.Fatalf("no windows configured: %v %v", online, next)
	}
}

func TestSealOpenRoundTripAndNoPlaintext(t *testing.T) {
	box, _ := crypt.New(bytes.Repeat([]byte{3}, 32))
	enc, err := seal(box, "متن خصوصی")
	if err != nil || bytes.Contains(enc, []byte("خصوصی")) {
		t.Fatalf("seal: %v", err)
	}
	if got, err := open(box, enc); err != nil || got != "متن خصوصی" {
		t.Fatalf("open: %q %v", got, err)
	}
	enc[len(enc)-1] ^= 1
	if _, err := open(box, enc); err == nil {
		t.Fatal("a tampered body must not decrypt")
	}
}

func TestFirstResponseAndOldestUnanswered(t *testing.T) {
	pool := testutil.NewDB(t)
	clk := clock.NewFake(time.Date(2026, 10, 3, 6, 30, 0, 0, time.UTC)) // 10:00 Tehran, a Saturday
	box, _ := crypt.New(bytes.Repeat([]byte{4}, 32))
	var observed []float64
	svc := NewService(pool, clk, box, StaticConfig{DefaultConfig()}, NewHub(pool), Observer{FirstResponse: func(s float64) { observed = append(observed, s) }})
	ctx := context.Background()
	uid := uuid.New()
	if _, err := pool.Exec(ctx, `insert into users (id, status, created_at) values ($1,'active',now())`, uid); err != nil {
		t.Fatal(err)
	}
	if svc.OldestUnanswered(ctx) != 0 {
		t.Fatal("nothing waits yet")
	}
	if _, err := svc.UserSend(ctx, uid, uuid.New(), "سلام", nil); err != nil {
		t.Fatal(err)
	}
	clk.Advance(7 * time.Minute)
	if d := svc.OldestUnanswered(ctx); d != 7*time.Minute {
		t.Fatalf("oldest unanswered = %v", d)
	}
	var cid uuid.UUID
	_ = pool.QueryRow(ctx, `select id from support_conversations`).Scan(&cid)
	opID := uuid.New()
	if _, err := pool.Exec(ctx, `insert into support_operators (id, username, password_hash, display_name, role, created_at) values ($1,'o','x','Op','agent',now())`, opID); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.OperatorSend(ctx, opID, cid, "جواب"); err != nil {
		t.Fatal(err)
	}
	if len(observed) != 1 || observed[0] != 420 {
		t.Fatalf("first response seconds = %v", observed)
	}
	if svc.OldestUnanswered(ctx) != 0 {
		t.Fatal("answered conversations stop counting")
	}
	// a second reply is not a "first response"
	if _, err := svc.OperatorSend(ctx, opID, cid, "ادامه"); err != nil || len(observed) != 1 {
		t.Fatalf("second reply observed=%v err=%v", observed, err)
	}
	// outside working hours the gauge reads 0 even when someone waits
	if _, err := svc.UserSend(ctx, uid, uuid.New(), "شبانه", nil); err != nil {
		t.Fatal(err)
	}
	clk.Advance(12 * time.Hour) // 22:00 Tehran
	if svc.OldestUnanswered(ctx) != 0 {
		t.Fatal("outside hours the unanswered alert must stay quiet")
	}
	if svc.OpenConversations(ctx) != 1 {
		t.Fatal("open conversations gauge")
	}
}
