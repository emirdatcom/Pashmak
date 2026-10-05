// Package operatorpanel is the support operators' web panel (docs/10 §6.4): a static, self-contained page
// (no external fonts, scripts or CDNs; strict CSP) plus its JSON/WebSocket API. Auth = operator username/password →
// session cookie (HttpOnly, SameSite=Strict) + CSRF header, behind the admin IP allowlist. Every action is audited.
package operatorpanel

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io/fs"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/emirdatcom/pashmak/backend/internal/modules/support"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
	"github.com/emirdatcom/pashmak/backend/internal/platform/httpx"
)

//go:embed static
var staticFS embed.FS

const (
	cookieName  = "op_session"
	sessionTTL  = 12 * time.Hour
	csrfHeader  = "X-CSRF-Token"
	cspPolicy   = "default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
	maxBodyJSON = 16 << 10
)

// Granter issues promo grants (entitlement.Service).
type Granter interface {
	GrantPromo(ctx context.Context, userID uuid.UUID, days int, reason string) error
}

// Options configure the panel.
type Options struct {
	Pool    *db.Pool
	Support *support.Service
	Grants  Granter
	Clock   clock.Clock
	Guard   httpx.Middleware // admin IP allowlist
	Secure  bool             // Secure cookie flag (prod)
}

// Panel serves the operator UI and API.
type Panel struct {
	o         Options
	loginRate *httpx.RateLimiter
}

// New builds the panel.
func New(o Options) *Panel {
	return &Panel{o: o, loginRate: httpx.NewRateLimiter(o.Clock, 10, 60)} // 10 attempts, then 1 per minute, per IP
}

type operator struct {
	ID          uuid.UUID
	Username    string
	DisplayName string
	Role        string
	token       string // raw session token
}

type opKey struct{}

func opFrom(ctx context.Context) operator { o, _ := ctx.Value(opKey{}).(operator); return o }

func hashToken(t string) string { h := sha256.Sum256([]byte(t)); return hex.EncodeToString(h[:]) }

// csrfFor derives the CSRF token from the session token (the page reads it from /me, never from a cookie).
func csrfFor(token string) string { return hashToken("csrf|" + token) }

// Register mounts the panel.
func (p *Panel) Register(r *httpx.Router) {
	g := p.o.Guard
	sub, _ := fs.Sub(staticFS, "static")
	files := http.FileServer(http.FS(sub))
	r.Handle("GET /admin/support/", http.StripPrefix("/admin/support/", secureHeaders(files)), g)
	r.HandleFunc("GET /admin/support", func(w http.ResponseWriter, req *http.Request) {
		http.Redirect(w, req, "/admin/support/", http.StatusFound)
	}, g)

	r.HandleFunc("POST /admin/v1/support/login", p.login, g)
	auth := func(h http.HandlerFunc) (http.HandlerFunc, httpx.Middleware) { return h, p.session }
	for pattern, h := range map[string]http.HandlerFunc{
		"POST /admin/v1/support/logout":                      p.logout,
		"GET /admin/v1/support/me":                           p.me,
		"GET /admin/v1/support/conversations":                p.listConversations,
		"GET /admin/v1/support/conversations/{id}":           p.getConversation,
		"GET /admin/v1/support/conversations/{id}/messages":  p.listMessages,
		"POST /admin/v1/support/conversations/{id}/messages": p.sendMessage,
		"POST /admin/v1/support/conversations/{id}/read":     p.markRead,
		"POST /admin/v1/support/conversations/{id}/assign":   p.assign,
		"POST /admin/v1/support/conversations/{id}/close":    p.closeConv,
		"GET /admin/v1/support/canned":                       p.listCanned,
		"PUT /admin/v1/support/canned/{key}":                 p.putCanned,
		"DELETE /admin/v1/support/canned/{key}":              p.deleteCanned,
		"POST /admin/v1/support/users/{id}/grant":            p.grant,
	} {
		hh, sess := auth(h)
		r.HandleFunc(pattern, hh, g, sess)
	}
	r.HandleFunc("GET /admin/v1/support/ws", p.socket, g, p.session)
}

func secureHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Content-Security-Policy", cspPolicy)
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

// ---- session -----------------------------------------------------------------------------------

