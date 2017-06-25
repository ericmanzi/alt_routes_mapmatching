-- USE fmsurvey;

select 'start_time', 'end_time', 'encoded_points', 'travel_id', 'trip_distance', 'user_id' UNION
select i.start_time as starttime, i.end_time as endtime, t.encoded_points as encoded_points,
t.id as travel_id, t.trip_distance as trip_distance, i.user_id as user_id
from travels t join intervals i ON i.id=t.interval_id
where i.validated = 1 and i.deleted=0;