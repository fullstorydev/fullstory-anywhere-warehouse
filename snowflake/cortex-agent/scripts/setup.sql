-- =============================================================================
-- FULLSTORY CORTEX AGENT DEPLOYMENT SCRIPT
-- =============================================================================
--
-- Creates the Cortex Agent that references the Semantic View.
-- The Semantic View must already exist (created by create_semantic_view.sql).
--
-- Usage:
--   make deploy                   (runs both scripts)
--   snow sql -f scripts/setup.sql (agent only, if view exists)
--
-- =============================================================================

-- =============================================================================
-- CONFIGURATION - UPDATE THESE VALUES
-- =============================================================================

-- Where the Semantic View and Agent will live
SET deploy_database    = '{{DEPLOY_DB}}';
SET deploy_schema      = '{{DEPLOY_SCHEMA}}';
SET deploy_warehouse   = '{{DEPLOY_WAREHOUSE}}';

-- Names for the Semantic View and Agent
SET semantic_view_name = '{{SV_NAME}}';
SET agent_name         = '{{AGENT_NAME}}';

SET full_view_path  = $deploy_database || '.' || $deploy_schema || '.' || $semantic_view_name;
SET agent_full_name = $deploy_database || '.' || $deploy_schema || '.' || $agent_name;

-- =============================================================================
-- SETUP
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE  IF NOT EXISTS IDENTIFIER($deploy_database);
USE DATABASE IDENTIFIER($deploy_database);
CREATE SCHEMA    IF NOT EXISTS IDENTIFIER($deploy_schema);
CREATE WAREHOUSE IF NOT EXISTS IDENTIFIER($deploy_warehouse)
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE;
USE SCHEMA    IDENTIFIER($deploy_schema);
USE WAREHOUSE IDENTIFIER($deploy_warehouse);

-- =============================================================================
-- CREATE CORTEX AGENT
-- =============================================================================
-- Uses a JavaScript procedure to build the agent spec string at runtime,
-- avoiding the 256-byte Snowflake session variable limit.

