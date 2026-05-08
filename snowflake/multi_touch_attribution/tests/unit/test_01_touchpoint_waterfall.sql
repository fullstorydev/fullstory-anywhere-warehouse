-- =============================================================================
-- UNIT TEST: Touchpoint Channel Classification Waterfall
-- =============================================================================
-- Validates the attribution waterfall priority logic from int_marketing__touchpoints:
--   1. Paid click IDs (gclid/fbclid) → medium='cpc'
--   2. UTM parameters → medium=utm_medium
--   3. Google/Bing referrer (no UTM) → medium='organic'
--   4. Other referrer → medium='referral'
--   5. No signal → medium='direct'
--
-- Also validates source and campaign standardization.
--
-- PASS: 0 rows returned
-- FAIL: rows returned — each row describes a failed assertion (case, field, expected, actual)
-- =============================================================================

WITH

-- ── Mock Inputs ───────────────────────────────────────────────────────────────
-- Simulates the output of the raw_events CTE in int_marketing__touchpoints
-- (after joins + REGEXP_SUBSTR extraction of UTM/click IDs).

mock_events AS (
    SELECT * FROM (VALUES
        --  case_name                    utm_source  utm_medium  utm_campaign  gclid     fbclid  cmpid   referrer_domain  exp_medium   exp_source    exp_campaign
        ('gclid wins over UTM',          'email',    'email',    'promo',      'abc123', NULL,   NULL,   NULL,            'cpc',       'google',     'promo'             ),
        ('fbclid wins over UTM',         'email',    'email',    'promo',      NULL,     'xyz',  NULL,   NULL,            'cpc',       'facebook',   'promo'             ),
        ('gclid wins over referral',     NULL,       NULL,       NULL,         'g1',     NULL,   NULL,   'google.com',    'cpc',       'google',     'organic/untracked' ),
        ('utm medium used',              'nl',       'email',    'spring',     NULL,     NULL,   NULL,   NULL,            'email',     'nl',         'spring'            ),
        ('utm campaign, cmpid fallback', 'nl',       'email',    NULL,         NULL,     NULL,   'c123', NULL,            'email',     'nl',         'c123'              ),
        ('google referrer organic',      NULL,       NULL,       NULL,         NULL,     NULL,   NULL,   'google.com',    'organic',   'google.com', 'organic/untracked' ),
        ('bing referrer organic',        NULL,       NULL,       NULL,         NULL,     NULL,   NULL,   'bing.com',      'organic',   'bing.com',   'organic/untracked' ),
        ('other referrer referral',      NULL,       NULL,       NULL,         NULL,     NULL,   NULL,   'partner.io',    'referral',  'partner.io', 'organic/untracked' ),
        ('no signal direct',             NULL,       NULL,       NULL,         NULL,     NULL,   NULL,   NULL,            'direct',    'direct',     'organic/untracked' ),
        ('empty referrer is direct',     NULL,       NULL,       NULL,         NULL,     NULL,   NULL,   '',              'direct',    'direct',     'organic/untracked' )
    ) AS t(
        case_name, utm_source, utm_medium, utm_campaign, gclid, fbclid, cmpid, referrer_domain,
        exp_medium, exp_source, exp_campaign
    )
),

-- ── Apply Production Logic ────────────────────────────────────────────────────
-- Exact copy of the CASE/COALESCE logic from int_marketing__touchpoints

classified AS (
    SELECT
        case_name,
        exp_medium,
        exp_source,
        exp_campaign,

        CASE
            WHEN gclid IS NOT NULL OR fbclid IS NOT NULL THEN 'cpc'
            WHEN utm_medium IS NOT NULL                  THEN utm_medium
            WHEN referrer_domain ILIKE '%google.%'
              OR referrer_domain ILIKE '%bing.%'         THEN 'organic'
            WHEN referrer_domain IS NOT NULL
             AND referrer_domain <> ''                   THEN 'referral'
            ELSE 'direct'
        END AS actual_medium,

        COALESCE(
            CASE WHEN gclid  IS NOT NULL THEN 'google'   END,
            CASE WHEN fbclid IS NOT NULL THEN 'facebook' END,
            utm_source,
            referrer_domain,
            'direct'
        ) AS actual_source,

        COALESCE(utm_campaign, cmpid, 'organic/untracked') AS actual_campaign

    FROM mock_events
)

-- ── Assertions — return rows only on failure ──────────────────────────────────

SELECT case_name, 'medium'   AS field, exp_medium   AS expected, actual_medium   AS actual FROM classified WHERE actual_medium   != exp_medium
UNION ALL
SELECT case_name, 'source'   AS field, exp_source   AS expected, actual_source   AS actual FROM classified WHERE actual_source   != exp_source
UNION ALL
SELECT case_name, 'campaign' AS field, exp_campaign AS expected, actual_campaign AS actual FROM classified WHERE actual_campaign != exp_campaign

ORDER BY case_name, field;
