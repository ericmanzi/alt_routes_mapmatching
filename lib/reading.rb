class Reading
	attr_accessor :timestamp, :lat, :lon
	def initialize(lat, lon, timestamp)
		@lat=lat
		@lon=lon
		@timestamp=timestamp
	end
	def coords
		return [@lat, @lon]
	end
end