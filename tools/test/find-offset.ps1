# when the wizard's object sample differs between Umoria and ZXMoria for the same seed: how many random numbers apart
# were the two games when it was asked for? In one ZXMoria session the generator is put back to where it was, moved
# on or back by each of a range of steps, and three objects are sampled each time, to set against Umoria's first three
# N.B: the nex file must have been built with UL_GAME_FIXED_SEED set to the seed, see compare-umoria.ps1
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([string]$Nex, [string]$UmoriaFile, [int]$From = -15, [int]$To = 15, [int]$Level = 10)
$t = $PSScriptRoot; $sp = Join-Path $PSScriptRoot '..\..\build\test'; $null = New-Item $sp -ItemType Directory -Force; $sp = (Resolve-Path $sp).Path
$zf = Join-Path $sp 'find-offset'; $null = New-Item $zf -ItemType Directory -Force
Get-ChildItem $zf -File | ForEach-Object { [IO.File]::Delete($_.FullName) }
Copy-Item $Nex "$zf\poc4uat.nex" -Force
# Moria's generator, rnd() in rng.cpp: the seed times 16807, modulo 2^31 - 1, and the same backwards
$M = [bigint]2147483647; $A = [bigint]16807; $Ainv = [bigint]::ModPow($A, $M - 2, $M)
function Step_([bigint]$seed, [int]$k){ if($k -ge 0){ ($seed * [bigint]::ModPow($A, $k, $M)) % $M } else { ($seed * [bigint]::ModPow($Ainv, -$k, $M)) % $M } }
$want = @(Get-Content $UmoriaFile | Where-Object { $_.Trim() } | Select-Object -Skip 3 -First 3 | ForEach-Object { ($_ -replace '\s+', ' ').Trim() })
"Umoria's first three: $($want -join ' / ')"
. "$t\lib.ps1"; $script:Proj = 'find-offset'
try {
    $ok = Start-Game -Class 0 -Race 0 -ExitAfter 900
    Wizard
    $h = (Z 'read-memory C200H 4' | Where-Object { $_ -notmatch '^###' -and $_ })
    $h = "$h".Trim(); $base = [bigint][uint32]('0x' + $h.Substring(6,2) + $h.Substring(4,2) + $h.Substring(2,2) + $h.Substring(0,2))
    "the generator as the game stands: $base"
    $n = 0
    foreach($k in $From..$To){
        $v = [uint32](Step_ $base $k)
        Poke8 0xC200 ($v -band 255); Poke8 0xC201 (($v -shr 8) -band 255); Poke8 0xC202 (($v -shr 16) -band 255); Poke8 0xC203 (($v -shr 24) -band 255)
        $name = "f$n.txt"; $n++
        Ctrl 'b'; Start-Sleep -Milliseconds 600; Type_ "$Level"; Start-Sleep -Milliseconds 600; Type_ '3'; Start-Sleep -Milliseconds 600; Key 110; Start-Sleep -Milliseconds 600; Type_ $name
        $ok = WaitFor 0 0 'Completed.' 60; Key 32; Start-Sleep -Milliseconds 500
        $got = @(Get-Content "$zf\$name" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() } | Select-Object -Skip 3 -First 3 | ForEach-Object { ($_ -replace '\s+', ' ').Trim() })
        $match = 0; while($match -lt 3 -and $got[$match] -eq $want[$match]){ $match++ }
        "{0,4} steps: {1} of 3 the same   {2}" -f $k, $match, ($got -join ' / ')
    }
} finally { Stop-Game }
