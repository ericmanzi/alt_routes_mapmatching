class MapMatchedSegment < ActiveRecord::Base
	# attr_accessible :edge_id, :osm_way_id, :end_time, :geom_way, :source_id, :user_id, :start_time, :target_id, :polyline, :name, :position, :mph, :clazz, :flags, :alternate_route_id
	attr_accessor :edge_id, :osm_way_id, :end_time, :geom_way, :source_id, :user_id, :start_time, :target_id, :polyline, :name, :position, :mph, :clazz, :flags, :alternate_route_id
	
	def set_polyline
	  points = []
	  if !self[:geom_way].nil?
	    JSON.parse(self[:geom_way])["coordinates"].each do |c|
	        points << [c[1], c[0]]
	        puts "points: #{points}"
	    end
	    # self.polyline = GMapPolylineEncoder.new().encode(points)[:points]
	    self.polyline = Polylines::Encoder.encode_points(points)
	    self.save
	  end
	end

	def length
	  distance = 0.0
	  begin
	    points = JSON.parse(self.geom_way)["coordinates"]
	    for i in 1..(points.size-1)
	      distance += distance_between(points[i-1], points[i])
	    end
	  rescue
	    return distance
	  end
	  distance
	end

	def type
	  TYPES[clazz]
	end

	TYPES = {
	  1 => "route.ferry",
	  2 => "route.shuttle_train",
	  3 => "railway.rail",
	  11 => "highway.motorway",
	  12 => "highway.motorway_link",
	  13 => "highway.trunk",
	  14 => "highway.trunk_link",
	  15 => "highway.primary",
	  16 => "highway.primary_link",
	  21 => "highway.secondary",
	  22 => "highway.secondary_link",
	  31 => "highway.tertiary",
	  32 => "highway.residential",
	  41 => "highway.road",
	  42 => "highway.unclassified",
	  51 => "highway.service",
	  62 => "highway.pedestrian",
	  63 => "highway.living_street",
	  71 => "highway.track",
	  72 => "highway.path",
	  81 => "highway.cycleway",
	  91 => "highway.footway",
	  92 => "highway.steps"
	}

	def distance_between(a, b)
	  dtor = Math::PI/180
	  r = 6378.14#*1000 # Commented out to return distance in km

	  rlat1 = a[1].to_f * dtor
	  rlong1 = a[0].to_f * dtor
	  rlat2 = b[1].to_f * dtor
	  rlong2 = b[0].to_f * dtor

	  dlon = rlong1 - rlong2
	  dlat = rlat1 - rlat2

	  a = (Math::sin(dlat/2) ** 2) + Math::cos(rlat1) * Math::cos(rlat2) * (Math::sin(dlon/2) ** 2)
	  c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))
	  d = r * c

	  return d # in km, * 0.621371192 to Return the result in Miles...
	end

end