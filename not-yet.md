# ZXMoria: what is not done yet

The register of everything we have thought of, seen in Umoria, crossed, or put off. Nothing leaves this list until it
is built and tested, or we decide together to drop it.

Two rules keep it honest:

- Every gap in the code is marked `NOT YET` at the place it belongs. To see them all: search `src\` for `NOT YET`.
  This file is the same list arranged by subject, plus the things that have no place in the code yet.
- When a step is finished, its lines come out of here in the same commit, and anything newly put off goes in.
- Anything in Umoria itself that looks like a slip goes in umoria-oddities.md as soon as it is found, with what
  we do about it, copy or part company, and why. sdo decides any that are open.

Last brought up to date: 2026-10-20, with "The next round", see the git log for the order.

## Monsters

Done so far: the monster record, which kinds turn up at which depth, putting them on a new dungeon level and in the
town, line of sight, showing the ones the player can see (light, invisibility, infravision), and the monsters' own
turn: waking (by the player's stealth), speed, making for the player or wandering, opening and breaking down doors,
walking through walls, eating lesser monsters, picking things up, and attacking the player with all 24 kinds of
attack (`monsterAttackPlayer()`, `executeAttackOnPlayer()`).

- Attacks that drain experience now take levels away with it (`spellLoseEXP()`), and a change in constitution
  changes the hit points, as intelligence and wisdom change spells and mana. Not tested.
- Seen working in play: ordinary hits, poison, fire (with smoke from the pack), frost, lightning, stealing an
  object and stealing gold (and the purse being protected), and the thief vanishing in a puff of smoke.
  Seen in a test on 13 October (a level 1 warrior kept alive by the wizard, and for each of Moria's attack types
  a creature that has it put beside them): losing strength, dexterity, intelligence and wisdom, each with its
  message and the number going down, confusion and fear from spores (and each wearing off), fire, acid, frost,
  lightning, the stinging red gas of corrosion, blindness from a gaze (and the attacker then being "It"),
  paralysis ("You are paralyzed." and later "You resist the effects!"), gold and an object stolen, poison, life
  draining away, the shrieker's wail ("You hear a sudden stirring in the distance!"), and "It got at your
  rations!". Loss of constitution was seen on a superhuman character ("Your health is damaged!").
  Experience drain taking levels away is compared with Umoria since 20 October (regression: a Grape Jelly drains
  a level 6 Gnome mage back to 4 experience, the hit points with the levels, the same in both).
  Not tested: disenchantment with
  something enchanted worn (the gaze came and, rightly, said nothing), the eaters of light and of charges with
  a lit torch or a charged wand carried.
- 13 October: the title under the class on the game screen was not rubbed out before a new one was put there,
  so a shorter title kept the end of the longer one ("Lord Keepert"). Put right, and seen through 14 levels.
- The player fights by walking into a monster: blows by strength and dexterity, misses, critical hits, slaying
  weapons, monsters dying, what they drop, experience and gaining levels (`playerAttackMonster()`,
  `monsterTakeHit()`, `monsterDeath()`, `displayCharacterExperience()`).
- Seen since, in the soak tests and the tests of 13 October: gaining experience and levels, gold and objects
  left by the dead and picked up, critical hits ("It was a good hit! (x2 damage)", excellent and superb ones),
  fighting with a weapon in hand, and hitting something unseen ("You hit it.").
  Slaying compared with Umoria (21 October, regression case 66): a sword the wizard's @ made, slaying animals and
  evil, kills a summoned Poltergeist (evil and undead, no animal) at one blow, and the monster memory learns it is
  evil, the same in both. And with every slay and brand on the sword: the Poltergeist slain as undead, ahead of
  evil, and a Giant House Fly as an animal, ahead of the fire brand, the memory learning each the same in both.
  Compared 22 October (regression): the fire brand alone on a Yellow Worm mass, and the frost brand alone on a
  Pitiful-Looking Beggar (the wizard's summons are never hurt by cold, most townspeople are), each the same, the
  memory learning 0020 and 0010. Slay Dragon compared 22 October (regression): a 9d9 sword of slay dragon on a
  Young Red Dragon asleep on level 40, its fire breath, and its death at the second hit, the same in every section.

- Monsters now cast spells, breathe and breed (`monsterCastSpell()`, `spellBreath()`, `monsterMultiplyCritter()`).
  Seen in a test: a dragon breathing gas and a bat breathing frost, and a spell being cast. The first version hung
  the game inside the breath (a wait for the next frame, with interrupts off); that is fixed, but a breath has
  not been watched running to its end since.
  Seen in a test on 13 October (a Floating Eye beside a level 1 mage, its kind given one spell at a time to cast
  every turn): blink and teleport (the eye moved, no message, as in Moria), light and serious wounds, hold
  person (paralysed, 150 turns went by), blindness (and the caster then "It"), confusion, fear, slow, each with
  "You resist the effects of the spell." on a saved throw, summon a monster and summon an undead (one more in
  the list each time), and all five breaths running to their end, the breather beside the player being caught
  in its own breath and hurt by it, which is Moria's doing too. Drain mana was seen earlier on a character with
  mana. Umoria has no bolt or ball spells for monsters; those bits give its "cast unknown spell." as they should.
  Breeding compared with Umoria (20 October, tools\test\regression.ps1): a Giant White Mouse on level 1, awake
  beside a resting Human warrior, breeds to 5 and 7 mice in 8 and 14 turns, the same squares, hit points and
  turns in both. Not tested: the player being pulled to a monster from a distance (the eye was already beside
  them). Tried 21 October (regression case 67): the shallowest caster, a Quasit asleep on level 19, 16 squares
  off; 700 turns of rest took its sleep from 204 to 67 and no further, a Killer Black Beetle broke the rest off;
  the same in both all the way, but no spell yet. Next time: a longer rest, or one of the deeper casters.
  Tried again 22 October: the beetle cannot be got out of the way, the wizard's Ctrl-F would take the Quasit too
  (it clears 20 squares round), and fighting it the level 12 priest misses nearly every blow and is bitten to death.
  Next time: a stronger character from the start (which changes the random numbers, so the walk is to be found
  again), or one of the deeper casters.
  Hunted 22 October with Umoria alone: four races on levels 28 to 50, a toughened warrior searching on arrival,
  every monster memory looked at for teleport-to seen: none cast it at the player (the Quasit walks up and claws,
  the Necromancer, Ogre Mage and Emperor Lich chose their other spells, or killed). Tested instead on a test build
  (as the run limit was) whose Necromancer casts teleport-to and nothing else, every turn: a Half-Orc warrior on
  level 42 searching was pulled from (63,93) to (63,84), beside it, with "The Necromancer casts a spell.", which is
  all Umoria says for it (spells 7 to 13 print that and no more, monster.cpp). Not compared with Umoria itself.
- The scent map: pages 42 to 46 were reserved for one, but Umoria 5.7 has no scent tracking. Pages 42 and 43 now
  hold the last messages and the high scores; 44 to 46 are spare.
- The two end game creatures, Evil Iggy and the Balrog (only the Balrog wins), are put down one at a time from
  level 50 (`monsterPlaceWinning()`), and killing the Balrog sets the winner's flag, which the death stage acts
  on. Seen in tools\test\balrog.ps1 (16 October): the Balrog put down by the level maker on level 50.
- A winner who plays on has `*Winner*` at the bottom left of the game screen (`printCharacterWinner()`). Seen
  in tools\test\balrog.ps1, after the kill.
- Seen in tests on 13 October (a Floating Eye whose kind was given each behaviour in turn, wizard sight switched
  off while watching): an invisible one beside a player carrying a torch is not seen and attacks as "It", and is
  seen and named once the player can see the invisible; a warm one three squares off in the dark is not seen,
  is seen with infravision of 5, and is lost again without it; one that breeds went from 1 to 6 in 24 turns;
  one walled in with granite on every side came through the rock to stand beside the player. A door bursting
  open was heard in the soak tests, and stunned monsters recovering.
  A monster opening a door compared with Umoria (20 October, tools\test\regression.ps1): a Novice Priest on
  level 5 opens the door a Half-Elf warrior shut behind him, the same turn and square in both.
  A thief compared with Umoria (20 October, tools\test\regression.ps1): a Scruffy-Looking Hobbit on level 4 hits a
  resting Half-Troll warrior, steals his gold, breaking the rest, vanishes in a puff of smoke and comes back to
  steal again, the same turns and gold in both. It found a fault, now mended: a rest a monster broke waited at
  -more- after the monster's messages, where Moria flushes at once (`playerRestOff()`), and the key that answered
  it was a turn lost. The same day the Ctrl-P history was mended too: a short message left the end of the longer
  one before it on the line, and that went into the history. And a third the same evening, found by saving each
  game's message history beside its state: what was typed at a prompt (a rest's turns, an offer in a store), the
  question "Which direction?" and identify's description all went into ZXMoria's history, where Moria keeps none of
  them; s_core_msg_forget() in the core now drops them.
  Not tested: one monster eating another, one picking something up. Both tried about ten times on 20 October and
  given up for now: the only eater below level 15 is the Blubbering Icky-Thing, which stayed asleep, and the hobbit
  meant to walk over dropped armour came at the player another way.

- The monster memory is being kept (Moria's `creature_recall`, the first 5,580 bytes of page 63, through
  `ful_core_recall()` in the core): everything Moria records, at every place it records it, 35 or so of them
  across twelve libraries, including two dice throws that had been missing (one time in four the player learns
  whether a creature they confused by touch never sleeps). As in Moria it is not wiped for a new character.
  Seen in a test: movement, kills, attacks seen, "slept on" counts and what was dropped, for three townspeople.
  Not tested: spells, deaths, and each of the other places. Defenses seen 21 October: the comparisons now have
  a "monster memory" section of their own (umoria-save.py and zxmoria-state.ps1), every creature Moria's save
  keeps; the slaying weapon's "evil" came out the same in both.
- Showing the memory is in: the recall paragraph (Moria's recall.cpp, in two pages, stage-lib-recall.bas and
  stage-lib-recall-2.bas), `l` look in a direction or all round with `r` to recall, and `/` identify a character
  (stage-lib-look.bas). Seen in a test: look in the town (shop entrances, the stairs, townspeople), recall from
  look, `/` for `p`, `>` and an unused character, and the paragraphs for three townspeople.
  Not tested: the cone of vision against walls and round corners in a dungeon, things seen in walls, and most
  of the paragraph's sentences (spells, breath, weaknesses, treasure, damage, the kill counts).
- Look does not put a cursor on the thing being described (we have no cursor), and does not describe kinds of rock
  (Moria only does with its `highlight_seams` option on).


- A monster caught inside rock (an earthquake, a wall built on it) now gets out to an open square beside it, or
  digs itself out and is hurt, or dies there with "a scream muffled by rock" (`monsterMoveOutOfWall()`). The door
  opening code moved to a second page, stage-lib-monster-moves-2.bas, to make room. A monster killed in the
  middle of the monsters' own turn is now only taken off the map until its turn comes (Moria's `hack_monptr`).
  Seen in a test that turned monsters' squares to granite by poking the map: four woken monsters each stepped out
  to an open square beside them, and three that were walled in on every side died with "You hear a scream muffled
  by rock!", the player gaining the experience. A sleeping monster stays where it is, as in Moria. Not seen: one
  surviving and digging itself out.

## Each turn

- Added on the night of 11 October: the slim chance, every sixteenth turn, of sensing that something carried or
  worn is enchanted (`playerDetectEnchantment()`), **which Moria throws dice for, so until now our turns had been
  using fewer random numbers than Umoria's**; random teleportation for those cursed with it; and the monsters'
  speeds changing with the player's when the pack's weight or a ring of speed changes it. None of the three tested.


Done: everything Moria's `playDungeon()` does as a turn begins, in its order: heroism, hunger (with fainting and
starving), hit points and mana coming back, blindness, confusion, fear, poison, being fast or slow, resting,
hallucination, paralysis, protection from evil, invulnerability, blessing, resistance to heat and cold, seeing the
invisible, infravision, the word of recall, the weight of the pack, and the words along the bottom of the screen.


- A new monster now wanders in (1 chance in 160 each turn) and the stores turn their stock over every 1,000 turns
  spent in the dungeon; neither has been seen to happen in a test.
- What confusion, fear and hallucination do to the player is in: staggering, "You are too afraid!", and seeing
  nonsense. Hallucination was watched, and "You are too afraid!" and "You are confused." came up in the soak tests.
- **Every disturbance is Moria's now** (15 October, night), `playerDisturb()` at each of its places and at the same
  moment, s_dst_disturb() in stage-disturb-include.bas: a light going out, growing faint or lit; heroism, fast,
  slow, invulnerability and blessing each starting and ending; getting hungry or weak; fainting; starving; going
  blind and seeing again; fear and poison ending; every turn of poison and of paralysis; random teleporting;
  sensing an enchantment; the end of confusion ends a rest only; hallucination ends a run only; and every test of
  being hit, whether it hits or not: a monster's blow, a trap's arrow or dart, the player's own blow, a bash, a
  throw. Saving the game is one too, as Moria's saveChar(), which also takes the pack's weight out of the speeds,
  and loading works it out again with its messages.
  Moria has two kinds and now so do we: a minor one ends a rest, a run and a count, a major one (a hit test,
  poison, paralysis, fainting, starving, a monster) also turns searching off. Until now every one was major, so a
  key pressed while resting turned searching off, which Moria's does not.
  Each takes effect at once: a rest that hunger ends is over before that turn's healing, which goes by it, and
  searching turned off in the middle of the monsters' turn changes the speed of the monsters still to move, the
  working monster's too (s_t2_change_speed()), which is what the NOT YET below "Against the real Umoria" waited for.
  Seen: the comparisons with Umoria that passed before all pass again, see below. Not tested in play: each kind of
  disturbance on its own.


- Free turns are in for looking at the pack or equipment, walking into a wall, a wrong key, nothing to open or
  close, and backing out of wear, take off or exchange (only actually changing something takes the turn).
- Seen in a test on 13 October, each counter set to 3 turns: protection from evil, resistance to heat and to
  cold, and super heroism wearing off with their messages; hallucination, seeing the invisible and timed
  infravision ending without one, as in Moria. And hunger: hungry below 2,000, weak below 1,000, fainting below
  300, and a hit point lost to starvation once the food had gone below nothing.
  Compared 22 October (regression): a Potion of Salt Water, fainting again and again, and starvation taking 6 hit
  points once the food was past nothing, the same as Umoria to turn 125. Dying of starvation compared 22 October
  (regression): a weaker mage starved to death, the last 22 messages the same, Umoria's save "killed by starvation"
  (a dead character's save holds no level, so the messages are all there is to compare). Mana coming back is compared with Umoria in the regression (a mage's Magic
  Missile, then 50 turns of rest: mana and its fraction the same, 16 October). The others were each forced and
  watched: fast, slow, hero, invulnerable, blessed, confused, afraid, paralysed, blind, poisoned, hungry, weak,
  healing, and the word of recall in the town.

## Walking and commands

- Not Moria's, ours: a key held down repeats walking, standing still (5), searching (s), bashing (B) and
  tunnelling (T), turn after turn, once it has been down for a third of a second, so a tap is still one step.
  For B and T it is the direction key that is held. Nothing else repeats, and anything that waits for a key of
  its own, -more- included, needs the key let go and pressed again, which is what stops a held key when
  something happens. Seen in a test: a tap, walking to a wall, standing, and tunnelling stopped by its message.
  Not tested: on a real keyboard, and how fast it feels in the dungeon.
Done: moving, stairs, store doors, light, `i e w t x`, `o c s`, picking up, attacking by walking into a monster,
`E` eat and `q` quaff with every effect food and potions have, `r` read with every scroll, `u` use a staff and `a`
aim a wand with every one of their effects, `f` throw or fire, `B` bash, `j` spike a door.

- Staffs and wands were tested by poking memory to make them. Seen working: light, detect evil, slow and sleep
  monsters, speed, magic missile, lightning, fire and acid balls, drain life, polymorph, clone, wall building,
  stone to mud, the line of light, wonder, earthquakes, teleportation, and gaining levels from the kills.
  Seen in a test on 13 October, with real ones made by the wizard's %, picked up and used by a level 1 mage on
  level 3: all 24 wands aimed and all 25 staffs used. Seen to act: the line of light, stone to mud, slow and
  sleep monster ("starts moving slower.", "falls asleep."), clone monster (one more monster); from staffs light,
  teleportation, summoning (one more monster each time), starlight, haste monsters, sleep monsters, speed,
  slowness, darkness, destruction and earthquakes. The detections, cure light wounds, curing, and the wands
  with nothing in their line said nothing, as in Moria. "You failed to use the wand properly." and the same for
  a staff were seen often, as they should be at level 1 with the harder ones, and "You can't carry a Wand of
  Cold Balls." when the pack was full.
  A wand striking compared with Umoria (21 October, regression): a wand the wizard's @ made with five effects at
  once (Moria runs every bit of the flags), lightning bolt, confuse, sleep, drain life and lightning ball, at a
  Yellow Jelly: struck, unaffected twice, killed, the ball enveloping another creature, the same messages.
  Mass polymorph compared with Umoria 21 October (regression, a staff of three effects made by @: "It shudders.",
  a Skeleton 2-Headed Troll, the same). Not tested: remove curse on something cursed, dispel evil on an evil
  creature in sight, a staff or wand running out of charges
  (compared with Umoria 21 October, regression: the same),
  and ones bought in a store.
- Throwing was tested with rations: hits, a kill, a critical hit, misses landing on the floor. Arrows from a long
  bow compared with Umoria 21 October (regression): made by the wizard's @, fired at a summoned hobbit, two hits
  (x3), a kill, the last arrow lost, the same in both. Then a sling with iron shots and a light crossbow with
  bolts, the same way, the same in both. Throwing at something unseen compared 22 October (regression): blind, rations
  thrown at a Black Mushroom patch, "You hear a cry as the Ration of Food finds a mark.", the same in every section.
- Bashing was tested on monsters (kills, stuns, being off balance) and on a spiked door, which gave way in the end.
  Bashing with a shield on, and while afraid, compared with Umoria 21 October (regression): stunned, off balance,
  slain, empty space, and "You are afraid!", the same in every section and message.

- Scrolls were tested by poking memory to make them, in the town: light, phase door, teleport, door creation,
  door and trap destruction, trap creation, detect traps, identify, blessing, summon monster, aggravate monsters,
  mass genocide, magic mapping (ran, nothing to show in the town), word of recall.
  Seen in a test on 13 October, with real scrolls (each made by the wizard's %, walked to, picked up and read
  on level 3 by a warrior wearing armour, a cloak and a dagger): the three enchant scrolls ("glows faintly!")
  and the two stronger ones ("glows brightly!"), with the armour class going up; curse weapon and curse armour
  ("glows black, fades.", the dagger left at (-10,-9) and refusing to come off: "Hmmm, it seems to be
  cursed."); remove curse ("You feel as if someone is watching over you.", and the dagger then came off);
  identify, with its question; summon monster (two more monsters); monster confusion ("Your hands begin to
  glow."); the rune of protection; the treasure, object, trap, door and invisible detections (nothing said
  when nothing is found, as in Moria); door creation; recharging ("You have nothing to recharge."); genocide,
  with its question; darkness; protection from evil, and it wearing off; create food; dispel undead; holy
  chant ("You feel righteous!") and holy prayer; trap and door destruction; teleport; teleport level (level 3
  to level 2); and destruction ("There is a searing blast of light!", and blind).
  N.B: the wizard's Ctrl-A removes curses, as Moria's wizardCureAll() does, which at first made the remove
  curse scroll look as if it said nothing.
  In a later run: summon undead (a White Wraith, then a Skeleton Hobgoblin and another), sleep monster ("The
  White Wraith is unaffected."), and trap creation, see the traps below.
  Not tested: scrolls bought in a store.
- Identify can now pick from what is worn as well as from the pack (/ in its question). Seen in a test.
- The rune of protection now stops monsters, unless they break it; not tested.

- Eating and drinking were tested with rations, and with potions made by poking memory (cure light wounds,
  strength, haste, heroism, sleep, and one with no effect).
  Seen in a test on 13 October, with real ones made by the wizard's %, picked up and used: 44 potions (the six
  stats gained, lost and restored, each with its message and the number changing; the cures; gain experience
  and "Welcome to level 2.", lose experience, restore life levels; sleep, blindness, confusion, poison, haste,
  slowness, salt water and the hunger after it, invulnerability with 100 on the armour class, heroism, super
  heroism, boldness, the resistances, detect invisible, slow and neutralize poison, restore mana, infra-vision,
  and the juices and water), and 18 things to eat (the mushrooms of poison, blindness, paranoia, confusion,
  hallucination, the cures, weakness, unhealth, restoration, the hairy mold and the slime mold), on to "You are
  full." and "You are bloated from overeating." with the slowness that brings.
  Learning an unknown potion by drinking it is in the regression since 16 October (level 10, a potion walked to,
  picked up and drunk; the known kinds section the same). The "tried" marking too, since 17 October: the unknown
  wand aimed on level 7 leaves its kind marked tried (01) in both.


- `R` rest (a number of turns, or `*` until fit), `S` search mode and `d` drop are in and were tested. Something that is
  being worn can be dropped too: / in the question goes over to the equipment, and it is taken off and put down
  (Moria's "Throw off"). Taking off something there is no room for in the pack offers to drop it. Seen in a
  test: armour thrown off, a cursed dagger refusing to come off, and, with all 22 places of the pack taken, a cloak
  taken off: "You can't carry it.  Drop it? [y/n]", "Was wearing a Cloak [1,+0].", "Dropped a Cloak [1,+0].", and
  the cloak on the floor underfoot.
- Traps are in: put down when a level is made, set off by stepping on them (all 18 kinds), disarmed with `D`.
  Seen working: pits, sleeping gas, the loose rock, acid, the constitution dart, blinding gas, teleport, and the trap
  door (which killed the test character).
  Seen in a test on 13 October (scrolls of trap creation read, and every square round the player stepped on):
  the arrow, the strength, slowness and constitution darts, acid, the blinding, sleeping, poison and corrosion
  gases, fire, falling rock (and the rubble it leaves), the loose rock with a potion under it, the teleport
  trap and the trap door (level 3 to level 4), each with Moria's message and, once sprung, its name when
  looked at ("You are on a dart trap.", "some corroded rock", "a blackened spot").
  And searching and disarming, by a rogue: 25 searches found the traps round them and named each ("You have
  found a covered pit.", "a strange rune", "a trap door", "some corroded rock"...), and D gave "You have
  disarmed the trap.", "You failed to disarm the trap." and "You set the trap off!" with the acid that followed.
  No experience comes from disarming a trap a scroll made, as in Moria.
  Traps going off compared with Umoria 21 October: a Scroll of Trap Creation made by the wizard's @ and read on
  level 7 puts eight round the player, and stepping on each, one comparison apiece, came out the same in every
  section and message: confusion gas, falling rock, fire, acid, the strength, constitution and slowing darts, and
  the loose rock with something under it; four of them are in the regression.
  Then, with searches first to make other traps: the summoning rune, the trap door (the new level 8 the same in
  both) and the teleport rune, the same in every section; the covered pit the same but for the numbers in the
  level's list, Umoria leaking a place there (umoria-oddities.md, ours does not, sdo's decision).
- A confused player now staggers; "You are confused." was seen many times in the soak tests.
- Stepping back off the rubble of a falling rock trap on to another trap now sets that one off too. Not tested.
- Running is in (`.` and a direction, Moria's player_run.cpp, stage-lib-run.bas): along walls, across open ground,
  round the corners of corridors, stopping at openings, things and monsters, and after 100 steps "to catch your
  breath"; a key press or anything that disturbs the player stops it. Seen in tests: runs across rooms and along
  walls, stopping at a gap in the wall, at a wall ahead, beside a monster, and when a monster in view moved.
  A later test, with a torch lit and the monsters frozen, saw a run west turn a corner and follow the corridor
  north for 13 squares, and corners being cut. Compared with Umoria 21 October (regression): running in four
  directions, and running while confused and while blind, the same. Not tested: the 100 step limit. Read beside
  Moria's code instead, 22 October: both take 101 steps (Moria the first in playerFindInitialize() and 100 more,
  ours from the walking stage's counter 2 to 102), but the stop to catch one's breath was a free turn here and
  takes a turn in Moria (playerRunAndFind() leaves player_free_turn false); put right. No comparison can reach it:
  a simulator of Moria's running (player_run.cpp in Python) found no run of 101 steps in about 260 levels, the
  longest that can be walked to is 82, and fewer rooms make it worse, the corridors only join the rooms. Tested
  22 October instead on a test build with the limit at 12 (sdo's idea of a test build, good enough for him): a
  run west along a corridor of 64 squares took 11 steps and 12 turns, "You stop running to catch your breath.",
  as the real limit's 101 steps, and the stop a turn of its own.
  Moria's three running options are fixed at their usual settings.
- Moria does not draw the player while they run (its `run_print_self` option is off by default); we always do.
- Shift and a direction to run: on the Next's keyboard Caps Shift with 5 to 8 are the arrow keys, so only `.` runs.
- Speed: a turn on a dungeon level took about a third of a second in the background emulator, because every
  monster was copied out of the level's list and back each turn. Distant, unseen monsters are now dealt with in
  place, and a turn on level 1 measured about 66 ms (30 in the town). The same test walk gave exactly the same
  game before and after, message for message, so nothing but the speed changed. Still worth timing on real
  hardware, and a busy screenful of monsters will still be slower.
- Repeat counts are in (Moria's `command_count`): `#` (Symbol Shift and 3), the number, then the command, with a
  space first if the command is a digit; nothing typed is 99. It repeats a step, `B D R T j o s -`, any message
  ends it (the core sees to that as the message is printed), as does a key or anything that disturbs the player,
  and the messages Moria lets pass ("You tunnel into the granite wall." and eight more) do not. A repeated
  command keeps the direction it was first given. "Repeat 9" shows on the bottom row.
  Seen in a test: five searches, three steps, a count of 7 before `R`, the default of 99, an invalid command, and
  a count before `o` ended by its message. Not tested: tunnelling or disarming with a count.
  A count before a run limits its steps (Moria's `find_count`). Not in: a count for Ctrl-P, counts above 255.
- Chests are in (stage-lib-chests.bas): opening and picking the lock, the five traps, what is inside falling out
  as if a creature had died there, disarming, bashing, being looked over when the player searches, and the spells
  that show their traps or unlock them. A monster standing on a door or chest is now "in your way!".
  Seen in a test, with chests planted beside the player: "I don't see a trap.", failing and then picking a lock,
  the needle, the chest becoming "(Empty)" and its treasure appearing, a lock broken by bashing, and, in an
  earlier run, every trap going off at once (the explosion killed the character).
  16 October, all of what was not tested is now, tools\test\chests.ps1, 15 checks, all passing, a superhuman
  mage with chests written in beside them: the mage's Trap/Door Destruction and Find Hidden Traps/Doors, the
  wands of Trap/Door Destruction and of Disarming, D (an unseen trap, then a known one: still locked, experience
  up by the chest's level), searching ("You have discovered a trap on the chest!", "The chest is trapped!"),
  bashing to a ruined chest (object 418) with the lock breaking on the way, opening one with summoning runes,
  and chests made with levels 11 to 37, their traps and names as Moria's magicalChests() gives them. Two things
  that look odd are Moria's: a spell says "Click!" at a chest with no trap or lock left, as long as treasure is
  in it (Moria tests the whole of the flags, and the treasure is in their top half); and summoning runes may
  bring fewer than three monsters, each needs room beside the chest. The NOT YET in stage-lib-spells-5.bas
  about chests was out of date, the spells did it already.
- A trap found by searching is now named: "You have found a trap door." Seen in the test of 13 October above.
- Tunnelling (`T`) is in, through rubble, rock and secret doors, and rubble is put down when a level is made. Only
  the refusals were seen ("Tunnel through what?  Empty air?!?") at first; the soak tests have since dug through
  granite, magma and quartz ("You tunnel into the granite wall.", "You have finished the tunnel.").
- Taking off something there is no room in the pack for (Moria offers to drop it).
- More of Moria's command list is in (stage-lib-info.bas, stage-lib-text.bas, and the commands library): `C` the
  character sheet with a change of name, `L` locate, `M` the reduced map, `?` (or `h`) help, `v` versions and
  credits, `F` fill the lamp, `-` move without picking up, `5` stay in one place, Ctrl-R (EXTEND and R) redraw,
  space and ESC do nothing. **Throwing is now on `f`, as in Moria; it had been put on `v` by mistake.**
  Seen in a test: all of them, `F` only as far as "You have no oil.", and Ctrl-R in a later test.
  Filling a lamp compared with Umoria 21 October (regression): every message, from "not using a lamp" to
  overflowing. Not tested: `5` picking up what is underfoot, `L` across a whole level.
- `{` (Symbol Shift and F) inscribes something in the pack, and "Replace ... New inscription:" changes it. Seen in
  a test, for something in the pack and for something worn.
- Moria's command list is all in. `=` the options is Moria's setGameOptions(), eleven of them, kept with the
  character and saved with the game, each obeyed where Moria obeys it: the four about running (cut corners,
  examine corners, print self, stop when the map sector changes) and running through open doors, prompt to pick
  up, show weights in inventory, highlight and notice mineral seams (drawn as %, looked at by `l`, named by `/`),
  and display rest/repeat counts.
  Seen in tests: the screen, setting and clearing, the settings a new character starts with, weights in `i` and
  `e`, "Pick up ...?", counts shown and hidden, the player drawn again when a run ends.
  Seen in a test on 13 October: a mineral seam on level 12 drawn as # with the option off and as % with it on.
  Not tested: stopping at a map sector, running through a door, the corner options, and print self seen during
  a run.
  N.B: as in Moria, the player is not drawn while they run unless "print self" is on, see below for how it starts.
- The rogue like commands are in: turned on and off in `=`, and saved with the game. hjklyubn step, with SHIFT
  they run, with CTRL they tunnel, . stays, a digit begins a count, and f W # z Z P t T S x X are Moria's rogue
  like keys for bash, locate, search mode, aim, use, browse, throw, take off, spike, look and exchange. Wherever
  a direction is asked for its letter will do. `?` shows Moria's rogue like help. The table is in the second
  commands library (fub_cm_rogue), it turns each rogue like key into the original one before anything else sees it.
  Seen in tests: every step, stay, a count, runs both ways, a tunnel, bash and look taking a direction by its
  letter, a letter that is not a command, the help, and back to the original commands.
  Seen in a test on 13 October: the wizard's \ (Symbol Shift and D, its help), * (the level lit) and & (a monster
  summoned), and a count before a run: 2, 3 and 4 steps as asked. A count before Ctrl-H cannot be given, Ctrl-H
  is the delete key while a count is being typed, in Moria too.
  **A fault put right:** after a run that was given a count, "Repeat 3" stayed on the bottom row for good, with
  either set of keys. It is taken off as the run begins.
  Not tested: a count before a tunnel in another direction, a held key.
- A new character starts with "print self during run" on, which is not how Moria starts: UB_CR_PRINT_SELF_AT_START
  at the top of s_stage_crawl() in stage-crawl.bas, there so that changing it compiles only that stage.
- A new character starts with Moria's original commands, as Moria does: UB_CR_ROGUELIKE_AT_START, beside the one
  above, is false. It was true for three hours on 13 October 2026 (the Next's digits are one row, not a keypad)
  and was put back the same evening: sdo plays on a keyboard with a number pad, bought for the purpose.
  Seen in tests that evening, a new warrior in the town with = never touched. With it true: the options word
  $0627, h l j k y u b n each step the right way and take a turn, . stays, a digit begins a count ("Repeat
  count: 4"), = shows "Rogue like commands : yes" and ? the rogue like help. With it false: $0607, and
  1 2 3 4 6 7 8 9 each step the right way.
- **NOT YET: the PC's keyboard in the emulator.** ZEsarUX turns PC keys into the Spectrum's forty, and loses
  some on the way. Found on 13 October by sending Windows key messages to a hidden emulator's window:
  the number pad's digits do not arrive at all; Ctrl and Alt are both symbol shift, so the PC's Ctrl-G is
  symbol shift and G, not our Ctrl-G (which is caps shift and symbol shift, or Tab, held with G); and shift
  with a punctuation key is caps shift and symbol shift and the key, so the PC's ? (shift and /) arrives as our
  Ctrl-V. Nothing in the game can tell these apart, it has to be put right between the keyboard and the
  emulator.
  Done that way on 13 October: tools\zesarux-keys.ahk, an AutoHotkey script (free, `winget install
  AutoHotkey.AutoHotkey`) that acts only while a ZEsarUX window has the keyboard: the number pad's digits become
  the top row's, Ctrl becomes Tab (ZEsarUX's extend, our Ctrl), and every punctuation key of a UK keyboard,
  shifted or not, is sent as symbol shift and the Spectrum key that has the character. build.ps1 starts it with
  the emulator. Seen by sdo on 13 October, playing: the number pad steps, the diagonals too, Ctrl-W, ? and =
  all do what they say. "zxmoria is now actually playable inside zesarux."
  Not tested: a held pad key, and the punctuation keys one by one. Not looked at: a PS/2 keyboard on a real
  Next.
- A fault put right: since a held key was made to repeat, a count given with # had been lost, and (once the
  game saved itself on a time out) the game then saved and left. Counts were seen working again in a test.
- The beep is in: a key that is no command at all gets a short beep from the speaker as well as "Type '?' for
  help.", if the option is on, s_cr_beep() in stage-crawl.bas, where UB_CR_BEEP_AT_START says how a new
  character starts out (on, as Moria does). N.B: Moria beeps for a bad choice in its menus, not here; ours is
  for an unknown command, as asked. Seen in a test only as far as the game carrying on, it cannot be heard there.
  Not tested: by ear, and that the pitch and length are right on a real machine at 28MHz.
- Ctrl-P is in: the last message again, marked `>`, and pressed twice running the last 22, oldest at the top.
  The core keeps them as they are printed on the top row (page 42, which was set aside for a "scent map" that
  Umoria does not have). Seen in a test. Two differences from Moria: "Which direction?" and the like, which we
  print as messages, are remembered too, and there is no count to say how many to show.
- Writing the character sheet to a file (`C` then `f`).
- The help text is Moria's, changed where our keys differ; it and the credits are held in the text library's page.
- "Prompt to pick up" and Moria's other options.
- Hallucination is in the map display: one square in twelve is drawn as nonsense, and Moria's dice are thrown for
  it. Seen in a test with the counter poked (the reduced map was a fine mess).
- The message line is Moria's printMessage() in full now: two messages short enough to share the row are put
  side by side and remembered as one, otherwise -more- follows the one showing, and only SPACE, ESCAPE or ENTER
  answers it. A message is cut at 79 characters, as Moria cuts it. Seen in a test: a fight.
- Moria keeps its inventory lists on screen and lets one command lead into the next; ours asks, does, and puts the
  screen back.
- Wherever something carried is picked: a digit picks the thing inscribed with just that digit, and a capital
  letter picks after "Try ...?", "Wear/Wield ...?", "Take off ...?" or "Drop ...?", as in Moria. Seen in tests.

## Making a level

- Rooms with inner rooms (plain, treasure vault, pillars, maze, four small rooms) and cross shaped rooms are in, with
  their own monsters, traps and treasure (stage-lib-rooms.bas), so a level should now use its random numbers exactly
  as Umoria does. Seen in a test: two levels made at 12,550 feet and the whole map read back out of memory, with
  cross shaped rooms, inner rooms, a vault, four small rooms, secret doors, and sleeping monsters, traps and objects
  inside them. Not tested: each of the variations one by one, and walking through one.
- Making room when a level's list of 175 items or 125 monsters is full is in (`compactObjects()`,
  `compactMonsters()`, stage-lib-compact.bas), with Moria's check each turn that the monster list is not nearly
  full. Seen in a test with the lists filled artificially: "Compacting monsters..." took the list from 125 to 86,
  "Compacting objects..." made room for a drop. Not tested: in the middle of the monsters' own turn (breeding).
