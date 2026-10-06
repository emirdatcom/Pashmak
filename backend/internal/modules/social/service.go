// Package social implements friends (decision: Finch parity): a public profile per user with a shareable friend
// code, mutual friendships added by code, and "good vibes" — one small gesture per friend per day. Nothing about
// goals, moods or journals is ever shared; only a nickname and the cat's look that the app chooses to publish.
package social

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

const (
	// MaxFriends caps the friend list on both sides of a new friendship.
	MaxFriends = 50
	codeLen    = 8
	codeChars  = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no 0/O, 1/I
)

// VibeKinds are the gestures a friend can send.
var VibeKinds = map[string]bool{"hug": true, "sun": true, "tea": true, "cheer": true, "star": true}

var (
	furs   = map[string]bool{"orangeCream": true, "smokeGray": true, "tricolor": true}
	stages = map[string]bool{"kitten": true, "young": true, "adult": true}
	// Iran has had no daylight saving time since 2022: a fixed zone gives the local calendar day for "once a day".
	tehran = time.FixedZone("IRST", 3*3600+1800)
)

// Profile is what friends see.
type Profile struct {
	FriendCode string `json:"friend_code"`
	Nickname   string `json:"nickname"`
	CatName    string `json:"cat_name"`
	CatFur     string `json:"cat_fur"`
	CatStage   string `json:"cat_stage"`
	CatHue     int    `json:"cat_hue"`
}

// ProfileInput updates the caller's public profile.
type ProfileInput struct {
	Nickname string `json:"nickname"`
	CatName  string `json:"cat_name"`
	CatFur   string `json:"cat_fur"`
	CatStage string `json:"cat_stage"`
	CatHue   int    `json:"cat_hue"`
}

// Friend is one entry of the friend list.
type Friend struct {
	Profile
	Since      time.Time `json:"since"`
	VibedToday bool      `json:"vibed_today"`
}

// Vibe is a received gesture.
type Vibe struct {
	ID       uuid.UUID  `json:"id"`
	Kind     string     `json:"kind"`
	FromCode string     `json:"from_code"`
	FromName string     `json:"from_nickname"`
	FromCat  string     `json:"from_cat_name"`
	SentAt   time.Time  `json:"sent_at"`
	ReadAt   *time.Time `json:"read_at"`
	Unread   bool       `json:"unread"`
}

// Service implements friends and vibes.
type Service struct {
	pool *db.Pool
	clk  clock.Clock
}

// NewService builds a Service.
func NewService(pool *db.Pool, clk clock.Clock) *Service { return &Service{pool: pool, clk: clk} }

func invalid(msg string) error { return httpx.NewError(httpx.CodeInvalidInput, msg) }

// NormalizeCode accepts lower case, spaces, dashes and Persian/Arabic digits.
func NormalizeCode(in string) string {
	var b strings.Builder
	for _, r := range strings.ToUpper(in) {
		switch {
		case r >= '۰' && r <= '۹':
			b.WriteRune('0' + (r - '۰'))
		case r >= '٠' && r <= '٩':
			b.WriteRune('0' + (r - '٠'))
		case r == ' ' || r == '-' || r == '_':
		default:
			b.WriteRune(r)
		}
	}
	return b.String()
}

func newCode() (string, error) {
	var b strings.Builder
	for range codeLen {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(codeChars))))
		if err != nil {
			return "", fmt.Errorf("random code: %w", err)
		}
		b.WriteByte(codeChars[n.Int64()])
	}
	return b.String(), nil
}

func toProfile(p dbgen.SocialProfile) Profile {
	return Profile{FriendCode: p.FriendCode, Nickname: p.Nickname, CatName: p.CatName, CatFur: p.CatFur, CatStage: p.CatStage, CatHue: int(p.CatHue)}
}

// Me returns the caller's profile, creating it (with a fresh friend code) on first use.
func (s *Service) Me(ctx context.Context, userID uuid.UUID) (Profile, error) {
	q := dbgen.New(s.pool)
	for attempt := 0; attempt < 5; attempt++ {
		p, err := q.GetSocialProfile(ctx, userID)
		if err == nil {
			return toProfile(p), nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return Profile{}, fmt.Errorf("get profile: %w", err)
		}
		code, err := newCode()
		if err != nil {
			return Profile{}, err
		}
		err = q.InsertSocialProfile(ctx, dbgen.InsertSocialProfileParams{UserID: userID, FriendCode: code, UpdatedAt: s.clk.Now()})
		var pgErr *pgconn.PgError
		if err != nil && !(errors.As(err, &pgErr) && pgErr.Code == "23505") {
			return Profile{}, fmt.Errorf("create profile: %w", err)
		}
		// on a code collision (or a concurrent first call) loop: read again or try another code
	}
	return Profile{}, errors.New("social: could not allocate a friend code")
}

