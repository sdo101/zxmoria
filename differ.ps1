# differ.ps1: the differences between this project and another, side by side, after the manner of OpenVMS DCL's
# DIFFERENCES /PARALLEL
#   the left-hand side is the project you are in (the folder you stand in, or the project it is part of, the folder
#   with the .git in it), the known and tested one, in green; the right-hand side the project named, the folder of
#   that name beside it, the one compared against it, in red, e.g. standing in D:\zxnext\projects\zxmoria:
#       .\differ.ps1 poc4uat                    everything that differs, zxmoria on the left, poc4uat on the right
#       .\differ.ps1 poc4uat -Width 200         wider, (200 - 3) / 2 = 98 characters a side, the default 160 gives 78
#       .\differ.ps1 poc4uat -ListOnly          only the list of the files that differ
#       .\differ.ps1 poc4uat -Filter *.bas      only the files whose names match, in the list and after
#       .\differ.ps1 poc4uat -Context 0         only the lines that differ, none of the same lines either side
#       .\differ.ps1 poc4uat -Pause             the prompt before every difference as well as at each full page
#       .\differ.ps1 poc4uat -NoPage            no prompts, all of it at once (| more gets nothing, see "the paging")
#       .\differ.ps1 poc4uat -Out diff.txt      all of it into a file to read later, plain text, nothing on the screen
#   at the prompt: space a page, enter a line, n on to the next difference, f to the next file, q (or escape) to stop
# first a list of the files that differ, a file on one side only coloured as such (green on the left only, red on the
# right only: where you stand, proven, green, what it is compared with red), files the same are not listed; then each file that
# differs, a section at a time: a heading with the lines of each side it covers, the lines that differ side by side
# (changed yellow, only on the left green, only on the right red), and -Context lines of what is the same either side
# (grey), a long line folded on to the next row rather than cut short
# the files compared: those in the project's own folder and in src (not the folders below them) with one of the
# -Extensions, .bas, .cfg, .bat and .ps1 (sdo, 22 October), so this script too
# N.B: line endings do not count, a file that differs only in CRLF against LF is the same; -IgnoreSpace ignores spaces
#      at the ends of lines and runs of spaces within them, -IgnoreCase upper against lower case
# N.B: written 22 October 2026, the comparing itself is Myers' O(ND) difference algorithm (the "bisect" form, as in
#      Google's diff-match-patch), in C# compiled once a session by Add-Type, PowerShell alone is too slow for it
param(
    [Parameter(Mandatory, Position = 0)][string]$Other,
    [int]$Width = 160,
    [int]$Context = 3,
    [string]$Filter = '*',
    [switch]$ListOnly,
    [switch]$Pause,
    [switch]$NoPage,
    [string]$Out = '',
    [switch]$IgnoreSpace,
    [switch]$IgnoreCase,
    [string[]]$Extensions = @('.bas', '.cfg', '.bat', '.ps1'),
    [string[]]$Folders = @('.', 'src')
)
$ErrorActionPreference = 'Stop'

