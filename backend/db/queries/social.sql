-- name: GetSocialProfile :one
SELECT * FROM social_profiles WHERE user_id = $1;

-- name: GetSocialProfileByCode :one
SELECT sp.* FROM social_profiles sp JOIN users u ON u.id = sp.user_id
WHERE sp.friend_code = $1 AND u.status = 'active';

-- name: InsertSocialProfile :exec
INSERT INTO social_profiles (user_id, friend_code, updated_at) VALUES ($1, $2, $3);

-- name: UpdateSocialProfile :exec
UPDATE social_profiles SET nickname = $2, cat_name = $3, cat_fur = $4, cat_stage = $5, cat_hue = $6, updated_at = $7
WHERE user_id = $1;

-- name: InsertFriendship :exec
INSERT INTO friendships (user_a, user_b, created_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING;

-- name: DeleteFriendship :exec
DELETE FROM friendships WHERE user_a = $1 AND user_b = $2;

-- name: CountFriends :one
SELECT COUNT(*)::int AS n FROM friendships WHERE user_a = $1 OR user_b = $1;

-- name: AreFriends :one
SELECT EXISTS (SELECT 1 FROM friendships WHERE user_a = $1 AND user_b = $2) AS ok;

-- name: ListFriends :many
SELECT sp.user_id, sp.friend_code, sp.nickname, sp.cat_name, sp.cat_fur, sp.cat_stage, sp.cat_hue, f.created_at AS since,
       EXISTS (SELECT 1 FROM vibes v WHERE v.from_user = sqlc.arg(me) AND v.to_user = sp.user_id AND v.day = sqlc.arg(day)::date) AS vibed_today
FROM friendships f
JOIN social_profiles sp ON sp.user_id = CASE WHEN f.user_a = sqlc.arg(me) THEN f.user_b ELSE f.user_a END
JOIN users u ON u.id = sp.user_id AND u.status = 'active'
WHERE f.user_a = sqlc.arg(me) OR f.user_b = sqlc.arg(me)
ORDER BY f.created_at;

-- name: InsertVibe :execrows
INSERT INTO vibes (id, from_user, to_user, kind, day, created_at) VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (from_user, to_user, day) DO NOTHING;

-- name: ListReceivedVibes :many
SELECT v.id, v.kind, v.created_at, v.read_at, sp.friend_code, sp.nickname, sp.cat_name
FROM vibes v JOIN social_profiles sp ON sp.user_id = v.from_user
WHERE v.to_user = $1 AND v.created_at > $2
ORDER BY v.created_at DESC
LIMIT 100;

-- name: MarkVibesRead :exec
UPDATE vibes SET read_at = $2 WHERE to_user = $1 AND read_at IS NULL;

-- name: DeleteUserSocial :exec
WITH f AS (DELETE FROM friendships WHERE user_a = $1 OR user_b = $1),
     v AS (DELETE FROM vibes WHERE from_user = $1 OR to_user = $1)
DELETE FROM social_profiles WHERE user_id = $1;

-- name: ListFriendIDs :many
SELECT CASE WHEN user_a = $1 THEN user_b ELSE user_a END::uuid AS friend FROM friendships WHERE user_a = $1 OR user_b = $1;
