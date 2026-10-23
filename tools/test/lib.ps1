# helpers for driving the game in a hidden ZEsarUX emulator over its remote protocol, dot-source this
# N.B: a script that uses this must not have a variable called $s, PowerShell would take it for $script:S below
# what the tests make goes in build\test, a folder for each test, with a copy of the nex file in it to run
$script:S = $PSScriptRoot
$script:Project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:Work = Join-Path $script:Project 'build\test'; $null = New-Item $script:Work -ItemType Directory -Force
# $script:Away: set it to $true when nobody is at the machine: the emulator may then keep the keyboard, which it takes as it starts
# N.B: only made false here if it is not there already, because a script's own -Away switch IS $script:Away, the same variable, and
# setting it here wiped it out: until 15 October every -Away (lifecycle.ps1, play.ps1, so the night tests) came to nothing
if($null -eq $script:Away){ $script:Away = $false }
if(-not $script:Proj){ $script:Proj = 'proj' }
function Z { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$c) & "$script:S\zrcp.ps1" @c }
function Txt($addr,$cells){ $r=Z ("read-memory {0:X4}H {1}" -f $addr,($cells*2)); $h=@($r|?{ $_ -notmatch '^###' -and $_ })[0]; $o=New-Object Text.StringBuilder;for($i=0;$i -lt $h.Length-1;$i+=4){$c=[Convert]::ToInt32($h.Substring($i,2),16);[void]$o.Append($(if($c -ge 32 -and $c -lt 127){[char]$c}else{'~'}))};$o.ToString() }
function Row($r){ (Txt (0xE000+$r*160) 80) }
function Screen($from,$to){ foreach($r in $from..$to){ "{0,2}|{1}" -f $r,(Row $r).TrimEnd() } }
function Key($n){ $null = Z "send-keys-event $n 1"; Start-Sleep -Milliseconds 180; $null = Z "send-keys-event $n 0"; Start-Sleep -Milliseconds 220 }
function Ctrl($ch){ $n=[int][char]$ch; $null = Z "send-keys-event 133 1" "send-keys-event 136 1"; Start-Sleep -Milliseconds 150; $null = Z "send-keys-event $n 1"; Start-Sleep -Milliseconds 250; $null = Z "send-keys-event $n 0" "send-keys-event 136 0" "send-keys-event 133 0"; Start-Sleep -Milliseconds 500 }
function Sym($key){ $null = Z "send-keys-event 136 1"; Start-Sleep -Milliseconds 150; $null = Z "send-keys-event $key 1"; Start-Sleep -Milliseconds 250; $null = Z "send-keys-event $key 0" "send-keys-event 136 0"; Start-Sleep -Milliseconds 400 }
function Str($ch){ $null = Z "send-keys-string 300 $ch"; Start-Sleep -Milliseconds 700 }
function Esc { $null = Z 'send-keys-event 133 1'; Start-Sleep -Milliseconds 200; $null = Z 'send-keys-event 32 1'; Start-Sleep -Milliseconds 500; $null = Z 'send-keys-event 32 0' 'send-keys-event 133 0'; Start-Sleep -Milliseconds 600 }
function Enter { Key 129 }
function Type_($text){ foreach($d in "$text".ToCharArray()){ Key ([int][char]$d) }; Key 129 }
function WaitFor($row,$col,$text,$secs){ $sw=[Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt $secs){ Start-Sleep -Milliseconds 200; try{ if((Txt (0xE000+$row*160+$col*2) $text.Length) -eq $text){ return $true } }catch{} }; $false }
# everything on the message line, answering -more-, as one string
function Msgs { $out=@(); foreach($q in 1..12){ Start-Sleep -Milliseconds 250; $m=(Row 0).Trim(); if($m){ $out += ($m -replace '\s*-more-$','') }; if($m -match '-more-'){ Key 32 } else { break } }; ($out -join ' | ') }
function Say($label){ "  ${label}: [" + (Msgs) + "]" }
function Peek8([int]$a){ $r=Z ("read-memory {0:X4}H 1" -f $a); [Convert]::ToInt32((@($r|?{ $_ -notmatch '^###' -and $_ })[0]).Substring(0,2),16) }
function Peek16([int]$a){ $r=Z ("read-memory {0:X4}H 2" -f $a); $h=@($r|?{ $_ -notmatch '^###' -and $_ })[0]; [Convert]::ToInt32($h.Substring(2,2)+$h.Substring(0,2),16) }
function Poke8([int]$a,[int]$v){ $null = Z ("write-memory {0:X4}H {1}" -f $a,($v -band 255)) }
function Poke16([int]$a,[int]$v){ Poke8 $a ($v -band 255); Poke8 ($a+1) (($v -shr 8) -band 255) }
# a page of the Next's memory, by its number, as a hex string
function Page([int]$page,[int]$offset,[int]$length){ $r = Z 'set-memory-zone 0' ("read-memory {0} {1}" -f (0x40000 + $page*8192 + $offset),$length) 'set-memory-zone -1'; @($r | ?{ $_ -notmatch '^###' -and $_ -match '^[0-9A-Fa-f]{2,}$' })[0] }
function PagePoke([int]$page,[int]$offset,[int]$v){ $null = Z 'set-memory-zone 0' ("write-memory {0} {1}" -f (0x40000 + $page*8192 + $offset),($v -band 255)) 'set-memory-zone -1' }
function Player { $p=Z 'read-memory D9E9H 2'; $h=@($p|?{ $_ -notmatch '^###' -and $_ })[0]; @([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16)) }
function Hp { $v=Peek16 0xD864; if($v -gt 32767){ $v-65536 } else { $v } }
function Level { Peek16 0xC210 }
function Turn { Peek16 0xC218 }
function Status { "    hp $(Hp) level $(Level) turn $(Turn) at $((Player) -join ',')  status [$((Row 23).Trim())]" }
# starts the game and makes a character of a class (0 warrior, 1 mage, 2 priest, 3 rogue, 4 ranger, 5 paladin), into the town
function Start-Game([int]$Class = 0, [int]$ExitAfter = 900, [int]$Race = 0, [switch]$Sd, [switch]$NoCharacter){
    # -Sd boots NextZXOS from the scratch card image, sd-test.mmc, which sdcard.ps1 makes, so that files can be written
    # the test's copy of the nex file is made afresh whenever the build has made a newer one, so a test never runs an old build
    $built = Get-ChildItem $script:Project -Filter *.nex | Select-Object -First 1; $copy = "$script:Work\$script:Proj\poc4uat.nex"
    if(-not (Test-Path $copy) -or (Get-Item $copy).LastWriteTime -lt $built.LastWriteTime){ $null = New-Item "$script:Work\$script:Proj" -ItemType Directory -Force; Copy-Item $built.FullName $copy -Force }
    # $script:EmuCfg and $script:EmuLog, if a test sets them, are the emulator's settings in place of the project's, and a file for what it prints
    $cfg = $(if($script:EmuCfg){ $script:EmuCfg } else { "$script:Project\src\zesarux.cfg" })
    $launch = { & "$script:S\emu.ps1" -ExitAfter $ExitAfter -WorkDir "$script:Work\$script:Proj" -BaseCfg $cfg -Nex poc4uat.nex -AllowFocus:$script:Away -Log "$script:EmuLog" }
    $script:Emu = & $launch
    foreach($try in 1..4){ if($script:Emu){ break }; Start-Sleep 6; $script:Emu = & $launch }
    if(-not $script:Emu){ return $false }
    $ok = WaitFor 5 28 'D U N G E O N S' $(if($Sd){ 300 } else { 60 }); if(-not $ok){ return $false }; Start-Sleep 2
    if($NoCharacter){ return $true }
    Key 113
    $ok = WaitFor 20 2 'Choose a race' 30; Key (97 + $Race)
    $ok = WaitFor 20 2 'Choose a sex' 20; Key 109
    $ok = WaitFor 20 2 'Hit space' 30; Esc
    $ok = WaitFor 20 2 'Choose a class' 20; Key (97 + $Class)
    $ok = WaitFor 21 2 'Enter your' 30; Type_ 'bob'
    $ok = WaitFor 23 17 '[ press any key' 20; Key 97
    $ok = WaitFor 23 65 'Town level' 90; Start-Sleep 3
    $ok
}
function Stop-Game { if($script:Emu){ Stop-Process -Id $script:Emu.Id -Force -ErrorAction SilentlyContinue } }
function Alive { $script:Emu -and -not $script:Emu.HasExited }
function Wizard { Ctrl 'w'; Start-Sleep 1; Key 32; Start-Sleep 1; Key 121; $null = Msgs }
function Super { Str '$'; Start-Sleep 10; $null = Msgs }
# a saved game brought back shows the character's sheet first, as Moria's changeCharacterName() (since 16 October): ESC
# goes on to the game, true if the sheet was there
function Pass-Sheet([int]$Secs = 120){ $ok = WaitFor 21 2 '<f>ile character description.' $Secs; if($ok){ Esc }; $ok }
function Goto-Level([int]$n){ Ctrl 'd'; Start-Sleep 1; Type_ "$n"; $feet = "$($n*50) feet"; if($n -eq 0){ $feet = 'Town level' }; $ok = WaitFor 23 65 $feet 180; Start-Sleep 2; $ok }




