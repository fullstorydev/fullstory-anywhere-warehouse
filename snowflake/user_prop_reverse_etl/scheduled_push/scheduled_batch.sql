-- =============================================================================
-- Scheduled nightly sync: push only users updated since the last successful run
-- =============================================================================
--   1. A tiny watermark table tracks the last successfully-synced timestamp
--   2. A stored proc reads users where updated_at > watermark and POSTs them
--      to /v2/users/batch. On HTTP success it advances the watermark.
--   3. A Snowflake Task calls the proc on a nightly cron.
--
-- Assumes the External Access Integration from one_time_push/ already exists
-- (fs_api_network_rule, fs_api_key, fs_api_access_integration in <API-EAI-DB>.PUBLIC).
--
-- Your source users table must have an UPDATED_AT column (TIMESTAMP_NTZ/TZ).
--
-- Before running, the placeholders below are replaced by run.sh from .env:
--   <API-EAI-DB>                            DB.SCHEMA where EAI objects live
--   <DATABASE>.<SCHEMA>.<USERS_TABLE>       source of uids + updated_at
--   <WAREHOUSE>                             warehouse the Task will run on
--
-- Then run:
--   ./run.sh
-- =============================================================================

USE SCHEMA <API-EAI-DB>.PUBLIC;

-- ── 1. Watermark table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fs_sync_state (
    sync_name       STRING       PRIMARY KEY,
    last_synced_at  TIMESTAMP_NTZ
);

MERGE INTO fs_sync_state t
USING (SELECT 'user_props' AS sync_name, '1970-01-01'::TIMESTAMP_NTZ AS last_synced_at) s
ON t.sync_name = s.sync_name
WHEN NOT MATCHED THEN INSERT (sync_name, last_synced_at) VALUES (s.sync_name, s.last_synced_at);

-- ── 2. Procedure ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE push_updated_user_properties()
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

SYNC_NAME  = 'user_props'
BATCH_SIZE = 1000   # users per POST; stays well under the FS batch payload limit

def main(session):
    last = session.sql(
        f"SELECT last_synced_at FROM fs_sync_state WHERE sync_name = '{SYNC_NAME}'"
    ).collect()[0][0]

    api_key = _snowflake.get_generic_secret_string("fs_api_key")
    headers = {"Authorization": f"Basic {api_key}", "Content-Type": "application/json"}

    def post(chunk):
        return requests.post(
            "https://api.fullstory.com/v2/users/batch",
            headers=headers,
            data=json.dumps({"requests": chunk}),
            timeout=60,
        )

    def advance(ts):
        session.sql(
            f"UPDATE fs_sync_state SET last_synced_at = '{ts}' "
            f"WHERE sync_name = '{SYNC_NAME}'"
        ).collect()

    row_iter = session.sql(f"""
        SELECT uid, loyalty_tier, updated_at
        FROM <DATABASE>.<SCHEMA>.<USERS_TABLE>
        WHERE uid IS NOT NULL AND uid <> ''
          AND updated_at > '{last}'
        ORDER BY updated_at
    """).to_local_iterator()

    chunk, chunk_max_ts = [], None
    users_pushed, chunks_pushed = 0, 0

    def flush():
        nonlocal chunk, users_pushed, chunks_pushed
        resp = post(chunk)
        if not (200 <= resp.status_code < 300):
            return resp  # caller handles failure
        advance(chunk_max_ts)
        users_pushed  += len(chunk)
        chunks_pushed += 1
        chunk = []
        return None

    for r in row_iter:
        chunk.append({
            "uid": r["UID"],
            "properties": {
                "loyalty_tier":        r["LOYALTY_TIER"],
                "warehouse_synced_at": str(r["UPDATED_AT"]),
            },
        })
        chunk_max_ts = r["UPDATED_AT"] # older updates first, if we fail in a chunk next scheduled run will pick up where we left off

        if len(chunk) >= BATCH_SIZE:
            failed = flush()
            if failed is not None:
                return {
                    "status":             "failed_mid_run",
                    "http_status":        failed.status_code,
                    "chunks_pushed":      chunks_pushed,
                    "users_pushed":       users_pushed,
                    "previous_watermark": str(last),
                    "response":           failed.text[:500],
                }

    if chunk:
        failed = flush()
        if failed is not None:
            return {
                "status":             "failed_on_final_chunk",
                "http_status":        failed.status_code,
                "chunks_pushed":      chunks_pushed,
                "users_pushed":       users_pushed,
                "previous_watermark": str(last),
                "response":           failed.text[:500],
            }

    if users_pushed == 0:
        return {"status": "no_updates", "last_synced_at": str(last)}

    return {
        "status":             "ok",
        "chunks_pushed":      chunks_pushed,
        "users_pushed":       users_pushed,
        "previous_watermark": str(last),
        "new_watermark":      str(chunk_max_ts),
    }
$$;

-- ── 3. Task: nightly at 02:00 UTC ────────────────────────────────────────────
CREATE OR REPLACE TASK fs_user_props_nightly
    WAREHOUSE = <WAREHOUSE>
    SCHEDULE  = 'USING CRON 0 2 * * * UTC'
AS
    CALL push_updated_user_properties();

ALTER TASK fs_user_props_nightly RESUME;

-- Optional: kick it once now to verify end-to-end.
-- EXECUTE TASK fs_user_props_nightly;