- Umoria 5.7 has no monster pits or nests, so there are none to add (noted so nobody goes looking).
- Levels, characters and stores have been compared with real Umoria for the same seed, see "Against the real Umoria".

## The character

- Spells and prayers are in: how many may be known and the mana for them (`playerCalculateAllowedSpellsCount()`,
  `playerGainMana()`), studying (`G`, `playerGainSpells()`), browsing a book (`b`), casting (`m`) and praying (`p`),
  with the chance of failing, fainting when out of mana, and experience the first time each one works. Spells are
  forgotten when levels are lost and remembered when they come back. Three pages: stage-lib-magic.bas,
  stage-lib-books.bas, stage-lib-cast.bas.
  Seen in tests, as a mage and as a priest: all of the above, and every spell and prayer cast at least once except
  the mage's Turn Stone to Mud, Recharge Item II and Genocide and the priest's Glyph of Warding and Holy Word (the
  last four failed their roll each time), though all five lead to routines that scrolls, wands and staffs have
  already exercised, bar Holy Word's turn undead.
  Seen in a test on 13 October: a superhuman rogue, ranger, paladin, mage and priest each cast every spell or
  prayer of every book once, on level 10 with monsters summoned round them. The rogue is refused the spells a
  rogue cannot have ("You don't know that spell.") and has none in the fourth book; bolts and balls struck
  ("The Fire Bolt strikes the Black Mushroom patch.", "The Frost Ball envelops several creatures!"), stinking
  cloud and the orb of draining killed, confusion, sleep, slow and polymorph took a direction, stone to mud,
  both recharges, identify, haste, teleport other, sanctuary, earthquake, protection from evil ("The Black
  Harpy is repelled."), dispel undead ("The Zombie Kobold shudders.") and dispel evil ("dissolves!") all
  worked. The failure rate looked high among the monsters, so it was measured: the chance the game used was 5%
  on every one of 60 casts, and over three measured runs 15 failed in 310 casts (6 in 160 in the quiet, 8 in 90
  and 1 in 60 among monsters), a little under 5 in 100 where 4 in 100 is expected: chance, not a fault.
  Turn undead on an actual undead creature compared 22 October (regression): a priest made level 40 by the wizard's
  + learns every prayer (Umoria's priests learn at random from all their level allows, the books do not come
  into it), walks up to a Skeleton Orc and prays it twice, "The Skeleton Orc runs frantically!", the same in
  every section. Not tested: a spell
  list longer than the screen, the "You can learn
  some new spells now." message at the moment a character is made, and the capital-letter "are you sure" when
  picking a spell.
- Tested on 12 October 2026 with a superhuman priest: Glyph of Warding ("You are on a strange rune.") and Holy
  Word (evil monsters dissolved, "Your skin turns into steel!") both work. They had failed their roll every
  time it was prayed in the earlier tests. The mage's three were tried the same day: Turn Stone to Mud ("The
  wall turns into mud."), Recharge Item II ("There is a bright flash of light.", the wand had 50 charges, so it
  was lost, as Moria has it) and Genocide ("Which type of creature do you wish exterminated?") all work. Seen too:
  a priest learning every prayer with G, and a mage every spell, one at a time.

