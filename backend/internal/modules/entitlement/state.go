package entitlement

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// Entry is one active entitlement.
type Entry struct {
	Key      string `json:"key"`
	Source   string `json:"source"`
	StartsAt string `json:"starts_at"`
	EndsAt   string `json:"ends_at"`
}

// TrialInfo is the trial block of EntitlementState.
type TrialInfo struct {
	Eligible bool    `json:"eligible"`
	Used     bool    `json:"used"`
	EndsAt   *string `json:"ends_at"`
}

// StateBody are the signed fields of EntitlementState.
type StateBody struct {
	Entitlements []Entry   `json:"entitlements"`
	Trial        TrialInfo `json:"trial"`
	ServerTime   string    `json:"server_time"`
	ValidUntil   string    `json:"valid_until"`
	GraceDays    int       `json:"grace_days"`
}

// State is the signed EntitlementState (docs/10 §6.2).
type State struct {
	StateBody
	Signature string `json:"signature"`
	Kid       string `json:"kid"`
}

// FormatTime renders RFC3339 UTC with seconds and no fraction.
func FormatTime(t time.Time) string {
	return t.UTC().Truncate(time.Second).Format("2006-01-02T15:04:05Z")
}

// Service issues entitlement state and manages trials and grants.
type Service struct {
	pool   *db.Pool
	signer Signer
	clk    clock.Clock
	cfg    ConfigReader
}

// NewService builds a Service. cfg may be nil (defaults are used).
func NewService(pool *db.Pool, signer Signer, clk clock.Clock, cfg ConfigReader) *Service {
	if cfg == nil {
		cfg = StaticConfig{}
	}
	return &Service{pool: pool, signer: signer, clk: clk, cfg: cfg}
}

// Sign canonicalizes body and signs it.
func (s *Service) Sign(body StateBody) (State, error) {
	canon, err := Canonicalize(body)
	if err != nil {
		return State{}, err
	}
	sig, kid := s.signer.Sign(canon)
	return State{StateBody: body, Signature: sig, Kid: kid}, nil
}

// VerifyState checks a State's signature (used by tests and tooling).
func (s *Service) VerifyState(st State) error {
	canon, err := Canonicalize(st.StateBody)
	if err != nil {
		return err
	}
	if err := s.signer.Verify(canon, st.Signature, st.Kid); err != nil {
		return fmt.Errorf("verify state: %w", err)
	}
	return nil
}

// State returns the signed state for the user, as seen from deviceID (trial eligibility is per device).
func (s *Service) State(ctx context.Context, userID, deviceID uuid.UUID) (State, error) {
	return s.stateWith(ctx, dbgen.New(s.pool), userID, deviceID)
}

func (s *Service) stateWith(ctx context.Context, q *dbgen.Queries, userID, deviceID uuid.UUID) (State, error) {
	now := s.clk.Now()
	cfg := s.cfg.Entitlement(ctx)
	grants, err := q.ListActiveGrants(ctx, dbgen.ListActiveGrantsParams{UserID: userID, EndsAt: now})
	if err != nil {
		return State{}, fmt.Errorf("list grants: %w", err)
	}
	body := StateBody{Entitlements: []Entry{}, ServerTime: FormatTime(now), GraceDays: cfg.GraceDays}
	validUntil := now.Add(time.Duration(cfg.OfflineValidityDays) * 24 * time.Hour)
	var maxEnd time.Time
	for _, g := range grants {
		body.Entitlements = append(body.Entitlements, Entry{Key: g.Entitlement, Source: g.Source,
			StartsAt: FormatTime(g.StartsAt), EndsAt: FormatTime(g.EndsAt)})
		if g.EndsAt.After(maxEnd) {
			maxEnd = g.EndsAt
		}
	}
	if !maxEnd.IsZero() && maxEnd.Before(validUntil) {
		validUntil = maxEnd
	}
	body.ValidUntil = FormatTime(validUntil)

	userTrial, err := q.GetTrialByUser(ctx, userID)
	hasTrial := err == nil
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return State{}, fmt.Errorf("get trial: %w", err)
	}
	deviceUsed := false
	if dev, derr := q.GetDeviceByID(ctx, deviceID); derr == nil {
		if _, terr := q.GetTrialByDeviceHash(ctx, dev.DeviceHash); terr == nil {
			deviceUsed = true
		} else if !errors.Is(terr, pgx.ErrNoRows) {
			return State{}, fmt.Errorf("get trial by device: %w", terr)
		}
	} else if !errors.Is(derr, pgx.ErrNoRows) {
		return State{}, fmt.Errorf("get device: %w", derr)
	}
	body.Trial = TrialInfo{Used: hasTrial || deviceUsed}
	body.Trial.Eligible = cfg.TrialEnabled && !body.Trial.Used
	if hasTrial {
		e := FormatTime(userTrial.EndsAt)
		body.Trial.EndsAt = &e
	}
	return s.Sign(body)
}

