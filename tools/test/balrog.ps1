# winning the game, against Moria's code, in one emulator start: a superhuman warrior goes to level 50, where the
# level maker puts the Balrog (monsterPlaceWinning(), or, if not, a summoned monster is made into one), every other
# monster is gone (mass genocide spares it), it is put beside them asleep with 1 hit point left, and the game is
# made scorable again (the wizard's marks taken off, so that "*Winner*" shows, Moria shows "Is wizard" instead), then:
#   the killing blow: "*** CONGRATULATIONS *** You have won the game." and "You cannot save this game, but you may
#     retire when ready.", the winner's flag, "*Winner*" on the status line
#   Ctrl-X: "You are a Total Winner,  your character must be retired." and "Use <Control>-K when you are ready to
#     quit.", and the game goes on
#   Ctrl-K: Moria's kingly() and printCrown(): "King!" by the crown, then the tombstone with "Magnificent", "*King*",
#     the level 40 up, "Ripe Old Age", and the gold 250,000 up
#   the high scores: "Ripe Old Age"
#   Ctrl-W on the opening screen: "Sorry, this character is retired from moria."
# each check prints PASS or FAIL, the emulator's files are in build\test\balrog
# -Away when nobody is at the machine
# N.B: never call a variable $s in these scripts, lib.ps1 keeps its own folder in $script:S
param([switch]$Away)
. "$PSScriptRoot\lib.ps1"
. "$PSScriptRoot\play-lib.ps1"
$script:Proj = 'balrog'; $script:Away = [bool]$Away
$script:Pass = 0; $script:Fail = 0
$w = "$script:Work\$script:Proj"
if (Test-Path $w) { Get-ChildItem $w -File | Where-Object Name -ne 'poc4uat.nex' | ForEach-Object { [IO.File]::Delete($_.FullName) } }

# the dungeon's map and monsters, N.B: pages 66 on (4 rows of 256 squares of 8 bytes to a page) and 33 on (128 records of 64)
function SqPoke([int]$r, [int]$c, [int]$off, [int]$v) { PagePoke (66 + [math]::Floor($r / 4)) (($r % 4) * 2048 + $c * 8 + $off) $v }
function Sq([int]$r, [int]$c) { $h = Page (66 + [math]::Floor($r / 4)) (($r % 4) * 2048 + $c * 8) 8; @(0..7 | ForEach-Object { [Convert]::ToInt32($h.Substring($_ * 2, 2), 16) }) }
function MonPoke([int]$n, [int]$off, [int]$v) { PagePoke 33 ($n * 64 + $off) $v }
function Mon([int]$n) { $h = Page 33 ($n * 64) 16; $b = @(0..15 | ForEach-Object { [Convert]::ToInt32($h.Substring($_ * 2, 2), 16) })
    $hp = $b[0] + 256 * $b[1]; if ($hp -gt 32767) { $hp -= 65536 }
    [pscustomobject]@{ Hp = $hp; Creature = $b[6] + 256 * $b[7]; Row = $b[8]; Col = $b[9] } }
function Check([string]$what, [bool]$ok, [string]$seen) { if ($ok) { $script:Pass++; "PASS  $what" } else { $script:Fail++; "FAIL  $what  [$seen]" } }
function P32([int]$a) { (Peek16 ($a + 2)) * 65536 + (Peek16 $a) }

$dirs = @( @(-1, -1, '7'), @(-1, 0, '8'), @(-1, 1, '9'), @(0, -1, '4'), @(0, 1, '6'), @(1, -1, '1'), @(1, 0, '2'), @(1, 1, '3') )

