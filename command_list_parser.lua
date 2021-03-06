-- luacheck: globals LogUI Utils Event high_level_commands
command_list_parser = {} --luacheck: allow defined top

global.command_list_parser = global.command_list_parser or {}

-- TODO: all sorts of vehicle things.

local inherited_actions = {
	["auto-refuel"] = "put",
	["move-to"] = "move",
	["move-to-command"] = "move",
	["auto-take"] = "take",
	["auto-build-blueprint"] = "build",
}

local max_ranges = {
	["build"] = 6,
	["throw-grenade"] = 15,
}

local generic_cmd_signature = {
	-- Fields a command can have. The ones you'd set in a run file are:
	-- [1], name, priority and any of the conditions
	[1] = "string",  -- command type, e.g. "build", "mine", ...

	finished = "boolean", 
	disabled = "boolean",
	tested = "boolean",

	name = {"string", "nil"},  -- Used to refer to this command from other commands
	namespace = "string",
	data = "table",
	action_type = "string",
	spawned_by = "table",
	parent_namespace = {"string", "nil"},
	toggle = {"string", "nil"},
	priority = {"number", "nil"},  -- Used to control order of execution. Lower priority gets executed first because we're weird

	rect = {"nil", "table"},
	distance = {"nil", "number"},
}

local condition_signatures = {
	-- Conditions
	command_finished = {"string", "nil"}, 
	on_leaving_range = "boolean",
	on_entering_range = "boolean",
	on_entering_area = {"table", "nil"},
	on_tick = {"table", "nil"},
	on_relative_tick = {"table", "nil"},
	items_available = {"table", "nil"},
	items_total = {"table", "nil"},
}

local required_files = {}

command_list_parser.generic_cmd_signature = Utils.merge_tables(generic_cmd_signature, condition_signatures)
command_list_parser.no_cond_cmd_signature = Utils.copy(generic_cmd_signature)

require("high_level_commands")



function command_list_parser.init()
	global.command_list_parser.current_command_set = {}
	global.command_list_parser.command_finished_times = {}
	global.command_list_parser.loaded_command_groups = {}
	global.command_list_parser.initialized_names = {}
	global.command_list_parser.finished_named_commands = {}

	global.command_list_parser.typecheck_errors = {}

	global.command_list_parser.current_mining = 0
	global.command_list_parser.stopped = true
	global.command_list_parser.current_ui = nil
	global.command_list_parser.entities_with_burner = {}
	global.command_list_parser.entities_by_type = {}

	global.command_list_parser.current_command_group_index = 0
	global.command_list_parser.current_command_group_tick = nil
	
	global.command_list_parser.current_move_state = {"move", "STOP"}
	global.command_list_parser.current_mine_state = {"mine", nil}
	global.command_list_parser.current_pick_state = {"pickup", false}
	
	global.command_list_parser.generated_queue = ""
end

local function pre_parse_command(command, dir)
	if high_level_commands[command[1]].get_children then
		for _,cmd in pairs(high_level_commands[command[1]].get_children(command)) do
			pre_parse_command(cmd, dir)
		end
	end
	
	if high_level_commands[command[1]].require then
		for _,name in pairs(high_level_commands[command[1]].require(command)) do
			pcall(function() required_files[name] = require(dir .. name) end)
		end
	end
end

function command_list_parser.pre_parse(command_list, dir)
	required_files = {}
	
	local loading_point = global.command_list_parser.current_command_group_index or 1
	
	for i,group in pairs(command_list) do
		if i >= loading_point then
			for _,cmd in pairs(group.commands) do
				pre_parse_command(cmd, dir)
			end
		end
	end
end

function command_list_parser.get_file(name)
	return required_files[name]
end

Event.register(defines.events.on_player_mined_entity, function(event)
	-- local player = game.players[event.player_index]
	for _, command in pairs(global.command_list_parser.current_command_set) do
		if command[1] == "mine" then
			if command_list_parser.command_sqdistance(command, {position=event.entity.position}) <= 0.3 then
				command.data.amount = command.data.amount - 1
				if command.data.amount <= 0 then
					command_list_parser.set_finished(command)
				end
			end
		end
	end
end)

Event.register(defines.events.on_player_mined_item, function(event)
	local player = game.players[event.player_index]
	if not player.selected then return end
	for _, command in pairs(global.command_list_parser.current_command_set) do
		if command[1] == "mine" then
			if command_list_parser.command_sqdistance(command, {position=player.selected.position}) <= 0.3 then
				command.data.amount = command.data.amount - 1
				if command.data.amount <= 0 then
					command_list_parser.set_finished(command)
				end
			end
		end
	end
end)