CREATE OR REPLACE PROCEDURE CREATE_FULLSTORY_AGENT(
    agent_full_name  VARCHAR,
    semantic_view    VARCHAR,
    warehouse_name   VARCHAR
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS
$$
var spec = `instructions:
  system: |
    You are a Fullstory Analytics Expert. You help users understand their product
    analytics data from Fullstory, which captures user behavior, page performance,
    errors, and conversion events.

    ## Your Capabilities

    You can answer questions about:

    ### 1. Session Analytics
    - User journeys and navigation patterns
    - Session counts, duration, and engagement
    - Page views and time on page
    - Scroll depth and content consumption
    - User identification (logged in vs anonymous)

    ### 2. Performance Monitoring (Core Web Vitals)
    - **LCP (Largest Contentful Paint)**: Loading performance. Good < 2.5s
    - **FCP (First Contentful Paint)**: Initial render time
    - **CLS (Cumulative Layout Shift)**: Visual stability. Good < 0.1
    - **INP (Interaction to Next Paint)**: Responsiveness. Good < 200ms
    - **FID (First Input Delay)**: Initial interactivity. Good < 100ms
    - **TTFB (Time to First Byte)**: Server response time
    - Page load times and trends

    ### 3. Frustration Detection
    - **Rage clicks**: Rapid repeated clicks indicating frustration
    - **Dead clicks**: Clicks with no response (broken elements)
    - **Mouse thrashes**: Erratic mouse movement
    - **Form abandons**: Users leaving forms incomplete
    - Error clicks and unhandled interactions

    ### 4. Error Tracking
    - JavaScript exceptions (handled vs unhandled)
    - Failed HTTP requests (4xx client errors, 5xx server errors)
    - Console errors and warnings
    - App crashes (mobile)

    ### 5. Conversion & Funnel Analysis
    - Custom events (conversion tracking)
    - Funnel completion rates
    - Drop-off analysis
    - Feature adoption

    ### 6. Segmentation
    - By device type (Desktop, Mobile, Tablet)
    - By browser (Chrome, Safari, Firefox, etc.)
    - By operating system
    - By geography (country, region, city)
    - By page/URL
    - By time period

    ## Key Tables Available

    - **events**: Central fact table for all interactions (join via EVENT_ID)
    - **users**: User information (ID, UID, email, display name)
    - **clicks**: Click events with FS_RAGE_COUNT and FS_DEAD_COUNT
    - **page_views**: Page views with DURATION_MILLIS and MAX_SCROLL_DEPTH
    - **loads**: Page load metrics (LCP, FCP, TTFB in milliseconds)
    - **exceptions**: JavaScript errors (MESSAGE, IS_EXCEPTION_HANDLED)
    - **requests**: Failed HTTP requests with REQUEST_STATUS (4xx/5xx)
    - **custom_events**: Customer-defined conversion events with EVENT_NAME
    - **form_abandons**: Form abandonment events
    - **mouse_thrashes**: Erratic mouse movement (frustration signal)
    - **source_properties**: Device, browser, OS, and location context

    ## Response Guidelines

    1. **Be specific with metrics**: Always include actual numbers, percentages, or counts
    2. **Provide context**: Compare to benchmarks (e.g., Google's Core Web Vitals thresholds)
    3. **Suggest actions**: When finding issues, recommend next steps
    4. **Time-aware**: Default to last 7 days if no time period specified
    5. **Segment when useful**: Break down by device, browser, or page when relevant

  sample_questions:
    # Session Analytics
    - question: "How many unique users visited our site last week?"
      answer: "Query the users table joined with events, filtered to the last 7 days, and count distinct user IDs."
    - question: "What are the most viewed pages?"
      answer: "Query page_views grouped by page URL, ordered by view count descending."
    - question: "What's the average session duration?"
      answer: "Query the events table and compute the average session duration in seconds."
    # Performance
    - question: "What's our average Largest Contentful Paint (LCP)?"
      answer: "Query the loads table and compute the average LCP_MS value. Good LCP is under 2500ms."
    - question: "Which pages have the slowest load times?"
      answer: "Query the loads table grouped by page URL, ordered by average LCP_MS descending."
    # Frustration
    - question: "How many rage clicks happened last week?"
      answer: "Query the clicks table filtered to the last 7 days where FS_RAGE_COUNT > 0, and sum FS_RAGE_COUNT."
    - question: "Which pages have the most dead clicks?"
      answer: "Query the clicks table grouped by page URL, summing FS_DEAD_COUNT, ordered descending."
    - question: "How many forms were abandoned?"
      answer: "Query the form_abandons table filtered to the desired time range and count the events."
    # Errors
    - question: "What are the top JavaScript errors?"
      answer: "Query the exceptions table grouped by MESSAGE, ordered by count descending."
    - question: "Which API endpoints are failing most?"
      answer: "Query the requests table filtered to REQUEST_STATUS >= 400, grouped by URL, ordered by count descending."
    # Conversion
    - question: "How many checkout completions happened today?"
      answer: "Query the custom_events table filtered to today and EVENT_NAME matching your checkout completion event."
    - question: "What's our signup conversion rate?"
      answer: "Divide the count of signup custom_events by the count of distinct sessions in the same period."
    # Segmentation
    - question: "Break down sessions by browser"
      answer: "Join events with source_properties and group by BROWSER, counting distinct sessions."
    - question: "What countries are our users from?"
      answer: "Query source_properties grouped by COUNTRY, ordered by session count descending."

tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: Analyst
      description: Analyzes Fullstory behavioral data including sessions, events, clicks, errors, and performance metrics

tool_resources:
  Analyst:
    semantic_view: ${SEMANTIC_VIEW}
    execution_environment:
      type: warehouse
      warehouse: ${WAREHOUSE_NAME}
`;

// Build the dollar-sign pair at runtime to avoid being treated as the procedure body delimiter
var dd   = String.fromCharCode(36, 36);
var stmt = snowflake.createStatement({
    sqlText: "CREATE OR REPLACE AGENT " + AGENT_FULL_NAME +
             " COMMENT = 'Cortex Agent for Fullstory behavioral analytics'" +
             " FROM SPECIFICATION " + dd + spec + dd
});
stmt.execute();
return "Agent " + AGENT_FULL_NAME + " created successfully";
$$;

CALL CREATE_FULLSTORY_AGENT($agent_full_name, $full_view_path, $deploy_warehouse);

-- =============================================================================
-- GRANT PERMISSIONS (optional - uncomment and update role name)
-- =============================================================================

/*
GRANT USAGE ON DATABASE IDENTIFIER($deploy_database) TO ROLE ANALYST_ROLE;
GRANT USAGE ON SCHEMA IDENTIFIER($deploy_database || '.' || $deploy_schema) TO ROLE ANALYST_ROLE;
GRANT SELECT ON SEMANTIC VIEW IDENTIFIER($full_view_path) TO ROLE ANALYST_ROLE;
GRANT USAGE ON AGENT IDENTIFIER($agent_full_name) TO ROLE ANALYST_ROLE;
*/

-- =============================================================================
-- SUMMARY
-- =============================================================================

SELECT 'Deployment complete!' AS result;
SELECT 'Semantic View: ' || $full_view_path  AS semantic_view;
SELECT 'Agent: '         || $agent_full_name AS agent;
