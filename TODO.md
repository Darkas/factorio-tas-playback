## TODO:
- Passive-Take produces too many warnings.
- Two auto-take cmds that take the same item are problematic!
- Log Craft Inactivity, unoptimal movement (UI alert), dump inventory into file
- UI Option: Number of commands to show.
- Redo movement logic. It's super costly at the moment.
- Make high_level_commands a proper module.
- Make the global table available in the run file.
- Improve the warning given when a blueprint was added to the run but not to the blueprint_list.lua
- New type of move command: give a direction and walk in that direction until condition is satisfied
- Raise on_built_entity event when entities are built.
- Build order filename does not contain cmd name currently

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