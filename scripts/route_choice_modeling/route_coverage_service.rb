class RouteCoverageService
  attr_accessor :trip, :route, :trip_segment_ids, :segment_ids, :coverage

	def initialize(route)
		@route = route
    @segment_ids = @route.segments.map{|r| r.osm_way_id}
	end

	def execute
    if !@route.nil?
      extract_trip_features
      calculate_intersection_distance
      puts "[#{@route.id}] Original Mileage: #{@mileage}"
      puts "[#{@route.id}] Alternate Route Mileage: #{@route.mileage}"
      puts "[#{@route.id}] Alternate Route Common Mileage: #{@distance}"
      puts "[#{@route.id}] Coverage: #{@overlap}%"
      @route.overlap = @overlap
      # @route.path_size = calculate_path_size
      # puts "[#{@route.id}] Path size: #{@route.path_size}%"
      @route.save
      # puts "Segments on the chosen route and not in the generated one: #{calculate_trip_only_coverage}%"
      # puts "Segments on the generated route and not in the chosen one: #{calculate_trip_specific_coverage}%"
    end
	end

  # Path Size
  # Initialize path size at 0.0
  # iterate over the segments in the route. For each segment on route:
    # Calculate path impedance (segment length / route total length)
    # Get sibling routes (routes generated from the same observation)
    # initialize sum = 1
    # iterate the siblig routes. For each sibling route (not including the main route) where the segment is used
      # Calculate main route length / sibling route length (Li/Lj)
      # sum += (li/lj)^ gamma
    # end
    # path size += (impedance of current segment) * 1.0 / sum
  # end

  # Initialize path size at 0.0
  # iterate over the segments in the route. For each segment on route:
  #   Calculate path impedance (segment length / route total lenght)
  #   Get sibling routes (routes generated from the same observation)
  #   initialize sum = 1
  #   iterate the siblig routes. For each sibling route (not including the main route) where the segment is used
  #     Calculate main route length / sibling route length (Li/Lj)
  #     if (li/lj)>1, sum = 0. otherwise, do nothing
  #   end
  #   path size += (impedance of current segment) * sum (note that this is a multiplying by sum now, not dividing)
  # end

  def calculate_path_size
    t0 = Time.now
    path_sizes = {0 => 0.0, 1 => 0.0, 2 => 0.0, 4 => 0.0, 10 => 0.0, Float::INFINITY => 0.0}

    # Retrieves all routes provenient from the same trip
    sibling_routes = AlternateRoute.where(:trip_id => @route.trip_id)#.where("state != 'discarded'")

    # Get segment-based mileage for all sibling routes
    sibling_routes_mileage = calculate_routes_mileage(sibling_routes)

    # Remove the main route from sibling routes group
    sibling_routes = (sibling_routes.map{|r| r.id} - [@route.id])

    # Generate frequencies of each route segment over alternate routes
    frequencies = {}
    appearances = Segment.where(:osm_way_id => @segment_ids).group_by {|s| s.osm_way_id}
    appearances.each do |k, v|
      frequencies[k] = v.map{|e| e.alternate_route_id}.uniq - [nil]
    end

    @route.segments.each do |segment|
      segment_length = segment.length

      impedance = segment_length/sibling_routes_mileage[@route.id]

      # Get all sibling routes where the current segment is used
      ocurrences = frequencies[segment.osm_way_id] & sibling_routes
      #ocurrences = AlternateRoute.joins(:segments).where(:id => sibling_routes).where("segments.osm_way_id = ?", segment.osm_way_id).references(:segments).pluck(:id).uniq

      path_sizes.keys.each do |gamma|
        sums = {0 => 1.0, 1 => 1.0, 2 => 1.0, 4 => 1.0, 10 => 1.0, Float::INFINITY => 1.0}

        ocurrences.each do |route|
          if gamma == Float::INFINITY
            # if (sibling_routes_mileage[@route.id]/sibling_routes_mileage[route]) > 1.0
            if (sibling_routes_mileage.values.min/sibling_routes_mileage[route]) > 1.0
              sums[gamma] = 0.0
            end
          else
            # sums[gamma] += (sibling_routes_mileage[@route.id]/sibling_routes_mileage[route])**gamma
            # sums[gamma] += (sibling_routes_mileage.values.min/sibling_routes_mileage[route])**gamma
            sums[gamma] += (sibling_routes_mileage.values.min/sibling_routes_mileage[route])**gamma**@route.systems_suggested
          end
        end

        if gamma == Float::INFINITY
          path_sizes[gamma] += (impedance * sums[gamma])
        else
          path_sizes[gamma] += (impedance * (1.0/sums[gamma]))
        end
      end
    end
    puts "[#{@route.id}] Completed in #{(Time.now - t0)* 1000.0} ms"
    puts "[#{@route.id}] Path Size: #{path_sizes}"
    path_sizes
  end

  private
      def extract_trip_features
        @trip = Trip.find(@route.trip_id)
        @trip_segments = @trip.user.segments.where(:start_time => @trip.origin.end_time..@trip.destination.start_time, :end_time => @trip.origin.end_time..@trip.destination.start_time)
        @trip_segment_ids = @trip_segments.map{|s| s.osm_way_id}
      end

      def calculate_intersection_distance
        # 1. distance (and fraction of the total distance of the chosen route) overlapped with the chosen route
        @distance = 0.0
        @trip_segments.where(:osm_way_id => @segment_ids).each do |segment|
          @distance += segment.length
        end
        @mileage = get_total_trip_mileage
        if @mileage.zero?
          @mileage = @trip.mileage
        end
        @overlap = (@distance*100.0)/@mileage
      end

      def get_total_trip_mileage
        total_trip_mileage = 0.0
        @trip_segments.each do |segment|
          total_trip_mileage += segment.length
        end
        total_trip_mileage
      end

      def calculate_trip_only_coverage
        # 2. distance (and fraction of the total distance of the chosen route) of segments that are in the chosen routes
        #    and not in the generated route. the fractions should be 1-x the result from above.
        return 1-(@coverage/100)*100
      end

      def calculate_trip_specific_coverage
        # 3. distance (and fraction of the total distance of the chosen route) of segments that are in the generated
        #    routes and not in the chosen route.
        @trip_only_ids = @trip_segment_ids - @segment_ids
      end

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

        return d*0.621371192 # Return the result in Miles...
      end

      def calculate_routes_mileage(routes)
        routes_mileage = {}
        routes.each do |route|
          routes_mileage[route.id] = 0.0
          route.segments.each do |segment|
            routes_mileage[route.id] += segment.length
          end
        end
        routes_mileage
      end

      def remove_route_outliers(segments)
        distance = 0.0
        segments.each do |segment|
          distance += segment.length
        end
        threshold = distance*0.2

        remaining_segments = []

        # Remove initial threshold


        # Remove final threshold
      end
end