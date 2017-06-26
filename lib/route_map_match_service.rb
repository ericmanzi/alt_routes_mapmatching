class RouteMapMatchService

  def initialize
    @mm = MapMatcher.new
  end
    
  def execute(route)
    @route = route
    initialize_log(route['id'])
    emulate_readings
    @segments = []
    if !@route.nil?
      map_match
      extract_polyline
      # @route.save!
    end
  end

  private

  def map_match
    # puts "Map Matching alternate route #{@route['id']} (#{@route.try(:summary)}) /#{@route.trip.user_id}/trips/#{@route.trip_id}/alternate_routes/#{@route['id']}"
    indexes = partition_dataset_by_mileage(500.0) # partition_dataset_by_size(500) # partition_dataset_by_mileage(300.0)
    indexes.each do |index|
      @log.info "[#{@route['id']}] MapMatching from reading ##{index.first} to reading ##{index.last}..."
      @mm.segments = []
      @mm.data = @readings[index.first..index.last]
      t0 = DateTime.now.to_i
      if !@readings[index.first].nil? and !@readings[index.last].nil?
        @mm.mapMatch(@readings[index.first].lat, @readings[index.first].lon, @readings[index.last].lat, @readings[index.last].lon, false)
        # @mm.mapMatch(@readings[index.first][:latitude], @readings[index.first][:longitude], @readings[index.last][:latitude], @readings[index.last][:longitude], false)
        @segments.concat(@mm.segments)
      end
      @log.info "[#{@route['id']}] Finished in #{DateTime.now.to_i - t0} seconds"
    end
  
  
    begin
      segments = []
      @segments.each_with_index do |s, index|
            segments.push "('#{s.start_time}', '#{s.end_time}', #{s.edge_id}, #{s.osm_way_id}, '#{s.try(:name).try(:gsub, "'", "")}', #{s.source_id}, #{s.target_id}, '#{s.geom_way}', #{@route['user_id']}, #{index+1}, '#{DateTime.now}', '#{DateTime.now}', #{s.mph*0.621371}, #{s.clazz}, #{s.flags}, #{@route['id']})"
      end
      if !segments.join(", ").empty?
        # @route.segments.delete_all
        sql = "INSERT INTO map_matched_segments (start_time, end_time, edge_id, osm_way_id, name, source_id, target_id, geom_way, user_id, position, created_at, updated_at, mph, clazz, flags, alternate_route_id) VALUES #{segments.join(", ")};"
        ActiveRecord::Base.connection.execute sql
  
      end
    rescue Exception => e
      raise ActiveRecord::Rollback, "[#{@route['id']}] Rolling back segment insertion: #{e}"
    end
  end
  
  
  def partition_dataset_by_size(n)
    # If route has more than n points, split it in chunks
    indexes = []
    if @readings.size < n
      indexes << [0, @readings.size-1]
    else
      @log.info "Splitting readings into chunks to minimize overhead..."
      start = 0; index = 0
      while((index + n) <= @readings.size)
        index += n
        indexes << [start, index]
        start = index+1 end
      indexes << [start , @readings.size-1]
    end
    return indexes
  end
  
  
  def partition_dataset_by_mileage(m)
    indexes = []
    points = Polylines::Decoder.decode_polyline(@route['polyline'])
    if @route['distance'] <= m and @route['num_points'] < 400
      indexes << [0, points.size-1]
    else
      distance = 0
      start = 0
      for i in (1..points.size-1)
        distance += distance_between(points[i-1], points[i])
        if (distance >= m or (i-start) >= 400)
          indexes << [start, i]
          start = i+1
          distance = 0
        end
      end
  
      if !indexes.empty? and (indexes.last.last+1) != (points.size-1)
        indexes << [indexes.last.last+1, points.size-1]
      end
  
    end
    indexes
  end
  
  def get_time_by_distance(a, b)
    distance = distance_between(a, b)
    # Assume 45 MPH (72 Km/h)
    (distance*3600)/72
  end
  
  def emulate_readings
    @readings = []
    # timestamp = DateTime.now
    timestamp = DateTime.parse(@route['start_time'])
    # points = Polylines::Decoder.decode_polyline(@route.polyline)
    
    points = Polylines::Decoder.decode_polyline(@route['polyline'])  
    points = dilute_dataset_per_distance(points)
    points.each_with_index do |p, i|
      # @readings << Reading.new(:latitude => p[0], :longitude => p[1], :timestamp => timestamp)
      # @readings << GpsData.new(:lat => p[0], :lon => p[1], :timestamp => timestamp)
      # reading = {:latitude => p[0], :longitude => p[1], :timestamp => timestamp}
      # @readings << reading
      @readings << Reading.new(p[0], p[1], timestamp)
      timestamp += get_time_by_distance(points[i], points[i+1]).seconds unless i == (points.size-1)
    end
    @log.info "[#{@route['id']}] Dataset Size: #{@readings.size}"
    @log.info "[#{@route['id']}] Mileage: #{@route['distance']}"
  end
  
  def dilute_dataset(points) # Dilute dataset into 2% of the original size
    # Just each 50th point
    if points.size < 800
      points
    else
      data = []
  
      # Find granularity
      percentile = points.size*0.02
      granularity = points.size/percentile
  
      points.each_with_index do |point, i|
        if i == 0 or i == points.size-1
          data << point
        elsif i%granularity == 0
          data << point
        end
      end
      data
    end
  end
  
  def dilute_dataset_per_distance(points) # Dilute dataset through point distance
    @log.info "Original size: #{points.size}"
    threshold = @route['distance']*0.02
    @log.info "Threshold: #{threshold}"
    data = [points.first]
    for i in 1..(points.size-1)
      if distance_between(data.last, points[i]) > threshold
        data << points[i]
      end
    end
    @log.info "Diluted: #{data.size}"
    data
  end
  
  def extract_polyline
    points = []
    @segments.each do |segment|
      segment_points = JSON.parse(segment.geom_way)["coordinates"]
      segment_points.each do |point|
          points << point.reverse # On geom_way, coordinates are lon/lat, so we need to reverse
      end
    end
    map_matched_polyline = Polylines::Encoder.encode_points(points)
    sql = "update alternate_routes set map_matched_polyline='#{map_matched_polyline}' where id=#{@route['id']}"
    ActiveRecord::Base.connection.execute sql
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
  
    # return d*0.621371 # Distance in miles
    return d # Distance in km
  end
  
  def initialize_log(alternate_route_id)
    name = "#{alternate_route_id}_MM_at_#{Time.now().strftime("%Y-%m-%d_%H%M")}.log"
    path = File.join(File.realpath("log"), name)
    @log = Logger.new(path)
  end


end



