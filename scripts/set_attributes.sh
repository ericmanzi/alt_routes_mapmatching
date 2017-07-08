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

# rails runner -e development app/jobs/set_mm_id.rb
rails runner -e development app/jobs/set_dist_attributes.rb $START $END