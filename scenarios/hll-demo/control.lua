
local config = require("configuration")
--require("blueprint_list")

script.on_event(defines.events.on_player_created, function(event)
	if config.autorun then
		remote.call("TAS_playback", "launch")
	end

end)

script.on_event(defines.events.on_tick, function(event)

	if game.tick ~= 1 then return end

	-- Insert items for blueprint build.
	game.print("Inserting items for blueprint build.")
	items = {
		{"transport-belt", 160},
		{"inserter", 96},
		{"stone-furnace", 48},
		{"small-electric-pole", 24},
		{"underground-belt", 4},
		{"splitter", 3},
	}
	for _, item in pairs(items) do
		game.players[1].insert{name=item[1], count=item[2]}
	end

	items = {
		{"transport-belt", 71},
		{"fast-inserter", 21},
		{"small-electric-pole", 13},
		{"assembling-machine-2", 9},
		{"pipe", 6},
		{"long-handed-inserter", 4},
		{"pipe-to-ground", 4},
		{"productivity-module", 4},
		{"underground-belt", 2},
	}
	for _, item in pairs(items) do
		game.players[1].insert{name=item[1], count=item[2]}
	end
end)

-- These interface are only there to transmit information to the mod without being allowed to.
remote.add_interface("TASName_" .. config.run_name, {})
remote.add_interface("TASFile_" .. config.run_file, {})
