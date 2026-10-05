package billing

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

const (
	marketTimeout = 8 * time.Second
	maxTokenLen   = 4096
	maxRestore    = 50
)

// Options configure a Service.
type Options struct {
	Pool       *db.Pool
	Entitle    *entitlement.Service
	Registry   Registry
	Clock      clock.Clock
	EncKey     []byte                      // DATA_ENC_KEY (32 bytes)
	Sink       ServerEventSink             // optional
	Observe    func(market, result string) // optional: market_verify_total{market,result}
	Backoff    []time.Duration             // retry delays; default 200ms, 600ms (2 retries)
	Sleep      func(context.Context, time.Duration)
	MarketCall time.Duration // per-attempt timeout; default 8s
}

// Service verifies purchases.
type Service struct {
	o   Options
	box *crypt.Box
}

// NewService builds a Service.
func NewService(o Options) (*Service, error) {
	g, err := crypt.New(o.EncKey)
	if err != nil {
		return nil, err
	}
	if o.Sink == nil {
		o.Sink = NoopSink{}
	}
	if o.Observe == nil {
		o.Observe = func(string, string) {}
	}
	if o.Backoff == nil {
		o.Backoff = []time.Duration{200 * time.Millisecond, 600 * time.Millisecond}
	}
	if o.Sleep == nil {
		o.Sleep = func(ctx context.Context, d time.Duration) {
			select {
			case <-ctx.Done():
			case <-time.After(d):
			}
		}
	}
	if o.MarketCall == 0 {
		o.MarketCall = marketTimeout
	}
	return &Service{o: o, box: g}, nil
}

// PurchaseInput is one purchase from the client.
type PurchaseInput struct {
	Market        string `json:"market"`
	ProductID     string `json:"product_id"`
	MarketSKU     string `json:"market_sku"`
	PurchaseToken string `json:"purchase_token"`
	OrderID       string `json:"order_id"`
}

// Outcome is the result of verifying one purchase.
type Outcome struct {
	PurchaseID    uuid.UUID
	PurchaseState string
	CoinsGranted  int
}

func (in PurchaseInput) validate() error {
	switch {
	case in.Market != "bazaar" && in.Market != "myket":
		return httpx.NewError(httpx.CodeInvalidInput, "market must be bazaar or myket")
	case in.ProductID == "" || len(in.ProductID) > 64, in.MarketSKU == "" || len(in.MarketSKU) > 128:
		return httpx.NewError(httpx.CodeInvalidInput, "product_id and market_sku are required")
	case in.PurchaseToken == "" || len(in.PurchaseToken) > maxTokenLen:
		return httpx.NewError(httpx.CodeInvalidInput, "purchase_token is required")
	case len(in.OrderID) > 128:
		return httpx.NewError(httpx.CodeInvalidInput, "order_id too long")
	}
	return nil
}

// Verify verifies a purchase and returns the outcome plus the fresh signed state.
func (s *Service) Verify(ctx context.Context, p httpx.Principal, in PurchaseInput) (Outcome, entitlement.State, error) {
	out, err := s.verifyOne(ctx, p, in)
	if err != nil {
		return Outcome{}, entitlement.State{}, err
	}
	st, err := s.o.Entitle.State(ctx, p.UserID, p.DeviceID)
	return out, st, err
}

// Restore re-verifies the purchases the market SDK reports and returns the fresh state.
func (s *Service) Restore(ctx context.Context, p httpx.Principal, market string, items []PurchaseInput) (entitlement.State, error) {
	if len(items) > maxRestore {
		return entitlement.State{}, httpx.NewError(httpx.CodeInvalidInput, "too many purchases")
	}
	succeeded, claimed := 0, 0
	for _, it := range items {
		it.Market = market
		_, err := s.verifyOne(ctx, p, it)
		switch code, _ := httpx.CodeOf(err); {
		case err == nil:
			succeeded++
		case code == httpx.CodePurchaseClaimed:
			claimed++
		case code == httpx.CodePurchaseInvalid:
			// expired/forged entries in a restore list are skipped
		default:
			return entitlement.State{}, err
		}
	}
	if succeeded == 0 && claimed > 0 {
		return entitlement.State{}, httpx.NewError(httpx.CodePurchaseClaimed, "purchase belongs to another account")
	}
	return s.o.Entitle.State(ctx, p.UserID, p.DeviceID)
}

