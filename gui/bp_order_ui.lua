
local mod_gui = require("mod-gui")

-- luacheck: globals Utils GuiEvent
BPUI = {} --luacheck: allow defined top
local Utils = require('../utility_functions')

global.BPUI = global.BPUI or {}

function BPUI.create(player)
    local flow = mod_gui.get_frame_flow(player)
    local frame = flow.add{type="frame", name="bp_order_ui_frame", style="frame_style", direction = "vertical", caption = "Blueprint Order Editor"}
    frame.add{type="label", name="label", style="label_style", caption="Blueprint Order UI output."}
    frame.style.visible = true

    local button_flow = frame.add{type="flow", name="button_flow", style="flow_style", direction="horizontal"}
    button_flow.add{type="sprite-button", name="build_order_ui_prev", style=mod_gui.button_style, sprite="tas_playback_prev"}
    button_flow.add{type="sprite-button", name="build_order_ui_save", style=mod_gui.button_style, sprite="tas_playback_save"}
    --button_flow.add{type="sprite-button", name="build_order_ui_undo", style=mod_gui.button_style, sprite="tas_playback_undo"}
    button_flow.add{type="sprite-button", name="build_order_ui_next", style=mod_gui.button_style, sprite="tas_playback_next"}
	Utils.make_hide_button(player, frame, true, "virtual-signal/signal-B")
end


function BPUI.update(player)
    local flow = mod_gui.get_frame_flow(player)
    if not flow.bp_order_ui_frame then return end

    if game.tick % math.floor(game.speed * 20 + 1) ~= 0 then return end

    local frame = flow.bp_order_ui_frame
    if not frame.style.visible then return end

    local bp_order_data = global.high_level_commands.bp_order_record
    if not bp_order_data then frame.style.visible = false return end

    local label = flow.bp_order_ui_frame.label
    local output = "Stage: " .. bp_order_data.stage_index .. ", Saved Entities: " .. bp_order_data.stage_lengths[bp_order_data.stage_index]
    label.caption = output
end

Event.register(defines.events.on_tick, function()
    for _, pl in pairs(game.players) do 
        BPUI.update(pl)
    end
end)

function BPUI.destroy(player)
    local fr = mod_gui.get_frame_flow(player).bp_order_ui_frame
    if fr and fr.valid then fr.destroy() end
end


return BPUI

