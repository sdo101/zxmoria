# plays one round of the game from what is on the screen, as a player would: a new character, of a race, sex and class
# chosen at random from what the game offers, shops in the town and then goes down the stairs to hunt monsters, until
# it dies or the time is up... everything that happens is written to play.log in the round's folder
#   -Dir <folder>                 the round's folder (made if it is not there), the nex file is copied into it, default build\test\play
#   -ShopMinutes, -HuntMinutes    how long each part may last
#   -Name                         the character's name, one of $script:Names at random if not given
#   -Result <file>                a line of JSON is added to it at the end: who, how far, how it ended (see nightly.ps1)
#   -Messages <file>              every different message seen is added to it, for the night's catalogue
#   -MaxDepth <n>                 the deepest dungeon level it will go to, in levels of 50 feet
#   -Away                         nobody is at the machine: the emulator may keep the keyboard
# the shopping, as sdo set it out on 14 October 2026: up to 10 rations of food and 10 wooden torches, then whatever
# armour can be afforded, a mage or other spell caster buying no gloves (they spoil spells, in Moria)
# bartering: the first offer is half the asking price, and each offer after it goes half of the way from the last
# offer to what the owner is now asking (50%, 75%, 87.5%...), what the owner says each time is logged
# a hang: no game turn passing for 90 seconds while keys are being pressed, an emulator snapshot is kept (hang.zsf)
param([string]$Dir = '', [double]$ShopMinutes = 5, [double]$HuntMinutes = 10, [string]$Name = '', [string]$Result = '',
      [string]$Messages = '', [int]$MaxDepth = 6, [switch]$Away)
$script:Proj = 'play'
. (Join-Path $PSScriptRoot 'lib.ps1'); . (Join-Path $PSScriptRoot 'play-lib.ps1')
$script:Away = [bool]$Away
if(-not $Dir){ $Dir = Join-Path $script:Work 'play' }
$null = New-Item $Dir -ItemType Directory -Force
$LogFile = Join-Path $Dir 'play.log'
if(-not $Name){ $Name = $script:Names | Get-Random }

function Log([string]$t){ $line = "$([DateTime]::Now.ToString('HH:mm:ss'))  $t"; $line; Add-Content -Path $LogFile -Value $line }
$script:LastMsg = ''; $script:Kills = 0; $script:Seen = @{}
function Note($rows){
    $m = $rows[0].Trim()
    if($m -and $m -ne $script:LastMsg){
        Log "   | $m"
        $script:Kills += ([regex]::Matches($m, 'You have (slain|killed)')).Count
        foreach($part in ($m -replace '\s*-more-\s*$', '' -split '(?<=[.!?])\s{2,}')){ $p = $part.Trim(); if($p){ $script:Seen[$p] = 1 + [int]$script:Seen[$p] } }
    }
    $script:LastMsg = $m
}
function Settle([int]$ms = 350){ Start-Sleep -Milliseconds $ms; for($i = 0; $i -lt 15; $i++){ $rows = Scr; Note $rows; if($rows[0] -match '-more-'){ Key 32; Start-Sleep -Milliseconds 250 } else { return $rows } }; Scr }
function Status($rows){ "depth $(Depth $rows), level $(Panel $rows 'LEV'), exp $(Panel $rows 'EXP'), hp $(Panel $rows 'CHP')/$(Panel $rows 'MHP'), ac $(Panel $rows 'AC  '), gold $(Panel $rows 'GOLD')" }
function Dead($rows){ ($rows -join "`n") -match 'Killed by|R\.I\.P|RIP' }

$out = [ordered]@{ Start = [DateTime]::Now.ToString('HH:mm:ss'); Name = $Name; Race = ''; Sex = ''; Class = ''; End = 'did not start'
                   Level = 0; Exp = 0; Deepest = 0; Kills = 0; Turns = 0; Bought = 0; Spent = 0; KilledBy = ''; Folder = $Dir }
function Finish([string]$how){
    $out.End = $how; $out.Kills = $script:Kills
    try { $out.Turns = Turn } catch { }
    if($Result){ Add-Content -Path $Result -Value ($out | ConvertTo-Json -Compress) }
    if($Messages){ foreach($k in $script:Seen.Keys){ Add-Content -Path $Messages -Value "$($script:Seen[$k])`t$k" } }
    Log "=== round over: $how"
    if($script:Emu){ $null = Z 'exit-emulator' 2>$null; Start-Sleep 2; Stop-Game }
}

