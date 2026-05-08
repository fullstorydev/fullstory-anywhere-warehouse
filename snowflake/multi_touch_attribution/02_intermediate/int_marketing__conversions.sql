-- =============================================================================
-- INTERMEDIATE: int_marketing__conversions  
-- =============================================================================
-- Identifies conversion events for identified and anonymous users.
--   • Filters to the configured conversion event name (from attribution_config)
--   • Identity key: user_id for identified users, device_id fallback for anonymous
--   • Adds a window function to track prior conversion time
--     (used in the mart to avoid double-counting across lookback windows)
-- =============================================================================

CREATE OR REPLACE DYNAMIC TABLE fs_marketing.intermediate.int_marketing__conversions
    TARGET_LAG = 'downstream'
    WAREHOUSE  = <% WAREHOUSE %>
    REFRESH_MODE = INCREMENTAL
AS

WITH config AS (
    SELECT lookback_days, conversion_event_name
    FROM fs_marketing.config.attribution_config
)

SELECT
    COALESCE(u.user_id, ce.device_id)                                                        AS user_id,
    ce.session_id                                                                             AS conversion_session_id,
    ce.event_time                                                                             AS converted_at,
    ce.price                                                                                  AS conversion_revenue,
    LAG(ce.event_time) OVER (PARTITION BY COALESCE(u.user_id, ce.device_id) ORDER BY ce.event_time ASC)  AS previous_conversion_at
FROM fs_marketing.staging.stg_fs__custom_events  ce
LEFT JOIN fs_marketing.staging.stg_fs__users      u  ON ce.device_id = u.device_id
CROSS JOIN config
WHERE ce.event_name = config.conversion_event_name
AND ce.event_time >= DATEADD(day, -(config.lookback_days), CURRENT_TIMESTAMP);
