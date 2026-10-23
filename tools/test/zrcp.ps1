# sends commands to a running ZEsarUX over its remote protocol (ZRCP, port 10000) and prints the replies
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Commands)
$c = New-Object Net.Sockets.TcpClient
$c.Connect('127.0.0.1', 10000)
$st = $c.GetStream(); $st.ReadTimeout = 1500
$buf = New-Object byte[] 65536
$read = {
    $r = ''
    try { while ($true) { $k = $st.Read($buf, 0, $buf.Length); if ($k -le 0) { break }; $r += [Text.Encoding]::ASCII.GetString($buf, 0, $k); if ($r -match 'command[>@] ?$') { break } } } catch {}
    $r -replace 'command[>@] ?$', ''
}
$null = & $read
foreach ($x in $Commands) {
    $b = [Text.Encoding]::ASCII.GetBytes("$x`n"); $st.Write($b, 0, $b.Length)
    "### $x"; (& $read).Trim()
}
$c.Close()
