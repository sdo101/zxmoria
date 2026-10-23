# bringing a dead character back, Ctrl-W on the opening screen, Moria's -w: run the steps in order, one emulator
# start each, N.B: in separate runs, the emulator kept the keyboard from the second start within one script
#   -Step 1  bob is made, starving, poisoned and below 0 hit points are put in, and he quits (dies)
#   -Step 2  Ctrl-W, yes to "Resurrect a dead character?": he is in the town, "Resurrected", the fixes made, and saved
#   -Step 3  the save is loaded normally (not refused as a dead character's), and he quits again
#   -Step 4  Ctrl-W, no to the resurrection: a new character, in wizard mode after the disclaimer, and saved
#   -Step 5  Ctrl-W with a living wizard's save: loaded, in wizard mode with no question, as Moria's
#   -Step 6  a new character who has won (gub_game_total_winner put in) quits
#   -Step 7  Ctrl-W: the retired character is refused, as Moria's, and a new character is begun in wizard mode
# the stores' stock: step 1 puts a mark in an unused corner of its second page, 41 at 8000, step 2 looks for it, N.B: the
# stock itself changes on the way back, Moria's townGeneration() calls storeMaintenance() every time the town is made
# the emulator is given the nex file, so the files are in build\test\resurrect
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([int]$Step = 1, [switch]$Away)
. "$PSScriptRoot\lib.ps1"; $script:Proj = 'resurrect'; $script:Away = [bool]$Away
$w = "$script:Work\$script:Proj"
function Quit-Emu { $null = Z 'exit-emulator'; if($script:Emu){ $null = $script:Emu.WaitForExit(15000) } }
function S16([int]$a){ $v = Peek16 $a; if($v -gt 32767){ $v - 65536 } else { $v } }
function P32([int]$a){ (Peek16 ($a + 2)) * 65536 + (Peek16 $a) }
function Bob { "    hp {0} food {1} poisoned {2} speed {3} heaviness {4} gold {5} exp {6} level {7} noscore {8} wizard {9} status {10:X8} | {11} | {12}" -f (S16 0xD864), (S16 0xD982), (S16 0xD990), (S16 0xD988), (S16 0xD9F6), (P32 0xD820), (P32 0xD828), (Peek16 0xD834), (Peek8 0xDA4D), (Peek8 0xDA4C), (P32 0xD976), (Row 22).Substring(0, 12), (Row 23).Trim() }
function Files { Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { "    {0} {1}" -f $_.Name, $_.Length } }
function Quit-Bob { Ctrl 'k'; Start-Sleep 1; Key 121
    $ok = WaitFor 22 0 'Character record?' 60; "  the tombstone: $ok"; Esc
    if(WaitFor 23 23 '[ press any key' 60){ "  the scores:"; 2..8 | ForEach-Object { "    " + (Row $_).TrimEnd() } | Where-Object { $_.Trim() }; Key 32 } else { "  no scores" }
    Start-Sleep 8 }

try {
    switch($Step){
        1 {
            if(Test-Path $w){ Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { [IO.File]::Delete($_.FullName) } }
            if(-not (Start-Game -ExitAfter 600)){ 'no game'; return }
            "1 bob in the town:"; Bob
            # starving, badly poisoned and below 0 hit points, for Moria's three fixes
            Poke16 0xD982 (-50); Poke16 0xD990 20; Poke16 0xD864 (-3)
            "1 as he quits:"; Bob
            PagePoke 41 8000 0xA5; PagePoke 41 8001 0x5A
            Quit-Bob
        }
        2 {
            if(-not (Start-Game -NoCharacter -ExitAfter 600)){ 'no game'; return }
            Ctrl 'w'
            $ok = WaitFor 0 0 'Resurrect a dead character? [y/n]' 60; "2 asked: $ok"
            Key 121
            "2 the sheet: " + (Pass-Sheet)
            $ok = WaitFor 23 65 'Town level' 120; "2 in the town: $ok"
            Start-Sleep 2; "  messages: " + (Msgs)
            Bob
            "  the stores' stock came back: " + ((Page 41 8000 2) -eq 'A55A')
            Ctrl 'x'
            if(WaitFor 23 23 '[ press any key' 60){ "  the scores after saving:"; 2..8 | ForEach-Object { "    " + (Row $_).TrimEnd() } | Where-Object { $_.Trim() }; Key 32 } else { "  no scores after saving" }
            $ok = WaitFor 14 31 'ZXMoria has ended.' 60; "2 saved: $ok"
        }
        3 {
            if(-not (Start-Game -NoCharacter -ExitAfter 600)){ 'no game'; return }
            Key 113
            "3 the sheet: " + (Pass-Sheet)
            $ok = WaitFor 23 65 'Town level' 120; "3 loaded: $ok"
            if(-not $ok){ Screen 0 23; return }
            Start-Sleep 2; "  messages: " + (Msgs)
            Bob
            Quit-Bob
        }
        4 {
            if(-not (Start-Game -NoCharacter -ExitAfter 600)){ 'no game'; return }
            Ctrl 'w'
            $ok = WaitFor 0 0 'Resurrect a dead character? [y/n]' 60; "4 asked: $ok"
            Key 110
            $ok = WaitFor 0 0 'Wizard mode is for debugging' 60; "4 the disclaimer: $ok"; Key 32
            $ok = WaitFor 0 0 'The game will not be scored' 30; "4 are you sure: $ok"; Key 121
            $ok = WaitFor 20 2 'Choose a race' 60; "4 a new character: $ok"; Key 97
            $ok = WaitFor 20 2 'Choose a sex' 20; Key 109
            $ok = WaitFor 20 2 'Hit space' 30; Esc
            $ok = WaitFor 20 2 'Choose a class' 20; Key 97
            $ok = WaitFor 21 2 'Enter your' 30; Type_ 'al'
            $ok = WaitFor 23 17 '[ press any key' 20; Key 97
            $ok = WaitFor 23 65 'Town level' 120; "4 in the town: $ok"
            Start-Sleep 2; "  messages: " + (Msgs)
            Bob
            Ctrl 'x'
            if(WaitFor 23 23 '[ press any key' 60){ Key 32 }
            $ok = WaitFor 14 31 'ZXMoria has ended.' 60; "4 saved: $ok"
        }
        5 {
            if(-not (Start-Game -NoCharacter -ExitAfter 600)){ 'no game'; return }
            Ctrl 'w'
            "5 the sheet: " + (Pass-Sheet)
            $ok = WaitFor 23 65 'Town level' 120; "5 loaded: $ok"
            if(-not $ok){ Screen 0 23; return }
            Start-Sleep 2; "  messages: " + (Msgs)
            Bob
        }
        6 {
            if(Test-Path $w){ Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { [IO.File]::Delete($_.FullName) } }
            if(-not (Start-Game -ExitAfter 600)){ 'no game'; return }
            Poke8 0xC22B 1
            "6 a winner:"; Bob
            Quit-Bob
        }
        7 {
            if(-not (Start-Game -NoCharacter -ExitAfter 600)){ 'no game'; return }
            Ctrl 'w'
            $ok = WaitFor 10 4 'Sorry, this character is retired from moria.' 60; "7 refused: $ok"; Screen 10 11
            Key 32
            $ok = WaitFor 0 0 'Wizard mode is for debugging' 60; "7 the disclaimer for a new character: $ok"
        }
    }
} finally { Quit-Emu; Stop-Game }
Files
