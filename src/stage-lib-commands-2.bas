#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_commands_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: three of the player's commands that the commands library,
' stage-lib-commands.bas, has no room for, it sends for them through the core:
' s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS_2 , <which routine> ), the routines are:
'
'   UB_LIB_COMMANDS_2_COUNT     # : a count, and the command it is for, Moria's getCommandRepeatCount()
'   UB_LIB_COMMANDS_2_INSCRIBE  { : the player writes on something in the pack, Moria's itemInscribe()
'   UB_LIB_COMMANDS_2_OPTIONS   = : the player's options, Moria's setGameOptions()
'   UB_LIB_COMMANDS_2_ROGUELIKE turns the rogue like command just typed into the command of ours that does the same,
'                               for the walking stage, when that option is on
'   UB_LIB_COMMANDS_2_REFILL    F : a flask of oil goes into the lamp, Moria's inventoryRefillLamp(), this one
'                               says for itself, in gub_game_free_turn, whether it took any time


Function fub_cm_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function

Dim gub_cm_rogue_dir        As UByte    At A_LIB_PRIVATE + 200      ' the direction that came with a rogue like command, 0 for none


Function fub_cm_rogue( pub_key As UByte ) As UByte
    ' turns a rogue like command into the command of ours that does the same, 255 if it is not a command, and
    ' leaves in gub_cm_rogue_dir the direction that came with it, if one did: a move is the digit, a run is "."
    ' and its direction, a tunnel is "T" and its direction
    ' N.B: Moria works the other way about, its own commands are the rogue like ones and the original keys are
    ' turned into them, its originalCommands(), this is that table read backwards
    Dim lub_dir     As UByte = 0
    Dim lub_small   As UByte
    Dim lub_ctrl    As UByte = false

    gub_cm_rogue_dir = 0
    If ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then lub_ctrl = true

    ' the eight directions: on their own a step, with SHIFT a run, with CTRL a tunnel
    lub_small = pub_key bOr 32
    If lub_ctrl And pub_key < 27 Then lub_small = pub_key + 96
    If lub_small = Code( "b" ) Then lub_dir = 1
    If lub_small = Code( "j" ) Then lub_dir = 2
    If lub_small = Code( "n" ) Then lub_dir = 3
    If lub_small = Code( "h" ) Then lub_dir = 4
    If lub_small = Code( "l" ) Then lub_dir = 6
    If lub_small = Code( "y" ) Then lub_dir = 7
    If lub_small = Code( "k" ) Then lub_dir = 8
    If lub_small = Code( "u" ) Then lub_dir = 9
    If lub_dir <> 0 Then
        If lub_ctrl And pub_key < 27 Then
            gub_cm_rogue_dir = lub_dir
            Return Code( "T" )
        ElseIf pub_key >= Code( "a" ) And pub_key <= Code( "z" ) Then
            Return Code( "0" ) + lub_dir
        ElseIf pub_key >= Code( "A" ) And pub_key <= Code( "Z" ) Then
            gub_cm_rogue_dir = lub_dir
            Return Code( "." )
        End If
    End If
    ' the control keys that are not directions are the same in both
    If lub_ctrl And pub_key < 27 Then Return pub_key

    If pub_key = Code( "." ) Then Return Code( "5" )
    If pub_key = Code( "f" ) Then Return Code( "B" )
    If pub_key = Code( "W" ) Then Return Code( "L" )
    If pub_key = Code( "#" ) Then Return Code( "S" )
    If pub_key = Code( "z" ) Then Return Code( "a" )
    If pub_key = Code( "Z" ) Then Return Code( "u" )
    If pub_key = Code( "P" ) Then Return Code( "b" )
    If pub_key = Code( "t" ) Then Return Code( "f" )
    If pub_key = Code( "T" ) Then Return Code( "t" )
    If pub_key = Code( "S" ) Then Return Code( "j" )
    If pub_key = Code( "x" ) Then Return Code( "l" )
    If pub_key = Code( "X" ) Then Return Code( "x" )
    ' three of the wizard's, which are control keys in the original commands
    If pub_key = 92 Or pub_key = Code( "*" ) Or pub_key = Code( "&" ) Then
        gub_key_modifiers = gub_key_modifiers bOr MB_KEY_CTRL
        If pub_key = 92 Then Return 8
        If pub_key = Code( "*" ) Then Return 12
        Return 21
    End If
    ' the letters that are the same command in both, anything else among the letters is not a command
    If ( pub_key >= Code( "a" ) And pub_key <= Code( "z" ) ) Or ( pub_key >= Code( "A" ) And pub_key <= Code( "Z" ) ) Then
        lub_small = 255
        If pub_key = Code( "c" ) Or pub_key = Code( "d" ) Or pub_key = Code( "e" ) Or pub_key = Code( "i" ) Or pub_key = Code( "m" ) Then lub_small = pub_key
        If pub_key = Code( "o" ) Or pub_key = Code( "p" ) Or pub_key = Code( "q" ) Or pub_key = Code( "r" ) Or pub_key = Code( "s" ) Then lub_small = pub_key
        If pub_key = Code( "v" ) Or pub_key = Code( "w" ) Or pub_key = Code( "C" ) Or pub_key = Code( "D" ) Or pub_key = Code( "E" ) Then lub_small = pub_key
        If pub_key = Code( "F" ) Or pub_key = Code( "G" ) Or pub_key = Code( "M" ) Or pub_key = Code( "R" ) Or pub_key = Code( "V" ) Then lub_small = pub_key
        If pub_key = Code( "Q" ) Then lub_small = pub_key
        Return lub_small
    End If
    Return pub_key
