// utils.js

var moment = require('moment');

var Utils = {

	CSVToArray: function(strData) {
		strDelimiter = ",";
		var objPattern = new RegExp((
		"(\\" + strDelimiter + "|\\r?\\n|\\r|^)" +
		"(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
		"([^\"\\" + strDelimiter + "\\r\\n]*))"), "gi");
		var arrData = [[]];
		var arrMatches = null;
		while (arrMatches = objPattern.exec(strData)) {
		    var strMatchedDelimiter = arrMatches[1];
		    if (strMatchedDelimiter.length && (strMatchedDelimiter != strDelimiter)) {
		        arrData.push([]);
		    }
		    if (arrMatches[2]) {
		        var strMatchedValue = arrMatches[2].replace(new RegExp("\"\"", "g"), "\"");
		    } else {
		        var strMatchedValue = arrMatches[3];
		    }
		    arrData[arrData.length - 1].push(strMatchedValue);
		}
		return (arrData);
	},

	CSV2JSON: function(csv) {
		var array = this.CSVToArray(csv);
    	var objArray = [];
    	for (var i = 1; i < array.length; i++) {
    	    objArray[i - 1] = {};
    	    for (var k = 0; k < array[0].length && k < array[i].length; k++) {
    	        var key = array[0][k];
    	        objArray[i - 1][key] = array[i][k]
    	    }
    	}
    	return objArray;
	},

	JSON2CSV: function(data, fields, quotes) {
		q = quotes;
		lines = [];
		header = q+fields.join(q+","+q)+q;
		lines.push(header);
		data.forEach((row)=>{
			line=q+fields.map((f)=>row[f]).join(q+","+q)+q;
			lines.push(line);
		});
		return lines.join("\n");
	},

	get_next_similar_time: function(departure_time_str) {
		// The departure_time must be set to the current time or some time in the future. It cannot be in the past.
		// Deprecated: Returns new date with the same time of day, day of week and week of year next year
		// Returns new date with the same time of day, day of week next week
		// Assumes time is in UTC
		var date = moment(departure_time_str);
		day_of_week = date.weekday();
		// week_of_year = Number.parseInt(date.format('W'));
		var today = moment();
		var week_of_year = Number.parseInt(today.format('W'));
		// target = moment().day(day_of_week).year(date.year()+1).week(week_of_year);
		target = moment().day(day_of_week).year(today.year()).week(week_of_year+1);
	
		target.second(date.second());
		target.minute(date.minute());
		target.hour(date.hour());
	
		return ""+target.unix();
	},

	format_time_bing: function(time_str) {
		return moment(time_str).format("MM/DD/YYYY HH:mm:ss");
	},

	makeArrayFromRange: function(a, b, d) {
		r=[];
		for (var i=a; i<=b; i+=d) { 
			r.push(i); 
		}
		return r;
	},

	csv_fields: [
	'trip_id',
	'user_id',
	'summary',
	'distance',
	'duration',
	'duration_traffic',
	'start_time',
	'provider',
	'avoid_tolls',
	// 'avoid_ferries',
	// 'avoid_highways',
	// 'alternative_route_leg_count',
	'num_intermediate_stops',
	'num_points',
	'original_duration',
	'original_distance',
	'min_duration_traffic',
	'max_duration_traffic',
	'polyline',

	],

}

module.exports = Utils;

