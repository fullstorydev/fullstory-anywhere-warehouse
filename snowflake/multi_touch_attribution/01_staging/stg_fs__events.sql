-- =============================================================================
-- STAGING: stg_fs__events
-- =============================================================================
-- Normalizes the core Fullstory event stream.
-- =============================================================================

CREATE OR REPLACE VIEW fs_marketing.staging.stg_fs__events AS


SELECT
    e.id             AS event_id,
    e.user_id        AS device_id,
    e.session_id,
    e.event_time,
    e.event_type,
    e.processed_time
FROM fs_marketing.staging.raw_fs__events e