// UpdateMe validates and stores the public profile.
func (s *Service) UpdateMe(ctx context.Context, userID uuid.UUID, in ProfileInput) (Profile, error) {
	in.Nickname, in.CatName = strings.TrimSpace(in.Nickname), strings.TrimSpace(in.CatName)
	switch {
	case utf8.RuneCountInString(in.Nickname) > 20:
		return Profile{}, invalid("nickname must be at most 20 characters")
	case utf8.RuneCountInString(in.CatName) > 16:
		return Profile{}, invalid("cat_name must be at most 16 characters")
	case !furs[in.CatFur]:
		return Profile{}, invalid("cat_fur is not a known fur")
	case !stages[in.CatStage]:
		return Profile{}, invalid("cat_stage must be kitten, young or adult")
	case in.CatHue < 0 || in.CatHue > 359:
		return Profile{}, invalid("cat_hue must be 0..359")
	}
	if _, err := s.Me(ctx, userID); err != nil {
		return Profile{}, err
	}
	if err := dbgen.New(s.pool).UpdateSocialProfile(ctx, dbgen.UpdateSocialProfileParams{UserID: userID, Nickname: in.Nickname, CatName: in.CatName,
		CatFur: in.CatFur, CatStage: in.CatStage, CatHue: int32(in.CatHue), UpdatedAt: s.clk.Now()}); err != nil { // #nosec G115 -- 0..359
		return Profile{}, fmt.Errorf("update profile: %w", err)
	}
	return s.Me(ctx, userID)
}

func pair(a, b uuid.UUID) (uuid.UUID, uuid.UUID) {
	if strings.Compare(a.String(), b.String()) < 0 {
		return a, b
	}
	return b, a
}

func (s *Service) today() time.Time {
	n := s.clk.Now().In(tehran)
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
}

// AddFriend makes the caller and the owner of code friends (mutual, immediate). Idempotent.
func (s *Service) AddFriend(ctx context.Context, userID uuid.UUID, code string) (Friend, error) {
	code = NormalizeCode(code)
	if len(code) != codeLen {
		return Friend{}, httpx.NewError(httpx.CodeFriendCodeInvalid, "no one has this friend code")
	}
	if _, err := s.Me(ctx, userID); err != nil {
		return Friend{}, err
	}
	var out Friend
	err := s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		other, err := q.GetSocialProfileByCode(ctx, code)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && other.UserID == userID) {
			return httpx.NewError(httpx.CodeFriendCodeInvalid, "no one has this friend code")
		}
		if err != nil {
			return fmt.Errorf("find code: %w", err)
		}
		a, b := pair(userID, other.UserID)
		already, err := q.AreFriends(ctx, dbgen.AreFriendsParams{UserA: a, UserB: b})
		if err != nil {
			return fmt.Errorf("are friends: %w", err)
		}
		if !already {
			for _, u := range []uuid.UUID{userID, other.UserID} {
				n, cerr := q.CountFriends(ctx, u)
				if cerr != nil {
					return fmt.Errorf("count friends: %w", cerr)
				}
				if int(n) >= MaxFriends {
					return httpx.NewError(httpx.CodeFriendLimit, fmt.Sprintf("a friend list is full (max %d)", MaxFriends))
				}
			}
			if err := q.InsertFriendship(ctx, dbgen.InsertFriendshipParams{UserA: a, UserB: b, CreatedAt: s.clk.Now()}); err != nil {
				return fmt.Errorf("insert friendship: %w", err)
			}
		}
		out = Friend{Profile: toProfile(other), Since: s.clk.Now()}
		return nil
	})
	return out, err
}

// RemoveFriend ends the friendship with the owner of code (idempotent).
func (s *Service) RemoveFriend(ctx context.Context, userID uuid.UUID, code string) error {
	q := dbgen.New(s.pool)
	other, err := q.GetSocialProfileByCode(ctx, NormalizeCode(code))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("find code: %w", err)
	}
	a, b := pair(userID, other.UserID)
	return q.DeleteFriendship(ctx, dbgen.DeleteFriendshipParams{UserA: a, UserB: b})
}

