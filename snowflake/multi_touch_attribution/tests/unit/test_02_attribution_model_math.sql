-- =============================================================================
-- UNIT TEST: Attribution Model Revenue Math
-- =============================================================================
-- Validates all four attribution models produce the correct per-session weights
-- across path lengths of 1, 2, 3, and 4 sessions.
--
-- Scenarios (all conversions happen 5 days after first touch):
--   user1: 1 session  → $100  (single-session path)
--   user2: 2 sessions → $200  (two-session path)
--   user3: 3 sessions → $300  (three-session path — classic U-shape)
--   user4: 4 sessions → $400  (four-session path — U-shape middle split)
--
-- Expected weights:
--   ┌────────┬──────────────┬──────────────┬──────────────────────────────────────────────┐
--   │ Model  │ 1 session    │ 2 sessions   │ 3 sessions        │ 4 sessions               │
--   ├────────┼──────────────┼──────────────┼───────────────────┼──────────────────────────┤
--   │ First  │ 100%         │ S1=100%      │ S1=100%           │ S1=100%                  │
--   │ Last   │ 100%         │ S2=100%      │ S3=100%           │ S4=100%                  │
--   │ Linear │ 100%         │ 50%/50%      │ 33.33% each       │ 25% each                 │
--   │ U-Shpd │ 100%         │ 50%/50%      │ 40%/20%/40%       │ 40%/10%/10%/40%          │
--   └────────┴──────────────┴──────────────┴───────────────────┴──────────────────────────┘
--
-- PASS: 0 rows returned
-- FAIL: rows describe which assertion failed and the observed values
-- =============================================================================

WITH

-- ── Mock Inputs ───────────────────────────────────────────────────────────────

mock_touchpoints AS (
    -- user1: 1 session
    SELECT 'user1' AS user_id, 'u1_s1' AS session_id, '2024-01-01 10:00:00'::TIMESTAMP_NTZ AS event_time, 'google'   AS source, 'cpc'      AS medium, 'c1' AS campaign
    UNION ALL
    -- user2: 2 sessions
    SELECT 'user2', 'u2_s1', '2024-01-01 10:00:00'::TIMESTAMP_NTZ, 'google',   'cpc',      'c1'
    UNION ALL
    SELECT 'user2', 'u2_s2', '2024-01-03 10:00:00'::TIMESTAMP_NTZ, 'email',    'email',    'c2'
    UNION ALL
    -- user3: 3 sessions
    SELECT 'user3', 'u3_s1', '2024-01-01 10:00:00'::TIMESTAMP_NTZ, 'google',   'cpc',      'c1'
    UNION ALL
    SELECT 'user3', 'u3_s2', '2024-01-02 10:00:00'::TIMESTAMP_NTZ, 'direct',   'direct',   'organic/untracked'
    UNION ALL
    SELECT 'user3', 'u3_s3', '2024-01-03 10:00:00'::TIMESTAMP_NTZ, 'email',    'email',    'c3'
    UNION ALL
    -- user4: 4 sessions
    SELECT 'user4', 'u4_s1', '2024-01-01 10:00:00'::TIMESTAMP_NTZ, 'google',   'cpc',      'c1'
    UNION ALL
    SELECT 'user4', 'u4_s2', '2024-01-02 10:00:00'::TIMESTAMP_NTZ, 'direct',   'direct',   'organic/untracked'
    UNION ALL
    SELECT 'user4', 'u4_s3', '2024-01-03 10:00:00'::TIMESTAMP_NTZ, 'email',    'email',    'c3'
    UNION ALL
    SELECT 'user4', 'u4_s4', '2024-01-04 10:00:00'::TIMESTAMP_NTZ, 'partner',  'referral', 'organic/untracked'
),

mock_conversions AS (
    SELECT 'user1' AS user_id, '2024-01-06 12:00:00'::TIMESTAMP_NTZ AS converted_at, 100.00 AS conversion_revenue, NULL::TIMESTAMP_NTZ AS previous_conversion_at, 1 AS conversion_index
    UNION ALL
    SELECT 'user2', '2024-01-06 12:00:00'::TIMESTAMP_NTZ, 200.00, NULL, 1
    UNION ALL
    SELECT 'user3', '2024-01-06 12:00:00'::TIMESTAMP_NTZ, 300.00, NULL, 1
    UNION ALL
    SELECT 'user4', '2024-01-06 12:00:00'::TIMESTAMP_NTZ, 400.00, NULL, 1
),

