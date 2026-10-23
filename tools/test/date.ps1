# does the game get the date? a character is made and its date of birth read out of memory, gsl_player_birth, the date
# in its top half and the time in its bottom half as files are dated, or a number with its top bit set if no clock answered
# -Sd boots NextZXOS from the scratch card, without it the emulator is given the nex file and answers the system calls itself
# -Log keeps what the emulator prints about the clock chip, its i2c messages, in build\test\date.log
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([switch]$Sd, [switch]$Log)
. "$PSScriptRoot\lib.ps1"; $script:Proj = 'date'
if($Log){
    $script:EmuCfg = "$script:Work\date-emu.cfg"; $script:EmuLog = "$script:Work\date.log"
    (Get-Content "$script:Project\src\zesarux.cfg" | Where-Object { $_ -notmatch 'debug-filter|^--verbose' }) + '--verbose 4' + '--verbose-always-console' | Set-Content $script:EmuCfg -Encoding Ascii
}
try {
    $ok = Start-Game -Class 0 -Race 0 -ExitAfter 600 -Sd:$Sd
    "in the town: $ok"
    if(-not $ok){ Screen 0 23 | Where-Object { $_.Length -gt 3 }; Z 'get-registers' }
    $time = Peek16 0xD81C; $date = Peek16 0xD81E
    if($date -band 0x8000){ "no clock: the birth is {0:X4}{1:X4}" -f $date, $time }
    else { "born {0:D4}-{1:D2}-{2:D2} {3:D2}:{4:D2}:{5:D2}" -f (1980 + ($date -shr 9)), (($date -shr 5) -band 15), ($date -band 31), ($time -shr 11), (($time -shr 5) -band 63), (($time -band 31) * 2) }
} finally { Stop-Game }
if($Log){ Start-Sleep 1; Select-String -Path $script:EmuLog, "$script:EmuLog.err" -Pattern 'DS1307|RTC|i2c' -ErrorAction SilentlyContinue | Select-Object -First 40 | ForEach-Object Line }