func (p *Panel) session(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		secureHeaders(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			c, err := r.Cookie(cookieName)
			if err != nil || c.Value == "" {
				httpx.WriteError(w, r, httpx.CodeUnauthenticated, "login required")
				return
			}
			s, err := dbgen.New(p.o.Pool).GetOperatorSession(r.Context(), hashToken(c.Value))
			now := p.o.Clock.Now()
			if err != nil || s.RevokedAt != nil || !s.ExpiresAt.After(now) || !s.Active {
				httpx.WriteError(w, r, httpx.CodeUnauthenticated, "login required")
				return
			}
			if r.Method != http.MethodGet && r.Method != http.MethodHead {
				if subtle.ConstantTimeCompare([]byte(r.Header.Get(csrfHeader)), []byte(csrfFor(c.Value))) != 1 {
					httpx.WriteError(w, r, httpx.CodeForbidden, "csrf token missing or wrong")
					return
				}
			}
			op := operator{ID: s.OperatorID, Username: s.Username, DisplayName: s.DisplayName, Role: s.Role, token: c.Value}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), opKey{}, op)))
		})).ServeHTTP(w, r)
	})
}

func (p *Panel) login(w http.ResponseWriter, r *http.Request) {
	secureHeaders(http.HandlerFunc(p.doLogin)).ServeHTTP(w, r)
}

func (p *Panel) doLogin(w http.ResponseWriter, r *http.Request) {
	if !p.loginRate.Allow(httpx.ClientIP(r)) {
		w.Header().Set("Retry-After", "60")
		httpx.WriteError(w, r, httpx.CodeRateLimited, "too many login attempts")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyJSON)
	var in struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	q := dbgen.New(p.o.Pool)
	op, err := q.GetOperatorByUsername(r.Context(), in.Username)
	// Always run bcrypt so response time does not reveal whether the username exists.
	hash := "$2a$10$7EqJtq98hPqEX7fNZaFWoOa1n0wQ4yq1iZ0mQz5yM9oXxQJb0j8e2"
	if err == nil {
		hash = op.PasswordHash
	}
	passOK := bcrypt.CompareHashAndPassword([]byte(hash), []byte(in.Password)) == nil
	if err != nil || !passOK || !op.Active {
		slog.WarnContext(r.Context(), "operator login failed", "ip", httpx.ClientIP(r))
		httpx.WriteError(w, r, httpx.CodeUnauthenticated, "wrong username or password")
		return
	}
	raw := make([]byte, 32)
	_, _ = rand.Read(raw)
	token := base64.RawURLEncoding.EncodeToString(raw)
	now := p.o.Clock.Now()
	if err := q.InsertOperatorSession(r.Context(), dbgen.InsertOperatorSessionParams{ID: uuid.Must(uuid.NewV7()), OperatorID: op.ID,
		TokenHash: hashToken(token), ExpiresAt: now.Add(sessionTTL), CreatedAt: now}); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	_ = q.TouchOperatorLogin(r.Context(), dbgen.TouchOperatorLoginParams{ID: op.ID, LastLoginAt: &now})
	http.SetCookie(w, &http.Cookie{Name: cookieName, Value: token, Path: "/admin", HttpOnly: true, Secure: p.o.Secure,
		SameSite: http.SameSiteStrictMode, MaxAge: int(sessionTTL.Seconds())})
	p.audit(r.Context(), operator{ID: op.ID, Username: op.Username}, "support.login", op.Username, nil)
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"username": op.Username, "display_name": op.DisplayName, "role": op.Role, "csrf": csrfFor(token)})
}

func (p *Panel) logout(w http.ResponseWriter, r *http.Request) {
	op := opFrom(r.Context())
	_ = dbgen.New(p.o.Pool).RevokeOperatorSession(r.Context(), dbgen.RevokeOperatorSessionParams{TokenHash: hashToken(op.token), RevokedAt: ptr(p.o.Clock.Now())})
	http.SetCookie(w, &http.Cookie{Name: cookieName, Value: "", Path: "/admin", HttpOnly: true, Secure: p.o.Secure, SameSite: http.SameSiteStrictMode, MaxAge: -1})
	w.WriteHeader(http.StatusNoContent)
}

func (p *Panel) me(w http.ResponseWriter, r *http.Request) {
	op := opFrom(r.Context())
	cfg := p.o.Support.Config(r.Context())
	online, _ := cfg.Status(p.o.Clock.Now())
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"username": op.Username, "display_name": op.DisplayName, "role": op.Role,
		"csrf": csrfFor(op.token), "support_enabled": cfg.Enabled, "within_hours": online})
}

