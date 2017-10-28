
-- luacheck: globals command_list_parser Utils high_level_commands LogUI Event TAScommands
-- luacheck: ignore 212


Blueprint = require("blueprint") 
local MvRec = require("record_movement")

BPStorage = nil
pcall( function() BPStorage = require("scenarios." .. global.system.tas_name .. ".BPStorage") end )


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


action_types = {always_possible = 1, selection = 2, ui = 3, throw = 4}
entities_with_inventory = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler", "lab", "rocket-silo"}


HLC = {} -- luacheck: allow defined top
HLC_Utils = {} -- luacheck: allow defined top

function HLC.call(hook, command)
	high_level_commands[command[1]][hook]()
end

function HLC_Utils.return_phantom ()
	return {"phantom"}
end

function HLC_Utils.empty()
end

function HLC_Utils.strip_command(command)
	if command[6] then error("Command " .. command[1] .. " has more arguments than expected: !") end
	return {command[1], command[2], command[3], command[4], command[5], already_executed = command.already_executed}
end

function HLC_Utils.return_self_finished(command, myplayer, tick)
	command_list_parser.set_finished(command)
	return HLC_Utils.strip_command(command)
end

function HLC_Utils.set_finished(command)
	command_list_parser.set_finished(command)
end


high_level_commands = {
	["auto-refuel"] = {
		type_signature = {
			target = {"nil", "number"},
			min = {"nil", "number"},
			skip_coal_drills = "boolean",
			type = {"nil", "string"},
			pos = {"nil", "position", "entity-position"}
		},
		execute = HLC_Utils.empty,
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
					LogUI.errprint("Auto-take was not optimal: there were more resources in the entities than needed.")
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
		execute = HLC_Utils.empty,
	},

	["craft-build"] = {
		type_signature = {
			[2] = "string",
			[3] = {"position", "entity-position"},
			[4] = {"nil", "number"},
		},
		default_priority = 100,
		execute = HLC_Utils.empty,
		spawn_commands = function (command, myplayer, tick)
			if not command.data.spawned then
				local x, y = Utils.get_coordinates(command[3])
				local name = "craftbuild_build_{" .. x .. ", " .. y .. "}"
				command.data.build_command = {"build", command[2], command[3], command[4], name=name}
				command.data.spawned = true

				return {{"craft", command[2], 1}, command.data.build_command}
			else
				if not command.data.build_command or command.data.build_command.finished then
					command_list_parser.set_finished(command)
				end
				return
			end
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
	

	["entity-interaction"] = {
		type_signature = {
			[2] = {"position", "entity-position"},
		},
		execute = HLC_Utils.empty,
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


	["passive-take"] = {
		type_signature = {
			[2] = "string",
			[3] = "string",
		},
		execute = HLC_Utils.empty,
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


	["enter-vehicle"] = {
		type_signature = {}
	},
	["leave-vehicle"] = {
		type_signature = {}
	},
}


local external_commands = {
	"move_cmd",
	"auto-build-blueprint_cmd",
	"system_cmds",
	"basic_cmds",
}
for _, filename in pairs(external_commands) do
	local cmds = require("high_level_commands." .. filename)
	for k, v in pairs(cmds) do
		high_level_commands[k] = v
	end
end

local defaults = {
	type_signature = nil,
	execute = HLC_Utils.return_self_finished,
	executable = function () return "" end,
	initialize = HLC_Utils.empty,
	default_action_type = action_types.always_possible,
	default_priority = 5,
	spawn_commands = function () return {} end,
}

for _, command in pairs(high_level_commands) do
	if command.type_signature then
		setmetatable(command.type_signature, {__index = command_list_parser.generic_cmd_signature})
	end
	if not getmetatable(command) then
		setmetatable(command, {__index = defaults})
	end
end

return high_level_commands