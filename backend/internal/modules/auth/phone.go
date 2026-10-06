package auth

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log/slog"
	"math/big"
	"strings"
	"time"
	"unicode"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

const (
	otpTTL            = 2 * time.Minute
	otpMaxAttempts    = 5
	otpPerPhonePerHr  = 3
	otpPerUserPerHr   = 6 // across all numbers: one account cannot fan codes out to many phones
	otpResendCooldown = 60 * time.Second
)

// SMSSender delivers OTP codes (sms.ir adapter, D-4/V6; `log` adapter for dev).
type SMSSender interface {
	SendOTP(ctx context.Context, phone, code string) error
}

// MergeHook moves data owned by `from` to `to` when two accounts are merged by a verified phone
// number. It runs inside the merge transaction.
type MergeHook interface {
	OnUserMerged(ctx context.Context, q *dbgen.Queries, from, to uuid.UUID) error
}

// NormalizePhone converts an Iranian mobile number to E.164 ("+989121234567"). It accepts Persian
// and Arabic-Indic digits, spaces, dashes, "09…", "9…", "98…", "+98…" and "0098…".
func NormalizePhone(in string) (string, error) {
	var digits strings.Builder
	for _, r := range in {
		switch {
		case r >= '0' && r <= '9':
			digits.WriteRune(r)
		case r >= '۰' && r <= '۹': // Persian digits
			digits.WriteRune('0' + (r - '۰'))
		case r >= '٠' && r <= '٩': // Arabic-Indic digits
			digits.WriteRune('0' + (r - '٠'))
		case r == ' ' || r == '-' || r == '(' || r == ')' || unicode.Is(unicode.Cf, r): // ZWNJ, LRM, RLM and other format marks
		case r == '+':
			if digits.Len() != 0 {
				return "", phoneInvalid()
			}
		default:
			return "", phoneInvalid()
		}
	}
	d := digits.String()
	switch {
	case strings.HasPrefix(d, "0098"):
		d = d[4:]
	case strings.HasPrefix(d, "98"):
		d = d[2:]
	case strings.HasPrefix(d, "0"):
		d = d[1:]
	}
	if len(d) != 10 || d[0] != '9' {
		return "", phoneInvalid()
	}
	return "+98" + d, nil
}

func phoneInvalid() error {
	return httpx.NewError(httpx.CodePhoneInvalid, "phone number must be an Iranian mobile number")
}

// MaskPhone returns "+98****1234" for logs.
func MaskPhone(e164 string) string {
	if len(e164) < 4 {
		return "****"
	}
	return "+98****" + e164[len(e164)-4:]
}

// PhoneService links phone numbers via OTP and merges accounts.
type PhoneService struct {
	pool  *db.Pool
	auth  *Service
	box   *crypt.Box
	sms   SMSSender
	clk   clock.Clock
	hooks []MergeHook
}

// NewPhoneService builds a PhoneService.
func NewPhoneService(pool *db.Pool, a *Service, box *crypt.Box, sms SMSSender, clk clock.Clock, hooks ...MergeHook) *PhoneService {
	return &PhoneService{pool: pool, auth: a, box: box, sms: sms, clk: clk, hooks: hooks}
}

func (s *PhoneService) phoneHash(e164 string) string { return s.box.Keyed("phone", e164) }

func (s *PhoneService) codeHash(challenge uuid.UUID, code string) string {
	return s.box.Keyed("otp", challenge.String()+":"+code)
}

func newCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(100000))
	if err != nil {
		return "", fmt.Errorf("random code: %w", err)
	}
	return fmt.Sprintf("%05d", n.Int64()), nil
}

