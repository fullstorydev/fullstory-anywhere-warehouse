-- =============================================================================
-- DATA TEST: Model Completeness and Session Uniqueness
-- =============================================================================
-- Validates that the fact table is structurally complete and free of duplicates.
--
-- Assertions:
--   1. Every conversion (user_id + converted_at) has all 5 attribution
--      models — no partial attribution allowed
--   2. No duplicate rows for the same (user_id, session_id, converted_at,
--      attribution_model) combination
--   3. attribution_model only contains the 5 expected values
--
-- PASS: 0 rows returned
-- FAIL: rows describe the incomplete conversion or duplicate
-- =============================================================================

WITH

-- 1. Every conversion must have all 5 attribution models
conversion_model_counts AS (
    SELECT
        user_id,
        converted_at,
        COUNT(DISTINCT attribution_model) AS model_count
    FROM fs_marketing.marts.fct_marketing_attribution
    GROUP BY 1, 2
),

assert_all_five_models AS (
    SELECT
        user_id,
        CAST(converted_at AS VARCHAR) AS context,
        CONCAT('only ', model_count::STRING, ' of 5 attribution models present') AS assertion
    FROM conversion_model_counts
    WHERE model_count != 5
),

-- 2. No duplicate (session + attribution_model) within the same conversion
assert_no_duplicate_sessions AS (
    SELECT
        user_id,
        session_id,
        CONCAT('duplicate row for model=', attribution_model,
               ' converted_at=', CAST(converted_at AS VARCHAR)) AS assertion
    FROM fs_marketing.marts.fct_marketing_attribution
    GROUP BY user_id, session_id, converted_at, attribution_model
    HAVING COUNT(*) > 1
),

-- 3. attribution_model values must be one of the five expected strings
assert_valid_model_names AS (
    SELECT
        user_id,
        session_id,
        CONCAT('unexpected attribution_model value: "', attribution_model, '"') AS assertion
    FROM fs_marketing.marts.fct_marketing_attribution
    WHERE attribution_model NOT IN ('First Touch', 'Last Touch', 'Linear', '40-20-40 U-Shaped', 'Full Credit')
)

SELECT user_id, context,     assertion FROM assert_all_five_models
UNION ALL
SELECT user_id, session_id,  assertion FROM assert_no_duplicate_sessions
UNION ALL
SELECT user_id, session_id,  assertion FROM assert_valid_model_names
ORDER BY assertion, user_id;
