// Package schemas loads and applies the JSON Schemas and catalogs in config-data/.
package schemas

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

// PackKeys are the content packs with a schema in config-data/content/schema.
var PackKeys = []string{"brand", "copy_fa", "habit_templates", "exercises", "adventures", "shop_items", "safety"}

// Set holds compiled schemas.
type Set struct {
	config *jsonschema.Schema
	packs  map[string]*jsonschema.Schema
}

// ValidationError lists human-readable problems, one per line, "path: message".
type ValidationError struct{ Problems []string }

func (e *ValidationError) Error() string { return strings.Join(e.Problems, "; ") }

func compile(path string) (*jsonschema.Schema, error) {
	raw, err := os.ReadFile(path) // #nosec G304 -- operator-controlled config-data dir
	if err != nil {
		return nil, fmt.Errorf("read schema: %w", err)
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("parse schema %s: %w", path, err)
	}
	c := jsonschema.NewCompiler()
	c.AssertFormat()
	url := "file:///" + filepath.Base(path)
	if err := c.AddResource(url, doc); err != nil {
		return nil, fmt.Errorf("add schema %s: %w", path, err)
	}
	s, err := c.Compile(url)
	if err != nil {
		return nil, fmt.Errorf("compile schema %s: %w", path, err)
	}
	return s, nil
}

// Load compiles the config and pack schemas found under dir (the config-data directory).
func Load(dir string) (*Set, error) {
	cs, err := compile(filepath.Join(dir, "config", "schema", "config.schema.json"))
	if err != nil {
		return nil, err
	}
	s := &Set{config: cs, packs: map[string]*jsonschema.Schema{}}
	for _, k := range PackKeys {
		ps, err := compile(filepath.Join(dir, "content", "schema", k+".schema.json"))
		if err != nil {
			return nil, err
		}
		s.packs[k] = ps
	}
	return s, nil
}

func validate(s *jsonschema.Schema, raw []byte) error {
	inst, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		return &ValidationError{Problems: []string{"$: invalid JSON: " + err.Error()}}
	}
	verr := s.Validate(inst)
	if verr == nil {
		return nil
	}
	var ve *jsonschema.ValidationError
	if !errors.As(verr, &ve) {
		return fmt.Errorf("validate: %w", verr)
	}
	var problems []string
	for _, u := range ve.BasicOutput().Errors {
		if u.Error == nil {
			continue
		}
		loc := u.InstanceLocation
		if loc == "" {
			loc = "$"
		}
		msg := u.Error.String()
		if strings.HasPrefix(msg, "oneOf failed") || strings.HasPrefix(msg, "allOf failed") ||
			strings.HasPrefix(msg, "if-then failed") || strings.HasPrefix(msg, "properties ") && strings.HasSuffix(msg, "failed") {
			continue // container messages; the leaf errors carry the detail
		}
		problems = append(problems, loc+": "+msg)
	}
	if len(problems) == 0 {
		problems = []string{"$: " + ve.Error()}
	}
	sort.Strings(problems)
	return &ValidationError{Problems: problems}
}

// ValidateConfig validates a config payload.
func (s *Set) ValidateConfig(raw []byte) error { return validate(s.config, raw) }

// ValidatePack validates a content pack document (envelope + entries).
func (s *Set) ValidatePack(packKey string, raw []byte) error {
	ps, ok := s.packs[packKey]
	if !ok {
		return &ValidationError{Problems: []string{"$.pack_key: unknown pack " + packKey}}
	}
	return validate(ps, raw)
}

// Catalog is config-data/analytics/events.json.
type Catalog struct {
	CommonProps    map[string]PropSpec `json:"common_props"`
	CommonPrefixes []string            `json:"common_prop_prefixes"`
	ForbiddenProps []string            `json:"forbidden_props"`
	Events         []EventSpec         `json:"events"`
}

// EventSpec describes one allowed event.
type EventSpec struct {
	Name       string              `json:"name"`
	Props      map[string]PropSpec `json:"props"`
	ServerSide bool                `json:"server_side"`
}

// PropSpec describes a prop type: "string" (optional enum, max_len), "int" (optional min/max) or "bool".
type PropSpec struct {
	Type   string   `json:"type"`
	Enum   []string `json:"enum"`
	MaxLen int      `json:"max_len"`
	Min    *int     `json:"min"`
	Max    *int     `json:"max"`
}

// LoadCatalog reads and sanity-checks the analytics catalog.
func LoadCatalog(dir string) (*Catalog, error) {
	raw, err := os.ReadFile(filepath.Join(dir, "analytics", "events.json")) // #nosec G304
	if err != nil {
		return nil, fmt.Errorf("read events catalog: %w", err)
	}
	var c Catalog
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	// "_comment" is tolerated by decoding into a wrapper first.
	var wrapper map[string]json.RawMessage
	if err := json.Unmarshal(raw, &wrapper); err != nil {
		return nil, fmt.Errorf("parse events catalog: %w", err)
	}
	delete(wrapper, "_comment")
	clean, _ := json.Marshal(wrapper)
	dec = json.NewDecoder(bytes.NewReader(clean))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&c); err != nil {
		return nil, fmt.Errorf("decode events catalog: %w", err)
	}
	seen := map[string]bool{}
	for _, e := range c.Events {
		if e.Name == "" || seen[e.Name] {
			return nil, fmt.Errorf("events catalog: empty or duplicate event %q", e.Name)
		}
		seen[e.Name] = true
		for p, spec := range e.Props {
			if spec.Type != "string" && spec.Type != "int" && spec.Type != "bool" {
				return nil, fmt.Errorf("events catalog: %s.%s has bad type %q", e.Name, p, spec.Type)
			}
		}
	}
	return &c, nil
}
