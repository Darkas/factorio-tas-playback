-- The map exchange string is: >>>AAAPABUAAAADAAcAAAAEAAAAY29hbAUEBQoAAABjb3BwZXItb3JlBQUFCQAAAGNydWRlLW9pbAQFBQoAAABlbmVteS1iYXNlAQADCAAAAGlyb24tb3JlBQUFBQAAAHN0b25lBQQFCwAAAHVyYW5pdW0tb3JlAQADjvdOcoCEHgCAhB4AAwEBAQF7FK5H4XqUPwEAAAAAAAAuQAEAAAAAAADwPwEAAAAAAFi7QAEAAAAAAOCFQAEAAAAAAFirQAEAAAAAAIjDQAEAAAAAAECfQAEAAAAAAEB/QAEAAAAAAECPQAEzMzMzMzPzPwEzMzMzMzPzPwF7FK5H4Xp0PwEAAQAAAAAAAAhAAQAAAAAAAAhAAXsUrkfheoQ/AQABAQGN7bWg98bQPgH8qfHSTWJgPwFpHVVNEHXvPgEBAQcAAAABAgAAAAECAAAAAZqZmZmZmbk/AQAAAAAAAABAAQAAAAAAAOA/AZqZmZmZmdk/Ac3MzMzMzOw/AQUAAAABFAAAAAFAOAAAAcBLAwABEA4AAAGgjAAAASAcAAABAAAAAAAAPkABAAAAAAAAFEABZmZmZmZm9j8BMzMzMzMz4z8BMzMzMzMz0z8BAAAAAAAACEABAAAAAAAAJEABPAAAAAEeAAAAAcgAAAABBQAAAAEAAAAAAAAAQAEBAQAAAAAAAFlAAQUAAAABGQAAAAEAAAAAAAAkQAEyAAAAAQAAAAAAAD5AAWQAAAABmpmZmZmZyT8BMzMzMzMzwz8BMzMzMzMz0z8BMzMzMzMz0z8BAAAAAAAAJEABAAAAAAAANEABAAAAAAAAPkABAAAAAAAAFEABAAAAAAAAPkABAAAAAAAAJEABAAAAAAAACEABCgAAAAFkAAAAAWQAAAAB6AMAAAEAAAAAAADgPwHQBwAAAQAAAAAAQH9AAwAAAAAAAAAAAAAA8D8SVIG9<<<
local commandqueue = {}

--[[

Currently implemented commands:
{"auto-move-to", {<X>,<Y>}}
{"build", <entity>, {<X>,<Y>}, <facing direction>} NOTE: The positions for build are currently required to be at the center of the entity. Otherwise, you do impossible stuff
{"craft", <item>, <count>}
{"auto-refuel", "<type>", {<X>,<Y>}} where type is m for burner mining drill, f for stone furnace and b for boiler, mining drills get refueled after 1600 ticks, furnaces after 2660 ticks, these might not be perfectly exact values (they are guaranteed to be less than 10 ticks too low)
{"rotate", {<X>, <Y>}, "<direction>"}
{"tech", "<research-name>"} - Note that this pushes the researches into a queue, so it need not be tick-perfect.
{"mine", {<X>,<Y>}, amount=...} NOTE: It is assumed that iron, coal and copper need 124 ticks, stone needs 95 ticks

To be implemented:

{"build-blueprint", "<name>"}
"move"
"put"
"take"
"take-from-ground"
"recipe"
"throw"
"vehicle"
"auto-take"
"stop-auto-refuel"
"stop-auto-take"
"stop-auto-move-to"

Currently implemented conditions:
on_entering_range=<bool> (as soon as this action is possible)
on_leaving_range=<bool> (right before this action becomes impossible)

To be implemented:
on_player_in_range=<range> (player is range away from )
on_tick=<tick> (do this on a certain tick)
on_relative_tick={<tick>, <name>} (do this a given amount of ticks after the command with the given name finished or after the current command set began (if name is not set))
items_total={<item name>, <N>} (there are currently N of item name available (in the entire world))
needs_fuel={<X>,<Y>} (entity needs fuel)

--]]

commandqueue["settings"] = {
    debugmode = true,
    allowspeed = true,
    end_tick_debug = true
}

commandqueue["command_list"] = {
	{
		name = "start-1",
		commands = {
			--{"speed", 10},
			{"craft", "iron-axe", 1},
			{"auto-move-to-command", "mine-coal"},
			{"build", "stone-furnace", {-32,29}, 0, on_entering_range = true},
			{"build", "burner-mining-drill", {-34,29}, 2, on_entering_range = true},
			{"mine", {-36.5,26.5}, amount=4, on_entering_range = true, name="mine-coal"},
			{"auto-refuel", "m", {-34,29}},
			{"auto-refuel", "f", {-32,29}},
		}
	},
	{
		name = "start-2",
		commands = {
			{"mine", {-56,16}}
		}
	},
}

return commandqueue
