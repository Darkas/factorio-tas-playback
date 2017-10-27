
-- luacheck: globals Utils LogUI
-- luacheck: ignore 212

-- Initial definitions of shortcuts used by the TAScommands
local directions = {}
directions["STOP"] = {walking = false}
directions["N"] = {walking = true, direction = defines.direction.north}
directions["E"] = {walking = true, direction = defines.direction.east}
directions["S"] = {walking = true, direction = defines.direction.south}
directions["W"] = {walking = true, direction = defines.direction.west}
directions["NE"] = {walking = true, direction = defines.direction.northeast}
directions["NW"] = {walking = true, direction = defines.direction.northwest}
directions["SE"] = {walking = true, direction = defines.direction.southeast}
directions["SW"] = {walking = true, direction = defines.direction.southwest}

local TAScommands = {}

-- Definitions of the TAScommands

TAScommands["move"] = function(tokens, myplayer)
    LogUI.debugprint("Moving: " .. tokens[2])
    global.walkstate = directions[tokens[2]]
    if tokens[2] == "STOP" then
        LogUI.debugprint("Stopped at: (" .. myplayer.position.x .. "," .. myplayer.position.y .. ")")
    end
end

TAScommands["craft"] = function(tokens, myplayer)
    myplayer.begin_crafting {recipe = tokens[2], count = tokens[3] or 1}
    LogUI.debugprint("Crafting: " .. tokens[2] .. " x" .. (tokens[3] or 1))
end

TAScommands["stopcraft"] = function(tokens, myplayer)
    myplayer.cancel_crafting {index = tokens[2], count = tokens[3] or 1}
    LogUI.debugprint("Craft abort: Index " .. tokens[2] .. " x" .. (tokens[3] or 1))
end

TAScommands["mine"] = function(tokens, myplayer)
    local position = tokens[2]
    local hasdecimals = false
    if position then
        if position[1] ~= Utils.roundn(position[1]) or position[2] ~= Utils.roundn(position[2]) then
            hasdecimals = true
        else
            hasdecimals = false
        end
    end

    if not position or hasdecimals then
        global.minestate = Utils.copy(position)
    else
        global.minestate = {position[1] + 0.5, position[2] + 0.5}
    end

    if position then
        if hasdecimals then
            LogUI.debugprint("Mining: Coordinates (" .. position[1] .. "," .. position[2] .. ")")
        else
            LogUI.debugprint("Mining: Tile (" .. position[1] .. "," .. position[2] .. ")")
        end
    else
        LogUI.debugprint("Mining: STOP")
    end
end

TAScommands["build"] =
    function(tokens, myplayer)
    local item = tokens[2]
    local position = tokens[3]
    local direction = tokens[4]

    LogUI.debugprint("Building: " .. item .. " on tile (" .. position[1] .. "," .. position[2] .. ")")

    -- Check if we have the item
    if myplayer.get_item_count(item) == 0 then
        LogUI.errprint("Build failed: No item available")
        return
    end

    -- Check if we are in range to build this
    local target_collision_box = Utils.collision_box {name = item, position = position, direction = direction}
    local distance = Utils.distance_from_rect(myplayer.position, target_collision_box)
    if not (distance <= myplayer.build_distance) then
        LogUI.errprint("Build failed: You are trying to place beyond realistic reach")
        return
    end

    -- Remove Items on ground
    local items = myplayer.surface.find_entities_filtered {area = target_collision_box, type = "item-entity"}
    local items_saved = {}

    for _, _item in pairs(items) do
        table.insert(items_saved, {name = _item.stack.name, position = _item.position, count = _item.stack.count})
        _item.destroy()
    end

    -- Check if we can actually place the item at this tile

    local entity = {
        name = item,
        position = position,
        direction = direction, 
        force = "player",
        surface = myplayer.surface,
    }

    local canplace, replace = Utils.can_player_place(myplayer, entity)
    	
    if not canplace then
        LogUI.errprint(
            "Building " .. item .. " failed: Something is in the way at {" .. position[1] .. ", " .. position[2] .. "}."
        )
        for _, _item in pairs(items_saved) do
            myplayer.surface.create_entity {
                name = "item-on-ground",
                position = _item.position,
                stack = {name = _item.name, count = _item.count}
            }
        end
        return
    end
	
	
    -- If no errors, proceed to actually building things
    -- Place the item
    entity.fast_replace = replace
    entity.force = "player"
    entity.player = myplayer
    if item == "underground-belt" and tokens[5] then
        entity.type = tokens[5]
    end
    local created = myplayer.surface.create_entity(entity)
    -- Remove the placed item from the player (since he has now spent it)
    if created and created.valid then
        if command_list_parser then
            command_list_parser.add_entity_to_global(created)
        end
        myplayer.remove_item({name = item, count = 1})

        for _, _item in pairs(items_saved) do
            myplayer.insert({name = _item.name, count = _item.count})
        end
    else
        LogUI.errprint("Build failed: Reason unknown.")
    end
