## TODO:
- Two auto-take cmds that take the same item are problematic!
- Log Craft Inactivity, unoptimal movement (UI alert), dump inventory into file
- UI Option: Number of commands to show.
- Redo movement logic. It's super costly at the moment.
- Smarter movement
- Make the global table available in the run file.
- require blueprints automatically if the command list needs them
- New type of move command: give a direction and walk in that direction until condition is satisfied
- For the build_order editor, make buttons for Next/Previous group and save and a toggle if the default group should be set to 0
- Mining adds 0.5 to both coordinates if they are integers. Remove that.
- We really need a better naming scheme: queue, set, list - sounds like cs students in first year.
- Move run control code out of control.lua

## Low Priority:
- Passive-take should get a position param - if set, only consider that entity.
- Simple-Sequence doesnt work with build-command
- Desyncs in blueprint storage
- Auto-refuel sometimes seems to ignore entities or something, but this is currently not critical.

## Caveats: 
- Mining and deconstructing buildings is not compatible with blueprints
- Generated Blueprint ghosts being mined may mess up the run
- Blueprinting logic currently assumes all buildings are <= 5x5. Dont build rocket silos per blueprint!
- Fast-Replace build does not check full inventory and handle modules


## Fix-Later:
- Sequence has a 1-tick delay