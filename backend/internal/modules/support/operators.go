package support

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db/dbgen"
)

// MinPasswordLen is the shortest accepted operator password.
const MinPasswordLen = 10

// AddOperator creates an operator (role agent|admin). Used by `admin-cli support-operator add`.
func AddOperator(ctx context.Context, pool *db.Pool, clk clock.Clock, username, password, displayName, role string) error {
	if username == "" || displayName == "" {
		return errors.New("username and display name are required")
	}
	if role != "agent" && role != "admin" {
		return errors.New("role must be agent or admin")
	}
	if len(password) < MinPasswordLen {
		return fmt.Errorf("password must have at least %d characters", MinPasswordLen)
	}
	h, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	return dbgen.New(pool).InsertOperator(ctx, dbgen.InsertOperatorParams{ID: uuid.Must(uuid.NewV7()), Username: username,
		PasswordHash: string(h), DisplayName: displayName, Role: role, CreatedAt: clk.Now()})
}

// SetOperatorActive enables or disables an operator and revokes their sessions when disabling.
func SetOperatorActive(ctx context.Context, pool *db.Pool, clk clock.Clock, username string, active bool) error {
	q := dbgen.New(pool)
	n, err := q.SetOperatorActive(ctx, dbgen.SetOperatorActiveParams{Username: username, Active: active})
	if err != nil {
		return err
	}
	if n == 0 {
		return errors.New("no such operator")
	}
	if !active {
		op, err := q.GetOperatorByUsername(ctx, username)
		if err == nil {
			return q.RevokeOperatorSessions(ctx, dbgen.RevokeOperatorSessionsParams{OperatorID: op.ID, RevokedAt: ptr(clk.Now())})
		}
	}
	return nil
}

// ResetOperatorPassword sets a new password and revokes every session of that operator.
func ResetOperatorPassword(ctx context.Context, pool *db.Pool, clk clock.Clock, username, password string) error {
	if len(password) < MinPasswordLen {
		return fmt.Errorf("password must have at least %d characters", MinPasswordLen)
	}
	h, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	q := dbgen.New(pool)
	n, err := q.SetOperatorPassword(ctx, dbgen.SetOperatorPasswordParams{Username: username, PasswordHash: string(h)})
	if err != nil {
		return err
	}
	if n == 0 {
		return errors.New("no such operator")
	}
	op, err := q.GetOperatorByUsername(ctx, username)
	if err != nil {
		return err
	}
	return q.RevokeOperatorSessions(ctx, dbgen.RevokeOperatorSessionsParams{OperatorID: op.ID, RevokedAt: ptr(clk.Now())})
}
