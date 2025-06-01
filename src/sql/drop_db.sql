-- Remove context and drop schema
SELECT hive.app_remove_context('witstats_app');
DROP SCHEMA IF EXISTS witstats_app CASCADE;
DROP SCHEMA IF EXISTS witstats_api CASCADE;