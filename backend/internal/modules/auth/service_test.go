package auth

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
)

func newSvc(t *testing.T) (*Service, *memStore, *clock.Fake) {
	t.Helper()
	dir := t.TempDir()
	if err := signer.Generate(dir, "at-1"); err != nil {
		t.Fatal(err)
	}
	sg, err := signer.LoadWithPrefix(dir, "at-")
	if err != nil {
		t.Fatal(err)
	}
	clk := clock.NewFake(time.Date(2026, 10, 5, 8, 0, 0, 0, time.UTC))
	st := newMemStore()
	return NewService(st, sg, clk, "salt"), st, clk
}

func input(install string) DeviceInput {
	return DeviceInput{InstallID: install, DeviceHashRaw: "android-id", Market: "bazaar",
		AppVersion: "1.0.0", OSVersion: "13", Model: "Pixel"}
}

func code(err error) httpx.Code { c, _ := httpx.CodeOf(err); return c }

func TestRegisterIdempotentPerInstall(t *testing.T) {
	s, st, _ := newSvc(t)
	ctx := context.Background()
	id := uuid.NewString()
	a, err := s.RegisterDevice(ctx, input(id))
	if err != nil {
		t.Fatal(err)
	}
	b, err := s.RegisterDevice(ctx, input(id))
	if err != nil || a.UserID != b.UserID {
		t.Fatalf("same install must keep user: %v %v %v", err, a.UserID, b.UserID)
	}
	// New install, same hardware: new user, same device_hash.
	c, err := s.RegisterDevice(ctx, input(uuid.NewString()))
	if err != nil || c.UserID == a.UserID {
		t.Fatalf("new install must be a new user: %v", err)
	}
	hashes := map[string]bool{}
	for _, d := range st.devices {
		hashes[d.DeviceHash] = true
		if strings.Contains(d.DeviceHash, "android-id") || len(d.DeviceHash) != 64 {
			t.Fatalf("bad hash %q", d.DeviceHash)
		}
	}
	if len(hashes) != 1 {
		t.Fatalf("device_hash should match across installs: %v", hashes)
	}
}

func TestRegisterValidation(t *testing.T) {
	s, _, _ := newSvc(t)
	bad := []DeviceInput{input("nope"), func() DeviceInput { i := input(uuid.NewString()); i.Market = "play"; return i }(),
		func() DeviceInput { i := input(uuid.NewString()); i.DeviceHashRaw = ""; return i }(),
		func() DeviceInput { i := input(uuid.NewString()); i.DeviceHashRaw = strings.Repeat("x", 129); return i }()}
	for i, in := range bad {
		if _, err := s.RegisterDevice(context.Background(), in); code(err) != httpx.CodeInvalidInput {
			t.Errorf("case %d: %v", i, err)
		}
	}
}

func TestRefreshRotationAndReuse(t *testing.T) {
	s, _, clk := newSvc(t)
	ctx := context.Background()
	a, _ := s.RegisterDevice(ctx, input(uuid.NewString()))
	b, err := s.Refresh(ctx, a.RefreshToken)
	if err != nil || b.RefreshToken == a.RefreshToken {
		t.Fatalf("rotate: %v", err)
	}
	clk.Advance(time.Minute)
	// Reuse of the old token: TOKEN_REUSED and the new one is revoked too.
	if _, err := s.Refresh(ctx, a.RefreshToken); code(err) != httpx.CodeTokenReused {
		t.Fatalf("want TOKEN_REUSED, got %v", err)
	}
	if _, err := s.Refresh(ctx, b.RefreshToken); code(err) != httpx.CodeTokenReused {
		t.Fatalf("family should be revoked, got %v", err)
	}
	if _, err := s.Refresh(ctx, "unknown-token"); code(err) != httpx.CodeTokenInvalid {
		t.Fatalf("want TOKEN_INVALID, got %v", err)
	}
}

func TestRefreshExpiry(t *testing.T) {
	s, _, clk := newSvc(t)
	ctx := context.Background()
	a, _ := s.RegisterDevice(ctx, input(uuid.NewString()))
	clk.Advance(refreshTTL + time.Second)
	if _, err := s.Refresh(ctx, a.RefreshToken); code(err) != httpx.CodeTokenInvalid {
		t.Fatalf("want TOKEN_INVALID, got %v", err)
	}
}

func TestAccessTokenLifecycle(t *testing.T) {
	s, _, clk := newSvc(t)
	ctx := context.Background()
	a, _ := s.RegisterDevice(ctx, input(uuid.NewString()))
	p, err := s.Authenticate(ctx, a.AccessToken)
	if err != nil || p.UserID != a.UserID {
		t.Fatalf("auth: %v", err)
	}
	// Tampered payload.
	parts := strings.Split(a.AccessToken, ".")
	if _, err := s.Authenticate(ctx, parts[0]+"."+parts[1]+"x."+parts[2]); code(err) != httpx.CodeUnauthenticated {
		t.Fatalf("tampered: %v", err)
	}
	// Foreign signer (unknown kid) rejected.
	other, _, _ := newSvc(t)
	b, _ := other.RegisterDevice(ctx, input(uuid.NewString()))
	if _, err := s.Authenticate(ctx, b.AccessToken); err == nil {
		t.Fatal("token from another key set must be rejected")
	}
	clk.Advance(accessTTL + time.Second)
	if _, err := s.Authenticate(ctx, a.AccessToken); code(err) != httpx.CodeUnauthenticated {
		t.Fatalf("expired: %v", err)
	}
}

func TestRevokeAllAndDeletedUser(t *testing.T) {
	s, st, _ := newSvc(t)
	ctx := context.Background()
	a, _ := s.RegisterDevice(ctx, input(uuid.NewString()))
	st.users[a.UserID] = false // simulate soft delete
	if err := s.RevokeAllForUser(ctx, a.UserID); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Authenticate(ctx, a.AccessToken); code(err) != httpx.CodeUnauthenticated {
		t.Fatalf("deleted user must be 401, got %v", err)
	}
	if _, err := s.Refresh(ctx, a.RefreshToken); code(err) != httpx.CodeTokenInvalid {
		t.Fatal("refresh after delete must fail")
	}
	// Re-registering the same install after deletion starts a fresh user.
	again, err := s.RegisterDevice(ctx, input(st.firstInstall()))
	if err != nil || again.UserID == a.UserID {
		t.Fatalf("re-register: %v", err)
	}
}

func (m *memStore) firstInstall() string {
	for id := range m.devices {
		return id.String()
	}
	return ""
}