// maxProvisionalAge is how far back an offline trial start is honored (docs/60 §4).
const maxProvisionalAge = 48 * time.Hour

// StartTrial starts the one-time trial for the user's device (docs/60 §4). It is idempotent for the
// user who already holds the trial (outbox retries).
func (s *Service) StartTrial(ctx context.Context, userID, deviceID uuid.UUID, provisional *time.Time) (State, error) {
	cfg := s.cfg.Entitlement(ctx)
	if !cfg.TrialEnabled {
		return State{}, httpx.NewError(httpx.CodeTrialDisabled, "trial is disabled")
	}
	now := s.clk.Now()
	started := now
	if provisional != nil && !provisional.After(now.Add(5*time.Minute)) && !provisional.Before(now.Add(-maxProvisionalAge)) {
		started = provisional.UTC()
		if started.After(now) {
			started = now
		}
	}
	err := s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		if _, err := q.GetTrialByUser(ctx, userID); err == nil {
			return nil // already started by this user: idempotent
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("get trial: %w", err)
		}
		dev, err := q.GetDeviceByID(ctx, deviceID)
		if err != nil {
			return fmt.Errorf("get device: %w", err)
		}
		if _, err := q.GetTrialByDeviceHash(ctx, dev.DeviceHash); err == nil {
			return httpx.NewError(httpx.CodeTrialAlreadyUsed, "trial already used on this device")
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("get trial by device: %w", err)
		}
		ends := started.Add(time.Duration(cfg.TrialDays) * 24 * time.Hour)
		tid, err := uuid.NewV7()
		if err != nil {
			return fmt.Errorf("uuid: %w", err)
		}
		if err := q.InsertTrial(ctx, dbgen.InsertTrialParams{ID: tid, UserID: userID, DeviceHash: dev.DeviceHash,
			StartedAt: started, EndsAt: ends}); err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == "23505" {
				return httpx.NewError(httpx.CodeTrialAlreadyUsed, "trial already used on this device")
			}
			return fmt.Errorf("insert trial: %w", err)
		}
		return s.insertGrant(ctx, q, userID, "trial", uuid.NullUUID{}, "", started, ends, now)
	})
	if err != nil {
		return State{}, err
	}
	return s.State(ctx, userID, deviceID)
}

func (s *Service) insertGrant(ctx context.Context, q *dbgen.Queries, userID uuid.UUID, source string,
	purchaseID uuid.NullUUID, reason string, starts, ends, now time.Time) error {
	gid, err := uuid.NewV7()
	if err != nil {
		return fmt.Errorf("uuid: %w", err)
	}
	if err := q.InsertGrant(ctx, dbgen.InsertGrantParams{ID: gid, UserID: userID, Source: source,
		PurchaseID: purchaseID, Reason: reason, StartsAt: starts, EndsAt: ends, CreatedAt: now}); err != nil {
		return fmt.Errorf("insert grant: %w", err)
	}
	return nil
}
