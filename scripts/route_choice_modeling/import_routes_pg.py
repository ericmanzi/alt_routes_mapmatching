#!/usr/bin/python
from __future__ import print_function
from datetime import datetime
from prompt_toolkit import AbortAction, prompt
import sys, csv
#import mysql.connector
import psycopg2

'''
This script imports alternate route records from the supplied csv file into the specified database

Usage: 
chmod +x import_alternate_routes.py
./import_alternate_routes.py --input_file alternate_routes_615.csv --user root --db fmsurvey --adapter mysql --host '127.0.0.1'

Dependencies:
- mysql-connector
- prompt_toolkit

sudo apt-get install python-pip
sudo pip install mysql-connector
sudo pip install prompt_toolkit

'''

user = 'root'
host = '127.0.0.1'
db = 'fmsurvey'
input_file='alternate_routes_all_with_id.csv'
TIME_FMT = '%Y-%m-%d %H:%M:%S'

from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--input_file", help="Path to directory containing csv file to import", default="alternate_routes.csv")
parser.add_argument("--user", help="user who owns database", default="root")
parser.add_argument("--db", help="database name", default="fmsurvey")
parser.add_argument("--adapter", help="database adapter", default="mysql")
parser.add_argument("--host", help="host", default="127.0.0.1")

args = parser.parse_args()

def create_table(adapter):
	if adapter=='mysql':
		return create_table_mysql()
	elif adapter=='psql':
		return create_table_psql()
	else:
		return None

def create_table_mysql():
	q = '''
	CREATE TABLE alternate_routes (id int(11), trip_id varchar(20), user_id int(11), 
	summary varchar(255), distance double, duration int, duration_traffic int, 
	start_time datetime, provider varchar(255), avoid_tolls tinyint(1), num_intermediate_stops int(11),
	num_points int(11), original_duration int(11), original_distance double, 
	min_duration_traffic int(11), max_duration_traffic int(11), polyline text, 
	map_matched_polyline text, toll_costs double, overlap double, 
	highest_overlap tinyint(1), toll_crossings_count int(11), h_distance double, 
	road_classification text, speed_classification text, road_distribution text, 
	road_distribution_percent text);
	'''
	return q	

def create_table_psql():
	q = '''
	CREATE TABLE alternate_routes (id integer, trip_id varchar(20), user_id integer, 
	summary varchar(255), distance double precision, duration integer, duration_traffic integer, 
	start_time timestamp, provider varchar(255), avoid_tolls integer, num_intermediate_stops integer,
	num_points integer, original_duration integer, original_distance double precision, 
	min_duration_traffic integer, max_duration_traffic integer, polyline text, 
	map_matched_polyline text, toll_costs double precision, overlap double precision, 
	highest_overlap integer, toll_crossings_count integer, h_distance double precision, 
	road_classification hstore, speed_classification hstore, road_distribution hstore, 
	road_distribution_percent hstore);
	'''
	return q	

def create_index():
	q = '''
	CREATE INDEX alternate_route_id_idx ON alternate_routes (id);
	'''
	return q

def gen_route_data(data):
	fields = ['id', 'trip_id', 'user_id', 'summary', 'distance', 'duration', 'duration_traffic', 'start_time', 'provider', 'avoid_tolls', 'num_intermediate_stops', 'num_points', 'original_duration', 'original_distance', 'min_duration_traffic', 'max_duration_traffic', 'polyline']
	dm = {
		'id': lambda x: int(x),
		'trip_id': lambda x: str(x),
		'user_id': lambda x: int(x),
		'summary': lambda x: str(x),
		'distance': lambda x: float(x),
		'duration': lambda x: int(x),
		'duration_traffic': lambda x: int(x),
		'start_time': lambda x: datetime.strptime(str(x), TIME_FMT),
		'provider': lambda x: str(x),
		'avoid_tolls': lambda x: int(x),
		'num_intermediate_stops': lambda x: int(x),
		'num_points': lambda x: int(x),
		'original_duration': lambda x: int(round(float(x))),
		'original_distance': lambda x: float(x),
		'min_duration_traffic': lambda x: int(x),
		'max_duration_traffic': lambda x: int(x),
		'polyline': lambda x: str(x)
	}

	return map(lambda route: tuple(map(lambda col: dm[col](route[col]), fields)), data)


def ReadCSVFileToList(filename):
    with open(filename) as file_obj:
        return list(csv.DictReader(file_obj, delimiter=','))

def main():
	data = ReadCSVFileToList(args.input_file)

	insert_primer = ("INSERT INTO alternate_routes "
		"(id, trip_id, user_id, summary, distance, duration, duration_traffic, start_time, provider, avoid_tolls, num_intermediate_stops, num_points, original_duration, original_distance, min_duration_traffic, max_duration_traffic, polyline)"
		"VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)")
	
	passwd = prompt(u'Enter password for this database (leave empty if none): ')
	print(passwd)

	if args.adapter == 'mysql':
		pass
#	    if passwd == '':
#	    	cnx=mysql.connector.connect(user=args.user, host=args.host, database=args.db)
#	    else:
#	    	cnx=mysql.connector.connect(user=args.user, host=args.host, database=args.db, password=passwd)
        elif args.adapter == 'psql':
	    cnx=psycopg2.connect(
		"dbname='%s' user='%s' host='%s' password='%s'" % 
		(args.db, args.user, args.host, passwd)
		)
	else:
    		print("No adapter provided.")
    		return

	try:
		cursor = cnx.cursor()
		cursor.execute(create_table(args.adapter))
		cnx.commit()

		route_data = gen_route_data(data)
		# print(route_data)
		cursor.executemany(insert_primer, route_data)
		cnx.commit()

		cursor.execute(create_index())
		cnx.commit()
		cursor.close()
	finally:
		cnx.close()


if __name__ == '__main__':
	main()
