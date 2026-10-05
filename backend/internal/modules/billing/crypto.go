package billing

import (
	"crypto/sha256"
	"encoding/hex"
)

func hashToken(t string) string {
	sum := sha256.Sum256([]byte(t))
	return hex.EncodeToString(sum[:])
}

// tokenTag is the only form of a purchase token that may appear in logs: last 8 chars of its hash.
func tokenTag(hash string) string {
	if len(hash) <= 8 {
		return hash
	}
	return hash[len(hash)-8:]
}
