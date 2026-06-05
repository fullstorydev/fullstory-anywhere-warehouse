# Fullstory Cortex Starter Kit

A complete toolkit for analyzing [Fullstory](https://www.fullstory.com/) behavioral analytics data in Snowflake using Cortex AI.

## Overview

This starter kit provides:

- **Cortex Agent**: Natural language queries for Fullstory data
- **MCP Server**: Connect any MCP-compatible client (Claude Desktop, Cursor, VS Code) directly to the agent. [Fullstory Official MCP](https://developer.fullstory.com/mcp/introduction/)
- **Semantic View**: 30+ table definitions covering all Fullstory data
- **Auto-detection Scripts**: Generate semantic information for your custom properties

## Use Cases

| Domain | Examples |
|--------|----------|
| **Session Analytics** | User journeys, engagement metrics, page views, scroll depth |
| **Performance (Core Web Vitals)** | LCP, FCP, CLS, INP, FID, TTFB monitoring |
| **Frustration Detection** | Rage clicks, dead clicks, mouse thrashes, form abandons |
| **Error Tracking** | JavaScript exceptions, failed requests, console errors |
| **Conversion Analysis** | Custom events, funnel analysis, drop-off points |

## Quick Start

### Prerequisites

- Fullstory data loaded in Snowflake (via Fullstory's Snowflake integration)
- Snowflake account with ACCOUNTADMIN or appropriate privileges
- Access to Cortex features
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) (`snow`) — recommended for local development

### 1. Clone the Repository

```bash
git clone https://github.com/fullstorydev/fullstory-anywhere-warehouse.git
cd fullstory-anywhere-warehouse/snowflake/cortex-agent
```

### 2. Set Up Snowflake CLI Connection (one-time)

```bash
snow connection add
```

Or manually add a profile to `~/.snowflake/config.toml`:

```toml
[connections.my-connection]
account = "your-account"
user = "your-user"
authenticator = "externalbrowser"
role = "ACCOUNTADMIN"
warehouse = "COMPUTE_WH"
```

### 3. Configure Your Settings

Edit the variables in the Makefile:

```
SNOW          := snow
CONNECTION    ?= snowflake

# ---- Fullstory source data (CHANGE THESE to match your Snowflake account) ----
FULLSTORY_DB  ?= FULLSTORY_READY_TO_ANALYZE
FULLSTORY_SCH ?= FULLSTORY_DEMO_DATA

# ---- Deployment targets (can leave as defaults) ----
DEPLOY_DB         ?= FS_CORTEX_DB
DEPLOY_SCHEMA     ?= SEMANTIC_TEST
DEPLOY_WAREHOUSE  ?= COMPUTE_WH
SV_NAME           ?= FS_SEMANTIC
AGENT_NAME        ?= FS_AGENT
MCP_SERVER_NAME   ?= FS_MCP_SERVER
MCP_ROLE_NAME     ?= FS_ANALYST
OAUTH_INTEGRATION ?= FS_MCP_OAUTH
```

### 4. Validate

```bash
make validate CONNECTION=my-connection
```

Runs structural checks and a live Cortex Analyst query to confirm everything works.

### 5. (Optional) Add Custom Properties

If you have custom fields in `USER_PROPERTIES`, `PAGE_PROPERTIES`, or `ELEMENT_PROPERTIES`:

1. Update the database and schema variables at the top of `scripts/detect_custom_properties.sql`

2. Run the detection script:
   ```bash
   snow sql -f scripts/detect_custom_properties.sql --connection my-connection
   ```

3. Copy the output for each table into the appropriate section in `scripts/setup.sql` — add to tables, relationships, and dimensions

### 6. Deploy

```bash
make deploy CONNECTION=my-connection
```

This runs `scripts/setup.sql` which creates the semantic view and Cortex Agent automatically.

---

## Development Workflow

The `Makefile` wraps the `snow` CLI for common tasks:

| Command | What it does |
|---------|-------------|
| `make deploy` | Run `setup.sql` — creates semantic view + agent |
| `make mcp` | Run `setup_mcp.sql` — creates MCP server (run after deploy) |
| `make validate` | Run `validate.sql` — structural checks + live query |
| `make teardown` | Run `teardown.sql` — drop all objects for re-deploy |


## Project Structure

```
fullstory-cortex-starter-kit/
├── README.md                              # This file
├── agent/
│   └── fullstory_agent_spec.yaml          # Cortex Agent configuration
├── scripts/
│   ├── setup.sql                          # Deploy semantic view + Cortex Agent
│   ├── setup_mcp.sql                      # Deploy MCP server + OAuth integration
│   ├── teardown.sql                       # Remove all deployed objects
│   ├── validate.sql                       # Verify deployment
│   └── detect_custom_properties.sql       # Auto-generate YAML for custom fields
└── examples/
    └── sample_questions.md                # 100+ example queries
```

## MCP Server

The MCP server lets AI clients like Claude Desktop, Cursor, and VS Code connect directly to the Fullstory Cortex Agent via the [Model Context Protocol](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-mcp).

### Deploy

```bash
# Must run make deploy first (agent must exist before MCP server)
make deploy CONNECTION=my-connection
make mcp    CONNECTION=my-connection
```

### Connection URL

```
https://<account>.snowflakecomputing.com/api/v2/databases/FULLSTORY_ANALYTICS/schemas/SEMANTIC_LAYER/mcp-servers/FULLSTORY_MCP
```

Replace `<account>` with your Snowflake account identifier (use hyphens, not underscores, in the hostname).

### Authentication

Two options — OAuth is recommended for production, PAT is the quickest path for local dev:

| Method | Best for |
|--------|---------|
| **OAuth 2.0** | Production, shared environments, interactive clients (Claude Desktop, Cursor) |
| **PAT** | Local dev, personal use, quick testing |

#### Option A: OAuth 2.0 

`setup_mcp.sql` creates the `FULLSTORY_MCP_OAUTH` security integration. Before running `make mcp`, update `OAUTH_REDIRECT_URI` in the script to match your client:

| Client | Redirect URI |
|--------|-------------|
| Claude Desktop | `http://localhost:3000/callback` |
| Generic / custom | `http://localhost:8080/callback` |

After deploying, retrieve your client credentials:

```sql
SELECT SYSTEM$SHOW_OAUTH_CLIENT_SECRETS('FULLSTORY_MCP_OAUTH');
```

Your MCP client will use the returned `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET` to complete the OAuth 2.0 flow. Always request `scope=session:role:MCP_ANALYST` to pin the session to the least-privilege role. PKCE (S256) is required.

#### Option B: Programmatic Access Token (PAT)

For local dev — no SQL setup needed:

1. Snowsight → **Admin → Security → Programmatic Access Tokens → Generate**
2. Assign it the `MCP_ANALYST` role
3. Use it as a Bearer token when connecting:
   ```
   Authorization: Bearer <your-pat>
   ```

Do not commit PATs or use them in shared environments.

### Claude Code Setup

Connect Claude Code directly to the Fullstory agent via MCP:

1. **Deploy everything** (if not already done):
   ```bash
   make deploy CONNECTION=my-connection
   make mcp    CONNECTION=my-connection
   ```

2. **Grant the `MCP_ANALYST` role to your user** in Snowsight or via SQL:
   ```sql
   GRANT ROLE MCP_ANALYST TO USER your_username;
   ```

3. **Generate a PAT** in Snowsight:
   - Go to **Admin → Security → Programmatic Access Tokens → Generate**
   - Assign it to the `MCP_ANALYST` role

4. **Register the MCP server** with Claude Code:
   ```bash
   claude mcp add snowflake-mcp \
     --transport http \
     "https://<account>.snowflakecomputing.com/api/v2/databases/FULLSTORY_ANALYTICS/schemas/SEMANTIC_LAYER/mcp-servers/FULLSTORY_MCP" \
     --header "Authorization: Bearer <your-pat>"
   ```

   Replace `<account>` with your Snowflake account identifier (e.g. `myorg-myaccount`) and `<your-pat>` with your PAT.

5. **Start Claude Code**:
   ```bash
   claude
   ```

You can then ask questions like "How many rage clicks happened last week?" and Claude Code will query Fullstory data through the agent.

### Access Control

`setup_mcp.sql` creates a dedicated `MCP_ANALYST` role and grants it the minimum permissions needed (`USAGE` on the MCP server and the underlying agent). Grant the role to users who need access:

```sql
GRANT ROLE MCP_ANALYST TO USER your_username;
```

Note: `USAGE` on the MCP server does not automatically grant access to the tools inside it — each underlying object (agent, semantic view) requires its own grant.

---

## Tables Included

### Core Tables
| Table | Description |
|-------|-------------|
| `events` | Central fact table for all user interactions |
| `users` | User information (IDs, emails, display names) |
| `clicks` | Click events with rage/dead click detection |
| `page_views` | Page views with duration and scroll depth |
| `custom_events` | Customer-defined conversion events |

### Performance Tables
| Table | Description |
|-------|-------------|
| `loads` | Page load metrics (FCP, LCP, TTFB, TTI, TBT) |
| `cumulative_layout_shifts` | CLS Core Web Vital |
| `interaction_to_next_paints` | INP Core Web Vital |
| `first_input_delays` | FID Core Web Vital |

### Error Tables
| Table | Description |
|-------|-------------|
| `exceptions` | JavaScript errors (handled/unhandled) |
| `requests` | Failed HTTP requests (4xx/5xx) |
| `console_messages` | Browser console logs |
| `crashes` | Mobile app crashes |

### Frustration Tables
| Table | Description |
|-------|-------------|
| `mouse_thrashes` | Erratic mouse movement |
| `form_abandons` | Abandoned form submissions |

### Context Tables
| Table | Description |
|-------|-------------|
| `source_properties` | Device, browser, location data |
| `navigates` | Page navigation events |
| `consents` | User consent events |

### Extensible Tables
| Table | Description |
|-------|-------------|
| `user_properties` | Customer-defined user attributes |
| `page_properties` | Customer-defined page attributes |
| `element_properties` | Customer-defined element attributes |

## Example Questions

Once deployed, ask your Cortex Agent questions like:

**Session Analytics**
- "How many unique users visited last week?"
- "What are the most viewed pages?"
- "Show me average session duration by day"

**Performance**
- "What's our average LCP? Is it good?"
- "Which pages have the slowest load times?"
- "Compare mobile vs desktop Core Web Vitals"

**Frustration**
- "How many rage clicks happened yesterday?"
- "Which pages have the most dead clicks?"
- "Show me frustrated sessions on the checkout page"

**Errors**
- "What are the top 10 JavaScript errors?"
- "How many 500 errors occurred last week?"
- "Which users encountered the most errors?"

**Conversions**
- "How many checkout completions today?"
- "What's our signup conversion rate by device?"
- "Show me custom event trends"

See `examples/sample_questions.md` for 100+ more examples.


## Resources

- [Fullstory Documentation](https://developer.fullstory.com/)
- [Fullstory Snowflake Integration](https://help.fullstory.com/hc/en-us/articles/6295349250199-Snowflake-Setup-Guide)
- [Snowflake Semantic Views](https://docs.snowflake.com/en/user-guide/views-semantic/overview)
- [Snowflake Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