mock_config AS (
    SELECT 14 AS attribution_window_days
),

-- ── Apply Mart Logic (exact copy from fct_marketing_attribution) ──────────────

attributed_sessions AS (
    SELECT
        t.user_id, t.session_id, t.event_time AS session_start_time,
        t.source, t.medium, t.campaign,
        c.converted_at, c.conversion_revenue, c.conversion_index
    FROM mock_config cfg
    CROSS JOIN mock_touchpoints t
    JOIN mock_conversions c
        ON  t.user_id    = c.user_id
        AND t.event_time < c.converted_at
        AND t.event_time >= DATEADD(day, -(cfg.attribution_window_days), c.converted_at)
        AND t.event_time >= COALESCE(
                c.previous_conversion_at,
                DATEADD(day, -(cfg.attribution_window_days), c.converted_at)
            )
),

session_meta AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY user_id, converted_at ORDER BY session_start_time ASC) AS session_number,
        COUNT(session_id)  OVER (PARTITION BY user_id, converted_at)                           AS total_sessions_for_conversion
    FROM attributed_sessions
),

calculated_weights AS (
    SELECT *,
        DIV0(1.0, total_sessions_for_conversion) * conversion_revenue                        AS linear_revenue,
        CASE WHEN session_number = 1                              THEN conversion_revenue ELSE 0.0 END AS first_touch_revenue,
        CASE WHEN session_number = total_sessions_for_conversion  THEN conversion_revenue ELSE 0.0 END AS last_touch_revenue,
        CASE
            WHEN total_sessions_for_conversion = 1 THEN 1.0 * conversion_revenue
            WHEN total_sessions_for_conversion = 2 THEN 0.5 * conversion_revenue
            WHEN session_number = 1 OR session_number = total_sessions_for_conversion THEN 0.4 * conversion_revenue
            ELSE DIV0(0.2, (total_sessions_for_conversion - 2)) * conversion_revenue
        END AS ushaped_revenue
    FROM session_meta
),

-- ── Assertions ────────────────────────────────────────────────────────────────

-- 1. Revenue sum per model per conversion must equal conversion_revenue

revenue_sums AS (
    SELECT user_id, converted_at, conversion_revenue,
        ROUND(SUM(linear_revenue),      2) AS sum_linear,
        ROUND(SUM(first_touch_revenue), 2) AS sum_first,
        ROUND(SUM(last_touch_revenue),  2) AS sum_last,
        ROUND(SUM(ushaped_revenue),     2) AS sum_ushaped
    FROM calculated_weights
    GROUP BY user_id, converted_at, conversion_revenue
),

assert_revenue_sums AS (
    SELECT user_id,
        'revenue_sum_mismatch' AS assertion,
        CONCAT(
            'linear=', sum_linear::STRING,
            ' first=', sum_first::STRING,
            ' last=',  sum_last::STRING,
            ' ushaped=', sum_ushaped::STRING,
            ' expected=', ROUND(conversion_revenue, 2)::STRING
        ) AS detail
    FROM revenue_sums
    WHERE sum_linear   != ROUND(conversion_revenue, 2)
       OR sum_first    != ROUND(conversion_revenue, 2)
       OR sum_last     != ROUND(conversion_revenue, 2)
       OR sum_ushaped  != ROUND(conversion_revenue, 2)
),

-- 2. First touch: only session 1 gets credit

assert_first_touch AS (
    SELECT user_id,
        'first_touch_wrong_session' AS assertion,
        CONCAT('session_id=', session_id, ' session_number=', session_number::STRING,
               ' first_touch_revenue=', first_touch_revenue::STRING) AS detail
    FROM calculated_weights
    WHERE first_touch_revenue > 0 AND session_number != 1
),

-- 3. Last touch: only the last session gets credit

assert_last_touch AS (
    SELECT user_id,
        'last_touch_wrong_session' AS assertion,
        CONCAT('session_id=', session_id, ' session_number=', session_number::STRING,
               ' total=', total_sessions_for_conversion::STRING) AS detail
    FROM calculated_weights
    WHERE last_touch_revenue > 0 AND session_number != total_sessions_for_conversion
),