try {
    if (-not (Start-Game -Class 0 -ExitAfter 3600)) { 'no game'; return }
    Wizard; Super
    if (-not (Goto-Level 50)) { 'not on level 50'; return }
    Ctrl 'f'; Start-Sleep 2; $null = Msgs

    # the Balrog, creature 278, the last of Moria's creatures
    $balrog = $null
    foreach ($n in 2..((Peek8 0xC22A) - 1)) { $m = Mon $n; if ($m.Creature -eq 278 -and $m.Hp -gt 0) { $balrog = $n; break } }
    if ($balrog) { "the level maker put the Balrog down: monster $balrog" }
    else {
        Ctrl 'u'; Start-Sleep 2; $null = Msgs
        $balrog = (Peek8 0xC22A) - 1
        MonPoke $balrog 6 (278 -band 255); MonPoke $balrog 7 1; MonPoke $balrog 14 ([int][char]'B')
        "no Balrog on the level, monster $balrog, summoned, is made into one"
    }

    # beside the player, on an open square, asleep, with 1 hit point
    $p = Player; $way = $null
    foreach ($d in $dirs) { $q = Sq ($p[0] + $d[0]) ($p[1] + $d[1]); if ($q[0] -le 3 -and $q[2] -eq 0) { $way = $d; break } }
    if (-not $way) { 'no room beside the player'; return }
    $m = Mon $balrog; SqPoke $m.Row $m.Col 2 0
    $r = $p[0] + $way[0]; $c = $p[1] + $way[1]
    MonPoke $balrog 8 $r; MonPoke $balrog 9 $c; SqPoke $r $c 2 $balrog
    MonPoke $balrog 0 1; MonPoke $balrog 1 0; MonPoke $balrog 2 255; MonPoke $balrog 3 0
    # scorable again, so that "*Winner*" shows, not "Is wizard"
    Poke8 0xDA4D 0; Poke8 0xDA4C 0
    Ctrl 'r'; Start-Sleep 2; $null = Msgs
    "the Balrog is at $r,$c, the way of key $($way[2])"

    # --- the killing blow, again until a blow lands
    $level = Peek16 0xD834; $gold = P32 0xD820
    $all = ''
    foreach ($try in 1..30) { Press $way[2]; Start-Sleep 2; $m = Msgs; $all += " | $m"; if ($m -match 'CONGRATULATIONS') { break } }
    Check "the Balrog killed: *** CONGRATULATIONS *** You have won the game." ($all -match '\*\*\* CONGRATULATIONS \*\*\* You have won the game\.') $all
    Check "...and: You cannot save this game, but you may retire when ready." ($all -match 'You cannot save this game, but you may retire when ready\.') $all
    Check "the winner's flag" ((Peek8 0xC22B) -eq 1) "$(Peek8 0xC22B)"
    Ctrl 'r'; Start-Sleep 2
    Check "*Winner* on the status line" ((Row 22) -match '^\*Winner\*') (Row 22)
    $level = Peek16 0xD834; $gold = P32 0xD820

    # --- Ctrl-X is refused
    Ctrl 'x'; $m = Msgs
    Check "Ctrl-X: You are a Total Winner,  your character must be retired. / Use <Control>-K when you are ready to quit." ($m -match 'You are a Total Winner,  your character must be retired\.' -and $m -match 'Use <Control>-K when you are ready to quit\.') $m
    Start-Sleep 2
    Check "...and the game goes on" ((Row 23) -match '2500 feet') (Row 23)

    # --- retiring
    Ctrl 'k'; Start-Sleep 1; Key 121
    $ok = WaitFor 17 45 'King!' 60
    Check "the crown: King!" $ok ((Row 17))
    Key 32
    $ok = WaitFor 22 0 'Character record?' 60
    $tomb = 5..17 | ForEach-Object { (Row $_).TrimEnd() }
    $tomb | ForEach-Object { "      $_" }
    $text = $tomb -join "`n"
    Check "the tombstone: Magnificent, *King*, Ripe Old Age" ($text -match 'Magnificent' -and $text -match '\*King\*' -and $text -match 'Ripe Old Age') ''
    Check "...the level 40 up ($level to $($level + 40))" ((Row 11).Substring(30, 3).Trim() -eq "$($level + 40)") (Row 11)
    Check "...the gold 250,000 up ($gold to $($gold + 250000))" ($text -match "\b$($gold + 250000) Au") ''
    Esc
    if (WaitFor 23 23 '[ press any key' 60) {
        $scores = 2..8 | ForEach-Object { (Row $_).TrimEnd() } | Where-Object { $_ }
        $scores | ForEach-Object { "      $_" }
        Check "the high scores: Ripe Old Age" (($scores -join ' ') -match 'Ripe Old Age') ''
        Key 32
    } else { Check "the high scores" $false 'not shown' }

    # --- a retired winner cannot be brought back
    $null = WaitFor 5 28 'D U N G E O N S' 60
    Ctrl 'w'
    $ok = WaitFor 10 4 'Sorry, this character is retired from moria.' 60
    Check "Ctrl-W: Sorry, this character is retired from moria." $ok ((Row 10))
} finally { $null = Z 'exit-emulator'; Start-Sleep 2; Stop-Game }
"passed $script:Pass, failed $script:Fail"
