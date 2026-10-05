package auth

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

const (
	accessTTL  = time.Hour
	refreshTTL = 90 * 24 * time.Hour
)

// Service implements device registration and token lifecycle.
type Service struct {
	store  Store
	signer TokenSigner
	clk    clock.Clock
	salt   string
}

// NewService builds a Service. salt is DEVICE_HASH_SALT.
func NewService(store Store, signer TokenSigner, clk clock.Clock, salt string) *Service {
	return &Service{store: store, signer: signer, clk: clk, salt: salt}
}

// DeviceInput is the /auth/device request.
type DeviceInput struct {
	InstallID     string `json:"install_id"`
	DeviceHashRaw string `json:"device_hash_raw"`
	Market        string `json:"market"`
	AppVersion    string `json:"app_version"`
	OSVersion     string `json:"os_version"`
	Model         string `json:"model"`
}

// Session is returned by register/refresh.
type Session struct {
	UserID          uuid.UUID
	AccessToken     string
	AccessExpiresAt time.Time
	RefreshToken    string
}

func invalid(msg string) error { return httpx.NewError(httpx.CodeInvalidInput, msg) }

func within(s string, limit int) bool { return len(s) >= 1 && len(s) <= limit }

func (in DeviceInput) validate() (uuid.UUID, error) {
	id, err := uuid.Parse(in.InstallID)
	if err != nil {
		return uuid.Nil, invalid("install_id must be a UUID")
	}
	switch {
	case !within(in.DeviceHashRaw, 128):
		return uuid.Nil, invalid("device_hash_raw must be 1..128 chars")
	case in.Market != "bazaar" && in.Market != "myket":
		return uuid.Nil, invalid("market must be bazaar or myket")
	case !within(in.AppVersion, 32), !within(in.OSVersion, 32), !within(in.Model, 64):
		return uuid.Nil, invalid("app_version, os_version and model are required")
	}
	return id, nil
}

func (s *Service) deviceHash(raw string) string {
	sum := sha256.Sum256([]byte(s.salt + raw))
	return hex.EncodeToString(sum[:])
}

// RegisterDevice creates or refreshes the device (idempotent per install_id) and issues a session.
func (s *Service) RegisterDevice(ctx context.Context, in DeviceInput) (Session, error) {
	installID, err := in.validate()
	if err != nil {
		return Session{}, err
	}
	var out Session
	for attempt := 0; attempt < 2; attempt++ {
		out, err = s.registerOnce(ctx, installID, in)
		if !errors.Is(err, ErrConflict) {
			break // concurrent first registration of the same install_id: retry once as "existing"
		}
	}
	if err != nil {
		return Session{}, fmt.Errorf("register device: %w", err)
	}
	return out, nil
}

func (s *Service) registerOnce(ctx context.Context, installID uuid.UUID, in DeviceInput) (Session, error) {
	var out Session
	err := s.store.InTx(ctx, func(st Store) error {
		now := s.clk.Now()
		d, err := st.DeviceByInstallID(ctx, installID)
		switch {
		case err == nil:
			active, aerr := st.UserActive(ctx, d.UserID)
			if aerr != nil {
				return aerr
			}
			if !active { // account was deleted: the install starts over as a new user
				uid, nerr := newID()
				if nerr != nil {
					return nerr
				}
				if cerr := st.CreateUser(ctx, uid, now); cerr != nil {
					return cerr
				}
				if rerr := st.RebindDevice(ctx, d.ID, uid); rerr != nil {
					return rerr
				}
				d.UserID = uid
			}
			d.Market, d.AppVersion, d.OSVersion, d.Model = in.Market, in.AppVersion, in.OSVersion, in.Model
			if terr := st.TouchDevice(ctx, d, now); terr != nil {
				return terr
			}
		case errors.Is(err, ErrNotFound):
			uid, nerr := newID()
			if nerr != nil {
				return nerr
			}
			did, nerr := newID()
			if nerr != nil {
				return nerr
			}
			if cerr := st.CreateUser(ctx, uid, now); cerr != nil {
				return cerr
			}
			d = Device{ID: did, UserID: uid, InstallID: installID, DeviceHash: s.deviceHash(in.DeviceHashRaw),
				Market: in.Market, AppVersion: in.AppVersion, OSVersion: in.OSVersion, Model: in.Model}
			if cerr := st.CreateDevice(ctx, d, now); cerr != nil {
				return cerr
			}
		default:
			return err
		}
		fam, err := newID()
		if err != nil {
			return err
		}
		out, err = s.issue(ctx, st, d.UserID, d.ID, fam, now)
		return err
	})
	return out, err
}

