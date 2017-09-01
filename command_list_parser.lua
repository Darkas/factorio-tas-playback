global.current_command_set = {}
global.previous_commands = {}

always_possible = {"speed"}
blocks_others = {"auto-refuel", "mine"}
blocks_movement = {"move", "mine"}
blocks_selection = {"auto-refuel", "put", "take"}

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


function evaluate_command_list(command_list, commandqueue, myplayer, tick)
	if not command_list then
		return true
	end
	
	
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
	local out_of_range_command = nil
	
	for _, command in pairs(executable_commands) do
		if out_of_range(command, myplayer, tick) then
			out_of_range_command = command
			break
		end
	end
	
	-- Process out of range command if it exists
	if out_of_range_command then
		add_compatible_commands(out_of_range_command, executable_commands, commandqueue[tick], myplayer)
				
	-- Determine blocking command with highest priority
	local blocking_command = nil
	
	for _, command in pairs(executable_commands) do
		if has_value(blocks_others, command[1]) then
			if not blocking_command or blocking_command.priority > command.priority then
				blocking_command = command
			end
		end
	end
	
	-- Process blocking command if it exists
	if blocking_command then
		commandqueue[tick] = {to_low_level(blocking_command, myplayer, tick)}
		
		for _, command in pairs(global.current_command_set) do
			if has_value(always_possible, command[1]) then
				commandqueue[tick][#commandqueue[tick] + 1] = to_low_level(command, myplayer, tick)
			end
		end
		
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
			if command.priority < com.priority then
				command = com
			end
		end
	-- Otherwise execute all commands we can.
	commandqueue[tick] = {}
		
		add_compatible_commands(command, executable_commands, commandqueue[tick], myplayer)
		if serpent.block(global.previous_commands) == serpent.block(commandqueue[tick]) then
			commandqueue[tick] = {}
		else
			global.previous_commands = commandqueue[tick]
		end
	end
	
	return true
end
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
	
	if command[1] == "craft" or command[1] == "build" or command[1] == "speed" then
		command.data.finished = true
		return command
	end
	
	if command[1] == "mine" then
		return command
	end
	
	if command[1] == "rotate" then

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
	
	return true
end

function out_of_range(command, myplayer, tick) 
	if not command.data.last_range then 
		command.data.last_range = command_sqdistance(command, myplayer)
		-- if not command.data.last_range then return false end
	else
		local dist = command_sqdistance(command, myplayer)
		-- TODO: command.range does not exist!
		local max_range = command.out_of_range or max_ranges[commands[1]] or 6
		if command.data.last_range < dist and command.data.last_range < max_range then 
			command.data.last_range = dist
			return true
		end
		command.data.last_range = dist
	end
	return false
end

function command_sqdistance(command, player)
	local position = nil
	if command[1] == "build" then position = command[3]
	elseif command[1] == "auto-move-to" then position = command[2]
	end
	
	if position then 
		return sqdistance(position, player.position)
	else 
		return nil 
	end
end

function add_compatible_commands(command, executable_commands, commands, myplayer)
	commands = {command}
	
	if has_value(selection_actions, basic_action(command)) then -- if you want things to happen in the same frame, use the exact same coordinates!
		coordinates = command[2] -- all selection actions have there coordinates at [2]
		
		local priority_take_or_put = nil
		
		if not has_value({"put-stack", "take"}, basic_action(command)) then
			-- find the highest priority take or put-stack action at this position
			
			for _,comm in pairs(executable_commands) do
				if has_value({"put-stack", "take"}, basic_action(com)) and com[2][1] == coordinates[1] and com[2][2] == coordinates[2] then
					if not priority_take_or_put and priority_take_or_put.priority > comm.priority then
						priority_take_or_put = comm
					end
				end
			end
		else
			priority_take_or_put = command
		end
		
		local forbidden_action = ""
		
		if basic_action(priority_take_or_put) == "put-stack" then
			forbidden_action = "take"
		else
			forbidden_action = "put-stack"
		end
		
		for _,comm in pairs(executable_commands) do
			if has_value(selection_actions, com) and com[2][1] == coordinates[1] and com[2][2] == coordinates[2] then
				if basic_action(com) ~= forbidden_action then
					commands[#commands + 1] = com
				end
			end
		end
	end
	
	-- TODO: move and mine are incompatible, do something about UI interactions
end

function sqdistance(pos1, pos2)
	return (pos1[1] - pos2.x)^2 + (pos1[2] - pos2.y)^2
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