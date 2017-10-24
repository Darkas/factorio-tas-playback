# factorio-tas-playback
TAS playback mod for factorio

## Installing the mod
* If using git : clone to `factorio/mods/tas_playback_0.0.1`
* If using an archive : Unpack the mod's contents into `factorio/mods/tas_playback_0.0.1`
* If using the mod portal (shouldn't be possible at the moment, but whatever) : Install the mod and unpack its contents.


## Creating a run
To create a run :
* Create a new folder `factorio/mods/tas_playback_0.0.1/scenarios/YourNewRunName/`
* Create a blueprint.dat file containing your run's map, like you would to create a scenario, and copy it into this folder.
 To do that :
	* Create a new game using your chosen map seed
	* Save this game without doing anything in the world
	* Exit factorio
	* From the console, navigate into the factorio's binary folder
	* Type the command `factorio --map2scenario mysave` (with mysave replaced by the name you used to save your map)
	* Copy the file `factorio/scenarios/mysave/blueprint.dat` into `factorio/mods/tas_playback_0.0.1/scenarios/YourNewRunName/`
	* You can now remove the folder `factorio/scenarios/mysave/` as well as your save with the empty world.
* Copy the files `configuration.lua` and `control.lua` from the folder `factorio/mods/tas_playback_0.0.1/scenarios/Test-TAS/`
 into `factorio/mods/tas_playback_0.0.1/scenarios/YourNewRunName/`
* Create the file that will contain the instructions for your run into the folder `factorio/mods/tas_playback_0.0.1/scenarios/YourNewRunName/`.
 You can choose the name you want for this file. For example : `YourRunFile.lua`
* Open the file configuration.lua in a text editor and edit the config.run_name and config.run_file variables to contain the name of your run's scenario and of the file that contains the commands.
In our case, we will have :
```
config.run_name = "YourNewRunName"
config.run_file = "YourRunFile"
```
**__ATTENTION__ : These __MUST__ be the __EXACT__ names used as the folder name and the run's file name. Otherwise, the run will not work !**
* you can now start writing your run's commands into `YourRunFile.lua`.

## Playing a run
To start playing the run :
* In factorio menu, navigate to _Play_ -> _Scenarios_
* A scenario will appear as `tas_playback/YourNewRunName` (YourNewRunName being the name you used when you created the run's scenario, of course). Launch it.
* If your run's configuration file contains `config.autorun = true`, the run will automatically start when loading the scenario.
* If your run's configuration file contains `config.autorun = false`, you can use the chat command `/init_run` to start it at any moment.
 Your player will be repositionned at the right location and your inventory reset.
 Any modification that happened to the world since the game was started will, however, be kept.
* You can at any point save the run.
	* When you will reload it, the run will continue playing from the tick when it was saved.
	* Any modification that is made to the run between saving and loading and that happens after the tick where the game was saved will be taken into account.

## Additional information
* The mod will not let you start a _New Game_ while it is active.
	* If you want to play a regular game, toggle the mod.
	* If you want to play a TAS run, please use a scenario as instructed above.
* Due to the way the mod loads the instructions for the run, the scenarios have to be located in the mod's folder and cannot be located in the standard scenarios folder.
* The menu _Options_ -> _Mods_ gives you options about the level of verbosity you want when displaying what the run does.

## Writing a run
Your run file (in our example `YourRunFile.lua`) should start with the lines :
```
local commandqueue = {}

commandqueue["settings"] = {
    allowspeed = true
}
```
You can change `allowspeed = true` by `allowspeed = false` if you want to inhibit the `speed` commands of your run.

If you include the line `end_tick_debug = true` in the `settings` section, the game will give the player back the control of mouse selection after the end of input.

The rest of the file should consist of a series of instruction that take the following form :
```
commandqueue[<tick>] = {
    {<command1>, <options1>},
    {<command2>, <options2>},
	...
}
```
Where :
* `<tick>` is the number of the tick where these commands will be executed (the start of the run being tick 0)
* Each `{<command>, <options>}` sequence represents an action to be executed by the TAS. It can be chosen in the following list :
	* `{"move","<DIRECTION>"}` commands the player to start moving in a direction or stop. Directions can be `N`,`S`,`E`,`W`,`NE`,`SE`,`SW`,`NW` or `STOP`.
	* `{"craft","<ITEM>", <AMOUNT>}` commands the player to pocket-craft given amount of specified item.
	* `{"mine", {<X>,<Y>}}` commands the player to start mining at specified coordinated. To stop mining, replace `{<X>,<Y>}` with `nil`.
	* `{"build","<ITEM>", {<X>,<Y>}, <FACING DIRECTION>, <TYPE>}` commands the player to build the specified item at the specified coordinates, with the item facing a certain direction. The `<FACING DIRECTION>` should be an element of the factorio class [`defines.direction`](http://lua-api.factorio.com/latest/defines.html#defines.direction ). The `<TYPE>` parameter is used only for underground-belt, in that case it can be either "input" or "output". NOTE: The specified position is must be entered as the center of the entity. Otherwise, you do things that are not possible in the base game.
	* `{"put",{X,Y},"<ITEM>", <AMOUNT>, <destination inventory type>}` commands the player to put the specified amount of the specified item into the inventory of the entity at the given coordinates. The `<destination inventory type>` must be an element of the factorio class [`defines.inventory`](http://lua-api.factorio.com/latest/defines.html#defines.inventory ) that says which inventory slot is to be used.
	* `{"speed", <speed>}` sets the game speed if `allowspeed` is at `true`. Otherwise, a warning will be generated.
	* `{"take",{<X>,<Y>},"<ITEM>",<AMOUNT>,<source inventory type>}` commands the player to take the specified amount of the specified item from the inventory of the entity at the given coordinates. The `<source inventory type>` must be an element of the factorio class [`defines.inventory`](http://lua-api.factorio.com/latest/defines.html#defines.inventory ) that says which inventory slot is to be used.
	* `{"tech", <RESEARCH>}` sets the current research as specified.
	* `{"print", "<text>"}` prints some text in the tchat.
	* `{"recipe", {<X>,<Y>}, <recipe>}` sets the recipe of the entity at the given coordinates.
	* `{"rotate", {<X>,<Y>}, "<direction>"}` rotates the entity at the given coordinates to face the direction specified, among directions `N`,`S`,`E`,`W`.
	* `{"stopcraft", <Index>, <Quantity>}` cancels the crafting of the given quantity of the items at the given index in the queue. If the `<Quantity>` is not specified, 1 will be used.
	* `{"pickup"}` picks up items from the floor around the player for a single tick.
    * `{"throw-grenade", {<x>, <y>}}` make boom.


## High Level Language
This fork is creating an abstracted language from the elementary actions given in the main mod. The goals are twofold, for one the input contains as little reference to ticks as possible, on the other hand we want to have smarter and more abstract commands. Instead of referencing ticks directly we determine the tick in which an action needs to run automatically depending on the game state while the game is running. For example the action that takes items from a furnace depends not on a tick but on the inventory of the furnace. We enqueue technologies instead of giving the tick in which the technology finishes, we walk to a position, we automatically refuel burner-miners, we allow building a whole blueprint.

The following is an example of our language in use (Warning: Outdated!).
```lua
commandqueue["command_list"] = {
	{
		name = "start-1",
		commands = {
			--{"speed", 10},
			{"craft", "iron-axe", 1},
			{"auto-move-to-command", "mine-coal"},
			{"build", "stone-furnace", {-32,29}, 0},
			{"build", "burner-mining-drill", {-34,29}, 2},
			{"mine", {-36.5,26.5}, amount=4, name="mine-coal"},
			{"auto-refuel"},
		}
	},
	{
		name = "start-2",
		commands = {
			{"mine", {-56,16}}
		}
	},
}
```

Commands are arranged in command groups which enable some elementary flow control. Each time a group finishes execution, all commands from the next group are loaded. If the `required` field is set in the block's properties, we instead wait for the named commands given in that field. Each group needs a unique name and a list of commands.

A command is a table of the following format: `{"<type>", "<arg1>", "<arg2>", ..., named_arg1 = value1, named_arg2 = value2, ... }`. The unnamed arguments are typically arguments without a clearly defined default, for example the type of building we want to build or the type of inventory we want to put items into. Unnamed arguments can still be omitted occasionally because we try to infer them sometimes. Other arguments are given by name, this includes arguments with a clear default, conditions to the execution of the command and the script name of a command. Typically all named arguments are optional.

In every tick we execute the executable command in the working set with the highest priority, unless there is a command which has `on_leaving_range` set, in that case we execute the first such command. Once we determine this command, we also execute all commands that are compatible with this command in the same tick. A command in the working set is thus generally executed as soon as possible unless there is a command with higher priority. For example a build command is usually executed as soon as we get into build range. The user can add conditions to a command which make it not executable until these conditions are satisfied, thus delaying the execution of the command. For example in `{"build", "furnace", {0,0}, on_leaving_range = true}`, the command will be executed when we leave the range.

The user can set a name in each command. Each command name has the form `groupname.name`, if the groupname is omitted, we automatically prepend the name of the current command group. The name can then be used to refer to that command in later execution. Every command can have a `command_finished` field, if this is set then the command is only executable if that command is executed. Similarly, if a command block has a `command_finished` name set, it will only be started when that command is finished. The name of a command is also used as a parameter for a number of commands that refer to other commands like `stop-command` and `auto-move-to-command`. This is demonstrated in the following example: We start by building a miner and stone furnace and mining two pieces of coal. We fuel the mining drill, then the furnace. When the mining finishes we move to a rock and mine it.

```lua
commandqueue.command_list = {

	{
		name = "start-1",
		{
			{"build", "burner-mining-drill", {-15,15}, 2},
			{"build", "stone-furnace", {-13,15}, 0},
			{"mine", {-11.5,12.5}, amount=2, name="mine-coal"},
			{"auto-refuel", {-13,15}},
			{"auto-refuel", {-15,15}, priority=4, name="refuel.coal-1"},
		},
	},
	{
		name = "start-2",
		required = {"mine-coal"},
		commands = {
			{"auto-move-to-command", "mine-rock"},
			{"mine", {-40,11}, amount=1, name="mine-rock"},
		}
	},
	...
	{
		name = "later",
		required = "assembler-built",
		{
			{"stop-command", "first.coal-1"},
			{"stop-command", "refuel.coal-1"},
		}
	}
}
```

Currently implemented commands:
* `{"alert", "<cmd-group-name>"}`: Alert the player if a certain cmd-group starts and set game-speed to 0.05. Will pause the game if in SP.
* `{"auto-build-blueprint", <name>, {<X>, <Y>}, rotation=<rotation>}`: Automates building blueprints (movement must still be entered manually though). Add build commands, recipe commands and put commands (for modules) to the current command set as we get in build range of the individual entities in the blueprint. `<name>` refers to the name of the blueprint in the `blueprint_data_raw` field, this can be set in the `blueprint_list.lua` of the run scenario - see examples. We have a mod that adds a command to conveniently export blueprints. The second argument is the offset, the third argument is the rotation and should be one of `defines.direction.north, east, south, west`. The blueprint build commands are added with the `on_leaving_range` constraint.
* `{"auto-refuel", min=..., amount=..., type=..., pos={<X>, <Y>}, skip_coal_drills=<boolean>}`: automatically refuel all burner mining drills, furnaces and boilers so they contain the given amount. If the parameters min and amount are not given, one piece of coal will be inserted a few frames before the entity runs out of coal. Otherwise, if the entity drops under min amount of coal, it will be refilled to amount. To only target certain entities, use type, pos and skip_coal_drills.
* `{"auto-take", <item>, <count>, exact = <bool>}`: Take items from surrounding entities until we have taken the given count. This will use the fewest take commands necessary to obtain this on the earliest tick possible, but it will likely only work when you are standing still.
* `{"build", <entity>, {<X>,<Y>}, <facing direction>, <type>}`: NOTE: The positions for build are currently required to be at the center of the entity. Otherwise, you do impossible stuff
* `{"craft", <item>, <count>, need_intermediates}`
* `{"craft", {{<item>, <count>, need_intermediates = <bool> or <table>}, {<item>, <count>}, ...}, need_intermediates = <bool> or <table>}`: Executes craft commands in order. If `need_intermediates` is set, the craft will only be started if all (or the given, if it is a table) necessary intermediate products in the recipe are already available.
* `{"craft-build", <entity>, {<X>, <Y>}, <facing direction>}`: Add a craft command for the entity, when that command is finished, add a build command.
* `{"display-contents", <type>, inventory_type=<inventory>, update_frequency=<ticks>, verbose=<bool>}`: Displays the contents of all entities of the given type as a floating text over them. Sometimes the inventory type can be guessed, otherwise it has to be specified. If verbose is true, contents are displayed for each item, otherwise the total number of items in the inventory is displayed.
* `{"display-warning" "<string>"}`: Display a warning string.
* `{"entity-interaction", {<X>,<Y>}}`: This is just a pointer to an entity that can be used as a target for other commands, for example "auto-move-to-command"
* `{"freeze-daytime"}`
* `{"mine", {<X>,<Y>}, amount=<int>, type=<string>}`: The `type` param is the entity type of the mined entity - typically "resource", "tree"; instead of "simple-entity" the string "rock" can also be used here.
* `{"move", {<X>,<Y>,entity=<bool>}}`: move to a position, walking diagonal first, without smart path-finding around entities. If entity is set to true, move in range of the entity at the given position.
* `{"move", "<command>"}`: move to the closest point from the player that allows the command with the given name to be executed.
* `{"move-sequence", {x1, y1}, ..., pass_arguments}`: Move to the positions in order.
* `{"parallel", {<command-list>}}`: Add the commands in the list to the current command set.
* `{"passive-take", <item>, <type>}`: Spawns `take` commands whenever there is an `<item>` in range available from an entity of the given type. `<type>` is not optional.
* `{"pickup", oneshot=<bool>, ticks=<number>}`: Pick up items from ground. If `oneshot` is not set, we pick up until this command is stopped, or if the given amount of ticks have passed.
* `{"put", {<X>,<Y>}, "<item>", <amount>, <inventory>}`: Can infer amount and inventory from position and item.
* `{"recipe", {<X>,<Y>}, <recipe>}`
* `{"rotate", {<X>, <Y>}, "<direction>"}`
* `{"sequence", {cmd1, cmd2}, pass_arguments={...}}`: Add the commands to the current command set, in order, only adding one after the previous is completed.
* `{"simple-sequence", "<command>", {<x1>, <y1>}, ... , pass_arguments={k1=v1, k2=v2 ...}`: Execute the given command at the locations in the order as given and walk to those locations in between executions. All arguments in the pass_arguments table will be added to each command. Example: `{"simple-sequence", "mine", {0, 1}, {5, -4}, pass_arguments={[3]="tree"}}` mines two trees. Does currently not work with "build".
* `{"speed", <speed>}`: Sets the game speed.
* `{"stop"}`: Does nothing.
* `{"stop-command", "<name>"}`: Remove the named command from the working set. Name can be of the form "name" or "group_name.name", if no group name is specified it refers only to the current group.
* `{"simple-sequence", "<cmd-type>", {<position-list>}, passed_arguments = {...}}` Spawn commands to execute the given command at the specified locations, with 'move-to-command's automatically generated. The positions will be passed in the order they are given. Example: `{"simple-sequence", "mine", {{5, 4}, {-4, 1}, passed_arguments = {type="tree"}}` sends the player to mine two trees.
* `{"take", {<X>,<Y>}, "<item>", <amount>, <inventory>}`: Can infer item, amount and inventory from the position
* `{"tech", "<research-name>", change_research = <bool>}`: Set research. If change_research is true then this will overwrite the current research, otherwise it is only activated when the current research has been completed.
* `{"tech", <research>, change_research=<bool>}`: Set research. If change_research is not set, this will only change the research when the current reseach is done. Note this currently shouldnt be used to queue multiple researches.
* `{"throw-grenade", {<x>, <y>}}`.

To be implemented:

"vehicle"

Further ideas:
"move" with different strategies - diagonal first, straight first, saw blade pattern
"build-blueprint" different build conditions - on_moving_away, on_leaving_range, on_entering_range

Currently implemented conditions:
* `on_entering_area={<top_left>, <bottom_right>}`: start the command if the given area is entered
* `on_leaving_range=<bool>`: shortly before this action becomes impossible
* `on_tick={<tick>}`: do this on or after a certain tick
* `on_relative_tick = {<tick>, <name>}`: do this on or after a given amount of ticks have passed since the command with given name finished or since the current command set began (if the name is not set or the param is a single int).
* `items_available = {"<name>", <count>}`: Execute only when the specified amount of items is in inventory.
* `items_total = {"<name>", <count>, pos={<x>, <y>}}`: Execute only when the specified amount of items is in player inventory plus optionally the entity at the given position if `pos` is set, or plus the other entity's inventory if the command is "take").
* `command_finished = "<name>"`: Name of command that needs to terminate before this one is executable.


To be implemented:
on_player_in_range=<range> (player is range away from )
on_exact_tick=<tick> (do this on exactly the tick - do we need this?)
on_exact_relative_tick={<tick>, <name>} (do this a given amount of ticks after the command with the given name finished or after the current command set began (if name is not set))
on_moving_away (player is moving away from the command target)


## Chat Commands

`/alert <cmd-group>` Alert the player if a certain cmd-grp starts. Pause game when command group is reached and set game speed = 0.05
`/exportqueue <name>` Export the cmd queue to a file in `script-output/TAS_<tas_name>_<name>_queue.lua` or `script-output/TAS_<tas_name>_queue.lua` if `name` is not set.
`/init_run` Start the run if it is not started already.