func (s *Service) verifyOne(ctx context.Context, p httpx.Principal, in PurchaseInput) (Outcome, error) {
	if err := in.validate(); err != nil {
		return Outcome{}, err
	}
	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		out, err := s.verifyAttempt(ctx, p, in)
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			lastErr = err // concurrent claim of the same token: re-run so the ownership check decides
			continue
		}
		return out, err
	}
	return Outcome{}, fmt.Errorf("verify purchase: %w", lastErr)
}

func (s *Service) verifyAttempt(ctx context.Context, p httpx.Principal, in PurchaseInput) (Outcome, error) {
	verifier, ok := s.o.Registry[in.Market]
	if !ok {
		return Outcome{}, httpx.NewError(httpx.CodeMarketUnavailable, "market is not available")
	}
	q := dbgen.New(s.o.Pool)
	product, err := q.GetProduct(ctx, dbgen.GetProductParams{ID: in.ProductID, Market: in.Market})
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && product.MarketSku != in.MarketSKU) {
		return Outcome{}, httpx.NewError(httpx.CodeInvalidInput, "unknown product")
	}
	if err != nil {
		return Outcome{}, fmt.Errorf("get product: %w", err)
	}
	hash := hashToken(in.PurchaseToken)

	existing, err := q.GetPurchaseByToken(ctx, dbgen.GetPurchaseByTokenParams{Market: in.Market, PurchaseTokenHash: hash})
	found := err == nil
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return Outcome{}, fmt.Errorf("get purchase: %w", err)
	}
	transfer := false
	if found {
		if existing.UserID != p.UserID {
			ok, terr := s.canTransfer(ctx, q, existing, product, p)
			if terr != nil {
				return Outcome{}, terr
			}
			if !ok {
				return Outcome{}, httpx.NewError(httpx.CodePurchaseClaimed, "purchase already claimed by another account")
			}
			transfer = true
		} else if existing.State == "verified" {
			return s.outcome(existing, product), nil // idempotent
		}
	}

	mp, err := s.callMarket(ctx, verifier, product.MarketSku, in.PurchaseToken)
	if err != nil {
		s.o.Observe(in.Market, "unavailable")
		return Outcome{}, httpx.NewError(httpx.CodeMarketUnavailable, "market did not respond")
	}
	s.o.Observe(in.Market, string(mp.State))
	if mp.State == MarketInvalid {
		return Outcome{}, httpx.NewError(httpx.CodePurchaseInvalid, "purchase could not be verified")
	}

	var out Outcome
	err = s.o.Pool.WithTx(ctx, func(tx pgx.Tx) error {
		tq := dbgen.New(tx)
		now := s.o.Clock.Now()
		state := purchaseState(mp, product, now)
		raw := mp.Raw
		if len(raw) == 0 {
			raw = []byte("{}")
		}
		var purchase dbgen.Purchase
		remaining := time.Duration(0)
		switch {
		case !found:
			enc, eerr := s.box.Encrypt([]byte(in.PurchaseToken))
			if eerr != nil {
				return eerr
			}
			id, uerr := uuid.NewV7()
			if uerr != nil {
				return fmt.Errorf("uuid: %w", uerr)
			}
			orderID := mp.OrderID
			if orderID == "" {
				orderID = in.OrderID
			}
			purchase, err = tq.InsertPurchase(ctx, dbgen.InsertPurchaseParams{ID: id, UserID: p.UserID, DeviceID: p.DeviceID,
				Market: in.Market, ProductID: product.ID, MarketOrderID: orderID, PurchaseTokenHash: hash,
				PurchaseTokenEnc: enc, State: state, PurchasedAt: nonZero(mp.PurchasedAt, now), VerifiedAt: &now,
				ExpiresAt: optTime(mp.ExpiresAt), AutoRenewing: mp.AutoRenewing, RawResponse: raw, CreatedAt: now})
			if err != nil {
				return fmt.Errorf("insert purchase: %w", err)
			}
		default:
			purchase = existing
			if transfer {
				if product.Kind == "pass" {
					if g, gerr := tq.GetGrantByPurchase(ctx, uuid.NullUUID{UUID: existing.ID, Valid: true}); gerr == nil {
						remaining = g.EndsAt.Sub(now)
					}
				}
				if err := s.o.Entitle.RevokePurchaseGrants(ctx, tq, existing.ID); err != nil {
					return err
				}
				if err := tq.TransferPurchase(ctx, dbgen.TransferPurchaseParams{ID: existing.ID, UserID: p.UserID, DeviceID: p.DeviceID}); err != nil {
					return fmt.Errorf("transfer purchase: %w", err)
				}
			}
			if err := tq.UpdatePurchaseVerification(ctx, dbgen.UpdatePurchaseVerificationParams{ID: existing.ID,
				State: state, VerifiedAt: &now, ExpiresAt: optTime(mp.ExpiresAt), AutoRenewing: mp.AutoRenewing, RawResponse: raw}); err != nil {
				return fmt.Errorf("update purchase: %w", err)
			}
			purchase.State = state
		}
		if err := s.applyGrants(ctx, tq, p.UserID, purchase, product, mp, state, remaining, transfer); err != nil {
			return err
		}
		out = s.outcome(purchase, product)
		return nil
	})
	if err != nil {
		return Outcome{}, err
	}
	if out.PurchaseState == "refunded" || out.PurchaseState == "canceled" {
		return Outcome{}, httpx.NewError(httpx.CodePurchaseInvalid, "purchase was refunded or canceled")
	}
	slog.InfoContext(ctx, "purchase verified", "market", in.Market, "product_id", product.ID,
		"state", out.PurchaseState, "token_tag", tokenTag(hash))
	return out, nil
}

