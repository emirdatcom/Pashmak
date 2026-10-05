-- +goose Up
CREATE TABLE config_versions (
    id              bigserial PRIMARY KEY,
    version         integer     NOT NULL UNIQUE,
    payload         jsonb       NOT NULL,
    min_app_version text        NOT NULL DEFAULT '',
    published_at    timestamptz NOT NULL DEFAULT now(),
    published_by    text        NOT NULL DEFAULT '',
    is_active       boolean     NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX config_versions_one_active ON config_versions ((true)) WHERE is_active;

CREATE TABLE experiments (
    key        text PRIMARY KEY,
    status     text        NOT NULL CHECK (status IN ('draft', 'running', 'stopped')),
    variants   jsonb       NOT NULL,
    audience   jsonb       NOT NULL DEFAULT '{}'::jsonb,
    started_at timestamptz,
    stopped_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE content_packs (
    id              bigserial PRIMARY KEY,
    pack_key        text        NOT NULL,
    version         integer     NOT NULL CHECK (version > 0),
    locale          text        NOT NULL DEFAULT 'fa',
    payload         jsonb       NOT NULL,
    raw             bytea       NOT NULL, -- exact served bytes; sha256 is computed over them
    sha256          text        NOT NULL,
    min_app_version text        NOT NULL DEFAULT '',
    published_at    timestamptz NOT NULL DEFAULT now(),
    is_active       boolean     NOT NULL DEFAULT true,
    UNIQUE (pack_key, version, locale)
);

-- Events are partitioned monthly on received_at. Dedupe is done through events_dedupe because a
-- unique index on a partitioned table must include the partition key.
CREATE TABLE events (
    id          uuid        NOT NULL,
    user_id     uuid,
    install_id  uuid,
    name        text        NOT NULL,
    props       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    client_ts   timestamptz NOT NULL,
    received_at timestamptz NOT NULL,
    app_version text        NOT NULL DEFAULT '',
    market      text        NOT NULL DEFAULT '',
    session_id  text        NOT NULL DEFAULT '',
    PRIMARY KEY (id, received_at)
) PARTITION BY RANGE (received_at);
CREATE INDEX events_name_received_idx ON events (name, received_at);
CREATE INDEX events_user_idx ON events (user_id) WHERE user_id IS NOT NULL;

CREATE TABLE events_dedupe (
    event_id    uuid PRIMARY KEY,
    received_at timestamptz NOT NULL
);
CREATE INDEX events_dedupe_received_idx ON events_dedupe (received_at);

-- +goose StatementBegin
CREATE FUNCTION ensure_events_partition(month_start date) RETURNS void AS $$
DECLARE
    from_d date := date_trunc('month', month_start)::date;
    to_d   date := (date_trunc('month', month_start) + interval '1 month')::date;
    pname  text := format('events_y%sm%s', to_char(from_d, 'YYYY'), to_char(from_d, 'MM'));
BEGIN
    IF to_regclass(pname) IS NULL THEN
        EXECUTE format('CREATE TABLE %I PARTITION OF events FOR VALUES FROM (%L) TO (%L)',
                       pname, from_d::timestamptz, to_d::timestamptz);
    END IF;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE FUNCTION drop_events_partitions_before(cutoff date) RETURNS integer AS $$
DECLARE
    r       record;
    dropped integer := 0;
    upper_b timestamptz;
BEGIN
    FOR r IN
        SELECT c.relname AS name, pg_get_expr(c.relpartbound, c.oid) AS bound
        FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'events'
    LOOP
        -- bound looks like: FOR VALUES FROM ('2026-10-01 ...') TO ('2026-11-01 ...')
        upper_b := substring(r.bound from 'TO \(''([^'']+)''\)')::timestamptz;
        IF upper_b <= cutoff::timestamptz THEN
            EXECUTE format('DROP TABLE %I', r.name);
            dropped := dropped + 1;
        END IF;
    END LOOP;
    RETURN dropped;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

SELECT ensure_events_partition(now()::date);
SELECT ensure_events_partition((now() + interval '1 month')::date);

CREATE TABLE daily_metrics (
    day    date             NOT NULL,
    metric text             NOT NULL,
    dims   jsonb            NOT NULL DEFAULT '{}'::jsonb,
    value  double precision NOT NULL,
    UNIQUE (day, metric, dims)
);

-- +goose Down
DROP TABLE daily_metrics;
DROP FUNCTION drop_events_partitions_before(date);
DROP FUNCTION ensure_events_partition(date);
DROP TABLE events_dedupe;
DROP TABLE events;
DROP TABLE content_packs;
DROP TABLE experiments;
DROP TABLE config_versions;
