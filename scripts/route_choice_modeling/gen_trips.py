#!/usr/bin/env python

# This script finds trips with 'pick up cargo' stops as origin and 'deliver cargo' stops as destination
# It then generates a csv file 'cargo_trips.csv' with the resulting trips

# To execute this script: 
# > chmod +x gen_trips.py
# > ./gen_trips.py

import time, datetime, calendar
import os, sys
import csv
import math


outfile='cargo_trips_bos.csv' # Name of output file
# outfile='cargo_trips_sg.csv'

base_dir = '/tmp/cargo_stops/' # This is the directory containing the stop and travel data files
# base_dir = '/tmp/cargo_stops/sg/'


# Opens input csv file and returns rows as list of objects keyed by the column name
def ReadCSVFileToList(filename):
    with open(filename) as file_obj:
        return list(csv.DictReader(file_obj, delimiter=','))

TIME_FMT = '%Y-%m-%d %H:%M:%S'
def parse_time(time_str):
    return time.mktime((datetime.datetime.strptime(time_str, TIME_FMT)).timetuple())

def get_next_day(time_str):
	return time.mktime((datetime.datetime.strptime(time_str, TIME_FMT)+datetime.timedelta(days=1)).timetuple())

def sample(arr, size):
	bin_size = float(len(arr))/size
	indices = [int(round(idx*bin_size)) for idx in range(0, size)]
	return map(lambda i: arr[i], indices)

# Find next delivery stop if one exists in the next 24 hours
def get_succeeding_delivery_stops(pick_up_stop):
	pick_up_end_time = parse_time(pick_up_stop["end_time"])
	return sorted(filter(
		lambda s: s["user_id"] == pick_up_stop["user_id"] # same user
			and parse_time(s["start_time"]) > pick_up_end_time
			and parse_time(s["start_time"]) < get_next_day(pick_up_stop["end_time"])
			# and s["start_time"].split(" ")[0] == pick_up_stop["end_time"].split(' ')[0] # same date
			, delivery_stops), key=lambda k: parse_time(k["start_time"]))

# find first delivery stop in time range between current pick up stop and next pick up stop 
# and by same user. 
# Returns None, None if: 
# 	no such stop is found
# 	the delivery stop starts 24 hours after the corresponding pick up stop
# 	there exists an intermediate stop that lasts longer than 4 hours between this stop and the pick up stop
# Otherwise, returns:
# 	delivery stop, intermediate stops
def get_corresponding_delivery(pick_up_stop, next_pickup):
	global deliveries_in_range_miss_counter
	global delivery_after_24hr_counter
	global long_intermediate_stop_counter

	deliveries_in_range = sorted(filter(
		lambda s: s['user_id'] == pick_up_stop['user_id'] 
		and parse_time(s['start_time']) > parse_time(pick_up_stop['end_time']) 
		and parse_time(s['end_time']) < parse_time(next_pickup['start_time']), 
		delivery_stops), key=lambda k: parse_time(k['start_time']))
	if len(deliveries_in_range) > 0:
		delivery_stop = deliveries_in_range[0]
		# time between pick up and drop off can't be longer than 24 hours
		if parse_time(delivery_stop['start_time']) - parse_time(pick_up_stop['end_time']) < 24*60*60:
			intermediate_stops = find_intermediate_stops(pick_up_stop, delivery_stop)
			if len(intermediate_stops) > 0:
				avg_intermediate_stop_duration = sum(
					map(lambda s: parse_time(s['end_time']) - parse_time(s['start_time']), intermediate_stops)
				)/len(intermediate_stops)
				durations = {'min': 4*60*60, 'max': 0, 'avg': avg_intermediate_stop_duration}
				for stop in intermediate_stops:
					stop_duration = parse_time(stop['end_time']) - parse_time(stop['start_time'])
					# Ignore trip if there exists an intermediate stop that lasts longer than 4 hours
					if stop_duration >= 4*60*60:
						long_intermediate_stop_counter+=1
						return None, None, None
					durations['min'] = min(durations['min'], stop_duration)
					durations['max'] = max(durations['max'], stop_duration)
				# max_waypoints = 8 as in ferrovial 
				if len(intermediate_stops) > 8:
					intermediate_stops = sample(intermediate_stops, 8)
				waypoints = str.join("|", map(lambda s: 'via:'+s['lat']+','+s['lon'], intermediate_stops))
				return delivery_stop, waypoints, durations
			else:
				return delivery_stop, "", {'min': 0, 'max': 0, 'avg': 0}
		else: 
			delivery_after_24hr_counter+=1

	deliveries_in_range_miss_counter+=1
	return None, None, None


def find_next_pickup(pick_up_stop):
	succeeding_pickups = sorted(filter(lambda p: p['user_id'] == pick_up_stop['user_id'] 
		and parse_time(p["start_time"]) > parse_time(pick_up_stop["end_time"]), 
		pick_up_stops), key=lambda k: parse_time(k['start_time']))
	if len(succeeding_pickups) > 0:
		return succeeding_pickups[0]
	else:
		return None


def find_intermediate_stops(pick_up_stop, delivery_stop):
	return sorted(filter(lambda s: s['user_id'] == pick_up_stop['user_id'] 
		and parse_time(s['start_time']) > parse_time(pick_up_stop['end_time'])
		and parse_time(s['end_time']) < parse_time(delivery_stop['start_time']), other_stops), 
	key=lambda k: parse_time(k['start_time']))


def find_travels_in_range(pick_up_stop, delivery_stop):
	return filter(
		lambda t: t["user_id"] == pick_up_stop["user_id"]
		and parse_time(t["start_time"]) >= parse_time(pick_up_stop["end_time"])
		and parse_time(t["end_time"]) <= parse_time(delivery_stop["start_time"]), 
		travels)


