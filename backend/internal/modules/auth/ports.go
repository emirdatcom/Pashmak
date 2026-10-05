// Package auth implements anonymous device identity, JWT access tokens and rotating refresh tokens.
package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
)

// Errors returned by Store.
var (
	ErrNotFound = errors.New("auth: not found")
	ErrConflict = errors.New("auth: conflict")
)

// Device is a registered installation.
type Device struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	InstallID  uuid.UUID
	DeviceHash string
	Market     string
	AppVersion string
	OSVersion  string
	Model      string
}

// RefreshRecord is a stored refresh token (hash only).
type RefreshRecord struct {
	ID        uuid.UUID
	DeviceID  uuid.UUID
	UserID    uuid.UUID
	TokenHash string
	FamilyID  uuid.UUID
	ExpiresAt time.Time
	RevokedAt *time.Time
}

// Store is the persistence port.
type Store interface {
	// InTx runs fn in a transaction; fn receives a Store bound to it.
	InTx(ctx context.Context, fn func(Store) error) error
	CreateUser(ctx context.Context, id uuid.UUID, at time.Time) error
	UserActive(ctx context.Context, id uuid.UUID) (bool, error)
	DeviceByInstallID(ctx context.Context, installID uuid.UUID) (Device, error)
	CreateDevice(ctx context.Context, d Device, at time.Time) error // ErrConflict on duplicate install_id
	TouchDevice(ctx context.Context, d Device, at time.Time) error
	RebindDevice(ctx context.Context, deviceID, userID uuid.UUID) error
	InsertRefresh(ctx context.Context, r RefreshRecord, at time.Time) error
	RefreshForUpdate(ctx context.Context, tokenHash string) (RefreshRecord, error)
	RevokeRefresh(ctx context.Context, id uuid.UUID, at time.Time) error
	RevokeFamily(ctx context.Context, familyID uuid.UUID, at time.Time) error
	RevokeUserTokens(ctx context.Context, userID uuid.UUID, at time.Time) error
}
