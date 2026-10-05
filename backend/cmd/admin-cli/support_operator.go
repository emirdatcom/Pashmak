package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/emirdatcom/pashmak/backend/internal/modules/support"
	"github.com/emirdatcom/pashmak/backend/internal/platform/clock"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
)

// supportOperator implements `admin-cli support-operator add|disable|enable|reset-password` (needs DATABASE_URL).
// The password is read from stdin (never from argv, so it stays out of shell history and process lists).
func supportOperator(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: admin-cli support-operator add -username u -name \"Display\" [-role agent|admin] | disable <u> | enable <u> | reset-password <u>   (password on stdin)")
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
	clk := clock.Real{}
	switch args[0] {
	case "add":
		fs := flag.NewFlagSet("add", flag.ContinueOnError)
		username := fs.String("username", "", "login name")
		name := fs.String("name", "", "display name shown to users")
		role := fs.String("role", "agent", "agent or admin")
		if err := fs.Parse(args[1:]); err != nil {
			return err
		}
		pw, err := readPassword()
		if err != nil {
			return err
		}
		if err := support.AddOperator(ctx, pool, clk, *username, pw, *name, *role); err != nil {
			return err
		}
		fmt.Println("operator created:", *username)
		return nil
	case "disable", "enable":
		if len(args) != 2 {
			return fmt.Errorf("usage: admin-cli support-operator %s <username>", args[0])
		}
		if err := support.SetOperatorActive(ctx, pool, clk, args[1], args[0] == "enable"); err != nil {
			return err
		}
		fmt.Println(args[0]+"d:", args[1])
		return nil
	case "reset-password":
		if len(args) != 2 {
			return fmt.Errorf("usage: admin-cli support-operator reset-password <username>   (new password on stdin)")
		}
		pw, err := readPassword()
		if err != nil {
			return err
		}
		if err := support.ResetOperatorPassword(ctx, pool, clk, args[1], pw); err != nil {
			return err
		}
		fmt.Println("password reset, sessions revoked:", args[1])
		return nil
	}
	return fmt.Errorf("unknown support-operator command %q", args[0])
}

func readPassword() (string, error) {
	b, err := io.ReadAll(io.LimitReader(os.Stdin, 1024))
	if err != nil {
		return "", err
	}
	pw := strings.TrimRight(string(b), "\r\n")
	if pw == "" {
		return "", fmt.Errorf("password must be given on stdin")
	}
	return pw, nil
}
