-- =============================================================================
-- FULLSTORY MCP SERVER DEPLOYMENT SCRIPT
-- =============================================================================
--
-- Creates a Snowflake-managed MCP (Model Context Protocol) server that exposes
-- the Fullstory Cortex Agent to any MCP-compatible client (Claude Desktop,
-- Cursor, VS Code, etc.).
--
-- Prerequisites:
--   The Cortex Agent must already exist — run `make deploy` first.
--
-- Authentication options:
--   OAuth 2.0  — recommended for production and shared environments
--   PAT        — fine for local dev / personal use (no SQL setup needed)
--
-- Usage:
--   make mcp                             (deploy MCP server)
--   snow sql -f scripts/setup_mcp.sql   (run directly)
--
-- =============================================================================

-- =============================================================================
-- CONFIGURATION — UPDATE THESE VALUES
-- =============================================================================

SET deploy_database   = '{{DEPLOY_DB}}';
SET deploy_schema     = '{{DEPLOY_SCHEMA}}';
SET deploy_warehouse  = '{{DEPLOY_WAREHOUSE}}';
SET agent_name        = '{{AGENT_NAME}}';
SET mcp_server_name   = '{{MCP_SERVER_NAME}}';
SET mcp_role_name     = '{{MCP_ROLE_NAME}}';         -- least-privilege role for MCP clients
SET oauth_integration = '{{OAUTH_INTEGRATION}}'; -- security integration name (must be uppercase)

SET schema_full_name        = $deploy_database || '.' || $deploy_schema;
SET agent_full_name         = $deploy_database || '.' || $deploy_schema || '.' || $agent_name;
SET mcp_full_name           = $deploy_database || '.' || $deploy_schema || '.' || $mcp_server_name;
SET semantic_view_full_name = $deploy_database || '.' || $deploy_schema || '.{{SV_NAME}}';
SET account_url            = CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() || '.snowflakecomputing.com';

-- =============================================================================
-- SETUP
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE IDENTIFIER($deploy_database);
USE SCHEMA   IDENTIFIER($deploy_schema);

-- =============================================================================
-- STEP 1: CREATE LEAST-PRIVILEGE ROLE FOR MCP CLIENTS
-- =============================================================================
-- Best practice: never connect MCP clients as ACCOUNTADMIN.
-- Create a dedicated role and grant only what MCP needs.

CREATE ROLE IF NOT EXISTS IDENTIFIER($mcp_role_name);

GRANT USAGE ON DATABASE IDENTIFIER($deploy_database)                               TO ROLE IDENTIFIER($mcp_role_name);
GRANT USAGE ON SCHEMA   IDENTIFIER($schema_full_name)                              TO ROLE IDENTIFIER($mcp_role_name);
-- USAGE on the MCP server and agent are granted after those objects are created (Step 3/4 below).

-- =============================================================================
-- STEP 2: OAUTH SECURITY INTEGRATION (OPTIONAL — skip for PAT-based local dev)
-- =============================================================================
-- Required for OAuth 2.0 authentication. Skip this step if you are using a
-- Programmatic Access Token (PAT) for local development (see note at bottom).
--
-- To use OAuth, uncomment the block below and choose one of:
--   a) Use https:// redirect URI (requires TLS termination)
--   b) Add OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE for http://localhost
--
-- Update OAUTH_REDIRECT_URI to match your MCP client's callback URL:
--   Claude Desktop  →  http://localhost:3000/callback
--   Generic clients →  http://localhost:8080/callback
--
-- The integration name is case-sensitive and must be uppercase when referenced
-- in SYSTEM$SHOW_OAUTH_CLIENT_SECRETS().

-- CREATE SECURITY INTEGRATION IF NOT EXISTS FULLSTORY_MCP_OAUTH
--     TYPE                             = OAUTH
--     OAUTH_CLIENT                     = CUSTOM
--     ENABLED                          = TRUE
--     OAUTH_CLIENT_TYPE                = 'CONFIDENTIAL'   -- required; PUBLIC not supported for MCP
--     OAUTH_REDIRECT_URI               = 'http://localhost:8080/callback'
--     OAUTH_ALLOW_NON_TLS_REDIRECT_URI = TRUE             -- required for http:// redirect URIs
--     OAUTH_ISSUE_REFRESH_TOKENS       = TRUE
--     OAUTH_REFRESH_TOKEN_VALIDITY     = 86400;            -- 24 hours; max 90 days (7776000)

-- Retrieve client_id and client_secret for your MCP client config:
-- SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('FULLSTORY_MCP_OAUTH');

