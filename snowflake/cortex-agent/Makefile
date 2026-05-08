SNOW          := snow
CONNECTION    ?= snowflake

# ---- Fullstory source data (CHANGE THESE to match your Snowflake account) ----
FULLSTORY_DB  ?= FULLSTORY_READY_TO_ANALYZE
FULLSTORY_SCH ?= FULLSTORY_DEMO_DATA

# ---- Deployment targets (can leave as defaults) ----
DEPLOY_DB     ?= FULLSTORY_CORTEX
DEPLOY_SCHEMA ?= SEMANTIC_LAYER
SV_NAME       ?= FULLSTORY_SEMANTIC
AGENT_NAME    ?= FULLSTORY_AGENT

SV_SQL_TMP    := /tmp/create_semantic_view_sub.sql

.PHONY: help deploy _create-semantic-view validate teardown mcp gen-mcp-config

help:
	@echo "Fullstory Cortex Starter Kit"
	@echo ""
	@echo "  make deploy            Deploy semantic view and Cortex Agent"
	@echo "  make validate          Validate the deployment"
	@echo "  make teardown          Remove deployed objects (clean slate for re-deploy)"
	@echo "  make mcp               Deploy the MCP server (run after deploy)"
	@echo "  make gen-mcp-config    Generate .mcp.json from MCP_URL and SNOWFLAKE_PAT"
	@echo ""
	@echo "Configure your Fullstory source location (defaults shown):"
	@echo "  make deploy FULLSTORY_DB=MY_DB FULLSTORY_SCH=MY_SCHEMA CONNECTION=my-connection"
	@echo ""
	@echo "Generate local MCP config (copy MCP_URL from 'make mcp' output):"
	@echo "  make gen-mcp-config MCP_URL=https://... SNOWFLAKE_PAT=<your-pat>"

# Full deploy: create semantic view then create agent
deploy: _create-semantic-view
	$(SNOW) sql -f scripts/setup.sql --connection $(CONNECTION)

# Substitute placeholders in create_semantic_view.sql and run it
_create-semantic-view:
	@echo "Substituting database=$(FULLSTORY_DB) schema=$(FULLSTORY_SCH) in semantic view SQL..."
	sed \
		-e 's/{{DATABASE}}/$(FULLSTORY_DB)/g' \
		-e 's/{{SCHEMA}}/$(FULLSTORY_SCH)/g' \
		-e 's/{{DEPLOY_DB}}/$(DEPLOY_DB)/g' \
		-e 's/{{DEPLOY_SCHEMA}}/$(DEPLOY_SCHEMA)/g' \
		-e 's/{{SV_NAME}}/$(SV_NAME)/g' \
		scripts/create_semantic_view.sql > $(SV_SQL_TMP)
	@echo "Creating semantic view in $(DEPLOY_DB).$(DEPLOY_SCHEMA)..."
	$(SNOW) sql -f $(SV_SQL_TMP) --connection $(CONNECTION)

validate:
	$(SNOW) sql -f scripts/validate.sql --connection $(CONNECTION)

teardown:
	$(SNOW) sql -f scripts/teardown.sql --connection $(CONNECTION)

mcp:
	$(SNOW) sql -f scripts/setup_mcp.sql --connection $(CONNECTION)

# Generate .mcp.json from .mcp.json.example by substituting MCP_URL and SNOWFLAKE_PAT.
# Usage: make gen-mcp-config MCP_URL=https://... SNOWFLAKE_PAT=<your-pat>
# Or:    export MCP_URL=... SNOWFLAKE_PAT=... && make gen-mcp-config
gen-mcp-config:
	@[ -n "$(MCP_URL)" ] || { echo "ERROR: MCP_URL is not set. Copy it from the 'make mcp' output."; exit 1; }
	@[ -n "$(SNOWFLAKE_PAT)" ] || { echo "ERROR: SNOWFLAKE_PAT is not set. Generate one in Snowsight → Admin → Security → Programmatic Access Tokens."; exit 1; }
	@sed \
		-e 's|<MCP_URL>|$(MCP_URL)|g' \
		-e 's|<SNOWFLAKE_PAT>|$(SNOWFLAKE_PAT)|g' \
		.mcp.json.example > .mcp.json
	@echo ".mcp.json generated. Restart Claude Code to connect."
