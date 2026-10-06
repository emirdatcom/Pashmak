-- +goose Up
-- Friends (prompt: Finch parity): a public profile per user with a shareable friend code, mutual friendships and
-- "good vibes" (one per friend per day). Only what the user chose to show is stored: a nickname and the cat's look.
CREATE TABLE social_profiles (
    user_id     uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    friend_code text        NOT NULL UNIQUE,
    nickname    text        NOT NULL DEFAULT '',
    cat_name    text        NOT NULL DEFAULT '',
    cat_fur     text        NOT NULL DEFAULT 'orangeCream',
    cat_stage   text        NOT NULL DEFAULT 'kitten',
    cat_hue     integer     NOT NULL DEFAULT 0,
    updated_at  timestamptz NOT NULL
);

CREATE TABLE friendships (
    user_a     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    user_b     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL,
    PRIMARY KEY (user_a, user_b),
    CHECK (user_a < user_b)
);
CREATE INDEX friendships_b_idx ON friendships (user_b);

CREATE TABLE vibes (
    id         uuid PRIMARY KEY,
    from_user  uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    to_user    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind       text        NOT NULL,
    day        date        NOT NULL,
    created_at timestamptz NOT NULL,
    read_at    timestamptz,
    UNIQUE (from_user, to_user, day)
);
CREATE INDEX vibes_to_idx ON vibes (to_user, created_at DESC);

-- +goose Down
DROP TABLE vibes;
DROP TABLE friendships;
DROP TABLE social_profiles;
