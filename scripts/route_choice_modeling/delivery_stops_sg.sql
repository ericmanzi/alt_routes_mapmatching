-- USE fmsurvey;

select 'start_time', 'end_time', 'lat', 'lon', 'stop_id', 'stop_activity', 'user_id', 'address', 'device_id' 
UNION select s.starttime as stop_starttime, s.endtime as stop_endtime, s.lat, s.lon, s.id as stop_id,
ans.help_text as stop_activity, i.user_id as user_id, s.address as stop_address, 
s.device_id as stop_device_id
from stops s
	JOIN intervals i ON i.id=s.interval_id JOIN response_sets rs ON rs.interval_id=i.id
	JOIN responses r ON r.response_set_id=rs.id JOIN answers ans ON ans.id=r.answer_id
	JOIN questions qn ON (ans.question_id=qn.id AND qn.common_identifier='freight_activity')
	where i.validated=1 and i.deleted = 0 and ans.help_text='Deliver cargo';