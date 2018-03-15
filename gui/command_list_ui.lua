local mod_gui = require("mod-gui")

-- luacheck: globals Utils GuiEvent

if not global.system.enable_high_level_commands then return end

local NUM_LINES = 40

local passive_commands = {
	"passive-take",
	"auto-refuel",
	"pickup",
}


CmdUI = {} --luacheck: allow defined top

CmdUI.categories = {
	disabled = {
		check = function(command)
			return command.disabled
		end,
		show_default = false,
		color = {r=0.03, g=0.03, b=0.03, a=1}
	},
	spawned = {
		check = function(command)
			return command.spawned_by ~= nil
		end,
		show_default = true,
		color = {r=0.8, g=0.6, b=0.3, a=1},
	},
	passive = {
		check = function (command)
			return Utils.in_list(command[1], passive_commands)
		end,
		show_default = false,
		color = {r=0.7, g=0.7, b=0.7, a=1},
	},
}

for name, _ in pairs(CmdUI.categories) do
	GuiEvent.on_checked_state_changed("cmd_show_" .. name, function(event)
		-- No closures in factorio-lua!
		local the_name = string.sub(event.element.name, 10)
		global.CmdUI.categories[the_name].show[event.player_index] = event.element.state
	end)
end


global.CmdUI = global.CmdUI or {}
global.CmdUI.ui_hidden = global.CmdUI.ui_hidden or {}
global.CmdUI.categories = global.CmdUI.categories or {}

for name, cfg in pairs(CmdUI.categories) do
	global.CmdUI.categories[name] = global.CmdUI.categories[name] or {
		show = {},
	}
end

function CmdUI.init()
end



function CmdUI.create(player)
	local flow = mod_gui.get_frame_flow(player)
	if not flow.direction == "vertical" then flow.direction = "vertical" end
	local frame = flow.command_list_frame
	if frame and frame.valid then frame.destroy() end
	frame = flow.add{type="frame", name="command_list_frame", direction="vertical"}

	local top_flow = frame.add{type="flow", name="top_flow", direction="horizontal"}
	local title = top_flow.add{type="label", name = "title", caption="Command List"}
	title.style.font = "default-frame"

	--  Checkbox to show/hide expanded view
	local label = top_flow.add{type="label", name = "title_show", caption="[Show]"}
	label.style.left_padding = 40
	local box = top_flow.add{type="checkbox", name="show_command_list_ui_checkbox", state=true}
	box.style.top_padding = 3
	box.style.right_padding = 8

	--  Checkboxes to show/hide categories
	local category_flow = frame.add{type="flow", name="category_flow", direction="horizontal"}
	for name, cfg in pairs(global.CmdUI.categories) do
		if cfg.show[player.index] == nil then cfg.show[player.index] = CmdUI.categories[name].show_default end
		category_flow.add{type="label", name = "title_show_" .. name, caption = "[Show " .. name .. "]"}
		box = category_flow.add{type="checkbox", name="cmd_show_" .. name, state=cfg.show[player.index]}
		box.style.top_padding = 3
		box.style.right_padding = 8
	end

	local group_flow = frame.add{type="flow", name="group_flow", direction="horizontal"}
	label = group_flow.add{type="label", name="current_command_group", caption = "Active Command Group"}
	label.style.font = "default-semibold"
	label.style.top_padding = 4
	local button = group_flow.add{type="button", name="next_command_group", caption="Next Command Group"}
	button.style.top_padding = 0
	button.style.bottom_padding = 0
	button.style.font = "default-semibold"

	label = frame.add{type="label", name="required_for_next", caption = "Required for next"}
	label.style.font = "default-semibold"

	local scroll_pane = frame.add{type="scroll-pane", name="scroll_pane", direction="vertical", caption="foo"}
	local table = scroll_pane.add{type="table", name="table", column_count=1}
	table.style.vertical_spacing = -1
	scroll_pane.style.top_padding = 10
	scroll_pane.style.maximal_height = 350
	scroll_pane.style.maximal_width = 500
	scroll_pane.style.minimal_height = 100
	scroll_pane.style.minimal_width = 50

	for index=1, NUM_LINES do
		label = table.add{type="label", name = "text_" .. index, caption="_", single_line=true, want_ellipsis=true}
		label.style.top_padding = 0
		label.style.bottom_padding = 0
	end

	Utils.make_hide_button(player, frame, true, "virtual-signal/signal-C")