// RequestOTP creates a challenge and sends the code. It returns the challenge id and the number of
// seconds before another code may be requested. Whether the number already belongs to an account is
// deliberately not revealed.
func (s *PhoneService) RequestOTP(ctx context.Context, p httpx.Principal, phone string) (uuid.UUID, int, error) {
	e164, err := NormalizePhone(phone)
	if err != nil {
		return uuid.Nil, 0, err
	}
	now := s.clk.Now()
	hash := s.phoneHash(e164)
	q := dbgen.New(s.pool)
	stats, err := q.OTPStatsForPhone(ctx, dbgen.OTPStatsForPhoneParams{PhoneHash: hash, CreatedAt: now.Add(-time.Hour)})
	if err != nil {
		return uuid.Nil, 0, fmt.Errorf("otp stats: %w", err)
	}
	if int(stats.SentInWindow) >= otpPerPhonePerHr || now.Sub(stats.LastSent) < otpResendCooldown {
		return uuid.Nil, 0, httpx.NewError(httpx.CodeRateLimited, "too many codes requested for this number")
	}
	byUser, err := q.OTPCountForUser(ctx, dbgen.OTPCountForUserParams{UserID: p.UserID, CreatedAt: now.Add(-time.Hour)})
	if err != nil {
		return uuid.Nil, 0, fmt.Errorf("otp count: %w", err)
	}
	if int(byUser) >= otpPerUserPerHr {
		return uuid.Nil, 0, httpx.NewError(httpx.CodeRateLimited, "too many codes requested")
	}
	code, err := newCode()
	if err != nil {
		return uuid.Nil, 0, err
	}
	id, err := newID()
	if err != nil {
		return uuid.Nil, 0, err
	}
	enc, err := s.box.Encrypt([]byte(e164))
	if err != nil {
		return uuid.Nil, 0, err
	}
	if err := q.InsertOTPChallenge(ctx, dbgen.InsertOTPChallengeParams{ID: id, UserID: p.UserID, PhoneHash: hash,
		PhoneEnc: enc, CodeHash: s.codeHash(id, code), ExpiresAt: now.Add(otpTTL), CreatedAt: now}); err != nil {
		return uuid.Nil, 0, fmt.Errorf("insert challenge: %w", err)
	}
	if err := s.sms.SendOTP(ctx, e164, code); err != nil {
		_ = q.ConsumeOTP(ctx, dbgen.ConsumeOTPParams{ID: id, ConsumedAt: &now}) // do not penalize the user for our outage
		slog.ErrorContext(ctx, "sms send failed", "phone", MaskPhone(e164), "err", err)
		return uuid.Nil, 0, httpx.NewError(httpx.CodeSMSUnavailable, "could not send the code, try again later")
	}
	slog.InfoContext(ctx, "otp sent", "phone", MaskPhone(e164))
	return id, int(otpResendCooldown.Seconds()), nil
}

// VerifyResult is the outcome of a successful verification.
type VerifyResult struct {
	Session Session
	Merged  bool
}

