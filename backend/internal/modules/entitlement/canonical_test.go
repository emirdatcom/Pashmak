package entitlement

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"testing"
)

var update = flag.Bool("update", false, "regenerate fixtures/entitlement_state_signed.json")

func TestCanonicalizeGolden(t *testing.T) {
	in := map[string]any{
		"z": 1, "a": []any{map[string]any{"y": true, "b": nil}, "x/y", "فارسی", "q\"\\\n\u0001"},
		"m": map[string]any{"k2": 2, "k1": 1},
	}
	got, err := Canonicalize(in)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"a":[{"b":null,"y":true},"x/y","فارسی","q\"\\\n\u0001"],"m":{"k1":1,"k2":2},"z":1}`
	if string(got) != want {
		t.Fatalf("\n got %s\nwant %s", got, want)
	}
}

func TestCanonicalizeStateBodyOmitsSignature(t *testing.T) {
	end := "2026-10-12T08:00:00Z"
	b := StateBody{Entitlements: []Entry{}, Trial: TrialInfo{Eligible: true, EndsAt: &end}, ServerTime: "2026-10-05T08:00:00Z",
		ValidUntil: "2026-10-12T08:00:00Z", GraceDays: 3}
	got, _ := Canonicalize(b)
	want := `{"entitlements":[],"grace_days":3,"server_time":"2026-10-05T08:00:00Z","trial":{"eligible":true,"ends_at":"2026-10-12T08:00:00Z","used":false},"valid_until":"2026-10-12T08:00:00Z"}`
	if string(got) != want {
		t.Fatalf("\n got %s\nwant %s", got, want)
	}
}

type testSigner struct{ priv ed25519.PrivateKey }

func (s testSigner) Sign(p []byte) (string, string) {
	return base64.RawURLEncoding.EncodeToString(ed25519.Sign(s.priv, p)), "ent-test"
}
func (s testSigner) Verify([]byte, string, string) error { return nil }

type fixture struct {
	Kid       string          `json:"kid"`
	PublicKey string          `json:"public_key"`
	Canonical string          `json:"canonical"`
	State     json.RawMessage `json:"state"`
}

const fixturePath = "../../../../fixtures/entitlement_state_signed.json"

// TestSignedFixture pins the cross-language contract: the Flutter client (prompt 14) and the
// integration suite (prompt 20) must reproduce `canonical` from `state` and verify `signature`.
func TestSignedFixture(t *testing.T) {
	seed := make([]byte, ed25519.SeedSize)
	for i := range seed {
		seed[i] = byte(i) // TEST KEY ONLY — never used outside fixtures
	}
	priv := ed25519.NewKeyFromSeed(seed)
	if *update {
		trialEnd := "2026-10-12T08:00:00Z"
		body := StateBody{
			Entitlements: []Entry{{Key: "premium", Source: "pass", StartsAt: "2026-10-05T08:00:00Z", EndsAt: "2027-01-03T08:00:00Z"}},
			Trial:        TrialInfo{Eligible: false, Used: true, EndsAt: &trialEnd},
			ServerTime:   "2026-10-05T08:00:00Z", ValidUntil: "2026-10-12T08:00:00Z", GraceDays: 3,
		}
		svc := &Service{signer: testSigner{priv}}
		st, err := svc.Sign(body)
		if err != nil {
			t.Fatal(err)
		}
		canon, _ := Canonicalize(st.StateBody)
		stJSON, _ := json.MarshalIndent(st, "  ", "  ")
		fx := fixture{Kid: "ent-test", PublicKey: base64.RawURLEncoding.EncodeToString(priv.Public().(ed25519.PublicKey)),
			Canonical: string(canon), State: stJSON}
		out, _ := json.MarshalIndent(fx, "", "  ")
		if err := os.MkdirAll(filepath.Dir(fixturePath), 0o750); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(fixturePath, append(out, 0x0a), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	raw, err := os.ReadFile(fixturePath)
	if err != nil {
		t.Fatalf("fixture missing; run: go test ./internal/modules/entitlement -update (%v)", err)
	}
	var fx fixture
	if err := json.Unmarshal(raw, &fx); err != nil {
		t.Fatal(err)
	}
	var st State
	if err := json.Unmarshal(fx.State, &st); err != nil {
		t.Fatal(err)
	}
	canon, err := Canonicalize(st.StateBody)
	if err != nil || string(canon) != fx.Canonical {
		t.Fatalf("canonical mismatch:\n got %s\nwant %s", canon, fx.Canonical)
	}
	pub, _ := base64.RawURLEncoding.DecodeString(fx.PublicKey)
	sig, _ := base64.RawURLEncoding.DecodeString(st.Signature)
	if !ed25519.Verify(pub, canon, sig) {
		t.Fatal("fixture signature does not verify")
	}
	canon[3] ^= 1 // flipping any byte invalidates the signature
	if ed25519.Verify(pub, canon, sig) {
		t.Fatal("tampered payload must not verify")
	}
}

func TestFormatTime(t *testing.T) {
	if got := FormatTime(parseT("2026-10-05T11:30:00.987+03:30")); got != "2026-10-05T08:00:00Z" {
		t.Fatal(got)
	}
}
