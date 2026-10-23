# chests, against Moria's code, in one emulator start: a superhuman mage on level 10 with the monsters gone, a chest
# put beside them each time with the traps and lock the check needs (written straight into the dungeon's items), then:
#   the mage's Trap/Door Destruction (spellDestroyAdjacentDoorsTraps): "You have disarmed the chest.", unlocked
#   the mage's Find Hidden Traps/Doors (spellDetectTrapsWithinVicinity): the chest known, its traps left alone
#   a Wand of Trap/Door Destruction (spellDestroyDoorsTrapsInDirection): "Click!", unlocked
#   a Wand of Disarming (spellDisarmAllInDirection): "Click!", unlocked, "Click!" again while treasure is in its flags,
#     and nothing once its flags are all 0
#   D on a chest not known to be trapped: "I don't see a trap.", no turn; on a known one: disarmed, still locked,
#     experience up by the chest's level
#   s next to a trapped chest: "You have discovered a trap on the chest!", and then "The chest is trapped!"
#   B until it breaks: "The lock breaks open!" maybe, "You have destroyed the chest." and it becomes a ruined chest
#   o on a chest with summoning runes: up to three monsters, and the chest empty
#   levels made until three chests are found: their traps and names as Moria's magicalChests() gives them
# each check prints PASS or FAIL, the emulator's files are in build\test\chests
# -Away when nobody is at the machine
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([switch]$Away)
. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\play-lib.ps1"
$script:Proj = 'chests'; $script:Away = [bool]$Away
$script:Pass = 0; $script:Fail = 0

# the dungeon's map and items, N.B: pages 66 on (4 rows of 256 squares of 8 bytes to a page) and 36 on (128 records of 64)
function Sq([int]$r, [int]$c) { $h = Page (66 + [math]::Floor($r / 4)) (($r % 4) * 2048 + $c * 8) 8; @(0..7 | ForEach-Object { [Convert]::ToInt32($h.Substring($_ * 2, 2), 16) }) }
function Set-SqItem([int]$r, [int]$c, [int]$n) { PagePoke (66 + [math]::Floor($r / 4)) (($r % 4) * 2048 + $c * 8 + 3) $n }
function RecPoke([int]$n, [int]$off, [int]$v) { PagePoke (36 + [math]::Floor($n / 128)) (($n % 128) * 64 + $off) $v }
function Rec([int]$n) { $h = Page (36 + [math]::Floor($n / 128)) (($n % 128) * 64) 64; $b = @(0..63 | ForEach-Object { [Convert]::ToInt32($h.Substring($_ * 2, 2), 16) })
    [pscustomobject]@{ Object = $b[0] + 256 * $b[1]; Name = $b[2]; Known = (($b[3] -band 8) -ne 0); Flags = $b[32] + 256 * $b[33]; Category = $b[36] } }
# N.B: all four bytes of the flags, the top two hold what treasure is inside, and Moria's spells test the whole (flags != 0)
function Set-Chest([int]$n, [long]$flags) { foreach ($i in 0..3) { RecPoke $n (32 + $i) (($flags -shr (8 * $i)) -band 255) }; RecPoke $n 3 0; RecPoke $n 2 0 }
# the items lying within 6 squares of the player, "row,col" = item number, a row of 13 squares read at a time
function Items-Near { $p = Player; $out = @{}
    foreach ($r in ($p[0] - 6)..($p[0] + 6)) { $h = Page (66 + [math]::Floor($r / 4)) (($r % 4) * 2048 + ($p[1] - 6) * 8) 104
        foreach ($i in 0..12) { $it = [Convert]::ToInt32($h.Substring($i * 16 + 6, 2), 16); if ($it -ne 0) { $out["$r,$($p[1] - 6 + $i)"] = $it } } }
    $out }
function Check([string]$what, [bool]$ok, [string]$seen) { if ($ok) { $script:Pass++; "PASS  $what" } else { $script:Fail++; "FAIL  $what  [$seen]" } }
function Say-All { Start-Sleep 2; Msgs }

# the eight directions as keys, and where they lead
$dirs = @( @(-1, -1, '7'), @(-1, 0, '8'), @(-1, 1, '9'), @(0, -1, '4'), @(0, 1, '6'), @(1, -1, '1'), @(1, 0, '2'), @(1, 1, '3') )
function Open-Ways { $p = Player; @($dirs | Where-Object { $q = Sq ($p[0] + $_[0]) ($p[1] + $_[1]); $q[0] -le 3 -and $q[3] -eq 0 -and $q[2] -eq 0 }) }

