// Package config loads and validates environment configuration.
package config

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds all runtime settings.
type Config struct {
	AppEnv            string
	HTTPAddr          string
	DatabaseURL       string
	DBMaxConns        int
	LogLevel          string
	MetricsAddr       string
	AdminUser         string
	AdminPasswordHash string
	AdminIPAllowlist  []string
	SigningKeysDir    string
	DeviceHashSalt    string
	DataEncKey        []byte
	ConfigDataDir     string // directory holding schemas and the events catalog (config-data/)

	BillingBazaarEnabled bool
	BillingMyketEnabled  bool
	BillingFakeEnabled   bool // dev/staging only
	BazaarPackageName    string
	BazaarClientID       string
	BazaarClientSecret   string
	BazaarRefreshToken   string
	MyketPackageName     string
	MyketAccessToken     string

	SMSProvider     string // "", "log" (dev) or "smsir"
	SMSIRAPIKey     string
	SMSIRTemplateID string
	SMSIRParamName  string
	SMSIRLineNumber string // service line for operational alerts
	AlertPhones     []string
	BackupMaxBytes  int
}

// IsProd reports whether APP_ENV is prod.
func (c Config) IsProd() bool { return c.AppEnv == "prod" }

// Load reads configuration using os.Getenv.
func Load() (Config, error) { return LoadFrom(os.Getenv) }

// LoadFrom reads configuration from the given lookup function.
func LoadFrom(get func(string) string) (Config, error) {
	str := func(k, def string) string {
		if v := get(k); v != "" {
			return v
		}
		return def
	}
	c := Config{
		AppEnv:            str("APP_ENV", "dev"),
		HTTPAddr:          str("HTTP_ADDR", ":8080"),
		DatabaseURL:       get("DATABASE_URL"),
		LogLevel:          str("LOG_LEVEL", "info"),
		MetricsAddr:       str("METRICS_ADDR", "127.0.0.1:9090"),
		AdminUser:         get("ADMIN_USER"),
		AdminPasswordHash: get("ADMIN_PASSWORD_HASH"),
		SigningKeysDir:    str("SIGNING_KEYS_DIR", "./keys"),
		DeviceHashSalt:    get("DEVICE_HASH_SALT"),
		ConfigDataDir:     str("CONFIG_DATA_DIR", "../config-data"),

		BillingBazaarEnabled: get("BILLING_BAZAAR_ENABLED") == "true",
		BillingMyketEnabled:  get("BILLING_MYKET_ENABLED") == "true",
		BillingFakeEnabled:   get("BILLING_FAKE_ENABLED") == "true",
		BazaarPackageName:    get("BAZAAR_PACKAGE_NAME"),
		BazaarClientID:       get("BAZAAR_CLIENT_ID"),
		BazaarClientSecret:   get("BAZAAR_CLIENT_SECRET"),
		BazaarRefreshToken:   get("BAZAAR_REFRESH_TOKEN"),
		MyketPackageName:     get("MYKET_PACKAGE_NAME"),
		MyketAccessToken:     get("MYKET_ACCESS_TOKEN"),

		SMSProvider:     get("SMS_PROVIDER"),
		SMSIRAPIKey:     get("SMSIR_API_KEY"),
		SMSIRTemplateID: get("SMSIR_OTP_TEMPLATE_ID"),
		SMSIRParamName:  str("SMSIR_OTP_PARAM_NAME", "CODE"),
		SMSIRLineNumber: get("SMSIR_LINE_NUMBER"),
		AlertPhones:     splitCSV(get("ALERT_PHONES")),
	}
	var errs []error
	switch c.AppEnv {
	case "dev", "staging", "prod":
	default:
		errs = append(errs, fmt.Errorf("APP_ENV must be dev|staging|prod, got %q", c.AppEnv))
	}
	c.DBMaxConns = 10
	if v := get("DB_MAX_CONNS"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			errs = append(errs, fmt.Errorf("DB_MAX_CONNS must be a positive integer"))
		} else {
			c.DBMaxConns = n
		}
	}
	for _, ip := range strings.Split(get("ADMIN_IP_ALLOWLIST"), ",") {
		if ip = strings.TrimSpace(ip); ip != "" {
			c.AdminIPAllowlist = append(c.AdminIPAllowlist, ip)
		}
	}
	if v := get("DATA_ENC_KEY"); v != "" {
		k, err := base64.StdEncoding.DecodeString(v)
		if err != nil || len(k) != 32 {
			errs = append(errs, errors.New("DATA_ENC_KEY must be base64 of 32 bytes"))
		} else {
			c.DataEncKey = k
		}
	}
	switch c.SMSProvider {
	case "", "log", "smsir":
	default:
		errs = append(errs, fmt.Errorf("SMS_PROVIDER must be empty, log or smsir, got %q", c.SMSProvider))
	}
	if c.SMSProvider == "smsir" && (c.SMSIRAPIKey == "" || c.SMSIRTemplateID == "") {
		errs = append(errs, errors.New("SMSIR_API_KEY and SMSIR_OTP_TEMPLATE_ID are required when SMS_PROVIDER=smsir"))
	}
	c.BackupMaxBytes = 5 << 20
	if v := get("BACKUP_MAX_BYTES"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1<<10 || n > 64<<20 {
			errs = append(errs, fmt.Errorf("BACKUP_MAX_BYTES must be between 1024 and 67108864, got %q", v))
		} else {
			c.BackupMaxBytes = n
		}
	}
	if c.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required"))
	}
	if c.IsProd() {
		for k, v := range map[string]string{
			"DEVICE_HASH_SALT":    c.DeviceHashSalt,
			"ADMIN_USER":          c.AdminUser,
			"ADMIN_PASSWORD_HASH": c.AdminPasswordHash,
		} {
			if v == "" {
				errs = append(errs, fmt.Errorf("%s is required in prod", k))
			}
		}
		if c.DataEncKey == nil {
			errs = append(errs, errors.New("DATA_ENC_KEY is required in prod"))
		}
		if c.SMSProvider == "log" {
			errs = append(errs, errors.New("SMS_PROVIDER=log must not be used in prod (it logs OTP codes)"))
		}
		if c.BillingFakeEnabled {
			errs = append(errs, errors.New("BILLING_FAKE_ENABLED must not be set in prod"))
		}
		if c.BillingBazaarEnabled && (c.BazaarPackageName == "" || c.BazaarClientID == "" || c.BazaarClientSecret == "" || c.BazaarRefreshToken == "") {
			errs = append(errs, errors.New("BAZAAR_PACKAGE_NAME/CLIENT_ID/CLIENT_SECRET/REFRESH_TOKEN are required when BILLING_BAZAAR_ENABLED"))
		}
	}
	return c, errors.Join(errs...)
}

// splitCSV splits a comma-separated env value, trimming spaces and dropping empties.
func splitCSV(v string) []string {
	var out []string
	for _, p := range strings.Split(v, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
