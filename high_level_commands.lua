require("blueprint")
local TAScommands = require("commands")

global.high_level_commands = global.high_level_commands or {
	throw_cooldown = nil,
	simple_sequence_index = 1,
	move_sequence_index = 1,
	command_requests = {},
}

function can_craft(craft, myplayer, need_intermediates)
	if not myplayer.force.recipes[craft.name].enabled then
		return false
	end
	if need_intermediates then
		local recipe = game.recipe_prototypes[craft.name]

		if need_intermediates then
			for _, ingr in pairs(recipe.ingredients) do
				if (need_intermediates == true or has_value(need_intermediates, ingr.name)) and myplayer.get_item_count(ingr.name) < ingr.amount then
					return false
				end
			end
		end
	end

	return myplayer.get_craftable_count(craft.name) >= 1
end

function empty()
end

function strip_command(command)
	if command[6] then error("Command " .. command[1] .. " has more arguments than expected: !") end
	return {command[1], command[2], command[3], command[4], command[5], already_executed = command.already_executed}
end

function return_self_finished(command, myplayer, tick)
	command.finished = true
	return strip_command(command)
end

function set_finished(command)
	command.finished = true
end

function return_phantom ()
	return {"phantom"}
end

action_types = {always_possible = 1, selection = 2, ui = 3, throw = 4}
entities_with_inventory = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler", "lab", "rocket-silo"}






