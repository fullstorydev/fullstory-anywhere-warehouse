-- =============================================================================
-- DATA TEST: Revenue Integrity — All Models Sum to the Same Total
-- =============================================================================
-- For every conversion (user_id, converted_at), the sum of attributed_revenue
-- must be equal across the four fractional models (First Touch, Last Touch,
-- Linear, 40-20-40 U-Shaped). This is a mathematical invariant: each of them
-- distributes 100% of the conversion value across the touchpoint path.
--
-- Full Credit is excluded: it gives every distinct channel the full conversion
-- value, so its total is intentionally a multiple of the others.
--
-- Joins model pairs within the same conversion and flags any mismatch.
--
-- PASS: 0 rows returned
-- FAIL: rows show which conversion has mismatched model totals
-- =============================================================================

WITH model_sums AS (
    SELECT
        user_id,
        converted_at,
        attribution_model,
        ROUND(SUM(attributed_revenue), 2) AS model_revenue
    FROM fs_marketing.marts.fct_marketing_attribution
    WHERE attribution_model != 'Full Credit'
    GROUP BY 1, 2, 3
)

SELECT
    a.user_id,
    a.converted_at,
    a.attribution_model AS model_a,
    a.model_revenue     AS revenue_a,
    b.attribution_model AS model_b,
    b.model_revenue     AS revenue_b,
    'Revenue mismatch between models' AS assertion
FROM model_sums a
JOIN model_sums b
    ON  a.user_id          = b.user_id
    AND a.converted_at     = b.converted_at
    AND a.attribution_model < b.attribution_model   -- avoid self-joins and duplicates
-- Tolerance of $0.01 accepted for NUMBER scale differences when fractional
-- shares are summed. Differences > $0.01 indicate a real attribution logic error.
WHERE ABS(a.model_revenue - b.model_revenue) > 0.01
ORDER BY a.user_id, a.converted_at, a.attribution_model;
