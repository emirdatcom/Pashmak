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

	BillingBazaarEnabled bool
	BillingMyketEnabled  bool
	BillingFakeEnabled   bool // dev/staging only
	BazaarPackageName    string
	BazaarClientID       string
	BazaarClientSecret   string
	BazaarRefreshToken   string
	MyketPackageName     string
	MyketAccessToken     string
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

		BillingBazaarEnabled: get("BILLING_BAZAAR_ENABLED") == "true",
		BillingMyketEnabled:  get("BILLING_MYKET_ENABLED") == "true",
		BillingFakeEnabled:   get("BILLING_FAKE_ENABLED") == "true",
		BazaarPackageName:    get("BAZAAR_PACKAGE_NAME"),
		BazaarClientID:       get("BAZAAR_CLIENT_ID"),
		BazaarClientSecret:   get("BAZAAR_CLIENT_SECRET"),
		BazaarRefreshToken:   get("BAZAAR_REFRESH_TOKEN"),
		MyketPackageName:     get("MYKET_PACKAGE_NAME"),
		MyketAccessToken:     get("MYKET_ACCESS_TOKEN"),
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
		if c.BillingFakeEnabled {
			errs = append(errs, errors.New("BILLING_FAKE_ENABLED must not be set in prod"))
		}
		if c.BillingBazaarEnabled && (c.BazaarPackageName == "" || c.BazaarClientID == "" || c.BazaarClientSecret == "" || c.BazaarRefreshToken == "") {
			errs = append(errs, errors.New("BAZAAR_PACKAGE_NAME/CLIENT_ID/CLIENT_SECRET/REFRESH_TOKEN are required when BILLING_BAZAAR_ENABLED"))
		}
	}
	return c, errors.Join(errs...)
}
