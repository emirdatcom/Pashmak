// Package backup stores client-side-encrypted snapshots. The server never decrypts, parses or
// inspects the blob: it only checks size and sha256 and stores the bytes (docs/30 §10).
package backup

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// DefaultMaxBytes is the default largest accepted backup (5 MB); BACKUP_MAX_BYTES overrides it.
const DefaultMaxBytes = 5 << 20

// Meta is the backup metadata exposed through headers.
type Meta struct {
	SchemaVersion int
	SHA256        string
	KDFParams     json.RawMessage
	UpdatedAt     time.Time
	Size          int
}

// Service implements backup storage.
type Service struct {
	pool     *db.Pool
	clk      clock.Clock
	maxBytes int
}

// NewService builds a Service. Blobs are stored in the database row (decision D-3: no object storage).
// maxBytes <= 0 means DefaultMaxBytes.
func NewService(pool *db.Pool, clk clock.Clock, maxBytes int) *Service {
	if maxBytes <= 0 {
		maxBytes = DefaultMaxBytes
	}
	return &Service{pool: pool, clk: clk, maxBytes: maxBytes}
}

// MaxBytes reports the effective size limit (the HTTP layer needs it to cap the request body).
func (s *Service) MaxBytes() int { return s.maxBytes }

func invalid(msg string) error { return httpx.NewError(httpx.CodeInvalidInput, msg) }

// validateKDF checks the shape of the KDF parameters the client needs to re-derive its key.
func validateKDF(raw string) (json.RawMessage, error) {
	var k struct {
		Alg  string `json:"alg"`
		M    int    `json:"m"`
		T    int    `json:"t"`
		P    int    `json:"p"`
		Salt string `json:"salt"`
	}
	if len(raw) == 0 || len(raw) > 1024 || json.Unmarshal([]byte(raw), &k) != nil ||
		k.Alg != "argon2id" || k.M <= 0 || k.T <= 0 || k.P <= 0 || k.Salt == "" {
		return nil, invalid("X-Kdf-Params must be JSON with alg=argon2id, m, t, p and salt")
	}
	return json.RawMessage(raw), nil
}

// Put stores the snapshot, replacing any previous one.
func (s *Service) Put(ctx context.Context, userID uuid.UUID, schema int, sha, kdf string, data []byte) (time.Time, error) {
	if len(data) == 0 {
		return time.Time{}, invalid("empty backup")
	}
	if len(data) > s.maxBytes {
		return time.Time{}, httpx.NewError(httpx.CodeBackupTooLarge, fmt.Sprintf("backup is too large (max %d bytes)", s.maxBytes))
	}
	if schema < 1 {
		return time.Time{}, invalid("X-Backup-Schema must be a positive integer")
	}
	sum := sha256.Sum256(data)
	if !strings.EqualFold(hex.EncodeToString(sum[:]), sha) {
		return time.Time{}, invalid("X-Backup-Sha256 does not match the body")
	}
	kdfRaw, err := validateKDF(kdf)
	if err != nil {
		return time.Time{}, err
	}
	now := s.clk.Now()
	p := dbgen.UpsertBackupParams{UserID: userID, Blob: data, SizeBytes: int32(len(data)), // #nosec G115 -- ≤ maxBytes
		SchemaVersion: int32(schema), Sha256: strings.ToLower(sha), KdfParams: kdfRaw, UpdatedAt: now} // #nosec G115
	if err := dbgen.New(s.pool).UpsertBackup(ctx, p); err != nil {
		return time.Time{}, fmt.Errorf("save backup: %w", err)
	}
	return now, nil
}

// Get returns the stored blob and metadata.
func (s *Service) Get(ctx context.Context, userID uuid.UUID) (Meta, []byte, error) {
	b, err := dbgen.New(s.pool).GetBackup(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return Meta{}, nil, httpx.NewError(httpx.CodeNotFound, "no backup")
	}
	if err != nil {
		return Meta{}, nil, fmt.Errorf("get backup: %w", err)
	}
	data := b.Blob
	return Meta{SchemaVersion: int(b.SchemaVersion), SHA256: b.Sha256, KDFParams: b.KdfParams, UpdatedAt: b.UpdatedAt, Size: len(data)}, data, nil
}

// Delete removes the backup (idempotent).
func (s *Service) Delete(ctx context.Context, userID uuid.UUID) error {
	q := dbgen.New(s.pool)
	if _, err := q.DeleteBackup(ctx, userID); err != nil {
		return fmt.Errorf("delete backup: %w", err)
	}
	return nil
}

// OnUserDeleted implements user.DeletionHook.
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	return s.Delete(ctx, userID)
}
