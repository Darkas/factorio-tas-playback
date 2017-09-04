require("mod-gui")


-- TODO: Do we need this to be more efficient?

--[[ 

Usage
Init logging system by init_logging()
Regularly call update_log_ui for relevant players
You can configure log types via configure_log_type.
Add a log message by log_to_ui.

Each log message has an associated log type, which allows filtering based on log type. 
Each log type can have an associated formatter function which allows postprocessing the message, for example to add the current tick or the log category. A log type can also make changes to the style of its messages
--]]

MAX_LOG_TYPE_SIZE = 50
NUM_LOG_LINES = 50

-- log_to_ui
-- text: message content
-- type_name: log type
-- data (optional): additional argument that is passed to the formatter function of a log type, if it is set.
function log_to_ui(text, type_name, data)
	-- Defaults
	if not type_name then type_name = "debug" end


	-- Add message to log
	if not global.log_data.log_messages[type_name] then global.log_data.log_messages[type_name] = {} end
	local type_messages = global.log_data.log_messages[type_name]

	if not type_messages[game.tick] then type_messages[game.tick] = {} end

	if not global.log_data.log_type_settings[type_name] then configure_log_type(type_name) end
	local type_settings = global.log_data.log_type_settings[type_name]

	local display_text = type_settings.message_formatter(text, data, game.tick, type_settings.data)
	type_messages[game.tick][#type_messages[game.tick] + 1] = {text=text, data=data, type_name = type_name, display_text=display_text, tick=game.tick}

	-- Save number of messages per log type.
	type_settings.log_size = type_settings.log_size + 1 

	-- Delete something if we have too many messages of the type.
	if type_settings.log_size > (type_settings.max_log_size or MAX_LOG_TYPE_SIZE) then 
		local tick = game.tick

		for t, messages in pairs(type_messages) do
			if t < tick then
				tick = t
			end
		end
		-- Actual deletion
		table.remove(type_messages[tick], 1) 
		if #type_messages[tick] == 0 then type_messages[tick] = nil end
		type_settings.log_size = type_settings.log_size  - 1 
	end

	global.log_data.need_update = true
end

-- configure_log_type
-- type_name: 
-- style (optional): style arguments that are set for the display style of the log messages. For example {font_color = {r=1, g=0.2, b=0.2}, font = "default-bold"}
-- max_size (optional): maximum number of log messages for this type that will be saved. We delete the oldest message first. Default is 50.
-- message_formatter (optional): formatter function that determines the actually shown text for each logged message. message_formatter(text, data, game_tick, type_settings_data). Default format is '[<type_name> | <game_tick>] <text>'.
-- data (optional): type-global argument for formatter function
function configure_log_type(type_name, style, max_size, message_formatter, data)
	if not global.log_data.log_type_settings[type_name] then global.log_data.log_type_settings[type_name] = {log_size = 0} end
	if not global.log_data.log_messages[type_name] then
		global.log_data.log_messages[type_name] = {}
	end

	local t = global.log_data.log_type_settings[type_name]
	t.message_formatter = message_formatter or t.message_formatter or function(text, data, game_tick) return "[" .. type_name .. " | " .. game_tick .. "] " .. text end
	t.max_log_size = max_size or t.max_log_size or 50
	t.data = data or t.data
	t.style = style or t.style
end

-- Init function that needs to be called before logging can be started.
function init_logging()
	if not global.log_data then 
		-- UI
		global.log_data = {}
		global.log_data.ui_paused = {}

		-- content
		global.log_data.log_messages = {}
		global.log_data.log_type_settings = {}
	end
end


-- create_log_ui
-- is called automatically when update_log_ui(player) is called
function create_log_ui(player)
	local flow = mod_gui.get_frame_flow(player)
	local frame = flow.log_frame
	if frame and frame.valid then frame.destroy() end
	frame = flow.add{type="frame", name="log_frame", style="frame_style", direction="vertical"}

	local top_flow = frame.add{type="flow", name="top_flow", style="flow_style", direction="horizontal"}
	local title = top_flow.add{type="label", style="label_style", name = "title", caption="Log"}
	title.style.font = "default-frame"
	top_flow.add{type="label", style="label_style", name = "title_show", caption="                    [Show]"}
	top_flow.add{type="checkbox", name="show_checkbox", state=true}

	local scroll_pane = frame.add{type="scroll-pane", name="scroll_pane", style="scroll_pane_style", direction="vertical", caption="foo"}
	scroll_pane.style.maximal_height = 500
	scroll_pane.style.maximal_width = 500
	scroll_pane.style.minimal_height = 100
	scroll_pane.style.minimal_width = 50

	for index=1, NUM_LOG_LINES do
		local label = scroll_pane.add{type="label", style="label_style", name = "text_" .. index, caption="", single_line=true, want_ellipsis=true}
		label.style.top_padding = 0
		label.style.bottom_padding = 0
		--label.style.font_color = {r=1.0, g=0.7, b=0.9}

	end
	local type_flow = frame.add{type="flow", name="type_flow", style="flow_style", direction="horizontal"}
end


-- update_log_ui
-- player: player
-- Since this is relatively expensive, it schedules itself automatically depending on game speed.
function update_log_ui(player)

	local flow = mod_gui.get_frame_flow(player)
	local frame = flow.log_frame

	if not frame then 
		create_log_ui(player) 
		frame = flow.log_frame
	end

	-- Visibility
	local show = frame.top_flow.show_checkbox.state
	frame.scroll_pane.style.visible = show
	frame.type_flow.style.visible = show

	-- Scheduling
	if game.tick % math.floor(game.speed * 20 + 1) ~= 0 then return end
	if not global.log_data.need_update then return end
	global.log_data.need_update = false


	-- Update
	if show and not global.log_data.ui_paused[player.index] then
		local type_flow = frame.type_flow

		-- Determine which log-types the user wants to see.
		local visible_types = {}
		for log_type, settings in pairs(global.log_data.log_type_settings) do
			local checkbox = type_flow[log_type .. "_checkbox"]
			if checkbox then
				if checkbox.state == true then
					visible_types[log_type] = true
				end
			else
				checkbox = type_flow.add{type="checkbox", name=log_type .. "_checkbox", state=true}
				type_flow.add{type="label", style="label_style", name=log_type .. "_text", caption=log_type}
			end
		end

		-- Determine the set of logs we want to display
		local displayable = {n=NUM_LOG_LINES}
		for type_name, _ in pairs(visible_types) do
			for _, messages in pairs(global.log_data.log_messages[type_name]) do
				for _, message in pairs(messages) do
					table.insert(displayable, message)
				end
			end
		end
		table.sort(displayable, function(a, b) return a.tick > b.tick end)

		-- Display
		local index = 1
		for _, message in ipairs(displayable) do
			if frame.scroll_pane["text_" .. index] then
				local label = frame.scroll_pane["text_" .. index]
				label.caption = message.display_text
				for k, v in pairs(global.log_data.log_type_settings[message.type_name].style) do
					label.style[k] = v
				end
			else 
				break
			end
			index = index + 1
		end
	end
end

function destroy_log_ui(player)
	local fr = mod_gui.get_frame_flow(player).log_frame
	if fr and fr.valid then fr.destroy() end
end

