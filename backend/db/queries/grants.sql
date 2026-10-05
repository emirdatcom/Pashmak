-- name: ListActiveGrants :many
SELECT * FROM entitlement_grants
WHERE user_id = $1 AND revoked_at IS NULL AND $2 < ends_at -- includes queued (future-start) pass grants
ORDER BY starts_at, id;

-- name: LatestGrantEnd :one
SELECT COALESCE(MAX(ends_at), 'epoch'::timestamptz)::timestamptz AS ends_at
FROM entitlement_grants
WHERE user_id = $1 AND entitlement = 'premium' AND revoked_at IS NULL;

-- name: InsertGrant :exec
INSERT INTO entitlement_grants (id, user_id, entitlement, source, purchase_id, reason, starts_at, ends_at, created_at)
VALUES ($1, $2, 'premium', $3, $4, $5, $6, $7, $8);

-- name: GetGrantByPurchase :one
SELECT * FROM entitlement_grants WHERE purchase_id = $1 AND revoked_at IS NULL ORDER BY created_at LIMIT 1;

-- name: UpdateGrantEnd :exec
UPDATE entitlement_grants SET ends_at = $2 WHERE id = $1;

-- name: RevokeGrantsByPurchase :exec
UPDATE entitlement_grants SET revoked_at = $2 WHERE purchase_id = $1 AND revoked_at IS NULL;

-- name: RevokeUserGrants :exec
UPDATE entitlement_grants SET revoked_at = $2 WHERE user_id = $1 AND revoked_at IS NULL;
