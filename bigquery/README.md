# Fullstory Warehouse Queries — BigQuery

SQL queries for working with Fullstory data exported to BigQuery.

## Structure

```
bigquery/
  starter-queries/
    ui-parity/          # Queries that replicate Fullstory UI metrics in the warehouse
      metrics/          # Point-in-time counts and session metrics
      funnels/          # Ordered conversion funnel queries
```

## Getting Started

All queries use the placeholder `<project_id>.<dataset>` for your BigQuery project and dataset.
Replace this with your actual values before running (e.g. `my-project.fullstory_data`).

**Quick replace:** `Cmd+H` (Mac) or `Ctrl+H` (Windows/Linux) in your editor, or `:%s/<project_id>.<dataset>/my-project.fullstory_data/g` in vim/vi.

## Sections

### `starter-queries/`
Foundational queries to help you get familiar with the Fullstory data model and build confidence in your warehouse metrics.

- **`ui-parity/`** — Queries that match (or explain the differences from) what you see in the Fullstory UI
  - **`metrics/`** — Point-in-time counts and session metrics (`sessions_by_page.sql`, `user_counts.sql`)
  - **`funnels/`** — Ordered conversion funnel queries (`purchase_funnel.sql`)
