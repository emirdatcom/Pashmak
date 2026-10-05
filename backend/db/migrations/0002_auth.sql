-- +goose Up
CREATE TABLE users (
    id                uuid PRIMARY KEY,
    created_at        timestamptz NOT NULL DEFAULT now(),
    status            text        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deleted')),
    phone_e164        text UNIQUE,
    phone_verified_at timestamptz,
    deleted_at        timestamptz
);

CREATE TABLE devices (
    id           uuid PRIMARY KEY,
    user_id      uuid        NOT NULL REFERENCES users (id),
    install_id   uuid        NOT NULL,
    device_hash  text        NOT NULL,
    market       text        NOT NULL CHECK (market IN ('bazaar', 'myket')),
    app_version  text        NOT NULL,
    os_version   text        NOT NULL,
    model        text        NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX devices_install_id_key ON devices (install_id);
CREATE INDEX devices_user_id_idx ON devices (user_id);
CREATE INDEX devices_device_hash_idx ON devices (device_hash);

CREATE TABLE refresh_tokens (
    id         uuid PRIMARY KEY,
    device_id  uuid        NOT NULL REFERENCES devices (id),
    token_hash text        NOT NULL,
    family_id  uuid        NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX refresh_tokens_token_hash_key ON refresh_tokens (token_hash);
CREATE INDEX refresh_tokens_family_id_idx ON refresh_tokens (family_id);
CREATE INDEX refresh_tokens_device_id_idx ON refresh_tokens (device_id);

-- +goose Down
DROP TABLE refresh_tokens;
DROP TABLE devices;
DROP TABLE users;
