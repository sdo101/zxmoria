# builds the game's database pages from the Moria source, so that nothing is ever typed in by hand and nothing is left out
#   creatures.bin   one 64 byte record per creature type,  from creatures_list[] in data_creatures.cpp
#   objects.bin     one 64 byte record per object type,    from game_objects[]   in data_treasure.cpp
# the record layouts are set out below, the same layouts are declared as variables in globals.bas (gxx_creature_..., gxx_object_...)
# sjasmplus.cfg puts the files into the NEX, build.ps1 runs this script before it does so, and has them written to build\data
param(
    [string]$SourceDir = (Join-Path $PSScriptRoot '..\..\..\umoria\src'),  # the Moria source
    [string]$OutDir    = (Join-Path $PSScriptRoot '..\build\data'),        # where the data pages are written
    [string]$TextDir   = $PSScriptRoot                                      # where our own text sources are, e.g. splash.txt, beside this script in src
)
$ErrorActionPreference = 'Stop'
If ( -not ( Test-Path -Path $OutDir -PathType Container ) ) { $null = New-Item -Path $OutDir -ItemType Directory -Force }
$RecordSize = 64

# every named number in the Moria headers, e.g. TV_FOOD = 80, so that the tables can use them
$Named = @{}
foreach ($h in Get-ChildItem $SourceDir -Filter *.h) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($h.FullName), 'constexpr\s+\w+\s+(\w+)\s*=\s*(-?(?:0x[0-9A-Fa-f]+|\d+))[UL]*\s*;')) {
        $Named[$m.Groups[1].Value] = $m.Groups[2].Value
    }
}

function Convert-Token([string]$t) {
    # one value from a table row, as a number: a character such as 'p', hex such as 0x0012000AL, a plain number, or a named number
    if ($t -match "^'\\(.)'$")  { return [long][char]$Matches[1] }
    if ($t -match "^'(.)'$")    { return [long][char]$Matches[1] }
    if ($t -match '^(-?)0x([0-9A-Fa-f]+)[UL]*$') { $v = [Convert]::ToInt64($Matches[2], 16); if ($Matches[1]) { $v = -$v }; return $v }
    if ($t -match '^(-?\d+)[UL]*$') { return [long]$Matches[1] }
    if ($Named.ContainsKey($t)) { return Convert-Token $Named[$t] }
    throw "cannot work out the value of '$t'"
}

function Read-Table([string]$file, [string]$tableName, [int]$valuesPerRow) {
    # returns one entry per row of a table in the C++ source: the name, and the row's other values as numbers, in order
    $text  = [IO.File]::ReadAllText((Join-Path $SourceDir $file))
    $start = $text.IndexOf($tableName + '[')
    if ($start -lt 0) { throw "$tableName not found in $file" }
    $end   = $text.IndexOf("`n};", $start)
    $rows  = New-Object Collections.Generic.List[object]
    foreach ($line in $text.Substring($start, $end - $start) -split "`n") {
        if ($line -notmatch '^\s*\{\s*"((?:[^"\\]|\\.)*)"\s*,(.*)$') { continue }
        $name = $Matches[1] -replace '\\(.)', '$1'
        $rest = ($Matches[2] -replace '//.*$', '')                      # drop the comment at the end of the row
        $tokens = [regex]::Matches($rest, "'(?:\\.|[^'])'|-?0x[0-9A-Fa-f]+[UL]*|-?\d+[UL]*|[A-Za-z_]\w*") | ForEach-Object { $_.Value }
        if ($tokens.Count -ne $valuesPerRow) { throw "$tableName row '$name' has $($tokens.Count) values, expected $valuesPerRow" }
        $rows.Add([pscustomobject]@{ Name = $name; V = @($tokens | ForEach-Object { Convert-Token $_ }) })
    }
    $rows
}

# a record being filled in, with a check that every value really fits the space it is given
$script:Rec = $null; $script:What = ''
function Put-Text([int]$at, [int]$size, [string]$s) {
    if ($s.Length -gt $size - 1) { throw "$script:What: text '$s' is longer than $($size - 1) characters" }
    for ($i = 0; $i -lt $s.Length; $i++) { $c = [int][char]$s[$i]; if ($c -lt 32 -or $c -gt 126) { throw "$script:What: '$s' has a character outside plain ASCII" }; $script:Rec[$at + $i] = $c }
}
function Put-Number([int]$at, [int]$bytes, [long]$v, [switch]$Signed) {
    $bits = 8 * $bytes
    if ($Signed) { $lo = -[Math]::Pow(2, $bits - 1); $hi = [Math]::Pow(2, $bits - 1) - 1 } else { $lo = 0; $hi = [Math]::Pow(2, $bits) - 1 }
    if ($v -lt $lo -or $v -gt $hi) { throw "$script:What: value $v does not fit in $bytes byte(s) at offset $at" }
    if ($v -lt 0) { $v += [long][Math]::Pow(2, $bits) }
    for ($i = 0; $i -lt $bytes; $i++) { $script:Rec[$at + $i] = [byte](($v -shr (8 * $i)) -band 255) }     # low byte first, as the Z80 wants
}

