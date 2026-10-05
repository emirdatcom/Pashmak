-- name: GetOpenConversationByUser :one
SELECT * FROM support_conversations WHERE user_id = $1 AND status <> 'closed';

-- name: GetLatestConversationByUser :one
SELECT * FROM support_conversations WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1;

-- name: GetConversation :one
SELECT * FROM support_conversations WHERE id = $1;

-- name: CreateConversation :one
INSERT INTO support_conversations (id, user_id, status, last_message_at, created_at)
VALUES ($1, $2, 'open', $3, $3) RETURNING *;

-- name: ConversationUserMessage :exec
UPDATE support_conversations SET status = 'open', closed_at = NULL, last_message_at = $2,
  awaiting_since = COALESCE(awaiting_since, $2), operator_unread = operator_unread + 1,
  device_meta = COALESCE(sqlc.narg('device_meta')::jsonb, device_meta)
WHERE id = $1;

-- name: ConversationOperatorMessage :exec
UPDATE support_conversations SET status = 'waiting_user', last_message_at = $2, awaiting_since = NULL,
  user_unread_count = user_unread_count + 1, operator_unread = 0,
  assigned_operator_id = COALESCE(assigned_operator_id, $3)
WHERE id = $1;

-- name: GetConversationForUpdate :one
SELECT * FROM support_conversations WHERE id = $1 FOR UPDATE;

-- name: InsertMessage :one
INSERT INTO support_messages (id, conversation_id, sender, operator_id, client_msg_id, body_enc, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (conversation_id, client_msg_id) WHERE client_msg_id IS NOT NULL DO NOTHING
RETURNING *;

-- name: GetMessageByClientID :one
SELECT * FROM support_messages WHERE conversation_id = $1 AND client_msg_id = $2;

-- name: GetMessage :one
SELECT * FROM support_messages WHERE id = $1;

-- name: ListMessagesAfter :many
SELECT m.*, o.display_name AS operator_display_name
FROM support_messages m LEFT JOIN support_operators o ON o.id = m.operator_id
WHERE m.conversation_id = $1 AND m.id > $2
ORDER BY m.id ASC LIMIT $3;

-- name: ListMessagesBefore :many
SELECT m.*, o.display_name AS operator_display_name
FROM support_messages m LEFT JOIN support_operators o ON o.id = m.operator_id
WHERE m.conversation_id = $1 AND m.id < $2
ORDER BY m.id DESC LIMIT $3;

-- name: ListMessagesLatest :many
SELECT m.*, o.display_name AS operator_display_name
FROM support_messages m LEFT JOIN support_operators o ON o.id = m.operator_id
WHERE m.conversation_id = $1
ORDER BY m.id DESC LIMIT $2;

-- name: MarkOperatorMessagesRead :exec
UPDATE support_messages SET read_at = $3
WHERE conversation_id = $1 AND sender <> 'user' AND read_at IS NULL AND id <= $2;

-- name: SetUserUnread :exec
UPDATE support_conversations SET user_unread_count = (
  SELECT count(*) FROM support_messages WHERE conversation_id = $1 AND sender <> 'user' AND read_at IS NULL)
WHERE id = $1;

-- name: MarkUserMessagesRead :exec
UPDATE support_messages SET read_at = $3
WHERE conversation_id = $1 AND sender = 'user' AND read_at IS NULL AND id <= $2;

-- name: ClearOperatorUnread :exec
UPDATE support_conversations SET operator_unread = 0 WHERE id = $1;

-- name: CloseConversation :exec
UPDATE support_conversations SET status = 'closed', closed_at = $2, awaiting_since = NULL WHERE id = $1;

-- name: AssignConversation :exec
UPDATE support_conversations SET assigned_operator_id = $2 WHERE id = $1;

-- name: DeleteConversationsByUser :exec
DELETE FROM support_conversations WHERE user_id = $1;

-- name: ListQueue :many
SELECT c.*, op.display_name AS operator_display_name
FROM support_conversations c LEFT JOIN support_operators op ON op.id = c.assigned_operator_id
WHERE ($1::text = '' OR c.status = $1)
ORDER BY (c.awaiting_since IS NULL), c.awaiting_since ASC NULLS LAST, c.last_message_at DESC
LIMIT $2;

-- name: OldestAwaitingSince :one
SELECT awaiting_since FROM support_conversations WHERE status <> 'closed' AND awaiting_since IS NOT NULL ORDER BY awaiting_since ASC LIMIT 1;

-- name: CountOpenConversations :one
SELECT count(*) FROM support_conversations WHERE status <> 'closed';

-- name: DeleteClosedConversationsBefore :execrows
DELETE FROM support_conversations WHERE status = 'closed' AND closed_at < $1;

-- name: GetOperatorByUsername :one
SELECT * FROM support_operators WHERE username = $1;

-- name: GetOperator :one
SELECT * FROM support_operators WHERE id = $1;

-- name: InsertOperator :exec
INSERT INTO support_operators (id, username, password_hash, display_name, role, active, created_at)
VALUES ($1, $2, $3, $4, $5, true, $6);

-- name: SetOperatorActive :execrows
UPDATE support_operators SET active = $2 WHERE username = $1;

-- name: SetOperatorPassword :execrows
UPDATE support_operators SET password_hash = $2 WHERE username = $1;

-- name: TouchOperatorLogin :exec
UPDATE support_operators SET last_login_at = $2 WHERE id = $1;

-- name: InsertOperatorSession :exec
INSERT INTO operator_sessions (id, operator_id, token_hash, expires_at, created_at) VALUES ($1, $2, $3, $4, $5);

-- name: GetOperatorSession :one
SELECT s.id AS session_id, s.expires_at, s.revoked_at, o.id AS operator_id, o.username, o.display_name, o.role, o.active
FROM operator_sessions s JOIN support_operators o ON o.id = s.operator_id WHERE s.token_hash = $1;

-- name: RevokeOperatorSession :exec
UPDATE operator_sessions SET revoked_at = $2 WHERE token_hash = $1;

-- name: RevokeOperatorSessions :exec
UPDATE operator_sessions SET revoked_at = $2 WHERE operator_id = $1 AND revoked_at IS NULL;

-- name: ListCanned :many
SELECT * FROM support_canned_replies WHERE active ORDER BY title;

-- name: ListCannedAll :many
SELECT * FROM support_canned_replies ORDER BY title;

-- name: UpsertCanned :exec
INSERT INTO support_canned_replies (id, key, title, body, active) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (key) DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, active = EXCLUDED.active;

-- name: DeleteCanned :exec
DELETE FROM support_canned_replies WHERE key = $1;
