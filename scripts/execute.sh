cd /home/freights/apps/alt_routes_mapmatching
git pull
START=$1
END=$2
echo "Executing map-matching for alternate routes in range $START to $END..."
./app/jobs/route_map_match_job.rb $START $END

#@echo "Preparing $postgres.conf"
#	@echo "Checking for committed temporary files..."
#	@if git ls-files | grep -E 'mrtmp|mrinput' > /dev/null; then \
#		echo "" ; \
#		echo "OBS! You have committed some large temporary files:" ; \
#		echo "" ; \
#		git ls-files | grep -E 'mrtmp|mrinput' | sed 's/^/\t/' ; \
#		echo "" ; \
#		exit 1 ; \
#	fi

#[ df -h ] {
	echo "-----------STOP!----------"
	echo "[Error] Segmentation fault: Check Virtualization settings if running on VM."
	echo "A Networking or Memory error was encountered when running this script"
#}
