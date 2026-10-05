package remoteconfig

import (
	"encoding/json"
	"math"
	"testing"

	"github.com/google/uuid"
)

func TestBucketDeterministicAndDistributed(t *testing.T) {
	variants := []Variant{{Name: "a", Weight: 50}, {Name: "b", Weight: 50}}
	counts := map[string]int{}
	const n = 10000
	for i := 0; i < n; i++ {
		id := uuid.NewString()
		v1, _ := Pick(variants, Bucket(id, "paywall_test"))
		v2, _ := Pick(variants, Bucket(id, "paywall_test"))
		if v1.Name != v2.Name {
			t.Fatal("variant must be stable for a user")
		}
		counts[v1.Name]++
	}
	if share := float64(counts["a"]) / n; math.Abs(share-0.5) > 0.02 {
		t.Fatalf("50/50 split off: %v", counts)
	}
	// Different experiment keys re-shuffle users independently.
	same := 0
	for i := 0; i < 2000; i++ {
		id := uuid.NewString()
		a, _ := Pick(variants, Bucket(id, "exp_one"))
		b, _ := Pick(variants, Bucket(id, "exp_two"))
		if a.Name == b.Name {
			same++
		}
	}
	if same < 800 || same > 1200 {
		t.Fatalf("experiments look correlated: same=%d/2000", same)
	}
}

func TestPickUnevenWeights(t *testing.T) {
	variants := []Variant{{Name: "a", Weight: 90}, {Name: "b", Weight: 10}}
	got := 0
	for i := 0; i < 10000; i++ {
		if v, _ := Pick(variants, Bucket(uuid.NewString(), "k")); v.Name == "b" {
			got++
		}
	}
	if got < 800 || got > 1200 {
		t.Fatalf("10%% arm got %d/10000", got)
	}
	if _, ok := Pick(nil, 5); ok {
		t.Fatal("no variants must not pick")
	}
}

func TestAudience(t *testing.T) {
	two, thirty := 2, 30
	a := Audience{Markets: []string{"myket"}, MinAppVersion: "1.1.0", MinInstallAgeDays: &two, MaxInstallAgeDays: &thirty}
	if !a.Matches(Subject{Market: "myket", AppVersion: "1.2.0", InstallAgeDays: 5}) {
		t.Fatal("should match")
	}
	for name, s := range map[string]Subject{
		"market":  {Market: "bazaar", AppVersion: "1.2.0", InstallAgeDays: 5},
		"version": {Market: "myket", AppVersion: "1.0.9", InstallAgeDays: 5},
		"young":   {Market: "myket", AppVersion: "1.2.0", InstallAgeDays: 1},
		"old":     {Market: "myket", AppVersion: "1.2.0", InstallAgeDays: 31},
		"unknown": {Market: "myket", AppVersion: "1.2.0", InstallAgeDays: -1},
	} {
		if a.Matches(s) {
			t.Errorf("%s should not match", name)
		}
	}
	if !(Audience{}).Matches(Subject{}) {
		t.Fatal("empty audience matches everyone")
	}
}

func TestApplyOverrides(t *testing.T) {
	base := json.RawMessage(`{"paywall":{"variant":"a","cooldown_hours":24},"pricing":{"plans":[1]}}`)
	out, err := ApplyOverrides(base, map[string]any{"paywall.variant": "b", "new.nested.key": 1.0, "pricing.plans": []any{2.0}})
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	_ = json.Unmarshal(out, &got)
	if got["paywall"].(map[string]any)["variant"] != "b" || got["paywall"].(map[string]any)["cooldown_hours"] != 24.0 {
		t.Fatalf("paywall: %v", got)
	}
	if got["new"].(map[string]any)["nested"].(map[string]any)["key"] != 1.0 {
		t.Fatalf("nested: %v", got)
	}
	var orig map[string]any
	_ = json.Unmarshal(base, &orig)
	if orig["paywall"].(map[string]any)["variant"] != "a" {
		t.Fatal("base must not be mutated")
	}
	if _, err := ApplyOverrides(base, map[string]any{"paywall.variant.deeper": 1}); err == nil {
		t.Fatal("crossing a scalar must fail")
	}
}

func TestExperimentValidate(t *testing.T) {
	ok := Experiment{Key: "price_test", Status: "running", Variants: []Variant{{Name: "a", Weight: 1}, {Name: "b", Weight: 1}}}
	if err := ok.Validate(); err != nil {
		t.Fatal(err)
	}
	bad := []Experiment{
		{Key: "Bad Key", Status: "running", Variants: ok.Variants},
		{Key: "k", Status: "weird", Variants: ok.Variants},
		{Key: "k", Status: "running", Variants: ok.Variants[:1]},
		{Key: "k", Status: "running", Variants: []Variant{{Name: "a", Weight: 1}, {Name: "a", Weight: 1}}},
		{Key: "k", Status: "running", Variants: []Variant{{Name: "a", Weight: 0}, {Name: "b", Weight: 1}}},
		{Key: "k", Status: "running", Variants: ok.Variants, Audience: Audience{Markets: []string{"play"}}},
	}
	for i, e := range bad {
		if e.Validate() == nil {
			t.Errorf("case %d should be invalid", i)
		}
	}
}
