--[[
{"build", "mining-drill", "N", {0,0}, on_entering=true, on_leaving, on_player_in_range=range, items_total="iron", needs_fuel=pos, priority=..., name=...}
{"build-blueprint", "blueprint", "N", {0,0}, ...}
{"move", "NE", ...}
{"move-to", {0,0}, ...}
"rotate"
"mine"
"craft"
"put"
"take"
"tech"
"recipe"
"throw"
"vehicle"
"auto-refuel"
"auto-take"
"stop-auto-refuel"
"stop-auto-take"
"stop-move"

command_list = {
	{
		name = "start-1"
		required = {"name1", ...},
		{"build", "mining-drill", "N", {0,0}, on_entering=true, on_leaving, on_player_in_range=range, items_total="iron", needs_fuel=pos, priority=..., name=...}
	},
	{
		name = "start-2"
		required = {"name1", ...},
		{"build", "mining-drill", "N", {0,0}, on_entering=true, on_leaving, on_player_in_range=range, items_total="iron", needs_fuel=pos, priority=..., name=...}
	}
}
--]]

current_command_set = {}

function evaluate_command_list(command_list, commandqueue, myplayer, tick)
	local finished = true
	local finished_commands = {}
	
	for _,command in pairs(current_command_set) do
		if command.data.finished and command.name then
			finished_commands[#finished_commands + 1] = command.name
		end
		
		if not command.data.finished then
			finished = false
		end
	end
	
	-- set finished to true if finished_commands and command_list[2].required have the same elements
	
	if finished then
		if not command_list[1] then
			return false
		end
		
		current_command_set = command_list[1].commands
		table.remove(command_list, 1)
		
		for _,command in pairs(current_command_set) do
			command.data = {}
		end
	end
	
	local executable_commands = {}
	
	for _,command in pairs(current_command_set) do
		if command_executable(command, myplayer) then
			executable_commands[#executable_commands + 1] = to_low_level(command, myplayer)
		end
	end
	
	-- Check in which orders the commands should be executed
	
	commandqueue[tick] = executable_commands
	
	return true
end

function to_low_level(command, myplayer)
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
	
	if command[1] == "build" then
		command.data.finished = true
		return {command[1], command[2], command[3], command[4]}
	end
end

function command_executable(command, myplayer)
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
	
	
	
	return true
end

function sqdistance(pos1, pos2)
	return (pos1[1] - pos2.x)^2 + (pos1[2] - pos2.y)^2
end