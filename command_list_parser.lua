require("high_level_commands")

command_list_parser = {}

global.command_list_parser = global.command_list_parser or {}

-- TODO: all sorts of vehicle things.

inherited_actions = {
	["auto-refuel"] = "put",
	["auto-move-to"] = "move",
	["auto-move-to-command"] = "move",
	["auto-take"] = "take",
	["auto-build-blueprint"] = "build",
}

max_ranges = {
	["build"] = 6,
	["throw-grenade"] = 15,
}

function command_list_parser.init()
	global.command_list_parser.current_command_set = {}
	global.command_list_parser.command_finished_times = {}
	global.command_list_parser.loaded_command_groups = {}
	global.command_list_parser.initialized_names = {}
	global.command_list_parser.finished_command_names = {}

	global.command_list_parser.current_mining = 0
	global.command_list_parser.stopped = true
	global.command_list_parser.current_ui = nil
	global.command_list_parser.entities_with_burner = {}

	global.command_list_parser.current_command_group_index = 0
	global.command_list_parser.current_command_group_tick = nil
end

script.on_event(defines.events.on_player_mined_entity, function(event)
	local player = game.players[event.player_index]
	for _, command in pairs(global.command_list_parser.current_command_set) do
		if command[1] == "mine" then
			if command_list_parser.command_sqdistance(command, {position=event.entity.position}) <= 0.3 then
				command.data.amount = command.data.amount - 1
				if command.data.amount <= 0 then
					command.finished = true
				end
			end
		end
	end
end)

script.on_event(defines.events.on_player_mined_item, function(event)
	local player = game.players[event.player_index]
	if not player.selected then return end
	for _, command in pairs(global.command_list_parser.current_command_set) do
		if command[1] == "mine" then
			if command_list_parser.command_sqdistance(command, {position=player.selected.position}) <= 0.3 then
				command.data.amount = command.data.amount - 1
				if command.data.amount <= 0 then
					command.finished = true
				end
			end
		end
	end
end)

