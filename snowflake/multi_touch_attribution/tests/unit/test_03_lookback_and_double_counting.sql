-- =============================================================================
-- UNIT TEST: Lookback Window Enforcement + Double-Counting Prevention
-- =============================================================================
-- Validates two key non-equi JOIN conditions in fct_marketing_attribution:
--
-- 1. Lookback Window (attribution_window_days = 14):
--      - Sessions exactly at the 14-day boundary (>=) are INCLUDED
--      - Sessions one second before the boundary are EXCLUDED
--      - Sessions after the conversion are EXCLUDED
--
-- 2. Double-Counting Prevention (previous_conversion_at):
--      - A session that occurred before a user's previous conversion must NOT
--        be attributed to the subsequent conversion
--      - A session between two conversions should count toward the LATER one only
--
-- Scenario:
--   user1 (lookback window test):
--     Conv:  2024-01-21 00:00:00   (14-day boundary = 2024-01-07 00:00:00)
--     u1_s1: 2024-01-06 23:59:59  → OUTSIDE window, must be EXCLUDED
--     u1_s2: 2024-01-07 00:00:00  → AT boundary,    must be INCLUDED
--     u1_s3: 2024-01-10 00:00:00  → inside window,  must be INCLUDED
--     u1_s4: 2024-01-22 00:00:00  → AFTER conv,     must be EXCLUDED
--
--   user2 (double-counting test):
--     Conv1: 2024-01-10 00:00:00  (prev=NULL)
--     Conv2: 2024-01-20 00:00:00  (prev=2024-01-10)
--     u2_s1: 2024-01-08 00:00:00  → counts for conv1; excluded from conv2 (< prev_conv_at)
--     u2_s2: 2024-01-12 00:00:00  → excluded from conv1 (after conv1); counts for conv2
--
-- PASS: 0 rows returned
-- FAIL: rows describe which assertion failed
-- =============================================================================

WITH

-- ── Mock Inputs ───────────────────────────────────────────────────────────────

mock_touchpoints AS (
    SELECT 'user1' AS user_id, 'u1_s1' AS session_id, '2024-01-06 23:59:59'::TIMESTAMP_NTZ AS event_time
    UNION ALL
    SELECT 'user1', 'u1_s2', '2024-01-07 00:00:00'::TIMESTAMP_NTZ
    UNION ALL
    SELECT 'user1', 'u1_s3', '2024-01-10 00:00:00'::TIMESTAMP_NTZ
    UNION ALL
    SELECT 'user1', 'u1_s4', '2024-01-22 00:00:00'::TIMESTAMP_NTZ

    UNION ALL

    SELECT 'user2', 'u2_s1', '2024-01-08 00:00:00'::TIMESTAMP_NTZ
    UNION ALL
    SELECT 'user2', 'u2_s2', '2024-01-12 00:00:00'::TIMESTAMP_NTZ
),

mock_conversions AS (
    SELECT 'user1' AS user_id, '2024-01-21 00:00:00'::TIMESTAMP_NTZ AS converted_at,
           100.00 AS conversion_revenue, NULL::TIMESTAMP_NTZ AS previous_conversion_at, 1 AS conversion_index
    UNION ALL
    SELECT 'user2', '2024-01-10 00:00:00'::TIMESTAMP_NTZ,
           100.00, NULL, 1
    UNION ALL
    SELECT 'user2', '2024-01-20 00:00:00'::TIMESTAMP_NTZ,
           200.00, '2024-01-10 00:00:00'::TIMESTAMP_NTZ, 2
),

mock_config AS (
    SELECT 14 AS attribution_window_days
),

-- ── Apply Mart Join Logic ─────────────────────────────────────────────────────

