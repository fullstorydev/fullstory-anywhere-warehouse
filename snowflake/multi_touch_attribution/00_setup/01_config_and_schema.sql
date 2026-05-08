-- =============================================================================
-- PHASE 1 — Setup: Database, Schemas, and Config Table
-- =============================================================================
-- Run this script once per environment (dev / prod).
-- This script is run in phase1 of make file
-- Replace the <PLACEHOLDERS> at the top before executing.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Session-level source table references
--    Update these to match your Fullstory data destination tables.
-- ---------------------------------------------------------------------------
SET fs_database            = '<YOUR_FS_DATABASE>';        -- e.g. 'FULLSTORY_PROD'
SET fs_schema              = '<YOUR_FS_SCHEMA>';           -- e.g. 'FS_DATA_DESTINATIONS'
SET fs_events_table        = '<YOUR_EVENTS_TABLE>';        -- e.g. 'ACME_abc123_EVENTS'
SET fs_source_props_table  = '<YOUR_SOURCE_PROPS_TABLE>';  -- e.g. 'ACME_abc123_SOURCE_PROPERTIES'
SET fs_users_table         = '<YOUR_USERS_TABLE>';         -- e.g. 'ACME_abc123_USERS'
SET fs_custom_events_table = '<YOUR_CUSTOM_EVENTS_TABLE>'; -- e.g. 'ACME_abc123_CUSTOM_EVENTS'

-- ---------------------------------------------------------------------------
-- 2. Target database and schemas
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS fs_marketing;

CREATE SCHEMA IF NOT EXISTS fs_marketing.config;
CREATE SCHEMA IF NOT EXISTS fs_marketing.staging;
CREATE SCHEMA IF NOT EXISTS fs_marketing.intermediate;
CREATE SCHEMA IF NOT EXISTS fs_marketing.marts;

-- ---------------------------------------------------------------------------
-- 3. Attribution config table
--    Single-row table used by all downstream views and dynamic tables.
--    Update the INSERT values to match your environment.
--    To change parameters: DELETE and re-INSERT, then refresh downstream DTs.
--
--    lookback_days          — how far back from CURRENT_TIMESTAMP the staging
--                             views will include events. Should be comfortably
--                             larger than attribution_window_days so there is
--                             enough history to build full touchpoint paths.
--    attribution_window_days — how far before a conversion to look for
--                             touchpoints (used in the mart range join).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE fs_marketing.config.attribution_config (
    lookback_days              INT           NOT NULL DEFAULT 90,
    attribution_window_days    INT           NOT NULL DEFAULT 14,
    conversion_event_name      VARCHAR(255)  NOT NULL DEFAULT 'Checkout Success'
);

-- Seed initial values — update as needed
INSERT INTO fs_marketing.config.attribution_config
    (lookback_days, attribution_window_days, conversion_event_name)
VALUES
    (90, 14, 'Checkout Success');

-- Verify
SELECT * FROM fs_marketing.config.attribution_config;
