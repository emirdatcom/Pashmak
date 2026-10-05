// Package dbfiles embeds the SQL migrations.
package dbfiles

import "embed"

// Migrations holds the goose migration files.
//
//go:embed migrations/*.sql
var Migrations embed.FS
