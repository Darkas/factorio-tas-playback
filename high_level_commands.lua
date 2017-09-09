

global.command_list_parser = global.command_list_parser or {}



function auto_move_to_low_level (command, myplayer, tick)
	local auto_move_commands = 0

	for _, cmd in pairs(global.command_list_parser.current_command_set) do
		if (not cmd.finished) and (cmd[1] == "auto-move-to" or cmd[1] == "auto-move-to-command") then
			auto_move_commands = auto_move_commands + 1
		end
	end

	if auto_move_commands > 1 and not command.data.err_message then
		errprint("You are using more than one auto-move command at once! Do this only if you know what you are doing!")
		command.data.err_message = true
	end

	local target_pos

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
				for _, com in pairs(global.command_list_parser.current_command_set) do
					if com.name == namespace_prefix(command[2], command.data.parent_command_group.name) then
						command.data.target_command = com
					end
				end
			end

			if not command.data.target_command then
				return "There is no command named: " .. command[2]
			end

			if command.data.target_command[1] == "craft-build" and command.data.target_command.data.build_command then
				command.data.target_command = command.data.target_command.data.build_command
			end

			if command.data.target_command.rect then
				command.data.target_pos = {}
				_, command.data.target_pos = distance_from_rect(myplayer.position, command.data.target_command.rect)

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
		execute = return_phantom,
		spawn_commands = function(command, myplayer, tick)
			if not command.data.already_refueled then
				command.data.already_refueled = {}
			end

			local target_fuel = command.target

			if not target_fuel then
				target_fuel = command.min or 1
			end

			local new_commands = {}
			local priority = 5

			for i, entity in pairs(global.command_list_parser.entities_with_burner) do
				if entity.type == "mining-drill" then
					priority = 4
				end

				if distance_from_rect(myplayer.position, collision_box(entity)) <= myplayer.reach_distance then
					if command.min then
						if entity.burner.inventory.get_item_count("coal") < command.min then
							if not command.data.already_refueled[i] then
								command.data.already_refueled[i] = true
								new_commands[#new_commands + 1] = {"put", {entity.position.x, entity.position.y}, "coal", target_fuel - entity.burner.inventory.get_item_count("coal"), priority=priority}
							end
						else
							command.data.already_refueled[i] = false
						end
					else
						if entity.burner.remaining_burning_fuel < 20000 and entity.burner.inventory.get_item_count("coal") == 0 then
							if not command.data.already_refueled[i] then
								command.data.already_refueled[i] = true
								new_commands[#new_commands + 1] = {"put", {entity.position.x, entity.position.y}, "coal", target_fuel, priority=priority}
							end
						else
							command.data.already_refueled[i] = false
						end
					end
				end
			end

			return new_commands
		end,
		default_priority = 100,
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
			command.rect = collision_box{name=command[2], position=copy(command[3])}
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

	["auto-build-blueprint"] = {
		default_priority = 5,
		initialize = function(command, myplayer, tick)
		end,
		execute = return_phantom,
		executable = function (command)
			if command.data.build_command then
				if command.data.build_command.finished then
					command.finished = true
				end

				return "auto-build-blueprint is never executable"
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

			command.rect = collision_box(entity)

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
			if not in_range(command, myplayer) then
				return "Out of range"
			end

			if command.amount and global.command_list_parser.current_mining >= command.amount then
				command.finished = true
				global.command_list_parser.current_mining = 0
				return "finished"
			end

			return ""
		end,
		default_priority = 6,
		initialize = function (command, myplayer)
			local entity = get_entity_from_pos(command[2], myplayer)

			command.distance = myplayer.resource_reach_distance

			if entity then
				command.rect = collision_box(entity)
			else
				errprint("There is no mineable thing at (" .. command[2][1] .. "," .. command[2][2] .. ")")
				command.rect = {left_top=copy(command[2]), right_bottom=copy(command[2])}
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
						command.rect = collision_box(command.data.entity)
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

			if myplayer.get_item_count(item) < command[4] then
				return "Not enough of " .. item .. " in inventory"
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
				command.rect = collision_box(command.data.entity)
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

			for _,com in pairs(global.command_list_parser.current_command_set) do
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
		spawn_commands = function(command, myplayer, tick)
			if command.data.next_tick and command.data.next_tick >= tick then return end

			local item = command[2]
			local count = command[3]
			if not count then return end

			if not command.exact then
				count = count - myplayer.get_item_count(item)
			end

			local area = {{myplayer.position.x - 9, myplayer.position.y-9}, {myplayer.position.x + 9, myplayer.position.y + 9}}
			local entities = {}
			for _, entity in pairs(myplayer.surface.find_entities_filtered{area=area, type="assembling-machine"}) do
				if (in_range({rect = collision_box(entity), distance = myplayer.build_distance}, myplayer) and get_recipe(entity) == item) then
					table.insert(entities, entity)
				end
			end
			for _, entity in pairs(myplayer.surface.find_entities_filtered{area=area, type="furnace"}) do
				if (in_range({rect = collision_box(entity), distance = myplayer.build_distance}, myplayer) and get_recipe(entity) == item) then
					table.insert(entities, entity)
				end
			end

			local count_to_craft = count
			for index, entity in pairs(entities) do
				count_to_craft = count_to_craft - entity.get_item_count(item)
			end

			local count_crafts_all = math.floor(count_to_craft / #entities)
			local remaining = count_to_craft % #entities

			local ret = {}
			if count_crafts_all <= 0 then
				if count_crafts_all < 0 then
					errprint("Auto-take was not optimal: there were more resources in the entities than needed.")
				end

				table.sort(entities, function(a, b) return a.crafting_progress > b.crafting_progress end)
				for index, entity in pairs(entities) do
					local amount = entity.get_item_count(item) + count_crafts_all + (index <= remaining and 1 or 0)
					if amount > 0 then
						local position = {entity.position.x, entity.position.y}
						local cmd = {"take", position, item, amount}
						ret[#ret + 1] = cmd
					end
				end
				command.finished = true
			end

			local ticks = (count_crafts_all - 1) * game.recipe_prototypes[get_recipe(entities[1])].energy * 60
			command.data.next_tick = tick + math.max(math.min(ticks / 3, 40), 1)
			return ret
		end,
		default_priority = 100,
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
