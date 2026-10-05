-- name: InsertOTPChallenge :exec
INSERT INTO otp_challenges (id, user_id, phone_hash, phone_enc, code_hash, expires_at, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7);

-- name: GetOTPForUpdate :one
SELECT * FROM otp_challenges WHERE id = $1 FOR UPDATE;

-- name: BumpOTPAttempts :one
UPDATE otp_challenges SET attempts = attempts + 1 WHERE id = $1 RETURNING attempts;

-- name: ConsumeOTP :exec
UPDATE otp_challenges SET consumed_at = $2 WHERE id = $1 AND consumed_at IS NULL;

-- name: OTPStatsForPhone :one
SELECT COUNT(*) FILTER (WHERE created_at > $2)::int AS sent_in_window,
       COALESCE(MAX(created_at), 'epoch'::timestamptz)::timestamptz AS last_sent
FROM otp_challenges WHERE phone_hash = $1;
