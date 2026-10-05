// Package analytics ingests client events with a strict whitelist and produces daily rollups (docs/70).
package analytics

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
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

const (
	maxBatch        = 200
	maxStringLen    = 64
	maxSessionIDLen = 64
	maxTSFuture     = 24 * time.Hour
)

// Event is one client event (docs/10 §6.2).
type Event struct {
	EventID   string         `json:"event_id"`
	Name      string         `json:"name"`
	TS        string         `json:"ts"`
	SessionID string         `json:"session_id"`
	Props     map[string]any `json:"props"`
}

// Rejection reasons (also the events_rejected_total label values).
const (
	ReasonUnknownEvent  = "unknown_event"
	ReasonServerOnly    = "server_only"
	ReasonForbiddenProp = "forbidden_prop"
	ReasonInvalidID     = "invalid_event_id"
	ReasonInvalidTS     = "invalid_ts"
	ReasonInvalidSess   = "invalid_session_id"
)

// Result is the ingest outcome.
type Result struct {
	Accepted int            `json:"accepted"`
	Rejected int            `json:"rejected"`
	Reasons  map[string]int `json:"rejected_reasons"`
}

// Service ingests and rolls up events.
type Service struct {
	pool    *db.Pool
	catalog *schemas.Catalog
	clk     clock.Clock
	byName  map[string]schemas.EventSpec
	forbid  map[string]bool

	// Observe hooks (optional) for Prometheus counters.
	OnIngested func(n int)
	OnRejected func(reason string)

	mu       sync.Mutex
	ensured  string // "YYYY-MM" of the last ensured partition month
	ensureFn func(ctx context.Context, month time.Time) error
}

// NewService builds a Service.
func NewService(pool *db.Pool, cat *schemas.Catalog, clk clock.Clock) *Service {
	s := &Service{pool: pool, catalog: cat, clk: clk, byName: map[string]schemas.EventSpec{}, forbid: map[string]bool{}}
	for _, e := range cat.Events {
		s.byName[e.Name] = e
	}
	for _, f := range cat.ForbiddenProps {
		s.forbid[strings.ToLower(f)] = true
	}
	s.ensureFn = s.ensurePartition
	return s
}

func (s *Service) ensurePartition(ctx context.Context, month time.Time) error {
	if err := dbgen.New(s.pool).EnsureEventsPartition(ctx, month); err != nil {
		return fmt.Errorf("ensure partition: %w", err)
	}
	return nil
}

