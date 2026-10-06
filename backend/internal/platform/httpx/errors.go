// Package httpx contains the router, middleware and standard error handling.
package httpx

import (
	"errors"
	"net/http"
)

// Code is an API error code (docs/10 §6.3).
type Code string

// API error codes.
const (
	CodeInvalidInput      Code = "INVALID_INPUT"
	CodeUnauthenticated   Code = "UNAUTHENTICATED"
	CodeTokenInvalid      Code = "TOKEN_INVALID"
	CodeTokenReused       Code = "TOKEN_REUSED"
	CodeForbidden         Code = "FORBIDDEN"
	CodeNotFound          Code = "NOT_FOUND"
	CodeTrialAlreadyUsed  Code = "TRIAL_ALREADY_USED"
	CodeTrialDisabled     Code = "TRIAL_DISABLED"
	CodePurchaseClaimed   Code = "PURCHASE_ALREADY_CLAIMED"
	CodePurchaseInvalid   Code = "PURCHASE_INVALID"
	CodePayloadTooLarge   Code = "PAYLOAD_TOO_LARGE"
	CodeBackupTooLarge    Code = "BACKUP_TOO_LARGE"
	CodeRateLimited       Code = "RATE_LIMITED"
	CodeUpgradeRequired   Code = "UPGRADE_REQUIRED"
	CodeMarketUnavailable Code = "MARKET_UNAVAILABLE"
	CodeInternal          Code = "INTERNAL"
	CodePhoneInvalid      Code = "PHONE_INVALID"
	CodeOTPInvalid        Code = "OTP_INVALID"
	CodeOTPExpired        Code = "OTP_EXPIRED"
	CodeSMSUnavailable    Code = "SMS_UNAVAILABLE"
	CodeSupportDisabled   Code = "SUPPORT_DISABLED"
	CodeFriendCodeInvalid Code = "FRIEND_CODE_INVALID"
	CodeFriendLimit       Code = "FRIEND_LIMIT"
	CodeVibeAlreadySent   Code = "VIBE_ALREADY_SENT"
)

// Status maps every API code to its HTTP status.
var Status = map[Code]int{
	CodeInvalidInput:      http.StatusBadRequest,
	CodeUnauthenticated:   http.StatusUnauthorized,
	CodeTokenInvalid:      http.StatusUnauthorized,
	CodeTokenReused:       http.StatusUnauthorized,
	CodeForbidden:         http.StatusForbidden,
	CodeNotFound:          http.StatusNotFound,
	CodeTrialAlreadyUsed:  http.StatusConflict,
	CodeTrialDisabled:     http.StatusConflict,
	CodePurchaseClaimed:   http.StatusConflict,
	CodePurchaseInvalid:   http.StatusUnprocessableEntity,
	CodePayloadTooLarge:   http.StatusRequestEntityTooLarge,
	CodeBackupTooLarge:    http.StatusRequestEntityTooLarge,
	CodeRateLimited:       http.StatusTooManyRequests,
	CodeUpgradeRequired:   http.StatusUpgradeRequired,
	CodeMarketUnavailable: http.StatusServiceUnavailable,
	CodeInternal:          http.StatusInternalServerError,
	CodePhoneInvalid:      http.StatusBadRequest,
	CodeOTPInvalid:        http.StatusBadRequest,
	CodeOTPExpired:        http.StatusBadRequest,
	CodeSMSUnavailable:    http.StatusServiceUnavailable,
	CodeSupportDisabled:   http.StatusServiceUnavailable,
	CodeFriendCodeInvalid: http.StatusNotFound,
	CodeFriendLimit:       http.StatusConflict,
	CodeVibeAlreadySent:   http.StatusConflict,
}

// Error is a domain error carrying an API code. Services return these (or wrap them with %w).
type Error struct {
	Code    Code
	Message string
}

func (e *Error) Error() string { return string(e.Code) + ": " + e.Message }

// NewError builds an Error.
func NewError(code Code, msg string) *Error { return &Error{Code: code, Message: msg} }

// Is lets errors.Is match on the same code.
func (e *Error) Is(target error) bool {
	t, ok := target.(*Error)
	return ok && t.Code == e.Code
}

// CodeOf extracts the API code from err; unknown errors map to INTERNAL.
func CodeOf(err error) (Code, string) {
	var e *Error
	if errors.As(err, &e) {
		return e.Code, e.Message
	}
	return CodeInternal, "internal error"
}
