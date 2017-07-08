# alternate_routes = ActiveRecord::Base.connection.select_all("select * from alternate_routes;")
alternate_routes = AlternateRoute.order(:id)

start_idx = ARGV[0].to_i
end_idx = ARGV[1].to_i

alternate_routes[start_idx..end_idx].each do |alternate_route| 	
  puts "Running road class calculation for alternate route #{alternate_route['id']}"
  RoadClassCalculatorService.new(alternate_route).execute
  puts "---"
end

alternate_routes[start_idx..end_idx].each do |alternate_route| 	
  puts "Running route distribution calculation for alternate route #{alternate_route['id']}"
  AlternateRouteInterstateService.new(alternate_route).execute
  puts "---"
end

