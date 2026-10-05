-- name: GetActiveConfig :one
SELECT * FROM config_versions WHERE is_active;

-- name: GetConfigVersion :one
SELECT * FROM config_versions WHERE version = $1;

-- name: InsertConfigVersion :one
INSERT INTO config_versions (version, payload, min_app_version, published_by, published_at)
VALUES ((SELECT COALESCE(MAX(version), 0) + 1 FROM config_versions), $1, $2, $3, $4)
RETURNING *;

-- name: DeactivateConfigs :exec
UPDATE config_versions SET is_active = false WHERE is_active;

-- name: ActivateConfig :execrows
UPDATE config_versions SET is_active = true WHERE version = $1;

-- name: ListRunningExperiments :many
SELECT * FROM experiments WHERE status = 'running' ORDER BY key;

-- name: GetExperiment :one
SELECT * FROM experiments WHERE key = $1;

-- name: UpsertExperiment :exec
INSERT INTO experiments (key, status, variants, audience, started_at, stopped_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (key) DO UPDATE SET status = EXCLUDED.status, variants = EXCLUDED.variants,
  audience = EXCLUDED.audience, started_at = EXCLUDED.started_at, stopped_at = EXCLUDED.stopped_at,
  updated_at = EXCLUDED.updated_at;
