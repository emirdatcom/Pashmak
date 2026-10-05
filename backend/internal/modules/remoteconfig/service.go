// Package remoteconfig serves the versioned remote config with deterministic experiment bucketing.
package remoteconfig

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
)

const cacheTTL = 30 * time.Second

// Response is the ConfigResponse of docs/10 §6.2.
type Response struct {
	Version     int               `json:"version"`
	Payload     json.RawMessage   `json:"payload"`
	Experiments map[string]string `json:"experiments"`
	ETag        string            `json:"etag"`
}

type snapshot struct {
	version int
	base    json.RawMessage
	exps    []Experiment
	loaded  time.Time
}

// Service implements remote config.
type Service struct {
	pool    *db.Pool
	schemas *schemas.Set
	clk     clock.Clock

	mu   sync.Mutex
	snap *snapshot
}

// NewService builds a Service.
func NewService(pool *db.Pool, s *schemas.Set, clk clock.Clock) *Service {
	return &Service{pool: pool, schemas: s, clk: clk}
}

func (s *Service) invalidate() {
	s.mu.Lock()
	s.snap = nil
	s.mu.Unlock()
}

func (s *Service) load(ctx context.Context) (*snapshot, error) {
	s.mu.Lock()
	if s.snap != nil && s.clk.Now().Sub(s.snap.loaded) < cacheTTL {
		sn := s.snap
		s.mu.Unlock()
		return sn, nil
	}
	s.mu.Unlock()

	q := dbgen.New(s.pool)
	cv, err := q.GetActiveConfig(ctx)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, httpx.NewError(httpx.CodeNotFound, "no active config")
	}
	if err != nil {
		return nil, fmt.Errorf("get active config: %w", err)
	}
	rows, err := q.ListRunningExperiments(ctx)
	if err != nil {
		return nil, fmt.Errorf("list experiments: %w", err)
	}
	sn := &snapshot{version: int(cv.Version), base: cv.Payload, loaded: s.clk.Now()}
	for _, r := range rows {
		e := Experiment{Key: r.Key, Status: r.Status}
		if err := json.Unmarshal(r.Variants, &e.Variants); err != nil {
			continue // a corrupt experiment must not break config delivery
		}
		_ = json.Unmarshal(r.Audience, &e.Audience)
		sn.exps = append(sn.exps, e)
	}
	s.mu.Lock()
	s.snap = sn
	s.mu.Unlock()
	return sn, nil
}

// Base returns the active config without experiment overrides (used by other modules).
func (s *Service) Base(ctx context.Context) (json.RawMessage, int, error) {
	sn, err := s.load(ctx)
	if err != nil {
		return nil, 0, err
	}
	return sn.base, sn.version, nil
}

// Resolve builds the response for a subject: active config + overrides of matching running experiments.
func (s *Service) Resolve(ctx context.Context, sub Subject) (Response, error) {
	sn, err := s.load(ctx)
	if err != nil {
		return Response{}, err
	}
	payload := sn.base
	assigned := map[string]string{}
	if sub.ID != "" {
		for _, e := range sn.exps { // sn.exps is sorted by key
			if !e.Audience.Matches(sub) {
				continue
			}
			v, ok := Pick(e.Variants, Bucket(sub.ID, e.Key))
			if !ok {
				continue
			}
			next, err := ApplyOverrides(payload, v.Overrides)
			if err != nil {
				continue // never fail delivery because of a bad override
			}
			payload = next
			assigned[e.Key] = v.Name
		}
	}
	return Response{Version: sn.version, Payload: payload, Experiments: assigned, ETag: etag(sn.version, payload, assigned)}, nil
}

