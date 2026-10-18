# puts the game on a real Next's SD card, the card from the Next itself, in a card reader on this PC...
#   the nex file and the licence go in the card's top folder, as on the emulator's card images, see build.ps1...
#   ...nothing else on the card is touched: the saved games, the high scores and the rest of NextZXOS stay as they are
#
#   tools\push-card.ps1                  finds the card itself, and copies the nex file and the licence on to it
#   tools\push-card.ps1 -Card E:         the card is drive E:, or any folder that holds a card's files
#   tools\push-card.ps1 -AutoExec        also makes the Next start the game when it is switched on, by putting the build's
#                                        autoexec.bas in c:/nextzxos, the one that was there is kept as autoexec.zxmoria-bak
#   tools\push-card.ps1 -NoAutoExec      puts back the autoexec.bas that -AutoExec kept, so the Next boots to its menu again
#   tools\push-card.ps1 -Eject           tells Windows to let go of the card when it is done, so it can be taken out
#
# how a card is recognised: it has a nextzxos folder in its top folder, as every NextZXOS card has...
# ...a card is only looked for among the removable drives and VMware Fusion's shared folders, a fixed disk is never
# chosen, however it is named, and a folder given with -Card that has no nextzxos folder is refused
# N.B: a card shared by the Mac must be ejected on the Mac afterwards, -Eject only lets go of a drive Windows has
# N.B: run the build first, this copies what the build last made, it does not build anything
Param( [string]$Card = '', [switch]$AutoExec, [switch]$NoAutoExec, [switch]$Eject )
$ErrorActionPreference = 'Stop'

$ProjectPath = Split-Path -Path $PSScriptRoot -Parent
$ProjectName = Split-Path -Path $ProjectPath -Leaf                     # the nex file is named after the project folder, see build.ps1
$NexName     = "$ProjectName.nex"
$NexFile     = Join-Path $ProjectPath $NexName
$Licence     = Join-Path $ProjectPath 'LICENSE'
$AutoExecNew = Join-Path $ProjectPath 'build\autoexec.bas'
$BackupName  = 'autoexec.zxmoria-bak'

Function Say( [string]$Text, [string]$Colour = 'Gray' ) { Write-Host $Text -ForegroundColor $Colour }
Function Stop-Here( [string]$Text ) { Say $Text Red ; Exit 1 }
Function Hash( [string]$Path ) { ( Get-FileHash -Path $Path -Algorithm SHA256 ).Hash }

If ( $AutoExec -and $NoAutoExec ) { Stop-Here '...-AutoExec and -NoAutoExec cannot both be given' }
ForEach ( $File In @( $NexFile, $Licence ) ) { If ( -not ( Test-Path $File -PathType Leaf ) ) { Stop-Here "...$File is not there, run build.ps1 first" } }
If ( $AutoExec -and -not ( Test-Path $AutoExecNew -PathType Leaf ) ) { Stop-Here "...$AutoExecNew is not there, run build.ps1 first" }

