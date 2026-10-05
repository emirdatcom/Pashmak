// Package admin exposes the minimal /admin/v1 API (docs/10 §6.4): Basic Auth + IP allowlist + audit.
package admin

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/emirdatcom/pashmak/backend/internal/modules/content"
	"github.com/emirdatcom/pashmak/backend/internal/modules/remoteconfig"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

// ConfigAdmin is the remoteconfig surface used by admin.
type ConfigAdmin interface {
	Publish(ctx context.Context, payload json.RawMessage, minAppVersion, publishedBy string) (int, error)
	Activate(ctx context.Context, version int) error
	PutExperiment(ctx context.Context, e remoteconfig.Experiment) error
}

// ContentAdmin is the content surface used by admin.
type ContentAdmin interface {
	Publish(ctx context.Context, doc json.RawMessage) (content.ManifestEntry, error)
}

// Granter issues promo grants (entitlement.Service).
type Granter interface {
	GrantPromo(ctx context.Context, userID uuid.UUID, days int, reason string) error
}

// Options configure the admin module.
type Options struct {
	Pool         *db.Pool
	Config       ConfigAdmin
	Content      ContentAdmin
	Grants       Granter
	Clock        clock.Clock
	User         string
	PasswordHash string   // bcrypt
	Allowlist    []string // IPs or CIDRs
	AllowLocal   bool     // dev only: allow loopback when the allowlist is empty
}

// Service implements the admin endpoints.
type Service struct {
	o    Options
	nets []*net.IPNet
	ips  []net.IP
}

// New builds the admin service.
func New(o Options) (*Service, error) {
	s := &Service{o: o}
	for _, a := range o.Allowlist {
		if _, n, err := net.ParseCIDR(a); err == nil {
			s.nets = append(s.nets, n)
			continue
		}
		ip := net.ParseIP(a)
		if ip == nil {
			return nil, errors.New("admin: invalid ADMIN_IP_ALLOWLIST entry " + a)
		}
		s.ips = append(s.ips, ip)
	}
	return s, nil
}

func (s *Service) ipAllowed(remote string) bool {
	ip := net.ParseIP(remote)
	if ip == nil {
		return false
	}
	for _, a := range s.ips {
		if a.Equal(ip) {
			return true
		}
	}
	for _, n := range s.nets {
		if n.Contains(ip) {
			return true
		}
	}
	return len(s.ips)+len(s.nets) == 0 && s.o.AllowLocal && ip.IsLoopback()
}

type actorKey struct{}

func actorFrom(ctx context.Context) string {
	a, _ := ctx.Value(actorKey{}).(string)
	return a
}

// guard checks IP allowlist then Basic Auth.
func (s *Service) guard() httpx.Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := httpx.ClientIP(r)
			if !s.ipAllowed(ip) {
				slog.WarnContext(r.Context(), "admin access denied", "reason", "ip", "ip", ip)
				httpx.WriteError(w, r, httpx.CodeForbidden, "forbidden")
				return
			}
			user, pass, ok := r.BasicAuth()
			userOK := subtle.ConstantTimeCompare([]byte(user), []byte(s.o.User)) == 1
			passOK := bcrypt.CompareHashAndPassword([]byte(s.o.PasswordHash), []byte(pass)) == nil
			if !ok || !userOK || !passOK || s.o.User == "" {
				slog.WarnContext(r.Context(), "admin access denied", "reason", "credentials", "ip", ip)
				w.Header().Set("WWW-Authenticate", `Basic realm="admin"`)
				httpx.WriteError(w, r, httpx.CodeUnauthenticated, "invalid credentials")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), actorKey{}, user)))
		})
	}
}

// Register mounts /admin/v1/*.
func Register(r *httpx.Router, s *Service) {
	g := s.guard()
	r.HandleFunc("POST /admin/v1/config", s.handlePublishConfig, g)
	r.HandleFunc("POST /admin/v1/config/{version}/activate", s.handleActivate, g)
	r.HandleFunc("PUT /admin/v1/experiments/{key}", s.handlePutExperiment, g)
	r.HandleFunc("POST /admin/v1/content/packs", s.handlePublishPack, g)
	r.HandleFunc("POST /admin/v1/users/{id}/grants", s.handleGrant, g)
	r.HandleFunc("GET /admin/v1/users/{id}", s.handleUser, g)
	r.HandleFunc("GET /admin/v1/metrics/daily", s.handleMetrics, g)
}

// audit records an admin operation. Payloads must never contain secrets or personal data.
func (s *Service) audit(ctx context.Context, action, target string, payload map[string]any, err error) {
	if err != nil {
		code, _ := httpx.CodeOf(err)
		payload["result"] = "error:" + string(code)
	} else {
		payload["result"] = "ok"
	}
	b, _ := json.Marshal(payload)
	if aerr := dbgen.New(s.o.Pool).InsertAdminAudit(ctx, dbgen.InsertAdminAuditParams{
		Actor: actorFrom(ctx), Action: action, Target: target, Payload: b}); aerr != nil {
		slog.ErrorContext(ctx, "admin audit insert failed", "action", action, "err", aerr)
	}
}

