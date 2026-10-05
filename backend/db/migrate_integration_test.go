package dbfiles_test

import (
	"context"
	"database/sql"
	"testing"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	dbfiles "github.com/emirdatcom/pashmak/backend/db"
)

func TestMigrateUpDown(t *testing.T) {
	ctx := context.Background()
	ctr, err := postgres.Run(ctx, "postgres:16-alpine",
		postgres.WithDatabase("t"), postgres.WithUsername("t"), postgres.WithPassword("t"),
		testcontainers.WithWaitStrategy(wait.ForListeningPort("5432/tcp")))
	if err != nil {
		t.Skipf("docker unavailable: %v", err)
	}
	t.Cleanup(func() { _ = ctr.Terminate(ctx) })
	url, err := ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	conn, err := sql.Open("pgx", url)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = conn.Close() }()
	goose.SetBaseFS(dbfiles.Migrations)
	if err := goose.SetDialect("postgres"); err != nil {
		t.Fatal(err)
	}
	if err := goose.UpContext(ctx, conn, "migrations"); err != nil {
		t.Fatal(err)
	}
	var n int
	if err := conn.QueryRowContext(ctx, `select count(*) from admin_audit`).Scan(&n); err != nil {
		t.Fatalf("admin_audit missing: %v", err)
	}
	if err := goose.DownContext(ctx, conn, "migrations"); err != nil {
		t.Fatal(err)
	}
	if err := conn.QueryRowContext(ctx, `select count(*) from admin_audit`).Scan(&n); err == nil {
		t.Fatal("admin_audit should be dropped")
	}
}