// EnsurePartitions creates partitions for the current month and the next `ahead` months.
func (s *Service) EnsurePartitions(ctx context.Context, ahead int) error {
	now := s.clk.Now()
	for i := 0; i <= ahead; i++ {
		if err := s.ensureFn(ctx, time.Date(now.Year(), now.Month()+time.Month(i), 1, 0, 0, 0, 0, time.UTC)); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) ensureCurrentMonth(ctx context.Context) error {
	now := s.clk.Now()
	key := now.Format("2006-01")
	s.mu.Lock()
	done := s.ensured == key
	s.mu.Unlock()
	if done {
		return nil
	}
	if err := s.EnsurePartitions(ctx, 1); err != nil {
		return err
	}
	s.mu.Lock()
	s.ensured = key
	s.mu.Unlock()
	return nil
}

// sanitized is a validated event ready to insert.
type sanitized struct {
	id     uuid.UUID
	name   string
	ts     time.Time
	sess   string
	props  map[string]any
	server bool
}

// validate applies the whitelist. It returns a rejection reason or "".
func (s *Service) validate(e Event, allowServer bool, now time.Time) (sanitized, string) {
	spec, ok := s.byName[e.Name]
	if !ok {
		return sanitized{}, ReasonUnknownEvent
	}
	if spec.ServerSide && !allowServer {
		return sanitized{}, ReasonServerOnly
	}
	id, err := uuid.Parse(e.EventID)
	if err != nil {
		return sanitized{}, ReasonInvalidID
	}
	ts, err := time.Parse(time.RFC3339, e.TS)
	if err != nil || ts.After(now.Add(maxTSFuture)) {
		return sanitized{}, ReasonInvalidTS
	}
	if len(e.SessionID) > maxSessionIDLen {
		return sanitized{}, ReasonInvalidSess
	}
	// Defensive layer: any forbidden prop name rejects the whole event, even if it is not in the catalog.
	for k := range e.Props {
		if s.forbid[strings.ToLower(k)] {
			return sanitized{}, ReasonForbiddenProp
		}
	}
	clean := map[string]any{}
	for k, v := range e.Props {
		ps, known := spec.Props[k]
		if !known {
			ps, known = s.catalog.CommonProps[k]
		}
		if !known {
			for _, pre := range s.catalog.CommonPrefixes {
				if strings.HasPrefix(k, pre) && len(k) > len(pre) {
					ps, known = schemas.PropSpec{Type: "string", MaxLen: maxStringLen}, true
				}
			}
		}
		if !known {
			continue // unknown props are dropped
		}
		if cv, ok := coerce(ps, v); ok {
			clean[k] = cv
		}
	}
	return sanitized{id: id, name: e.Name, ts: ts.UTC(), sess: e.SessionID, props: clean, server: spec.ServerSide}, ""
}

func coerce(ps schemas.PropSpec, v any) (any, bool) {
	switch ps.Type {
	case "bool":
		b, ok := v.(bool)
		return b, ok
	case "int":
		f, ok := v.(float64)
		if !ok || f != math.Trunc(f) || math.Abs(f) > 1e12 {
			return nil, false
		}
		n := int64(f)
		if ps.Min != nil && n < int64(*ps.Min) || ps.Max != nil && n > int64(*ps.Max) {
			return nil, false
		}
		return n, true
	case "string":
		str, ok := v.(string)
		if !ok {
			return nil, false
		}
		limit := ps.MaxLen
		if limit == 0 {
			limit = maxStringLen
		}
		if len(str) > limit {
			return nil, false
		}
		if len(ps.Enum) > 0 {
			for _, e := range ps.Enum {
				if e == str {
					return str, true
				}
			}
			return nil, false
		}
		return str, true
	}
	return nil, false
}

// Ingest validates and stores a client batch for the caller. installID may be nil.
func (s *Service) Ingest(ctx context.Context, userID uuid.UUID, installID uuid.NullUUID, appVersion, market string, events []Event) (Result, error) {
	if len(events) == 0 || len(events) > maxBatch {
		return Result{}, httpx.NewError(httpx.CodeInvalidInput, fmt.Sprintf("batch must contain 1..%d events", maxBatch))
	}
	if err := s.ensureCurrentMonth(ctx); err != nil {
		return Result{}, err
	}
	now := s.clk.Now()
	res := Result{Reasons: map[string]int{}}
	rows := make([]dbgen.InsertEventParams, 0, len(events))
	for _, e := range events {
		cl, reason := s.validate(e, false, now)
		if reason != "" {
			res.Rejected++
			res.Reasons[reason]++
			if s.OnRejected != nil {
				s.OnRejected(reason)
			}
			continue
		}
		props, _ := json.Marshal(cl.props)
		rows = append(rows, dbgen.InsertEventParams{ID: cl.id, UserID: uuid.NullUUID{UUID: userID, Valid: userID != uuid.Nil},
			InstallID: installID, Name: cl.name, Props: props, ClientTs: cl.ts, AppVersion: truncate(appVersion, 32),
			Market: market, ReceivedAt: now, SessionID: cl.sess})
		res.Accepted++ // duplicates (same event_id) count as accepted so the client drops them
	}
	if err := s.insert(ctx, rows); err != nil {
		return Result{}, err
	}
	if s.OnIngested != nil && res.Accepted > 0 {
		s.OnIngested(res.Accepted)
	}
	return res, nil
}

func (s *Service) insert(ctx context.Context, rows []dbgen.InsertEventParams) error {
	if len(rows) == 0 {
		return nil
	}
	return s.pool.WithTx(ctx, func(tx pgx.Tx) error {
		br := dbgen.New(tx).InsertEvent(ctx, rows)
		var first error
		br.Exec(func(_ int, err error) {
			if err != nil && first == nil {
				first = err
			}
		})
		if err := br.Close(); err != nil && first == nil {
			first = err
		}
		if first != nil {
			return fmt.Errorf("insert events: %w", first)
		}
		return nil
	})
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}

// Emit records a server-side event (billing worker implements ServerEventSink through this).
func (s *Service) Emit(ctx context.Context, name string, userID uuid.UUID, props map[string]any) error {
	id, err := uuid.NewV7()
	if err != nil {
		return fmt.Errorf("uuid: %w", err)
	}
	now := s.clk.Now()
	// JSON round trip so props have the same dynamic types as client events.
	b, _ := json.Marshal(props)
	var p map[string]any
	_ = json.Unmarshal(b, &p)
	cl, reason := s.validate(Event{EventID: id.String(), Name: name, TS: now.Format(time.RFC3339), Props: p}, true, now)
	if reason != "" {
		return fmt.Errorf("analytics: server event %s rejected: %s", name, reason)
	}
	if err := s.ensureCurrentMonth(ctx); err != nil {
		return err
	}
	pj, _ := json.Marshal(cl.props)
	return s.insert(ctx, []dbgen.InsertEventParams{{ID: id, UserID: uuid.NullUUID{UUID: userID, Valid: userID != uuid.Nil},
		Name: name, Props: pj, ClientTs: now, ReceivedAt: now}})
}

// OnUserDeleted implements user.DeletionHook: events are kept but anonymized.
func (s *Service) OnUserDeleted(ctx context.Context, userID uuid.UUID) error {
	if err := dbgen.New(s.pool).AnonymizeUserEvents(ctx, uuid.NullUUID{UUID: userID, Valid: true}); err != nil {
		return fmt.Errorf("anonymize events: %w", err)
	}
	return nil
}
