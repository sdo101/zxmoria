# a character's life across saves, on one of the three ways of starting the game:
#   zf  the emulator given the nex file, its files in the folder (no NextZXOS)
#   za  NextZXOS booting a card whose autoexec.bas starts the game
#   zb  NextZXOS booting a card with no autoexec.bas, the game started from the Browser
# 1: a new character, of random race, sex and class, to the town; its sheet kept; saved (Ctrl-X), the game ends
# 2: the game again; the character loaded from the saved game; its sheet must be the same; then switched off, not saved
# 3: the game again; the character must still load, and its sheet still be the same; saved again (Ctrl-X)
# each save shows the high scores, with the character in them as "(saved)", once only however often it is saved, as Moria's
# -Dir is the folder for it (the card is made fresh there for za and zb, from poc4uat-base.mmc, as build.ps1 makes them)
# -Result <file> has a line of JSON added: which way, who, and whether each step did what it should
param([Parameter(Mandatory)][ValidateSet('zf', 'za', 'zb')][string]$Way, [Parameter(Mandatory)][string]$Dir, [string]$Result = '', [switch]$Away)
. (Join-Path $PSScriptRoot 'lib.ps1'); . (Join-Path $PSScriptRoot 'play-lib.ps1')
$script:Away = [bool]$Away
$null = New-Item $Dir -ItemType Directory -Force
$LogFile = Join-Path $Dir "lifecycle-$Way.log"
function Log([string]$t){ $line = "$([DateTime]::Now.ToString('HH:mm:ss'))  $t"; $line; Add-Content -Path $LogFile -Value $line }
$hdf = Join-Path $script:Project '..\..\tools\hdfmonkey.exe'
$out = [ordered]@{ Way = $Way; Name = ''; Race = ''; Sex = ''; Class = ''; Made = $false; Saved = $false; Loaded = $false; Same1 = $false; Reloaded = $false; Same2 = $false; Note = '' }

# --- the card, for za and zb
$Card = Join-Path $Dir "$Way.mmc"
if($Way -ne 'zf'){
    Copy-Item (Join-Path $script:Project 'poc4uat-base.mmc') $Card -Force; Set-ItemProperty $Card IsReadOnly $false
    & $hdf rm $Card /nextzxos/autoexec.bas 2>&1 | Out-Null
    & $hdf put $Card (Join-Path $script:Project 'poc4uat.nex') /poc4uat.nex | Out-Null
    & $hdf put $Card (Join-Path $script:Project 'LICENSE') /zxmoria.lic | Out-Null
    if($Way -eq 'za'){ & $hdf put $Card (Join-Path $script:Project 'build\autoexec.bas') /nextzxos/autoexec.bas | Out-Null }
    Log "card made: $(( & $hdf ls $Card / ) -join ', ')"
} else {
    Copy-Item (Join-Path $script:Project 'poc4uat.nex') (Join-Path $Dir 'poc4uat.nex') -Force
}

function Start-Way {
    # the game started the chosen way, true once its title is on the screen
    if($Way -eq 'zf'){ $script:Emu = & "$script:S\emu.ps1" -ExitAfter 900 -WorkDir $Dir -Nex poc4uat.nex -AllowFocus:$script:Away }
    else { $script:Emu = & "$script:S\emu.ps1" -ExitAfter 900 -WorkDir $Dir -AllowFocus:$script:Away -ExtraCfg @('--enable-mmc', '--enable-divmmc-ports', "--mmc-file $Card") }
    if(-not $script:Emu){ Log 'the emulator did not start'; return $false }
    if($Way -eq 'zb'){
        # NextZXOS's menu, then the Browser, then down the list to the nex file and Enter
        $sw = [Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt 120){ Start-Sleep 3; if(((Z 'get-ocr') -join ' ') -match 'Browser'){ break } }
        Start-Sleep 2; Key 129; Start-Sleep 5
        # the files are listed as they are on the card: the nex file is the 17th, saved games come after it
        1..16 | ForEach-Object { $null = Z 'send-keys-event 133 1'; Start-Sleep -Milliseconds 120; $null = Z 'send-keys-event 54 1'; Start-Sleep -Milliseconds 150; $null = Z 'send-keys-event 54 0' 'send-keys-event 133 0'; Start-Sleep -Milliseconds 250 }
        Start-Sleep 1; Key 129
    }
    $ok = WaitFor 5 28 'D U N G E O N S' 180
    if(-not $ok){ Log "no title: $((Scr)[0..3] -join ' | ')" }
    $ok
}
function End-Way { $null = Z 'exit-emulator'; if($script:Emu){ $null = $script:Emu.WaitForExit(20000) }; Stop-Game; Start-Sleep 2 }
function Save-End {
    # Ctrl-X: the game is saved, the high scores are shown with the character in them, a key, and the game ends
    Ctrl 'x'
    if(WaitFor 23 23 '[ press any key' 60){
        $lines = (2..21 | ForEach-Object { (Row $_).TrimEnd() }) | Where-Object { $_ }
        $null = Log "the high scores:`n$($lines -join "`n")"
        $script:SavedLines = @($lines | Where-Object { $_ -match '\(saved\)' }).Count
        Key 32
    } else { $null = Log 'no high scores after saving' }
    WaitFor 14 31 'ZXMoria has ended.' 120
}
function Load-First {
    # from the title, the saved game, which the game carries on with of its own accord, as Moria's does
    Start-Sleep 2; Key 113
    $null = Pass-Sheet
    WaitFor 23 65 'Town level' 120
}

try {
    # 1
    if(Start-Way){
        Start-Sleep 2; Key 113
        $name = $script:Names | Get-Random
        $pick = New-Character $name
        if($pick){
            $out.Made = $true; $out.Name = $name; $out.Race = $pick.Race; $out.Sex = $pick.Sex; $out.Class = $pick.Class
            Log "1 made: $name, $($pick.Sex) $($pick.Race) $($pick.Class)"
            $sheet = Sheet; Log "1 sheet:`n$sheet"
            $out.Saved = Save-End; Log "1 saved and ended: $($out.Saved)"
        } else { Log '1 the character was not made' }
    }
    End-Way
    if($Way -ne 'zf'){ Log "card after saving: $(( & $hdf ls $Card / ) -join ', ')" } else { Log "folder after saving: $((Get-ChildItem $Dir -File | ForEach-Object { "$($_.Name) $($_.Length)" }) -join ', ')" }

    # 2
    if($out.Saved -and (Start-Way)){
        $out.Loaded = Load-First; Log "2 loaded: $($out.Loaded)"
        if($out.Loaded){ $again = Sheet; $out.Same1 = ($again -eq $sheet); Log "2 sheet the same: $($out.Same1)"; if(-not $out.Same1){ Log "2 sheet now:`n$again" } }
        Log '2 switched off, not saved'
    }
    End-Way

    # 3
    if($out.Loaded -and (Start-Way)){
        $out.Reloaded = Load-First; Log "3 loaded again: $($out.Reloaded)"
        if($out.Reloaded){ $again = Sheet; $out.Same2 = ($again -eq $sheet); Log "3 sheet the same: $($out.Same2)"; if(-not $out.Same2){ Log "3 sheet now:`n$again" } }
        if($out.Reloaded){ $script:SavedLines = -1; $saved2 = Save-End; Log "3 saved again and ended: $saved2, lines with (saved) in the high scores: $script:SavedLines" }
    }
    End-Way
} catch {
    $out.Note = "$_"; Log "failed: $_"
    End-Way
}
if($Result){ Add-Content -Path $Result -Value ($out | ConvertTo-Json -Compress) }
Log "=== $Way : $(($out.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')"
