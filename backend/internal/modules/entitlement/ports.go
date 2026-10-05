// Package entitlement owns grants, trials and the signed EntitlementState (docs/60, docs/10 §6.2).
package entitlement

import "context"

// Config are the config keys this module consumes (trial.*, entitlement.*; docs/60 §3).
type Config struct {
	TrialEnabled        bool
	TrialDays           int
	GraceDays           int
	OfflineValidityDays int
}

// ConfigReader provides Config; the remoteconfig module implements it once available (prompt 04).
type ConfigReader interface {
	Entitlement(ctx context.Context) Config
}

// StaticConfig returns the docs/60 §3 defaults.
type StaticConfig struct{}

// Entitlement implements ConfigReader.
func (StaticConfig) Entitlement(context.Context) Config {
	return Config{TrialEnabled: true, TrialDays: 7, GraceDays: 3, OfflineValidityDays: 7}
}

// Signer signs EntitlementState (platform/signer.Signer loaded with prefix "ent-").
type Signer interface {
	Sign(payload []byte) (sig, kid string)
	Verify(payload []byte, sig, kid string) error
}
