package app

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync/atomic"

	"github.com/emirdatcom/pashmak/backend/internal/modules/admin"
	"github.com/emirdatcom/pashmak/backend/internal/modules/analytics"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth"
	smslog "github.com/emirdatcom/pashmak/backend/internal/modules/auth/sms/log"
	"github.com/emirdatcom/pashmak/backend/internal/modules/auth/sms/smsir"
	"github.com/emirdatcom/pashmak/backend/internal/modules/backup"
	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/modules/content"
	"github.com/emirdatcom/pashmak/backend/internal/modules/entitlement"
	"github.com/emirdatcom/pashmak/backend/internal/modules/remoteconfig"
	"github.com/emirdatcom/pashmak/backend/internal/modules/support"
	"github.com/emirdatcom/pashmak/backend/internal/modules/support/operatorpanel"
	"github.com/emirdatcom/pashmak/backend/internal/modules/user"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/config"
	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/metrics"
	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
)

// Services is the fully wired module set shared by cmd/api and cmd/worker.
type Services struct {
	Auth         *auth.Service
	User         *user.Service
	Entitlement  *entitlement.Service
	Billing      *billing.Service
	RemoteConfig *remoteconfig.Service
	Content      *content.Service
	Analytics    *analytics.Service
	Admin        *admin.Service
	Phone        *auth.PhoneService // nil unless SMS_PROVIDER is set
	Backup       *backup.Service
	Support      *support.Service
	SupportPanel *operatorpanel.Panel
}

// entitlementConfig adapts remoteconfig to entitlement.ConfigReader using the active base config
// (experiment overrides are per-user and therefore not applied here). Missing/invalid config
// falls back to the docs/60 defaults.
type entitlementConfig struct{ rc *remoteconfig.Service }

func (e entitlementConfig) Entitlement(ctx context.Context) entitlement.Config {
	def := entitlement.StaticConfig{}.Entitlement(ctx)
	raw, _, err := e.rc.Base(ctx)
	if err != nil {
		return def
	}
	var c struct {
		Trial struct {
			Enabled *bool `json:"enabled"`
			Days    *int  `json:"days"`
		} `json:"trial"`
		Entitlement struct {
			GraceDays           *int `json:"grace_days"`
			OfflineValidityDays *int `json:"offline_validity_days"`
		} `json:"entitlement"`
	}
	if json.Unmarshal(raw, &c) != nil {
		return def
	}
	if c.Trial.Enabled != nil {
		def.TrialEnabled = *c.Trial.Enabled
	}
	if c.Trial.Days != nil {
		def.TrialDays = *c.Trial.Days
	}
	if c.Entitlement.GraceDays != nil {
		def.GraceDays = *c.Entitlement.GraceDays
	}
	if c.Entitlement.OfflineValidityDays != nil {
		def.OfflineValidityDays = *c.Entitlement.OfflineValidityDays
	}
	return def
}

// supportConfig adapts remoteconfig to support.ConfigReader (active base config; the defaults apply when it
// cannot be read, so the chat keeps working during a config outage).
type supportConfig struct{ rc *remoteconfig.Service }

func (c supportConfig) Support(ctx context.Context) support.Config {
	def := support.DefaultConfig()
	raw, _, err := c.rc.Base(ctx)
	if err != nil {
		return def
	}
	var v struct {
		Support *struct {
			Enabled         *bool           `json:"enabled"`
			Hours           []support.Hours `json:"hours"`
			Timezone        string          `json:"timezone"`
			MaxMessageChars int             `json:"max_message_chars"`
		} `json:"support"`
	}
	if json.Unmarshal(raw, &v) != nil || v.Support == nil {
		return def
	}
	if v.Support.Enabled != nil {
		def.Enabled = *v.Support.Enabled
	}
	if v.Support.Hours != nil {
		def.Hours = v.Support.Hours
	}
	if v.Support.Timezone != "" {
		def.Timezone = v.Support.Timezone
	}
	if v.Support.MaxMessageChars > 0 {
		def.MaxMessageChars = v.Support.MaxMessageChars
	}
	return def
}

// BuildOptions tune BuildServices.
type BuildOptions struct {
	// NeedSigners requires the at-/ent- signing keys (the API); the worker only needs grant methods.
	NeedSigners bool
}

