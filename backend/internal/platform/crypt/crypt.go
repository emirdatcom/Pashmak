// Package crypt provides AES-256-GCM encryption for data at rest and keyed hashing helpers.
package crypt

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
)

// Box encrypts small values with a 32-byte key (DATA_ENC_KEY).
type Box struct {
	gcm cipher.AEAD
	key []byte
}

// New builds a Box. The key must be 32 bytes.
func New(key []byte) (*Box, error) {
	if len(key) != 32 {
		return nil, errors.New("crypt: key must be 32 bytes")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("aes: %w", err)
	}
	g, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("gcm: %w", err)
	}
	return &Box{gcm: g, key: append([]byte(nil), key...)}, nil
}

// Encrypt returns nonce||ciphertext.
func (b *Box) Encrypt(plain []byte) ([]byte, error) {
	nonce := make([]byte, b.gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("nonce: %w", err)
	}
	return b.gcm.Seal(nonce, nonce, plain, nil), nil
}

// Decrypt reverses Encrypt.
func (b *Box) Decrypt(blob []byte) ([]byte, error) {
	if len(blob) < b.gcm.NonceSize() {
		return nil, errors.New("crypt: ciphertext too short")
	}
	out, err := b.gcm.Open(nil, blob[:b.gcm.NonceSize()], blob[b.gcm.NonceSize():], nil)
	if err != nil {
		return nil, fmt.Errorf("decrypt: %w", err)
	}
	return out, nil
}

// Keyed returns hex(HMAC-SHA256(key derived for purpose, data)). Different purposes yield
// independent keys, so a phone-lookup hash can never be confused with an OTP hash.
func (b *Box) Keyed(purpose, data string) string {
	dk := hmac.New(sha256.New, b.key)
	_, _ = dk.Write([]byte("purpose:" + purpose))
	m := hmac.New(sha256.New, dk.Sum(nil))
	_, _ = m.Write([]byte(data))
	return hex.EncodeToString(m.Sum(nil))
}

// Equal compares two hex strings in constant time.
func Equal(a, b string) bool { return hmac.Equal([]byte(a), []byte(b)) }