high_level_commands = {
	alert = {
		type_signature = {
			[2] = "string",
		},
		execute = function(command, myplayer, tick)
			if #game.players == 1 then
				game.show_message_dialog{text="Now entering: " .. command[2]}
			else
				game.print("Now entering: " .. command[2])
			end
			command.finished = true
		end
	},
	["auto-build-blueprint"] = {
		type_signature =
		{
			[2] = "string",
			[3] = {"nil", "position"},
			area = {"nil", "table"},
			rotation = {"nil", "number"},
		},
		default_priority = 100,

		execute = empty,

		executable = function (command)
			return ""
		end,

		spawn_commands = function (command, myplayer, tick)
			local blueprint = command.data.blueprint_data
			local entities = Blueprint.get_entities_in_build_range(blueprint, myplayer)

			-- This is for compatibility between move-to-command and build-blueprint.
			for index, request in pairs(global.high_level_commands.command_requests) do
				local name = request[1]
				local move_to_namespace = request[2]
				local _, _, namespace, data = string.find(name, "(.*%.)bp_(.*)")
				if not data then _, _, data = string.find(name, "bp_(.*)") end
				if data and (not namespace or namespace == command.namespace or namespace == move_to_namespace) then
					local _, _, x, y = string.find(data, "{(.*),(.*)}")
					local position = {tonumber(x), tonumber(y)}
					local entity = Blueprint.get_entity_at(blueprint, position)
					if entity then
						entities[#entities + 1] = entity
						table.remove(global.high_level_commands.command_requests, index)
					end
				end
			end

			command.data.all_commands = command.data.all_commands or {}
			local added_commands = {}

			for _, entity in pairs(entities) do
				local cmd_already_spawned = false
				for _, cmd in pairs(global.command_list_parser.current_command_set) do
					if cmd[1] == "build" then
						if sqdistance(cmd[3], entity.position) < 0.01 and cmd[2] == entity.name then
							cmd_already_spawned = true
							break
						end
					end
				end

				if cmd_already_spawned or get_entity_from_pos(entity.position, myplayer, game.entity_prototypes[entity.name].type) then
					entity.built = true
					command.data.added_all_entities = not Blueprint.remove_entity(blueprint, entity)
				else
					if not entity.built then
						entity.built = true
						local build_command = {
							"build",
							entity.name,
							entity.position,
							entity.direction,
							name="bp_{" .. entity.position[1] .. ", " .. entity.position[2] .. "}",
							on_leaving_range = command.set_on_leaving_range and true,
							namespace = command.namespace,
						}
						if entity.name == "underground-belt" then
							build_command[5] = entity.type
						end
						table.insert(command.data.all_commands, build_command)
						table.insert(added_commands, build_command)
					end

					if entity.recipe and entity.built and not entity.set_recipe then
						entity.set_recipe = true
						local recipe_command = {
							"recipe",
							entity.position,
							entity.recipe,
							name="bp_recipe_{" .. entity.position[1] .. ", " .. entity.position[2] .. "}",
							namespace = command.namespace,
						}
						table.insert(added_commands, recipe_command)
						table.insert(command.data.all_commands, recipe_command)

						if entity.items then
							for name, count in pairs(entity.items) do
								local module_command = {
									"put",
									entity.position,
									name,
									count,
									name="bp_module_{" .. entity.position[1] .. ", " .. entity.position[2] .. "}",
									namespace = command.namespace,
								}
								table.insert(command.data.all_commands, module_command)
								table.insert(added_commands, module_command)
							end
						end
						command.data.added_all_entities = not Blueprint.remove_entity(blueprint, entity)
					elseif not entity.recipe then
						command.data.added_all_entities = not Blueprint.remove_entity(blueprint, entity)
					end
				end
			end

			if command.data.all_commands then
				local finished = true
				for index, cmd in pairs(command.data.all_commands) do
					finished = cmd.finished and finished
					if cmd.finished then table.remove(command.data.all_commands, index) end
				end
				if command.data.added_all_entities and finished then
					command.finished = true
				end
			end

			return added_commands
		end,

		initialize = function (command, myplayer, tick)
			local name = command[2]
			local offset = command[3]
			local area = command.area
			local rotation = command.rotation or defines.direction.north
			command.data.blueprint_data = Blueprint.load(name, offset, rotation, 9, area)
			command.data.area = area
		end
	},

	["auto-refuel"] = {
		type_signature = {
			target = {"nil", "number"},
			min = {"nil", "number"},
			skip_coal_drills = "boolean",
			type = {"nil", "string"},
			pos = {"nil", "position"}
		},
		execute = empty,
		spawn_commands = function(command, myplayer, tick)
			if not command.data.already_refueled then
				command.data.already_refueled = {}
			end

			local target_fuel = command.target or command.min or 1

			local new_commands = {}
			local priority = 5

			for i, entity in pairs(global.command_list_parser.entities_with_burner) do
				if not entity.valid then
					game.print("Invalid entity in auto-refuel! This may occur if you mine a fuelable entity.")
				else
					if not (command.skip_coal_drills and entity.type == "mining-drill" and entity.mining_target and entity.mining_target.name == "coal") then
						if ((not command.type) or entity.type == command.type) and ((not command.pos) or (entity.position.x == command.pos[1] and entity.position.y == command.pos[2])) then
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
					end
				end
			end

			return new_commands
		end,
		default_priority = 100,
	},

	["auto-take"] = {
		type_signature = {
			[2] = "string",
			[3] = "number",
			exact = "boolean",
		},
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
			for _, entity in pairs(entities) do
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
	},

	build = {
		type_signature = {
			[2] = "string",
			[3] = "position",
			[4] = {"nil", "number"},
		},
		execute = function(command, myplayer)
			if myplayer.get_item_count(command[2]) ~= 0 then
				TAScommands["build"](command, myplayer)
				command.finished = true
				command.already_executed = true
				return strip_command(command)
			else
				return
			end
		end,
		executable = function(command, myplayer, tick)
			if myplayer.get_item_count(command[2]) == 0 then
				return "Item not available (" .. command[2] .. ")"
			end

			if not in_range(command, myplayer, tick) then
				return "Player not in range (" .. command[2] .. ")"
			end

			if inside_rect(myplayer.position, collision_box{name=command[2], position=command[3], direction=command[4]}) then
				return "Player is in the way!"
			end
			return ""
		end,
		default_priority = 5,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
			command.rect = collision_box{name=command[2], position=copy(command[3])}
		end,
	},

	craft = {
		type_signature = {
			[2] = {"table", "string"},
			[3] = {"number", "nil"},
			need_intermediates = "boolean",
		},
		execute = function(command, myplayer)
			local craft = command.data.crafts[command.data.craft_index]
			local return_commands = {}

			while can_craft(craft, myplayer, craft.need_intermediates) do
				local cmd = {"craft", craft.name, 1, already_executed = true}
				TAScommands["craft"](cmd, myplayer)
				table.insert(return_commands, cmd)

				craft.count = craft.count - 1
				if craft.count == 0 then
					command.data.craft_index = command.data.craft_index + 1
					craft = command.data.crafts[command.data.craft_index]
				end

				if not craft then
					command.finished = true
					break
				end
			end

			return table.unpack(return_commands)
		end,
		executable = function(command, myplayer, tick)
			local item = command.data.crafts[command.data.craft_index].name
			local recipe = myplayer.force.recipes[item]
			local craft = command.data.crafts[command.data.craft_index]

			if not recipe.enabled then
				return "Recipe " .. item .. " is not available."
			end

			if not can_craft(craft, myplayer, craft.need_intermediates) then
				return "The requested item cannot be crafted."
			end

			return ""
		end,
		default_priority = 5,
		initialize = function(command)
			if type(command[2]) == "string" then
				command[3] = command[3] or 1
				command.data.crafts = {{name=command[2], count=command[3], need_intermediates=command.need_intermediates}}
			elseif type(command[2]) == "table" then
				command.data.crafts = {}
				for _, craft in pairs(command[2]) do
					local need_intermediates = craft.need_intermediates
					if need_intermediates == nil then
						need_intermediates = command.need_intermediates
					end
					local name = craft[1] or craft.name
					local count = craft[2] or craft.count
					command.data.crafts[#command.data.crafts + 1] = {name = name, count = count, need_intermediates = need_intermediates}
				end
			else
				errprint("Craft: Wrong parameter type")
			end

			command.data.craft_index = 1
		end
	},

	["craft-build"] = {
		type_signature = {
			[2] = "string",
			[3] = "position",
			[4] = {"nil", "number"},
		},
		default_priority = 5,
		execute = empty,
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
			local x, y = get_coordinates(command[3])
			local name = "craftbuild_build_{" .. x .. ", " .. y .. "}"
			command.data.build_command = {"build", command[2], command[3], command[4], name=name}

			return {{"craft", command[2], 1}, command.data.build_command}
		end,
	},

	["display-warning"] = {
		type_signature = {
			[2] = "string",
		},
		execute = empty,
		default_priority = 100,
		initialize = function (command, myplayer)
			errprint(command[2])
			command.finished = true
		end,
	},

	["entity-interaction"] = {
		type_signature = {
			[2] = "position",
		},
		execute = empty,
		executable = function (command, myplayer)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer, entities_with_inventory)

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

			if in_range(command, myplayer) then
				command.finished = true

				return ""
			else
				return "Out of range"
			end
		end,
		default_priority = 100,
	},

	["freeze-daytime"] = {
		type_signature = { },
		execute = empty,
		default_priority = 100,
		initialize = function (command, myplayer)
			myplayer.surface.freeze_daytime = true
		end,
	},

	mine = {
		type_signature = {
			[2] = "position",
			amount = {"nil", "number"},
			type  = {"nil", "string"},
		},
		execute = strip_command,

		executable = function(command, myplayer, tick)
			if not in_range(command, myplayer) then
				return "Out of range"
			end

			if global.command_list_parser.current_mining >= command.data.amount then
				command.finished = true
				global.command_list_parser.current_mining = 0
				return "finished"
			end

			return ""
		end,

		default_priority = 6,

		initialize = function (command, myplayer)
			local position = command[2]
			if not command.amount then command.amount = 1 end

			command.data.amount = command.amount or 1

			local type = nil

			if command[3] then
				type = command[3]

				if type == "stone-rock" or type == "rock" then type = "simple-entity" end
				if type == "res" then type = "resource" end
			end

			local entity = get_entity_from_pos(position, myplayer, type)

			command.distance = myplayer.resource_reach_distance

			if entity then
				command.rect = collision_box(entity)
				command[2] = {entity.position.x, entity.position.y}
			else
				errprint("There is no mineable thing at (" .. serpent.block(position) .. ")")
				command.rect = {copy(position), copy(position)}
			end
		end,
		default_action_type = action_types.selection,
	},

	move = {
		type_signature = {
			[2] = {"string", "position"},
		},
		execute = function (command, myplayer, tick)
			if (command.data.move_to_command and in_range(command.data.target_command, myplayer)) or (command.data.move_to_entity and in_range(command, myplayer)) then
				command.finished = true
				return {"phantom"}
			end

			if command.data.move_dir == "" then
				if (command[1] == "move" and not command.data.move_to_command) or command.data.move_to_entity then
					command.finished = true
					return {"phantom"}
				else
					command.data.move_dir = command.data.last_dir
				end
			end

			if not command.data.move_started then
				debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
				command.data.move_started = true
			end

			command.data.last_dir = command.data.move_dir

			return {"move", command.data.move_dir}
		end,
		executable = function(command, myplayer, tick)
			if command.data.move_to_entity then
				if not command.data.target_entity then
					command.data.target_entity = get_entity_from_pos(command[2], myplayer)
					if not command.data.target_entity then
						return "No entity at " .. serpent.block(command.position) .. "."
					else
						command.rect = collision_box(command.data.target_entity)
					end
				end
			elseif command.data.move_to_command then
				if not command.data.target_command then
					for _, com in pairs(global.command_list_parser.current_command_set) do
						if com.name and has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
							command.data.target_command = com
						end
					end
				end

				if not command.data.target_command then
					errprint("move: There is no command named: " .. command[2])
					return "There is no command named: " .. command[2]
				end

				if command.data.target_command[1] == "craft-build" and command.data.target_command.data.build_command then
					command.data.target_command = command.data.target_command.data.build_command
				end

				if not command.data.target_command.rect then
					return "The command does currently not have a location"
				end
			end

			if (not command.data.target_pos or not command.data.move_started) then
				if command[1] == "move"  then
					if command.data.move_to_command then
						command.data.target_pos = closest_point(command.data.target_command.rect, command.data.target_command.distance, myplayer.position)
					elseif command.data.move_to_entity then
						command.data.target_pos = closest_point(command.rect, command.distance, myplayer.position)
					else
						command.data.target_pos = command[2]
					end
				else
					command.data.target_pos = closest_point(command.rect, command.distance, myplayer.position)
				end
			end

			if not command.data.last_dir then
				command.data.last_dir = ""

				if myplayer.position.y > command.data.target_pos[2] then
					command.data.last_dir = command.data.last_dir .. "N"
				end
				if myplayer.position.y < command.data.target_pos[2] then
					command.data.last_dir = command.data.last_dir .. "S"
				end
				if myplayer.position.x > command.data.target_pos[1] then
					command.data.last_dir = command.data.last_dir .. "W"
				end
				if myplayer.position.x < command.data.target_pos[1] then
					command.data.last_dir = command.data.last_dir .. "E"
				end
			end

			local epsilon = 0.15 -- TODO: This should depend on the velocity.

			if myplayer.position.y > command.data.target_pos[2] + epsilon then
				command.data.move_north = true
			end
			if myplayer.position.y < command.data.target_pos[2] - epsilon then
				command.data.move_south = true
			end
			if myplayer.position.x > command.data.target_pos[1] + epsilon then
				command.data.move_west = true
			end
			if myplayer.position.x < command.data.target_pos[1] - epsilon then
				command.data.move_east = true
			end

			if myplayer.position.y < command.data.target_pos[2] then
				command.data.move_north = false
			end
			if myplayer.position.y > command.data.target_pos[2] then
				command.data.move_south = false
			end
			if myplayer.position.x < command.data.target_pos[1] then
				command.data.move_west = false
			end
			if myplayer.position.x > command.data.target_pos[1] then
				command.data.move_east = false
			end

			command.data.move_dir = ""

			if command.data.move_north then
				command.data.move_dir = command.data.move_dir .. "N"
			end
			if command.data.move_south then
				command.data.move_dir = command.data.move_dir .. "S"
			end
			if command.data.move_west then
				command.data.move_dir = command.data.move_dir .. "W"
			end
			if command.data.move_east then
				command.data.move_dir = command.data.move_dir .. "E"
			end

			return ""
		end,
		default_priority = 7,
		initialize = function (command, myplayer)
			command.data.move_north = false
			command.data.move_south = false
			command.data.move_west = false
			command.data.move_east = false
			
			command.distance = myplayer.reach_distance

			if type(command[2]) == "string" then
				command.data.move_to_command = true
				
				for _, com in pairs(global.command_list_parser.current_command_set) do
					if com.name and has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
						command.data.target_command = com
					end
				end

				if not command.data.target_command and string.find(command[2], "bp_") then
					global.high_level_commands.command_requests[#global.high_level_commands.command_requests + 1] = {command[2], command.namespace}
				end
			elseif command[2].entity then
				command.data.move_to_entity = true
			end
		end,
	},

	parallel = {
		type_signature = {
			[2] = "table",
		},
		execute = empty,
		initialize = empty,
		spawn_commands = function(command, myplayer, tick)
			local commands = {}
			local i = 1
			if global.high_level_commands.parallel_name == command.data.parent_command_group.name then
				global.high_level_commands.parallel_index = global.high_level_commands.parallel_index + 1
			else
				global.high_level_commands.parallel_index = 1
				global.high_level_commands.parallel_name = command.data.parent_command_group.name
			end
			for index, cmd in ipairs(command[2]) do
				if not cmd.name then
					i = i + 1
					cmd.name = i
				end
				commands[#commands + 1] = copy(cmd)
				if command.name then
					commands[#commands].namespace = command.namespace .. command.name .. "."
				else
					commands[#commands].namespace = command.namespace .. "parallel-" .. global.high_level_commands.parallel_index .. "."
				end
			end

			command.finished = true
			return commands
		end,
		default_priority = 100,
	},

	["passive-take"] = {
		type_signature = {
			[2] = "string",
			[3] = "string",
		},
		execute = empty,
		executable = function (command, myplayer, tick)
			command.data.spawn_queue = {}

			for i,entity in pairs(global.command_list_parser.entities_by_type[command[3]]) do
				if command.data.take_spawned[i] and command.data.take_spawned[i].finished then
					command.data.take_spawned[i] = nil
				end
				if (not command.data.take_spawned[i]) and entity.get_item_count(command[2]) > 0 then
					local cmd = {"take", {entity.position.x, entity.position.y}, command[2], data={}, namespace=command.namespace}

					if high_level_commands["take"].executable(cmd, myplayer, tick) == "" then
						command.data.take_spawned[i] = cmd
						table.insert(command.data.spawn_queue, cmd)
					end
				end
			end

			if #command.data.spawn_queue == 0 then
				return "No new commands available"
			end

			return ""
		end,
		spawn_commands = function(command, myplayer, tick)
			return command.data.spawn_queue
		end,
		initialize = function(command, myplayer, tick)
			command.data.take_spawned = {}
		end,
		default_priority = 100,
	},

	pickup = {
		type_signature = {
			oneshot = "boolean",
			ticks = "number",
		},
		execute = function (command, myplayer, tick)
			if command.ticks then
				if command.data.final then
					if tick >= command.data.final then
						command.finished = true
					end
				else
					command.data.final = tick + command.ticks
				end
			elseif command.oneshot then
				command.finished = true
			end
			
			return strip_command(command)
		end,
		default_priority = 100,
	},

	put = {
		type_signature = {
			[2] = "position",
			[3] = "string",
			[4] = {"nil", "number"},
			[5] = {"nil", "number"},
		},
		execute = function(command, myplayer, tick)
			command.finished = true

			return {command[1], command[2], command[3], command.data.count, command.data.inventory}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = get_entity_from_pos(command[2], myplayer, entities_with_inventory)
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

			if not command.data.count then
				command.data.count = math.min(myplayer.get_item_count(item), game.item_prototypes[item].stack_size)
			elseif myplayer.get_item_count(item) < command[4] then
				return "Not enough of " .. item .. " in inventory"
			end

			if not command.data.inventory then -- TODO: cargo wagon is missing here
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
					elseif command.data.entity.type == "boiler" then
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
						command.data.inventory = defines.inventory.car_trunk
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
					else
						return "Inventory could not be determined"
					end
				end
			end

			if command.data.entity.type == "assembling-machine" and (not command.data.entity.recipe) then
				return "Recipe is not set for assembling-machine"
			end

			if not in_range(command, myplayer, tick) then
				return "Out of range (" .. item .. ")"
			end

			return ""
		end,
		default_priority = 5,
		default_action_type = action_types.selection,
		initialize = function (command, myplayer)
			command.data.count = command[4]
			command.data.inventory = command[5]
		end
	},

	recipe = {
		type_signature = {
			[2] = "position",
			[3] = "string",
		},
		executable = function(command, myplayer, tick)
			local entity = get_entity_from_pos(command[2], myplayer, "assembling-machine", 0.5)
			if entity then
				command.rect = collision_box(entity)
			else
				return "Entity not built"
			end

			if in_range(command, myplayer, tick) then
				return ""
			else
				return "Player not in range"
			end
		end,

		default_priority = 5,
		default_action_type = action_types.ui,
		initialize = function (command, myplayer)
			command.data.ui = command[2]
			command.distance = myplayer.build_distance
			--command.rect = collision_box{name=command[2], position=copy(command[3])}
		end,
	},

	rotate = {
		type_signature = {
			[2] = "position",
			[3] = {"nil", "string"},
		},
		execute = return_self_finished,
		default_priority = 5,
		default_action_type = action_types.selection,
	},

	speed = {
		type_signature = {
			[2] = "number",
		},
		execute = return_self_finished,
		default_priority = 100,
	},

	stop = {
		type_signature = { },
		execute = empty,
		default_priority = 100,
	},

	["stop-command"] = {
		type_signature = {
			[2] = "string",
		},
		execute = empty,
		default_priority = 100,
		initialize = function (command, myplayer)
			if global.command_list_parser.finished_named_commands[command[2]]
			or global.command_list_parser.finished_named_commands[command.namespace .. command[2]] then
				errprint("Attempting to stop command that is already finished: " .. command[2])
				command.finished = true
				return
			end
			for _, com in pairs(global.command_list_parser.current_command_set) do
				if com.name and has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
					com.finished = true
					command.finished = true
					if com[1] == "mine" then
						global.command_list_parser.current_mining = 0
					end

					return
				end
			end

			errprint("No command with the name " .. command[2] .. " found!")
		end,
	},

	take = {
		type_signature = {
			[2] = "position",
			[3] = {"nil", "string"},
			[4] = {"nil", "number"},
			[5] = {"nil", "number"},
		},
		execute = function(command, myplayer, tick)
			command.finished = true

			return {command[1], command[2], command.data.item, command.data.amount, command.data.inventory, action_type = command.action_type}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				if command.type then
					command.data.entity = get_entity_from_pos(command[2], myplayer, command.type)
				else
					command.data.entity = get_entity_from_pos(command[2], myplayer, entities_with_inventory)
				end

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
			if (not command.data.amount) or (command.data.amount == command.data.entity.get_inventory(command.data.inventory).get_item_count(command.data.item)) then
				command.data.amount = command.data.entity.get_inventory(command.data.inventory).get_item_count(command.data.item)
				command.action_type = action_types.selection
			else
				command.action_type = action_types.ui
				command.data.ui = command[2]
			end

			if command.data.amount == 0 then
				return "You cannot take 0 items!"
			end

			if command.data.entity.get_item_count(command.data.item) < command.data.amount then
				return "Not enough items available!"
			end

			if not in_range(command, myplayer) then
				return "Player too far away"
			end

			return ""
		end,
		default_priority = 5,
	},

	tech = {
		type_signature = {
			[2] = "string"
		},
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

	["throw-grenade"] =
	{
		type_signature = {
			[2] = "position",
		},
		execute = function(command)
			command.finished = true
			global.high_level_commands.throw_cooldown = game.tick
			return strip_command(command)
		end,
		default_action_type = action_types.throw,
		executable = function (command, myplayer, tick)
			if myplayer.get_item_count("grenade") < 1 then
				return "Need more grenades!"
			end
			if sqdistance(myplayer.position, command[2]) > 15^2 then
				return "Not in range!"
			end
			if global.high_level_commands.throw_cooldown and game.tick - global.high_level_commands.throw_cooldown < 30 then
				return "Cooldown not expired yet!"
			end

			return ""
		end
	},
	["simple-sequence"] = {
		type_signature = {
			[2] = "string",
			[3] = "table",
			passed_arguments = {"nil", "table"},
		},
		initialize = function(command, myplayer, tick)
			if global.high_level_commands.simple_sequence_name == command.data.parent_command_group.name then
				global.high_level_commands.simple_sequence_index = global.high_level_commands.simple_sequence_index + 1
			else
				global.high_level_commands.simple_sequence_index = 1
				global.high_level_commands.simple_sequence_name = command.data.parent_command_group.name
			end

			command.data.index = 0
			command.data.namespace = command.namespace .. command[2] .. "-sequence-"
			if command.name then
				command.data.namespace = command.data.namespace .. command.name .. "."
			else
				command.data.namespace = command.data.namespace .. global.high_level_commands.simple_sequence_index .. "."
			end
		end,
		execute = empty,
		spawn_commands = function(command, myplayer, tick)
			command.data.index = command.data.index + 1
			if command.data.index + 2 > #command then
				command.finished = true
			else
				local cmd = {
					command[2],
					command[command.data.index + 2],
					name= "command-" .. command.data.index,
					namespace=command.data.namespace,
				}
				
				if command[2] == "move" then
					for k, v in pairs(command.pass_arguments or {}) do
						cmd[k] = v
					end
					return {cmd}
				else
					for k, v in pairs(command.pass_arguments or {}) do
						cmd[k] = v
					end

					return {
						cmd,
						{
							"move",
							"command-" .. command.data.index,
							namespace = command.data.namespace,
						}
					}
				end
			end
		end,
		executable = function(command, myplayer, tick)
			if command.data.index == 0 or global.command_list_parser.finished_named_commands[command.data.namespace .. "command-" .. command.data.index] then
				return ""
			else
				return "Waiting for command: command-" .. command.data.index
			end
		end,
		default_priority = 100,
	},

	sequence = {
		type_signature = {
			[2] = "table",
			pass_arguments = {"table", "nil"},
		},
		initialize = function(command, myplayer, tick)
			if global.high_level_commands.sequence_name == command.data.parent_command_group.name then
				global.high_level_commands.sequence_index = global.high_level_commands.sequence_index + 1
			else
				global.high_level_commands.sequence_index = 1
				global.high_level_commands.sequence_name = command.data.parent_command_group.name
			end

			command.data.index = 0
			if command.name then
				command.data.namespace = command.namespace  .. command.name .. "."
			else
				command.data.namespace = command.namespace .. "sequence-" .. global.high_level_commands.sequence_index .. "."
			end
		end,
		execute = empty,
		spawn_commands = function(command, myplayer, tick)
			command.data.index = command.data.index + 1
			if command[command.data.index + 1] == nil then
				command.finished = true
			else
				local cmd = copy(command[2][command.data.index + 1])
				for k, v in pairs(command.pass_arguments or {}) do
					cmd[k] = v
				end

				return { cmd }
			end
		end,
		executable = function(command, myplayer, tick)
			if command.data.index == 0 or global.command_list_parser.finished_named_commands[command.data.namespace .. "command-" .. command.data.index] then
				return ""
			else
				return "Waiting for command: command-" .. command.data.index
			end
		end,
		default_priority = 100,
	}
}


defaults = {
	type_sequence = nil,
	execute = return_self_finished,
	executable = function () return "" end,
	initialize = empty,
	default_action_type = action_types.always_possible,
	default_priority = 5,
	spawn_commands = function () return {} end,
}

for _, command in pairs(high_level_commands) do
	setmetatable(command, {__index = defaults})
end
