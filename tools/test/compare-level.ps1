# a level as each game makes it, the real Umoria and ZXMoria, from the same seed, and compared: the map, what lies on it, the
# monsters, and the six stores with their stock, as they are the moment the character first stands in the town, or with
# -Level, on that dungeon level, reached at once by the wizard's Ctrl-D, and with -Rest, after resting that many turns there
# (the monsters move, wake and fight in the meantime, so this tests the turns, not only the making of the level), and
# with -Keys, after those keys have been typed into both, one at a time, e.g. -Keys 'ss' for two turns of searching, and with
# -First, keys typed into both before the rest, e.g. -First 'S' for search mode, and with -Wait, a wait of that many seconds
# after the keys, for a count to run its course, e.g. -First 'S' -Keys '#999s' -Wait 60 searches until something breaks it off
# N.B: a rest turns searching off, in both games
# N.B: a key typed while a count runs breaks it off, in both games, so a long count (#30s) must end the keys, and -Wait
# let it run its course: keys after it (#30s~~) land part way through, Umoria about 20 turns in, ZXMoria about 23
# (found 17 October 2026, the turns differed and it looked like a fault)
# N.B: ~ in -Keys or -First is ESCAPE, in both games, to answer a -more- (Umoria waits there for ESCAPE, space or return, and
# ignores anything else, so keys typed while it waits are lost), at the command prompt it does nothing and takes no turn,
# and | is ENTER, e.g. after an offer in a store: -Keys 'pa58|', and ^ and a letter is Ctrl and the letter, e.g. -Keys '^t'
# for the wizard's teleport: Umoria takes ^ as its own way of typing a control key (both key sets), and ZXMoria is sent
# the Ctrl key itself, the two together, by lib.ps1's Ctrl
# N.B: \ in -Keys, -First or -After waits there as -Wait does, Umoria for -Wait seconds and ZXMoria until the turn has
# stood still for three seconds, so that a rest can run its course before the keys after it, e.g. -Keys 'R999|\~R999|'
# -Wait 150 rests twice (added 21 October 2026, a Quasit took two rests to wake)
# Umoria saves at once (Ctrl-X) and umoria-save.py reads its saved game; ZXMoria's memory is read in the emulator by
# zxmoria-state.ps1; both print the same form of text, which is compared a section at a time
# N.B: the ZXMoria nex file in -Nex must have been built with UL_GAME_FIXED_SEED set to the same seed, see seeded-build.ps1
# -After, keys typed into both once the wait is over, e.g. -After '~' to answer a -more- that the count or rest ended on
# (found 17 October 2026: a Word of Recall during a rest left "You feel yourself yanked upwards!" at -more-, and Umoria's
# Ctrl-X was lost there, it made no saved game)
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([uint32]$Seed = 12345, [string]$Nex, [int]$Race = 0, [int]$Class = 0, [int]$Level = 0, [int]$Rest = 0, [string]$Keys = '', [string]$First = '', [int]$Wait = 0, [string]$After = '', [switch]$WaitReady)
$t = $PSScriptRoot; $sp = Join-Path $PSScriptRoot '..\..\build\test'; $null = New-Item $sp -ItemType Directory -Force; $sp = (Resolve-Path $sp).Path
# N.B: a long tag is cut short, with a hash of the whole of it after, the folders it names must stay within Windows'
# 260 characters (found 17 October 2026: a fight of 300 keys gave a folder Umoria could not be started in)
$tag = "level$Level-seed$Seed-r$Race-c$Class" + $(if($Rest){ "-rest$Rest" } else { '' }) + $(if($First){ '-first' + ($First -replace '[^A-Za-z0-9]', '_') } else { '' }) + $(if($Keys){ '-keys' + ($Keys -replace '[^A-Za-z0-9]', '_') } else { '' }) + $(if($After){ '-after' + ($After -replace '[^A-Za-z0-9]', '_') } else { '' })
if($tag.Length -gt 100){
    $whole = [Text.Encoding]::UTF8.GetBytes("$Level|$Race|$Class|$Rest|$First|$Keys|$Wait|$After")
    $tag = $tag.Substring(0, 90) + '-' + ([BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash($whole)) -replace '-', '').Substring(0, 8)
}

