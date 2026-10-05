package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"

	plog "github.com/emirdatcom/pashmak/backend/internal/platform/log"
)

type errorBody struct {
	Error struct {
		Code      Code   `json:"code"`
		Message   string `json:"message"`
		RequestID string `json:"request_id"`
	} `json:"error"`
}

// WriteJSON writes v as JSON with the given status.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		slog.Error("write json", "err", err)
	}
}

// WriteError writes the standard error body for code.
func WriteError(w http.ResponseWriter, r *http.Request, code Code, msg string) {
	status, ok := Status[code]
	if !ok {
		status, code = http.StatusInternalServerError, CodeInternal
	}
	var b errorBody
	b.Error.Code = code
	b.Error.Message = msg
	b.Error.RequestID = plog.FieldsFrom(r.Context()).RequestID
	WriteJSON(w, status, b)
}

// WriteErr maps any error to the standard body; non-domain errors are logged and hidden.
func WriteErr(w http.ResponseWriter, r *http.Request, err error) {
	code, msg := CodeOf(err)
	if code == CodeInternal {
		slog.ErrorContext(r.Context(), "internal error", "err", err)
	}
	WriteError(w, r, code, msg)
}

// DecodeJSON decodes the body into dst, rejecting unknown fields and trailing data.
func DecodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return NewError(CodePayloadTooLarge, "request body too large")
		}
		return NewError(CodeInvalidInput, "invalid JSON body")
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return NewError(CodeInvalidInput, "unexpected trailing data")
	}
	return nil
}
