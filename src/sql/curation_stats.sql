-- Curation stats
SET ROLE witstats_owner;

-- Grant these manually from haf_admin
/*
GRANT USAGE ON SCHEMA hivemind_app TO witstats_user;
GRANT SELECT ON hivemind_app.hive_votes TO witstats_user;
GRANT SELECT ON hivemind_app.hive_accounts TO witstats_user;
*/

CREATE OR REPLACE FUNCTION witstats_api.outgoing_votes_summary(voter VARCHAR, last_days INT, direction INT)
RETURNS jsonb AS $function$
BEGIN
  IF (SELECT hive.is_app_in_sync('hivemind_app') IS FALSE) THEN
    RAISE EXCEPTION 'hivemind_app is not in sync';
  END IF;
  IF last_days < 1 OR last_days > 30 THEN
    RAISE EXCEPTION 'last_days must be between 1 and 30';
  ELSIF direction != 1 AND direction != 2 THEN
    RAISE EXCEPTION 'direction must be 1 (upvote) or 2 (downvote)';
  ELSIF voter IS NULL OR LENGTH(voter) = 0 THEN
    RAISE EXCEPTION 'invalid voter';
  END IF;
  RETURN (
    WITH summary AS (
      SELECT aa.name as author, SUM(vote_percent) as vote_weight_agg, COUNT(v.author_id) as vote_count
      FROM hivemind_app.hive_votes v
      JOIN hivemind_app.hive_accounts aa ON
        aa.id = v.author_id
      JOIN hivemind_app.hive_accounts va ON
        va.id = v.voter_id
      WHERE va.name = voter AND v.last_update > NOW()::TIMESTAMP - (last_days * interval '1 day') AND (SELECT CASE WHEN direction = 1 THEN vote_percent > 0 ELSE vote_percent < 0 END)
      GROUP BY aa.name
      ORDER BY vote_count DESC, vote_weight_agg DESC
    )
    SELECT jsonb_agg(jsonb_build_object(
      'author', s.author,
      'weights', s.vote_weight_agg,
      'count', s.vote_count
    ))
    FROM summary s
  );
END $function$
LANGUAGE plpgsql STABLE;