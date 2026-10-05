package schemas

import (
	"os"
	"strings"
	"testing"
)

const dir = "../../../../config-data"

func TestDefaultConfigValidAndBadRejected(t *testing.T) {
	s, err := Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(dir + "/config/default.json")
	if err := s.ValidateConfig(raw); err != nil {
		t.Fatal(err)
	}
	bad := strings.Replace(string(raw), `"free_active_habits": 3`, `"free_active_habits": "three"`, 1)
	err = s.ValidateConfig([]byte(bad))
	ve, ok := err.(*ValidationError)
	if !ok || !strings.Contains(ve.Error(), "/limits/free_active_habits") {
		t.Fatalf("want precise path, got %v", err)
	}
	unknown := strings.Replace(string(raw), `"streak": {`, `"streek": {`, 1)
	if err := s.ValidateConfig([]byte(unknown)); err == nil {
		t.Fatal("unknown/misspelled key must be rejected")
	}
	if err := s.ValidateConfig([]byte(`{`)); err == nil {
		t.Fatal("invalid JSON must be rejected")
	}
}

func TestCatalogLoads(t *testing.T) {
	c, err := LoadCatalog(dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(c.Events) < 28 || len(c.ForbiddenProps) == 0 {
		t.Fatalf("catalog looks incomplete: %d events", len(c.Events))
	}
}
