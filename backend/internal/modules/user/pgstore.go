package user

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

// PGStore implements Store on PostgreSQL via sqlc.
type PGStore struct{ q *dbgen.Queries }

// NewPGStore builds a PGStore from a pgx pool or tx.
func NewPGStore(db dbgen.DBTX) *PGStore { return &PGStore{q: dbgen.New(db)} }

// Get implements Store.
func (s *PGStore) Get(ctx context.Context, id uuid.UUID) (Account, error) {
	u, err := s.q.GetUser(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return Account{}, ErrNotFound
	}
	if err != nil {
		return Account{}, fmt.Errorf("query user: %w", err)
	}
	return Account{ID: u.ID, CreatedAt: u.CreatedAt, Active: u.Status == "active", PhoneLinked: u.PhoneVerifiedAt != nil}, nil
}

// SoftDelete implements Store.
func (s *PGStore) SoftDelete(ctx context.Context, id uuid.UUID, at time.Time) (bool, error) {
	n, err := s.q.SoftDeleteUser(ctx, dbgen.SoftDeleteUserParams{ID: id, DeletedAt: &at})
	if err != nil {
		return false, fmt.Errorf("soft delete: %w", err)
	}
	return n > 0, nil
}
