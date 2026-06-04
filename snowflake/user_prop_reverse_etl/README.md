# Reverse-ETL: Snowflake → Fullstory

Push user data from Snowflake **back into Fullstory** as user properties using the [batch user import API](https://developer.fullstory.com/server/users/create-batch-user-import-job/). Useful when the data you want to act on in Fullstory — subscription tier, predicted churn, fraud score, an offer cohort — lives in your warehouse, not in Fullstory's event stream.

Two patterns are scaffolded here:

- [`one_time_push/`](./one_time_push/) — fire-and-forget push of a uid list + properties
- [`scheduled_push/`](./scheduled_push/) — incremental, stateful sync on a nightly cadence

Both share the same External Access Integration (network rule + secret + EAI) so the Snowflake stored proc can call `api.fullstory.com`. `one_time_push/` bootstraps those objects; `scheduled_push/` reuses them.

---

## When to use which

| Pattern | Use when |
|---|---|
| [One-time push](./one_time_push/) | The data doesn't change, or you're seeding a property for an upcoming launch |
| [Scheduled push](./scheduled_push/) | The data changes over time and Fullstory needs to reflect the current state |

### One-time push at a glance

A single stored proc, called once. Reads N uids, POSTs them with a hardcoded properties bag.

**Examples**: personalization cohort flags, coupon eligibility, backfilling a property on existing users after launching a new FS feature.

See [`one_time_push/README.md`](./one_time_push/README.md) for full setup.

### Scheduled push at a glance

A watermark table (`fs_sync_state`) + a stored proc that pulls only users whose `updated_at` is newer than the watermark + a Snowflake Task that runs the proc nightly. Chunked, resumable, memory-bounded.

**Examples**: dynamic segmentation (subscription tier, LTV bucket), churn-risk scores, propensity-to-buy, any property where stale data leads to bad targeting.

See [`scheduled_push/README.md`](./scheduled_push/README.md) for full setup.

---

## Shared prerequisites

- Snowflake account with `ACCOUNTADMIN` (required once to create the External Access Integration in `one_time_push/`)
- A **Fullstory server-side API key** with permission to import users
- `snow` CLI configured with a connection profile
- A Snowflake table with a `uid` column you can read from (and, for `scheduled_push/`, an `updated_at` column)

---

## Recommended bootstrap order

1. Run [`one_time_push/`](./one_time_push/) once — this creates the EAI + secret + network rule that both patterns use, and proves your API key works end-to-end.
2. Run [`scheduled_push/`](./scheduled_push/) when you want continuous sync. It reuses the EAI from step 1.