# --- the game, and a character
Copy-Item (Join-Path $script:Project 'poc4uat.nex') (Join-Path $Dir 'poc4uat.nex') -Force
$script:Emu = & "$script:S\emu.ps1" -ExitAfter ([int](($ShopMinutes + $HuntMinutes) * 60 + 600)) -WorkDir $Dir -Nex poc4uat.nex -AllowFocus:$script:Away
if(-not $script:Emu){ Log 'the emulator did not start'; Finish 'emulator did not start'; exit 1 }
if(-not (WaitFor 5 28 'D U N G E O N S' 90)){ Log 'no title screen'; Finish 'no title screen'; exit 1 }
Start-Sleep 2; Key 113
$pick = New-Character $Name
if(-not $pick){ Log "the character was not made: $((Scr) -join ' | ')"; Finish 'character not made'; exit 1 }
$out.Race = $pick.Race; $out.Sex = $pick.Sex; $out.Class = $pick.Class
$Caster = $pick.Class -match 'Mage|Priest|Ranger|Paladin|Rogue'
$rows = Scr
Log "$Name, $($pick.Sex) $($pick.Race) $($pick.Class), $(Status $rows)"

function Inventory {
    # what is carried, as the i command lists it: letter -> description
    Press 'i'; Start-Sleep -Milliseconds 700; $rows = Scr; $inv = [ordered]@{}
    foreach($r in $rows[1..22]){ if($r -match '\b([a-w])\) (.+?)\s*(\d+\.\d+ lb)?\s*$'){ $inv[$Matches[1]] = $Matches[2].Trim() } }
    Esc; Start-Sleep -Milliseconds 300; $null = Settle; $inv
}
function Show-Inv($inv){ @($inv.Keys | ForEach-Object { '{0}) {1}' -f $_, $inv[$_] }) -join '; ' }
function Find-Item($inv, [string]$pattern){ foreach($k in $inv.Keys){ if($inv[$k] -match $pattern){ return $k } }; $null }
function Count-Of($inv, [string]$pattern){ $n = 0; foreach($v in $inv.Values){ if($v -match $pattern){ if($v -match '^(\d+) '){ $n += [int]$Matches[1] } else { $n += 1 } } }; $n }

# --- shopping
function Stock($rows){ $s = @(); foreach($i in 5..16){ if($rows[$i] -match '^([a-l])\) (.+?)\s+(\d+)\s*$'){ $s += [pscustomobject]@{ Letter = $Matches[1]; Name = $Matches[2]; Price = [int]$Matches[3] } } }; $s }
function Buy($item){
    # one of it, bartering as above, returns what it cost, 0 if not bought
    $before = [int]((Scr)[18] -replace '\D', '')
    Press 'p'; Start-Sleep -Milliseconds 500; Press $item.Letter; $last = 0
    for($round = 1; $round -le 12; $round++){
        Start-Sleep -Milliseconds 700; $rows = Scr; $top = $rows[0].Trim()
        if($top -match '-more-'){ Log "   | $top"; Key 32; continue }
        if($top -match 'What do you offer'){
            if($rows[1] -notmatch '(Asking|Final [Oo]ffer)\s*:\s*(\d+)'){ Log "   ? $($rows[1].Trim())"; Esc; break }
            $kind = $Matches[1]; $ask = [int]$Matches[2]
            $offer = $(if($last -eq 0){ [int][math]::Floor($ask / 2) } else { $last + [int][math]::Ceiling(($ask - $last) / 2) })
            if($kind -match 'Final' -or $offer -ge $ask - 1){ $offer = $ask }
            if($offer -gt $before){ Log "   owner asks $ask, more than the $before gold there is, no sale"; Esc; Start-Sleep -Milliseconds 800; $null = Settle; break }
            Log "   owner: $kind $ask   offer $offer   ($([math]::Round(100 * $offer / [math]::Max(1, $ask)))% of what is asked)"
            Type_ "$offer"; $last = $offer; continue
        }
        if($rows[21] -match 'Purchase an item'){ if($top){ Log "   | $top" }; break }
    }
    Start-Sleep -Milliseconds 500; $after = [int]((Scr)[18] -replace '\D', '')
    if($after -lt $before){ Log "   bought $($item.Name) for $($before - $after) (list price $($item.Price)), gold now $after"; $out.Bought++; $out.Spent += ($before - $after); return ($before - $after) }
    0
}
function Shop([int]$store, $wants, [datetime]$until){
    # walks to a store, and buys from the list in order, as many of each as wanted and as can be afforded
    if([datetime]::Now -ge $until){ return }
    $rows = Settle; Log "to store $store, $(Status $rows)"
    for($n = 0; $n -lt 150; $n++){
        $rows = Scr
        if($rows[21] -match 'Purchase an item'){ break }
        if($rows[0] -match '-more-'){ Key 32; continue }
        $w = Find-Way $rows { param($ch, $r, $c) $ch -eq "$store" }
        if(-not $w){ $w = @((Get-Random -Minimum 1 -Maximum 10)) }
        Press "$($w[0])"
    }
    $rows = Scr; if($rows[21] -notmatch 'Purchase an item'){ Log "   could not get into store $store"; return }
    Log "   in: $($rows[3].Trim())"
    foreach($s in (Stock $rows)){ Log ("      {0}) {1,-50} {2,6}" -f $s.Letter, $s.Name, $s.Price) }
    foreach($want in $wants){
        for($k = 0; $k -lt $want.Count -and [datetime]::Now -lt $until; $k++){
            $rows = Scr; if($rows[21] -notmatch 'Purchase an item'){ Log '   no longer in the store'; return }
            $gold = [int]($rows[18] -replace '\D', '')
            $item = Stock $rows | Where-Object { $_.Name -match $want.Match } | Select-Object -First 1
            if(-not $item){ if($k -eq 0){ Log "   none of: $($want.Match)" }; break }
            if($want.Max -and $item.Price -gt $want.Max){ Log "   $($item.Name) at $($item.Price) is more than it is worth to a new character ($($want.Max))"; break }
            if($item.Price / 2 -gt $gold - $want.Keep){ Log "   $($item.Name) at $($item.Price) is more than can be spared from $gold"; break }
            if((Buy $item) -eq 0){ break }
        }
    }
    Esc; Start-Sleep 1; $null = Settle
}

