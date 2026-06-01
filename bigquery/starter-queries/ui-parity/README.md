# UI Parity Queries

These queries reproduce metrics from the Fullstory UI using raw warehouse data. The goal is to establish a baseline and build confidence that your warehouse data aligns with what you see in the product before building more complex analyses.

## Configuration

Replace `<project-id>.<dataset>` with your BigQuery project and dataset in each query.

Example: `my-project.fullstory_data`

To replace: **Cmd+H** (Mac) or **Ctrl+H** (Windows/Linux) → find `<project-id>.<dataset>` → replace with your value.

## Queries

### Metrics

| File | Description | UI Metric|
|------|--------------| -------------|
| `metrics/sessions_by_page.sql` | Sessions count filtered by page definition | Unique Sessions |
| `metrics/user_counts.sql` | Explains the multiple ways to count users and difference in UI | Unique Users & Unique Property|

### Funnels

| File | Description | UI Metric |
|------|-------------|-----------|
| `funnels/purchase_funnel.sql` | Ordered session conversion across a multi-step purchase funnel | Funnel |

## Key Gotchas

### Timezone
The Fullstory UI displays times in your local timezone. Warehouse data is stored in UTC. All queries use `DATE(event_time, 'America/Denver')` as an example — replace with your timezone.

### User Counts
User counts are the hardest metric to replicate exactly. The Fullstory UI counts users by `uid` (your identity, set via `FS('setIdentity', ...)`) when available, and falls back to a device-based `user_id` when not. 

See `user_counts.sql` for a breakdown of the three user identity concepts in the warehouse and an approximation of the UI's counting logic.

### Page Definitions
The Fullstory UI uses named page definitions (e.g. "404 Page") that map URL patterns to friendly names. In the warehouse, these are stored in the `page_definitions` table and joined via `source_properties.page_definition_id`.
