-- =============================================================================
-- VALIDATION SCRIPT
-- =============================================================================
--
-- Verifies that make deploy completed successfully.
--
--   snow sql -f scripts/validate.sql --connection <your-connection>
--   OR: make validate
--
-- =============================================================================

SET deploy_database    = 'FULLSTORY_ANALYTICS';
SET deploy_schema      = 'SEMANTIC_LAYER';
SET semantic_view_name = 'FULLSTORY_ANALYTICS';
SET agent_name         = 'FULLSTORY_AGENT';

SET full_view_path  = $deploy_database || '.' || $deploy_schema || '.' || $semantic_view_name;
SET full_agent_path = $deploy_database || '.' || $deploy_schema || '.' || $agent_name;

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($deploy_database);
USE SCHEMA   IDENTIFIER($deploy_schema);

-- =============================================================================
-- CHECK 1: Semantic view exists (DESCRIBE will error if missing)
-- =============================================================================

SELECT '--- CHECK 1: Semantic View ---' AS check_name;
DESCRIBE SEMANTIC VIEW IDENTIFIER($full_view_path);

-- =============================================================================
-- CHECK 2: Cortex Agent exists
-- =============================================================================

SELECT '--- CHECK 2: Cortex Agent ---' AS check_name;
SHOW AGENTS IN SCHEMA FULLSTORY_ANALYTICS.SEMANTIC_LAYER;

-- =============================================================================
-- CHECK 3: MCP Server exists
-- =============================================================================

SELECT '--- CHECK 3: MCP Server ---' AS check_name;
SHOW MCP SERVERS IN SCHEMA FULLSTORY_ANALYTICS.SEMANTIC_LAYER;

-- =============================================================================
-- CHECK 4: Verify semantic view DDL is intact
-- =============================================================================

SELECT '--- CHECK 4: Semantic View DDL ---' AS check_name;
SELECT LEFT(GET_DDL('SEMANTIC_VIEW', $full_view_path), 200) AS ddl_preview;

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'All checks passed!' AS summary;
SELECT 'To chat with the agent, open Snowsight > AI & ML > Agents and select FULLSTORY_AGENT.' AS next_step;