func (s *Service) outcome(p dbgen.Purchase, pr dbgen.Product) Outcome {
	o := Outcome{PurchaseID: p.ID, PurchaseState: p.State}
	if pr.Kind == "consumable" && p.State == "verified" && pr.CoinsAmount != nil {
		o.CoinsGranted = int(*pr.CoinsAmount)
	}
	return o
}

// canTransfer allows moving a pass/subscription purchase from another account when that account
// used the same device (same device_hash). Consumables are never transferred (docs/60 §7).
func (s *Service) canTransfer(ctx context.Context, q *dbgen.Queries, existing dbgen.Purchase, pr dbgen.Product, p httpx.Principal) (bool, error) {
	if pr.Kind == "consumable" {
		return false, nil
	}
	dev, err := q.GetDeviceByID(ctx, p.DeviceID)
	if err != nil {
		return false, fmt.Errorf("get device: %w", err)
	}
	same, err := q.UserHasDeviceHash(ctx, dbgen.UserHasDeviceHashParams{UserID: existing.UserID, DeviceHash: dev.DeviceHash})
	if err != nil {
		return false, fmt.Errorf("check device hash: %w", err)
	}
	return same, nil
}

func purchaseState(mp MarketPurchase, pr dbgen.Product, now time.Time) string {
	switch mp.State {
	case MarketRefunded:
		return "refunded"
	case MarketCanceled:
		return "canceled"
	case MarketExpired:
		return "expired"
	}
	if pr.Kind == "subscription" && !mp.ExpiresAt.IsZero() && !mp.ExpiresAt.After(now) {
		return "expired"
	}
	return "verified"
}

func (s *Service) applyGrants(ctx context.Context, q *dbgen.Queries, userID uuid.UUID, purchase dbgen.Purchase,
	pr dbgen.Product, mp MarketPurchase, state string, remaining time.Duration, transfer bool) error {
	if state == "refunded" || state == "canceled" {
		return s.o.Entitle.RevokePurchaseGrants(ctx, q, purchase.ID)
	}
	if state != "verified" {
		return nil
	}
	switch pr.Kind {
	case "subscription":
		starts := nonZero(mp.PurchasedAt, s.o.Clock.Now())
		return s.o.Entitle.UpsertSubscriptionGrant(ctx, q, userID, purchase.ID, starts, mp.ExpiresAt)
	case "pass":
		if _, err := q.GetGrantByPurchase(ctx, uuid.NullUUID{UUID: purchase.ID, Valid: true}); err == nil {
			return nil
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("get grant: %w", err)
		}
		dur := time.Duration(0)
		if pr.DurationDays != nil {
			dur = time.Duration(*pr.DurationDays) * 24 * time.Hour
		}
		if transfer {
			dur = remaining
		}
		if dur <= 0 {
			return nil
		}
		_, err := s.o.Entitle.AddPassGrant(ctx, q, userID, purchase.ID, dur)
		return err
	}
	return nil
}

