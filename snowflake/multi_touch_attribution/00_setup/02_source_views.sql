-- =============================================================================
-- PHASE 1 — Setup: Raw Source Views (thin pass-through over FullStory tables)
-- =============================================================================
-- Decouples the rest of the pipeline from client-specific FullStory table names.
--
-- Variables are injected by the Makefile via snow sql -D flags:
--   FS_DATABASE, FS_SCHEMA, FS_EVENTS_TABLE, FS_SOURCE_PROPS_TABLE,
--   FS_USERS_TABLE, FS_CUSTOM_EVENTS_TABLE
--
-- Run via:  make phase1
-- Or manually via snow cli:
--   snow sql -c <conn> \
--     -D FS_DATABASE=mydb \
--     -D FS_SCHEMA=myschema \
--     -D FS_EVENTS_TABLE=mytable \
--     ... \
--     -f 00_setup/02_source_views.sql
-- =============================================================================

CREATE OR REPLACE VIEW fs_marketing.staging.raw_fs__events AS
    SELECT * FROM <% FS_DATABASE %>.<% FS_SCHEMA %>.<% FS_EVENTS_TABLE %>;

CREATE OR REPLACE VIEW fs_marketing.staging.raw_fs__source_properties AS
    SELECT * FROM <% FS_DATABASE %>.<% FS_SCHEMA %>.<% FS_SOURCE_PROPS_TABLE %>;

CREATE OR REPLACE VIEW fs_marketing.staging.raw_fs__users AS
    SELECT * FROM <% FS_DATABASE %>.<% FS_SCHEMA %>.<% FS_USERS_TABLE %>;

CREATE OR REPLACE VIEW fs_marketing.staging.raw_fs__custom_events AS
    SELECT * FROM <% FS_DATABASE %>.<% FS_SCHEMA %>.<% FS_CUSTOM_EVENTS_TABLE %>;
