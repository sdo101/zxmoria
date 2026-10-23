# the wizard's sample of random objects, Ctrl-B, made in the real Umoria and in ZXMoria from the same seed, and compared
# N.B: the ZXMoria nex file in -Nex must have been built with UL_GAME_FIXED_SEED, in src\constants.bas, set to the same seed
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([uint32]$Seed = 12345, [string]$Nex, [int]$Level = 10, [int]$Count = 40)
$t = $PSScriptRoot; $sp = Join-Path $PSScriptRoot '..\..\build\test'; $null = New-Item $sp -ItemType Directory -Force; $sp = (Resolve-Path $sp).Path
$tag = "objects-seed$Seed-l$Level-n$Count"

# --- Umoria: a Human Warrior, wizard mode, Ctrl-B, the level, how many, not only small ones, and the file's name
$uf = Join-Path $sp "$tag-umoria"
pwsh -NoProfile -Command "& '$t\umoria.ps1' -Seed $Seed -Folder '$uf' -Steps 'SPACE','a','m','ESC','a','bob','ENTER','SPACE','SPACE','ESC','^w','SPACE','y','SPACE','^b','$Level','ENTER','$Count','ENTER','n','objs.txt','ENTER','SPACE','SPACE','SPACE','SPACE' *> '$uf.log'"

# --- ZXMoria: the same
$zf = Join-Path $sp "$tag-zxmoria"; $null = New-Item $zf -ItemType Directory -Force
Get-ChildItem $zf -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
Copy-Item $Nex "$zf\poc4uat.nex" -Force
. "$t\lib.ps1"; $script:Proj = "$tag-zxmoria"
try {
    $ok = Start-Game -Class 0 -Race 0 -ExitAfter 2400
    Wizard
    Ctrl 'b'; Start-Sleep 1; Type_ "$Level"; Start-Sleep 1; Type_ "$Count"; Start-Sleep 1; Key 110; Start-Sleep 1; Type_ 'objs.txt'
    # N.B: about two seconds an object in the emulator, and a killed emulator leaves the file cut short
    $ok = WaitFor 0 0 'Completed.' 2000; if(-not $ok){ 'ZXMoria did not finish its sample in time' }
} finally { Stop-Game }

# --- the two files, a line at a time, runs of spaces apart
function Lines_($path){
    if(-not (Test-Path $path)){ return @("(no file: $path)") }
    Get-Content $path | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ }
}
$u = @(Lines_ "$uf\objs.txt"); $z = @(Lines_ "$zf\objs.txt")
$same = 0; $n = [Math]::Min($u.Count, $z.Count)
while($same -lt $n -and $u[$same] -eq $z[$same]){ $same++ }
"{0}: Umoria {1} lines, ZXMoria {2} lines, the same for the first {3}" -f $tag, $u.Count, $z.Count, $same
if($same -lt [Math]::Max($u.Count, $z.Count)){
    foreach($i in $same..([Math]::Min($same + 5, [Math]::Max($u.Count, $z.Count) - 1))){ "    line {0}:  Umoria [{1}]   ZXMoria [{2}]" -f ($i + 1), $u[$i], $z[$i] }
} else {
    $u | Select-Object -Skip 3 -First 6 | ForEach-Object { "    $_" }
}

