local Blueprint = require("blueprint")
local TAScommands = require("commands")
local Utils = require("utility_functions")
local MvRec = require("record_movement")
local Event = require("stdlib/event/event")
local BPStorage
pcall( function() BPStorage = require("scenarios." .. global.system.tas_name .. ".BPStorage") end )

-- luacheck: ignore 212

global.high_level_commands = global.high_level_commands or {
	throw_cooldown = nil,
	simple_sequence_index = 1,
	move_sequence_index = 1,
	command_requests = {},
}

if global.MvRec and global.MvRec.initialized then
	Event.register("stop-recording", function(event)
		MvRec.stop_record(event.player_index)
		for _, cmd in pairs(global.command_list_parser.current_command_set) do
			if cmd[1] == "drive-recorded" then
				command_list_parser.set_finished(cmd)
			end
		end
	end)
	Event.register("save-recording", function(event)
		local name
		for _, cmd in pairs(global.command_list_parser.current_command_set) do
			if cmd[1] == "drive-recorded" then
				name = "Drive_" .. cmd[2]
			end
		end
		MvRec.write_data(event.player_index, global.system.tas_name .. "/" .. name)
	end)

	Event.register(MvRec.on_replaying_finished, function(event)
		local record_task = event.record_task
		if record_task.recording then
			game.speed = 0.01
			game.show_message_dialong{text = "Recording Car Movements for " .. record_task.name .. " now!"}
		end
	end)
end
			
local function empty()
end

local function strip_command(command)
	if command[6] then error("Command " .. command[1] .. " has more arguments than expected: !") end
	return {command[1], command[2], command[3], command[4], command[5], already_executed = command.already_executed}
end

local function return_self_finished(command, myplayer, tick)
	command_list_parser.set_finished(command)
	return strip_command(command)
end

local function set_finished(command)
	command_list_parser.set_finished(command)
end

local function return_phantom ()
	return {"phantom"}
end



-- Blueprint Order Record
local function record_bp_order_entity(event)
	if not global.high_level_commands.bp_order_record then return end
	local bp_data = global.high_level_commands.bp_order_record.blueprint_data
	local record = global.high_level_commands.bp_order_record
	local record_data = global.high_level_commands.bp_order_record.record
	local player = game.players[event.player_index]
	local entity = player.selected
	
	if not entity or entity.type ~= "entity-ghost" then 
		game.print("No entity selected!")
		return 
	end
	
	local bp_entity = Utils.Chunked.get_entry_at(bp_data.chunked_entities, bp_data.chunk_size, entity.position)

	local x, y = Utils.get_coordinates(entity.position)
	record_data[Utils.roundn(x, 1) .. "_" .. Utils.roundn(y, 1)] = record.stage_index
	if not global.high_level_commands.bp_order_record.current_group then global.high_level_commands.bp_order_record.current_group = {} end
	table.insert(global.high_level_commands.bp_order_record.current_group, bp_entity)

	bp_entity.build_command.disabled = false
	
	Utils.display_floating_text(entity.position, Utils.printable(record.stage_index), true)
	
	entity.destroy()
end

