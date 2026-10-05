-- name: InsertAdminAudit :exec
INSERT INTO admin_audit (actor, action, target, payload)
VALUES ($1, $2, $3, $4);

-- name: ListAdminAudit :many
SELECT id, actor, action, target, payload, at
FROM admin_audit
ORDER BY at DESC
LIMIT $1;
