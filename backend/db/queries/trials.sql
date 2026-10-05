-- name: GetTrialByUser :one
SELECT * FROM trials WHERE user_id = $1;

-- name: GetTrialByDeviceHash :one
SELECT * FROM trials WHERE device_hash = $1;

-- name: InsertTrial :exec
INSERT INTO trials (id, user_id, device_hash, started_at, ends_at) VALUES ($1, $2, $3, $4, $5);
