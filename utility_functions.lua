-- Utility functions
Utils = {} --luacheck: allow defined top
local LogUI = require("log_ui")
local mod_gui = require("mod-gui")
local GuiEvent = require("stdlib.event.gui")


if not global.Utils then global.Utils = {} end
if not global.Utils.floating_texts then global.Utils.floating_texts = {} end
local our_global = global.Utils


if not our_global.entity_recipe then our_global.entity_recipe = {} end



-- Categories: 
--   Tables
--   Printing
--   Maths and Geometry
--   String
--   Chunked
--   Entity
--   Gui



-- Tables
----------

-- This can obviously be done better but it works for now.
function Utils.tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
end

function Utils.table_keys(t)
	local keys = {}
	for k, _ in pairs(t) do
		keys[#keys + 1] = k
	end
	return keys
end

function Utils.is_position(v)
	return type(v) == "table" and type(v[1] or v.x) == "number" and type(v[2] or v.y) == "number" and not v[3]
end

-- Taken from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
function Utils.copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[Utils.copy(k, s)] = Utils.copy(v, s) end
  return res
end

function Utils.has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	return false
end

-- Yep, this is a duplicate.
function Utils.in_list(element, list)
	if not list then game.print(debug.traceback()) error("Nil argument to in_list!") end
	for _, v in pairs(list) do
		if v == element then
			return true
		end
	end
	return false
end

-- list only
function Utils.get_minimum_index(list, lessthan_func)
	if #list == 0 then return 0 end
	local index = 1
	local min_value = list[index]
	for i, value in ipairs(list) do
		if lessthan_func then
			if lessthan_func(value, min_value) then
				index = i
				min_value = value
			end
		else
			if value < min_value then
				index = i
				min_value = value
			end
		end
	end
	return index, min_value
end

function Utils.concat_tables(table1, table2)
	for i = 1, #table2 do
		table1[#table1+1] = table2[i]
	end
	return table1
end



-- Printing
------------

function Utils.debugprint(msg)
	LogUI.log_to_ui(msg, "run-debug")
end

function Utils.errprint(msg)
	LogUI.log_to_ui(msg, "tascommand-error")
end



-- Maths and Geometry
----------------------

function Utils.roundn(x, prec)
	if not x then game.print(debug.traceback()); error("roundn called without valid parameter.") end
	if not prec then
		return math.floor(x + 0.5)
	else
		return math.floor(x*10^prec + 0.5) / 10^prec
	end
end

-- don't use this function, use in_range instead
-- TODO: remove this function
function Utils.inrange(position, myplayer)
  return ((position[1] - myplayer.position.x)^2 + (position[2] - myplayer.position.y)^2) < 36
end

function Utils.inside_rect(point, rect)
	local x, y = Utils.get_coordinates(point)
	local lower_x, lower_y = Utils.get_coordinates(rect[1] or rect.left_top)
	local upper_x, upper_y = Utils.get_coordinates(rect[2] or rect.right_bottom)
	
	if not x or not y or not lower_x or not lower_y or not upper_x or not upper_y then
		game.print(debug.traceback());
		error("inside_rect called with invalid parameters.")
	end
	
	return lower_x < x and x < upper_x and lower_y < y and y < upper_y
end

-- rotation for angles multiple of 90°, encoded as 2 for 90°, 4 for 180°, 6 for 270°
function Utils.rotate_orthogonal(position, rotation)
	local x, y = Utils.get_coordinates(position)
	if not rotation or rotation == 0 then return {x, y}
	elseif rotation == 2 then return {-y, x}
	elseif rotation == 4 then return {-x, -y}
	elseif rotation == 6 then return {y, -x}
	else game.print(debug.traceback()) error("Bad rotation parameter! rotation = " .. Utils.printable(rotation)) end
end

function Utils.rotate_rect(rect, rotation)
	if not rect then game.print(debug.traceback()) error("Called rotate_rect without rect param!") end
	if not rotation or rotation == 0 then return {rect[1] or rect.left_top, rect[2] or rect.right_bottom} end
	local x1, y1 = Utils.get_coordinates(Utils.rotate_orthogonal(rect[1] or rect.left_top, rotation))
	local x2, y2 = Utils.get_coordinates(Utils.rotate_orthogonal(rect[2] or rect.right_bottom, rotation))

	if x1 <= x2 then
		if y1 <= y2 then
			return {{x1, y1}, {x2, y2}}
		else
			return {{x1, y2}, {x2, y1}}
		end
	else
		if y1 <= y2 then
			return {{x2, y1}, {x1, y2}}
		else
			return {{x2, y2}, {x1, y1}}
		end
	end
end

function Utils.prettytime()
  local tick = game.tick - (global.start_tick or 0)
  if settings.global["tas-pretty-time"].value then
    local hours = string.format("%02.f", math.floor(tick / 216000))
    local minutes = string.format("%02.f", math.floor(tick / 3600) - hours * 60)
    local seconds = string.format("%02.f", math.floor(tick / 60) - hours * 3600 - minutes * 60)
    local ticks = string.format("%02.f", tick - hours * 216000 - minutes * 3600 - seconds * 60)
    if hours == "00" then
      return "[" .. minutes .. ":" .. seconds .. ":" .. ticks .. "] "
    else
      return "[" .. hours .. ":" .. minutes .. ":" .. seconds .. ":" .. ticks .. "] "
    end
  end
  return "[" .. tick .. "] "
end



function Utils.translate(position, offset)
	if not offset then return position end
	local x, y = Utils.get_coordinates(position)
	local dx, dy = Utils.get_coordinates(offset)
	return {x+dx, y+dy}
end

function Utils.sqdistance(pos1, pos2)
	if not pos1[1] and not pos1.x then game.print(serpent.block(pos1)) game.print(debug.traceback()) error("Called distance with invalid parameter!") end
	local x1, y1 = Utils.get_coordinates(pos1)
	local x2, y2 = Utils.get_coordinates(pos2)

	return (x1 - x2)^2 + (y1 - y2)^2
end

-- works for name or entity or table {name=..., position=..., direction=...}
global.Utils.collision_box_cache = {}
function Utils.collision_box(entity)
	local cache_key
	if type(entity) == "string" then 
		cache_key = entity
	else
		local x, y = Utils.get_coordinates(entity.position)
		cache_key = "_" .. entity.name .. "_" .. x .. "_" .. y .. "_" .. (entity.direction or "")
	end
	if global.Utils.collision_box_cache[cache_key] then
		return global.Utils.collision_box_cache[cache_key]
	end

	if not entity then game.print(debug.traceback()) error("Called collision_box with parameter nil!") end

	local rect = nil
	if type(entity) == "string" then
		local ret_val = game.entity_prototypes[entity].collision_box
		global.Utils.collision_box_cache[cache_key] = ret_val
		return ret_val
	end
	pcall(function()
		if entity.prototype then
			rect = Utils.copy(entity.prototype.collision_box)
		end
	end)
	if not rect then rect = Utils.copy(game.entity_prototypes[entity.name].collision_box) end

	-- Note: copy outputs a rect as {left_top=..., right_bottom=...}, rotate_rect handles this and returns {[1]=..., [2]=...}.
	rect = Utils.rotate_rect(rect, Utils.rotation_stringtoint(entity.direction))

	local ret_val = {Utils.translate(rect[1], entity.position), Utils.translate(rect[2], entity.position)}
	global.Utils.collision_box_cache[cache_key] = ret_val	
	return ret_val
end

function Utils.in_range(command, myplayer)
	return Utils.distance_from_rect(myplayer.position, command.rect) <= command.distance
end

-- Say we wish to get within a certain distance of a square. This function Utils.outputs the closest point to the given position which is within range.
-- Closest here is not quite according to euclidean distance since we can only walk axis-aligned or diagonally.
function Utils.closest_point(square, circle_radius, position)
	local ax, ay = Utils.get_coordinates(square[1] or square.left_top)
	local bx, by = Utils.get_coordinates(square[2] or square.right_bottom)

	local cx, cy = (ax + bx) / 2, (ay + by) / 2
	local square_radius = cx - ax

	-- Translate to origin
	local px, py = Utils.get_coordinates(Utils.translate(position, {-cx, -cy}))

	-- Rotate until coordinates are positive
	local rotation = 0
	while not ((px >= 0) and (py >= 0)) do
		rotation = rotation + 2
		px, py = Utils.get_coordinates(Utils.rotate_orthogonal({px, py}, 2))
	end

	-- Mirror until x > y
	local mirrored = false
	if py > px then
		mirrored = true
		px, py = py, px
	end


	-- Actual calculation of target point.
	local rx, ry -- result.
	if py <= square_radius then
		rx, ry = square_radius + circle_radius, py
		--  then
	elseif py <= square_radius + circle_radius * math.sin(3.14159 / 8) then
		px, py = px - square_radius, py - square_radius
		rx, ry = math.sqrt(circle_radius^2 - py^2), py
		rx, ry = rx + square_radius, ry + square_radius
	elseif px - (square_radius + circle_radius * math.cos(3.14159 / 8)) >= py - (square_radius + circle_radius * math.sin(3.14159 / 8))  then
		rx, ry = square_radius + circle_radius * math.cos(3.14159 / 8), square_radius + circle_radius * math.sin(3.14159 / 8)
	else
		px, py = px - square_radius, py - square_radius
		local D = math.sqrt(2*circle_radius^2 - (px-py)^2)
		rx, ry = (px - py + D) / 2, (py - px + D) / 2
		rx, ry = rx + square_radius, ry + square_radius
	end

	-- Revert mirroring
	if mirrored then
		rx, ry = ry, rx
	end
	-- Revert rotation
	rx, ry = Utils.get_coordinates(Utils.rotate_orthogonal({rx, ry}, (-rotation % 8)))

	local ret = Utils.translate({cx, cy}, {rx*0.99, ry*0.99})
	return ret
end

-- Works only for axis-aligned rectangles.
function Utils.distance_from_rect(pos, rect)
	if not rect then game.print(debug.traceback()) error("Called distance_from_rect with invalid rect param.") end
	local posx, posy = Utils.get_coordinates(pos)
	local rect1x, rect1y = Utils.get_coordinates(rect[1])
	local rect2x, rect2y = Utils.get_coordinates(rect[2])

	-- find the two closest corners to pos and the center
	local corners = {{x=rect1x, y=rect1y}, {x=rect1x, y=rect2y}, {x=rect2x, y=rect1y}, {x=rect2x, y=rect2y}}

	local function lt(a, b)
		return Utils.sqdistance(a, pos) < Utils.sqdistance(b, pos)
	end
	local index, corner1 = Utils.get_minimum_index(corners, lt)
	table.remove(corners, index)
	local _, corner2 = Utils.get_minimum_index(corners, lt)

	local closest = {}

	-- Set closest point on rectangle
	if corner1.x == corner2.x then
		closest[1] = corner1.x
		if corner1.y > corner2.y then corner1, corner2 = corner2, corner1 end
		if posy < corner1.y then closest[2] = corner1.y
		elseif posy > corner2.y then closest[2] = corner2.y
		else closest[2] = posy end
	else
		closest[2] = corner1.y
		if corner1.x > corner2.x then corner1, corner2 = corner2, corner1 end
		if posx < corner1.x then closest[1] = corner1.x
		elseif posx > corner2.x then closest[1] = corner2.x
		else closest[1] = posx end
	end

	return math.sqrt(Utils.sqdistance(closest, pos)), closest
end

function Utils.distance_rect_to_rect(rect1, rect2)
	local corners1 = {{rect1[1][1], rect1[1][2]}, {rect1[2][1], rect1[1][2]}, {rect1[2][1], rect1[2][2]}, {rect1[1][1], rect1[2][2]}} -- corners1[1] is the top left corner, continue clockwise
	local corners2 = {{rect2[1][1], rect2[1][2]}, {rect2[2][1], rect2[1][2]}, {rect2[2][1], rect2[2][2]}, {rect2[1][1], rect2[2][2]}}

	local in_cross_x = false
	local in_cross_y = false

	for _,corner in pairs(corners1) do
		if corners2[1][1] <= corner[1] and corner[1] <= corners2[2][1] then
			in_cross_x = true
		end

		if corners2[2][2] <= corner[2] and corner[2] <= corners2[3][2] then
			in_cross_y = true
		end
	end

	if in_cross_x then
		return math.min(math.abs(corners1[1][2] - corners2[1][2]), math.abs(corners1[3][2] - corners2[1][2]), math.abs(corners1[1][2] - corners2[3][2]), math.abs(corners1[3][2] - corners2[3][2]))
	end

	if in_cross_y then
		return math.min(math.abs(corners1[2][1] - corners2[2][1]), math.abs(corners1[4][1] - corners2[2][1]), math.abs(corners1[2][1] - corners2[4][1]), math.abs(corners1[4][1] - corners2[4][1]))
	end

	local min_distance = Utils.sqdistance(corners1[1], corners2[1])

	for _,corner1 in pairs(corners1) do
		for _,corner2 in pairs(corners2) do
			local distance = Utils.sqdistance(corner1, corner2)

			if distance < min_distance then
				min_distance = distance
			end
		end
	end

	return min_distance
end

function Utils.get_coordinates(pos)
	if not pos then game.print(debug.traceback()); error("Trying to access coordinates of invalid point!") end
	if pos.x then
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end



-- String Processing
---------------------

function Utils.namespace_prefix(name, command_group)
	if not name then
		return nil
	end

	if not string.find(name, "%.") then
		return command_group .. "." .. name
	else
		return name
	end
end


function Utils.string_to_position(data)
	local _, _, x, y = string.find(data, "{(.*),(.*)}")
	return {tonumber(x), tonumber(y)}
end


local direction_ints = {N = 0, NE = 1, E = 2, SE = 3, S = 4, SW = 5, W = 6, NW = 7}
function Utils.rotation_stringtoint(rot)
	if type(rot) == "int" then
		return rot
	else
		return direction_ints[rot]
	end
end

function Utils.printable(v)
	if v == nil then return "nil"
	elseif v == true then return "true"
	elseif v == false then return "false"
	elseif type(v) == "number" then return Utils.roundn(v, 1)
	elseif type(v) == "table" then
		local pos_string = ", "
		local one = false
		local two = false
		if v.__self then return "<Factorio Data>" end
		for key, value in pairs(v) do
			if (key == 1 or key == "x") and type(value) == "number" then
				one = true
				pos_string = "{" .. Utils.roundn(value) .. pos_string
			elseif (key == 2 or key == "y") and type(value) == "number" then
				two = true
				pos_string = pos_string .. Utils.roundn(value) .. "}"
			else
				return "{…}"
			end
		end
		if one and two then 
			return pos_string
		elseif not one and not two then
			return "{}"
		else
			return "{…}"
		end
	else
		return v
	end
end

-- Surface related
-------------------

function Utils.get_entity_from_pos(pos, myplayer, types, epsilon)
	if (not pos) or (type(pos) ~= type({})) then game.print(debug.traceback()) end
	local x, y = Utils.get_coordinates(pos)

	if not epsilon then
		epsilon = 0.2
	end

	-- if type == "resource" and x == math.floor(x) then
	-- 	x = x + 0.5
	-- 	y = y + 0.5
	-- end

	local accepted_types

	if type(types) == type("") then
		accepted_types = {types}
	elseif type(types) == type({}) then
		accepted_types = types
	else
		accepted_types = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler",
			"resource", "simple-entity", "tree", "lab", "rocket-silo", "transport-belt", "underground-belt", "splitter", "inserter"}
	end

	local entity = nil

	for _,ent in pairs(myplayer.surface.find_entities_filtered({area = {{-epsilon + x, -epsilon + y}, {epsilon + x, epsilon + y}}})) do
		if Utils.has_value(accepted_types, ent.type) then
			entity = ent
		end
	end

	return entity
end



-- Entity related
------------------

-- Note this should only be called for entities that are actually on a surface.
function Utils.get_recipe_name(entity)
	if not entity then game.print(debug.traceback()) error("Trying to access recipe of nil entity!") end
	local x, y = Utils.get_coordinates(entity.position)
	local recipe
	pcall(function() recipe = entity.recipe end)
	if entity.type == "furnace" then
		if recipe then
			our_global.entity_recipe[x .. "_" .. y] = recipe.name
			return recipe.name
		end
		pcall(function() recipe = entity.previous_recipe end)
		if recipe then
			our_global.entity_recipe[x .. "_" .. y] = recipe.name
			return recipe.name
		end
		if our_global.entity_recipe[x .. "_" .. y] then return our_global.entity_recipe[x .. "_" .. y] end

		local stack = entity.get_output_inventory()[1]
		if stack and stack.valid_for_read then
			return stack.name
		else
			return nil
		end
	elseif entity.type == "assembling-machine" then
		return recipe.name
	else
		error("Called get_recipe for entity without recipe.")
	end
end

function Utils.craft_interpolate(entity, ticks)
	local craft_speed = entity.prototype.crafting_speed
	local recipe = Utils.get_recipe_name(entity)
	local energy = game.recipe_prototypes[recipe].energy
	local progress = entity.crafting_progress

	return math.floor((ticks / 60 * craft_speed) / energy + progress)
end

function Utils.display_floating_text(position, text, stay, color)
	local pos = position.position or position
	local entity_info = {name="flying-text", position=pos, text=text, color=color}
	
	local entity = game.surfaces.nauvis.create_entity(entity_info)
	
	global.Utils.floating_texts[#global.Utils.floating_texts + 1] = {entity, entity_info, stay}
	
	return #global.Utils.floating_texts
end

function Utils.remove_floating_text(index)
	global.Utils.floating_texts[index][1].destroy()
	global.Utils.floating_texts[index] = nil
end

function Utils.update_floating_text(index, new_text)
	local text_data = global.Utils.floating_texts[index]
	text_data[1].destroy()
	text_data[2].text = new_text
	text_data[1] = game.surfaces.nauvis.create_entity(text_data[2])
	text_data[1].teleport(text_data[2].position)
end

Event.register(defines.events.on_tick, function (event)
	for i,text_data in pairs(global.Utils.floating_texts) do
		if text_data[1] and text_data[1].valid then
			text_data[1].teleport(text_data[2].position)
		else
			if text_data[3] then
				text_data[1] = game.surfaces.nauvis.create_entity(text_data[2])
			else
				global.Utils.floating_texts[i] = nil
			end
		end
	end
end)

-- Returns true if the player can craft at least one. 
-- craft is a table {name = <item_name>}
function Utils.can_craft(craft, player, need_intermediates)
	if not player.force.recipes[craft.name].enabled then
		return false
	end
	if need_intermediates then
		local recipe = game.recipe_prototypes[craft.name]

		if need_intermediates then
			for _, ingr in pairs(recipe.ingredients) do
				if (need_intermediates == true or Utils.has_value(need_intermediates, ingr.name)) and player.get_item_count(ingr.name) < ingr.amount then
					return false
				end
			end
		end
	end

	return player.get_craftable_count(craft.name) >= 1
end

-- Chunk optimization
---------------------

Utils.Chunked = {}

function Utils.Chunked.get_entries_close(chunked_data, chunk_size, position)
    local res = {}
	
    local x = math.floor((position.x or position[1]) / chunk_size)
    local y = math.floor((position.y or position[2]) / chunk_size)

    for X = x-1, x+1 do
        for Y = y-1, y+1 do
            for _, entity in pairs(chunked_data[X .. "_" .. Y] or {}) do
                table.insert(res, entity)
            end
        end
    end

    return res
end

function Utils.Chunked.key_from_position(position, chunk_size)
    if not position then game.print(debug.traceback()) end
    return math.floor((position.x or position[1]) / chunk_size) .. "_" .. math.floor((position.y or position[2]) / chunk_size)
end

function Utils.Chunked.get_entry_at(chunked_data, chunk_size, position)
    for _, entity in pairs(chunked_data[Utils.Chunked.key_from_position(position, chunk_size)] or {}) do
        if Utils.sqdistance(entity._position, position) < 0.01 then
            return entity
        end
    end
end

function Utils.Chunked.save_entry_data(chunked_data, chunk_size, position, t)
    for _, entity in pairs(chunked_data[Utils.Chunked.key_from_position(position, chunk_size)] or {}) do
        if Utils.sqdistance(entity._position, position) < 0.01 then
            for k, v in pairs(t) do
                entity[k] = v
            end
			return entity
        end
    end
end

function Utils.Chunked.create_entry(chunked_data, chunk_size, position, entry)
    local key = Utils.Chunked.key_from_position(position, chunk_size)
    if chunked_data[key] then
        table.insert(chunked_data[key], entry)
    else
        chunked_data[key] = {entry}
    end
    entry._index = #chunked_data[key]
	entry._position = position
end

-- Returns wether the chunked table has entries left
function Utils.Chunked.remove_entry(chunked_data, chunk_size, entry)
    if not chunked_data or not entry then
        game.print(debug.traceback())
        error("Called Utils.Chunked.remove_entry with invalid param!")
    end
    local key = Utils.Chunked.key_from_position(entry._position, chunk_size)

    if not chunked_data[key] then game.print(debug.traceback()); error("Attempted to delete entry in chunk that does not exist! Entry: " .. serpent.block(entry)) end
    if not chunked_data[key][entry._index] then game.print(debug.traceback()); error("Attempted to delete entry that does not exist! Entry: " .. serpent.block(entry)) end
    chunked_data[key][entry._index] = nil
    if next(chunked_data[key]) == nil then
        chunked_data[key] = nil
    end
    return (next(chunked_data) ~= nil)
end

function Utils.can_fast_replace(name, position, myplayer)
	local prototype = game.entity_prototypes[name]
	local blocking_entity = Utils.get_entity_from_pos(position, myplayer, prototype.type)
	
	if blocking_entity and game.entity_prototypes[blocking_entity.name].fast_replaceable_group == game.entity_prototypes[name].fast_replaceable_group and name ~= blocking_entity.name then
		return blocking_entity
	end
end


-- Check if a player can place entity.
-- surface is the target surface.
-- entity = {name=..., position=..., direction=..., force=...} is a table that describes the entity we wish to describe
function Utils.can_player_place(surface, entity, myplayer)
	-- local name = entity.name
	-- local position = entity.position
	-- local direction = entity.direction
	-- local force = entity.force or "player"

	local target_collision_box = Utils.collision_box(entity)

	-- Remove Items on ground
	local items = surface.find_entities_filtered {area = target_collision_box, type = "item-entity"}
	local items_saved = {}

	for _, item in pairs(items) do
		table.insert(items_saved, {name = item.stack.name, position = item.position, count = item.stack.count})
		item.destroy()
	end

	-- Check if we can actually place the entity at this tile
	local can_place = surface.can_place_entity(entity)

	-- Put items back.
	for _, item in pairs(items_saved) do
		surface.create_entity {
			name = "item-on-ground",
			position = item.position,
			stack = {name = item.name, count = item.count}
		}
	end
	
	if not can_place then -- maybe we can fast-replace
		if Utils.can_fast_replace(entity.name, entity.position, myplayer) then
			can_place = true
		end
	end
	
	return can_place
end


-- GUI related.
---------------


local function button_handler(event)
	-- local player = game.players[event.player_index]
	local element = event.element
	local button_data = global.Utils.hide_buttons[event.player_index][element.name]
	button_data.show = not button_data.show
	button_data.element.style.visible = button_data.show
end

function Utils.make_hide_button(player, gui_element, show, is_sprite, text)
	global.Utils.hide_buttons = global.Utils.hide_buttons or {}
	global.Utils.hide_buttons[player.index] = global.Utils.hide_buttons[player.index] or {}

	local flow = mod_gui.get_button_flow(player)
	local name = "hide_button_" .. gui_element.name
	local button
	if is_sprite then
		button = flow.add{name=name, type="sprite-button", style="button_style", sprite=text}
	else
		button = flow.add{name=name, type="button", style="button_style", caption=text}		
	end
	global.Utils.hide_buttons[player.index][name] = {
		element = gui_element,
		show = show,
		button = button,
	}

	gui_element.style.visible = show

	GuiEvent.on_click(name, button_handler)
end

function Utils.remove_hide_button(player, gui_element)
	local name = "hide_button_" .. gui_element.name
	local button_data = global.Utils.hide_buttons[player.index][name]
	button_data.button.destroy()
	global.Utils.hide_buttons[player.index][name] = nil
	GuiEvent.remove(defines.events.on_gui_click, name)
end

function Utils.hide_button_info(player, gui_element)
	local name = "hide_button_" .. gui_element.name
	if not global.Utils.hide_buttons or not global.Utils.hide_buttons[player.index] then
		return false
	end
	return global.Utils.hide_buttons[player.index][name]	
end

return Utils