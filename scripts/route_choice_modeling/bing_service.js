#!/usr/bin/env node

/*
 This script takes in a csv file with cargo trips as input with the following fields:
 user_id,travel_id,origin_lat,origin_lon,destination_lat,destination_lon,start_time,end_time,trip_distance,encoded_points
 and queries the bing api for alternative routes with different criteria.
 The results are aggregated into the output csv file: alternative_routes.csv
 with the following fields:
 trip_id,summary,polyline,distance,duration,duration_traffic,avoid,provider

 To execute this script, run:
 > ./bing_service.js input_filename.csv output_filename.csv api_key_index
 For instance
./bing_service.js cargo_trips.csv alternative_routes.csv 0

See https://msdn.microsoft.com/en-us/library/ff701717.aspx for API documentation

Dependencies:
npm install moment
npm install polyline-encoded
npm install request
chmod +x bing_service.js 

*/


DEBUG = 0; // Set to 0 to turn off debug logs.

// Make sure we got a filename on the command line.
if (process.argv.length < 5) {
    console.log('Usage: ./' + process.argv[1] + ' input_filename.csv output_filename.csv');
    process.exit(1);
}

inputFile = process.argv[2];
outFile = process.argv[3];
api_idx = process.argv[4];

api_keys = [
	'AgzZ_2N0c4XEIfln1eFEoPa2uriCbP745gPUjUUYfkOTZDxzRFzCvDmT5Dq2nNUa', // - manziera@yahoo.com	
];

API_KEY = api_keys[Number.parseInt(api_idx)%api_keys.length];

var util = require('./utils.js'),
	fs = require('fs'),
	polyUtil = require('polyline-encoded'),
	request = require('request'),
	moment = require('moment');

BASE_URL = 'http://dev.virtualearth.net';
ENDPOINT = '/REST/v1/Routes';
trip = null;
pool = [];
durations = {};
params = {};
res = [];
alternative_routes = [];
data = [];


function prepare_params(trip) {

	params = {
		key: API_KEY,
    	distanceUnit: 'km',
    	maxSolutions: 3, // maximum number of transit or driving routes to return
    	routeAttributes: 'routePath',
    	routePathOutput: 'Points',
    	optimize: 'timeWithTraffic', // Route is calculated to minimize time using current traffic information
    	dateTime: util.format_time_bing(trip.start_time), // predictive traffic data is used to calculate route
    	timeType: 'Departure',
	};

	start = trip.origin_lat+','+trip.origin_lon;
	end = trip.destination_lat+','+trip.destination_lon;
	params['wayPoint.0'] = start;
	var num_intermediate_stops = Number.parseInt(trip.num_intermediate_stops);
	params['wayPoint.'+(num_intermediate_stops+1)] = end;

	if (num_intermediate_stops > 0) {
		intermediate_stops = trip.waypoints.split("|");
		for (var n = 0; n < num_intermediate_stops; n++) {
			params['viaWaypoint.'+(n+1)] = intermediate_stops[n].split("via:")[1];
		}
	}

}

function makeCallback(i, j, avoid) {
	return function(response) {
		parse_results(response, avoid);
		log("parse_results");
		nextQuery(i+1, j);
	}
}

function find_all_alternative_routes(i, j) {
	perform_request('', makeCallback(i,j,''));
}

function find_routes_avoiding_tolls(i, j) {
	perform_request('tolls', makeCallback(i,j,'tolls'));
}

function find_routes_avoiding_highways(i,j) {
	perform_request('highways', makeCallback(i,j,'highways'));
}

function find_routes_minimizing_highways(i,j) {
	perform_request('minimizeHighways', makeCallback(i,j,'minimizeHighways'));
}

function find_routes_minimizing_tolls(i,j) {
	perform_request('minimizeTolls', makeCallback(i,j,'minimizeTolls'));
}

function makeQueryWithTime(time) {
	return function(i,j) {
		params.dateTime = time;
		find_all_alternative_routes(i,j);
	}
}

queries = [
	find_all_alternative_routes,
	find_routes_avoiding_tolls,
	find_routes_avoiding_highways,
	find_routes_minimizing_tolls,
	find_routes_minimizing_highways,
];


days = util.makeArrayFromRange(0,6,2);
morning_peak = util.makeArrayFromRange(6,9,1);
evening_peak = util.makeArrayFromRange(16,19,1);
non_peak = util.makeArrayFromRange(0,5,1);
hours = non_peak.concat(morning_peak.concat(evening_peak));
var now = moment();
var week_of_year = Number.parseInt(now.format('W'));
days.forEach((day)=>{
	hours.forEach((hour)=>{
		var t = moment().day(day).year(now.year()).week(week_of_year-1).hour(hour);
		// queries.push(makeQueryWithTime(util.format_time_bing(t.format("YYYY-MM-DD HH:mm:ss"))));
	});
});


function perform_request(avoid, callback) {

	req = Object.assign({}, params);
	if (avoid != '') {
		req.avoid = avoid;
	}
	dbg(req);
	request({
		url:BASE_URL+ENDPOINT, 
		qs:req,
	}, function(err, response, body) {
		if (!err) {
			log("response.statusCode: " + response.statusCode);
			callback(JSON.parse(body));
		} else {
			console.log(err);
		}
	});

}

function parse_results(response, avoid) {
	// dbg(response);
	if (!response.hasOwnProperty('resourceSets')) {
		return;
	}
	response.resourceSets.forEach((resourceSet)=>{
		resourceSet.resources.forEach((route)=>{
			alternative_route = {
				trip_id: trip.id,
				summary: route["routeLegs"].slice(0,3).map((l)=>l["description"]).join(', '),
				polyline: polyUtil.encode(route["routePath"]["line"]["coordinates"]),
				provider: 'bing',
				num_points: trip.num_intermediate_stops,
				avoid_tolls: avoid == 'tolls' ? 1 : 0,
				// avoid_highways: avoid == 'highways' ? 1 : 0,
				// avoid_ferries: 0,
				start_time: trip.start_time,
				distance: route["travelDistance"], // kilometers
				duration: route["travelDuration"], // seconds
				duration_traffic: route["travelDurationTraffic"], // seconds
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
			// console.log(alternative_route.duration_traffic);
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

		});
	});
	
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
		execute(j+1);
		return;
	}
	log("i:"+i+",j:"+j);
	queries[i](i, j);
}

function execute(trip_idx) {
	if (trip_idx == data.length) {
		console.log("Done. Got "+alternative_routes.length+" alternative routes for "+trip_idx+" trips.");
		setTimeout(()=>{ writeOut(outFile); }, 1);
		return;
	}
	console.log("Querying alternative routes for trip "+(trip_idx+1)+"/"+data.length);
	trip = data[trip_idx];
	pool = [];
	durations = {};
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
	    data = util.CSV2JSON(csv).slice(0);
	    execute(0);
	});
}

begin(inputFile);















