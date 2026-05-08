-- =============================================================================
-- TEARDOWN SCRIPT
-- =============================================================================
--
-- Removes all objects created by make deploy so you can re-deploy from scratch.
--
--   snow sql -f scripts/teardown.sql --connection <your-connection>
--   OR: make teardown
--
-- WARNING: This is destructive. The database and schema are preserved by
-- default. Set DROP_DATABASE = TRUE below to also remove them.
-- =============================================================================

SET deploy_database    = 'FULLSTORY_ANALYTICS';
SET deploy_schema      = 'SEMANTIC_LAYER';
SET semantic_view_name = 'FULLSTORY_ANALYTICS';
SET agent_name         = 'FULLSTORY_AGENT';
SET mcp_server_name    = 'FULLSTORY_MCP';

-- Set to TRUE to also drop the database (removes everything)
SET drop_database = TRUE;

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($deploy_database);
USE SCHEMA   IDENTIFIER($deploy_schema);

-- Drop the MCP Server (if deployed)
SET _stmt = 'DROP MCP SERVER IF EXISTS ' || $deploy_database || '.' || $deploy_schema || '.' || $mcp_server_name;
EXECUTE IMMEDIATE $_stmt;

-- Drop the Cortex Agent
SET _stmt = 'DROP AGENT IF EXISTS ' || $deploy_database || '.' || $deploy_schema || '.' || $agent_name;
EXECUTE IMMEDIATE $_stmt;

-- Drop the Semantic View
SET _stmt = 'DROP SEMANTIC VIEW IF EXISTS ' || $deploy_database || '.' || $deploy_schema || '.' || $semantic_view_name;
EXECUTE IMMEDIATE $_stmt;

-- Drop the helper procedure
DROP PROCEDURE IF EXISTS CREATE_FULLSTORY_AGENT(VARCHAR, VARCHAR);

-- Optionally drop schema and database
SET _stmt = CASE WHEN $drop_database THEN 'DROP DATABASE IF EXISTS ' || $deploy_database ELSE 'SELECT ''Skipping database drop (set drop_database = TRUE to remove)'' AS note' END;
EXECUTE IMMEDIATE $_stmt;

SELECT 'Teardown complete. Run make deploy to redeploy.' AS result;