function command_list_parser.set_finished(command)
	command.finished = true
	if command.name then
		global.command_list_parser.finished_named_commands[command.namespace .. command.name] = command
	end
end

function command_list_parser.check_type(command)
	local type_signature = high_level_commands[command[1]].type_signature
	if not type_signature then
		if not global.command_list_parser.typecheck_errors[command[1]] then
			game.print("Type check not yet implemented for command " .. command[1])
			global.command_list_parser.typecheck_errors[command[1]] = true
		end
		return
	end
	local function check_argument(value, types)
		if type(types) ~= "table" then
			types = {types}
		end

		for _, t in pairs(types) do
			if t == "position" and Utils.is_position(value) then
				return true
			elseif t == "entity-position" and Utils.is_entity_position(value) then
				return true
			elseif t == "rect" and Utils.is_rect(value) then
				return true
			elseif t == "boolean" then
				return value == true or value == false or value == nil
			elseif type(value) == t then
				return true
			end
		end
		return false
	end

	for k, v in pairs(command) do
		if command[1] == "simple-sequence" and type(k) == "number" and k > 4 then
			if not check_argument(command[k], type_signature[4]) then
				error("Command has wrong type. \nGroup: " .. command.data.parent_command_group.name .. "\nCommand: " .. command[1] .. "\nArgument: " .. k .. "\nValue: " .. Utils.printable(command[k]))
			end	
		elseif not type_signature[k] then
			error(command[1] .. " typecheck failed: unexpected argument " .. Utils.printable(k) .. " = " .. serpent.block(v))
		end
	end

	for k, t in pairs(type_signature) do
		if not check_argument(command[k], t) then
			error("Command has wrong type. \nGroup: " .. command.data.parent_command_group.name .. "\nCommand: " .. command[1] .. "\nArgument: " .. k .. "\nValue: " .. Utils.printable(command[k]))
		end
	end
end

