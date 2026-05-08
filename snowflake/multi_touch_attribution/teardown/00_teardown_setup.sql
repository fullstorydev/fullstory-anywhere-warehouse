-- =============================================================================
-- TEARDOWN: Setup — Config Table and Schemas
-- =============================================================================
-- Run this last (after all views and dynamic tables are dropped).
-- =============================================================================

DROP TABLE  IF EXISTS fs_marketing.config.attribution_config;

DROP SCHEMA IF EXISTS fs_marketing.config;
DROP SCHEMA IF EXISTS fs_marketing.staging;
DROP SCHEMA IF EXISTS fs_marketing.intermediate;
DROP SCHEMA IF EXISTS fs_marketing.marts;
DROP SCHEMA IF EXISTS fs_marketing.ml;

DROP DATABASE IF EXISTS fs_marketing;