# --- colours ------------------------------------------------------------------------------------------------------------------
# the colours of things on the map, ours, not Moria's, from colours.txt beside this script (which says how it works): each colour
# used is given a pair of the tilemap's palette, from pair 16 up, and the attribute byte that shows it, 2 x the pair, goes into
# byte 50 of a creature's record, byte 59 of an object's, and the flavour table of the game tables page; the palette itself
# goes into the game tables page too, for the core to load as it starts, see s_core_load_palette() in core.bas
$ColourRgb = @{}; $CreatureWords = @(); $ObjectWords = @(); $ClassColour = @{}; $FlavourColour = @{}; $InvisibleColour = $null
foreach ($line in [IO.File]::ReadAllLines((Join-Path $TextDir 'colours.txt'))) {
    $t = ($line -replace '#.*$', '').Trim()
    if (-not $t) { continue }
    $f = @($t -split '\|' | ForEach-Object { $_.Trim() })
    switch ($f[0].ToLower()) {
        'colour'    { if ($f[2] -notmatch '^[0-7]{3}$') { throw "colours.txt: $line" }; $ColourRgb[$f[1].ToLower()] = ([int]"$($f[2][0])" -shl 6) -bor ([int]"$($f[2][1])" -shl 3) -bor [int]"$($f[2][2])" }
        'creature'  { $CreatureWords += , @($f[1], $f[2]) }
        'object'    { $ObjectWords += , @($f[1], $f[2], $f[3]) }
        'class'     { $ClassColour[[int]$Named[$f[1]]] = $f[2] }
        'flavour'   { $FlavourColour["$($f[1].ToLower())|$($f[2].ToLower())"] = $f[3] }
        'invisible' { $InvisibleColour = $f[1] }
        default     { throw "colours.txt: what is this? $line" }
    }
}
$Pairs = [ordered]@{}                               # 9 bit colour -> palette pair
$ColourReport = New-Object Collections.Generic.List[string]
function Get-Attribute([string]$colour) {
    if ($colour -eq 'none') { return 0 }            # no colour of its own: drawn as the map's own rules have it, see s_core_map_put()
    $rgb = $ColourRgb[$colour.ToLower()]
    if ($null -eq $rgb) { throw "colours.txt has no colour called '$colour'" }
    $key = "$rgb"                                   # N.B: a text key, an [ordered] takes a number for a position
    if (-not $Pairs.Contains($key)) {
        if ($Pairs.Count -ge 112) { throw "colours.txt wants more than 112 colours, the palette has room for no more" }
        $Pairs[$key] = 16 + $Pairs.Count
    }
    2 * $Pairs[$key]
}
function Test-Phrase([string]$name, [string]$phrase) { $name -match ('(?i)(?<![\w-])' + [regex]::Escape($phrase) + '(?![\w-])') }
function Get-CreatureColour([string]$name, [long]$movement) {
    if (($movement -band 0x10000) -ne 0) { return $InvisibleColour }      # CM_INVISIBLE
    $best = $null
    foreach ($w in $CreatureWords) { if ((Test-Phrase $name $w[0]) -and (-not $best -or $w[0].Length -gt $best[0].Length)) { $best = $w } }
    if ($best) { return $best[1] }
    $null                                                                   # red, as before: the core's default
}
function Get-ObjectColour([string]$name, [int]$category) {
    $plain = $name -replace '[&~]', ''
    foreach ($scope in 'category', 'any') {
        $best = $null
        foreach ($w in $ObjectWords) {
            $ok = $(if ($scope -eq 'category') { $w[0] -ne '*' -and [int]$Named[$w[0]] -eq $category } else { $w[0] -eq '*' })
            if ($ok -and (Test-Phrase $plain $w[1]) -and (-not $best -or $w[1].Length -gt $best[1].Length)) { $best = $w }
        }
        if ($best) { return $best[2] }
    }
    if (-not $ClassColour.ContainsKey($category)) { throw "colours.txt has no colour for category $category ('$name')" }
    $ClassColour[$category]
}
# the flavoured kinds, whose colour is their flavour's, put into the objects as each game shuffles the flavours, see
# s_ob_flavour_colours() in stage-lib-objects.bas: potions, wands, staffs, rings, amulets, and mushrooms (food from
# ITEM_SINGLE_STACK_MIN up whose low six bits are 20 or less, as Moria's itemDescription() has them)
function Test-Flavoured([int]$category, [int]$sub) {
    if ($category -in [int]$Named['TV_POTION1'], [int]$Named['TV_POTION2'], [int]$Named['TV_WAND'], [int]$Named['TV_STAFF'], [int]$Named['TV_RING'], [int]$Named['TV_AMULET']) { return $true }
    $category -eq [int]$Named['TV_FOOD'] -and $sub -ge 64 -and ($sub -band 63) -le 20       # mushrooms and hairy molds, as itemDescription()
}

# --- creatures ----------------------------------------------------------------------------------------------------------------
#   offset  size  field                     Moria's Creature_t
#        0    26  name, ends in a 0         name
#       26     4  movement                  movement            bit field
#       30     4  spells                    spells              bit field
#       34     2  defenses                  defenses            bit field
#       36     2  kill experience           kill_exp_value
#       38     1  sleep counter             sleep_counter
#       39     1  area affect radius        area_affect_radius
#       40     1  armour class              ac
#       41     1  speed                     speed               (+10, so that it is never negative)
#       42     1  sprite                    sprite              the character shown on the map
#       43     2  hit dice: number, sides   hit_die
#       45     4  attacks                   damage[4]           numbers of entries in the monster attacks table
#       49     1  level                     level
#       50    14  spare
$creatures = Read-Table 'data_creatures.cpp' 'creatures_list' 16
$bytes = New-Object byte[] ($creatures.Count * $RecordSize); $n = 0
foreach ($c in $creatures) {
    $script:Rec = New-Object byte[] $RecordSize; $script:What = "creature $n"; $v = $c.V
    Put-Text   0 26 $c.Name
    Put-Number 26 4 $v[0]
    Put-Number 30 4 $v[1]
    Put-Number 34 2 $v[2]
    Put-Number 36 2 $v[3]
    Put-Number 38 1 $v[4]
    Put-Number 39 1 $v[5]
    Put-Number 40 1 $v[6]
    Put-Number 41 1 $v[7]
    Put-Number 42 1 $v[8]
    Put-Number 43 1 $v[9]
    Put-Number 44 1 $v[10]
    for ($i = 0; $i -lt 4; $i++) { Put-Number (45 + $i) 1 $v[11 + $i] }
    Put-Number 49 1 $v[15]
    $colour = Get-CreatureColour $c.Name $v[0]
    if ($colour) { Put-Number 50 1 (Get-Attribute $colour) }
    $ColourReport.Add("creature $n $($c.Name): $(if ($colour) { $colour } else { 'red, as before' })")
    [Array]::Copy($script:Rec, 0, $bytes, $n * $RecordSize, $RecordSize); $n++
}
[IO.File]::WriteAllBytes((Join-Path $OutDir 'creatures.bin'), $bytes)
"creatures.bin: $($creatures.Count) creatures, $($bytes.Length) bytes, $([Math]::Ceiling($bytes.Length / 8192)) pages; last is '$($creatures[-1].Name)', longest name $(($creatures | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)"

# --- creature levels ----------------------------------------------------------------------------------------------------------
# how many kinds of creature there are of each level or less, worked out the way Moria does when it starts,
# initializeMonsterLevels() in game_run.cpp, the last 2 creatures (MON_ENDGAME_MONSTERS) are left out, they are only ever put
# down on purpose, the creatures are already in order of level, so "a creature of level 5" is one of a run of them
# sjasmplus.cfg puts this file in the core data page, 4480 bytes in, so that it is never paged (see A_TABLE_MONSTER_LEVELS
# in constants.bas)
#   offset  size  what
#        0    82  how many creatures are of each level or less, 41 entries of 2 bytes       monster_levels[]
$monMaxLevels = [int](Convert-Token 'MON_MAX_LEVELS'); $endgame = [int][regex]::Match([IO.File]::ReadAllText((Join-Path $SourceDir 'config.cpp')), 'MON_ENDGAME_MONSTERS\s*=\s*(\d+)').Groups[1].Value
if ($monMaxLevels -ne 40 -or $endgame -ne 2) { throw "MON_MAX_LEVELS is $monMaxLevels and MON_ENDGAME_MONSTERS is $endgame, expected 40 and 2" }
$monsterLevels = New-Object int[] ($monMaxLevels + 1); $lastLevel = 0
for ($i = 0; $i -lt $creatures.Count - $endgame; $i++) {
    $level = [int]$creatures[$i].V[15]
    if ($level -lt $lastLevel) { throw "creature $i is of level $level, after one of level $lastLevel, the creatures are not in order of level" }
    $lastLevel = $level; $monsterLevels[$level]++
}
for ($i = 1; $i -le $monMaxLevels; $i++) { $monsterLevels[$i] += $monsterLevels[$i - 1] }
$script:Rec = New-Object byte[] (2 * ($monMaxLevels + 1)); $script:What = 'creature levels'
for ($i = 0; $i -le $monMaxLevels; $i++) { Put-Number (2 * $i) 2 $monsterLevels[$i] }
[IO.File]::WriteAllBytes((Join-Path $OutDir 'creaturelevels.bin'), $script:Rec)
"creaturelevels.bin: $($monsterLevels[$monMaxLevels]) creatures by level, $($monsterLevels[0]) of them townspeople, $($script:Rec.Length) bytes"