function Wizard-Object([int]$id) {
    # one object of the kind, near the player, by the wizard's %: where it was put and its item number, N.B: found by
    # what has changed, a new item may take the number of one that was picked up, it is not always the highest
    $before = Items-Near
    Press '%'; Start-Sleep 1; Type_ "$id"; Start-Sleep 2; $null = Msgs
    $after = Items-Near
    foreach ($k in $after.Keys) { if ($before[$k] -ne $after[$k]) { $rc = $k -split ','; return @([int]$rc[0], [int]$rc[1], $after[$k]) } }
    $null
}
function New-Chest([int]$flags) {
    # a Large Steel Chest beside the player, in the chest's direction, with the flags given, unknown and unnamed
    $at = Wizard-Object 331; $n = $at[2]; Set-SqItem $at[0] $at[1] 0
    $p = Player; Set-SqItem ($p[0] + $script:ChestWay[0]) ($p[1] + $script:ChestWay[1]) $n
    Set-Chest $n $flags; Ctrl 'r'; Start-Sleep 1
    $n
}
function Get-Wand([int]$id) {
    # a wand of the kind into the pack: made, put under the player, and picked up by stepping off and back
    $at = Wizard-Object $id; $n = $at[2]; Set-SqItem $at[0] $at[1] 0
    $p = Player; Set-SqItem $p[0] $p[1] $n
    Press $script:StepWay[2]; Start-Sleep 1; $null = Msgs
    Press $script:StepBack; Start-Sleep 1
    $m = Msgs; if ($m -match '\(([a-w])\)') { return $Matches[1] }; "no wand: $m" | Write-Host; $null
}
function Cast([string]$book, [string]$spell) {
    # a spell, again if it fails, as it may one time in twenty
    foreach ($try in 1..5) { Press 'm'; Start-Sleep 1; Press $book; Start-Sleep 1; Press $spell; $m = Say-All; if ($m -notmatch 'failed') { return $m } }
    $m
}
function Aim([string]$wand) {
    foreach ($try in 1..5) { Press 'a'; Start-Sleep 1; Press $wand; Start-Sleep 1; Press $script:ChestWay[2]; $m = Say-All; if ($m -notmatch 'failed') { return $m } }
    $m
}

