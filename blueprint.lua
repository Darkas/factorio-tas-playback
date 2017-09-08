
function blueprint_path(name)
  return "scenarios." .. tas_name .. "." .. "blueprints." .. name
end

global.blueprint_raw_data = global.blueprint_raw_data or {}

function bp_load(name, offset, rotation, chunk_size)
  local blueprint_raw = global.blueprint_raw_data[name]
  if not blueprint_raw then
    pcall(function() blueprint_raw = require(blueprint_path(name)))
    global.blueprint_raw_data[name] = blueprint_raw
  end

  if not blueprint_raw then return end

  local blueprint = {}
  blueprint.type = name

  local entities = blueprint_raw.entity_data
  if not entities then error("Loading empty blueprint!") end

  blueprint.entities = {}
  blueprint.counts = {}
  blueprint.chunk_size = chunk_size or 9

  for index, ent in pairs(entities) do
    local entity = copy(ent)
    if blueprint.counts[entity.name] then
      blueprint.counts[entity.name] = blueprint.counts[entity.name] + 1
    else
      blueprint.counts[entity.name] = 1
    end

    if entity.direction and rotation then
      entity.direction = (entity.direction + rotation) % 8
    end
    entity.position = translate(rotate(entity.position, direction), offset)

    local key = key_from_position(entity.position)
    if blueprint.chunked_entities[key] then
      table.insert(blueprint.chunked_entities[key], entity)
    end
  end

  return blueprint
end


function bp_get_entities_in_build_range(blueprint_data, position)
  if not blueprint_data then error("Trying to get entities from blueprint that wasnt loaded"!) end

  local ret = {}

  local entities = blueprint_data.entities
  local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
  local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

  for X = x-1, x+1 do
    for Y = y-1, y+1 do
      for _, entity in ipairs(entities[x .. "_" .. y]) do
        local cbox = move_collision_box(game.entity_prototypes[entity.name].collision_box
        local rect = {{x=cbox[1][1], y=cbox[1][2]}, {x=cbox[2][1], y=cbox[2][2]}}
        if distance_from_rect(position, rect, {}) < range + 6.0024 then
          table.insert(ret, entity)
        end
      end
    end
  end

  return ret
end

function bp_get_entities_close(name, position)
  if not blueprint_data then error("Trying to get entities from blueprint that wasnt loaded"!) end

  local ret = {}

  local blueprint_data = global.blueprint_data.blueprints[name]
  local entities = blueprint_data.entities
  local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
  local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

  for X = x-1, x+1 do
    for Y = y-1, y+1 do
      for _, entity in ipairs(entities[x .. "_" .. y]) do
        table.insert(ret, entity)
      end
    end
  end

  return ret
end

local function key_from_position(position)
  return math.floor((position.x or position[1]) / blueprint_data.chunk_size) .. "_" .. math.floor((position.y or position[2]) / blueprint_data.chunk_size)
end

