# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170625001043) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "hstore"
  enable_extension "pgrouting"

  create_table "alternate_routes", id: false, force: :cascade do |t|
    t.integer "id"
    t.string "trip_id", limit: 20
    t.integer "user_id"
    t.string "summary", limit: 255
    t.float "distance"
    t.integer "duration"
    t.integer "duration_traffic"
    t.datetime "start_time"
    t.string "provider", limit: 255
    t.integer "avoid_tolls"
    t.integer "num_intermediate_stops"
    t.integer "num_points"
    t.integer "original_duration"
    t.float "original_distance"
    t.integer "min_duration_traffic"
    t.integer "max_duration_traffic"
    t.text "polyline"
    t.text "map_matched_polyline"
    t.float "toll_costs"
    t.float "overlap"
    t.integer "highest_overlap"
    t.integer "toll_crossings_count"
    t.float "h_distance"
    t.hstore "road_classification"
    t.hstore "speed_classification"
    t.hstore "road_distribution"
    t.hstore "road_distribution_percent"
    t.index ["id"], name: "alternate_route_id_idx"
  end

  create_table "cars", id: false, force: :cascade do |t|
    t.integer "id", null: false
    t.string "name", limit: 20
    t.integer "price"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "edges", id: false, force: :cascade do |t|
    t.integer "timestamp"
    t.decimal "dist", precision: 16, scale: 5
    t.integer "id"
    t.float "x1"
    t.float "y1"
    t.float "x2"
    t.float "y2"
    t.integer "source"
    t.integer "target"
  end

  create_table "gps_datas", id: false, force: :cascade do |t|
    t.integer "id"
    t.float "lat"
    t.float "lon"
    t.datetime "timestamp"
  end

  create_table "grpedges", id: false, force: :cascade do |t|
    t.integer "id"
    t.integer "timestamp"
    t.float "cost"
  end

  create_table "italy_2po_4pgr", id: false, force: :cascade do |t|
    t.integer "id", null: false
    t.bigint "osm_id"
    t.string "osm_name"
    t.string "osm_meta"
    t.bigint "osm_source_id"
    t.bigint "osm_target_id"
    t.integer "clazz"
    t.integer "flags"
    t.integer "source"
    t.integer "target"
    t.float "km"
    t.integer "kmh"
    t.float "cost"
    t.float "reverse_cost"
    t.float "x1"
    t.float "y1"
    t.float "x2"
    t.float "y2"
  end

  create_table "layer", primary_key: ["topology_id", "layer_id"], force: :cascade do |t|
    t.integer "topology_id", null: false
    t.integer "layer_id", null: false
    t.string "schema_name", null: false
    t.string "table_name", null: false
    t.string "feature_column", null: false
    t.integer "feature_type", null: false
    t.integer "level", default: 0, null: false
    t.integer "child_id"
    t.index ["schema_name", "table_name", "feature_column"], name: "layer_schema_name_table_name_feature_column_key", unique: true
  end

  create_table "map_matched_segments", id: false, force: :cascade do |t|
    t.integer "id"
    t.integer "edge_id"
    t.integer "source_id"
    t.integer "target_id"
    t.text "geom_way"
    t.integer "osm_way_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "start_time"
    t.datetime "end_time"
    t.text "polyline"
    t.string "name", limit: 255
    t.integer "position"
    t.float "mph"
    t.integer "clazz"
    t.integer "flags"
    t.integer "user_id"
    t.integer "alternate_route_id"
  end