local function record_bp_order_group(event)
	if not global.high_level_commands.bp_order_record then return end
	local record = global.high_level_commands.bp_order_record
	local record_data = global.high_level_commands.bp_order_record.record
	
	if #global.high_level_commands.bp_order_record.current_group == 0 then
		record_data.default_stage = record.stage_index
		game.print("Blueprint record: Stage " .. record.stage_index .. " declared as default.")
	else
		game.print("Blueprint record: Stage " .. record.stage_index .. ": " .. #record.current_group .. " entities saved.")
	end

	record.stage_index = record.stage_index + 1
	
	record.current_group = {}
end

local function record_bp_order_save(event)
	local record_data = global.high_level_commands.bp_order_record
	if not record_data or not record_data.stage_index or record_data.stage_index < 2 then 
		game.print("Attempting to save Blueprint build order while nothing is recorded!") 
		return
	end
	local filename = "Blueprints/" .. global.high_level_commands.bp_order_record.blueprint_data.name
	if record_data.command_name then 
		filename = filename .. "_" .. record_data.command_name .. "-build_order"
	else
		filename = filename .. "-build_order"	
	end

	local data = "return " .. serpent.block(global.high_level_commands.bp_order_record.record)

	game.print("Writing build order to file " .. filename .. ".lua")
	game.write_file(filename .. ".lua", data, true)

	global.high_level_commands.bp_order_record = nil
end

local function record_bp_area_trigger(event)
	if not global.high_level_commands.bp_order_record then return end
	local bp_data = global.high_level_commands.bp_order_record.blueprint_data
	local record = global.high_level_commands.bp_order_record
	local record_data = global.high_level_commands.bp_order_record.record
	local player = game.players[event.player_index]
	local entity = player.selected
	
	if not entity or entity.type ~= "entity-ghost" then 
		game.print("No entity selected!")
		return
	end
	
	local bp_entity = Utils.Chunked.get_entry_at(bp_data.chunked_entities, bp_data.chunk_size, entity.position)
	
	if not record_data.areas then record_data.areas = {} end
	
	local rect = Utils.copy(game.entity_prototypes[entity.ghost_name].collision_box)
	rect = Utils.rotate_rect(rect, Utils.rotation_stringtoint(entity.direction))
	rect = {Utils.translate(rect[1], entity.position), Utils.translate(rect[2], entity.position)}
	
	record_data.areas[record.stage_index] = rect
	
	Utils.display_floating_text({entity.position.x, entity.position.y + 0.4}, "Stage " .. Utils.printable(record.stage_index) .. " area trigger", true)
end

Event.register("bp_order_entity", record_bp_order_entity)
Event.register("bp_order_group", record_bp_order_group)
Event.register("bp_order_save", record_bp_order_save)
Event.register("bp_area_trigger", record_bp_area_trigger)



action_types = {always_possible = 1, selection = 2, ui = 3, throw = 4}
local entities_with_inventory = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler", "lab", "rocket-silo"}






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
			command_list_parser.set_finished(command)
		end
	},
	["auto-build-blueprint"] = {
		type_signature =
		{
			[2] = "string",
			[3] = {"nil", "position"},
			area = {"nil", "table"},
			rotation = {"nil", "number"},
			set_on_leaving_range = "boolean",
			show_ghosts = "boolean",
			record_order = "boolean",

		},
		default_priority = 100,

		execute = empty,

		executable = function (command)
			return ""
		end,

		spawn_commands = function (command, myplayer, tick)
			local blueprint = command.data.blueprint_data
			local added_commands = {}
			command.data.all_commands = command.data.all_commands or {}

			if not command.data.commands_spawned then
				command.data.commands_spawned = true
				
				if command.record_order then
					table.insert(added_commands, {"enable-manual-walking"})
					
					LogUI.log_to_ui("Press K to mark an entity hitbox as trigger for the group.", "run-output")
					LogUI.log_to_ui("Press Ctrl+J to save the order and write it to a file.", "run-output")
					LogUI.log_to_ui("Press Shift+J to start a new group of buildings.", "run-output")
					LogUI.log_to_ui("Press J to mark a building for construction.", "run-output")
					LogUI.log_to_ui("Blueprint order recording started!", "run-output")

					if global.high_level_commands.bp_order_record then
						error("Attempting to record a two blueprint orders simultaneously!")
					end
					
					global.high_level_commands.bp_order_record = {
						command_name = command.name,
						blueprint_data = blueprint,
						current_group = {},
						stage_index = 1,
						record = {}
					}
				end

				local commands_by_type = {}
				for _, cmd in pairs(global.command_list_parser.current_command_set) do
					if cmd[1] == "build" then
						commands_by_type[cmd[2]] = commands_by_type[cmd[2]] or {}
						table.insert(commands_by_type[cmd[2]], cmd)
					end
				end

				for _, l in pairs(command.data.blueprint_data.chunked_entities) do
					for _, entity in pairs(l) do
						local command_already_spawned = false
						for _, cmd in pairs(commands_by_type[entity.name] or {}) do
							if Utils.sqdistance(cmd[3], entity.position) < 0.01 then
								command_already_spawned = true
								break
							end
						end

						local x, y = Utils.get_coordinates(entity.position)
						local entity_built = myplayer.surface.find_entities_filtered{name=entity.name, area={{x-0.1, y-0.1}, {x+0.1, y+0.1}}}[1]
						-- TODO: allow name parameter in Utils.get_entity_from_pos
						if not command_already_spawned and not entity_built then
							local build_command = {
								"build",
								entity.name,
								entity.position,
								entity.direction,
								name = "bp_{" .. entity.position[1] .. ", " .. entity.position[2] .. "}",
								on_leaving_range = command.set_on_leaving_range,
								namespace = command.namespace,
								disabled = true,
							}
							if entity.name == "underground-belt" then
								build_command[5] = entity.type
							end
							
							local stage_index
							
							if blueprint.build_order then
								stage_index = blueprint.build_order[Utils.roundn(x, 1) .. "_" .. Utils.roundn(y, 1)] or command.data.default_stage
							else
								stage_index = 1
							end
							
							if stage_index then
								if not command.data.ordered_build_commands[stage_index] then
									command.data.ordered_build_commands[stage_index] = {}
								end
								entity.stage = stage_index
								table.insert(command.data.ordered_build_commands[stage_index], build_command)	
								table.insert(added_commands, build_command)
								
								entity.build_command = build_command
							end
						else
							command.data.added_all_entities = not Utils.Chunked.remove_entry(blueprint.chunked_entities, blueprint.chunk_size, entity)							
						end
					end
				end
			end
			
			local stage_finished = true
			
			if command.data.current_stage == 0 then
				stage_finished = true
			else
				if command.data.ordered_build_commands[command.data.current_stage] then
					for i, com in pairs(command.data.ordered_build_commands[command.data.current_stage]) do
						if com.finished then
							command.data.ordered_build_commands[command.data.current_stage][i] = nil
						else
							stage_finished = false
						end
					end
				end
			end
			
			if stage_finished then
				if not blueprint.build_order or not blueprint.build_order.areas or not blueprint.build_order.areas[command.data.current_stage + 1]
					or Utils.inside_rect(myplayer.position, blueprint.build_order.areas[command.data.current_stage + 1]) then
					command.data.current_stage = command.data.current_stage + 1
				end
			end
			
			local entities = Blueprint.get_entities_in_build_range(blueprint, myplayer)
			for _, entity in pairs(entities) do
				if entity.build_command and entity.stage <= command.data.current_stage and not command.record_order then
					entity.build_command.disabled = false
				end
			end

			-- This is for compatibility between move-to-command and build-blueprint.
			for index, request in pairs(global.high_level_commands.command_requests) do
				local name = request[1]
				local move_to_namespace = request[2]
				local _, _, namespace, data = string.find(name, "(.*%.)bp_(.*)")
				if not data then _, _, data = string.find(name, "bp_(.*)") end
				if data and (not namespace or namespace == command.namespace or namespace == move_to_namespace) then
					local position = Utils.string_to_position(data)
					local entity = Utils.Chunked.get_entry_at(blueprint.chunked_entities, blueprint.chunk_size, position)
					if entity then
						entity.build_command.disabled = false
						table.remove(global.high_level_commands.command_requests, index)
					end
				end
			end

			for _, entity in pairs(entities) do
				if not entity.build_command or entity.build_command.finished and not entity.recipe then
					command.data.added_all_entities = not Utils.Chunked.remove_entry(blueprint.chunked_entities, blueprint.chunk_size, entity)
				elseif entity.recipe and not entity.set_recipe and entity.build_command and entity.build_command.finished then
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
					command.data.added_all_entities = not Utils.Chunked.remove_entry(blueprint.chunked_entities, blueprint.chunk_size, entity)
				end
			end
			
			if not command.data.ordered_build_commands[command.data.current_stage] then
				local finished = true
				
				if command.data.ordered_build_commands[0] then
					for i, com in pairs(command.data.ordered_build_commands[0]) do
						if com.finished then
							command.data.ordered_build_commands[0][i] = nil
						else
							finished = false
						end
					end
				end
				
				if finished then
					command_list_parser.set_finished(command)
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
			
			if not command.record_order then
				command.data.blueprint_data.build_order = BPStorage.get_build_order(command)
			
				if command.data.blueprint_data.build_order then
					command.data.default_stage = command.data.blueprint_data.build_order.default_stage
				end
			end
			
			command.data.ordered_build_commands = {}
			command.data.current_stage = 0
			
			command.data.area = area

			if command.show_ghosts or command.record_order then
				local chest = myplayer.surface.create_entity{name="iron-chest", position={0,0}, force="player"}
				local inv = chest.get_inventory(defines.inventory.chest)
				inv.insert{name="blueprint", count=1}
				local bp = inv[1]
				local bp_data = Blueprint.get_raw_data(name)
				local x, y = Utils.get_coordinates(offset)
				if command.data.area then
					local entities = {}
					for _, ent in pairs(bp_data.entities) do
						if Utils.inside_rect({ent.position.x + x - bp_data.anchor.x + 0.5, ent.position.y + y - bp_data.anchor.y + 0.5}, command.data.area) then
							entities[#entities + 1] = ent
						end
					end
					bp.set_blueprint_entities(entities)
				else
					bp.set_blueprint_entities(bp_data.entities)
				end
				local off = {x - bp_data.anchor.x + 0.5, y - bp_data.anchor.y + 0.5}
				bp.build_blueprint{surface=myplayer.surface, force=myplayer.force, position=off, force_build=true, direction=rotation}
				chest.destroy()
			end
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
			local new_commands = {}
			local priority = 5
			
			if #global.command_list_parser.entities_with_burner > command.data.cached_amount then
				local entity = global.command_list_parser.entities_with_burner[command.data.cached_amount + 1]
				
				while entity do
					if not (command.skip_coal_drills and entity.type == "mining-drill" and entity.mining_target and entity.mining_target.name == "coal") then
						if ((not command.type) or entity.type == command.type) and ((not command.pos) or (entity.position.x == command.pos[1] and entity.position.y == command.pos[2])) then
							Utils.Chunked.create_entry(command.data.entity_cache, 9, entity.position, {entity, Utils.collision_box(entity)})
						end
					end
					command.data.cached_amount = command.data.cached_amount + 1
					entity = global.command_list_parser.entities_with_burner[command.data.cached_amount + 1]
				end
			end

			for i, entry in pairs(Utils.Chunked.get_entries_close(command.data.entity_cache, 9, myplayer.position)) do
				local entity = entry[1]
				local collision_box = entry[2]
				local next_tick = entry.autorefuel_next_tick
				if not next_tick or tick >= next_tick then 
					if not entity.valid then
						game.print("Invalid entity in auto-refuel! This may occur if you mine a fuelable entity.")
					else
						if entity.type == "mining-drill" then
							priority = 4
						end

						local energy_usages = {
							boiler = 30000,
							["burner-mining-drill"] = 5000,
							["stone-furnace"] = 3000,
							["steel-furnace"] = 6000,
						}
						local energy_usage = energy_usages[entity.name]
						local remaining_burning_fuel = entity.burner.remaining_burning_fuel
						local coal_count = entity.burner.inventory.get_item_count("coal")
						
						if entry.refuel_command and entry.refuel_command.finished then
							entry.refuel_command = nil
						end
						
						if not entry.refuel_command then
							if Utils.distance_from_rect(myplayer.position, collision_box) <= myplayer.reach_distance then
								local cmd
							
								if command.min then
									if coal_count < command.min then
										cmd = {"put", {entity.position.x, entity.position.y}, "coal", command.data.target_fuel - entity.burner.inventory.get_item_count("coal"), priority=priority}
									end
								else
									if remaining_burning_fuel < 20000 and coal_count == 0 then
										cmd = {"put", {entity.position.x, entity.position.y}, "coal", command.data.target_fuel, priority=priority}
									end
								end
							
								if cmd then
									entry.refuel_command = cmd
									table.insert(new_commands, cmd)
								end
							end
						end

						local delta_tick
						if command.min then coal_count = coal_count - command.min end
						
						if coal_count > 0 then
							delta_tick = 8000000 / energy_usage / 2
						elseif coal_count == 0 and remaining_burning_fuel >= 20000 then
							delta_tick = (remaining_burning_fuel - 20000) / energy_usage / 2
						end
						
						if delta_tick then
							entry.autorefuel_next_tick = tick + math.min(delta_tick)
						else
							entry.autorefuel_next_tick = nil
						end
					end
				end
			end

			return new_commands
		end,
		default_priority = 100,
		initialize = function (command, myplayer, tick)
			command.data.entity_cache = {}
			command.data.cached_amount = 0
			
			command.data.target_fuel = command.target or command.min or 1
		end
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
				if (Utils.in_range({rect = Utils.collision_box(entity), distance = myplayer.build_distance}, myplayer) and Utils.get_recipe_name(entity) == item) then
					table.insert(entities, entity)
				end
			end
			for _, entity in pairs(myplayer.surface.find_entities_filtered{area=area, type="furnace"}) do
				if (Utils.in_range({rect = Utils.collision_box(entity), distance = myplayer.build_distance}, myplayer) and Utils.get_recipe_name(entity) == item) then
					table.insert(entities, entity)
				end
			end


			local count_to_craft = count
			for _, entity in pairs(entities) do
				count_to_craft = count_to_craft - entity.get_item_count(item)
			end

			if #entities == 0 then
				command.data.next_tick = tick + 60
				return
			end

			local recipe_prototype = game.recipe_prototypes[Utils.get_recipe_name(entities[1])]
			

			local count_crafts_all = math.floor(count_to_craft / #entities)
			local remaining = count_to_craft % #entities

			local ret = {}
			if count_crafts_all <= 0 then
				if count_crafts_all < 0 then
					Utils.errprint("Auto-take was not optimal: there were more resources in the entities than needed.")
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
				command_list_parser.set_finished(command)
			end

			local ticks = (count_crafts_all - 1) * recipe_prototype.energy * 60
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
			[5] = {"nil", "string"},
		},
		execute = function(command, myplayer)
			if myplayer.get_item_count(command[2]) ~= 0 then
				TAScommands["build"](command, myplayer)
				command_list_parser.set_finished(command)
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

			if not Utils.in_range(command, myplayer, tick) then
				return "Player not in range (" .. command[2] .. ")"
			end
			
			local entity = {name=command[2], position=command[3], direction=command[4] or 0}
			if not Utils.can_player_place(myplayer.surface, entity, myplayer) then
				return "Something is in the way at " .. serpent.block(command[3]) .. " for " .. command[2] .. "."
			end
			
			return ""
		end,
		default_priority = 5,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
			command.rect = Utils.collision_box{name=command[2], position=Utils.copy(command[3])}
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

			while Utils.can_craft(craft, myplayer, craft.need_intermediates) do
				local cmd = {"craft", craft.name, 1, already_executed = true}
				TAScommands["craft"](cmd, myplayer)
				table.insert(return_commands, cmd)

				craft.count = craft.count - 1
				if craft.count == 0 then
					command.data.craft_index = command.data.craft_index + 1
					craft = command.data.crafts[command.data.craft_index]
				end

				if not craft then
					command_list_parser.set_finished(command)
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

			if not Utils.can_craft(craft, myplayer, craft.need_intermediates) then
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
				Utils.errprint("Craft: Wrong parameter type")
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
					command_list_parser.set_finished(command)
				end

				return "craft-build is never executable"
			end

			return ""
		end,
		spawn_commands = function (command, myplayer, tick)
			local x, y = Utils.get_coordinates(command[3])
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
			Utils.errprint(command[2])
			command_list_parser.set_finished(command)
		end,
	},
	
	["display-contents"] = {
		type_signature = {
			[2] = "string",
			["inventory_type"] = {"number", "nil"},
			["update_frequency"] = {"number", "nil"},
			["verbose"] = {"boolean", "nil"},
		},
		default_priority = 100,
		execute = function(command, myplayer, tick)
			if tick % command.data.update_frequency ~= 0 then
				return
			end
			
			local entity = global.command_list_parser.entities_by_type[command.data.type][command.data.cached_entities + 1]
			
			while entity do
				command.data.cached_entities = command.data.cached_entities + 1
				
				if entity.valid and entity.get_inventory(command.data.inventory) then
					table.insert(command.data.entity_info, {entity, Utils.display_floating_text(entity, "", true)})
				end
				
				entity = global.command_list_parser.entities_by_type[command.data.type][command.data.cached_entities + 1]
			end
			
			for _, entry in pairs(command.data.entity_info) do
				local inventory = entry[1].get_inventory(command.data.inventory)
				local new_text = ""
				
				if command.verbose then
					for item, count in pairs(inventory.get_contents()) do
						new_text = new_text .. item .. ": " .. Utils.printable(count) .. ", "
					end
				else
					new_text = Utils.printable(inventory.get_item_count())
				end
				
				Utils.update_floating_text(entry[2], new_text)
			end
		end,
		initialize = function(command, myplayer, tick)
			command.data.type = command[2]
			
			if command.inventory_type then
				command.data.inventory = command.inventory_type
			else
				if command.data.type == "assembling-machine" then
					command.data.inventory = defines.inventory.assembling_machine_output
				elseif command.data.type == "furnace" then
					command.data.inventory = defines.inventory.furnace_result
				elseif command.data.type == "container" then
					command.data.inventory = defines.inventory.chest
				elseif command.data.type == "lab" then
					command.data.inventory = defines.inventory.lab_input
				else
					error("Cannot guess inventory_type!")
				end
			end
			
			command.data.update_frequency = command.update_frequency or 10
			
			command.data.entity_info = {}
			command.data.cached_entities = 0
		end,
	},

	["drive-recorded"] = {
		type_signature = {
			[2] = "string",
			["recording"] = "boolean",
		},
		initialize = function(command, myplayer, tick)
		end,
		execute = function(command, myplayer, tick)
			if not command.data.record_task then
				command.data.record_task = {
					name = command[2],
					player = myplayer,
					drive = true,
					replay = true,
					record = command.recording,
				}
				MvRec.start_record(command.data.record_task)			
			end
		end,
	},
	
	["enable-manual-walking"] = {
		type_signature = {},
		execute = return_self_finished,
	},

	["entity-interaction"] = {
		type_signature = {
			[2] = "position",
		},
		execute = empty,
		executable = function (command, myplayer)
			if not command.data.entity then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, entities_with_inventory)

				if not command.data.entity then
					return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
				end
			end

			if not command.data.entity.valid then
				command.data.entity = nil
				return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
			end

			if not command.rect then
				command.rect = Utils.collision_box(command.data.entity)
				command.distance = myplayer.reach_distance
			end

			if Utils.in_range(command, myplayer) then
				command_list_parser.set_finished(command)
				
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
			[3]  = {"nil", "string"},
			amount = {"nil", "number"},
		},
		execute = strip_command,

		executable = function(command, myplayer, tick)
			if not Utils.in_range(command, myplayer) then
				return "Out of range"
			end

			if global.command_list_parser.current_mining >= command.data.amount then
				command_list_parser.set_finished(command)
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

			local entity = Utils.get_entity_from_pos(position, myplayer, type)

			command.distance = myplayer.resource_reach_distance

			if entity then
				command.rect = Utils.collision_box(entity)
				command[2] = {entity.position.x, entity.position.y}
			else
				Utils.errprint("There is no mineable thing at (" .. serpent.block(position) .. ")")
				command.rect = {Utils.copy(position), Utils.copy(position)}
			end
		end,
		default_action_type = action_types.selection,
	},

	move = {
		type_signature = {
			[2] = {"string", "position"},
		},
		execute = function (command, myplayer, tick)
			if (command.data.move_to_command and Utils.in_range(command.data.target_command, myplayer)) or (command.data.move_to_entity and Utils.in_range(command, myplayer)) then
				command_list_parser.set_finished(command)
				return {"phantom"}
			end

			if command.data.move_dir == "" then
				if (command[1] == "move" and not command.data.move_to_command) or command.data.move_to_entity then
					command_list_parser.set_finished(command)
					return {"phantom"}
				else
					command.data.move_dir = command.data.last_dir
				end
			end

			if not command.data.move_started then
				Utils.debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
				command.data.move_started = true
			end

			command.data.last_dir = command.data.move_dir

			return {"move", command.data.move_dir}
		end,
		executable = function(command, myplayer, tick)
			if command.data.move_to_entity then
				if not command.data.target_entity then
					command.data.target_entity = Utils.get_entity_from_pos(command[2], myplayer)
					if not command.data.target_entity then
						return "No entity at " .. serpent.block(command.position) .. "."
					else
						command.rect = Utils.collision_box(command.data.target_entity)
					end
				end
			elseif command.data.move_to_command then
				if not command.parent_namespace then
					command.parent_namespace = ""
				end
				
				if not command.data.target_command then
					for _, com in pairs(global.command_list_parser.current_command_set) do
						if com.name and Utils.has_value({command.parent_namespace .. command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
							command.data.target_command = com
						end
					end
				end

				if not command.data.target_command then
					Utils.errprint("move: There is no command named: " .. command[2])
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
						command.data.target_pos = Utils.closest_point(command.data.target_command.rect, command.data.target_command.distance, myplayer.position)
					elseif command.data.move_to_entity then
						command.data.target_pos = Utils.closest_point(command.rect, command.distance, myplayer.position)
					else
						command.data.target_pos = command[2]
					end
				else
					command.data.target_pos = Utils.closest_point(command.rect, command.distance, myplayer.position)
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
					if com.name and Utils.has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
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
		executable = function(command, myplayer, tick)
			if command.data.all_commands then
				local finished = true
				local cmd = command.data.all_commands[1]
				while cmd do
					if cmd.finished then 
						table.remove(command.data.all_commands, 1) 
					else
						finished = false
						break
					end
					cmd = command.data.all_commands[1]
				end
				
				if finished then
					command_list_parser.set_finished(command)
					return "finished"
				else
					return "Waiting for all commands to finish."
				end
			else
				return ""
			end
		end,
		initialize = empty,
		spawn_commands = function(command, myplayer, tick)
			local commands = {}
			command.data.all_commands = {}
			
			local i = 1
			if global.high_level_commands.parallel_name == command.data.parent_command_group.name then
				global.high_level_commands.parallel_index = global.high_level_commands.parallel_index + 1
			else
				global.high_level_commands.parallel_index = 1
				global.high_level_commands.parallel_name = command.data.parent_command_group.name
			end
			for index, _cmd in ipairs(command[2]) do
				local cmd = Utils.copy(_cmd)
				
				if not cmd.name then
					i = i + 1
					cmd.name = i
				end
				
				if command.name then
					cmd.namespace = command.namespace .. command.name .. "."
				else
					cmd.namespace = command.namespace .. "parallel-" .. global.high_level_commands.parallel_index .. "."
				end
				table.insert(commands, cmd)
				table.insert(command.data.all_commands, cmd)
			end
			
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
			
			if #global.command_list_parser.entities_by_type[command[3]] > command.data.cached_amount then
				local entity = global.command_list_parser.entities_by_type[command[3]][command.data.cached_amount + 1]
				
				while entity and entity.valid do
					Utils.Chunked.create_entry(command.data.entity_cache, 9, entity.position, {entity=entity, take_spawned = nil})
					command.data.cached_amount = command.data.cached_amount + 1
					entity = global.command_list_parser.entities_by_type[command[3]][command.data.cached_amount + 1]
				end
			end

			for i,entry in pairs(Utils.Chunked.get_entries_close(command.data.entity_cache, 9, myplayer.position)) do
				if entry.entity.valid then
					if entry.take_spawned then
						if entry.entity.type == "assembling-machine" and entry.entity.recipe and entry.entity.recipe.name ~= entry.take_spawned[3] then
							command_list_parser.set_finished(entry.take_spawned)
						end
						
						if entry.take_spawned.finished then
							entry.take_spawned = nil
						end
					end
					if (not entry.take_spawned) and entry.entity.get_item_count(command[2]) > 0 then
						local cmd = {"take", {entry.entity.position.x, entry.entity.position.y}, command[2], data={}, namespace=command.namespace}
						
						if high_level_commands["take"].executable(cmd, myplayer, tick) == "" then
							entry.take_spawned = cmd
							table.insert(command.data.spawn_queue, cmd)
						end
					end
				else
					-- TODO: this line makes passive-take incompatible with fast-replacing buildings, maybe there is a good way to do this
					--Utils.Chunked.remove_entry(command.data.entity_cache, 9, entry)
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
			command.data.entity_cache = {}
			command.data.cached_amount = 0
		end,
		default_priority = 100,
	},

	pickup = {
		type_signature = {
			oneshot = {"nil", "boolean"},
			ticks = {"nil", "number"},
		},
		execute = function (command, myplayer, tick)
			if command.ticks then
				if command.data.final then
					if tick >= command.data.final then
						command_list_parser.set_finished(command)
					end
				else
					command.data.final = tick + command.ticks
				end
			elseif command.oneshot then
				command_list_parser.set_finished(command)
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
			command_list_parser.set_finished(command)
			
			return {command[1], command[2], command[3], command.data.count, command.data.inventory}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity or not command.data.entity.valid then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, entities_with_inventory)
				if not command.data.entity then
					return "No valid entity found!"
				else
					if not command.rect then
						command.rect = Utils.collision_box(command.data.entity)
						command.distance = myplayer.reach_distance
					end
				end
			end

			local item = command[3]

			if not command[4] then
				command.data.count = math.min(myplayer.get_item_count(item), game.item_prototypes[item].stack_size)
			end
			
			if myplayer.get_item_count(item) < command.data.count then
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

			if not Utils.in_range(command, myplayer, tick) then
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
			if not command.data.entity or not command.data.entity.valid then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, "assembling-machine", 0.5)
			end

			if command.data.entity and command.data.entity.valid then
				command.rect = Utils.collision_box(command.data.entity)
			else
				return "Entity not built"
			end

			if Utils.in_range(command, myplayer, tick) then
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
		executable = function (command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer)
			end

			if command.data.entity and command.data.entity.valid then
				command.rect = Utils.collision_box(command.data.entity)
			else
				return "Entity not built"
			end

			if Utils.in_range(command, myplayer, tick) then
				return ""
			else
				return "Player not in range"
			end
		end,
		default_priority = 5,
		default_action_type = action_types.selection,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
		end,
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
				Utils.errprint("Attempting to stop command that is already finished: " .. command[2])
				command_list_parser.set_finished(command)
				return
			end
			for _, com in pairs(global.command_list_parser.current_command_set) do
				if com.name and Utils.has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
					com.finished = true
					command_list_parser.set_finished(command)
					if com[1] == "mine" then
						global.command_list_parser.current_mining = 0
					end

					return
				end
			end

			Utils.errprint("No command with the name " .. command[2] .. " found!")
		end,
	},

	take = {
		type_signature = {
			[2] = "position",
			[3] = {"nil", "string"},
			[4] = {"nil", "number"},
			inventory = {"nil", "number"},
			type = {"nil", "string"},
		},
		execute = function(command, myplayer, tick)
			command_list_parser.set_finished(command)
			
			return {command[1], command[2], command.data.item, command.data.amount, command.data.inventory, action_type = command.action_type}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				if command.type then
					command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, command.type)
				else
					command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, entities_with_inventory)
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
				command.rect = Utils.collision_box(command.data.entity)
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
						Utils.errprint("No inventory given and automatically determining the inventory failed! Entity type: " .. command.data.entity.type)
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
						local x, y = Utils.get_coordinates(command[2])
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

			if not Utils.in_range(command, myplayer) then
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
			command_list_parser.set_finished(command)
			global.high_level_commands.throw_cooldown = game.tick
			return strip_command(command)
		end,
		default_action_type = action_types.throw,
		executable = function (command, myplayer, tick)
			if myplayer.get_item_count("grenade") < 1 then
				return "Need more grenades!"
			end
			if Utils.sqdistance(myplayer.position, command[2]) > 15^2 then
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
			[3] = {"table", "string"},
			[4] = {"table", "string", "nil"},
			pass_arguments = {"nil", "table"},
			table_arg = {"nil", "boolean"},
		},
		initialize = function(command, myplayer, tick)
			if global.high_level_commands.simple_sequence_name == command.data.parent_command_group.name then
				global.high_level_commands.simple_sequence_index = global.high_level_commands.simple_sequence_index + 1
			else
				global.high_level_commands.simple_sequence_index = 1
				global.high_level_commands.simple_sequence_name = command.data.parent_command_group.name
			end

			command.data.index = 0
			if command.name then
				command.data.namespace = command.namespace .. command.name .. "."
			else
				command.data.namespace = command.namespace .. command[2] .. "-sequence-" .. global.high_level_commands.simple_sequence_index .. "."
			end
		end,
		execute = empty,
		spawn_commands = function(command, myplayer, tick)
			command.data.index = command.data.index + 1
			if command.data.index + 2 > #command then
				command_list_parser.set_finished(command)
			else
				local cmd_arg
				
				if command.table_arg then
					cmd_arg = command[3][command.data.index]
				else
					cmd_arg = command[command.data.index + 2]
				end
				
				local cmd = {
					command[2],
					cmd_arg,
					name= "command-" .. command.data.index,
					namespace=command.data.namespace,
					parent_namespace=command.namespace,
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
			if command[2][command.data.index] == nil then
				command_list_parser.set_finished(command)
			else
				local cmd = Utils.copy(command[2][command.data.index])
				for k, v in pairs(command.pass_arguments or {}) do
					cmd[k] = v
				end
			
				cmd.name = "command-" .. command.data.index
				cmd.namespace = command.data.namespace

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
	},
	["enter-vehicle"] = {
		type_signature = {}
	},
	["leave-vehicle"] = {
		type_signature = {}
	},
}


local defaults = {
	type_signature = nil,
	execute = return_self_finished,
	executable = function () return "" end,
	initialize = empty,
	default_action_type = action_types.always_possible,
	default_priority = 5,
	spawn_commands = function () return {} end,
}

for _, command in pairs(high_level_commands) do
	if command.type_signature then
		setmetatable(command.type_signature, {__index = command_list_parser.generic_cmd_signature})
	end
	setmetatable(command, {__index = defaults})
end

return high_level_commands