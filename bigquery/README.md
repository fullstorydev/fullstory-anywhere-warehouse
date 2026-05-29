# Fullstory Warehouse Queries — BigQuery

SQL queries for working with Fullstory data exported to BigQuery.

## Structure

```
bigquery/
  starter-queries/
    ui-parity/    # Queries that replicate Fullstory UI metrics in the warehouse
```

## Getting Started

All queries use the placeholder `<project_id>.<dataset>` for your BigQuery project and dataset.
Replace this with your actual values before running (e.g. `my-project.fullstory_data`).

**Quick replace:** `Cmd+H` (Mac) or `Ctrl+H` (Windows/Linux) in your editor.

## Sections

### `starter-queries/`
Foundational queries to help you get familiar with the Fullstory data model and build confidence in your warehouse metrics.

- **`ui-parity/`** — Queries that match (or explain the differences from) what you see in the Fullstory UI
