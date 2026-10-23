' what the two recall libraries share, stage-lib-recall.bas and stage-lib-recall-2.bas: the line being filled, what is
' remembered of the creature, and the printing, each page has its own copy of these routines, and its own lists of
' phrases, fuw_rc_table(), which it must define before including this file

' --- its working storage is in globals.bas, under "private to stage-recall-include.bas", moved there on 22 October 2026 ---


Sub s_rc_char( pub_char As UByte )
    ' Moria's memoryPrint(), a character at a time: a line that is full is broken at its last space
    Dim q , i As UByte

    Poke A_RC_LINE + gub_rc_length , pub_char
    If pub_char = 10 Or gub_rc_length >= 79 Then
        q = gub_rc_length
        If pub_char <> UC_NEWLINE Then
            While Peek( A_RC_LINE + q ) <> UC_SPACE
                q = q - 1
            End While
        End If
        For i = 0 To UB_SCREEN_COLS - 1
            If i < q Then
                s_core_print_char_at( gub_rc_row , i , Peek( A_RC_LINE + i ) , UB_WHITE )
            Else
                s_core_print_char_at( gub_rc_row , i , 32 , UB_WHITE )
            End If
        Next
        gub_rc_row = gub_rc_row + 1
        ' what came after the space starts the next line
        i = 0
        While q < gub_rc_length
            q = q + 1
            Poke A_RC_LINE + i , Peek( A_RC_LINE + q )
            i = i + 1
        End While
        gub_rc_length = i
    Else
        gub_rc_length = gub_rc_length + 1
    End If
End Sub


Sub s_rc_print( ps_text As String )
    Dim i As UByte

    If Len( ps_text ) = 0 Then Return
    For i = 0 To Len( ps_text ) - 1
        s_rc_char( Code( ps_text( i ) ) )
    Next
End Sub


Sub s_rc_number( pul_value As ULong )
    s_rc_print( fs_core_number( pul_value ) )
End Sub


Sub s_rc_phrase( pub_table As UByte , pub_index As UByte )
    ' prints one phrase of one of the lists
    Dim luw_at As UInteger

    luw_at = fuw_rc_table( pub_table )
    While pub_index > 0
        While Peek( luw_at ) <> 0
            luw_at = luw_at + 1
        End While
        luw_at    = luw_at + 1
        pub_index = pub_index - 1
    End While
    While Peek( luw_at ) <> 0
        s_rc_char( Peek( luw_at ) )
        luw_at = luw_at + 1
    End While
End Sub


Function fub_rc_list( pul_bits As ULong , pub_count As UByte , pub_table As UByte , ps_first As String , ps_last As String ) As UByte
    ' the way Moria lists what a set of bits stands for: an opening, the phrases with commas between them, and
    ' ps_last before the last of them, bit 0 of pul_bits is the first phrase of the list, true if there were any
    Dim i           As UByte
    Dim lul_mask    As ULong
    Dim lub_any     As UByte = false

    lul_mask = 1
    For i = 0 To pub_count - 1
        If ( pul_bits bAnd lul_mask ) <> 0 Then
            pul_bits = pul_bits bAnd ( $FFFFFFFF - lul_mask )
            If lub_any = false Then
                s_rc_print( ps_first )
                lub_any = true
            ElseIf pul_bits <> 0 Then
                s_rc_print( ", " )
            Else
                s_rc_print( ps_last )
            End If
            s_rc_phrase( pub_table , i )
        End If
        lul_mask = lul_mask << 1
    Next
    Return lub_any
End Function


Function fs_rc_have( puw_count As UInteger ) As String
    If puw_count = 1 Then Return "has"
    Return "have"
End Function
