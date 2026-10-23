# ZXMoria quick start

ZXMoria is *Umoria* 5.7.15, *The Dungeons of Moria*, on the ZX Spectrum Next. You go down through the dungeon under
the town, level by level, and kill the Balrog at the bottom. This page gets you playing. `README.md` covers the
licence and building it yourself.

## You need

- the game, the `.nex` file (named after its folder, `zxmoria.nex`), and the licence, `zxmoria.lic`
- either a ZX Spectrum Next, or a Windows PC with the [ZEsarUX](https://github.com/chernandezba/zesarux) emulator,
  version 13 or later
- on the PC: [AutoHotkey](https://www.autohotkey.com/) version 2 is strongly recommended, see below

## On a real Next

1. Put `zxmoria.nex` and `zxmoria.lic` together in any folder of the Next's SD card.
   (`tools\push-card.ps1` does it from a card reader on a PC, and `tools\wifi-server.ps1` sends them over Wi-Fi.)
2. Start the Next, open the Browser, go to that folder and choose `zxmoria.nex`.

The game saves to `zxmoria.sav` in the same folder, and keeps its scores in `scores.dat` and `scores.txt` there.

## On a PC, in ZEsarUX

If you have built the game yourself, `.\build.ps1` builds it and starts ZEsarUX with it, and AutoHotkey too if that
is installed. Otherwise, start ZEsarUX as a Next (machine "ZX Spectrum Next", `--machine tbblue`), then load
`zxmoria.nex` with Smartload (F5 opens ZEsarUX's menu). The saved game and scores go in the folder ZEsarUX was started
in.

### PC keyboards and AutoHotkey

ZEsarUX turns the PC's keys into the Spectrum's forty, and some are lost or changed on the way: the number pad does
nothing, Ctrl arrives as Symbol Shift, and Shift with a punctuation key arrives as something else entirely.

`tools\zesarux-keys.ahk` puts that right. With AutoHotkey version 2 installed (`winget install AutoHotkey.AutoHotkey`)
double click it, or let `build.ps1` start it. A green **H** appears in the notification area; right click it to stop
it. It only does anything while the ZEsarUX window has the keyboard. Its punctuation is laid out for a **UK
keyboard**; another layout needs the two tables near the top of the file changed.

| To type | Next keyboard | PC, with AutoHotkey | PC, without |
|---|---|---|---|
| a direction, 1 to 9 | the number keys | the number pad or the top row | the top row only |
| a step | the cursor keys | the arrow keys | the arrow keys |
| ESC (leave, cancel, -more-) | BREAK | Esc | Esc |
| Ctrl and a letter, e.g. Ctrl-X | hold EXTEND, press X | Ctrl+X | hold Tab, press X |
| a symbol, e.g. `>` | Symbol Shift and the key it is on | just type it | hold Ctrl and the Spectrum key that has it |
| Delete | DELETE | Backspace | Backspace |

Without AutoHotkey, the symbols are where a Spectrum has them, held with Ctrl: `>` is Ctrl+T, `<` Ctrl+R, `?`
Ctrl+C, `=` Ctrl+L, `#` Ctrl+3, `{` Ctrl+F, `}` Ctrl+G, `[` Ctrl+Y, `]` Ctrl+U, `-` Ctrl+J, `+` Ctrl+K, `*` Ctrl+B,
`/` Ctrl+V, `.` Ctrl+M.

## Your first game

1. The game starts with your character: choose a race, a sex and a class, and the game rolls the rest.
2. You begin in the town. The numbered doors are the six stores; walk into one to buy armour, a weapon, food, flasks
   of oil and Cure Light Wounds potions. `p` buys, `s` sells, ESC leaves.
3. Find the `>` and press `>` on it to go down. `<` comes back up.
4. `?` shows every command. The ones you need first:

| Key | Does |
|---|---|
| 1 to 9 | walk (`5` stays put), a run is `.` and a direction |
| `i` `e` | what you carry, what you wear |
| `w` `t` | wear or wield, take off |
| `q` `r` `E` | quaff a potion, read a scroll, eat |
| `R` | rest: a number, or `*` until healed |
| `s` | search for traps and secret doors |
| `l` | look about |
| `=` | options: the rogue like keys, colour on or off and more |
| Ctrl-P | the last message again, twice for all of them |
| Ctrl-X | save and leave; the game carries on from there next time |

As in Moria, there is only one saved game, and when your character dies, it is gone.

## Our own keys

These are ZXMoria's, not Moria's, and none of them takes a turn:

| Key | Does |
|---|---|
| `[` | the mini map: off, full size (the part of the level around you), half size (all of it), and round again |
| `]` | the colours off and on, the same as "Plain map, no colours" in the options |
| `}` | the live memory monitor at the bottom of the screen: the MMU slots, the heap and the stack; then the same with the MMU 2 cache misses as well; then off |

`[` and `]` work when the game is asking for a command; `}` works anywhere, even in a store or a menu.
