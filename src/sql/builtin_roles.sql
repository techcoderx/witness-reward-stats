-- Role involved into data schema creation.
DO $$
BEGIN
  CREATE ROLE witstats_owner WITH LOGIN INHERIT IN ROLE hive_applications_owner_group;
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;

DO $$
BEGIN
  CREATE ROLE witstats_user WITH LOGIN INHERIT IN ROLE hive_applications_group;  
EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
END
$$;

--- Allow to create schemas
GRANT witstats_owner TO haf_admin;
GRANT witstats_user TO witstats_owner;