-- name: InsertContentPack :one
INSERT INTO content_packs (pack_key, version, locale, payload, raw, sha256, min_app_version, published_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING id, pack_key, version, locale, sha256, min_app_version, published_at;

-- name: ListActivePackMeta :many
SELECT pack_key, version, sha256, length(raw)::int AS size, min_app_version
FROM content_packs
WHERE is_active AND locale = 'fa'
ORDER BY pack_key, version DESC;

-- name: GetPackRaw :one
SELECT raw, sha256 FROM content_packs WHERE pack_key = $1 AND version = $2 AND locale = 'fa' AND is_active;
