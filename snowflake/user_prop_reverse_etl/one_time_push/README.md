# One-time push — single batch of user properties

Fire-and-forget push of a uid list + a hardcoded properties bag to Fullstory's [batch user import API](https://developer.fullstory.com/server/users/create-batch-user-import-job/). Run it once and you're done.

## Architecture

```
users table
    │
    ▼
push_static_user_properties(LIMIT_N)  ──►  POST /v2/users/batch
```

Three Snowflake objects (all in `<EAI_DATABASE>.PUBLIC`):

- `fs_api_network_rule` — egress rule allowing calls to `api.fullstory.com`
- `fs_api_key` — generic-string secret holding your FS server API key
- `fs_api_access_integration` — wires the network rule + secret together
- `push_static_user_properties(LIMIT_N)` — the proc. Reads `LIMIT_N` uids and POSTs them with a static properties bag.

The first three are reused by [`scheduled_push/`](../scheduled_push/), so this folder is also the right place to bootstrap them once.

## Use cases

- **Personalization** — flag a cohort (e.g. `early_access: true`) so Fullstory experiences can target them
- **Coupon / offer eligibility** — mark users who qualify for a promo
- **Backfilling** a property on existing users after launching a new Fullstory feature

## Prerequisites

- `ACCOUNTADMIN` (or a role with `CREATE INTEGRATION`) — required once to create the EAI
- A **Fullstory server-side API key** with permission to import users
- `snow` CLI configured with a connection profile
- A Snowflake table with a `uid` column

## Run

```bash
cd one_time_push
cp .env.example .env   # fill in FS_API_KEY, FS_USERS_TABLE, EAI_DATABASE, SNOW_CONN
./run.sh
```

`run.sh` substitutes the placeholders in `simple_batch.sql` from `.env` and pipes the result to `snow sql`. A successful run returns HTTP 200 with a job id you can verify against the FS API (see "Verify" below).

## What to edit before running for real

The properties bag is hardcoded in `simple_batch.sql` for demo purposes:

```python
"properties": {
    "warehouse_synced":       True,
    "warehouse_demo_cohort":  "luxury_car_interest",
    "warehouse_synced_at":    "2026-06-04",
},
```

Change those keys/values (and the `LIMIT_N` argument at the bottom — `CALL push_static_user_properties(10);`) to whatever you want pushed.

## Verify

The batch user import API is asynchronous — HTTP 200 means "job accepted," not "applied." After the run:

1. Grab the `job.id` from the proc's return value
2. Poll `GET https://api.fullstory.com/v2/users/batch/<JOB_ID>` until `status` is `COMPLETED`
3. Look up one of the pushed uids in Fullstory to confirm the properties landed