# --- the comparing, in C# ---------------------------------------------------------------------------------------------
if (-not ('ZxDiffer.Myers' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
namespace ZxDiffer {
    public static class Myers {
        // the lines the two have in common, as pairs of line numbers (from 0), in order
        public static List<int[]> Matches(int[] a, int[] b) {
            var m = new List<int[]>();
            Lcs(a, 0, a.Length, b, 0, b.Length, m);
            return m;
        }
        static void Lcs(int[] a, int aLo, int aHi, int[] b, int bLo, int bHi, List<int[]> m) {
            while (aLo < aHi && bLo < bHi && a[aLo] == b[bLo]) { m.Add(new[] { aLo, bLo }); aLo++; bLo++; }
            int aEnd = aHi, bEnd = bHi;
            while (aLo < aEnd && bLo < bEnd && a[aEnd - 1] == b[bEnd - 1]) { aEnd--; bEnd--; }
            if (aLo < aEnd && bLo < bEnd) {
                int x, y;
                if (Bisect(a, aLo, aEnd, b, bLo, bEnd, out x, out y)) {
                    Lcs(a, aLo, x, b, bLo, y, m);
                    Lcs(a, x, aEnd, b, y, bEnd, m);
                }
            }
            for (int i = 0; aEnd + i < aHi; i++) m.Add(new[] { aEnd + i, bEnd + i });
        }
        // where the middle snake of the shortest edit is, the two halves either side of it are compared on their own
        static bool Bisect(int[] a, int aLo, int aHi, int[] b, int bLo, int bHi, out int sx, out int sy) {
            int n = aHi - aLo, mm = bHi - bLo;
            int maxD = (n + mm + 1) / 2, off = maxD, len = 2 * maxD + 2;
            var v1 = new int[len]; var v2 = new int[len];
            for (int i = 0; i < len; i++) { v1[i] = -1; v2[i] = -1; }
            v1[off + 1] = 0; v2[off + 1] = 0;
            int delta = n - mm; bool front = (delta % 2 != 0);
            int k1start = 0, k1end = 0, k2start = 0, k2end = 0;
            for (int d = 0; d < maxD; d++) {
                for (int k1 = -d + k1start; k1 <= d - k1end; k1 += 2) {
                    int k1o = off + k1, x1;
                    if (k1 == -d || (k1 != d && v1[k1o - 1] < v1[k1o + 1])) x1 = v1[k1o + 1]; else x1 = v1[k1o - 1] + 1;
                    int y1 = x1 - k1;
                    while (x1 < n && y1 < mm && a[aLo + x1] == b[bLo + y1]) { x1++; y1++; }
                    v1[k1o] = x1;
                    if (x1 > n) k1end += 2;
                    else if (y1 > mm) k1start += 2;
                    else if (front) {
                        int k2o = off + delta - k1;
                        if (k2o >= 0 && k2o < len && v2[k2o] != -1 && x1 >= n - v2[k2o]) { sx = aLo + x1; sy = bLo + y1; return true; }
                    }
                }
                for (int k2 = -d + k2start; k2 <= d - k2end; k2 += 2) {
                    int k2o = off + k2, x2;
                    if (k2 == -d || (k2 != d && v2[k2o - 1] < v2[k2o + 1])) x2 = v2[k2o + 1]; else x2 = v2[k2o - 1] + 1;
                    int y2 = x2 - k2;
                    while (x2 < n && y2 < mm && a[aLo + n - x2 - 1] == b[bLo + mm - y2 - 1]) { x2++; y2++; }
                    v2[k2o] = x2;
                    if (x2 > n) k2end += 2;
                    else if (y2 > mm) k2start += 2;
                    else if (!front) {
                        int k1o = off + delta - k2;
                        if (k1o >= 0 && k1o < len && v1[k1o] != -1) {
                            int x1 = v1[k1o], y1 = off + x1 - k1o;
                            if (x1 >= n - x2) { sx = aLo + x1; sy = bLo + y1; return true; }
                        }
                    }
                }
            }
            sx = 0; sy = 0; return false;         // nothing in common at all
        }
    }
}
'@
}

# --- the two sides ----------------------------------------------------------------------------------------------------
$here = (Get-Location).Path
$top = $here
while ($top -and -not (Test-Path (Join-Path $top '.git'))) { $top = Split-Path $top -Parent }
if (-not $top) { $top = $here }                     # not in a git project: the folder itself is the top
$otherTop = if (Test-Path $Other -PathType Container) { (Resolve-Path $Other).Path } else { Join-Path (Split-Path $top -Parent) $Other }
if (-not (Test-Path $otherTop -PathType Container)) { throw "there is no project '$Other' beside $top" }
$left = $top; $right = $otherTop                   # where you stand on the left, what it is compared with on the right
$leftName = Split-Path $left -Leaf; $rightName = Split-Path $right -Leaf
$half = [Math]::Floor(($Width - 3) / 2)
if ($half -lt 20) { throw "-Width $Width leaves too little room, 43 at least" }

function Get-SourceFiles([string]$root) {
    # every file worth comparing in the -Folders of $root (not the folders below them), by its path below $root in
    # lower case
    $list = @{}
    foreach ($sub in $Folders) {
        $f = if ($sub -eq '.') { $root } else { Join-Path $root $sub }
        if (-not (Test-Path $f -PathType Container)) { continue }
        foreach ($file in [IO.Directory]::GetFiles($f)) {
            $name = [IO.Path]::GetFileName($file)
            if (($Extensions -contains [IO.Path]::GetExtension($file).ToLower()) -and $name -like $Filter) {
                $rel = $file.Substring($root.Length).TrimStart('\')
                $list[$rel.ToLower()] = $rel
            }
        }
    }
    $list
}
$leftFiles = Get-SourceFiles $left
$rightFiles = Get-SourceFiles $right

function Read-Lines([string]$path) {
    # the lines without their endings, a tab as spaces to the next multiple of 4
    $lines = [IO.File]::ReadAllLines($path)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].IndexOf("`t") -ge 0) {
            $sb = [Text.StringBuilder]::new()
            foreach ($c in $lines[$i].ToCharArray()) { if ($c -eq "`t") { [void]$sb.Append(' ', 4 - $sb.Length % 4) } else { [void]$sb.Append($c) } }
            $lines[$i] = $sb.ToString()
        }
    }
    , $lines
}
function Get-Key([string]$line) {
    if ($IgnoreSpace) { $line = ($line -replace '\s+', ' ').Trim() }
    if ($IgnoreCase) { $line = $line.ToLowerInvariant() }
    $line
}
# each file's lines as numbers, the same number for the same line on either side, for the comparing
$script:Ids = [Collections.Generic.Dictionary[string, int]]::new()     # N.B: not @{}, which takes no notice of case
function Get-Ids([string[]]$lines) {
    $ids = New-Object int[] $lines.Length
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $k = Get-Key $lines[$i]
        if (-not $script:Ids.ContainsKey($k)) { $script:Ids[$k] = $script:Ids.Count }
        $ids[$i] = $script:Ids[$k]
    }
    , $ids
}

