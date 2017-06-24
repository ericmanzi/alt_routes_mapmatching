#!/usr/bin/env node

/*
 This script takes in a csv file with cargo trips as input with the following fields:
 user_id,travel_id,origin_lat,origin_lon,destination_lat,destination_lon,start_time,end_time,trip_distance,encoded_points
 and queries the google api for alternative routes with different criteria.
 The results are aggregated into the output csv file: alternative_routes.csv
 with the following fields:
 trip_id,summary,polyline,distance,duration,duration_traffic,avoid,provider

 To execute this script, run:
 > ./google_service.js input_filename.csv output_filename.csv api_idx partitionNum partitionSize
 For instance
./google_service.js cargo_trips.csv alternative_routes.csv 0 0 10

See https://developers.google.com/maps/documentation/directions/intro for API documentation

Dependencies:
npm install moment
npm install request
chmod +x google_service.js 
*/

// Set to 0 to turn off debug messages.
DEBUG = 0;

// Make sure we got a filename on the command line.
if (process.argv.length < 5) {
    console.log('Usage: ./' + process.argv[1] + ' input_filename.csv output_filename.csv');
    process.exit(1);
}

inputFile = process.argv[2];
outFile = process.argv[3];
api_idx = Number.parseInt(process.argv[4]);
partitionNum = Number.parseInt(process.argv[5]);
partitionSize = Number.parseInt(process.argv[6]);

api_keys = [
	'AIzaSyCM808vhqkwTh0UGIGtWpZS_OlD5yldg-g', // from eric
	'AIzaSyD6vdp9VjzT_4sBs4ltyaTWiXeqNS1aGl0',
	'AIzaSyBiWcvQdHtJVnn3_ceudEw4dGQkM0MxUsM',
	'AIzaSyCTr_K60Md633goY7_kR6LRL4GXO6Pyv80',
	'AIzaSyCqJBh7lHcrSlf4LRHs4EgYcUP9pPkMOk0', // from peiyu
	'AIzaSyDYmdZ8Ew5vQXNX58VbYfKV6oNbEUpkZzw',
	'AIzaSyD-gk8olhRx5v_Ru6lqUXdhi4rP7Jp8RPo',
	'AIzaSyB7rmDdAz4nq6-eEZzUIT6FiqXUE3a_eeA',
	'AIzaSyBRGyhpeihLq-4XUgy9otZ4LOp_sy3MbFk',
];

API_KEY = api_keys[api_idx%api_keys.length];
// console.log(API_KEY);

var util = require('./utils.js'),
	fs = require('fs'),
	request = require('request'),
	moment = require('moment'),
	child_process = require('child_process')
	gmaps_lib=require('@google/maps');

gMaps = gmaps_lib.createClient({ key: API_KEY});

BASE_URL = 'https://maps.googleapis.com';
ENDPOINT = '/maps/api/directions/json';
trip = null;
pool = [];
durations = {};
params = {};
res = [];
alternative_routes = [];
data = [];
data_all = [];

function prepare_params(trip) {

	var start = trip.origin_lat+','+trip.origin_lon;
	var end = trip.destination_lat+','+trip.destination_lon;
	future_departure_time = util.get_next_similar_time(trip.start_time);

	params = {
    	mode: 'driving',
    	units: 'metric',
    	alternatives: true, // set to true to search for alternative routes
    	departure_time: future_departure_time, // specify departure_time to take traffic conditions into account
    	origin: start,
    	destination: end,
    	avoid: [],
	};
	if (Number.parseInt(trip.num_intermediate_stops)>0) {
		params['waypoints'] = trip.waypoints;
	}

}

function makeCallback(i, j, avoid) {
	return (response) => {
		var ok = parse_results(response, avoid);
		nextQuery(i+ok, j);
	}
}

function find_all_alternative_routes(i, j) {
	perform_request('', makeCallback(i,j,''));
}

function find_routes_avoiding_tolls(i, j) {
	perform_request('tolls', makeCallback(i,j,'tolls'));
}

function find_routes_avoiding_ferries(i,j) {
	perform_request('ferries', makeCallback(i,j,'ferries'));
}

function find_routes_avoiding_highways(i,j) {
	perform_request('highways', makeCallback(i,j,'highways'));
}

function makeQueryWithTime(time) {
	return function(i,j) {
		params.departure_time = time;
		find_all_alternative_routes(i,j);
	}
}

queries = [
	find_routes_avoiding_tolls,
	find_routes_avoiding_ferries,
	find_routes_avoiding_highways,
	find_all_alternative_routes,
];

days = [0,1,5,6]; // mon,fri,sat,sun
morning_peak = util.makeArrayFromRange(6,9,1);
afternoon = [12,2];
evening_peak = util.makeArrayFromRange(16,19,1);
midnight_non_peak = [0,2,4];
// hours = util.makeArrayFromRange(0,24,1);
hours = midnight_non_peak.concat(morning_peak.concat(afternoon.concat(evening_peak)));
var now = moment();
var week_of_year = Number.parseInt(now.format('W'));
days.forEach((day)=>{
	hours.forEach((hour)=>{
		var t = moment().day(day).year(now.year()).week(week_of_year+1).hour(hour);
		queries.push(makeQueryWithTime(""+t.unix()));
	});
});

