package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/emirdatcom/pashmak/backend/internal/platform/schemas"
)

// client talks to /admin/v1 using ADMIN_URL, ADMIN_USER and ADMIN_PASSWORD.
type client struct {
	base, user, pass string
	http             *http.Client
}

func newClient() (*client, error) {
	c := &client{base: strings.TrimRight(os.Getenv("ADMIN_URL"), "/"), user: os.Getenv("ADMIN_USER"),
		pass: os.Getenv("ADMIN_PASSWORD"), http: &http.Client{Timeout: 30 * time.Second}}
	if c.base == "" || c.user == "" || c.pass == "" {
		return nil, fmt.Errorf("ADMIN_URL, ADMIN_USER and ADMIN_PASSWORD must be set")
	}
	return c, nil
}

func (c *client) do(method, path string, body any) (int, []byte, error) {
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, nil, fmt.Errorf("encode body: %w", err)
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(context.Background(), method, c.base+path, rdr)
	if err != nil {
		return 0, nil, fmt.Errorf("build request: %w", err)
	}
	req.SetBasicAuth(c.user, c.pass)
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.http.Do(req) // #nosec G107 -- operator-supplied URL
	if err != nil {
		return 0, nil, fmt.Errorf("request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return resp.StatusCode, b, nil
}

func (c *client) must(method, path string, body any, okStatus ...int) ([]byte, error) {
	st, b, err := c.do(method, path, body)
	if err != nil {
		return nil, err
	}
	for _, s := range okStatus {
		if st == s {
			return b, nil
		}
	}
	return nil, fmt.Errorf("%s %s: HTTP %d: %s", method, path, st, strings.TrimSpace(string(b)))
}

func configDataDir() string {
	if d := os.Getenv("CONFIG_DATA_DIR"); d != "" {
		return d
	}
	return "../config-data"
}

func publishConfig(args []string) error {
	fs := flag.NewFlagSet("publish-config", flag.ContinueOnError)
	minV := fs.String("min-app-version", "", "minimum app version for this config")
	activate := fs.Bool("activate", false, "activate after publishing")
	if err := fs.Parse(args); err != nil || fs.NArg() != 1 {
		return fmt.Errorf("usage: admin-cli publish-config [-min-app-version v] [-activate] <file>")
	}
	raw, err := os.ReadFile(fs.Arg(0)) // #nosec G304 -- operator-supplied path
	if err != nil {
		return fmt.Errorf("read config: %w", err)
	}
	set, err := schemas.Load(configDataDir())
	if err != nil {
		return err
	}
	if err := set.ValidateConfig(raw); err != nil { // fail locally before sending
		return fmt.Errorf("config is invalid: %w", err)
	}
	c, err := newClient()
	if err != nil {
		return err
	}
	out, err := c.must(http.MethodPost, "/admin/v1/config", map[string]any{
		"payload": json.RawMessage(raw), "min_app_version": *minV, "activate": *activate}, http.StatusCreated)
	if err != nil {
		return err
	}
	fmt.Println(string(out))
	return nil
}

func activateConfig(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: admin-cli activate-config <version>")
	}
	c, err := newClient()
	if err != nil {
		return err
	}
	out, err := c.must(http.MethodPost, "/admin/v1/config/"+args[0]+"/activate", nil, http.StatusOK)
	if err != nil {
		return err
	}
	fmt.Println(string(out))
	return nil
}

func publishContent(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: admin-cli publish-content <dir>")
	}
	set, err := schemas.Load(configDataDir())
	if err != nil {
		return err
	}
	files, err := filepath.Glob(filepath.Join(args[0], "*.json"))
	if err != nil || len(files) == 0 {
		return fmt.Errorf("no pack files found in %s", args[0])
	}
	sort.Strings(files)
	type packFile struct {
		name string
		raw  []byte
	}
	var packs []packFile
	for _, f := range files { // validate everything first so a bad pack does not half-publish
		raw, err := os.ReadFile(f) // #nosec G304
		if err != nil {
			return fmt.Errorf("read %s: %w", f, err)
		}
		var head struct {
			PackKey string `json:"pack_key"`
		}
		if err := json.Unmarshal(raw, &head); err != nil {
			return fmt.Errorf("%s: %w", f, err)
		}
		if err := set.ValidatePack(head.PackKey, raw); err != nil {
			return fmt.Errorf("%s is invalid: %w", f, err)
		}
		packs = append(packs, packFile{f, raw})
	}
	c, err := newClient()
	if err != nil {
		return err
	}
	for _, p := range packs {
		out, err := c.must(http.MethodPost, "/admin/v1/content/packs", json.RawMessage(p.raw), http.StatusCreated)
		if err != nil {
			return fmt.Errorf("%s: %w", p.name, err)
		}
		fmt.Printf("%s -> %s\n", filepath.Base(p.name), strings.TrimSpace(string(out)))
	}
	return nil
}

func putExperiment(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: admin-cli experiment put <file>")
	}
	raw, err := os.ReadFile(args[0]) // #nosec G304
	if err != nil {
		return fmt.Errorf("read experiment: %w", err)
	}
	var e struct {
		Key string `json:"key"`
	}
	if err := json.Unmarshal(raw, &e); err != nil || e.Key == "" {
		return fmt.Errorf("experiment file must be JSON with a \"key\"")
	}
	c, err := newClient()
	if err != nil {
		return err
	}
	if _, err := c.must(http.MethodPut, "/admin/v1/experiments/"+e.Key, json.RawMessage(raw), http.StatusNoContent); err != nil {
		return err
	}
	fmt.Println("experiment", e.Key, "stored")
	return nil
}
