
local Utils = require("utility_functions")
local Event = require("stdlib/event/event")

-- Usage: 
-- TODO: Document
-- Raises MvRec.on_started_recording

MvRec = {} --luacheck: allow defined top
global.MvRec = global.MvRec or {
    record_tasks = {},
}

local movement_data_raw

function MvRec.init(movement_data)
    movement_data_raw = movement_data
    if movement_data then global.MvRec.initialized = true end
    MvRec.on_replaying_finished = script.generate_event_name()
end

local function process_record_task(record_task)
    local tick = game.tick - record_task.tick

    if record_task.replay then
        local state = record_task.data[tick]
        if state then 
            record_task.last_state = state
        else
            state = record_task.last_state
        end

        if record_task.data.end_of_input == tick then
            record_task.replay = false
            if record_task.record and #game.players == 1 then
                Event.dispatch{ name = MvRec.on_replaying_finished, record_task = record_task}
            end
        end

        if record_task.drive then
            record_task.player.riding_state = state
        else
            record_task.walking_state = state
        end

    elseif record_task.record then
        local state
        if not record_task.drive then
            state = record_task.player.walking_state
            if record_task.last_state.walking ~= state.walking or record_task.last_state.direction ~= state.direction then
                record_task.last_state = state
            end
        else
            state = record_task.player.riding_state
            if record_task.last_state.acceleration ~= state.acceleration or record_task.last_state.direction ~= state.direction then
                record_task.last_state = state
            end
        end
        record_task.data[game.tick - record_task.tick] = state
        record_task.data.end_of_input = tick
    end
end


local function process_recordings()
    for _, record_task in pairs(global.MvRec.record_tasks) do
        process_record_task(record_task)
    end
end


-- Record movements for the given player. Currently needs to specify if it is a car or walking. If `replay` is set and either the `data` table is set or the file `scenarios/<tas_name>/movement_records` contains movement data, the movement data will be replayed. Afterwards, if the `record` field is set, we start recording movements from the player and alert the player of this.
-- record_task is a table with the following fields:
-- player (LuaPlayer) - the player or entity whose movement we are recording
-- name (string) - unique identifier for the movement recording
-- drive (boolean) - is this a vehicle or walking
-- record (boolean) - are we recording?
-- replay (boolean) - are we replaying?
-- data (table, optional) - table that is used to represent recorded movement data.

function MvRec.start_record(record_task)
    if not record_task.name then
        Utils.errprint("Missing name parameter for movement recording!")
        return
    elseif not record_task.player then
        Utils.errprint("Missing player parameter for movement recording " .. record_task.name .. "!")
        return   
    elseif global.MvRec[record_task.player.index] then
        Utils.errprint("Already recording movement " .. record_task.name .. " for player " .. record_task.player.index .. "!")
        return
    end

    if next(global.MvRec.record_tasks) == nil then
        Event.register(defines.events.on_tick, process_recordings)
    end

    if not record_task.data then record_task.data = movement_data_raw[record_task.name] end
    if not record_task.data or not next(record_task.data) then
        record_task.data = {}
        record_task.end_of_input = 0
    else
        record_task.replay = true
    end

    record_task.last_state = record_task.last_state or {}
    record_task.tick = game.tick

    table.insert(global.MvRec.record_tasks, record_task)
end



function MvRec.stop_record(player_index)
    if not global.MvRec[player_index] then
        Utils.errprint("Attempting to stop unexisting movement record for player " .. player_index)
        return
    end

    global.MvRec[player_index] = nil
    if next(global.MvRec.record_tasks) == nil then
        Event.remove(defines.events.on_tick, process_recordings)
    end
end



function MvRec.write_data(player_index, filename)
    local record_task = global.MvRec.record_tasks[player_index]
    if not record_task then
        game.print("Attempting to write unexisting movement record for player " .. player_index .. " to file " .. filename .. ".")
        return
    end
    local data = "return " .. serpent.block(record_task.data)
    game.write_file(filename, data)
    game.print("Movement data " .. record_task.name .. " exported to file " .. filename ".")
end

function MvRec.is_recording(player_index)
    return global.MvRec.record_tasks[player_index] ~= nil
end

return MvRec