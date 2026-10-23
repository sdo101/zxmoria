# drives the real Umoria, the Windows program, from a script: it is started in a console of its own, hidden, this
# process joins that console, types keys into it and reads what is on its screen
# -Steps is a list: a string of keys to type (ESC, ENTER and SPACE by name), SCREEN to print the screen, or WAIT and a number of
# seconds, e.g. WAIT10, to let it get on: a key typed while it rests or runs breaks that off, as in Moria
param([uint32]$Seed = 12345, [string[]]$Steps = @(), [string]$Folder = '')
$bin = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\umoria-bin')).Path     # the Windows release of Umoria 5.7.15, unpacked beside the tools
$exe = Join-Path $bin 'umoria.exe'
if(-not $Folder){ $Folder = Join-Path $PSScriptRoot ('..\..\build\test\umoria-' + (Get-Date -Format 'HHmmss')) }
$null = New-Item $Folder -ItemType Directory -Force
# Umoria looks for its data folder beside where it is started, so it is run from a copy of its own folder
Copy-Item (Join-Path $bin '*') $Folder -Recurse -Force
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
public static class Con {
    [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct SMALL_RECT { public short L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct INFO { public COORD Size, Cursor; public ushort Attr; public SMALL_RECT Win; public COORD Max; }
    [StructLayout(LayoutKind.Explicit, Size = 20)] public struct INPUT { [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public int Down; [FieldOffset(8)] public ushort Repeat; [FieldOffset(10)] public ushort Vk; [FieldOffset(12)] public ushort Scan; [FieldOffset(14)] public char Ch; [FieldOffset(16)] public uint Ctrl; }
    [DllImport("kernel32.dll")] public static extern bool FreeConsole();
    [DllImport("kernel32.dll", SetLastError = true)] public static extern bool AttachConsole(uint pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll")] public static extern bool GetConsoleScreenBufferInfo(IntPtr h, out INFO info);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool ReadConsoleOutputCharacter(IntPtr h, StringBuilder sb, uint len, COORD at, out uint read);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool WriteConsoleInput(IntPtr h, INPUT[] r, uint n, out uint written);
    [DllImport("user32.dll")] public static extern short VkKeyScan(char c);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
    [DllImport("kernel32.dll")] public static extern bool AllocConsole();
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("kernel32.dll")] public static extern bool SetStdHandle(int which, IntPtr h);
    [DllImport("kernel32.dll")] public static extern bool SetHandleInformation(IntPtr h, uint mask, uint flags);
    public static bool Make() { FreeConsole(); if(!AllocConsole()) return false; ShowWindow(GetConsoleWindow(), 0); hin = CreateFile("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); hout = CreateFile("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); SetHandleInformation(hin, 1, 1); SetHandleInformation(hout, 1, 1); SetStdHandle(-10, hin); SetStdHandle(-11, hout); SetStdHandle(-12, hout); return hin != (IntPtr)(-1) && hout != (IntPtr)(-1); }
    static IntPtr hin, hout;
    public static int Err; public static bool Join(uint pid) { FreeConsole(); if(!AttachConsole(pid)){ Err = Marshal.GetLastWin32Error(); return false; } hin = CreateFile("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); hout = CreateFile("CONOUT$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); return hin != (IntPtr)(-1) && hout != (IntPtr)(-1); }
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    // N.B: the screen is read from whichever buffer is showing now, the program makes one of its own
    public static IntPtr Out() { foreach(uint acc in new uint[]{ 0xC0000000, 0x80000000, 0x40000000 }){ foreach(uint sh in new uint[]{ 3, 7, 1, 2, 0 }){ IntPtr h = CreateFile("CONOUT$", acc, sh, IntPtr.Zero, 3, 0, IntPtr.Zero); if(h != (IntPtr)(-1)){ How = acc.ToString("X") + "/" + sh; return h; } Err = Marshal.GetLastWin32Error(); } } return (IntPtr)(-1); }
    public static string How = "";
    public static string[] Screen() { IntPtr hout = Out(); try { return Read(hout); } finally { CloseHandle(hout); } }
    public static string Info() { IntPtr h = Out(); INFO i; bool ok = GetConsoleScreenBufferInfo(h, out i); CloseHandle(h); return "handle " + h + " how " + How + " err " + Err + " ok " + ok + " size " + i.Size.X + "x" + i.Size.Y + " cursor " + i.Cursor.X + "," + i.Cursor.Y + " window " + i.Win.L + "," + i.Win.T + "-" + i.Win.R + "," + i.Win.B; }
    static string[] Read(IntPtr hout) { INFO i; GetConsoleScreenBufferInfo(hout, out i); int w = i.Size.X, rows = Math.Min((int)i.Size.Y, 30); var lines = new string[rows]; for(int y = 0; y < rows; y++){ var sb = new StringBuilder(w + 1); uint n; ReadConsoleOutputCharacter(hout, sb, (uint)w, new COORD { X = 0, Y = (short)y }, out n); lines[y] = sb.ToString(0, (int)Math.Min(n, (uint)sb.Length)).TrimEnd(); } return lines; }
    public static void Key(char c, ushort vk) { short s = vk != 0 ? (short)vk : VkKeyScan(c); ushort v = (ushort)(s & 0xFF); uint ctrl = ((s & 0x100) != 0 && vk == 0) ? 0x10u : 0u; var r = new INPUT[2]; for(int k = 0; k < 2; k++){ r[k].Type = 1; r[k].Down = k == 0 ? 1 : 0; r[k].Repeat = 1; r[k].Vk = v; r[k].Scan = (ushort)MapVirtualKey(v, 0); r[k].Ch = c; r[k].Ctrl = ctrl; } uint w; WriteConsoleInput(hin, r, 2, out w); }
}
'@
# a console of our own, hidden, and Umoria started in it
$made = [Con]::Make()
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = $exe; $info.Arguments = "-n -s $Seed `"$Folder\test.sav`""; $info.WorkingDirectory = $Folder; $info.UseShellExecute = $false
$game = [System.Diagnostics.Process]::Start($info)
Start-Sleep -Milliseconds 1500
$out = New-Object System.Collections.ArrayList
$null = $out.Add("made $made, umoria $($game.Id) exited $($game.HasExited)" + $(if($game.HasExited){ " code $($game.ExitCode)" }) + ", " + [Con]::Info())
if(-not $made){ $null = $out.Add("could not make a console") } else {
    foreach($step in $Steps){
        if($step -match '^WAIT(\d+)$'){ Start-Sleep -Seconds ([int]$Matches[1]); continue }
        if($step -eq 'SCREEN'){ $null = $out.Add('--- screen'); foreach($l in [Con]::Screen()){ if($l){ $null = $out.Add($l) } }; continue }
        if($step -eq 'ESC'){ [Con]::Key([char]27, 0x1B) } elseif($step -eq 'ENTER'){ [Con]::Key([char]13, 0x0D) } elseif($step -eq 'SPACE'){ [Con]::Key(' ', 0x20) } else { foreach($ch in $step.ToCharArray()){ [Con]::Key($ch, 0); Start-Sleep -Milliseconds 120 } }
        Start-Sleep -Milliseconds 500
    }
}
if(-not $game.HasExited){ $game.Kill() }
[Con]::FreeConsole() | Out-Null
$out | Set-Content (Join-Path $Folder 'out.txt')
"out: $(Join-Path $Folder 'out.txt')"







