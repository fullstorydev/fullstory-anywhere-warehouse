-- CONFIGURATION: Replace <project-id>.<dataset> with your BigQuery project and dataset
-- Example: my-project.fullstory_data
-- To replace: Cmd+H (Mac) or Ctrl+H (Windows/Linux) → find `<project-id>.<dataset>` → replace with your value

-- Purchase Funnel (5 steps)
--
-- Step 1: ProductPage or Search        (page_definitions)
-- Step 2: Checkout Billing             (page_definitions)
-- Step 3: Checkout Payment             (page_definitions)
-- Step 4: Checkout Review              (page_definitions)
-- Step 5: Checkout Success             (custom_events)
--
-- Note: page names and custom events are configured uniquely for each org these are just used for an example purchase funnel please replace with your org specific configuration
with funnel_events as (

  -- Steps 1–4: page-based, joined through source_properties → page_definitions
  select
    e.user_id,
    e.session_id,
    e.event_time,
    case
      when pd.name in ('ProductPage', 'Search') then 1
      when pd.name = 'Checkout Billing'         then 2
      when pd.name = 'Checkout Payment'         then 3
      when pd.name = 'Checkout Review'          then 4
    end as funnel_step
  from `<project-id>.<dataset>.events` e
  join `<project-id>.<dataset>.source_properties` sp on e.id = sp.event_id
  join `<project-id>.<dataset>.page_definitions` pd   on sp.page_definition_id = pd.id
  where date(e.event_time, 'America/Denver') = '2026-05-31'
    and pd.name in ('ProductPage', 'Search', 'Checkout Billing', 'Checkout Payment', 'Checkout Review')

  union all

  -- Step 5: custom event, joined through custom_events
  select
    e.user_id,
    e.session_id,
    e.event_time,
    5 as funnel_step
  from `<project-id>.<dataset>.events` e
  join `<project-id>.<dataset>.custom_events` ce on e.id = ce.event_id
  where date(e.event_time, 'America/Denver') = '2026-05-31'
    and ce.event_name = 'Checkout Success'

),

session_steps as (
  -- Per session: earliest timestamp reached for each funnel step
  select
    user_id,
    session_id,
    min(case when funnel_step = 1 then event_time end) as stp1_time,
    min(case when funnel_step = 2 then event_time end) as stp2_time,
    min(case when funnel_step = 3 then event_time end) as stp3_time,
    min(case when funnel_step = 4 then event_time end) as stp4_time,
    min(case when funnel_step = 5 then event_time end) as stp5_time
  from funnel_events
  group by user_id, session_id
),

funnel_sessions as (
  -- Only sessions that entered at step 1; flag each subsequent step as ordered progression
  select
    user_id,
    session_id,
    stp1_time,
    stp2_time is not null and stp2_time > stp1_time                            as reached_stp2,
    stp3_time is not null and stp3_time > stp2_time and stp2_time > stp1_time  as reached_stp3,
    stp4_time is not null and stp4_time > stp3_time and stp3_time > stp2_time
                          and stp2_time > stp1_time                            as reached_stp4,
    stp5_time is not null and stp5_time > stp4_time and stp4_time > stp3_time
                          and stp3_time > stp2_time and stp2_time > stp1_time  as reached_stp5
  from session_steps
  where stp1_time is not null
)

select
  count(distinct session_id)                                                              as stp1_sessions,
  countif(reached_stp2)                                                                   as stp2_sessions,
  countif(reached_stp3)                                                                   as stp3_sessions,
  countif(reached_stp4)                                                                   as stp4_sessions,
  countif(reached_stp5)                                                                   as stp5_sessions,

  -- Conversion rates relative to the previous step
  round(safe_divide(countif(reached_stp2), count(distinct session_id)) * 100, 1)         as stp1_to_stp2_pct,
  round(safe_divide(countif(reached_stp3), countif(reached_stp2))      * 100, 1)         as stp2_to_stp3_pct,
  round(safe_divide(countif(reached_stp4), countif(reached_stp3))      * 100, 1)         as stp3_to_stp4_pct,
  round(safe_divide(countif(reached_stp5), countif(reached_stp4))      * 100, 1)         as stp4_to_stp5_pct,

  -- Overall conversion: step 1 → step 5
  round(safe_divide(countif(reached_stp5), count(distinct session_id)) * 100, 1)         as overall_pct
from funnel_sessions;


-- =============================================================================
-- V1: ORIGINAL QUERY (kept for reference)
-- =============================================================================
--
-- The original approach used one CTE per funnel step, each independently
-- scanning the events table and joining source_properties + page_definitions.
-- Steps were chained via correlated subqueries:
--
--   and e.session_id in (select session_id from stp_N where stp_N_time < e.event_time)
--
-- This caused BigQuery to re-evaluate the subquery per row, and the final
-- SELECT re-materialized every CTE up to 10 times for the scalar subqueries.
--
-- Result on the same dataset (2026-05-31, ~11 GB scanned):
--   V1: 23.3 seconds
--   V2: 2.4 seconds  (~10x faster, same bytes scanned, identical results)
--
-- The speedup comes from V2's single-scan + single-aggregation approach —
-- not from caching (bytes processed were identical in both runs).
--
-- =============================================================================

