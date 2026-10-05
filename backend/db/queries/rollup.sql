-- Daily rollups (docs/70 §5). Window bounds are UTC and passed by the caller. The "actor" of an
-- event is its install_id (stable across account deletion), falling back to user_id.

-- name: DeleteDailyMetrics :exec
DELETE FROM daily_metrics WHERE day = sqlc.arg(day)::date;

-- name: RollupActiveUsers :exec
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, sqlc.arg(metric)::text, '{}'::jsonb, COUNT(DISTINCT COALESCE(install_id, user_id))
FROM events
WHERE name = 'app_opened' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz;

-- name: RollupStickiness :exec
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT d.day, 'stickiness', '{}'::jsonb, d.value / m.value
FROM daily_metrics d JOIN daily_metrics m ON m.day = d.day AND m.metric = 'mau' AND m.dims = '{}'::jsonb
WHERE d.day = sqlc.arg(day)::date AND d.metric = 'dau' AND d.dims = '{}'::jsonb AND m.value > 0;

-- name: RollupNewInstalls :exec
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, 'new_installs', '{}'::jsonb, COUNT(DISTINCT COALESCE(install_id, user_id))
FROM events
WHERE name = 'app_installed' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz;

-- name: RollupRetention :exec
WITH cohort AS (
  SELECT DISTINCT COALESCE(install_id, user_id) AS actor FROM events
  WHERE name = 'app_installed' AND received_at >= sqlc.arg(cohort_start)::timestamptz AND received_at < sqlc.arg(cohort_end)::timestamptz
    AND COALESCE(install_id, user_id) IS NOT NULL
), returned AS (
  SELECT DISTINCT COALESCE(install_id, user_id) AS actor FROM events
  WHERE name = 'app_opened' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
), sizes AS (
  SELECT (SELECT COUNT(*) FROM cohort) AS total, (SELECT COUNT(*) FROM cohort c JOIN returned r USING (actor)) AS back
)
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, sqlc.arg(metric)::text,
       jsonb_build_object('cohort_day', sqlc.arg(cohort_day)::text, 'cohort_size', total),
       back::float8 / total
FROM sizes WHERE total > 0;

-- name: RollupTrialStartRate :exec
WITH onb AS (
  SELECT COUNT(DISTINCT COALESCE(install_id, user_id)) AS n FROM events
  WHERE name = 'onboarding_completed' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
), tr AS (
  SELECT COUNT(DISTINCT COALESCE(install_id, user_id)) AS n FROM events
  WHERE name = 'trial_started' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
)
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, 'trial_start_rate', '{}'::jsonb, tr.n::float8 / onb.n FROM onb, tr WHERE onb.n > 0;

-- name: RollupActivation :exec
WITH onb AS (
  SELECT COALESCE(install_id, user_id) AS actor, MIN(received_at) AS t FROM events
  WHERE name = 'onboarding_completed' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
    AND COALESCE(install_id, user_id) IS NOT NULL
  GROUP BY 1
), act AS (
  SELECT DISTINCT o.actor FROM onb o JOIN events e
    ON COALESCE(e.install_id, e.user_id) = o.actor AND e.name = 'habit_completed'
   AND e.received_at >= o.t AND e.received_at < o.t + interval '24 hours'
)
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, 'activation_rate', '{}'::jsonb, (SELECT COUNT(*) FROM act)::float8 / COUNT(*) FROM onb HAVING COUNT(*) > 0;

-- name: RollupPaywall :exec
WITH views AS (
  SELECT session_id, props->>'trigger' AS trigger, COALESCE(props->>'variant', '') AS variant, MIN(received_at) AS t
  FROM events
  WHERE name = 'paywall_viewed' AND session_id <> '' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
  GROUP BY 1, 2, 3
), agg AS (
  SELECT v.trigger, v.variant, COUNT(*) AS views,
         COUNT(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM events p WHERE p.name = 'purchase_completed' AND p.session_id = v.session_id
             AND p.received_at >= v.t AND p.received_at < sqlc.arg(window_end)::timestamptz)) AS conv
  FROM views v GROUP BY 1, 2
), ins_views AS (
  INSERT INTO daily_metrics (day, metric, dims, value)
  SELECT sqlc.arg(day)::date, 'paywall_views', jsonb_build_object('trigger', trigger, 'variant', variant), views FROM agg
  RETURNING 1
)
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, 'paywall_cvr', jsonb_build_object('trigger', trigger, 'variant', variant), conv::float8 / views FROM agg WHERE views > 0;

-- name: RollupCoreLoop :exec
WITH dau AS (
  SELECT DISTINCT COALESCE(install_id, user_id) AS actor FROM events
  WHERE name = 'app_opened' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
), adv AS (
  SELECT DISTINCT COALESCE(install_id, user_id) AS actor FROM events
  WHERE name = 'adventure_started' AND received_at >= sqlc.arg(window_start)::timestamptz AND received_at < sqlc.arg(window_end)::timestamptz
)
INSERT INTO daily_metrics (day, metric, dims, value)
SELECT sqlc.arg(day)::date, 'core_loop_completion', '{}'::jsonb,
       (SELECT COUNT(*) FROM dau JOIN adv USING (actor))::float8 / COUNT(*) FROM dau HAVING COUNT(*) > 0;
