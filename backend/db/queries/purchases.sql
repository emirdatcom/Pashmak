-- name: GetPurchaseByToken :one
SELECT * FROM purchases WHERE market = $1 AND purchase_token_hash = $2;

-- name: InsertPurchase :one
INSERT INTO purchases (id, user_id, device_id, market, product_id, market_order_id, purchase_token_hash,
  purchase_token_enc, state, purchased_at, verified_at, expires_at, auto_renewing, raw_response, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
RETURNING *;

-- name: UpdatePurchaseVerification :exec
UPDATE purchases SET state = $2, verified_at = $3, expires_at = $4, auto_renewing = $5, raw_response = $6
WHERE id = $1;

-- name: TransferPurchase :exec
UPDATE purchases SET user_id = $2, device_id = $3 WHERE id = $1;

-- name: ListPurchasesForReverify :many
SELECT p.* FROM purchases p
JOIN products pr ON pr.id = p.product_id AND pr.market = p.market
WHERE pr.kind = 'subscription' AND p.state = 'verified'
  AND (p.expires_at < $1::timestamptz + interval '48 hours' OR p.purchased_at > $1::timestamptz - interval '7 days')
ORDER BY p.created_at
LIMIT $2;

-- name: TransferUserPurchases :exec
UPDATE purchases SET user_id = $2 WHERE user_id = $1;