-- with stp1_pdp_search as (
--   select
--     e.user_id,
--     e.session_id,
--     min(e.event_time) as stp1_time
--   from <project-id>.<dataset>.events e
--   join <project-id>.<dataset>.source_properties sp on e.id = sp.event_id
--   join <project-id>.<dataset>.page_definitions pd   on sp.page_definition_id = pd.id
--   where date(e.event_time, 'America/Denver') = '2026-05-31'
--     and pd.name in ('ProductPage', 'Search')
--   group by e.user_id, e.session_id
-- ),
--
-- stp2_checkout_billing as (
--   select
--     e.user_id,
--     e.session_id,
--     min(e.event_time) as stp2_time
--   from <project-id>.<dataset>.events e
--   join <project-id>.<dataset>.source_properties sp on e.id = sp.event_id
--   join <project-id>.<dataset>.page_definitions pd   on sp.page_definition_id = pd.id
--   where date(e.event_time, 'America/Denver') = '2026-05-31'
--     and pd.name = 'Checkout Billing'
--     and e.session_id in (select session_id from stp1_pdp_search where stp1_time < e.event_time)
--   group by e.user_id, e.session_id
-- ),
--
-- stp3_checkout_payment as (
--   select
--     e.user_id,
--     e.session_id,
--     min(e.event_time) as stp3_time
--   from <project-id>.<dataset>.events e
--   join <project-id>.<dataset>.source_properties sp on e.id = sp.event_id
--   join <project-id>.<dataset>.page_definitions pd   on sp.page_definition_id = pd.id
--   where date(e.event_time, 'America/Denver') = '2026-05-31'
--     and pd.name = 'Checkout Payment'
--     and e.session_id in (select session_id from stp2_checkout_billing where stp2_time < e.event_time)
--   group by e.user_id, e.session_id
-- ),
--
-- stp4_checkout_review as (
--   select
--     e.user_id,
--     e.session_id,
--     min(e.event_time) as stp4_time
--   from <project-id>.<dataset>.events e
--   join <project-id>.<dataset>.source_properties sp on e.id = sp.event_id
--   join <project-id>.<dataset>.page_definitions pd   on sp.page_definition_id = pd.id
--   where date(e.event_time, 'America/Denver') = '2026-05-31'
--     and pd.name = 'Checkout Review'
--     and e.session_id in (select session_id from stp3_checkout_payment where stp3_time < e.event_time)
--   group by e.user_id, e.session_id
-- ),
--
-- stp5_checkout_success as (
--   select
--     e.user_id,
--     e.session_id,
--     min(e.event_time) as stp5_time
--   from <project-id>.<dataset>.events e
--   join <project-id>.<dataset>.custom_events ce on e.id = ce.event_id
--   where date(e.event_time, 'America/Denver') = '2026-05-31'
--     and ce.event_name = 'Checkout Success'
--     and e.session_id in (select session_id from stp4_checkout_review where stp4_time < e.event_time)
--   group by e.user_id, e.session_id
-- )
--
-- select
--   (select count(distinct session_id) from stp1_pdp_search)       as stp1_sessions,
--   (select count(distinct session_id) from stp2_checkout_billing)  as stp2_sessions,
--   (select count(distinct session_id) from stp3_checkout_payment)  as stp3_sessions,
--   (select count(distinct session_id) from stp4_checkout_review)   as stp4_sessions,
--   (select count(distinct session_id) from stp5_checkout_success)  as stp5_sessions,
--
--   round(safe_divide((select count(distinct session_id) from stp2_checkout_billing),  (select count(distinct session_id) from stp1_pdp_search))      * 100, 1) as stp1_to_stp2_pct,
--   round(safe_divide((select count(distinct session_id) from stp3_checkout_payment),  (select count(distinct session_id) from stp2_checkout_billing)) * 100, 1) as stp2_to_stp3_pct,
--   round(safe_divide((select count(distinct session_id) from stp4_checkout_review),   (select count(distinct session_id) from stp3_checkout_payment))  * 100, 1) as stp3_to_stp4_pct,
--   round(safe_divide((select count(distinct session_id) from stp5_checkout_success),  (select count(distinct session_id) from stp4_checkout_review))   * 100, 1) as stp4_to_stp5_pct,
--
--   round(safe_divide((select count(distinct session_id) from stp5_checkout_success),  (select count(distinct session_id) from stp1_pdp_search))        * 100, 1) as overall_pct;
