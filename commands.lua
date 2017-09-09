-- Initial definitions of shortcuts used by the TAScommands
local directions = {}
directions["STOP"] = {walking = false}
directions["N"] =  {walking = true, direction = defines.direction.north}
directions["E"] =  {walking = true, direction = defines.direction.east}
directions["S"] =  {walking = true, direction = defines.direction.south}
directions["W"] =  {walking = true, direction = defines.direction.west}
directions["NE"] = {walking = true, direction = defines.direction.northeast}
directions["NW"] = {walking = true, direction = defines.direction.northwest}
directions["SE"] = {walking = true, direction = defines.direction.southeast}
directions["SW"] = {walking = true, direction = defines.direction.southwest}

local TAScommands = {}

-- Definitions of the TAScommands

TAScommands["move"] = function (tokens, myplayer)
  debugprint("Moving: " .. tokens[2])
  global.walkstate = directions[tokens[2]]
  if tokens[2] == "STOP" then
    debugprint("Stopped at: (" .. myplayer.position.x .. "," .. myplayer.position.y .. ")")
  end
end

TAScommands["craft"] = function (tokens, myplayer)
  myplayer.begin_crafting{recipe = tokens[2], count = tokens[3] or 1}
  debugprint("Crafting: " .. tokens[2] .. " x" .. (tokens[3] or 1))
end

TAScommands["stopcraft"] = function (tokens, myplayer)
  myplayer.cancel_crafting{index = tokens[2], count = tokens[3] or 1}
  debugprint("Craft abort: Index " .. tokens[2] .. " x" .. (tokens[3] or 1))
end

TAScommands["mine"] = function (tokens, myplayer)
  local position = tokens[2]
  local hasdecimals = false
  if position then
    if position[1] ~= roundn(position[1]) or position[2] ~= roundn(position[2]) then
      hasdecimals = true
    else
      hasdecimals = false
    end
  end

  if not position or hasdecimals then global.minestate = position
  else global.minestate = {position[1] + 0.5, position[2] + 0.5} end

  if position then
    if hasdecimals then debugprint("Mining: Coordinates (" .. position[1] .. "," .. position[2] .. ")")
    else debugprint("Mining: Tile (" .. position[1] .. "," .. position[2] .. ")") end
  else debugprint("Mining: STOP") end
end

TAScommands["build"] = function (tokens, myplayer)
  local item = tokens[2]
  local position = tokens[3]
  local direction = tokens[4]
  debugprint("Building: " .. item .. " on tile (" .. position[1] .. "," .. position[2] .. ")")

  -- Check if we have the item
  if myplayer.get_item_count(item) == 0 then
    errprint("Build failed: No item available")
    return
  end

  -- Check if we are in range to build this
  local target_collision_box = collision_box{name=item, position=position, direction=direction}
  local distance = distance_from_rect(myplayer.position, target_collision_box)
  if not (distance < myplayer.build_distance) then
    errprint("Build failed: You are trying to place beyond realistic reach")
    return
  end


  -- Remove Items on ground
  local items = myplayer.surface.find_entities_filtered{area=target_collision_box, type="item-entity"}
  local items_saved = {}

  for _, _item in pairs(items) do
    table.insert(items_saved, {name=_item.name, position=_item.position, count=_item.stack.count})
    _item.destroy()
  end

  -- Check if we can actually place the item at this tile
  local canplace = myplayer.surface.can_place_entity{
    name = item,
    position = position,
    direction = direction,
    force = "player"
  }
  if not canplace then
    errprint("Build failed: Something is in the way")
    for _, _item in pairs(items_saved) do
      myplayer.surface.create_entity{name=item, position=_item.position, stack={name=_item.name, count=_item.count}}
    end
    return
  end

  -- If no errors, proceed to actually building things
  -- Place the item
  local asm = myplayer.surface.create_entity{name = item, position = position, direction = direction, force="player"}
  -- Remove the placed item from the player (since he has now spent it)
  if asm then
	command_list_parser.add_entity_to_global(asm)
    myplayer.remove_item({name = item, count = 1})

    for _, _item in pairs(items_saved) do
      myplayer.insert_item({name=_item.name, count=_item.count})
    end
  else
    errprint("Build failed: Reason unknown.")
  end

end

