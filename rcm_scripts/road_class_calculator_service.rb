# require 'json'
class RoadClassCalculatorService

	def initialize(route)
		@route = route
    @segment_mileage = {}
    @class_distribution = {}
    @speed_distribution = {"Under 35" => 0.0, "35-40" => 0.0, "40-45" => 0.0, "45-50" => 0.0, "50-55" => 0.0, "55-60" => 0.0, "60-65" => 0.0, "65-70" => 0.0, "Over 70" => 0.0}
	end

  def execute
    @segments = @route.map_matched_segments
    @mileage = calculate_route_mileage

    @segments.group_by {|s| s.type}.each do |klazz, segments|
      @class_distribution[klazz] = 0.0
      segments.each do |segment|
        @class_distribution[klazz] += calculate_segment_percentage(segment)
      end
    end

    @segments.each do |segment|
      if !segment.mph.nil?
        if segment.mph < 35.0
          @speed_distribution["Under 35"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 35.0 and segment.mph < 40.0
          @speed_distribution["35-40"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 40.0 and segment.mph < 45.0
          @speed_distribution["40-45"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 45.0 and segment.mph < 50.0
          @speed_distribution["45-50"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 50.0 and segment.mph < 55.0
          @speed_distribution["50-55"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 55.0 and segment.mph < 60.0
          @speed_distribution["55-60"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 60.0 and segment.mph < 65.0
          @speed_distribution["60-65"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 65.0 and segment.mph < 70.0
          @speed_distribution["65-70"] += calculate_segment_percentage(segment)
        elsif segment.mph >= 70.0
          @speed_distribution["Over 70"] += calculate_segment_percentage(segment)
        end
      end
    end

    @route.road_classification = @class_distribution
    @route.speed_classification =  @speed_distribution
    @route.save
  end

  def calculate_route_mileage
    distance = 0.0
    @segments.each do |segment|
      @segment_mileage[segment.id] = segment.length
      distance += @segment_mileage[segment.id]
    end
    distance
  end

  def calculate_segment_percentage(segment)
    @segment_mileage[segment.id]/@mileage
  end

end