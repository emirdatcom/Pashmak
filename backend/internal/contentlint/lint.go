// Package contentlint checks config-data/ (config, content packs, analytics catalog) against the
// schemas and the style rules of docs/40 §4.
package contentlint

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
)

// Issue is one finding.
type Issue struct{ File, Key, Msg string }

func (i Issue) String() string {
	if i.Key == "" {
		return i.File + ": " + i.Msg
	}
	return i.File + ": " + i.Key + ": " + i.Msg
}

const (
	maxNotifBody  = 80
	maxNotifTitle = 25
)

var (
	allowedVars = map[string]bool{"APP_NAME": true, "CAT_NAME": true, "n": true, "habit": true, "place": true, "date": true, "time": true, "item": true}
	varRe       = regexp.MustCompile(`\{([^{}]*)\}`)
	// copy key prefixes that may mention medical words (they state "not therapy").
	exemptPrefixes = []string{"disclaimer.", "safety.", "help.", "legal."}
	canonicalIDs   = map[string][]string{
		"habit_templates": {"water", "sleep", "short_break", "walk", "healthy_food", "medicine", "loved_ones"},
		"exercises":       {"breathing_basic", "gratitude", "guided_journal", "muscle_relax", "afternoon_tea"},
	}
	// *_key fields that are identifiers, not references into copy_fa.
	idFields           = map[string]bool{"location_key": true, "story_key": true, "item_key": true, "pack_key": true}
	canonicalLocations = []string{"alley", "rooftop", "courtyard", "bazaar", "garden"}
)

func readJSON(path string, v any) error {
	raw, err := os.ReadFile(path) // #nosec G304 -- operator-controlled
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}
	if err := json.Unmarshal(raw, v); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	return nil
}

// LoadBanned reads banned_words.txt.
func LoadBanned(path string) ([]string, error) {
	f, err := os.Open(path) // #nosec G304
	if err != nil {
		return nil, fmt.Errorf("open banned words: %w", err)
	}
	defer func() { _ = f.Close() }()
	var words []string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		w := strings.TrimSpace(sc.Text())
		if w != "" && !strings.HasPrefix(w, "#") {
			words = append(words, w)
		}
	}
	return words, sc.Err()
}

// checkText applies the character, variable and banned-word rules to one string.
func checkText(file, key, s string, banned []string, exemptBanned bool) []Issue {
	var out []Issue
	add := func(msg string) { out = append(out, Issue{file, key, msg}) }
	if strings.ContainsAny(s, "يكـ") { // Arabic yeh (U+064A), kaf (U+0643), tatweel
		add("contains Arabic ي/ك or tatweel; use Persian ی/ک")
	}
	for _, m := range varRe.FindAllStringSubmatch(s, -1) {
		if !allowedVars[m[1]] {
			add("unknown variable {" + m[1] + "}")
		}
	}
	if !exemptBanned {
		for _, w := range banned {
			if strings.Contains(s, w) {
				add("banned word «" + w + "»")
			}
		}
	}
	return out
}

func exemptKey(key string) bool {
	for _, p := range exemptPrefixes {
		if strings.HasPrefix(key, p) {
			return true
		}
	}
	return false
}

type pack struct {
	PackKey string          `json:"pack_key"`
	Entries json.RawMessage `json:"entries"`
}

