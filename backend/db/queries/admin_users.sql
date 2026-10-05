-- name: ListDevicesByUser :many
SELECT id, market, app_version, os_version, model, created_at, last_seen_at
FROM devices WHERE user_id = $1 ORDER BY created_at;

-- name: ListGrantsByUser :many
SELECT * FROM entitlement_grants WHERE user_id = $1 ORDER BY starts_at;

-- name: ListPurchasesByUser :many
SELECT id, market, product_id, state, purchased_at, expires_at, auto_renewing
FROM purchases WHERE user_id = $1 ORDER BY purchased_at;

-- name: ListDailyMetrics :many
SELECT day, metric, dims, value FROM daily_metrics
WHERE day BETWEEN $1 AND $2 AND ($3::text = '' OR metric = $3)
ORDER BY day, metric;
