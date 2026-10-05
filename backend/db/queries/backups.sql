-- name: UpsertBackup :exec
INSERT INTO backups (user_id, storage, blob_ref, blob, size_bytes, schema_version, sha256, kdf_params, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
ON CONFLICT (user_id) DO UPDATE SET storage = EXCLUDED.storage, blob_ref = EXCLUDED.blob_ref, blob = EXCLUDED.blob,
  size_bytes = EXCLUDED.size_bytes, schema_version = EXCLUDED.schema_version, sha256 = EXCLUDED.sha256,
  kdf_params = EXCLUDED.kdf_params, updated_at = EXCLUDED.updated_at;

-- name: GetBackup :one
SELECT * FROM backups WHERE user_id = $1;

-- name: DeleteBackup :execrows
DELETE FROM backups WHERE user_id = $1;
