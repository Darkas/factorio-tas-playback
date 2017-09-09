
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

  if not blueprint_raw then game.print(debug.traceback()); error("Attempted to load not existing blueprint: " .. blueprint_path(name)) end

  local blueprint = {}
  blueprint.type = name

  local entities = blueprint_raw.entity_data

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
    entity.position = translate(rotate_orthogonal(entity.position, rotation), offset)

    local key = key_from_position(entity.position)
    if blueprint.chunked_entities[key] then
      table.insert(blueprint.chunked_entities[key], entity)
    else 
      blueprint.chunked_entities[key] = {entity}
    end
  end

  return blueprint
end


function bp_get_entities_in_build_range(blueprint_data, position)
  local res = {}

  local entities = blueprint_data.entities
  local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
  local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

  for X = x-1, x+1 do
    for Y = y-1, y+1 do
      for _, entity in ipairs(entities[x .. "_" .. y]) do
        if distance_from_rect(position, collision_box(entity)) < range + 6.0024 then
          table.insert(res, entity)
        end
      end
    end
  end

  return res
end

function bp_get_entities_close(blueprint_data, position)
  local res = {}

  local entities = blueprint_data.entities
  local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
  local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

  for X = x-1, x+1 do
    for Y = y-1, y+1 do
      for _, entity in ipairs(entities[x .. "_" .. y]) do
        table.insert(res, entity)
      end
    end
  end

  return res
end

function bp_key_from_position(position)
  return math.floor((position.x or position[1]) / blueprint_data.chunk_size) .. "_" .. math.floor((position.y or position[2]) / blueprint_data.chunk_size)
end

