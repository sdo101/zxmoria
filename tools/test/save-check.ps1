# a saved game is checked as Moria's loadGame() checks one: a character is saved (Ctrl-X), and then, each with an
# emulator start of its own:
#   the save with 99 kinds of thing in the pack (22 is all it holds): "Error during reading of file." and "Please
#     try again without that save file.", the game ends, and the file is left as it was
#   the save cut short after three of its pages: the same
#   the save with another version number: the same, and "Sorry. This save file is from a different version of
#     ZXMoria." (sdo, 16 October 2026: the version must match, or it is a no go)
#   a file of the name that is not ours at all: the same as the first
#   no file at all: a new character, as ever
#   the save as it was made: it loads, the character's sheet, and the town
# each check prints PASS or FAIL, the emulator's files are in build\test\save-check
# -Away when nobody is at the machine
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([switch]$Away)
. "$PSScriptRoot\lib.ps1"
$script:Proj = 'save-check'; $script:Away = [bool]$Away
$script:Pass = 0; $script:Fail = 0
$w = "$script:Work\$script:Proj"
if (Test-Path $w) { Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { [IO.File]::Delete($_.FullName) } }
function Check([string]$what, [bool]$ok, [string]$seen) { if ($ok) { $script:Pass++; "PASS  $what" } else { $script:Fail++; "FAIL  $what  [$seen]" } }
function Quit-Emu { $null = Z 'exit-emulator'; if ($script:Emu) { $null = $script:Emu.WaitForExit(15000) }; Stop-Game }
function Hash([string]$f) { (Get-FileHash $f -Algorithm SHA256).Hash }

# --- a character, saved
try {
    if (-not (Start-Game -ExitAfter 600)) { 'no game'; return }
    Ctrl 'x'
    if (WaitFor 23 23 '[ press any key' 60) { Key 32 }
    $ok = WaitFor 14 31 'ZXMoria has ended.' 60
    Check "a character saved" $ok ''
} finally { Quit-Emu }
$sav = "$w\zxmoria.sav"
Copy-Item $sav "$w\good.sav" -Force
$good = [IO.File]::ReadAllBytes($sav)

function Try-Bad([string]$what, [byte[]]$bytes, [switch]$Version) {
    [IO.File]::WriteAllBytes($sav, $bytes); $before = Hash $sav
    try {
        if (-not (Start-Game -NoCharacter -ExitAfter 600)) { 'no game'; return }
        Key 113
        $ok = WaitFor 0 0 'Error during reading of file.' 60
        Check "${what}: Error during reading of file." $ok ((Row 0).Trim())
        Check "${what}: Please try again without that save file." ((Row 1).Trim() -eq 'Please try again without that save file.') ((Row 1).Trim())
        if ($Version) { Check "${what}: Sorry. This save file is from a different version of ZXMoria." ((Row 2).Trim() -eq 'Sorry. This save file is from a different version of ZXMoria.') ((Row 2).Trim()) }
        else { Check "${what}: no word of a version" ((Row 2).Trim() -eq '') ((Row 2).Trim()) }
        Key 32
        $ok = WaitFor 14 31 'ZXMoria has ended.' 60
        Check "${what}: the game ends" $ok ''
    } finally { Quit-Emu }
    Check "${what}: the file left as it was" ((Hash $sav) -eq $before) ''
}

# --- 99 kinds of thing in the pack, N.B: Moria's pack.unique_items, the player's record is 6144 bytes into the core's
# data, the first page of the file, and the count 498 bytes into that
$bad = [byte[]]$good.Clone(); $bad[6144 + 498] = 99; $bad[6144 + 499] = 0
Try-Bad 'the pack holding 99' $bad

# --- cut short after three pages
Try-Bad 'the file cut short' ([byte[]]$good[0..(3 * 8192 - 1)])

# --- another version, N.B: the marks are "ZM" and the version 6995 bytes into the core's data
$bad = [byte[]]$good.Clone(); $bad[6997] = 99
Try-Bad 'another version' $bad -Version

# --- not ours: the marks gone
$bad = [byte[]]$good.Clone(); $bad[6995] = 0; $bad[6996] = 0
Try-Bad 'not ours' $bad

# --- no file: a new character
Remove-Item $sav -Force
try {
    if (-not (Start-Game -NoCharacter -ExitAfter 600)) { 'no game'; return }
    Key 113
    $ok = WaitFor 20 2 'Choose a race' 60
    Check "no file: a new character" $ok ((Row 20).Trim())
} finally { Quit-Emu }

# --- the save as it was made
Copy-Item "$w\good.sav" $sav -Force
try {
    if (-not (Start-Game -NoCharacter -ExitAfter 600)) { 'no game'; return }
    Key 113
    $sheet = Pass-Sheet
    $ok = WaitFor 23 65 'Town level' 120
    Check "the good save: the sheet, and then the town" ($sheet -and $ok) "sheet $sheet town $ok"
} finally { Quit-Emu }
"passed $script:Pass, failed $script:Fail"
