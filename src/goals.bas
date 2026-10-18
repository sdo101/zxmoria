'##################################################################################################################################
' --- PROJECT GOALS ---
'   name:       ZXmoria
'   what:       create a faithful 100% reproduction and port of the dungeon crawler game Moria/uMoria featuring all aspects of game play, with nothing lost or left out
'               the emphasis here is better than reasonable endeavours, in fact to get as close to best endeavours as possible
'               to achieve a very level of fidelity with umoria game play
'   how:        with AI/LLM help throughout: begun with Google Gemini in early 2026, and continued with Anthropic's Claude Pro (Claude Code) from October 2026.  Amazing!  And thankyou!!
'   which:      uMoria v5.7.15, i.e. not Rogue, not Angband - as, at this time, I don't want any of them in this, this is pure uMoria only
'   who then:   original authors: Robert Alan Koeneke, James E. Wilson, many others, and current maintainer Michael R.Cook.
'   who this:   just someone with fond memories of playing Moria v4.5 running on VAX/VMS
'   when:       this project was started mid-January 2026, struggled with during February 2026, and then left until starting again in October 2026
'   why:        I had always wanted to play Moria on my ZX Spectrum, and whilst that could never happen, it appears to now be feasible on a ZX Next with virtual memory paging
'
'##################################################################################################################################
' --- THE HARD ANGLE ---
' tooling, the high level basics...
'       platform:   ZX Next with minimum 2MB RAM, any of models: KS1 or KS2 or KS3
'       dev:        using VSCode, on Windows 11 Arm64, any hypervisor
'       emulator:   ZEsarUX and associated tooling (CSpect was used at the start)
'       languages:  compiled Boriel ZXBasic v1.19.0 with embedded ASM, stitched into a NEX file by sjasmplus
'
' tooling, the low level detail...
'   all these versions, as at 15-Oct-2026 (onetime-setup.ps1 fixes the tool versions, change them there)...
'   host:
'       hardware:   MacBook Pro M3, macOS 27.0.1, Arm64
'       hypervisor: VMware Fusion 26H1U1, Arm64
'   guest:
'       os:         Windows 11 Pro 25H2 (10.0.26200), Arm64
'       compiler:   Boriel ZX BASIC 1.19.0
'       python:     Python 3.14.7, which runs the compiler and tools\make-sld.py
'       assembler:  sjasmplus 1.24.0
'       emulator:   ZEsarUX 13.0 (09-Jun-2026)
'       card tool:  hdfmonkey 0.5.7, puts files on the card images
'       card flash: balenaEtcher 2.1.7, writes a card image to a real SD card
'       keyboard:   AutoHotkey 2.0.30, runs tools\zesarux-keys.ahk
'       editor:     VSCode 1.142.0
'       shell:      PowerShell 7.6.7
'   emulated ZXNext:
'       emulator:   ZEsarUX 13.0
'                   the card image the emulator boots, the game is tested on this, ZEsarUX 13 does not boot the newer 24.11, see not-yet.md
'       distro:     System/Next 1.3.2
'       os:         NextZXOS 2.06H
'       firmware:   1.29b
'       core:       3.01.05
'   real ZXNext:
'       model:      KS3, 2MB
'       System/Next 24.11, the newest we have, for the KS3's card, check specnext.com for a newer one before it is flashed
'       distro:     System/Next 24.11 (24.06 in its own README)
'       os:         NextZXOS 2.09
'       firmware:   1.44.db
'       core:       3.02.00 (issue 2), 3.02.01 (issue 4)
'##################################################################################################################################
' --- THE SOFT ANGLE ---
' styling...
'   source:     language keywords "Start With Leading Upper Case" and embedded "UpperCase" if syntax keyword is two words stitched together
'   casing:     I like to use "Pascal Casing" for all language keywords and reserved words, and UPPER_CASE with underscores for all constants and defines
'   spacing:    I like loose spacing inside parentheses and routine parameters
'   choice:     I think I would like to code as much as possible in Basic, as long as I can keep heap usage to an absolute minimum, and only code the abolute busiest routines in ASM
'   comments:   all source code comments are to start in lowercase, and be in lowercase unless super pertinent points need hightlighting with leading UpperCase or in extreme cases fully UPPERCASE !
'   math:       no floating-point, no fixed-point, instead only pure integer math, bytes, words, longs
'   un/signed:  all integer data (defines, constants, variables, parameters, data) are to be unsigned unless explicity required to be signed (like anything to do with player stats and combat)
'   ethos:      no in logic hardcoding of any values or addresses whatsoever, all values must "be" or "be dervied from" defined constants or named locations/addresses
'
' the setup and config...
'   hardware:   no ZX ROM, and no interrupt driven code: interrupts stay off (DI) except while we are deliberately waiting for the 50Hz frame interrupt, which is what times every wait...
'               ...that uses interrupt mode 2 with a handler of our own (a single RETI) so that nothing of ours is needed at $0038 for IM1
'   memory:     all 64KB in 8 pages of MMU, with each page being 8KB
'               we take complete control of all 64 KB
'   paging:     some pages are "core" and fixed to specific MMUs and never swapped out, and we will use our own "virtual memory" system to swap/page code and data in and out of other MMUs...
'               ...as built: "paged" data pages are in MMU 0, 1 and 2, one page of paged "stage" code in MMU 3, the core's code in MMU 4 and 5, its data and the heap in MMU 6, the screen and stack in MMU 7...
'               ...a stage never calls another stage, it returns to the core, and the core picks the next stage
'   keyboard:   players may use a PS/2 keyboard or the ZX Next's own keyboard, both are read the same way and every key Moria needs can be typed on either (Extend, i.e. caps shift + symbol shift, is Ctrl)...
'               ...we do not need interrupt based keyboard polling, we wait for keys
'   mouse:      nope
'   sound:      nope
'   screen:     tile map mode 3, giving 80 colums by 32 rows, 2 bytes per screen tile (one byte for ASCII font char, one byte for attributes/palette/colour)
'   graphics:   plain ASCII, plus optional UDG, no sprites, no scrolling graphics on a bit plane, no use of "copper"
'   updates:    we will not be redrawing the screen every time any square/floor of dungeon is updated/changed, e.g. "detect monsters" spell will just update/revert the necessary screen tiles
'   colour:     every single character cell (i.e. screen tile) can independently be one of any of 32 colours (including black on black)
'   font:       8x8 pixels for 256 characters, classic ASCII for char codes 32 to 126, and upper codes 128 to 255 are the mini-map's 128 UDG chars, 16 wide by 8 tall (see FUTURE IDEAS 1, done)
'   text:       I have yet to decide whether to use some of the high order ASCII codes as a text tokeniser for very long strings in the strings DB
'
' game play...
'   game view:  classic Moria, top two lines for messages, stats on the left in 12 columns, 2 column gutter, right hand side viewport of 66 columns by 22 rows, as in Moria...
'               ...N.B: decided on 12 October 2026, for the sake of fidelity: 30 rows had been the idea, but a few of Moria's spells act on "whatever is on screen", so the window is Moria's
'               ...own size and the eight rows below it are the monitor's, so we reverted to true Moria of 22 rows
'   game play:  the internal game turn loop can loop several times processing creature speed and their actions until it reaches the point where it is now the player's turn
'   game turn:  at which point we wait for the player to decide next action, hence our keyboard really does behave like a serial interface for an old VT100/VT520 terminal
'   auto save:  if, after an hour, no input from player, then title screen and player selection should just quit, but a timeout anywhere else (town, shop, dungeon) should trigger an auto save and quit
'   peek/poke:  the original goal was no PEEKs or POKEs at all, that turned out to be the wrong lesson from Sinclair BASIC: in compiled Boriel a Peek or Poke is a single machine instruction...
'               ...exactly what a variable declared "At <address>" compiles to, so they are used freely, the rule that remains is the ethos above: never a bare number for an address
'   roughness:  the routines that were simple ideas captured during the early discussions with Gemini have stayed behind in the "poc1design" project, what is in this project has been built and tested
'   files:      a loader, a core, and one source file per paged stage, with constants.bas and globals.bas shared by all of them, and the game's data built from the Moria source by create-data.ps1
'   self-check: the intention is to add code at the start of runtime to self-check the size and length of the various structures and generate an error if necessary
'   errors:     a simple generic error/crash routine which displays a numeric code and some text, and then halts for a manual reset (done: s_core_crash)
'   monitoring: we need to be able to toggle (via some Alt or Ctrl key) some monitoring stats such as MMU page swap/hit/miss counts and heap and Z80 stack size to be displayed discreetly in the bottom
'               right corner of the viewport, unless the player is actually up there in the corner of the viewport, in which case display the monitoring at the bottom left of the viewport
'               (done differently, decided on 12 October 2026: the monitor has the last five rows of the screen, 27 to 31, below Moria's 24 line screen, so it never covers the game, and the GRAPH key, caps shift and 9, turns it on and off:
'               for each of the MMU slots 0 to 3 the page in it, the count of requests, the hits and the misses, and beside them the heap and the stack, see s_core_display_monitor() in core.bas)
'##################################################################################################################################
' --- PROJECT STATE ---
' state of this source code:
'   1) as of October 2026 the foundation is proven (loader, core, shimmed routines, paged code, paged data, SD card save and load) and the game is being built on it stage by stage
'   2) what exists so far: the opening screens, character creation, and the making and viewing of a dungeon level, each ported from the Moria source routine for routine
'   3) of course I would love it if I could create perfect routines first time
'   4) but then again this is my first ever project on this platform, *AND* my first ever project using Z80 assembler!  yay!!
'   5) I need to make sure that all variables for AC, HP, MANA, STATS (strength, intelligence, etc...), ToDam, ToHit...
'      ...that these are all "signed word" data type so that we can detect when things head south for the player, or indeed any creature!
'
' game play notes, as they occur to me:
'   1) yes, we do want items (loot & treasure) to be found in the dungeon to be both scattered and stacked, but I haven't quite worked out my data "linked list" structures yet
'   2) no smooth scrolling with the player remaining at the centre, instead classic Moria of jump and re-center and redraw the viewport
'   3) but if not jumping/re-center/redrawer then track changes to player location, and monsters moving/dying/appearing, doors opening, rock disolving, and new items being dropped
'
' naming monikers/vernacular:
'   1) use the word "colour" for color/colour not "col", because "col" is short for "column"
'   2) "tile" is for screen tiles, not for the dungeon/town map "floor"
'   3) "floor" is for dungeon map and also town map
'##################################################################################################################################
' --- MILESTONE LOG ---
'   29-Jan-2026     first compile and error, and it always errors the first time, and it errored on the first line!  haha!!
'    2-Feb-2026     first successful compile of around 2400 lines of code (and comment), yay!
'   10-Feb-2026     first run and crash, and it always crashes the first time
'   28-Feb-2026     first attempt to compile a demo of ZX Next hardware and screen config
'      ---          (left it for several months)
'    9-Oct-2026     first visible 80 by 32 tilemap screen, and first keyboard reading, inside an emulator (the core, its data, the paged code and data,
'                   the screen and stack, and the shimmed core routines had already been seen working in February, by stepping through them in ZEsarUX)
'   10-Oct-2026     first display of title screen
'                   first dungeon level made, by Moria's own level maker, and first display of it in the viewport
'   11-Oct-2026     first player creation
'                   first town creation
'                   first display in viewport (of the town)
'                   first walk around the town
'                   first shop entered
'                   first purchase haggling
'                   first selling haggling
'                   first creature (and it just has to be the blubbering idiot) walking the town
'                   first slaying of a creature (ooops, I only bumped in to him!)
'                   first population of town with several folk
' ...after ZX Next issue 3 arrives...
'                   first successful run of anything on a real ZX Next
'##################################################################################################################################
' --- VERSION TABLE ---
'   version  date           description
'   -------  ----           -----------
'   v0.001   15-Jan-2026    The idea was born.
'   v0.002   26-Jan-2026    Bottomed out the design of swapped data paging of use of MMU4/5/6 for creatures and items and DB_MAPS.
'   v0.003   29-Jan-2026    The realization that Boriel compiler does not support Type or Structure or Class.
'   v0.004    2-Feb-2026    First attempt to re-factor from Type data structures to instead specific memory addresses.
'   v0.005   28-Feb-2026    The "poc2demo" project: core code, core data, paged code, paged data, screen and stack, and the shimmed core routines working
'                           (stepped through in ZEsarUX), and most of the screen mode set up.
'             9-Oct-2026    poc2demo finished: the 80 by 32 tilemap made visible, the keyboard read, and the rest of the foundation, see below.
'   v0.006   10-Oct-2026    The "poc3game" project, started as a copy of poc2demo: Moria's databases, random numbers, level maker and opening screens.
'   v0.007   11-Oct-2026    The full player record, and Moria's character creation.
'##################################################################################################################################
' --- PROJECT HISTORY: WHO BROUGHT WHAT ---
' written by Claude on 12-Oct-2026, at the author's request, from what the three project folders and their histories show...
' ...so that a reader can tell the design that was already here from the advice and the labour that came afterwards...
' ...and revised on 13-Oct-2026, when the folders were given names that say the order they were made in, with the author's own account of why each was begun
'
' the three folders, in order, each a "proof of concept":
'   poc1design:     the first attempt, at everything at once: the memory management, the realization that paged code needs a vector/shim mechanism, ORG and
'                   IM1/IM2 and where things go, the font, the screen tiles and the palette, the ZX Next hardware, and first stabs at the game itself such as
'                   making a dungeon map...
'                   ...which became too much: too many unfinished concepts in flight at once, documentation that was poor and inaccurate, and an AI assistant
'                   whose answers could not be relied on, so it was stopped
'   poc2demo:       a fresh start on much less: the ZX Next hardware set up properly, and the simplest possible example of paged code called through the shims,
'                   a "left" stage and a "right" stage that flip between each other...
'                   ...which by the end of February 2026 had the core code, core data, paged code, paged data, screen and stack, and the shimmed core
'                   routines all working, proved by stepping through the assembler in ZEsarUX, and most of the screen mode set up, but not yet a visible
'                   80 by 32 tilemap or a working keyboard routine: it was left there for several months, and finished in October 2026 once the author had
'                   Claude to work with
'   poc3game:       this folder, poc2demo finished and used as the platform for turning Umoria into ZXMoria
' N.B: on the evening of 13-Oct-2026 poc3game was renamed poc3dev, and copied to make poc4uat, where the work goes on:
'   poc3dev:        the folder that was poc3game, the development copy, left as it stood that evening
'   poc4uat:        a clone of poc3dev, the copy the game is played and tried out in, and worked on from then
' N.B: until 13-Oct-2026 the three were called "beforedemo" (and before that "zxproject"), "demo" and "poc1", older notes and logs use those names
'
' 1) what was already worked out, January and February 2026, by the author, with Google Gemini (the "poc1design" folder):
'   the aim:        a faithful port of Umoria to the ZX Next in compiled Boriel BASIC with a little assembler, and the house rules set out at the top of this file
'   the memory:     the 64KB seen as eight 8KB MMU slots, some holding the core for good, the others a "virtual memory" of pages swapped in and out as needed:
'                   paged code, paged lists of what is on a level, and paged databases and maps, with the page counts worked out in zxmoria.xlsx
'   the core:       one core of routines every part of the game needs (screen, keys, paging, random numbers, crash), reached through a jump table at a fixed address
'   the shims:      stage-include.bas, a matching routine for each core routine that simply jumps to its entry in the table, so that a stage is compiled entirely
'                   on its own and still calls the core by name
'   the stages:     the game cut into stages that each fit a page and take turns in the paged code slot: init, player, create town, create dungeon, crawl, store
'   interrupts:     mode 1, with the core at $0000 so that its own handler sat at $0038, interrupts off except while waiting for the next frame
'   two words:      a kind of thing in a database is not the thing itself on a level: creatures and monsters, objects and items, each pair with its own records and pages
'   the strings:    text kept out of the code, in a strings database of its own pages, found through an index
'   the rest:       the 80 by 32 tilemap screen with its own font, fixed addresses in place of the structures Boriel does not have, a memory monitor, the build
'                   script, the font tool, and the start of a script to make the data from Moria's source
'   its state:      a design, and a great deal of thinking, but not yet a program: four of its six stages did not compile
'
' 2) the foundation, the "poc2demo" folder, kept free of anything to do with the game:
'   by the author, to 28 February 2026: the concept of screen and stack, core code, core data, paged code and paged data, and the shimmed core routines, all of it
'                   working, proved by stepping through the assembler in ZEsarUX, and most of the screen mode set up
'   what it lacked: an actual visible 80 by 32 tilemap, and a working keyboard reading routine
'   finished by the author with Claude, 9 and 10 October 2026: the visible tilemap and the keyboard reading, and the foundation as it then stood:
'   the core moves: from $0000 to $8000 (MMU 4 and 5), with its data in MMU 6 and the screen and stack in MMU 7, paged code in MMU 3, and the three slots of paged
'                   data at the bottom, MMU 0, 1 and 2, because NextZXOS only answers a file call with its ROM at the bottom of memory, so those are lent back for it
'   IM1 to IM2:     which leaves nothing of ours at $0038, so the frame interrupt had to become mode 2, its handler and its table at the top of the core's second page
'   a loader:       a small program that sets the machine up, maps the pages, builds the interrupt table and hands over to the core
'   one heap:       1KB at the end of the core's data, and every module compiled with the same heap address, which is what lets a stage hand a string to the core
'   and:            keyboard scanning with EXTEND as Ctrl, a page saved to and loaded from the SD card, the nex file made by sjasmplus, NextZXOS starting it by itself
'
' 3) the architecture advised since, 10 to 12 October 2026, by Claude, with the author deciding (this "poc3game" folder):
'   libraries:      a page of code that any stage, or another library, may call through the core and return from, where a stage can only be handed over to...
'                   ...each with the top 512 bytes of its own page as private working storage that is still there the next time it is called
'   the rule:       a stage returns to the core and the core picks the next (the author's model, kept), a library puts back any data page it changes
'   the data:       every record 64 bytes, the databases and tables built from Moria's own source by create-data.ps1 so that nothing is typed in or left out,
'                   data pages packed together from page 30, code pages from 96 upwards
'   the map:        8 bytes a square and 256 squares a row, so a row never crosses a page and finding a square is two shifts
'   saving:         the game IS a set of pages, so those pages are what is saved, one after another in one file
'   messages:       fixed messages kept in the author's strings database and shown by number, the message line and the map drawing moved into the core, one copy of each
'   the build:      only what has changed is compiled, several modules at once, with checks on every page's size and start address
'   discipline:     each random number asked for exactly when Moria asks for it, every gap marked NOT YET in the source and listed in not-yet.md, a test for each piece
'   one hard bug:   Boriel's own CHR routine writes to a ZX system variable which, in this memory layout, is in the middle of a data page: found, replaced, guarded against
'
' 4) and the labour: the translation of Umoria 5.7.15, routine by routine, from C++ into Boriel BASIC, done by Claude and checked against Moria's source and in the emulator:
'   as of 12-Oct-2026 about 28,000 lines in 89 source files, compiled into 64 pages of code and a core, about 322KB of code and 176KB of data
'##################################################################################################################################
' --- FUTURE IDEAS ---
' these ideas are all out of scope for now, but I'm logging them here so that I don't forget them...
'   1) mini-map 2:1 ratio of "seen" dungeon floor squares within upper half of font page of 128 UDG chars...
'      ...where each dot in the mini-map represents any "seen rock" in any "2x2" area of the dungeon floor...
'      ...i.e. a max dungeon size of 256 cols by 128 rows, is 32768 floor "squares", that would be a lot of pixels to draw, but if we get clever...
'      ...max dungeon columns of 256, at floor:dot ratio 2:1, yields a mini-map of 128 dots wide, and the 128 rows yields 64 dots height...
'      ...and we know that UDG chars are 8x8 "dots", so now we know that we would need the mini-map to be 16 UDG wide, and 8 UDG tall...
'      ...and 16 x 8 magically works out at 128 UDGs which is "made for it" perfect for the otherwise unused upper half of the font page! wow!!
'      So, in the future I would like to make a scrolling mini-map fit within the bottom area of the left-hand side bar of player stats...
'      ...such that the mini-map UDG set of "16 x 8" scrolls within a mini-map view area of the side-bar width of 12 by 6 rows, so a minimap view area of "12 x 6".
'      So, during game play the player will have a main "viewport" of dungeon of "66 x 22" squares, plus now also a "minimap" of dungeon of "192 x 96" squares...
'      i.e. each dot in the mini-map represents "2x2" of the dungeon floor.
'      And, we can colour the UDG char (i.e. the 16x16 floor tile area) that the player is currently within, in colour green maybe.
'      Gosh, how good does that sound!  Wow, I really hope that I do get to implement this one day, in the not too distant future hopefully.
'      DONE, 16-Oct-2026 (stage-lib-minimap.bas, page 163), and how it turned out:
'        - the [ key cycles it (O at first, [ since the same evening, and ] for the live monitor): off, 1:1 (a dot for each square, a 128 x 64 window that follows the player), 1:2 (a dot for each 2x2, the whole level)
'        - the 16 x 8 UDG chars 128 to 255 sit at the far left of screen rows 24 to 31, below Moria's 24 lines, the live monitor's MMU 2 misses moved up to rows 24 to 26, from column 17, to make room
'        - two stages, as planned: a 1:1 bitmap of what is known, kept in page 44 and a bit set as each wall becomes known, turned into the UDGs just before the prompt
'        - it shows the walls the player remembers, as Moria remembers them, and the player as a dot, it takes no turn, and is only drawn while waiting for a key
'        - measured in the emulator: 2.1 ms a turn at 1:1, 8.3 ms at 1:2, 50 ms to rebuild the bitmap after a new level, a lit room, a spell or a tunnel
'        - not done (yet): the green highlight of the char the player is in
'##################################################################################################################################