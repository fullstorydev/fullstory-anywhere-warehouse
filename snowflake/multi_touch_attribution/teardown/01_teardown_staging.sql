-- =============================================================================
-- TEARDOWN: Phase 1 — Staging Views and Source Views
-- =============================================================================

-- Staging views
DROP VIEW IF EXISTS fs_marketing.staging.stg_fs__events;
DROP VIEW IF EXISTS fs_marketing.staging.stg_fs__users;
DROP VIEW IF EXISTS fs_marketing.staging.stg_fs__custom_events;
DROP VIEW IF EXISTS fs_marketing.staging.stg_fs__source_properties;

-- Raw source pass-through views
DROP VIEW IF EXISTS fs_marketing.staging.raw_fs__events;
DROP VIEW IF EXISTS fs_marketing.staging.raw_fs__source_properties;
DROP VIEW IF EXISTS fs_marketing.staging.raw_fs__users;
DROP VIEW IF EXISTS fs_marketing.staging.raw_fs__custom_events;