// BuildServices constructs every module. m may be nil (worker).
func BuildServices(ctx context.Context, cfg config.Config, pool *db.Pool, clk clock.Clock, m *metrics.Metrics, opt BuildOptions) (*Services, error) {
	_ = ctx
	sch, err := schemas.Load(cfg.ConfigDataDir)
	if err != nil {
		return nil, fmt.Errorf("schemas (CONFIG_DATA_DIR=%s): %w", cfg.ConfigDataDir, err)
	}
	cat, err := schemas.LoadCatalog(cfg.ConfigDataDir)
	if err != nil {
		return nil, err
	}
	sv := &Services{}
	sv.Analytics = analytics.NewService(pool, cat, clk)
	if m != nil {
		sv.Analytics.OnIngested = func(n int) { m.EventsIngested.Add(float64(n)) }
		sv.Analytics.OnRejected = func(reason string) { m.EventsRejected.WithLabelValues(reason).Inc() }
	}
	sv.RemoteConfig = remoteconfig.NewService(pool, sch, clk)
	sv.Content = content.NewService(pool, sch, clk)

	var atSigner auth.TokenSigner
	var entSigner entitlement.Signer
	if s, err := signer.LoadWithPrefix(cfg.SigningKeysDir, "at-"); err == nil {
		atSigner = s
	} else if opt.NeedSigners {
		return nil, fmt.Errorf("access-token signer (keys with prefix at-): %w", err)
	}
	if s, err := signer.LoadWithPrefix(cfg.SigningKeysDir, "ent-"); err == nil {
		entSigner = s
	} else if opt.NeedSigners {
		return nil, fmt.Errorf("entitlement signer (keys with prefix ent-): %w", err)
	}
	sv.Entitlement = entitlement.NewService(pool, entSigner, clk, entitlementConfig{sv.RemoteConfig})
	sv.Auth = auth.NewService(auth.NewPGStore(pool), atSigner, clk, cfg.DeviceHashSalt)
	sv.User = user.NewService(user.NewPGStore(pool), sv.Auth, clk, sv.Entitlement, sv.Analytics)
	sv.Billing, err = NewBilling(cfg, pool, clk, m, sv.Entitlement, sv.Analytics)
	if err != nil {
		return nil, fmt.Errorf("billing: %w", err)
	}
	sv.Backup = backup.NewService(pool, clk, cfg.BackupMaxBytes)
	sv.User.AddHook(sv.Backup)
	if cfg.SMSProvider != "" {
		key := cfg.DataEncKey
		if key == nil {
			key = devEncKey
		}
		box, err := crypt.New(key)
		if err != nil {
			return nil, fmt.Errorf("phone service: %w", err)
		}
		var sender auth.SMSSender
		switch cfg.SMSProvider {
		case "smsir":
			sender = smsir.New(smsir.Config{APIKey: cfg.SMSIRAPIKey, TemplateID: cfg.SMSIRTemplateID, ParamName: cfg.SMSIRParamName, LineNumber: cfg.SMSIRLineNumber}, nil)
		default:
			sender = smslog.Adapter{}
		}
		sv.Phone = auth.NewPhoneService(pool, sv.Auth, box, sender, clk, sv.Billing)
	}
	{
		key := cfg.DataEncKey
		if key == nil {
			if cfg.IsProd() {
				return nil, fmt.Errorf("DATA_ENC_KEY is required")
			}
			key = devEncKey
		}
		box, err := crypt.New(key)
		if err != nil {
			return nil, fmt.Errorf("support box: %w", err)
		}
		hub := support.NewHub(pool)
		var obs support.Observer
		if m != nil {
			obs.FirstResponse = m.SupportFirstResponse.Observe
		}
		sv.Support = support.NewService(pool, clk, box, supportConfig{sv.RemoteConfig}, hub, obs)
		sv.User.AddHook(sv.Support)
		if m != nil {
			var conns atomic.Int64
			hub.OnConnections(func(n int) { conns.Store(int64(n)) })
			m.RegisterGauge("support_ws_connections", "Open support WebSocket connections.", func() float64 { return float64(conns.Load()) })
			m.RegisterGauge("support_open_conversations", "Non-closed support conversations.", func() float64 { return float64(sv.Support.OpenConversations(context.Background())) })
			m.RegisterGauge("support_oldest_unanswered_seconds", "Age of the longest-waiting user message during working hours (0 when none).",
				func() float64 { return sv.Support.OldestUnanswered(context.Background()).Seconds() })
		}
	}
	if cfg.AdminUser != "" {
		sv.Admin, err = admin.New(admin.Options{Pool: pool, Config: sv.RemoteConfig, Content: sv.Content, Grants: sv.Entitlement,
			Clock: clk, User: cfg.AdminUser, PasswordHash: cfg.AdminPasswordHash, Allowlist: cfg.AdminIPAllowlist, AllowLocal: !cfg.IsProd()})
		if err != nil {
			return nil, err
		}
		sv.SupportPanel = operatorpanel.New(operatorpanel.Options{Pool: pool, Support: sv.Support, Grants: sv.Entitlement, Clock: clk,
			Guard: sv.Admin.IPGuard(), Secure: cfg.IsProd()})
	}
	return sv, nil
}

// Deps converts Services to handler dependencies.
func (s *Services) Deps(pool *db.Pool, m *metrics.Metrics, clk clock.Clock) Deps {
	return Deps{DB: pool, Metrics: m, Clock: clk, Auth: s.Auth, User: s.User, Entitle: s.Entitlement, Billing: s.Billing,
		RemoteConfig: s.RemoteConfig, Content: s.Content, Analytics: s.Analytics, Admin: s.Admin,
		Phone: s.Phone, Backup: s.Backup, Support: s.Support, SupportPanel: s.SupportPanel}
}

// ConfigDataFile reads a file under the config-data directory (used by tools and tests).
func ConfigDataFile(cfg config.Config, rel string) ([]byte, error) {
	b, err := os.ReadFile(filepath.Join(cfg.ConfigDataDir, rel)) // #nosec G304 -- operator-controlled dir
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", rel, err)
	}
	return b, nil
}
