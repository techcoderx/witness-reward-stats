SET ROLE witstats_owner;

DROP SCHEMA IF EXISTS witstats_api CASCADE;
CREATE SCHEMA IF NOT EXISTS witstats_api AUTHORIZATION witstats_owner;
GRANT USAGE ON SCHEMA witstats_api TO witstats_user;
GRANT USAGE ON SCHEMA witstats_app TO witstats_user;
GRANT SELECT ON ALL TABLES IN SCHEMA witstats_api TO witstats_user;
GRANT SELECT ON ALL TABLES IN SCHEMA witstats_app TO witstats_user;

DROP TYPE IF EXISTS witstats_app.sort_direction CASCADE;
CREATE TYPE witstats_app.sort_direction AS ENUM (
  'asc',
  'desc'
);

DROP TYPE IF EXISTS witstats_app.granularity CASCADE;
CREATE TYPE witstats_app.granularity AS ENUM (
  'daily',
  'monthly',
  'yearly'
);

CREATE OR REPLACE FUNCTION witstats_api.witness_reward_stats(producer VARCHAR)
RETURNS jsonb AS $function$
DECLARE
	_producer_id INTEGER;
BEGIN
	SELECT id INTO _producer_id FROM hive.irreversible_accounts_view WHERE name = producer;
  IF _producer_id IS NULL THEN
    RAISE EXCEPTION 'Account % does not exist', producer;
  END IF;
	RETURN jsonb_build_object(
		'total_vests', SUM(reward_vests),
		'total_hive', SUM(reward_hive),
		'total_blocks', SUM(block_count)
	)
	FROM witstats_app.daily_stats
	WHERE producer_id = _producer_id;
END $function$
LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION witstats_api.witness_reward_history(
  producer VARCHAR,
  start_date TIMESTAMP = NULL,
  end_date TIMESTAMP = NULL,
  direction witstats_app.sort_direction = 'asc',
  granularity witstats_app.granularity = 'daily'
)
RETURNS jsonb AS $function$
DECLARE
    _producer_id INTEGER;
    _min_date TIMESTAMP;
    _max_date TIMESTAMP;
    _start TIMESTAMP;
    _end TIMESTAMP;
BEGIN
	SELECT id INTO _producer_id FROM hive.irreversible_accounts_view WHERE name = producer;
  IF _producer_id IS NULL THEN
    RAISE EXCEPTION 'Account % does not exist', producer;
  END IF;

  SELECT MIN(date) INTO _min_date FROM witstats_app.daily_stats WHERE producer_id = _producer_id;
  _start := DATE_TRUNC('day', COALESCE(start_date, _min_date));
  SELECT MAX(date) INTO _max_date FROM witstats_app.daily_stats WHERE producer_id = _producer_id;
  _end := DATE_TRUNC('day', COALESCE(end_date, _max_date));

  IF granularity = 'daily' THEN
    RETURN (
      WITH 
        dates AS (
          SELECT generate_date::date AS date 
          FROM generate_series(
            _start::date, 
            _end::date, 
            '1 day'::interval
          ) AS generate_date
        ),
        history AS (
          SELECT 
            d.date,
            COALESCE(ds.reward_vests, 0) AS reward_vests,
            COALESCE(ds.reward_hive, 0) AS reward_hive,
            COALESCE(ds.block_count, 0) AS block_count
          FROM dates d
          LEFT JOIN witstats_app.daily_stats ds 
            ON ds.date = d.date 
            AND ds.producer_id = _producer_id
          ORDER BY 
            CASE WHEN direction = 'desc' THEN d.date END DESC,
            CASE WHEN direction = 'asc' THEN d.date END ASC
        )
      SELECT jsonb_agg(jsonb_build_object(
        'date', date,
        'vests', reward_vests,
        'hive', reward_hive,
        'count', block_count
      )) FROM history
    );
  ELSE
    RETURN (
      WITH 
        dates AS (
          SELECT generate_date AS period 
          FROM generate_series(
            DATE_TRUNC(
              CASE granularity 
                WHEN 'monthly' THEN 'month'
                WHEN 'yearly' THEN 'year'
              END,
              _start
            ),
            DATE_TRUNC(
              CASE granularity 
                WHEN 'monthly' THEN 'month'
                WHEN 'yearly' THEN 'year'
              END,
              _end
            ),
            (CASE 
              WHEN granularity = 'monthly' THEN '1 month'::interval 
              ELSE '1 year'::interval 
            END)
          ) AS generate_date
        ),
        aggregated_data AS (
          SELECT 
            DATE_TRUNC(
              CASE granularity 
                WHEN 'monthly' THEN 'month'
                WHEN 'yearly' THEN 'year'
              END,
              date
            ) AS period,
            SUM(reward_vests) AS reward_vests,
            SUM(reward_hive) AS reward_hive,
            SUM(block_count) AS block_count
          FROM witstats_app.daily_stats
          WHERE producer_id = _producer_id 
            AND date >= _start 
            AND date <= _end
          GROUP BY period
        ),
        history AS (
          SELECT 
            d.period,
            COALESCE(ad.reward_vests, 0) AS reward_vests,
            COALESCE(ad.reward_hive, 0) AS reward_hive,
            COALESCE(ad.block_count, 0) AS block_count
          FROM dates d
          LEFT JOIN aggregated_data ad 
            ON ad.period = d.period
          ORDER BY 
            CASE WHEN direction = 'desc' THEN d.period END DESC,
            CASE WHEN direction = 'asc' THEN d.period END ASC
        )
      SELECT jsonb_agg(jsonb_build_object(
        'date', period::date,
        'vests', reward_vests,
        'hive', reward_hive,
        'count', block_count
      )) FROM history
    );
  END IF;
END $function$
LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION witstats_api.last_synced_block()
RETURNS INTEGER AS $function$
BEGIN
	RETURN hive.app_get_current_block_num('witstats_app');
END
$function$
LANGUAGE plpgsql STABLE;
