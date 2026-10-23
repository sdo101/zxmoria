# ZXMoria

ZXMoria is a port of *Umoria* 5.7.15, *The Dungeons of Moria*, to the ZX Spectrum Next.
It aims to play exactly as Umoria plays: the same dungeon, monsters, objects, spells and rules.

> **This is a beta.** The game can be played from the town to the depths, saved and reloaded, but not everything is
> finished, and **it has not yet been tested on a real ZX Spectrum Next**: so far it has only been run in the ZEsarUX
> emulator. A test on real hardware is coming soon. `not-yet.md` lists what is not finished and what has not been
> tested, and `umoria-oddities.md` lists the slips found in Umoria's own source while matching it, and what ZXMoria
> does about each.

**Just want to try it?** Download `zxmoria.nex` from the
[latest release](https://github.com/sdo101/zxmoria/releases/latest) and run it in ZEsarUX (as a Next, with Smart Load)
or, at your own risk while it is untested there, on your Next (copy it to the SD card and choose it in the Browser).
In the game, `?` shows the commands, as in Umoria. `QUICKSTART.md` says more: playing on a Next or in ZEsarUX, a PC
keyboard with and without AutoHotkey, a first game, and the few keys that are ZXMoria's own.

## Where it comes from

*The Dungeons of Moria* was written by Robert Alan Koeneke and first released in 1983.
James E. Wilson ported it to C and released it as *Umoria* in 1988.
Umoria 5.7.15 is maintained at <https://github.com/dungeons-of-moria/umoria>.
The full list of people who have worked on it is in Umoria's `AUTHORS` file, and the game shows it in its opening credits.

ZXMoria is a modified version of Umoria, begun in 2026.
The game was rewritten from Umoria's C++ source in Boriel ZX BASIC and Z80 assembler, and reorganised to fit the Next's memory, screen and keyboard.
Its data (creatures, objects, spells, tables and text) is generated from the Umoria source when the game is built.
Where ZXMoria differs from Umoria on purpose, the source file concerned says so near its top.

The opening picture, the Bridge of Khazad-dum, is ZXMoria's own drawing, made by `tools\make-splash.py`.

## Who did what

ZXMoria was made by sdo working with Claude, Anthropic's AI model, in Claude Code.

- **sdo**: the design of the memory as 8KB pages swapped in and out of the Next's MMU slots, the core reached through a
  jump table and the shimmed routines that let each stage be compiled on its own, the frame interrupt in IM1, the
  strings database, and the decisions throughout.
- **Claude**: the visible 80 by 32 tilemap screen, the keyboard reading, the move from IM1 to IM2, the translation of
  Umoria 5.7.15 from C++ into Boriel ZX BASIC, routine by routine, and the testing, above all the comparisons with
  the real Umoria, which play the same game with the same random numbers in both and compare what comes out.

The history in more detail is at the top of `src\goals.bas`.

## Copyright and licence

- Copyright (c) 1981-86 Robert A. Koeneke
- Copyright (c) 1987-94 James E. Wilson
- Copyright (c) 2026 The ZXMoria authors

ZXMoria is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This is the same licence as Umoria's.

ZXMoria is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

The full text of the licence is in the file `LICENSE`.
It goes on the SD card beside the game as `zxmoria.lic`, and in the game `?` and `v` show the copyright notices and name that file.

## If you pass it on

The licence asks the following of anyone who gives a copy of the game to someone else:

- Give them the `LICENSE` file with it, and leave the copyright notices in place.
- Give them the complete source as well, or a written offer to supply it. The source is everything in this repository, together with the Umoria 5.7.15 source that the data is built from.
- If you have changed it, say so prominently, with the date, and release your version under the same licence.

## Building it yourself

What you need:

- Windows with PowerShell 7.2 or later
- Python 3, which runs the compiler
- [Boriel ZX BASIC](https://zxbasic.readthedocs.io/) 1.19
- [sjasmplus](https://github.com/z00m128/sjasmplus) 1.24, which builds the nex file
- [ZEsarUX](https://github.com/chernandezba/zesarux) 13, which comes with a NextZXOS SD card image
- hdfmonkey, which puts files on the SD card images
- the [Umoria 5.7.15 source](https://github.com/dungeons-of-moria/umoria), which the game's data is built from
- optional: [AutoHotkey](https://www.autohotkey.com/) v2, for `tools\zesarux-keys.ahk` (see below)

These are not part of ZXMoria and have their own licences.
`build.ps1` finds them by looking upwards from its own folder for one that contains `boriel\<version>\zxbc.py`.
Boriel, sjasmplus and ZEsarUX each have a folder for each version, and the newest is used unless `build.ps1` names one
(`$CompilerPinned`, `$LinkerPinned`, `$EmulatorPinned`). So the layout is:

```
<any folder>\
    boriel\1.19.0\      zxbc.py and the rest of Boriel ZX BASIC
    sjasmplus\1.24.0\   sjasmplus.exe
    zesarux\13.0\       zesarux.exe and its tbblue.mmc
    tools\              hdfmonkey.exe
    umoria\             the Umoria 5.7.15 source (its src\ folder is what the data is built from)
    images\tbblue\      optional: new.mmc, a NextZXOS card image to use in place of ZEsarUX's
    ...\zxmoria\        this folder, at any depth below
```

Then:

```
pwsh .\build.ps1
```

This makes the font, the game's data from the Umoria source, and the opening pictures; compiles the loader, the core
and every stage and library, only those that have changed; checks them; builds the nex file beside `build.ps1`; puts
it on the SD card images; and starts ZEsarUX. Everything it makes on the way is in `build\`, and a dated copy of every
build's log is kept in `logs\`. The nex file and the card images are named after the folder `build.ps1` is in, so in a
folder called `zxmoria` they are `zxmoria.nex`, `zxmoria-base.mmc` and so on, as below.

Options: `-NoRun` builds without starting the emulator, `-Full` compiles everything, `-Jobs <n>` sets how many modules
compile at once, and `-Start <x>` chooses how the emulator starts:

- `zf`, the default: the nex file straight into ZEsarUX, with no NextZXOS boot and no SD card. Files the game writes go
  in this folder.
- `za`: NextZXOS boots from `zxmoria-za.mmc`, and its `autoexec.bas` starts the game, as on a real Next.
- `zb`: NextZXOS boots from `zxmoria-zb.mmc` to its own menu, where the game can be chosen in the Browser.
- `zd`: ZEsarUX waits for the DeZog debugger in VS Code, which loads the game and shows the source as it runs.

The first build copies a NextZXOS card image to make `zxmoria-base.mmc` (from `images\tbblue\new.mmc` if you have one,
otherwise from ZEsarUX's own `tbblue.mmc`), and the za and zb cards are made from that. What the game saves on a card
stays there from build to build. `clean.bat` deletes everything the build makes, the card images included.

To play on a real Next, `tools\push-card.ps1` copies the nex file and the licence to the Next's SD card in a card reader
on the PC, `tools\make-card.ps1` makes a whole new card (the official NextZXOS distribution, then the game), or
`tools\wifi-server.ps1` serves them to the Next over Wi-Fi, where `.http` fetches them. The top of each script says how
to use it.

To play in ZEsarUX with a PC keyboard, `tools\zesarux-keys.ahk` makes the number pad, Ctrl and the punctuation keys (of
a UK keyboard) type what they say. `build.ps1` starts it with the emulator if AutoHotkey v2 is installed
(`winget install AutoHotkey.AutoHotkey`), and it does nothing outside the emulator's window.

## Files the game writes

On the SD card, beside the nex file (or, when an emulator is given the nex file directly, in the folder it was started in):

| File | What it is |
|---|---|
| `zxmoria.sav` | The saved game, 278,528 bytes. As in Moria there is only the one: saving replaces it, and the game carries on with it when it starts. When the character dies it is cut to two pages, which keep what characters have learnt about the dungeon's creatures for the next one. |
| `scores.dat`, `scores.txt` | The high scores, and the same as text to read. |
| `player-<name>.txt` | A character's record: the sheet, what is worn and what is carried. |
