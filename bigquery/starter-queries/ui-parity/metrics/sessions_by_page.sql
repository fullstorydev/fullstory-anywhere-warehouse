-- CONFIGURATION: Replace <project_id>.<dataset> with your BigQuery project and dataset
-- Example: my-project.fullstory_data
-- To replace: Cmd+H (Mac) or Ctrl+H (Windows/Linux) → find `<project_id>.<dataset>` → replace with your value

-- This query computes the number of unique sessions that visited the '404 Page'
select
  count(distinct session_id) as sessions
from `<project_id>.<dataset>.events` e
join `<project_id>.<dataset>.source_properties` sp on e.id = sp.event_id
left join `<project_id>.<dataset>.page_definitions` pd on sp.page_definition_id = pd.id
where pd.name = '404 Page'
  -- this part is important to convert timezone to your local timezone
  -- by default the fullstory ui will use the local timezone and warehouse uses utc
  and DATE(e.event_time, 'America/Denver') = '2026-05-27'
