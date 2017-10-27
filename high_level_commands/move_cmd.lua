-- move

-- luacheck: globals command_list_parser Utils high_level_commands LogUI Event TAScommands
-- luacheck: ignore 212

local move_cmd = {
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
            LogUI.debugprint("Auto move to: " .. serpent.block(command.data.target_pos))
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
                LogUI.errprint("move: There is no command named: " .. command[2])
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
}

return {move = move_cmd}