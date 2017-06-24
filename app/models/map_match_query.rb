class MapMatchQuery < ActiveRecord::Base

	NETWORK = "network_na_130606"

	def self.sql(x1,y1,x2,y2)
		"DROP TABLE IF EXISTS edges;
		CREATE TEMP TABLE edges ON COMMIT DROP as (
		          SELECT e.timestamp, e.dist, #{NETWORK}.id, #{NETWORK}.x1, #{NETWORK}.y1, #{NETWORK}.x2, #{NETWORK}.y2, #{NETWORK}.source, #{NETWORK}.target FROM
		              (
		              	SELECT nn_gid AS id, nn_dist as dist, timestamp FROM (
		                     SELECT  trip.timestamp as timestamp, (pgis_fn_nn(trip.coord, 0.016, 4, 32, '#{NETWORK}', 'true', 'id', 'geom_way')).*
		                          FROM trip) AS g1
					   )
		               AS e
		               INNER JOIN #{NETWORK} ON (e.id = #{NETWORK}.id)
		);

		DROP TABLE IF EXISTS grpedges;
		CREATE TEMP TABLE grpedges ON COMMIT DROP AS (
		     with exttrip as (
		          SELECT s.timestamp, ST_Azimuth(s.postcoord, s.precoord) as heading FROM (
		                 select lag(coord) over (ORDER BY timestamp) as precoord, lead(coord) over (ORDER BY timestamp) as postcoord, timestamp FROM trip)
		                 AS s
		     )

		     SELECT edges.id, edges.timestamp, (edges.dist)::float8
		     		as cost
        		    FROM edges INNER JOIN exttrip ON (edges.timestamp = exttrip.timestamp)
		);

		SELECT s.start_time as start_time, s.end_time as end_time, #{NETWORK}.id as edge_id, #{NETWORK}.osm_id as osm_way_id, #{NETWORK}.osm_name as name,
			#{NETWORK}.osm_source_id as source_id, #{NETWORK}.osm_target_id as target_id, ST_AsGeoJSON(#{NETWORK}.geom_way) as geom_way, #{NETWORK}.kmh as mph, #{NETWORK}.clazz as clazz, #{NETWORK}.flags as flags FROM
			map_match(
				'SELECT #{NETWORK}.id,
				#{NETWORK}.source,
				#{NETWORK}.target,
				(#{NETWORK}.cost) as default_cost,
				(#{NETWORK}.reverse_cost) as reverse_cost
				FROM #{NETWORK} WHERE ST_SetSRID(''BOX3D(#{x1} #{y1},#{x2} #{y2})''::BOX3D, 4326) && geom_way',
				false,
				true,
				'SELECT * FROM grpedges WHERE cost is NOT NULL')
			AS s INNER JOIN #{NETWORK} ON (s.edge_id=#{NETWORK}.id
		);"
	end
end