-- 4. Linear: each session gets approximately 1/N of revenue (within $0.01)
-- DIV0(1.0, N) * revenue and revenue/N can differ by tiny float amounts — only
-- flag if the per-session difference exceeds $0.01 (a real logic error).

assert_linear AS (
    SELECT s.user_id,
        'linear_unequal_split' AS assertion,
        CONCAT('session=', s.session_id,
               ' got=', ROUND(s.linear_revenue, 2)::STRING,
               ' expected~', ROUND(s.conversion_revenue / s.total_sessions_for_conversion, 2)::STRING) AS detail
    FROM calculated_weights s
    WHERE ABS(s.linear_revenue - s.conversion_revenue / s.total_sessions_for_conversion) > 0.01
),

-- 5. U-shaped: user3 (3 sessions, $300) → $120 / $60 / $120

assert_ushaped_3sess AS (
    SELECT user_id,
        'ushaped_3sess_wrong_weight' AS assertion,
        CONCAT('session=', session_id, ' session_number=', session_number::STRING,
               ' got=', ROUND(ushaped_revenue, 2)::STRING) AS detail
    FROM calculated_weights
    WHERE user_id = 'user3'
      AND NOT (
            (session_number = 1 AND ROUND(ushaped_revenue, 2) = 120.00) OR
            (session_number = 2 AND ROUND(ushaped_revenue, 2) = 60.00)  OR
            (session_number = 3 AND ROUND(ushaped_revenue, 2) = 120.00)
          )
),

-- 6. U-shaped: user4 (4 sessions, $400) → $160 / $40 / $40 / $160

assert_ushaped_4sess AS (
    SELECT user_id,
        'ushaped_4sess_wrong_weight' AS assertion,
        CONCAT('session=', session_id, ' session_number=', session_number::STRING,
               ' got=', ROUND(ushaped_revenue, 2)::STRING) AS detail
    FROM calculated_weights
    WHERE user_id = 'user4'
      AND NOT (
            (session_number = 1 AND ROUND(ushaped_revenue, 2) = 160.00) OR
            (session_number = 2 AND ROUND(ushaped_revenue, 2) = 40.00)  OR
            (session_number = 3 AND ROUND(ushaped_revenue, 2) = 40.00)  OR
            (session_number = 4 AND ROUND(ushaped_revenue, 2) = 160.00)
          )
),

-- 7. U-shaped: user2 (2 sessions, $200) → $100 / $100

assert_ushaped_2sess AS (
    SELECT user_id,
        'ushaped_2sess_wrong_weight' AS assertion,
        CONCAT('session=', session_id, ' session_number=', session_number::STRING,
               ' got=', ROUND(ushaped_revenue, 2)::STRING) AS detail
    FROM calculated_weights
    WHERE user_id = 'user2'
      AND NOT (
            (session_number = 1 AND ROUND(ushaped_revenue, 2) = 100.00) OR
            (session_number = 2 AND ROUND(ushaped_revenue, 2) = 100.00)
          )
),

-- 8. U-shaped: user1 (1 session, $100) → $100

assert_ushaped_1sess AS (
    SELECT user_id,
        'ushaped_1sess_wrong_weight' AS assertion,
        CONCAT('session=', session_id, ' got=', ROUND(ushaped_revenue, 2)::STRING) AS detail
    FROM calculated_weights
    WHERE user_id = 'user1' AND ROUND(ushaped_revenue, 2) != 100.00
)

-- ── Return failures ───────────────────────────────────────────────────────────
SELECT user_id, assertion, detail FROM assert_revenue_sums
UNION ALL SELECT user_id, assertion, detail FROM assert_first_touch
UNION ALL SELECT user_id, assertion, detail FROM assert_last_touch
UNION ALL SELECT user_id, assertion, detail FROM assert_linear
UNION ALL SELECT user_id, assertion, detail FROM assert_ushaped_3sess
UNION ALL SELECT user_id, assertion, detail FROM assert_ushaped_4sess
UNION ALL SELECT user_id, assertion, detail FROM assert_ushaped_2sess
UNION ALL SELECT user_id, assertion, detail FROM assert_ushaped_1sess
ORDER BY assertion, user_id;
