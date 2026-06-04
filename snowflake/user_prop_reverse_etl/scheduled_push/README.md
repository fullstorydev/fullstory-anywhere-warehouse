# Scheduled push — nightly incremental sync

Push only users whose `updated_at` changed since the last successful run, on a Snowflake Task cadence.

## Architecture

```
users table (with updated_at)
        │
        ▼
push_updated_user_properties()  ──►  POST /v2/users/batch
        │
        ├── reads watermark from fs_sync_state
        ├── selects rows where updated_at > watermark
        └── on HTTP 2xx, advances watermark to MAX(updated_at)
        ▲
        │
fs_user_props_nightly  (Snowflake Task, cron: 0 2 * * * UTC)
```

Three Snowflake objects:

- `fs_sync_state` — one row per sync (`sync_name`, `last_synced_at`). The high-water mark.
- `push_updated_user_properties()` — the proc. Reads watermark, pulls the delta, POSTs, advances watermark only on success.
- `fs_user_props_nightly` — the Task that calls the proc nightly.

## Prerequisites

- The External Access Integration from `one_time_push/` is already created (`fs_api_network_rule`, `fs_api_key`, `fs_api_access_integration`). This pattern reuses them.
- Your source users table has an `updated_at` column.
- A warehouse for the Task to run on.

## Run

```bash
cd scheduled_push
cp .env.example .env   # fill in values
./run.sh
```

Verify a run end-to-end without waiting for 02:00 UTC:

```sql
EXECUTE TASK fs_user_props_nightly;
SELECT * FROM fs_sync_state;
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(TASK_NAME => 'FS_USER_PROPS_NIGHTLY'));
```

## Notes

- **Failure semantics**: if a chunk POST fails (non-2xx, network error), the proc stops there. The watermark already reflects everything *previously* pushed in this run, so the next run resumes from the first failed chunk — no re-sending of already-confirmed users.
- **Watermark choice**: advanced to the `MAX(updated_at)` of each successful chunk, not `CURRENT_TIMESTAMP()`. Avoids skipping rows whose `updated_at` lands between read and update.
- **Chunking & memory**: rows are streamed via `to_local_iterator()` and POSTed in batches of `BATCH_SIZE` (default 1000). Memory is bounded by chunk size, not by total delta — 50k or 5M user deltas both work. Tune `BATCH_SIZE` against the Fullstory batch payload limit.