try {
    if (-not (Start-Game -Class 1 -ExitAfter 3600)) { 'no game'; return }
    Wizard; Super
    if (-not (Goto-Level 10)) { 'not on level 10'; return }
    # somewhere with two open squares beside the player: one for the chest, one to step to
    foreach ($try in 1..10) { $ways = Open-Ways; if ($ways.Count -ge 2) { break }; Ctrl 't'; Start-Sleep 2; $null = Msgs }
    if ($ways.Count -lt 2) { 'nowhere with room for a chest'; return }
    $script:ChestWay = $ways[0]; $script:StepWay = $ways[1]
    $script:StepBack = ($dirs | Where-Object { $_[0] -eq -$script:StepWay[0] -and $_[1] -eq -$script:StepWay[1] })[2]
    Ctrl 'f'; Start-Sleep 2; $null = Msgs
    # the pack is all but full after the superhuman command: the last two things in it, the torches and the dagger, go
    Poke16 0xD9F2 19
    "the chest goes the way of key $($script:ChestWay[2]), the player steps the way of key $($script:StepWay[2])"

    # --- the spells and wands, a chest locked and with a poison needle (CH_LOCKED + CH_POISON) each time
    $n = New-Chest 0x21
    $m = Cast 'b' 'c'; $c = Rec $n
    Check "Trap/Door Destruction beside a chest" ($m -match 'You have disarmed the chest\.' -and $c.Flags -eq 0 -and $c.Name -eq 54 -and $c.Known) "$m | flags $($c.Flags) name $($c.Name) known $($c.Known)"
    Set-Chest $n 0x21
    $m = Cast 'a' 'f'; $c = Rec $n
    Check "Find Hidden Traps/Doors: the chest known, its traps left" ($c.Flags -eq 0x21 -and $c.Known) "$m | flags $($c.Flags) known $($c.Known)"
    $tw = Get-Wand 281
    Set-Chest $n 0x21
    $m = Aim $tw; $c = Rec $n
    Check "Wand of Trap/Door Destruction: Click!" ($m -match 'Click!' -and $c.Flags -eq 0 -and $c.Name -eq 54 -and $c.Known) "$m | flags $($c.Flags) name $($c.Name) known $($c.Known)"
    $dw = Get-Wand 286
    Set-Chest $n 0x21
    $m = Aim $dw; $c = Rec $n
    Check "Wand of Disarming: Click!" ($m -match 'Click!' -and $c.Flags -eq 0 -and $c.Name -eq 54 -and $c.Known) "$m | flags $($c.Flags) name $($c.Name) known $($c.Known)"
    Set-Chest $n 0x33800000
    $m = Aim $dw; $c = Rec $n
    Check "Wand of Disarming on a chest with treasure in it but no trap or lock: still Click!, as Moria's (flags != 0)" ($m -match 'Click!') $m
    Set-Chest $n 0
    $m = Aim $dw
    Check "Wand of Disarming on a chest with nothing in its flags: no Click!" ($m -notmatch 'Click!') $m

    # --- disarming by hand
    Set-Chest $n 0x21
    $t0 = Turn; Press 'D'; Start-Sleep 1; Press $script:ChestWay[2]; $m = Say-All
    Check "D, the trap not known: I don't see a trap, and no turn" ($m -match "I don't see a trap\." -and (Turn) -eq $t0) "$m | turns $((Turn) - $t0)"
    RecPoke $n 3 8
    $e0 = Peek16 0xD828
    foreach ($try in 1..5) { Press 'D'; Start-Sleep 1; Press $script:ChestWay[2]; $m = Say-All; if ($m -match 'disarmed') { break } }
    $c = Rec $n
    Check "D, the trap known: disarmed, still locked, experience up by its level (50)" ($m -match 'You have disarmed the chest\.' -and $c.Flags -eq 1 -and $c.Name -eq 47 -and ((Peek16 0xD828) - $e0) -eq 50) "$m | flags $($c.Flags) name $($c.Name) exp +$((Peek16 0xD828) - $e0)"

    # --- searching
    Set-Chest $n 0x21
    $m = ''; foreach ($try in 1..30) { Press 's'; $m = Say-All; if ($m -match 'discovered') { break } }
    $c = Rec $n
    Check "searching finds the trap on the chest" ($m -match 'You have discovered a trap on the chest!' -and $c.Known) $m
    # N.B: each square searched has its own roll, Moria's playerSearch(), so it may take a few
    foreach ($try in 1..30) { Press 's'; $m = Say-All; if ($m -match 'trapped') { break } }
    Check "searching again: The chest is trapped!" ($m -match 'The chest is trapped!') $m

    # --- bashing, a 1 in 10 chance a blow
    Set-Chest $n 0x21
    $seen = @(); foreach ($try in 1..80) { Press 'B'; Start-Sleep -Milliseconds 600; Press $script:ChestWay[2]; $m = Say-All; if ($m -ne 'The chest holds firm.') { $seen += $m }; if ($m -match 'destroyed') { break } }
    $c = Rec $n
    Check "bashing: You have destroyed the chest. and its contents!, a ruined chest (418)" (($seen -join ' ') -match 'You have destroyed the chest\.\s+and its contents!' -and $c.Object -eq 418 -and $c.Flags -eq 0) (($seen -join ' / ') + " | object $($c.Object)")
    "      on the way: " + ($seen -join ' / ')

    # --- opening a chest with summoning runes and no lock
    $p = Player; Set-SqItem ($p[0] + $script:ChestWay[0]) ($p[1] + $script:ChestWay[1]) 0
    $n = New-Chest 0x100
    $m0 = Peek8 0xC22A
    Press 'o'; Start-Sleep 1; Press $script:ChestWay[2]; $m = Say-All
    $c = Rec $n
    # N.B: three tries, each may find no room beside the chest, Moria's placeMonsterAdjacentTo()
    $made = (Peek8 0xC22A) - $m0
    Check "opening a chest with summoning runes: up to three monsters ($made), the chest empty (46)" ($made -ge 1 -and $made -le 3 -and $c.Flags -eq 0 -and $c.Name -eq 46) "$m | monsters +$made flags $($c.Flags) name $($c.Name)"
    Ctrl 'f'; Start-Sleep 2; $null = Msgs

    # --- chests made with the level, Moria's magicalChests(): which traps go with which name
    $names = @{ 0 = 46; 1 = 47; 0x11 = 48; 0x21 = 48; 0x41 = 49; 0x81 = 50; 0x101 = 51; 0x71 = 52; 0x181 = 52 }
    $found = 0
    foreach ($lv in 11..60) {
        if (-not (Goto-Level $lv)) { "level $lv not reached"; break }
        $null = Msgs
        $next = Peek8 0xC214; $hex = (Page 36 0 8192) + (Page 37 0 8192)
        for ($i = 1; $i -lt $next; $i++) {
            if ([Convert]::ToInt32($hex.Substring(($i * 64 + 36) * 2, 2), 16) -eq 2) {
                $c = Rec $i; $traps = $c.Flags -band 0x1F1
                Check "a chest made on level ${lv}: object $($c.Object), traps $('{0:X3}' -f $traps), name $($c.Name)" ($names.ContainsKey($traps) -and $names[$traps] -eq $c.Name -and $c.Object -ge 326 -and $c.Object -le 331) "expected name $($names[$traps])"
                $found++
            }
        }
        if ($found -ge 3) { break }
    }
} finally { $null = Z 'exit-emulator'; Start-Sleep 2; Stop-Game }
"passed $script:Pass, failed $script:Fail"
