package auth

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
)

// memStore is an in-memory Store for unit tests.
type memStore struct {
	mu      sync.Mutex
	users   map[uuid.UUID]bool // id -> active
	devices map[uuid.UUID]*Device
	tokens  map[string]*RefreshRecord
}

func newMemStore() *memStore {
	return &memStore{users: map[uuid.UUID]bool{}, devices: map[uuid.UUID]*Device{}, tokens: map[string]*RefreshRecord{}}
}

func (m *memStore) InTx(_ context.Context, fn func(Store) error) error { return fn(m) }
func (m *memStore) CreateUser(_ context.Context, id uuid.UUID, _ time.Time) error {
	m.users[id] = true
	return nil
}
func (m *memStore) UserActive(_ context.Context, id uuid.UUID) (bool, error) { return m.users[id], nil }
func (m *memStore) DeviceByInstallID(_ context.Context, id uuid.UUID) (Device, error) {
	if d, ok := m.devices[id]; ok {
		return *d, nil
	}
	return Device{}, ErrNotFound
}
func (m *memStore) CreateDevice(_ context.Context, d Device, _ time.Time) error {
	m.devices[d.InstallID] = &d
	return nil
}
func (m *memStore) TouchDevice(_ context.Context, d Device, _ time.Time) error {
	m.devices[d.InstallID] = &d
	return nil
}
func (m *memStore) RebindDevice(_ context.Context, deviceID, userID uuid.UUID) error {
	for _, d := range m.devices {
		if d.ID == deviceID {
			d.UserID = userID
		}
	}
	return nil
}
func (m *memStore) InsertRefresh(_ context.Context, r RefreshRecord, _ time.Time) error {
	m.tokens[r.TokenHash] = &r
	return nil
}
func (m *memStore) RefreshForUpdate(_ context.Context, h string) (RefreshRecord, error) {
	if r, ok := m.tokens[h]; ok {
		return *r, nil
	}
	return RefreshRecord{}, ErrNotFound
}
func (m *memStore) RevokeRefresh(_ context.Context, id uuid.UUID, at time.Time) error {
	for _, r := range m.tokens {
		if r.ID == id && r.RevokedAt == nil {
			r.RevokedAt = &at
		}
	}
	return nil
}
func (m *memStore) RevokeFamily(_ context.Context, f uuid.UUID, at time.Time) error {
	for _, r := range m.tokens {
		if r.FamilyID == f && r.RevokedAt == nil {
			r.RevokedAt = &at
		}
	}
	return nil
}
func (m *memStore) RevokeUserTokens(_ context.Context, u uuid.UUID, at time.Time) error {
	for _, r := range m.tokens {
		if r.UserID == u && r.RevokedAt == nil {
			r.RevokedAt = &at
		}
	}
	return nil
}
