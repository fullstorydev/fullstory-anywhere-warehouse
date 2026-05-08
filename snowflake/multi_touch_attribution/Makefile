# =============================================================================
# Fullstory Marketing Attribution — Snowflake Native
# =============================================================================
# Prerequisites:
#   1. snow CLI installed  (brew install snowflake-cli)
#   2. ~/.snowflake/config.toml  with a named connection profile
#   3. .env file created from .env.example with your values filled in
#
# Quickstart:
#   cp .env.example .env   # fill in your values
#   make phase1            # deploy setup + staging
#   make phase2            # deploy intermediate dynamic tables
#   make phase3            # deploy mart dynamic table
# =============================================================================

# Load .env if present (silently — no error if missing)
-include .env
export

# ── Connection ────────────────────────────────────────────────────────────────
SNOWSQL_CONN        ?= fs_marketing_attr
SNOWFLAKE_WAREHOUSE ?=
SNOWFLAKE_ROLE      ?=

SF = snow sql -c $(SNOWSQL_CONN) $(if $(SNOWFLAKE_ROLE),--role $(SNOWFLAKE_ROLE),)

# ── Source table variables (passed to snowsql as --variable flags) ────────────
FS_DATABASE            ?=
FS_SCHEMA              ?=
FS_EVENTS_TABLE        ?=
FS_SOURCE_PROPS_TABLE  ?=
FS_USERS_TABLE         ?=
FS_CUSTOM_EVENTS_TABLE ?=

# Variables injected into 02_source_views.sql
SOURCE_VARS = \
	-D FS_DATABASE=$(FS_DATABASE) \
	-D FS_SCHEMA=$(FS_SCHEMA) \
	-D FS_EVENTS_TABLE=$(FS_EVENTS_TABLE) \
	-D FS_SOURCE_PROPS_TABLE=$(FS_SOURCE_PROPS_TABLE) \
	-D FS_USERS_TABLE=$(FS_USERS_TABLE) \
	-D FS_CUSTOM_EVENTS_TABLE=$(FS_CUSTOM_EVENTS_TABLE)

# Warehouse injected into Dynamic Table DDL (phases 2 & 3)
WH_VAR = -D WAREHOUSE=$(SNOWFLAKE_WAREHOUSE)

.DEFAULT_GOAL := help

.PHONY: help check-conn check-vars \
        phase1 phase2 phase3 \
        teardown-mart teardown-intermediate teardown-staging teardown-setup teardown \
        refresh-intermediate refresh-mart refresh \
        status \
        test-unit test-data test

# ── Help ──────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "  Setup"
	@echo "    check-conn            Verify Snowflake connection"
	@echo "    check-vars            Validate all required env vars are set"
	@echo ""
	@echo "  Deployment (run in order)"
	@echo "    phase1                Setup schemas, config table, source views, staging views"
	@echo "    phase2                Deploy intermediate Dynamic Tables"
	@echo "    phase3                Deploy mart Dynamic Table (leaf node, refreshes hourly)"
	@echo ""
	@echo "  Teardown (cascades — each target drops dependents first)"
	@echo "    teardown-mart         Drop fct_marketing_attribution"
	@echo "    teardown-intermediate Drop int_* Dynamic Tables (also drops mart)"
	@echo "    teardown-staging      Drop all staging views (also drops phase 2+3)"
	@echo "    teardown-setup        Drop config table and schemas (full wipe)"
	@echo "    teardown              Full teardown of everything"
	@echo ""
	@echo "  Utilities"
	@echo "    refresh               Manually trigger full pipeline refresh"
	@echo "    refresh-intermediate  Manually trigger intermediate DTs only"
	@echo "    refresh-mart          Manually trigger mart DT only"
	@echo "    status                Show Dynamic Table refresh status"
	@echo ""
	@echo "  Testing"
	@echo "    test-unit             Run SQL unit tests (no real data needed; test_04 creates/drops fs_marketing.tests schema, ~1min)"
	@echo "    test-data             Run data quality assertions against deployed tables"
	@echo "    test                  Run all tests (unit + data)"
	@echo ""
	@echo "  Note: tests return 0 rows on PASS and descriptive rows on FAIL."
	@echo ""

# ── Pre-flight checks ─────────────────────────────────────────────────────────
check-conn:
	@echo "Testing Snowflake connection..."
	@snow connection test -c $(SNOWSQL_CONN)

check-vars:
	@[ -n "$(FS_DATABASE)" ]            || (echo "ERROR: FS_DATABASE is not set. Copy .env.example to .env and fill in your values." && exit 1)
	@[ -n "$(FS_SCHEMA)" ]              || (echo "ERROR: FS_SCHEMA is not set."              && exit 1)
	@[ -n "$(FS_EVENTS_TABLE)" ]        || (echo "ERROR: FS_EVENTS_TABLE is not set."        && exit 1)
	@[ -n "$(FS_SOURCE_PROPS_TABLE)" ]  || (echo "ERROR: FS_SOURCE_PROPS_TABLE is not set."  && exit 1)
	@[ -n "$(FS_USERS_TABLE)" ]         || (echo "ERROR: FS_USERS_TABLE is not set."         && exit 1)
	@[ -n "$(FS_CUSTOM_EVENTS_TABLE)" ] || (echo "ERROR: FS_CUSTOM_EVENTS_TABLE is not set." && exit 1)
	@[ -n "$(SNOWFLAKE_WAREHOUSE)" ]    || (echo "ERROR: SNOWFLAKE_WAREHOUSE is not set."    && exit 1)
	@echo "All required variables are set."

# ── Deployment ────────────────────────────────────────────────────────────────