- A weapon too heavy for the player's strength is in ("You have trouble wielding such a heavy weapon."). Seen in a
- NOT Moria's, ours: the auto roller. A capital R at "Hit space to re-roll" asks for the least that will do for
  each of the six stats (typed as 15 or 18/50, RETURN for any) and then rolls, every roll shown and counted,
  until a character has them all or a key is pressed, fub_pl_ask_least() in stage-player.bas. Each roll is
  Moria's own, nothing can be had that the space bar would not bring in time. Asking for more than the race
  can have rolls until a key stops it: there is no check.
  While it rolls only the stats are rolled, and they are shown one roll in eight, about 38 rolls a second in
  the emulator; the background, age, height and weight are made up for the character it stops at.
  Seen in tests on 13 October: a male Halfling, strength 15 and intelligence 18/01 asked for, came up after
  924 rolls with STR 15 and INT 18/17; ESC at the questions goes back without accepting the character; and
  with strength 17 asked for, which a Halfling cannot have, a key stopped it at 769 rolls. Ctrl-V and ? both
  showed the help in the town.
- `?` while choosing a race, sex or class now shows Moria's words of welcome. Seen in a test. The text is Moria's
  as it stands, so it speaks of control-C and of `%` at the class question, neither of which we have.

## Stores

- Ctrl-R redraws the store. Seen in a test on 13 October, with the walk in, the list and the first haggling prompt.
  (The NOT YET about it at the top of stage-store.bas was left behind; taken out 16 October.)
- 16 October, two things set beside Moria's storeEnter(): the inventory commands may be capitals too, `E` `I` `T`
  `W` `X`, as Moria's inventoryExecuteCommand() makes them small; and any other key beeps (terminalBellSound(),
  with the "beep for invalid character" option, as in the dungeon). Seen in a test in the General Store: `E`
  ("You are not using any equipment."), `I` (the pack), Ctrl-R putting back a screen spoilt on purpose, and `z`
  changing nothing on the screen (the beep was not heard, the test has no ears). Not as Moria has it: Moria's ^R
  is not the store's but its getKeyInput()'s, which redraws the screen at any key at all and never returns ^R;
  ours redraws in the dungeon and in a store only, at any other question Ctrl-R is just a key.
- The store's turn passing while the player is away (stock turning over happens each time the town is made, as in
  Moria).
- **A fault put right**, 14 October, found by sdo playing: in a store the message left by one command was not
  cleared when the next command was given, so the next message was put after it on the same row as if the two
  were one, "But you are wielding no weapons.   You are not using any equipment." The store clears it now as each
  command is given, as the walking stage does and as Moria's storeEnter() does ("clear the msg flag just like we
  do in dungeon.c"). Seen in a test before and after: x, then t, in the General Store.

## The game as a whole

- Death is in as Moria has it: the tombstone, drawn from Moria's own death_tomb.txt, and for a winner the crown
  first (death_royal.txt) and the retirement of a *King* or *Queen*, "Magnificent", with the gold and experience
  Moria awards. `Q` (or Ctrl-K) asks "Do you really want to quit?" and the character then dies of "Quitting";
  after that tombstone the game goes back to NextZXOS, after any other it begins again.
  Seen in tests: the quit question, both answers, the tombstone, and, with the winner's flag poked, the crown
  and the winner's tombstone. Winning by killing the Balrog was seen in a test on 12 October
  2026: a superhuman character on level 50, the Balrog brought beside them by changing the memory, ten rounds of
  blows, "*** CONGRATULATIONS *** You have won the game.", "You cannot save this game, but you may retire when
  ready.", the treasure it dropped, and then Q: the crown, and the tombstone of "bob the Magnificent", "*King*".
  16 October, made a test that can be run again, tools\test\balrog.ps1, 12 checks, all passing: the Balrog the
  level maker put down on level 50, moved beside a superhuman warrior with 1 hit point left, the game made
  scorable again; the two messages, the flag, "*Winner*"; Ctrl-X refused with Moria's two messages; Ctrl-K: the
  crown, the tombstone (Magnificent, *King*, level 39 to 79, gold up 250,000, Ripe Old Age); the high scores;
  and Ctrl-W on the opening screen refusing the retired character. Put right on the way: Ctrl-X's second message
  is now the one for the keys in use, Moria's "Use <Control>-K when you are ready to quit." for the original
  keys (ours had always said 'Q'), and the roguelike one with Moria's "to when" mended (see umoria-oddities.md); and the
  King is made before the save at death, as Moria's endGame() has it, so the save holds the King. The NOT YET
  "the winner's crown when the Balrog dies" in stage-lib-player-attack.bas was out of date: Moria shows the crown
  on retiring, not on the kill, and so did we.
- The high scores are in (stage-lib-scores.bas): worked out as Moria does (experience, depth, gold, and the worth
  of everything carried and worn), put in their place in a table of the best 100 kept in the file scores.dat,
  and shown after the tombstone and by `V`. Seen in a test on the emulated SD card: two characters, two boots,
  both in the table in the right order.
- 16 October, early: **a saved character is put in the table as "(saved)"**, as Moria's commandSaveAndExit() and
  endGame() do, and the table is shown after the save; when it is saved again, or dies, its new score takes the
  place of the "(saved)" one (the same birth, sex, race and class), and a "(saved)" score that is better than the
  new one stays and the new one is not put in, as in Moria. The save also holds the character's score as the
  least it may ever score (Moria's max_score, which ours never set), and "(saved)" for what it died of, which a
  load makes "(alive and well)" again. The check that a saved game's character has died (ours) passes over
  "(saved)" scores. Seen in a test (tools\test\lifecycle.ps1, zf): saved, loaded twice, saved again, one line
  "1 39 Morwen F Half-Orc Warrior 1 (saved)" in the table after both saves, and the game loaded both times.
  Seen too: a character saved ("1 40 bob M Human Warrior 1 (saved)"), loaded and quit: its line became
  "1 40 bob M Human Warrior 1 Quitting", and no "(saved)" line was left.
  14 October: the file was zxmoria.sc until now (it is still read if there is no scores.dat), and, NOT Moria's,
  ours, the whole table is also written out as text each time a score goes in, scores.txt, to read on a PC.
  Seen in a test: both files, and the text read back.
- "Character record?" after the tombstone shows the dead character's sheet, and then what they were using and
  carrying, with their weights, everything identified first, as in Moria; or writes all of it to a file on the
  SD card. One difference: Moria asks again if the file will not write, we say so and go on.
  14 October, NOT as Moria has it, which asks for the file's name: the file is always player-<name>.txt, after
  the character (anything in the name that is not a letter or a digit becomes an underline, see
  stage-playerfile-include.bas), so the question after the tombstone is a key, f, and <f>ile on the character
  sheet asks nothing. Seen in a test: both, "Written to player-bob.txt.", and the file read back.
- The Next's clock is read (14 October 2026), see fub_sc_date() in stage-lib-scores.bas: the day is on the
  tombstone, as Moria has it, "Wed Oct 14", and a Next without a clock has none there. Every character has a
  birth, Moria's date_of_birth: the date and time it was made, or with no clock a number from the key timings
  with its top bit set. The high scores carry each character's birth and when it died (the table's scores are 88
  bytes now, 90 of them, an older table is made over as it is read), and a saved game whose character is already
  in the high scores is refused, "That character has died", which is ours and not Moria's: it stops a save copied
  off the card before a death being put back and played on. Not caught: a game in which wizard mode was used,
  which never goes in the table, and saves from before this, which have no birth.
  The clock is read straight from its chip, a DS1307 on the i2c lines, not through the system's M_GETDATE, which
  hangs ZEsarUX both when it answers the calls itself and under NextZXOS; ZEsarUX has the chip and gives it the
  PC's time. Seen in tests in both: born 2026-10-14 04:22, the tombstone's "Wed Oct 14", the score's birth and
  death, a kept-back save refused (tools\test\date.ps1, dead-save.ps1). Not seen: a real Next's clock, and a
  Next without one (it should read all ones, which is no time, and so no clock).
- Save and restore are in (stage-lib-save.bas). Ctrl-X saves the game and goes back to NextZXOS; the next time
  the game is started it carries on from there, in the same turn; and when that character dies the save is
  marked so that it cannot be loaded again. The game is saved as the 34 pages that hold it, each to a file of
  its own in the current folder of the SD card, zxmoria.32 to zxmoria.88, 8KB each, which takes about two seconds.
  Seen in tests that booted NextZXOS from a scratch copy of the build's SD card image: a save, the 34 files on
  the card, a restore after a fresh boot with the same town, position, turn, gold and pack, and after that
  character quit, a new game at the next start; and a save on dungeon level 1 with a monster in view, which
  came back with the same position, turn, hit points, room, and counts of monsters and things.
  Not tested: a save while resting, running or mid-count; a card that is full or missing while playing.
- When a character dies the monster memory is saved (and the save, if there was one, marked dead), and a new
  character begins with it, as in Moria. Seen in a test: a character killed by a townsperson, a reboot, and the
  next character starting with that death already in the memory.