# Could not dump table "network_na_130606" because of following StandardError
#   Unknown type 'geometry(LineString,4326)' for column 'geom_way'

  create_table "network_na_130606_line", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "barrier"
    t.text "toll"
  end

  create_table "network_na_130606_point", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "barrier"
    t.text "toll"
    t.index ["barrier"], name: "idx_network_na_130606_point_barrier"
    t.index ["osm_id"], name: "idx_network_na_130606_point_osm_id"
    t.index ["toll"], name: "idx_network_na_130606_point_toll"
  end

  create_table "network_na_130606_polygon", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "barrier"
    t.text "toll"
  end

  create_table "network_na_130606_roads", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "barrier"
    t.text "toll"
  end

  create_table "network_sg_140508", id: false, force: :cascade do |t|
    t.integer "id", null: false
    t.bigint "osm_id"
    t.string "osm_name"
    t.bigint "osm_source_id"
    t.bigint "osm_target_id"
    t.integer "clazz"
    t.integer "flags"
    t.integer "source"
    t.integer "target"
    t.float "km"
    t.integer "kmh"
    t.float "cost"
    t.float "reverse_cost"
    t.float "x1"
    t.float "y1"
    t.float "x2"
    t.float "y2"
  end

  create_table "network_sg_140508_line", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "access"
    t.text "addr:housename"
    t.text "addr:housenumber"
    t.text "addr:interpolation"
    t.text "admin_level"
    t.text "aerialway"
    t.text "aeroway"
    t.text "amenity"
    t.text "area"
    t.text "barrier"
    t.text "bicycle"
    t.text "brand"
    t.text "bridge"
    t.text "boundary"
    t.text "building"
    t.text "construction"
    t.text "covered"
    t.text "culvert"
    t.text "cutting"
    t.text "denomination"
    t.text "disused"
    t.text "embankment"
    t.text "foot"
    t.text "generator:source"
    t.text "harbour"
    t.text "highway"
    t.text "historic"
    t.text "horse"
    t.text "intermittent"
    t.text "junction"
    t.text "landuse"
    t.text "layer"
    t.text "leisure"
    t.text "lock"
    t.text "man_made"
    t.text "military"
    t.text "motorcar"
    t.text "name"
    t.text "natural"
    t.text "office"
    t.text "oneway"
    t.text "operator"
    t.text "place"
    t.text "population"
    t.text "power"
    t.text "power_source"
    t.text "public_transport"
    t.text "railway"
    t.text "ref"
    t.text "religion"
    t.text "route"
    t.text "service"
    t.text "shop"
    t.text "sport"
    t.text "surface"
    t.text "toll"
    t.text "tourism"
    t.text "tower:type"
    t.text "tracktype"
    t.text "tunnel"
    t.text "water"
    t.text "waterway"
    t.text "wetland"
    t.text "width"
    t.text "wood"
    t.integer "z_order"
    t.float "way_area"
  end

  create_table "network_sg_140508_nodes", id: false, force: :cascade do |t|
    t.bigint "id", null: false
    t.integer "lat", null: false
    t.integer "lon", null: false
    t.text "tags", array: true
  end

  create_table "network_sg_140508_point", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "access"
    t.text "addr:housename"
    t.text "addr:housenumber"
    t.text "addr:interpolation"
    t.text "admin_level"
    t.text "aerialway"
    t.text "aeroway"
    t.text "amenity"
    t.text "area"
    t.text "barrier"
    t.text "bicycle"
    t.text "brand"
    t.text "bridge"
    t.text "boundary"
    t.text "building"
    t.text "capital"
    t.text "construction"
    t.text "covered"
    t.text "culvert"
    t.text "cutting"
    t.text "denomination"
    t.text "disused"
    t.text "ele"
    t.text "embankment"
    t.text "foot"
    t.text "generator:source"
    t.text "harbour"
    t.text "highway"
    t.text "historic"
    t.text "horse"
    t.text "intermittent"
    t.text "junction"
    t.text "landuse"
    t.text "layer"
    t.text "leisure"
    t.text "lock"
    t.text "man_made"
    t.text "military"
    t.text "motorcar"
    t.text "name"
    t.text "natural"
    t.text "office"
    t.text "oneway"
    t.text "operator"
    t.text "place"
    t.text "poi"
    t.text "population"
    t.text "power"
    t.text "power_source"
    t.text "public_transport"
    t.text "railway"
    t.text "ref"
    t.text "religion"
    t.text "route"
    t.text "service"
    t.text "shop"
    t.text "sport"
    t.text "surface"
    t.text "toll"
    t.text "tourism"
    t.text "tower:type"
    t.text "tunnel"
    t.text "water"
    t.text "waterway"
    t.text "wetland"
    t.text "width"
    t.text "wood"
    t.integer "z_order"
  end

  create_table "network_sg_140508_polygon", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "access"
    t.text "addr:housename"
    t.text "addr:housenumber"
    t.text "addr:interpolation"
    t.text "admin_level"
    t.text "aerialway"
    t.text "aeroway"
    t.text "amenity"
    t.text "area"
    t.text "barrier"
    t.text "bicycle"
    t.text "brand"
    t.text "bridge"
    t.text "boundary"
    t.text "building"
    t.text "construction"
    t.text "covered"
    t.text "culvert"
    t.text "cutting"
    t.text "denomination"
    t.text "disused"
    t.text "embankment"
    t.text "foot"
    t.text "generator:source"
    t.text "harbour"
    t.text "highway"
    t.text "historic"
    t.text "horse"
    t.text "intermittent"
    t.text "junction"
    t.text "landuse"
    t.text "layer"
    t.text "leisure"
    t.text "lock"
    t.text "man_made"
    t.text "military"
    t.text "motorcar"
    t.text "name"
    t.text "natural"
    t.text "office"
    t.text "oneway"
    t.text "operator"
    t.text "place"
    t.text "population"
    t.text "power"
    t.text "power_source"
    t.text "public_transport"
    t.text "railway"
    t.text "ref"
    t.text "religion"
    t.text "route"
    t.text "service"
    t.text "shop"
    t.text "sport"
    t.text "surface"
    t.text "toll"
    t.text "tourism"
    t.text "tower:type"
    t.text "tracktype"
    t.text "tunnel"
    t.text "water"
    t.text "waterway"
    t.text "wetland"
    t.text "width"
    t.text "wood"
    t.integer "z_order"
    t.float "way_area"
  end

  create_table "network_sg_140508_rels", id: false, force: :cascade do |t|
    t.bigint "id", null: false
    t.integer "way_off", limit: 2
    t.integer "rel_off", limit: 2
    t.bigint "parts", array: true
    t.text "members", array: true
    t.text "tags", array: true
    t.boolean "pending", null: false
  end

  create_table "network_sg_140508_roads", id: false, force: :cascade do |t|
    t.bigint "osm_id"
    t.text "access"
    t.text "addr:housename"
    t.text "addr:housenumber"
    t.text "addr:interpolation"
    t.text "admin_level"
    t.text "aerialway"
    t.text "aeroway"
    t.text "amenity"
    t.text "area"
    t.text "barrier"
    t.text "bicycle"
    t.text "brand"
    t.text "bridge"
    t.text "boundary"
    t.text "building"
    t.text "construction"
    t.text "covered"
    t.text "culvert"
    t.text "cutting"
    t.text "denomination"
    t.text "disused"
    t.text "embankment"
    t.text "foot"
    t.text "generator:source"
    t.text "harbour"
    t.text "highway"
    t.text "historic"
    t.text "horse"
    t.text "intermittent"
    t.text "junction"
    t.text "landuse"
    t.text "layer"
    t.text "leisure"
    t.text "lock"
    t.text "man_made"
    t.text "military"
    t.text "motorcar"
    t.text "name"
    t.text "natural"
    t.text "office"
    t.text "oneway"
    t.text "operator"
    t.text "place"
    t.text "population"
    t.text "power"
    t.text "power_source"
    t.text "public_transport"
    t.text "railway"
    t.text "ref"
    t.text "religion"
    t.text "route"
    t.text "service"
    t.text "shop"
    t.text "sport"
    t.text "surface"
    t.text "toll"
    t.text "tourism"
    t.text "tower:type"
    t.text "tracktype"
    t.text "tunnel"
    t.text "water"
    t.text "waterway"
    t.text "wetland"
    t.text "width"
    t.text "wood"
    t.integer "z_order"
    t.float "way_area"
  end

  create_table "network_sg_140508_ways", id: false, force: :cascade do |t|
    t.bigint "id", null: false
    t.bigint "nodes", null: false, array: true
    t.text "tags", array: true
    t.boolean "pending", null: false
  end

  create_table "old_network_table", id: false, force: :cascade do |t|
    t.integer "id", null: false
    t.bigint "osm_id"
    t.string "osm_name"
    t.string "osm_meta"
    t.bigint "osm_source_id"
    t.bigint "osm_target_id"
    t.integer "clazz"
    t.integer "flags"
    t.integer "source"
    t.integer "target"
    t.float "km"
    t.integer "kmh"
    t.float "cost"
    t.float "reverse_cost"
    t.float "x1"
    t.float "y1"
    t.float "x2"
    t.float "y2"
  end

  create_table "spatial_ref_sys", primary_key: "srid", id: :integer, default: nil, force: :cascade do |t|
    t.string "auth_name", limit: 256
    t.integer "auth_srid"
    t.string "srtext", limit: 2048
    t.string "proj4text", limit: 2048
  end

  create_table "topology", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.integer "srid", null: false
    t.float "precision", null: false
    t.boolean "hasz", default: false, null: false
    t.index ["name"], name: "topology_name_key", unique: true
  end

# Could not dump table "trip" because of following StandardError
#   Unknown type 'geometry(Point,4326)' for column 'coord'

  create_table "truckstops", id: false, force: :cascade do |t|
    t.text "name"
    t.text "coordinates"
    t.text "address"
    t.float "latitude"
    t.float "longitude"
    t.float "dist"
    t.bigint "osm_id"
  end

  add_foreign_key "layer", "topology", name: "layer_topology_id_fkey"
end
