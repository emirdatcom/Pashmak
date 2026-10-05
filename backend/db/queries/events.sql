-- name: InsertEvent :batchexec
WITH d AS (
  INSERT INTO events_dedupe (event_id, received_at) VALUES ($1, $9) ON CONFLICT (event_id) DO NOTHING RETURNING 1
)
INSERT INTO events (id, user_id, install_id, name, props, client_ts, received_at, app_version, market, session_id)
SELECT $1, $2, $3, $4, $5, $6, $9, $7, $8, $10 FROM d;

-- name: EnsureEventsPartition :exec
SELECT ensure_events_partition($1::date);

-- name: DropEventPartitionsBefore :one
SELECT drop_events_partitions_before($1::date)::int AS dropped;

-- name: PruneEventsDedupe :execrows
DELETE FROM events_dedupe WHERE received_at < $1;

-- name: AnonymizeUserEvents :exec
UPDATE events SET user_id = NULL WHERE user_id = $1;
