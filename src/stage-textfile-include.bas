' writing a file of text to the SD card, a line at a time, a library that makes one includes this file: the wizard's
' sample of objects, stage-lib-wizard-3.bas, and the character sheet, stage-lib-info.bas...
' ...the core saves files a whole 8KB page at a time, so the text is gathered in a spare page, and each time that is
' full it goes out as the file's next 8KB, the first of them replaces any file of that name, and the last is made up
' with spaces, so the file's length is always a whole number of 8KB
'   s_tf_begin( where the name is )     the name is text ending in a 0, 31 characters at most
'   s_tf_write( "a line" )              a line feed is put after it
'   fub_tf_end()                        true if all of it was written

' --- working storage, at the top of the page's own, see A_LIB_PRIVATE in constants.bas ---
Dim guw_tf_at               As UInteger At A_LIB_PRIVATE + 440      ' how much of the page being filled is full
Dim gub_tf_slot             As UByte    At A_LIB_PRIVATE + 442      ' which 8KB of the file that page is
Dim gub_tf_failed           As UByte    At A_LIB_PRIVATE + 443      ' true once the file would not write
Dim gub_tf_saved_page       As UByte    At A_LIB_PRIVATE + 444      ' the page the caller had in the first data slot
#define A_TF_NAME           A_LIB_PRIVATE + 448                     ' 32 bytes, the name of the file, text ending in a 0


Sub s_tf_begin( puw_name As UInteger )
    Dim i As UByte

    For i = 0 To 30
        Poke A_TF_NAME + i , Peek( puw_name + i )
    Next
    Poke A_TF_NAME + 31 , 0
    guw_tf_at         = 0
    gub_tf_slot       = 0
    gub_tf_failed     = false
    gub_tf_saved_page = gub_core_MMU0_page_number
End Sub


Sub s_tf_flush()
    ' the page that has been filled goes out to the file, as its next 8KB, N.B: the first replaces the whole file,
    ' and the core keeps the file open from then until fub_tf_end() closes it, see fub_core_file_transfer()
    If gub_tf_failed = false Then
        gub_core_file_slot = gub_tf_slot
        If fub_core_file_save_page( fs_core_text_at( A_TF_NAME ) , UB_PAGE_TEST_FILE ) <> 0 Then gub_tf_failed = true
        gub_core_file_slot = 255
    End If
    gub_tf_slot = gub_tf_slot + 1
    guw_tf_at   = 0
End Sub


Sub s_tf_char( pub_char As UByte )
    ' one character of the file, N.B: the page being filled is brought into the first data slot each time, the
    ' routines that make what is being written use the slots too
    If guw_tf_at = 8192 Then s_tf_flush()
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_TEST_FILE )
    Poke A_MMU_SLOT_PAGED_CORRIDORS + guw_tf_at , pub_char
    guw_tf_at = guw_tf_at + 1
End Sub


Sub s_tf_write( ps_text As String )
    ' a line of the file: the text and a line feed
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    i = 0
    While i < lub_length
        s_tf_char( Code( ps_text( i ) ) )
        i = i + 1
    End While
    s_tf_char( 10 )
End Sub


Function fub_tf_end() As UByte
    ' the last page, made up with spaces, and the caller's own page put back
    If guw_tf_at > 0 Then
        While guw_tf_at < 8192
            s_tf_char( 32 )
        End While
        s_tf_flush()
    End If
    ' the file is finished with, N.B: this must be done whether or not its pages went out, the core has it open
    If gub_tf_slot > 0 Then
        gub_core_file_slot = 254
        gub_shared_1 = fub_core_file_save_page( fs_core_text_at( A_TF_NAME ) , UB_PAGE_TEST_FILE )
        gub_core_file_slot = 255
    End If
    If gub_tf_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_tf_saved_page )
    If gub_tf_failed Then Return false
    Return true
End Function
