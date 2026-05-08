-- =============================================================================
-- FULLSTORY CUSTOM PROPERTIES DETECTION SCRIPT
-- =============================================================================
-- 
-- This script introspects your Fullstory property tables (USER_PROPERTIES,
-- PAGE_PROPERTIES, ELEMENT_PROPERTIES) and generates ready-to-paste SQL DDL
-- entries for the DIMENSIONS block of your semantic view.
--
-- USAGE:
--   1. Update the DATABASE and SCHEMA variables below to match your setup
--   2. Run: snow sql -f scripts/detect_custom_properties.sql --connection <name>
--   3. Copy the output and paste into the DIMENSIONS section of create_semantic_view.sql
--
-- =============================================================================

-- Set your Fullstory database and schema
SET fs_database = 'FULLSTORY_READY_TO_ANALYZE';
SET fs_schema = 'FULLSTORY_DEMO_DATA';
-- Pre-compute the full table path so IDENTIFIER() receives a simple variable (not an expression)
SET fs_columns_path = $fs_database || '.INFORMATION_SCHEMA.COLUMNS';

-- =============================================================================
-- USER_PROPERTIES - Custom user attributes
-- =============================================================================
SELECT '-- USER_PROPERTIES custom columns (paste into DIMENSIONS block)' as sql_output
UNION ALL
SELECT ''
UNION ALL
SELECT
    '        USER_PROPERTIES.' || column_name || ' AS ' || LOWER(column_name) || CHR(10) ||
    '            COMMENT = ''Customer-defined user property'',' as sql_output
FROM IDENTIFIER($fs_columns_path)
WHERE table_schema = $fs_schema
  AND table_name = 'USER_PROPERTIES'
  AND column_name NOT IN ('USER_ID', 'LAST_UPDATED_TIME', 'PROCESSED_TIME', 'UPDATED_TIME');

-- =============================================================================
-- PAGE_PROPERTIES - Custom page attributes
-- =============================================================================
SELECT '-- PAGE_PROPERTIES custom columns (paste into DIMENSIONS block)' as sql_output
UNION ALL
SELECT ''
UNION ALL
SELECT
    '        PAGE_PROPERTIES.' || column_name || ' AS ' || LOWER(column_name) || CHR(10) ||
    '            COMMENT = ''Customer-defined page property'',' as sql_output
FROM IDENTIFIER($fs_columns_path)
WHERE table_schema = $fs_schema
  AND table_name = 'PAGE_PROPERTIES'
  AND column_name NOT IN ('EVENT_ID', 'PROCESSED_TIME', 'UPDATED_TIME', 'EVENT_TIME');

-- =============================================================================
-- ELEMENT_PROPERTIES - Custom element attributes
-- =============================================================================
SELECT '-- ELEMENT_PROPERTIES custom columns (paste into DIMENSIONS block)' as sql_output
UNION ALL
SELECT ''
UNION ALL
SELECT
    '        ELEMENT_PROPERTIES.' || column_name || ' AS ' || LOWER(column_name) || CHR(10) ||
    '            COMMENT = ''Customer-defined element property'',' as sql_output
FROM IDENTIFIER($fs_columns_path)
WHERE table_schema = $fs_schema
  AND table_name = 'ELEMENT_PROPERTIES'
  AND column_name NOT IN ('EVENT_ID', 'PROCESSED_TIME', 'UPDATED_TIME', 'EVENT_TIME');
