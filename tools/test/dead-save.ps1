# a dead character's save, kept from before it died and put back, is not loaded again: bob is made and saved (Ctrl-X),
# his save is copied aside, he is loaded and quits (Q), which puts him in the high scores with his birth and puts the
# date on his tombstone, then the copy is put back and loading it must say he has died
# the emulator is given the nex file, so the files are in build\test\dead-save
# -Away when nobody is at the machine: the emulator may keep the keyboard, see lib.ps1, N.B: needed from the second start
# on, when the emulator kept the keyboard every time on 15 October and the test was stopped
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([switch]$Away)
. "$PSScriptRoot\lib.ps1"; $script:Proj = 'dead-save'; $script:Away = [bool]$Away
$w = "$script:Work\$script:Proj"
if(Test-Path $w){ Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { [IO.File]::Delete($_.FullName) } }
function Quit-Emu { $null = Z 'exit-emulator'; if($script:Emu){ $null = $script:Emu.WaitForExit(15000) } }
function Hex4($b, $at){ '{0:X2}{1:X2}{2:X2}{3:X2}' -f $b[$at+3], $b[$at+2], $b[$at+1], $b[$at] }

# --- 1: bob is made, and saved
try {
    $ok = Start-Game -ExitAfter 300
    "1 in the town: $ok, birth " + ('{0:X4}{1:X4}' -f (Peek16 0xD81E), (Peek16 0xD81C))
    Ctrl 'x'; $ok = WaitFor 14 31 'ZXMoria has ended.' 120; "1 saved and ended: $ok"
} finally { Quit-Emu; Stop-Game }
Get-ChildItem $w -File | ForEach-Object { "    {0} {1}" -f $_.Name, $_.Length }
Copy-Item "$w\zxmoria.sav" "$w\keep.sav"

# --- 2: bob is loaded, and quits
try {
    $ok = Start-Game -NoCharacter -ExitAfter 300; Key 113
    $null = Pass-Sheet; $ok = WaitFor 23 65 'Town level' 120; "2 loaded: $ok"
    Ctrl 'k'; Start-Sleep 1; Key 121
    $ok = WaitFor 22 0 'Character record?' 60; "2 the tombstone: $ok"; Screen 5 18
    Esc; Start-Sleep 8
} finally { Quit-Emu; Stop-Game }
if(Test-Path "$w\scores.txt"){ Get-Content "$w\scores.txt" | Where-Object { $_.Trim() } | Select-Object -First 4 }
if(Test-Path "$w\scores.dat"){ $b = [IO.File]::ReadAllBytes("$w\scores.dat"); "scores.dat: {0} scores, marker {1}, the first's birth {2}, died {3}" -f $b[0], [char]$b[1], (Hex4 $b 82), (Hex4 $b 86) }

# --- 3: the copy of his save is put back, and loading it is refused
Copy-Item "$w\keep.sav" "$w\zxmoria.sav" -Force
try {
    $ok = Start-Game -NoCharacter -ExitAfter 300; Key 113
    Start-Sleep 6; Screen 10 10; Screen 23 23
} finally { Quit-Emu; Stop-Game }
