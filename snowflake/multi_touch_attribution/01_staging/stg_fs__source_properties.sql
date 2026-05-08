-- =============================================================================
-- STAGING: stg_fs__source_properties
-- =============================================================================
-- Extracts URL and referrer data linked to each event.
-- Provides the raw inputs for UTM extraction and traffic source classification
-- in the intermediate touchpoints model.
--
-- Column notes:
--   full_url               — the complete URL visited during the event
--   url_query              — the raw query string (e.g. ?utm_source=google&...)
--   url_path               — path component of the URL
--   referrer_host          — domain portion of the referring URL
--   initial_referrer_full_url — full URL of the session's first referrer;
--                              used in the intermediate layer for organic/referral
--                              source classification. Sourced from the
--                              'initial_referrer_full_url' column in FullStory's
--                              source_properties table.
--
-- =============================================================================

CREATE OR REPLACE VIEW fs_marketing.staging.stg_fs__source_properties AS


SELECT
    sp.event_id,
    sp.url_full_url              AS full_url,
    sp.url_query,
    sp.url_path,
    sp.initial_referrer_host     AS referrer_host,
    sp.initial_referrer_full_url              
FROM fs_marketing.staging.raw_fs__source_properties sp
