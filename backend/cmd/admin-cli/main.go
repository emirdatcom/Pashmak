// Command admin-cli provides operator tooling.
//
//	admin-cli keygen <kid> [dir]            generate an Ed25519 keypair (kid prefix at- or ent-)
//	admin-cli hash-password                 read a password from stdin, print the bcrypt hash for ADMIN_PASSWORD_HASH
//	admin-cli seed-products [products.json] upsert products (needs DATABASE_URL)
//	admin-cli publish-config [-activate] [-min-app-version v] <file>   (needs ADMIN_URL/USER/PASSWORD)
//	admin-cli activate-config <version>
//	admin-cli publish-content <dir>
//	admin-cli experiment put <file>
//	admin-cli support-operator add|disable|enable|reset-password   support chat operators (password on stdin)
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"

	"golang.org/x/crypto/bcrypt"

	"github.com/emirdatcom/pashmak/backend/internal/modules/billing"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: admin-cli keygen|seed-products|publish-config|activate-config|publish-content|experiment (see source header)")
	}
	switch args[0] {
	case "keygen":
		return keygen(args[1:])
	case "support-operator":
		return supportOperator(args[1:])
	case "hash-password":
		return hashPassword()
	case "seed-products":
		return seedProducts(args[1:])
	case "publish-config":
		return publishConfig(args[1:])
	case "activate-config":
		return activateConfig(args[1:])
	case "publish-content":
		return publishContent(args[1:])
	case "experiment":
		if len(args) > 1 && args[1] == "put" {
			return putExperiment(args[2:])
		}
		return fmt.Errorf("usage: admin-cli experiment put <file>")
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func hashPassword() error {
	pw, err := io.ReadAll(io.LimitReader(os.Stdin, 1024))
	if err != nil {
		return fmt.Errorf("read stdin: %w", err)
	}
	h, err := bcrypt.GenerateFromPassword([]byte(strings.TrimRight(string(pw), "\r\n")), 12)
	if err != nil {
		return fmt.Errorf("bcrypt: %w", err)
	}
	fmt.Println(string(h))
	return nil
}

func keygen(args []string) error {
	if len(args) < 1 {
		return fmt.Errorf("usage: admin-cli keygen <kid> [dir]")
	}
	dir := os.Getenv("SIGNING_KEYS_DIR")
	if len(args) > 1 {
		dir = args[1]
	}
	if dir == "" {
		dir = "./keys"
	}
	if err := signer.Generate(dir, args[0]); err != nil {
		return err
	}
	fmt.Printf("generated %s/%s.key (private) and %s.pub (public, embed in APK for ent- keys)\n", dir, args[0], args[0])
	return nil
}

func seedProducts(args []string) error {
	file := "../config-data/products.json"
	if len(args) > 0 {
		file = args[0]
	}
	data, err := os.ReadFile(file) // #nosec G304 G703 -- operator-supplied path
	if err != nil {
		return fmt.Errorf("read %s: %w", file, err)
	}
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return fmt.Errorf("DATABASE_URL is required")
	}
	ctx := context.Background()
	pool, err := db.Open(ctx, url, 2)
	if err != nil {
		return err
	}
	defer pool.Close()
	n, err := billing.SeedProducts(ctx, pool, data)
	if err != nil {
		return err
	}
	fmt.Printf("seeded %d product rows\n", n)
	return nil
}
