-- basic commands


-- luacheck: globals command_list_parser Utils high_level_commands LogUI Event TAScommands Blueprint BPStorage HLC_Utils
-- luacheck: ignore 212


return {
    build = {
        type_signature = {
            [2] = "string",
            [3] = "position",
            [4] = {"nil", "number", "string"},
            [5] = {"nil", "string"},
        },
        execute = function(command, myplayer)
            if myplayer.get_item_count(command[2]) ~= 0 then
                TAScommands["build"](command, myplayer)
                command_list_parser.set_finished(command)
                command.already_executed = true
                return HLC_Utils.strip_command(command)
            else
                return
            end
        end,
        executable = function(command, myplayer, tick)
            if myplayer.get_item_count(command[2]) == 0 then
                return "Item not available (" .. command[2] .. ")"
            end

            if not Utils.in_range(command, myplayer, tick) then
                return "Player not in range (" .. command[2] .. ")"
            end
            
            local entity = {name=command[2], position=command[3], direction=command[4] or 0}
            if not Utils.can_player_place(myplayer, entity) then
                return "Something is in the way at " .. serpent.block(command[3]) .. " for " .. command[2] .. "."
            end
            
            return ""
        end,
        default_priority = 5,
        initialize = function (command, myplayer)
            command.distance = myplayer.build_distance
            command.rect = Utils.collision_box{name=command[2], position=Utils.copy(command[3])}
        end,
    },


    craft = {
        type_signature = {
            [2] = {"table", "string"},
            [3] = {"number", "nil"},
            need_intermediates = "boolean",
        },
        execute = function(command, myplayer)
            local craft = command.data.crafts[command.data.craft_index]
            local return_commands = {}

            while Utils.can_craft(craft, myplayer, craft.need_intermediates) do
                local cmd = {"craft", craft.name, 1, already_executed = true}
                TAScommands["craft"](cmd, myplayer)
                table.insert(return_commands, cmd)

                craft.count = craft.count - 1
                if craft.count == 0 then
                    command.data.craft_index = command.data.craft_index + 1
                    craft = command.data.crafts[command.data.craft_index]
                end

                if not craft then
                    command_list_parser.set_finished(command)
                    break
                end
            end

            return table.unpack(return_commands)
        end,
        executable = function(command, myplayer, tick)
            local item = command.data.crafts[command.data.craft_index].name
            local recipe = myplayer.force.recipes[item]
            local craft = command.data.crafts[command.data.craft_index]

            if not recipe.enabled then
                return "Recipe " .. item .. " is not available."
            end

            if not Utils.can_craft(craft, myplayer, craft.need_intermediates) then
                return "The requested item cannot be crafted."
            end

            return ""
        end,
        default_priority = 5,
        initialize = function(command)
            if type(command[2]) == "string" then
                command[3] = command[3] or 1
                command.data.crafts = {{name=command[2], count=command[3], need_intermediates=command.need_intermediates}}
            elseif type(command[2]) == "table" then
                command.data.crafts = {}
                for _, craft in pairs(command[2]) do
                    local need_intermediates = craft.need_intermediates
                    if need_intermediates == nil then
                        need_intermediates = command.need_intermediates
                    end
                    local name = craft[1] or craft.name
                    local count = craft[2] or craft.count
                    command.data.crafts[#command.data.crafts + 1] = {name = name, count = count, need_intermediates = need_intermediates}
                end
            else
                LogUI.errprint("Craft: Wrong parameter type")
            end

            command.data.craft_index = 1
        end
    },


    mine = {
		type_signature = {
			[2] = "position",
			[3]  = {"nil", "string"},
			amount = {"nil", "number"},
		},
		execute = HLC_Utils.strip_command,

		executable = function(command, myplayer, tick)
			if not Utils.in_range(command, myplayer) then
				return "Out of range"
			end

			if global.command_list_parser.current_mining >= command.data.amount then
				command_list_parser.set_finished(command)
				global.command_list_parser.current_mining = 0
				return "finished"
			end

			return ""
		end,

		default_priority = 6,

		initialize = function (command, myplayer)
			local position = command[2]
			if not command.amount then command.amount = 1 end

			command.data.amount = command.amount or 1

			local type = nil

			if command[3] then
				type = command[3]

				if type == "stone-rock" or type == "rock" then type = "simple-entity" end
				if type == "res" then type = "resource" end
			end

			local entity = Utils.get_entity_from_pos(position, myplayer, type)

			command.distance = myplayer.resource_reach_distance

			if entity then
				command.rect = Utils.collision_box(entity)
				command[2] = {entity.position.x, entity.position.y}
			else
				LogUI.errprint("There is no mineable thing at (" .. serpent.block(position) .. ")")
				command.rect = {Utils.copy(position), Utils.copy(position)}
			end
		end,
		default_action_type = action_types.selection,
    },
    

    pickup = {
		type_signature = {
			oneshot = {"nil", "boolean"},
			ticks = {"nil", "number"},
		},
		execute = function (command, myplayer, tick)
			if command.ticks then
				if command.data.final then
					if tick >= command.data.final then
						command_list_parser.set_finished(command)
					end
				else
					command.data.final = tick + command.ticks
				end
			elseif command.oneshot then
				command_list_parser.set_finished(command)
			end
			
			return HLC_Utils.strip_command(command)
		end,
		default_priority = 100,
	},


    put = {
		type_signature = {
			[2] = "position",
			[3] = "string",
			[4] = {"nil", "number"},
			[5] = {"nil", "number"},
		},
		execute = function(command, myplayer, tick)
			command_list_parser.set_finished(command)
			
			return {command[1], command[2], command[3], command.data.count, command.data.inventory}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity or not command.data.entity.valid then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, entities_with_inventory)
				if not command.data.entity then
					return "No valid entity found!"
				else
					if not command.rect then
						command.rect = Utils.collision_box(command.data.entity)
						command.distance = myplayer.reach_distance
					end
				end
			end

			local item = command[3]

			if not command[4] then
				command.data.count = math.min(myplayer.get_item_count(item), game.item_prototypes[item].stack_size)
			end
			
			if myplayer.get_item_count(item) < command.data.count then
				return "Not enough of " .. item .. " in inventory"
			end

			if not command.data.inventory then -- TODO: cargo wagon is missing here
				command.data.inventory = command.inventory
				if not command.data.inventory then
					local item_type = game.item_prototypes[item].type
					if command.data.entity.type == "furnace" then
						if item == "raw-wood" or item == "coal" then
							command.data.inventory = defines.inventory.fuel
						else
							command.data.inventory = defines.inventory.furnace_source
						end
					elseif command.data.entity.type == "mining-drill" then
						command.data.inventory = defines.inventory.fuel
					elseif command.data.entity.type == "boiler" then
						command.data.inventory = defines.inventory.fuel
					elseif command.data.entity.type == "assembling-machine" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.assembling_machine_modules
						else
							command.data.inventory = defines.inventory.assembling_machine_input
						end
					elseif command.data.entity.type == "lab" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.lab_modules
						else
							command.data.inventory = defines.inventory.lab_input
						end
					elseif command.data.entity.type == "car" then
						command.data.inventory = defines.inventory.car_trunk
					elseif command.data.entity.type == "rocket-silo" then
						if item_type == "module" then
							command.data.inventory = defines.inventory.assembling_machine_modules
						elseif item == "satellite" then
							command.data.inventory = defines.inventory.rocket_silo_rocket
						else
							command.data.inventory = defines.inventory.assembling_machine_input
						end
					elseif command.data.entity.type == "container" then
						command.data.inventory = defines.inventory.chest
					else
						return "Inventory could not be determined"
					end
				end
			end

			if command.data.entity.type == "assembling-machine" and (not command.data.entity.recipe) then
				return "Recipe is not set for assembling-machine"
			end

			if not Utils.in_range(command, myplayer, tick) then
				return "Out of range (" .. item .. ")"
			end

			return ""
		end,
		default_priority = 5,
		default_action_type = action_types.selection,
		initialize = function (command, myplayer)
			command.data.count = command[4]
			command.data.inventory = command[5]
		end
	},


    recipe = {
		type_signature = {
			[2] = "position",
			[3] = "string",
		},
		executable = function(command, myplayer, tick)
			if not command.data.entity or not command.data.entity.valid then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, "assembling-machine", 0.5)
			end

			if command.data.entity and command.data.entity.valid then
				command.rect = Utils.collision_box(command.data.entity)
			else
				return "Entity not built"
			end

			if Utils.in_range(command, myplayer, tick) then
				return ""
			else
				return "Player not in range"
			end
		end,

		default_priority = 5,
		default_action_type = action_types.ui,
		initialize = function (command, myplayer)
			command.data.ui = Utils.copy(command[2])
			command.distance = myplayer.build_distance
			--command.rect = collision_box{name=command[2], position=copy(command[3])}
		end,
    },
    
    
    rotate = {
		type_signature = {
			[2] = "position",
			[3] = "string",
		},
		execute = HLC_Utils.return_self_finished,
		executable = function (command, myplayer, tick)
			if not command.data.entity then
				command.data.entity = Utils.get_entity_from_pos(command[2], myplayer)
			end

			if command.data.entity and command.data.entity.valid then
				command.rect = Utils.collision_box(command.data.entity)
			else
				return "Entity not built"
			end

			if Utils.in_range(command, myplayer, tick) then
				return ""
			else
				return "Player not in range"
			end
		end,
		default_priority = 5,
		default_action_type = action_types.selection,
		initialize = function (command, myplayer)
			command.distance = myplayer.build_distance
		end,
    },
    

	tech = {
		type_signature = {
			[2] = "string"
		},
		default_priority = 5,
		execute = HLC_Utils.return_self_finished,
		executable = function (command, myplayer, tick)
			if (not myplayer.force.current_research) or command.change_research then
				return ""
			else
				return "There is something researching and changing is not allowed."
			end
		end,
	},


    take = {
		type_signature = {
			[2] = "position",
			[3] = {"nil", "string"},
			[4] = {"nil", "number"},
			inventory = {"nil", "number"},
			type = {"nil", "string"},
		},
		execute = function(command, myplayer, tick)
			command_list_parser.set_finished(command)
			
			return {command[1], Utils.copy(command[2]), command.data.item, command.data.amount, command.data.inventory, action_type = command.action_type}
		end,
		executable = function(command, myplayer, tick)
			if not command.data.entity then
				if command.type then
					command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, command.type)
				else
					command.data.entity = Utils.get_entity_from_pos(command[2], myplayer, entities_with_inventory)
				end

				if not command.data.entity then
					return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
				end
			end

			if not command.data.entity.valid then
				command.data.entity = nil
				return "No valid entity found at (" .. command[2][1] .. "," .. command[2][2] .. ")"
			end

			if not command.rect then
				command.rect = Utils.collision_box(command.data.entity)
				command.distance = myplayer.reach_distance
			end

			if not command.data.inventory then
				command.data.inventory = command.inventory
				if not command.data.inventory then
					local invs = {
						furnace = defines.inventory.furnace_result,
						["assembling-machine"] = defines.inventory.assembling_machine_output,
						container = defines.inventory.chest,
						car = defines.inventory.car_trunk,
						["cargo-wagon"] = defines.inventory.cargo_wagon,
						["mining-drill"] = defines.inventory.fuel
					}
					command.data.inventory = invs[command.data.entity.type]

					if not command.data.inventory then
						LogUI.errprint("No inventory given and automatically determining the inventory failed! Entity type: " .. command.data.entity.type)
						return "No inventory given and automatically determining the inventory failed! Entity type: " .. command.data.entity.type
					end
				end
			end

			-- TODO: if no item and amount are given, take the entire inventory as a selection action. Otherwise, it is a ui action

			if not command.data.item then
				command.data.item = command[3]
				if not command.data.item then -- take the first thing in the inventory
					local entity_inventory = command.data.entity.get_inventory(command.data.inventory)

					if entity_inventory and entity_inventory[1] and entity_inventory[1].valid_for_read then
						command.data.item = command.data.entity.get_inventory(command.data.inventory)[1].name
					else
						local x, y = Utils.get_coordinates(command[2])
						return "Entity " .. command.data.entity.name .. " at (" .. x .. "," .. y .. ") has no valid inventory item to guess"
					end
				end
			end

			command.data.amount = command[4]
			if (not command.data.amount) or (command.data.amount == command.data.entity.get_inventory(command.data.inventory).get_item_count(command.data.item)) then
				command.data.amount = command.data.entity.get_inventory(command.data.inventory).get_item_count(command.data.item)
				command.action_type = action_types.selection
			else
				command.action_type = action_types.ui
				command.data.ui = Utils.copy(command[2])
			end

			if command.data.amount == 0 then
				return "You cannot take 0 items!"
			end

			if command.data.entity.get_item_count(command.data.item) < command.data.amount then
				return "Not enough items available!"
			end

			if not Utils.in_range(command, myplayer) then
				return "Player too far away"
			end

			return ""
		end,
		default_priority = 5,
	},


    ["throw-grenade"] =
	{
		type_signature = {
			[2] = "position",
		},
		execute = function(command)
			command_list_parser.set_finished(command)
			global.high_level_commands.throw_cooldown = game.tick
			return HLC_Utils.strip_command(command)
		end,
		default_action_type = action_types.throw,
		executable = function (command, myplayer, tick)
			if myplayer.get_item_count("grenade") < 1 then
				return "Need more grenades!"
			end
			if Utils.sqdistance(myplayer.position, command[2]) > 15^2 then
				return "Not in range!"
			end
			if global.high_level_commands.throw_cooldown and game.tick - global.high_level_commands.throw_cooldown < 30 then
				return "Cooldown not expired yet!"
			end

			return ""
        end
    }
}