# --- the list ---------------------------------------------------------------------------------------------------------
$all = @($leftFiles.Keys) + @($rightFiles.Keys) | Sort-Object -Unique
$differ = [Collections.Generic.List[object]]::new()
foreach ($k in $all) {
    $inL = $leftFiles.ContainsKey($k); $inR = $rightFiles.ContainsKey($k)
    if ($inL -and $inR) {
        $a = Read-Lines (Join-Path $left $leftFiles[$k]); $b = Read-Lines (Join-Path $right $rightFiles[$k])
        $same = $a.Length -eq $b.Length
        if ($same) { for ($i = 0; $i -lt $a.Length; $i++) { if ((Get-Key $a[$i]) -cne (Get-Key $b[$i])) { $same = $false; break } } }
        if (-not $same) { $differ.Add([pscustomobject]@{ Name = $leftFiles[$k]; Kind = 'both'; A = $a; B = $b }) }
    } elseif ($inL) {
        $differ.Add([pscustomobject]@{ Name = $leftFiles[$k]; Kind = 'left'; A = $null; B = $null })
    } else {
        $differ.Add([pscustomobject]@{ Name = $rightFiles[$k]; Kind = 'right'; A = $null; B = $null })
    }
}

# --- the paging -------------------------------------------------------------------------------------------------------
# everything is written by Write-Host, for its colours, and that goes straight to the screen and never down a pipe, so
# | more gets nothing: the paging is done here instead, a screen at a time, unless -NoPage or the output is redirected
$paging = -not $NoPage -and $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected
$pageRows = 0; $screenWidth = 0
$outFile = $null; $script:outRow = ''
if ($Out) {
    # -Out: the whole of it into a file, plain text without the colours, and no paging
    $outFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    [IO.File]::WriteAllText($outFile, '')
    $paging = $false
}
try { $pageRows =[Math]::Max(5, [Console]::WindowHeight - 1); $screenWidth = [Console]::BufferWidth } catch { $paging = $false }   # the last row is for the prompt; no console, no paging
$script:rowsLeft = $pageRows; $script:column = 0; $script:skipTo = $null; $script:lastMark = $null
function Wait-Key {
    # the prompt, a key, and the prompt rubbed out again
    $prompt = ' -- more --  space: a page   enter: a line   n: the next difference   f: the next file   q: quit '
    Write-Host $prompt -ForegroundColor Black -BackgroundColor Cyan -NoNewline
    $k = [Console]::ReadKey($true)
    Write-Host ("`r" + (' ' * $prompt.Length) + "`r") -NoNewline
    switch ($k.Key) {
        'Enter'  { $script:rowsLeft = 1 }
        'N'      { $script:skipTo = 'section' }
        'F'      { $script:skipTo = 'file' }
        'Q'      { exit }
        'Escape' { exit }
        default  { $script:rowsLeft = $pageRows }
    }
}
function Out-Text([string]$Text, [ConsoleColor]$ForegroundColor = 'Gray', [switch]$NoNewline) {
    # Write-Host, counting the rows written, with the prompt when a page is full; nothing while skipping to a heading
    if ($script:skipTo) { return }
    if ($outFile) {
        # -Out: the pieces of a row put together and the row added to the file, nothing on the screen
        $script:outRow += $Text
        if (-not $NoNewline) { [IO.File]::AppendAllText($outFile, $script:outRow + "`r`n"); $script:outRow = '' }
        return
    }
    if ($paging -and $script:column -eq 0 -and $script:rowsLeft -le 0) { Wait-Key; if ($script:skipTo) { return } }
    Write-Host $Text -ForegroundColor $ForegroundColor -NoNewline:$NoNewline
    $script:column += $Text.Length
    if (-not $NoNewline) {
        $script:rowsLeft -= [Math]::Max(1, [Math]::Ceiling($script:column / [Math]::Max(1, $screenWidth)))
        $script:column = 0
    }
}
function Set-Mark([string]$Kind) {
    # just before a file's heading or a section's: the end of a skip to it (shown at the top of a fresh page), or with
    # -Pause the prompt before every difference (not between a file's heading and its first section)
    if (-not $paging) { return }
    if ($script:skipTo -eq 'section' -or ($script:skipTo -eq 'file' -and $Kind -eq 'file')) {
        $script:skipTo = $null; $script:rowsLeft = $pageRows
    } elseif (-not $script:skipTo -and $Pause -and $script:rowsLeft -lt $pageRows -and -not ($Kind -eq 'section' -and $script:lastMark -eq 'file')) {
        $script:rowsLeft = 0
    }
    $script:lastMark = $Kind
}

