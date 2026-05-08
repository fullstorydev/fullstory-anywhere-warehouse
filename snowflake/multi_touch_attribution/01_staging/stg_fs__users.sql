-- =============================================================================
-- STAGING: stg_fs__users
-- =============================================================================
-- Maps FullStory device IDs to permanent user IDs.
-- Only includes sessions where the user has been identified (uid is not null).
-- =============================================================================

CREATE OR REPLACE VIEW fs_marketing.staging.stg_fs__users AS

SELECT
    id  AS device_id,
    uid AS user_id
FROM fs_marketing.staging.raw_fs__users
WHERE uid IS NOT NULL;
