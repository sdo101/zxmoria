# takes pictures of the map in colour, for looking at the colours of things (colours.txt): the game is started, taken
# to a level by the wizard's Ctrl-D, the level lit by the wizard's Ctrl-L so that its monsters and things are on view,
# and the screen drawn as a PNG by render-screen.py from the screen's cells, the font and the palette
# -Nex the build to run (the project's own by default), -Out the folder for the pictures, -Levels which levels
# N.B: written 22 October 2026, ZEsarUX's remote commands cannot save a picture of the screen
param([string]$Nex = (Join-Path $PSScriptRoot '..\..\poc4uat.nex'), [Parameter(Mandatory)][string]$Out, [int[]]$Levels = @(5))
. "$PSScriptRoot\lib.ps1"; . "$PSScriptRoot\play-lib.ps1"
$script:Away = $true; $script:Proj = 'colour-shot'
$dir = "$script:Work\$script:Proj"; $null = New-Item $dir -ItemType Directory -Force
Get-ChildItem $dir -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
Copy-Item $Nex "$dir\poc4uat.nex" -Force
(Get-Item "$dir\poc4uat.nex").LastWriteTime = Get-Date
$null = New-Item $Out -ItemType Directory -Force
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Hex-To-File([string]$hex, [string]$file){
    $b = New-Object byte[] ($hex.Length / 2)
    for($i = 0; $i -lt $b.Length; $i++){ $b[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    [IO.File]::WriteAllBytes($file, $b)
}
function Shot([string]$name){
    $cells = ''; for($at = 0; $at -lt 5120; $at += 2048){ $cells += (Page 11 $at ([Math]::Min(2048, 5120 - $at))) }
    $font = Page 10 0 2048
    Hex-To-File $cells "$dir\cells.bin"; Hex-To-File $font "$dir\font.bin"
    python -I "$PSScriptRoot\render-screen.py" "$dir\cells.bin" "$dir\font.bin" "$root\src\load.bas" "$root\build\data\gametables.bin" (Join-Path $Out "$name.png") 2
}
try {
    if(Start-Game -ExitAfter 900){
        Wizard
        Shot 'town'
        foreach($n in $Levels){
            if(Goto-Level $n){
                Start-Sleep 2; Ctrl 'l'; Start-Sleep 3; $null = Msgs
                # Ctrl-L puts the light out instead if the player's square was lit already (a lit room), Moria's
                # wizardLightUpDungeon(), so a screen with hardly a wall on it gets a second press
                $walls = ([regex]::Matches((Page 11 0 2048) + (Page 11 2048 2048), '(?i)23[0-9a-f]{2}')).Count
                if($walls -lt 100){ Ctrl 'l'; Start-Sleep 3; $null = Msgs }
                Shot "level$n"
            }
        }
    } else { 'the game did not start' }
} finally { Stop-Game }
