// Package testutil provides shared test helpers.
package testutil

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"os"
	"testing"

	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib" // database/sql driver for goose
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	dbfiles "github.com/emirdatcom/pashmak/backend/db"
	"github.com/emirdatcom/pashmak/backend/internal/platform/db"
)

// NewDB returns a pool on a freshly migrated database. It uses TEST_DATABASE_URL (admin connection;
// a temporary database is created and dropped) or, failing that, a testcontainers Postgres.
// The test is skipped when neither is available.
func NewDB(t *testing.T) *db.Pool {
	t.Helper()
	ctx := context.Background()
	adminURL := os.Getenv("TEST_DATABASE_URL")
	if adminURL == "" {
		ctr, err := postgres.Run(ctx, "postgres:16-alpine",
			postgres.WithDatabase("t"), postgres.WithUsername("t"), postgres.WithPassword("t"),
			testcontainers.WithWaitStrategy(wait.ForListeningPort("5432/tcp")))
		if err != nil {
			t.Skipf("no Postgres available (set TEST_DATABASE_URL or run Docker): %v", err)
		}
		t.Cleanup(func() { _ = ctr.Terminate(ctx) })
		if adminURL, err = ctr.ConnectionString(ctx, "sslmode=disable"); err != nil {
			t.Fatal(err)
		}
	}
	admin, err := sql.Open("pgx", adminURL)
	if err != nil {
		t.Fatal(err)
	}
	name := "t_" + uuid.NewString()[:8]
	if _, err := admin.ExecContext(ctx, fmt.Sprintf("CREATE DATABASE %s", name)); err != nil {
		t.Fatalf("create database: %v", err)
	}
	u, err := url.Parse(adminURL)
	if err != nil {
		t.Fatal(err)
	}
	u.Path = "/" + name
	testURL := u.String()

	conn, err := sql.Open("pgx", testURL)
	if err != nil {
		t.Fatal(err)
	}
	goose.SetBaseFS(dbfiles.Migrations)
	if err := goose.SetDialect("postgres"); err != nil {
		t.Fatal(err)
	}
	if err := goose.UpContext(ctx, conn, "migrations"); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	_ = conn.Close()

	pool, err := db.Open(ctx, testURL, 5)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		pool.Close()
		_, _ = admin.ExecContext(ctx, fmt.Sprintf("DROP DATABASE IF EXISTS %s WITH (FORCE)", name))
		_ = admin.Close()
	})
	return pool
}
