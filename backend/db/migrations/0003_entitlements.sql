-- +goose Up
CREATE TABLE products (
    id            text        NOT NULL,
    market        text        NOT NULL CHECK (market IN ('bazaar', 'myket')),
    kind          text        NOT NULL CHECK (kind IN ('subscription', 'pass', 'consumable')),
    entitlement   text        CHECK (entitlement IN ('premium')),
    duration_days integer     CHECK (duration_days > 0),
    coins_amount  integer     CHECK (coins_amount > 0),
    market_sku    text        NOT NULL,
    active        boolean     NOT NULL DEFAULT true,
    PRIMARY KEY (id, market)
);
CREATE UNIQUE INDEX products_market_sku_key ON products (market, market_sku);

CREATE TABLE purchases (
    id                 uuid PRIMARY KEY,
    user_id            uuid        NOT NULL REFERENCES users (id),
    device_id          uuid        NOT NULL REFERENCES devices (id),
    market             text        NOT NULL CHECK (market IN ('bazaar', 'myket')),
    product_id         text        NOT NULL,
    market_order_id    text        NOT NULL DEFAULT '',
    purchase_token_hash text       NOT NULL,
    purchase_token_enc bytea       NOT NULL,
    state              text        NOT NULL CHECK (state IN ('pending', 'verified', 'invalid', 'refunded', 'expired', 'canceled')),
    purchased_at       timestamptz NOT NULL,
    verified_at        timestamptz,
    expires_at         timestamptz,
    auto_renewing      boolean     NOT NULL DEFAULT false,
    raw_response       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at         timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (product_id, market) REFERENCES products (id, market)
);
CREATE UNIQUE INDEX purchases_market_token_key ON purchases (market, purchase_token_hash);
CREATE INDEX purchases_user_id_idx ON purchases (user_id);
CREATE INDEX purchases_reverify_idx ON purchases (state, expires_at);

CREATE TABLE entitlement_grants (
    id          uuid PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users (id),
    entitlement text        NOT NULL CHECK (entitlement IN ('premium')),
    source      text        NOT NULL CHECK (source IN ('trial', 'subscription', 'pass', 'promo')),
    purchase_id uuid        REFERENCES purchases (id),
    reason      text        NOT NULL DEFAULT '',
    starts_at   timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL,
    revoked_at  timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at)
);
CREATE INDEX entitlement_grants_user_ends_idx ON entitlement_grants (user_id, ends_at);
CREATE INDEX entitlement_grants_purchase_idx ON entitlement_grants (purchase_id);

CREATE TABLE trials (
    id          uuid PRIMARY KEY,
    user_id     uuid        NOT NULL UNIQUE REFERENCES users (id),
    device_hash text        NOT NULL,
    started_at  timestamptz NOT NULL,
    ends_at     timestamptz NOT NULL
);
CREATE UNIQUE INDEX trials_device_hash_key ON trials (device_hash);

-- +goose Down
DROP TABLE trials;
DROP TABLE entitlement_grants;
DROP TABLE purchases;
DROP TABLE products;