End Function


Sub s_cm_count()
    ' Moria's getCommandRepeatCount(), and what executeInputCommands() does with it: the player gives a count and
    ' then the command it is for, which the walking stage then does that many times, or until something stops it
    ' N.B: with the rogue like commands a count is begun by its first digit, which is in gub_key_char as we arrive
    Dim luw_count   As UInteger = 0
    Dim lub_key     As UByte
    Dim lub_valid   As UByte = false
    Dim lub_rogue   As UByte = false

    If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) <> 0 Then
        lub_rogue = true
        luw_count = gub_key_char - Code( "0" )
    End If
    gub_cm_rogue_dir = 0
    s_msg_flush()
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , "Repeat count:" , UB_WHITE )
    If lub_rogue Then s_core_print_string_at( 0 , 14 , fs_core_number( luw_count ) , UB_WHITE )
    Do
        s_core_get_key()
        lub_key = gub_key_char
        If guw_key_code = 0 Then lub_key = 27
        If lub_key = 8 Then
            luw_count = luw_count / 10
        ElseIf lub_key >= Code( "0" ) And lub_key <= Code( "9" ) Then
            If luw_count <= 99 Then luw_count = luw_count * 10 + ( lub_key - Code( "0" ) )
        End If
        s_core_print_string_at( 0 , 14 , fs_core_number( luw_count ) + "    " , UB_WHITE )
    Loop While lub_key = 8 Or ( lub_key >= Code( "0" ) And lub_key <= Code( "9" ) )
    If luw_count = 0 Then
        luw_count = 99
        s_core_print_string_at( 0 , 14 , "99" , UB_WHITE )
    End If
    ' a special hack to allow numbers as commands
    If lub_key = 32 Then
        s_core_print_string_at( 0 , 20 , "Command:" , UB_WHITE )
        s_core_get_key()
        lub_key = gub_key_char
    End If
    ' the arrow keys are the same commands as 8, 2, 4 and 6
    If guw_key_code = UW_KEY_UP Then lub_key = Code( "8" )
    If guw_key_code = UW_KEY_DOWN Then lub_key = Code( "2" )
    If guw_key_code = UW_KEY_LEFT Then lub_key = Code( "4" )
    If guw_key_code = UW_KEY_RIGHT Then lub_key = Code( "6" )
    s_msg_clear()
    If lub_key = 27 Then Return
    ' a rogue like command is turned into ours, a direction may come with it
    If lub_rogue And guw_key_code < 130 Then lub_key = fub_cm_rogue( lub_key )

    ' Moria's validCountCommand(): the commands it makes sense to repeat
    If lub_key >= Code( "1" ) And lub_key <= Code( "9" ) Then lub_valid = true
    If lub_key = Code( "B" ) Or lub_key = Code( "D" ) Or lub_key = Code( "R" ) Or lub_key = Code( "T" ) Or lub_key = Code( "j" ) Then lub_valid = true
    If lub_key = Code( "o" ) Or lub_key = Code( "s" ) Or lub_key = Code( "-" ) Or lub_key = Code( "." ) Then lub_valid = true
    ' ...and three of the wizard's: Ctrl-D, Ctrl-G and +, each uses the count itself, see stage-lib-wizard.bas
    If lub_key = Code( "+" ) Or ( ( lub_key = 4 Or lub_key = 7 ) And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 ) Then lub_valid = true
    If lub_valid = false Then
        s_core_message( UW_MSG_INVALID_COMMAND_WITH_A_COUNT )
        Return
    End If
    ' N.B: up to 999, as Moria's, it was kept to 255 until 16 October 2026, when the count was a byte
    guw_game_command_count = luw_count
    gub_game_repeat_key    = lub_key
    If gub_cm_rogue_dir <> 0 Then
        ' the direction is known already, so it is not asked for: as from the second time round of any count
        gub_player_prev_dir = gub_cm_rogue_dir
        gub_game_repeat_key = lub_key bOr 128
    End If
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
    ' the key must be let go of first, a key that is down stops the repeating
    While fub_core_scan_key() <> 0
    End While
