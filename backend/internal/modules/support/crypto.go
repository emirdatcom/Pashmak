package support

import (
	"fmt"

	"github.com/emirdatcom/pashmak/backend/internal/platform/crypt"
)

// seal encrypts a message body. Every write of a body goes through here (and every read through open):
// plaintext never touches the database, the logs or the metrics.
func seal(box *crypt.Box, body string) ([]byte, error) {
	enc, err := box.Encrypt([]byte(body))
	if err != nil {
		return nil, fmt.Errorf("encrypt message: %w", err)
	}
	return enc, nil
}

func open(box *crypt.Box, enc []byte) (string, error) {
	b, err := box.Decrypt(enc)
	if err != nil {
		return "", fmt.Errorf("decrypt message: %w", err)
	}
	return string(b), nil
}
