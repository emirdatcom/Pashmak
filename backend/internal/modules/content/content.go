// Package content stores immutable versioned content packs and serves them with a manifest (docs/40).
package content

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/emirdatcom/pashmak/backend/internal/platform/appver"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
)

// ManifestEntry describes one downloadable pack.
type ManifestEntry struct {
	PackKey       string `json:"pack_key"`
	Version       int    `json:"version"`
	SHA256        string `json:"sha256"`
	Size          int    `json:"size"`
	MinAppVersion string `json:"min_app_version"`
	URL           string `json:"url"`
}

// Service implements content publishing and serving.
type Service struct {
	pool    *db.Pool
	schemas *schemas.Set
	clk     clock.Clock
}

// NewService builds a Service.
func NewService(pool *db.Pool, s *schemas.Set, clk clock.Clock) *Service {
	return &Service{pool: pool, schemas: s, clk: clk}
}

// Publish validates and stores a new immutable pack version. The served bytes are the minified
// JSON stored in `raw`; sha256 is computed over exactly those bytes.
func (s *Service) Publish(ctx context.Context, doc json.RawMessage) (ManifestEntry, error) {
	var head struct {
		PackKey       string `json:"pack_key"`
		Version       int    `json:"version"`
		Locale        string `json:"locale"`
		MinAppVersion string `json:"min_app_version"`
	}
	if err := json.Unmarshal(doc, &head); err != nil {
		return ManifestEntry{}, httpx.NewError(httpx.CodeInvalidInput, "invalid JSON: "+err.Error())
	}
	if err := s.schemas.ValidatePack(head.PackKey, doc); err != nil {
		return ManifestEntry{}, httpx.NewError(httpx.CodeInvalidInput, "pack does not match the schema: "+err.Error())
	}
	var tree any
	if err := json.Unmarshal(doc, &tree); err != nil {
		return ManifestEntry{}, httpx.NewError(httpx.CodeInvalidInput, "invalid JSON: "+err.Error())
	}
	raw, err := json.Marshal(tree) // minified, keys sorted: deterministic bytes
	if err != nil {
		return ManifestEntry{}, fmt.Errorf("encode pack: %w", err)
	}
	sum := sha256.Sum256(raw)
	hash := hex.EncodeToString(sum[:])
	row, err := dbgen.New(s.pool).InsertContentPack(ctx, dbgen.InsertContentPackParams{PackKey: head.PackKey,
		Version: int32(head.Version), Locale: head.Locale, Payload: raw, Raw: raw, Sha256: hash, // #nosec G115
		MinAppVersion: head.MinAppVersion, PublishedAt: s.clk.Now()})
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return ManifestEntry{}, httpx.NewError(httpx.CodeInvalidInput, "this pack version already exists; packs are immutable, publish a higher version")
	}
	if err != nil {
		return ManifestEntry{}, fmt.Errorf("insert pack: %w", err)
	}
	return entry(row.PackKey, int(row.Version), row.Sha256, len(raw), row.MinAppVersion), nil
}

func entry(key string, version int, sha string, size int, minV string) ManifestEntry {
	return ManifestEntry{PackKey: key, Version: version, SHA256: sha, Size: size, MinAppVersion: minV,
		URL: "/v1/content/packs/" + key + "/" + strconv.Itoa(version)}
}

// Manifest lists, per pack_key, the highest version compatible with appVersion.
func (s *Service) Manifest(ctx context.Context, appVersion string) ([]ManifestEntry, error) {
	rows, err := dbgen.New(s.pool).ListActivePackMeta(ctx)
	if err != nil {
		return nil, fmt.Errorf("list packs: %w", err)
	}
	out := []ManifestEntry{}
	seen := map[string]bool{}
	for _, r := range rows { // ordered by pack_key, version DESC
		if seen[r.PackKey] || !appver.AtLeast(appVersion, r.MinAppVersion) {
			continue
		}
		seen[r.PackKey] = true
		out = append(out, entry(r.PackKey, int(r.Version), r.Sha256, int(r.Size), r.MinAppVersion))
	}
	return out, nil
}

// Pack returns the exact stored bytes and sha256 of a pack version.
func (s *Service) Pack(ctx context.Context, key string, version int) ([]byte, string, error) {
	r, err := dbgen.New(s.pool).GetPackRaw(ctx, dbgen.GetPackRawParams{PackKey: key, Version: int32(version)}) // #nosec G115
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, "", httpx.NewError(httpx.CodeNotFound, "pack not found")
	}
	if err != nil {
		return nil, "", fmt.Errorf("get pack: %w", err)
	}
	return r.Raw, r.Sha256, nil
}

// Register mounts the public content endpoints.
func Register(r *httpx.Router, s *Service) {
	r.HandleFunc("GET /v1/content/manifest", s.handleManifest, httpx.Gzip())
	r.HandleFunc("GET /v1/content/packs/{pack_key}/{version}", s.handlePack, httpx.Gzip())
}

func (s *Service) handleManifest(w http.ResponseWriter, r *http.Request) {
	entries, err := s.Manifest(r.Context(), httpx.ClientFrom(r.Context()).AppVersion)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	body, _ := json.Marshal(map[string]any{"packs": entries})
	sum := sha256.Sum256(body)
	etag := `"` + hex.EncodeToString(sum[:8]) + `"`
	h := w.Header()
	h.Set("ETag", etag)
	h.Set("Cache-Control", "public, no-cache")
	h.Set("Vary", "X-App-Version")
	if httpx.ETagMatches(r.Header.Get("If-None-Match"), etag) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	h.Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(body)
}

func (s *Service) handlePack(w http.ResponseWriter, r *http.Request) {
	version, err := strconv.Atoi(r.PathValue("version"))
	if err != nil || version < 1 {
		httpx.WriteError(w, r, httpx.CodeNotFound, "pack not found")
		return
	}
	raw, sha, err := s.Pack(r.Context(), r.PathValue("pack_key"), version)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	h := w.Header()
	h.Set("Content-Type", "application/json; charset=utf-8")
	h.Set("ETag", `"`+sha+`"`)
	h.Set("Cache-Control", "public, max-age=31536000, immutable")
	if httpx.ETagMatches(r.Header.Get("If-None-Match"), `"`+sha+`"`) {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	_, _ = w.Write(raw) // #nosec G705 -- static JSON bytes served as application/json, not HTML
}