# --- which card
If ( $Card ) {
    If ( $Card -match '^[A-Za-z]:?$' ) { $Card = "$( $Card.Substring( 0, 1 ) ):\" }
    If ( -not ( Test-Path $Card -PathType Container ) ) { Stop-Here "...$Card is not there" }
} Else {
    $Removable = @( Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Removable' } )
    $Cards     = @( $Removable | Where-Object { Test-Path "$( $_.DriveLetter ):\nextzxos" -PathType Container } | ForEach-Object { [pscustomobject]@{ Path = "$( $_.DriveLetter ):\" ; Label = "'$( $_.FileSystemLabel )'  $( [math]::Round( $_.Size / 1GB, 1 ) )GB" } } )
    # ...or a card the Mac has, shared with this virtual machine by VMware Fusion: the Mac's own SD card slot is not
    # a USB device, so Fusion cannot hand it to Windows, but it can share the folder the Mac shows the card as
    $Shares = '\\vmware-host\Shared Folders'
    If ( Test-Path $Shares ) {
        $Cards += @( Get-ChildItem $Shares -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path ( Join-Path $_.FullName 'nextzxos' ) -PathType Container } | ForEach-Object { [pscustomobject]@{ Path = $_.FullName ; Label = 'shared by the Mac' } } )
    }
    If ( $Cards.Count -eq 0 ) {
        Say '...no Next SD card found: no removable drive has a nextzxos folder' Red
        If ( $Removable.Count ) { $Removable | ForEach-Object { Say "    $( $_.DriveLetter ):  $( $_.FileSystem )  '$( $_.FileSystemLabel )'  $( [math]::Round( $_.Size / 1GB, 1 ) )GB" } }
        Else { Say '    there are no removable drives at all: is the card reader connected to this virtual machine, or the card shared by the Mac?' }
        Exit 1
    }
    If ( $Cards.Count -gt 1 ) {
        Say '...more than one Next SD card, say which with -Card:' Red
        $Cards | ForEach-Object { Say "    $( $_.Path )  $( $_.Label )" }
        Exit 1
    }
    $Card = $Cards[0].Path
}
If ( -not ( Test-Path ( Join-Path $Card 'nextzxos' ) -PathType Container ) ) { Stop-Here "...$Card has no nextzxos folder, it does not look like a Next SD card, nothing was written" }
Say "...card:  $Card"

# --- the game's files, each copied only if it has changed, and checked after
Function Put( [string]$From, [string]$To ) {
    $Target = Join-Path $Card $To
    If ( ( Test-Path $Target -PathType Leaf ) -and ( Hash $Target ) -eq ( Hash $From ) ) { Say "    $To is already the same" DarkGray ; Return }
    Copy-Item -Path $From -Destination $Target -Force
    If ( ( Hash $Target ) -ne ( Hash $From ) ) { Stop-Here "...$To on the card is not the same as $From after copying it, the card may be faulty or full" }
    Say "    $To  $( ( Get-Item $From ).Length ) bytes, copied" Green
}
Say "...nex file:  $NexName, made $( ( Get-Item $NexFile ).LastWriteTime.ToString( 'yyyy-MM-dd HH:mm:ss' ) )"
Put $NexFile $NexName
Put $Licence 'zxmoria.lic'          # under a short plain name, as on the emulator's cards, see build.ps1

# --- the Next's start up program, only if asked
$CardAutoExec = Join-Path $Card 'nextzxos\autoexec.bas'
$CardBackup   = Join-Path $Card "nextzxos\$BackupName"
If ( $AutoExec ) {
    # the one that was there is kept, the first time only, so a second -AutoExec does not keep ours in place of it
    If ( ( Test-Path $CardAutoExec -PathType Leaf ) -and -not ( Test-Path $CardBackup -PathType Leaf ) -and ( Hash $CardAutoExec ) -ne ( Hash $AutoExecNew ) ) {
        Copy-Item -Path $CardAutoExec -Destination $CardBackup
        Say "    nextzxos\autoexec.bas that was there is kept as nextzxos\$BackupName"
    }
    Put $AutoExecNew 'nextzxos\autoexec.bas'
}
If ( $NoAutoExec ) {
    If ( Test-Path $CardBackup -PathType Leaf ) {
        Move-Item -Path $CardBackup -Destination $CardAutoExec -Force
        Say '    nextzxos\autoexec.bas put back as it was' Green
    } ElseIf ( ( Test-Path $CardAutoExec -PathType Leaf ) -and ( Hash $CardAutoExec ) -eq ( Hash $AutoExecNew ) ) {
        Remove-Item -Path $CardAutoExec
        Say '    nextzxos\autoexec.bas removed, there was none before ours' Green
    } Else {
        Say '    nextzxos\autoexec.bas is not ours, it is left alone' DarkGray
    }
}

# --- let go of the card
If ( $Card -match '^([A-Za-z]):\\$' ) {
    $Letter = $Matches[1]
    Try { Write-VolumeCache -DriveLetter $Letter } Catch { }
    If ( $Eject ) {
        ( New-Object -ComObject Shell.Application ).Namespace( 17 ).ParseName( "$($Letter):" ).InvokeVerb( 'Eject' )
        Say "...$($Letter): ejected, the card can be taken out" Green
    }
}
Say '...done'
