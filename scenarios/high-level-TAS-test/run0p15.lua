-- The map exchange string is: >>>AAAPABUAAAADAAcAAAAEAAAAY29hbAUEBQoAAABjb3BwZXItb3JlBQUFCQAAAGNydWRlLW9pbAQFBQoAAABlbmVteS1iYXNlAQADCAAAAGlyb24tb3JlBQUFBQAAAHN0b25lBQQFCwAAAHVyYW5pdW0tb3JlAQADjvdOcoCEHgCAhB4AAwEBAQF7FK5H4XqUPwEAAAAAAAAuQAEAAAAAAADwPwEAAAAAAFi7QAEAAAAAAOCFQAEAAAAAAFirQAEAAAAAAIjDQAEAAAAAAECfQAEAAAAAAEB/QAEAAAAAAECPQAEzMzMzMzPzPwEzMzMzMzPzPwF7FK5H4Xp0PwEAAQAAAAAAAAhAAQAAAAAAAAhAAXsUrkfheoQ/AQABAQGN7bWg98bQPgH8qfHSTWJgPwFpHVVNEHXvPgEBAQcAAAABAgAAAAECAAAAAZqZmZmZmbk/AQAAAAAAAABAAQAAAAAAAOA/AZqZmZmZmdk/Ac3MzMzMzOw/AQUAAAABFAAAAAFAOAAAAcBLAwABEA4AAAGgjAAAASAcAAABAAAAAAAAPkABAAAAAAAAFEABZmZmZmZm9j8BMzMzMzMz4z8BMzMzMzMz0z8BAAAAAAAACEABAAAAAAAAJEABPAAAAAEeAAAAAcgAAAABBQAAAAEAAAAAAAAAQAEBAQAAAAAAAFlAAQUAAAABGQAAAAEAAAAAAAAkQAEyAAAAAQAAAAAAAD5AAWQAAAABmpmZmZmZyT8BMzMzMzMzwz8BMzMzMzMz0z8BMzMzMzMz0z8BAAAAAAAAJEABAAAAAAAANEABAAAAAAAAPkABAAAAAAAAFEABAAAAAAAAPkABAAAAAAAAJEABAAAAAAAACEABCgAAAAFkAAAAAWQAAAAB6AMAAAEAAAAAAADgPwHQBwAAAQAAAAAAQH9AAwAAAAAAAAAAAAAA8D8SVIG9<<<
local commandqueue = {}

--[[

Currently implemented commands:
{"auto-move-to", {<X>,<Y>}}

To be implemented:
"build"
"build-blueprint"
"move"
"rotate"
"mine"
"craft"
"put"
"take"
"take-from-ground"
"tech"
"recipe"
"throw"
"vehicle"
"auto-refuel"
"auto-take"
"stop-auto-refuel"
"stop-auto-take"
"stop-auto-move-to"

Currently implemented conditions:
none

To be implemented:
on_entering=<bool> (as soon as this action is possible)
on_leaving=<bool> (right before this action becomes impossible)
on_player_in_range=<range> (player is range away from )
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
		name = "start",
		commands = {
			{"move-to", {5,10}}
		}
	}
}

return commandqueue
