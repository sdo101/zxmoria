' small helpers for putting the character sheet on the screen, shared by the two stages that make a new character
' (stage-player.bas and stage-player-class.bas) and by the character library (stage-lib-character.bas)...
' ...each stage includes this file, so each has its own copy of whichever of these it uses, the compiler leaves out the rest
' N.B: a stage cannot call into another stage, which is why these are not simply in one of them

Sub s_pl_put( pub_row As UByte , pub_col As UByte , ps_text As String )
    s_core_print_string_at( pub_row , pub_col , ps_text , UB_WHITE )
End Sub


Sub s_pl_clear_to_bottom( pub_row As UByte )
    ' blanks the screen from the given row down to row 23, Moria's clearToBottom()
    Dim lub_row As UByte

    For lub_row = pub_row To 23
        s_core_clear_row( lub_row , 0 , UB_WHITE )
    Next
End Sub


Function fs_pl_number( psl_value As Long , pub_width As UByte ) As String
    ' a number as text, with a minus sign if it needs one, and spaces in front to make it up to the given width, as C's %6d does
    Dim ls_text As String

    If psl_value < 0 Then
        ls_text = "-" + fs_core_number( Cast( ULong , -psl_value ) )
    Else
        ls_text = fs_core_number( Cast( ULong , psl_value ) )
    End If
    While Len( ls_text ) < pub_width
        ls_text = " " + ls_text
    End While
    Return ls_text
End Function


Sub s_pl_header_number( ps_header As String , psl_value As Long , pub_width As UByte , pub_row As UByte , pub_col As UByte )
    ' a heading, a colon, and a number, Moria's printHeaderNumber() (width 6) and printHeaderLongNumber7Spaces() (width 7)
    s_pl_put( pub_row , pub_col , ps_header + ": " + fs_pl_number( psl_value , pub_width ) )
End Sub


Function fs_pl_stat( pub_stat As UByte ) As String
    ' a stat as the player sees it: up to 18 it is just the number, above that it is 18/01 to 18/100, Moria's statsAsString()
    If pub_stat <= 18 Then Return fs_pl_number( pub_stat , 6 )
    If pub_stat = 118 Then Return "18/100"
    If pub_stat < 28 Then Return " 18/0" + fs_core_number( pub_stat - 18 )
    Return " 18/" + fs_core_number( pub_stat - 18 )
End Function


Function fs_pl_text( puw_address As UInteger , pub_max As UByte ) As String
    ' text held in memory as a string, stopping at a 0 or after pub_max characters, whichever comes first
    Dim ls_text     As String = ""
    Dim lub_char    As UByte
    Dim i           As UByte = 0

    While i < pub_max
        lub_char = Peek( puw_address + i )
        If lub_char = 0 Then Exit While
        ls_text = ls_text + fs_core_char( lub_char )
        i = i + 1
    End While
    Return ls_text
End Function


Function fuw_pl_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_pl_welcome()
    ' ? while a character is being made: Moria's words of welcome, the text library shows them and puts the
    ' screen back
    gub_lib_param_1 = UB_TEXT_WELCOME
    s_core_call_library( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW )
End Sub
