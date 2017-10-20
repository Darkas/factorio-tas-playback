
Blueprint = {} --luacheck: allow defined top
local Utils = require("utility_functions")

local blueprint_data_raw
function Blueprint.init(blueprint_raw)
    blueprint_data_raw = blueprint_raw or {}
end


function Blueprint.get_raw_data(name)
    return blueprint_data_raw[name]
end


function Blueprint.load(name, offset, rotation, chunk_size, area)
    local blueprint_raw = blueprint_data_raw[name]
    if not blueprint_raw then
        game.print(debug.traceback())
        error("Attempted to load not existing blueprint: " .. name)
    end
    if not blueprint_raw.anchor then error("Loading blueprint without anchor!") end
    local entities = blueprint_raw.entities

    local blueprint = {
        name = name,
        chunk_size = chunk_size or 32,
        chunked_entities = {},
        counts = {},
    }

    for _, ent in pairs(entities) do
        local entity = Utils.copy(ent)
        entity.position = Utils.translate(Utils.rotate_orthogonal(entity.position, rotation), {offset[1] - blueprint_raw.anchor.x + 0.5, offset[2] - blueprint_raw.anchor.y + 0.5})
        if not area or Utils.inside_rect(entity.position, area) then
            if blueprint.counts[entity.name] then
                blueprint.counts[entity.name] = blueprint.counts[entity.name] + 1
            else
                blueprint.counts[entity.name] = 1
            end

            if rotation then
                entity.direction = ((entity.direction or 0) + rotation) % 8
            end

            local key = Blueprint.key_from_position(entity.position, chunk_size)
            if blueprint.chunked_entities[key] then
                table.insert(blueprint.chunked_entities[key], entity)
            else
                blueprint.chunked_entities[key] = {entity}
            end
            entity._index = #blueprint.chunked_entities[key]
        end
    end

    return blueprint
end

-- Returns wether the blueprint has entities left
function Blueprint.remove_entity(blueprint, entity)
    if not blueprint or not entity then
        game.print(debug.traceback())
        error("Called Blueprint.remove_blueprint with invalid param!")
    end
    local key = Blueprint.key_from_position(entity.position, blueprint.chunk_size)

    if not blueprint.chunked_entities[key] then game.print(debug.traceback()); error("Attempted to delete entity in chunk that does not exist from blueprint! Blueprint name: " .. blueprint.name .. ", entity: " .. serpent.block(entity)) end
    if not blueprint.chunked_entities[key][entity._index] then game.print(debug.traceback()); error("Attempted to delete entity that does not exist in blueprint! Blueprint name: " .. blueprint.name .. ", entity: " .. serpent.block(entity)) end
    blueprint.chunked_entities[key][entity._index] = nil
    if next(blueprint.chunked_entities[key]) == nil then
        blueprint.chunked_entities[key] = nil
    end
    local entities_left = (next(blueprint.chunked_entities) ~= nil)
    return entities_left
end


function Blueprint.get_entities_in_build_range(blueprint_data, player)
    if not blueprint_data then game.print(debug.traceback()); error("Called Blueprint.get_entities_in_build_range with invalid blueprint_data!") end
    local res = {}
    local position = player.position

    local entities = blueprint_data.chunked_entities
    local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
    local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

    for X = x-1, x+1 do
        for Y = y-1, y+1 do
            for _, entity in pairs(entities[X .. "_" .. Y] or {}) do
                if Utils.distance_from_rect(position, Utils.collision_box(entity)) <= player.build_distance + 0.1 then -- TODO: This should be done dynamically.
                    table.insert(res, entity)
                end
            end
        end
    end

    return res
end

function Blueprint.get_entities_close(blueprint_data, position)
    local res = {}

    local entities = blueprint_data.chunked_entities
    local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
    local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

    for X = x-1, x+1 do
        for Y = y-1, y+1 do
            for _, entity in ipairs(entities[X .. "_" .. Y] or {}) do
                table.insert(res, entity)
            end
        end
    end

    return res
end

function Blueprint.get_entity_at(blueprint_data, position)
    local entities = blueprint_data.chunked_entities
    for _, entity in pairs(entities[Blueprint.key_from_position(position, blueprint_data.chunk_size)] or {}) do
        if Utils.sqdistance(entity.position, position) < 0.01 then
            return entity
        end
    end
end

function Blueprint.save_entity_data(blueprint_data, position, t)
    local entities = blueprint_data.chunked_entities
    for _, entity in pairs(entities[Blueprint.key_from_position(position, blueprint_data.chunk_size)] or {}) do
        if Utils.sqdistance(entity.position, position) < 0.01 then
            for k, v in pairs(t) do
                entity[k] = v
            end
        end
    end
end

function Blueprint.key_from_position(position, chunk_size)
    return math.floor((position.x or position[1]) / chunk_size) .. "_" .. math.floor((position.y or position[2]) / chunk_size)
end

return Blueprint