// callMarket calls the verifier with a per-attempt timeout and up to len(Backoff) retries.
func (s *Service) callMarket(ctx context.Context, v MarketVerifier, sku, token string) (MarketPurchase, error) {
	var lastErr error
	for attempt := 0; ; attempt++ {
		actx, cancel := context.WithTimeout(ctx, s.o.MarketCall)
		mp, err := v.Verify(actx, sku, token)
		cancel()
		if err == nil {
			return mp, nil
		}
		lastErr = err
		if ctx.Err() != nil || attempt >= len(s.o.Backoff) {
			return MarketPurchase{}, fmt.Errorf("market verify: %w", lastErr)
		}
		s.o.Sleep(ctx, s.o.Backoff[attempt])
	}
}

func nonZero(t, def time.Time) time.Time {
	if t.IsZero() {
		return def
	}
	return t
}

func optTime(t time.Time) *time.Time {
	if t.IsZero() {
		return nil
	}
	return &t
}

// ReverifySubscriptions re-checks subscriptions that expire within 48h or were bought in the last
// 7 days (docs/10 §8). It records renewals, auto-renew changes, refunds and cancellations.
func (s *Service) ReverifySubscriptions(ctx context.Context) error {
	q := dbgen.New(s.o.Pool)
	now := s.o.Clock.Now()
	list, err := q.ListPurchasesForReverify(ctx, dbgen.ListPurchasesForReverifyParams{Column1: now, Limit: 500})
	if err != nil {
		return fmt.Errorf("list purchases: %w", err)
	}
	for _, pu := range list {
		if err := s.reverifyOne(ctx, pu); err != nil {
			slog.ErrorContext(ctx, "reverify failed", "purchase_id", pu.ID.String(), "market", pu.Market,
				"token_tag", tokenTag(pu.PurchaseTokenHash), "err", err)
		}
	}
	return nil
}

func (s *Service) reverifyOne(ctx context.Context, pu dbgen.Purchase) error {
	verifier, ok := s.o.Registry[pu.Market]
	if !ok {
		return nil
	}
	q := dbgen.New(s.o.Pool)
	pr, err := q.GetProductAnyState(ctx, dbgen.GetProductAnyStateParams{ID: pu.ProductID, Market: pu.Market})
	if err != nil {
		return fmt.Errorf("get product: %w", err)
	}
	token, err := s.box.Decrypt(pu.PurchaseTokenEnc)
	if err != nil {
		return err
	}
	mp, err := s.callMarket(ctx, verifier, pr.MarketSku, string(token))
	if err != nil {
		s.o.Observe(pu.Market, "unavailable")
		return nil // try again next run; do not touch grants on market errors
	}
	s.o.Observe(pu.Market, string(mp.State))
	if mp.State == MarketInvalid {
		return nil // never revoke on an ambiguous answer
	}
	now := s.o.Clock.Now()
	state := purchaseState(mp, pr, now)
	raw := mp.Raw
	if len(raw) == 0 {
		raw = json.RawMessage("{}")
	}
	wasRenewing := pu.AutoRenewing
	err = s.o.Pool.WithTx(ctx, func(tx pgx.Tx) error {
		tq := dbgen.New(tx)
		if err := tq.UpdatePurchaseVerification(ctx, dbgen.UpdatePurchaseVerificationParams{ID: pu.ID, State: state,
			VerifiedAt: &now, ExpiresAt: optTime(mp.ExpiresAt), AutoRenewing: mp.AutoRenewing, RawResponse: raw}); err != nil {
			return fmt.Errorf("update purchase: %w", err)
		}
		pu.State = state
		return s.applyGrants(ctx, tq, pu.UserID, pu, pr, mp, state, 0, false)
	})
	if err != nil {
		return err
	}
	if state == "refunded" || state == "canceled" || (wasRenewing && !mp.AutoRenewing && state == "verified") {
		if err := s.o.Sink.Emit(ctx, "subscription_canceled", pu.UserID, map[string]any{"product_id": pu.ProductID}); err != nil {
			slog.WarnContext(ctx, "emit subscription_canceled", "err", err)
		}
	}
	return nil
}