$Until = [datetime]::Now.AddMinutes($ShopMinutes)
Log "=== shopping, $ShopMinutes minutes"
$inv = Inventory; Log "carrying: $(Show-Inv $inv)"
$food = Count-Of $inv 'Ration'; $torches = Count-Of $inv 'Torch'
# up to 10 rations and 10 torches, counting what the character already has
Shop 1 @( @{ Match = 'Rations? of Food'; Count = [math]::Max(0, 10 - $food); Keep = 0 }, @{ Match = 'Wooden Torch'; Count = [math]::Max(0, 10 - $torches); Keep = 0 } ) $Until
# armour, at prices that suit a new character (Max), so that one enchanted cap does not take all the gold
$armour = @( @{ Match = 'Hard Leather Cap|Metal Cap'; Count = 1; Keep = 0; Max = 60 }, @{ Match = 'Soft Leather Cap'; Count = 1; Keep = 0; Max = 30 },
             @{ Match = 'Leather Boots|Leather Shoes'; Count = 1; Keep = 0; Max = 40 } )
if(-not $Caster){ $armour += @{ Match = 'Leather Gloves|Gauntlets'; Count = 1; Keep = 0; Max = 40 } }
$armour += @( @{ Match = 'Small Metal Shield|Leather Shield'; Count = 1; Keep = 0; Max = 160 },
              @{ Match = 'Hard Studded Leather|Soft Studded Leather|Hard Leather Armou?r|Leather Scale'; Count = 1; Keep = 0; Max = 260 } )
Shop 2 $armour $Until

# wear what was bought, one at a time, as each one worn leaves the pack and the letters move up
# N.B: what is tried is remembered by its name less any count and turns of light, so that a torch, whose stack's name
# changes each time one is taken from it, is wielded once and not again and again
$tried = @{}; $lit = $false
for($n = 0; $n -lt 16; $n++){
    $inv = Inventory; $l = $null
    # the weakest first, so that of two of a kind the better one is put on last and stays on
    $order = @($inv.Keys | Sort-Object { if($inv[$_] -match '\[(\d+),([+-]\d+)\]'){ [int]$Matches[1] + [int]$Matches[2] } else { 0 } })
    foreach($k in $order){
        $key = $inv[$k] -replace '^(an?|\d+) ', '' -replace 'with \d+ turns.*$', ''
        if($inv[$k] -match 'Torch' -and $lit){ continue }
        if($inv[$k] -match 'Armou?r|Leather|Studded|Shield|Cap\b|Boots|Shoes|Gloves|Gauntlets|Cloak|Robe|Dagger|Sword|Mace|Spear|Axe|Hammer|Whip|Lance|Rapier|Sabre|Cutlass|Pick|Flail|Club|Quarterstaff|Bow|Torch' -and -not $tried[$key]){ $l = $k; $tried[$key] = $true; break }
    }
    if(-not $l){ break }
    if($inv[$l] -match 'Torch'){ $lit = $true }
    Press 'w'; Start-Sleep -Milliseconds 600; Press $l; $null = Settle 600; Log "   wore or wielded $($inv[$l])"
}
$inv = Inventory; Log "carrying: $(Show-Inv $inv)"
$rows = Settle; Log "shopping done, $(Status $rows)"

