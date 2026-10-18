' shims for core API routines...
'
' how these work:
'   a stage calls one of these exactly as if it were the real routine, so the parameters and the return address are on the stack...
'   ...the shim then jumps (not calls) to the routine's fixed entry in the core jump table (see constants.bas)...
'   ...the real core routine therefore sees the stack exactly as if the stage had called it directly...
'   ...and when it finishes it removes the parameters and returns straight back to the stage.
'
' N.B: for any Sub that takes parameters the compiler starts it with "push ix : ld ix, 0 : add ix, sp"...
' ...so those shims must "pop ix" first to undo that, the shims with no parameters have nothing to undo.
' N.B: the shims that take a String work because the stages share the core's heap (see the heap notes in build.ps1)...
' ...the stage builds the string in the heap, and the core routine frees it from the same heap when it has finished with it.

Sub s_core_next_reg( pub_reg As UByte , pub_value As UByte )
    Asm
        pop ix
        jp A_JUMP_NEXT_REG
    End Asm
End Sub


Sub s_core_crash( pub_error_code As UByte , ps_error_text As String )
    Asm
        pop ix
        jp A_JUMP_CRASH
    End Asm
End Sub


Sub s_core_ram_copy( puw_src_address As UInteger , puw_dst_address As UInteger , puw_byte_count As UInteger )
    Asm
        pop ix
        jp A_JUMP_RAM_COPY
    End Asm
End Sub


Sub s_core_clear_screen()
    Asm
        jp A_JUMP_CLEAR_SCREEN
    End Asm
End Sub


Sub s_core_print_char_at( pub_x As UByte , pub_y As UByte , pub_char As UByte , pub_colour As UByte )
    Asm
        pop ix
        jp A_JUMP_PRINT_CHAR_AT
    End Asm
End Sub


Sub s_core_clear_row( pub_row As UByte , pub_from As UByte , pub_colour As UByte )
    ' a row of spaces, from the column pub_from to the end of the row: use this to clear a row, never a loop
    Asm
        pop ix
        jp A_JUMP_CLEAR_ROW
    End Asm
End Sub


Sub s_core_print_string_at( pub_x As UByte , pub_y As UByte , ps_text As String , pub_colour As UByte )
    Asm
        pop ix
        jp A_JUMP_PRINT_STRING_AT
    End Asm
End Sub


Sub s_core_get_key()
    Asm
        jp A_JUMP_GET_KEY
    End Asm
End Sub


Sub s_core_countdown( pub_x As UByte , pub_y As UByte , pub_stay_key As UByte , pub_flip_key As UByte )
    Asm
        pop ix
        jp A_JUMP_COUNTDOWN
    End Asm
End Sub


' N.B: a Function works through a shim in just the same way as a Sub, the core routine hands its result straight back to the stage...
' ...here the result is a string, which the core builds in the shared heap, and the stage frees once it has used it
Function fs_core_number( pul_value As ULong ) As String
    Asm
        pop ix
        jp A_JUMP_NUMBER
    End Asm
    Return ""       ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_core_scan_key() As UByte
    Asm
        jp A_JUMP_SCAN_KEY
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fs_core_key_name( pub_code As UByte , pub_modifiers As UByte ) As String
    Asm
        pop ix
        jp A_JUMP_KEY_NAME
    End Asm
    Return ""       ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_core_swap_paged_data( pub_slot As UByte , pub_page_number As UByte )
    Asm
        pop ix
        jp A_JUMP_SWAP_PAGED_DATA
    End Asm
End Sub


Function fub_core_file_save_page( ps_name As String , pub_page As UByte ) As UByte
    Asm
        pop ix
        jp A_JUMP_FILE_SAVE_PAGE
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_core_file_load_page( ps_name As String , pub_page As UByte ) As UByte
    Asm
        pop ix
        jp A_JUMP_FILE_LOAD_PAGE
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_core_random_seed( pul_seed As ULong )
    Asm
        pop ix
        jp A_JUMP_RANDOM_SEED
    End Asm
End Sub


Function ful_core_random() As ULong
    Asm
        jp A_JUMP_RANDOM
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function ful_core_random_number( pul_max As ULong ) As ULong
    Asm
        pop ix
        jp A_JUMP_RANDOM_NUMBER
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_core_dice_roll( pub_dice As UByte , pub_sides As UByte ) As UInteger
    Asm
        pop ix
        jp A_JUMP_DICE_ROLL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_core_record_address( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger ) As UInteger
    Asm
        pop ix
        jp A_JUMP_RECORD_ADDRESS
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_core_fetch_record( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger , puw_address As UInteger )
    Asm
        pop ix
        jp A_JUMP_FETCH_RECORD
    End Asm
End Sub


Sub s_core_store_record( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger , puw_address As UInteger )
    Asm
        pop ix
        jp A_JUMP_STORE_RECORD
    End Asm
End Sub


Function fuw_core_map_square( pub_first_page As UByte , pub_row As UByte , pub_col As UByte ) As UInteger
    Asm
        pop ix
        jp A_JUMP_MAP_SQUARE
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_core_message( puw_string As UInteger )
    Asm
        pop ix
        jp A_JUMP_MESSAGE
    End Asm
End Sub


Sub s_core_direction_key()
    Asm
        jp A_JUMP_DIRECTION_KEY
    End Asm
End Sub


Sub s_core_message_after( puw_before As UInteger , puw_string As UInteger )
    Asm
        pop ix
        jp A_JUMP_MESSAGE_AFTER
    End Asm
End Sub


Function ful_core_recall( puw_creature As UInteger , pub_what As UByte , pul_value As ULong ) As ULong
    Asm
        pop ix
        jp A_JUMP_RECALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fs_core_char( pub_code As UByte ) As String
    ' a string of one character, N.B: use this and never BASIC's own CHR, see the core's routine for why
    Asm
        pop ix
        jp A_JUMP_CHAR
    End Asm
    Return ""       ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fs_core_text_at( puw_address As UInteger ) As String
    Asm
        pop ix
        jp A_JUMP_TEXT_AT
    End Asm
    Return ""       ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_core_call_library( pub_page As UByte , pub_function As UByte )
    Asm
        pop ix
        jp A_JUMP_CALL_LIBRARY
    End Asm
End Sub


Function fub_core_print_text_at( pub_row As UByte , pub_col As UByte , puw_address As UInteger , pub_colour As UByte ) As UByte
    Asm
        pop ix
        jp A_JUMP_PRINT_TEXT_AT
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fsw_core_random_normal( psw_mean As Integer , psw_standard As Integer ) As Integer
    Asm
        pop ix
        jp A_JUMP_RANDOM_NORMAL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fsw_c_half( psw_value As Integer ) As Integer
    ' a signed number halved as C halves it, Moria's "/ 2": towards nought, so -3 / 2 is -1... Boriel turns a signed
    ' "/ 2" into a shift, sra, which goes down instead, -3 / 2 is -2, its normal, faster, choice, and one that
    ' differs from C only for an odd number below nought, which is where Moria's numbers sometimes are, so the places
    ' that can be negative use this, found 16 October 2026 when the wizard's teleport landed a square off Umoria's
    If psw_value < 0 Then Return -( ( -psw_value ) >> 1 )
    Return psw_value >> 1
End Function