# generate unique number from 2 distinct positive integers a and b
def cantor_pair(a, b):
	return ((a+b+1)*(a+b))/2 + b

def cantor_inverse(z):
	w = math.floor((math.sqrt((8*z)+1)-1)/2)
	y = z-(w**2+w)/2
	x = w-y
	return int(x), int(y)


travels = ReadCSVFileToList(base_dir+'travels.csv')
pick_up_stops = ReadCSVFileToList(base_dir+'pick_up_cargo_stops.csv')
delivery_stops = ReadCSVFileToList(base_dir+'deliver_cargo_stops.csv')
other_stops = ReadCSVFileToList(base_dir+'other_stops.csv')

output_trips = []

hit_counter = 0
next_pickup_miss_counter = 0
matched_travels_miss_counter = 0
long_intermediate_stop_counter = 0
signal_loss_counter = 0
delivery_after_24hr_counter = 0
deliveries_in_range_miss_counter = 0


# BEGIN EXECUTION
for pick_up_stop in pick_up_stops:

	delivery_stop = None
	next_pickup = find_next_pickup(pick_up_stop)

	if next_pickup is None:
		succeeding_deliveries = get_succeeding_delivery_stops(pick_up_stop)
		if len(succeeding_deliveries) == 0:
			next_pickup_miss_counter+=1
			continue
		next_pickup = {}
		next_pickup["start_time"]=datetime.datetime.strftime(datetime.datetime.strptime(
			succeeding_deliveries[0]["end_time"], TIME_FMT)+datetime.timedelta(minutes=1), TIME_FMT)
		# print "NONE: next_pickup[start_time]:", next_pickup["start_time"]
	delivery_stop, waypoints, intermediate_stop_durations = get_corresponding_delivery(pick_up_stop, next_pickup)
	if delivery_stop is None:
		# print "pick_up_stop[start_time]:", pick_up_stop["start_time"]
		# print "next_pickup[start_time]:", next_pickup["start_time"]
		# print "---------------"
		continue

	matched_travels = find_travels_in_range(pick_up_stop, delivery_stop)
	if len(matched_travels) == 0:
		matched_travels_miss_counter+=1
		continue

	num_intermediate_stops = 0
	if waypoints != "":
		num_intermediate_stops = len(waypoints.split("|"))

	if num_intermediate_stops+1 != len(matched_travels):
		signal_loss_counter += 1
		# print map(lambda x: x["start_time"]+"__|__"+x["end_time"]+"__|__"+x["trip_distance"], matched_travels)
	# print map(lambda x: x["trip_distance"], matched_travels)

	t = {
		'id': cantor_pair(int(pick_up_stop['stop_id']), int(delivery_stop['stop_id'])),
		'origin_id': pick_up_stop['stop_id'],
		'destination_id': delivery_stop['stop_id'],
		'user_id': pick_up_stop['user_id'],
		'start_time': matched_travels[0]['start_time'],
		'end_time': matched_travels[-1]['end_time'],
		'origin_lat': pick_up_stop['lat'],
		'origin_lon': pick_up_stop['lon'],
		'destination_lat': delivery_stop['lat'],
		'destination_lon': delivery_stop['lon'],
		'waypoints': waypoints, # intermediate stop coords
		'num_intermediate_stops': num_intermediate_stops,
		'trip_distance': sum(map(lambda x: float(x['trip_distance']) 
			if x['trip_distance'] != '\\N' and x['trip_distance'] != 'NULL' else 0, 
			matched_travels)), # in meters (i think)
		'duration_without_stops': sum(map(lambda x: 
			parse_time(x["end_time"])-parse_time(x["start_time"]), 
			matched_travels)), # in seconds
		'duration_with_stops': parse_time(delivery_stop['start_time'])-parse_time(pick_up_stop['end_time']), # in seconds
		'min_intermediate_stop_duration': intermediate_stop_durations['min'],
		'max_intermediate_stop_duration': intermediate_stop_durations['max'],
		'avg_intermediate_stop_duration': intermediate_stop_durations['avg'],
	}
	
	hit_counter+=1

	output_trips.append(t)


print "pick_up_stops:",len(pick_up_stops)
print "hit:",hit_counter
print "no next pickup:",next_pickup_miss_counter
print "matched_travels_miss:",matched_travels_miss_counter
print "possible signal loss:",signal_loss_counter
print "long intermediate stops:",long_intermediate_stop_counter
print "delivery 24hrs after pickup:",delivery_after_24hr_counter
print "no deliveries until next pickup:",deliveries_in_range_miss_counter

keys = [
	'id',
	'user_id',
	'origin_id',
	'destination_id',
	'start_time',
	'end_time',
	'origin_lat',
	'origin_lon',
	'destination_lat',
	'destination_lon',
	'trip_distance',
	'duration_without_stops',
	'duration_with_stops',
	'waypoints',
	'num_intermediate_stops',
	'min_intermediate_stop_duration',
	'max_intermediate_stop_duration',
	'avg_intermediate_stop_duration',
]


with open(outfile, 'wb') as output_file:
	dw = csv.DictWriter(output_file, keys, quoting=csv.QUOTE_ALL)
	dw.writeheader()
	dw.writerows(output_trips)


"""
General stats for boston data
---
pick_up_stops: 431
hit: 252
next_pickup_miss: 10
matched_travels_miss: 8
possible signal loss: 45
long intermediate stops: 14
delivery 24hrs after pickup: 16

General stats for HPV URA data
---
pick_up_stops: 3033
hit: 1233
no next pickup: 89
matched_travels_miss: 108
possible signal loss: 14
long intermediate stops: 1
delivery 24hrs after pickup: 0
no deliveries until next pickup: 1602
"""

print "Done. Output written to %s" % outfile



