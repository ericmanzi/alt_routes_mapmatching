require 'logger'

class MapMatcher
	attr_accessor :data, :segments, :log

	def initialize(options={})
		@data = []
		@segments = []
		@log = Logger.new(STDOUT)
	end

	def mapMatch(initLat, initLong, lastLat, lastLong, toll_info)
		if @data==nil or @data.size==0
   		@log.warn "findStops: no data provided"
   		return
   	end

		# When the segments have timestamps, use them to determine the reading we have to start from
		# (like in stop_detector)

		# Prepare the SQL command that we will use to insert the readings into a temporary table
		sqlcmd = 'BEGIN;
		          DROP TABLE IF EXISTS trip;
		          CREATE TEMP TABLE trip ("timestamp" integer, coord geometry(Point,4326)) ON COMMIT DROP;
		          INSERT INTO trip ("timestamp", coord) '

		if initLong < lastLong
			x1 = initLong
			x2 = lastLong
		else
			x1 = lastLong
			x2 = initLong
		end
		if initLat < lastLat
			y1 = initLat
			y2 = lastLat
		else
			y1 = lastLat
			y2 = initLat
		end

		num = @data.size-1
        sqlcmd << "VALUES (#{@data.at(0).timestamp.to_time.to_i}, ST_SetSRID(ST_Point(#{initLong.to_f}, #{initLat.to_f}),4326))"
		for i in 0..num
			if i==0
			else
				sqlcmd << ", (#{@data.at(i).timestamp.to_time.to_i}, ST_SetSRID(ST_Point(#{@data.at(i).lon.to_f}, #{@data.at(i).lat.to_f}),4326))"
			end
			x = @data.at(i).lon.to_f
			y = @data.at(i).lat.to_f
			if x < x1
				x1 = x
			end
			if x > x2
				x2 = x
			end
			if y < y1
				y1 = y
			end
			if y > y2
				y2 = y
			end
		end
		sqlcmd << ", (#{@data.at(num).timestamp.to_time.to_i}, ST_SetSRID(ST_Point(#{lastLong.to_f}, #{lastLat.to_f}),4326));"

		# Calculate the segments
		results = []
		begin
			# Insert readings in a temporary table
			MapMatchQuery.connection.execute(sqlcmd)
			# Run the map matching algorithm
			results = MapMatchQuery.connection.execute(MapMatchQuery.sql(x1-0.1,y1-0.1,x2+0.1,y2+0.1))
			# End the transaction
			MapMatchQuery.connection.execute('COMMIT;')
		rescue
			@log.warn "mapMatch: SQL error"
			MapMatchQuery.connection.execute('ROLLBACK;')
		end

		# Convert the hashes returned by execute() into Segments
		# IMPORTANT: the column names in the last SELECT query must match the attributes of the Segment model
		@segments = []
		results.each do |r|
			r["start_time"] = Time.at(r["start_time"].to_i)
			r["end_time"] = Time.at(r["end_time"].to_i)

			tmp = MapMatchedSegment.new(r)
			puts tmp.to_json
			@segments << tmp
		end

		return nil
	end

end

