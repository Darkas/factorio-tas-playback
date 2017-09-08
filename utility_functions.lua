-- Utility functions

if not global.utility_functions then global.utility_functions = {} end
local our_global = global.utility_functions

-- Tables
----------

function tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
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
	-- for _, player in pairs(game.connected_players) do
	-- 	if player.mod_settings["tas-verbose-logging"].value then 
	-- 		-- player.print("[" .. game.tick - (global.start_tick or 0) .. "] " .. msg)
	-- 	end
	-- end
end

function errprint(msg)
	log_to_ui(msg, "tascommand-error")
	--game.print("[" .. game.tick - (global.start_tick or 0) .. "]  ___WARNING___ " .. msg)
end



-- Maths and Geometry
----------------------

function roundn(x)
  return math.floor(x + 0.5)
end

function inrange(position, myplayer)
  return ((position[1] - myplayer.position.x)^2 + (position[2] - myplayer.position.y)^2) < 36
end

function sqdistance(pos1, pos2)
	local x1, y1 = get_coordinates(pos1)
	local x2, y2 = get_coordinates(pos2)

	return (x1 - x2)^2 + (y1 - y2)^2
end

function move_collision_box(collision_box, coords)
	local x,y = get_coordinates(coords)
	return {{collision_box.left_top.x + x, collision_box.left_top.y + y}, {collision_box.right_bottom.x + x, collision_box.right_bottom.y + y}}
end

function in_range(command, myplayer)
	return distance_from_rect(myplayer.position, command.rect) <= command.distance
end

-- Works only for axis-aligned rectangles.
function distance_from_rect(pos, rect, closest)
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
	
	-- Set closest point on rectangle
	if corner1.x == corner2.x then
		closest[1] = corner1.x
		if corner1.y > corner2.y then corner1, corner2 = corner2, corner1 end
		if posy < corner1.y then closest[2] = corner1.y
		elseif posy > corner2.y then closest[2] = corner2.y
		else closest[2] = posy end
	else
		closest[2] = corner1.y
		if corner1.x > corner2.y then corner1, corner2 = corner2, corner1 end
		if posx < corner1.x then closest[1] = corner1.x
		elseif posx > corner2.x then closest[1] = corner2.x
		else closest[1] = posx end
	end
	
	return math.sqrt(sqdistance(closest, pos)), closest
end

function get_coordinates(pos)
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



-- Surface related
-------------------

function get_entity_from_pos(pos, myplayer, type, epsilon)
	if not epsilon then
		epsilon = 0.2
	end
	
	local types = {"furnace", "assembling-machine", "container", "car", "cargo-wagon", "mining-drill", "boiler", "resource", "simple-entity"}
	
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

function get_recipe(entity)
	local x, y = get_coordinates(entity.position)
	local recipe = pcall(function(ent) return ent.recipe end)
	if ent.type == "furnace" then
		if recipe then our_global.entity_recipe[x .. "_" .. y] = recipe.name; return recipe.name end
		if our_global.entity_recipe[x .. "_" .. y] then return our_global.entity_recipe[x .. "_" .. y] end
		if ent.get_output_inventory()[1] then 
			return ent.get_output_inventory()[1].name 
		else
			return nil
		end
	elseif ent.type == "assembling-machine" then
		return recipe
	else 
		errprint("Trying to get recipe of entity without recipe.")
	end
end

function craft_interpolate(entity, ticks)
	local craft_speed = entity.prototype.crafting_speed
	local recipe = get_recipe(entity)
	local progress = entity.crafting_progress
	return math.floor((progress + ticks * craft_speed) / recipe.energy)
end