$rule = '=' * $Width
Out-Text $rule -ForegroundColor Cyan
Out-Text ('  DIFFERENCES   left:  ' + $left) -ForegroundColor Cyan
Out-Text ('                right: ' + $right) -ForegroundColor Cyan
Out-Text ('                ' + $all.Count + ' files looked at, ' + $differ.Count + ' differ' + $(if ($Filter -ne '*') { ", names like $Filter" } else { '' })) -ForegroundColor Cyan
Out-Text $rule -ForegroundColor Cyan
if ($differ.Count -eq 0) { Out-Text '  no differences' -ForegroundColor Green; return }
foreach ($d in $differ) {
    switch ($d.Kind) {
        'both'  { Out-Text ('  differs         ' + $d.Name) -ForegroundColor Yellow }
        'left'  { Out-Text ('  LEFT ONLY       ' + $d.Name + '      (not in ' + $rightName + ')') -ForegroundColor Green }
        'right' { Out-Text ('  RIGHT ONLY      ' + $d.Name + '      (not in ' + $leftName + ')') -ForegroundColor Red }
    }
}
$nb = @($differ | Where-Object Kind -eq 'both').Count; $nl = @($differ | Where-Object Kind -eq 'left').Count; $nr = @($differ | Where-Object Kind -eq 'right').Count
Out-Text ("  $nb differ, $nl on the left only, $nr on the right only") -ForegroundColor Cyan
if ($ListOnly) { return }

# --- the differences, file by file ------------------------------------------------------------------------------------
$numW = 5                                           # a line number and a space
$textW = $half - $numW
function Split-Text([string]$t) {
    # a line cut into pieces that fit a side, at least one piece
    if ($t.Length -le $textW) { return , @($t) }
    $parts = @(); for ($i = 0; $i -lt $t.Length; $i += $textW) { $parts += $t.Substring($i, [Math]::Min($textW, $t.Length - $i)) }
    , $parts
}
function Write-Row($ln, [string]$lt, $rn, [string]$rt, [ConsoleColor]$lc, [ConsoleColor]$rc) {
    # one line of each side, side by side, either may be absent ($null), a long one folded on to further rows
    $lp = if ($null -ne $ln) { Split-Text $lt } else { @() }
    $rp = if ($null -ne $rn) { Split-Text $rt } else { @() }
    $rows = [Math]::Max($lp.Count, $rp.Count)
    for ($r = 0; $r -lt $rows; $r++) {
        $l = if ($r -lt $lp.Count) { $(if ($r -eq 0) { ('{0,4} ' -f ($ln + 1)) } else { '   + ' }) + $lp[$r] } else { '' }
        $rr = if ($r -lt $rp.Count) { $(if ($r -eq 0) { ('{0,4} ' -f ($rn + 1)) } else { '   + ' }) + $rp[$r] } else { '' }
        Out-Text $l.PadRight($half) -ForegroundColor $lc -NoNewline
        Out-Text ' # ' -ForegroundColor DarkCyan -NoNewline
        Out-Text $rr -ForegroundColor $rc
    }
}

