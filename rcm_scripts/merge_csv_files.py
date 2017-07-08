#!/usr/bin/env python

# Helper script to merge csv files
# Usage: ./merge_csv_files.py --input_dir ROUTES_DIRECTORY --out OUTPUT_FILE

import os, sys, csv
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--input_dir", help="Path to directory containing csv files to merge", default="routes")
parser.add_argument("--out", help="Path to output file", default="routes_merged.csv")

args = parser.parse_args()

if len(args.input_dir) == 0 or len(args.out) == 0:
	print 'Incorrect usage: Both --input_dir and --out are required.'
	sys.exit(1)

input_files = os.listdir(args.input_dir)

input_filenames = map(lambda f: os.path.join(args.input_dir, f), input_files)

csv_fields = [
	'trip_id',
	'user_id',
	'summary',
	'distance',
	'duration',
	'duration_traffic',
	'start_time',
	'provider',
	'avoid_tolls',
	'num_intermediate_stops',
	'num_points', 
	'original_duration',
	'original_distance',
	'min_duration_traffic',
	'max_duration_traffic',
	'polyline',
]

# Opens input csv file and returns rows as list of objects keyed by the column name
def ReadCSVFileToList(filename):
    with open(filename) as file_obj:
        return list(csv.DictReader(file_obj, delimiter=','))

data = []

for f in input_filenames:
	print f
	routes=ReadCSVFileToList(f)
	data+=routes
	print "Adding %d routes from %s" % (len(routes), f)

with open(args.out, 'wb') as output_file:
	dw = csv.DictWriter(output_file, csv_fields, quoting=csv.QUOTE_ALL)
	dw.writeheader()
	dw.writerows(data)

print "Done. Output written to %s. %d trips in total" % (args.out, len(data))