func newID() (uuid.UUID, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return uuid.Nil, fmt.Errorf("uuid: %w", err)
	}
	return id, nil
}

// issue creates an access JWT and a new refresh token in family.
func (s *Service) issue(ctx context.Context, st Store, userID, deviceID, family uuid.UUID, now time.Time) (Session, error) {
	access, exp, err := issueAccess(s.signer, userID, deviceID, now, accessTTL)
	if err != nil {
		return Session{}, err
	}
	refresh, err := newRefreshToken()
	if err != nil {
		return Session{}, err
	}
	rid, err := newID()
	if err != nil {
		return Session{}, err
	}
	rec := RefreshRecord{ID: rid, DeviceID: deviceID, UserID: userID, TokenHash: hashToken(refresh),
		FamilyID: family, ExpiresAt: now.Add(refreshTTL)}
	if err := st.InsertRefresh(ctx, rec, now); err != nil {
		return Session{}, err
	}
	return Session{UserID: userID, AccessToken: access, AccessExpiresAt: exp, RefreshToken: refresh}, nil
}

// Refresh rotates a refresh token. Reuse of a rotated token revokes the whole family.
func (s *Service) Refresh(ctx context.Context, token string) (Session, error) {
	if token == "" || len(token) > 256 {
		return Session{}, httpx.NewError(httpx.CodeTokenInvalid, "invalid refresh token")
	}
	hash := hashToken(token)
	var out Session
	var reused bool
	err := s.store.InTx(ctx, func(st Store) error {
		now := s.clk.Now()
		rec, err := st.RefreshForUpdate(ctx, hash)
		if errors.Is(err, ErrNotFound) {
			return httpx.NewError(httpx.CodeTokenInvalid, "invalid refresh token")
		}
		if err != nil {
			return err
		}
		if subtle.ConstantTimeCompare([]byte(rec.TokenHash), []byte(hash)) != 1 {
			return httpx.NewError(httpx.CodeTokenInvalid, "invalid refresh token")
		}
		active, err := st.UserActive(ctx, rec.UserID)
		if err != nil {
			return err
		}
		if !active { // deleted accounts get TOKEN_INVALID, never TOKEN_REUSED
			return httpx.NewError(httpx.CodeTokenInvalid, "invalid refresh token")
		}
		if rec.RevokedAt != nil {
			reused = true // commit the family revocation, then report below
			return st.RevokeFamily(ctx, rec.FamilyID, now)
		}
		if !now.Before(rec.ExpiresAt) {
			return httpx.NewError(httpx.CodeTokenInvalid, "refresh token expired")
		}
		if err := st.RevokeRefresh(ctx, rec.ID, now); err != nil {
			return err
		}
		out, err = s.issue(ctx, st, rec.UserID, rec.DeviceID, rec.FamilyID, now)
		return err
	})
	if err != nil {
		return Session{}, err
	}
	if reused {
		return Session{}, httpx.NewError(httpx.CodeTokenReused, "refresh token was already used")
	}
	return out, nil
}

// Authenticate validates an access token and that the user is still active.
func (s *Service) Authenticate(ctx context.Context, token string) (httpx.Principal, error) {
	uid, did, err := parseAccess(s.signer, token, s.clk.Now())
	if err != nil {
		return httpx.Principal{}, httpx.NewError(httpx.CodeUnauthenticated, "invalid or expired token")
	}
	active, err := s.store.UserActive(ctx, uid)
	if err != nil {
		return httpx.Principal{}, fmt.Errorf("check user: %w", err)
	}
	if !active {
		return httpx.Principal{}, httpx.NewError(httpx.CodeUnauthenticated, "account not found")
	}
	return httpx.Principal{UserID: uid, DeviceID: did}, nil
}

// RevokeAllForUser revokes every refresh token of the user (used by account deletion).
func (s *Service) RevokeAllForUser(ctx context.Context, userID uuid.UUID) error {
	if err := s.store.RevokeUserTokens(ctx, userID, s.clk.Now()); err != nil {
		return fmt.Errorf("revoke user tokens: %w", err)
	}
	return nil
}