end

TAScommands["enter-vehicle"] = function(tokens, myplayer)
    myplayer.driving = true
    if not myplayer.driving then
        LogUI.errprint("Entering vehicle failed! Player at " .. serpent.block(myplayer.position))
    end
end

TAScommands["leave-vehicle"] = function(tokens, myplayer)
    myplayer.driving = false
end

TAScommands["riding-state"] = function(tokens, myplayer)
    myplayer.riding_state = tokens[2]
end

TAScommands["put"] =
    function(tokens, myplayer)
    local position = tokens[2]
    local item = tokens[3]
    local toinsert = tokens[4]
    local slot = tokens[5]

    myplayer.update_selected_entity(position)

    if not myplayer.selected then
        LogUI.errprint("Put failed: No object at position {" .. position[1] .. "," .. position[2] .. "}.")
        return
    end

    --[[
  if not inrange(position, myplayer) then
    errprint("Put failed: You are trying to reach too far.")
    return
  end--]]
    local otherinv = myplayer.selected.get_inventory(slot)
	
	if myplayer.get_item_count(item) < toinsert then
        LogUI.errprint("Put failed: Not enough items {" .. position[1] .. "," .. position[2] .. "}.")
        return
	end

    if toinsert == 0 then
        LogUI.errprint("Put failed: Trying to insert 0 items at {" .. position[1] .. "," .. position[2] .. "}.")
        return
    end
    if not otherinv then
        LogUI.errprint(
            "Put failed : Target doesn't have an inventory at {" .. position[1] .. "," .. position[2] .. "}."
        )
        return
    end

    local inserted = otherinv.insert {name = item, count = toinsert}

    --if we already failed for trying to insert no items, then if no items were inserted, it must be because it is full
    if inserted == 0 then
        LogUI.errprint("Put failed: No space at {" .. position[1] .. "," .. position[2] .. "}.")
        return
    end

    myplayer.remove_item {name = item, count = inserted}

    if inserted < toinsert then
        LogUI.errprint(
            "Put sub-optimal: Only put " ..
                inserted ..
                    "x " ..
                        item ..
                            " instead of " ..
                                toinsert .. "x " .. item .. " at {" .. position[1] .. "," .. position[2] .. "}."
        )
    end
    LogUI.debugprint(
        "Put " ..
            inserted ..
                "x " ..
                    item .. " into " .. myplayer.selected.name .. " at {" .. position[1] .. "," .. position[2] .. "}."
    )
end

TAScommands["speed"] = function(tokens, myplayer)
    if global.allowspeed then
        game.speed = tokens[2]
        LogUI.debugprint("Speed: " .. tokens[2])
    else
        LogUI.errprint("Speed failed : Changing the speed of the run is not allowed. ")
    end
end

TAScommands["take"] =
    function(tokens, myplayer)
    local position = tokens[2]
    local item = tokens[3]
    local amount = tokens[4]
    local slot = tokens[5]
    myplayer.update_selected_entity(position)

    if not myplayer.selected then
        LogUI.errprint("Take failed: No object at position {" .. position[1] .. "," .. position[2] .. "}.")
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
        LogUI.errprint("Take failed: Unable to access inventories " .. slot)
        return
    end

    local totake = amount
    local amountintarget = otherinv.get_item_count(item)
    if totake == "all" then
        totake = amountintarget
    else
        totake = math.min(amountintarget, amount)
    end

    if amountintarget == 0 then
        LogUI.errprint("Take failed: No items at {" .. position[1] .. "," .. position[2] .. "}.")
        return
    end

    if totake == 0 then
        LogUI.errprint("Taking 0 items is not allowed!")
        return
    end

    local taken = myplayer.insert {name = item, count = totake}
    LogUI.debugprint(
        "Took " ..
            taken ..
                "x " ..
                    item .. " from " .. myplayer.selected.name .. " at {" .. position[1] .. "," .. position[2] .. "}."
    )

    if taken == 0 then
        LogUI.errprint("Take failed: No space at {" .. position[1] .. "," .. position[2] .. "}.")
        return
    end

    otherinv.remove {name = item, count = taken}

    if amount ~= "all" and taken < amount then
        LogUI.errprint("Take sub-optimal: Only took " .. taken .. " at {" .. position[1] .. "," .. position[2] .. "}.")
    end