# --- hunting
$Until = [datetime]::Now.AddMinutes($HuntMinutes)
Log "=== hunting, $HuntMinutes minutes"
$lastStatus = [datetime]::Now; $lastDepth = ''; $doorTries = @{}; $lost = 0
$lastTurn = -1; $turnSince = [datetime]::Now; $levelSince = [datetime]::Now
$script:Trail = New-Object Collections.Generic.Queue[string]; $script:Circles = 0
$how = 'time up'
while([datetime]::Now -lt $Until){
    if(-not (Alive)){ Log 'the emulator has gone'; $how = 'EMULATOR GONE'; break }
    $rows = Scr; Note $rows
    if(Dead $rows){
        Log "DIED:"; Screen 0 23 | ForEach-Object { Log "   $_" }
        $i = [array]::IndexOf($rows, ($rows | Where-Object { $_ -match 'killed by' } | Select-Object -First 1))
        if($i -ge 0 -and $i + 1 -lt 24){ $out.KilledBy = ($rows[$i + 1] -replace '[|]', '').Trim() }
        $how = 'died'; break
    }
    # a hang: no turn has passed for a minute and a half while keys have been going in
    $t = Turn
    if($t -ne $lastTurn){ $lastTurn = $t; $turnSince = [datetime]::Now }
    elseif(([datetime]::Now - $turnSince).TotalSeconds -gt 90){
        Log "HANG? no turn has passed since $($turnSince.ToString('HH:mm:ss')), turn $t"
        Screen 0 23 | ForEach-Object { Log "   $_" }
        $null = Z "snapshot-save $Dir\hang.zsf"; Log "   registers: $((Z 'get-registers') -join ' ')"
        $how = 'HANG'; break
    }
    if($rows[0] -match '-more-'){ Key 32; continue }
    if($rows[0] -match '\?\s*$|Direction'){ Esc; continue }
    $depth = Depth $rows
    if($depth -ne $lastDepth){ $script:Known = @{} }
    Remember $rows
    if($depth -ne $lastDepth){
        Log "now at: $depth, $(Status $rows)"; $script:Blocked = @{}; $doorTries = @{}; $lastDepth = $depth; $levelSince = [datetime]::Now; $script:Circles = 0; $script:Trail.Clear()
        if($depth -match '(\d+) feet'){ $out.Deepest = [math]::Max($out.Deepest, [int]$Matches[1] / 50) }
    }
    if(([datetime]::Now - $lastStatus).TotalSeconds -ge 60){ Log "status: $(Status $rows), kills $script:Kills"; $lastStatus = [datetime]::Now }
    $out.Level = [int](Panel $rows 'LEV'); $out.Exp = [int](Panel $rows 'EXP')
    $me = Me $rows; if(-not $me){ $lost++; if($lost -ge 4){ Log "   not on the map: $($rows[0].Trim()) / $($rows[1].Trim()), Escape"; Esc; $lost = 0 }; Start-Sleep -Milliseconds 300; continue }; $lost = 0
    $hp = Panel $rows 'CHP'; $mhp = Panel $rows 'MHP'
    # going round in circles: the last 40 moves on no more than 4 squares, nothing killed and no harm taken... then
    # a random walk, and on the third time on a level, the first stairs to be seen, whichever way they go
    $here = "$((Player) -join ',')"; $script:Trail.Enqueue("$here/$script:Kills/$hp"); if($script:Trail.Count -gt 40){ [void]$script:Trail.Dequeue() }
    if($script:Trail.Count -eq 40 -and @($script:Trail | Select-Object -Unique).Count -le 4){
        $script:Circles++; $script:Trail.Clear()
        Log "   going round in circles ($script:Circles on this level), a random walk"
        $rows[1..22] | Where-Object { $_.Substring(13).Trim() } | ForEach-Object { Log "      $($_.Substring(13).TrimEnd())" }      # the map, to see in the morning what it was caught on
        1..10 | ForEach-Object { Press "$(@(1,2,3,4,6,7,8,9) | Get-Random)"; $null = Settle 150 }
        continue
    }
    if($script:Circles -ge 3){
        $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '<' -or $ch -eq '>' }
        if($w){ if($w[1] -eq 0){ $stairs = $rows[$w[2]][$w[3]]; Press "$($w[4])"; Start-Sleep -Milliseconds 400; Press "$stairs"; Log "   took the stairs $stairs, to get away from going round in circles"; $null = Settle 1500 } else { Press "$($w[0])"; $null = Settle 200 }; continue }
    }
    $adjacent = Find-Way $rows { param($ch, $r, $c) IsMonster $ch } 0
    $monster = Find-Way $rows { param($ch, $r, $c) IsMonster $ch } 25
    if($depth -match 'Town'){
        # the town's people are no prize for a new character and some are deadly (the veteran), so: down the stairs
        $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '>' }
        if($w){ if($w[1] -eq 0){ Press "$($w[4])"; Start-Sleep -Milliseconds 400; Press '>'; Log '   down the stairs'; $null = Settle 1500 } else { Press "$($w[0])"; $null = Settle 150 }; continue }
        # no staircase to be seen: perhaps it is under the player
        Press '>'; $after = Settle 1500; if((Depth $after) -notmatch 'Town'){ Log '   down the stairs, they were underfoot'; continue }
    }

    # hurt: drink, or read a way out, or rest when nothing is about
    if($hp -lt $mhp * 0.35 -and $adjacent){
        $inv = Inventory; $l = Find-Item $inv 'Cure Light Wounds|Cure Serious'
        if($l){ Log "   hp $hp/$mhp, drinking $($inv[$l])"; Press 'q'; Start-Sleep -Milliseconds 500; Press $l; $null = Settle; continue }
        $l = Find-Item $inv 'Phase Door'
        if($l){ Log "   hp $hp/$mhp, reading $($inv[$l])"; Press 'r'; Start-Sleep -Milliseconds 500; Press $l; $null = Settle; continue }
    }
    if($hp -lt $mhp * 0.6 -and -not $monster){ Log "   hp $hp/$mhp, resting"; Press 'R'; Start-Sleep -Milliseconds 500; Press '*'; Key 129; Start-Sleep 3; $null = Settle; continue }
    # hungry: eat
    if($rows[23] -match 'Hungry|Weak'){ $inv = Inventory; $l = Find-Item $inv 'Ration|Jerky|Biscuit|Food'; if($l){ Log "   $($Matches[0]), eating"; Press 'E'; Start-Sleep -Milliseconds 500; Press $l; $null = Settle; continue } }

    if($adjacent){ Press "$($adjacent[0])"; $null = Settle 250; continue }
    if($monster){
        # oil thrown at one in a straight line a few squares away
        $dr = $monster[2] - $me[0]; $dc = $monster[3] - $me[1]
        if(($dr -eq 0 -or $dc -eq 0 -or [math]::Abs($dr) -eq [math]::Abs($dc)) -and [math]::Max([math]::Abs($dr), [math]::Abs($dc)) -ge 2 -and [math]::Max([math]::Abs($dr), [math]::Abs($dc)) -le 6){
            $inv = Inventory; $l = Find-Item $inv 'Flasks? of [Oo]il'
            if($l){
                $dir = @{ '-1,-1' = 7; '-1,0' = 8; '-1,1' = 9; '0,-1' = 4; '0,1' = 6; '1,-1' = 1; '1,0' = 2; '1,1' = 3 }["$([math]::Sign($dr)),$([math]::Sign($dc))"]
                Log "   throwing oil at '$($rows[$monster[2]][$monster[3]])' $([math]::Max([math]::Abs($dr), [math]::Abs($dc))) squares away"
                Press 'f'; Start-Sleep -Milliseconds 500; Press $l; Start-Sleep -Milliseconds 500; Press "$dir"; $null = Settle 500; continue
            }
        }
        Press "$($monster[0])"; $null = Settle 250; continue
    }
    # deeper: once the character is up to it, and sooner if this level has had four minutes and the stairs are in sight
    $feet = $(if($depth -match '(\d+) feet'){ [int]$Matches[1] } else { 0 })
    $level = [int](Panel $rows 'LEV')
    $wanted = [math]::Min($MaxDepth, $level + 1) * 50          # a level deeper than the character's level, at most
    $restless = ([datetime]::Now - $levelSince).TotalMinutes -gt 4
    if($restless -and $feet -lt $wanted){
        $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '>' }
        if($w){ if($w[1] -eq 0){ Press "$($w[4])"; Start-Sleep -Milliseconds 400; Press '>'; Log "   down the stairs"; $null = Settle 1500 } else { Press "$($w[0])"; $null = Settle 200 }; continue }
    }
    $w = Find-Way $rows { param($ch, $r, $c) "$ch" -cmatch '^[!?=$"(\[\]/|\\{}\-_~,&]$' -and -not $script:Blocked["$r,$c"] } 12
    if(-not $w){ $w = Find-Way $rows { param($ch, $r, $c) $ch -eq ' ' -and -not $script:Blocked["$r,$c"] -and -not (IsKnown $r $c) } }
    if($w){
        # rubble in the way: dig through it, T and the direction, as a player would, a few goes at a time
        $step = $script:Steps | Where-Object { $_[2] -eq [int]$w[0] } | Select-Object -First 1
        if($step -and $rows[$me[0] + $step[0]][$me[1] + $step[1]] -eq ':'){
            Log "   digging through rubble"
            for($d = 0; $d -lt 8; $d++){ Press 'T'; Start-Sleep -Milliseconds 300; Press "$($w[0])"; $after = Settle 300; if($after[$me[0] + $step[0]][$me[1] + $step[1]] -ne ':'){ break } }
            continue
        }
        Press "$($w[0])"; $null = Settle 200
        # a step that went nowhere: a wall felt in the dark, or gold in a mineral vein ($ in a wall, as Moria shows it,
        # to be dug out with T, not walked on), either way not to be tried again
        if($w[1] -eq 0){ $after = Scr; if("$(Me $after)" -eq "$me"){ $script:Blocked["$($w[2]),$($w[3])"] = $true } }
        continue
    }
    $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '+' -and $doorTries["$r,$c"] -lt 8 }
    if($w){
        if($w[1] -eq 0){ $k = "$($w[2]),$($w[3])"; $doorTries[$k]++; Press $(if($doorTries[$k] -gt 4){ 'B' } else { 'o' }); Start-Sleep -Milliseconds 400; Press "$($w[4])"; $null = Settle }
        else { Press "$($w[0])"; $null = Settle 200 }
        continue
    }
    if($feet -lt $wanted){
        $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '>' }
        if($w){ if($w[1] -eq 0){ Press "$($w[4])"; Start-Sleep -Milliseconds 400; Press '>'; Log "   down the stairs"; $null = Settle 1500 } else { Press "$($w[0])"; $null = Settle 200 }; continue }
    }
    $w = Find-Way $rows { param($ch, $r, $c) $ch -eq '<' -or $ch -eq '>' }
    if($w){ if($w[1] -eq 0){ $stairs = $rows[$w[2]][$w[3]]; Press "$($w[4])"; Start-Sleep -Milliseconds 400; Press "$stairs"; Log "   took the stairs $stairs, nothing left here"; $null = Settle 1500 } else { Press "$($w[0])"; $null = Settle 200 }; continue }
    # nothing to go for: search for secret doors every other time, and otherwise a random step, but only on to a square
    # that may be walked on, never into a trap that can be seen (a pit, five times in one round, before this)
    $script:Idle++
    if($script:Idle % 2){ Press 's'; $null = Settle 200; continue }
    $ok = @($script:Steps | Where-Object { $ch = $rows[$me[0] + $_[0]][$me[1] + $_[1]]; (Walkable $ch) -or ($ch -eq ' ' -and -not (IsKnown ($me[0] + $_[0]) ($me[1] + $_[1]))) })
    if($ok.Count){ Press "$(($ok | Get-Random)[2])" } else { Press 's' }
    $null = Settle 200
}

# --- the end
if($how -eq 'time up'){
    $rows = Settle
    Log "=== done, $(Status $rows), kills seen $script:Kills"
    Press 'C'; Start-Sleep 1; Screen 0 23 | ForEach-Object { Log "   $_" }; Esc; Start-Sleep -Milliseconds 500
}
Finish $how
