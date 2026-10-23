# for each level given, the seeded ZXMoria started afresh with the character given, wizard mode and Ctrl-D to the level,
# exactly as compare-level.ps1 reaches it, its state written to <Out>\level<n>.txt, and find-path.py asked for a way to
# each of the targets: a category (75 76 potions, 70 71 scrolls, 65 wands, 55 staffs, 101 102 traps, 105 closed doors,
# 109 secret doors, 103 rubble ...), or o and an object's number, several to a target with spaces, e.g. -Targets '101 102'
# prints, for each level, the walk to the nearest of each target, or that there is none in reach
# N.B: -Class is the place in the list of classes the race may have, as Start-Game types it, see vary-race-class notes
# -Nex the seeded build, -Out a folder for the states
param([int]$Race = 0, [int]$Class = 0, [int[]]$Levels = 1..10, [string[]]$Targets = @('75 76'), [Parameter(Mandatory)][string]$Nex, [Parameter(Mandatory)][string]$Out)
$null = New-Item $Out -ItemType Directory -Force
foreach ($n in $Levels) {
    $file = Join-Path $Out "r$Race-c$Class-level$n.txt"
    if (-not (Test-Path $file)) {
        pwsh -NoProfile -Command {
            param($n, $nex, $file, $race, $class, $here)
            . "$here\lib.ps1"; . "$here\play-lib.ps1"; . "$here\zxmoria-state.ps1"
            $script:Away = $true; $script:Proj = "level-scan-r$race-c$class-$n"
            $dir = "$script:Work\$script:Proj"; $null = New-Item $dir -ItemType Directory -Force
            Get-ChildItem $dir -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
            Copy-Item $nex "$dir\poc4uat.nex" -Force
            (Get-Item "$dir\poc4uat.nex").LastWriteTime = Get-Date
            try { if ((Start-Game -Race $race -Class $class -ExitAfter 600)) { Wizard; if (Goto-Level $n) { Get-ZxState | Set-Content $file } } } finally { Stop-Game }
        } -args $n, $Nex, $file, $Race, $Class, $PSScriptRoot | Out-Null
    }
    if (-not (Test-Path $file)) { "level ${n}: not reached"; continue }
    $line = "level ${n}:"
    foreach ($t in $Targets) { $line += " [$t] " + (python -I (Join-Path $PSScriptRoot 'find-path.py') $file ($t -split ' ')) }
    $line
}
