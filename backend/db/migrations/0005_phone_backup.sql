-- +goose Up
-- Phone numbers are stored encrypted (AES-GCM, DATA_ENC_KEY) with a salted hash for lookup.
ALTER TABLE users DROP COLUMN phone_e164;
ALTER TABLE users ADD COLUMN phone_enc   bytea;
ALTER TABLE users ADD COLUMN phone_hash  text;
ALTER TABLE users ADD COLUMN phone_last4 text;
CREATE UNIQUE INDEX users_phone_hash_key ON users (phone_hash) WHERE phone_hash IS NOT NULL;

CREATE TABLE otp_challenges (
    id          uuid PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users (id),
    phone_hash  text        NOT NULL,
    phone_enc   bytea       NOT NULL,
    code_hash   text        NOT NULL,
    attempts    integer     NOT NULL DEFAULT 0,
    expires_at  timestamptz NOT NULL,
    consumed_at timestamptz,
    created_at  timestamptz NOT NULL
);
CREATE INDEX otp_challenges_phone_idx ON otp_challenges (phone_hash, created_at DESC);

-- The server stores the blob without being able to read it (client-side encryption, docs/30 §10).
CREATE TABLE backups (
    user_id        uuid PRIMARY KEY REFERENCES users (id),
    storage        text        NOT NULL CHECK (storage IN ('db', 's3')),
    blob_ref       text        NOT NULL DEFAULT '',
    blob           bytea,
    size_bytes     integer     NOT NULL,
    schema_version integer     NOT NULL,
    sha256         text        NOT NULL,
    kdf_params     jsonb       NOT NULL,
    updated_at     timestamptz NOT NULL
);

-- +goose Down
DROP TABLE backups;
DROP TABLE otp_challenges;
DROP INDEX users_phone_hash_key;
ALTER TABLE users DROP COLUMN phone_last4;
ALTER TABLE users DROP COLUMN phone_hash;
ALTER TABLE users DROP COLUMN phone_enc;
ALTER TABLE users ADD COLUMN phone_e164 text UNIQUE;
