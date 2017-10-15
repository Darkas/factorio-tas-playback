
local Utils = require("utility_functions")
local Event = require("stdlib/event/event")



RecordMovement = {} --luacheck: allow defined top
global.RecordMovement = global.RecordMovement or {
    record_tasks = {},
}

local movement_data_raw

function RecordMovement.init(movement_data)
    movement_data_raw = movement_data
    RecordMovement.on_started_recording = script.generate_event_name()
end


local function process_recordings()
    for _, record_task in pairs(global.RecordMovement.record_tasks) do
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
                    Event.dispatch{ name = RecordMovement.on_started_recording, record_name = record_task.name}
                    -- TODO move this and set permissions!
                    game.speed = 0.01
                    game.show_message_dialong{text = "Recording Car Movements for " .. record_task.name .. " now!"}
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
end


-- Record movements for the given player. Currently needs to specify if it is a car or walking. If `replay` is set and either the `data` table is set or the file `scenarios/<tas_name>/movement_records` contains movement data, the movement data will be replayed. Afterwards, if the `record` field is set, we start recording movements from the player and alert the player of this.
-- record_task is a table with the following fields:
-- player (LuaPlayer) - the player or entity whose movement we are recording
-- name (string) - unique identifier for the movement recording
-- drive (boolean) - is this a vehicle or walking
-- record (boolean) - are we recording?
-- replay (boolean) - are we replaying?
-- data (table, optional) - table that is used to represent recorded movement data.

function RecordMovement.start_record(record_task)
    if not record_task.name then
        Utils.errprint("Missing name parameter for movement recording!")
        return
    elseif not record_task.player then
        Utils.errprint("Missing player parameter for movement recording " .. record_task.name .. "!")
        return   
    elseif global.RecordMovement[record_task.name] then
        Utils.errprint("Already recording movement " .. record_task.name .. "!")
        return
    end

    if next(global.RecordMovement.record_tasks) == nil then
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

    table.insert(global.RecordMovement.record_tasks, record_task)
end



function RecordMovement.stop_record(name)
    if not global.RecordMovement[name] then
        Utils.errprint("Attempting to stop unexisting movement record: " .. name)
        return
    end

    table.remove(global.RecordMovement[name])
    if next(global.RecordMovement.record_tasks) == nil then
        Event.remove(defines.events.on_tick, process_recordings)
    end
end



function RecordMovement.write_data(name, filename)
    if not global.RecordMovement[name] then
        game.print("Attempting to write unexisting movement record " .. name " to file " .. filename .. ".")
        return
    end
    local data = "return " .. serpent.block(global.RecordMovement[name].data)
    game.write_file(filename, data)
    game.print("Movement data " .. name .. " exported to file " .. filename ".")
end

