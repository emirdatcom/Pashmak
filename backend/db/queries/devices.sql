-- name: GetDeviceByInstallID :one
SELECT * FROM devices WHERE install_id = $1;

-- name: CreateDevice :one
INSERT INTO devices (id, user_id, install_id, device_hash, market, app_version, os_version, model, created_at, last_seen_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $9)
RETURNING *;

-- name: TouchDevice :exec
UPDATE devices SET app_version = $2, os_version = $3, model = $4, market = $5, last_seen_at = $6
WHERE id = $1;

-- name: RebindDevice :exec
UPDATE devices SET user_id = $2 WHERE id = $1;
