-- This SQL script queries the database for trips between 'pick up cargo' and 'deliver cargo' stops.
-- Results will be in the generated csv files under the directory /tmp/cargo_stops/
-- To execute run:
-- mkdir -p /tmp/cargo_stops/
-- mysql -uroot fmsurvey < cargo_stops.sql

USE fmsurvey;


-- -----------------------------------------------------------------------
-- get all pick up cargo stops
-- -----------------------------------------------------------------------
select 'start_time', 'end_time', 'lat', 'lon', 'stop_id', 'stop_activity', 'user_id', 'address', 'device_id' 
UNION select s.starttime as stop_starttime, s.endtime as stop_endtime, s.lat, s.lon, s.id as stop_id,
ans.help_text as stop_activity, i.user_id as user_id, s.address as stop_address, 
s.device_id as stop_device_id
from stops s
  	JOIN intervals i ON i.id=s.interval_id JOIN response_sets rs ON rs.interval_id=i.id
  	JOIN responses r ON r.response_set_id=rs.id JOIN answers ans ON ans.id=r.answer_id
  	JOIN questions qn ON (ans.question_id=qn.id AND qn.common_identifier = 'freight_activity')
    WHERE i.validated = 1 and i.deleted = 0
        and ans.help_text='Pick up cargo'
into outfile '/tmp/cargo_stops/pick_up_cargo_stops.csv'
fields terminated by ',' ENCLOSED BY '"' lines terminated by '\n';

-- -----------------------------------------------------------------------
-- get all deliver cargo stops
-- -----------------------------------------------------------------------
select 'start_time', 'end_time', 'lat', 'lon', 'stop_id', 'stop_activity', 'user_id', 'address', 'device_id' 
UNION select s.starttime as stop_starttime, s.endtime as stop_endtime, s.lat, s.lon, s.id as stop_id,
ans.help_text as stop_activity, i.user_id as user_id, s.address as stop_address, 
s.device_id as stop_device_id
from stops s
	JOIN intervals i ON i.id=s.interval_id JOIN response_sets rs ON rs.interval_id=i.id
	JOIN responses r ON r.response_set_id=rs.id JOIN answers ans ON ans.id=r.answer_id
	JOIN questions qn ON (ans.question_id=qn.id AND qn.common_identifier='freight_activity')
	WHERE i.validated=1 and i.deleted = 0 and ans.help_text='Deliver cargo'
into outfile '/tmp/cargo_stops/deliver_cargo_stops.csv'
fields terminated by ',' ENCLOSED BY '"' lines terminated by '\n';


-- -----------------------------------------------------------------------
-- get all other non-cargo stops
-- -----------------------------------------------------------------------
select 'start_time', 'end_time', 'lat', 'lon', 'stop_id', 'stop_activity', 'user_id', 'address', 'device_id' 
UNION select s.starttime as stop_starttime, s.endtime as stop_endtime, s.lat, s.lon, s.id as stop_id,
ans.help_text as stop_activity, i.user_id as user_id, s.address as stop_address, 
s.device_id as stop_device_id
from stops s
	JOIN intervals i ON i.id=s.interval_id JOIN response_sets rs ON rs.interval_id=i.id
	JOIN responses r ON r.response_set_id=rs.id JOIN answers ans ON ans.id=r.answer_id
	JOIN questions qn ON (ans.question_id=qn.id AND qn.common_identifier='freight_activity')
	WHERE i.validated=1 and i.deleted = 0 
	and qn.text='Fueling - how much?'
	-- and ans.help_text not in ('Deliver cargo', 'Pick up cargo', 'Start/end my shift, change driver')
-- into outfile '/tmp/cargo_stops/other_stops.csv'
-- fields terminated by ',' ENCLOSED BY '"' lines terminated by '\n';

-- -----------------------------------------------------------------------
-- get all travels
-- -----------------------------------------------------------------------
select 'start_time', 'end_time', 'encoded_points', 'travel_id', 'trip_distance', 'user_id' UNION
select i.start_time as starttime, i.end_time as endtime, t.encoded_points as encoded_points,
t.id as travel_id, t.trip_distance as trip_distance, i.user_id as user_id
from travels t join intervals i ON i.id=t.interval_id
where i.validated = 1 and i.deleted=0
into outfile '/tmp/cargo_stops/travels.csv'
fields terminated by ',' ENCLOSED BY '"' lines terminated by '\n';


