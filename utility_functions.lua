-- Utility functions


-- Tables
----------

function tables_equal(t1, t2)
	return serpent.block(t1) == serpent.block(t2)
end



-- Printing
------------

function debugprint(msg)
	for _, player in pairs(game.connected_players) do
		if player.mod_settings["tas-verbose-logging"].value then 
			player.print("[" .. game.tick - (global.start_tick or 0) .. "] " .. msg)
		end
	end
end

function errprint(msg)
	game.print("[" .. game.tick - (global.start_tick or 0) .. "]  ___WARNING___ " .. msg)
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

function distance_from_rect(pos, rect, closest)
	local posx, posy = get_coordinates(pos)
	
	local rect1x, rect1y = get_coordinates(rect[1])
	local rect2x, rect2y = get_coordinates(rect[2])
	
	local corners = {{rect1x, rect1y}, {rect1x, rect2y}, {rect2x, rect1y}, {rect2x, rect2y}}
	
	-- find the two closest corners to pos and the center
	
	local index = 1
	
	for i,corner in pairs(corners) do
		if sqdistance(corner, pos) < sqdistance(corners[index], pos) then
			index = i
		end
	end
	
	local corner1 = corners[index]
	table.remove(corners, index)
	
	local index = 1
	
	for i,corner in pairs(corners) do
		if sqdistance(corner, pos) < sqdistance(corners[index], pos) then
			index = i
		end
	end
	
	local corner2 = corners[index]
	
	local center = {(rect1x + rect2x)/2, (rect1y + rect2y)/2}
	
	-- find the intersection of the line [corner1, corner2] and [pos, center]
	
	local d = (corner1[1] - corner2[1]) * (posy - center[2]) - (corner1[2] - corner2[2]) * (posx - center[1])
	
	local intersection = {
		(corner1[1] * corner2[2] - corner1[2] * corner2[1]) * (posx - center[1]) - (posx * center[2] - posy * center[1]) * (corner1[1] - corner2[1]),
		(corner1[1] * corner2[2] - corner1[2] * corner2[1]) * (posy - center[2]) - (posx * center[2] - posy * center[1]) * (corner1[2] - corner2[2]),
	}
	
	-- closest is defined this way, so that if passed to the function as a parameter, the closest point will also be returned
	
	if not closest then
		closest = {}
	end
	
	closest[1] = corner1[1]
	closest[2] = corner1[2]
	
	for _,point in pairs({corner2, intersection}) do
		if sqdistance(point, pos) < sqdistance(closest, pos) then
			closest[1] = point[1]
			closest[2] = point[2]
		end
	end
	
	return math.sqrt(sqdistance(closest, pos))
end

function get_coordinates(pos)
	if pos.x then 
		return pos.x, pos.y
	else
		return pos[1], pos[2]
	end
end

function has_value(table, element)
	for _,v in pairs(table) do
		if v == element then
			return true
		end
	end
	
	return false
end

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

function is_entity_at_pos(pos, myplayer)
	local entities = myplayer.surface.find_entities_filtered({area = {{-0.1 + pos[1], -0.1 + pos[2]}, {0.1 + pos[1], 0.1 + pos[2]}}})

	if (not entities) or #entities ~= 1 then
		return false
	else
		return true
	end
end

function get_entity_from_pos(pos, myplayer)
	local entities = myplayer.surface.find_entities_filtered({area = {{-0.1 + pos[1], -0.1 + pos[2]}, {0.1 + pos[1], 0.1 + pos[2]}}})

	if (not entities) or #entities ~= 1 then
		game.print("There is not precisely one entity at this place!")
		return nil
	end
	
	return entities[1]
end