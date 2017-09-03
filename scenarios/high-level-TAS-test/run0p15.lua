-- The map exchange string is: >>>AAAPABUAAAADAAcAAAAEAAAAY29hbAUEBQoAAABjb3BwZXItb3JlBQUFCQAAAGNydWRlLW9pbAQFBQoAAABlbmVteS1iYXNlAQADCAAAAGlyb24tb3JlBQUFBQAAAHN0b25lBQQFCwAAAHVyYW5pdW0tb3JlAQADjvdOcoCEHgCAhB4AAwEBAQF7FK5H4XqUPwEAAAAAAAAuQAEAAAAAAADwPwEAAAAAAFi7QAEAAAAAAOCFQAEAAAAAAFirQAEAAAAAAIjDQAEAAAAAAECfQAEAAAAAAEB/QAEAAAAAAECPQAEzMzMzMzPzPwEzMzMzMzPzPwF7FK5H4Xp0PwEAAQAAAAAAAAhAAQAAAAAAAAhAAXsUrkfheoQ/AQABAQGN7bWg98bQPgH8qfHSTWJgPwFpHVVNEHXvPgEBAQcAAAABAgAAAAECAAAAAZqZmZmZmbk/AQAAAAAAAABAAQAAAAAAAOA/AZqZmZmZmdk/Ac3MzMzMzOw/AQUAAAABFAAAAAFAOAAAAcBLAwABEA4AAAGgjAAAASAcAAABAAAAAAAAPkABAAAAAAAAFEABZmZmZmZm9j8BMzMzMzMz4z8BMzMzMzMz0z8BAAAAAAAACEABAAAAAAAAJEABPAAAAAEeAAAAAcgAAAABBQAAAAEAAAAAAAAAQAEBAQAAAAAAAFlAAQUAAAABGQAAAAEAAAAAAAAkQAEyAAAAAQAAAAAAAD5AAWQAAAABmpmZmZmZyT8BMzMzMzMzwz8BMzMzMzMz0z8BMzMzMzMz0z8BAAAAAAAAJEABAAAAAAAANEABAAAAAAAAPkABAAAAAAAAFEABAAAAAAAAPkABAAAAAAAAJEABAAAAAAAACEABCgAAAAFkAAAAAWQAAAAB6AMAAAEAAAAAAADgPwHQBwAAAQAAAAAAQH9AAwAAAAAAAAAAAAAA8D8SVIG9<<<
local commandqueue = {}



commandqueue["settings"] = {
    debugmode = true,
    allowspeed = true,
    end_tick_debug = true
}

commandqueue["command_list"] = {
	{
		name = "start-1",
		commands = {
			{"speed", 5},
			{"craft", "iron-axe", 1},
			{"auto-move-to-command", "mine-coal"},
			{"build", "stone-furnace", {-32,29}, 0, on_entering_range = true},
			{"build", "burner-mining-drill", {-34,29}, 2, on_entering_range = true},
			{"mine", {-36.5,26.5}, amount=4, on_entering_range = true, name="mine-coal"},
			{"auto-refuel", "m", {-34,29}, priority=4},
			{"auto-refuel", "f", {-32,29}},
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
			{"auto-move-to-command", "mine-coal"},
			{"craft", "stone-furnace", 4},
			{"mine", {-36.5,26.5}, on_entering_range = true, name="mine-coal"},
		}
	},
}

return commandqueue
