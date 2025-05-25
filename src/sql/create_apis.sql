SET ROLE witstats_owner;

DROP SCHEMA IF EXISTS witstats_api CASCADE;
CREATE SCHEMA IF NOT EXISTS witstats_api AUTHORIZATION witstats_owner;
GRANT USAGE ON SCHEMA witstats_api TO witstats_user;
GRANT USAGE ON SCHEMA witstats_app TO witstats_user;
GRANT SELECT ON ALL TABLES IN SCHEMA witstats_api TO witstats_user;
GRANT SELECT ON ALL TABLES IN SCHEMA witstats_app TO witstats_user;

-- GET /
CREATE OR REPLACE FUNCTION witstats_api.home()
RETURNS jsonb
AS
$function$
DECLARE
    _last_processed_block INTEGER;
    _db_version INTEGER;
BEGIN
    SELECT last_processed_block, db_version INTO _last_processed_block, _db_version FROM witstats_app.state;
    RETURN jsonb_build_object(
        'last_processed_block', _last_processed_block,
        'db_version', _db_version
    );
END
$function$
LANGUAGE plpgsql STABLE;

-- The rest of PostgREST API methods goes here