# the comparisons with the real Umoria that have passed, run again one after another: each is compare-level.ps1 with its
# parameters, and at the end how many sections of each came out the same, N.B: every case passing is the aim, any
# DIFFERENT is a fault in ZXMoria (or, now and then, see not-yet.md, the 01:09 run: run it again before relying on it)
# -Nex the ZXMoria nex file built with the same seed (UL_GAME_FIXED_SEED 12345), or -Workspace to build one first with
#   seeded-build.ps1 in that second workspace
# -Out a file the whole of it goes into as well, -Only a pattern to run some of the cases, e.g. -Only 'Level 5'
# N.B: the emulator may keep the keyboard, run it with nobody at the machine, it takes about 25 minutes
param([string]$Nex, [string]$Workspace, [string]$Out = '', [string]$Only = '')
if(-not $Nex){
    if(-not $Workspace){ throw 'give -Nex, a seeded build, or -Workspace, to make one' }
    $Nex = & "$PSScriptRoot\seeded-build.ps1" -Seed 12345 -Workspace $Workspace
}
# the walk from where the character stands in the town of seed 12345 into the Alchemist (store 5), found by walking it
# in ZXMoria on 16 October 2026 (Find-Way in play-lib.ps1)
$walk = '71444111111111'
# ...and from there on to the town's down staircase, and the escapes that give ZXMoria time to make the new level (an
# ESCAPE at the command prompt takes no turn in either game)
$stairs = '7144477777774'; $pause = '~' * 12
# ...and 18 rests, each waited out (\) and its -more-s answered, for the starving case below
$starve = 'R100|\~~~' * 18
# ...and for turning undead: a priest made level 40 (999 experience, then the wizard's + doubles it 13 times), the third
# prayer book made by @ and picked up, every prayer gained (G, the -more-s answered), and the walk (find-path.py) to 4
# squares from a Skeleton Orc
$turnUndead = '#999+~' + ('+~' * 13) + '@ 91|?|66|30|1|1|1|0|0|0|0|0|1FF0000|400|40|y~~4~6~~G' + ('~' * 30) + '99669888888o88o9966666666666666999333~'
$cases = @(
    # 16 October, the first ten: the town, rests, searching, walking (east; south and north), search mode and a fight
    '',
    '-Level 5 -Rest 130',
    '-Level 5 -Rest 1000',
    '-Level 30 -Rest 300',
    '-Level 50 -Rest 300',
    '-Level 5 -Keys s',
    "-Level 5 -Keys '66666666'",
    "-Level 50 -Keys '22228888'",
    "-Level 5 -First S -Keys '#999s' -Wait 40",
    "-Level 5 -Rest 1000 -Keys '555555554~4~4~4~4~4~4~4~4~4~'",
    # 16 October, eating: a ration, three (bloated), and three then 200 turns of rest
    "-Keys 'Ea~'",
    "-Keys 'Ea~Ea~Ea~'",
    "-First 'Ea~Ea~Ea~' -Rest 200",
    # 16 October, the walk to the Alchemist and a Potion of Slow Poison bought, then drunk, then 50 turns of rest
    "-Keys '${walk}pa58|~~'",
    "-Keys '${walk}pa58|~~qb~'",
    "-First '${walk}pa58|~~qb~' -Rest 50",
    # 16 October, Scrolls of Phase Door and of Light bought and read
    "-Keys '${walk}pj35|~pi35|~~rb~rb~'",
    # 16 October, down the town's stairs to a new level 1, and 100 turns of rest there
    "-Keys '${stairs}>$pause'",
    "-First '${stairs}>$pause' -Rest 100",
    # 16 October, a mage: G and Magic Missile (a) learnt, cast east into the town, and 50 turns of rest after
    "-Class 1 -Keys 'Ga~'",
    "-Class 1 -Keys 'Ga~maa6~'",
    "-Class 1 -First 'Ga~maa6~' -Rest 50",
    # 16 October, a priest: G and a prayer given at random (Bless, c, for this seed), recited, and 50 turns of rest after
    "-Class 2 -Keys 'G~'",
    "-Class 2 -Keys 'G~pac~'",
    "-Class 2 -First 'G~pac~' -Rest 50",
    # 16 October, level 10: walks planned by find-path.py on the level's map to an unknown potion and an unknown scroll
    # (two doors opened on the way), each picked up by stepping onto it, and drunk or read, and so learnt
    "-Level 10 -Keys '774444444441144122222321444444478744444~qb~'",
    "-Level 10 -Keys '99669888888o88o9966666666666666999966666~rb~'",
    # 16 October, the starting kit worn: the armour, then all three (each next one comes up to b), and the armour put
    # on and taken off again
    "-Keys 'wb~'",
    "-Keys 'wb~wb~wb~'",
    "-Keys 'wb~ta~'",
    # 16 October, night, ^ and a letter for Ctrl: the wizard's teleport on level 1 (it found fsw_c_half()'s fault), and
    # from where it lands a walk planned by find-path.py to the up staircase, and up into the town
    "-Level 1 -Keys '^t~'",
    "-Level 1 -Keys '^t~999333333223321444444444444444144444444447789888888798<~~~~~~~~~~~~'",
    # 16 October, night, a mage on level 1: Magic Missile learnt, the wizard's summons (^u) puts a monster to the east,
    # two missiles and three blows kill it, and the experience takes the mage up a level (hit points and mana again)
    "-Class 1 -Level 1 -Keys 'Ga~^u~'",
    "-Class 1 -Level 1 -Keys 'Ga~^u~maa6~maa6~6~6~6~'",
    # 16 October, night, the wizard's + with a count of 300 (it found the count kept in a byte): the mage at level 5,
    # G and spells learnt, then Phase Door and Light Area cast
    "-Class 1 -Level 1 -Keys '#300+~Gagcb~'",
    "-Class 1 -Level 1 -Keys '#300+~Gagcb~mac~mad~'",
    # 17 October, the stores' stock turned over at turn 1,000 on a dungeon level: level 1, the wizard's mass genocide
    # (^f) so that nothing breaks the rest off, and 1,100 turns of rest (the rests on level 5 are broken off by turn 230)
    "-Level 1 -First '^f~' -Rest 1100",
    # 17 October, level 7: a wand walked to (find-path.py), picked up, and aimed east while it is still unknown
    "-Level 7 -Keys '99669888888o88o9966666666666666999966666~ab6~'",
    # 17 October, a priest taken to level 5 by the wizard's + and given five prayers at random by G, each with its
    # message, hence the escapes
    "-Class 2 -Level 1 -Keys '#300+~G~~~~~~'",
    # 17 October, the town at night (turns 5,000 to 9,999): 5,000 turns of rest on level 1 after the mass genocide, then
    # the wizard's ^d to level 0, which makes the town in the dark, N.B: this one takes about ten minutes
    "-Level 1 -First '^f~' -Rest 5000 -Keys '^d0|~~~~~~~~~~~~'",
    # 17 October, a ball spell: a level 5 mage learns Stinking Cloud first (g), and kills a summoned monster with it
    "-Class 1 -Level 1 -Keys '#300+~Ggaaa~~^u~mag6~mag6~'",
    # 17 October, a known wand: the level 7 wand identified by the wizard's ^i, then aimed
    "-Level 7 -Keys '99669888888o88o9966666666666666999966666~^ib~ab6~'",
    # 17 October, a priest walking into the Magic Shop and straight out (it found the store turn's fault), and, made
    # rich by the wizard's ^e, buying a Staff of Light there (at its asking price, an offer of more is not understood)
    # and using it
    "-Class 2 -Keys '6322222133333222214447~'",
    "-Class 2 -Keys '^w y ^e||||||||5000|~6322222133333222214447pj1193|~~uc~'",
    # 17 October, a prayer at a monster: the priest buys the third book at the Temple, is taken past level 15 by the
    # wizard's + (four times), learns his prayers at random, Orb of Draining among them, and prays it twice at a
    # summoned monster
    "-Class 2 -Keys '^w y ^e||||||||5000|~744411111114444444777111111111pb769|~~#999+~+~+~+~G~~~~~~~~~~~~~~~~~~~~^u~pbb6~pbb6~'",
    # 17 October, a bolt: a mage buys the second book at the Magic Shop, learns Lightning Bolt first (i), and kills a
    # summoned monster with it
    "-Class 1 -Keys '999996333366633333333333366666666666999336666669pa212|~~^w y #300+~Giaaa~~^u~mbb2~'",
    # from 17 October each new comparison has a race and class of its own (-Class is the place in the race's own list)
    # a trap: a Dwarf warrior on level 2 walks onto one
    "-Race 5 -Class 0 -Level 2 -Keys '4444444444444444444444444444444444477778888999996999888o996666666669888889698996~~~'",
    # a locked door: a Half-Orc rogue, put near it by the wizard's ^t, picks it
    "-Race 6 -Class 2 -Level 1 -Keys '^t~999333333223321123323632222o3~o3~o3~o3~o3~o3~o3~o3~3~'",
    # a stuck door: the same rogue tries it and bashes it (B)
    "-Race 6 -Class 2 -Level 1 -Keys '^t~999333333223323669966632222222223666666323666632223666322214444414444444444444417771111o1~B1~B1~B1~B1~B1~B1~B1~B1~1~'",
    # a secret door: a Gnome mage, the monsters in sight vanquished (^f) and a torch wielded (there is a tenth of the
    # chance in the dark), searches 40 times, one key a turn (a key typed during a count breaks it off, see
    # compare-level.ps1), finds it, opens it and steps in
    "-Race 4 -Class 1 -Level 1 -Keys '89999888887^f~we~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~s~o9~9~'",
    # throwing (f in the original keys, t is take off): a Halfling rogue summons a Green Jelly (^u) on the square north
    # of him, steps back one, backs out of the throw twice (f~ at the item, fd~ at the direction, each a free turn, it
    # found that ours took one), then throws the stiletto at it (missing, it lies short), two torches (hitting, the
    # jelly cannot move) and one west, landing short of a sleeping monster
    "-Race 3 -Class 2 -Level 1 -Keys '^u~2f~fd~fd8~~fd8~~fd8~~fd4~~'",
    # digging: a Half-Troll priest wields the stiletto and tunnels with a count of 30 at the secret door east of him, in
    # the dark (it found that a count given to a command that asks which way went round once, and then stopped at the
    # -more- after two messages); then, with a torch wielded too, finds the door by tunnelling at it, can't tunnel
    # through it once found (a free turn), opens it and the door beyond, crosses the room and digs through the magma
    # east of it with a count of 999 (it breaks through, and the count ends at the empty air beyond)
    "-Race 7 -Class 1 -Level 1 -Keys 'wd~#30T6' -Wait 40",
    "-Race 7 -Class 1 -Level 1 -Keys 'wd~wd~T6~T6~T6~o6~6~6~o8~8~8~8~999666666#999T6' -Wait 150",
    # selling: an Elf ranger walks into the Weaponsmith and sells the stiletto, asking the 1 gold piece offered
    # N.B: and again, backing out of "Which one?" first ('999999666666666666666666663333s~sd~1|~~~~'), which in Moria
    # makes the turn he stepped in on free, was a case here until 22 October, when ours took that turn after all
    # (sdo's decision, see umoria-oddities.md): it now comes out a turn ahead of Umoria, as it should
    "-Race 2 -Class 4 -Keys '999999666666666666666666663333sd~1|~~~~'",
    # Word of Recall: a Half-Elf paladin, made rich by the wizard's ^e, buys a scroll at the Alchemist, wields a torch
    # (no scroll is read without light) and reads it: on level 5, and is taken up to the town; in the town, never having
    # been deeper, the townspeople vanquished (^f) so that the rest goes on, and the town is made again; and in the town
    # after a visit to level 5 (^d5, ^d0), and is taken down to it; each rests until it comes, -After answers the -more-
    "-Race 1 -Class 5 -Keys '^w y ^e||||||||5000|~711111111113222221pc322|~~^d5|~~~~~~~~~~~~wf~rc~R99|' -Wait 60 -After '~~'",
    "-Race 1 -Class 5 -Keys '^w y ^e||||||||5000|~711111111113222221pc322|~~wf~^f~rc~R99|' -Wait 60 -After '~~'",
    "-Race 1 -Class 5 -Keys '^w y ^e||||||||5000|~711111111113222221pc322|~~^d5|~~~~~~~~~~~~^d0|~~~~~~~~~~~~wf~rc~R99|' -Wait 60 -After '~~'",
    # spikes: a Dwarf priest walks round the Armoury's door (find-path.py would walk through it) into the General Store,
    # buys 14 iron spikes, goes to level 1 (^d1), jams the door below the room with three of them (j), tries to open it
    # twice and bashes it three times
    "-Race 5 -Class 1 -Keys '444444444444444444444444444448888884pg28|~~^w y ^d1|~~~~~~~~~~~~111444j2~j2~j2~o2~o2~B2~B2~B2~'",
    # breeding: a Human warrior rests on level 1 until a Giant White Mouse 11 squares off wakes (turn 637) and
    # comes to him, then searches, one key a turn, while it breeds round him: 8 turns (5 mice) and 14 (7 mice);
    # 40 turns kill him, in both games, and Umoria's save of a dead character holds no level to compare
    "-Race 0 -Class 0 -Level 1 -Rest 1000 -Keys 's~s~s~s~s~s~s~s~'",
    "-Race 0 -Class 0 -Level 1 -Rest 1000 -Keys 's~s~s~s~s~s~s~s~s~s~s~s~s~s~'",
    # a monster opening a door: a Half-Elf warrior on level 5 steps through the open door north of him, closes it
    # behind him (c2), walks two squares up the corridor and rests; a Novice Priest wakes and the rest ends (turn
    # 339), then he searches, one key a turn: 8 turns, the priest on his way and the door still shut; 14 turns, the
    # priest has opened it and stands in the doorway (turn 353); 30 turns kill him, in both games
    "-Race 1 -Class 0 -Level 5 -Keys '996698c2~88R500|' -Wait 60 -After '~s~s~s~s~s~s~s~s~'",
    "-Race 1 -Class 0 -Level 5 -Keys '996698c2~88R500|' -Wait 60 -After '~s~s~s~s~s~s~s~s~s~s~s~s~s~s~'",
    # a thief and a broken rest: a Half-Troll warrior on level 4 walks into the corridor of a Scruffy-Looking Hobbit,
    # drops his armour and cloak there (meant for the hobbit to pick up, it never walks over them), steps back into the
    # room and rests; the hobbit hits him and steals his gold, breaking the rest, vanishes in a puff of smoke, comes
    # back and steals again while he searches (it found that a rest broken by a monster waited at -more- after the
    # monster's messages, which Moria never does, and the key that answered it was a turn lost)
    "-Race 7 -Class 0 -Level 4 -Keys '7~7~8~9~9~9~6~db~4~db~1~1~2~2~R999|' -Wait 90 -After '~s~s~s~s~s~s~s~s~s~s~'",
    # experience drained: a Gnome Mage on level 16 is given 999 experience by the wizard's + (a count of 999, Umoria
    # takes no more digits once past 99), climbs to level 6, walks to the side of a sleeping Grape Jelly in a corridor
    # and rests until it wakes; its touches drain the mage back to 4 experience, and the hit points go with the levels lost
    "-Race 4 -Class 1 -Level 16 -Keys '#999+~2~2~2~2~2~2~2~2~2~2~1~7~4~R999|' -Wait 120 -After '~s~s~s~s~s~s~s~s~'",
    # a slaying weapon: a Human paladin on level 1 has the wizard's @ make a sword (category 23) of 2d5 that slays animals
    # and evil (flags C000; the space answers the -more- after its warning, the escapes the messages after), steps off it
    # and back on to pick it up, wields it and summons a monster (^u), a Poltergeist, evil and undead but no animal, north
    # of him; one blow, doubled for evil, kills it, and the monster memory learns that it is evil (defenses 0004)
    "-Race 0 -Class 5 -Level 1 -Keys '@ 23|/|6|100|1|2|5|0|0|0|0|0|C000|1000|1|y~~6~4~~we~~^u~~8~8~8~8~' -After '~~'",
    # firing: a Human ranger has the wizard's @ make a long bow (category 20, P1 3, the x3 multiplier) and 20 arrows
    # (category 12, 1d4), picks each up, wields the bow, summons a Scruffy-Looking Hobbit (^u) beside him and fires four
    # arrows at it (f, the arrows, 9): two hits, the hobbit hits back, dies, the last arrow flies on and is lost; it found
    # that ours never put "You are wielding ..." and the other equipment messages into the history
    "-Race 0 -Class 4 -Level 1 -Keys '@ 20|}|2|40|1|0|0|0|0|0|0|3|0|120|1|y~~6~4~~@ 12|{|193|2|20|1|4|0|0|0|0|0|0|1|1|y~~6~4~~we~~^u~~ff9~~ff9~~ff9~~ff9~~' -After '~~'",
    # a wand striking: a Half-Orc priest on level 8, taken to level 5 by the wizard's +, has @ make a wand of 10 charges
    # whose flags (40E02) are five effects at once, as Moria runs every bit: lightning bolt, confuse, sleep, drain life
    # and lightning ball; a summoned Yellow Jelly beside him (57 hit points) takes the bolt, is unaffected by confusion
    # and sleep, dies of the drain, the ball envelops another creature, and the memory learns the jelly's defenses
    "-Race 6 -Class 1 -Level 8 -Keys '#300+~@ 65|-|1|10|1|1|1|0|0|0|0|10|40E02|1|1|y~~6~4~~^u~~ac9~~~ac9~~~ac9~~~ac9~~~' -After '~~'",
    # traps: a Halfling warrior on level 7 has the wizard's @ make a Scroll of Trap Creation and reads it, which puts a
    # trap on each of the eight squares round him, then steps on one: the confusion gas (2), the falling rock (3), the
    # slowing dart (1, two messages on one line) and the loose rock with something under it (9); on 21 October all
    # eight were tried, the fire, acid, strength and constitution darts as well, every section the same
    "-Race 3 -Class 0 -Level 7 -Keys '@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~2~~' -After '~~'",
    "-Race 3 -Class 0 -Level 7 -Keys '@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~3~~' -After '~~'",
    "-Race 3 -Class 0 -Level 7 -Keys '@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~1~~' -After '~~'",
    "-Race 3 -Class 0 -Level 7 -Keys '@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~9~~' -After '~~'",
    # more traps from the same scroll, after searching first, which moves the random numbers on and so makes another
    # eight: the summoning rune (three searches, 3: a centipede, a gnome and a skeleton come and attack), the trap door
    # (three searches, 7: down to a new level 8, made the same in both) and the teleport rune (four searches, 7); N.B: a
    # covered pit (one search, 6) is the same but for the numbers of the things on the map, see umoria-oddities.md
    "-Race 3 -Class 0 -Level 7 -Keys 's~s~s~@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~3~~' -After '~~'",
    "-Race 3 -Class 0 -Level 7 -Keys 's~s~s~@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~7~~' -After '~~~~~~~~~~~~'",
    "-Race 3 -Class 0 -Level 7 -Keys 's~s~s~s~@ 70|?|85|5|1|0|0|0|0|0|0|0|200000|0|1|y~~6~4~~rb~~7~~' -After '~~'",
    # bashing with a shield on: a Half-Orc warrior on level 4 has the wizard's @ make a large leather shield (category
    # 34, 1d2, 100 in weight) and wears it, summons a Giant House Fly beside him and bashes it three times (B4): stunned,
    # off balance, the fly recovers, then slain, and the last bash at empty space; and again afraid, after a Mushroom of
    # Paranoia made by @ (category 80, flags 4): "You are afraid!" and no bash, then empty space, the fly having moved
    "-Race 6 -Class 0 -Level 4 -Keys '@ 34|)|3|100|1|1|2|0|0|4|0|0|0|15|1|y~~6~4~~wc~~^u~~B4~~B4~~B4~~' -After '~~'",
    "-Race 6 -Class 0 -Level 4 -Keys '@ 34|)|3|100|1|1|2|0|0|4|0|0|0|15|1|y~~6~4~~wc~~@ 80|,|66|1|1|0|0|0|0|0|0|500|4|0|1|y~~6~4~~Eb~~^u~~B6~~B6~~' -After '~~'",
    # the order of the slays: a sword with every slay and brand (flags 7E000); the paladin's Poltergeist, evil and
    # undead, is slain as undead (x3, the memory learns 0008, not the evil of the case above), and the Half-Orc
    # warrior's Giant House Fly, an animal that fire and poison also hurt, as an animal (x2, before the brands, 0002)
    "-Race 0 -Class 5 -Level 1 -Keys '@ 23|/|6|100|1|2|5|0|0|0|0|0|7E000|1000|1|y~~6~4~~we~~^u~~8~8~8~8~' -After '~~'",
    "-Race 6 -Class 0 -Level 4 -Keys '@ 23|/|6|100|1|2|5|0|0|0|0|0|7E000|1000|1|y~~6~4~~we~~^u~~4~~4~~4~~4~~' -After '~~'",
    # a brand alone (22 October): a Dwarf warrior on level 6 with a sword of fire (flags 40000) and nothing else, the
    # summoned Yellow Worm mass west of him, hurt by fire: two hits of half as much again kill it, and the monster
    # memory learns that fire hurts it (0020)
    "-Race 5 -Class 0 -Level 6 -Keys '@ 23|/|6|100|1|2|5|0|0|0|0|0|40000|1000|1|y~~6~4~~we~~^u~~4~~4~~4~~4~~' -After '~~'",
    # slay dragon (22 October): a Halfling warrior on level 40, made level 40 (999 experience doubled 13 times), has the
    # wizard's @ make a 9d9 sword that slays dragons (flags 2000), steps north and back for it, wields it, walks 11
    # steps (find-path.py) to a sleeping Young Red Dragon and strikes it: a Disenchanter Bat joins in, the dragon
    # breathes fire and dies of the second hit at four times the damage, the memory learning that it is a dragon (0001)
    "-Race 3 -Class 0 -Level 40 -Keys '#999+~$('+~' * 13)@ 23|/|6|100|1|9|9|0|0|0|0|0|2000|1000|1|y~~8~2~~we~~87777888778$('9~~' * 8)' -After '~~'",
    # ...and the frost brand (flags 20000): the summons were never hurt by cold, so a Half-Elf warrior in the town,
    # wizard mode on by ^W, walks up to a sleeping Pitiful-Looking Beggar (hurt by cold, as most townspeople are) and
    # slays it, and the memory learns 0010
    "-Race 1 -Class 0 -Keys '^w y @ 23|/|6|100|1|2|5|0|0|0|0|0|20000|1000|1|y~~6~4~~we~~888~7~~7~~7~~' -After '~~'",
    # running out of charges: a Half-Elf priest on level 1 has the wizard's @ make a Wand of Magic Missile and a Staff of
    # Light of one charge each, and uses each twice: "You have 0 charges remaining.", then "The wand has no charges
    # left." and the same for the staff
    "-Race 1 -Class 2 -Level 1 -Keys '@ 65|-|13|10|1|1|1|0|0|0|0|1|2000|1|1|y~~6~4~~@ 55|_|0|50|1|1|2|0|0|0|0|1|1|1|1|y~~6~4~~ac6~~ac6~~ud~~ud~~' -After '~~'",
    # the staffs that had always failed: a Gnome warrior on level 3, made tough by the wizard's + (four times), has @
    # make a staff of level 1 with five charges whose flags (4C0000) are mass polymorph, remove curse and dispel evil,
    # summons a monster and uses the staff three times: the monster shudders into a Skeleton 2-Headed Troll, which and
    # a Xorn then fight him; without the +, both games kill him the same way (a Xorn), but a dead character's save has
    # no level to compare
    "-Race 4 -Class 0 -Level 3 -Keys '#999+~+~+~+~@ 55|_|17|50|1|1|2|0|0|0|0|5|4C0000|1|1|y~~6~4~~^u~~ub~~~ub~~~ub~~~' -After '~~'",
    # the other launchers, as the long bow above: an Elf rogue on level 2 with a sling (P1 1, x2) and 20 iron shots
    # (category 10) kills a Grey Mushroom patch, its spores between; a Half-Elf ranger on level 3 with a light crossbow
    # (P1 5, x3) and 20 bolts (category 11) at a Giant House Fly, one hit in four
    "-Race 2 -Class 3 -Level 2 -Keys '@ 20|}|20|5|1|0|0|0|0|0|0|1|0|5|1|y~~6~4~~@ 10|{|194|5|20|1|3|0|0|0|0|0|0|2|1|y~~6~4~~we~~^u~~ff6~~ff6~~ff6~~' -After '~~'",
    "-Race 1 -Class 4 -Level 3 -Keys '@ 20|}|10|110|1|0|0|0|0|0|0|5|0|140|1|y~~6~4~~@ 11|{|193|3|20|1|5|0|0|0|0|0|0|2|1|y~~6~4~~we~~^u~~ff7~~ff7~~ff7~~ff7~~' -After '~~'",
    # filling a lamp: a Human rogue on level 1 fills with no light wielded ("But you are not using a lamp.", it found
    # ours said "You have no oil.", Moria's empty place being object 417, sub category 64), has the wizard's @ make the
    # store's Brass Lantern (sub category 0, the dungeon's, sub 1, can never be filled, see umoria-oddities.md) with
    # 1000 turns, wields it, fills with no oil, has @ make two flasks of oil and fills twice: more than half full, then
    # overflowing and full (the symbol is = as ~ is typed as ESCAPE; two spaces after the first @ for two -more-s)
    "-Race 0 -Class 3 -Level 1 -Keys 'F~~@  15|=|0|50|1|1|1|0|0|0|0|1000|0|35|1|y~~6~4~~we~~F~~@ 77|!|64|10|2|2|6|0|0|0|0|7500|40000|3|1|y~~6~4~~F~~F~~' -After '~~'",
    # running: a Gnome priest on level 3 runs east, south, west, north and east again (. and a direction, 18 turns);
    # and confused, after a Mushroom of Confusion the wizard's @ made (category 80, flags 8): "You feel drugged.", and
    # the same runs
    "-Race 4 -Class 2 -Level 3 -Keys '.6~~.2~~.4~~.8~~.6~~' -After '~~'",
    "-Race 4 -Class 2 -Level 3 -Keys '@ 80|,|67|1|1|0|0|0|0|0|0|500|8|0|1|y~~6~4~~Ec~~.6~~.2~~.4~~.8~~' -After '~~'",
    # running blind: the same, after a Mushroom of Blindness made by @ (category 80, flags 2); it found that ours did not
    # unlight the monsters as the blindness began (Moria's updateMonsters( false )), so a monster beyond its range still
    # had its moves that turn and the random numbers came out a draw apart, whatever the running
    "-Race 4 -Class 2 -Level 3 -Keys '@ 80|,|65|1|1|0|0|0|0|0|0|500|2|0|1|y~~6~4~~Ec~~.6~~.2~~.4~~.8~~' -After '~~'",
    # the other effects that light and unlight the monsters as they begin and end (Moria's updateMonsters( false ), as
    # blindness): a Halfling mage on level 3 drinks a potion the wizard's @ made of detect invisible and infra-vision
    # at once (category 76, flags 4400), two monsters about 12 squares off, and rests 250 turns, both wearing off
    "-Race 3 -Class 1 -Level 3 -Keys '@ 76|!|104|4|1|1|1|0|0|0|0|0|4400|0|1|y~~6~4~~qc~~R250|' -Wait 60 -After '~~'",
    # throwing at something unseen (22 October): a Half-Troll priest on level 2 has the wizard's @ make a Mushroom of
    # Blindness (category 80, flags 2), steps west and back to pick it up, summons a Black Mushroom patch west of him,
    # eats the mushroom and, blind, throws his rations at it four times: "You hear a cry as the Ration of Food finds a
    # mark." for each hit, "It releases a cloud of spores." for its answer
    "-Race 7 -Class 1 -Level 2 -Keys '@ 80|,|65|1|1|0|0|0|0|0|0|500|2|0|1|y~~4~6~~^u~~Ec~~fb4~~fb4~~fb4~~fb4~~' -After '~~'",
    # turning undead (22 October): a Dwarf priest on level 10, made level 40, learns every prayer (Umoria's priests
    # learn at random from all their level allows, book or no book, so only a level that allows them all is sure of
    # Turn Undead), walks up to a Skeleton Orc and prays Turn Undead (the third book, its ninth) twice: "The Skeleton
    # Orc runs frantically!" each time, confused for 40 turns, the memory learning that it is undead (0008)
    "-Race 5 -Class 1 -Level 10 -Keys '${turnUndead}pbi~~~pbi~~~' -After '~~'",
    # starving (22 October): a Human mage on level 1, made tough by the wizard's + (four times), has @ make a Potion of
    # Salt Water (category 76, sub category 96, flags 4) and drinks it: "The potion makes you vomit!", the food down to
    # 150, below fainting; then rests, again and again, as fainting breaks each rest off, until the food is past
    # nothing and starvation has taken 6 of his 63 hit points (food -23, turn 125); N.B: nothing is typed while he lies
    # fainted, Umoria throws away keys typed then and ZXMoria is not reading the keyboard, so the two would part
    # company on the test's timing alone; about 9 minutes
    "-Race 0 -Class 1 -Level 1 -Keys '#999+~+~+~+~@ 76|!|96|4|1|1|1|0|0|0|0|0|4|0|1|y~~6~4~~qc~~$starve' -Wait 8 -After '~'",
    # a deep caster (22 October): a Half-Orc warrior on level 44, made level 40, searches beside an awake Necromancer:
    # it teleports itself away, blinds and paralyses (hold person), comes back and hits, the memory learning those three
    # spells (00000623), the same in both; N.B: hunting a caster that teleports the player to it, none did yet
    "-Race 6 -Class 0 -Level 44 -Keys '#999+~$('+~' * 13)$('s~' * 20)' -After '~~'",
    # dying of starvation (22 October): the starving case above without the +, so the mage's few hit points go, 26 rests;
    # Umoria's save of a dead character holds no level, so only the messages are compared, the last 22, the same in
    # both, Umoria's save saying "killed by starvation"; about 15 minutes
    "-Race 0 -Class 1 -Level 1 -Keys '@ 76|!|96|4|1|1|1|0|0|0|0|0|4|0|1|y~~6~4~~qc~~$('R100|\~~~' * 26)' -Wait 8 -After '~'",
    # deep and long, on the way to a Quasit's teleport-to (not reached yet): an Elf priest on level 19 is taken to level
    # 12 by the wizard's + (four times), clears the monsters round him (^f), walks 92 steps (find-path.py) to 16 squares
    # from a sleeping Quasit and rests twice (\ waits for the first to end); a Killer Black Beetle breaks the second off
    # at turn 1810, and the Quasit sleeps on (204 down to 67); N.B: about ten minutes, Umoria waits 150 seconds twice
    "-Race 2 -Class 2 -Level 19 -Keys '#999+~+~+~+~^f~99698888879988888889966666666666666666666666o669888988o88777774114444444444444444444444444444441~R999|\~~R999|' -Wait 150 -After '~s~s~s~s~s~s~s~s~'"
)
if($Only){ $cases = @($cases | Where-Object { $_ -match $Only }) }
$script:Away = $true
$summary = @()
foreach($case in $cases){
    $head = "=== $(if($case){ $case } else { '(the town)' })  ($(Get-Date -Format HH:mm:ss))"
    $head; if($Out){ Add-Content $Out $head }
    $text = (Invoke-Expression ". '$PSScriptRoot\compare-level.ps1' -Nex '$Nex' $case" 2>&1 | Out-String).TrimEnd()
    $text; if($Out){ Add-Content $Out $text }
    $same = ([regex]::Matches($text, 'the same \(')).Count; $diff = ([regex]::Matches($text, 'DIFFERENT')).Count
    $summary += '{0,3} the same {1,3} different   {2}{3}' -f $same, $diff, $(if($case){ $case } else { '(the town)' }), $(if($text -match 'WRONG BUILD'){ '   WRONG BUILD, run it again' } else { '' })
}
''; '=== summary'; $summary
$all = ($summary | ForEach-Object { [int]($_.Substring(0, 3)) } | Measure-Object -Sum).Sum
$bad = ($summary | ForEach-Object { [int]($_.Substring(13, 3)) } | Measure-Object -Sum).Sum
"$($cases.Count) comparisons, $all sections the same, $bad different"
if($Out){ Add-Content $Out ('', '=== summary') ; Add-Content $Out $summary }