- The saved game is one file now, zxmoria.sav, 34 pages of 8KB one after another (278,528 bytes), written and
  read a page at a time by seeking, a new thing in the core's file routine (gub_core_file_slot). The 34 files of
  before, zxmoria.32 and so on, are no longer read. When no key has been pressed for an hour in the walking stage
  the game is saved before going back to NextZXOS; Moria has no saving by the clock, the nearest it has is the
  save it makes when its input is cut off.
  Seen in a test, on a scratch copy of the card: Ctrl-X, the one file on the card, and the game picked up again.
  Seen in a test on 13 October: the save after an hour (the hour was made ten seconds by changing the number
  in the machine's memory): "Saving game...", a zxmoria.sav of 278,528 bytes, and the game picked up again at
  the same turn and place. And a character quitting on a card with no save on it: a zxmoria.sav of two pages
  and a zxmoria.sc are written, the score is shown, and the next start makes a new character.
- 14 October, decided with sdo: **the one saved game, zxmoria.sav, as Moria has it**, and the VAX/VMS Pascal
  Moria before it. A saved game for each character (zxmoria-<name>.sav), a list of them to choose from at the
  start (saves.dat) and the monster memory in a file of its own (memory.dat) were built in the small hours and
  taken out again the same evening. Dropped, not put off. As in Moria, the game carries on with the saved game
  when it starts, and a death cuts the file to two pages, the core's data marked dead and the monster memory,
  so that the next start makes a new character who knows what the last one learnt. A save kept from before its
  character died and put back on the card is still refused, by the birth the high scores know it by.
  16 October: a death now cuts it to ten pages, 81,920 bytes, up to the stores' stock, so that a wizard can bring
  the character back (see the wizard notes below).
- 16 October, **a save is checked as Moria's loadGame() checks one**, after our marks and version: no more than
  22 kinds of thing in the pack, nor 24 in any store, the level and the player inside the map, and no more items
  or monsters than a level holds; and a page that will not read is the same. Any of these is Moria's "Error
  during reading of file." and "Please try again without that save file.", and the game goes back to NextZXOS
  and leaves the file as it is. Until then a save that would not read started a new character, whose own save
  would have written over it. Seen in tests, tools\test\save-check.ps1, 10 checks: a save with 99 kinds of thing
  in the pack, and one cut short after three pages, each refused with both messages and left as it was, and the
  save as made loading. Run again after it, all passing: resurrect.ps1 steps 1 to 3, dead-save.ps1, and
  lifecycle.ps1 on zf.
  Decided by sdo the same day: "the save version has to match or it's a no go no show", we do not handle or
  convert old saves. So a zxmoria.sav that is not ours, or will not read, gets the same two messages and the game
  ends; one of ours with another version number gets them too, with Moria's third line, "Sorry. This save file
  is from a different version of ZXMoria." (Moria's says umoria); only no file at all (esxDOS error 5,
  esx_enoent) begins a new character. N.B: so UB_SAVE_VERSION must go up whenever what a save holds changes.
  Seen in tests: save-check.ps1, now 23 checks (another version, not ours, and no file added), all passing on
  zf; lifecycle.ps1 on za, a fresh card under NextZXOS still beginning a new character.
- **Faults put right**, 14 October, found by sdo saving a game: with the nex file given straight to the
  emulator a saved game was all noughts but for its last page, and could not be brought back. ZEsarUX's own
  file handling empties a file every time it is opened for writing, however that is asked for, and the save
  opened its file afresh for each of its 34 pages. A file of many pages is now kept open from its first page to
  its last, see fub_core_file_transfer(), which NextZXOS is as happy with. Seen in tests, both ways of starting:
  a save, its marks and pages looked at in the file, and the game picked up again at the same turn.
  And the end of the game: the reset that hands the machine back to NextZXOS does not do that in ZEsarUX, booted
  from a card or not, it starts the processor again with our pages still at the bottom of memory, and hung. A
  page of ours with a jump in it is put there first, see s_core_return_to_zxos(): a real Next's reset replaces
  it with the ROM, and the emulator lands in "ZXMoria has ended. This emulator cannot go back to NextZXOS by
  itself: close it, or reset it". Seen in tests, both ways of starting. **Not tested: on a real Next**, where
  the reset should simply be the reset it always was.
  N.B: an emulator that is killed, and not closed, loses what it had not yet written to its card image, a test
  that did that found the saved games empty.
- The game opens on Moria's own first screen, 14 October: the screen of start up tests that came before it (the
  paged data slots, a file saved and loaded, the random numbers, the records, the databases) is no longer run,
  and nothing writes poc4uattest.bin any more. The stage itself, stage-init.bas, was taken out the same day,
  which freed page 96; git has it. Its scratch pages, 89 to 94, stay: saving and text files use them.
- Still to do about saving: the stages that had been set aside for all this (page numbers 103 to 105) are not
  used.

- The live monitor is in: the last five rows of the screen (27 to 31), turned on and off with ] (symbol
  shift and U, until 16 October 2026 GRAPH) in any stage, off to begin with. It is drawn each time the game waits for a key, so it does not
  move during a run, a rest or a repeated command. It is a table, a column for each of slots 0 to 3. Slots 4 to 7 never change, so they are not shown. The
  count (c:), hits (h:) and misses (m:) are shown up to 999999 and then start again from 0, the counts kept are ULongs. The
  opening screens use rows 27 to 31 themselves, and turning the monitor off there blanks those rows.
- Wizard mode is in (stage-lib-wizard.bas, stage-lib-wizard-2.bas, pages 158 and 159): Ctrl-W turns it on, after
  Moria's warning and "Are you sure?", and off; a game it has been used in shows "Is wizard" or "Was wizard" and
  is never put in the scores. While it is on: Ctrl-A cure all, Ctrl-D jump to a level, Ctrl-E edit the character,
  Ctrl-F vanquish monsters, Ctrl-G random items, Ctrl-H its help, Ctrl-I identify, Ctrl-L wizard light, Ctrl-T
  teleport, Ctrl-U summon, : map, + or ENTER experience, % an object by its number, @ an object made up field by
  field. The wizard sees every monster in the window, and the monster memory shows everything. A count (#) before
  Ctrl-D, Ctrl-G or + is the level, how many, or the experience. Any key that is nothing else now gets Moria's
  "Type '?' for help."
  Seen in tests: every command above. Not tested: the scores really being left alone, a saved wizard game coming
  back as "Was wizard" with its message, Ctrl-L putting the light out again, how long Ctrl-L takes on a real machine.
  Not as Moria has it, each explained at the top of stage-lib-wizard.bas and stage-lib-wizard-2.bas: % works with
  the original keys (in Moria it only works with the roguelike keys); % identifies only the kind of thing; a
  message showing is waited for before a question; Ctrl-E's "Searching" sets the skill to the answer.
- NOT Moria's, ours, for testing: $ in wizard mode makes the character superhuman (stage-lib-wizard-3.bas, page
  160): every stat 18/100, level 39 and half way to 40, 30000 hit points and mana, 500000 gold, a Holy Avenger two-handed sword 9d9
  (+50,+50) that slays everything and resists everything, plate armour, shield, helm, gauntlets, boots and cloak
  with a great deal of armour, a full lantern, and a pack of books, potions (10 of invulnerability), scrolls,
  food, oil, wands, staffs and a ring of speed, as far as there is room for them, and every spell or prayer the
  character's level allows is learnt. What was worn in those places
  is lost. Seen in a test: the character, the equipment and the pack. Not tested: fighting with it.
- Ctrl-B in wizard mode is in (a sample of random objects written to a file), and so is <f>ile character
  description on the character sheet, both write plain text files to the SD card through
  stage-textfile-include.bas. Seen in tests: both files read back off a scratch card. A wizard's game saved and
  brought back says "This save file cannot be used to get on the score board." and shows "Was wizard", and its
  death left no score file: seen in a test.
- 16 October, **Moria's -w is in: Ctrl-W on the opening screen** (any of its screens) starts the game as a
  wizard, a nex file having no command line. Asked by sdo. As Moria's:
  - a dead character in the save: "Resurrect a dead character? [y/n]". Yes brings back the character, the pack,
    what they knew and the stores, to the town, made afresh (Moria's townGeneration() also turns the stores'
    stock over, so it changes on the way back). Hit points below 0 become 0, food below 0 becomes 0, poison
    above 1 becomes 1. The game is never scored again: "Resurrected" on the status line, and "This save file
    cannot be used to get on the score board." as they arrive. Not in wizard mode.
  - a character who won and retired: "Sorry, this character is retired from moria." and "You can not
    resurrect a retired character.", and then a new character.
  - no to the resurrection, no save, or a living character's save: wizard mode from the start, after the
    disclaimer and "Are you sure?" if the game could still be scored. No ends the game, as Moria's does.
  - a death's save now holds the first ten pages, the core's data to the stores' stock (Moria's dead save keeps
    everything but the level). The pages in between are written too, the file is written in order.
  NOT Moria's, ours: a character who died before 16 October left a save of two pages, without the stock: they
  come back with the stores emptied, and stock comes in with the town. Our own check that refuses a save kept
  from before its character died leaves a resurrected character alone (their death is in the high scores).
  What s_sv_dead() did not do as the character died and Moria's saveChar() does (searching and resting off, the
  pack's weight out of the speed) is done as they come back.
  Seen in tests, tools\test\resurrect.ps1, seven steps: a character starving, poisoned (20) and at -3 hit
  points quits; Ctrl-W and yes: in the town at 0 hit points, food 0, poison 1 ("You feel better."),
  "Resurrected", the message, the stores' pages back (a mark put in them before the death), and saving left the
  scores as they were; that save loads normally and quits again; Ctrl-W and no: the disclaimer, "Are you
  sure?", a new character, "Is wizard"; Ctrl-W with that wizard's save: loaded in wizard mode with no question;
  a winner refused; and a save cut to two pages: brought back with the stores emptied.
  Found on the way, and put right the same day, asked by sdo: after any saved game is loaded, Moria shows the
  character sheet with "<f>ile character description. <c>hange character name." (changeCharacterName(), called
  by startMoria() in game_run.cpp, after enterWizardMode()), ours went straight to the game. Now in core.bas, for
  an ordinary load and a resurrection alike. The test scripts that load a save press ESC at it (Pass-Sheet in
  lib.ps1: dead-save.ps1, lifecycle.ps1, resurrect.ps1). Seen in tests: resurrect.ps1 steps 2 and 3, the sheet
  and then the game; lifecycle.ps1 on zf, za and zb (made, saved, loaded with the sheet the same, switched off,
  loaded again, saved again, "(saved)" once); dead-save.ps1; resurrect.ps1 steps 4 to 7.

## Debugging in VS Code

- 13 October 2026: the build now makes build\<project>.sld (tools\make-sld.py), which tells the DeZog debugger
  which address, in which page, is which line, for the core, the loader and every stage and library, so that a
  page of code can be told from the fifty others that run at the same address. Code compiled from BASIC is shown
  in the module's assembly, build\<module>.asm, code written in an Asm block in the .bas file itself.
  `build.ps1 -Start zd` starts the emulator waiting for the debugger on port 10001, and .vscode\launch.json and
  tasks.json in the workspace (D:\zxnext, outside this repository) make that F5.
  Seen: every module's assembly put together again gives the very binary that is in the game, the emulator
  started by zd answers on port 10001 and loads the nex file.
  Seen on 13 October, evening, in DeZog 3.7.4 itself: F5 builds, starts the emulator, loads the nex file and
  stops on the loader's first instruction, the di at line 9 of src\load.bas; a label hovered over gives its
  address; and a step over goes on to the calls that follow, shown in build\load.asm. A step back and a step
  forward again through the emulator's history work too, and the Memory Banks panel shows the page in each of
  the eight slots as the loader has set them (30 and 31 in slots 4 and 5, 0 in 6, 11 in 7).
  **Not tested: a breakpoint**, in the core or in a page of code that shares its address with others.
- NOT YET: stepping by BASIC line. Boriel's compiler writes no line numbers for BASIC statements, only for Asm
  blocks, so there is nothing to make it from yet.

## The opening

