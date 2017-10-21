## TODO:
- Passive-Take produces too many warnings.
- Two auto-take cmds that take the same item are problematic!
- Log Craft Inactivity, unoptimal movement (UI alert), dump inventory into file
- UI Option: Number of commands to show.
- Redo movement logic. It's super costly at the moment.
- Make high_level_commands a proper module.


## Low Priority:
- Passive-take should get a position param - if set, only consider that entity.
- Simple-Sequence doesnt work with build-command

## Caveats: 
- Mining burners causes errors for the auto-refuel system
- Mining and deconstructing buildings is not compatible with blueprints
- Generated Blueprint ghosts being mined may mess up the run
- Blueprinting logic currently assumes all buildings are <= 5x5. Dont build rocket silos per blueprint!


## Fix-Later:
- Sequence has a 1-tick delay