# the night's testing, as sdo set it out on 14 October 2026, everything in build\test\nightly-<date and time>:
#   1  a fresh, full build (build.ps1 -Full -NoRun), and the commit it was built from
#   2  fresh za and zb cards, made in the night's own folder from poc4uat-base.mmc as build.ps1 makes them (sdo's own
#      poc4uat-za.mmc and poc4uat-zb.mmc are not touched)
#   3  on each of zf, za and zb: a character of random race, sex and class to the town, saved, the game ended; started
#      again and loaded (its sheet must be the same), switched off without saving; started again and loaded again,
#      see lifecycle.ps1
#   4  from then on zf only, round after round until -Until: a new character of random race, sex and class shops (up to
#      10 rations and 10 torches, then armour, bartering from 50%) and goes slaying until it dies or its time is up,
#      see play.ps1
# report.md, rewritten after every round, says how it went: the build, the save tests, each round, anything that
# went wrong (a hang, the emulator gone), and the messages seen, those never seen on an earlier night marked new
#   tools\test\nightly.ps1                      until 06:30
#   tools\test\nightly.ps1 -Until 07:15 -HuntMinutes 25
param([string]$Until = '06:30', [double]$ShopMinutes = 4, [double]$HuntMinutes = 20, [switch]$NoBuild)
$ErrorActionPreference = 'Continue'
$Project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Night = Join-Path $Project ("build\test\nightly-" + [DateTime]::Now.ToString('yyyy-MM-dd-HHmm'))
$null = New-Item $Night -ItemType Directory -Force
$Log = Join-Path $Night 'nightly.log'
function Log([string]$t){ $line = "$([DateTime]::Now.ToString('HH:mm:ss'))  $t"; $line; Add-Content -Path $Log -Value $line }

# the end of the night: -Until today, or tomorrow if that time has gone
$End = [DateTime]::Today.Add([TimeSpan]::Parse($Until)); if($End -le [DateTime]::Now){ $End = $End.AddDays(1) }

# keep the PC awake all night
Add-Type -Namespace Night -Name Power -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);' -ErrorAction SilentlyContinue
$null = [Night.Power]::SetThreadExecutionState([uint32]'0x80000001')       # ES_CONTINUOUS | ES_SYSTEM_REQUIRED

function No-Emulators { Get-Process zesarux -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }

$Info = [ordered]@{ Started = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm'); Until = $End.ToString('yyyy-MM-dd HH:mm'); Commit = ''; Build = '' }
$Info.Commit = (git -C $Project log -1 --format='%h %s' 2>$null)
$Info.Dirty = ((git -C $Project status --short 2>$null) | Measure-Object).Count

function Report {
    # report.md, from what is in the night's folder so far
    $life = @(); if(Test-Path "$Night\lifecycle.jsonl"){ $life = @(Get-Content "$Night\lifecycle.jsonl" | ForEach-Object { $_ | ConvertFrom-Json }) }
    $rounds = @(); if(Test-Path "$Night\rounds.jsonl"){ $rounds = @(Get-Content "$Night\rounds.jsonl" | ForEach-Object { $_ | ConvertFrom-Json }) }
    $md = New-Object Collections.Generic.List[string]
    $md.Add("# ZXMoria night test, $($Info.Started)"); $md.Add('')
    $md.Add("- Until: $($Info.Until)"); $md.Add("- Built from: $($Info.Commit)$(if($Info.Dirty){ " (and $($Info.Dirty) files changed since)" })"); $md.Add("- Build: $($Info.Build)"); $md.Add('')
    $md.Add('## Saving and loading, each way of starting'); $md.Add('')
    $md.Add('| Way | Character | Made | Saved | Loaded | Same | Loaded again | Same |'); $md.Add('|---|---|---|---|---|---|---|---|')
    foreach($l in $life){ $md.Add("| $($l.Way) | $($l.Name), $($l.Sex) $($l.Race) $($l.Class) | $($l.Made) | $($l.Saved) | $($l.Loaded) | $($l.Same1) | $($l.Reloaded) | $($l.Same2) |") }
    $md.Add('')
    $md.Add("## Rounds of play ($($rounds.Count))"); $md.Add('')
    if($rounds.Count){
        $md.Add("- Ended: $(($rounds | Group-Object End | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', ')")
        $md.Add("- Kills $(($rounds | Measure-Object Kills -Sum).Sum), turns $(($rounds | Measure-Object Turns -Sum).Sum), deepest $(($rounds | Measure-Object Deepest -Maximum).Maximum) (x 50 feet), highest level $(($rounds | Measure-Object Level -Maximum).Maximum)")
        $md.Add("- Races: $(($rounds | Group-Object Race | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', ')")
        $md.Add("- Classes: $(($rounds | Group-Object Class | ForEach-Object { "$($_.Name) $($_.Count)" }) -join ', ')")
        $md.Add('')
        $md.Add('| # | Started | Character | Ended | Level | Exp | Deepest | Kills | Turns | Bought | Killed by |'); $md.Add('|---|---|---|---|---|---|---|---|---|---|---|')
        $i = 0; foreach($r in $rounds){ $i++; $md.Add("| $i | $($r.Start) | $($r.Name), $($r.Sex) $($r.Race) $($r.Class) | $($r.End) | $($r.Level) | $($r.Exp) | $($r.Deepest) | $($r.Kills) | $($r.Turns) | $($r.Bought) for $($r.Spent) | $($r.KilledBy) |") }
    }
    $md.Add('')
    $bad = @($rounds | Where-Object { $_.End -notin @('died', 'time up') })
    $md.Add('## Anything that went wrong'); $md.Add('')
    if(-not $bad.Count -and -not @($life | Where-Object { -not ($_.Made -and $_.Saved -and $_.Loaded -and $_.Same1 -and $_.Reloaded -and $_.Same2) }).Count){ $md.Add('Nothing.') }
    foreach($b in $bad){ $md.Add("- $($b.Start) $($b.Name): $($b.End), see $($b.Folder)") }
    foreach($l in $life){ if(-not ($l.Made -and $l.Saved -and $l.Loaded -and $l.Same1 -and $l.Reloaded -and $l.Same2)){ $md.Add("- saving and loading on $($l.Way) did not all go as it should, see lifecycle-$($l.Way).log $($l.Note)") } }
    $md.Add('')
    # the messages: all of them with how often, those not seen on any earlier night marked new
    if(Test-Path "$Night\messages-raw.txt"){
        $count = @{}
        foreach($line in Get-Content "$Night\messages-raw.txt"){ $p = $line -split "`t", 2; if($p.Count -eq 2){ $count[$p[1]] = [int]$count[$p[1]] + [int]$p[0] } }
        $old = @{}
        Get-ChildItem (Split-Path $Night) -Directory -Filter 'nightly-*' | Where-Object { $_.FullName -ne $Night } | ForEach-Object {
            if(Test-Path "$($_.FullName)\messages.txt"){ Get-Content "$($_.FullName)\messages.txt" | ForEach-Object { $p = $_ -split "`t", 2; if($p.Count -eq 2){ $old[$p[1]] = $true } } } }
        ($count.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Value)`t$($_.Key)" }) | Set-Content "$Night\messages.txt"
        $new = @($count.Keys | Where-Object { -not $old.ContainsKey($_) } | Sort-Object)
        $md.Add("## Messages: $($count.Count) different, $($new.Count) never seen on an earlier night"); $md.Add('')
        foreach($m in $new){ $md.Add("- $m ($($count[$m]))") }
    }
    $md | Set-Content "$Night\report.md"
}

Log "the night's testing, until $($Info.Until), in $Night"
No-Emulators

# --- 1: the build
if(-not $NoBuild){
    Log 'a full build...'
    pwsh -NoProfile -File (Join-Path $Project 'build.ps1') -Full -NoRun *> "$Night\build.log"
    $Info.Build = $(if($LASTEXITCODE -eq 0){ 'built, status 0' } else { "FAILED, status $LASTEXITCODE, see build.log" })
    Log "...$($Info.Build)"
    if($LASTEXITCODE -ne 0){ Report; exit 1 }
} else { $Info.Build = 'not built tonight (-NoBuild)' }
$Info.Nex = (Get-Item (Join-Path $Project 'poc4uat.nex')).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
Report

# --- 2 and 3: saving and loading, each way of starting
foreach($way in 'zf', 'za', 'zb'){
    Log "saving and loading on $way..."
    pwsh -NoProfile -File (Join-Path $PSScriptRoot 'lifecycle.ps1') -Way $way -Dir (Join-Path $Night "lifecycle-$way") -Result "$Night\lifecycle.jsonl" -Away *> "$Night\lifecycle-$way.out"
    No-Emulators
    Log "...$((Get-Content "$Night\lifecycle.jsonl" -ErrorAction SilentlyContinue | Select-Object -Last 1))"
    Report
}

# --- 4: rounds of play until the end of the night
$n = 0
while([DateTime]::Now.AddMinutes($ShopMinutes + $HuntMinutes + 2) -lt $End){
    $n++
    $dir = Join-Path $Night ('round-{0:D2}' -f $n)
    Log "round $n..."
    pwsh -NoProfile -File (Join-Path $PSScriptRoot 'play.ps1') -Dir $dir -ShopMinutes $ShopMinutes -HuntMinutes $HuntMinutes -Result "$Night\rounds.jsonl" -Messages "$Night\messages-raw.txt" -Away *> "$dir.out"
    No-Emulators
    Log "...$((Get-Content "$Night\rounds.jsonl" -ErrorAction SilentlyContinue | Select-Object -Last 1))"
    # keep the folders small: the nex file is the same in every round
    Remove-Item (Join-Path $dir 'poc4uat.nex') -ErrorAction SilentlyContinue
    Report
}
Log "the night is over: $n rounds"
Report
$null = [Night.Power]::SetThreadExecutionState([uint32]'0x80000000')
