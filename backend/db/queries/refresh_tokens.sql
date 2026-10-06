-- name: InsertRefreshToken :exec
INSERT INTO refresh_tokens (id, device_id, token_hash, family_id, expires_at, created_at)
VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetRefreshTokenForUpdate :one
SELECT rt.id, rt.device_id, rt.token_hash, rt.family_id, rt.expires_at, rt.revoked_at, d.user_id
FROM refresh_tokens rt
JOIN devices d ON d.id = rt.device_id
WHERE rt.token_hash = $1
FOR UPDATE OF rt;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked_at = $2 WHERE id = $1 AND revoked_at IS NULL;

-- name: RevokeTokenFamily :exec
UPDATE refresh_tokens SET revoked_at = $2 WHERE family_id = $1 AND revoked_at IS NULL;

-- name: RevokeUserTokens :exec
UPDATE refresh_tokens SET revoked_at = $2
WHERE revoked_at IS NULL AND device_id IN (SELECT id FROM devices WHERE user_id = $1);

-- name: RevokeDeviceTokens :exec
UPDATE refresh_tokens SET revoked_at = $2 WHERE device_id = $1 AND revoked_at IS NULL;