- 14 October 2026: before the screen of A's, the scene on the Bridge of Khazad-dum (drawn again on 15 October, laid out
  after a picture sdo liked: the bridge running away from us to the Balrog, winged and crowned with fire, its whip
  curling across the hall, Gandalf seen from behind at the lower right, Glamdring and his staff raised, blue and green
  walls, pink fire rising from the abyss; our own drawing, only the scene is Tolkien's). First as a 48K screen (the
  nex file's loading screen, page 10), with a tape's pilot tone (border magenta and blue) and a burst of made up data
  (blue and yellow) on the border and beeper, no tape is loaded; then the same scene on Layer 2 at 320 x 256 in 256
  colours (pages 66 to 75) with "You shall not pass!" through the DACs (pages 77 to 79); then the font is copied from
  page 76 into page 10 and the loader goes on as before. The 48K picture blends into the Next's (the ULA and Layer 2
  added together, layer mode 110, the 48K's palette fading down as Layer 2's comes up, 16 steps of 3 frames), and
  the words come once the blend is done. BREAK (Caps Shift and Space, the PC's Escape) at any point skips the rest,
  and the loader waits for it to be let go. Seen: the blend half way, and BREAK during the pilot tone giving the
  screen of A's within a second and the title, which stayed, 4 seconds after. tools\make-splash.py draws both pictures from one drawing,
  tools\make-voice.ps1 made src\splash-voice.raw. No words on either picture: the "Voice: TTS" at bottom left and the
  "(c) The Tolkien Estate" at bottom right were taken off on 18 Oct 2026, as sdo asked. Seen in the emulator: both pictures, the screen of A's with its font, the title after about 14 seconds.
  **Not heard: the sounds** (the emulator ran hidden), **not seen: the border stripes** (screenshots show only one
  border colour). **Not tested: a real Next.**
- The voice is Windows' text to speech (Microsoft Hazel, lowered and slowed, with an echo), not anyone's recording.
  NOT YET: a real voice, only with the speaker's written permission, then put through tools\make-voice.py. Using a voice for the line from the film needs its owner's permission too.
- sdo's choice in the conversation (my reading): the 48K pilot stripes are magenta and blue as asked, though a real
  Spectrum's ROM shows red and cyan for the pilot tone.

## Getting the game on to a real Next

- 14 October 2026, for the KS3 that is on its way: two ways, neither tried on a real Next yet.
- tools\push-card.ps1 copies the nex file and zxmoria.lic to the top folder of a Next's SD card in a card reader
  on this PC, only when they have changed, and checks each copy. Nothing else on the card is touched. -AutoExec
  makes the Next start the game when it boots (the card's own autoexec.bas is kept as autoexec.zxmoria-bak), and
  -NoAutoExec puts it back. It finds the card itself, but only among removable drives with a nextzxos folder, and
  refuses a folder given with -Card that has none. Seen: on a folder made to look like a card. **Not tested: a
  real card, through VMware Fusion's card reader.**
- tools\wifi-server.ps1 is a small web server from which the Next fetches the game with .http, the dot command
  NextZXOS comes with. The Next fetches getgame.bas once, and after that LOAD "getgame.bas" fetches the licence
  and the nex file and starts the game. The PC's address is written into the program. Seen: all three files
  fetched over the network, from this PC to itself, the same to the byte. In the emulator a program of the same
  kind ran each line in turn and started the game. The emulator has no Wi-Fi chip, so .http itself could not be
  tried. **Not tested: on a real Next.** Things to check then: that .http writes over a file that is already
  there, and that the 770KB nex file fits in its buffer (if not, -r on the .http line). The VM must be bridged,
  not NAT, and Windows' firewall needs the rule the script prints, once.
- The M3 MacBook's own card slot cannot be handed to the Windows VM (it is not a USB device), so a USB card reader
  is used, which Fusion connects to Windows. push-card.ps1 also finds a card the Mac shares through Fusion's
  shared folders.
- tools\make-card.ps1 makes a whole card: the official distribution (downloads\sn-complete-24.11.zip, NextZXOS
  2.09, firmware 1.44.db, cores 3.02.00 and 3.02.01) unpacked on to it, each file's length checked, then the game
  by push-card.ps1. It takes only a drive letter of a removable USB or SD drive of up to 64GB, and an empty one
  unless -Wipe is given, which formats it FAT32 once the card's label has been typed in. Seen, 14 October 2026:
  a 32GB card (S:, ZXNEXT) made from empty, 1,343 files, the game copied, a second run refused it as not empty,
  push-card.ps1 found it by itself. **Not tested: -Wipe, and that card in a real Next.** When the KS3 arrives,
  the card it comes with may have a newer distribution than this one, and is the one to keep as it is.
- NOT YET, **before the KS3's first boot**: the card was later written with poc4uat-zb.mmc by balenaEtcher (one 128MB
  FAT16 partition), whose distribution is old: NextZXOS 2.06H, firmware 1.29b, a core update file for 3.01.05. It
  must not go into a new KS3 like that. Reflash it with the current distribution (make-card.ps1 -Wipe with the
  newest sn-complete zip, 24.11 or later), and never use its core update file. Decided 14 October 2026.
- Ideas for later: move the emulator's base card to the same distribution as the KS3's (there is a 24.11 image,
  images\release-24.11-emulator\sn-emulator-24.11.img), so the game is tested on the OS it will really run on.
  Tried 14 October 2026 in ZEsarUX 13, neither boots: the 128MB new.mmc (NextZXOS 2.09) shows the firmware's
  first-boot video mode test, saves the mode, and then hangs before NextZXOS appears (PC at $0168 in ROM, MMU6/7
  stepping through pages, a black screen), the same after a fresh start; the 1GB sn-emulator-24.11.img stops in
  the firmware with "Error opening 'menu.ini/.def'!" though the file is there. Not looked into further yet.

## The licence

- ZXMoria is under Umoria's licence, the GNU General Public License, version 3 or later, decided on 12 October
  2026. The LICENSE file is Umoria's own, README.md gives the copyrights (Koeneke, Wilson, The ZXMoria authors),
  says that this is a modified version, and what passing it on requires. The help (?) and the versions (v)
  carry the notices and name the file. The source files have no headers of their own, by choice.
- 13 October 2026: the game no longer shows the licence, which Moria's Ctrl-V does. Whoever wants to read it has
  the file. Ctrl-V is help now, as ? is, because that is what the ? of a PC keyboard arrives as in the emulator.
- The licence's text is out of the game, the same evening: data pages 219 to 222 are free, and page 223
  (UB_PAGE_HELP_TEXT, build\data\helptext.bin) holds only the rogue like help and the rogue like wizard's help,
  which the text library has no room for in its own page. What the licence asks for is still met: the LICENSE
  file is in the repository and goes on every SD card image with the game, and the game's ? and v screens say
  whose it is, that there is no warranty, that it may be passed on under the GPL, and which file to read.
  N.B: anyone passing on the nex file alone, without a card image, must send the LICENSE file with it.
- build.ps1 puts the LICENSE file on the SD card images beside the game, as zxmoria.lic.

## Decisions still open

- Your own credit and version line on the opening screen.

## Ideas for later

- **The mini map is in** (16 October, night, sdo's design), ours, not Moria's: [ cycles off, 1:1, 1:2, taking no
  turn ([ does nothing in either of Moria's key sets; it was O until the evening of 16 October, when sdo chose [
  for the mini map and ] for the live monitor). It has the 16 by 8 characters at the bottom left of the
  screen (rows 24 to 31, columns 0 to 15), drawn with the upper half of the font, characters 128 to 255, and shows
  the walls the player remembers, as Moria remembers them (in the dark, the walls, not the floor), with the player
  as a pixel: at 1:1 a window of 128 by 64 squares that follows the player, at 1:2 the whole level.
  Two stages, stage-lib-minimap.bas: a bitmap of the level in page 44, one bit a square, 32 bytes a row, whose bits
  the walking stage sets as the player's light finds walls (s_cr_minimap_set()), and which is made again from the
  map (gub_minimap_rebuild) after a new level, a lit room, a spell, a wizard command, tunnelling or a monster
  boring through rock; and, only as the game waits for a command, the font made from the bitmap. Its pages are put
  in and out of the slots by writing the Next registers directly, so the monitor does not count them.
  The monitor's "MMU 2 misses, by page" moved up to rows 24 to 26, to make room (from column 34 since the evening).
  **Measured in the emulator** (T-states between the library's entry and return, breakpoint actions): each turn
  2.1 ms at 1:1 and 8.3 ms at 1:2, a frame is 20 ms; making the bitmap again 50 ms, on the rare events above.
  Seen: both modes drawn, the room in the right place at each scale, the cells cleared when it is off, the monitor
  beside it. Not tested: a whole level's walls (the wizard's Ctrl-L did not light the level in the test), a
  monster or a tunnel changing a wall that the map shows, a save and load with it on.
  16 October, evening, sdo's two tweaks, done the same night:
  1) the mini map is dark grey, and the one character with the player in it green: the library keeps which cell is
     green in its own storage (A_LIB_PRIVATE), and rewrites only that cell and the new one when the player moves
     into another, and sets it again whenever all 128 cells are drawn afresh (s_mm_player())
  2) the monitor's "MMU 2 misses" counters are on the same rows, 24 to 26, from column 34, their widest line, 46
     characters, ending at the screen's last column (UB_MN_MISSES_LEFT in stage-lib-monitor.bas)
  Seen in a test: at 1:1 127 cells dark grey and the player's green (row 25, column 7, for the square 8,61), after
  three steps east the green one column on (8,64) and the old one grey again, at 1:2 the green cell at row 24 column
  4, off: all 128 cleared; the monitor's three rows from column 34 to 79 beside the mini map.
- The test keys `T`, `M` and `S` were taken off the keyboard when the game took it over; the library test screens
  they showed are still in the code.
- Playing the same game in Umoria 5.7.15 itself and comparing, sdo's idea of 14 October, see "Against the real
  Umoria" below for what has been done. Its saved game can be read now (15 October), so the next steps are more
  of the game: walking, a fight, spells, the stores after a turn over.

## The next round

Gathered on 18 to 20 October 2026, while the work stood still. All of it is done here, in poc4uat; zxmoria, the
shared copy, only takes something when sdo asks for it to be carried over.

The order of work:

1. **A regression baseline first**: the comparisons in tools\test\regression.ps1 against the build as it now stands,
   after the build scripts, the src and build layout, the font and the emulator settings were all changed (18 Oct).
   DONE 20 October, on the seeded build of fdb19a7: 59 comparisons, 1,003 sections the same, 0 different
   (build\test\regression-2026-10-20.txt). Run again after the rest fix (the thief, above), stopped part way by Claude Code for
   low memory: 34 of the first 35 the same, the other a fault in the test, not the game (compare-level.ps1 now gives
   ZXMoria the two ESCAPEs after a rest that Umoria was always given), and the same once mended (build\test\regression-2026-10-20b.txt).
   Then all of it again, as a process of its own so Claude Code could not stop it: 64 comparisons, 1,152 sections
   the same, 0 different (build\test\regression-2026-10-20c.txt, about 2 hours).
   Again 21 October, with the monster memory a section of its own for the first time: 67 comparisons, 1,204
   sections the same, 2 different, both the monster memory missing the spell a Novice Priest cast (put right, see
   Faults found, and both the same since); build\test\regression-2026-10-21.txt, about 3 hours.
   Again 21 October, evening, with the message histories compared too: 89 comparisons, 1,675 sections the same,
   15 different, all in the messages: 8 the test's own (ZXMoria's message on show was marked "(showing)",
   now taken off), 5 the first two messages of a game and 2 selling, both put right, and the 7 the same since;
   build\test\regression-2026-10-21b.txt, about 4 hours and a half.
2. **The "Not tested" notes above, a subject at a time**, each as a new comparison with Umoria, a race and class of
   its own: monsters first (breeding, doors, eating each other, picking things up, experience drain, slaying weapons,
   pulling the player), then fighting and devices, objects, traps, movement, the character, saving.
3. **The 27 NOT YET markers in src**: sort them into things still to build and things only waiting for a test, and
   agree an order. DONE 20 October: all 27 are the "what is NOT here yet" heading at the top of a stage or library,
   not markers in the code, and none lists anything still to build. Most say "nothing that is known of"; four name
   a deliberate difference from Moria (equipment lists not kept on the screen, no cursor in look, the best 90 scores
   kept, not 1000) or a gap in Moria itself (nothing learnt from genocide); stage-lib-inventory.bas still listed
   wielding and the too-heavy weapon, both done long ago, and now says so.
4. **Soak tests overnight**, nightly.ps1 from the Task Scheduler, not from a Claude session.
5. **The real Next, when the KS3 arrives**: reflash its card with a current NextZXOS first, then push-card.ps1 and a
   checklist of what the emulator cannot prove: the keyboard (a held key, the punctuation, a PS/2 keyboard), the
   sounds by ear, the speed at 28MHz, saving to a real card (and a full or missing one), the opening's border stripes.

sdo's points, as they came to him reading the code:

- **DONE 20 October: the two message history routines named alike** (sdo, 20 October). In the core, `s_core_msg_*`
  is the message line itself (Moria's printMessage(): msg_text, msg, msg_more, msg_flush, msg_clear) and
  `s_core_message` / `s_core_message_after` fetch a numbered message from the strings pages and hand it to
  msg_text. Two routines are neither: `s_core_message_push()` puts the line that was showing into the Ctrl-P
  history, and `s_core_msg_forget()` (added 20 October) drops it instead. They become `s_core_history_push()`
  and `s_core_history_forget()`, with A_JUMP_MSG_FORGET renamed to match and every call and comment that names
  them.
- **DONE 21 October: s_core_countdown() taken out**, 339 bytes freed in the core (13,786 to 13,447). Its jump table entry ($8025, A_JUMP_RETIRED_8025, A_JUMP_SPARE1 since 23 October) now goes to s_core_crash(), and load.bas's two comments name s_core_get_key() and s_core_wait_for_vblank() instead.
  Was: **does s_core_countdown() still earn its place?** (sdo, 20 October.) Looked at the same day:
  nothing in poc4uat calls it. It is poc2demo's (the 5 4 3 2 1 with a stay key and a flip key, and the name of
  each key pressed, a test of the keyboard routine), kept in the core only by its jump table entry, the stub in
  stage-include.bas and a call in core.bas that never runs. So it can go: the routine, the stub and that call,
  freeing its bytes in the core. Its jump table entry ($8025) stays, pointing somewhere harmless, as the entries
  after it must keep their addresses. Two comments in load.bas name it as the reason for keeping 50Hz and the frame
  interrupt; both are still needed (s_core_wait_for_vblank()), and their comments would say so instead.
- **DONE 21 October: s_core_swap_paged_data() sorts by the UB_PAGE_ names.** The 34 UB_PAGE_ Consts in constants.bas became #defines, same names and numbers, so the Asm can take them, and UB_PAGE_MINIMAP_NUMBER, a copy kept for stage-crawl.bas's Asm, went. All 66 modules but the core came out byte for byte the same; the core differs in one byte, a fault put right on the way: the monitor counted page 53, the objects' last, as the tables, which are page 54 alone.
  Was: **page numbers typed out in s_core_swap_paged_data()** (sdo, 20 October). In the core's Asm that sorts
  each page fetched into the third slot by kind, for the live monitor, the bounds are bare numbers: 89, 66, 64, 63,
  55, 53, 50 and 47 (the maps, the screens, what the player knows, the strings, the tables, the objects, the
  creatures), though its own comment says they are the UB_PAGE_ constants. They become those constants (the Asm
  already takes #defines, e.g. A_NEXTREG_SELECT), so a page moved in constants.bas cannot leave the monitor's
  counts wrong. The same goes for the kinds' offsets into A_CORE_MMU2_KINDS (0, 4 ... 24, four bytes each) and the
  $50 of MMU slot 0's Next register.
- **DONE 21 October: UW_PLAYER_SIZE (768) in constants.bas, UB_SPELL_ORDER_SIZE (32) and UB_SPELL_ORDER_END (99) in globals.bas beside A_PLAYER_SPELL_ORDER**, used in core.bas's two loops (the size less 1), stage-player.bas's blank character, and every 99 of the spell order in stage-lib-books, -inventory, -magic and -wizard-3. The food stays for sdo. Every module the same size afterwards.
  Was: **767, 31 and 99 typed out in core.bas** (sdo, 20 October), in the new game's start, both clearing
  loops in Asm: `ld bc, 767` wipes the player's record (A_PLAYER, 768 bytes, which constants.bas gives only in a
  comment), and `ld bc, 31` with `ld (hl), 99` fills the order the spells were learnt in (A_PLAYER_SPELL_ORDER,
  32 bytes, likewise only in a comment) with 99, Moria's mark for "none". Each size a #define (a Const cannot be
  used in Asm) and 99 a named one, with each loop's count worked out as the size less 1. Nearby, the new character's
  food (7500, and 2 digested) is as Moria writes it, for sdo to say whether it stays.
- **DONE 21 October: UW_MONSTER_MEMORY_SIZE (5580) in constants.bas**, for core.bas's clearing loop and stage-lib-save.bas's copy. It is the number itself, not 279 x 20 worked out, as UW_CREATURES_IN_GAME is a Const and the Asm can only take a #define; the record size of 20 is not named yet.
  Was: **the monster memory's size typed out** (sdo, 20 October). core.bas clears it at start up with
  `ld bc, 5579`, and stage-lib-save.bas copies it with 5580: 279 kinds of creature (UW_CREATURES_IN_GAME) of 20
  bytes each, Moria's creature_recall. One #define, worked out from those two (a Const cannot be used in Asm),
  for both, and the record size of 20 named as well; constants.bas's own comments say "5580" and "279 of 20 bytes"
  in words, and those can stay.
- **DONE 23 October: nextreg everywhere.** The last four writes to a fixed register through the ports went: the core's
  start (page 32 into MMU 6, now `nextreg MMU_SLOT_6, UB_PAGE_CORE_DATA`), s_cr_minimap_set()'s two writes to MMU 0,
  and the score clock's two writes of the CPU speed (its $07 now NEXTREG_CPU_SPEED). What still goes through the ports
  is a read (Peripheral 1 to 3, the extra keys, the monitor, MMU 0 and the speed before they are changed) or a register
  chosen at run time (s_core_next_reg(), the core's slot swap, fub_mm_slot() and the mini map's slot write). Tested: the
  game starts, the clock read at birth (the time right), and the mini map's bits set as a lit torch finds walls (2,
  then 9 after 16 steps) with MMU 0 put back each time. zxpaging and poc2demo not touched.
  Was: **nextreg everywhere.** Every write to a Next register through the two OUTs to $243B and $253B becomes
  the Z80N's nextreg (22 port writes in 6 files on 18 October): smaller, faster, and one instruction, so an interrupt
  can no longer come between choosing the register and writing it. The ports stay for reading a register and for a
  register chosen at run time. (zxpaging and poc2demo have 7 each; zxpaging, being public, would be a v1.1.)
- **DONE 22 October: every definition in constants.bas and globals.bas.** 199 #defines and fixed address Dims
  moved out of 41 stage, library and include files, with the comments above them: values to constants.bas, addresses
  and Dims to globals.bas, a section for each file headed "private to <file>", which tools\check-addresses.ps1
  now reads to check a library's private storage with its own module, as it did when it was in the library's file
  (tested with overlaps planted on purpose). Every module byte for byte the same. Only STANDALONE and a Sub's own
  variables are left in the files. On the way, three names defined twice put right, one of them a fault (see
  Faults found, 22 October).
  Was: **every definition in constants.bas and globals.bas.** On 18 October 140 #defines in 73 files (about 66 of
  them each stage's own `#define STANDALONE`, which stays where it is) and 94 fixed-address `Dim ... At` in 27 files,
  mostly a stage's or a library's private storage. The whole memory map in one place; the price is that a change to
  either file recompiles all 66 modules (about 3 minutes). Only a Sub's own variables and STANDALONE stay in their
  files, and private storage is named so that it is plain who may use it. Asked for again on 20 October; counted
  again then: 140 #defines in 73 files and 93 `Dim`s outside a Sub in 26 files, and two Consts, true and false in
  load.bas, which stay (the loader is built without constants.bas).