# --- objects ------------------------------------------------------------------------------------------------------------------
#   offset  size  field                     Moria's DungeonObject_t
#        0    32  name, ends in a 0         name                with Moria's own markers in it, & for a/an, ~ for a plural s, etc.
#       32     4  flags                     flags               bit field
#       36     1  category                  category_id         (tval)
#       37     1  sprite                    sprite              the character shown on the map
#       38     2  misc use, signed          misc_use            (p1)
#       40     4  cost, signed              cost
#       44     1  sub category              sub_category_id     (subval)
#       45     1  number of items           items_count
#       46     2  weight                    weight
#       48     2  to hit, signed            to_hit
#       50     2  to damage, signed         to_damage
#       52     2  armour class, signed      ac
#       54     2  to armour class, signed   to_ac
#       56     2  damage dice: number, sides    damage
#       58     1  depth first found         depth_first_found
#       59     1  colour                    ours: its attribute byte on the map, see colours.txt, 0 for a flavoured kind
#       60     4  spare
$objects = Read-Table 'data_treasure.cpp' 'game_objects' 15
$bytes = New-Object byte[] ($objects.Count * $RecordSize); $n = 0
foreach ($o in $objects) {
    $script:Rec = New-Object byte[] $RecordSize; $script:What = "object $n"; $v = $o.V
    Put-Text   0 32 $o.Name
    Put-Number 32 4 $v[0]
    Put-Number 36 1 $v[1]
    Put-Number 37 1 $v[2]
    Put-Number 38 2 $v[3] -Signed
    Put-Number 40 4 $v[4] -Signed
    Put-Number 44 1 $v[5]
    Put-Number 45 1 $v[6]
    Put-Number 46 2 $v[7]
    Put-Number 48 2 $v[8] -Signed
    Put-Number 50 2 $v[9] -Signed
    Put-Number 52 2 $v[10] -Signed
    Put-Number 54 2 $v[11] -Signed
    Put-Number 56 1 $v[12]
    Put-Number 57 1 $v[13]
    Put-Number 58 1 $v[14]
    if (Test-Flavoured $v[1] $v[5]) {
        $ColourReport.Add("object $n $($o.Name): its flavour's")
    } else {
        $colour = Get-ObjectColour $o.Name $v[1]
        Put-Number 59 1 (Get-Attribute $colour)
        $ColourReport.Add("object $n $($o.Name): $colour")
    }
    [Array]::Copy($script:Rec, 0, $bytes, $n * $RecordSize, $RecordSize); $n++
}
[IO.File]::WriteAllBytes((Join-Path $OutDir 'objects.bin'), $bytes)
"objects.bin:   $($objects.Count) objects, $($bytes.Length) bytes, $([Math]::Ceiling($bytes.Length / 8192)) pages; last is '$($objects[-1].Name)', longest name $(($objects | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum)"

# --- object levels ------------------------------------------------------------------------------------------------------------
# which objects are found at which depth, worked out the way Moria does when it starts, initializeTreasureLevels() in game_run.cpp...
# ...only the first 344 objects (MAX_DUNGEON_OBJECTS) are ever found lying in the dungeon, the rest are store stock, doors, traps etc.
# sjasmplus.cfg puts this file in the last page of the objects database, 4096 bytes in, after the last object (see UB_PAGE_OBJECT_LEVELS
# in constants.bas)
#   offset  size  what
#        0   102  how many objects are found at each depth or above, 51 entries of 2 bytes      treasure_levels[]
#      128   688  the object numbers in order of depth, 344 entries of 2 bytes                  sorted_objects[]
$maxDungeonObjects = [int]$Named['MAX_DUNGEON_OBJECTS']; $maxLevels = [int]$Named['TREASURE_MAX_LEVELS']
if ($maxDungeonObjects -ne 344 -or $maxLevels -ne 50) { throw "MAX_DUNGEON_OBJECTS is $maxDungeonObjects and TREASURE_MAX_LEVELS is $maxLevels, expected 344 and 50" }
$treasureLevels = New-Object int[] ($maxLevels + 1)
for ($i = 0; $i -lt $maxDungeonObjects; $i++) { $treasureLevels[[int]$objects[$i].V[14]]++ }
for ($i = 1; $i -le $maxLevels; $i++) { $treasureLevels[$i] += $treasureLevels[$i - 1] }
$indexes = New-Object int[] ($maxLevels + 1); for ($i = 0; $i -le $maxLevels; $i++) { $indexes[$i] = 1 }
$sorted = New-Object int[] $maxDungeonObjects
for ($i = 0; $i -lt $maxDungeonObjects; $i++) { $level = [int]$objects[$i].V[14]; $sorted[$treasureLevels[$level] - $indexes[$level]] = $i; $indexes[$level]++ }
$script:Rec = New-Object byte[] (128 + 2 * $maxDungeonObjects); $script:What = 'object levels'
for ($i = 0; $i -le $maxLevels; $i++) { Put-Number (2 * $i) 2 $treasureLevels[$i] }
for ($i = 0; $i -lt $maxDungeonObjects; $i++) { Put-Number (128 + 2 * $i) 2 $sorted[$i] }
[IO.File]::WriteAllBytes((Join-Path $OutDir 'objectlevels.bin'), $script:Rec)
"objectlevels.bin: $maxDungeonObjects objects in order of depth, $($treasureLevels[0]) of them found in the town, $($script:Rec.Length) bytes"

