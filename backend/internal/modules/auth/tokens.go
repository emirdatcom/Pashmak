package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// TokenSigner signs and verifies access JWTs (platform/signer.Signer satisfies it).
type TokenSigner interface {
	ActiveKid() string
	Sign(payload []byte) (sig, kid string)
	Verify(payload []byte, sig, kid string) error
}

var b64 = base64.RawURLEncoding

type jwtHeader struct {
	Alg string `json:"alg"`
	Typ string `json:"typ"`
	Kid string `json:"kid"`
}

type claims struct {
	Sub string `json:"sub"`
	Did string `json:"did"`
	Iat int64  `json:"iat"`
	Exp int64  `json:"exp"`
}

var errBadToken = errors.New("auth: invalid access token")

// issueAccess builds an EdDSA JWT. The signer's active kid is placed in the header.
func issueAccess(s TokenSigner, userID, deviceID uuid.UUID, now time.Time, ttl time.Duration) (string, time.Time, error) {
	h, err := json.Marshal(jwtHeader{Alg: "EdDSA", Typ: "JWT", Kid: s.ActiveKid()})
	if err != nil {
		return "", time.Time{}, fmt.Errorf("marshal header: %w", err)
	}
	exp := now.Add(ttl)
	c, err := json.Marshal(claims{Sub: userID.String(), Did: deviceID.String(), Iat: now.Unix(), Exp: exp.Unix()})
	if err != nil {
		return "", time.Time{}, fmt.Errorf("marshal claims: %w", err)
	}
	signingInput := b64.EncodeToString(h) + "." + b64.EncodeToString(c)
	sig, _ := s.Sign([]byte(signingInput))
	return signingInput + "." + sig, exp, nil
}

// parseAccess verifies the JWT and returns the principal ids.
func parseAccess(s TokenSigner, token string, now time.Time) (userID, deviceID uuid.UUID, err error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	hb, err := b64.DecodeString(parts[0])
	if err != nil {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	var h jwtHeader
	if json.Unmarshal(hb, &h) != nil || h.Alg != "EdDSA" || h.Kid == "" {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	if s.Verify([]byte(parts[0]+"."+parts[1]), parts[2], h.Kid) != nil {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	cb, err := b64.DecodeString(parts[1])
	if err != nil {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	var c claims
	if json.Unmarshal(cb, &c) != nil || now.Unix() >= c.Exp {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	if userID, err = uuid.Parse(c.Sub); err != nil {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	if deviceID, err = uuid.Parse(c.Did); err != nil {
		return uuid.Nil, uuid.Nil, errBadToken
	}
	return userID, deviceID, nil
}

// newRefreshToken returns 32 random bytes as base64url.
func newRefreshToken() (string, error) {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", fmt.Errorf("random: %w", err)
	}
	return b64.EncodeToString(b[:]), nil
}

func hashToken(t string) string {
	sum := sha256.Sum256([]byte(t))
	return hex.EncodeToString(sum[:])
}