End Sub


Sub s_cm_inscribe()
    ' Moria's itemInscribe(): the player writes a few words of their own on something they carry
    ' N.B: / in the question goes over to what is being worn
    Dim lsw_i , lsw_place           As Integer
    Dim luw_record                  As UInteger
    Dim ls_prompt , ls_name         As String
    Dim lub_max , lub_length , lub_col As UByte

    If gsw_player_pack_unique = 0 And gsw_player_equipment_count = 0 Then
        s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING_TO )
        Return
    End If
    For lsw_i = 0 To UB_PACK_SIZE - 1
        Poke A_INV_MASK + lsw_i , 1
    Next
    ls_prompt = "Which one? "
    For lsw_i = 0 To Len( ls_prompt ) - 1
        Poke A_PROMPT + lsw_i , Code( ls_prompt( lsw_i ) )
    Next
    Poke A_PROMPT + Len( ls_prompt ) , 0
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE , UB_INV_CHOOSE_TRY , Cast( UInteger , UB_INVENTORY_SIZE ) << 8 )
    lsw_place = gsw_lib_result
    If lsw_place < 0 Then Return

    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , true , 0 )
    ls_name = fs_core_text_at( A_TEXT_BUFFER )
    s_msg( "Inscribing " + ls_name )
    If Peek( luw_record + UB_ITEM_INSCRIPTION_OFFSET ) <> 0 Then
        ls_prompt = "Replace " + fs_core_text_at( luw_record + UB_ITEM_INSCRIPTION_OFFSET ) + " New inscription:"
    Else
        ls_prompt = "Inscription: "
    End If
    lub_max = 12
    If Len( ls_name ) > 66 Then lub_max = 78 - Len( ls_name )
    ' N.B: as in Moria the question simply goes over the message, plain white so that it is not taken for one
    s_core_clear_row( 0 , 0 , UB_WHITE )
    gub_message_length = 0
    s_core_print_string_at( 0 , 0 , ls_prompt , UB_BRIGHT_WHITE )
    lub_col    = Len( ls_prompt )
    lub_length = 0
    ' Moria's getStringInput(): escape leaves things as they were
    Do
        s_core_get_key()
        If gub_key_char = 27 Or guw_key_code = 0 Then
            s_msg_clear()
            Return
        End If
        If gub_key_char = 8 Then
            If lub_length > 0 Then
                lub_length = lub_length - 1
                s_core_print_char_at( 0 , lub_col + lub_length , 32 , UB_WHITE )
            End If
        ElseIf gub_key_char >= 32 And gub_key_char < 127 And lub_length < lub_max Then
            Poke A_PROMPT + lub_length , gub_key_char
            s_core_print_char_at( 0 , lub_col + lub_length , gub_key_char , UB_WHITE )
            lub_length = lub_length + 1
        End If
    Loop Until gub_key_char = 13
    ' Moria's itemReplaceInscription()
    For lub_col = 0 To 12
        If lub_col < lub_length Then
            Poke luw_record + UB_ITEM_INSCRIPTION_OFFSET + lub_col , Peek( A_PROMPT + lub_col )
        Else
            Poke luw_record + UB_ITEM_INSCRIPTION_OFFSET + lub_col , 0
        End If
    Next
    s_msg_clear()
End Sub


