local commandqueue = {}

commandqueue["settings"] = {
    debugmode = true,
    allowspeed = true,
    end_tick_debug = true,
    enable_high_level_commands = true,
    spawn_x = -204,
    spawn_y = 194.5,
    init_player_inventory = function(player)
        player.clear_items_inside()
        player.insert{name="steel-axe", count=3}
        player.insert{name="submachine-gun", count=1}
        player.insert{name="firearm-magazine", count=40}
        player.insert{name="shotgun", count=1}
        player.insert{name="shotgun-shell", count=20}
        player.insert{name="power-armor", count=1}
        player.insert{name="construction-robot", count=20}
        player.insert{name="blueprint", count=3}
        player.insert{name="deconstruction-planner", count=1}
        player.insert{name="iron-plate", count=200}
        player.insert{name="pipe", count=200}
        player.insert{name="pipe-to-ground", count=50}
        player.insert{name="copper-plate", count=200}
        player.insert{name="steel-plate", count=200}
        player.insert{name="iron-gear-wheel", count=250}
        player.insert{name="transport-belt", count=600}
        player.insert{name="underground-belt", count=40}
        player.insert{name="splitter", count=40}
        player.insert{name="gun-turret", count=8}
        player.insert{name="stone-wall", count=50}
        player.insert{name="repair-pack", count=20}
        player.insert{name="inserter", count=100}
        player.insert{name="burner-inserter", count=50}
        player.insert{name="small-electric-pole", count=50}
        player.insert{name="medium-electric-pole", count=50}
        player.insert{name="big-electric-pole", count=15}
        player.insert{name="burner-mining-drill", count=50}
        player.insert{name="electric-mining-drill", count=50}
        player.insert{name="stone-furnace", count=35}
        player.insert{name="steel-furnace", count=20}
        player.insert{name="electric-furnace", count=8}
        player.insert{name="assembling-machine-1", count=50}
        player.insert{name="assembling-machine-2", count=20}
        player.insert{name="assembling-machine-3", count=8}
        player.insert{name="electronic-circuit", count=200}
        player.insert{name="fast-inserter", count=100}
        player.insert{name="long-handed-inserter", count=100}
        player.insert{name="substation", count=10}
        player.insert{name="boiler", count=10}
        player.insert{name="offshore-pump", count=1}
        player.insert{name="steam-engine", count=20}
        player.insert{name="chemical-plant", count=20}
        player.insert{name="oil-refinery", count=5}
        player.insert{name="pumpjack", count=10}
        player.insert{name="small-lamp", count=20}
    end
}

commandqueue["command_list"] = {
    {
        name = "end-run",
        commands = {
            {"enable-manual-walking"},
            {"speed", 1},
        }
    },
}

return commandqueue