// VerifyOTP checks the code. On success the phone is linked to the caller or, when it belongs to
// another account A, the calling device moves to A (merged=true) and receives a session for A.
func (s *PhoneService) VerifyOTP(ctx context.Context, p httpx.Principal, challengeID, code string) (VerifyResult, error) {
	cid, err := uuid.Parse(challengeID)
	if err != nil || len(code) != 5 {
		return VerifyResult{}, httpx.NewError(httpx.CodeInvalidInput, "challenge_id and a 5-digit code are required")
	}
	var res VerifyResult
	var failure error
	err = s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		now := s.clk.Now()
		ch, gerr := q.GetOTPForUpdate(ctx, cid)
		if errors.Is(gerr, pgx.ErrNoRows) || (gerr == nil && ch.UserID != p.UserID) {
			failure = httpx.NewError(httpx.CodeOTPInvalid, "invalid code")
			return nil
		}
		if gerr != nil {
			return fmt.Errorf("get challenge: %w", gerr)
		}
		switch {
		case ch.ConsumedAt != nil || int(ch.Attempts) >= otpMaxAttempts:
			failure = httpx.NewError(httpx.CodeOTPInvalid, "invalid code")
			return nil
		case !now.Before(ch.ExpiresAt):
			failure = httpx.NewError(httpx.CodeOTPExpired, "code expired")
			return nil
		}
		if !crypt.Equal(ch.CodeHash, s.codeHash(cid, code)) {
			attempts, berr := q.BumpOTPAttempts(ctx, cid)
			if berr != nil {
				return fmt.Errorf("bump attempts: %w", berr)
			}
			if int(attempts) >= otpMaxAttempts {
				if cerr := q.ConsumeOTP(ctx, dbgen.ConsumeOTPParams{ID: cid, ConsumedAt: &now}); cerr != nil {
					return fmt.Errorf("invalidate challenge: %w", cerr)
				}
			}
			failure = httpx.NewError(httpx.CodeOTPInvalid, "invalid code")
			return nil // commit the attempt counter
		}
		if err := q.ConsumeOTP(ctx, dbgen.ConsumeOTPParams{ID: cid, ConsumedAt: &now}); err != nil {
			return fmt.Errorf("consume challenge: %w", err)
		}
		plain, derr := s.box.Decrypt(ch.PhoneEnc)
		if derr != nil {
			return derr
		}
		last4 := string(plain[len(plain)-4:])
		target := p.UserID
		owner, oerr := q.GetActiveUserByPhoneHash(ctx, &ch.PhoneHash)
		switch {
		case errors.Is(oerr, pgx.ErrNoRows):
			if err := q.SetUserPhone(ctx, dbgen.SetUserPhoneParams{ID: p.UserID, PhoneEnc: ch.PhoneEnc,
				PhoneHash: &ch.PhoneHash, PhoneLast4: &last4, PhoneVerifiedAt: &now}); err != nil {
				return fmt.Errorf("set phone: %w", err)
			}
		case oerr != nil:
			return fmt.Errorf("find phone owner: %w", oerr)
		case owner.ID == p.UserID:
			// already linked to this account
		default:
			target = owner.ID
			res.Merged = true
			if err := s.merge(ctx, q, p, owner.ID, now); err != nil {
				return err
			}
		}
		fam, ferr := newID()
		if ferr != nil {
			return ferr
		}
		res.Session, ferr = s.auth.issue(ctx, &PGStore{q: q}, target, p.DeviceID, fam, now)
		return ferr
	})
	if err != nil {
		return VerifyResult{}, err
	}
	if failure != nil {
		return VerifyResult{}, failure
	}
	return res, nil
}

// merge moves the calling device from B (p.UserID) to A and transfers B's purchases to A.
// B's trial and trial grants stay with B.
func (s *PhoneService) merge(ctx context.Context, q *dbgen.Queries, p httpx.Principal, a uuid.UUID, now time.Time) error {
	b := p.UserID
	// Only this install leaves B: its old sessions end, B's other devices stay signed in.
	if err := q.RevokeDeviceTokens(ctx, dbgen.RevokeDeviceTokensParams{DeviceID: p.DeviceID, RevokedAt: &now}); err != nil {
		return fmt.Errorf("revoke device tokens: %w", err)
	}
	if err := q.RebindDevice(ctx, dbgen.RebindDeviceParams{ID: p.DeviceID, UserID: a}); err != nil {
		return fmt.Errorf("rebind device: %w", err)
	}
	for _, h := range s.hooks {
		if err := h.OnUserMerged(ctx, q, b, a); err != nil {
			return fmt.Errorf("merge hook: %w", err)
		}
	}
	n, err := q.CountUserDevices(ctx, b)
	if err != nil {
		return fmt.Errorf("count devices: %w", err)
	}
	if n == 0 { // B was only this install: retire it
		if err := q.MarkUserDeleted(ctx, dbgen.MarkUserDeletedParams{ID: b, DeletedAt: &now}); err != nil {
			return fmt.Errorf("retire merged user: %w", err)
		}
	}
	return nil
}