Function fuw_cm_options( pub_which As UByte ) As UInteger
    ' Moria's game_options[]: what each option is called, text ending in a 0, in the order they are shown, and,
    ' for pub_which of 1, which bit of guw_game_options each one is, 2 bytes each
    If pub_which = 1 Then Return @cm_option_bits
    Return @cm_option_names
cm_option_names:
    Asm
        defm "Running: cut known corners"
        defb 0
        defm "Running: examine potential corners"
        defb 0
        defm "Running: print self during run"
        defb 0
        defm "Running: stop when map sector changes"
        defb 0
        defm "Running: run through open doors"
        defb 0
        defm "Prompt to pick up objects"
        defb 0
        defm "Rogue like commands"
        defb 0
        defm "Show weights in inventory"
        defb 0
        defm "Highlight and notice mineral seams"
        defb 0
        defm "Beep for invalid character"
        defb 0
        defm "Display rest/repeat counts"
        defb 0
    End Asm
cm_option_bits:
    Asm
        defw $0001, $0002, $0004, $0008, $0100, $0010, $0020, $0040, $0080, $0200, $0400
    End Asm
    Return 0
End Function


Sub s_cm_option_line( pub_option As UByte , pub_current As UByte )
    ' one line of the options screen: its name, and yes or no, N.B: we have no cursor, the answer of the line
    ' the player is on is in bright yellow instead
    Dim luw_at          As UInteger
    Dim i , lub_col     As UByte
    Dim lub_colour      As UByte

    luw_at = fuw_cm_options( 0 )
    i = pub_option
    While i > 0
        While Peek( luw_at ) <> 0
            luw_at = luw_at + 1
        End While
        luw_at = luw_at + 1
        i = i - 1
    End While
    For lub_col = 0 To UB_SCREEN_COLS - 1
        i = 32
        If lub_col < 38 Then
            If Peek( luw_at ) <> 0 Then
                i = Peek( luw_at )
                luw_at = luw_at + 1
            End If
        ElseIf lub_col = 38 Then
            i = Code( ":" )
        End If
        s_core_print_char_at( pub_option + 1 , lub_col , i , UB_WHITE )
    Next
    lub_colour = UB_WHITE
    If pub_current Then lub_colour = UB_BRIGHT_YELLOW
    If ( guw_game_options bAnd Peek( UInteger , fuw_cm_options( 1 ) + 2 * Cast( UInteger , pub_option ) ) ) <> 0 Then
        s_core_print_string_at( pub_option + 1 , 40 , "yes" , lub_colour )
    Else
        s_core_print_string_at( pub_option + 1 , 40 , "no " , lub_colour )
    End If
End Sub


Sub s_cm_options()
    ' = : Moria's setGameOptions(), the screen is put aside and put back afterwards
    Dim lub_option , lub_was , i    As UByte
    Dim lub_saved_page              As UByte
    Dim luw_bit                     As UInteger
    Dim lub_key , lub_next          As UByte

    s_msg_flush()
    lub_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , 5120 )

    s_core_clear_row( 0 , 0 , UB_WHITE )
    s_core_clear_row( 12 , 0 , UB_WHITE )
    s_core_print_string_at( 0 , 0 , "  ESC when finished, y/n to set options, <return> or - to move cursor" , UB_WHITE )
    For i = 0 To 10
        s_cm_option_line( i , false )
    Next

    lub_option = 0
    Do
        s_cm_option_line( lub_option , true )
        s_core_get_key()
        lub_key  = gub_key_char
        lub_was  = lub_option
        lub_next = false
        If lub_key = 27 Or guw_key_code = 0 Then Exit Do
        If lub_key = Code( "-" ) Then
            If lub_option > 0 Then
                lub_option = lub_option - 1
            Else
                lub_option = 10
            End If
        ElseIf lub_key = 32 Or lub_key = 13 Then
            lub_next = true
        ElseIf ( lub_key bOr 32 ) = Code( "y" ) Or ( lub_key bOr 32 ) = Code( "n" ) Then
            luw_bit = Peek( UInteger , fuw_cm_options( 1 ) + 2 * Cast( UInteger , lub_option ) )
            guw_game_options = guw_game_options bAnd ( $FFFF - luw_bit )
            If ( lub_key bOr 32 ) = Code( "y" ) Then guw_game_options = guw_game_options bOr luw_bit
            lub_next = true
        End If
        If lub_next Then
            If lub_option < 10 Then
                lub_option = lub_option + 1
            Else
                lub_option = 0
            End If
        End If
        s_cm_option_line( lub_was , false )
    Loop

    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , 5120 )
    If lub_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , lub_saved_page )
    gub_message_length = 0
