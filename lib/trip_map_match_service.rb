# class TripMapMatchService

#   # def initialize
#   #   @mm = MapMatcher.new
#   #   @segments = []
#   # end

#   def parseDate(datetime_str)
#     sqlDate = datetime_str.in_time_zone('Eastern Time (US & Canada)').to_datetime.utc.to_s(:db)
#   end

#   def partition_dataset_by_size(n, dataset)
#     # If route has more than n points, split it in chunks
#     indexes = []
#     if dataset.size < n
#       indexes << [0, dataset.size-1]
#     else
#       start = 0; idx = 0
#       while((idx + n) < dataset.size-1)
#         idx += n
#         indexes << [start, idx]
#         start = idx+1 
#       end
#       indexes << [start, dataset.size-1]
#     end
#     return indexes
#   end

#   def map_match(user_id)

#     @mm = MapMatcher.new
#     @segments = []

# # All users: [25, 39, 38, 43, 48, 49, 46, 54, 57, 30, 37, 45, 40, 41, 55, 35, 61, 52, 56]
# # Completed: [48, 37, 54, 41, 35, 38, 30, 40*]
# # Missing: [25, 61, 56, 25, 49, 57, 39, 43, 46, 45, 55, 52]

#     # user_id = UsersDevice.where("device_id = ?", device_id).first.user_id.to_i
#     device_id = UsersDevice.where("user_id = ?", user_id).first.device_id.to_i

#     start_time_str = "1475294400"
#     end_time_str = "1483160400"

#     start_time = Time.at(start_time_str.to_i)
#     end_time = Time.at(end_time_str.to_i)

#     @start_time = parseDate(start_time)
#     @end_time = parseDate(end_time)

#     # directory_name = "log/map_match"
#     # Dir.mkdir(directory_name) unless File.exists?(directory_name)
#     # log = Logger.new(File.join(File.realpath(directory_name), "/#{user_id}_S_#{Time.now().strftime("%Y-%m-%d")}.txt"))
#     # log.debug "MapMatchService started at #{Time.now()} for user: #{user_id} for range #{start_time} -to- #{end_time}"

#     stops = Stop.where("deleted = ? and user_id = ? and endtime > ? and starttime < ?", false, user_id, @start_time, @end_time).order(:starttime)
#     gpsData = GpsData.where("device_id = ? and timestamp >= ? and timestamp <= ? and accuracy<? and lat!=? and altitude<=?", device_id, parseDate(stops.first.endtime), parseDate(stops.last.starttime), MAX_GPS_ACCURACY, "0.0", MAX_ALT)

#     # Partition gpsData by stops
#     trip_indexes = []
#     lower_index = 0
#     i = 0
#     while i < stops.size-1
#       num_gps_datas_btn_stops = gpsData.where("timestamp <= ? and timestamp >= ?", stops[i+1].starttime, stops[i].endtime).count-1
#       trip_indexes << [lower_index, lower_index + num_gps_datas_btn_stops]
#       num_gps_datas_in_stop = gpsData.where("timestamp <= ? and timestamp >= ?", stops[i+1].endtime, stops[i+1].starttime).count-1
#       lower_index += num_gps_datas_btn_stops + num_gps_datas_in_stop
#       i+=1
#     end


#     trip_indexes.select{|ti| ti[1]-ti[0] > 2}.each do |trip_index|
#     # trip_indexes.select{|ti| ti[1]-ti[0] > 2}.each do |trip_index|
#       trip_data = gpsData[trip_index.first..trip_index.last]

#       puts "trip_data.size: #{trip_data.size}"
#       puts "trip_index: #{trip_index}"
#       trip_pts = []
#       k = 0
#       lastPtIdx = 0
#       while k < trip_data.size
#         lastPt = trip_data[lastPtIdx]
#         pt = trip_data[k]
#         distance_from_lastPt = FmsMath.calculateLatDistance(lastPt.lat.to_f, lastPt.lon.to_f, pt.lat.to_f, pt.lon.to_f)
#         # puts "distance_from_lastPt: #{distance_from_lastPt}"
#         if k==0 or distance_from_lastPt > GPS_PTS_MIN_DIST*2
#           trip_pts << pt
#           lastPtIdx = k
#         end
#         k+=1
#       end

#       puts "trip_pts.size: #{trip_pts.size}"

#       trip_chunk_indexes = partition_dataset_by_size(300, trip_pts)
#       puts "trip_chunk_indexes: #{trip_chunk_indexes}"

#       trip_chunk_indexes.select{|tci| tci[1]-tci[0] > 2}.each do |chunk_index|

#         chunk_start_time = parseDate(trip_pts[chunk_index.first].timestamp)
#         chunk_end_time = parseDate(trip_pts[chunk_index.last].timestamp)


#         if !trip_pts[chunk_index.first].nil? and !trip_pts[chunk_index.last].nil?
#           @mm.segments = []
#           @mm.data = trip_pts[chunk_index.first..chunk_index.last]
#           chunk = trip_pts[chunk_index.first..chunk_index.last]
#           puts "chunk.size: #{chunk.size}"
#           @mm.mapMatch(chunk.first.lat, chunk.first.lon, chunk.last.lat, chunk.last.lon, false)
#           @segments.concat(@mm.segments)

#           begin
#             t0 = parseDate(DateTime.now)
#             segments = []
#             @mm.segments.each_with_index do |s, index|
#               segments.push "('#{parseDate(s.start_time)}', '#{parseDate(s.end_time)}', #{s.edge_id}, #{s.osm_way_id}, '#{s.try(:name).try(:gsub, "'", "")}', #{s.source_id}, #{s.target_id}, '#{s.geom_way}', #{user_id}, #{index+1}, '#{t0}', '#{t0}', #{s.mph*0.621371}, #{s.clazz}, #{s.flags})"
#             end
  
#             if !segments.join(", ").empty?
#               ## MapMatchedSegment.where("user_id = ? and start_time >= ? and end_time <= ?", user_id, start_time, end_time).delete_all

#               sql = "INSERT INTO map_matched_segments (start_time, end_time, edge_id, osm_way_id, name, source_id, target_id, geom_way, user_id, position, created_at, updated_at, mph, clazz, flags) VALUES #{segments.join(", ")};"
#               ActiveRecord::Base.connection.execute sql
              
#               # set_polyline - GMapPolyline encode the coordinates.
#               MapMatchedSegment.where("user_id = ? and start_time >= ? and end_time <= ?", user_id, chunk_start_time, chunk_start_time).each do |segment|
#                 segment.set_polyline
#               end
#             end
#           rescue Exception => e
#             # log.debug "Raised exception: #{e}"
#             raise ActiveRecord::Rollback, "Rolling back segment insertion for user:#{user_id} - #{e}"
#           end        
#         end
#       end
#     end

#     puts "MapMatching for user #{user_id} completed."
#   end



# end







# ###############################################
# # trip_data.size: 194
# # trip_index: [300957, 301150]
# # trip_pts.size: 147
# # trip_chunk_indexes: [[0, 146]]
# # chunk.size: 147









