-- =============================================================================
-- MART: fct_marketing_attribution  
-- =============================================================================
-- Core attribution fact table. Produces one row per session per attribution model.
-- Supports four rule-based models:
--   • First Touch    — 100% credit to the first session in the path
--   • Last Touch     — 100% credit to the final session before conversion
--   • Linear         — equal credit distributed across all sessions in the path
--   • 40-20-40 U-Shaped — 40% first, 40% last, 20% split across middle sessions
--   • Full Credit - each distinct touch point prior to covnersion gets 100% credit

CREATE OR REPLACE DYNAMIC TABLE fs_marketing.marts.fct_marketing_attribution
    TARGET_LAG   = '3 days'         -- leaf node: set explicit lag
    WAREHOUSE    = <% WAREHOUSE %>
    REFRESH_MODE = INCREMENTAL
AS

WITH config AS (
    SELECT attribution_window_days
    FROM fs_marketing.config.attribution_config
),

touchpoints AS (
    SELECT * FROM fs_marketing.intermediate.int_marketing__touchpoints
),

conversions AS (
    SELECT * FROM fs_marketing.intermediate.int_marketing__conversions
),

-- Link each touchpoint session to its downstream conversion within the lookback window
attributed_sessions AS (
    SELECT
        t.user_id,
        t.session_id,
        t.event_time                AS session_start_time,
        t.source,
        t.medium,
        t.campaign,
        c.converted_at,
        c.conversion_revenue
    FROM config cfg
    CROSS JOIN touchpoints t
    JOIN conversions c
        ON  t.user_id    = c.user_id
        -- Session must occur before the conversion
        AND t.event_time < c.converted_at
        -- Session must be within the lookback window
        AND t.event_time >= DATEADD(day, -(cfg.attribution_window_days), c.converted_at)
        -- Session must be after the user's previous conversion (no double-counting)
        AND t.event_time >= COALESCE(
                c.previous_conversion_at,
                DATEADD(day, -(cfg.attribution_window_days), c.converted_at)
            )
),

-- Count sessions per conversion path and assign sequence numbers
session_meta AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY user_id, converted_at ORDER BY session_start_time ASC) AS session_number,
        COUNT(session_id) OVER (PARTITION BY user_id, converted_at)                            AS total_sessions_for_conversion
    FROM attributed_sessions
),

-- Compute per-model revenue weights
calculated_weights AS (
    SELECT
        *,
        CASE WHEN session_number = total_sessions_for_conversion THEN TRUE ELSE FALSE END AS is_conversion_session,

        -- Linear: even split
        DIV0(1.0, total_sessions_for_conversion) * conversion_revenue                        AS linear_revenue,

        -- First Touch: 100% to session 1
        CASE WHEN session_number = 1                                THEN conversion_revenue ELSE 0.0 END AS first_touch_revenue,

        -- Last Touch: 100% to final session
        CASE WHEN session_number = total_sessions_for_conversion    THEN conversion_revenue ELSE 0.0 END AS last_touch_revenue,

        -- 40-20-40 U-Shaped
        CASE
            WHEN total_sessions_for_conversion = 1 THEN 1.0 * conversion_revenue
            WHEN total_sessions_for_conversion = 2 THEN 0.5 * conversion_revenue
            WHEN session_number = 1
              OR session_number = total_sessions_for_conversion     THEN 0.4 * conversion_revenue
            ELSE DIV0(0.2, (total_sessions_for_conversion - 2))    * conversion_revenue
        END AS ushaped_revenue,

        CASE WHEN TRUE THEN conversion_revenue ELSE 0.0 END AS full_credit_revenue

    FROM session_meta
),

-- Pivot wide → long: one row per session per attribution model
first_touch AS (
    SELECT *, 'First Touch' AS attribution_model, first_touch_revenue AS attributed_revenue
    FROM calculated_weights WHERE first_touch_revenue > 0
),
last_touch AS (
    SELECT *, 'Last Touch'  AS attribution_model, last_touch_revenue  AS attributed_revenue
    FROM calculated_weights WHERE last_touch_revenue  > 0
),
linear AS (
    SELECT *, 'Linear'      AS attribution_model, linear_revenue      AS attributed_revenue
    FROM calculated_weights WHERE linear_revenue      > 0
),
ushaped AS (
    SELECT *, '40-20-40 U-Shaped' AS attribution_model, ushaped_revenue AS attributed_revenue
    FROM calculated_weights WHERE ushaped_revenue     > 0
),

-- Full Credit: deduplicate to one row per unique channel per conversion.
-- Without this, a channel with N sessions before conversion would contribute
-- N * conversion_revenue when aggregated.
full_credit_deduped AS (
    SELECT
        user_id,
        source,
        medium,
        campaign,
        converted_at,
        conversion_revenue,
        MAX(session_id)           AS session_id,
        MAX(session_start_time)   AS session_start_time,
        MAX(total_sessions_for_conversion) AS total_sessions_for_conversion,
        MAX(session_number)       AS session_number,
        MAX(is_conversion_session::INT)::BOOLEAN AS is_conversion_session
    FROM calculated_weights
    GROUP BY user_id, source, medium, campaign, converted_at, conversion_revenue
),

full_credit AS (
    SELECT
        *,
        'Full Credit'      AS attribution_model,
        conversion_revenue AS attributed_revenue
    FROM full_credit_deduped
)

SELECT
    user_id,
    session_id,
    session_start_time,
    converted_at,
    source,
    medium,
    campaign,
    total_sessions_for_conversion,
    session_number,
    is_conversion_session,
    attribution_model,
    attributed_revenue
FROM first_touch
UNION ALL SELECT user_id, session_id, session_start_time, converted_at,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM last_touch
UNION ALL SELECT user_id, session_id, session_start_time, converted_at,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM linear
UNION ALL SELECT user_id, session_id, session_start_time, converted_at,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM ushaped
UNION ALL SELECT user_id, session_id, session_start_time, converted_at,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM full_credit;
