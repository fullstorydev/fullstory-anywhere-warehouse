-- =============================================================================
-- INTERMEDIATE: int_marketing__touchpoints  
-- =============================================================================
-- Builds the marketing touchpoint dimension.
--   • Joins events → source_properties → users (LEFT JOIN — anonymous sessions included)
--   • Identity key: user_id for identified users, device_id fallback for anonymous
--   • Extracts and standardizes UTM params, click IDs, and referrer signals
--   • Implements the attribution waterfall priority (Paid > Organic > Referral > Direct)
--   • Deduplicates to one touchpoint per session (highest-priority signal, earliest time)

CREATE OR REPLACE DYNAMIC TABLE fs_marketing.intermediate.int_marketing__touchpoints
    TARGET_LAG = 'downstream'
    WAREHOUSE  = <% WAREHOUSE %>
    REFRESH_MODE = INCREMENTAL
AS

WITH raw_events AS (
    SELECT
        e.event_id,
        COALESCE(u.user_id, e.device_id)                                               AS user_id,
        e.session_id,
        e.event_time,
        DATE_TRUNC('week', e.event_time)                                                    AS week,
        sp.full_url,
        sp.initial_referrer_full_url,

        -- Standard UTM parameters
        REGEXP_SUBSTR(sp.full_url, '[?&]utm_source=([^&]+)',   1, 1, 'e', 1)               AS utm_source,
        REGEXP_SUBSTR(sp.full_url, '[?&]utm_medium=([^&]+)',   1, 1, 'e', 1)               AS utm_medium,
        REGEXP_SUBSTR(sp.full_url, '[?&]utm_campaign=([^&]+)', 1, 1, 'e', 1)               AS utm_campaign,

        -- Click IDs
        REGEXP_SUBSTR(sp.full_url, '[?&]gclid=([^&]+)',  1, 1, 'e', 1)                    AS gclid,
        REGEXP_SUBSTR(sp.full_url, '[?&]fbclid=([^&]+)', 1, 1, 'e', 1)                    AS fbclid,
        REGEXP_SUBSTR(sp.full_url, '[?&]cmpid=([^&]+)',  1, 1, 'e', 1)                    AS cmpid,

        sp.referrer_host                                                                    AS referrer_domain
    FROM fs_marketing.staging.stg_fs__events              e
    JOIN  fs_marketing.staging.stg_fs__source_properties sp ON e.event_id  = sp.event_id
    LEFT JOIN fs_marketing.staging.stg_fs__users          u  ON e.device_id = u.device_id
    CROSS JOIN fs_marketing.config.attribution_config config 
    WHERE e.event_time >= DATEADD(day, -(config.lookback_days + config.attribution_window_days), CURRENT_TIMESTAMP) 
),

standardized_traffic AS (
    SELECT
        *,
        -- Standardize Medium
        CASE
            WHEN gclid IS NOT NULL OR fbclid IS NOT NULL THEN 'cpc'
            WHEN utm_medium IS NOT NULL                  THEN utm_medium
            WHEN referrer_domain ILIKE '%google.%'
              OR referrer_domain ILIKE '%bing.%'         THEN 'organic'
            WHEN referrer_domain IS NOT NULL
             AND referrer_domain <> ''                   THEN 'referral'
            ELSE 'direct'
        END AS standard_medium,

        -- Standardize Source
        COALESCE(
            CASE WHEN gclid  IS NOT NULL THEN 'google'   END,
            CASE WHEN fbclid IS NOT NULL THEN 'facebook' END,
            utm_source,
            referrer_domain,
            'direct'
        ) AS standard_source,

        -- Standardize Campaign
        COALESCE(utm_campaign, cmpid, 'organic/untracked') AS standard_campaign

    FROM raw_events
)

SELECT
    user_id,
    session_id,
    event_time,
    week,
    standard_source    AS source,
    standard_medium    AS medium,
    standard_campaign  AS campaign
FROM standardized_traffic
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY session_id, user_id
    ORDER BY
        -- Priority: paid click IDs > organic/referral > direct
        CASE
            WHEN standard_medium NOT IN ('direct', 'organic', 'referral') THEN 1
            WHEN standard_medium IN ('organic', 'referral')               THEN 2
            ELSE 3
        END ASC,
        event_time ASC
) = 1;