# --- tables -------------------------------------------------------------------------------------------------------------------
# small tables that the core wants to hand all the time, sjasmplus.cfg loads this file straight into the core data page (see A_NORMAL_TABLE
# and A_ATTACKS in constants.bas), so they are never paged
#   offset  size  what
#        0   512  the normal distribution table, 256 entries of 2 bytes          normal_table[]    in data_tables.cpp
#      512   860  the monster attacks, 215 entries of 4 bytes:                   monster_attacks[] in data_creatures.cpp
#                 attack type, description, damage dice: number, sides
function Read-Numbers([string]$file, [string]$tableName) {
    $text  = [IO.File]::ReadAllText((Join-Path $SourceDir $file))
    $start = $text.IndexOf($tableName + '[')
    if ($start -lt 0) { throw "$tableName not found in $file" }
    $start = $text.IndexOf('{', $start)
    $end   = $text.IndexOf("`n};", $start)
    $body  = ($text.Substring($start, $end - $start) -split "`n" | ForEach-Object { $_ -replace '//.*$', '' }) -join ' '
    @([regex]::Matches($body, '\d+') | ForEach-Object { [long]$_.Value })
}
$normal  = Read-Numbers 'data_tables.cpp' 'normal_table'
$attacks = Read-Numbers 'data_creatures.cpp' 'monster_attacks'
if ($normal.Count -ne 256) { throw "normal_table has $($normal.Count) entries, expected 256" }
if ($attacks.Count -ne 215 * 4) { throw "monster_attacks has $($attacks.Count) values, expected 860" }
#     1372   160  the experience needed for each level, 40 entries of 4 bytes     levels[] in player_stats.cpp
if ([IO.File]::ReadAllText((Join-Path $SourceDir 'player_stats.cpp')) -notmatch 'levels\[PLAYER_MAX_LEVEL\]\s*=\s*\{([^}]*)\}') { throw 'levels[] not found in player_stats.cpp' }
$expLevels = @([regex]::Matches($Matches[1], '\d+') | ForEach-Object { [long]$_.Value })
if ($expLevels.Count -ne 40) { throw "levels[] has $($expLevels.Count) entries, expected 40" }
$script:Rec = New-Object byte[] (512 + 860 + 160); $script:What = 'tables'
for ($i = 0; $i -lt 256; $i++) { Put-Number (2 * $i) 2 $normal[$i] }
for ($i = 0; $i -lt 860; $i++) { Put-Number (512 + $i) 1 $attacks[$i] }
for ($i = 0; $i -lt 40; $i++) { Put-Number (1372 + 4 * $i) 4 $expLevels[$i] }
[IO.File]::WriteAllBytes((Join-Path $OutDir 'tables.bin'), $script:Rec)
"tables.bin:    normal distribution table, $($attacks.Count / 4) monster attacks and $($expLevels.Count) experience levels, $($script:Rec.Length) bytes"

# --- screens ------------------------------------------------------------------------------------------------------------------
# whole screens of text, shown by stage-splash.bas: the opening screen, from splash.txt in the src folder, followed by the
# credits, which are Umoria's AUTHORS file, complete, a screenful at a time, so that nobody's credit is left out or reworded
# each screen is 32 rows of 81 bytes: the row's colour, then its 80 characters, i.e. 2592 bytes, and 3 screens share a page...
# ...so screen n is in page UB_PAGE_SCREENS + n / 3, starting ( n mod 3 ) * 2592 bytes into it
# the file is always 2 pages long (room for 6 screens), and the number of screens there really are is its very last byte
# N.B: capitals and small letters are different colours, so this must be a table that tells them apart, an ordinary @{ } does not
$Colours = New-Object Collections.Hashtable ([StringComparer]::Ordinal)
'W', 30, 'w', 14, 'Y', 28, 'y', 12, 'C', 26, 'G', 24, 'R', 20, 'D', 16 | ForEach-Object -Begin { $k = $null } -Process { if ($null -eq $k) { $k = $_ } else { $Colours[$k] = $_; $k = $null } }     # the UB_ colour numbers in constants.bas
$UmoriaDir = Join-Path $SourceDir '..'
$verText = [IO.File]::ReadAllText((Join-Path $SourceDir 'version.h'))
$UmoriaVersion = (@('MAJOR', 'MINOR', 'PATCH') | ForEach-Object { if ($verText -notmatch "CURRENT_VERSION_$_\s*=\s*(\d+)") { throw "no version $_ in version.h" }; $Matches[1] }) -join '.'

$Screens = New-Object Collections.Generic.List[object]
function New-Screen { $rows = New-Object object[] 32; for ($i = 0; $i -lt 32; $i++) { $rows[$i] = @('w', '') }; $Screens.Add($rows); , $rows }
function Centre([string]$s) { (' ' * [Math]::Max(0, [int][Math]::Floor((80 - $s.Length) / 2))) + $s }

# the opening screen
$rows = New-Screen; $r = 0
foreach ($line in [IO.File]::ReadAllLines((Join-Path $TextDir 'splash.txt'))) {
    if ($line.StartsWith(';')) { continue }
    if ($line -notmatch '^(.)\|(.*)$' -or -not $Colours.ContainsKey($Matches[1])) { throw "splash.txt: every row must start with a colour letter and a |, this one does not: '$line'" }
    if ($r -ge 32) { throw 'splash.txt has more than 32 rows' }
    $c = $Matches[1]; $text = $Matches[2].Replace('${umoria_version}', $UmoriaVersion)
    if ($text.StartsWith('^')) { $text = Centre $text.Substring(1) }
    $rows[$r] = @($c, $text); $r++
}

# the credits: the AUTHORS file, with its # headings in yellow, the names in bright white, and what they did in white
$credit = New-Object Collections.Generic.List[object]
foreach ($line in [IO.File]::ReadAllLines((Join-Path $UmoriaDir 'AUTHORS'))) {
    $line = $line.TrimEnd()
    if ($line -match '^#+\s*(.*)$')      { $c = 'Y'; $line = $Matches[1] }
    elseif ($line -match '^\s')          { $c = 'w' }
    elseif ($line -match '\[-\w+-\]|\((GPL|Public Domain)') { $c = 'W' }
    else                                 { $c = 'w' }
    # a line too long for the screen is carried over at a space
    while ($line.Length -gt 76) { $cut = $line.LastIndexOf(' ', 76); $credit.Add(@($c, $line.Substring(0, $cut))); $line = $line.Substring($cut + 1) }
    $credit.Add(@($c, $line))
}
# a screenful is rows 2 to 28, break only at a blank line so that a name is never parted from what follows it
$pages = New-Object Collections.Generic.List[object]; $page = New-Object Collections.Generic.List[object]; $i = 0
while ($i -lt $credit.Count) {
    $j = $i; while ($j -lt $credit.Count -and $credit[$j][1] -ne '') { $j++ }      # $i to $j - 1 is one block, up to the next blank line
    $block = $j - $i
    if ($block -gt 27) { throw 'a block in AUTHORS is too long for one screen' }
    if ($page.Count -gt 0 -and $page.Count + 1 + $block -gt 27) { $pages.Add($page); $page = New-Object Collections.Generic.List[object] }
    if ($page.Count -gt 0 -and $block -gt 0) { $page.Add(@('w', '')) }
    for ($k = $i; $k -lt $j; $k++) { $page.Add($credit[$k]) }
    $i = $j + 1
}
if ($page.Count -gt 0) { $pages.Add($page) }
$n = 0
foreach ($page in $pages) {
    $n++; $rows = New-Screen
    $rows[0] = @('C', (Centre "ZXMoria credits, $n of $($pages.Count)"))
    for ($k = 0; $k -lt $page.Count; $k++) { $rows[2 + $k] = @($page[$k][0], ('  ' + $page[$k][1])) }
    $rows[30] = @('G', (Centre $(if ($n -lt $pages.Count) { '[ press any key for more, or Q to go straight on ]' } else { '[ press any key ]' })))
}