# Phase 1: database + schemas + config table + source views + staging views
phase1: check-conn check-vars
	@echo ">>> Phase 1: Creating schemas and config table..."
	$(SF) -f 00_setup/01_config_and_schema.sql
	@echo ">>> Phase 1: Creating raw source views..."
	$(SF) $(SOURCE_VARS) -f 00_setup/02_source_views.sql
	@echo ">>> Phase 1: Creating staging views..."
	$(SF) -f 01_staging/stg_fs__events.sql
	$(SF) -f 01_staging/stg_fs__users.sql
	$(SF) -f 01_staging/stg_fs__custom_events.sql
	$(SF) -f 01_staging/stg_fs__source_properties.sql
	@echo ">>> Phase 1 complete."

# Phase 2: intermediate Dynamic Tables
phase2: check-conn
	@[ -n "$(SNOWFLAKE_WAREHOUSE)" ] || (echo "ERROR: SNOWFLAKE_WAREHOUSE is not set." && exit 1)
	@echo ">>> Phase 2: Creating intermediate Dynamic Tables..."
	$(SF) $(WH_VAR) -f 02_intermediate/int_marketing__touchpoints.sql
	$(SF) $(WH_VAR) -f 02_intermediate/int_marketing__conversions.sql
	@echo ">>> Phase 2 complete."

# Phase 3: mart Dynamic Table (leaf node)
phase3: check-conn
	@[ -n "$(SNOWFLAKE_WAREHOUSE)" ] || (echo "ERROR: SNOWFLAKE_WAREHOUSE is not set." && exit 1)
	@echo ">>> Phase 3: Creating mart Dynamic Table..."
	$(SF) $(WH_VAR) -f 03_marts/fct_marketing_attribution.sql
	@echo ">>> Phase 3 complete."

# ── Teardown ──────────────────────────────────────────────────────────────────
# Cascades: each target drops downstream dependents before itself.

teardown-mart: check-conn
	@echo ">>> Dropping mart Dynamic Table..."
	$(SF) -f teardown/03_teardown_mart.sql

teardown-intermediate: teardown-mart
	@echo ">>> Dropping intermediate Dynamic Tables..."
	$(SF) -f teardown/02_teardown_intermediate.sql

teardown-staging: teardown-intermediate
	@echo ">>> Dropping staging views..."
	$(SF) -f teardown/01_teardown_staging.sql

teardown-setup: teardown-staging
	@echo ">>> Dropping config table and schemas..."
	$(SF) -f teardown/00_teardown_setup.sql

teardown: teardown-setup
	@echo ">>> Full teardown complete."

# ── Utilities ─────────────────────────────────────────────────────────────────

refresh-intermediate: check-conn
	@echo ">>> Refreshing intermediate Dynamic Tables..."
	$(SF) -q "ALTER DYNAMIC TABLE fs_marketing.intermediate.int_marketing__touchpoints REFRESH;"
	$(SF) -q "ALTER DYNAMIC TABLE fs_marketing.intermediate.int_marketing__conversions REFRESH;"

refresh-mart: check-conn
	@echo ">>> Refreshing mart Dynamic Table..."
	$(SF) -q "ALTER DYNAMIC TABLE fs_marketing.marts.fct_marketing_attribution REFRESH;"

refresh: refresh-intermediate refresh-mart
	@echo ">>> Pipeline refresh triggered."

status: check-conn
	@echo ">>> Dynamic Table status — intermediate:"
	$(SF) -q "SELECT name, scheduling_state, last_completed_dependency_updated_on, rows AS row_count FROM snowflake.account_usage.dynamic_tables WHERE schema_name = 'INTERMEDIATE' AND database_name = 'FS_MARKETING' ORDER BY name;"
	@echo ">>> Dynamic Table status — marts:"
	$(SF) -q "SELECT name, scheduling_state, last_completed_dependency_updated_on, rows AS row_count FROM snowflake.account_usage.dynamic_tables WHERE schema_name = 'MARTS' AND database_name = 'FS_MARKETING' ORDER BY name;"

# ── Tests ──────────────────────────────────────────────────────────────────────
# Each test file returns 0 rows on PASS and descriptive rows on FAIL.

test-unit: check-conn
	@echo ""
	@echo "=== Unit Tests (self-contained, no real data required) ==="
	@echo ""
	@echo "--- test_01_touchpoint_waterfall ---"
	$(SF) -f tests/unit/test_01_touchpoint_waterfall.sql
	@echo "--- test_02_attribution_model_math ---"
	$(SF) -f tests/unit/test_02_attribution_model_math.sql
	@echo "--- test_03_lookback_and_double_counting ---"
	$(SF) -f tests/unit/test_03_lookback_and_double_counting.sql
	@echo "--- test_04_incremental_refresh (creates/drops fs_marketing.tests schema; ~1min) ---"
	$(SF) -f tests/unit/test_04_incremental_refresh.sql
	@echo ""
	@echo "Unit tests complete. Empty result = PASS. Rows = FAIL (details shown above)."
	@echo ""

test-data: check-conn
	@echo ""
	@echo "=== Data Tests (require deployed tables) ==="
	@echo ""
	@echo "--- data_test_01_revenue_integrity ---"
	$(SF) -f tests/data/data_test_01_revenue_integrity.sql
	@echo "--- data_test_02_session_ordering ---"
	$(SF) -f tests/data/data_test_02_session_ordering.sql
	@echo "--- data_test_03_completeness ---"
	$(SF) -f tests/data/data_test_03_completeness.sql
	@echo "--- data_test_04_value_integrity ---"
	$(SF) -f tests/data/data_test_04_value_integrity.sql
	@echo ""
	@echo "Data tests complete. Empty result = PASS. Rows = FAIL (details shown above)."
	@echo ""

test: test-unit test-data
	@echo ">>> All tests complete."
