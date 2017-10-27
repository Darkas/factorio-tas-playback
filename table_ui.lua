local GuiEvent = require("stdlib/event/gui")
local Event = require("stdlib/event/event")
local Utils = require("utility_functions")


local TableUI = {}
global.TableUI = global.TableUI or { }

local NUM_LINES = 200

Event.register(defines.events.on_tick, function()
    for _, player in pairs(game.players) do
        TableUI.update(player)
    end
end)


function TableUI.add_table(name, t)
    global.TableUI.the_table = global.TableUI.the_table or {}
    global.TableUI.the_table[name] = t
end

function TableUI.remove_table(name)
    global.TableUI.the_table[name] = nil
end

function TableUI.create(player)
    global.TableUI.the_table = global.TableUI.the_table or {}

    global.TableUI[player.index] = { showed_elements = {}, line_data = {}, show_ui = true, need_update = false}
    local flow = player.gui.center
    local frame = flow.add{name="tableui_frame", type="frame", direction="vertical", style="frame_style"}
	local scroll_pane = frame.add{type="scroll-pane", name="scroll_pane", style="scroll_pane_style", direction="vertical"}
	local table = scroll_pane.add{type="table", name="table", style="table_style", colspan=1}
	table.style.vertical_spacing = 0
	scroll_pane.style.maximal_height = 800
	scroll_pane.style.maximal_width = 800
	scroll_pane.style.minimal_height = 800
    scroll_pane.style.minimal_width = 800
    
    Utils.make_hide_button(player, frame, false, false, "Table Dbg")
end

function TableUI.get_line(player, line_index)
    if line_index > NUM_LINES then return nil end
    local line_table = player.gui.center.tableui_frame.scroll_pane.table
    if line_table["tableui_line_" .. line_index] then 
        return line_table["tableui_line_" .. line_index]
    else
        return line_table.add{type="label", caption="--", style="label_style", name="tableui_line_" .. line_index}
    end
end

local function descend(table, keys, stop_before)
    local t = table
    for i = 1, #keys - (stop_before or 0) do
        local k = keys[i]
        if t[k] then 
            t = t[k]
        else
            return nil
        end
    end
    return t
end


function TableUI.update(player)
    if not global.TableUI.the_table then return end
    local flow = player.gui.center
    local player_ui_data = global.TableUI[player.index]
    
    if not player_ui_data then 
        TableUI.create(player)
        player_ui_data = global.TableUI[player.index]
    elseif not flow.tableui_frame and player_ui_data.show_ui then
        TableUI.create(player)
    end
    

    if player_ui_data.show_ui == flow.tableui_frame.style.visible then 
        flow.tableui_frame.style.visible = player_ui_data.show_ui
    end


	if not player_ui_data.show_ui or not player_ui_data.need_update and game.tick % math.floor(game.speed * 20 + 1) ~= 0 then return end
    player_ui_data.need_update = false


    local line_index = 1
    local stack = {{global.TableUI.the_table, {}}}
    local t
    local context
    while true do
        local node = stack[#stack]
        if not node then break end
        t = node[1]
        context = node[2]
        stack[#stack] = nil

        local line = TableUI.get_line(player, line_index)
        if not line then break end

        local output_string = ""
        for i = 1, #context do
            output_string = output_string .. "        "
        end

        if descend(player_ui_data.showed_elements, context) then
            output_string = output_string .. "▼   "
        else
            local tab = descend(global.TableUI.the_table, context)
            local found_table = false
            for _, v in pairs(tab) do
                if type(v) == "table" and not Utils.is_position(v) then
                    found_table = true
                    break
                end
            end
            if found_table then
                output_string = output_string .. "▶   "
            else
                output_string = output_string .. "        "
            end
        end

        if not next(context) then 
            output_string = output_string .. "Root: " 
        else
            output_string = output_string .. context[#context] .. ": "
        end


        for k, v in pairs(t) do
            if type(v) == "table" and not Utils.is_position(v) then
                local new_context = Utils.copy(context)
                table.insert(new_context, k)
                if descend(player_ui_data.showed_elements, context) then
                    table.insert(stack, {v, new_context})
                end
            else
                output_string = output_string .. Utils.printable(k) .. "= " .. Utils.printable(v) .. "  "
            end
        end
        line.caption = output_string
        player_ui_data.line_data[line_index] = { Utils.copy(context) }
        line_index = line_index + 1        
    end

    while player_ui_data.line_data[line_index] do
        player_ui_data.line_data[line_index] = nil
        local line = TableUI.get_line(player, line_index)
        line.caption = ""
        line_index = line_index + 1
    end
end



function TableUI.destroy(player)
    local flow = player.gui.center
    flow.tableui_frame.destroy()
end



local function expandNode(event)
    local player = game.players[event.player_index]
    local player_ui_data = global.TableUI[player.index]
    local line = event.element
    local the_table = global.TableUI.the_table
    player_ui_data.need_update = true
    local line_num = tonumber(string.sub(line.name, 14)) -- tableui_line_###
    local line_data = player_ui_data.line_data[line_num]

    if not line_data or line_num == 1 then return end

    local context = line_data[1]
    local t = descend(the_table, context)
    local show_t = descend(player_ui_data.showed_elements, context)

    local table_found = false

    for _, v in pairs(t) do
        if type(v) == "table" then
            table_found = true
            break
        end
    end

    if not table_found then return end


    if #context >= 1 then
        if show_t then 
            local parent = descend(player_ui_data.showed_elements, context, 1)
            parent[context[#context]] = nil
        else
            local parent = descend(player_ui_data.showed_elements, context, 1)
            parent[context[#context]] = {}
        end
    end
end


GuiEvent.on_click("tableui_line_.*", expandNode)




return TableUI