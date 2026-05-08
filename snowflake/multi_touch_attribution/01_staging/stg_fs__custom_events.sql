-- =============================================================================
-- STAGING: stg_fs__custom_events
-- =============================================================================
-- Extracts custom/conversion events from Fullstory. 
-- This will need to be configured to your specific revenue event and event property payload.
-- =============================================================================

CREATE OR REPLACE VIEW fs_marketing.staging.stg_fs__custom_events AS


SELECT
    e.event_id,
    e.user_id        AS device_id,
    e.session_id,
    e.event_time,
    e.event_name,
    e.event_properties,

    TRY_TO_NUMBER(e.event_properties:price::STRING)                  AS price


FROM fs_marketing.staging.raw_fs__custom_events e

