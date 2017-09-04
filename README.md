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
	* `{"build","<ITEM>", {<X>,<Y>}, <FACING DIRECTION>}` commands the player to build the specified item at the specified coordinates, with the item facing a certain direction. The `<FACING DIRECTION>` should be an element of the factorio class [`defines.direction`](http://lua-api.factorio.com/latest/defines.html#defines.direction ). NOTE: The specified position is must be entered as the center of the entity. Otherwise, you do things that are not possible in the base game.
	* `{"put",{X,Y},"<ITEM>", <AMOUNT>, <destination inventory type>}` commands the player to put the specified amount of the specified item into the inventory of the entity at the given coordinates. The `<destination inventory type>` must be an element of the factorio class [`defines.inventory`](http://lua-api.factorio.com/latest/defines.html#defines.inventory ) that says which inventory slot is to be used. 
	* `{"speed", <speed>}` sets the game speed if `allowspeed` is at `true`. Otherwise, a warning will be generated. 
	* `{"take",{<X>,<Y>},"<ITEM>",<AMOUNT>,<source inventory type>}` commands the player to take the specified amount of the specified item from the inventory of the entity at the given coordinates. The `<source inventory type>` must be an element of the factorio class [`defines.inventory`](http://lua-api.factorio.com/latest/defines.html#defines.inventory ) that says which inventory slot is to be used. 
	* `{"tech", <RESEARCH>}` sets the current research as specified. 
	* `{"print", "<text>"}` prints some text in the tchat. 
	* `{"recipe", {<X>,<Y>}, <recipe>}` sets the recipe of the entity at the given coordinates. 
	* `{"rotate", {<X>,<Y>}, "<direction>"}` rotates the entity at the given coordinates to face the direction specified, among directions `N`,`S`,`E`,`W`. 
	* `{"stopcraft", <Index>, <Quantity>}` cancels the crafting of the given quantity of the items at the given index in the queue. If the `<Quantity>` is not specified, 1 will be used. 
	* `{"pickup"} picks up items from the floor around the player.
	
	
## High Level Language
This fork is creating an abstracted language from the elementary actions given in the main mod. The goals are twofold, for one out input contains as little reference to ticks as possible and instead we determines the tick in which an action needs to run depending on the game state while the game is running. We also add some more abstracted commands. For example the action that takes items from a furnace depends not on a tick but on the inventory of the furnace. We enqueue technologies instead of giving the tick in which the technology finishes, we walk to a position, we automatically refuel burner-miners, we allow building a whole blueprint.

The following is an example of our language in use.
```
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

```

Currently implemented commands:
* `{"auto-move-to", {<X>,<Y>}}`: move to a position, walking diagonal first, without smart path-finding around entities.
* `{"auto-move-to-command", "<command name>"}`: move to the closest point from the player that allows the command with the given name to be executed.
* `{"build", <entity>, {<X>,<Y>}, <facing direction>}`: NOTE: The positions for build are currently required to be at the center of the entity. Otherwise, you do impossible stuff
* `{"craft", <item>, <count>}`: 
* `{"auto-refuel", "<type>", {<X>,<Y>}}`: automatically refuel the entity at the location. Where type is "m" for burner mining drill, "f" for stone furnace and "b" for boiler, mining drills get refueled after 1600 ticks, furnaces after 2660 ticks, these might not be perfectly exact values (they are guaranteed to be less than 10 ticks too low). 
* `{"rotate", {<X>, <Y>}, "<direction>"}`
* `{"tech", "<research-name>", change_research = <bool>}`: Set research. If change_research is true then this will overwrite the current research, otherwise it is only activated when the current research has been completed.
* `{"mine", {<X>,<Y>}, amount=...}`: It is assumed that iron, coal and copper need 124 ticks, stone needs 95 ticks
* `{"take", {<X>,<Y>}, "<item>", <amount>, <inventory>}`: Can infer item, amount and inventory from the position
* `{"put", {<X>,<Y>}, "<item>", <amount>, <inventory>}`: Can infer amount and inventory from position and item.
* `{"entity-interaction", {<X>,<Y>}}`: This is just a pointer to an entity that can be used as a target for other commands, for example "auto-move-to-command"
* `{"pickup", oneshot}`: Pick up items from floor. If `oneshot` is set, this will be active only once, otherwise it stays active until it is deactivated.
* `{"recipe", {<X>,<Y>}, <recipe>}`

To be implemented:

{"build-blueprint", "<name>", {<X>, <Y>}}
"move"
"throw"
"vehicle"
"auto-take"
"stop-auto-refuel"
"stop-auto-take"
"stop-auto-move-to"
{"stop", name="<name>"} stop the command with the specified name. name can be of the form "name" or "group_name.name", if no group name is specified it refers only to the current group.

Currently implemented conditions:
* `on_entering_range=<bool>`: as soon as this action is possible
* `on_leaving_range=<bool>`: right before this action becomes impossible
* `on_tick={<tick>}`: do this on or after a certain tick
* `on_relative_tick = {<tick>, <name>}`: do this on or after a given amount of ticks have passed since the command with given name finished or since the current command set began (if the name is not set or the param is a single int).


To be implemented:
on_player_in_range=<range> (player is range away from )
on_exact_tick=<tick> (do this on exactly the tick - do we need this?)
on_exact_relative_tick={<tick>, <name>} (do this a given amount of ticks after the command with the given name finished or after the current command set began (if name is not set))
items_total={<item name>, <N>} (there are currently N of item name available (in the entire world))
needs_fuel={<X>,<Y>} (entity needs fuel)

--]]