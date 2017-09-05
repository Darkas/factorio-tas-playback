function auto_move_to_low_level (command, myplayer, tick)
	local auto_move_commands = 0
	
	for _, command in pairs(global.current_command_set) do
		if (not command.finished) and (command[1] == "auto-move-to" or command[1] == "auto-move-to-command") then
			auto_move_commands = auto_move_commands + 1
		end
	end
	
	if auto_move_commands > 1 then
		errprint("You are using more than one auto-move command at once! Do this only if you know what you are doing!")
	end
	
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
		command.finished = true
	end
	
	return {"move", move_dir}
end

function move_collision_box(collision_box, coords)
	local x,y = get_coordinates(coords)
	return {{collision_box.left_top.x + x, collision_box.left_top.y + y}, {collision_box.right_bottom.x + x, collision_box.right_bottom.y + y}}
end

function empty()	
end

function return_self_finished(command, myplayer, tick)
	command.finished = true
	return command
end

function return_phantom ()
	return {"phantom"}
end

function in_range(command, myplayer)
	return distance_from_rect(myplayer.position, command.rect) <= command.distance
end

high_level_commands = {
	
	["auto-move-to"] = {
		to_low_level = auto_move_to_low_level,
		default_priority = 7,
	},
	
	["auto-move-to-command"] = {
		to_low_level = auto_move_to_low_level,
		executable = function(command, myplayer, tick)
			if high_level_commands[command.data.target_command[1]].executable(command.data.target_command, myplayer, tick) == "" then
				command.finished = true
				return "finished"
			end
			
			return ""
		end,
		default_priority = 7,
		initialize = function (command, myplayer)
			for _, com in pairs(global.current_command_set) do
				if com.name == namespace_prefix(command[2], command.data.parent_command_group.name) then
					command.data.target_pos = {}
					distance_from_rect(myplayer.position, com.rect, command.data.target_pos)
					command.data.target_command = com

					debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
				end
			end
			
			if not command.data.target_command then
				debugprint("There is no command named: " .. command[2])
			end
		end,
		init_dependencies = function (command)
			return command[2]
		end
	},
	
	["auto-refuel"] = {
		to_low_level = function(command, myplayer, tick)
			if not command.data.started then
				command.data.started = tick
			end
		
			return {"put", command[2], "coal", 1, defines.inventory.fuel}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer)
				
				if command.data.entity then
					if not has_value({"boiler", "furnace", "mining-drill"}, command.data.entity.type) then
						command.data.entity = nil
						return "No refuelable entity found"
					else
						command.rect = move_collision_box(game.entity_prototypes[command.data.entity.name].collision_box, command.data.entity.position)
						
						if command.data.entity.type == "mining-drill" then
							command.data.frequency = 1600
						end
		
						if command.data.entity.type == "furnace" then -- stone furnace
							command.data.frequency = 2660
						end
					end
				else
					return "No refuelable entity found"
				end
			end
			
			if command.data.started then
				if (command.data.started - tick) % command.data.frequency > 0 then
					return "Needs no refueling now"
				end
			end
			
			if myplayer.get_item_count("coal") == 0 then
				return "Player has no coal"
			end
			
			return ""
		end,
		default_priority = 5,
		initialize = function (command, myplayer)
			command.distance = myplayer.reach_distance
		end,
	},
	
	build = {
		to_low_level = return_self_finished,
		executable = function(command, myplayer, tick)
			if in_range(command, myplayer, tick) and (myplayer.get_item_count(command[2]) > 0) then
				return ""
			else
				return "Player not in range"
			end
		end,
		default_priority = 5,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
			command.rect = move_collision_box(game.entity_prototypes[command[2]].collision_box, command[3])
		end,
	},
	
	craft = {
		to_low_level = return_self_finished,
		executable = function(command, myplayer, tick)
		--	-- Check for missing materials
			local item = command[2]
			local count = command[3]
			if myplayer.get_craftable_count(item) >= count then
				return ""
			else
				return "Player does not have enough items to craft " .. item
			end
		end,
		default_priority = 5,
	},
	
	["craft-build"] = {
		to_low_level = function(command, myplayer, tick)
			if command.data.stage == 1 and not command.data.crafted then
				command.data.crafted = true
				return {"craft", command[2], 1}
			end
			
			if command.data.stage == 2 then
				command.finished = true
				return {"build", command[2], command[3], command[4]}
			end
		end,
		executable = function(command, myplayer, tick)
			command.data.stage = 0
			
			if high_level_commands.build.executable(command, myplayer, tick) == "" then
				command.data.stage = 2
			else
				if high_level_commands.craft.executable({"craft", command[2], 1}, myplayer, tick) == "" and not command.data.crafted then
					command.data.stage = 1
				end
			end
			
			if command.data.stage > 0 then
				return ""
			else
				return "Can do neither craft nor build"
			end
		end,
		default_priority = 5,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
			command.rect = move_collision_box(game.entity_prototypes[command[2]].collision_box, command[3])
		end,
	},
	
	["entity-interaction"] = {
		to_low_level = return_phantom,
		executable = function (command, myplayer)
			if in_range(command, myplayer) then
				return ""
			else
				return "Out of range"
			end
		end,
		default_priority = 100,
		initialize = function (command, myplayer)
			command.distance = command[3] or myplayer.build_distance
			
			local entity = get_entity_from_pos(command[2], myplayer)
		
			command.rect = move_collision_box(game.entity_prototypes[entity.name].collision_box, entity.position)
			
			command.finished = true
		end,
	},
	
	["freeze-daytime"] = {
		to_low_level = return_phantom,
		default_priority = 100,
		initialize = function (command, myplayer)
			myplayer.surface.freeze_daytime = true
		end,
	},
	
	mine = {
		to_low_level = function (command, myplayer, tick)
			return command
		end,
		executable = function(command, myplayer, tick)
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Out of range"
			end
		
			if command.amount and global.current_mining >= command.amount then
				command.finished = true
				global.current_mining = 0
				return "finished"
			end
			
			return ""
		end,
		default_priority = 6,
		initialize = function (command, myplayer)
			local entity = get_entity_from_pos(command[2], myplayer)
			
			
		
			command.distance = myplayer.resource_reach_distance
			
			if entity then
				command.rect = move_collision_box(game.entity_prototypes[entity.name].collision_box, entity.position)
			else
				errprint("There is no mineable thing at (" .. command[2][1] .. "," .. command[2][2] .. ")")
				command.rect = move_collision_box({left_top={x=0,y=0},right_bottom={x=0,y=0}}, command[2])
			end
		end,
	},
	
	put = {
		to_low_level = function(command, myplayer, tick)
			local item = command[3]
			local amount = command[4]
			local inventory = command.inventory
			
			local entity = get_entity_from_pos(command[2], myplayer)
			
			if not inventory then
				local item_type = game.item_prototypes[item].type
				if entity.type == "furnace" then
					if item == "raw-wood" or item == "coal" then
						inventory = defines.inventory.fuel
					else 
						inventory = defines.inventory.furnace_source
					end
				elseif entity.type == "assembling-machine" then
					if item_type == "module" then
						inventory = defines.inventory.assembling_machine_modules
					else
						inventory = defines.inventory.assembling_machine_input
					end
				elseif entity.type == "lab" then
					if item_type == "module" then
						inventory = defines.inventory.lab_modules
					else
						inventory = defines.inventory.lab_input
					end
				elseif entity.type == "car" then
					inventory = defines.inventory.car_trunk
				elseif entity.type == "rocket-silo" then
					if item_type == "module" then
						inventory = defines.inventory.assembling_machine_modules
					elseif item == "satellite" then 
						inventory = defines.inventory.rocket_silo_rocket
					else 
						inventory = defines.inventory.assembling_machine_input
					end
				elseif entity.type == "container" then
					inventory = defines.inventory.chest
				end
			end
			
			if not item then -- take the first thing in the inventory
				item = entity.get_inventory(inventory)[1].name
			end
			
			if not amount then -- take everything
				amount = math.min(entity.get_item_count(item), game.item_prototypes[item].stack_size)
			end
			
			command.finished = true
			
			return {command[1], command[2], item, amount, inventory}
		end,
		executable = function(command, myplayer, tick)
			local entity = get_entity_from_pos(command[2], myplayer)
			if not entity then
				return "No entity found"
			else
				if not command.rect then
					command.rect = move_collision_box(game.entity_prototypes[entity.name].collision_box, entity.position)
					command.distance = myplayer.reach_distance
				end
			end
			
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Out of range"
			end
			
			return ""
		end,
		default_priority = 5,
	},
	
	rotate = {
		to_low_level = return_self_finished,
		default_priority = 5,
	},
	
	speed = {
		to_low_level = return_self_finished,
		default_priority = 100,
	},
	stop = {
		to_low_level = return_phantom,
		default_priority = 100,
	},
	
	take = {
		to_low_level = function(command, myplayer, tick)
			local amount = command[4]
			
			if not amount then -- take everything
				amount = math.min(command.data.entity.get_item_count(command.data.item), game.item_prototypes[command.data.item].stack_size)
			end
			
			command.finished = true
			
			return {command[1], command[2], command.data.item, amount, command.data.inventory}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer)
				if not command.data.entity then
					return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
				end
			end
			
			if not command.data.entity.valid then
				command.data.entity = nil
				return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
			end
			
			if not command.rect then
				command.rect = move_collision_box(game.entity_prototypes[command.data.entity.name].collision_box, command.data.entity.position)
				command.distance = myplayer.reach_distance
			end
			
			if not command.data.inventory then
				command.data.inventory = command.inventory
				if not command.data.inventory then
					local invs = {
						furnace = defines.inventory.furnace_result,
						["assembling-machine"] = defines.inventory.assembling_machine_output,
						container = defines.inventory.chest,
						car = defines.inventory.car_trunk,
						["cargo-wagon"] = defines.inventory.cargo_wagon,
						["mining-drill"] = defines.inventory.fuel
					}
					command.data.inventory = invs[command.data.entity.type]
					
					if not command.data.inventory then
						errprint("No inventory given and automatically determining the inventory failed! Entity type: " .. command.data.entity.type)
						return "No inventory given and automatically determining the inventory failed! Entity type: " .. command.data.entity.type
					end
				end
			end
			
			if not command.data.item then
				command.data.item = command[3]
				if not command.data.item then -- take the first thing in the inventory
					local entity_inventory = command.data.entity.get_inventory(command.data.inventory)
				
					if entity_inventory and entity_inventory[1] and entity_inventory[1].valid_for_read then
						command.data.item = command.data.entity.get_inventory(command.data.inventory)[1].name
					else
						return "Entity " .. command.data.entity.name .. " at (" .. command[2][1] .. "," .. command[2][2] .. ") has no valid inventory item to guess"
					end
				end
			end
			
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Player too far away"
			end
			
			return ""
		end,
		default_priority = 5,
	},

	pickup = {
		to_low_level = function (command, myplayer, tick)
			if command.oneshot then command.finished = true end
			return command
		end,
		default_priority = 100,
	},

	recipe = {
		to_low_level = return_self_finished,
		default_priority = 5,
	},

	["stop-command"] = {
		to_low_level = return_phantom,
		default_priority = 100,
		initialize = function (command, myplayer)
			local cancel = namespace_prefix(command[2], command.command_group)
			
			for _,com in pairs(global.current_command_set) do
				if com.name == cancel then
					com.finished = true
				end
			end
		end,
	},

	tech = {
		default_priority = 5,
		to_low_level = return_self_finished,
		executable = function (command, myplayer, tick)
			if (not myplayer.force.current_research) or command.change_research then
				return ""
			else
				return "There is something reasearching and changing is not allowed."
			end
		end,
	}
}


defaults = {
	to_low_level = return_self_finished,
	executable = function () return "" end,
	initialize = empty,
	init_dependencies = empty
}

for _, command in pairs(high_level_commands) do
	setmetatable(command, {__index = defaults})
end