-- name: CreateUser :one
INSERT INTO users (id, created_at) VALUES ($1, $2) RETURNING *;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1;

-- name: SoftDeleteUser :execrows
UPDATE users SET status = 'deleted', deleted_at = $2, phone_enc = NULL, phone_hash = NULL, phone_last4 = NULL, phone_verified_at = NULL
WHERE id = $1 AND status = 'active';

-- name: SetUserPhone :exec
UPDATE users SET phone_enc = $2, phone_hash = $3, phone_last4 = $4, phone_verified_at = $5 WHERE id = $1;

-- name: GetActiveUserByPhoneHash :one
SELECT * FROM users WHERE phone_hash = $1 AND status = 'active';

-- name: MarkUserDeleted :exec
UPDATE users SET status = 'deleted', deleted_at = $2, phone_enc = NULL, phone_hash = NULL, phone_last4 = NULL, phone_verified_at = NULL
WHERE id = $1 AND status = 'active';
