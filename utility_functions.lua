-- Utility functions

function roundn(x)
  return x + 0.5 - (x + 0.5) % 1
end

function inrange(position, myplayer)
  return ((position[1]-myplayer.position.x)^2+(position[2]-myplayer.position.y)^2) < 36
end

function debugprint(msg)
	log_to_ui(msg, "run-debug")
	-- for _, player in pairs(game.connected_players) do
	-- 	if player.mod_settings["tas-verbose-logging"].value then 
	-- 		-- player.print("[" .. game.tick - (global.start_tick or 0) .. "] " .. msg)
	-- 	end
	-- end
end

function errprint(msg)
	log_to_ui(msg, "tascommand-error")
	--game.print("[" .. game.tick - (global.start_tick or 0) .. "]  ___WARNING___ " .. msg)
end