function command_list_parser.add_entity_to_global (entity)
	if entity.burner then
		global.command_list_parser.entities_with_burner[#global.command_list_parser.entities_with_burner + 1] = entity
	end
end



-- Add command to current command set and initialize the command.
function command_list_parser.add_command_to_current_set(command, myplayer, command_group)
	-- Reset on_relative_tick time.
	if command.name then global.command_list_parser.command_finished_times[command.name] = nil end

	command.data = {}

	command.data.parent_command_group = command_group
	
	if not command.namespace then
		command.namespace = command_group.name .. "."
	end

	if command.name then
		-- Filter duplicate named commands. This is used e.g. for building blueprints with the same raw data but different areas.
		if global.command_list_parser.initialized_names[command.namespace .. command.name] then return end
		global.command_list_parser.initialized_names[#global.command_list_parser.initialized_names + 1] = command.name
	end

	-- Set default priority
	if not command.priority then
		command.priority = high_level_commands[command[1]].default_priority
	end

	-- Set action type
	command.action_type = high_level_commands[command[1]].default_action_type

	local not_add = high_level_commands[command[1]].initialize(command, myplayer)
	if not_add then return end

	-- Add command to set
	if not not_add then
		global.command_list_parser.current_command_set[#global.command_list_parser.current_command_set + 1] = command
	end
end



function command_list_parser.evaluate_command_list(command_list, commandqueue, myplayer, tick)
	if not command_list then
		return true
	end

	commandqueue[tick] = {}

	-- Check if we finished all commands in the current command set

	local finished = true

	for _, command in pairs(global.command_list_parser.current_command_set) do
		if command.finished and command.name then
			global.command_list_parser.finished_command_names[command.namespace .. command.name] = true
			--table.remove(global.command_list_parser.current_command_set, k)
		end

		if not command.finished then
			finished = false
		end
	end

	if command_list[global.command_list_parser.current_command_group_index + 1]
	and command_list[global.command_list_parser.current_command_group_index + 1].required then
		finished = true

		if type(command_list[global.command_list_parser.current_command_group_index + 1].required) == "string" then
			command_list[global.command_list_parser.current_command_group_index + 1].required
				= {command_list[global.command_list_parser.current_command_group_index + 1].required}
		end
		for _,name in pairs(command_list[global.command_list_parser.current_command_group_index + 1].required) do
			if not (global.command_list_parser.finished_command_names[command_list[global.command_list_parser.current_command_group_index].name .. "." .. name]
					or global.command_list_parser.finished_command_names[name]) then
				finished = false
			end
		end
	end

	-- Add the next command group to the current command set.

	if finished then
		global.command_list_parser.current_command_group_index = global.command_list_parser.current_command_group_index + 1

		if (not command_list[global.command_list_parser.current_command_group_index]) then
			return false
		end

		local command_group = command_list[global.command_list_parser.current_command_group_index]
		if command_group.force_save then
			global.system.save = command_group.name
		end

		if global.command_list_parser.loaded_command_groups[command_group.name] then error("Duplicate command group name!") end
		global.command_list_parser.loaded_command_groups[command_group.name] = true

		for i, command in ipairs(command_group.commands) do
			if not high_level_commands[command[1]] then
				error("The command with the name '" .. command[1] .. "' does not exist!")
			end
				
			command_list_parser.add_command_to_current_set(command, myplayer, command_group)
		end

		global.command_list_parser.current_command_group_tick = tick
	end

	-- 	Determine which commands we can execute this tick
	local executable_commands = {}

	local unchecked_commands = true

	while unchecked_commands do
		unchecked_commands = false

		for _, command in pairs(global.command_list_parser.current_command_set) do
			if not command.tested then
				if command_list_parser.command_executable(command, myplayer, tick) then
					executable_commands[#executable_commands + 1] = command
					local new_commands = high_level_commands[command[1]].spawn_commands(command, myplayer, tick)

					for _, com in pairs(new_commands or {}) do
						unchecked_commands = true
						command_list_parser.add_command_to_current_set(com, myplayer, command.data.parent_command_group)
					end
				end

				command.tested = true
			end
		end
	end

	for _, command in pairs(global.command_list_parser.current_command_set) do
		command.tested = false
	end
	
	local auto_move_commands = 0
	
	for _, cmd in pairs(executable_commands) do
		if (not cmd.finished) and (cmd[1] == "auto-move-to" or cmd[1] == "auto-move-to-command") then
			auto_move_commands = auto_move_commands + 1
		end
	end
	
	if auto_move_commands > 1 then
		errprint("You are using more than one auto-move command at once! Don't do this!")
	end

	-- Determine first out of range command
	local leaving_range_command = nil

	for _, command in pairs(executable_commands) do
		if command_list_parser.leaving_range(command, myplayer, tick) then
			leaving_range_command = command
			break
		end
	end

	local priority_command

	-- Process out of range command if it exists
	if leaving_range_command then
		priority_command = leaving_range_command
	else
		-- Otherwise execute first command with highest priority.
		if #executable_commands > 0 then
			local command = executable_commands[1]
			for _, com in pairs(executable_commands) do
				if command.priority > com.priority  then --and com.action_type ~= action_types.always_possible then
					command = com
				end
			end

			priority_command = command
		end
	end

	if priority_command then
		log_to_ui("Priority command: " .. priority_command[1], "command-not-executable")
		commandqueue[tick] = command_list_parser.create_commandqueue(executable_commands, priority_command, myplayer, tick)
	else
		commandqueue[tick] = {}
	end

	if commandqueue[tick - 1] then
		local craft_action
		local ui_action

		for _,queue in pairs({commandqueue[tick - 1], commandqueue[tick]}) do
			for _,c in pairs(queue) do
				if c[1] == "craft" then
					craft_action = c
				end

				if c.action_type == action_types.ui then
					ui_action = c
				end
			end
		end

		if craft_action and ui_action then
			errprint("You are executing a craft and a ui action in adjacent frames! This is impossible! The craft action is " .. serpent.block(craft_action) .. " and the ui action is " .. serpent.block(ui_action))
		end
	end
	
	local move_found = false
	local moves = ""
	
	for _,command in pairs(commandqueue[tick]) do
		if command[1] == "move" then
			moves = moves .. command[2] .. ", "
			if move_found then
				errprint("You are executing more than one move action in the same frame! Moves: " .. moves)
				break
			else
				move_found = true
			end
		end
	end

	return true
end



function command_list_parser.create_commandqueue(executable_commands, command, myplayer, tick)
	local command_collection = {command}

	command_list_parser.add_compatible_commands(executable_commands, command_collection, myplayer)

	local current_commands = "Commands in this tick: "
	local queue = {}

	for _,cmd in pairs(command_collection) do
		current_commands = current_commands .. cmd[1] .. ", "
		local low_level_command = high_level_commands[cmd[1]].execute(cmd, myplayer, tick)
		if low_level_command then
			queue[#queue + 1] = low_level_command
		end
	end

	log_to_ui(current_commands, "command-not-executable")

	-- save finishing time for on_relative_tick
	for _, cmd in pairs(queue) do
		if cmd.name then
			global.command_list_parser.command_finished_times[cmd.name] = tick
		end
	end

	return queue
end

function command_list_parser.command_executable(command, myplayer, tick)
	if command.finished then
		return false
	end
	
	local fail_reason = high_level_commands[command[1]].executable(command, myplayer, tick)

	if fail_reason ~= "" then
		log_to_ui(command[1] .. ": " .. fail_reason, "command-not-executable")
		return false
	end

	-- on_tick, on_relative_tick
	if command.on_tick and command.on_tick < tick then return false end
	if command.on_relative_tick then
		if type(command.on_relative_tick) == type(1) then
			if tick < global.command_list_parser.current_command_group_tick + command.on_relative_tick then
				log_to_ui(command[1] .. ": " .. "The tick has not been reached", "command-not-executable")
				return false
			end
		else
			if type(command.on_relative_tick) == type({}) then
				if not global.command_list_parser.command_finished_times[command.on_relative_tick[2]] or tick < global.command_list_parser.command_finished_times[command.on_relative_tick[2]] + command.on_relative_tick[1] then
					log_to_ui(command[1] .. ": " .. "The tick has not been reached", "command-not-executable")
					return false
				end
			else
				error("Unrecognized format for on_relative_tick!")
			end
		end
	end

	if command.on_leaving_range and not command_list_parser.leaving_range(command, myplayer, tick) then
		log_to_ui(command[1] .. ": Not leaving range.", "command-not-executable")
		return false
	end

	if command.items_available then
		local pos
		local entity

		if command[1] == "take" and not command.items_available.pos then -- we can use the default position here
			pos = command[2]
		else
			pos = command.items_available.pos
		end

		if pos then
			entity = get_entity_from_pos(pos, myplayer)

			if not entity then
				errprint("There is no entity at (" .. pos[1] .. "," .. pos[2] .. ")")
				return false
			end
		else
			entity = myplayer
		end

		if entity.get_item_count(command.items_available[1]) < command.items_available[2] then
			log_to_ui(command[1] .. ": " .. "Not enough items available!", "command-not-executable")
			return false
		end
		
		command.items_available = false
	end

	if command.items_total then
		local pos
		local entity

		local count = myplayer.get_item_count(command.items_total[1])

		if command[1] == "take" and not command.items_total.pos then
			pos = command[2]
		else
			pos = command.items_total.pos
		end

		if pos then
			entity = get_entity_from_pos(pos, myplayer, command.type or command.items_total.type)

			if not entity then
				errprint("There is no entity at (" .. pos[1] .. "," .. pos[2] .. ")")
				return false
			end

			count = count + entity.get_item_count(command.items_total[1])
		end

		if (not command.items_total.min) and count < command.items_total[2] then
			log_to_ui(command[1] .. ": " .. "Not enough items available! " .. count .. " / " .. command.items_total[2], "command-not-executable")
			return false
		elseif command.items_total.min and count > command.items_total[2] then
			log_to_ui(command[1] .. ": " .. "Too many items available!", "command-not-executable")
			return false
		end
	end

	if command.command_finished then
		local com_finished = false

		for _, com in pairs(global.command_list_parser.current_command_set) do
			if com.finished and com.name and has_value({command.command_finished, command.namespace .. command.command_finished}, com.namespace .. com.name) then
				com_finished = true
			end
		end

		if not com_finished then
			log_to_ui(command[1] .. ": " .. "The prerequisite command has not finished", "command-not-executable")
			return false
		end
	end

	return true
end

function command_list_parser.leaving_range(command, myplayer, tick)
	if command.data.range_check_tick == game.tick then return command.data.leaving_range end

	command.data.range_check_tick = game.tick
	local distsq = command_list_parser.command_sqdistance(command, myplayer)
	if not command.data.last_range_sq then
		command.data.last_range_sq = distsq
	else
		local max_range = command.leaving_range or max_ranges[command[1]] or 6
		if command.data.last_range_sq < distsq and distsq < max_range*max_range and 0.8*max_range*max_range < command.data.last_range_sq then
			command.data.last_range_sq = distsq
			command.data.leaving_range = true
			return true
		end
		command.data.last_range_sq = distsq
	end
	command.data.leaving_range = false
	return false
end

function command_list_parser.command_sqdistance(command, player)
	local position = nil
	if in_list(command[1], {"rotate", "recipe", "take", "put", "mine", "throw-grenade"}) then position = command[2]
	elseif command[1] == "auto-move-to" or command[1] == "build" then position = command[3]
	end

	--game.print(serpent.block(position))
	--if position == nil then game.print(command[1]) end
	if position then
		return sqdistance(position, player.position)
	else
		return nil
	end
end

-- Given the set commands, add commands from the set executable_commands
function command_list_parser.add_compatible_commands(executable_commands, commands, myplayer)
	-- TODO: Allow more than one command in the commands list here!
	if #commands ~= 1 then
		error("Function add_compatible_commands: commands parameter has not exactly one element.")
	end
	local command = commands[1]

	if command.action_type == action_types.selection then -- if you want things to happen in the same frame, use the exact same coordinates!
		local coordinates = command[2] -- all selection actions have there coordinates at [2]

		local priority_take_or_put = nil

		if not has_value({"put", "take"}, basic_action(command)) then
			-- find the highest priority take or put-stack action at this position

			for _, comm in pairs(executable_commands) do
				if has_value({"put", "take"}, basic_action(comm)) and comm.action_type == action_types.selection and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] then
					if not priority_take_or_put and priority_take_or_put.priority > comm.priority then
						priority_take_or_put = comm
					end
				end
			end
		else
			priority_take_or_put = command
		end

		local forbidden_action

		if priority_take_or_put and basic_action(priority_take_or_put) == "put" then
			forbidden_action = "take"
		else
			forbidden_action = "put"
		end

		for _, comm in pairs(executable_commands) do
			if comm.action_type == action_types.selection and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] and comm ~= command then
				if basic_action(comm) ~= forbidden_action then
					commands[#commands + 1] = comm
				end
			end
		end
	end

	if command.action_type == action_types.ui then
		if global.command_list_parser.current_ui == nil then -- we have to open the ui first
			global.command_list_parser.current_ui = command.data.ui

			table.remove(commands, 1)
		else
			-- do the command, close the ui
			global.command_list_parser.current_ui = nil
		end
	end

	-- TODO: move and mine are incompatible

	for _, comm in pairs(executable_commands) do
		if comm.action_type == action_types.always_possible and comm ~= command then
			commands[#commands + 1] = comm
		end
	end
end

function basic_action(command)
	return inherited_actions[command[1]] or command[1]
end
