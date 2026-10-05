// Command admin-cli provides operator tooling. Subcommands: keygen <kid> [dir].
package main

import (
	"fmt"
	"os"

	"github.com/emirdatcom/pashmak/backend/internal/platform/signer"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) < 2 || args[0] != "keygen" {
		return fmt.Errorf("usage: admin-cli keygen <kid> [dir]")
	}
	dir := os.Getenv("SIGNING_KEYS_DIR")
	if len(args) > 2 {
		dir = args[2]
	}
	if dir == "" {
		dir = "./keys"
	}
	if err := signer.Generate(dir, args[1]); err != nil {
		return err
	}
	fmt.Printf("generated %s/%s.key (private) and %s.pub (public, embed in APK)\n", dir, args[1], args[1])
	return nil
}
