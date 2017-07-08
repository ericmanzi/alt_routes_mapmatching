# allow bigint for id
set_id_type = "ALTER TABLE map_matched_segments ALTER COLUMN id TYPE numeric;"
set_id = "UPDATE map_matched_segments SET id=( ((((extract(epoch from created_at)+source_id+1)*(extract(epoch from created_at)+source_id)) / 2.0)+source_id) - (extract(epoch from start_time)-extract(epoch from end_time)) )/10000;"
set_pkey = "ALTER TABLE map_matched_segments ADD PRIMARY KEY (id);"
ActiveRecord::Base.connection.execute set_id_type
ActiveRecord::Base.connection.execute set_id
ActiveRecord::Base.connection.execute set_pkey

# set id and polyline
MapMatchedSegment.all.each do |s|
  s.set_polyline
end