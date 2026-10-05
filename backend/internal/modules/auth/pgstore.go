package auth

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

// PGStore implements Store on PostgreSQL via sqlc.
type PGStore struct {
	pool *db.Pool // nil when bound to a transaction
	q    *dbgen.Queries
}

// NewPGStore builds a store on pool.
func NewPGStore(pool *db.Pool) *PGStore { return &PGStore{pool: pool, q: dbgen.New(pool)} }

// InTx implements Store.
func (s *PGStore) InTx(ctx context.Context, fn func(Store) error) error {
	if s.pool == nil { // already in a transaction
		return fn(s)
	}
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		return fn(&PGStore{q: dbgen.New(tx)})
	})
}

func wrap(op string, err error) error { return fmt.Errorf("%s: %w", op, err) }

// CreateUser implements Store.
func (s *PGStore) CreateUser(ctx context.Context, id uuid.UUID, at time.Time) error {
	if _, err := s.q.CreateUser(ctx, dbgen.CreateUserParams{ID: id, CreatedAt: at}); err != nil {
		return wrap("create user", err)
	}
	return nil
}

// UserActive implements Store.
func (s *PGStore) UserActive(ctx context.Context, id uuid.UUID) (bool, error) {
	u, err := s.q.GetUser(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, wrap("get user", err)
	}
	return u.Status == "active", nil
}

func toDevice(d dbgen.Device) Device {
	return Device{ID: d.ID, UserID: d.UserID, InstallID: d.InstallID, DeviceHash: d.DeviceHash,
		Market: d.Market, AppVersion: d.AppVersion, OSVersion: d.OsVersion, Model: d.Model}
}

// DeviceByInstallID implements Store.
func (s *PGStore) DeviceByInstallID(ctx context.Context, installID uuid.UUID) (Device, error) {
	d, err := s.q.GetDeviceByInstallID(ctx, installID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Device{}, ErrNotFound
	}
	if err != nil {
		return Device{}, wrap("get device", err)
	}
	return toDevice(d), nil
}

// CreateDevice implements Store.
func (s *PGStore) CreateDevice(ctx context.Context, d Device, at time.Time) error {
	_, err := s.q.CreateDevice(ctx, dbgen.CreateDeviceParams{
		ID: d.ID, UserID: d.UserID, InstallID: d.InstallID, DeviceHash: d.DeviceHash, Market: d.Market,
		AppVersion: d.AppVersion, OsVersion: d.OSVersion, Model: d.Model, CreatedAt: at,
	})
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ErrConflict
	}
	if err != nil {
		return wrap("create device", err)
	}
	return nil
}

// TouchDevice implements Store.
func (s *PGStore) TouchDevice(ctx context.Context, d Device, at time.Time) error {
	if err := s.q.TouchDevice(ctx, dbgen.TouchDeviceParams{ID: d.ID, AppVersion: d.AppVersion,
		OsVersion: d.OSVersion, Model: d.Model, Market: d.Market, LastSeenAt: at}); err != nil {
		return wrap("touch device", err)
	}
	return nil
}

// RebindDevice implements Store.
func (s *PGStore) RebindDevice(ctx context.Context, deviceID, userID uuid.UUID) error {
	if err := s.q.RebindDevice(ctx, dbgen.RebindDeviceParams{ID: deviceID, UserID: userID}); err != nil {
		return wrap("rebind device", err)
	}
	return nil
}

// InsertRefresh implements Store.
func (s *PGStore) InsertRefresh(ctx context.Context, r RefreshRecord, at time.Time) error {
	if err := s.q.InsertRefreshToken(ctx, dbgen.InsertRefreshTokenParams{ID: r.ID, DeviceID: r.DeviceID,
		TokenHash: r.TokenHash, FamilyID: r.FamilyID, ExpiresAt: r.ExpiresAt, CreatedAt: at}); err != nil {
		return wrap("insert refresh token", err)
	}
	return nil
}

// RefreshForUpdate implements Store.
func (s *PGStore) RefreshForUpdate(ctx context.Context, tokenHash string) (RefreshRecord, error) {
	r, err := s.q.GetRefreshTokenForUpdate(ctx, tokenHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return RefreshRecord{}, ErrNotFound
	}
	if err != nil {
		return RefreshRecord{}, wrap("get refresh token", err)
	}
	return RefreshRecord{ID: r.ID, DeviceID: r.DeviceID, UserID: r.UserID, TokenHash: r.TokenHash,
		FamilyID: r.FamilyID, ExpiresAt: r.ExpiresAt, RevokedAt: r.RevokedAt}, nil
}

// RevokeRefresh implements Store.
func (s *PGStore) RevokeRefresh(ctx context.Context, id uuid.UUID, at time.Time) error {
	if err := s.q.RevokeRefreshToken(ctx, dbgen.RevokeRefreshTokenParams{ID: id, RevokedAt: &at}); err != nil {
		return wrap("revoke refresh token", err)
	}
	return nil
}

// RevokeFamily implements Store.
func (s *PGStore) RevokeFamily(ctx context.Context, familyID uuid.UUID, at time.Time) error {
	if err := s.q.RevokeTokenFamily(ctx, dbgen.RevokeTokenFamilyParams{FamilyID: familyID, RevokedAt: &at}); err != nil {
		return wrap("revoke family", err)
	}
	return nil
}

// RevokeUserTokens implements Store.
func (s *PGStore) RevokeUserTokens(ctx context.Context, userID uuid.UUID, at time.Time) error {
	if err := s.q.RevokeUserTokens(ctx, dbgen.RevokeUserTokensParams{UserID: userID, RevokedAt: &at}); err != nil {
		return wrap("revoke user tokens", err)
	}
	return nil
}
