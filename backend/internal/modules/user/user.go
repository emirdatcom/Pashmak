// Package user owns the users table reads and account deletion (docs/10 §7).
package user

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Account is the minimal user profile.
type Account struct {
	ID          uuid.UUID
	CreatedAt   time.Time
	Active      bool
	PhoneLinked bool
}

// ErrNotFound is returned when the user does not exist.
var ErrNotFound = errors.New("user: not found")

// Store is the persistence port.
type Store interface {
	Get(ctx context.Context, id uuid.UUID) (Account, error)
	// SoftDelete marks the user deleted; reports false if already deleted.
	SoftDelete(ctx context.Context, id uuid.UUID, at time.Time) (bool, error)
}

// SessionRevoker revokes all sessions of a user (implemented by the auth module).
type SessionRevoker interface {
	RevokeAllForUser(ctx context.Context, userID uuid.UUID) error
}

// DeletionHook lets other modules (entitlement, analytics, backup) clean up when an account is
// deleted. Hooks must be idempotent: they run before the user row is marked deleted, so a failed
// request can be retried.
type DeletionHook interface {
	OnUserDeleted(ctx context.Context, userID uuid.UUID) error
}

// Service implements user operations.
type Service struct {
	store Store
	rev   SessionRevoker
	clk   clock.Clock
	hooks []DeletionHook
}

// NewService builds a Service.
func NewService(store Store, rev SessionRevoker, clk clock.Clock, hooks ...DeletionHook) *Service {
	return &Service{store: store, rev: rev, clk: clk, hooks: hooks}
}

// AddHook registers another deletion hook.
func (s *Service) AddHook(h DeletionHook) { s.hooks = append(s.hooks, h) }

// Get returns the account.
func (s *Service) Get(ctx context.Context, id uuid.UUID) (Account, error) {
	a, err := s.store.Get(ctx, id)
	if errors.Is(err, ErrNotFound) || (err == nil && !a.Active) {
		return Account{}, httpx.NewError(httpx.CodeUnauthenticated, "account not found")
	}
	if err != nil {
		return Account{}, fmt.Errorf("get user: %w", err)
	}
	return a, nil
}

// Delete deletes the account: hooks, then soft delete, then session revocation.
func (s *Service) Delete(ctx context.Context, id uuid.UUID) error {
	for _, h := range s.hooks {
		if err := h.OnUserDeleted(ctx, id); err != nil {
			return fmt.Errorf("deletion hook: %w", err)
		}
	}
	now := s.clk.Now()
	if _, err := s.store.SoftDelete(ctx, id, now); err != nil {
		return fmt.Errorf("soft delete user: %w", err)
	}
	if err := s.rev.RevokeAllForUser(ctx, id); err != nil {
		return fmt.Errorf("revoke sessions: %w", err)
	}
	return nil
}
