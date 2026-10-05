// Command admin-cli provides operator tooling.
//
//	admin-cli keygen <kid> [dir]            generate an Ed25519 keypair (kid prefix at- or ent-)
//	admin-cli seed-products [products.json] upsert products (needs DATABASE_URL)
package main

import (
	"context"
	"fmt"
	"os"

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
		return fmt.Errorf("usage: admin-cli keygen <kid> [dir] | seed-products [file]")
	}
	switch args[0] {
	case "keygen":
		return keygen(args[1:])
	case "seed-products":
		return seedProducts(args[1:])
	default:
		return fmt.Errorf("unknown command %q", args[0])
	}
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
