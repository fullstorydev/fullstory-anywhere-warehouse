-- =============================================================================
-- Simple one-time batch: push static user properties from Snowflake to Fullstory
-- =============================================================================
--   1. Wire up external access to api.fullstory.com  (network rule + secret + EAI)
--   2. Create a tiny stored proc that:
--        - grabs N uids from your Fullstory users table
--        - posts them with a hardcoded properties bag to /v2/users/batch
--   3. CALL it.
--
-- Before running, the placeholders below are replaced by run.sh from .env:
--   <API-EAI-DB>                            DB.SCHEMA where EAI objects live
--   <DATABASE>.<SCHEMA>.<USERS_TABLE>       source of uids + updated_at
--   <WAREHOUSE>                             warehouse the Task will run on
--
-- Then run:
--   ./run.sh
-
-- =============================================================================

-- ── 1. External access ───────────────────────────────────────────────────────
USE SCHEMA <API-EAI-DB>.PUBLIC;

CREATE OR REPLACE NETWORK RULE fs_api_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('api.fullstory.com');

CREATE OR REPLACE SECRET fs_api_key
    TYPE = GENERIC_STRING
    SECRET_STRING = '<YOUR_FULLSTORY_SERVER_API_KEY>';

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION fs_api_access_integration
    ALLOWED_NETWORK_RULES          = (fs_api_network_rule)
    ALLOWED_AUTHENTICATION_SECRETS = (fs_api_key)
    ENABLED = TRUE;

-- ── 2. Procedure ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE push_static_user_properties(LIMIT_N NUMBER)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'main'
EXTERNAL_ACCESS_INTEGRATIONS = (fs_api_access_integration)
SECRETS = ('fs_api_key' = fs_api_key)
AS
$$
import json
import requests
import _snowflake

def main(session, limit_n):
    # this query just samples some users for demo purposes replace with logic to segment users that you want to set properties for
    rows = session.sql(f"""
        SELECT uid
        FROM <DATABASE>.<SCHEMA>.<USERS_TABLE>
        WHERE uid IS NOT NULL AND uid <> ''
        LIMIT {int(limit_n)}
    """).collect()

    if not rows:
        return {"status": "no_users_found"}

    users = [{
        "uid": r["UID"],
        "properties": {
            "warehouse_synced":       True,
            "warehouse_demo_cohort":  "luxury_car_interest",
            "warehouse_synced_at":    "2026-06-04",
        },
    } for r in rows]

    api_key = _snowflake.get_generic_secret_string("fs_api_key")
    resp = requests.post(
        "https://api.fullstory.com/v2/users/batch",
        headers={
            "Authorization": f"Basic {api_key}",
            "Content-Type":  "application/json",
        },
        data=json.dumps({"requests": users}),
        timeout=60,
    )
    return {
        "http_status": resp.status_code,
        "user_count":  len(users),
        "response":    resp.text[:500],
    }
$$;

-- ── 3. Run it ────────────────────────────────────────────────────────────────
CALL push_static_user_properties(10);
