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

-- GET /
CREATE OR REPLACE FUNCTION witstats_api.home()
RETURNS INTEGER AS $function$
BEGIN
	RETURN hive.app_get_current_block_num('witstats_app');
END
$function$
LANGUAGE plpgsql STABLE;

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
  _start TIMESTAMP = DATE_TRUNC('day', COALESCE(start_date, '1970-01-01'::TIMESTAMP));
  _end TIMESTAMP = DATE_TRUNC('day', COALESCE(end_date, NOW()::TIMESTAMP));
BEGIN
	SELECT id INTO _producer_id FROM hive.irreversible_accounts_view WHERE name = producer;
  IF _producer_id IS NULL THEN
    RAISE EXCEPTION 'Account % does not exist', producer;
  END IF;
	IF granularity = 'daily' THEN
    RETURN (
      WITH history AS (
        SELECT date, reward_vests, reward_hive, block_count
        FROM witstats_app.daily_stats
        WHERE producer_id = _producer_id AND date >= _start AND date <= _end
        ORDER BY
          (CASE WHEN direction = 'desc' THEN date ELSE NULL END) DESC,
          (CASE WHEN direction = 'asc' THEN date ELSE NULL END) ASC
      )
      SELECT jsonb_agg(jsonb_build_object(
        'date', date,
        'vests', reward_vests,
        'hive', reward_hive,
        'count', block_count
      ))
      FROM history
    );
  ELSE
    RETURN (
      WITH history AS (
        SELECT DATE_TRUNC((CASE WHEN granularity = 'monthly' THEN 'month' ELSE 'year' END), date) d, SUM(reward_vests) reward_vests, SUM(reward_hive) reward_hive, SUM(block_count) block_count
        FROM witstats_app.daily_stats
        WHERE producer_id = _producer_id AND date >= _start AND date <= _end
        GROUP BY DATE_TRUNC((CASE WHEN granularity = 'monthly' THEN 'month' ELSE 'year' END), date)
        ORDER BY
          (CASE WHEN direction = 'desc' THEN DATE_TRUNC((CASE WHEN granularity = 'monthly' THEN 'month' ELSE 'year' END), date) END) DESC,
          (CASE WHEN direction = 'asc' THEN DATE_TRUNC((CASE WHEN granularity = 'monthly' THEN 'month' ELSE 'year' END), date) END) ASC
      )
      SELECT jsonb_agg(jsonb_build_object(
        'date', d,
        'vests', reward_vests,
        'hive', reward_hive,
        'count', block_count
      ))
      FROM history
    );
  END IF;
END $function$
LANGUAGE plpgsql STABLE;