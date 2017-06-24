class RouteTollPaymentsService

	def initialize(route)
		@route = route
	end

	def execute
		# user = @route.trip.user rescue nil
		truck_config = "Single unit only"
		payment_method = "Electronic toll tag, please specify which one:"
		groups = @route.toll_crossings.group_by{|toll_crossing| toll_crossing.toll.toll_road_id}
		groups.each do |toll_road, toll_crossings|
			puts "[#{@route.id}] Toll Road #{toll_road}"
			bridges = []

			# Remove toll bridges
			toll_crossings.each do |crossing|
				if crossing.toll.is_toll_bridge?
					bridges << crossing
				end
			end
			toll_crossings -= bridges

			puts "[#{@route.id}] Bridges: #{bridges.map{|t| t.toll.name}}"
			puts "[#{@route.id}] Tolls: #{toll_crossings.map{|t| t.toll.name}}"

			bridges.each do |bridge|
				# truck_config = user.last_truck_configuration(bridge.timestamp)
				# payment_method = user.last_payment_method(bridge.timestamp)

				fee = TollFee.calculate(bridge.toll, bridge.toll, truck_config, payment_method)
				fee.each do |f|
					# Adds toll bridge fee
					puts "[#{@route.id}] Toll Payment on #{bridge.toll.toll_road.name}: #{bridge.toll.name} Bridge: #{f.amount}"
					TollPayment.create(payment_type: "Toll Bridge", toll_fee_id: f.id, entry_cross_id: bridge.id, exit_cross_id: bridge.id, :timestamp => bridge.timestamp)
				end
			end

			for i in 1..(toll_crossings.size-1)
				if toll_crossings[i-1].toll.is_entry? and toll_crossings[i].toll.is_exit?
					# truck_config = user.last_truck_configuration(toll_crossings[i].timestamp)
					# payment_method = user.last_payment_method(toll_crossings[i].timestamp)

					fee = TollFee.calculate(toll_crossings[i-1].toll, toll_crossings[i].toll, truck_config, payment_method)
					fee.each do |f|
						puts "[#{@route.id}] Toll Payment on #{toll_crossings[i].toll.toll_road.name}: #{toll_crossings[i-1].toll.name} to #{toll_crossings[i].toll.name}: #{f.amount}"
						TollPayment.create(payment_type: "Segment", toll_fee_id: f.id, entry_cross_id: toll_crossings[i-1].id, exit_cross_id: toll_crossings[i].id, :timestamp => toll_crossings[i].timestamp)
					end
				end
			end
		end

		puts "[#{@route.id}] Applying total toll costs to alternate route..."
		@route.update_attribute(:toll_costs, @route.get_cost)
	end
end