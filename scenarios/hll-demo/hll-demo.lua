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
			{"pickup"},
			{"auto-build-blueprint", "smelter", {1.5, 73.5}, name="build-smelter"}, 
			{"mine", {2, 42}, "tree", name="mine-tree", amount=1},
			{"auto-move-to-command", "mine-tree"},
			{"mine", {3, 59}, "rock", name="mine-rock", command_finished = "mine-tree"},
			{"auto-move-to-command", "mine-rock", command_finished = "mine-tree"},
			--{"auto-refuel"},
			{"craft", "iron-axe", 1},
			{"auto-move-to", {1.5, 120}, name="move-down", command_finished = "mine-rock"}
		}
	},
	{
		name = "slowdown",
		required = {"build-smelter"},
		--required = {"blueprint_x-6.5_y98.5"},
		commands = {
			{"stop-command", "start-1.move-down"},
			{"speed", 0.05}
		}
	},
}

return commandqueue