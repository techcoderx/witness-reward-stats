DROP TYPE IF EXISTS witstats_app.enum_result CASCADE;
CREATE TYPE witstats_app.enum_result AS (
  producer INTEGER,
  date TIMESTAMP,
  rv NUMERIC,
  rh NUMERIC,
  bc INTEGER
);

CREATE OR REPLACE FUNCTION witstats_app.process_range(IN _first_block INT, IN _last_block INT)
RETURNS void
AS $function$
DECLARE
  _res witstats_app.enum_result;
BEGIN
  FOR _res IN
  (
    SELECT
      b.producer_account_id producer,
      DATE_TRUNC('day', b.created_at) AS date,
      SUM((o.body->'value'->'vesting_shares'->>'amount')::NUMERIC) rv,
      ROUND(SUM((o.body->'value'->'vesting_shares'->>'amount')::NUMERIC * b.total_vesting_fund_hive / b.total_vesting_shares), 0) rh,
      COUNT(b.producer_account_id)::INTEGER bc
    FROM hive.irreversible_blocks_view b
    JOIN hive.irreversible_operations_view o ON
      o.block_num = b.num AND o.op_type_id = 64
    WHERE b.num >= _first_block AND b.num <= _last_block AND (b.num > 864000 OR o.body->'value'->'vesting_shares'->>'nai' = '@@000000037')
    GROUP BY producer, date
  )
  LOOP
    INSERT INTO witstats_app.daily_stats(producer_id, date, reward_vests, reward_hive, block_count) VALUES(_res.producer, _res.date, _res.rv, _res.rh, _res.bc)
    ON CONFLICT(producer_id, date) DO UPDATE SET
      reward_vests = witstats_app.daily_stats.reward_vests + _res.rv,
      reward_hive = witstats_app.daily_stats.reward_hive + _res.rh,
      block_count = witstats_app.daily_stats.block_count + _res.bc;
  END LOOP;
END $function$
LANGUAGE plpgsql VOLATILE;