foreach ($d in $differ) {
    Set-Mark 'file'
    Out-Text ''
    Out-Text $rule -ForegroundColor Cyan
    if ($d.Kind -eq 'left') { Out-Text ("  $($d.Name)   is only on the left, $left") -ForegroundColor Green; continue }
    if ($d.Kind -eq 'right') { Out-Text ("  $($d.Name)   is only on the right, $right") -ForegroundColor Red; continue }
    $a = $d.A; $b = $d.B
    $m = [ZxDiffer.Myers]::Matches((Get-Ids $a), (Get-Ids $b))
    # the runs that differ, each the lines of each side between one match and the next
    $hunks = [Collections.Generic.List[object]]::new()
    $i = 0; $j = 0
    foreach ($p in @($m) + , @($a.Length, $b.Length)) {
        if ($p[0] -gt $i -or $p[1] -gt $j) { $hunks.Add(@($i, $p[0], $j, $p[1])) }
        $i = $p[0] + 1; $j = $p[1] + 1
    }
    $added = 0; $gone = 0
    foreach ($h in $hunks) { $gone += $h[1] - $h[0]; $added += $h[3] - $h[2] }
    Out-Text ("  $($d.Name)      $($hunks.Count) section$(if ($hunks.Count -ne 1) { 's' }), $gone line$(if ($gone -ne 1) { 's' }) on the left and $added on the right that differ   ($($a.Length) lines against $($b.Length))") -ForegroundColor Cyan
    Out-Text (('  ' + $left).PadRight($half) + ' # ' + '  ' + $right) -ForegroundColor DarkCyan
    # sections close enough that their context would meet are shown as one
    $groups = @()
    foreach ($h in $hunks) {
        $last = $groups.Count - 1
        if ($last -ge 0 -and $h[0] - $groups[$last][$groups[$last].Count - 1][1] -le 2 * $Context) { $groups[$last] += , $h } else { $groups += , @(, $h) }
    }
    foreach ($g in $groups) {
        $aFrom = [Math]::Max(0, $g[0][0] - $Context); $aTo = [Math]::Min($a.Length, $g[-1][1] + $Context)
        $bFrom = [Math]::Max(0, $g[0][2] - $Context); $bTo = [Math]::Min($b.Length, $g[-1][3] + $Context)
        $head = '  ****** left {0}-{1}' -f ($aFrom + 1), $aTo
        $headR = '  ****** right {0}-{1}' -f ($bFrom + 1), $bTo
        Set-Mark 'section'
        Out-Text ($head + ' ' + ('*' * [Math]::Max(0, $half - $head.Length - 1))) -ForegroundColor DarkCyan -NoNewline
        Out-Text ' # ' -ForegroundColor DarkCyan -NoNewline
        Out-Text ($headR + ' ' + ('*' * [Math]::Max(0, $half - $headR.Length - 1))) -ForegroundColor DarkCyan
        $ai = $aFrom; $bi = $bFrom
        foreach ($h in $g) {
            while ($ai -lt $h[0]) { Write-Row $ai $a[$ai] $bi $b[$bi] DarkGray DarkGray; $ai++; $bi++ }
            $rowsA = $h[1] - $h[0]; $rowsB = $h[3] - $h[2]
            for ($r = 0; $r -lt [Math]::Max($rowsA, $rowsB); $r++) {
                if ($r -lt $rowsA -and $r -lt $rowsB) { Write-Row ($h[0] + $r) $a[$h[0] + $r] ($h[2] + $r) $b[$h[2] + $r] Yellow Yellow }
                elseif ($r -lt $rowsA) { Write-Row ($h[0] + $r) $a[$h[0] + $r] $null '' Green Gray }
                else { Write-Row $null '' ($h[2] + $r) $b[$h[2] + $r] Gray Red }
            }
            $ai = $h[1]; $bi = $h[3]
        }
        while ($ai -lt $aTo -and $bi -lt $bTo) { Write-Row $ai $a[$ai] $bi $b[$bi] DarkGray DarkGray; $ai++; $bi++ }
    }
}
$script:skipTo = $null                              # the totals are shown even after a skip past the last difference
Out-Text ''
Out-Text $rule -ForegroundColor Cyan
Out-Text ("  $nb differ, $nl on the left only, $nr on the right only") -ForegroundColor Cyan
if ($outFile) { Write-Host "  written to $outFile, $nb differ, $nl on the left only, $nr on the right only" -ForegroundColor Cyan }