if ($Screens.Count -gt 6) { throw "there are $($Screens.Count) screens, screens.bin and sjasmplus.cfg only have room for 6" }
$script:Rec = New-Object byte[] 16384; $script:What = 'screens'; $number = 0
foreach ($rows in $Screens) {
    # N.B: three screens to a page, and a screen never straddles two pages, so the fourth screen starts at the start of the second page
    $at = [Math]::Floor($number / 3) * 8192 + ($number % 3) * 2592; $number++
    foreach ($row in $rows) {
        if ($row[1].Length -gt 80) { throw "a screen row is longer than 80 characters: '$($row[1])'" }
        $script:Rec[$at] = $Colours[$row[0]]
        Put-Text ($at + 1) 81 $row[1].PadRight(80)
        $at += 81
    }
}
$script:Rec[16383] = $Screens.Count
[IO.File]::WriteAllBytes((Join-Path $OutDir 'screens.bin'), $script:Rec)
"screens.bin:   $($Screens.Count) screens, the opening screen and $($pages.Count) of credits, for Umoria $UmoriaVersion"

# --- character ----------------------------------------------------------------------------------------------------------------
# everything needed to make a new character, one page exactly, stage-player.bas reads it (UB_PAGE_CHARACTER_DB in constants.bas)
#   offset  size  what
#        0   512  the 8 races, 64 bytes each          character_races[]        in data_player.cpp
#      512   384  the 6 classes, 64 bytes each        classes[] and class_level_adj[]
#      896    60  what each class starts with, 6 classes of 5 object numbers     class_base_provisions[]
#     1024  7168  the 128 backgrounds, 56 bytes each  character_backgrounds[]
$playerText = [IO.File]::ReadAllText((Join-Path $SourceDir 'data_player.cpp'))
function Get-Block([string]$tableName) { $a = $playerText.IndexOf($tableName + '['); if ($a -lt 0) { throw "$tableName not found" }; $b = $playerText.IndexOf("`n};", $a); ($playerText.Substring($a, $b - $a) -split "`n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n" }
$page = New-Object byte[] 8192

# a race:
#   offset  size  field                     Moria's Race_t
#        0    16  name, ends in a 0         name
#       16     6  adjustments, signed       str, int, wis, dex, con, chr _adjustment
#       22     2  age: base, random part    base_age, max_age
#       24     4  male: height base and spread, weight base and spread
#       28     4  female: the same four
#       32    14  7 signed 2 byte values    disarm_chance_base, search_chance_base, stealth, fos, base_to_hit, base_to_hit_bows, saving_throw_base
#       46     1  hit points base           hit_points_base
#       47     1  infra vision              infra_vision
#       48     1  experience factor         exp_factor_base
#       49     1  classes allowed, 1 bit each, bit 0 = the first class     classes_bit_field
$races = [regex]::Matches((Get-Block 'character_races'), '\{\s*"([^"]+)"\s*,([^{}]*)\}')
if ($races.Count -ne 8) { throw "found $($races.Count) races, expected 8" }
$n = 0
foreach ($m in $races) {
    $v = @([regex]::Matches($m.Groups[2].Value, '-?0x[0-9A-Fa-f]+|-?\d+') | ForEach-Object { Convert-Token $_.Value })
    if ($v.Count -ne 27) { throw "race '$($m.Groups[1].Value)' has $($v.Count) values, expected 27" }
    $script:Rec = New-Object byte[] 64; $script:What = "race $n"
    Put-Text 0 16 $m.Groups[1].Value
    for ($i = 0; $i -lt 6; $i++)  { Put-Number (16 + $i) 1 $v[$i] -Signed }
    for ($i = 0; $i -lt 10; $i++) { Put-Number (22 + $i) 1 $v[6 + $i] }
    for ($i = 0; $i -lt 7; $i++)  { Put-Number (32 + 2 * $i) 2 $v[16 + $i] -Signed }
    for ($i = 0; $i -lt 4; $i++)  { Put-Number (46 + $i) 1 $v[23 + $i] }
    [Array]::Copy($script:Rec, 0, $page, $n * 64, 64); $n++
}

# a class:
#   offset  size  field                     Moria's Class_t
#        0    16  title, ends in a 0        title
#       16     8  hit points, disarm, searching, stealth, frequency of search, to hit, to hit with bows, saving throw
#       24     6  adjustments, signed       strength, intelligence, wisdom, dexterity, constitution, charisma
#       30     1  kind of spells            class_to_use_mage_spells    0 none, 1 mage's spells, 2 priest's prayers
#       31     1  experience factor         experience_factor
#       32     1  first level with spells   min_level_for_spell_casting
#       33     5  gain per level            class_level_adj[]: to hit, to hit with bows, magic devices, disarming, saving throw
$spellTypes = @{}; foreach ($m in [regex]::Matches([IO.File]::ReadAllText((Join-Path $SourceDir 'config.cpp')), 'SPELL_TYPE_(\w+)\s*=\s*(\d+)')) { $spellTypes[$m.Groups[1].Value] = $m.Groups[2].Value }
$classText = (Get-Block 'classes') -replace 'config::spells::SPELL_TYPE_(\w+)', { $spellTypes[$_.Groups[1].Value] }
$classes = [regex]::Matches($classText, '\{\s*"([^"]+)"\s*,([^{}]*)\}')
$adj = @([regex]::Matches(((Get-Block 'class_level_adj') -replace '^[^=]*=', ''), '-?\d+') | ForEach-Object { [long]$_.Value })
if ($classes.Count -ne 6 -or $adj.Count -ne 30) { throw "found $($classes.Count) classes and $($adj.Count) level adjustments, expected 6 and 30" }
$n = 0
foreach ($m in $classes) {
    $v = @([regex]::Matches($m.Groups[2].Value, '-?\d+') | ForEach-Object { [long]$_.Value })
    if ($v.Count -ne 17) { throw "class '$($m.Groups[1].Value)' has $($v.Count) values, expected 17" }
    $script:Rec = New-Object byte[] 64; $script:What = "class $n"
    Put-Text 0 16 $m.Groups[1].Value
    for ($i = 0; $i -lt 8; $i++) { Put-Number (16 + $i) 1 $v[$i] }
    for ($i = 0; $i -lt 6; $i++) { Put-Number (24 + $i) 1 $v[8 + $i] -Signed }
    for ($i = 0; $i -lt 3; $i++) { Put-Number (30 + $i) 1 $v[14 + $i] }
    for ($i = 0; $i -lt 5; $i++) { Put-Number (33 + $i) 1 $adj[5 * $n + $i] }
    [Array]::Copy($script:Rec, 0, $page, 512 + $n * 64, 64); $n++
}

# a background, one piece of a character's history:
#   offset  size  field                     Moria's Background_t
#        0     1  roll                      roll        the piece is used if the 1 to 100 roll is no higher than this
#        1     1  chart                     chart       which part of the history this is a choice for
#        2     1  next                      next        the chart to go on to, 0 to stop
#        3     1  bonus                     bonus       social class + 50
#        4    52  text, ends in a 0         info
$backs = [regex]::Matches((Get-Block 'character_backgrounds'), '\{\s*"((?:[^"\\]|\\.)*)"\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}')
if ($backs.Count -ne 128) { throw "found $($backs.Count) backgrounds, expected 128" }
$n = 0
foreach ($m in $backs) {
    $script:Rec = New-Object byte[] 56; $script:What = "background $n"
    for ($i = 0; $i -lt 4; $i++) { Put-Number $i 1 ([long]$m.Groups[2 + $i].Value) }
    Put-Text 4 52 ($m.Groups[1].Value -replace '\\(.)', '$1')
    [Array]::Copy($script:Rec, 0, $page, 1024 + $n * 56, 56); $n++
}
# what each class starts with: 5 object numbers of 2 bytes each, at 896        class_base_provisions[] in data_player.cpp
$provisions = @([regex]::Matches(((Get-Block 'class_base_provisions') -replace '^[^=]*=', ''), '\d+') | ForEach-Object { [long]$_.Value })
if ($provisions.Count -ne 30) { throw "class_base_provisions has $($provisions.Count) values, expected 30" }
$script:Rec = $page; $script:What = 'starting equipment'
for ($i = 0; $i -lt 30; $i++) { Put-Number (896 + 2 * $i) 2 $provisions[$i] }[IO.File]::WriteAllBytes((Join-Path $OutDir 'character.bin'), $page)
"character.bin: $($races.Count) races, $($classes.Count) classes, $($backs.Count) backgrounds, $($page.Length) bytes"

# --- spells -------------------------------------------------------------------------------------------------------------------
# what each class's spells and prayers cost, and what they are called, sjasmplus.cfg puts this file in the last page of the objects
# database, 5120 bytes in, after the object levels (see A_TABLE_SPELLS in constants.bas)
#   offset  size  what
#        0   620  the spells of the 5 classes that have them, 31 each, 4 bytes a spell       magic_spells[] in data_player.cpp
#                 (the level it can first be learnt at, the mana it takes, how likely it is to fail, and a quarter
#                 of the experience for first casting it), the classes in Moria's order less the warrior: mage,
#                 priest, rogue, ranger, paladin
#      640  1736  the names of the 31 spells and then the 31 prayers, 28 bytes each           spell_names[] in data_player.cpp
$spellNumbers = Read-Numbers 'data_player.cpp' 'magic_spells'
if ($spellNumbers.Count -ne 5 * 31 * 4) { throw "magic_spells has $($spellNumbers.Count) values, expected 620" }
$spellText = [IO.File]::ReadAllText((Join-Path $SourceDir 'data_player.cpp'))
$m = [regex]::Match($spellText, '(?s)spell_names\[62\]\s*=\s*\{(.*?)\n\};')
if (-not $m.Success) { throw 'spell_names[] not found in data_player.cpp' }
$spellNames = @([regex]::Matches((($m.Groups[1].Value -split "`n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n"), '"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
if ($spellNames.Count -ne 62) { throw "spell_names has $($spellNames.Count) entries, expected 62" }
$script:Rec = New-Object byte[] (640 + 62 * 28); $script:What = 'spells'
for ($i = 0; $i -lt 620; $i++) { Put-Number $i 1 $spellNumbers[$i] }
for ($i = 0; $i -lt 62; $i++) { Put-Text (640 + 28 * $i) 28 $spellNames[$i] }
[IO.File]::WriteAllBytes((Join-Path $OutDir 'spells.bin'), $script:Rec)
"spells.bin:    $($spellNumbers.Count / 4) spells and prayers for 5 classes, $($spellNames.Count) names, longest '$(($spellNames | Sort-Object Length | Select-Object -Last 1))', $($script:Rec.Length) bytes"

# --- game tables --------------------------------------------------------------------------------------------------------------
# small tables that never change, read from the paged data when they are wanted (UB_PAGE_GAME_TABLES in constants.bas)
#   offset  size  what
#        0  1152  the 18 store owners, 64 bytes each          store_owners[]            in data_store_owners.cpp
#     1152   312  what each store stocks, 6 stores of 26      store_choices[]           in data_stores.cpp
#                 object numbers, 2 bytes each
#     1464    64  how each race of owner prices for each      race_gold_adjustments[]   in data_stores.cpp
#                 race of player, 8 rows of 8 bytes, a percentage
$page = New-Object byte[] 8192

# a store owner:
#   offset  size  field                     Moria's Owner_t
#        0    52  name, ends in a 0         name            their name, their race and their store, as one line of text
#       52     2  the most they will pay    max_cost
#       54     1  highest mark up, %        max_inflate
#       55     1  lowest mark up, %         min_inflate
#       56     1  haggle step, %            haggles_per
#       57     1  race                      race
#       58     1  insults they will take    max_insults
$ownerText = ([IO.File]::ReadAllText((Join-Path $SourceDir 'data_store_owners.cpp')) -split "`n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n"
$a = $ownerText.IndexOf('store_owners['); $b = $ownerText.IndexOf("`n};", $a)
$owners = [regex]::Matches($ownerText.Substring($a, $b - $a), '\{\s*"([^"]+)"\s*,([^{}]*)\}')
if ($owners.Count -ne 18) { throw "found $($owners.Count) store owners, expected 18" }
$n = 0
foreach ($m in $owners) {
    $v = @([regex]::Matches($m.Groups[2].Value, '-?\d+') | ForEach-Object { [long]$_.Value })
    if ($v.Count -ne 6) { throw "store owner '$($m.Groups[1].Value)' has $($v.Count) values, expected 6" }
    $script:Rec = New-Object byte[] 64; $script:What = "store owner $n"
    Put-Text 0 52 $m.Groups[1].Value
    Put-Number 52 2 $v[0]
    for ($i = 1; $i -lt 6; $i++) { Put-Number (53 + $i) 1 $v[$i] }
    [Array]::Copy($script:Rec, 0, $page, $n * 64, 64); $n++
}

$choices = Read-Numbers 'data_stores.cpp' 'store_choices'
$raceAdj = Read-Numbers 'data_stores.cpp' 'race_gold_adjustments'
if ($choices.Count -ne 6 * 26) { throw "store_choices has $($choices.Count) values, expected 156" }
if ($raceAdj.Count -ne 64) { throw "race_gold_adjustments has $($raceAdj.Count) values, expected 64" }
$script:Rec = $page; $script:What = 'game tables'
for ($i = 0; $i -lt 156; $i++) { Put-Number (1152 + 2 * $i) 2 $choices[$i] }
for ($i = 0; $i -lt 64; $i++)  { Put-Number (1464 + $i) 1 $raceAdj[$i] }

# the names that items go by, each list is fixed width so that entry n is found by multiplying...
#     2048   784  49 potion colours, 16 bytes each           colors[]              in data_tables.cpp
#     3072   352  22 mushroom kinds, 16 bytes each           mushrooms[]
#     3584   400  25 staff woods, 16 bytes each              woods[]
#     4096   400  25 wand metals, 16 bytes each              metals[]
#     4608   512  32 ring stones, 16 bytes each              rocks[]
#     5632   176  11 amulet materials, 16 bytes each         amulets[]
#     5888   765  153 syllables for scroll titles, 5 each    syllables[]
#     6656  1100  55 special names, 20 bytes each            special_item_names[]  e.g. "of Slay Evil"
$nameText = ''
foreach ($file in 'data_tables.cpp', 'identification.cpp', 'data_treasure.cpp') { $nameText += [IO.File]::ReadAllText((Join-Path $SourceDir $file)) }
function Put-Names([string]$list, [int]$at, [int]$width, [int]$count) {
    $m = [regex]::Match($nameText, "(?s)\b$list\[[^\]]*\]\s*=\s*\{(.*?)\n\};")
    if (-not $m.Success) { throw "the list $list was not found in the Moria source" }
    $body  = ($m.Groups[1].Value -split "`n" | ForEach-Object { $_ -replace '//.*$', '' }) -join "`n"
    $names = @([regex]::Matches($body, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value -replace '\\(.)', '$1' })
    if ($names.Count -ne $count) { throw "$list has $($names.Count) entries, expected $count" }
    $script:Rec = $page; $script:What = $list
    for ($i = 0; $i -lt $count; $i++) { Put-Text ($at + $i * $width) $width $names[$i] }
}
Put-Names 'colors'              2048 16 49
Put-Names 'mushrooms'           3072 16 22
Put-Names 'woods'               3584 16 25
Put-Names 'metals'              4096 16 25
Put-Names 'rocks'               4608 16 32
Put-Names 'amulets'             5632 16 11
Put-Names 'syllables'           5888  5 153
Put-Names 'special_item_names'  6656 20 55

# the colours, ours, see colours.txt:
#     1536   164  each flavour's attribute byte, in the order of the six lists above: 49 potion colours, 22 mushroom
#                 kinds, 25 woods, 25 metals, 32 stones, 11 amulet materials
#     1792     1  how many pairs of the palette, from pair 16, the colours use
#     1793   224  each pair's ink, two bytes as NEXTREG_PALETTE_VALUE_9 takes them: RRRGGGBB, then the lowest blue bit
$at = 1536
foreach ($l in @(@('colors', 49), @('mushrooms', 22), @('woods', 25), @('metals', 25), @('rocks', 32), @('amulets', 11))) {
    $m = [regex]::Match($nameText, "(?s)\b$($l[0])\[[^\]]*\]\s*=\s*\{(.*?)\n\};")
    $names = @([regex]::Matches($m.Groups[1].Value, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value })
    if ($names.Count -ne $l[1]) { throw "$($l[0]) has $($names.Count) entries, expected $($l[1])" }
    foreach ($nm in $names) {
        $colour = $FlavourColour["$($l[0])|$($nm.ToLower())"]
        if (-not $colour) { throw "colours.txt has no colour for the $($l[0]) flavour '$nm'" }
        $script:Rec = $page; $script:What = 'flavour colours'
        Put-Number $at 1 (Get-Attribute $colour); $at++
        $ColourReport.Add("flavour $($l[0]) $($nm): $colour")
    }
}
$script:Rec = $page; $script:What = 'palette'
Put-Number 1792 1 $Pairs.Count
$i = 0
foreach ($key in $Pairs.Keys) {
    $rgb = [int]$key
    Put-Number (1793 + 2 * $i) 1 ($rgb -shr 1)
    Put-Number (1794 + 2 * $i) 1 ($rgb -band 1)
    $i++
}
[IO.File]::WriteAllLines((Join-Path $OutDir 'colours-report.txt'), $ColourReport)
"colours: $($Pairs.Count) colours of the palette's 112 spare pairs, see colours-report.txt for what each thing is given"
[IO.File]::WriteAllBytes((Join-Path $OutDir 'gametables.bin'), $page)
"gametables.bin: $($owners.Count) store owners, the stock lists of 6 stores, the race price table, the names items go by, $($page.Length) bytes"

# --- strings ------------------------------------------------------------------------------------------------------------------
# the game's text, kept out of the code: every string has a number, constants.bas names the first number of each group...
#   stringsindex.bin    4 bytes per string: which page of text it is in (0 for the first), where it starts in that
#                       page (2 bytes), and its length including the 0 on its end
#   stringstext.bin     the strings themselves, each ending in a 0, packed end to end, a string never crosses from one
#                       8KB page into the next, the last few bytes of a page are left unused instead
# the groups, in order, each is one of Moria's arrays, the number after it is how many strings it must have, a check
# that constants.bas and the Moria source still agree:
$StringGroups = @(
    @('data_store_owners.cpp', 'speech_sale_accepted',          14),    # UW_STR_SALE_ACCEPTED     = 0
    @('data_store_owners.cpp', 'speech_selling_haggle_final',    3),    # UW_STR_SELLING_FINAL     = 14
    @('data_store_owners.cpp', 'speech_selling_haggle',         16),    # UW_STR_SELLING_HAGGLE    = 17
    @('data_store_owners.cpp', 'speech_buying_haggle_final',     3),    # UW_STR_BUYING_FINAL      = 33
    @('data_store_owners.cpp', 'speech_buying_haggle',          15),    # UW_STR_BUYING_HAGGLE     = 36
    @('data_store_owners.cpp', 'speech_insulted_haggling_done',  5),    # UW_STR_INSULTED          = 51
    @('data_store_owners.cpp', 'speech_get_out_of_my_store',     5),    # UW_STR_GET_OUT           = 56
    @('data_store_owners.cpp', 'speech_haggling_try_again',     10),    # UW_STR_TRY_AGAIN         = 61
    @('data_store_owners.cpp', 'speech_sorry',                   5),    # UW_STR_SORRY             = 71
    @('data_player.cpp',       'class_rank_titles',            240)     # UW_STR_RANK_TITLES       = 76, 40 for each of the 6 classes
)
$allStrings = New-Object Collections.Generic.List[string]
foreach ($g in $StringGroups) {
    $text = [IO.File]::ReadAllText((Join-Path $SourceDir $g[0]))
    $m = [regex]::Match($text, "(?s)\b$($g[1])(?:\[[^\]]*\])+\s*=\s*\{(.*?)\n\};")
    if (-not $m.Success) { throw "the strings $($g[1]) were not found in $($g[0])" }
    $body = ($m.Groups[1].Value -split "`n" | ForEach-Object { $_ -replace '^\s*//.*$', '' }) -join "`n"
    $found = @([regex]::Matches($body, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value -replace '\\(.)', '$1' })
    if ($found.Count -ne $g[2]) { throw "$($g[1]) has $($found.Count) strings, expected $($g[2])" }
    "               strings $($allStrings.Count) to $($allStrings.Count + $found.Count - 1): $($g[1])"
    $allStrings.AddRange([string[]]$found)
}
# our own messages, from messages.txt, after Moria's, each has a number in constants.bas, which must be the place it gets here
$constants = [IO.File]::ReadAllText((Join-Path $TextDir 'constants.bas'))
$ours = 0
foreach ($line in [IO.File]::ReadAllLines((Join-Path $TextDir 'messages.txt'))) {
    if ($line.Trim() -eq '' -or $line.StartsWith('#')) { continue }
    if ($line -notmatch '^(\w+)\s+(.+?)\s*$') { throw "messages.txt: cannot make sense of '$line'" }
    $name = $Matches[1]; $message = $Matches[2]
    if ($constants -notmatch "(?m)^\s*Const\s+UW_MSG_$name\s+As\s+UInteger\s*=\s*$($allStrings.Count)\b") { throw "constants.bas should have:  Const   UW_MSG_$name   As UInteger = $($allStrings.Count)" }
    $allStrings.Add($message); $ours++
}
"               strings $($allStrings.Count - $ours) to $($allStrings.Count - 1): our own messages, messages.txt"
if ($allStrings.Count -gt 2048) { throw 'more than 2048 strings, the index needs its second page, see sjasmplus.cfg' }
$index = New-Object byte[] 8192
$textPages = New-Object Collections.Generic.List[byte[]]
$pageBytes = New-Object byte[] 8192; $used = 0; $n = 0
foreach ($str in $allStrings) {
    if ($str.Length + 1 -gt 255) { throw "string $n is longer than 254 characters" }
    if ($used + $str.Length + 1 -gt 8192) { $textPages.Add($pageBytes); $pageBytes = New-Object byte[] 8192; $used = 0 }
    for ($i = 0; $i -lt $str.Length; $i++) { $c = [int][char]$str[$i]; if ($c -lt 32 -or $c -gt 126) { throw "string $n has a character outside plain ASCII: '$str'" }; $pageBytes[$used + $i] = $c }
    $index[4 * $n]     = $textPages.Count
    $index[4 * $n + 1] = $used -band 255
    $index[4 * $n + 2] = $used -shr 8
    $index[4 * $n + 3] = $str.Length + 1
    $used += $str.Length + 1; $n++
}
$textPages.Add($pageBytes)
if ($textPages.Count -gt 6) { throw "the strings now need $($textPages.Count) pages of text, there are only 6 for them, 57 to 62, see sjasmplus.cfg" }
$textUsed = $textPages.Count
# N.B: always exactly 6 pages, the ones not needed yet are empty, so that sjasmplus.cfg never has to change
while ($textPages.Count -lt 6) { $textPages.Add((New-Object byte[] 8192)) }
[IO.File]::WriteAllBytes((Join-Path $OutDir 'stringsindex.bin'), $index)
[IO.File]::WriteAllBytes((Join-Path $OutDir 'stringstext.bin'), [byte[]]($textPages | ForEach-Object { $_ }))
"strings:       $($allStrings.Count) strings, $textUsed of the 6 pages of text in use, $used bytes in the last of them"

# ---------------------------------------------------------------------------------------------------------------
# helptext.bin: two texts for the text library that there is no room for in its own page, one data page, see sjasmplus.cfg
# and UB_PAGE_HELP_TEXT in constants.bas, each line ends in a 13 and a 0 follows the last:
#   at 0      the commands with the rogue like keys, Moria's rl_help.txt as far as its table goes, and then a few
#             words of our own
#   at 4096   the wizard's commands with the rogue like keys, Moria's rl_help_wizard.txt
# N.B: until 13-Oct-2026 this was the end of licence.bin, five pages with the whole GNU General Public License in front of
# these two, for Ctrl-V to show as Moria's does; the game no longer shows it, the licence is the file LICENSE beside
# this script, which build.ps1 puts on the SD card as zxmoria.lic
$helpText = New-Object byte[] 8192
function Put-Text([int]$at, [int]$room, [string[]]$lines) {
    $p = $at
    foreach ($line in $lines) {
        if ($line.Length -gt 79) { throw "a line of help is longer than 79 characters: '$line'" }
        foreach ($ch in $line.ToCharArray()) { $c = [int]$ch; if ($c -lt 32 -or $c -gt 126) { throw "help text has a character outside plain ASCII: '$line'" }; $helpText[$p] = $c; $p++ }
        $helpText[$p] = 13; $p++
    }
    $helpText[$p] = 0
    if ($p - $at -ge $room) { throw "a help text is $($p - $at) bytes, it has only $room" }
}
$rlHelp = @([IO.File]::ReadAllLines((Join-Path $UmoriaDir 'data\rl_help.txt')) | Select-Object -First 26 | ForEach-Object { $_.TrimEnd() })
$rlHelp[0] = 'Rogue like commands (@ is optional count, ~ is direction, CTRL is EXTEND)'
$rlHelp += @(
    '',
    'To give a count to a command, type the number in digits, then the command.',
    'A count of 0 defaults to a count of 99.',
    '',
    'Also: CTRL-W is wizard mode, = sets the options,',
    'and that is where to go back to the original commands.'
)
Put-Text 0 4096 $rlHelp
$rlWizard = @('Wizard commands, rogue like (CTRL is the EXTEND key)', '') + @([IO.File]::ReadAllLines((Join-Path $UmoriaDir 'data\rl_help_wizard.txt')) | ForEach-Object { $_.TrimEnd() }) + @('$  - Superhuman: stats, level, gold, arms, armour and a full pack (not Moria''s)', '', 'A count before ^D, ^G or + is the level, how many, or the experience.')
Put-Text 4096 4096 $rlWizard
[IO.File]::WriteAllBytes((Join-Path $OutDir 'helptext.bin'), $helpText)
"helptext.bin:  the two rogue like help texts, 1 page"
