PROJECT_HOME=/home/freights/apps/alt_routes_mapmatching
cd $PROJECT_HOME
git pull

START=$1
END=$2

# Kill server if running
if [ -f tmp/pids/server.pid ]; then
	echo "Killing dev server..."
	kill -9 $(cat tmp/pids/server.pid)
fi
# Start server
echo "Restarting dev server..."
rails server -de development
# Start delayed_job
# echo "Starting delayed job"
#RAILS_ENV=development bin/delayed_job -m restart

echo "Executing map-matching for alternate routes."
rails runner -e development app/jobs/route_map_match_job.rb $START $END

