# the game's state, read out of the memory of a running ZXMoria in the emulator and printed as text, in the same form as
# umoria-save.py prints a saved game of the real Umoria, so that the two can be compared line by line:
# the game's numbers, the map (what each square is made of, and its flags), what lies on it, the monsters, and the six stores
# dot-source lib.ps1 first, with the game running, then: Get-ZxState | Set-Content <file>
# N.B: the layouts are those in constants.bas and globals.bas: the core's data page (32), the map squares (8 bytes, 4 rows of
# 256 to a page), the 64 byte records of items and monsters (128 to a page), the stores' state and their stock (page 40)

# a page of the Next's memory, or part of one, as bytes, read in pieces of 2KB
function PageBytes([int]$page, [int]$offset = 0, [int]$length = 8192){
    $out = New-Object byte[] $length
    for($at = 0; $at -lt $length; $at += 2048){
        $n = [Math]::Min(2048, $length - $at)
        $hex = Page $page ($offset + $at) $n
        if(-not $hex -or $hex.Length -lt $n * 2){ throw "page $page at $($offset + $at): read $($hex.Length / 2) bytes of $n" }
        for($i = 0; $i -lt $n; $i++){ $out[$at + $i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
    }
    ,$out
}
function U16($b, $at){ [BitConverter]::ToUInt16($b, $at) }
function S16($b, $at){ [BitConverter]::ToInt16($b, $at) }
function U32($b, $at){ [BitConverter]::ToUInt32($b, $at) }
function S32($b, $at){ [BitConverter]::ToInt32($b, $at) }

# one 64 byte record, from pages already read: $pages is a hash of page number to its bytes
function RecordAt($pages, [int]$first, [int]$index){
    $page = $first + [Math]::Floor($index / 128)
    if(-not $pages.ContainsKey($page)){ $pages[$page] = PageBytes $page }
    $b = $pages[$page]; $at = ($index % 128) * 64
    ,([byte[]]$b[$at..($at + 63)])
}
function ItemText($r){
    'obj {0} cat {1} sub {2} n {3} special {4} p1 {5} cost {6} wt {7} hit {8} dam {9} ac {10} toac {11} {12}d{13} flags {14:X8}' -f `
        (U16 $r 0), $r[36], $r[44], $r[45], $r[2], (S16 $r 38), (S32 $r 40), (U16 $r 46), (S16 $r 48), (S16 $r 50), (S16 $r 52), (S16 $r 54), $r[56], $r[57], (U32 $r 32)
}

# the last messages, oldest first, as Ctrl-P keeps them: the ring of 22 in page 42 (UB_PAGE_MESSAGES, 80 bytes each),
# gub_log_next (core data + 6993) the place the next one goes, then the one showing now (A_MESSAGE_LINE, core data + 6912)
# N.B: ours remembers "Which direction?" and the like too, Moria does not, see not-yet.md
function Get-ZxMessages {
    $ring = PageBytes 42 0 1760; $now = PageBytes 32 6912 82; $next = $now[81]
    $text = { param($b, $at) ([Text.Encoding]::ASCII.GetString($b, $at, 80) -replace "`0.*$", '').TrimEnd() }
    for($n = 0; $n -lt 22; $n++){ $m = & $text $ring ((($next + $n) % 22) * 80); if($m){ $m } }
    $m = & $text $now 0; if($m){ "(showing) $m" }
}

function Get-ZxState {
    $core = PageBytes 32
    $game = 512; $player = 6144
    $level = U16 $core ($game + 16); $rows = $core[$game + 18]; $cols = $core[$game + 19]
    $mapPage = $core[$game + 21]; $itemsPage = $core[$game + 22]; $monstersPage = $core[$game + 23]
    # where the player is: Player in lib.ps1 reads it from $D9E9, the core's data page is at $C000
    $py = $core[0xD9E9 - 0xC000]; $px = $core[0xD9EA - 0xC000]
    '# game'
    'turn {0}' -f (S32 $core ($game + 24))
    'gold {0} exp {1} max_exp {2}' -f (S32 $core ($player + 32)), (S32 $core ($player + 40)), (S32 $core ($player + 36))
    'hp {0} hp_fraction {1} max_hp {2} mana {3} mana_fraction {4} max_mana {5}' -f (S16 $core ($player + 100)), (U16 $core ($player + 102)), (S16 $core ($player + 66)), (S16 $core ($player + 96)), (U16 $core ($player + 98)), (S16 $core ($player + 64))
    # N.B: shown as Moria's saveChar() leaves them, as Umoria's state comes from its saved game: resting and searching
    # turned off (a major playerDisturb()), and the pack's weight taken out of the speeds, so every monster's speed is
    # moved by $speedFix, see the monsters below, ZXMoria's own save does the same since 15 October 2026
    $status = U32 $core ($player + 374); $speedFix = -(S16 $core ($player + 502))
    if($status -band 0x100){ $status = $status -band (-bnot 0x100); $speedFix -= 1 }
    $status = $status -band (-bnot 0x200)
    # Moria's bits that only ask for the screen to be drawn again (PY_ARMOR, PY_STATS, PY_HP, PY_MANA), left out of both,
    # see umoria-save.py, ours uses none of them
    $status = $status -band 0x00BFFFFF
    'food {0} rest {1} status {2:X8}' -f (S16 $core ($player + 386)), 0, $status
    # the 23 counters after rest, in Moria's order, at 380 to 424 in the player's record, as umoria-save.py prints them:
    # the food digested and the speed as the save leaves them (resting off adds 1, searching off takes 1 away, and the
    # speed loses the pack's weight and the searching)
    $orig = U32 $core ($player + 374)
    $counters = for($o = 380; $o -le 424; $o += 2){ S16 $core ($player + $o) }
    if($orig -band 0x200){ $counters[4] += 1 }
    if($orig -band 0x100){ $counters[4] -= 1 }
    $counters[6] += $speedFix
    'counters ' + ($counters -join ' ')
    # what Moria's next randomNumber( 256 ) - 1 would be, the Park and Miller generator, so that it can be set beside the byte
    # that Umoria's save begins with, which is that, and shows whether the two games' random numbers are still in step
    $script:ZxSeed = U32 $core $game
    'next random(256) - 1: {0}' -f (((16807 * [uint64]$script:ZxSeed) % 2147483647) % 256)
    'magic seed {0}' -f (U32 $core ($game + 8))
    'town seed {0}' -f (U32 $core ($game + 12))
    "level $level"
    "player $py,$px"
    "size ${rows}x$cols"
    # the stats, Moria's four sets of six, at 344 in the player's record (A_PLAYER_STATS_MAX and on in globals.bas), and
    # what is carried: the 34 records at 2048 in the core's data (A_INVENTORY), 22 places in the pack, then 12 of equipment
    '# stats'
    'max {0} current {1} modified {2} used {3}' -f ($core[($player + 344)..($player + 349)] -join ' '), ($core[($player + 350)..($player + 355)] -join ' '), ((0..5 | ForEach-Object { S16 $core ($player + 356 + 2 * $_) }) -join ' '), ($core[($player + 368)..($player + 373)] -join ' ')
    $unique = S16 $core ($player + 498)
    "# pack: $unique"
    for($i = 0; $i -lt $unique; $i++){ "$i " + (ItemText ([byte[]]$core[(2048 + $i * 64)..(2048 + $i * 64 + 63)])) }
    '# carrying: weight {0} equipment {1}' -f (S16 $core ($player + 500)), (S16 $core ($player + 504))
    '# spells'
    'learnt {0:X8} worked {1:X8} forgotten {2:X8} order {3}' -f (U32 $core ($player + 445)), (U32 $core ($player + 449)), (U32 $core ($player + 453)), ($core[($player + 457)..($player + 488)] -join ' ')
    # the kinds of thing known, tried and so on: 448 bytes at 6912 in the page of what the player knows, 63 (A_KNOW_IDENTIFIED)
    '# known kinds'
    $known = PageBytes 63 6912 448
    for($i = 0; $i -lt 448; $i++){ if($known[$i]){ '{0} {1:X2}' -f $i, $known[$i] } }
    '# equipment'
    # N.B: an empty place is category 0, see umoria-save.py
    for($i = 0; $i -lt 12; $i++){ $at = 2048 + (22 + $i) * 64; "$i " + $(if($core[$at + 36] -eq 0){ 'empty' } else { ItemText ([byte[]]$core[$at..($at + 63)]) }) }
    $pages = @{}
    $squares = foreach($y in 0..($rows - 1)){
        $page = $mapPage + [Math]::Floor($y / 4)
        if(-not $pages.ContainsKey($page)){ $pages[$page] = PageBytes $page }
        $at = ($y % 4) * 2048
        ,([byte[]]$pages[$page][$at..($at + $cols * 8 - 1)])
    }
    '# map features'
    foreach($row in $squares){ -join (0..($cols - 1) | ForEach-Object { '{0:X}' -f ($row[$_ * 8] -band 15) }) }
    '# map flags'
    foreach($row in $squares){ -join (0..($cols - 1) | ForEach-Object { '{0:X}' -f ($row[$_ * 8 + 1] -band 15) }) }
    $records = @{}
    '# things on the map'
    foreach($y in 0..($rows - 1)){ foreach($x in 0..($cols - 1)){
        $i = $squares[$y][$x * 8 + 3]
        if($i){ "$y,$x #$i " + (ItemText (RecordAt $records $itemsPage $i)) }
    } }
    '# monsters on the map'
    foreach($y in 0..($rows - 1)){ foreach($x in 0..($cols - 1)){
        $m = $squares[$y][$x * 8 + 2]
        if($m -gt 1){
            $r = RecordAt $records $monstersPage $m
            '{0},{1} #{2} creature {3} hp {4} sleep {5} speed {6} stunned {7} confused {8} distance {9} lit {10}' -f $y, $x, $m, (U16 $r 6), (S16 $r 0), (S16 $r 2), ((S16 $r 4) + $speedFix), $r[12], $r[13], $r[10], $r[11]
        }
    } }
    # the monster memory: 20 bytes for each of the 279 kinds of creature at the start of page 63 (UB_PAGE_KNOWLEDGE), laid
    # out as Moria's Recall_t, see ful_core_recall() in core.bas, a line for each kind that Moria's save would keep: those
    # with anything known but how often one woke or slept on
    '# monster memory'
    $mem = PageBytes 63 0 5580
    foreach($i in 0..278){
        $a = $i * 20
        if((U32 $mem $a) -or (U32 $mem ($a + 4)) -or (U16 $mem ($a + 8)) -or (U16 $mem ($a + 10)) -or (U16 $mem ($a + 12)) -or (U32 $mem ($a + 16))){
            '{0} movement {1:X8} spells {2:X8} kills {3} deaths {4} defenses {5:X4} wake {6} ignore {7} attacks {8} {9} {10} {11}' -f $i, (U32 $mem $a), (U32 $mem ($a + 4)), (U16 $mem ($a + 8)), (U16 $mem ($a + 10)), (U16 $mem ($a + 12)), $mem[$a + 14], $mem[$a + 15], $mem[$a + 16], $mem[$a + 17], $mem[$a + 18], $mem[$a + 19]
        }
    }
    foreach($n in 0..5){
        $at = 1536 + $n * 16; $count = $core[$at + 7]
        '# store {0}: owner {1} items {2} turns_left {3} insults {4} good {5} bad {6}' -f $n, $core[$at + 6], $count, (S32 $core $at), (S16 $core ($at + 4)), (U16 $core ($at + 8)), (U16 $core ($at + 10))
        for($i = 0; $i -lt $count; $i++){
            $r = RecordAt $records 40 ($n * 24 + $i)
            "paid $(S32 $r 20) " + (ItemText $r)
        }
    }
}
