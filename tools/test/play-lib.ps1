# helpers for playing the game from what is on the screen: reading the map, finding a way across it, and the
# stats panel, dot-source after lib.ps1, see play.ps1
# N.B: the screen is Moria's: messages on row 0, the map on rows 1 to 22 from column 13, the stats down the left,
# the depth on row 23 from column 65; the map scrolls a panel at a time, so a way is worked out afresh at every step

$script:MapTop = 1; $script:MapBottom = 22; $script:MapLeft = 13; $script:MapRight = 79
# the eight steps, as Moria's number pad directions
$script:Steps = @( @(-1,-1,7), @(-1,0,8), @(-1,1,9), @(0,-1,4), @(0,1,6), @(1,-1,1), @(1,0,2), @(1,1,3) )
$script:Blocked = @{}        # squares found not to be walkable though they look it, "row,col", forgotten on a new level

function Scr {
    # the whole screen in one read, rows 0 to 23, 80 characters each, N.B: not by Txt, which comes back wrong for a read this long
    $reply = Z 'read-memory E000H 3840'; $hex = @($reply | Where-Object { $_ -notmatch '^###' -and $_ })[0]
    $sb = New-Object Text.StringBuilder
    for($i = 0; $i -lt $hex.Length - 1; $i += 4){ $v = [Convert]::ToInt32($hex.Substring($i, 2), 16); [void]$sb.Append($(if($v -ge 32 -and $v -lt 127){ [char]$v } else { '~' })) }
    $all = $sb.ToString(); @( 0..23 | ForEach-Object { $all.Substring($_*80, 80) } )
}
function Cell($rows, [int]$r, [int]$c){ $rows[$r][$c] }
function Panel($rows, [string]$label){ foreach($r in $rows){ if($r.StartsWith($label)){ $v = $r.Substring(5, 7).Trim(); if($v -match '^-?\d+$'){ return [int]$v } } }; $null }
function Depth($rows){ $rows[23].Substring(60).Trim() }
function Me($rows){ for($r = $script:MapTop; $r -le $script:MapBottom; $r++){ $c = $rows[$r].IndexOf('@', $script:MapLeft); if($c -ge 0){ return @($r, $c) } }; $null }

# what may be walked over: floor, open doors, stairs, the objects lying about (which are picked up), and rubble, which
# play.ps1 digs through when its next step is into it
function Walkable([char]$ch){ "$ch" -cmatch '^[.''<>!?="$()\[\]/|\\{}\-_~,&:]$' }
function IsMonster([char]$ch){ "$ch" -cmatch '^[A-Za-z]$' }

# what has been walked or seen, by the dungeon's own row and column (the player's position, gub_player_row and _col,
# against where the @ is on the screen gives the panel's offset): as in Moria, a dark corridor's floor is not shown once
# the torch has passed, only its walls are, so without this the way back looks like ground never explored
$script:Known = @{}; $script:Offset = $null
function Remember($rows){
    $me = Me $rows; if(-not $me){ return }
    $p = Player; $script:Offset = @(($p[0] - $me[0]), ($p[1] - $me[1]))
    for($r = $script:MapTop; $r -le $script:MapBottom; $r++){ $line = $rows[$r]
        for($c = $script:MapLeft; $c -le $script:MapRight; $c++){ $ch = $line[$c]; if($ch -ne ' ' -and $ch -ne '#' -and $ch -ne '%' -and ((Walkable $ch) -or $ch -eq '@' -or (IsMonster $ch))){ $script:Known["$($r + $script:Offset[0]),$($c + $script:Offset[1])"] = $true } } }
}
function IsKnown([int]$r, [int]$c){ $script:Offset -and $script:Known["$($r + $script:Offset[0]),$($c + $script:Offset[1])"] }

# the nearest square from which a target is one step away: returns @(first step's direction, distance, target row, target col,
# direction from there to the target), or $null... $IsTarget is given a character and its row and column
function Find-Way($rows, [scriptblock]$IsTarget, [int]$MaxDist = 400){
    $me = Me $rows; if(-not $me){ return $null }
    $seen = @{}; $first = @{}; $dist = @{}
    $q = New-Object Collections.Generic.Queue[object]
    $k0 = "$($me[0]),$($me[1])"; $seen[$k0] = $true; $dist[$k0] = 0; $q.Enqueue($me)
    while($q.Count){
        $p = $q.Dequeue(); $kp = "$($p[0]),$($p[1])"
        if($dist[$kp] -gt $MaxDist){ break }
        foreach($s in $script:Steps){
            $r = $p[0] + $s[0]; $c = $p[1] + $s[1]
            if($r -lt $script:MapTop -or $r -gt $script:MapBottom -or $c -lt $script:MapLeft -or $c -gt $script:MapRight){ continue }
            $ch = $rows[$r][$c]
            if(& $IsTarget $ch $r $c){
                $d = $(if($dist[$kp] -eq 0){ $s[2] } else { $first[$kp] })
                return @($d, $dist[$kp], $r, $c, $s[2])
            }
        }
        foreach($s in $script:Steps){
            $r = $p[0] + $s[0]; $c = $p[1] + $s[1]; $k = "$r,$c"
            if($r -lt $script:MapTop -or $r -gt $script:MapBottom -or $c -lt $script:MapLeft -or $c -gt $script:MapRight){ continue }
            if($seen[$k] -or $script:Blocked[$k]){ continue }
            $ch = $rows[$r][$c]
            if(-not ((Walkable $ch) -or ($ch -eq ' ' -and (IsKnown $r $c)))){ continue }
            $seen[$k] = $true; $dist[$k] = $dist[$kp] + 1
            $first[$k] = $(if($dist[$kp] -eq 0){ $s[2] } else { $first[$kp] })
            $q.Enqueue(@($r, $c))
        }
    }
    $null
}

