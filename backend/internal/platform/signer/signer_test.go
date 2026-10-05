package signer

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestSignVerifyRotation(t *testing.T) {
	dir := t.TempDir()
	if err := Generate(dir, "k1"); err != nil {
		t.Fatal(err)
	}
	if err := Generate(dir, "k2"); err != nil {
		t.Fatal(err)
	}
	s, err := Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	if s.ActiveKid() != "k2" {
		t.Fatalf("active=%s", s.ActiveKid())
	}
	sig, kid := s.Sign([]byte("hello"))
	if err := s.Verify([]byte("hello"), sig, kid); err != nil {
		t.Fatal(err)
	}
	if err := s.Verify([]byte("tampered"), sig, kid); err == nil {
		t.Fatal("expected bad signature")
	}
	if err := s.Verify([]byte("hello"), sig, "nope"); !errors.Is(err, ErrUnknownKid) {
		t.Fatalf("want ErrUnknownKid, got %v", err)
	}
	// Old key still verifies; active_kid override switches signing.
	if err := os.WriteFile(filepath.Join(dir, "active_kid"), []byte("k1\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	s2, err := Load(dir)
	if err != nil {
		t.Fatal(err)
	}
	sig1, kid1 := s2.Sign([]byte("x"))
	if kid1 != "k1" || s.Verify([]byte("x"), sig1, kid1) != nil {
		t.Fatal("k1 signing/verification failed")
	}
}

func TestLoadEmpty(t *testing.T) {
	if _, err := Load(t.TempDir()); err == nil {
		t.Fatal("expected error for empty dir")
	}
}
