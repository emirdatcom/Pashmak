package config

import (
	"encoding/base64"
	"strings"
	"testing"
)

func env(m map[string]string) func(string) string { return func(k string) string { return m[k] } }

func TestDefaults(t *testing.T) {
	c, err := LoadFrom(env(map[string]string{"DATABASE_URL": "postgres://x"}))
	if err != nil {
		t.Fatal(err)
	}
	if c.AppEnv != "dev" || c.HTTPAddr != ":8080" || c.DBMaxConns != 10 || c.MetricsAddr != "127.0.0.1:9090" {
		t.Fatalf("unexpected defaults: %+v", c)
	}
}

func TestRequiredAndInvalid(t *testing.T) {
	_, err := LoadFrom(env(map[string]string{"APP_ENV": "nope", "DB_MAX_CONNS": "0", "DATA_ENC_KEY": "abc"}))
	if err == nil {
		t.Fatal("expected error")
	}
	for _, want := range []string{"APP_ENV", "DB_MAX_CONNS", "DATA_ENC_KEY", "DATABASE_URL"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error missing %s: %v", want, err)
		}
	}
}

func TestProdRequiresSecrets(t *testing.T) {
	_, err := LoadFrom(env(map[string]string{"APP_ENV": "prod", "DATABASE_URL": "postgres://x"}))
	if err == nil || !strings.Contains(err.Error(), "DEVICE_HASH_SALT") {
		t.Fatalf("expected DEVICE_HASH_SALT error, got %v", err)
	}
	key := base64.StdEncoding.EncodeToString(make([]byte, 32))
	c, err := LoadFrom(env(map[string]string{
		"APP_ENV": "prod", "DATABASE_URL": "postgres://x", "DEVICE_HASH_SALT": "s",
		"ADMIN_USER": "a", "ADMIN_PASSWORD_HASH": "h", "DATA_ENC_KEY": key,
		"ADMIN_IP_ALLOWLIST": "10.0.0.1, 10.0.0.2",
	}))
	if err != nil {
		t.Fatal(err)
	}
	if len(c.AdminIPAllowlist) != 2 || len(c.DataEncKey) != 32 {
		t.Fatalf("bad parse: %+v", c)
	}
}

func TestSMSIRAndBackupLimitEnv(t *testing.T) {
	base := map[string]string{"DATABASE_URL": "postgres://x", "DEVICE_HASH_SALT": "s"}
	with := func(extra map[string]string) (Config, error) {
		m := map[string]string{}
		for k, v := range base {
			m[k] = v
		}
		for k, v := range extra {
			m[k] = v
		}
		return LoadFrom(func(k string) string { return m[k] })
	}
	c, err := with(map[string]string{"SMS_PROVIDER": "smsir", "SMSIR_API_KEY": "k", "SMSIR_OTP_TEMPLATE_ID": "7", "ALERT_PHONES": " +989121111111, ,09122222222 "})
	if err != nil {
		t.Fatal(err)
	}
	if c.SMSIRParamName != "CODE" || len(c.AlertPhones) != 2 || c.AlertPhones[1] != "09122222222" || c.BackupMaxBytes != 5<<20 {
		t.Fatalf("defaults: %+v", c)
	}
	if _, err := with(map[string]string{"SMS_PROVIDER": "smsir"}); err == nil {
		t.Fatal("smsir without key/template must be rejected")
	}
	if _, err := with(map[string]string{"SMS_PROVIDER": "kavenegar"}); err == nil {
		t.Fatal("the removed provider must be rejected")
	}
	if c, err := with(map[string]string{"BACKUP_MAX_BYTES": "1048576"}); err != nil || c.BackupMaxBytes != 1<<20 {
		t.Fatalf("custom limit: %v %v", c.BackupMaxBytes, err)
	}
	if _, err := with(map[string]string{"BACKUP_MAX_BYTES": "12"}); err == nil {
		t.Fatal("absurd limit must be rejected")
	}
}
