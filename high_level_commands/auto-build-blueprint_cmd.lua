-- auto-build-blueprint

-- luacheck: globals command_list_parser Utils high_level_commands LogUI Event TAScommands HLC_Utils GuiEvent
-- luacheck: ignore 212

local Blueprint = require("blueprint") 
local BPUI = require("gui.bp_order_ui")
-- local BPStorage = nil 
-- pcall( function() BPStorage = require("scenarios." .. global.system.tas_name .. ".BPStorage") end )

local function blueprint_name(command)
	return command[2]
end

local function blueprint_build_order_name(command)
	local filename = command[2]
	if command.area then 
		local function convert(n)
			return string.gsub(Utils.printable(Utils.roundn(n, 1)), "%.", ",")
		end
		
		filename = filename .. "_(" .. convert(command.area[1][1]) .. "_" .. convert(command.area[1][2]) .. ")_(" .. convert(command.area[2][1]) .. "_" .. convert(command.area[2][2]) .. ")"
	end
	
	return filename .. "_build_order"
end


-- Blueprint Order Record
local function record_bp_order_entity(event)
	if not global.high_level_commands.bp_order_record then return end
	local bp_data = global.high_level_commands.bp_order_record.blueprint_data
	local record = global.high_level_commands.bp_order_record
	local output_data = global.high_level_commands.bp_order_record.output_data
	local player = game.players[event.player_index]
	local entity = player.selected
	
	if not entity or entity.type ~= "entity-ghost" then 
		game.print("Add: No entity selected!")
		return 
	end
	
    local bp_entity = Utils.Chunked.get_entry_at(bp_data.chunked_entities, bp_data.chunk_size, entity.position)
    if not bp_entity then
        game.print("Add: Entity not part of current blueprint!")
        return
    end

	local x, y = Utils.get_coordinates(entity.position)
    output_data[Utils.roundn(x, 1) .. "_" .. Utils.roundn(y, 1)] = record.stage_index
    if not record.stage_lengths[record.stage_index] then 
        record.stage_lengths[record.stage_index] = 1 
    else
        record.stage_lengths[record.stage_index] = record.stage_lengths[record.stage_index] + 1
    end

	bp_entity.build_command.disabled = false
	
    local index = Utils.display_floating_text(entity.position, Utils.printable(record.stage_index), true)
    local cmd = {
        bp_entity.build_command[1], bp_entity.build_command[2], bp_entity.build_command[3], bp_entity.build_command[4], bp_entity.build_command[5]
    }
	
    local key_str = Utils.roundn(x, 1) .. "_" .. Utils.roundn(y, 1)
	
	if not record.entity_restore_data[key_str] then
		record.entity_restore_data[key_str] = {}
	end
	
	local restore_data = record.entity_restore_data[key_str]
	
    restore_data.command = cmd
	restore_data.text_index = index
	restore_data.command_group = commandqueue.command_list[global.command_list_parser.current_command_group_index]
	restore_data.recipe = bp_entity.recipe
	
	entity.destroy()
end

local function record_bp_order_entity_remove(event)
    if not global.high_level_commands.bp_order_record then return end
	local bp_data = global.high_level_commands.bp_order_record.blueprint_data
	local record = global.high_level_commands.bp_order_record
	local output_data = global.high_level_commands.bp_order_record.output_data
	local player = game.players[event.player_index]
	local entity = player.selected

	if not entity or entity.type == "entity-ghost" then 
		game.print("Remove: No entity selected!")
		return 
    end


    local x, y = Utils.get_coordinates(entity.position)
    local key_str = Utils.roundn(x, 1) .. "_" .. Utils.roundn(y, 1)

    entity.destroy()

    local restore_data = record.entity_restore_data[key_str]
    if not restore_data then
        game.print("Remove: Cannot restore entity ghost!")
        return
    end

    local entity_stage = output_data[key_str]
    output_data[key_str] = nil
    record.stage_lengths[entity_stage] = record.stage_lengths[entity_stage] - 1
    Utils.remove_floating_text(restore_data.text_index)

    local cmd = restore_data.command
    cmd.disabled = true
    player.surface.create_entity{name="entity-ghost", inner_name = cmd[2], position=cmd[3], direction=cmd[4], force="player", expires=false, type=cmd[5]}

    command_list_parser.add_command_to_current_set(cmd, player, restore_data.command_group)
    local ent = {name=cmd[2], position=cmd[3], direction=cmd[4], type=cmd[5], recipe=restore_data.recipe, build_command = cmd}
    Utils.Chunked.create_entry(bp_data.chunked_entities, bp_data.chunk_size, cmd[3], ent)
	
	if restore_data.area_group then
		output_data.areas[restore_data.area_group] = nil
		Utils.remove_floating_text(restore_data.area_text_index)
	end
        
    record.entity_restore_data[key_str] = nil
end

