class AlternateRoute < ActiveRecord::Base
	attr_accessor :summary, :polyline, :distance, :duration, :duration_traffic, :avoid_tolls,
					:provider, :toll_costs, :highest_overlap, :num_points, :trip_id, :original_duration,
					:clazz, :min_duration_traffic, :max_duration_traffic, :road_classification,
					:speed_classification, :path_sizes, :path_sizes_v2, :path_sizes_v3, :provider_distribution,
					:road_distribution, :road_distribution_percent,
					:user_id

end