# the same character made in the real Umoria and in ZXMoria, from the same seed, and their two character files compared
# N.B: the ZXMoria nex file in -Nex must have been built with UL_GAME_FIXED_SEED, in src\constants.bas, set to the same seed,
# build that somewhere else, a copy of the whole workspace say, the project's own nex file is for playing
# -Race and -Class are the letters of the two menus counted from 0, a class is its place among those the race may be
# e.g.   .\compare-umoria.ps1 -Seed 12345 -Nex <the seeded nex> -Race 3 -Class 1     a Halfling Mage
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([uint32]$Seed = 12345, [string]$Nex, [int]$Race = 0, [int]$Class = 0, [string]$Name = 'bob')
$t = $PSScriptRoot; $sp = Join-Path $PSScriptRoot '..\..\build\test'; $null = New-Item $sp -ItemType Directory -Force; $sp = (Resolve-Path $sp).Path
$tag = "seed$Seed-r$Race-c$Class"
# --- Umoria
$uf = Join-Path $sp "cmp-$tag-umoria"
pwsh -NoProfile -Command "& '$t\umoria.ps1' -Seed $Seed -Folder '$uf' -Steps 'SPACE','$([char](97+$Race))','m','ESC','$([char](97+$Class))','$Name','ENTER','SPACE','SPACE','ESC','SPACE','ESC','C','f','char.txt','ENTER','ESC','ESC' *> '$uf.log'"
# --- ZXMoria
$zf = Join-Path $sp "cmp-$tag-zxmoria"; $null = New-Item $zf -ItemType Directory -Force
Get-ChildItem $zf -File | Remove-Item -Force; Copy-Item $Nex "$zf\poc4uat.nex" -Force
. "$t\lib.ps1"; $script:Proj = "cmp-$tag-zxmoria"
try { $ok = Start-Game -Class $Class -Race $Race -ExitAfter 300; Str 'C'; Start-Sleep 2; Key 102; Start-Sleep 5 } finally { Stop-Game }
# --- the two files, with what is only layout taken out: runs of spaces, blank lines, the title Umoria's file has and
# ours has not, and the full stop we put after "Exp to Adv"
function Lines_($path){ if(-not (Test-Path $path)){ return @("(no file: $path)") }; Get-Content $path | ForEach-Object { ($_ -replace '\s+', ' ').Trim() -replace 'Exp to Adv\.? ?:', 'Exp to Adv:' -replace '^Title : .*?(CON : )', '$1' } | Where-Object { $_ } }
$u = @(Lines_ "$uf\char.txt"); $z = @(Lines_ "$zf\player-$Name.txt")
$d = @(Compare-Object $u $z)
"{0}: Umoria {1} lines, ZXMoria {2} lines, differences {3}   [{4}]" -f $tag, $u.Count, $z.Count, $d.Count, (($u | Select-Object -First 4 | ForEach-Object { $_ -replace '^(Name|Race|Sex|Class) : (\S+).*', '$2' }) -join ' ')
"    stats: " + (($u | Where-Object { $_ -match '(STR|INT|WIS|DEX|CON|CHR) :' } | ForEach-Object { if($_ -match '((STR|INT|WIS|DEX|CON|CHR) : \S+)$'){ $Matches[1] } }) -join ', ')
$d | ForEach-Object { "    $($_.SideIndicator) $($_.InputObject)" }


