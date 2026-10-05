package httpx

import (
	"context"

	"github.com/google/uuid"

	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
)

// Principal is the authenticated caller.
type Principal struct {
	UserID   uuid.UUID
	DeviceID uuid.UUID
}

type principalKey struct{}

// WithPrincipal stores p in ctx and adds user_id to the log fields.
func WithPrincipal(ctx context.Context, p Principal) context.Context {
	f := plog.FieldsFrom(ctx)
	f.UserID = p.UserID.String()
	ctx = plog.WithFields(ctx, f)
	return context.WithValue(ctx, principalKey{}, p)
}

// PrincipalFrom returns the authenticated caller, if any.
func PrincipalFrom(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(principalKey{}).(Principal)
	return p, ok
}
