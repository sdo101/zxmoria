# makes a whole Next SD card: the official system distribution (NextZXOS, the firmware, the cores, the dot commands,
# the demos), and then the game on it, by tools\push-card.ps1...
#   tools\make-card.ps1 -Card S:              an empty card: the distribution is unpacked on to it, nothing is wiped
#   tools\make-card.ps1 -Card S: -Wipe        a card with something on it: it is formatted first, FAT32, which loses
#                                             everything on it, and only after its label has been typed in to say so
#   -AutoExec, -Eject                         as for push-card.ps1, passed on to it
#   -Zip <file>                               the distribution, sn-complete-24.11.zip in the downloads folder if not given,
#                                             from https://www.specnext.com/latestdistro/ or the zip a Next comes with
#
# what is accepted as a card, so that nothing else can ever be written over: a drive letter, of a removable drive, on a
# USB or SD disk, of no more than 64GB, formatted FAT32 or FAT16...
# ...and without -Wipe it must be empty, nothing on it but Windows' own System Volume Information
# N.B: Windows can only format a drive of up to 32GB as FAT32, a bigger card has to be formatted some other way first
Param( [Parameter(Mandatory)][string]$Card, [string]$Zip = '', [switch]$Wipe, [switch]$AutoExec, [switch]$Eject )
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$RootPath = Split-Path ( Split-Path ( Split-Path $PSScriptRoot -Parent ) -Parent ) -Parent     # <root>\projects\<project>\tools
If ( -not $Zip ) { $Zip = Join-Path $RootPath 'downloads\sn-complete-24.11.zip' }

Function Say( [string]$Text, [string]$Colour = 'Gray' ) { Write-Host $Text -ForegroundColor $Colour }
Function Stop-Here( [string]$Text ) { Say $Text Red ; Exit 1 }

If ( -not ( Test-Path $Zip -PathType Leaf ) ) { Stop-Here "...the distribution $Zip is not there" }

# --- is it a card
If ( $Card -notmatch '^([A-Za-z]):?\\?$' ) { Stop-Here "...-Card must be a drive letter, such as S:" }
$Letter = $Matches[1].ToUpper()
$Volume = Get-Volume -DriveLetter $Letter -ErrorAction SilentlyContinue
If ( -not $Volume ) { Stop-Here "...there is no drive $($Letter):" }
$Disk   = Get-Partition -DriveLetter $Letter | Get-Disk
$About  = "$($Letter):  '$( $Volume.FileSystemLabel )'  $( $Volume.FileSystem )  $( [math]::Round( $Volume.Size / 1GB, 1 ) )GB  on disk $( $Disk.Number ), $( $Disk.FriendlyName ) ($( $Disk.BusType ))"
Say "...card:  $About"
If ( $Volume.DriveType -ne 'Removable' )            { Stop-Here "...$($Letter): is not a removable drive, nothing was written" }
If ( "$( $Disk.BusType )" -notin @( 'USB', 'SD', 'MMC' ) ) { Stop-Here "...$($Letter): is not on a USB or SD disk, nothing was written" }
If ( $Disk.IsBoot -or $Disk.IsSystem )               { Stop-Here "...$($Letter): is on the disk Windows runs from, nothing was written" }
If ( $Disk.Size -gt 64GB )                            { Stop-Here "...$($Letter): is on a disk of more than 64GB, too big to be a Next's card, nothing was written" }
If ( $Volume.FileSystem -notin @( 'FAT32', 'FAT' ) -and -not $Wipe ) { Stop-Here "...$($Letter): is $( $Volume.FileSystem ), not FAT32, -Wipe formats it" }

$Root    = "$($Letter):\"
$Present = @( Get-ChildItem $Root -Force | Where-Object { $_.Name -ne 'System Volume Information' } )

# --- wipe it, only if asked, and only when the label has been typed in
If ( $Wipe ) {
    If ( $Volume.Size -gt 32GB ) { Stop-Here "...Windows cannot format more than 32GB as FAT32, format the card on the Mac (MS-DOS (FAT), Master Boot Record) and run this again without -Wipe" }
    Say "...EVERYTHING on $($Letter): will be lost, $( $Present.Count ) files and folders in its top folder:" Yellow
    $Present | Select-Object -First 12 | ForEach-Object { Say "    $( $_.Name )" Yellow }
    $Typed = Read-Host "Type the card's label, $( $Volume.FileSystemLabel ), to wipe it, anything else to stop"
    If ( -not $Volume.FileSystemLabel -or $Typed -cne $Volume.FileSystemLabel ) { Stop-Here '...not wiped, nothing was written' }
    Say "...formatting $($Letter): FAT32, label ZXNEXT"
    $Null = Format-Volume -DriveLetter $Letter -FileSystem FAT32 -NewFileSystemLabel 'ZXNEXT' -Force
    $Present = @()
}
If ( $Present.Count ) { Stop-Here "...$($Letter): is not empty, $( $Present.Count ) files and folders in its top folder: tools\push-card.ps1 puts the game on a card that already has NextZXOS, -Wipe starts it again" }

# --- the distribution, every file checked for its length once it is on the card
Say "...unpacking $( Split-Path $Zip -Leaf ) on to $($Letter):"
[IO.Compression.ZipFile]::ExtractToDirectory( $Zip, $Root )
$Archive = [IO.Compression.ZipFile]::OpenRead( $Zip )
Try {
    $Files = @( $Archive.Entries | Where-Object { -not $_.FullName.EndsWith( '/' ) } )
    $Wrong = @( $Files | Where-Object { $p = Join-Path $Root $_.FullName ; -not ( Test-Path -LiteralPath $p -PathType Leaf ) -or ( Get-Item -LiteralPath $p ).Length -ne $_.Length } )
} Finally { $Archive.Dispose() }
If ( $Wrong.Count ) { $Wrong | Select-Object -First 10 | ForEach-Object { Say "    $( $_.FullName )" Red } ; Stop-Here "...$( $Wrong.Count ) of the distribution's files are missing or the wrong length on the card" }
Say "    $( $Files.Count ) files, all there" Green

# --- and the game
& ( Join-Path $PSScriptRoot 'push-card.ps1' ) -Card "$($Letter):" -AutoExec:$AutoExec -Eject:$Eject
Exit $LastExitCode