end


function CmdUI.update_command_list_ui(player, command_list)
	if game.tick % math.floor(game.speed * 20 + 1) ~= 0 then return end
	if not command_list then return end
	if not global.command_list_parser.current_command_group_index or not command_list[global.command_list_parser.current_command_group_index] then return end
	local flow = mod_gui.get_frame_flow(player)
	local frame = flow.command_list_frame

	if not global.CmdUI then CmdUI.init() end

	if not frame then
		CmdUI.create(player)
		frame = flow.command_list_frame
	end

	-- Visibility
	local show = frame.top_flow.show_command_list_ui_checkbox.state
	if global.CmdUI.ui_hidden[player.index] ~= not show then
		frame.scroll_pane.style.visible = show
		global.CmdUI.ui_hidden[player.index] = not show
	end


	-- Update
	local current_command_group = command_list[global.command_list_parser.current_command_group_index]
	frame.group_flow.current_command_group.caption = "Active Command Group: " .. current_command_group.name


	local next_command_group = command_list[global.command_list_parser.current_command_group_index + 1]
	if next_command_group then
		if next_command_group.required then
			local s = "Required: | "
			for _, name in ipairs(next_command_group.required) do
				if not global.command_list_parser.finished_named_commands[name] then
					s = s .. name .. " | "
				end
			end
			frame.required_for_next.caption = s
		else
			frame.required_for_next.caption = "Required: <All>"
		end
	else
		frame.required_for_next.caption = "End of Input."
	end


	if not show then return end	

	
	local command_set_index = 0
	for index = 1, NUM_LINES do
		local command
		local valid
		repeat
			command_set_index = command_set_index + 1
			command = global.command_list_parser.current_command_set[command_set_index]
			valid = true
			if not command then 
				valid = false 
			else
				for name, cfg in pairs(global.CmdUI.categories) do
					if not cfg.show[player.index] and CmdUI.categories[name].check(command) then
						valid = false
						break
					end
				end
			end
		until ( (command and not command.finished and valid) 
		or command_set_index > #global.command_list_parser.current_command_set )

		if command then
			local s = "[" .. index .. "] | "
			for key, value in pairs(command) do
				if not Utils.in_list(key, {"data", "action_type", "tested", "rect", "distance", "disabled", "namespace"}) then
					local expression
					if key == "name" then
						expression = command.namespace .. value
					elseif key == "spawned_by" then
						expression = value[1]
						
						if value.name then
							expression = expression .. ": " .. value.namespace .. value.name
						end
					else
						expression = Utils.printable(value)
					end
					
					s = s .. key .. "= " .. expression .. " | "
				end
			end
			local label = frame.scroll_pane.table["text_" .. index]
			label.caption = s
			local set_color = false
			for name, cfg in pairs(global.CmdUI.categories) do
				if cfg.show[player.index] and CmdUI.categories[name].check(command) then
					set_color = true
					label.style.font_color = CmdUI.categories[name].color or {r=1, g=1, b=1, a=1}
					break
				end
			end
			if not set_color then
				label.style.font_color = {r=1, g=1, b=1,a=1}
			end
		else
			frame.scroll_pane.table["text_" .. index].caption = ""
		end
	end
end

function CmdUI.destroy_command_list_ui(player)
	local fr = mod_gui.get_frame_flow(player).command_list_frame
	if fr and fr.valid then fr.destroy() end
end

return CmdUI