// Friends lists the caller's friends, oldest friendship first, with whether a vibe was sent to each today.
func (s *Service) Friends(ctx context.Context, userID uuid.UUID) ([]Friend, error) {
	rows, err := dbgen.New(s.pool).ListFriends(ctx, dbgen.ListFriendsParams{Me: userID, Day: s.today()})
	if err != nil {
		return nil, fmt.Errorf("list friends: %w", err)
	}
	out := make([]Friend, 0, len(rows))
	for _, r := range rows {
		out = append(out, Friend{Profile: Profile{FriendCode: r.FriendCode, Nickname: r.Nickname, CatName: r.CatName, CatFur: r.CatFur,
			CatStage: r.CatStage, CatHue: int(r.CatHue)}, Since: r.Since, VibedToday: r.VibedToday})
	}
	return out, nil
}

// SendVibe sends one gesture to a friend; a second one the same (Tehran) day is refused.
func (s *Service) SendVibe(ctx context.Context, userID uuid.UUID, code, kind string) error {
	if !VibeKinds[kind] {
		return invalid("kind must be hug, sun, tea, cheer or star")
	}
	q := dbgen.New(s.pool)
	other, err := q.GetSocialProfileByCode(ctx, NormalizeCode(code))
	if errors.Is(err, pgx.ErrNoRows) {
		return httpx.NewError(httpx.CodeFriendCodeInvalid, "no one has this friend code")
	}
	if err != nil {
		return fmt.Errorf("find code: %w", err)
	}
	a, b := pair(userID, other.UserID)
	ok, err := q.AreFriends(ctx, dbgen.AreFriendsParams{UserA: a, UserB: b})
	if err != nil {
		return fmt.Errorf("are friends: %w", err)
	}
	if !ok {
		return httpx.NewError(httpx.CodeForbidden, "you can only send vibes to friends")
	}
	id, err := uuid.NewV7()
	if err != nil {
		return fmt.Errorf("uuid: %w", err)
	}
	n, err := q.InsertVibe(ctx, dbgen.InsertVibeParams{ID: id, FromUser: userID, ToUser: other.UserID, Kind: kind, Day: s.today(), CreatedAt: s.clk.Now()})
	if err != nil {
		return fmt.Errorf("insert vibe: %w", err)
	}
	if n == 0 {
		return httpx.NewError(httpx.CodeVibeAlreadySent, "you already sent this friend a vibe today")
	}
	return nil
}

// Vibes lists the gestures received in the last 30 days, newest first.
func (s *Service) Vibes(ctx context.Context, userID uuid.UUID) ([]Vibe, error) {
	rows, err := dbgen.New(s.pool).ListReceivedVibes(ctx, dbgen.ListReceivedVibesParams{ToUser: userID, CreatedAt: s.clk.Now().AddDate(0, 0, -30)})
	if err != nil {
		return nil, fmt.Errorf("list vibes: %w", err)
	}
	out := make([]Vibe, 0, len(rows))
	for _, r := range rows {
		out = append(out, Vibe{ID: r.ID, Kind: r.Kind, FromCode: r.FriendCode, FromName: r.Nickname, FromCat: r.CatName, SentAt: r.CreatedAt, ReadAt: r.ReadAt, Unread: r.ReadAt == nil})
	}
	return out, nil
}

// MarkRead marks every received vibe as read.
func (s *Service) MarkRead(ctx context.Context, userID uuid.UUID) error {
	now := s.clk.Now()
	return dbgen.New(s.pool).MarkVibesRead(ctx, dbgen.MarkVibesReadParams{ToUser: userID, ReadAt: &now})
}

// OnUserDeleted implements user.DeletionHook: the profile, friendships and vibes go.
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	if err := dbgen.New(s.pool).DeleteUserSocial(ctx, userID); err != nil {
		return fmt.Errorf("delete social: %w", err)
	}
	return nil
}

// OnUserMerged implements auth.MergeHook: B's friends become A's friends, B's profile and vibes go.
func (s *Service) OnUserMerged(ctx context.Context, q *dbgen.Queries, from, to uuid.UUID) error {
	friends, err := q.ListFriendIDs(ctx, from)
	if err != nil {
		return fmt.Errorf("list friends: %w", err)
	}
	now := s.clk.Now()
	for _, f := range friends {
		if f == to {
			continue
		}
		a, b := pair(to, f)
		if err := q.InsertFriendship(ctx, dbgen.InsertFriendshipParams{UserA: a, UserB: b, CreatedAt: now}); err != nil {
			return fmt.Errorf("move friendship: %w", err)
		}
	}
	if err := q.DeleteUserSocial(ctx, from); err != nil {
		return fmt.Errorf("delete merged social: %w", err)
	}
	return nil
}