# a name typed in, capitals and all, then Enter
function TypeName([string]$t){ foreach($ch in $t.ToCharArray()){ Press "$ch" }; Key 129 }

# the letters and names the game offers on rows 21 and 22, e.g. "a) Human   b) Half-Elf", as letter -> name
function Choices($rows){
    $o = [ordered]@{}
    foreach($r in $rows[21..22]){ foreach($m in [regex]::Matches($r, '\b([a-z])\) ([A-Za-z\-]+(?: [A-Za-z\-]+)?)')){ $o[$m.Groups[1].Value] = $m.Groups[2].Value.Trim() } }
    $o
}
# a new character, from the title screen to the town, its race, sex and class chosen at random from what the game
# offers (it offers only the classes the race may be), returns what was chosen, or $null if a screen did not come
function New-Character([string]$Name){
    $pick = @{ Name = $Name }
    if(-not (WaitFor 20 2 'Choose a race' 30)){ return $null }
    $c = Choices (Scr); $k = @($c.Keys) | Get-Random; $pick.Race = $c[$k]; Press $k
    if(-not (WaitFor 20 2 'Choose a sex' 20)){ return $null }
    $k = @('m', 'f') | Get-Random; $pick.Sex = $(if($k -eq 'f'){ 'Female' } else { 'Male' }); Press $k
    if(-not (WaitFor 20 2 'Hit space' 30)){ return $null }
    Esc
    if(-not (WaitFor 20 2 'Choose a class' 20)){ return $null }
    $c = Choices (Scr); $k = @($c.Keys) | Get-Random; $pick.Class = $c[$k]; Press $k
    if(-not (WaitFor 21 2 'Enter your' 30)){ return $null }
    TypeName $Name
    if(-not (WaitFor 23 17 '[ press any key' 20)){ return $null }
    Key 97
    if(-not (WaitFor 23 65 'Town level' 90)){ return $null }
    Start-Sleep 2
    $pick
}
# the character sheet, C, as text, rows 2 to 18, for comparing a character before saving and after loading
function Sheet { Press 'C'; Start-Sleep 1; $r = Scr; Esc; Start-Sleep -Milliseconds 600; ($r[2..18] | ForEach-Object { $_.TrimEnd() }) -join "`n" }
$script:Names = @('Arwen', 'Eowyn', 'Galadriel', 'Luthien', 'Idril', 'Nienor', 'Elwing', 'Morwen', 'Rosie', 'Lobelia',
                  'Boromir', 'Faramir', 'Legolas', 'Gimli', 'Beorn', 'Thorin', 'Balin', 'Haldir', 'Bilbo', 'Merry', 'Pippin', 'Halbarad')

# a key, by its character, for the game: digits and letters as themselves, N.B: a capital is its small letter with Caps Shift
# held, ZEsarUX takes no key event for a capital, it is simply lost (R for rest, B for bash, the F of a name)
function Press([string]$ch){
    $k = [char]$ch
    # the symbols are Symbol Shift with a letter, as on the Spectrum's keys, and they too are lost when sent on their own
    $sym = @{ '>' = 't'; '<' = 'r'; '#' = '3'; '*' = 'b'; '&' = '6'; '?' = 'c'; '+' = 'k'; '-' = 'j'; '=' = 'l'; ':' = 'z'; ';' = 'o'; ',' = 'n'; '.' = 'm'; '%' = '5'; '$' = '4'; '@' = '2'; '[' = 'y'; ']' = 'u'; '{' = 'f'; '}' = 'g' }
    if($sym.ContainsKey("$k")){ Sym ([int][char]$sym["$k"]); return }
    if([char]::IsUpper($k)){ $n = [int][char]::ToLower($k); $null = Z 'send-keys-event 133 1'; Start-Sleep -Milliseconds 120; $null = Z "send-keys-event $n 1"; Start-Sleep -Milliseconds 180; $null = Z "send-keys-event $n 0" 'send-keys-event 133 0'; Start-Sleep -Milliseconds 250 }
    else { Key ([int]$k) }
}
