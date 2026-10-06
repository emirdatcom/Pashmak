-- +goose Up
-- Per-account OTP rate limit (auth.RequestOTP) looks challenges up by user and time.
CREATE INDEX otp_challenges_user_idx ON otp_challenges (user_id, created_at DESC);

-- +goose Down
DROP INDEX otp_challenges_user_idx;
