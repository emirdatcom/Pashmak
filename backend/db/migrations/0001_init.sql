-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE admin_audit (
    id      bigserial PRIMARY KEY,
    actor   text        NOT NULL,
    action  text        NOT NULL,
    target  text        NOT NULL DEFAULT '',
    payload jsonb       NOT NULL DEFAULT '{}'::jsonb,
    at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_audit_at_idx ON admin_audit (at DESC);

-- +goose Down
DROP TABLE admin_audit;
DROP EXTENSION IF EXISTS pgcrypto;
