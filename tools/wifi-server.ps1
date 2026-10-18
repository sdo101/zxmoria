# sends the game to a real Next over Wi-Fi: a small web server on this PC, from which the Next fetches the files itself
# with .http, the dot command that comes with NextZXOS (c:/dot/http), using the Next's own Wi-Fi...
#   tools\wifi-server.ps1                serves on port 8080 until Ctrl+C
#   tools\wifi-server.ps1 -Port 8000     on another port
#
# what the Next can fetch, and nothing else:
#   /getgame.bas      a NextBASIC program, made afresh for each request, that fetches the two files below into the
#                     folder it is run from, and then starts the game
#   /<project>.nex    the nex file, as the build last made it, read afresh for each request, so a new build needs no restart
#   /zxmoria.lic      the licence, which goes with the game wherever it goes
#
# on the Next, the first time, in the folder the game is to go in (the top folder of the card, c:/, as the emulator has it):
#   .http -h <this PC's address> -p 8080 -u /getgame.bas -f getgame.bas
#   LOAD "getgame.bas"
# ...and after that, each time there is a new build, only:  LOAD "getgame.bas"
# (the program starts itself, it was saved with LINE 10, and the PC's address is written into it)
#
# N.B: what has to be true for the Next to reach this PC...
#   the Next's Wi-Fi is set up and joined to the same network as this PC, once, with c:/apps/wifi/setup/wifi.bas
#   this virtual machine's network is "bridged" in VMware Fusion, so it has an address on the home network itself...
#   ...with "share with my Mac" (NAT) the Next cannot see it
#   Windows' firewall lets the port in: this script says how, once, if it has not been allowed
Param( [int]$Port = 8080 )
$ErrorActionPreference = 'Stop'

$ProjectPath = Split-Path -Path $PSScriptRoot -Parent
$ProjectName = Split-Path -Path $ProjectPath -Leaf                     # the nex file is named after the project folder, see build.ps1
$NexName     = "$ProjectName.nex"
$RuleName    = 'ZXMoria Wi-Fi'
$Served      = @{
    "/$NexName"    = Join-Path $ProjectPath $NexName
    '/zxmoria.lic' = Join-Path $ProjectPath 'LICENSE'
}

Function Say( [string]$Text, [string]$Colour = 'Gray' ) { Write-Host "$( [DateTime]::Now.ToString( 'HH:mm:ss' ) )  $Text" -ForegroundColor $Colour }

# --- the program the Next runs: a saved NextBASIC program, a 128 byte "+3DOS" header and then the program, exactly as
# build.ps1 makes autoexec.bas, but with several lines...
# ...each line is a dot command, which NextBASIC keeps as plain text, so nothing in it needs turning into tokens
Function New-Program( [string[]]$Lines ) {
    $Program = New-Object Collections.Generic.List[byte]
    $Number  = 10
    ForEach ( $Line In $Lines ) {
        $Text = [Text.Encoding]::ASCII.GetBytes( $Line )
        $Program.Add( [byte]( $Number -shr 8 ) ) ; $Program.Add( [byte]( $Number -band 255 ) )          # line number, high byte first
        $Program.Add( [byte]( ( $Text.Length + 1 ) -band 255 ) ) ; $Program.Add( [byte]( ( $Text.Length + 1 ) -shr 8 ) )   # length, low byte first
        $Program.AddRange( $Text ) ; $Program.Add( 0x0D )
        $Number += 10
    }
    $File = New-Object byte[] ( 128 + $Program.Count )
    [Text.Encoding]::ASCII.GetBytes( 'PLUS3DOS' ).CopyTo( $File, 0 )
    $File[8]  = 0x1A ; $File[9] = 0x01 ; $File[10] = 0x00
    $File[11] = [byte]( $File.Length -band 255 ) ; $File[12] = [byte]( ( $File.Length -shr 8 ) -band 255 )
    $File[15] = 0x00                                                                                    # a BASIC program
    $File[16] = [byte]( $Program.Count -band 255 ) ; $File[17] = [byte]( $Program.Count -shr 8 )        # its length
    $File[18] = 10 ; $File[19] = 0                                                                      # LINE 10, it starts itself
    $File[20] = $File[16] ; $File[21] = $File[17]                                                       # no variables
    $Program.ToArray().CopyTo( $File, 128 )
    $Sum = 0 ; For ( $i = 0 ; $i -lt 127 ; $i++ ) { $Sum = ( $Sum + $File[$i] ) -band 255 } ; $File[127] = [byte]$Sum
    $File
}
Function Get-Program( [string]$HostAddress ) {
    $Fetch = "-h $HostAddress -p $Port"
    New-Program @(
        ".http $Fetch -u /zxmoria.lic -f zxmoria.lic"
        ".http $Fetch -u /$NexName -f $NexName"
        ".nexload $NexName"
    )
}

