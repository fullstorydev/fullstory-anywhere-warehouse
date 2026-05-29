-- CONFIGURATION: Replace <project_id>.<dataset> with your BigQuery project and dataset

-- Youll notice there are multiple defintions of a user in the warehouse data
-- events.user_id is a fullstory defined device id that persist acrossed sessions on the same device
-- users.uid is set via fullstory API FS('setIdentity', { uid, properties }) usually after a user logins and can span across devices
-- Neither of these will match what fullstory UI shows because the UI will be a combination of both of them
-- it counts distinct uid but if that is not set it will defualt to user_id
select
 count(distinct user_id) as cnt_user_id,
 count(distinct uid) as cnt_uid,
from `<project_id>.<dataset>.events` e
 join `<project_id>.<dataset>.users` u on e.user_id = u.id
where
 date(event_time, 'America/Denver') = '2026-05-28';


-- This is a simplified version of what the UI is doing in the backend
with user_session as (
  select 
    session_id,
    max(e.user_id) as user_id,
    max(u.uid) as uid
  from `<project_id>.<dataset>.events` e 
  join `<project_id>.<dataset>.users` u on e.user_id = u.id 
  where date(event_time, 'America/Denver') = '2026-05-27'
  group by session_id  
  )
  
select
  count(distinct coalesce(uid, user_id)) as cnt_users
from user_session; 

-- If you have any ids stored in user properties you can get parity between warehouse and what you see in the fullstory UI
select
 count(distinct up.enterpriseID) as cnt_enterpriseID_id
from
  `<project_id>.<dataset>.events` e
  join `<project_id>.<dataset>.user_properties` up on e.user_id = up.user_id
where up.enterpriseID is not null
and date(event_time, 'America/Denver') = '2026-05-28';

