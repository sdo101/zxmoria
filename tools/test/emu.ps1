# starts the scratch build in ZEsarUX as a hidden background window with the remote protocol on.
# ZEsarUX grabs keyboard focus when it starts, even hidden, so for the first few seconds this hides its window and hands
# focus back to whatever had it. Returns the process, or $null if focus could not be handed back (the emulator is stopped).
param([int]$ExitAfter = 60, [string[]]$ExtraCfg = @(), [string]$WorkDir = "", [string]$BaseCfg = (Join-Path $PSScriptRoot '..\..\src\zesarux.cfg'), [string]$Nex = '', [switch]$AllowFocus, [string]$Log = '')
# -Log is a file for what the emulator prints, give it --verbose-always-console in -ExtraCfg to have its messages there
$s = Join-Path $PSScriptRoot '..\..\build\test'; $null = New-Item $s -ItemType Directory -Force; $s = (Resolve-Path $s).Path
Add-Type -Namespace Emu -Name Win -MemberDefinition '[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr h, out uint pid); [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int cmd); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);' -ErrorAction SilentlyContinue
Get-Content $BaseCfg | Where-Object { $_ -notmatch 'mmc|breakpoint' } | Set-Content "$s\fast-test.cfg" -Encoding Ascii
Add-Content "$s\fast-test.cfg" "--enable-remoteprotocol`r`n--exit-after $ExitAfter" -Encoding Ascii; foreach ($x in $ExtraCfg) { Add-Content "$s\fast-test.cfg" $x -Encoding Ascii }
$prev = [Emu.Win]::GetForegroundWindow()
$zargs = @('--configfile', "`"$s\fast-test.cfg`""); if ($Nex) { $zargs += $Nex }
# the emulator is in a folder for each version (zesarux\13.0), the newest is used, N.B: the names compared as [version]s
# made up to four parts with 0s, a [version] of fewer parts leaves the others at -1 and 13.0 is then less than 13.0.0
$zroot = Join-Path $PSScriptRoot '..\..\..\..\zesarux'
$zdir = Get-ChildItem $zroot -Directory | Where-Object { $_.Name -match '^\d+(\.\d+){0,3}$' -and (Test-Path (Join-Path $_.FullName 'zesarux.exe')) } |
    Sort-Object { $p = @($_.Name.Split('.')); while ($p.Count -lt 4) { $p += '0' }; [version]($p -join '.') } -Descending | Select-Object -First 1
if (-not $zdir) { throw "no version of ZEsarUX in $zroot" }
$sp = @{ FilePath = (Join-Path $zdir.FullName 'zesarux.exe'); ArgumentList = $zargs; WorkingDirectory = $(if ($WorkDir) { $WorkDir } else { "$s\proj" }); PassThru = $true; WindowStyle = 'Hidden' }
if ($Log) { $sp.RedirectStandardOutput = $Log; $sp.RedirectStandardError = "$Log.err" }
$p = Start-Process @sp
$grabs = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt 4000) {
    $h = [Emu.Win]::GetForegroundWindow(); $fp = 0; [void][Emu.Win]::GetWindowThreadProcessId($h, [ref]$fp)
    if ($fp -eq $p.Id) { $grabs++; [void][Emu.Win]::ShowWindow($h, 6); [void][Emu.Win]::SetForegroundWindow($prev) }
    Start-Sleep -Milliseconds 40
}
$fp = 0; [void][Emu.Win]::GetWindowThreadProcessId([Emu.Win]::GetForegroundWindow(), [ref]$fp)
# if nothing had the keyboard before the emulator started (the screen is locked, or everything is minimised) there is nobody to hand it back to, and nobody typing
if ($fp -eq $p.Id -and $AllowFocus) { [void][Emu.Win]::ShowWindow([Emu.Win]::GetForegroundWindow(), 6); Write-Host "emulator running, it kept the keyboard (allowed: nobody is at the machine)"; return $p }
if ($fp -eq $p.Id -and $prev -ne [IntPtr]::Zero) { Stop-Process -Id $p.Id -Force; Write-Host "emulator kept keyboard focus, stopped it"; return $null }
if ($fp -eq $p.Id) { Write-Host "emulator running in the background, minimised (nothing had the keyboard before it started)"; return $p }
Write-Host "emulator running in the background (focus grabs handed back: $grabs)"
$p