func ptr[T any](v T) *T { return &v }

// audit records an operator action. Payloads never contain message text.
func (p *Panel) audit(ctx context.Context, op operator, action, target string, payload map[string]any) {
	if payload == nil {
		payload = map[string]any{}
	}
	payload["result"] = "ok"
	b, _ := json.Marshal(payload)
	if err := dbgen.New(p.o.Pool).InsertAdminAudit(ctx, dbgen.InsertAdminAuditParams{Actor: "operator:" + op.Username, Action: action, Target: target, Payload: b}); err != nil {
		slog.ErrorContext(ctx, "operator audit insert failed", "action", action, "err", err)
	}
}

// ---- conversations ------------------------------------------------------------------------------

func convID(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "invalid id")
		return uuid.Nil, false
	}
	return id, true
}

func (p *Panel) listConversations(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	if status != "" && status != "open" && status != "waiting_user" && status != "closed" {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "status must be open, waiting_user or closed")
		return
	}
	items, err := p.o.Support.Queue(r.Context(), status, 100)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"conversations": items})
}

// getConversation returns conversation facts, the consented device meta and the user's entitlement status.
// The server holds no mood, note or habit data, so there is nothing of that kind to show.
func (p *Panel) getConversation(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	c, err := p.o.Support.Conversation(r.Context(), id)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	out := map[string]any{"id": c.ID, "user_id": c.UserID, "status": c.Status, "created_at": c.CreatedAt, "last_message_at": c.LastMessageAt,
		"awaiting_since": c.AwaitingSince, "assigned_operator_id": c.AssignedOperatorID.UUID}
	if len(c.DeviceMeta) > 0 {
		out["device_meta"] = json.RawMessage(c.DeviceMeta)
	}
	out["entitlement"] = p.entitlement(r.Context(), c.UserID)
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (p *Panel) entitlement(ctx context.Context, userID uuid.UUID) map[string]any {
	q := dbgen.New(p.o.Pool)
	now := p.o.Clock.Now()
	res := map[string]any{"premium": false}
	grants, _ := q.ListGrantsByUser(ctx, userID)
	for _, g := range grants {
		if g.RevokedAt == nil && !g.StartsAt.After(now) && g.EndsAt.After(now) {
			res["premium"] = true
			if prev, ok := res["ends_at"].(time.Time); !ok || g.EndsAt.After(prev) {
				res["ends_at"] = g.EndsAt
				res["source"] = g.Source
			}
		}
	}
	if t, err := q.GetTrialByUser(ctx, userID); err == nil {
		res["trial_ends_at"] = t.EndsAt
	}
	return res
}

func (p *Panel) listMessages(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	cursor := func(name string) (*uuid.UUID, bool) {
		v := r.URL.Query().Get(name)
		if v == "" {
			return nil, true
		}
		u, err := uuid.Parse(v)
		if err != nil {
			httpx.WriteError(w, r, httpx.CodeInvalidInput, name+" must be a message id")
			return nil, false
		}
		return &u, true
	}
	after, ok1 := cursor("after")
	before, ok2 := cursor("before")
	if !ok1 || !ok2 {
		return
	}
	msgs, more, err := p.o.Support.OperatorMessages(r.Context(), id, after, before, 50)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"messages": msgs, "has_more": more})
}

func (p *Panel) sendMessage(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyJSON)
	var in struct {
		Body string `json:"body"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	op := opFrom(r.Context())
	m, err := p.o.Support.OperatorSend(r.Context(), op.ID, id, in.Body)
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.reply", id.String(), map[string]any{"message_id": m.ID})
	httpx.WriteJSON(w, http.StatusOK, m)
}

func (p *Panel) markRead(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	var in struct {
		UpTo uuid.UUID `json:"up_to_message_id"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil || in.UpTo == uuid.Nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "up_to_message_id is required")
		return
	}
	if err := p.o.Support.OperatorRead(r.Context(), id, in.UpTo); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (p *Panel) assign(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	op := opFrom(r.Context())
	if err := p.o.Support.Assign(r.Context(), id, op.ID); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.assign", id.String(), nil)
	w.WriteHeader(http.StatusNoContent)
}

func (p *Panel) closeConv(w http.ResponseWriter, r *http.Request) {
	id, ok := convID(w, r)
	if !ok {
		return
	}
	op := opFrom(r.Context())
	if err := p.o.Support.Close(r.Context(), id); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.close", id.String(), nil)
	w.WriteHeader(http.StatusNoContent)
}

