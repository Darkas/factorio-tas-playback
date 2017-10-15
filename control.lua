if not settings.global["tas-playback-enabled"].value then
	return
end

-- Global variables initialization
global.system = global.system or {}
global.system.save = false -- if this is a string, save at the end of this tick.

local max_tick = 0

-- Get the path of the scenario and the name of the run file through a very dirty trick
for k,_ in pairs(remote.interfaces) do
	global.system.tas_name = global.system.tas_name or string.match(k,"^TASName_(.+)$")
	global.system.run_file = global.system.run_file or string.match(k,"^TASFile_(.+)$")
end

-- Get the run instructions every time the game is loaded
if global.system.tas_name and global.system.run_file then
	commandqueue = require("scenarios." .. global.system.tas_name .. "." .. global.system.run_file)
	-- determine last tick, each time the run is loaded
	for k,_ in pairs(commandqueue) do
		if type(k) == "number" and (k > max_tick) then -- Makes sure that k is actually bigger than our current max_tick
			max_tick = k
		end
	end
else
	script.on_event(defines.events.on_tick, function()
		game.print("TAS-playback: Not in run scenario. ")
		script.on_event(defines.events.on_tick, nil)
	end)
	return
end

require("silo-script")
require("command_list_parser")

local CmdUI = require("command_list_ui")
local LogUI = require("log_ui")
local Event = require("stdlib/event/event")
local Utils = require("utility_functions")
-- local MvRec = require("record_movement")
-- local movement_records = {}
-- pcall(function() movement_records = require("scenarios." .. global.system.tas_name .. ".movement_records") end)
-- MvRec.init(movement_records)

local BP = require("blueprint")
local blueprint_data_raw = {}
pcall( function() blueprint_data_raw = require("scenarios." .. global.system.tas_name .. ".blueprint_list") end )
if global.blueprint_error then error("Failed to load blueprints: " .. serpent.block(global.blueprint_error)) end
BP.init(blueprint_data_raw)


-- Get the commands that the speedrun can use
local TAScommands = require("commands")


function set_run_logging_types()
	LogUI.configure_log_type(
		"run-debug",
		{font_color = {r=0.5, g=0.9, b=0.9}},
		50,
		function(message)
			return "[" .. message.tick - (global.start_tick or 0) .. "] " .. message.text
		end,
		true
	)
	LogUI.configure_log_type(
		"tascommand-error",
		{font_color = {r=0.9, g=0.3, b=0.2}, font = "default-bold"},
		50,
		function(message)
			return "[" .. message.tick - (global.start_tick or 0) .. "] " .. message.text
		end
	)
	LogUI.configure_log_type(
		"run-output",
		{font_color = {r=0.5, g=1, b=0.5}, font = "default"},
		50,
		function(message)
			return "[" .. message.tick - (global.start_tick or 0) .. "] " .. message.text
		end
	)
	LogUI.configure_log_type(
		"command-not-executable",
		{font_color = {r=1, g=0.5, b=0.5}, font = "default"},
		50,
		function(message)
			return "[" .. message.tick - (global.start_tick or 0) .. "] " .. message.text
		end,
		true
	)
end


------------------------------------
-- Functions that control the run --
------------------------------------

-- Initialize the player's inventory
local function init_player_inventory(player)
	player.clear_items_inside()
	player.insert{name="iron-plate", count=8}
	player.insert{name="pistol", count=1}
	player.insert{name="firearm-magazine", count=10}
	player.insert{name="burner-mining-drill", count = 1}
	player.insert{name="stone-furnace", count = 1}
end

local function init_player(player)
	local char_entity = player.surface.create_entity({name="player", position={0,0}, force=player.force})
	player.character = char_entity
	player.surface.always_day = true
	player.game_view_settings.update_entity_selection = false
	player.game_view_settings.show_entity_info = true
	player.game_view_settings.show_controller_gui = true
	init_player_inventory(player)
end