local function record_bp_order_next(event)
	if not global.high_level_commands.bp_order_record then return end
	local record = global.high_level_commands.bp_order_record
    local output_data = global.high_level_commands.bp_order_record.output_data
    local current_count = record.stage_lengths[record.stage_index]
	
	if record.stage_lengths[record.stage_index] == 0 or not record.stage_lengths[record.stage_index] then
		output_data.default_stage = record.stage_index
		game.print("Blueprint record: Stage " .. record.stage_index .. " declared as default.")
	-- else
	-- 	game.print("Blueprint record: Stage " .. record.stage_index .. ": " .. current_count .. " entities saved.")
    end
    
    if not record.stage_lengths[record.stage_index + 1] then record.stage_lengths[record.stage_index + 1] = 0 end

	record.stage_index = record.stage_index + 1
end

local function record_bp_order_prev(event)
	if not global.high_level_commands.bp_order_record then return end
	local record = global.high_level_commands.bp_order_record
    --local current_count = record.stage_lengths[record.stage_index]
	
    if record.stage_index > 1 then
        record.stage_index = record.stage_index - 1
    end
end

local function record_bp_order_save(event)
	local record = global.high_level_commands.bp_order_record
	if not record or not record.stage_index then 
		game.print("Attempting to save Blueprint build order while nothing is recorded!") 
		return
	end
	local filename = "Blueprints/" .. blueprint_build_order_name(global.high_level_commands.bp_order_record.command)

	local data = "return " .. serpent.block(record.output_data)

	game.print("Writing build order to file " .. filename .. ".lua")
	game.write_file(filename .. ".lua", data, false)

	global.high_level_commands.bp_order_record = nil
end

local function record_bp_area_trigger(event)
	if not global.high_level_commands.bp_order_record then return end
	local bp_data = global.high_level_commands.bp_order_record.blueprint_data
	local record = global.high_level_commands.bp_order_record
	local output_data = global.high_level_commands.bp_order_record.output_data
	local player = game.players[event.player_index]
	local entity = player.selected
	
	if not entity or entity.type ~= "entity-ghost" then 
		game.print("No entity selected!")
		return
	end
	
	local bp_entity = Utils.Chunked.get_entry_at(bp_data.chunked_entities, bp_data.chunk_size, entity.position)
    if not bp_entity then 
        game.print("Entity not part of blueprint!")
        return
    end
	if not output_data.areas then output_data.areas = {} end
	
	local rect = Utils.copy(game.entity_prototypes[entity.ghost_name].collision_box)
	rect = Utils.rotate_rect(rect, Utils.rotation_stringtoint(entity.direction))
	rect = {Utils.translate(rect[1], entity.position), Utils.translate(rect[2], entity.position)}
	
	output_data.areas[record.stage_index] = rect
	
	local text_index = Utils.display_floating_text({entity.position.x, entity.position.y + 0.4}, "Stage " .. Utils.printable(record.stage_index) .. " area trigger", true)
	
    local key_str = Utils.roundn(entity.position.x, 1) .. "_" .. Utils.roundn(entity.position.y, 1)
	
	if not record.entity_restore_data[key_str] then
		record.entity_restore_data[key_str] = {}
	end
	
	local restore_data = record.entity_restore_data[key_str]
	
	restore_data.area_group = record.stage_index
	restore_data.area_text_index = text_index
end



Event.register("bp_order_entity", record_bp_order_entity)
Event.register("bp_order_entity_remove", record_bp_order_entity_remove)
Event.register("bp_area_trigger", record_bp_area_trigger)
GuiEvent.on_click("build_order_ui_save", record_bp_order_save)
GuiEvent.on_click("build_order_ui_prev", record_bp_order_prev)
GuiEvent.on_click("build_order_ui_next", record_bp_order_next)



return { ["auto-build-blueprint"] = {
        type_signature =
        {
            [2] = "string",
            [3] = {"nil", "position"},
            area = {"nil", "rect"},
            rotation = {"nil", "number"},
            set_on_leaving_range = "boolean",
            show_ghosts = "boolean",
            record_order = "boolean",

        },
        default_priority = 100,

        execute = HLC_Utils.empty,

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
                    LogUI.log_to_ui("Press Shift+J to unmark a building.", "run-output")
                    LogUI.log_to_ui("Press J to mark a building for construction.", "run-output")
                    LogUI.log_to_ui("Blueprint order recording started!", "run-output")

                    if global.high_level_commands.bp_order_record then
                        error("Attempting to record a two blueprint orders simultaneously!")
                    end
                    
                    global.high_level_commands.bp_order_record = {
                        command = command,
                        blueprint_data = blueprint,
                        stage_index = 1,
                        output_data = {},
                        stage_lengths = {0},
                        entity_restore_data = {}
                    }
                    BPUI.create(myplayer)                    
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
                if not command.record_order and entity.build_command and entity.stage <= command.data.current_stage then
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

            command.data.blueprint_data = Blueprint.load(blueprint_name(command), offset, rotation, 9, area)
            
            if not command.record_order then
                command.data.blueprint_data.build_order = command_list_parser.get_file("bp." .. blueprint_build_order_name(command))
            
                if command.data.blueprint_data.build_order then
                    command.data.default_stage = command.data.blueprint_data.build_order.default_stage or 0
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
                local bp_data = Blueprint.get_raw_data(blueprint_name(command))
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
        end,
		require = function(command)
			return {"bp." .. blueprint_name(command), "bp." .. blueprint_build_order_name(command)}
		end
    }
}
