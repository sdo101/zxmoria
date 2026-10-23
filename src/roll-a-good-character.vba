Option Explicit

' 15th June 2016
' script written in VBA for Reflection (terminal emulator)...
' ...whilst running on a PC, with simh running a MicroVAX running OpenVMS...
' ...and a Reflection VT340 terminal session over TCP/IP to OpenVMS...
' ...to roll a great Moria character :)

Sub modulea()
  Dim ls_att, ls_list, ls_best, ls_max, ls_min As String
  Dim ll_row, ll_att(7), ll_min(7), ll_max(7), ll_max_tot, ll_min_tot, ll_pos, ll_tot, ll_best As Long
  Dim ll_char, ll_count As Long
  Dim lb_ok As Boolean

  ll_count = 0
  ll_char = InputBox("Next character number")

  ll_min(2) = 11     'strength
  ll_min(3) = 60     'intelligence
  ll_min(4) = 13     'wisdom
  ll_min(5) = 16     'dexterity
  ll_min(6) = 12     'constitution
  ll_min(7) = 13     'charisma
  ls_min = ""
  ll_min_tot = 0
  For ll_row = 2 To 7
    ll_min_tot = ll_min_tot + ll_min(ll_row)
    ls_min = ls_min & ll_min(ll_row) & " "
  Next

  ll_best = 0

  ll_max_tot = 0
  For ll_row = 2 To 7
    ll_max(ll_row) = 0
  Next

  Do
    lb_ok = True
    ll_count = ll_count + 1

    Session.Transmit ("run moria" & vbCr)
    Session.WaitForString ("to exit")
    Session.Transmit (vbCr)
    Session.WaitForString ("Troll")
    Session.Transmit ("d")
    Session.WaitForString ("Female")
    Session.Transmit ("m")
    Session.WaitForString ("Rogue")
    Session.Transmit ("b")
    Session.WaitForString ("finished]")

    ls_list = ""
    ll_tot = 0
    For ll_row = 2 To 7
      ls_att = Session.GetText(ll_row, 69, ll_row, 75)
      ll_pos = InStr(1, ls_att, "/")
      If ll_pos = 0 Then
        ll_att(ll_row) = CLng(ls_att)
      Else
        ll_att(ll_row) = CLng(Mid(ls_att, 1, ll_pos - 1)) + CLng(Mid(ls_att, ll_pos + 1, Len(ls_att)))
      End If
      ls_list = ls_list & ll_att(ll_row) & " "
      If ll_att(ll_row) > ll_max(ll_row) Then ll_max(ll_row) = ll_att(ll_row)
      ll_tot = ll_tot + ll_att(ll_row)
      If ll_att(ll_row) < ll_min(ll_row) Then lb_ok = False
    Next
    If ll_tot > ll_best Then
      ll_best = ll_tot
      ls_best = ls_list
    End If

    Debug.Print "count: " & ll_count & "    char: " & ll_char
    Debug.Print "now:  " & ll_tot & " = " & ls_list
    ll_max_tot = 0
    ls_max = ""
    For ll_row = 2 To 7
      ls_max = ls_max & ll_max(ll_row) & " "
      ll_max_tot = ll_max_tot + ll_max(ll_row)
    Next
    Debug.Print "best: " & ll_best & " = " & ls_best
    Debug.Print "want: " & ll_min_tot & " = " & ls_min
    Debug.Print "max:  " & ll_max_tot & " = " & ls_max

'good strength and overall ok...
'   If ll_att(2) >= 11 And ll_tot >= 160 Then lb_ok = True
'exceptional characters...
'   If (ll_att(2) >= 12) Then lb_ok = True
    If (ll_att(3) >= 77) Then lb_ok = True
'   If (ll_att(2) >= 8) And (ll_att(3) >= 78) Then lb_ok = True
'   If (ll_att(2) >= 9) And (ll_tot >= 165) Then lb_ok = True

    If lb_ok Then
      Session.Transmit ("sdo" & ll_char & vbCr)
      Session.WaitForString ("to exit]")
      Session.Transmit (vbCr)
      Session.WaitForString ("spell")
      Session.Transmit ("a")
      If Session.FindText("spell", 1, 1) Then
        Session.Transmit ("a")
      End If
      Session.WaitForString ("Town level")
      Session.Transmit (Chr(26))
      Session.WaitForString ("Filename:")
      Session.Transmit ("sdo" & ll_char & ".chr" & vbCr)
      Session.WaitForString ("VAX1::SDO>")
      ll_char = ll_char + 1
    Else
      Session.Transmit (Chr(26))
      Session.WaitForString ("to exit]")
      Session.Transmit (Chr(26))
      Session.WaitForString ("VAX1::SDO>")
    End If

  Loop While True

  MsgBox "Found one!"
End Sub