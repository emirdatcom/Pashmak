-- name: UpsertProduct :exec
INSERT INTO products (id, market, kind, entitlement, duration_days, coins_amount, market_sku, active)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (id, market) DO UPDATE SET kind = EXCLUDED.kind, entitlement = EXCLUDED.entitlement,
  duration_days = EXCLUDED.duration_days, coins_amount = EXCLUDED.coins_amount,
  market_sku = EXCLUDED.market_sku, active = EXCLUDED.active;

-- name: GetProduct :one
SELECT * FROM products WHERE id = $1 AND market = $2 AND active;

-- name: GetProductAnyState :one
SELECT * FROM products WHERE id = $1 AND market = $2;
