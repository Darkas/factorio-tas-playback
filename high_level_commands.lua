


function auto_move_to_low_level (command, myplayer, tick)
	local target_pos = nil
	
	if command[1] == "auto-move-to" then
		target_pos = command[2]
	else
		target_pos = command.data.target_pos
	end
			
	if not command.data.moveData then
		command.data.moveData = {}
	
		if target_pos[2] < myplayer.position.y then
			command.data.moveData.N = true
		end
	
		if target_pos[2] > myplayer.position.y then
			command.data.moveData.S = true
		end
	
		if target_pos[1] > myplayer.position.x then
			command.data.moveData.E = true
		end
	
		if target_pos[1] < myplayer.position.x then
			command.data.moveData.W = true
		end
	end
	
	local move_dir = ""
	
	-- TODO: Test if this works when we walk on transport belts
	-- Could replace this by
	-- if command[2][2] < myplayer.position.y - epsilon then
	-- 	move_dir = move_dir .. "N"
	-- end
	if target_pos[2] < myplayer.position.y and not command.data.moveData.S then
		move_dir = move_dir .. "N"
	end
	
	if target_pos[2] > myplayer.position.y and not command.data.moveData.N then
		move_dir = move_dir .. "S"
	end
	
	if target_pos[1] > myplayer.position.x and not command.data.moveData.W then
		move_dir = move_dir .. "E"
	end
	
	if target_pos[1] < myplayer.position.x and not command.data.moveData.E then
		move_dir = move_dir .. "W"
	end
	
	if move_dir == "" then
		move_dir = "STOP"
		command.data.finished = true
	end
	
	return {"move", move_dir}
end

function move_collision_box(collision_box, coords)
	local x,y = get_coordinates(coords)
	return {{collision_box.left_top.x + x, collision_box.left_top.y + y}, {collision_box.right_bottom.x + x, collision_box.right_bottom.y + y}}
end

function return_true()
	return true
end

function empty()	
end

function return_self_finished(command, myplayer, tick)
	command.finished = true
	return command
end

function in_range(command, myplayer)
	return distance_from_rect(myplayer.position, command.rect) <= command.distance
end

high_level_commands = {
	
	["auto-move-to"] = {
		["to_low_level"] = auto_move_to_low_level,
		["executable"] = return_true,
		["initialize"] = empty,
		["init_dependencies"] = empty
	},
	
	["auto-move-to-command"] = {
		["to_low_level"] = auto_move_to_low_level,
		["executable"] = function(command, myplayer, tick)
			if high_level_commands[command.data.target_command[1]].executable(command.data.target_command, myplayer, tick) then
				command.finished = true
				return false
			end
			
			return true
		end,
		["initialize"] = function (command, myplayer)
			for _, com in pairs(global.current_command_set) do
				if com.name == namespace_prefix(command[2], command.data.parent_command_group.name) then
					command.data.target_pos = {}
					distance_from_rect(myplayer.position, com.rect, command.data.target_pos)
					command.data.target_command = com

					debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
				end
			end
		end,
		["init_dependencies"] = function (command)
			return command[2]
		end
	},
	
	["auto-refuel"] = {
		["to_low_level"] = function(command, myplayer, tick)
			if not command.data.started then
				command.data.started = tick
			end
		
			return {"put", command[3], "coal", 1, defines.inventory.fuel}
		end,
		["executable"] = function(command, myplayer, tick)
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
			
			return true
		end,
		["initialize"] = empty,
		["init_dependencies"] = empty
	},
	
	["build"] = {
		["to_low_level"] = return_self_finished,
		["executable"] = in_range,
		["initialize"] = function (command, myplayer)
			command.distance = myplayer.build_distance
			command.rect = move_collision_box(game.entity_prototypes[command[2]].collision_box, command[3])
		end,
		["init_dependencies"] = empty
	},
	
	["craft"] = {
		["to_low_level"] = return_self_finished,
		["executable"] = return_true,
		["initialize"] = empty,
		["init_dependencies"] = empty
	},
	
	["mine"] = {
		["to_low_level"] = function (command, myplayer, tick)
			if not command.data.started then
				command.data.started = tick
			end
			
			return command
		end,
		["executable"] = function(command, myplayer, tick)
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return false
			end
		
			if command.data.started and command.amount then
				local time = 0
				if command.data.ore_type == "stone" then
					time = 95
				else
					time = 125
				end
			
				if tick - command.data.started > time * command.amount then
					command.finished = true
					command.data.send_nil = true
					return false
				end
			end
			
			return true
		end,
		["initialize"] = function (command, myplayer)
			local resources = myplayer.surface.find_entities_filtered({area = {{-0.1 + command[2][1], -0.1 + command[2][2]}, {0.1 + command[2][1], 0.1 + command[2][2]}}})
		
			if (not resources) or #resources ~= 1 then
				game.print("There is not precisely 1 resource patch at this place!")
				return false
			end
		
			command.data.ore_type = resources[1].name
		
			command.distance = myplayer.resource_reach_distance
			command.rect = move_collision_box(game.entity_prototypes[resources[1].name].collision_box, resources[1].position)
		end,
		["init_dependencies"] = empty
	},
	
	["rotate"] = {
		["to_low_level"] = return_self_finished,
		["executable"] = return_true,
		["initialize"] = empty,
		["init_dependencies"] = empty
	},
	
	["speed"] = {
		["to_low_level"] = return_self_finished,
		["executable"] = return_true,
		["initialize"] = empty,
		["init_dependencies"] = empty
	},
}