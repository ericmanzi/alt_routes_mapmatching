class TripTollPaymentsService

	def initialize(route)
		@route = route
	end

	def execute
		user = @route.user
		groups = @route.get_tolls.group_by{|toll_crossing| toll_crossing.toll.toll_road_id}
		groups.each do |toll_road, toll_crossings|
			bridges = []

			# Remove toll bridges
			toll_crossings.each do |crossing|
				if crossing.toll.is_toll_bridge?
					bridges << crossing
				end
			end
			toll_crossings -= bridges

			bridges.each do |bridge|
				truck_config = user.last_truck_configuration(bridge.timestamp)
				payment_method = user.last_payment_method(bridge.timestamp)

				# Search for possible fees
				fees = TollFee.calculate(bridge.toll, bridge.toll, truck_config, payment_method)

				peak_period = find_matching_peak_periods(bridge, fees).first

				if !peak_period.nil?
					possible_fees = fees.where(:peak_period_name => peak_period.name)
					if possible_fees.size > 0
						possible_fees.each do |f|
							TollPayment.create(payment_type: "Toll Bridge", toll_fee_id: f.id, entry_cross_id: bridge.id, exit_cross_id: bridge.id, :timestamp => bridge.timestamp)
						end
					else
						fees.each do |f|
							# Adds toll bridge fee
							TollPayment.create(payment_type: "Toll Bridge", toll_fee_id: f.id, entry_cross_id: bridge.id, exit_cross_id: bridge.id, :timestamp => bridge.timestamp)
						end
					end
				else
					fees.each do |f|
						# Adds toll bridge fee
						TollPayment.create(payment_type: "Toll Bridge", toll_fee_id: f.id, entry_cross_id: bridge.id, exit_cross_id: bridge.id, :timestamp => bridge.timestamp)
					end
				end
			end

			for i in 1..(toll_crossings.size-1)
				truck_config = user.last_truck_configuration(toll_crossings[i].timestamp)
				payment_method = user.last_payment_method(toll_crossings[i].timestamp)

				if toll_crossings[i-1].toll.is_entry? and toll_crossings[i].toll.is_exit?
					fees = TollFee.calculate(toll_crossings[i-1].toll, toll_crossings[i].toll, truck_config, payment_method)

					peak_period = find_matching_peak_periods(toll_crossings[i], fees).first
					if !peak_period.nil?
						possible_fees = fees.where(:peak_period_name => peak_period.name)
						if possible_fees.size > 0
							possible_fees.each do |f|
								TollPayment.create(payment_type: "Segment", toll_fee_id: f.id, entry_cross_id: toll_crossings[i-1].id, exit_cross_id: toll_crossings[i].id, :timestamp => toll_crossings[i].timestamp)
							end
						else
							fees.each do |f|
								TollPayment.create(payment_type: "Segment", toll_fee_id: f.id, entry_cross_id: toll_crossings[i-1].id, exit_cross_id: toll_crossings[i].id, :timestamp => toll_crossings[i].timestamp)
							end
						end
					else
						fees.each do |f|
							TollPayment.create(payment_type: "Segment", toll_fee_id: f.id, entry_cross_id: toll_crossings[i-1].id, exit_cross_id: toll_crossings[i].id, :timestamp => toll_crossings[i].timestamp)
						end
					end
				end
			end
		end

		puts "Applying total toll costs to trip..."
		@route.update_attribute(:toll_costs, @route.get_cost)
	end

	private

	def find_matching_peak_periods(toll_crossing, fees)
		# Matching toll fees which have reference to peak periods
		if fees.where.not(:peak_period_name => nil).size > 0
			# Normalize toll cross time to seconds in UTC
			crossing_time = Time.at(toll_crossing.timestamp.to_i - toll_crossing.timestamp.beginning_of_day.to_i).in_time_zone("UTC").to_i

			# Get peak periods applied on current toll road
			# check if toll was crossed in a existing peak period
			# Filter day type (weekday, weekend, holiday, etc)
			peak_periods = toll_crossing.toll.toll_road.peak_periods.where("period_start <= ? and period_end >= ?", crossing_time, crossing_time).where("day_type like ? or day_type like 'Everyday'", toll_crossing.classify_day)

			return peak_periods
		end
		return []
	end
end