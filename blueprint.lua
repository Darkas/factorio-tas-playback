
Blueprint = {}

function Blueprint.load(name, offset, rotation, chunk_size, area)
  chunk_size = chunk_size or 32
  local blueprint_raw = blueprint_data_raw[name]

  if not blueprint_raw then
    game.print(debug.traceback())
    error("Attempted to load not existing blueprint: " .. name)
  end

  local blueprint = {}
  blueprint.type = name

  local entities = blueprint_raw.entities

  blueprint.chunked_entities = {}
  blueprint.counts = {}
  blueprint.chunk_size = chunk_size or 9

  for _, ent in pairs(entities) do
    local entity = copy(ent)
    entity.position = translate(rotate_orthogonal(entity.position, rotation), {offset[1] - blueprint_raw.anchor.x + 0.5, offset[2] - blueprint_raw.anchor.y + 0.5})
    if not area or inside_rect(entity.position, area) then
      if blueprint.counts[entity.name] then
        blueprint.counts[entity.name] = blueprint.counts[entity.name] + 1
      else
        blueprint.counts[entity.name] = 1
      end

      if entity.direction and rotation then
        entity.direction = (entity.direction + rotation) % 8
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
  blueprint.chunked_entities[key][entity._index] = nil
  local finished = true
  for _, _ in pairs(blueprint.chunked_entities[key]) do
    finished = false
    break
  end
  if finished then blueprint.chunked_entities[key] = nil end
  for _, _ in pairs(blueprint.chunked_entities) do
    return true
  end
  return false
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
        if distance_from_rect(position, collision_box(entity)) <= player.build_distance then -- TODO: This should be done dynamically.
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
      for _, entity in ipairs(entities[X .. "_" .. Y]) do
        table.insert(res, entity)
      end
    end
  end

  return res
end

function Blueprint.get_entity_at(blueprint_data, position)
    local res = {}
    local entities = blueprint_data.chunked_entities
    local X, Y = position.x or position[1], position.y or position[2]
    local x = math.floor(X / blueprint_data.chunk_size)
    local y = math.floor(Y / blueprint_data.chunk_size)
    for _, entity in pairs(entities[x .. "_" .. y]) do
        if entity.x == X and entity.y == Y then
            return entity
        end
    end
end

function Blueprint.key_from_position(position, chunk_size)
  return math.floor((position.x or position[1]) / chunk_size) .. "_" .. math.floor((position.y or position[2]) / chunk_size)
end
