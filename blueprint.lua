local function init_blueprint_loader()
  global.blueprint_data.blueprints = {}
end

function bp_load(name, offset, chunk_size)
  if not global.blueprint_data then init_blueprint() end

  if not blueprints then return end
  local blueprint = blueprints[name]

  local entities = blueprint.entity_data
  if not entities then error("Loading empty blueprint!") end

  global.blueprint_data.blueprints[name] = {name = name}
  local blueprint_data = global.blueprint_data.blueprints[name]
  blueprint_data.chunked_entities = {}
  blueprint_data.counts = {}
  blueprint_data.chunk_size = chunk_size or 9

  for index, entity in pairs(entities) do
    if blueprint_data.counts[entity.name] then
      blueprint_data.counts[entity.name] = blueprint_data.counts[entity.name] + 1
    else
      blueprint_data.counts[entity.name] = 1
    end

    entity.position.x = entity.position.x + offset.x
    entity.position.y = entity.position.x + offset.y

    local key = key_from_position(entity.position)
    if blueprint_data.chunked_entities[key] then
      table.insert(blueprint_data.chunked_entities[key], entity)
    end
  end
end


function bp_remove_entity(name, entity)
  local blueprint_data = global.blueprint_data.blueprints[name]
  for index, ent in pairs(blueprint_data.entities[key_from_position(entity.position)]) do
    if entity.entity_number == ent.number then
      table.remove(blueprint_data.entities, entity)
      break
    end
  end
end


function bp_get_entities_in_build_range(name, position)
  if not blueprint_data then error("Trying to get entities from blueprint that wasnt loaded"!) end

  local ret = {}

  local blueprint_data = global.blueprint_data.blueprints[name]
  local entities = blueprint_data.entities
  local x = math.floor((position.x or position[1]) / blueprint_data.chunk_size)
  local y = math.floor((position.y or position[2]) / blueprint_data.chunk_size)

  for X = x-1, x+1 do
    for Y = y-1, y+1 do
      for _, entity in ipairs(entities[x .. "_" .. y]) do
        local cbox = game.entity_prototypes.collision_box
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

