# builds ZXMoria with a fixed seed, for comparing with Umoria, without touching the project's own build:
# -Workspace is a second copy of the whole workspace (the tools and a clone of this project in projects\poc4uat),
# onetime-setup.ps1 makes one, its clone is brought up to date with this project, given the seed, and built there
# prints where the nex file is
param([uint32]$Seed = 12345, [string]$Workspace)
$here = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$there = Join-Path $Workspace 'projects\poc4uat'
if(-not (Test-Path (Join-Path $there '.git'))){ throw "no clone of the project at $there" }
git -C $there checkout -q -- . 2>&1 | Out-Null
git -C $there pull -q $here 2>&1 | Out-Null
$f = Join-Path $there 'src\constants.bas'; $c = [IO.File]::ReadAllText($f)
[IO.File]::WriteAllText($f, [regex]::Replace($c, '#define UL_GAME_FIXED_SEED(\s+)\d+', "#define UL_GAME_FIXED_SEED`${1}$Seed"))
pwsh -NoProfile -File (Join-Path $there 'build.ps1') -NoRun *> $null
if($LASTEXITCODE -ne 0){ throw "the build failed, see $there\build.log" }
$out = Join-Path $there "poc4uat-seed$Seed.nex"; Copy-Item (Join-Path $there 'poc4uat.nex') $out -Force
$out
