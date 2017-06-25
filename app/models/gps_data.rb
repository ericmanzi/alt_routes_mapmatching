class GpsData < ActiveRecord::Base
	attr_accessible :timestamp, :lat, :lon
end