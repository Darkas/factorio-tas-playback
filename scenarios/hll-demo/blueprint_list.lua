local list = {
  "smelter",
  "bad-bluechips",
}

local blueprints = {}

for _, name in pairs(list) do
	pcall(function() blueprints[name] = require("bp." .. name) end)
	if not blueprints[name] then
		if not global.blueprint_error then global.blueprint_error = {} end
		global.blueprint_error[#global.blueprint_error + 1] = name
	end
end

return blueprints
