class AlternateRoute < ActiveRecord::Base
	attr_accessible :summary, :polyline, :distance, :duration, :duration_traffic, :avoid_tolls,
					:provider, :toll_costs, :highest_overlap, :num_points, :trip_id, :original_duration,
					:clazz, :min_duration_traffic, :max_duration_traffic, :road_classification,
					:speed_classification, :path_sizes, :path_sizes_v2, :path_sizes_v3, :provider_distribution,
					:road_distribution, :road_distribution_percent,
					:user_id

	has_many :map_matched_segments, -> { order(:end_time) }, :dependent => :destroy
	# belongs_to :cargo_trip #, :counter_cache => true
	# has_many :alternate_route_legs, :dependent => :destroy
	# has_many :toll_crossings, as: :route
	# has_many :toll_payments, :through => :toll_crossings

	def set_mapmatched_polyline
		points = []
		self.segments.pluck(:geom_way).each do |segment|
		  JSON.parse(segment)["coordinates"].to_a.each do |c|
		    points << [c[1], c[0]]
		  end
		end
		self.map_matched_polyline = Polylines::Encoder.encode_points(points)
	end

	# def find_tolls
	# 	tolls = []
	# 	self.segments.find_each do |segment|
	# 	  tolls = Toll.where(:osm_node_id => [segment.source_id, segment.target_id]).limit(1)
	# 	  tolls.each do |toll|
	# 	    # puts "Found toll: " + toll.to_json
	# 	    tmp = TollCrossing.new(:osm_node_id => toll.osm_node_id, :timestamp => segment.start_time, :toll_id => toll.id)
	# 	    tolls << tmp
	# 	  end
	# 	end
	# 	tolls
	# end

	# def find_tolls
	# 	toll_crossings = []
	# 	sources = self.segments.pluck(:source_id)
	# 	target_sources_diff = self.segments.pluck(:target_id) - sources

	# 	tolls = Toll.where(:osm_node_id => sources)
	# 	tolls.each do |toll|
	# 	  segments = self.segments.where("source_id = ?", toll.osm_node_id)
	# 	  segments.each do |segment|
	# 	    toll_crossings << TollCrossing.new(:osm_node_id => toll.osm_node_id, :timestamp => segment.start_time, :toll_id => toll.id, :route_id => self.id)
	# 	  end
	# 	end

	# 	if !target_sources_diff.nil?
	# 	  tolls = Toll.where(:osm_node_id => target_sources_diff)
	# 	  tolls.each do |toll|
	# 	    segments = self.segments.where("target_id = ?", toll.osm_node_id)
	# 	    segments.each do |segment|
	# 	      toll_crossings << TollCrossing.new(:osm_node_id => toll.osm_node_id, :timestamp => segment.start_time, :toll_id => toll.id, :route_id => self.id)
	# 	    end
	# 	  end
	# 	end

	# 	toll_crossings.each do |t|
	# 	  toll = self.toll_crossings.where(:osm_node_id => t.osm_node_id, :toll_id => t.toll_id, :timestamp => t.timestamp, :route_id => t.route_id)
	# 	  if toll.empty? and !t.timestamp.nil?
	# 	    t.route = self
	# 	    t.save
	# 	  end
	# 	end
	# end

	# def get_cost
	# 	self.toll_payments.map{|p| p.toll_fee.amount}.sum
	# end

	def get_map_matched_mileage
		distance = 0.0
		segments.each do |segment|
			distance += segment.length
		end
		distance > 0.0 ? distance : mileage
	end
end
