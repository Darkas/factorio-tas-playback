local commandqueue = {}

commandqueue["settings"] = {
    debugmode = true,
    allowspeed = true,
    end_tick_debug = true,
	enable_high_level_commands = true
}

commandqueue["command_list"] = {
	{
		name = "start-1",
		commands = {
			{"build", "stone-furnace", {0, 0}, on_leaving_range = true},
			{"auto-build-blueprint", "smelter", {-6.5, 73.5}}, 
			{"pickup"},
			{"auto-refuel"},
			{"craft", "iron-axe", 1},
			{"auto-move-to", {-6.5, 110}, name="move-down"}
		}
	},
	{
		name = "slowdown",
		required = {"blueprint_x-6.5_y98.5"},
		commands = {
			{"stop-command", "start-1.move-down"},
			{"speed", 0.05}
		}
	},
}

return commandqueue