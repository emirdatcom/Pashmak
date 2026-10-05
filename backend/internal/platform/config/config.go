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

	SMSProvider       string // "", "log" (dev) or "kavenegar"
	KavenegarAPIKey   string
	KavenegarTemplate string
	BackupStorage     string // "db" (default) or "s3"
	S3Endpoint        string
	S3Region          string
	S3Bucket          string
	S3AccessKey       string
	S3SecretKey       string
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

		SMSProvider:       get("SMS_PROVIDER"),
		KavenegarAPIKey:   get("KAVENEGAR_API_KEY"),
		KavenegarTemplate: get("KAVENEGAR_TEMPLATE"),
		BackupStorage:     str("BACKUP_STORAGE", "db"),
		S3Endpoint:        get("S3_ENDPOINT"),
		S3Region:          str("S3_REGION", "us-east-1"),
		S3Bucket:          get("S3_BUCKET"),
		S3AccessKey:       get("S3_ACCESS_KEY"),
		S3SecretKey:       get("S3_SECRET_KEY"),
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
	case "", "log", "kavenegar":
	default:
		errs = append(errs, fmt.Errorf("SMS_PROVIDER must be empty, log or kavenegar, got %q", c.SMSProvider))
	}
	if c.SMSProvider == "kavenegar" && (c.KavenegarAPIKey == "" || c.KavenegarTemplate == "") {
		errs = append(errs, errors.New("KAVENEGAR_API_KEY and KAVENEGAR_TEMPLATE are required when SMS_PROVIDER=kavenegar"))
	}
	switch c.BackupStorage {
	case "db":
	case "s3":
		if c.S3Endpoint == "" || c.S3Bucket == "" || c.S3AccessKey == "" || c.S3SecretKey == "" {
			errs = append(errs, errors.New("S3_ENDPOINT, S3_BUCKET, S3_ACCESS_KEY and S3_SECRET_KEY are required when BACKUP_STORAGE=s3"))
		}
	default:
		errs = append(errs, fmt.Errorf("BACKUP_STORAGE must be db or s3, got %q", c.BackupStorage))
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
