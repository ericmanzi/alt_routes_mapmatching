#!/usr/bin/env node

/*
 This script takes in a csv file with cargo trips as input with the following fields:
 user_id,travel_id,origin_lat,origin_lon,destination_lat,destination_lon,start_time,end_time,trip_distance,encoded_points
 and queries the MapQuest api for alternative routes with different criteria.
 The results are aggregated into the output csv file: alternative_routes.csv
 with the following fields:
 trip_id,summary,polyline,distance,duration,duration_traffic,avoid,provider

 To execute this script, run:
 > ./map_quest_service.js input_filename.csv output_filename.csv api_key_index
 For instance
./map_quest_service.js cargo_trips.csv alternative_routes.csv 1

See https://developer.mapquest.com/documentation/directions-api/route/get/ for API documentation

Dependencies:
npm install moment
npm install moment-timezone
npm install polyline-encoded
npm install request
npm install tzwhere
chmod +x map_quest_service.js

*/


DEBUG = 0; // Set to 0 to turn off debug logs.

// Make sure we got a filename on the command line.
if (process.argv.length < 5) {
    console.log('Usage: ./' + process.argv[1] + ' input_filename.csv output_filename.csv api_key_index');
    process.exit(1);
}

inputFile = process.argv[2];
outFile = process.argv[3];
api_idx = process.argv[4];

api_keys = [
	'DmjDl3ANoStjjEpV5rqsOv57WYHb1XUG', // - manzieric424a@gmail.com
	'AfPs2EpAk7BHOJsgV901g3MJrPDBksQ2',
	'aZf9bEYZfljnVKqNIG3ACQhD3khyS0XH',
];

API_KEY = api_keys[Number.parseInt(api_idx)%api_keys.length];

var util = require('./utils.js'),
	fs = require('fs'),
	polyUtil = require('polyline-encoded'),
	request = require('request'),
	tzwhere = require('tzwhere'),
	moment = require('moment-timezone');

BASE_URL = 'http://www.mapquestapi.com';
// ENDPOINT = '/directions/v2/alternateroutes'; // Does not work for multi-point routes
ENDPOINT = '/directions/v2/route';
trip = null;
pool = [];
durations = {};
params = {};
res = [];
alternative_routes = [];
data = [];

request.debug = false;
tzwhere.init();
ROUTE_TYPES = ["fastest", "shortest"];
ROUTE_TYPE_IDX = 0;
last_tz = "America/New_York";

function prepare_params(trip) {
	var start = trip.origin_lat+','+trip.origin_lon;
	var end = trip.destination_lat+','+trip.destination_lon;
	var waypoints = [];

	if (trip.num_intermediate_stops > 0) {
		waypoints = trip.waypoints.split("|").map((p)=>p.split("via:")[1]);
	}
	waypoints.push(end);
	if (!trip.hasOwnProperty("origin_lat") || !trip.hasOwnProperty("origin_lon")) { return; }
	var tz = tzwhere.tzNameAt(Number.parseFloat(trip.origin_lat), Number.parseFloat(trip.origin_lon));
	log("tz:"+tz);
	if (tz == null) { tz = last_tz;} else { last_tz = tz;}
	var locat_start_time = moment.utc(trip.start_time).tz(tz);
	log("locat_start_time:"+locat_start_time);

	params = {
		key: API_KEY,
		shapeFormat: 'raw',
		generalize: '0',
    	unit: 'm',
    	from: start,
    	to: waypoints,
    	timeType: 2, // 2 denotes Start At: https://developer.mapquest.com/documentation/directions-api/routetime-refresh/
    	dateType: 0, // 0 denotes Specific Date & Time
    	date: locat_start_time.format("MM/DD/YYYY"),
    	localTime: locat_start_time.format("HH:mm"),
    	useTraffic: true,
    	// maxRoutes: 10,Alternateroutes requests must have exactly two location objects.  Your request provided 5 location object.
    	// maxLinkId: 10000,
	};	

}

function makeCallback(i, j, avoid) {
	return function(response) {
		parse_results(response, avoid);
		nextQuery(i+1, j);
	}
}

function find_all_alternative_routes(i, j) {
	perform_request('', makeCallback(i,j,''));
}

function find_routes_avoiding_tolls(i, j) {
	perform_request('Toll Road', makeCallback(i,j,'Toll Road'));
}

function find_routes_avoiding_highways(i,j) {
	perform_request('Limited Access', makeCallback(i,j,'Limited Access'));
}

function find_routes_avoiding_ferries(i,j) {
	perform_request('Ferry', makeCallback(i,j,'Ferry'));
}

function find_routes_avoiding_tunnels(i,j) {
	perform_request('Tunnel', makeCallback(i,j,'Tunnel'));
}

function find_routes_avoiding_bridges(i,j) {
	perform_request('Bridge', makeCallback(i,j,'Bridge'));
}

function makeQueryWithTime(date, time) {
	return function(i,j) {
		params.date = date;
		params.localTime = time;
		find_all_alternative_routes(i,j);
	}
}

queries = [
	find_all_alternative_routes,
	find_routes_avoiding_tolls,
	find_routes_avoiding_highways,
	find_routes_avoiding_ferries,
	find_routes_avoiding_tunnels,
	find_routes_avoiding_bridges,
];

