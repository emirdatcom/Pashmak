package entitlement

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// The methods below take the caller's transaction so billing can create purchases and grants atomically.

// AddPassGrant adds a period grant that accumulates after the user's current premium end
// (starts_at = max(now, latest end), docs/60 §2).
func (s *Service) AddPassGrant(ctx context.Context, q *dbgen.Queries, userID, purchaseID uuid.UUID, dur time.Duration) (time.Time, error) {
	now := s.clk.Now()
	latest, err := q.LatestGrantEnd(ctx, userID)
	if err != nil {
		return time.Time{}, fmt.Errorf("latest grant end: %w", err)
	}
	starts := now
	if latest.After(now) {
		starts = latest
	}
	ends := starts.Add(dur)
	return ends, s.insertGrant(ctx, q, userID, "pass", uuid.NullUUID{UUID: purchaseID, Valid: true}, "", starts, ends, now)
}

// UpsertSubscriptionGrant creates or updates the single grant of a subscription purchase so it ends
// at the market's expires_at.
func (s *Service) UpsertSubscriptionGrant(ctx context.Context, q *dbgen.Queries, userID, purchaseID uuid.UUID, starts, ends time.Time) error {
	g, err := q.GetGrantByPurchase(ctx, uuid.NullUUID{UUID: purchaseID, Valid: true})
	if err == nil {
		if ends.IsZero() {
			return nil // the market gave no expiry this time: keep the known end rather than ending premium
		}
		if err := q.UpdateGrantEnd(ctx, dbgen.UpdateGrantEndParams{ID: g.ID, EndsAt: ends}); err != nil {
			return fmt.Errorf("update grant: %w", err)
		}
		return nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("get grant: %w", err)
	}
	if !ends.After(starts) {
		return nil
	}
	return s.insertGrant(ctx, q, userID, "subscription", uuid.NullUUID{UUID: purchaseID, Valid: true}, "", starts, ends, s.clk.Now())
}

// RevokePurchaseGrants revokes all grants created by a purchase (refund/cancel/transfer).
func (s *Service) RevokePurchaseGrants(ctx context.Context, q *dbgen.Queries, purchaseID uuid.UUID) error {
	if err := q.RevokeGrantsByPurchase(ctx, dbgen.RevokeGrantsByPurchaseParams{
		PurchaseID: uuid.NullUUID{UUID: purchaseID, Valid: true}, RevokedAt: ptr(s.clk.Now())}); err != nil {
		return fmt.Errorf("revoke grants: %w", err)
	}
	return nil
}

func ptr[T any](v T) *T { return &v }

// GrantPromo grants premium for days (admin use, prompt 04). reason is required and audited by the caller.
func (s *Service) GrantPromo(ctx context.Context, userID uuid.UUID, days int, reason string) error {
	if days < 1 || days > 3650 || reason == "" {
		return httpx.NewError(httpx.CodeInvalidInput, "days (1..3650) and reason are required")
	}
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		now := s.clk.Now()
		latest, err := q.LatestGrantEnd(ctx, userID)
		if err != nil {
			return fmt.Errorf("latest grant end: %w", err)
		}
		starts := now
		if latest.After(now) {
			starts = latest
		}
		return s.insertGrant(ctx, q, userID, "promo", uuid.NullUUID{}, reason, starts, starts.Add(time.Duration(days)*24*time.Hour), now)
	})
}

// OnUserDeleted implements user.DeletionHook: grants are revoked; purchases stay for auditing.
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	if err := dbgen.New(s.pool).RevokeUserGrants(ctx, dbgen.RevokeUserGrantsParams{UserID: userID, RevokedAt: ptr(s.clk.Now())}); err != nil {
		return fmt.Errorf("revoke user grants: %w", err)
	}
	return nil
}
