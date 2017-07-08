
class AlternateRouteInterstateService
	# Calculate route parts which go through routes like I-X, I-X5, I-X10 (e.g.: I-35)
	# Routes that use I-x5 or I-x10 roads. these are three 1/0 dummy variables. for each route,
	# calculate from the road names the distance that uses I-x5 routes, I-x10 routes and both.
	# For each one if it is more than 33% of the route length, the value is one, and otherwise zero.
	# So, for example if a route is 20% on I-25 and I-35, 40% on I-40 and I-50,
	# the values will be 0 1 1 for I-x5 I-x10 an I-X, respectively.

	TYPES = {"I-X5" => "%I [0-9]{1}5[a-zA-Z]?[;]?%", "I-X10" => "%I [0-9]{1}0[a-zA-Z]?[;]?%"}
	THRESHOLD = 0.33

	def initialize(alternate_route)
		@route = alternate_route
	end

	def execute
		total_distance = @route.get_map_matched_mileage
		mileages = {}
		TYPES.keys.map{|t| mileages[t] = 0.0}
		TYPES.each do |key, value|
			mileages[key] = segments_mileage(@route.segments.where("name similar to '#{value}'"))
		end
		percentages = {}
		mileages.each do |key, value|
			percentages[key] = (value*100)/total_distance
		end
		percentages["I-X"] = percentages["I-X5"] + percentages["I-X10"]

		road_distribution = {}
		percentages.map{|k, v| road_distribution[k] = (v/100 > THRESHOLD) ? 1 : 0}
		puts "road_distribution:#{road_distribution}"
		puts "road_distribution_percent:#{percentages}"

		save_road_dist = "UPDATE alternate_routes SET road_distribution=hstore(ARRAY['#{road_distribution.keys.join("','")}'], ARRAY['#{road_distribution.values.join("','")}']) where id=#{@route[:id]};"
		save_road_perc = "UPDATE alternate_routes SET road_distribution_percent=hstore(ARRAY['#{percentages.keys.join("','")}'], ARRAY['#{percentages.values.join("','")}']) where id=#{@route[:id]};"
	
    	ActiveRecord::Base.connection.execute save_road_dist
    	ActiveRecord::Base.connection.execute save_road_perc

		# @route.update_attributes(road_distribution: road_distribution, road_distribution_percent: percentages)
	end

	private

	def segments_mileage(segments)
		mileage = 0.0
		segments.map{|s| mileage += s.length}
		mileage
	end
end