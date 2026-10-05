package billing

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
)

func newGCM(key []byte) (cipher.AEAD, error) {
	if len(key) != 32 {
		return nil, errors.New("billing: encryption key must be 32 bytes")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes: %w", err)
	}
	g, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("gcm: %w", err)
	}
	return g, nil
}

// encrypt returns nonce||ciphertext.
func encrypt(g cipher.AEAD, plain []byte) ([]byte, error) {
	nonce := make([]byte, g.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("nonce: %w", err)
	}
	return g.Seal(nonce, nonce, plain, nil), nil
}

func decrypt(g cipher.AEAD, blob []byte) ([]byte, error) {
	if len(blob) < g.NonceSize() {
		return nil, errors.New("billing: ciphertext too short")
	}
	out, err := g.Open(nil, blob[:g.NonceSize()], blob[g.NonceSize():], nil)
	if err != nil {
		return nil, fmt.Errorf("decrypt: %w", err)
	}
	return out, nil
}

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
