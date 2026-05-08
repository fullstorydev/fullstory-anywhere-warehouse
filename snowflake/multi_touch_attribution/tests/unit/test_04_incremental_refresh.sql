USE DATABASE fs_marketing;
CREATE SCHEMA IF NOT EXISTS fs_marketing.tests;

CREATE OR REPLACE TABLE fs_marketing.tests.mock_touchpoints as (
    SELECT 'user1' AS user_id, 'u1_s1' AS session_id, '2024-01-01 10:00:00'::TIMESTAMP_NTZ AS event_time, 'google'   AS source, 'cpc'      AS medium, 'c1' AS campaign
    UNION ALL
    SELECT 'user2', 'u2_s1', '2024-01-01 10:00:00'::TIMESTAMP_NTZ, 'google',   'cpc',      'c1'
    UNION ALL
    SELECT 'user3', 'u3_s1', '2024-01-01 10:00:00'::TIMESTAMP_NTZ, 'google',   'cpc',      'c1'

);

CREATE OR REPLACE TABLE fs_marketing.tests.mock_conversions as (
    SELECT 'user1' AS user_id, '2024-01-06 12:00:00'::TIMESTAMP_NTZ AS converted_at, 100.00 AS conversion_revenue, NULL::TIMESTAMP_NTZ AS previous_conversion_at, 1 AS conversion_index
    UNION ALL
    SELECT 'user2', '2024-01-06 12:00:00'::TIMESTAMP_NTZ, 200.00, NULL, 1
);

CREATE OR REPLACE TABLE fs_marketing.tests.mock_config as (
    SELECT 14 as attribution_window_days
);


CREATE OR REPLACE DYNAMIC TABLE fs_marketing.tests.fct_marketing_attribution
    TARGET_LAG   = '1minutes'         -- leaf node: set explicit lag
    WAREHOUSE    = COMPUTE_WH
    REFRESH_MODE = INCREMENTAL
AS

WITH config AS (
    SELECT attribution_window_days from fs_marketing.tests.mock_config
),

touchpoints AS (
    SELECT * FROM fs_marketing.tests.mock_touchpoints
),

conversions AS (
    SELECT * FROM fs_marketing.tests.mock_conversions
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
        c.conversion_revenue,
        c.conversion_index
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
        conversion_index,
        conversion_revenue,
        -- Arbitrary representative session for the channel; pick the last one
        MAX(session_id)           AS session_id,
        MAX(session_start_time)   AS session_start_time,
        MAX(total_sessions_for_conversion) AS total_sessions_for_conversion,
        MAX(session_number)       AS session_number,
        MAX(is_conversion_session::INT)::BOOLEAN AS is_conversion_session
    FROM calculated_weights
    GROUP BY user_id, source, medium, campaign, converted_at, conversion_index, conversion_revenue
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
    conversion_index,
    source,
    medium,
    campaign,
    total_sessions_for_conversion,
    session_number,
    is_conversion_session,
    attribution_model,
    attributed_revenue
FROM first_touch
UNION ALL SELECT user_id, session_id, session_start_time, converted_at, conversion_index,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM last_touch
UNION ALL SELECT user_id, session_id, session_start_time, converted_at, conversion_index,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM linear
UNION ALL SELECT user_id, session_id, session_start_time, converted_at, conversion_index,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM ushaped
UNION ALL SELECT user_id, session_id, session_start_time, converted_at, conversion_index,
    source, medium, campaign, total_sessions_for_conversion, session_number,
    is_conversion_session, attribution_model, attributed_revenue FROM full_credit;

CALL SYSTEM$WAIT(1, 'MINUTES');

insert into fs_marketing.tests.mock_conversions values ('user3', '2024-01-06 12:00:00'::TIMESTAMP_NTZ, 200.00, NULL, 1);

ALTER DYNAMIC TABLE fs_marketing.tests.fct_marketing_attribution REFRESH;

-- Correctness: user3's conversion must appear in the output
SELECT 'user3' AS user_id, 'FAIL: user3 conversion not linked to touchpoint' AS assertion
FROM (SELECT COUNT(*) AS cnt FROM fs_marketing.tests.fct_marketing_attribution WHERE user_id = 'user3')
WHERE cnt = 0

UNION ALL

-- Empirical: REFRESH_ACTION must be CHANGE (incremental), not REINITIALIZE (full refresh)
SELECT 'user3', 'FAIL: Snowflake fell back to full refresh (REINITIALIZE)'
FROM (
    SELECT REFRESH_ACTION
    FROM TABLE(fs_marketing.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'fs_marketing.TESTS.FCT_MARKETING_ATTRIBUTION', RESULT_LIMIT => 100
    ))
    ORDER BY REFRESH_END_TIME DESC LIMIT 1
)
WHERE REFRESH_ACTION != 'CHANGE'

UNION ALL

-- Empirical: no rows should be deleted (full refresh would delete the existing 10 rows)
SELECT 'user3', 'FAIL: Rows were deleted, indicating full recompute'
FROM (
    SELECT CAST(STATISTICS:numDeletedRows AS INT) AS num_deleted_rows
    FROM TABLE(fs_marketing.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'fs_marketing.TESTS.FCT_MARKETING_ATTRIBUTION', RESULT_LIMIT => 100
    ))
    ORDER BY REFRESH_END_TIME DESC LIMIT 1
)
WHERE num_deleted_rows > 0

UNION ALL

-- Empirical: exactly 5 new rows inserted (1 conversion × 5 attribution models)
SELECT 'user3', 'FAIL: Expected exactly 5 inserted rows'
FROM (
    SELECT CAST(STATISTICS:numInsertedRows AS INT) AS num_inserted_rows
    FROM TABLE(fs_marketing.INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
        NAME => 'fs_marketing.TESTS.FCT_MARKETING_ATTRIBUTION', RESULT_LIMIT => 100
    ))
    ORDER BY REFRESH_END_TIME DESC LIMIT 1
)
WHERE num_inserted_rows != 5;


DROP SCHEMA fs_marketing.tests cascade;