End Sub


Sub s_cm_refill()
    ' Moria's inventoryRefillLamp(): a flask of oil from the pack goes into the lamp the player is using
    Dim lsw_i , lsw_flask   As Integer
    Dim luw_lamp            As UInteger
    Dim lsw_oil             As Integer

    gub_game_free_turn = true
    luw_lamp = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_LIGHT ) * UB_RECORD_SIZE
    ' N.B: as in Moria it is the sub category that says lamp, so with nothing in the hand at all the answer is "no oil"
    If Peek( luw_lamp + UB_ITEM_SUB_CATEGORY_OFFSET ) <> 0 Then
        s_core_message( UW_MSG_BUT_YOU_ARE_NOT_USING_A_LAMP )
        Return
    End If
    lsw_flask = -1
    If gsw_player_pack_unique > 0 Then
        For lsw_i = 0 To gsw_player_pack_unique - 1
            If lsw_flask < 0 And Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_FLASK Then lsw_flask = lsw_i
        Next
    End If
    If lsw_flask < 0 Then
        s_core_message( UW_MSG_YOU_HAVE_NO_OIL )
        Return
    End If

    gub_game_free_turn = false
    lsw_oil = Peek( Integer , luw_lamp + UB_ITEM_MISC_USE_OFFSET ) + Peek( Integer , A_INVENTORY + Cast( UInteger , lsw_flask ) * UB_RECORD_SIZE + UB_ITEM_MISC_USE_OFFSET )
    If lsw_oil > 15000 Then
        ' OBJECT_LAMP_MAX_CAPACITY
        lsw_oil = 15000
        s_core_message( UW_MSG_YOUR_LAMP_OVERFLOWS_SPILLING_OIL )
        s_core_message( UW_MSG_YOUR_LAMP_IS_FULL )
    ElseIf lsw_oil > 7500 Then
        s_core_message( UW_MSG_YOUR_LAMP_IS_MORE_THAN_HALF_FULL )
    ElseIf lsw_oil = 7500 Then
        s_core_message( UW_MSG_YOUR_LAMP_IS_HALF_FULL )
    Else
        s_core_message( UW_MSG_YOUR_LAMP_IS_LESS_THAN_HALF_FULL )
    End If
    Poke UInteger luw_lamp + UB_ITEM_MISC_USE_OFFSET , Cast( UInteger , lsw_oil )
    ' "You have 2 Flasks of Oil." and one of them goes
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_USE_REMAINING , lsw_flask , 0 )
End Sub

Sub s_lib_commands_2()
    If gub_lib_function = UB_LIB_COMMANDS_2_COUNT Then
        s_cm_count()
    ElseIf gub_lib_function = UB_LIB_COMMANDS_2_INSCRIBE Then
        s_cm_inscribe()
    ElseIf gub_lib_function = UB_LIB_COMMANDS_2_REFILL Then
        s_cm_refill()
    ElseIf gub_lib_function = UB_LIB_COMMANDS_2_OPTIONS Then
        s_cm_options()
    ElseIf gub_lib_function = UB_LIB_COMMANDS_2_ROGUELIKE Then
        ' the key just pressed, in gub_key_char, is a rogue like command: it is turned into ours, for the walking
        ' stage, gsw_lib_result is true if it was a step, or came with its direction
        gsw_lib_result = false
        If guw_key_code >= 130 Then
            ' the arrow keys are as they were
        ElseIf gub_key_char >= Code( "0" ) And gub_key_char <= Code( "9" ) Then
            ' a digit begins a count, and then nothing more is to be done this time round
            s_cm_count()
            gub_key_char = 32
            guw_key_code = 32
        Else
            gub_key_char = fub_cm_rogue( gub_key_char )
            guw_key_code = gub_key_char
            If gub_cm_rogue_dir <> 0 Then
                gub_player_prev_dir = gub_cm_rogue_dir
                gub_game_repeat_key = gub_key_char bOr 128
                gsw_lib_result = true
            ElseIf gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) Then
                gsw_lib_result = true
            End If
        End If
    End If
End Sub