# --- this PC's addresses on the network, the one the Next is to be given
$Addresses = @( Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.InterfaceAlias -notlike 'vEthernet*' } )
If ( -not ( Test-Path $Served["/$NexName"] -PathType Leaf ) ) { Say "...$NexName is not there, run build.ps1 first" Red ; Exit 1 }

# --- the firewall
$Rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
If ( -not $Rule ) {
    Say "...Windows' firewall has no rule letting the Next in, the Next will get error 3 (no connection) until it has" Yellow
    Say "   in a PowerShell run as administrator, once:" Yellow
    Say "   New-NetFirewallRule -DisplayName '$RuleName' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Private" Yellow
    Say "   (it lets in only this port, and only on a network Windows has been told is private, as a home network is)" Yellow
} ElseIf ( @( $Rule | Get-NetFirewallPortFilter | Where-Object { "$( $_.LocalPort )" -eq "$Port" } ).Count -eq 0 ) {
    Say "...the firewall rule '$RuleName' is not for port $Port, the Next may not get in" Yellow
}

$Listener = [Net.Sockets.TcpListener]::new( [Net.IPAddress]::Any, $Port )
Try { $Listener.Start() } Catch { Say "...cannot listen on port $($Port): $( $_.Exception.Message )" Red ; Exit 1 }
Say "...serving the game on port $Port, Ctrl+C to stop"
ForEach ( $A In $Addresses ) {
    Say "   $( $A.InterfaceAlias ):  $( $A.IPAddress )"
    Say "   on the Next, the first time:  .http -h $( $A.IPAddress ) -p $Port -u /getgame.bas -f getgame.bas" Cyan
}
Say '   then, every time:  LOAD "getgame.bas"' Cyan

# --- one request at a time, which is all a Next makes: read what it asks for, send it, close
Function Send( $Stream, [int]$Code, [string]$Status, [byte[]]$Body, [bool]$Head ) {
    # N.B: always with Content-Length and never in chunks, .http needs the length and cannot read chunked replies
    $Header = "HTTP/1.1 $Code $Status`r`nContent-Type: application/octet-stream`r`nContent-Length: $( $Body.Length )`r`nConnection: close`r`n`r`n"
    $Bytes  = [Text.Encoding]::ASCII.GetBytes( $Header )
    $Stream.Write( $Bytes, 0, $Bytes.Length )
    If ( -not $Head -and $Body.Length ) { $Stream.Write( $Body, 0, $Body.Length ) }
    $Stream.Flush()
}
Try {
    While ( $True ) {
        If ( -not $Listener.Pending() ) { Start-Sleep -Milliseconds 100 ; Continue }
        $Client = $Listener.AcceptTcpClient()
        Try {
            $Client.ReceiveTimeout = 10000 ; $Client.SendTimeout = 60000
            $Stream  = $Client.GetStream()
            $From    = $Client.Client.RemoteEndPoint.Address.ToString()
            $Request = New-Object Text.StringBuilder ; $Buffer = New-Object byte[] 1024
            While ( $Request.ToString() -notmatch "`r?`n`r?`n" -and $Request.Length -lt 8192 ) {
                $n = $Stream.Read( $Buffer, 0, $Buffer.Length ) ; If ( $n -le 0 ) { Break }
                [void]$Request.Append( [Text.Encoding]::ASCII.GetString( $Buffer, 0, $n ) )
            }
            $First = ( $Request.ToString() -split "`r?`n" )[0]
            If ( $First -notmatch '^(GET|HEAD) (\S+)' ) { Send $Stream 405 'Method Not Allowed' @() $False ; Say "$From  $First  refused" Yellow ; Continue }
            $Head = $Matches[1] -eq 'HEAD' ; $Path = ( $Matches[2] -split '\?' )[0]
            If ( $Path -eq '/getgame.bas' ) {
                # the PC's address as the Next reached it, so the program fetches from the same place
                $Body = Get-Program $Client.Client.LocalEndPoint.Address.ToString()
            } ElseIf ( $Served.ContainsKey( $Path ) ) {
                $Body = [IO.File]::ReadAllBytes( $Served[$Path] )
            } Else {
                Send $Stream 404 'Not Found' @() $Head ; Say "$From  $Path  not found" Yellow ; Continue
            }
            Send $Stream 200 'OK' $Body $Head
            Say "$From  $Path  $( $Body.Length ) bytes sent" Green
        } Catch {
            Say "...a request failed: $( $_.Exception.Message )" Red
        } Finally {
            $Client.Close()
        }
    }
} Finally {
    $Listener.Stop()
    Say '...stopped'
}
