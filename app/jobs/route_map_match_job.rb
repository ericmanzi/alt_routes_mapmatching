# Alternate Route Map Maptch Job

start_idx = ARGV[0].to_i
end_idx = ARGV[1].to_i

puts "Start: #{start_idx}, End: #{end_idx}"

alternate_routes = ActiveRecord::Base.connection.select_all("select * from alternate_routes where id < #{end_idx} and id >= #{start_idx};").to_a

alternate_routes.each do |alternate_route| 
  Delayed::Job.enqueue RouteMapMatchService.new.execute(alternate_route), :queue => "general"
end

