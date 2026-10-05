// Package log is the dev-only SMS adapter: it writes the code to the application log.
// It is refused in prod by config validation.
package log

import (
	"context"
	"log/slog"
)

// Adapter implements auth.SMSSender.
type Adapter struct{}

// SendOTP logs the code (dev only).
func (Adapter) SendOTP(ctx context.Context, phone, code string) error {
	slog.WarnContext(ctx, "DEV SMS (not sent)", "phone", "+98****"+phone[len(phone)-4:], "code", code)
	return nil
}