- **NOT YET, in v1.0 (sdo, 21 October): no bare numbers that should be constants.** The survey, 21 October
  (a script over src\*.bas, outside comments, strings and the definitions themselves): 5,317 numbers other than 0
  and 1 in 82 files, 4,337 in BASIC and 980 in Asm. Roughly: about 650 Moria's own game numbers (chances, dice,
  damage, levels), 520 character and key codes, 470 offsets and sizes in memory, 200 screen rows and columns,
  140 masks and limits, 115 loop bounds, 980 in Asm, and 2,250 not yet sorted. Decided (sdo, 21 October): Moria's
  own numbers stay as Moria writes them, so the code can still be read beside Umoria's; everything that is ours
  is named (UC_ for character codes, as constants.bas already says). The check for each batch: every module
  compiled byte for byte the same as before (a name changes nothing in the code), so no regression is needed
  per batch; a byte that changes is a mistake or a fault found, and is explained.
  Done 21 October, 14 batches, every module byte for byte the same after each (the script that checks it refuses
  to report if the build stopped part way, which once it did): the keyboard (UC_ character codes, the key matrix,
  the Next's extra keys), the rest of core.bas that is ours, key and character comparisons everywhere, record
  offsets, Moria's own named constants written as numbers (PLAYER_FOOD_*, PLAYER_REGEN_*, CS_FREQ, CM_TR_SHIFT,
  ITEM_SINGLE_STACK_MAX, ITEM_GROUP_MIN, OBJECTS_RUNE_PROTECTION, PLAYER_MAX_EXP, OBJECT_LAMP_MAX_CAPACITY,
  MON_CHANCE_OF_NEW, by Moria's names; a Moria literal stays a number, a Moria name becomes ours), the live
  monitor, the mini map, the saved page tests (85), the help texts, a score's fields, the save library, the
  library private storage used by number, and every Next register by its official name (NEXTREG_, 115 nextregs).
  The loader now includes constants.bas. Taken out on the way, all unused: the tilemap register's bits (wrong for
  all but bit 7), Peripheral 1's, the keyboard port masks, and UB_NEXTREG_PERIPHERAL_1 (it was $08, Peripheral 3).
  Lessons: an expression like x + A - B is two sums, ( A - B ) folds to one; @variable costs a byte where a
  #define of the address does not. The survey went from 5,317 to about 4,600; what is left is mostly Moria's
  own (its screen layouts, chances, dice and tables), the Asm's register values with their comments, and ours
  still to go through file by file.
  DONE 22 October, the last of ours, each batch byte for byte the same: Moria's enums by Moria's names
  (UB_FOOD_, UB_POTION_, UB_STAFF_, UB_WAND_, UB_MAGE_, UB_PRIEST_, UB_TRAP_, UB_INNER_ROOM_, UB_SPELL_TYPE_), the
  death screen (its pictures, the length of "Ripe Old Age"), player creation (the race and class record size,
  the background's fields, the not-chosen marker, the auto-roller's own numbers), the spell tables' record sizes,
  the wizard's superhuman command (its tables' fields and its own amounts; the comment said 12 bytes an entry,
  it is 13), and the loader (its pages, the register select port, the registers it reads, the DAC and divMMC
  ports). The survey now counts 4,337. What stays a number, as decided: Moria's own literals (chances, dice,
  levels, its 60-character history lines, its 1200 and 10000 limits), the screen positions copied from Moria's
  layouts (sdo, 21 October: "for now"), the pictures' character codes in the death screen's Asm (13, 92, 34,
  each said in a comment), the data tables' object numbers (each with its name in a comment), and the loader's
  register values, written in binary with a comment on every line saying what each bit does.
  Was: **no bare numbers that should be constants.** sdo found fixed numbers here and there in the source
  (20 October) that should be constants, or worked out from them. For example, stage-lib-turn-2.bas has the
  bottom row's place on the screen (row 23, columns 0, 7, 13, 22, 29, 38, 49, 59), the item categories that can be
  enchanted (10 to 39) and the flag masks $4000107F and $07FFE980. The one sdo saw is 5120, the size of the
  screen's tile map (80 columns by 32 rows, two bytes a cell), typed out 18 times in s_core_ram_copy() calls across
  ten libraries and stage-magic-include.bas, with 5118 (the same less the first cell) in the clearing loops in
  core.bas and load.bas: one constant, worked out from the columns and rows, would do for all of them. DONE 21 October: UW_SCREEN_CELLS_SIZE, a #define of 5120 (the Asm cannot take UB_SCREEN_COLS, a Const), in all 18 copies and core.bas's clearing loop; load.bas keeps its 5118 and $E000, as it is built without constants.bas; stage-lib-wizard.bas's 767, its three map rows, now UW_WZ_ROWS_SIZE beside A_WZ_ROWS. The rest of the survey still to do. First a survey, a file at a time, of each number
  that is not 0 or 1; then each given a constant in constants.bas, or worked out from one (a size times a count, an
  offset plus a field), with the regression run after each batch. Numbers Moria itself writes as numbers (a chance
  of 1 in 50, a dice throw) might stay as Moria has them, so the code can still be read beside Moria's; that is for
  sdo to decide when the survey is done. Best done with, or just after, every definition in constants.bas and
  globals.bas (above), as both recompile everything.
- **NOT YET: a trial of Boriel ZX Basic 2.0**, and for it, more than one version of each tool side by side:
  Boriel, sjasmplus, ZEsarUX, hdfmonkey and CSpect, each in version subfolders inside its own folder in D:\zxnext
  (today boriel, sjasmplus, zesarux, cspect, and tools\hdfmonkey.exe, one version each). sdo will go through his
  ideas for it first (20 October). It touches the workspace as well as poc4uat: the build scripts that find each
  tool, onetime-setup.ps1 that installs them, and the version table.
- **NOT YET, after the 2.0 trial: Boriel's TYPE records**, if 2.x has them, so `player.exp As ULong` in place of
  `gul_player_exp` (20 October). Not in the local Boriel docs or the installed compiler's changelog, so first find
  out what 2.x offers. Today's variables sit at fixed addresses (`Dim ... At A_PLAYER + 592`). Saved games need not
  carry over from one build to the next while this is a proof of concept and a beta (sdo, 20 October): a save of
  another version is already refused, and save-check.ps1 and dead-save.ps1 make their own saves on the build under
  test. What does rely on the addresses: the Asm that reads the variables, and zxmoria-state.ps1, which reads
  ZXMoria's memory by page and offset for every Umoria comparison. So the aim is to keep the layout as it is: each
  record placed at the address its variables have now, its fields in the same order and of the same sizes (sdo,
  20 October: "we should strive to maintain alignment"), and where anything must move, zxmoria-state.ps1's offsets
  move with it (better still, taken from the build). Naming (sdo, 20 October): the record keeps the g, the field
  takes the type letters: `g_player.ul_exp` for `gul_player_exp`, `g_player.sw_rest` for `gsw_player_rest`.
- **NOT YET: the five msg routines in the core?** Presumably those of stage-message-include.bas, compiled into every
  page that includes them: one copy in the core, through the jump table, would free room in each. Find which five,
  what each page would save, and set it against the core's room: 13,552 of 15,805 bytes on 18 October, 2,253 free
  (build\core.size; the build log lists only the ten fullest modules).
- **NOT YET: a Balrog's roar in the opening**, about four seconds, ours, made from noise and low tones (deep,
  rumbling, rising, a crackle of fire), never from a film or a sound library. The spoken line's player and its
  pages, 77 to 79 (24KB), are free since it was taken out, and about 6,000 samples a second gives four seconds.
- **NOT YET: a roar command, ours, not Moria's** (sdo, 20 October): a new key in play that sounds the Balrog's
  roar (above) on demand, on the Next's speaker. It takes a turn, and wakes the monsters over a wide area round the
  player, but not the whole level: sleeping ones within some distance wake (their sleep set to 0), nothing more.
  It does not aggravate them: no speeding up, unlike Moria's aggravate monster. The key must be hard to press by
  accident: sdo suggests ~ (tilde), which Moria uses for no command in either key set (it is only its own mark for
  a key it does not know) and which ZXMoria's keyboard table already gives (core.bas, row 1, a = ~). N.B: the test
  scripts type ~ as ESCAPE, so a test of the roar needs another way to type a real tilde. To settle: the distance, whether walls and doors muffle it, and how the sound reaches the
  speaker. Being ours, no Umoria comparison can cover it; a test of its own, and the help screen and messages.txt
  told of it.
- **NOT YET: colour on the map**, ours, not Moria's. Only the symbols of monsters and items in the main view are
  coloured; not the mini map, and no text (messages, inventory, stores and look stay as they are), so only the
  core's routine that works out and draws what a square shows changes.
  - the colours: a creature's from a new byte in its record (+50, of 14 spare bytes, +50 to +63), copied into the
    live monster record at +15 beside the symbol it keeps at +14; an object's from a new byte at +59 (of 5 spare,
    +59 to +63); for the flavoured kinds (potions, mushrooms, staffs, wands, rings, amulets), whose names are shuffled
    every game and whose 16 byte name slots are full ("Aluminum-Plated"), a table of their own, 164 bytes
    (49 + 22 + 25 + 25 + 32 + 11), made by create-data.ps1 and found through the game's shuffled order (A_KNOW_*); a
    gap of about 240 bytes after A_TABLE_COLOURS should hold it (to confirm)
  - Umoria's colour words (a survey of all 279 creatures, 419 objects and the six flavour lists, 20 October): 27
    colours (Azure, Black, Blue, Brown, Chartreuse, Crimson, Cyan, Ecru, Golden, Green, Grey, Indigo, Magenta, Orange,
    Pink, Puce, Purple, Red, Rusty, Tan, Tangerine, Turquoise, Umber, Vermilion, Violet, White, Yellow), 20 metals and
    stones (Amber, Amethyst, Aquamarine, Brass, Bronze, Copper, Coral, Emerald, Garnet, Gold, Ivory, Jade, Obsidian,
    Onyx, Opal, Pearl, Ruby, Sapphire, Silver, Topaz), the shades Light, Dark and Metallic, and Fire, Frost and Ice,
    and Lightning in creatures' names
  - decided: unknown potions and the like show their flavour colour on the floor (Angband does; Umoria gives no such
    hint, a deliberate difference); hallucination makes the colours random as well as the symbols; Multi-Hued (the
    three dragons) a rich purple or violet; Shimmering silvery; no colour ever changes for effect; an invisible
    creature, when it can be seen, pale grey
  - decided (sdo, 21 October): every object and item coloured on its own wherever its name gives a colour, and any
    that does not, a default colour for its class (e.g. metal weapons grey, food brown, as Angband); monsters a
    colour from the name wherever there is one (Grape Jelly included), all others red, as now. In v1.0, and it
    must not change play: the comparisons with Umoria read memory, so they will show it if it does
  - the palette: written with all nine bits, register $44, two writes a colour (RRRGGGBB, then the lowest blue bit),
    in place of the 8 bit writes to $41 that load.bas makes now, the 16 colours of today included. N.B: text mode can
    only ever show about 126 of the 512 colours: 128 pairs of the 256 entry tilemap palette, every paper black, so 128
    inks at most, less black (pair 0), less any colour whose top 8 bits are $E7, the transparent colour, which the
    hardware compares on the top 8 bits only. About 65 to 70 pairs are wanted, of the 112 free. No palette swapping.
- **NOT YET: micro pictures.** The Balrog, the dragons and the next toughest creatures each drawn as an 8 by 8
  picture in the font's unused codes 0 to 31 (128 to 255 are the mini map's), in place of Moria's letter on the map,
  a deliberate difference: one Balrog picture, three dragon pictures (Young, Mature, Ancient, each of Umoria's 18
  dragons drawn in its own colour), and 28 more, chosen by level and experience, the list for sdo to approve, some
  perhaps sharing a picture. Drawn in create-font.ps1, as the font is. The Balrog's is chosen (20 October), in fiery
  red, the bytes 24 99 DB FF 5A 19 24 66: horns; wing tips and head; wings and neck; wings meeting the shoulders;
  wing ends, arms and chest; waist and whip; legs; feet. To check: that 0 to 31 are free, and what look, recall and
  hallucination show for them.
- **NOT YET: a second font, 512 characters in all** (sdo, 21 October). The tilemap's 512 tile mode, register $6B
  bit 1: bit 0 of each cell's attribute byte becomes a ninth bit of the character number, so characters 0 to 255
  come from today's font and 256 to 511 from a second, chosen cell by cell, both on screen at once (for micro
  pictures and the map's symbols, above). The font grows from 2KB to 4KB, page 10 offset 0 to $0FFF; the screen
  stays 5120 bytes, 80 x 32 cells of two bytes each, as now, since the ninth bit takes a bit the attribute byte
  already has. That bit is "ULA over tilemap" today, which only counts while the ULA is on, and the game turns the
  ULA off ($68 bit 7, load.bas), as 512 tiles need. To check: that nothing uses page 10 from $0800 to $0FFF once the
  game is going (the loader's 48K picture is there before, the system variables from $1B00); the core's printing
  given a way to set the bit; create-font.ps1 to make the second 2KB.
- **NOT YET: sort src\messages.txt by name, once.** A message's number is its place in the file (create-data.ps1
  numbers them in order and checks each against its UW_MSG_ Const in constants.bas), so all of about 330 Consts are
  renumbered to match, by a script, then a full recompile. Once only: new messages still go on the end afterwards.
  Check first that nothing saved holds a message number.

## Against the real Umoria

- 14 October 2026: **the same seed makes the same character in ZXMoria as in Umoria 5.7.15 itself.** The Windows
  program (umoria.exe, in umoria-bin beside the tools, it runs on this PC) takes a seed, -s, and ZXMoria can be
  built with one, UL_GAME_FIXED_SEED in constants.bas. tools\test\umoria.ps1 starts Umoria in a hidden console of
  its own and types into it; tools\test\compare-umoria.ps1 makes the same character in both, has each write its
  character file (C, then f), and compares the two files, layout apart.
  With seed 12345, eight characters, all male and all called bob: a Human Warrior, a Halfling Mage, a Dwarf
  Priest, a Half-Troll Warrior, an Elf Ranger, a Half-Elf Rogue, a Half-Orc Rogue and a Gnome Mage. **No
  differences in any of them**: the six stats (18/43 12 14 15 11 11 for the Human), age, height, weight, social
  class, gold, hit points, the plusses, the abilities in words, the background word for word, and what they
  start out carrying.
  So the random numbers are seeded and used as Moria's are from the title to the town: the stores' owners, the
  stat dice, the race's and the class's changes to them, the history, the age, height and weight, the gold.
  What the two files differ in is layout only: Umoria's has the character's title, ours writes "Exp to Adv."
  The same for a Human Warrior with seeds 777 and 31337.
- **A fault found that way and put right: every turn was one out.** The wizard's sample of random objects
  (Ctrl-B) is written to a file by both games, so it can be compared too, tools\test\compare-objects.ps1: forty
  objects for level 10, taken as soon as the character reaches the town. The two lists differed for their first
  six objects and were then the same, to the last enchantment and curse, which is what two runs of the same
  random numbers look like when one starts a little after the other. tools\test\find-offset.ps1 moved our
  generator on and back until the lists agreed: Umoria was exactly one random number ahead, with each of three
  seeds. Moria's turn counter starts at -1, so its first turn is turn 0, and on turn 0, as on every sixteenth
  turn, it throws for the slim chance of sensing an enchantment; ours started at 0, its first turn was turn 1,
  and it did not throw. gsl_game_turn starts at -1 now, see s_core_main(). With that the forty objects are the
  same, every one. It also put right, unseen, when everything else that goes by the turn happens: the stores'
  turn over, the regeneration and poison that go by odd and even turns, which turns a slow monster moves on.
  N.B: as in Moria, a store entered on turn 0 is locked, which wants a character who starts beside its door.
- Bigger samples, seed 12345, all the same as Umoria's, every line: 200 objects for level 1, 300 for level 30 and
  300 for level 50, wands and staffs with their charges, armour and weapons with their plusses, the curses.
  **A second fault found on the way, ours and a day old:** the two 300s stopped after 8KB of the file with "File
  could not be opened." The handle of a file kept open from one page to the next, gub_core_file_handle, had been
  given two bytes that the live monitor's counts of page changes already had, so a count going up between two
  pages changed it. It has bytes of its own now, see globals.bas. A saved game is written with nothing in
  between its pages and its tests passed, but it was open to the same fault.
