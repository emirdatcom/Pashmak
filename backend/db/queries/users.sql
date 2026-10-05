-- name: CreateUser :one
INSERT INTO users (id, created_at) VALUES ($1, $2) RETURNING *;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: SoftDeleteUser :execrows
UPDATE users SET status = 'deleted', deleted_at = $2, phone_e164 = NULL, phone_verified_at = NULL
WHERE id = $1 AND status = 'active';
