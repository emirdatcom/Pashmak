package analytics

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
)

func newValidator(t *testing.T) *Service {
	t.Helper()
	cat, err := schemas.LoadCatalog("../../../../config-data")
	if err != nil {
		t.Fatal(err)
	}
	return NewService(nil, cat, clock.NewFake(time.Date(2026, 10, 5, 8, 0, 0, 0, time.UTC)))
}

func ev(name string, props map[string]any) Event {
	return Event{EventID: uuid.NewString(), Name: name, TS: "2026-10-05T07:59:00Z", SessionID: "s1", Props: props}
}

func TestValidateWhitelist(t *testing.T) {
	s := newValidator(t)
	now := s.clk.Now()
	_, reason := s.validate(ev("totally_unknown", nil), false, now)
	if reason != ReasonUnknownEvent {
		t.Fatalf("unknown: %q", reason)
	}
	if _, reason := s.validate(ev("subscription_canceled", map[string]any{"product_id": "x"}), false, now); reason != ReasonServerOnly {
		t.Fatalf("server-only from client: %q", reason)
	}
	if _, reason := s.validate(ev("subscription_canceled", map[string]any{"product_id": "x"}), true, now); reason != "" {
		t.Fatalf("server-side allowed: %q", reason)
	}
	// Forbidden props reject the whole event, even though checkin_completed is valid.
	for _, bad := range []string{"mood_level", "note", "text", "title", "phone", "MOOD_LEVEL"} {
		if _, reason := s.validate(ev("checkin_completed", map[string]any{"has_note": true, bad: 3}), false, now); reason != ReasonForbiddenProp {
			t.Errorf("%s: %q", bad, reason)
		}
	}
	// Unknown props dropped; wrong types/enums dropped; known kept; exp_ prefix kept.
	cl, reason := s.validate(ev("checkin_completed", map[string]any{
		"has_note": true, "source": "widget", "habit_title": "secret", "exp_paywall": "b", "bogus": 1}), false, now)
	if reason != "" || len(cl.props) != 3 || cl.props["source"] != "widget" || cl.props["exp_paywall"] != "b" {
		t.Fatalf("props: %v %q", cl.props, reason)
	}
	cl, _ = s.validate(ev("checkin_completed", map[string]any{"has_note": "yes", "source": "carrier_pigeon"}), false, now)
	if len(cl.props) != 0 {
		t.Fatalf("invalid values must be dropped: %v", cl.props)
	}
	cl, _ = s.validate(ev("exercise_completed", map[string]any{"exercise_key": "breathing_basic", "duration_s": 120.0}), false, now)
	if cl.props["duration_s"] != int64(120) {
		t.Fatalf("int coercion: %v", cl.props)
	}
	cl, _ = s.validate(ev("exercise_completed", map[string]any{"duration_s": 1.5}), false, now)
	if _, ok := cl.props["duration_s"]; ok {
		t.Fatal("non-integer must be dropped")
	}
	// Bad envelope fields.
	bad := ev("app_opened", nil)
	bad.EventID = "nope"
	if _, reason := s.validate(bad, false, now); reason != ReasonInvalidID {
		t.Fatalf("id: %q", reason)
	}
	bad = ev("app_opened", nil)
	bad.TS = "yesterday"
	if _, reason := s.validate(bad, false, now); reason != ReasonInvalidTS {
		t.Fatalf("ts: %q", reason)
	}
	bad = ev("app_opened", nil)
	bad.TS = "2030-01-01T00:00:00Z"
	if _, reason := s.validate(bad, false, now); reason != ReasonInvalidTS {
		t.Fatalf("future ts: %q", reason)
	}
}

func TestEveryCatalogEventIsKnownAndForbiddenNeverAllowed(t *testing.T) {
	cat, _ := schemas.LoadCatalog("../../../../config-data")
	forbidden := map[string]bool{}
	for _, f := range cat.ForbiddenProps {
		forbidden[f] = true
	}
	for _, e := range cat.Events {
		for p := range e.Props {
			if forbidden[p] {
				t.Errorf("event %s declares forbidden prop %s", e.Name, p)
			}
		}
	}
}