// days = util.makeArrayFromRange(0,6,2);
days = [0,1,5,6]; // mon,fri,sat,sun
morning_peak = util.makeArrayFromRange(6,9,1);
evening_peak = util.makeArrayFromRange(16,19,1);
afternoon = [12,2];
midnight_non_peak = [0,2,4];
// hours = util.makeArrayFromRange(0,24,1);
hours = midnight_non_peak.concat(morning_peak.concat(afternoon.concat(evening_peak)));

var now = moment();
var week_of_year = Number.parseInt(now.format('W'));
days.forEach((day)=>{
	hours.forEach((hour)=>{
		var t = moment().day(day).year(now.year()).week(week_of_year-1).hour(hour);
		var date = t.format("MM/DD/YYYY");
    	var localTime = t.format("HH:mm");
		queries.push(makeQueryWithTime(date, localTime));
	});
});


function perform_request(avoid, callback) {

	var req = Object.assign({}, params);
	if (avoid != '') {
		req.avoids = avoid;
	}
	req.routeType = ROUTE_TYPES[ROUTE_TYPE_IDX];
	dbg(req);
	request({
		url:BASE_URL+ENDPOINT, 
		qs:req,
		useQuerystring: true,
	}, function(err, response, body) {
		if (!err) {
			callback(JSON.parse(body));
		} else {
			console.log(err);
		}
	});

}

function parse_results(response, avoid) {
	dbg(response);
	if (!response.hasOwnProperty('route')) {
		return;
	}
	var route = response.route;
	var alternative_route = {
		trip_id: trip.id,
		summary: "MapQuest Route",
		polyline: polyUtil.encode(splitPointListIntoPairs(route["shape"]["shapePoints"])),
		provider: 'mapquest',
		num_points: trip.num_intermediate_stops,
		avoid_tolls: avoid == 'Toll Road' ? 1 : 0,
		// avoid_highways: avoid == 'Limited Access' ? 1 : 0,
		// avoid_ferries: avoid == 'Ferry' ? 1 : 0,
		start_time: trip.start_time,
		distance: route["distance"], // kilometers
		duration: route["time"], // seconds
		duration_traffic: route["realTime"], // seconds
		original_distance: trip.trip_distance,
		original_duration: trip.duration_without_stops,
	};
	// do not include duplicates
	duplicates = pool.filter((r)=>r.polyline == alternative_route.polyline);
	if (duplicates.length < 1) {
		// Object.keys(alternative_route).forEach((k)=>{alternative_route[k]=""+alternative_route[k];});
		pool.push(alternative_route);
		// dbg(pool);
	}

	console.log(alternative_route.duration_traffic);
	// min/max duration_traffic
	if (!durations.hasOwnProperty(alternative_route.polyline)) {
		durations[alternative_route.polyline] = {min:24*60*60, max: 0};
	}
	durations[alternative_route.polyline].min = Math.min(
		durations[alternative_route.polyline].min, 
		alternative_route.duration_traffic
		);
	durations[alternative_route.polyline].max = Math.max(
		durations[alternative_route.polyline].max, 
		alternative_route.duration_traffic
		);
}

function splitPointListIntoPairs(pointList) {
	res = [];
	for (var i=0; i<pointList.length; i+=2) {
		res.push(pointList.slice(i,i+2));
	}
	return res;
}



function dbg(obj) { log(JSON.stringify(obj)); }
function dbgtrip(obj) { obj2=Object.assign({},obj); obj2['polyline']=""; log(JSON.stringify(obj2)); }
function log(s) { if (DEBUG) console.log(s); }

function nextQuery(i, j) {
	
	if (i == queries.length) {
		pool.forEach((route)=>{
			route.max_duration_traffic = durations[route.polyline].max;
			route.min_duration_traffic = durations[route.polyline].min;
		});
		alternative_routes = alternative_routes.concat(pool);
		log("i:"+i+",j:"+j+",ROUTE_TYPE_IDX:"+ROUTE_TYPE_IDX);
		execute(j+1);
		return;
	}

	if (ROUTE_TYPE_IDX == 0) {
		ROUTE_TYPE_IDX = 1;
		log("i:"+i+",j:"+j+",ROUTE_TYPE_IDX:"+ROUTE_TYPE_IDX);
		queries[i](i, j);
		return;
	}

	ROUTE_TYPE_IDX = 0;
	var h = Math.max(i-1, 0);
	log("i:"+h+",j:"+j+",ROUTE_TYPE_IDX:"+ROUTE_TYPE_IDX);
	queries[h](h, j);
	
}

function execute(trip_idx) {
	console.log("Querying alternative routes for trip "+(trip_idx+1)+"/"+data.length);
	if (trip_idx == data.length) {
		console.log("Done. Got "+alternative_routes.length+" alternative routes for "+trip_idx+" trips.");
		setTimeout(function(){
			writeOut(outFile);
		},1);
		return;
	}
	trip = data[trip_idx];
	pool = [];
	durations = {};
	if (trip == null || trip == undefined) { return; }
	prepare_params(trip);
	nextQuery(0, trip_idx);
}

function writeOut(outFile) {
	var csv = util.JSON2CSV(alternative_routes, util.csv_fields, "\"");
	fs.writeFile(outFile, csv, function(err) {
	  if (err) throw err;
	  console.log('alternative_routes saved to '+outFile);
	});	
}

function begin(inputFile) {
	fs.readFile(inputFile, 'utf8', function(err, csv) {
	    if (err) throw err;
	    data = util.CSV2JSON(csv);// data=data.slice(250,data.length);
	    execute(0);
	});
}

begin(inputFile);















