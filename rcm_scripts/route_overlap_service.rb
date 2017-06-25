class RouteOverlapService

  def initialize(route)
    @route = route
  end

  def execute
    trip_segments = @route.trip.user.segments.where(:start_time => @route.trip.origin.end_time..@route.trip.destination.start_time, :end_time => @route.trip.origin.end_time..@route.trip.destination.start_time)
    @route_linestring = build_linestring_from_segments(trip_segments)
    @alternative_linestring = build_linestring(decompose_polyline(@route.polyline))
    if @route_linestring != "LINESTRING()" and @alternative_linestring != "LINESTRING()"
      hausdorff_distance
    end
  end

  private
    def snapped_intersection
      statement = "SELECT ST_AsGeoJSON(ST_Intersection(
        ST_SNAP(alternative, route, ST_Distance(alternative,route)*10.0), route))
        FROM (SELECT
          ST_GeomFromText('#{@alternative_linestring}') As alternative,
          ST_GeomFromText('#{@route_linestring}') As route
        ) as routes;"
      results = MapMatchQuery.connection.execute(statement)
      results.each do |t|
        @points = []
        puts JSON.parse(t["st_asgeojson"]).to_json
        result = JSON.parse(t["st_asgeojson"])
        result["coordinates"].each do |c|
          @points << c.reverse
        end

        # geometries = JSON.parse(t["st_asgeojson"])["geometries"]
        # geometries.each do |g|
        #   if g["type"] == "Point"
        #     @points << g["coordinates"].reverse
        #   else
        #     g["coordinates"].each do |c|
        #       @points << c.reverse
        #     end
        #   end
        # end

        polyline = Polylines::Encoder.encode_points(@points)
        puts polyline

        puts "\n\n"
        puts "Original: #{@trip_points.size}"
        puts "Alternate Route: #{@alternate_points.size}"
        puts "Intersection: #{@points.size}"
        puts "Point Overlap: #{(@points.size*100)/@trip_points.size}"
      end
    end

    def intersection
      statement = "SELECT ST_AsGeoJSON(
          ST_Intersection(route, alternative)
        )
        FROM (SELECT
          ST_GeomFromText('#{@alternative_linestring}') As alternative,
          ST_GeomFromText('#{@route_linestring}') As route
        ) as routes"
      results = MapMatchQuery.connection.execute(statement)
      results.each do |t|
        puts t.to_json
        @points = JSON.parse(t["st_asgeojson"])["coordinates"]
        @points = @points.map{|p| p.reverse }
        polyline = Polylines::Encoder.encode_points(@points)
        puts polyline
        # @snapped_points = Polylines::Decoder.decode_polyline(polyline)
        # break_in_segments(@points)

        puts "\n\n"
        puts "Original: #{@trip_points.size}"
        puts "Alternate Route: #{@alternate_points.size}"
        puts "Intersection: #{@points.size}"
        puts "Point Overlap: #{(@points.size*100)/@trip_points.size}"
      end
    end

    def snapped_shared_paths
      statement = "SELECT ST_AsGeoJSON(ST_SharedPaths(
        ST_SNAP(alternative,route, ST_Distance(alternative,route)*1.01), route
        ))
        FROM (SELECT
          ST_GeomFromText('#{@alternative_linestring}') As alternative,
          ST_GeomFromText('#{@route_linestring}') As route
        ) as routes;"
      results = MapMatchQuery.connection.execute(statement)
      results.each do |t|
        JSON.parse(t["st_asgeojson"])["geometries"].each do |geometry|
          points = []
          geometry["coordinates"].each do |lines|
            lines.each do |p|
              points << p
            end
          end

          polyline = Polylines::Encoder.encode_points(points)
          puts polyline
          puts "\n\n"
        end
      end
    end

    def hausdorff_distance
      statement = "select ST_HausdorffDistance(ST_GeomFromText('#{@alternative_linestring}'), ST_GeomFromText('#{@route_linestring}'));"
      results = MapMatchQuery.connection.execute(statement)
      results.each do |t|
        puts t["st_hausdorffdistance"]
        @route.h_distance = t["st_hausdorffdistance"]
        @route.save
      end
    end

    def decompose_polyline(polyline)
      Polylines::Decoder.decode_polyline(polyline)
    end

    def build_linestring(points)
      @alternate_points = points
      'LINESTRING(' + points.map{|p| "#{p.last} #{p.first}"}.join(", ") + ')'
    end

    def build_linestring_from_segments(segments)
      points = []
      segments.each do |segment|
        geom_way = JSON.parse(segment.geom_way)["coordinates"]
        points.concat(geom_way)
      end
      @trip_points = points.map{|p| p.reverse}
      'LINESTRING(' + points.map{|p| "#{p.first} #{p.last}"}.join(", ") + ')'
    end


    def build_multilinestring_from_segments(segments)
      linestrings = []
      segments.each do |segment|
        points = JSON.parse(segment.geom_way)["coordinates"]
        linestrings << '(' + points.map{|p| "#{p.last} #{p.first}"}.join(", ") + ')'
      end
      'MULTILINESTRING(' + linestrings.join(",") + ')'
    end

    def break_in_segments(points)
      segments = []
      current_segment = [points.first]
      for i in 1..(points.size-1)
        if distance_between(current_segment.last, points[i]) < 30
          current_segment << points[i]
        else
          segments << current_segment
          current_segment = [points[i]]
        end
      end
      # puts segments.to_json
      distance = 0
      segments.each do |segment|
        if segment.size > 1
          for i in 1..(segment.size-1)
            distance += distance_between(segment[i-1], segment[i])*0.621371192
          end
        end
      end
      puts distance
    end

    def match_with_original_route
      puts "Route Size: #{@trip_points.size}"
      puts "Alternative Size: #{@snapped_points.size}"
      common_points = []
      @snapped_points.each do |point|
        if @trip_points.include? point
          common_points << point
        end
      end
      puts "Common points: #{common_points}"
      puts Polylines::Encoder.encode_points(common_points)
    end

    def distance_between(a, b)
      dtor = Math::PI/180
      r = 6378.14#*1000 # Commented out to return distance in km

      rlat1 = a[0].to_f * dtor
      rlong1 = a[1].to_f * dtor
      rlat2 = b[0].to_f * dtor
      rlong2 = b[1].to_f * dtor

      dlon = rlong1 - rlong2
      dlat = rlat1 - rlat2

      a = (Math::sin(dlat/2) ** 2) + Math::cos(rlat1) * Math::cos(rlat2) * (Math::sin(dlon/2) ** 2)
      c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))
      d = r * c

      return d
    end
end