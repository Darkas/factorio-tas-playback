## High Priority:
- UI Option: Number of commands to show.
- New type of move command: give a direction and walk in that direction until condition is satisfied
- We really need a better naming scheme: queue, set, list - sounds like cs students in first year.
- Move run control code out of control.lua
- Add the after_passed conditition, which allows a command to be executed after the collision box of the command has been entered (useful for build, almost the same as on_enting_area)
- Implement the "set-variable" (also add, remove for tables) command to blacklist things from passive-take, auto-refuel etc. and other things.
- Passive take needs the runtime optimizations that auto-refuel already has.
- Passive-take should get a position param - if set, only consider that entity.
- If the first parameter of a command is a table of valid commands, interpret that as a "parallel" command.
- If a build order already exists, load it into the build order ui.
- Maybe remove move-sequence in favor of simple-sequence with move
- Moving to an entity should have the option to move into mining range as well

## Debug features:
- Log Craft Inactivity, unoptimal movement (UI alert), dump inventory into file
- Typecheck for areas and for entity positions
- Mark non-passive commands that have started over 5 command groups ago as red and display its namespace.

## Low Priority:
- Simple-Sequence doesnt work with build-command
- Desyncs in blueprint storage
- Auto-refuel sometimes seems to ignore entities or something, but this is currently not critical.
- Allow setting of the trigger area in the build order ui if the entity has been already built.
- The build order ui can only save once.
- Make the global table available in the run file.
- The build order ui needs a better way of setting the default group.
- Remove the phantom commands.

## Bugs & Caveats: 
- Two auto-take cmds that take the same item are problematic!
- Mining and deconstructing buildings is not compatible with blueprints
- Generated Blueprint ghosts being mined may mess up the run
- Blueprinting logic currently assumes all buildings are <= 5x5. Dont build rocket silos per blueprint!
- Fast-Replace build does not check full inventory and handle modules

## Fix-Later:
- Sequence has a 1-tick delay
- Move has a 1-tick delay
- Mining adds 0.5 to both coordinates if they are integers. Remove that.
- Mining currently doesn't always prevent moving.
- Redo movement logic. It's super costly at the moment.
- Smarter movement