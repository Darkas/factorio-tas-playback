require("high_level_commands")
module("command_list_parser", package.seeall) -- TODO: This is apparently old-lua style but for now it works better than the new style.

always_possible = {"speed"}
blocks_others = {"auto-refuel", "mine"}
blocks_movement = {"move", "mine"}

blocks_selection = {"auto-refuel", "build", "put", "take"}

always_possible_actions = {"pickup", "speed", "stop-auto-move-to", "stop-auto-refuel", "stop-auto-take"}
selection_actions = {"mine", "put", "rotate", "take-stack"}
ui_actions = {"craft", "recipe", "take", "tech"}

-- TODO: "throw" and "vehicle"
-- TODO: Check if we need the type parameter in auto-refuel, add amount parameter?

inherited_actions = {
	["auto-refuel"] = "put-stack",
	["auto-move-to"] = "move",
	["auto-move-to-command"] = "move",
	["auto-take"] = "take",
	["build-blueprint"] = "build",
}

default_priorities = {
	["build"] = 5,
	["craft"] = 5,
	["take"] = 5,
	["put"] = 5,
	["auto-refuel"] = 5,
	["mine"] = 6,
	["auto-move-to"] = 7,
	["auto-move-to-command"] = 7,
	["entity-interaction"] = 100,
	["pickup"] = 100,
	["speed"] = 100,
	["stop-command"] = 100,
}
max_ranges = {
	["build"] = 6,
}

function init()
	global.current_command_set = {}
	global.tech_queue = {}
	global.command_finished_times = {}
	global.loaded_command_groups = {}
	global.finished_command_names = {}
	
	global.current_mining = 0
	global.stopped = true
	
	global.current_command_group_tick = nil
end