function perform_request(avoid, callback) {
	var avoid_arr = avoid == '' ? [] : [avoid]
	req = Object.assign({}, params);
	req.avoid = avoid_arr;
	dbg(req);
	gMaps.directions(req, function(err, response) {
      	if (!err) {
      	    callback(response.json);
      	} else {
      	    console.log(err);
      	}
	});

	// req.key = API_KEY;
	// request({
	// 	url:BASE_URL+ENDPOINT, 
	// 	qs:req,
	// }, function(err, response, body) {
	// 	if (!err) {
	// 		// dbg(body);
	// 		callback(JSON.parse(body));
	// 	} else {
	// 		console.log(err);
	// 	}
	// });

}

consecutive_fails = 0;
function parse_results(response, avoid) {
	// log("avoid:"+avoid);
	// log(response.routes.length);
	if (response.status=="OVER_QUERY_LIMIT") {
		console.log(response.error_message);
    		//process.exit(1);
		console.log("API key="+API_KEY+", idx="+api_idx);
		api_idx = (api_idx + 1)%api_keys.length;//console.log(api_idx);
	    API_KEY = api_keys[api_idx];//console.log(API_KEY);
	    gMaps = gmaps_lib.createClient({ key: API_KEY});

		consecutive_fails += 1;
		if (consecutive_fails > api_keys.length) {
			process.exit(1);
		}
		return 0;
	}
	consecutive_fails = 0;
	response.routes.forEach((route)=> {

		route_primer = {
			trip_id: trip.id,
			user_id: trip.user_id,
			summary: route["summary"],
			polyline: route["overview_polyline"]["points"],
			provider: 'google',
			num_points: trip.num_intermediate_stops,
			avoid_tolls: avoid == 'tolls' ? 1 : 0,
			// avoid_ferries: avoid == 'ferries' ? 1 : 0,
			// avoid_highways: avoid == 'highways' ? 1 : 0,
			start_time: trip.start_time,
			original_distance: trip.trip_distance,
			original_duration: trip.duration_without_stops,
			// alternative_route_leg_count: route["legs"].length,
		};
		alternative_route = Object.assign(route_primer, extract_route_legs(route));

		// do not include duplicates
		duplicates = pool.filter((r)=>r.polyline == alternative_route.polyline);
		if (duplicates.length < 1) {
			// Object.keys(alternative_route).forEach((k)=>{alternative_route[k]=""+alternative_route[k];});
			pool.push(alternative_route);
		}
		
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
	log("len(response.routes):"+response.routes.length);
	return 1;
}

function extract_route_legs(route) {
	output_route = {
		distance: 0, // in kilometers if units specified as 'metric'
		duration: 0, // in seconds
		duration_traffic: 0, // in seconds
	};
	if (route["legs"].length>0) {
		route["legs"].forEach((leg)=> {
			if (leg.hasOwnProperty("duration_in_traffic")) {
				output_route.duration += Number.parseFloat(leg.duration.value);
				output_route.duration_traffic += Number.parseFloat(leg.duration_in_traffic.value);
				output_route.distance += Number.parseFloat(leg.distance.value)/1000.0; // m to km
			}
		});
	}
	
	return output_route;
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
		console.log("Got "+pool.length+" routes for trip "+(j+1)+"/"+data.length);
		execute(j+1);
		return;
	}
	log("i:"+i+",j:"+j);
	queries[i](i, j);
}

function writeOut(outFile) {
	var csv = util.JSON2CSV(alternative_routes, util.csv_fields, "\"");
	fs.writeFile(outFile, csv, function(err) {
	  if (err) throw err;
	  console.log("partition saved to "+outFile);
	  if (partitionNum*partitionSize >= data_all.length) {
	  	process.exit(1);
	  } 
	  do_map(partitionNum+1);
	});	
}

function execute(trip_idx) {
	if (trip_idx >= data.length) {
		console.log("Got "+alternative_routes.length+" alternative routes for "+trip_idx+" trips.");
		setTimeout(()=>{ 
			writeOut("groutes/partition_"+partitionNum+".csv"); 
		}, 1);
		return;
	}
	// console.log("Got "+pool.length+" routes for trip "+(trip_idx)+"/"+data.length);
	trip = data[trip_idx];
	log(trip);
	if (trip == null || trip == undefined || !trip.hasOwnProperty('id')) { 
		console.log("null trip "+trip_idx);
		// execute(trip_idx+1);
		return; 
	}
	pool = [];
	durations = {};
	prepare_params(trip);
	nextQuery(0, trip_idx);
}

function do_map(start) {
	partitionNum = start;
	var first = partitionNum*partitionSize;
	var last = (partitionNum+1)*partitionSize;
	log(partitionNum);
	if (first >= data_all.length) {
		// do_reduce();
		setTimeout(()=>{ writeOut("groutes/partition_"+partitionNum+".csv"); }, 1);
		return;
	}
	console.log("Partition "+partitionNum+"/"+Math.floor(data_all.length/partitionSize));
	alternative_routes = [];
	data = data_all.slice(first, last);
	execute(0);
}

function do_reduce() {
	// var cmd = "./merge_csv_file.py --input_dir groutes --out "+outFile;
	var cmd = "python merge_csv_file.py --input_dir groutes --out "+outFile;
	child_process.exec(cmd, function(err, stdout, stderr) {
		console.log('alternative_routes saved to '+outFile);
	});
} 

function begin(inputFile) {
	fs.readFile(inputFile, 'utf8', function(err, csv) {
	    if (err) throw err;
	    data_all = util.CSV2JSON(csv).slice(0);
	    do_map(partitionNum);
	});
}

child_process.exec("mkdir groutes", function(err, stdout, stderr) {
	begin(inputFile);
});