-- This function initializes the run's clock and a few properties
function init_run(myplayer_index)
	set_run_logging_types()
	Utils.debugprint("Initializing the run")
	-- Examine the command queue for errors.
	if not commandqueue then
		Utils.errprint("The command queue is empty! No point in starting.")
		return
	end
	Utils.debugprint("Command queue size is " .. table_size(commandqueue)) --includes settings "field"

	if not commandqueue.settings then
		Utils.errmessage("The settings for of the command queue don't exist.")
		return
	end
	-- Applying command queue settings
	global.allowspeed = commandqueue.settings.allowspeed
	Utils.debugprint("Changing the speed of the run through commands is " .. ((global.allowspeed and "allowed") or "forbidden") .. ".")
	-- Initiating the game:
	-- Prepare the players:
	-- Prepare the runner
	local player = game.players[myplayer_index]
	init_player(player)
	global.myplayer = player
	player.surface.always_day = true
	--player.game_view_settings.update_entity_selection = false
	player.game_view_settings.show_entity_info = true
	-- Prepare the players:
	-- Make all non-running players unable to interact with the world and have no body (character)
	-- set up permissions
	local spectators = game.permissions.create_group("Spectator")
	for _, input_action in pairs(defines.input_action) do
		spectators.set_allows_action(input_action, false)
	end
	local allowed_actions = {
		defines.input_action.start_walking,
		defines.input_action.open_gui,
		defines.input_action.open_technology_gui,
		defines.input_action.open_achievements_gui,
		defines.input_action.open_trains_gui,
		defines.input_action.open_train_gui,
		defines.input_action.open_train_station_gui,
		defines.input_action.open_bonus_gui,
		defines.input_action.open_production_gui,
		defines.input_action.open_kills_gui,
		defines.input_action.open_logistic_gui,
		defines.input_action.open_equipment,
		defines.input_action.open_item,
		defines.input_action.write_to_console
	}
	for _, input_action in pairs(allowed_actions) do
		spectators.set_allows_action(input_action, true)
	end
	-- make everyone spectator except the runner
	for _, pl in pairs(game.connected_players) do
		if pl.index ~= myplayer_index then
			pl.game_view_settings.update_entity_selection = true
			spectators.add_player(pl)
		end
	end

	global.start_tick = game.tick
	Utils.debugprint("Starting tick is " .. global.start_tick)

	global.running = true
end

local function end_of_input(player)
	if commandqueue.settings.end_tick_debug then
		player.game_view_settings.update_entity_selection = true
	end
end

Event.register(defines.events.on_tick, function()
	for _, player in pairs(game.players) do
		if player.connected then
			LogUI.update_log_ui(player)
			if commandqueue then
				CmdUI.update_command_list_ui(player, commandqueue.command_list)
			end
		end
	end

	if commandqueue and global.running then
		local tick = game.tick - global.start_tick
		local myplayer = global.myplayer

		-- Check what commands are to be executed next
		if commandqueue.settings.enable_high_level_commands then
			global.minestate = nil
			global.walkstate = {walking = false}

			if not command_list_parser.evaluate_command_list(commandqueue["command_list"], commandqueue, myplayer, tick) then
				end_of_input(myplayer)
			end
		end

		if not myplayer.connected then
			error("The runner left.")
		end
		if commandqueue[tick] then
			for _, command in pairs(commandqueue[tick]) do
				if not TAScommands[command[1]] then error("TAS-Command does not exist: " .. command[1]) end
				if not command.already_executed then
					TAScommands[command[1]](command, myplayer)
				end
			end
		end
		myplayer.walking_state = global.walkstate
		myplayer.picking_state = myplayer.picking_state or global.pickstate
		if not global.minestate then
			myplayer.mining_state = {mining = false}
		else
			myplayer.update_selected_entity(global.minestate)
			myplayer.mining_state = {mining = true, position = global.minestate}
		end
		if tick == max_tick then
			end_of_input(myplayer)
		end
	end

	if global.system.save then
		if type(global.system.save) ~= "string" then error("Save name must be a string! Is: " .. Utils.printable(global.system.save)) end
		local name = global.system.save
		global.system.save = false
		game.server_save("_TAS_" .. name)
	end
end)

local function init_spectator(player)
	local char_entity = player.character
	player.character = nil
	char_entity.destroy()
	player.game_view_settings.show_entity_info = true
	player.game_view_settings.show_controller_gui = false
	player.game_view_settings.update_entity_selection = false