script.on_event(defines.events.on_research_finished, function (event)
	local force = event.research.force
	commandqueue[game.tick][#commandqueue[game.tick] + 1] =	{"tech", global.tech_queue[1]}
	table.delete(global.tech_queue, 1)
end)

script.on_event(defines.events.on_player_mined_item, function(event)
	global.current_mining = global.current_mining + (event.item_stack.count or 1)
end)

function evaluate_command_list(command_list, commandqueue, myplayer, tick)
	if not command_list then
		return true
	end
		
	commandqueue[tick] = {}

	-- Check if we finished all commands in the current command set

	local finished = true
	
	for k, command in pairs(global.current_command_set) do
		-- Handle stop command
		if command[1] == "stop" and command_executable(command, myplayer, tick) then
			for i, com in pairs(global.current_command_set) do
				if com.name == command.name then
					com.finished = true
					command.finished = true
					--table.remove(current_command_set, i)
					--table.remove(current_command_set, k)
					break
				end
			end
		end
		if command.finished and command.name then
			global.finished_command_names[command.name] = true
		end
		
		if not command.finished then
			finished = false
		end
	end
	
	if command_list[1] and command_list[1].required then
		finished = true
		
		for _,name in pairs(command_list[1].required) do
			if not global.finished_command_names[name] then
				finished = false
			end
		end
	end
	
	-- Add the next command group to the current command set.
	
	if finished then
		if (not command_list[1]) then
			return false
		end

		local command_group = command_list[1]

		if global.loaded_command_groups[command_group.name] then error("Duplicate command group name!") end
		global.loaded_command_groups[command_group.name] = true

		--if command_group.save_before then 
		--	game.server_save(tas_name .. "__" .. command_group.name)
		--end
		
		local iterations = command_group.iterations or 5
		local initialized_names = {}
		
		for i=0,iterations do
			for i, command in ipairs(command_group.commands) do
				if (not high_level_commands[command[1]].init_dependencies(command)) or has_value(initialized_names, namespace_prefix(high_level_commands[command[1]].init_dependencies(command), command_group.name)) then
					add_command_to_current_set(command, myplayer, tick, commandqueue, command_group)
					
					if command.name then
						initialized_names[#initialized_names + 1] = command.name
					end
					table.remove(command_group.commands, i)
				end
			end
		end
		
		-- Add namespace prefixes to the next group
		
		if command_list[2] and command_list[2].required then
			for i, name in pairs(command_list[2].required) do
				command_list[2].required[i] = namespace_prefix(name, command_list[1].name)
			end
		end
		
		table.remove(command_list, 1)
		global.current_command_group_tick = tick
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
		commandqueue[tick] = create_commandqueue(executable_commands, leaving_range_command, myplayer, tick)
	end
	

	-- Otherwise execute first command with highest priority.
	if #executable_commands > 0 then
		local command = executable_commands[1]
		for _, com in pairs(executable_commands) do
			if command.priority > com.priority then
				command = com
			end
		end
		
		commandqueue[tick] = create_commandqueue(executable_commands, command, myplayer, tick)
	end
	
	return true
end



-- Add command to current command set and initialize the command. 
function add_command_to_current_set(command, myplayer, tick, commandqueue, command_group)
	local do_add = true -- At the end of this function we add the command to the set if this is still true

	-- Reset on_relative_tick time.
	if command.name then global.command_finished_times[command.name] = nil end

	command.data = {}
	
	command.data.parent_command_group = command_group
	
	if command.name then
		command.name = namespace_prefix(command.name, command_group.name)
	end
	
	if command.command_finished then
		command.command_finished = namespace_prefix(command.command_finished, command_group.name)
	end
	
	-- Set default priority
	if not command.priority then
		command.priority = default_priorities[command[1]]
	end
	
	not_add = high_level_commands[command[1]].initialize(command, myplayer)

	-- Add command to set
	if not not_add then
		global.current_command_set[#global.current_command_set + 1] = command
	end
end


function create_commandqueue(executable_commands, command, myplayer, tick)
	local command_collection = {command}
	
	add_compatible_commands(executable_commands, command_collection, myplayer)
	
	local queue = {}
	
	for _,com in pairs(command_collection) do
		queue[#queue + 1] = high_level_commands[com[1]].to_low_level(com, myplayer, tick)
	end

	-- save finishing time for on_relative_tick
	for _, command in pairs(queue) do
		if command.name then
			global.command_finished_times[command.name] = tick
		end
	end
	
	return queue
end

function command_executable(command, myplayer, tick)
	if command.finished or not high_level_commands[command[1]].executable(command, myplayer, tick) then
		return false
	end

	-- on_tick, on_relative_tick
	if command.on_tick and command.on_tick < tick then return false end
	if command.on_relative_tick then
		if type(command.on_relative_tick) == type(1) and tick < global.current_command_group_tick + command.on_relative_tick then return false
		elseif type(command.on_relative_tick) == type({}) and not global.command_finished_times[command.on_relative_tick[2]] or tick < global.command_finished_times[command.on_relative_tick[2]] + command.on_relative_tick[1] then return false
		else error("Unrecognized format for on_relative_tick!")
		end
	end
	
	if command.on_entering_range then
		if distance_from_rect(myplayer.position, command.rect) > command.distance then
			return false
		end
	end
	
	if command.on_leaving_range and not leaving_range(command, myplayer, tick) then
		return false
	end
	
	if command.items_available then
		local pos = nil
		
		if command[1] == "take" and not command.items_available.pos then -- we can use the default position here
			pos = command[2]
		else
			pos = command.items_available.pos
		end
		
		if pos then
			entity = get_entity_from_pos(pos, myplayer)
		else
			entity = myplayer
		end
		
		if entity.get_item_count(command.items_available[1]) < command.items_available[2] then
			return false
		end
	end
	
	if command.command_finished then
		local com_finished = false
		
		for _, com in pairs(global.current_command_set) do
			if com.finished and com.name and com.name == command.command_finished then
				com_finished = true
			end
		end
		
		if not com_finished then
			return false
		end
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

-- Given the set commands, add commands from the set executable_commands
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
			if has_value(selection_actions, basic_action(comm)) and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] then
				if basic_action(comm) ~= forbidden_action then
					commands[#commands + 1] = comm
				end
			end
		end
	end
	
	-- TODO: move and mine are incompatible, do something about UI interactions
	
	for _, comm in pairs(executable_commands) do
		if has_value(always_possible_actions, basic_action(comm)) then
			commands[#commands + 1] = comm
		end
	end
end

function basic_action(command)
	return inherited_actions[command[1]] or command[1]
end


