-- Drop all FK constraints
-- ALTER TABLE witstats_app.table_name DROP CONSTRAINT IF EXISTS table_fk_name;

-- Drop all state providers
SELECT hive.app_state_provider_drop_all('witstats_app');

-- Remove context and drop schema
SELECT hive.app_remove_context('witstats_app');
DROP SCHEMA IF EXISTS witstats_app CASCADE;
DROP SCHEMA IF EXISTS witstats_api CASCADE;