-- =============================================================================
-- STEP 3: CREATE MCP SERVER
-- =============================================================================
-- Exposes the Fullstory Cortex Agent as an MCP tool.
-- Uses a JavaScript procedure to build the spec string at runtime so the agent
-- identifier is read from session variables rather than hardcoded.

CREATE OR REPLACE PROCEDURE CREATE_FULLSTORY_MCP(
    mcp_full_name   VARCHAR,
    agent_full_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS $$
var spec =
'tools:\n' +
'  - name: "fullstory-agent"\n' +
'    type: "CORTEX_AGENT_RUN"\n' +
'    identifier: "' + AGENT_FULL_NAME + '"\n' +
'    description: "Natural language analytics for Fullstory behavioral data. Ask questions about sessions, page views, rage clicks, JavaScript errors, Core Web Vitals (LCP, CLS, INP), user journeys, and conversion funnels."\n' +
'    title: "Fullstory Analytics"\n';

var dd   = String.fromCharCode(36, 36);
var stmt = snowflake.createStatement({
    sqlText: 'CREATE OR REPLACE MCP SERVER ' + MCP_FULL_NAME +
             ' FROM SPECIFICATION ' + dd + spec + dd
});
stmt.execute();
return 'MCP Server ' + MCP_FULL_NAME + ' created successfully';
$$;

CALL CREATE_FULLSTORY_MCP($mcp_full_name, $agent_full_name);
DROP PROCEDURE IF EXISTS CREATE_FULLSTORY_MCP(VARCHAR, VARCHAR);

-- =============================================================================
-- STEP 4: GRANT ACCESS TO THE MCP ROLE
-- =============================================================================
-- USAGE on the MCP server does NOT automatically grant access to the underlying
-- tools — each object requires its own grant.

GRANT USAGE ON WAREHOUSE IDENTIFIER($deploy_warehouse)                                          TO ROLE IDENTIFIER($mcp_role_name);
GRANT USAGE ON MCP SERVER  IDENTIFIER($mcp_full_name)                                           TO ROLE IDENTIFIER($mcp_role_name);
GRANT USAGE ON AGENT       IDENTIFIER($agent_full_name)                                         TO ROLE IDENTIFIER($mcp_role_name);
GRANT SELECT ON SEMANTIC VIEW IDENTIFIER($semantic_view_full_name)                              TO ROLE IDENTIFIER($mcp_role_name);

-- Grant the MCP role to your Snowflake user:
-- GRANT ROLE IDENTIFIER($mcp_role_name) TO USER your_username;

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'MCP Server created!' AS result;

SELECT
    'https://' || $account_url || '/api/v2/databases/'
    || $deploy_database || '/schemas/' || $deploy_schema
    || '/mcp-servers/' || $mcp_server_name AS mcp_connection_url;

-- =============================================================================
-- AUTH STATUS REMINDER
-- =============================================================================

SELECT
    'PAT (Programmatic Access Token)' AS current_auth_method,
    'Suitable for local dev only. For production, uncomment the security integration block in Step 2 and re-run make mcp.' AS note;

SELECT 'Copy mcp_connection_url above, then run: make gen-mcp-config MCP_URL=<url> SNOWFLAKE_PAT=<pat>' AS next_step;

-- =============================================================================
-- OAUTH CLIENT CONFIG
-- =============================================================================
-- Use the client_id and client_secret from the SELECT above to configure your
-- MCP client. The authorization URL pattern is:
--
--   https://<your-account-url>/oauth/authorize
--     ?client_id=<client_id>
--     &response_type=code
--     &redirect_uri=<redirect_uri>
--     &scope=refresh_token session:role:MCP_ANALYST
--     &code_challenge=<pkce_s256_challenge>
--     &code_challenge_method=S256
--
-- Your account URL is printed in the mcp_connection_url query above.
--
-- Token exchange endpoint:
--   POST https://<your-account-url>/oauth/token-request
--
-- Always use scope=session:role:MCP_ANALYST (or your role name) to pin the
-- session to the least-privilege role. PKCE (S256) is required.
--
-- =============================================================================
-- LOCAL DEV ALTERNATIVE: PROGRAMMATIC ACCESS TOKEN (PAT)
-- =============================================================================
-- For personal use or local testing, skip the OAuth integration entirely and
-- use a PAT as a Bearer token instead. No SQL needed:
--
--   1. Snowsight → Admin → Security → Programmatic Access Tokens → Generate
--   2. Assign the token to the MCP_ANALYST role (or equivalent)
--   3. Use it directly:  Authorization: Bearer <your-pat>
--
-- WARNING: PATs are long-lived secrets. Do not commit them or share them.
--          Use OAuth for any shared or production environment.
-- =============================================================================
