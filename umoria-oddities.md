# Umoria's own oddities

The one list of things in Umoria 5.7.15 that look like slips in its own source, found while matching it. Anything
new goes in here as soon as it is found, and stays here whatever we decide about it.

Our rule so far: where the player could tell the difference, play as Moria plays, slip and all; part company only
where the original plainly does not do what it set out to do, and say so in the code ("NOT Moria's" or "not as
Moria 5.7.15 has it") at the place it happens. Each entry: what Moria does, what we do, and where. sdo decides
any that are open.

Started 16 October 2026, from notes that until then were spread through the code and not-yet.md.

## Parted company

- **A Brass Lantern found in the dungeon can never be filled, probably a slip in Umoria.** There are two: object
  364, the General Store's, sub category 0, and object 85, the dungeon's, sub category 1, alike in all else.
  inventoryRefillLamp() takes only sub category 0 as a lamp, so with the dungeon's wielded F says "But you are not
  using a lamp." Moria's own changelog shows how it came about: 5.0 renumbered the lamps' and torches' sub
  categories more than once in 1989 ("fixed lamp/torch subvals, again", 7 October; "change definition of subval
  192 so it can be used for torches ... fix all code fragments that test subvals", 1 November), and this test and
  the dungeon's lantern look to have been missed. Ours takes anything below a torch's sub category (192) as a
  lamp, so both lanterns fill (sdo, 22 October). Found 21 October by the lamp comparison. (stage-lib-commands-2.bas,
  filling a lamp)
  Compared 22 October, the regression's lamp case with the dungeon's lantern (sub category 1) in place of the
  store's: Umoria says "But you are not using a lamp." three times, ours fills it ("Your lamp is more than half
  full.", then "Your lamp overflows, spilling oil on the ground.  Your lamp is full."); every other difference
  follows from that, the two flasks used, the two turns taken and the food they eat, as expected. Not in the
  regression, whose cases must all come out the same.

- **A covered pit leaks a place in the level's list, possibly a flaw in Umoria.** trapCoveredPit() turns the
  pit into an open one with dungeonSetTrap(), which takes a new place with popt() and never frees the covered
  pit's, so that record stays in the list, on no square, until the level ends or the list is compacted. Ours
  turns the same record into the open pit, so nothing leaks (sdo, 21 October). The player cannot see it; what
  differs is the numbering: every thing made on that level afterwards is one lower in ours, the list fills
  one later, and a comparison after a covered pit shows the numbers different in "things on the map" (the
  open pit was 82 in ours, 86 in Umoria), so no such case is in the regression. Found 21 October by the trap
  comparison. (stage-lib-traps.bas, the covered pit)

- **Wizard `%` works only with the roguelike keys.** It is missing from the table of the original keys,
  although Moria's own help_wizard.txt lists it: originalCommands() in game_run.cpp turns every key it does not
  list into '~', "Anything illegal". Ours works with both, as the help says. Decided by sdo, 16 October 2026.
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
  chooses. Decided by sdo, 16 October 2026: mend the words. (src\messages.txt, stage-lib-commands.bas Ctrl-X)
- **The Wand of Trap/Door Destruction goes through rock.** spellDestroyDoorsTrapsInDirection() carries on
  while it is within range OR the way is open (`||`), where the Wand of Disarming stops at the first wall
  (`&&`), so it reaches doors and traps behind walls, and past its range along an open corridor. Ours stops at
  the first square that is not open, as the Wand of Disarming does (sdo, 22 October: it should not go through rock). (stage-lib-spells-5.bas, fub_s5_destroy_doors())
- **Backing out of selling makes the step into the store free.** inventoryGetInputForItemId() sets
  player_free_turn on ESCAPE, which is right for a command, but in a store it is still set when storeEnter()
  returns, in the middle of the step that went in: the monsters lose that turn and no new turn begins. Only an
  inventory command in the store sets it back ("No free moves here"). So a visit with an ESCAPE at "Which one?"
  is a turn shorter than one without. Found 17 October by comparing an Elf ranger selling. Ours takes the turn
  either way (sdo, 22 October: backing out should cost the turn).
  (stage-crawl.bas, coming out of a store; stage-store.bas, the inventory commands)

## Copied, because the player can see the difference

- **"Click!" at a chest with nothing left to undo.** The spells that unlock chests test the whole of a chest's
  flags (item.flags != 0), and the top half of the flags says what treasure is inside, so a chest that has
  been unlocked and disarmed still clicks every time until it is emptied. Found 16 October by
  tools\test\chests.ps1. (stage-lib-chests.bas, fub_ch_unlock())

## Makes no difference, nothing to copy

- **"This character is already on the scoreboard" can never be shown.** loadGame() tests
  `(!game.noscore) & 0x04`, which is always 0 (! gives 0 or 1), so the message never appears, the noscore bit
  for a duplicate is never set, and "Duplicate" never reaches the status line. Ours has none of it, which plays
  the same. Found 16 October, reading loadGame() for the resurrection.
- **Wizard Ctrl-E asks "(0-100) Save" but takes up to 200.** wizard.cpp tests `number < 201`, as the skills either
  side of it do. Ours does the same. Found 22 October, checking the list for Umoria's maintainer.
  (stage-lib-wizard-2.bas, Ctrl-E)
