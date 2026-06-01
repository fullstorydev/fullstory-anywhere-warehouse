# Purchase Funnel

Measures ordered session conversion across a 5-step purchase funnel using Fullstory event data in BigQuery.

## What it does

Counts sessions that progressed through each step in order (each step must occur after the previous one within the same session), then computes step-over-step and overall conversion rates.

| Step | Event type | Page / Event name |
|------|------------|-------------------|
| 1 | Page view | ProductPage or Search |
| 2 | Page view | Checkout Billing |
| 3 | Page view | Checkout Payment |
| 4 | Page view | Checkout Review |
| 5 | Custom event | Checkout Success |


## Query design

`purchase_funnel.sql` uses a single-scan approach: one `UNION ALL` pass tags all relevant events with a step number, a single `GROUP BY` computes the earliest timestamp per step per session, and boolean flags enforce ordering. This runs ~10x faster than the naive one-CTE-per-step approach (23s → 2.4s on ~11 GB, identical results).

The original query is preserved at the bottom of the file with an explanation of why it was replaced.


