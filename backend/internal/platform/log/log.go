// Package log configures structured logging.
package log

import (
	"context"
	"io"
	"log/slog"
	"strings"
)

type ctxKey struct{}

// Fields are request-scoped values added to every log line.
type Fields struct {
	RequestID string
	UserID    string
}

// WithFields stores f in ctx.
func WithFields(ctx context.Context, f Fields) context.Context {
	return context.WithValue(ctx, ctxKey{}, f)
}

// FieldsFrom returns the fields stored in ctx.
func FieldsFrom(ctx context.Context) Fields {
	f, _ := ctx.Value(ctxKey{}).(Fields)
	return f
}

type ctxHandler struct{ slog.Handler }

func (h ctxHandler) Handle(ctx context.Context, r slog.Record) error {
	f := FieldsFrom(ctx)
	if f.RequestID != "" {
		r.AddAttrs(slog.String("request_id", f.RequestID))
	}
	if f.UserID != "" {
		r.AddAttrs(slog.String("user_id", f.UserID))
	}
	return h.Handler.Handle(ctx, r)
}

func (h ctxHandler) WithAttrs(a []slog.Attr) slog.Handler {
	return ctxHandler{h.Handler.WithAttrs(a)}
}

func (h ctxHandler) WithGroup(n string) slog.Handler { return ctxHandler{h.Handler.WithGroup(n)} }

// New builds a JSON logger at the given level.
func New(w io.Writer, level string) *slog.Logger {
	var l slog.Level
	switch strings.ToLower(level) {
	case "debug":
		l = slog.LevelDebug
	case "warn":
		l = slog.LevelWarn
	case "error":
		l = slog.LevelError
	default:
		l = slog.LevelInfo
	}
	return slog.New(ctxHandler{slog.NewJSONHandler(w, &slog.HandlerOptions{Level: l})})
}
