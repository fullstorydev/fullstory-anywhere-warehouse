-- =============================================================================
-- DATA TEST: Session Ordering and Timing
-- =============================================================================
-- Validates structural correctness of session_number sequencing and
-- the fundamental constraint that touchpoints always precede conversions.
--
-- Assertions:
--   1. No session_start_time >= converted_at (touchpoint must be before conversion)
--   2. session_number always starts at 1 for each (user_id, converted_at)
--   3. max(session_number) == total_sessions_for_conversion for each path
--   4. session_number never exceeds total_sessions_for_conversion
--
-- Uses 'Linear' to deduplicate rows per session (each session has one row per model).
--
-- PASS: 0 rows returned
-- FAIL: rows describe the violation
-- =============================================================================

WITH linear_only AS (
    -- One row per session per conversion (deduplicated via a single model)
    SELECT *
    FROM fs_marketing.marts.fct_marketing_attribution
    WHERE attribution_model = 'Linear'
),

-- 1. Touchpoints must precede their conversion
assert_no_future_sessions AS (
    SELECT
        user_id,
        session_id,
        session_start_time,
        converted_at,
        'session_start_time >= converted_at' AS assertion
    FROM linear_only
    WHERE session_start_time >= converted_at
),

path_stats AS (
    SELECT
        user_id,
        converted_at,
        conversion_index,
        MIN(session_number)                AS min_session_num,
        MAX(session_number)                AS max_session_num,
        MAX(total_sessions_for_conversion) AS declared_total
    FROM linear_only
    GROUP BY 1, 2, 3
),

-- 2. session_number must start at 1
assert_min_is_one AS (
    SELECT
        user_id,
        CAST(converted_at AS VARCHAR)                                          AS context,
        CONCAT('min(session_number)=', min_session_num::STRING, ', expected 1') AS assertion
    FROM path_stats
    WHERE min_session_num != 1
),

-- 3. max(session_number) must equal total_sessions_for_conversion
assert_max_matches_total AS (
    SELECT
        user_id,
        CAST(converted_at AS VARCHAR)                                     AS context,
        CONCAT('max(session_number)=', max_session_num::STRING,
               ' but total_sessions_for_conversion=', declared_total::STRING) AS assertion
    FROM path_stats
    WHERE max_session_num != declared_total
),

-- 4. No individual session_number can exceed total_sessions_for_conversion
assert_no_overflow AS (
    SELECT
        user_id,
        session_id,
        CONCAT('session_number=', session_number::STRING,
               ' > total_sessions=', total_sessions_for_conversion::STRING) AS assertion
    FROM linear_only
    WHERE session_number > total_sessions_for_conversion
)

SELECT user_id, session_id,             assertion FROM assert_no_future_sessions
UNION ALL
SELECT user_id, context,                assertion FROM assert_min_is_one
UNION ALL
SELECT user_id, context,                assertion FROM assert_max_matches_total
UNION ALL
SELECT user_id, session_id,             assertion FROM assert_no_overflow
ORDER BY assertion, user_id;
