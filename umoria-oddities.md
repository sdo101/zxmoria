# Umoria's own oddities

The one list of things in Umoria 5.7.15 that look like slips in its own source, found while matching it. Anything
new goes in here as soon as it is found, and stays here whatever we decide about it.

Our rule so far: where the player could tell the difference, play as Moria plays, slip and all; part company only
where the original plainly does not do what it set out to do, and say so in the code ("NOT Moria's" or "not as
Moria 5.7.15 has it") at the place it happens. Each entry: what Moria does, what we do, and where. The author decides
any that are open.

Started 16 October 2026, from notes that until then were spread through the code and not-yet.md.

## Parted company

- **Wizard `%` works only with the roguelike keys.** It is missing from the table of the original keys,
  although Moria's own help_wizard.txt lists it: originalCommands() in game_run.cpp turns every key it does not
  list into '~', "Anything illegal". Ours works with both, as the help says. Decided by the author, 16 October 2026.
  (stage-lib-wizard.bas, the note at the top)
- **Wizard `%` can identify the wrong thing.** Moria calls itemIdentify() with the object's number on the
  level, where a place in the pack is expected, so two unrelated things in the pack can be stacked or marked
  known. Ours makes the kind of object known and touches nothing else. (stage-lib-wizard.bas)
- **Wizard `@`'s warning is never seen.** Moria writes the next question straight over it. Ours waits for the
  message with -more- first. (stage-lib-wizard.bas)
- **Wizard Ctrl-E's "Searching" throws the answer away.** Moria sets the skill to the length of the question
  instead of the number typed. Ours sets it to the answer. (stage-lib-wizard-2.bas)
- **A save that fails leaves the speed wrong.** Moria's saveChar() takes the pack's weight out of everyone's
  speed and, when the write fails, the game carries on without putting it back. Ours works the weight out
  again. (stage-lib-save.bas, fub_sv_save())
- **"Use 'Q' to when you are ready to quit."** Moria's commandSaveAndExit() says this to a Total Winner who
  tries Ctrl-X with the roguelike keys, "to when" and all (the original keys get "Use <Control>-K when you are
  ready to quit."). Ours says "Use 'Q' when you are ready to quit.", and only for the roguelike keys, as Moria
  chooses. Decided by the author, 16 October 2026: mend the words. (src\messages.txt, stage-lib-commands.bas Ctrl-X)

## Copied, because the player can see the difference

- **"Click!" at a chest with nothing left to undo.** The spells that unlock chests test the whole of a chest's
  flags (item.flags != 0), and the top half of the flags says what treasure is inside, so a chest that has
  been unlocked and disarmed still clicks every time until it is emptied. Found 16 October by
  tools\test\chests.ps1. (stage-lib-chests.bas, fub_ch_unlock())
- **The Wand of Trap/Door Destruction goes through rock.** spellDestroyDoorsTrapsInDirection() carries on
  while it is within range OR the way is open (`||`), where the Wand of Disarming stops at the first wall
  (`&&`), so it reaches doors and traps behind walls, and past its range along an open corridor. Ours has a
  guard at the edge of the map, where Moria relies on the rock. (stage-lib-spells-5.bas, fub_s5_destroy_doors())
- **Backing out of selling makes the step into the store free.** inventoryGetInputForItemId() sets
  player_free_turn on ESCAPE, which is right for a command, but in a store it is still set when storeEnter()
  returns, in the middle of the step that went in: the monsters lose that turn and no new turn begins. Only an
  inventory command in the store sets it back ("No free moves here"). So a visit with an ESCAPE at "Which one?"
  is a turn shorter than one without. Found 17 October by comparing an Elf ranger selling.
  (stage-crawl.bas, coming out of a store; stage-store.bas, the inventory commands)

## Makes no difference, nothing to copy

- **"This character is already on the scoreboard" can never be shown.** loadGame() tests
  `(!game.noscore) & 0x04`, which is always 0 (! gives 0 or 1), so the message never appears, the noscore bit
  for a duplicate is never set, and "Duplicate" never reaches the status line. Ours has none of it, which plays
  the same. Found 16 October, reading loadGame() for the resurrection.
