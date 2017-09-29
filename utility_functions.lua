-- Utility functions

if not global.utility_functions then global.utility_functions = {} end
local our_global = global.utility_functions


if not our_global.entity_recipe then our_global.entity_recipe = {} end

-- Tables
----------

-- This can obviously be done better but it works for now.
function tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
end

-- Taken from https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

function has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	return false
end

-- Yep, this is a duplicate.
function in_list(element, list)
	for _, v in pairs(list) do
		if v == element then
			return true
		end
	end
	return false
end

-- list only
function get_minimum_index(list, lessthan_func)
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



-- Printing
------------

function debugprint(msg)
	log_to_ui(msg, "run-debug")
end

function errprint(msg)
	log_to_ui(msg, "tascommand-error")
end



-- Maths and Geometry
----------------------

function roundn(x)
  if not x then game.print(debug.traceback()); error("roundn called without valid parameter.") end
  return math.floor(x + 0.5)
end

-- don't use this function, use in_range instead
-- TODO: remove this function
function inrange(position, myplayer)
  return ((position[1] - myplayer.position.x)^2 + (position[2] - myplayer.position.y)^2) < 36
end

function inside_rect(point, rect)
	local x, y = get_coordinates(point)
	local lower_x, lower_y = get_coordinates(rect[1] or rect.left_top)
	local upper_x, upper_y = get_coordinates(rect[2] or rect.right_bottom)
	return lower_x < x and x < upper_x and lower_y < y and y < upper_y
end

-- rotation for angles multiple of 90°, encoded as 2 for 90°, 4 for 180°, 6 for 270°
function rotate_orthogonal(position, rotation)
	local x, y = get_coordinates(position)
	if not rotation or rotation == 0 then return {x, y}
	elseif rotation == 2 then return {-y, x}
	elseif rotation == 4 then return {-x, -y}
	elseif rotation == 6 then return {y, -x}
	else game.print(debug.traceback()) error("Bad rotation parameter! rotation = " .. printable(rotation)) end
end

function rotate_rect(rect, rotation)
	if not rect then game.print(debug.traceback()) error("Called rotate_rect without rect param!") end
	if not rotation or rotation == 0 then return {rect[1] or rect.left_top, rect[2] or rect.right_bottom} end
	local x1, y1 = get_coordinates(rotate_orthogonal(rect[1] or rect.left_top, rotation))
	local x2, y2 = get_coordinates(rotate_orthogonal(rect[2] or rect.right_bottom, rotation))

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

function translate(position, offset)
	if not offset then return position end
	local x, y = get_coordinates(position)
	local dx, dy = get_coordinates(offset)
	return {x+dx, y+dy}
end

function sqdistance(pos1, pos2)
	if not pos1[1] and not pos1.x then game.print(serpent.block(pos1)) game.print(debug.traceback()) error("Called distance with invalid parameter!") end
	local x1, y1 = get_coordinates(pos1)
	local x2, y2 = get_coordinates(pos2)

	return (x1 - x2)^2 + (y1 - y2)^2
end

-- works for name or entity or table {name, position, direction}
function collision_box(entity)
	if not entity then game.print(debug.traceback()) error("Called collision_box with parameter nil!") end

	local rect = nil
	if type(entity) == "string" then
		return game.entity_prototypes[entity].collision_box
	end
	pcall(function()
		if entity.prototype then
			rect = copy(entity.prototype.collision_box)
		end
	end)
	if not rect then rect = copy(game.entity_prototypes[entity.name].collision_box) end

	-- Note: copy outputs a rect as {left_top=..., right_bottom=...}, rotate_rect handles this and returns {[1]=..., [2]=...}.
	rect = rotate_rect(rect, rotation_stringtoint(entity.direction))

	return {translate(rect[1], entity.position), translate(rect[2], entity.position)}
end

function in_range(command, myplayer)
	return distance_from_rect(myplayer.position, command.rect) <= command.distance
end

-- Works only for axis-aligned rectangles.
function distance_from_rect(pos, rect)
	if not closest then closest = {} end
	local posx, posy = get_coordinates(pos)
	local rect1x, rect1y = get_coordinates(rect[1])
	local rect2x, rect2y = get_coordinates(rect[2])

	-- find the two closest corners to pos and the center
	local corners = {{x=rect1x, y=rect1y}, {x=rect1x, y=rect2y}, {x=rect2x, y=rect1y}, {x=rect2x, y=rect2y}}

	function lt(a, b)
		return sqdistance(a, pos) < sqdistance(b, pos)
	end
	local index, corner1 = get_minimum_index(corners, lt)
	table.remove(corners, index)
	local _, corner2 = get_minimum_index(corners, lt)

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

	return math.sqrt(sqdistance(closest, pos)), closest
end

function distance_rect_to_rect(rect1, rect2)
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

	local min_distance = sqdistance(corners1[1], corners2[1])

	for _,corner1 in pairs(corners1) do
		for _,corner2 in pairs(corners2) do
			local distance = sqdistance(corner1, corner2)

			if distance < min_distance then
				min_distance = distance
			end
		end
	end

	return min_distance
end

function get_coordinates(pos)
	if not pos then game.print(debug.traceback()); error("Trying to access coordinates of invalid point!") end
	if pos.x then
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end



-- String Processing
---------------------

function namespace_prefix(name, command_group)
	if not name then
		return nil
	end

	if not string.find(name, "%.") then
		return command_group .. "." .. name
	else
		return name
	end
end

local direction_ints = {N = 0, NE = 1, E = 2, SE = 3, S = 4, SW = 5, W = 6, NW = 7}
function rotation_stringtoint(rot)
	if type(rot) == "int" then
		return rot
	else
		return direction_ints[rot]
	end
end



-- Surface related
-------------------

function get_entity_from_pos(pos, myplayer, type, epsilon)
	if not pos then game.print(debug.traceback()) end
	local x, y = get_coordinates(pos)

	if not epsilon then
		epsilon = 0.2
	end

	if type == "resource" and x == math.floor(x) then
		x = x + 0.5
		y = y + 0.5
	end

	local types = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler", "resource", "simple-entity", "tree"}

	if type then
		types = {type}
	end

	local x, y = get_coordinates(pos)
	local entity = nil

	for _,ent in pairs(myplayer.surface.find_entities_filtered({area = {{-epsilon + x, -epsilon + y}, {epsilon + x, epsilon + y}}})) do
		if has_value(types, ent.type) then
			entity = ent
		end
	end

	return entity
end



-- Entity related
------------------

-- Note this should only be called for entities that are actually on a surface.
function get_recipe(entity)
	if not entity then game.print(debug.traceback()) error("Trying to access recipe of nil entity!") end
	local x, y = get_coordinates(entity.position)
	local recipe = nil
	pcall(function() recipe = entity.recipe end)
	if entity.type == "furnace" then
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
		return recipe
	else
		error("Called get_recipe for entity without recipe.")
	end
end

function craft_interpolate(entity, ticks)
	local craft_speed = entity.prototype.crafting_speed
	local recipe = get_recipe(entity)
	local energy = game.recipe_prototypes[recipe].energy
	local progress = entity.crafting_progress

	return math.floor((ticks / 60 * craft_speed) / energy + progress)
end
