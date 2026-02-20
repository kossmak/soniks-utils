with stat as (
SELECT
  count(o.id) qty
  , o.station_id
FROM public.observations o
where
  o.observation_status = 'FUTURE'::observation_status_enum
group by
  o.station_id
ORDER BY qty desc
LIMIT 20
)
select
  t.*
from
  observations t
  inner join stat s
   on t.station_id = s.station_id
where
  t.observation_status = 'FUTURE'::observation_status_enum
order by
  s.qty desc
  , t.station_id
  , t.start_time