// ---- canned replies & grants --------------------------------------------------------------------

func (p *Panel) listCanned(w http.ResponseWriter, r *http.Request) {
	q := dbgen.New(p.o.Pool)
	var rows []dbgen.SupportCannedReply
	var err error
	if opFrom(r.Context()).Role == "admin" {
		rows, err = q.ListCannedAll(r.Context())
	} else {
		rows, err = q.ListCanned(r.Context())
	}
	if err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	out := make([]map[string]any, 0, len(rows))
	for _, c := range rows {
		out = append(out, map[string]any{"key": c.Key, "title": c.Title, "body": c.Body, "active": c.Active})
	}
	httpx.WriteJSON(w, http.StatusOK, map[string]any{"canned": out})
}

func requireAdmin(w http.ResponseWriter, r *http.Request) (operator, bool) {
	op := opFrom(r.Context())
	if op.Role != "admin" {
		httpx.WriteError(w, r, httpx.CodeForbidden, "admin role required")
		return op, false
	}
	return op, true
}

func (p *Panel) putCanned(w http.ResponseWriter, r *http.Request) {
	op, ok := requireAdmin(w, r)
	if !ok {
		return
	}
	var in struct {
		Title  string `json:"title"`
		Body   string `json:"body"`
		Active *bool  `json:"active"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxBodyJSON)
	if err := httpx.DecodeJSON(r, &in); err != nil || strings.TrimSpace(in.Title) == "" || strings.TrimSpace(in.Body) == "" {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "title and body are required")
		return
	}
	key := r.PathValue("key")
	active := in.Active == nil || *in.Active
	if err := dbgen.New(p.o.Pool).UpsertCanned(r.Context(), dbgen.UpsertCannedParams{ID: uuid.Must(uuid.NewV7()), Key: key, Title: in.Title, Body: in.Body, Active: active}); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.canned.put", key, nil)
	w.WriteHeader(http.StatusNoContent)
}

func (p *Panel) deleteCanned(w http.ResponseWriter, r *http.Request) {
	op, ok := requireAdmin(w, r)
	if !ok {
		return
	}
	key := r.PathValue("key")
	if err := dbgen.New(p.o.Pool).DeleteCanned(r.Context(), key); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.canned.delete", key, nil)
	w.WriteHeader(http.StatusNoContent)
}

// grant gives a promo period (role admin only). The reason is audited, the amount is bounded.
func (p *Panel) grant(w http.ResponseWriter, r *http.Request) {
	op, ok := requireAdmin(w, r)
	if !ok {
		return
	}
	uid, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "invalid user id")
		return
	}
	var in struct {
		Days   int    `json:"days"`
		Reason string `json:"reason"`
	}
	if err := httpx.DecodeJSON(r, &in); err != nil || in.Days < 1 || in.Days > 365 || strings.TrimSpace(in.Reason) == "" {
		httpx.WriteError(w, r, httpx.CodeInvalidInput, "days (1..365) and reason are required")
		return
	}
	u, uerr := dbgen.New(p.o.Pool).GetUser(r.Context(), uid)
	if errors.Is(uerr, pgx.ErrNoRows) || (uerr == nil && u.Status != "active") {
		httpx.WriteError(w, r, httpx.CodeNotFound, "user not found")
		return
	}
	if err := p.o.Grants.GrantPromo(r.Context(), uid, in.Days, "support:"+in.Reason); err != nil {
		httpx.WriteErr(w, r, err)
		return
	}
	p.audit(r.Context(), op, "support.grant.promo", uid.String(), map[string]any{"days": in.Days, "reason": in.Reason})
	httpx.WriteJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

// ---- operator WebSocket ------------------------------------------------------------------------

// socket streams every conversation event to the panel. Cookie auth + same-origin check (browser clients).
func (p *Panel) socket(w http.ResponseWriter, r *http.Request) {
	c, err := websocket.Accept(w, r, &websocket.AcceptOptions{OriginPatterns: []string{r.Host}})
	if err != nil {
		return
	}
	defer func() { _ = c.CloseNow() }()
	events, unsub := p.o.Support.Hub().SubscribeOperator()
	defer unsub()
	p.o.Support.Pump(r.Context(), c, events)
	_ = c.Close(websocket.StatusNormalClosure, "")
}
