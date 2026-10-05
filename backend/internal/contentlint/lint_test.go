package contentlint

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const realDir = "../../../config-data"

func copyDir(t *testing.T, src, dst string) {
	t.Helper()
	err := filepath.Walk(src, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		target := filepath.Join(dst, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0o750)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(target, b, 0o600)
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestRepoConfigDataIsClean(t *testing.T) {
	issues, err := Run(realDir)
	if err != nil {
		t.Fatal(err)
	}
	for _, i := range issues {
		t.Error(i)
	}
}

// mutateCopy changes one copy_fa entry in a temp copy of config-data and lints it.
func lintWithCopy(t *testing.T, key string, value any) []Issue {
	t.Helper()
	dir := t.TempDir()
	copyDir(t, realDir, dir)
	path := filepath.Join(dir, "content", "copy_fa.json")
	raw, _ := os.ReadFile(path)
	var doc map[string]any
	if err := json.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	doc["entries"].(map[string]any)[key] = value
	out, _ := json.Marshal(doc)
	if err := os.WriteFile(path, out, 0o600); err != nil {
		t.Fatal(err)
	}
	issues, err := Run(dir)
	if err != nil {
		t.Fatal(err)
	}
	return issues
}

func has(issues []Issue, sub string) bool {
	for _, i := range issues {
		if strings.Contains(i.String(), sub) {
			return true
		}
	}
	return false
}

func TestBannedWord(t *testing.T) {
	if !has(lintWithCopy(t, "home.x", "این یه درمان واقعیه"), "banned word «درمان»") {
		t.Fatal("banned word not reported")
	}
	// exempt prefix may use it
	if has(lintWithCopy(t, "disclaimer.extra", "این جایگزین درمان نیست"), "banned word") {
		t.Fatal("disclaimer.* must be exempt")
	}
}

func TestArabicLetters(t *testing.T) {
	if !has(lintWithCopy(t, "home.y", "سلام علي"), "Arabic") {
		t.Fatal("arabic yeh not reported")
	}
	if !has(lintWithCopy(t, "home.k", "كتاب"), "Arabic") {
		t.Fatal("arabic kaf not reported")
	}
}

func TestVariablesAndLength(t *testing.T) {
	if !has(lintWithCopy(t, "home.z", "سلام {USER}"), "unknown variable {USER}") {
		t.Fatal("unknown variable not reported")
	}
	if !has(lintWithCopy(t, "notif.too_long", strings.Repeat("الف ", 30)), "too long") {
		t.Fatal("long notification not reported")
	}
	if !has(lintWithCopy(t, "notif.big.title", strings.Repeat("ب", 30)), "too long") {
		t.Fatal("long notification title not reported")
	}
}

func TestMissingReferenceAndSchema(t *testing.T) {
	dir := t.TempDir()
	copyDir(t, realDir, dir)
	path := filepath.Join(dir, "content", "shop_items.json")
	raw, _ := os.ReadFile(path)
	raw = []byte(strings.Replace(string(raw), "shop.item.samovar.name", "shop.item.nope.name", 1))
	_ = os.WriteFile(path, raw, 0o600)
	issues, _ := Run(dir)
	if !has(issues, "missing copy key shop.item.nope.name") {
		t.Fatalf("missing reference not reported: %v", issues)
	}
	// schema violation: negative price
	raw = []byte(strings.Replace(string(raw), `"price_coins": 180`, `"price_coins": -5`, 1))
	_ = os.WriteFile(path, raw, 0o600)
	issues, _ = Run(dir)
	if !has(issues, "schema:") {
		t.Fatalf("schema violation not reported: %v", issues)
	}
}
