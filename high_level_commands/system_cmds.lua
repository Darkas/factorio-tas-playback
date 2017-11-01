-- auto-build-blueprint

-- luacheck: globals command_list_parser Utils high_level_commands LogUI Event TAScommands Blueprint BPStorage HLC_Utils
-- luacheck: globals strip_command return_self_finished action_types entities_with_inventory
-- luacheck: ignore 212

local function simple_set_command(name, key, value)
	return {
		type_signature = {
			[2] = "string",
			_no_conditions = true
		},
		execute = HLC_Utils.empty,
		default_priority = 100,
		initialize = function(command, myplayer)
			local found
			for _, cmd in pairs(global.command_list_parser.current_command_set) do
				if cmd.name == command[2] or cmd.namespace .. cmd.name == command[2] then
					cmd[key] = value
					found = true
					break
				end
			end

			if not found then LogUI.errprint(name .. ": command " .. command[2] .. "not found.") end
			command_list_parser.set_finished(command)
		end
	}
end

return {
	alert = {
		type_signature = {
			[2] = "string",
		},
		execute = function(command, myplayer, tick) 
			if #game.players == 1 then
				game.show_message_dialog{text="Now entering: " .. command[2]}
			else
				game.print("Now entering: " .. command[2])
			end
			command_list_parser.set_finished(command)
		end
	},
	["disable-cmd"] = simple_set_command("disable-cmd", "disabled", true),

	["display-warning"] = {
		type_signature = {
			[2] = "string",
		},
		execute = HLC_Utils.empty,
		default_priority = 100,
		initialize = function (command, myplayer)
			LogUI.errprint(command[2])
			command_list_parser.set_finished(command)
		end,
	},
	
	["display-contents"] = {
		type_signature = {
			[2] = "string",
			["inventory_type"] = {"number", "nil"},
			["update_frequency"] = {"number", "nil"},
			["verbose"] = {"boolean", "nil"},
		},
		default_priority = 100,
		execute = function(command, myplayer, tick)
			if tick % command.data.update_frequency ~= 0 then
				return
			end
			
			local entity = global.command_list_parser.entities_by_type[command.data.type][command.data.cached_entities + 1]
			
			while entity do
				command.data.cached_entities = command.data.cached_entities + 1
				
				if entity.valid and entity.get_inventory(command.data.inventory) then
					table.insert(command.data.entity_info, {entity, Utils.display_floating_text(entity, "", true)})
				end
				
				entity = global.command_list_parser.entities_by_type[command.data.type][command.data.cached_entities + 1]
			end
			
			for _, entry in pairs(command.data.entity_info) do
				local inventory = entry[1].get_inventory(command.data.inventory)
				local new_text = ""
				
				if command.verbose then
					for item, count in pairs(inventory.get_contents()) do
						new_text = new_text .. item .. ": " .. Utils.printable(count) .. ", "
					end
				else
					new_text = Utils.printable(inventory.get_item_count())
				end
				
				Utils.update_floating_text(entry[2], new_text)
			end
		end,
		initialize = function(command, myplayer, tick)
			command.data.type = command[2]
			
			if command.inventory_type then
				command.data.inventory = command.inventory_type
			else
				if command.data.type == "assembling-machine" then
					command.data.inventory = defines.inventory.assembling_machine_output
				elseif command.data.type == "furnace" then
					command.data.inventory = defines.inventory.furnace_result
				elseif command.data.type == "container" then
					command.data.inventory = defines.inventory.chest
				elseif command.data.type == "lab" then
					command.data.inventory = defines.inventory.lab_input
				else
					error("Cannot guess inventory_type!")
				end
			end
			
			command.data.update_frequency = command.update_frequency or 10
			
			command.data.entity_info = {}
			command.data.cached_entities = 0
		end,
	},

	["enable-cmd"] = simple_set_command("enable-cmd", "disabled", false),

	["enable-manual-walking"] = {
		type_signature = {},
		execute = return_self_finished,
	},

	parallel = {
		type_signature = {
			[2] = "table",
		},
		execute = HLC_Utils.empty,
		executable = function(command, myplayer, tick)
			if command.data.all_commands then
				local finished = true
				local cmd = command.data.all_commands[1]
				while cmd do
					if cmd.finished then 
						table.remove(command.data.all_commands, 1) 
					else
						finished = false
						break
					end
					cmd = command.data.all_commands[1]
				end
				
				if finished then
					command_list_parser.set_finished(command)
					return "finished"
				else
					return "Waiting for all commands to finish."
				end
			else
				return ""
			end
		end,
		initialize = HLC_Utils.empty,
		spawn_commands = function(command, myplayer, tick)
			local commands = {}
			command.data.all_commands = {}
			
			local i = 1
			if global.high_level_commands.parallel_name == command.data.parent_command_group.name then
				global.high_level_commands.parallel_index = global.high_level_commands.parallel_index + 1
			else
				global.high_level_commands.parallel_index = 1
				global.high_level_commands.parallel_name = command.data.parent_command_group.name
			end
			for index, _cmd in ipairs(command[2]) do
				local cmd = Utils.copy(_cmd)
				
				if not cmd.name then
					i = i + 1
					cmd.name = i
				end
				
				if command.name then
					cmd.namespace = command.namespace .. command.name .. "."
				else
					cmd.namespace = command.namespace .. "parallel-" .. global.high_level_commands.parallel_index .. "."
				end
				table.insert(commands, cmd)
				table.insert(command.data.all_commands, cmd)
			end
			
			return commands
		end,
		default_priority = 100,
	},

	["stop-command"] = {
		type_signature = {
			[2] = "string",
			_no_conditions = true,
		},
		execute = HLC_Utils.empty,
		default_priority = 100,
		initialize = function (command, myplayer)
			if global.command_list_parser.finished_named_commands[command[2]]
			or global.command_list_parser.finished_named_commands[command.namespace .. command[2]] then
				LogUI.errprint("Attempting to stop command that is already finished: " .. command[2])
				command_list_parser.set_finished(command)
				return
			end
			for _, com in pairs(global.command_list_parser.current_command_set) do
				if com.name and Utils.has_value({command[2], command.namespace .. command[2]}, com.namespace .. com.name) then
					com.finished = true
					command_list_parser.set_finished(command)
					if com[1] == "mine" then
						global.command_list_parser.current_mining = 0
					end

					return
				end
			end

			LogUI.errprint("No command with the name " .. command[2] .. " found!")
		end,
	},
	["simple-sequence"] = {
		type_signature = {
			[2] = "string",
			[3] = {"table", "string"},
			[4] = {"table", "string", "nil"},
			pass_arguments = {"nil", "table"},
			table_arg = {"nil", "boolean"},
		},
		initialize = function(command, myplayer, tick)
			if global.high_level_commands.simple_sequence_name == command.data.parent_command_group.name then
				global.high_level_commands.simple_sequence_index = global.high_level_commands.simple_sequence_index + 1
			else
				global.high_level_commands.simple_sequence_index = 1
				global.high_level_commands.simple_sequence_name = command.data.parent_command_group.name
			end

			command.data.index = 0
			if command.name then
				command.data.namespace = command.namespace .. command.name .. "."
			else
				command.data.namespace = command.namespace .. command[2] .. "-sequence-" .. global.high_level_commands.simple_sequence_index .. "."
			end
		end,
		execute = HLC_Utils.empty,
		spawn_commands = function(command, myplayer, tick)
			command.data.index = command.data.index + 1
			if command.data.index + 2 > #command then
				command_list_parser.set_finished(command)
			else
				local cmd_arg
				
				if command.table_arg then
					cmd_arg = command[3][command.data.index]
				else
					cmd_arg = command[command.data.index + 2]
				end
				
				local cmd_name
				
				if type(cmd_arg) == type({}) and cmd_arg.name then
					cmd_name = cmd_arg.name
					cmd_arg.name = nil
				else
					cmd_name = "command-" .. command.data.index
				end
				
				command.data.prev_command = cmd_name
				
				local cmd = {
					command[2],
					cmd_arg,
					name=cmd_name,
					namespace=command.data.namespace,
					parent_namespace=command.namespace,
				}
				
				if command[2] == "move" then
					for k, v in pairs(command.pass_arguments or {}) do
						cmd[k] = v
					end
					return {cmd}
				else
					for k, v in pairs(command.pass_arguments or {}) do
						cmd[k] = v
					end

					return {
						cmd,
						{
							"move",
							cmd_name,
							namespace = command.data.namespace,
						}
					}
				end
			end
		end,
		executable = function(command, myplayer, tick)
			if not command.data.prev_command or global.command_list_parser.finished_named_commands[command.data.namespace .. command.data.prev_command] then
				return ""
			else
				return "Waiting for command: " .. command.data.prev_command
			end
		end,
		default_priority = 100,
	},
	
	sequence = {
		type_signature = {
			[2] = "table",
			pass_arguments = {"table", "nil"},
		},
		initialize = function(command, myplayer, tick)
			if global.high_level_commands.sequence_name == command.data.parent_command_group.name then
				global.high_level_commands.sequence_index = global.high_level_commands.sequence_index + 1
			else
				global.high_level_commands.sequence_index = 1
				global.high_level_commands.sequence_name = command.data.parent_command_group.name
			end

			command.data.index = 0
			if command.name then
				command.data.namespace = command.namespace  .. command.name .. "."
			else
				command.data.namespace = command.namespace .. "sequence-" .. global.high_level_commands.sequence_index .. "."
			end
		end,
		execute = HLC_Utils.empty,
		spawn_commands = function(command, myplayer, tick)
			command.data.index = command.data.index + 1
			if command[2][command.data.index] == nil then
				command_list_parser.set_finished(command)
			else
				local cmd = Utils.copy(command[2][command.data.index])
				for k, v in pairs(command.pass_arguments or {}) do
					cmd[k] = v
				end
			
				cmd.name = "command-" .. command.data.index
				cmd.namespace = command.data.namespace

				return { cmd }
			end
		end,
		executable = function(command, myplayer, tick)
			if command.data.index == 0 or global.command_list_parser.finished_named_commands[command.data.namespace .. "command-" .. command.data.index] then
				return ""
			else
				return "Waiting for command: command-" .. command.data.index
			end
		end,
		default_priority = 100,
	},

	["set-variable"] = {
		type_signature = {
			[2] = "string",
			[3] = {"nil", "string", "number", "boolean", "position", "rect"},
			_no_conditions = true,
		},
		execute = HLC_Utils.set_finished,
		default_priority = 100,
		initialize = function(command, myplayer, tick)
			global.high_level_commands.variables[command[2]] = Utils.copy(command[3])
		end,
	},
	speed = {
		type_signature = {
			[2] = "number",
		},
		execute = return_self_finished,
		default_priority = 100,
	},

}