# allow bigint for id
set_id_type = "ALTER TABLE map_matched_segments ALTER COLUMN id TYPE numeric;"
set_id = "UPDATE map_matched_segments SET id=(((extract(epoch from created_at)+source_id+1)*(extract(epoch from created_at)+source_id))/2.0)+source_id;"
set_pkey = "ALTER TABLE map_matched_segments ADD PRIMARY KEY (id);"
ActiveRecord::Base.connection.execute set_id_type
ActiveRecord::Base.connection.execute set_id
ActiveRecord::Base.connection.execute set_pkey

# set id and polyline
MapMatchedSegment.all.each do |s|
  s.set_polyline
end

# alternate_routes = ActiveRecord::Base.connection.select_all("select * from alternate_routes;")
alternate_routes = AlternateRoute.all

start_idx = ARGV[0].to_i
end_idx = ARGV[1].to_i

alternate_routes[start_idx..end_idx].each do |alternate_route| 	
  puts "Running road class calculation for alternate route #{alternate_route['id']}"
  RoadClassCalculatorService.new.execute(alternate_route)
end