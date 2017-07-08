# require 'json'
class RoadClassCalculatorService

  def initialize(route)
    @TYPES = {
      1 => "route.ferry",
      2 => "route.shuttle_train",
      3 => "railway.rail",
      11 => "highway.motorway",
      12 => "highway.motorway_link",
      13 => "highway.trunk",
      14 => "highway.trunk_link",
      15 => "highway.primary",
      16 => "highway.primary_link",
      21 => "highway.secondary",
      22 => "highway.secondary_link",
      31 => "highway.tertiary",
      32 => "highway.residential",
      41 => "highway.road",
      42 => "highway.unclassified",
      51 => "highway.service",
      62 => "highway.pedestrian",
      63 => "highway.living_street",
      71 => "highway.track",
      72 => "highway.path",
      81 => "highway.cycleway",
      91 => "highway.footway",
      92 => "highway.steps"
    }
    @route = route
    @segment_mileage = {}
    @class_distribution = {}
    @speed_distribution = {"Under 35" => 0.0, "35-40" => 0.0, "40-45" => 0.0, "45-50" => 0.0, "50-55" => 0.0, "55-60" => 0.0, "60-65" => 0.0, "65-70" => 0.0, "Over 70" => 0.0}
  end

  def execute
    #  @segments = @route.map_matched_segments
    @segments = MapMatchedSegment.where("alternate_route_id = ?", @route['id'])
    @mileage = calculate_route_mileage
    puts "@segments.size=#{@segments.size}"
    @segments.group_by {|s| @TYPES[s[:clazz]]}.each do |klazz, segments|
      @class_distribution[klazz] = 0.0
      segments.each do |segment|
        @class_distribution[klazz] += calculate_segment_percentage(segment)
      end
    end
    @segments.each do |segment|
      # puts "segment[:mph]: #{segment[:mph]}"
      if !segment[:mph].nil?
        if segment[:mph] < 35.0
          @speed_distribution["Under 35"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 35.0 and segment[:mph] < 40.0
          @speed_distribution["35-40"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 40.0 and segment[:mph] < 45.0
          @speed_distribution["40-45"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 45.0 and segment[:mph] < 50.0
          @speed_distribution["45-50"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 50.0 and segment[:mph] < 55.0
          @speed_distribution["50-55"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 55.0 and segment[:mph] < 60.0
          @speed_distribution["55-60"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 60.0 and segment[:mph] < 65.0
          @speed_distribution["60-65"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 65.0 and segment[:mph] < 70.0
          @speed_distribution["65-70"] += calculate_segment_percentage(segment)
        elsif segment[:mph] >= 70.0
          @speed_distribution["Over 70"] += calculate_segment_percentage(segment)
        end
      end
    end

    @route[:road_classification] = @class_distribution
    @route[:speed_classification] =  @speed_distribution
    # @route.save

    save_road = "UPDATE alternate_routes SET road_classification=hstore(#{@route[:road_classification]}) where id=#{@route[:id]};"
    save_speed = "UPDATE alternate_routes SET speed_classification=hstore(#{@route[:speed_classification]}) where id=#{@route[:id]};"

    ActiveRecord::Base.connection.execute save_road
    ActiveRecord::Base.connection.execute save_speed

  end

  def calculate_route_mileage
    distance = 0.0
    @segments.each do |segment|
      @segment_mileage[segment[:id]] = segment.length
      distance += @segment_mileage[segment[:id]]
    end
    distance
  end

  def calculate_segment_percentage(segment)
    @segment_mileage[segment[:id]]/@mileage
  end

end