func etag(version int, payload json.RawMessage, exps map[string]string) string {
	keys := make([]string, 0, len(exps))
	for k := range exps {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	h := sha256.New()
	_, _ = h.Write(payload)
	for _, k := range keys {
		_, _ = h.Write([]byte("|" + k + "=" + exps[k]))
	}
	return fmt.Sprintf(`"v%d-%s"`, version, hex.EncodeToString(h.Sum(nil))[:12])
}

// InstallAgeDays returns the account age in whole days, or -1 when unknown.
func (s *Service) InstallAgeDays(ctx context.Context, userID uuid.UUID) int {
	u, err := dbgen.New(s.pool).GetUser(ctx, userID)
	if err != nil {
		return -1
	}
	return int(s.clk.Now().Sub(u.CreatedAt).Hours() / 24)
}

func invalid(format string, a ...any) error {
	return httpx.NewError(httpx.CodeInvalidInput, fmt.Sprintf(format, a...))
}

// Publish validates and stores a new (inactive) config version. It returns the new version number.
func (s *Service) Publish(ctx context.Context, payload json.RawMessage, minAppVersion, publishedBy string) (int, error) {
	if err := s.schemas.ValidateConfig(payload); err != nil {
		return 0, invalid("config does not match the schema: %v", err)
	}
	cv, err := dbgen.New(s.pool).InsertConfigVersion(ctx, dbgen.InsertConfigVersionParams{
		Payload: payload, MinAppVersion: minAppVersion, PublishedBy: publishedBy, PublishedAt: s.clk.Now()})
	if err != nil {
		return 0, fmt.Errorf("insert config version: %w", err)
	}
	return int(cv.Version), nil
}

// Activate makes version the active config (also used for rollback).
func (s *Service) Activate(ctx context.Context, version int) error {
	err := s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		q := dbgen.New(tx)
		if _, err := q.GetConfigVersion(ctx, int32(version)); errors.Is(err, pgx.ErrNoRows) { // #nosec G115 -- bounded by DB integer
			return httpx.NewError(httpx.CodeNotFound, "config version not found")
		} else if err != nil {
			return fmt.Errorf("get config version: %w", err)
		}
		if err := q.DeactivateConfigs(ctx); err != nil {
			return fmt.Errorf("deactivate: %w", err)
		}
		if _, err := q.ActivateConfig(ctx, int32(version)); err != nil { // #nosec G115
			return fmt.Errorf("activate: %w", err)
		}
		return nil
	})
	if err != nil {
		return err
	}
	s.invalidate()
	return nil
}

// PutExperiment creates or updates an experiment. Every variant's overrides must yield a config
// that still validates against the schema when applied to the active (or given) base config.
func (s *Service) PutExperiment(ctx context.Context, e Experiment) error {
	if err := e.Validate(); err != nil {
		return invalid("%v", err)
	}
	base, _, err := s.Base(ctx)
	if err != nil {
		return err
	}
	for _, v := range e.Variants {
		merged, err := ApplyOverrides(base, v.Overrides)
		if err != nil {
			return invalid("variant %s: %v", v.Name, err)
		}
		if err := s.schemas.ValidateConfig(merged); err != nil {
			return invalid("variant %s produces an invalid config: %v", v.Name, err)
		}
	}
	variants, _ := json.Marshal(e.Variants)
	audience, _ := json.Marshal(e.Audience)
	q := dbgen.New(s.pool)
	now := s.clk.Now()
	existing, gerr := q.GetExperiment(ctx, e.Key)
	var started, stopped *time.Time
	if gerr == nil {
		started, stopped = existing.StartedAt, existing.StoppedAt
	}
	switch e.Status {
	case "running":
		if started == nil {
			started = &now
		}
		stopped = nil
	case "stopped":
		if stopped == nil {
			stopped = &now
		}
	}
	if err := q.UpsertExperiment(ctx, dbgen.UpsertExperimentParams{Key: e.Key, Status: e.Status, Variants: variants,
		Audience: audience, StartedAt: started, StoppedAt: stopped, UpdatedAt: now}); err != nil {
		return fmt.Errorf("upsert experiment: %w", err)
	}
	s.invalidate()
	return nil
}