attributed_sessions AS (
    SELECT
        t.user_id, t.session_id, t.event_time AS session_start_time,
        c.converted_at, c.conversion_index
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

-- ── Assertions ────────────────────────────────────────────────────────────────

-- 1. u1_s1 must be excluded (23:59:59 before window boundary)
assert_outside_window_excluded AS (
    SELECT user_id, session_id,
        'FAIL: session outside 14-day window was included' AS assertion
    FROM attributed_sessions
    WHERE user_id = 'user1' AND session_id = 'u1_s1'
),

-- 2. u1_s2 must be included (exactly at boundary: >= applies)
assert_boundary_included AS (
    SELECT 'user1' AS user_id, 'u1_s2' AS session_id,
        'FAIL: session at 14-day boundary was excluded (should be included)' AS assertion
    FROM (
        SELECT COUNT(*) AS cnt
        FROM attributed_sessions
        WHERE user_id = 'user1' AND session_id = 'u1_s2'
    ) x WHERE cnt = 0
),

-- 3. u1_s3 must be included (inside window)
assert_inside_window_included AS (
    SELECT 'user1' AS user_id, 'u1_s3' AS session_id,
        'FAIL: session inside 14-day window was excluded' AS assertion
    FROM (
        SELECT COUNT(*) AS cnt
        FROM attributed_sessions
        WHERE user_id = 'user1' AND session_id = 'u1_s3'
    ) x WHERE cnt = 0
),

-- 4. u1_s4 must be excluded (after conversion)
assert_future_session_excluded AS (
    SELECT user_id, session_id,
        'FAIL: session after conversion was included' AS assertion
    FROM attributed_sessions
    WHERE user_id = 'user1' AND session_id = 'u1_s4'
),

-- 5. u2_s1 must appear in conv1 (conversion_index=1)
assert_s1_in_conv1 AS (
    SELECT 'user2' AS user_id, 'u2_s1' AS session_id,
        'FAIL: session u2_s1 is missing from conv1' AS assertion
    FROM (
        SELECT COUNT(*) AS cnt
        FROM attributed_sessions
        WHERE user_id = 'user2' AND session_id = 'u2_s1' AND conversion_index = 1
    ) x WHERE cnt = 0
),

-- 6. u2_s1 must NOT appear in conv2 (double-counting prevention)
assert_s1_not_in_conv2 AS (
    SELECT user_id, session_id,
        'FAIL: double-counting — session u2_s1 attributed to conv2 (it is before previous_conversion_at)' AS assertion
    FROM attributed_sessions
    WHERE user_id = 'user2' AND session_id = 'u2_s1' AND conversion_index = 2
),

-- 7. u2_s2 must NOT appear in conv1 (it occurs after conv1)
assert_s2_not_in_conv1 AS (
    SELECT user_id, session_id,
        'FAIL: session u2_s2 attributed to conv1 (it occurs after conv1 converted_at)' AS assertion
    FROM attributed_sessions
    WHERE user_id = 'user2' AND session_id = 'u2_s2' AND conversion_index = 1
),

-- 8. u2_s2 must appear in conv2
assert_s2_in_conv2 AS (
    SELECT 'user2' AS user_id, 'u2_s2' AS session_id,
        'FAIL: session u2_s2 is missing from conv2' AS assertion
    FROM (
        SELECT COUNT(*) AS cnt
        FROM attributed_sessions
        WHERE user_id = 'user2' AND session_id = 'u2_s2' AND conversion_index = 2
    ) x WHERE cnt = 0
)

-- ── Return failures ───────────────────────────────────────────────────────────
SELECT user_id, session_id, assertion FROM assert_outside_window_excluded
UNION ALL SELECT user_id, session_id, assertion FROM assert_boundary_included
UNION ALL SELECT user_id, session_id, assertion FROM assert_inside_window_included
UNION ALL SELECT user_id, session_id, assertion FROM assert_future_session_excluded
UNION ALL SELECT user_id, session_id, assertion FROM assert_s1_in_conv1
UNION ALL SELECT user_id, session_id, assertion FROM assert_s1_not_in_conv2
UNION ALL SELECT user_id, session_id, assertion FROM assert_s2_not_in_conv1
UNION ALL SELECT user_id, session_id, assertion FROM assert_s2_in_conv2
ORDER BY assertion;
