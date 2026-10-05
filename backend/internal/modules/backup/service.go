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

// MaxBlobBytes is the largest accepted backup (10 MB, docs/10 §6.1).
const MaxBlobBytes = 10 << 20

// ErrNotFound is returned by blob stores for missing objects.
var ErrNotFound = errors.New("backup: not found")

// BlobStore is an optional external object store (S3-compatible). Without one, blobs live in the
// database row (BACKUP_STORAGE=db).
type BlobStore interface {
	Put(ctx context.Context, key string, data []byte) error
	Get(ctx context.Context, key string) ([]byte, error)
	Delete(ctx context.Context, key string) error
}

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
	pool  *db.Pool
	clk   clock.Clock
	blobs BlobStore // nil = database storage
}

// NewService builds a Service. blobs may be nil.
func NewService(pool *db.Pool, clk clock.Clock, blobs BlobStore) *Service {
	return &Service{pool: pool, clk: clk, blobs: blobs}
}

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
	if len(data) > MaxBlobBytes {
		return time.Time{}, httpx.NewError(httpx.CodeBackupTooLarge, "backup is too large (max 10 MB)")
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
	p := dbgen.UpsertBackupParams{UserID: userID, Storage: "db", Blob: data, SizeBytes: int32(len(data)), // #nosec G115 -- ≤10MB
		SchemaVersion: int32(schema), Sha256: strings.ToLower(sha), KdfParams: kdfRaw, UpdatedAt: now} // #nosec G115
	if s.blobs != nil {
		key := "backups/" + userID.String()
		if err := s.blobs.Put(ctx, key, data); err != nil {
			return time.Time{}, fmt.Errorf("store blob: %w", err)
		}
		p.Storage, p.BlobRef, p.Blob = "s3", key, nil
	}
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
	if b.Storage == "s3" {
		if s.blobs == nil {
			return Meta{}, nil, errors.New("backup is stored in S3 but no blob store is configured")
		}
		if data, err = s.blobs.Get(ctx, b.BlobRef); err != nil {
			if errors.Is(err, ErrNotFound) {
				return Meta{}, nil, httpx.NewError(httpx.CodeNotFound, "no backup")
			}
			return Meta{}, nil, fmt.Errorf("load blob: %w", err)
		}
	}
	return Meta{SchemaVersion: int(b.SchemaVersion), SHA256: b.Sha256, KDFParams: b.KdfParams, UpdatedAt: b.UpdatedAt, Size: len(data)}, data, nil
}

// Delete removes the backup (idempotent).
func (s *Service) Delete(ctx context.Context, userID uuid.UUID) error {
	q := dbgen.New(s.pool)
	b, err := q.GetBackup(ctx, userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("get backup: %w", err)
	}
	if b.Storage == "s3" && s.blobs != nil {
		if err := s.blobs.Delete(ctx, b.BlobRef); err != nil {
			return fmt.Errorf("delete blob: %w", err)
		}
	}
	if _, err := q.DeleteBackup(ctx, userID); err != nil {
		return fmt.Errorf("delete backup: %w", err)
	}
	return nil
}

// OnUserDeleted implements user.DeletionHook.
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	return s.Delete(ctx, userID)
}
