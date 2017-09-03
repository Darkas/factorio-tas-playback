-- The map exchange string is: >>>AAAPABUAAAADAAcAAAAEAAAAY29hbAUEBQoAAABjb3BwZXItb3JlBQUFCQAAAGNydWRlLW9pbAQFBQoAAABlbmVteS1iYXNlAQADCAAAAGlyb24tb3JlBQUFBQAAAHN0b25lBQQFCwAAAHVyYW5pdW0tb3JlAQADjvdOcoCEHgCAhB4AAwEBAQF7FK5H4XqUPwEAAAAAAAAuQAEAAAAAAADwPwEAAAAAAFi7QAEAAAAAAOCFQAEAAAAAAFirQAEAAAAAAIjDQAEAAAAAAECfQAEAAAAAAEB/QAEAAAAAAECPQAEzMzMzMzPzPwEzMzMzMzPzPwF7FK5H4Xp0PwEAAQAAAAAAAAhAAQAAAAAAAAhAAXsUrkfheoQ/AQABAQGN7bWg98bQPgH8qfHSTWJgPwFpHVVNEHXvPgEBAQcAAAABAgAAAAECAAAAAZqZmZmZmbk/AQAAAAAAAABAAQAAAAAAAOA/AZqZmZmZmdk/Ac3MzMzMzOw/AQUAAAABFAAAAAFAOAAAAcBLAwABEA4AAAGgjAAAASAcAAABAAAAAAAAPkABAAAAAAAAFEABZmZmZmZm9j8BMzMzMzMz4z8BMzMzMzMz0z8BAAAAAAAACEABAAAAAAAAJEABPAAAAAEeAAAAAcgAAAABBQAAAAEAAAAAAAAAQAEBAQAAAAAAAFlAAQUAAAABGQAAAAEAAAAAAAAkQAEyAAAAAQAAAAAAAD5AAWQAAAABmpmZmZmZyT8BMzMzMzMzwz8BMzMzMzMz0z8BMzMzMzMz0z8BAAAAAAAAJEABAAAAAAAANEABAAAAAAAAPkABAAAAAAAAFEABAAAAAAAAPkABAAAAAAAAJEABAAAAAAAACEABCgAAAAFkAAAAAWQAAAAB6AMAAAEAAAAAAADgPwHQBwAAAQAAAAAAQH9AAwAAAAAAAAAAAAAA8D8SVIG9<<<
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
			{"speed", 10},
			{"craft", "iron-axe", 1},
			{"auto-move-to-command", "mine-coal"},
			{"build", "stone-furnace", {-32,29}, 0, on_entering_range = true},
			{"build", "burner-mining-drill", {-34,29}, 2, on_entering_range = true},
			{"mine", {-36.5,26.5}, amount=4, on_entering_range = true, name="mine-coal"},
			{"auto-refuel", {-34,29}, priority=4},
			{"auto-refuel", {-32,29}},
		}
	},
	{
		name = "start-2",
		required = {"mine-coal"},
		commands = {
			{"auto-move-to-command", "mine-rock"},
			{"mine", {-56,16}, amount=1, name="mine-rock"},
		}
	},
	{
		name = "start-3",
		required = {"mine-rock"},
		commands = {
			{"auto-move-to-command", "furnace-interaction"},
			{"entity-interaction", {-32,29}, name="furnace-interaction"},
			{"craft", "stone-furnace", 4},
			{"take", {-32,29}, name="iron-taken"},
		}
	},
	{
		name = "start-4",
		required = {"iron-taken"},
		commands = {
			{"craft", "iron-gear-wheel", 3},
			{"mine", {-36.5,28.5}, amount=10, on_entering_range = true, name="mine-coal"},
			{"take", {-32,29}, "iron-plate", items_available={"iron-plate", 2}, name="iron-taken"},
			{"craft", "burner-mining-drill", 1, command_finished="iron-taken"},
			{"build", "burner-mining-drill", {-34,31}, 2, items_available={"burner-mining-drill", 1}, name="miner-built"},
			{"speed", 1},
		}
	},
	{
		name = "start-5",
		required = {"miner-built"},
		commands = {
			{"auto-move-to-command", "furnace", priority=3},
			{"build", "stone-furnace", {-32,31}, 0, name="furnace"},
			{"auto-refuel", {-34,31}, priority=4},
			{"auto-refuel", {-32,31}},
			--{"speed", 1},
		}
	},
}

return commandqueue