function command_list_parser.add_entity_to_global (entity)
	if entity.burner then
		global.command_list_parser.entities_with_burner[#global.command_list_parser.entities_with_burner + 1] = entity
	end

	if not global.command_list_parser.entities_by_type[entity.type] then
		global.command_list_parser.entities_by_type[entity.type] = {}
	end

	global.command_list_parser.entities_by_type[entity.type][#global.command_list_parser.entities_by_type[entity.type] + 1] = entity
end



-- Add command to current command set and initialize the command.
function command_list_parser.add_command_to_current_set(command, myplayer, command_group)
	if not high_level_commands[command[1]] then
		error("The command with the name '" .. command[1] .. "' does not exist!")
	end

	-- Reset on_relative_tick time.
	if command.name then global.command_list_parser.command_finished_times[command.name] = nil end

	command.data = {
		parent_command_group = command_group
	}

	if not command.namespace then
		command.namespace = command_group.name .. "."
	end

	-- Set default priority
	if not command.priority then
		command.priority = high_level_commands[command[1]].default_priority
	end

	-- Set action type
	command.action_type = high_level_commands[command[1]].default_action_type

	-- Type check.
	command_list_parser.check_type(command)
	
	if command.name then
		-- Filter duplicate named commands. This is used e.g. for building blueprints with the same raw data but different areas.
		if global.command_list_parser.initialized_names[command.namespace .. command.name] then return end
		global.command_list_parser.initialized_names[#global.command_list_parser.initialized_names + 1] = command.name
	end

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
	local check_for_next = false

	local index = 1
	local cmd = global.command_list_parser.current_command_set[index]
	while cmd do
		if cmd.finished then
			table.remove(global.command_list_parser.current_command_set, index)
		else
			index = index + 1
		end

		if cmd.finished then
			check_for_next = true
		else
			finished = false
		end
		cmd = global.command_list_parser.current_command_set[index]
	end

	local next_command_group = command_list[global.command_list_parser.current_command_group_index + 1]
	if next_command_group and next_command_group.required then
		finished = true

		if type(next_command_group.required) == "string" then
			next_command_group.required	= {next_command_group.required}
		end
		for _,name in pairs(next_command_group.required) do
			if not (global.command_list_parser.finished_named_commands[command_list[global.command_list_parser.current_command_group_index].name .. "." .. name]
			or global.command_list_parser.finished_named_commands[name]) then
				finished = false
			end
		end
	end
	
	if not next_command_group and not global.run_finished then
		global.run_finished = true
		local command_count = {}
		
		for _, commands in pairs(commandqueue) do
			for _,com in pairs(commands) do
				if type(com) == type({}) and com[1] then
					if not command_count[com[1]] then
						command_count[com[1]] = 1
					else
						command_count[com[1]] = command_count[com[1]] + 1
					end
				end
			end
		end
		
		local total = 0
		
		for type, number in pairs(command_count) do
			if not Utils.has_value({"move", "mine", "pickup"}, type) then
				total = total + number
			end
			LogUI.log_to_ui("Number of " .. type .. " commands: " .. number, "run-output")
		end
		
		LogUI.log_to_ui("Total number of commands without move, mine and pickup: " .. total, "run-output")
	end

	-- Add the next command group to the current command set.

	if finished then
		global.command_list_parser.current_command_group_index = global.command_list_parser.current_command_group_index + 1

		if (not command_list[global.command_list_parser.current_command_group_index]) then
			return false
		end

		local command_group = command_list[global.command_list_parser.current_command_group_index]
		if command_group.force_save == true then
			global.system.save = command_group.name
		elseif command_group.force_save then
			global.system.save = command_group.force_save
		end

		if global.command_list_parser.loaded_command_groups[command_group.name] then error("Duplicate command group name!") end
		global.command_list_parser.loaded_command_groups[command_group.name] = true

		for i, command in ipairs(command_group.commands) do
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
						com.spawned_by = command
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

	for _, command in pairs(executable_commands) do
		if (not command.finished) and (command[1] == "move-to" or command[1] == "move-to-command") then
			auto_move_commands = auto_move_commands + 1
		end
	end

	if auto_move_commands > 1 then
		LogUI.errprint("You are using more than one move command at once! Don't do this!")
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
		LogUI.log_to_ui("Priority command: " .. priority_command[1], "command-not-executable")
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
			LogUI.errprint("You are executing a craft and a ui action in adjacent frames! This is impossible! The craft action is " .. serpent.block(craft_action) .. " and the ui action is " .. serpent.block(ui_action))
		end
	end

	local move_found = false
	local mine_found = false
	local pick_found = false
	local moves = ""
	
	local i = 1
	local command = commandqueue[tick][1]
	local remove = false

	while command do
		if command[1] == "move" then
			moves = moves .. command[2] .. ", "
			if move_found then
				LogUI.errprint("You are executing more than one move action in the same frame! Moves: " .. moves)
				break
			else
				move_found = true
				
				if global.command_list_parser.current_move_state[2] == command[2] then
					remove = true
				else
					global.command_list_parser.current_move_state[2] = command[2]
				end
			end
		end
		if command[1] == "mine" then
			mine_found = true
			
			if serpent.block(global.command_list_parser.current_mine_state[2]) == serpent.block(command[2]) then
				remove = true
			else
				global.command_list_parser.current_mine_state[2] = command[2]
			end
		end
		if command[1] == "pickup" then
			pick_found = true
			
			if global.command_list_parser.current_pick_state[2] == command[2] then
				remove = true
			else
				global.command_list_parser.current_pick_state[2] = command[2]
			end
		end
		
		if remove then
			table.remove(commandqueue[tick], i)
		else
			i = i + 1
		end
		
		command = commandqueue[tick][i]
		remove = false
	end
	
	if not move_found and global.command_list_parser.current_move_state[2] ~= "STOP" then
		table.insert(commandqueue[tick], {"move", "STOP"})
		global.command_list_parser.current_move_state[2] = "STOP"
	end
	
	if not mine_found and global.command_list_parser.current_mine_state[2] ~= nil then
		table.insert(commandqueue[tick], {"mine", nil})
		global.command_list_parser.current_mine_state[2] = nil
	end
	
	if not pick_found and global.command_list_parser.current_pick_state[2] ~= false then
		table.insert(commandqueue[tick], {"pickup", false})
		global.command_list_parser.current_pick_state[2] = false
	end
	
	local command_string = ""
	
	for _,cmd in pairs(commandqueue[tick]) do
		command_string = command_string .. serpent.line(HLC_Utils.strip_command(cmd, true)) .. ","
	end
	
	if command_string ~= "" then
		global.command_list_parser.generated_queue = global.command_list_parser.generated_queue .. "[" .. tick .. "]={" .. string.sub(command_string, 1, -2) .. "},\n"
	end

	return true
end



function command_list_parser.create_commandqueue(executable_commands, command, myplayer, tick)
	local command_collection = {command}

	command_list_parser.add_compatible_commands(executable_commands, command_collection, myplayer)

	local current_commands = "Commands in this tick: "
	local queue = {}

	for _, cmd in pairs(command_collection) do
		current_commands = current_commands .. cmd[1] .. ", "
		local low_level_commands = table.pack(high_level_commands[cmd[1]].execute(cmd, myplayer, tick))
		for _, low_level_command in ipairs(low_level_commands) do
			if low_level_command then
				queue[#queue + 1] = low_level_command
			end
		end
		
		-- save finishing time for on_relative_tick
		if cmd.name and cmd.finished then
			global.command_list_parser.command_finished_times[cmd.namespace .. cmd.name] = tick
		end
	end

	LogUI.log_to_ui(current_commands, "command-not-executable")

	return queue
end

function command_list_parser.command_executable(command, myplayer, tick)
	if command.finished or command.disabled then
		return false
	end

	if command.toggle and not global.high_level_commands.variables[command.toggle] then
		return false
	end

	local fail_reason = high_level_commands[command[1]].executable(command, myplayer, tick)

	if fail_reason ~= "" then
		if fail_reason == nil then game.print(serpent.block(command)) end
		LogUI.log_to_ui(command[1] .. ": " .. fail_reason, "command-not-executable")
		return false
	end

	-- on_tick, on_relative_tick
	if command.on_tick and command.on_tick < tick then return false end
	if command.on_relative_tick then
		local remaining_ticks
		if type(command.on_relative_tick) == type(1) then
			remaining_ticks = global.command_list_parser.current_command_group_tick + command.on_relative_tick - tick
		elseif type(command.on_relative_tick) == type({}) then
			local finished_tick = global.command_list_parser.command_finished_times[command.on_relative_tick[2]] or global.command_list_parser.command_finished_times[command.namespace .. command.on_relative_tick[2]]
			
			if not finished_tick then
				LogUI.log_to_ui(command[1] .. ": The previous command has not been finished.", "command-not-executable")
				return false
			end
			
			remaining_ticks = finished_tick + command.on_relative_tick[1] - tick
		else
			error("Unrecognized format for on_relative_tick!")
		end
		
		if remaining_ticks > 0 then
			LogUI.log_to_ui(command[1] .. ": The tick has not been reached. Remaining " .. remaining_ticks, "command-not-executable")
			return false
		end
	end

	if command.on_leaving_range and not command_list_parser.leaving_range(command, myplayer, tick) then
		LogUI.log_to_ui(command[1] .. ": Not leaving range.", "command-not-executable")
		return false
	end
	
	if command.on_entering_area then
		if Utils.inside_rect(myplayer.position, command.on_entering_area) then
			command.on_entering_area = nil
		else
			LogUI.log_to_ui(command[1] .. ": Not in the given area.", "command-not-executable")
			return false
		end
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
			entity = Utils.get_entity_from_pos(pos, myplayer)

			if not entity then
				LogUI.errprint("There is no entity at (" .. pos[1] .. "," .. pos[2] .. ")")
				return false
			end
		else
			entity = myplayer
		end

		if entity.get_item_count(command.items_available[1]) < command.items_available[2] then
			LogUI.log_to_ui(command[1] .. ": " .. "Not enough items available!", "command-not-executable")
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
			entity = Utils.get_entity_from_pos(pos, myplayer, command.type or command.items_total.type)

			if not entity then
				LogUI.errprint("There is no entity at (" .. pos[1] .. "," .. pos[2] .. ")")
				return false
			end

			count = count + entity.get_item_count(command.items_total[1])
		end

		if (not command.items_total.min) and count < command.items_total[2] then
			LogUI.log_to_ui(command[1] .. ": " .. "Not enough items available! " .. count .. " / " .. command.items_total[2], "command-not-executable")
			return false
		elseif command.items_total.min and count > command.items_total[2] then
			LogUI.log_to_ui(command[1] .. ": " .. "Too many items available!", "command-not-executable")
			return false
		end
	end

	if command.command_finished then
		if not (global.command_list_parser.finished_named_commands[command.command_finished]
		or global.command_list_parser.finished_named_commands[command.namespace .. command.command_finished]) then
			LogUI.log_to_ui(command[1] .. ": " .. "The prerequisite (" .. command.command_finished  .. ") command has not finished", "command-not-executable")
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
	if Utils.in_list(command[1], {"rotate", "recipe", "take", "put", "mine", "throw-grenade"}) then position = command[2]
	elseif command[1] == "move-to" or command[1] == "build" then position = command[3]
	end

	--game.print(serpent.block(position))
	--if position == nil then game.print(command[1]) end
	if position then
		return Utils.sqdistance(position, player.position)
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
		local coordinates = command[2] -- all selection actions have their coordinates at [2]

		local priority_take_or_put = nil

		if not Utils.has_value({"put", "take"}, basic_action(command)) then
			-- find the highest priority take or put-stack action at this position

			for _, comm in pairs(executable_commands) do
				if Utils.has_value({"put", "take"}, basic_action(comm)) and comm.action_type == action_types.selection and comm[2][1] == coordinates[1] and comm[2][2] == coordinates[2] then
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