- 15 October 2026: **the whole game, not only the character.** Umoria's saved game can be read:
  tools\test\umoria-save.py undoes its scrambling (each byte is xor'ed with the one before it) and prints the town
  or level it holds as text: the map square by square (what it is made of and its four flags), everything lying on
  it, every monster (its kind, hit points, sleep, speed, distance, whether it is seen), the six stores with every
  item in stock and what was paid, and the player's turn, gold, experience, hit points, mana, food and status.
  tools\test\zxmoria-state.ps1 reads the same out of ZXMoria's memory in the emulator and prints it the same way,
  and tools\test\compare-level.ps1 makes the same character in both, saves Umoria at once (Ctrl-X), and compares
  the two a section at a time. -Level goes to a dungeon level first (wizard, Ctrl-D), -Rest rests there for so
  many turns, -Keys types any keys into both. The first byte Umoria's save scrambles with is the next
  randomNumber( 256 ) - 1 from its generator, so the comparison also shows whether the two games' random numbers
  are still in step, which is how faults that nothing on the screen shows yet were found.
  **All the same** with seed 12345 (a Human Warrior) and seed 777 (a Halfling Mage): the town, its 4 people and
  all six stores' stock (142 lines); dungeon levels 5, 10, 15, 30 and 50 as they are made, 66 by 198 squares,
  up to 106 things and 34 monsters; and, once the three faults below were put right, the turns: a turn of
  searching, 130 turns of rest on level 5, 1,000 turns of rest on level 5 (broken off at turn 212 by a monster
  coming into view, as in Umoria), and 300 turns of rest on levels 30 and 50 (with monsters waking and walking).
- **Three faults found that way and put right, 15 October:**
  1. **The window was a half window too high or too far left** for a player on rows 5, 16, 27, 38, 49 or 60, or
     columns 16, 49, 82, 115, 148 or 181: the compiler works out 22 / 4 as 5.5 where Moria's C has 5, see
     fub_core_map_outside_panel() in core.bas. It mattered beyond the look of it: a monster outside the window is
     not seen, even by the wizard, so a monster that ZXMoria wrongly showed noticed the player when Umoria's did
     not, and from then on the two games' random numbers were one apart every turn.
  2. **A rest broken off by a monster ended one turn late**: the disturbance was only acted on before the next
     command, after the next turn's eating and healing, which go by whether the player is resting, so ZXMoria ate
     one less. It is acted on after the monsters' turn now, and after a monster wandering in, see stage-crawl.bas.
  3. **...and it must end at once, in the middle of the monsters' turn**: Moria's playerDisturb() stops the rest
     there and then, so the monsters still to move that turn notice the player as they do when the player is
     awake. s_mon_disturb() in the new stage-disturb-include.bas does that part at once, in the four monster
     libraries; the words on the screen follow when the flag is dealt with.
  4. **...and searching too** (15 October, night): turning searching off changes every monster's speed, which could
     not be done while one of them was in the working record, so it waited until after the monsters' turn. The
     speed change now puts the working monster right as well, so it happens at once, see "Each turn" above.
- 15 October, night, after the disturbances were made Moria's: **all the same again**, seed 12345: the town;
  level 5 with 130 and with 1,000 turns of rest; levels 30 and 50 with 300; level 5 with a turn of searching; and
  five turns of searching from a count (#5s, -Keys and -Wait, new in compare-level.ps1). Search mode and then a
  rest (-First S, new) is the same too, but proves little: a rest turns searching off, in both games. Search mode
  and then searching from a count (#999s) on levels 5, 30 and 50 is the same, every section: each count was broken
  off within a few turns, on level 5 on turn 4 by a monster's spell that left the player afraid (status 00000010
  in both), which is a disturbance in the middle of the monsters' turn with searching on, the case of 15 October,
  and every monster's speed afterwards was Umoria's.
  N.B: compare-level.ps1 now shows ZXMoria's state as Umoria's save leaves it (searching and resting off, the
  pack's weight out of the speeds), see zxmoria-state.ps1, and play-lib.ps1's Press types # (Symbol Shift and 3).
- 16 October, early: **walking, the same as Umoria's**, seed 12345: eight steps east and eight west along the
  corridor on level 5 (the player stops where Umoria's does, at 16,60 on turn 7, the steps into the wall taking no
  turn in either), sixteen steps east, four and four on level 30, four down and four up on level 50, every section
  the same. N.B: compare-level.ps1 had been letting Start-Game put the project's own build in place of the seeded
  one whenever the project was built after it, the seeded copy is now dated as it is copied.
- 16 October, early: **a fault found that way and put right: standing still threw a die it should not.** Moria's
  playerRandomMovement() throws the 1 in 4 die for a confused player's stagger on every move, but not for 5,
  standing still, "never random if sitting"; ours threw it for 5 too, so each turn stood still used one random
  number too many and the two games went their own ways from there. Found by a fight on level 5 (a rest of 1,000
  broken off by a monster at turn 212, then standing still while it came): the very first 5 put the random
  numbers out. Since: one 5, and eight 5s with the monster arriving and frightening the player, the same as Umoria
  in every section, the fear's count of turns too (compare-level.ps1 now shows the player's 23 counters, fear,
  blindness, poison and the rest, as both games keep them, and ~ in -Keys is ESCAPE, for a -more-).
- **Two more faults found by the same fight, and put right, 16 October:**
  1. **Every level gained cost half of the experience over what it needed.** Moria's playerGainLevel() goes up a
     level first and then trims the experience to half of what is over base_exp_levels[ level - 1 ], which is
     what the level AFTER the new one needs, so it only bites when several levels are gained at once; ours took
     what the new level itself needed, so killing the Novice Priest at level 1 (7 x 2 = 14) left 12, not 14.
     See s_ef_display_experience() in stage-lib-effects.bas.
  2. **After a kill the player could walk on by themselves.** A key held down repeats walking (ours, not Moria's),
     and the key it watches was the last one pressed, which after a -more- in the middle of the command was the
     SPACE or ESCAPE that answered it: held a moment, the attack's direction was repeated, a step a turn. Only a
     direction key or s carries a repeat on now, see stage-crawl.bas.
  N.B: once, at 01:09, rest 1000 and eight 5s matched Umoria completely with the build that still had the extra
  die for 5, and every run after it differed, the same build each time: not understood, a comparison may pass by
  luck now and then, so a pass is worth repeating before it is relied on.
  16 October, 03:19 to 03:38, with all three put right: **ten comparisons, 110 sections, every one the same as
  Umoria's**: the town; level 5 with 130 and 1,000 turns of rest; levels 30 and 50 with 300; a turn of searching;
  eight steps east on level 5; four down and four up on level 50; search mode and searching from a count; and the
  fight, ten attacks to the Novice Priest's death and two steps on, the second time it has matched.
- 16 October, evening: **the comparisons now look at what the player carries**, the stats, the pack item by item,
  the equipment (an empty place printed as "empty": Moria fills one with object 417, ZXMoria with noughts, both go
  by the category), the weight, the spells and the known kinds of thing (objects_identified); and `|` types ENTER.
  New, all the same as Umoria's: eating a ration, three (bloated), three and 200 turns of rest; the walk to the
  Alchemist, a Potion of Slow Poison bought at its asking price, drunk, and 50 turns of rest; Scrolls of Phase Door
  and of Light bought and read (the same square after the phase door); down the town's stairs to a new level 1,
  and 100 turns of rest there; a mage learning Magic Missile (G, a), casting it (1 mana spent, the spell marked as
  having worked) and resting 50 turns; a priest given a prayer at random (Bless, for this seed), reciting it (its
  20 turns) and resting, the rest broken off at turn 22 as the blessing ends, in both. **tools\test\regression.ps1**
  holds every comparison that has passed, the ten of the night before (recovered exactly from the session's log)
  and these fifteen: 25 comparisons, 17 sections each, all the same (16 October, 17:36 to 19:2x, in three runs).
  Then, 19:37 to 19:42, on level 10, an unknown potion and an unknown scroll walked to, picked up, drunk and read,
  each kind then known (objects_identified) the same in both: 27 comparisons. The walks are planned on the level's
  map by tools\test\find-path.py, which opens doors that are neither locked nor stuck on the way (o and the
  direction) and goes round traps, rubble, stairs, monsters and locked or secret doors; a scan of levels 1 to 15,
  each reached afresh as compare-level.ps1 reaches it, found potions or scrolls in reach on levels 4, 8, 9, 10, 11
  and 14 (the rest closed in by secret doors). N.B: levels reached the same way from the town share their layout,
  the same dice in the same order, the level changing only what is put in them.
  And 19:42 to 19:46, the starting kit worn: the armour, all three (dagger, armour, cloak, each in its place), and
  the armour put on and taken off: 30 comparisons. Going up stairs is not compared yet: on every level scanned the
  stairs are behind secret doors from where the player arrives, a walk to them would need searching, or a Ctrl key
  in compare-level.ps1 for the wizard's teleport.
  N.B: once, two comparisons run one after the other in the same PowerShell session, the second ran the project's
  own unseeded build in place of the seeded one it was given, and came out all different; run on its own it
  passed. How is not known. compare-level.ps1 now checks the file the game ran against the one it was given and
  says "WRONG BUILD" if they differ, regression.ps1 shows it in its summary.
- Not compared yet: nothing on the list as it stood on 17 October, see "Faults found and put right". (Done since the first list: spells beyond the first,
  a monster killed by a spell, going up stairs, and the stores' stock turning over, see "Faults found and put
  right".)
- 17 October, each with a race and class of its own from now on (sdo's wish, the old ones not redone): a trap
  walked onto (a Dwarf warrior, level 2), a locked door picked and a stuck door bashed (a Half-Orc rogue), and a
  secret door found by searching, opened and stepped into (a Gnome mage, with the monsters in sight vanquished by
  ^f and a torch wielded, Moria gives a tenth of the chance in the dark), all 17 sections the same: regression.ps1
  is 50 comparisons. N.B: a key typed while a count runs breaks it off in both games, so `#30s~~` ends wherever
  the next key lands (Umoria about 20 turns in, ours about 23) and looked like a fault, a long count must end
  -Keys, with -Wait; and Umoria, driven from Git Bash, quits at once, run the comparisons from PowerShell.
  17 October, later: throwing (a Halfling rogue, a Green Jelly summoned beside him): two throws backed out of, a
  stiletto that missed and two torches that hit, and one thrown west that landed short, all 17 sections the same
  once the fault below was put right: regression.ps1 is 51 comparisons, the whole of it run again on the fixed
  build, 867 sections, all the same. N.B: throw is f in the original keys, t is
  take off (Moria turns f into t inside), and a jelly beside a level 1 character kills him once woken, so throw from
  two squares off.
  Still to come: digging (a Half-Troll priest), selling (an Elf ranger, and with it ESCAPE at the sell question,
  which in Moria makes the step into the store a free turn, see "Faults found and put right"), Word of Recall (a
  Half-Elf paladin), a deep fight with monster spells and breath (a Human ranger), and spikes.
- Not to be compared: a female character (Start-Game in lib.ps1 always answers m). sdo's decision, 15 October:
  being female only changes the starting gold (50 more), the height and weight tables (the same random draws)
  and the words Female, F, Queen, all read off the same flag as the male ones.
- **The whole regression on the build to be released, 22 to 23 October (20:31 to 02:01): 96 comparisons, 1805
  sections, every one the same as Umoria's, none different, none failed.** A seeded build (12345) of
  commit 9e29412, whose last change to the source is b151bf9: with the colour, the plain map option, the turn taken
  by catching breath and by coming out of a store, and the Wand of Trap/Door Destruction stopped by rock. The cases
  that now differ on purpose (the dungeon's lantern filled, ESCAPE at selling) are not in it.
  (build\test\regression-final.txt)

## Umoria's own oddities

The one list of them is umoria-oddities.md, beside this file: what Moria does, what we do, and why.

## Faults found and put right

- 27 October, **a monster that cast a summoning spell turned into a copy of what it summoned,** since the start.
  The new monster is made in the working monster (A_MONSTER), which is the caster's own record while it casts, and
  the monsters' turn then stored that back over the caster, so the summoner vanished and the summoned one was there
  twice, once in each record. Umoria works on the list itself, so its summoner stays. Found in zxcrawl, where Sauron
  disappeared on summoning; the monsters library now keeps the caster and puts it back, as breeding always did
  (UB_MON_KEPT), and fetches its creature again. Checked with a summoner made beside the player: before, a Green
  Jelly's record held the Grape Jelly it summoned from the next turn; after, a Red Worm mass summoned four times and
  was itself throughout. Not compared with Umoria yet, no comparison has had a summoner cast.
- 22 October, **the new game wiped only 595 of the player record's 768 bytes,** since the morning of 21 October.
  Naming 767 as UW_PLAYER_SIZE - 1 met a UW_PLAYER_SIZE already in globals.bas, 595, how much of the record is
  used, and the later definition won; the check that day was by module sizes, and ld bc, 594 is as long as ld bc,
  767. No harm done, the bytes past 595 are unused, but put right (the old one is UW_PLAYER_USED now), found by
  looking for names defined twice before the definitions tidy. Lesson: the byte for byte check, not sizes; and
  a #define defined twice takes the later value, without a word from the compiler.
- 21 October, evening, **the first two messages of a game, put side by side, were kept as the first alone.** The
  history's line is noughts until a message has been put away, and the joining wrote the second message two
  columns on without writing the two spaces between, so Ctrl-P read "You are full." and stopped at the nought.
  Found by the regression, now that the histories are compared (five cases), and seen in the emulator: the screen
  and the line were right, the two bytes between were 0.
- 21 October, evening, **"Selling ..." and "You've sold ..." never reached the history.** The store printed them
  straight on to the top row, as the equipment library did; now each is a message, as Moria's printMessage().
  ("You have ... (c)" after buying is Moria's putStringClearToEOL(), no message, and stays out.)
- 21 October, **blindness left the monsters lit for the rest of the turn.** Moria's playerUpdateBlindness() calls
  updateMonsters( false ) as the blindness begins and as it ends; ours did not, and a lit monster gets its moves
  however far off it is, so the random numbers came out one draw apart (measured by stepping ZXMoria's seed
  against Umoria's). Monsters are now also seen or not by the PY_BLIND status rather than the blind counter, as
  Moria's monsterUpdateVisibility() does. Found by running blind; a Mushroom of Blindness alone showed it.
- 21 October, **F with no light wielded said "You have no oil."** Moria fills an empty place with object 417,
  whose sub category is 64, so its lamp test says "But you are not using a lamp."; ours is all noughts, and its
  comment had it backwards. Found by the lamp comparison.
- 21 October, **"You are wielding ..." never reached the history.** Found by the bow comparison, now that the
  message histories are a section of their own: the equipment library printed its messages (wielding, wearing,
  your light source, was wielding, dropped, cursed, primary weapon) straight on to the top row, after a -more- of
  its own. Now each is a message like any other, put after the one showing if both fit, as Moria's
  printMessage(). The slaying weapon comparison had the same gap and it was not seen (only the state was compared).
- 21 October, **the monster memory never learnt which spell a monster cast.** Found by the new monster memory
  section of the comparisons: a Novice Priest's fear spell, bit $1000, in Umoria's memory and not in ours; the
  count of spells seen was right. The monster spells library sent the spell's number back in gub_shared_2, which
  s_core_next_reg() uses on the way back to the caller's page, so the memory was given the page's bit, none at
  all. The number is now the library's answer, gsw_lib_result. Nothing else hands a result back in gub_shared_1 or
  gub_shared_2 across a library call (looked for the same day).
- 17 October, **backing out of a question took a turn.** Found by the throwing comparison: an ESCAPE at "Fire/Throw
  which one?" cost a turn in ours and not in Umoria. Moria's getDirectionWithMemory() and
  inventoryGetInputForItemId() set player_free_turn themselves on ESCAPE (and the second on a "no" to a capital
  letter's "are you sure"), so backing out of any question for an item or a direction takes no time. Ours left it
  to each command, and four got it wrong, each with a comment saying Moria charges the turn: throw, bash, aiming a
  wand, and the direction of a bolt or ball spell (whose mana was taken too). The direction questions of the fight
  and throw, cast, commands, moves and traps libraries, the wand's own, and fsw_inv_choose() now set it, as Moria's
  do. N.B: it follows that, as in Moria, an ESCAPE at the item question of a Scroll of Identify or Recharging spares
  the reading's turn, and one at the store's "sell which one?" spares the step into the store (Moria sets it back
  only after an inventory command in the store); the second is to be compared with selling.
- 17 October, **the turn a store is entered in was cut short, and Ctrl-W saw the monsters too soon.** Comparing
  a priest walking into the Magic Shop and straight out put the random numbers out of step, an awake townsperson
  not having moved: Moria's storeEnter() is called in the middle of the player's move, and when the player comes
  out that turn goes on, the monsters have theirs, ours left the turn for the store at once and lost it (a
  warrior's visits matched only because his townspeople were all asleep). The walking stage now finishes that turn,
  the monsters' turn and what it disturbs, as it comes back out of a store. And Ctrl-W asked for the monsters to
  be looked at again at once, a monster in view became seen a turn before Umoria's: Moria's
  commandFlipWizardMode() does not, the wizard sees them from the next turn's look.
  With them: Stinking Cloud and Lightning Bolt killing summoned monsters, a wand identified (^i) and aimed, a Staff
  of Light bought and used, and a priest's Orb of Draining at a summoned monster (the third prayer book bought at
  the Temple, the priest taken past level 15), all 17 sections the same: regression.ps1 is 46 comparisons, and the
  whole of it, with both faults put right, 782 sections, the same as Umoria's (17 October, about 03:05). Moria
  5.7 has no rods (they are Angband's), so there are none to compare. N.B: an offer above the asking price is
  "What did you say?" in both games, the haggling goes on, so a purchase is made at the asking price exactly.

- 16 October, night, **a repeat count kept in one byte.** Comparing the wizard's + with a count of 300 (a mage
  taken to level 5) gave 95 experience here and 101 in Umoria: ours kept the count in a byte and stopped it at 255,
  and the level gains halve what is over each level's need from there. Moria's command_count is an unsigned int
  and find_count (a run given a count) an int, a count may be up to 999. The count is two bytes now, at core data
  + 760, which nothing used (guw_game_command_count), and so is a run's step limit (guw_game_run_limit, + 7000 and
  + 7001), with the locals that hold the count for a moment. Seen after: the mage's experience 101, and the spells
  then learnt and cast (Phase Door, Light Area), all 17 sections the same; regression.ps1 is 36 comparisons.
  Also the same as Umoria's that night: a summoned monster (the wizard's ^u) killed by two Magic Missiles and three
  blows, and the level that brought the mage. With both faults put right, the whole of regression.ps1, 36
  comparisons, 612 sections, the same as Umoria's (17 October, about 00:05 to 01:05). And then the stores' stock
  turning over at turn 1,000 on a dungeon level, never compared till now (the long rests on level 5 are broken off
  by a monster before turn 250): level 1, the wizard's mass genocide, 1,100 turns of rest, all 17 sections, the six
  stores with them, the same: regression.ps1 is 37 comparisons. Then an unknown wand on level 7, walked to, picked
  up and aimed (the kind marked tried), and a priest taken to level 5 and given five prayers at random by G (the same
  five, in the same order): 39 comparisons. And the town at night, never compared till now: 5,000 turns of rest on
  level 1, then the wizard's ^d to the town, made in the dark at turn 5,002, all 17 sections the same: 40.

- 16 October, night, **a signed halving rounded the wrong way.** Comparing the wizard's teleport on level 1
  (compare-level.ps1 can type Ctrl keys now, ^ and the letter) put the player a square up and left of Umoria's,
  with the dice in step. Moria brings the random spot nearer by halving the gap, (py.pos.y - location.y) / 2, and C
  halves towards nought, where Boriel turns a signed / 2 into a shift, sra, which halves downwards (its normal,
  faster way, documented, not a fault): -3 / 2 is -1 in C and -2 here. Boriel's division by anything else goes
  through __DIVI16, which works on the size and puts the sign back, as C does, so only / 2, / 4 and so on are
  different. Every such halving in src\ was looked at (30 of them): fsw_c_half() in stage-include.bas halves as C
  does, used where the number can be below nought: the teleport, a confused player's chance with a wand or staff
  (stage-lib-devices.bas), and the spells allowed and mana of a caster drained below their first spell's level
  (stage-lib-magic.bas, where Moria makes them forget as many spells as the count is below nought). The rest are
  never negative. Seen after: the teleport the same as Umoria's, and the walk from there to the up staircase and up
  into the town, 54 steps, all 17 sections the same; regression.ps1 is 32 comparisons now.
  The regression run before it, all 30 comparisons, 510 sections, the same as Umoria's (22:00 to 22:55).

- 12 October 2026: **CHR was overwriting the paged data.** The compiler's own routine for Chr() keeps a value,
  while it works, in the ZX Spectrum system variable DEST at address $5C4D. On our machine that address is 7,245
  bytes into whatever page is in the third data slot, so every Chr() anywhere, and the core's fs_core_text_at()
  used one for every character of every name, wrote two bytes of rubbish there: into spare bytes of one square of
  the map, into one creature's or object's record in the databases, into the text of a spell's name, and, in the
  page of what the player knows, into the "identified" flags of two kinds of potion. It was found by a spell name
  that came out as "S..se Surroundings". Nothing uses Chr() now, fs_core_char() in the core does its job without
  touching anything, and build.ps1 refuses a module that uses it. The compiler's routines were looked through for
  anything else of the kind: the only other is its error exit (out of memory, say), which sets ERR_NR at $5C3A
  and does RST 8, and that is only reached when the game has already gone wrong.
  Seen in a test: the page compared with its file before and after, and the name read correctly.

## Soak tests

- 12 October 2026, evening: a superhuman warrior, wizard mode, 9 minutes of random actions on each of levels 3,
  12, 25 and 40 (steps, runs, searches, teleports, summons, doors, tunnelling, lists, the map, random items):
  1,747 actions, 65 kills, 205 different messages, no crash, no hang, nothing stuck. The heap's biggest free
  block went up and down between 325 and 608 bytes and its free total stayed at 1,002 to 1,007 of 1,020; the
  stack never used more than 347 of its 3,070 bytes.

- 12 October 2026, later: a superhuman mage who knows every spell, 15 minutes on each of levels 5, 15, 30 and 45,
  doing a wider set of things at random and answering whatever was asked at random: 3,180 actions (1,271 steps,
  250 spells, 191 runs, 136 quaffs, 117 reads, 112 throws, 103 staffs, 101 wands, 92 bashes, eating, dropping,
  disarming, tunnelling, looking, taking off, wearing, summoning, teleporting, the map), 441 different messages,
  no crash, no hang, nothing stuck. Heap free 1,000 to 1,007 of 1,020 throughout, biggest block 447 to 560; the
  stack never used more than 338 bytes. By the end the character had used up or dropped everything it carried.

- 13 October 2026, just after midnight: a superhuman priest who knows every prayer, with the rogue like keys on,
  13 minutes on each of levels 8, 20, 35 and 49, on the build with the character printing in Z80 and
  s_core_clear_row(): 2,489 actions (1,058 steps, 177 prayers, 151 runs, 99 reads, 92 quaffs, bashes, wands,
  staffs, throws, tunnelling with Ctrl and a direction, summoning with &), 433 different messages, no crash, no
  hang, nothing stuck. Heap free 1,007 to 1,015 of 1,020, the stack never used more than 363 bytes. The first
  level was left for the town by a prayer of recall, as it should be.

- 13 October 2026, towards 6 in the morning, on the build that build.ps1 itself made at 04:55 with everything
  above in it: a superhuman ranger with the original keys, 13 minutes on each of levels 2, 18 and 33: 1,912
  actions (777 steps, 164 spells, 129 runs and the rest), 327 different messages, no crash, no hang. Heap free
  1,009 to 1,015 of 1,020, the stack never used more than 339 bytes. The character recalled itself to the town
  three times and at the end had walked into a store, where some 200 random keys did no harm; the test could
  not get it out again to go to level 48, which is the test's limit, not the game's.
- 13 October 2026, afternoon, two hours on the build of 14:53 (the one with the folder's new name and nothing else
  changed): a superhuman rogue with the original keys, 14 minutes on each of levels 3, 11 and 43, then a superhuman
  mage with the rogue like keys, 14 minutes on each of levels 9, 19, 36 and 47. 4,286 actions in all (1,698
  steps, 325 spells, 254 runs, 196 reads, 165 quaffs and the rest), 309 and 476 different messages, no crash, no
  hang, nothing stuck. Heap free 1,010 to 1,015 of 1,020 for the rogue, and for the mage the same but for one
  reading of 919; the stack never used more than 369 bytes.
  New in the test: when a word of recall, a trap door or the like takes the character off the level being
  tested they are brought back to it, ten times in these two runs, so the time is no longer spent in the town.
  The rogue's level 27 was missed, and that was the test: "Welcome to level 40." came up just as it asked for
  the level, and took its keys.
## Changes of page

- 13 October 2026: the live monitor now also counts what the third data slot's changes of page were for (far left
  of its panel: map, creatures, objects, tables, strings, knowledge, other). A soak of 854 turns gave 70,274
  changes in that slot: 65% to fetch a map page, 22% creatures, 6% strings, 3% objects, 2% tables, 2% knowledge.
  Every other kind of page pushes the map out, so about half of the map's own count was the map coming back.
- So the creatures database is now read through the second data slot (MMU 1, with the items) and not the third:
  a monster's record, its creature and the map are all there at once during the monsters' turn. Measured on the
  same level made from the same seed with the same keys: the third slot went from 86 changes a turn to 45, the
  second from 17 to 34 (creatures and items now take turns there), 104 down to 79 in all, about a quarter fewer.
  Every library that reads a creature puts the second slot back as it found it.
- The table of how many creatures there are of each level (82 bytes) moved from the creatures' last page into
  the core data page, so it is never paged. A save holds that page, so the save's version number went up to 2:
  **a game saved before this is no longer accepted.**
- Not done, and why: moving the objects database (3% of the changes, and the first slot is where the monster
  list is worked on in place), and the town and dungeon in different slots (every address would then depend on
  which one the player is in). Strings (6%) could share the second slot with the creatures; not yet measured.
- The player's @ is bright green and the stairs are bright magenta (ours, Moria has no colours).
## Speed

- 13 October 2026: a way of timing a turn. A level 30 made from a fixed seed, all 33 of its monsters woken, the
  player walled in with granite and paralysed, so that some 290 turns run one after another with nothing to
  wait for; the wall clock is read as the turn count goes up. Two runs of the same build agree to 0.1 ms.
- With that: fuw_core_map_square() and fuw_core_record_address() written in Z80 in place of compiled BASIC, the
  same names, parameters and answers, took a turn from 50.7 ms to 43.0 ms, 15% quicker. (s_core_print_char_at()
  had already been done the day before, with s_core_clear_row().)
- Then s_core_swap_paged_data(), which those two call: 43.0 ms to 40.0 ms, another 7%. From 50.7 ms to 40.0 ms in
  all, a turn takes a fifth less time than it did. The monitor's counts were checked afterwards: the seven kinds
  of page add up to the third slot's misses exactly.
- **The log of routines rewritten for speed.** Each keeps its name, its parameters and its answer, so nothing that
  calls it changed; each reads its parameters straight from IX. Add to this list whenever another is done.

  | Routine (all in core.bas) | What it does | Done | Was BASIC? | Measured |
  |---|---|---|---|---|
  | `s_core_print_char_at` | one character and its colour into one screen cell | 12 Oct 2026 | BASIC wrapper round an asm body | not timed |
  | `s_core_clear_row` | spaces from a column to the end of a row, one LDIR | 12 Oct 2026 | new, in place of 80 calls a row | not timed |
  | `fuw_core_map_square` | pages in a map square and gives its address | 13 Oct 2026 | compiled BASIC | with the next: 50.7 to 43.0 ms a turn |
  | `fuw_core_record_address` | pages in a 64 byte record and gives its address | 13 Oct 2026 | compiled BASIC | with the one above |
  | `s_core_swap_paged_data` | puts a page into a data slot, and keeps the counts | 13 Oct 2026 | compiled BASIC | 43.0 to 40.0 ms a turn |

  Converted to FASTCALL: none yet.
  Written in assembler from the start, and so not in the list: s_core_next_reg(), s_core_clear_screen(), the copy
  in s_core_ram_copy(), the random number generator's multiply and its division, and the file routines' calls.
- Decided on 13 October 2026, not to do: FASTCALL for the core's routines of one parameter. It was expected to be
  worth less than either step above, for a change to how many routines are called; it was never measured.

## Room in the pages

- The map routines (what a square shows, drawing one, drawing the window, lighting a room, moving the window)
  and the message line routines are in the core now, one copy of each, where thirteen and thirty-four pages
  each had their own. A page still calls them by the names it always did, the two include files are now only
  the way through the jump table. The same for the eleven identical "call a library" wrappers and the nineteen
  random number wrappers. The walking stage went from 7,805 bytes to 6,050, monster moves from 7,364 to 6,166.
  The core went from 12,592 to 14,917 of its 15,805, so the live monitor was then moved out of it into a library
  of its own (stage-lib-monitor.bas, page 161), which brought the core back to about 13,200.
  It also puts right a small unfaithfulness: the monster spells page used to draw without hallucination,
  for want of room, every page draws through the one routine now.
  Seen in a test: a walk through a dungeon level, fights, messages.
- The character library was split in two: the character sheet and the block down the left of the screen are
  stage-lib-character-2.bas (page 162) now, the first half passes them on by the same numbers. It had 126 bytes
  left, the two halves are 2,404 and 5,306. Seen in a test: making a character, the block, and the sheet.

- Messages can now be kept out of the pages of code: a message that is the same every time is listed in
  src\messages.txt, goes into the strings database, and is shown with s_core_message( UW_MSG_... ), a core
  routine. The walking stage's ten were moved first, which took it from 8,093 bytes to 7,413 of its 8,192.
  The same was then done for traps (7,663 to 6,487), consume (7,582 to 7,052), player attack (7,599 to 7,304),
  books (7,489 to 7,252), monster spells (7,658 to 7,597), and the combat and fight includes that several pages
  share (fight and throw each lost 172): 79 messages in all, strings 316 to 394. The character library had none
  to move, its text is labels, not messages. The strings database now has six pages for its text, 57 to 62,
  one in use.
  Then every other page: 255 more messages, 650 strings in all now, in two of the six pages of text. And a
  second core routine, s_core_message_after( where a name is , UW_MSG_... ), shows a message with a name in
  front of it, "The Kobold " and then "hits you.", which the monster attack and monster spells libraries use
  (monster attack 6,761 to 5251, monster spells 7,597 to 6991).
  Seen in tests: trap messages, and a fight, both kinds of message. Not tested: each moved message one by one.
  Still to do, if more room is wanted: messages handed to a routine as a parameter (the consume library's
  "You feel..." texts are), and labels and questions printed with s_core_print_string_at().
  The three messages with a number in them are left as they are.

As of the morning of 12 October there are 59 pages of code: 10 stages and 49 libraries, pages 96 to 157 (103 to
105 are unused). The next free code page is 158. A library may be 7,680 bytes, a stage 8,192, the core 15,805.

Full, or as good as: the traps library (7,663), the monster spells library (7,658), the player attack library
(7,599), the consume library (7,582), the character library (7,554), the books library (7,489). The walking
stage is at 7,791 of 8,192. Anything new for those needs a page of its own, as was done for the monster moves, the commands
and the recall paragraph, each of which is now two pages that share their working storage in the core's data.
The core is at 11,224.

Core data: the sixteen bytes after the working map square (584 to 599) and the bytes from 6,912 to 6,999 are now
in use, for a monster's move, the repeat count, the message being shown and the marks of a saved game. A_GAME is
full. Byte 7,000 is the step limit of a counted run. What is left is 7,001 to 7,167.