func (s *Service) handlePublishConfig(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Payload       json.RawMessage `json:"payload"`
		MinAppVersion string          `json:"min_app_version"`
		Activate      bool            `json:"activate"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	v, err := s.o.Config.Publish(r.Context(), in.Payload, in.MinAppVersion, actorFrom(r.Context()))
	if err == nil && in.Activate {
		err = s.o.Config.Activate(r.Context(), v)
	}
	s.audit(r.Context(), "config.publish", "config", map[string]any{"version": v, "activate": in.Activate, "min_app_version": in.MinAppVersion}, err)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, map[string]any{"version": v, "active": in.Activate})
}

func (s *Service) handleActivate(w http.ResponseWriter, r *http.Request) {
	v, perr := strconv.Atoi(r.PathValue("version"))
	if perr != nil || v < 1 {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "invalid version")
		return
	}
	err := s.o.Config.Activate(r.Context(), v)
	s.audit(r.Context(), "config.activate", "config", map[string]any{"version": v}, err)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"version": v, "active": true})
}

func (s *Service) handlePutExperiment(w http.ResponseWriter, r *http.Request) {
	var e remoteconfig.Experiment
	if err := httpx.DecodeJSON(r, &e); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	if e.Key != "" && e.Key != r.PathValue("key") {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "key in body does not match the path")
		return
	}
	e.Key = r.PathValue("key")
	if e.Status == "" {
		e.Status = "draft"
	}
	err := s.o.Config.PutExperiment(r.Context(), e)
	s.audit(r.Context(), "experiment.put", e.Key, map[string]any{"status": e.Status, "variants": len(e.Variants)}, err)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handlePublishPack(w http.ResponseWriter, r *http.Request) {
	var doc json.RawMessage
	if err := httpx.DecodeJSON(r, &doc); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	m, err := s.o.Content.Publish(r.Context(), doc)
	s.audit(r.Context(), "content.publish", m.PackKey, map[string]any{"pack_key": m.PackKey, "version": m.Version, "sha256": m.SHA256}, err)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, m)
}

func (s *Service) handleGrant(w http.ResponseWriter, r *http.Request) {
	id, perr := uuid.Parse(r.PathValue("id"))
	if perr != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "invalid user id")
		return
	}
	var in struct {
		Days   int    `json:"days"`
		Reason string `json:"reason"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	var err error
	if u, uerr := dbgen.New(s.o.Pool).GetUser(r.Context(), id); errors.Is(uerr, pgx.ErrNoRows) || (uerr == nil && u.Status != "active") {
		err = httpx.NewError(httpx.CodeNotFound, "user not found")
	} else if uerr != nil {
		err = uerr
	} else {
		err = s.o.Grants.GrantPromo(r.Context(), id, in.Days, in.Reason)
	}
	s.audit(r.Context(), "grant.promo", id.String(), map[string]any{"days": in.Days, "reason": in.Reason}, err)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

// handleUser returns account facts only; the server holds no emotional or habit data.
func (s *Service) handleUser(w http.ResponseWriter, r *http.Request) {
	id, perr := uuid.Parse(r.PathValue("id"))
	if perr != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "invalid user id")
		return
	}
	q := dbgen.New(s.o.Pool)
	u, err := q.GetUser(r.Context(), id)
	if errors.Is(err, pgx.ErrNoRows) {
		httpx.WriteError(w, r, httpx.CodeNotFound, "user not found")
		return
	}
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	devices, _ := q.ListDevicesByUser(r.Context(), id)
	grants, _ := q.ListGrantsByUser(r.Context(), id)
	purchases, _ := q.ListPurchasesByUser(r.Context(), id)
	trial, terr := q.GetTrialByUser(r.Context(), id)
	out := map[string]any{"user_id": id, "status": u.Status, "created_at": u.CreatedAt, "phone_linked": u.PhoneVerifiedAt != nil,
		"phone_last4": u.PhoneLast4,
		"devices":     devices, "grants": grants, "purchases": purchases}
	if terr == nil {
		out["trial"] = map[string]any{"started_at": trial.StartedAt, "ends_at": trial.EndsAt}
	}
	s.audit(r.Context(), "user.view", id.String(), map[string]any{}, nil)
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (s *Service) handleMetrics(w http.ResponseWriter, r *http.Request) {
	parse := func(name string, def time.Time) (time.Time, error) {
		v := r.URL.Query().Get(name)
		if v == "" {
			return def, nil
		}
		return time.Parse("2006-01-02", v)
	}
	now := s.o.Clock.Now()
	to, err1 := parse("to", now)
	from, err2 := parse("from", to.AddDate(0, 0, -30))
	if err1 != nil || err2 != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "from/to must be YYYY-MM-DD")
		return
	}
	rows, err := dbgen.New(s.o.Pool).ListDailyMetrics(r.Context(), dbgen.ListDailyMetricsParams{
		Day: from, Day_2: to, Column3: r.URL.Query().Get("metric")})
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	type row struct {
		Day    string          `json:"day"`
		Metric string          `json:"metric"`
		Dims   json.RawMessage `json:"dims"`
		Value  float64         `json:"value"`
	}
	out := make([]row, 0, len(rows))
	for _, m := range rows {
		out = append(out, row{Day: m.Day.Format("2006-01-02"), Metric: m.Metric, Dims: m.Dims, Value: m.Value})
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"metrics": out})
}