# --- Umoria: the character, into the town, wizard mode and Ctrl-D to the level if there is one, Ctrl-X saves and ends the game
$jump = $(if($Level){ "'^w','SPACE','y','SPACE','^d','$Level','ENTER'," } else { '' }) + (-join ($First.ToCharArray() | ForEach-Object { if($_ -eq '~'){ "'ESC'," } elseif($_ -eq '|'){ "'ENTER'," } elseif($_ -eq '\'){ "'WAIT$Wait'," } else { "'$_'," } })) + $(if($Rest){ "'R','$Rest','ENTER','WAIT$([Math]::Ceiling($Rest / 10) + 5)','ESC','ESC'," } else { '' }) + (-join ($Keys.ToCharArray() | ForEach-Object { if($_ -eq '~'){ "'ESC'," } elseif($_ -eq '|'){ "'ENTER'," } elseif($_ -eq '\'){ "'WAIT$Wait'," } else { "'$_'," } })) + $(if($Wait){ "'WAIT$Wait'," } else { '' }) + (-join ($After.ToCharArray() | ForEach-Object { if($_ -eq '~'){ "'ESC'," } elseif($_ -eq '|'){ "'ENTER'," } elseif($_ -eq '\'){ "'WAIT$Wait'," } else { "'$_'," } }))
$uf = Join-Path $sp "$tag-umoria"
if(Test-Path "$uf\test.sav"){ Remove-Item "$uf\test.sav" -Force }
pwsh -NoProfile -Command "& '$t\umoria.ps1' -Seed $Seed -Folder '$uf' -Steps 'SPACE','$([char](97+$Race))','m','ESC','$([char](97+$Class))','bob','ENTER','SPACE','SPACE','ESC',$jump'^x','SPACE','SPACE' *> '$uf.log'"
if(-not (Test-Path "$uf\test.sav")){ "Umoria made no saved game, see $uf.log"; return }
python -I "$t\umoria-save.py" "$uf\test.sav" | Set-Content "$uf\state.txt"
# the messages each game kept, beside its state, to find where the two parted when a section comes out different
python -I "$t\umoria-save.py" "$uf\test.sav" --messages | Set-Content "$uf\messages.txt"

# --- ZXMoria: the same, and its memory read as soon as it is there
$zf = Join-Path $sp "$tag-zxmoria"; $null = New-Item $zf -ItemType Directory -Force
Get-ChildItem $zf -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
Copy-Item $Nex "$zf\poc4uat.nex" -Force
# N.B: dated now, so Start-Game does not take it for out of date and put the project's own (unseeded) build in its place
(Get-Item "$zf\poc4uat.nex").LastWriteTime = Get-Date
. "$t\lib.ps1"; . "$t\play-lib.ps1"; . "$t\zxmoria-state.ps1"; $script:Proj = "$tag-zxmoria"
# the keys of -First or -Keys typed into ZXMoria: ~ ESCAPE, | ENTER, ^ and a letter Ctrl and the letter, anything else itself
# -WaitReady, for a key thought lost: each key waits until ZXMoria is waiting for one, in place of the 0.8 seconds between
# keys, a key pressed and let go while the game works out a long turn would never be seen; waiting is the PC in the core's
# s_core_get_key(), fub_core_scan_key() or s_core_wait_for_vblank(), twice running, their addresses from the core.map of
# the build in -Nex (its build folder beside it), or with no map the old 0.8 seconds
# N.B: about three times as slow, each look at the PC is a ZRCP call of its own; a turn short on 20 October 2026 looked like
# a lost key and was not (a -more- Moria never shows), so it is not the default
$readyAt = @()
$map = Join-Path (Split-Path $Nex) 'build\core.map'
if($WaitReady -and (Test-Path $map)){
    $labels = @{}
    foreach($line in Get-Content $map){ if($line -match '^([0-9A-F]{4}): \._(\w+)$'){ $labels[$Matches[2]] = [Convert]::ToInt32($Matches[1], 16) } }
    foreach($name in 's_core_get_key', 'fub_core_scan_key', 's_core_wait_for_vblank'){
        if($labels.ContainsKey($name) -and $labels.ContainsKey("${name}__leave")){ $readyAt += ,@($labels[$name], ($labels["${name}__leave"] + 16)) }
    }
}
function Waiting {
    $pc = (Z 'get-registers') -join ' '
    if($pc -notmatch 'PC=([0-9A-Fa-f]{4})'){ return $false }
    $pc = [Convert]::ToInt32($Matches[1], 16)
    foreach($r in $readyAt){ if($pc -ge $r[0] -and $pc -le $r[1]){ return $true } }
    $false
}
function Wait-Ready {
    if(-not $readyAt){ Start-Sleep -Milliseconds 800; return }
    Start-Sleep -Milliseconds 200
    $sw = [Diagnostics.Stopwatch]::StartNew(); $seen = 0
    while($seen -lt 2 -and $sw.Elapsed.TotalSeconds -lt 30){ if(Waiting){ $seen++ } else { $seen = 0 }; Start-Sleep -Milliseconds 100 }
}
function Wait-Still {
    # over when the turn has stood still for three seconds, whether a count or a rest ran its course or something broke it off
    $last = -1; $still = 0
    while($still -lt 6){ Start-Sleep -Milliseconds 500; $now = Turn; if($now -eq $last){ $still++ } else { $still = 0; $last = $now } }
}
function Type-Keys([string]$keys){
    for($i = 0; $i -lt $keys.Length; $i++){
        $k = $keys[$i]
        if($k -eq '\'){ Start-Sleep 2; Wait-Still; continue }
        Wait-Ready
        if($k -eq '~'){ Esc } elseif($k -eq '|'){ Enter } elseif($k -eq '^' -and $i + 1 -lt $keys.Length){ $i++; Ctrl "$($keys[$i])" } else { Press "$k" }
    }
    Wait-Ready
}
try {
    # N.B: the emulator gives up after 30 minutes, a long comparison needs more than the 10 it had (found 22 October 2026: a
    # character starved to death over 26 rests, the emulator had gone before ZXMoria's memory could be read)
    $ok = Start-Game -Class $Class -Race $Race -ExitAfter 1800
    if($ok -and $Level){ Wizard; $ok = Goto-Level $Level }
    if($ok -and $First){ Type-Keys $First }
    if($ok -and $Rest){
        # the rest is over when the turn has stood still for three seconds, whether it ran its course or something broke it off
        Press 'R'; $ok = WaitFor 0 0 'Rest for how long?' 10; Type_ "$Rest"
        $last = -1; $still = 0
        while($ok -and $still -lt 6){ Start-Sleep -Milliseconds 500; $now = Turn; if($now -eq $last){ $still++ } else { $still = 0; $last = $now } }
        # and the two ESCAPEs Umoria is given after its rest, for a -more- the rest ended on, which can be in the middle
        # of a turn (found 20 October 2026: slowness wearing off ended a rest, ZXMoria was read at its -more-, before the
        # turn had put the speed flag back, and the game section came out different)
        if($ok){ Type-Keys '~~' }
    }
    if($ok -and $Keys){ Type-Keys $Keys; Start-Sleep 2 }
    if($ok -and $Wait){
        # as for a rest: over when the turn has stood still for three seconds
        Wait-Still
    }
    if($ok -and $After){ Type-Keys $After; Start-Sleep 2 }
    if(-not $ok){ 'ZXMoria did not reach the level' } else { Get-ZxState | Set-Content "$zf\state.txt"; Get-ZxMessages | Set-Content "$zf\messages.txt"; "$script:ZxSeed" | Set-Content "$zf\seed.txt" }
} finally { Stop-Game }
# N.B: the game must have run the seeded build it was given: on 16 October 2026, two comparisons run one after the other
# in the same PowerShell session, the second ran the project's own unseeded build instead (Start-Game had put it in the
# folder), and came out all different, how is not known, so the file the game ran is checked against the one given
$wrongBuild = (Get-FileHash $Nex).Hash -ne (Get-FileHash "$zf\poc4uat.nex").Hash

# --- the two, a section at a time
function Sections($path){
    $h = [ordered]@{}; $name = ''
    foreach($line in Get-Content $path){ if($line -match '^# (.*?)(:|$)'){ $name = $Matches[1]; $h[$name] = @($line) } elseif($name){ $h[$name] += $line } }
    $h
}
$u = Sections "$uf\state.txt"; $z = Sections "$zf\state.txt"
"${tag}:"
if($wrongBuild){ "    WRONG BUILD: ZXMoria did not run $Nex, the comparison below means nothing, run it again on its own" }
foreach($name in $u.Keys){
    $a = @($u[$name]); $b = @($z[$name])
    $d = @(Compare-Object $a $b -SyncWindow 1000)
    if($d.Count -eq 0){ "    {0,-22} the same ({1} lines)" -f $name, ($a.Count - 1) } else {
        "    {0,-22} DIFFERENT: Umoria {1} lines, ZXMoria {2}" -f $name, ($a.Count - 1), ($b.Count - 1)
        $d | Select-Object -First 8 | ForEach-Object { "        {0} {1}" -f $(if($_.SideIndicator -eq '<='){ 'Umoria ' } else { 'ZXMoria' }), $_.InputObject }
    }
}
# the messages each kept for Ctrl-P, the last 22: Umoria's save adds "Saving game..." to its own, as a message of its
# own (taking one of the 22 places, so the oldest of ours is left out) or put after the last one on the same line
# (added 21 October 2026, ZXMoria's history had been missing "You are wielding ..." since the start, unseen)
if((Test-Path "$uf\messages.txt") -and (Test-Path "$zf\messages.txt")){
    $a = @(Get-Content "$uf\messages.txt" | ForEach-Object { $_ -replace '  Saving game\.\.\.$', '' } | Where-Object { $_ -ne 'Saving game...' })
    # N.B: the one ZXMoria has on show is marked "(showing)", Moria's is in its history already, it stores a message as
    # it prints it, so the mark comes off (added 21 October 2026, it showed as a difference in every case that ended
    # on a message)
    $b = @(Get-Content "$zf\messages.txt" | ForEach-Object { $_ -replace '^\(showing\) ', '' })
    if($b.Count -gt $a.Count){ $b = @($b | Select-Object -Last $a.Count) }
    $d = @(Compare-Object $a $b -SyncWindow 1000)
    if($d.Count -eq 0){ "    {0,-22} the same ({1} lines)" -f 'messages', $a.Count } else {
        "    {0,-22} DIFFERENT: Umoria {1} lines, ZXMoria {2}" -f 'messages', $a.Count, $b.Count
        $d | Select-Object -First 8 | ForEach-Object { "        {0} {1}" -f $(if($_.SideIndicator -eq '<='){ 'Umoria ' } else { 'ZXMoria' }), $_.InputObject }
    }
}