end

TAScommands["tech"] = function(tokens, myplayer)
    myplayer.force.current_research = tokens[2]
    LogUI.debugprint("Research: " .. tokens[2])
end

TAScommands["print"] = function(tokens, myplayer)
    LogUI.log_to_ui(tokens[2], "run-output")
    --myplayer.print(tokens[2])
end

TAScommands["recipe"] =
    function(tokens, myplayer)
    myplayer.update_selected_entity(tokens[2])
    if not myplayer.selected then
        LogUI.errprint(
            "Setting recipe: Entity at position {" .. tokens[2][1] .. "," .. tokens[2][2] .. "} could not be selected."
        )
        return
    end
    local ent =
        myplayer.surface.create_entity {
        name = myplayer.selected.name,
        position = {100000, 100000},
        force = "player",
        recipe = tokens[3]
    }
    local items = myplayer.selected.copy_settings(ent)
    ent.destroy()
    if items then
        for name, count in pairs(items) do
            myplayer.insert {name = name, count = count}
        end
    end
    LogUI.debugprint("Setting recipe: " .. tokens[3] .. " at position {" .. tokens[2][1] .. "," .. tokens[2][2] .. "}.")
end

TAScommands["rotate"] = function(tokens, myplayer)
    local position = tokens[2]
    local direction = tokens[3]

    myplayer.update_selected_entity(position)

    if not myplayer.selected then
        LogUI.errprint("Rotate failed, no object at position {" .. position[1] .. "," .. position[2] .. "}")
    end

    myplayer.selected.direction = directions[direction].direction
    LogUI.debugprint("Rotating " .. myplayer.selected.name .. " so that it faces " .. direction .. ".")
end

TAScommands["phantom"] = function(tokens, myplayer)
end

TAScommands["pickup"] = function(tokens, myplayer)
    if tokens[2] == true or tokens[2] == false then
        global.pickstate = tokens[2]
    else
        myplayer.picking_state = true
    end
end

TAScommands["enable-manual-walking"] = function(tokens, myplayer)
    global.enable_manual_walking = true
end

TAScommands["throw-grenade"] = function(tokens, myplayer)
    -- We could generalize this to arbitrary capsules but then we'd have to parse through item.capsule_action
    local target = tokens[2]

    if myplayer.get_item_count("grenade") < 1 then
        LogUI.errprint("Throw Grenade failed! No grenade item in inventory. ")
        return
    end

    -- TODO: Is this < or <=?
    if global.last_grenade_throw and game.tick - global.last_grenade_throw < 30 then
        LogUI.errprint("Throw Grenade failed! Grenade is not off cooldown yet. ")
        return
    end

    if Utils.sqdistance(target, myplayer.position) > 15 ^ 2 then
        LogUI.errprint("Throw Grenade failed! Not in throwing distance. ")
    end

    -- Interpolate for projectile_creation_distance.
    local grenade_spawn
    if Utils.sqdistance(myplayer.position, target) < 0.6 then
        grenade_spawn = target
    else
        local origin_x, origin_y = Utils.get_coordinates(myplayer.position)
        local target_x, target_y = Utils.get_coordinates(target)
        local direction_x, direction_y = target_x - origin_x, target_y - origin_y
        local norm = math.sqrt(direction_x ^ 2 + direction_y ^ 2)
        grenade_spawn = {origin_x + direction_x / norm * 0.6, origin_y + direction_y / norm * 0.6}
    end

    myplayer.surface.create_entity {name = "grenade", position = grenade_spawn, target = target, speed = 0.3}
    myplayer.remove_item({name = "grenade", count = 1})
end

return TAScommands
