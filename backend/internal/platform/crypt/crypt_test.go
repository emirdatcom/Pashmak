package crypt

import (
	"bytes"
	"testing"
)

func TestRoundTripAndKeyed(t *testing.T) {
	b, err := New(bytes.Repeat([]byte{1}, 32))
	if err != nil {
		t.Fatal(err)
	}
	ct, _ := b.Encrypt([]byte("+989121234567"))
	if bytes.Contains(ct, []byte("9121234567")) {
		t.Fatal("ciphertext leaks plaintext")
	}
	pt, err := b.Decrypt(ct)
	if err != nil || string(pt) != "+989121234567" {
		t.Fatalf("%q %v", pt, err)
	}
	ct[len(ct)-1] ^= 1
	if _, err := b.Decrypt(ct); err == nil {
		t.Fatal("tampering must be detected")
	}
	k1, k2 := b.Keyed("phone", "x"), b.Keyed("phone", "x")
	if b.Keyed("phone", "x") == b.Keyed("otp", "x") || k1 != k2 {
		t.Fatal("purpose separation / determinism")
	}
	if _, err := New([]byte("short")); err == nil {
		t.Fatal("short key must fail")
	}
}
