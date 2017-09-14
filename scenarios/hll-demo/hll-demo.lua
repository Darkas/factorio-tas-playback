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
			{"auto-build-blueprint", "smelter", {1.5, 73.5}, name="build-smelter", area={{1, -400}, {10, 500}}},
			{"mine", {2, 42}, "tree", name="mine-tree", amount=1},
			{"auto-move-to-command", "mine-tree"},
			{"mine", {3, 59}, "rock", name="mine-rock", command_finished = "mine-tree"},
			{"build", "burner-mining-drill", {-5, 76}},
			{"build", "stone-furnace", {-5, 74}},
			{"auto-move-to-command", "mine-rock", command_finished = "mine-tree"},
			{"auto-refuel"},
			{"craft", "iron-axe", 1},
			{"auto-move-to", {1.5, 120.5}, name="move-down", command_finished = "mine-rock"},
            {"auto-build-blueprint", "bad-bluechips", {-15, 120}, name="build-chips", command_finished = "build-smelter"},
            {"auto-move-to", {-24.5, 120.5}, name="move-right", command_finished = "move-down"},
			{"auto-move-to", {-0.05, 120}, command_finished="move-right"},
			{"craft", "stone-furnace", 4, },
		}
	},
	{
		name = "start-2",
        required = "build-chips",
		commands = {
			{"auto-build-blueprint", "smelter", {1.5, 73.5}, name="build-smelter", area={{-6, -400}, {1, 500}}},
			{"auto-move-to", {1, 52}, name="move-up"},
			{"auto-move-to", {-7, 74}, command_finished = "move-up", name="move-to-mining"},
			{"mine", {-7.5, 71.5}, amount = 1, name = "mine-coal"}
		}
		--required = {"blueprint_x-6.5_y98.5"},
	},
	{
		name = "start-3",
		required = "move-to-mining",
		commands = {
			{"mine", {-7.5, 71.5, amount = 10}},
			{"take", {-5, 74}},
			{"craft", "iron-gear-wheel", 3, name="gears"},
			{"auto-take", "iron-plate", 3, command_finished="gears"},
			{"craft-build", "burner-mining-drill", {-9, 74}, 2, name="miner-built"},
		}
	},
	{
		name = "slowdown",
		commands = {
			{"stop-command", "start-2.move-up"},
			{"speed", 0.05}
		}
	},
}

return commandqueue
