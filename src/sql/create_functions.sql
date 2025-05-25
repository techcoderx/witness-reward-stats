CREATE OR REPLACE FUNCTION witstats_app.process_range(IN _first_block INT, IN _last_block INT)
RETURNS void
AS $function$
BEGIN
  INSERT INTO witstats_app.daily_stats (producer_id, date, reward_vests, reward_hive, block_count)
  SELECT
    b.producer_account_id,  -- Maps to producer_id in the table
    DATE_TRUNC('day', b.created_at),
    SUM((o.body->'value'->'vesting_shares'->>'amount')::NUMERIC),
    ROUND(SUM((o.body->'value'->'vesting_shares'->>'amount')::NUMERIC * b.total_vesting_fund_hive / b.total_vesting_shares), 0),
    COUNT(b.producer_account_id)::INTEGER
  FROM hive.irreversible_blocks_view b
  JOIN hive.irreversible_operations_view o ON o.block_num = b.num AND o.op_type_id = 64
  WHERE b.num BETWEEN _first_block AND _last_block
    AND (b.num > 864000 OR o.body->'value'->'vesting_shares'->>'nai' = '@@000000037')
  GROUP BY b.producer_account_id, DATE_TRUNC('day', b.created_at)
  ON CONFLICT (producer_id, date) DO UPDATE SET
    reward_vests = daily_stats.reward_vests + excluded.reward_vests,
    reward_hive = daily_stats.reward_hive + excluded.reward_hive,
    block_count = daily_stats.block_count + excluded.block_count;
END $function$
LANGUAGE plpgsql VOLATILE;
