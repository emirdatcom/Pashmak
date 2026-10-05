// Package signer loads Ed25519 keys and signs/verifies payloads with key rotation by kid.
package signer

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ErrUnknownKid is returned when verifying with a kid that has no public key.
var ErrUnknownKid = errors.New("signer: unknown kid")

// Signer signs with the active private key and verifies with any known public key.
type Signer struct {
	activeKid string
	priv      map[string]ed25519.PrivateKey
	pub       map[string]ed25519.PublicKey
}

var b64 = base64.RawURLEncoding

// Generate creates a keypair and writes {kid}.key and {kid}.pub (base64url) into dir.
func Generate(dir, kid string) error {
	if kid == "" || strings.ContainsAny(kid, `/\.`) {
		return fmt.Errorf("invalid kid %q", kid)
	}
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return fmt.Errorf("generate key: %w", err)
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("mkdir keys dir: %w", err)
	}
	if err := os.WriteFile(filepath.Join(dir, kid+".key"), []byte(b64.EncodeToString(priv.Seed())), 0o600); err != nil {
		return fmt.Errorf("write private key: %w", err)
	}
	if err := os.WriteFile(filepath.Join(dir, kid+".pub"), []byte(b64.EncodeToString(pub)), 0o644); err != nil { // #nosec G306 -- public key
		return fmt.Errorf("write public key: %w", err)
	}
	return nil
}

// Load reads keys from dir. The active kid is the content of `active_kid`, else the last private key by name.
func Load(dir string) (*Signer, error) {
	s := &Signer{priv: map[string]ed25519.PrivateKey{}, pub: map[string]ed25519.PublicKey{}}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read keys dir: %w", err)
	}
	var privKids []string
	for _, e := range entries {
		name := e.Name()
		switch {
		case strings.HasSuffix(name, ".key"):
			kid := strings.TrimSuffix(name, ".key")
			raw, err := os.ReadFile(filepath.Join(dir, name)) // #nosec G304 -- operator-controlled dir
			if err != nil {
				return nil, fmt.Errorf("read %s: %w", name, err)
			}
			seed, err := b64.DecodeString(strings.TrimSpace(string(raw)))
			if err != nil || len(seed) != ed25519.SeedSize {
				return nil, fmt.Errorf("invalid private key %s", name)
			}
			k := ed25519.NewKeyFromSeed(seed)
			s.priv[kid] = k
			s.pub[kid] = k.Public().(ed25519.PublicKey)
			privKids = append(privKids, kid)
		case strings.HasSuffix(name, ".pub"):
			kid := strings.TrimSuffix(name, ".pub")
			raw, err := os.ReadFile(filepath.Join(dir, name)) // #nosec G304
			if err != nil {
				return nil, fmt.Errorf("read %s: %w", name, err)
			}
			p, err := b64.DecodeString(strings.TrimSpace(string(raw)))
			if err != nil || len(p) != ed25519.PublicKeySize {
				return nil, fmt.Errorf("invalid public key %s", name)
			}
			if _, ok := s.pub[kid]; !ok {
				s.pub[kid] = p
			}
		}
	}
	if len(privKids) == 0 {
		return nil, errors.New("signer: no private key found")
	}
	sort.Strings(privKids)
	s.activeKid = privKids[len(privKids)-1]
	if raw, err := os.ReadFile(filepath.Join(dir, "active_kid")); err == nil { // #nosec G304
		kid := strings.TrimSpace(string(raw))
		if _, ok := s.priv[kid]; !ok {
			return nil, fmt.Errorf("active_kid %q has no private key", kid)
		}
		s.activeKid = kid
	}
	return s, nil
}

// ActiveKid returns the kid used for signing.
func (s *Signer) ActiveKid() string { return s.activeKid }

// Sign signs payload, returning a base64url (no padding) signature and the kid.
func (s *Signer) Sign(payload []byte) (sig, kid string) {
	return b64.EncodeToString(ed25519.Sign(s.priv[s.activeKid], payload)), s.activeKid
}

// Verify checks sig for payload under kid.
func (s *Signer) Verify(payload []byte, sig, kid string) error {
	pub, ok := s.pub[kid]
	if !ok {
		return ErrUnknownKid
	}
	raw, err := b64.DecodeString(sig)
	if err != nil {
		return fmt.Errorf("decode signature: %w", err)
	}
	if !ed25519.Verify(pub, payload, raw) {
		return errors.New("signer: bad signature")
	}
	return nil
}
