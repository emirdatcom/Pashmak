package remoteconfig

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"regexp"
	"sort"
	"strings"

	"github.com/emirdatcom/pashmak/backend/internal/platform/appver"
)

var keyRe = regexp.MustCompile(`^[a-z0-9_]{1,64}$`)

// Variant is one arm of an experiment. Overrides map dotted config paths ("paywall.variant")
// to replacement values.
type Variant struct {
	Name      string         `json:"name"`
	Weight    int            `json:"weight"`
	Overrides map[string]any `json:"overrides"`
}

// Audience restricts who is eligible. All set fields must match.
type Audience struct {
	Markets           []string `json:"markets,omitempty"`
	MinAppVersion     string   `json:"min_app_version,omitempty"`
	MaxAppVersion     string   `json:"max_app_version,omitempty"`
	MinInstallAgeDays *int     `json:"min_install_age_days,omitempty"`
	MaxInstallAgeDays *int     `json:"max_install_age_days,omitempty"`
}

// Experiment is a stored experiment definition.
type Experiment struct {
	Key      string    `json:"key"`
	Status   string    `json:"status"` // draft | running | stopped
	Variants []Variant `json:"variants"`
	Audience Audience  `json:"audience"`
}

// Subject describes the requester for bucketing and audience matching.
type Subject struct {
	ID             string // user_id, or install id for anonymous callers; empty = no experiments
	Market         string
	AppVersion     string
	InstallAgeDays int // -1 when unknown
}

// Bucket returns the deterministic bucket in [0, 10000) for subject+experiment (docs/10 §9).
func Bucket(subjectID, key string) int {
	h := fnv.New32a()
	_, _ = h.Write([]byte(subjectID + ":" + key))
	return int(h.Sum32() % 10000)
}

// Pick chooses the variant for a bucket proportionally to the weights.
func Pick(variants []Variant, bucket int) (Variant, bool) {
	total := 0
	for _, v := range variants {
		total += v.Weight
	}
	if total <= 0 {
		return Variant{}, false
	}
	pos := bucket * total / 10000
	acc := 0
	for _, v := range variants {
		acc += v.Weight
		if pos < acc {
			return v, true
		}
	}
	return variants[len(variants)-1], true
}

// Matches reports whether the subject is inside the audience.
func (a Audience) Matches(s Subject) bool {
	if len(a.Markets) > 0 {
		ok := false
		for _, m := range a.Markets {
			if m == s.Market {
				ok = true
			}
		}
		if !ok {
			return false
		}
	}
	if a.MinAppVersion != "" && !appver.AtLeast(s.AppVersion, a.MinAppVersion) {
		return false
	}
	if a.MaxAppVersion != "" && (!appver.AtLeast(s.AppVersion, "0") || appver.Compare(s.AppVersion, a.MaxAppVersion) > 0) {
		return false
	}
	if a.MinInstallAgeDays != nil && (s.InstallAgeDays < 0 || s.InstallAgeDays < *a.MinInstallAgeDays) {
		return false
	}
	if a.MaxInstallAgeDays != nil && (s.InstallAgeDays < 0 || s.InstallAgeDays > *a.MaxInstallAgeDays) {
		return false
	}
	return true
}

// Validate checks structure (not whether the overrides yield a valid config; the service does that).
func (e Experiment) Validate() error {
	if !keyRe.MatchString(e.Key) {
		return fmt.Errorf("key must match %s", keyRe)
	}
	switch e.Status {
	case "draft", "running", "stopped":
	default:
		return fmt.Errorf("status must be draft, running or stopped")
	}
	if len(e.Variants) < 2 {
		return fmt.Errorf("at least 2 variants are required")
	}
	names := map[string]bool{}
	for _, v := range e.Variants {
		if !keyRe.MatchString(v.Name) || names[v.Name] {
			return fmt.Errorf("variant names must be unique and match %s", keyRe)
		}
		names[v.Name] = true
		if v.Weight <= 0 {
			return fmt.Errorf("variant %s: weight must be positive", v.Name)
		}
	}
	for _, m := range e.Audience.Markets {
		if m != "bazaar" && m != "myket" {
			return fmt.Errorf("audience market %q is not bazaar/myket", m)
		}
	}
	return nil
}

// setPath sets a dotted path inside a decoded JSON object, creating objects as needed.
func setPath(root map[string]any, path string, value any) error {
	parts := strings.Split(path, ".")
	cur := root
	for _, p := range parts[:len(parts)-1] {
		next, ok := cur[p]
		if !ok {
			m := map[string]any{}
			cur[p] = m
			cur = m
			continue
		}
		m, ok := next.(map[string]any)
		if !ok {
			return fmt.Errorf("override path %q crosses a non-object at %q", path, p)
		}
		cur = m
	}
	cur[parts[len(parts)-1]] = value
	return nil
}

// ApplyOverrides returns base with the overrides applied (base is not modified).
func ApplyOverrides(base json.RawMessage, overrides map[string]any) (json.RawMessage, error) {
	if len(overrides) == 0 {
		return base, nil
	}
	var root map[string]any
	if err := json.Unmarshal(base, &root); err != nil {
		return nil, fmt.Errorf("decode base config: %w", err)
	}
	paths := make([]string, 0, len(overrides))
	for p := range overrides {
		paths = append(paths, p)
	}
	sort.Strings(paths)
	for _, p := range paths {
		if err := setPath(root, p, overrides[p]); err != nil {
			return nil, err
		}
	}
	out, err := json.Marshal(root)
	if err != nil {
		return nil, fmt.Errorf("encode config: %w", err)
	}
	return out, nil
}
