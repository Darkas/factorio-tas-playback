local list = {
  "smelter",
  "bad-bluechips",
}

local blueprints = {}

for _, name in pairs(list) do
  blueprints[name] = require("bp." .. name)
end

return blueprints
