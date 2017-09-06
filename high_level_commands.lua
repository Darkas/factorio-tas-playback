
if not global.command_list_parser then global.command_list_parser = {} end
local our_global = global.command_list_parser


function auto_move_to_low_level (command, myplayer, tick)
	local auto_move_commands = 0
	
	for _, command in pairs(our_global.current_command_set) do
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

function empty()	
end

function return_self_finished(command, myplayer, tick)
	command.finished = true
	return command
end

function set_finished(command)
	command.finished = true
end

function return_phantom ()
	return {"phantom"}
end

action_types = {always_possible = 1, selection = 2, ui = 3}

high_level_commands = {
	
	["auto-move-to"] = {
		execute = auto_move_to_low_level,
		default_priority = 7,
	},
	
	["auto-move-to-command"] = {
		execute = auto_move_to_low_level,
		executable = function(command, myplayer, tick)
			if not command.data.target_command then
				for _, com in pairs(our_global.current_command_set) do
					if com.name == namespace_prefix(command[2], command.data.parent_command_group.name) then
						command.data.target_command = com
					end
				end
			end
			
			if not command.data.target_command then
				return "There is no command named: " .. command[2]
			end
			
			if command.data.target_command.name == "craft-build" then
				return "auto-move-to-command cannot move to a craft-build command! Please use the name " .. command[2] .. "-build to go to the build part"
			end
			
			if command.data.target_command.rect then
				command.data.target_pos = {}
				distance_from_rect(myplayer.position, command.data.target_command.rect, command.data.target_pos)
				
				debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
			else
				return "The command does currently not have a location"
			end
			
			if high_level_commands[command.data.target_command[1]].executable(command.data.target_command, myplayer, tick) == "" then
				command.finished = true
				return "finished"
			end
			
			return ""
		end,
		default_priority = 7,
		initialize = function (command, myplayer)
			
		end,
		init_dependencies = function (command)
			return command[2]
		end
	},
	
	["auto-refuel"] = {
		execute = function(command, myplayer, tick)
			if not command.data.started then
				command.data.started = tick
			end
		
			return {"put", command[2], "coal", 1, defines.inventory.fuel}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer)
				
				if command.data.entity then -- TODO: instead, try using entity.burner to determine if refueling is needed
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
		default_action_type = action_types.selection,
	},
	
	build = {
		execute = return_self_finished,
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
		execute = return_self_finished,
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
		default_priority = 5,
		execute = return_phantom,
		executable = function (command)
			if command.data.build_command then
				if command.data.build_command.finished then
					command.finished = true
				end
				
				return "craft-build is never executable"
			end
			
			return ""
		end,
		spawn_commands = function (command, myplayer, tick)
			command.data.build_command = {"build", command[2], command[3], command[4]}
			
			return {{"craft", command[2], 1}, command.data.build_command}
		end,
	},
	
	["entity-interaction"] = {
		execute = return_phantom,
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
		execute = return_phantom,
		default_priority = 100,
		initialize = function (command, myplayer)
			myplayer.surface.freeze_daytime = true
		end,
	},
	
	mine = {
		execute = function (command, myplayer, tick)
			return command
		end,
		executable = function(command, myplayer, tick)
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Out of range"
			end
		
			if command.amount and our_global.current_mining >= command.amount then
				command.finished = true
				our_global.current_mining = 0
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
		default_action_type = action_types.selection,
	},
	
	put = {
		execute = function(command, myplayer, tick)
			local item = command[3]
			local amount = command[4]
			local inventory = command.inventory
		
			
			command.finished = true
			
			return {command[1], command[2], command[3], command[4], command.data.inventory}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer)
				if not command.data.entity then
					return "No entity found"
				else
					if not command.rect then
						command.rect = move_collision_box(game.entity_prototypes[command.data.entity.name].collision_box, command.data.entity.position)
						command.distance = myplayer.reach_distance
					end
				end
			end
			
			local item = command[3]
			
			if not command.data.inventory then
				command.data.inventory = command.inventory
				if not command.data.inventory then
					local item_type = game.item_prototypes[item].type
					if command.data.entity.type == "furnace" then
						if item == "raw-wood" or item == "coal" then
							command.data.inventory = defines.inventory.fuel
						else 
							command.data.inventory = defines.inventory.furnace_source
						end
					elseif command.data.entity.type == "mining-drill" then
						command.data.inventory = defines.inventory.fuel
					elseif command.data.entity.type == "assembling-machine" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.assembling_machine_modules
						else
							command.data.inventory = defines.inventory.assembling_machine_input
						end
					elseif command.data.entity.type == "lab" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.lab_modules
						else
							command.data.inventory = defines.inventory.lab_input
						end
					elseif command.data.entity.type == "car" then
						inventory = defines.inventory.car_trunk
					elseif command.data.entity.type == "rocket-silo" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.assembling_machine_modules
						elseif item == "satellite" then 
							command.data.inventory = defines.inventory.rocket_silo_rocket
						else 
							command.data.inventory = defines.inventory.assembling_machine_input
						end
					elseif command.data.entity.type == "container" then
						command.data.inventory = defines.inventory.chest
					end
					if not command.data.inventory then
						return "Inventory could not be determined"
					end
				end
			end
			
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Out of range"
			end
			
			return ""
		end,
		default_priority = 5,
		default_action_type = action_types.selection,
	},
	
	rotate = {
		execute = return_self_finished,
		default_priority = 5,
		default_action_type = action_types.selection,
	},
	
	speed = {
		execute = return_self_finished,
		default_priority = 100,
	},
	stop = {
		execute = return_phantom,
		default_priority = 100,
	},
	
	take = {
		execute = function(command, myplayer, tick)
			command.finished = true
			
			return {command[1], command[2], command.data.item, command.data.amount, command.data.inventory, action_type = command.action_type}
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
			
			-- TODO: if no item and amount are given, take the entire inventory as a selection action. Otherwise, it is a ui action
			
			if not command.data.item then
				command.data.item = command[3]
				if not command.data.item then -- take the first thing in the inventory
					local entity_inventory = command.data.entity.get_inventory(command.data.inventory)
				
					if entity_inventory and entity_inventory[1] and entity_inventory[1].valid_for_read then
						command.data.item = command.data.entity.get_inventory(command.data.inventory)[1].name
					else
						local x, y = get_coordinates(command[2])
						return "Entity " .. command.data.entity.name .. " at (" .. x .. "," .. y .. ") has no valid inventory item to guess"
					end
				end
			end

			command.data.amount = command[4]
			if not command.data.amount then
				command.data.amount = command.data.entity.get_item_count(command.data.item)
				command.action_type = action_types.selection
			else
				command.action_type = action_types.ui
				command.ui = command[2]
			end

			if command.data.entity.get_item_count(command.data.item) < command.data.amount then
   				return "Not enough items available!"
			end			
			
			if distance_from_rect(myplayer.position, command.rect) > command.distance then
				return "Player too far away"
			end
			
			return ""
		end,
		default_priority = 5,
	},

	pickup = {
		execute = function (command, myplayer, tick)
			if command.oneshot then command.finished = true end
			return command
		end,
		default_priority = 100,
	},

	recipe = {
		execute = return_self_finished,
		default_priority = 5,
		default_action_type = action_types.ui,
	},

	["stop-command"] = {
		execute = return_phantom,
		default_priority = 100,
		initialize = function (command, myplayer)
			local cancel = namespace_prefix(command[2], command.command_group)
			
			for _,com in pairs(our_global.current_command_set) do
				if com.name == cancel then
					com.finished = true
				end
			end
			command.finished = true
		end,
	},

	tech = {
		default_priority = 5,
		execute = return_self_finished,
		executable = function (command, myplayer, tick)
			if (not myplayer.force.current_research) or command.change_research then
				return ""
			else
				return "There is something researching and changing is not allowed."
			end
		end,
	},
	
	["auto-take"] = {
		update = function(command, command_list, commandqueue, myplayer, tick)
			if command.data.next_tick and command.data.next_tick < game.tick then return end

			local item = command[2]
			local count = command[3]
			if not command.exact then
				count = count - myplayer.get_item_count()
			end

			local area = {{myplayer.position.x - 9, myplayer.position.y-9}, {myplayer.position.x + 9, myplayer.position.y + 9}}
			local entities = {}
			for _, entity in pairs(myplayer.surface.find_entities_filtered{area=area, type="assembling-machine"}) do
				if (distance_from_rect(myplayer.position, collision_box(entity)) and get_recipe(entity) == item) then
					table.insert(entities, entity)
				end
			end
			for _, entity in pairs(myplayer.surface.find_entities_filtered{area=area, type="furnace"}) do
				if (distance_from_rect(myplayer.position, collision_box(entity)) and get_recipe(entity) == item) then
					table.insert(entities, entity)
				end
			end

			game.print(#entities)

			local ticks = 1
			local upper = nil
			
			while upper == nil or upper - ticks > 5 do
				local amount = command[3]
				for _, ent in pairs(entities) do 
					amount = amount - craft_interpolate(ent, ticks)
				end

				game.print("amount " .. amount)

				--amount = 80 - ticks
				if upper == nil then 
					if amount > 0 then 
						ticks = ticks * 2
					else
						upper = ticks
						ticks = ticks / 2
					end
				elseif amount > 0 then 
					ticks = (ticks + upper) / 2
				elseif amount < 0 then upper = (ticks + upper) / 2
				else break
				end

				game.print("ticks " .. ticks)
			end

			-- local ticks = 300
			for _, entity in pairs(entities) do
				local amount = craft_interpolate(entity, ticks)
				if amount > 0 then
					local position = {entity.position.x, entity.position.y}
					local cmd = {"take", position, item, amount}
					if ticks < 15 then
						command.command_finished = true
						command_list_parser.add_command_to_current_set(cmd, myplayer, tick, command.data.parent_command_group)
					end
				end
			end

			command.data.next_tick = game.tick + ticks / 3
		end,
		execute = empty,
	}
}


defaults = {
	execute = return_self_finished,
	executable = function () return "" end,
	initialize = empty,
	init_dependencies = empty,
	default_action_type = action_types.always_possible,
	default_priority = 5,
	spawn_commands = function () return {} end,
}

for _, command in pairs(high_level_commands) do
	setmetatable(command, {__index = defaults})
end