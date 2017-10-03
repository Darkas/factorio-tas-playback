require("mod-gui")

NUM_LINES = 40
--[[

--]]

local passive_commands = {
	"passive-take",
	"auto-refuel",
	"pickup",
}


function init_command_list_ui()
	if global.command_list_ui then return end
	global.command_list_ui = {}
	global.command_list_ui.ui_hidden = {}

end

function create_command_list_ui(player)
	local flow = mod_gui.get_frame_flow(player)
	if not flow.direction == "vertical" then flow.direction = "vertical" end
	local frame = flow.command_list_frame
	if frame and frame.valid then frame.destroy() end
	frame = flow.add{type="frame", name="command_list_frame", style="frame_style", direction="vertical"}

	local top_flow = frame.add{type="flow", name="top_flow", style="flow_style", direction="horizontal"}
	local title = top_flow.add{type="label", style="label_style", name = "title", caption="Command List"}
	title.style.font = "default-frame"

	local label = top_flow.add{type="label", style="label_style", name = "title_show", caption="                    [Show]"}
	top_flow.add{type="checkbox", name="show_command_list_ui_checkbox", state=true}
	local label = top_flow.add{type="label", style="label_style", name = "title_show_passive", caption="[Show Passive]"}
	top_flow.add{type="checkbox", name="show_passive_button", state=true}

	local group_flow = frame.add{type="flow", name="group_flow", style="flow_style", direction="horizontal"}
	label = group_flow.add{type="label", style="label_style", name="current_command_group", caption = "Active Command Group"}
	label.style.font = "default-semibold"
	local button = group_flow.add{type="button", style="button_style", name="next_command_group", caption="Next Command Group"}
	button.style.top_padding = 0
	button.style.bottom_padding = 0
	button.style.font = "default-semibold"

	label = frame.add{type="label", style="label_style", name="required_for_next", caption = "Required for next"}
	label.style.font = "default-semibold"

	local scroll_pane = frame.add{type="scroll-pane", name="scroll_pane", style="scroll_pane_style", direction="vertical", caption="foo"}
	local table = scroll_pane.add{type="table", name="table", style="table_style", colspan=1}
	table.style.vertical_spacing = -1
	scroll_pane.style.top_padding = 10
	scroll_pane.style.maximal_height = 350
	scroll_pane.style.maximal_width = 500
	scroll_pane.style.minimal_height = 100
	scroll_pane.style.minimal_width = 50

	for index=1, NUM_LINES do
		label = table.add{type="label", style="label_style", name = "text_" .. index, caption="_", single_line=true, want_ellipsis=true}
		label.style.top_padding = 0
		label.style.bottom_padding = 0
		--label.style.font_color = {r=1.0, g=0.7, b=0.9}

	end
end


function update_command_list_ui(player, command_list)
	if not command_list then return end
	if not global.command_list_parser.current_command_group_index or not command_list[global.command_list_parser.current_command_group_index] then return end
	local flow = mod_gui.get_frame_flow(player)
	local frame = flow.command_list_frame

	if not global.command_list_ui then init_command_list_ui() end

	if not frame then
		create_command_list_ui(player)
		frame = flow.command_list_frame
	end

	-- Visibility
	local show = frame.top_flow.show_command_list_ui_checkbox.state
	if global.command_list_ui.ui_hidden[player.index] ~= not show then
		frame.scroll_pane.style.visible = show
		--frame.type_flow.style.visible = show
		global.command_list_ui.ui_hidden[player.index] = not show
	end

	-- Scheduling
	if game.tick % math.floor(game.speed * 20 + 1) ~= 0 then return end
	if not command_list then return end


	-- Update
	if show then
		local show_passive_commands = frame.top_flow.show_passive_button.state
		local current_command_group = command_list[global.command_list_parser.current_command_group_index]
		frame.group_flow.current_command_group.caption = "Active Command Group: " .. current_command_group.name

		local next_command_group = command_list[global.command_list_parser.current_command_group_index + 1]
		if next_command_group then
			if next_command_group.required then
				local s = ""
				for _, name in ipairs(next_command_group.required) do
					if not global.command_list_parser.finished_command_names[name] then
						s = s .. name .. " | "
					end
				end
				frame.required_for_next.caption = "Required: | " .. s
			else
				frame.required_for_next.caption = "Required: <All>"
			end
		else
			frame.required_for_next.caption = "End of Input."
		end

		local command_set_index = 1
		for index = 1, NUM_LINES do
			local command
			repeat
				command = global.command_list_parser.current_command_set[command_set_index]
				command_set_index = command_set_index + 1
			until (command and not command.finished and (show_passive_commands or not in_list(command[1], passive_commands))) or command_set_index > #global.command_list_parser.current_command_set

			if command and not command.finished then
				s = "[" .. index .. "] | "
				for key, value in pairs(command) do
					if not in_list(key, {"data", "action_type", "tested", "rect", "distance"}) then
						s = s .. key .. "= " .. printable(value) .. " | "
					end
				end
				frame.scroll_pane.table["text_" .. index].caption = s
			else
				frame.scroll_pane.table["text_" .. index].caption = ""
			end
		end
	end
end

function destroy_command_list_ui(player)
	local fr = mod_gui.get_frame_flow(player).command_list_frame
	if fr and fr.valid then fr.destroy() end
end