TAScommands["put"] = function (tokens, myplayer)
  local position = tokens[2]
  local item = tokens[3]
  local amount = tokens[4]
  local slot = tokens[5]

  myplayer.update_selected_entity(position)

  if not myplayer.selected then
    errprint("Put failed: No object at position {" .. position[1] .. "," .. position[2] .. "}.")
    return
  end

  --[[
  if not inrange(position, myplayer) then
    errprint("Put failed: You are trying to reach too far.")
    return
  end--]]

  local amountininventory = myplayer.get_item_count(item)
  local otherinv = myplayer.selected.get_inventory(slot)
  local toinsert = math.min(amountininventory, amount)

  if toinsert == 0 then
    errprint("Put failed: No items")
    return
  end
  if not otherinv then
	errprint("Put failed : Target doesn't have an inventory at {" .. position[1] .. "," .. position[2] .. "}.")
	return
  end

  local inserted = otherinv.insert{name=item, count=toinsert}

  --if we already failed for trying to insert no items, then if no items were inserted, it must be because it is full
  if inserted == 0 then
    errprint("Put failed: No space at {" .. position[1] .. "," .. position[2] .. "}.")
    return
  end

  myplayer.remove_item{name=item, count = inserted}

  if inserted < amount then
    errprint("Put sub-optimal: Only put " .. inserted .. "x " .. item  .. " instead of " .. amount .. "x " .. item .. " at {" .. position[1] .. "," .. position[2] .. "}.")
  end
  debugprint("Put " .. inserted .. "x " .. item .. " into " .. myplayer.selected.name  .. " at {" .. position[1] .. "," .. position[2] .. "}.")
end

TAScommands["speed"] = function (tokens, myplayer)
  if global.allowspeed then
    game.speed = tokens[2]
    debugprint("Speed: " .. tokens[2])
  else
    errprint("Speed failed : Changing the speed of the run is not allowed. ")
  end
end

TAScommands["take"] = function (tokens, myplayer)
  local position = tokens[2]
  local item = tokens[3]
  local amount = tokens[4]
  local slot = tokens[5]
  myplayer.update_selected_entity(position)

  if not myplayer.selected then
    errprint("Take failed: No object at position {" .. position[1] .. "," .. position[2] .. "}.")
    return
  end

  --[[
  -- Check if we are in reach of this tile
  if not inrange(position, myplayer) then
    errprint("Take failed: You are trying to reach too far.")
    return
  end--]]

  local otherinv = myplayer.selected.get_inventory(slot)

  if not otherinv then
     errprint("Take failed: Unable to access inventories " .. slot)
    return
  end

  local totake = amount
  local amountintarget = otherinv.get_item_count(item)
  if totake == "all" then totake = amountintarget
  else totake = math.min(amountintarget, amount)
  end

  if amountintarget == 0 then
    errprint("Take failed: No items at {" .. position[1] .. "," .. position[2] .. "}.")
    return
  end

  if totake == 0 then
	errprint("Taking 0 items is not allowed!")
	return
  end

  local taken = myplayer.insert{name=item, count=totake}
  debugprint("Took " .. taken .. "x " .. item .. " from " .. myplayer.selected.name  .. " at {" .. position[1] .. "," .. position[2] .. "}.")

  if taken == 0 then
    errprint("Take failed: No space at {" .. position[1] .. "," .. position[2] .. "}.")
    return
  end

  otherinv.remove{name=item, count=taken}

  if amount ~= "all" and taken < amount then
    errprint("Take sub-optimal: Only took " .. taken .. " at {" .. position[1] .. "," .. position[2] .. "}.")
  end

end

TAScommands["tech"] = function (tokens, myplayer)
  myplayer.force.current_research = tokens[2]
  debugprint("Research: " .. tokens[2])
end

TAScommands["print"] = function (tokens, myplayer)
  log_to_ui(tokens[2], "run-output")
  --myplayer.print(tokens[2])
end

TAScommands["recipe"] = function (tokens, myplayer)
  myplayer.update_selected_entity(tokens[2])
  if not myplayer.selected then
	errprint("Setting recipe: Entity at position {" .. tokens[2][1] .. "," .. tokens[2][2] .. "} could not be selected.")
	return
  end
  myplayer.selected.recipe = tokens[3]
  debugprint("Setting recipe: " .. tokens[3] .. " at position {" .. tokens[2][1] .. "," .. tokens[2][2] .. "}.")
end

TAScommands["rotate"] = function (tokens, myplayer)
  local position = tokens[2]
  local direction = tokens[3]

  myplayer.update_selected_entity(position)

  if not myplayer.selected then
    errprint ("Rotate failed, no object at position {" .. position[1] .. "," .. position[2] .. "}")
  end

  myplayer.selected.direction = directions[direction]
  debugprint("Rotating " .. myplayer.selected.name  .. " so that it faces " .. direction .. ".")
end

TAScommands["phantom"] = function (tokens, myplayer)
end


TAScommands["pickup"] = function (tokens, myplayer)
  local pos = myplayer.position
  local r = myplayer.item_pickup_distance
  local area = {{pos.x - r, pos.y - r}, {pos.x + r, pos.y + r}}
  local items = myplayer.surface.find_entities_filtered{area=area, type="item-entity"}

  if #items > 0 then
	debugprint("Picking up items (at position {" .. myplayer.position.x .. ", " .. myplayer.position.y .. "}).")
  end

  for _, item in pairs(items) do
    local stack = item.stack
    local totake = stack.count
    local taken = myplayer.insert{name=stack.name, count=totake}

    if taken < totake then errprint("Pickup failed, inventory full!") end

    item.destroy()
  end
end

return TAScommands
