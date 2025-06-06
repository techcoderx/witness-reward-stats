-- Daily reward stats
CREATE TABLE IF NOT EXISTS witstats_app.daily_stats(
    producer_id INTEGER,
    date TIMESTAMP,
    reward_vests NUMERIC,
    reward_hive NUMERIC,
    block_count INTEGER,
    PRIMARY KEY(producer_id, date)
);
