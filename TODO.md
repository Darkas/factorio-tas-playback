## TODO:
- Log Craft Inactivity, unoptimal movement (UI alert), dump inventory into file
- UI Option: Number of commands to show.
- Redo movement logic. It's super costly at the moment.
- Smarter movement
- Make the global table available in the run file.
- New type of move command: give a direction and walk in that direction until condition is satisfied
- For the build_order editor, make buttons for Next/Previous group and save and a toggle if the default group should be set to 0
- We really need a better naming scheme: queue, set, list - sounds like cs students in first year.
- Move run control code out of control.lua
- Make sure the commandqueue contains only changes to movement state, mining state and picking state, remove flag continuous_move_commands. Should halve the filesize of the cmdqueue.
- Typecheck for areas and for entity positions
- Add the after_passed conditition, which allows a command to be executed after the collision box of the command has been entered (useful for build, almost the same as on_enting_area)
- Implement the "set-variable" (also add, remove for tables) command to blacklist things from passive-take, auto-refuel etc. and other things.
- Mark non-passive commands that have started over 5 command groups ago as red and display its namespace.
- Passive take needs the runtime optimizations that auto-refuel already has.

## Low Priority:
- Passive-take should get a position param - if set, only consider that entity.
- Simple-Sequence doesnt work with build-command
- Desyncs in blueprint storage
- Auto-refuel sometimes seems to ignore entities or something, but this is currently not critical.

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