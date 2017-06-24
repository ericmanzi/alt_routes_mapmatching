class TrackMatchingService
  APP_ID = Rails.application.secrets.track_matching_app_id
  APP_KEY = Rails.application.secrets.track_matching_app_key
  MAX_HOURLY_VOLUME = 100000

	def initialize(route, start_point=0, end_point=-1)
    @route = route
    @points = []
    @current_chunk = []
    @conn = Faraday.new(:url => "http://test.roadmatching.com") do |faraday|
      faraday.request :url_encoded
      faraday.response :logger
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end
  end

	def execute
    # Split dataset in chunks of 1000 points
    @points = Polylines::Decoder.decode_polyline(@route.polyline)

    if @points.size > MAX_HOURLY_VOLUME
      puts "Route too big to mapmatch using TrackMatching."
    elsif ($redis.get("trackmatch_h_volume").to_i + @points.size) > MAX_HOURLY_VOLUME
      # Schedule for next hour
      puts "Scheduling for next hour"
      TrackMatchingWorker.perform_at(1.hour, @route.id)
    else
      # Removes previously assigned segments
      @route.segments.delete_all

      indexes = partition_dataset(@points, 1000)
      indexes.each do |index|
        @current_chunk = @points[index.first..index.last]
        perform_request
        parse_results

        if $redis.get("trackmatch_limit_exceeded") == "true" or $redis.get("trackmatch_limit_exceeded").nil? # Reset gps volume count
          $redis.set("trackmatch_limit_exceeded", false)
          $redis.set("trackmatch_h_volume", 0)
        end

        $redis.set("trackmatch_h_volume", $redis.get("trackmatch_h_volume").to_i + @current_chunk.size)
        sleep(1)
      end
      @route.set_mapmatched_polyline
      @route.save
    end
  end

  def parse_error(error)
    doc = Nokogiri::XML(error)
    reason = doc.root.css("reason").text
    usage_reports = doc.root.css("usage_report[exceeded='true']")
    usage_reports.each do |report|
      case report["period"]
      when "eternity"
        $redis.set("trackmatch_overall_limit_exceeded", true)
        # Send email notifying for the apocalypse
        NotificationMailer.track_matching_error(error).deliver
      when "hour"
        $redis.set("trackmatch_h_volume", report.css("current_value").text.to_i)
        $redis.set("trackmatch_max_h_volume", report.css("max_value").text.to_i)
        $redis.set("trackmatch_limit_exceeded", true)

        # Enqueue next job for 1 min after period_end
        next_schedule = (Time.new(report.css("period_end").text.to_i) + 1.second).to_i
        TrackMatchingWorker.perform_at(next_schedule, @route.id)
      when "minute"
        # Schedule job for next available window
        next_schedule = (Time.new(report.css("period_end").text.to_i) + 1.second).to_i
        TrackMatchingWorker.perform_at(next_schedule, @route.id)
      end
    end
  end

  private

    def perform_request
      @response = @conn.post do |req|
        req.url 'rest/mapmatch/' # API Main Endpoint
        req.params = {"app_id" => APP_ID, "app_key" => APP_KEY, "output.waypoints" => true, "output.waypointsIds" => true, "output.groupByWays" => true }
        req.headers['Content-Type'] = 'txt/csv'
        req.headers['Accept'] = 'application/json'
        req.body = chunk_to_csv
        req.options.timeout = 30
      end
      filter_status
    end

    def parse_results
      begin
        result = JSON.parse(@response.body)
      rescue
        return false
      end

      entries = result.try(:[], "diary").try(:[], "entries").to_a
      index = @route.segments.size
      segments = []
      entries.each do |entry|
        route = entry.try(:[], "route")
        links = route.try(:[], "links").to_a
        links.each do |link|
          params = {:osm_way_id => link.try(:[], "id"), :source_id => link.try(:[], "src"), :target_id => link.try(:[], "dst"), :position => index}
          waypoints = link.try(:[], "wpts").to_a
          coordinates = []
          waypoints.each do |point|
            coordinates << [point.try(:[], "x"), point.try(:[], "y")]
          end
          params[:geom_way] = {:type => "LineString", :coordinates => coordinates}.to_json
          # Prepare for batch insert
          segments.push("(#{@route.id}, #{params[:osm_way_id]}, #{params[:source_id]}, #{params[:target_id]}, #{params[:position]}, '#{params[:geom_way]}', '#{DateTime.now}', '#{DateTime.now}')")
          index+=1
        end
      end

      # Batch insertion
      if !segments.join(", ").empty?
        sql = "INSERT INTO segments (alternate_route_id, osm_way_id, source_id, target_id, position, geom_way, created_at, updated_at) VALUES #{segments.join(", ")};"
        ActiveRecord::Base.connection.execute sql
      end
    end

    def chunk_to_csv
      csv = ""
      timestamp = DateTime.now
      @current_chunk.each_with_index do |p, i|
        csv += "#{i},#{p[1]},#{p[0]},\"#{timestamp.strftime("%Y-%m-%dT%H:%M:%S.0")}\"\n"
        timestamp += 15.seconds
      end
      csv
    end

    def partition_dataset(dataset, n)
      # If route has more than n points, split it in chunks
      indexes = []
      if dataset.size < n
        indexes << [0, dataset.size-1]
      else
        puts "Splitting points into chunks to minimize overhead..."
        start = 0; index = 0
        while((index + n) <= dataset.size)
          index += n
          indexes << [start, index]
          start = index+1
        end
        indexes << [start , dataset.size-1]
      end
      return indexes
    end

    def filter_status
      case @response.status
      when 200
        return true
      when 400
        puts "Invalid GPX format supplied."
      when 404
        puts "Data is lying outside supported countries."
      when 409
        # Retry after exceeded period
        puts "Usage limits were exceeded: #{@response.body}"
        parse_error(@response.body)
      when 413
        puts "Uploaded file size exceeds authorized limit."
      end
      return false
    end
end