end

local function init_world(player_index) --does what the freeplay scenario usually does
	local myplayer = game.players[player_index]
	-- Reveal the map around the player
	local pos = myplayer.position
	myplayer.force.chart(myplayer.surface, {{pos.x - 200, pos.y - 200}, {pos.x + 200, pos.y + 200}})
	silo_script.gui_init(myplayer)
end

Event.register(defines.events.on_player_created, function(event)
	init_world(event.player_index)
	init_spectator(game.players[event.player_index])
	if global.init_on_player_created and (event.player_index == 1) then -- Only the first player created automatically starts the run
		init_run(event.player_index)
	end
end)

Event.register(defines.events.on_player_joined_game, function(event)
	if global.running and (event.player_index ~= global.myplayer.index) then
		local player = game.players[event.player_index]
		player.game_view_settings.update_entity_selection = true
		game.permissions.get_group("Spectator").add_player(player)
	end
end)

-- Create the interface and command that allow to launch a run
script.on_init(function()
	-- Global variables initialization
	global.walkstate = {walking = false}
	silo_script.init()
	command_list_parser.init()
	--init_logging()
end)


remote.add_interface("TAS_playback", {launch = function()
	global.init_on_player_created = true
end})

commands.add_command("init_run", "Start the speedrun", function(event)
	local player = game.players[event.player_index]
	if not player.admin then
		player.print("Only admins can start the run.")
	elseif global.running then
		player.print("The run has already been started.")
	elseif (table_size(game.connected_players) > 1) then
		local warning_frame = player.gui.center.add{
			type = "frame",
			name = "tas-warning-frame",
			direction = "vertical",
			caption = "Warning"
		}
		warning_frame.style.font_color = {r=1, g=0.2, b=0.3}
		warning_frame.add{
			type = "label",
			name = "tas-warning-label",
			caption = "Only the server host should start the run, otherwise the run can fail."
		}
		local warning_table = warning_frame.add{
			type = "table",
			name = "tas-warning-table",
			colspan = 2
		}
		warning_table.add{
			type = "button",
			name = "tas-cancel-button",
			caption = "Cancel"
		}
		warning_table.add{
			type = "button",
			name = "tas-start-button",
			caption = "Start run"
		}
	else
		init_run(event.player_index)
	end
end)

commands.add_command("alert", "Alert when entering command group and set game speed.", function(arg)
	if commandqueue.command_list then
		local found = false
		for _, cmd_grp in pairs(commandqueue.command_list) do
			if cmd_grp.name == arg.parameter then
				found = true
				game.print("Alerting for command group " .. arg.parameter)
				table.insert(cmd_grp.commands, {"alert", arg.parameter})
				table.insert(cmd_grp.commands, {"speed", 0.05})
			end
		end
		if not found then game.print("Command group with name " .. arg.parameter .. " not found!") end
	else
		game.print("Can only use /wait_for if the command_list is set!")
	end
end)

commands.add_command("exportqueue", "Export the command queue to file.", function(event)
	local name = "TAS_" .. global.system.tas_name
	if event.parameter and event.parameter ~= "" then
		name = name .. "_" .. event.parameter .. "_queue.lua"
	else
		name = name .. "_queue.lua"
	end
	local list = commandqueue.command_list
	commandqueue.command_list= nil
	local data = "return " .. serpent.block(commandqueue)
	commandqueue.command_list = list
	game.write_file(name, data, false, event.player_index)
end)

Event.register(defines.events.on_gui_click, function(event)
	silo_script.on_gui_click(event)

	if event.element.name == "next_command_group" then
		if game.players[event.player_index].admin then
			global.command_list_parser.next_command_group = true
		else
			game.players[event.player_index].print("Only admins can do that!")
		end
	end

	if event.element.name == "tas-cancel-button" then
		game.players[event.player_index].gui.center["tas-warning-frame"].destroy()
	elseif event.element.name == "tas-start-button" then
		game.players[event.player_index].gui.center["tas-warning-frame"].destroy()
		init_run(event.player_index)
	end
end)

Event.register(defines.events.on_rocket_launched, function(event)
	silo_script.on_rocket_launched(event)
end)

silo_script.add_remote_interface()