// Run lints the config-data directory.
func Run(dir string) ([]Issue, error) {
	set, err := schemas.Load(dir)
	if err != nil {
		return nil, err
	}
	banned, err := LoadBanned(filepath.Join(dir, "content-lint", "banned_words.txt"))
	if err != nil {
		return nil, err
	}
	var issues []Issue
	addSchema := func(file string, err error) {
		if err == nil {
			return
		}
		if ve, ok := err.(*schemas.ValidationError); ok {
			for _, p := range ve.Problems {
				issues = append(issues, Issue{File: file, Msg: "schema: " + p})
			}
			return
		}
		issues = append(issues, Issue{File: file, Msg: err.Error()})
	}

	// config/default.json
	cfgPath := filepath.Join(dir, "config", "default.json")
	cfgRaw, err := os.ReadFile(cfgPath) // #nosec G304
	if err != nil {
		return nil, fmt.Errorf("read default config: %w", err)
	}
	addSchema("config/default.json", set.ValidateConfig(cfgRaw))

	// analytics catalog
	if _, err := schemas.LoadCatalog(dir); err != nil {
		issues = append(issues, Issue{File: "analytics/events.json", Msg: err.Error()})
	}

	// packs
	copyKeys := map[string]bool{}
	packs := map[string]pack{}
	raws := map[string][]byte{}
	for _, k := range schemas.PackKeys {
		file := "content/" + k + ".json"
		raw, err := os.ReadFile(filepath.Join(dir, file)) // #nosec G304
		if err != nil {
			issues = append(issues, Issue{File: file, Msg: "missing pack file"})
			continue
		}
		raws[k] = raw
		addSchema(file, set.ValidatePack(k, raw))
		var p pack
		if err := json.Unmarshal(raw, &p); err == nil {
			packs[k] = p
		}
	}

	// copy_fa rules
	if p, ok := packs["copy_fa"]; ok {
		var entries map[string]json.RawMessage
		if err := json.Unmarshal(p.Entries, &entries); err == nil {
			keys := sortedKeys(entries)
			for _, key := range keys {
				copyKeys[key] = true
				vals := stringsOf(entries[key])
				for i, v := range vals {
					k := key
					if len(vals) > 1 {
						k = fmt.Sprintf("%s[%d]", key, i)
					}
					issues = append(issues, checkText("content/copy_fa.json", k, v, banned, exemptKey(key))...)
					if strings.HasPrefix(key, "notif.") {
						limit := maxNotifBody
						if strings.HasSuffix(key, ".title") {
							limit = maxNotifTitle
						}
						if n := utf8.RuneCountInString(v); n > limit {
							issues = append(issues, Issue{"content/copy_fa.json", k, fmt.Sprintf("too long: %d > %d characters", n, limit)})
						}
					}
				}
			}
		}
	}

	// other packs: text rules + references to copy keys
	for _, k := range schemas.PackKeys {
		if k == "copy_fa" || raws[k] == nil {
			continue
		}
		var tree any
		if err := json.Unmarshal(packs[k].Entries, &tree); err != nil {
			continue
		}
		file := "content/" + k + ".json"
		walk(tree, "", func(path, field, s string) {
			if field == "keywords" {
				issues = append(issues, checkText(file, path, s, nil, true)...)
				return
			}
			issues = append(issues, checkText(file, path, s, banned, k == "safety")...)
			if (strings.HasSuffix(field, "_key") && !idFields[field]) || field == "prompts" {
				if !copyKeys[s] {
					issues = append(issues, Issue{file, path, "references missing copy key " + s})
				}
			}
		})
		if want, ok := canonicalIDs[k]; ok {
			issues = append(issues, checkIDSet(file, "key", packs[k].Entries, want)...)
		}
	}
	if raw, ok := raws["adventures"]; ok {
		_ = raw
		issues = append(issues, checkLocations("content/adventures.json", packs["adventures"].Entries)...)
	}

	// config cross-checks
	var cfg struct {
		Limits struct {
			FreeExercises []string `json:"free_exercises"`
			FreeLocations []string `json:"free_adventure_locations"`
		} `json:"limits"`
		Adventure struct {
			Locations []struct {
				Key string `json:"location_key"`
			} `json:"locations"`
		} `json:"adventure"`
		Pricing struct {
			Plans []struct {
				BadgeKey string `json:"badge_key"`
			} `json:"plans"`
		} `json:"pricing"`
	}
	if err := json.Unmarshal(cfgRaw, &cfg); err == nil {
		have := toSet(canonicalLocations)
		for _, l := range cfg.Limits.FreeLocations {
			if !have[l] {
				issues = append(issues, Issue{"config/default.json", "limits.free_adventure_locations", "unknown location " + l})
			}
		}
		for _, l := range cfg.Adventure.Locations {
			if !have[l.Key] {
				issues = append(issues, Issue{"config/default.json", "adventure.locations", "unknown location " + l.Key})
			}
		}
		ex := toSet(canonicalIDs["exercises"])
		for _, e := range cfg.Limits.FreeExercises {
			if !ex[e] {
				issues = append(issues, Issue{"config/default.json", "limits.free_exercises", "unknown exercise " + e})
			}
		}
		for _, p := range cfg.Pricing.Plans {
			if p.BadgeKey != "" && len(copyKeys) > 0 && !copyKeys[p.BadgeKey] {
				issues = append(issues, Issue{"config/default.json", "pricing.plans.badge_key", "missing copy key " + p.BadgeKey})
			}
		}
	}
	return issues, nil
}

func checkIDSet(file, field string, entries json.RawMessage, want []string) []Issue {
	var list []map[string]any
	if json.Unmarshal(entries, &list) != nil {
		return nil
	}
	got := map[string]bool{}
	for _, e := range list {
		if s, ok := e[field].(string); ok {
			got[s] = true
		}
	}
	var out []Issue
	for _, w := range want {
		if !got[w] {
			out = append(out, Issue{file, "", "missing canonical id " + w})
		}
	}
	return out
}

func checkLocations(file string, entries json.RawMessage) []Issue {
	var e struct {
		Locations []struct {
			Key string `json:"location_key"`
		} `json:"locations"`
	}
	if json.Unmarshal(entries, &e) != nil {
		return nil
	}
	got := map[string]bool{}
	for _, l := range e.Locations {
		got[l.Key] = true
	}
	var out []Issue
	for _, w := range canonicalLocations {
		if !got[w] {
			out = append(out, Issue{file, "", "missing canonical location " + w})
		}
	}
	return out
}

func toSet(s []string) map[string]bool {
	m := map[string]bool{}
	for _, v := range s {
		m[v] = true
	}
	return m
}

func sortedKeys(m map[string]json.RawMessage) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func stringsOf(raw json.RawMessage) []string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return []string{s}
	}
	var a []string
	if json.Unmarshal(raw, &a) == nil {
		return a
	}
	return nil
}

// walk calls fn for every string leaf with its JSON path and the nearest object field name.
func walk(v any, path string, fn func(path, field, s string)) {
	walkField(v, path, "", fn)
}

func walkField(v any, path, field string, fn func(path, field, s string)) {
	switch t := v.(type) {
	case string:
		fn(path, field, t)
	case []any:
		for i, e := range t {
			walkField(e, fmt.Sprintf("%s[%d]", path, i), field, fn)
		}
	case map[string]any:
		keys := make([]string, 0, len(t))
		for k := range t {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			p := k
			if path != "" {
				p = path + "." + k
			}
			walkField(t[k], p, k, fn)
		}
	}
}
