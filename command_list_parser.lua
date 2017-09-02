global.current_command_set = {}
global.previous_commands = {}
global.tech_queue = {}

always_possible = {"speed"}
blocks_others = {"auto-refuel", "mine"}
blocks_movement = {"move", "mine"}

blocks_selection = {"auto-refuel", "build", "put", "take"}

always_possible_actions = {"take-from-ground", "speed", "stop-auto-move-to", "stop-auto-refuel", "stop-auto-take"}
selection_actions = {"mine", "put-stack", "rotate", "take"}
ui_actions = {"craft", "put", "recipe", "tech"}

-- TODO: "throw" and "vehicle"

inherited_actions = {
	["auto-refuel"] = "put-stack",
	["auto-move-to"] = "move",
	["auto-take"] = "take",
	["build-blueprint"] = "build",
}

default_priorities = {
	["speed"] = 5,
	["build"] = 5,
	["craft"] = 5,
	["auto-refuel"] = 5,
	["mine"] = 6,
	["auto-move-to"] = 7,
}
max_ranges = {
	["build"] = 6,
}

script.on_event(defines.events.on_research_finished, function (event)
	local force = event.research.force
	commandqueue[game.tick][#commandqueue[game.tick] + 1] =	{"tech", global.tech_queue[1]}
	table.delete(global.tech_queue, 1)
end)

function evaluate_command_list(command_list, commandqueue, myplayer, tick)
	if not command_list then
		return true
	end
	
	
	commandqueue[tick] = {}

	-- Check if we finished all commands in the current command set

	local finished = true
	local finished_commands = {}
	
	for _, command in pairs(global.current_command_set) do
		if command.data.finished and command.name then
			finished_commands[#finished_commands + 1] = command.name
		end
		
		if not command.data.finished then
			finished = false
		end
	end
	
	-- TODO: set finished to true if finished_commands and command_list[2].required have the same elements
	

	-- Add the next command group to the current command set.
	if finished then
		if not command_list[1] then
			return false
		end
		
		-- TODO: Add, not overwrite here.
		global.current_command_set = command_list[1].commands
		for i, command in ipairs(global.current_command_set) do
			if command[1] == "tech" then
				if myplayer.force.current_research then
					global.tech_queue[#global.tech_queue + 1] = command[2]
				else
					commandqueue[tick][#commandqueue[tick] + 1] = command
				end
				table.delete(global.current_command_set, i)
			end
		end
		table.remove(command_list, 1)
		
		for _, command in pairs(global.current_command_set) do
			command.data = {}
			
			if not command.priority then
				command.priority = default_priorities[command[1]]
			end
		end
	end

	-- 	Determine which commands we can execute this tick
	local executable_commands = {}
	
	for _, command in pairs(global.current_command_set) do
		if command_executable(command, myplayer, tick) then
			executable_commands[#executable_commands + 1] = command
		end
	end
	
	-- Determine first out of range command
	local leaving_range_command = nil
	
	for _, command in pairs(executable_commands) do
		if leaving_range(command, myplayer, tick) then
			leaving_range_command = command
			break
		end
	end
	
	-- Process out of range command if it exists
	if leaving_range_command then
		commandqueue[tick][#commandqueue[tick] + 1] = to_low_level(leaving_range_command, myplayer, tick)
		add_compatible_commands(executable_commands, commandqueue[tick], myplayer)
				
		if tables_equal(global.previous_commands, commandqueue[tick]) then
			commandqueue[tick] = {}
		else
			global.previous_commands = commandqueue[tick]
		end
		
		return true
	end
	

	-- Otherwise execute first command with highest priority.
	if #executable_commands > 0 then
		local command = executable_commands[1]
		for _, com in pairs(executable_commands) do
			if command.priority > com.priority then
				command = com
			end
		end

		commandqueue[tick][#commandqueue[tick] + 1] = to_low_level(command, myplayer, tick)
		
		add_compatible_commands(executable_commands, commandqueue[tick], myplayer)
		if tables_equal(global.previous_commands, commandqueue[tick]) then
			commandqueue[tick] = {}
		else
			global.previous_commands = commandqueue[tick]
		end
	end
	return true
end

function to_low_level(command, myplayer, tick)
	if command[1] == "auto-move-to" then		
		if not command.data.moveData then
			command.data.moveData = {}
		
			if command[2][2] < myplayer.position.y then
				command.data.moveData.N = true
			end
		
			if command[2][2] > myplayer.position.y then
				command.data.moveData.S = true
			end
		
			if command[2][1] > myplayer.position.x then
				command.data.moveData.E = true
			end
		
			if command[2][1] < myplayer.position.x then
				command.data.moveData.W = true
			end
		end
		
		local move_dir = ""
		
		-- TODO: Test if this works when we walk on transport belts
		-- Could replace this by
		-- if command[2][2] < myplayer.position.y - epsilon then
		-- 	move_dir = move_dir .. "N"
		-- end
		if command[2][2] < myplayer.position.y and not command.data.moveData.S then
			move_dir = move_dir .. "N"
		end
		
		if command[2][2] > myplayer.position.y and not command.data.moveData.N then
			move_dir = move_dir .. "S"
		end
		
		if command[2][1] > myplayer.position.x and not command.data.moveData.W then
			move_dir = move_dir .. "E"
		end
		
		if command[2][1] < myplayer.position.x and not command.data.moveData.E then
			move_dir = move_dir .. "W"
		end
		
		if move_dir == "" then
			move_dir = "STOP"
			command.data.finished = true
		end
		
		return {"move", move_dir}
	end
	
	if command[1] == "auto-refuel" then
		if not command.data.started then
			command.data.started = tick
		end
		
		return {"put", command[3], "coal", 1, defines.inventory.fuel}
	end
	
	if command[1] == "craft" or command[1] == "build" or command[1] == "speed" or command[1] == "rotate" then
		command.data.finished = true
		return command
	end
	
	if command[1] == "mine" then
		return command
	end
end

function command_executable(command, myplayer, tick)
	if command.data.finished then
		return false
	end
	
	if command.on_entering_range then
		if command[1] == "build" then
			distance = myplayer.build_distance
		end
		
		if sqdistance(command[3], myplayer.position) > distance^2 then
			return false
		end
	end
	
	if command[1] == "auto-refuel" then
		if myplayer.get_item_count("coal") == 0 then
			return false
		end
			
		if command.data.started then
			local frequency = 0
		
			if command[2] == "m" then -- mining drill
				frequency = 1600
			end
		
			if command[2] == "f" then -- stone furnace
				frequency = 2660
			end
		
			if (command.data.started - tick) % frequency > 0 then
				return false
			end
		end
	end
	
	if command[1] == "mine" then
		if myplayer.mining_state.mining == true then
			return false
		end
	end
	if command.on_leaving_range and not leaving_range(command, myplayer, tick) then
		return false
	end
	
	return true
end

function leaving_range(command, myplayer, tick)
	if command.data.range_check_tick == game.tick then return command.data.leaving_range end

	command.data.range_check_tick = game.tick
	local distsq = command_sqdistance(command, myplayer)
	if not command.data.last_range_sq then 
		command.data.last_range_sq = distsq
	else
		local max_range = command.leaving_range or max_ranges[command[1]] or 6
		if command.data.last_range_sq < distsq and distsq < max_range*max_range and 0.9*max_range*max_range < command.data.last_range_sq then 
			command.data.last_range_sq = distsq
			command.data.leaving_range = true
			return true
		end
		command.data.last_range_sq = distsq
	end
	command.data.leaving_range = false
	return false
end

function command_sqdistance(command, player)
	local position = nil
	if has_value({"rotate", "recipe", "take", "put", "mine"}, command[1]) then position = command[2]
	elseif command[1] == "auto-move-to" or command[1] == "build" then position = command[3]
	end
	
	if position then 
		return sqdistance(position, player.position)
	else 
		return nil 
	end
end

function add_compatible_commands(executable_commands, commands, myplayer)
	-- TODO: Allow more than one command in the commands list here!
	if #commands ~= 1 then
		game.print(serpent.block(commands))
		error("Function add_compatible_commands: commands parameter has not exactly one element.")
	end
	local command = commands[1]

	if has_value(selection_actions, basic_action(command)) then -- if you want things to happen in the same frame, use the exact same coordinates!
		coordinates = command[2] -- all selection actions have there coordinates at [2]
		
		local priority_take_or_put = nil
		
		if not has_value({"put-stack", "take"}, basic_action(command)) then
			-- find the highest priority take or put-stack action at this position
			
			for _, comm in pairs(executable_commands) do
				if has_value({"put-stack", "take"}, basic_action(comm)) and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] then
					if not priority_take_or_put and priority_take_or_put.priority > comm.priority then
						priority_take_or_put = comm
					end
				end
			end
		else
			priority_take_or_put = command
		end
		
		local forbidden_action = ""
		
		if priority_take_or_put and basic_action(priority_take_or_put) == "put-stack" then
			forbidden_action = "take"
		else
			forbidden_action = "put-stack"
		end
		
		for _, comm in pairs(executable_commands) do
			if has_value(selection_actions, comm) and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] then
				if basic_action(comm) ~= forbidden_action then
					commands[#commands + 1] = comm
				end
			end
		end
	end
	
	-- TODO: move and mine are incompatible, do something about UI interactions
end

function sqdistance(pos1, pos2)
	local x1 = 0
	local y1 = 0
	local x2 = 0
	local y2 = 0

	if pos1.x then 
		x1 = pos1.x
		y1 = pos1.y
	else
		x1 = pos1[1]
		y1 = pos1[2]
	end
	if pos2.x then 
		x2 = pos2.x
		y2 = pos2.y
	else
		x2 = pos2[1]
		y2 = pos2[2]
	end
	return (x1 - x2)^2 + (y1 - y2)^2
end

function has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	
	return false
end

function tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
end

function basic_action(command)
	return inherited_actions[command[1]] or command[1]
end
