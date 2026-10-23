#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_commands()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: the player's commands, all but walking and the stairs, which the walking stage
' keeps for itself, this is the rest of Moria's doCommand() (game_run.cpp), most commands are a library of their own
' and this page only sends for them, a few small ones are done here...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , <which routine> ),
' the routines are:
'
'   UB_LIB_COMMANDS_KEY         carries out the command for the key in gub_key_char, gsw_lib_result is 0 if the key
'                               is not a command, otherwise the MB_COMMAND_ bits in constants.bas, which say what
'                               the walking stage must do next, gub_game_free_turn is set if the command took no time
'   UB_LIB_COMMANDS_DISTURB     something has disturbed the player: they stop resting, and stop searching,
'                               Moria's playerDisturb()
'
' the commands so far:
'   i e w t x   look at the pack or the equipment, wear or wield, take off, exchange weapons (the equipment library)
'   d           drop something from the pack
'   E q r       eat, quaff a potion, read a scroll (the consume and read libraries)
'   u a         use a staff, aim a wand (the devices library)
'   f B j       throw or fire (the throw library), bash, spike a door shut (the fight library)
'   F           fill the lamp with oil
'   -           move without picking up, the walking stage takes the step
'   C L M       the character's sheet, locate on the map, the whole map reduced (the info library)
'   V           the high scores (the scores library)
'   l /         look about, and what a character stands for, both with the monster memory (the look library)
'   ? h v       help, and the versions and credits (the text library)
'   =           the options (the second commands library)
'   {           inscribe something in the pack (the second commands library, as are F and #)
'   #           a count, then the command to repeat that many times: a step, B D R T j o s - or .
'   Ctrl-X      save the game and leave (the save library), it is picked up again when the game is next started
'   Ctrl-R      draw the screen again
'   Ctrl-V      help, as ? is, N.B: not the licence as in Moria, that is the file zxmoria.lic beside the game
'   Ctrl-P      the last message again, twice for all that are remembered (the text library, the core keeps them)
'   Q Ctrl-K    quit, after "Do you really want to quit?", the character is dead of "Quitting"
'   space ESC   nothing
'   }           (symbol shift and G) is not one of ours: the core takes it, in every stage, for its live monitor
'   o c s       open a door, close a door, search (the moves library)
'   D T         disarm a trap, tunnel (the traps library)
'   m p         cast a spell, recite a prayer (the cast library)
'   G b         study, to gain a spell or prayer, browse a book (the books library)
'   .           run, in a direction (the run library), the walking stage takes the steps
'   R           rest, for a number of turns or until fit again
'   S           search mode on and off
'   Ctrl-W      wizard mode on and off, and its commands while it is on (the wizard library, stage-lib-wizard.bas),
'               which is also given any key that is nothing else: "Type '?' for help."
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, the whole of Moria's list is in


' --- its working storage is in globals.bas, under "private to stage-lib-commands.bas", moved there on 22 October 2026 ---


Function fub_cm_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_cm_block()
    ' the player's details down the left of the screen are shown again
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


'##################################################################################################################################
' --- searching and resting ---

Sub s_cm_search_off()
    ' Moria's playerSearchOff()
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_RESET_VIEW
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED , 0 , $FFFF )
    gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_SEARCH )
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
    gsw_player_food_digested = gsw_player_food_digested - 1
End Sub


Sub s_cm_search_toggle()
    ' Moria's commandToggleSearch(): a searching player looks around at every step, and moves at half speed
    If ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then
        s_cm_search_off()
    Else
        ' Moria's playerSearchOn()
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED , 0 , 1 )
        gul_player_status = gul_player_status bOr UL_PY_SEARCH
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
        gsw_player_food_digested = gsw_player_food_digested + 1
    End If
End Sub


Sub s_cm_rest()
    ' Moria's playerRestOn(): the player says for how many turns, or * for until hit points and mana are back
    Dim lsl_turns   As Long = 0
    Dim lub_length  As UByte = 0
    Dim lub_star    As UByte = false
    Dim lub_done    As UByte = false

    s_msg_flush()
    s_msg_clear()
    If guw_game_command_count > 0 Then
        ' a count given before the command is how long to rest
        lsl_turns = guw_game_command_count
        guw_game_command_count = 0
        lub_done  = true
    Else
        s_core_print_string_at( 0 , 0 , "Rest for how long? " , UB_BRIGHT_WHITE )
    End If
    While lub_done = false
        s_core_get_key()
        If gub_key_char = UC_ENTER Then
            lub_done = true
        ElseIf gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then
            lsl_turns = 0
            lub_star  = false
            lub_done  = true
        ElseIf gub_key_char = Code( "*" ) And lub_length = 0 Then
            lub_star = true
            s_core_print_char_at( 0 , 19 , Code( "*" ) , UB_BRIGHT_WHITE )
            lub_length = 1
        ElseIf gub_key_char >= Code( "0" ) And gub_key_char <= Code( "9" ) And lub_length < 5 And lub_star = false Then
            lsl_turns = lsl_turns * 10 + ( gub_key_char - Code( "0" ) )
            s_core_print_char_at( 0 , 19 + lub_length , gub_key_char , UB_BRIGHT_WHITE )
            lub_length = lub_length + 1
        End If
    End While
    ' what was typed is not a message, Moria keeps nothing of it for Ctrl-P
    Asm
        call A_JUMP_HISTORY_FORGET
    End Asm
    s_msg_clear()

    If lub_star Then lsl_turns = -32767
    If lub_star Or ( lsl_turns > 0 And lsl_turns <= 32767 ) Then
        If ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then s_cm_search_off()
        gsw_player_rest   = lsl_turns
        gul_player_status = gul_player_status bOr UL_PY_REST
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
        gsw_player_food_digested = gsw_player_food_digested - 1
        ' the key that ended the answer must be let go first, or it would count as the key that stops the rest
        While fub_core_scan_key() <> 0
        End While
        ' N.B: this is not a message to be read and acknowledged, it stays up while the player rests
        s_core_print_string_at( 0 , 0 , "Press any key to stop resting..." , UB_BRIGHT_WHITE )
        Return
    End If
    ' something has gone wrong, or the player thought better of it
    If lsl_turns <> 0 Then s_core_message( UW_MSG_INVALID_REST_COUNT )
    gub_game_free_turn = true
End Sub


Sub s_cm_disturb()
    ' the screen's part of Moria's playerDisturb(), the game's part has been done already, where it happened, by
    ' s_dst_disturb() in stage-disturb-include.bas: the word for a rest that has ended, with the messages flushed,
    ' and the words for searching and speed when searching has been turned off
    Dim lub_disturb As UByte

    lub_disturb      = gub_game_disturb
    gub_game_disturb = 0
    gub_game_running       = 0
    guw_game_command_count = 0
    If gsw_player_rest <> 0 Or gub_game_rest_broken Then s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_REST_OFF )
    If ( lub_disturb bAnd MB_DISTURB_SEARCH_OFF ) <> 0 Then s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_STATUS_LINE )
End Sub


'##################################################################################################################################
' --- running ---

Function fub_cm_direction() As UByte
    ' asks which way, Moria's getDirectionWithMemory(), 0 if the player thought better of it
    Dim lub_direction As UByte = 0
    Dim luw_count     As UInteger

    ' a command that is being repeated uses the direction it had the first time, without asking, and asking
    ' does not end a count that has just been given, Moria's use_last_direction
    luw_count = guw_game_command_count
    If gub_game_repeat_key >= MB_REPEAT_DONE Then
        lub_direction = gub_player_prev_dir
    Else
        s_core_message( UW_MSG_WHICH_DIRECTION )
        Do
            s_core_get_key()
            s_core_direction_key()
            If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) And gub_key_char <> Code( "5" ) Then lub_direction = gub_key_char - Code( "0" )
            If guw_key_code = UW_KEY_UP Then lub_direction = 8
            If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
            If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
            If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
        Loop Until lub_direction <> 0 Or gub_key_char = UC_ESCAPE Or guw_key_code = 0
        ' the question is not a message, Moria asks it with getCommand() and keeps nothing of it for Ctrl-P
        Asm
            call A_JUMP_HISTORY_FORGET
        End Asm
        s_msg_clear()
    End If
    guw_game_command_count = luw_count
    If lub_direction <> 0 Then gub_player_prev_dir = lub_direction
    ' backing out takes no time, Moria's getDirectionWithMemory() sets player_free_turn itself
    If lub_direction = 0 Then gub_game_free_turn = true
    Return lub_direction
End Function


Sub s_cm_run()
    ' the player says which way and starts to run, Moria's getDirectionWithMemory() and playerFindInitialize(),
    ' this takes no time itself, the walking stage takes the first step of the run as its next turn
    Dim lub_direction As UByte

    gub_game_free_turn = true
    lub_direction = fub_cm_direction()
    If lub_direction = 0 Then Return
    ' the key must be let go of first, a key that is down stops a run
    While fub_core_scan_key() <> 0
    End While
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_RUN , UB_LIB_RUN_START , lub_direction , 0 )
    ' a count before a run is how many steps it goes on for, Moria's find_count: one fewer than the count is left
    ' after the first step, N.B: as in Moria a count of 1 therefore sets no limit at all
    guw_game_run_limit = 0
    If guw_game_command_count > 0 Then
        guw_game_run_limit     = guw_game_command_count - 1
        guw_game_command_count = 0
        ' N.B: "Repeat 3" comes off the bottom row, the count is the run's now, it was left there for good
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
    End If
End Sub


'##################################################################################################################################
' --- dropping ---

Function fub_cm_drop() As UByte
    ' Moria's uiCommandInventoryDropItem(), executeDropItemCommand() and inventoryDropItem(): something from the
    ' pack is put down where the player stands, true if the map changed
    ' N.B: / in the question goes over to what is being worn, and something picked there is taken off and dropped,
    ' Moria's "Throw off", the equipment library does that
    Dim lsw_place , lsw_i       As Integer
    Dim luw_record              As UInteger
    Dim lub_count , lub_all     As UByte
    Dim lub_number              As UByte
    Dim ls_prompt               As String

    gub_game_free_turn = true
    If gsw_player_pack_unique = 0 And gsw_player_equipment_count = 0 Then
        s_core_message( UW_MSG_BUT_YOURE_NOT_CARRYING_ANYTHING )
        Return false
    End If
    If Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_ITEM ) <> 0 Then
        s_core_message( UW_MSG_THERES_NO_ROOM_TO_DROP_ANYTHING )
        Return false
    End If
    ' the level's list of items is full? room is made by throwing distant things away, the compact library
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_OBJECTS )
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then Return false

    For lsw_i = 0 To UB_PACK_SIZE - 1
        Poke A_INV_MASK + lsw_i , 1
    Next
    ls_prompt = "Drop which one?"
    For lsw_i = 0 To Len( ls_prompt ) - 1
        Poke A_PROMPT + lsw_i , Code( ls_prompt( lsw_i ) )
    Next
    Poke A_PROMPT + Len( ls_prompt ) , 0
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE , UB_INV_CHOOSE_DROP , Cast( UInteger , UB_INVENTORY_SIZE ) << 8 )
    lsw_place = gsw_lib_result
    If lsw_place < 0 Then Return false
    If lsw_place >= UB_PACK_SIZE Then
        ' something that is being worn: Moria's executeRemoveItemCommand() with "r", take off and drop
        Return fub_cm_call( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_THROW_OFF , 0 , lsw_place )
    End If

    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    lub_count  = Peek( luw_record + UB_ITEM_COUNT_OFFSET )
    lub_all    = true
    If lub_count > 1 Then
        ' all of them, or just one? Moria's getInputConfirmationWithAbort()
        s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , true , 0 )
        ls_prompt = fs_core_text_at( A_TEXT_BUFFER )
        ls_prompt = "Drop all " + ls_prompt( 0 To Len( ls_prompt ) - 2 ) + "? [y/n]"
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , ls_prompt , UB_BRIGHT_WHITE )
        s_core_get_key()
        s_msg_clear()
        If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then Return false
        If gub_key_char <> Code( "y" ) And gub_key_char <> Code( "Y" ) Then lub_all = false
    End If
    gub_game_free_turn = false

    ' Moria's inventoryDropItem(): a new item on the level, a copy of the one in the pack, Moria's popt()
    lub_number = gub_dungeon_item_next
    gub_dungeon_item_next = gub_dungeon_item_next + 1
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    If lub_all = false Then gub_item_count = 1
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , lub_number , A_ITEM )
    Poke fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_ITEM , lub_number

    If lub_all Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_REMOVE_ALL , 0 , lsw_place )
    Else
        gsw_player_pack_weight = gsw_player_pack_weight - Peek( Integer , luw_record + UB_ITEM_WEIGHT_OFFSET )
        Poke luw_record + UB_ITEM_COUNT_OFFSET , lub_count - 1
    End If

    ' "Dropped 3 Flasks of Oil."
    s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_number , A_ITEM )
    gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , true , 0 )
    s_msg( "Dropped " + fs_core_text_at( A_TEXT_BUFFER ) )
    gul_player_status = gul_player_status bOr UL_PY_STR_WGT
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
    ' as a safety measure, set the player's pack weight to 0 when the last object is dropped
    If gsw_player_pack_unique = 0 And gsw_player_equipment_count = 0 Then gsw_player_pack_weight = 0
    Return true
End Function


'##################################################################################################################################

Function fub_cm_key( pub_key As UByte ) As UByte
    ' Moria's doCommand(), all of it but walking and the stairs, what comes back is 0 or the MB_COMMAND_ bits
    Dim lub_answer  As UByte = MB_COMMAND_DONE
    Dim luw_result  As UInteger
    Dim ls_prompt   As String
    Dim lub_i       As UByte

    ' N.B: Ctrl-P looks at this before it is cleared, see below
    lub_i = gub_cm_last_was_ctrl_p
    If pub_key <> 16 Or ( gub_key_modifiers bAnd MB_KEY_CTRL ) = 0 Then gub_cm_last_was_ctrl_p = false
    If pub_key = Code( "i" ) Or pub_key = Code( "e" ) Or pub_key = Code( "w" ) Or pub_key = Code( "t" ) Or pub_key = Code( "x" ) Then
        ' the inventory commands, the armour class and the stats may have changed
        ' N.B: none of them takes any time unless something is put on, taken off or exchanged, the equipment
        ' library clears gub_game_free_turn when it is
        gub_game_free_turn = true
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_COMMAND , pub_key , 0 )
        s_cm_block()
    ElseIf pub_key = Code( "d" ) Then
        If fub_cm_drop() Then lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
    ElseIf pub_key = Code( "E" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_CONSUME , UB_LIB_CONSUME_EAT , 0 , 0 ) = false Then gub_game_free_turn = true
        s_cm_block()
    ElseIf pub_key = Code( "q" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_CONSUME , UB_LIB_CONSUME_QUAFF , 0 , 0 ) = false Then gub_game_free_turn = true
        s_cm_block()
    ElseIf pub_key = Code( "r" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_READ , UB_LIB_READ_SCROLL , 0 , 0 ) = false Then gub_game_free_turn = true
        s_cm_block()
    ElseIf pub_key = Code( "u" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_DEVICES , UB_LIB_DEVICES_USE_STAFF , 0 , 0 ) = false Then gub_game_free_turn = true
        s_cm_block()
    ElseIf pub_key = Code( "a" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_DEVICES , UB_LIB_DEVICES_AIM_WAND , 0 , 0 ) = false Then gub_game_free_turn = true
        s_cm_block()
    ElseIf pub_key = Code( "f" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_THROW , UB_LIB_THROW_ITEM , 0 , 0 )
        s_cm_block()
    ElseIf pub_key = Code( "B" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_FIGHT , UB_LIB_FIGHT_BASH , 0 , 0 )
        s_cm_block()
        lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
    ElseIf pub_key = Code( "j" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_FIGHT , UB_LIB_FIGHT_SPIKE , 0 , 0 )
    ElseIf pub_key = Code( "o" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_OPEN , 0 , 0 ) Then
            lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
        Else
            gub_game_free_turn = true       ' there was nothing there to open
        End If
    ElseIf pub_key = Code( "c" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_CLOSE , 0 , 0 ) Then
            lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
        Else
            gub_game_free_turn = true       ' there was nothing there to close
        End If
    ElseIf pub_key = Code( "s" ) Then
        ' Moria's playerSearch(), with the player's own chance of finding things
        If fub_cm_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_SEARCH , 0 , Cast( UInteger , gsw_player_search ) ) Then lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
    ElseIf pub_key = Code( "D" ) Then
        ' disarm a trap, the traps library says whether the player then steps on to the square, the walking stage
        ' does the stepping
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_DISARM , 0 , 0 )
        luw_result = gsw_lib_result
        gub_game_step_direction = luw_result bAnd 255
        gub_game_step_code      = luw_result >> 8
    ElseIf pub_key = Code( "T" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_TUNNEL , 0 , 0 )
        lub_answer = lub_answer bOr MB_COMMAND_DRAW_AROUND
    ElseIf pub_key = Code( "m" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_CAST , UB_LIB_CAST_SPELL , 0 , 0 ) = false Then gub_game_free_turn = true
    ElseIf pub_key = Code( "p" ) Then
        If fub_cm_call( UB_PAGED_CODE_LIB_CAST , UB_LIB_CAST_PRAY , 0 , 0 ) = false Then gub_game_free_turn = true
    ElseIf pub_key = Code( "G" ) Then
        ' N.B: the library itself says when studying takes no time
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_BOOKS , UB_LIB_BOOKS_GAIN , 0 , 0 )
    ElseIf pub_key = Code( "b" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_BOOKS , UB_LIB_BOOKS_BROWSE , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "." ) Then
        s_cm_run()
    ElseIf pub_key = Code( "-" ) Then
        ' move without picking up: the walking stage takes the step
        gub_game_free_turn = true
        gub_game_step_direction = fub_cm_direction()
        If gub_game_step_direction <> 0 Then
            gub_game_free_turn = false
            gub_game_step_code = UB_STEP_PLAIN
        End If
    ElseIf pub_key = Code( "F" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_COMMANDS_2 , UB_LIB_COMMANDS_2_REFILL , 0 , 0 )
    ElseIf pub_key = Code( "l" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_LOOK , UB_LIB_LOOK_LOOK , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "/" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_LOOK , UB_LIB_LOOK_IDENTIFY , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "Q" ) Or ( pub_key = 11 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 ) Then
        ' Moria's commandQuit(), Q or Ctrl-K: the character is given up for dead, of "Quitting"
        gub_game_free_turn = true
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "Do you really want to quit? [y/n]" , UB_BRIGHT_WHITE )
        s_core_get_key()
        s_msg_clear()
        If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then
            ls_prompt = "Quitting"
            For lub_i = 0 To 7
                Poke A_DIED_FROM + lub_i , Code( ls_prompt( lub_i ) )
            Next
            Poke A_DIED_FROM + 8 , 0
            gub_game_character_dead = true
        End If
    ElseIf pub_key = Code( "#" ) Then
        ' a count, and the command it is for, which the walking stage then repeats
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_COMMANDS_2 , UB_LIB_COMMANDS_2_COUNT , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "{" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_COMMANDS_2 , UB_LIB_COMMANDS_2_INSCRIBE , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "=" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_COMMANDS_2 , UB_LIB_COMMANDS_2_OPTIONS , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = 91 Then
        ' [ (symbol shift and Y), ours, not Moria's ([ is no command in either of Moria's key sets, nor the wizard's): the
        ' mini map, off, 1:1, 1:2, and round again, it takes no turn, see stage-lib-minimap.bas, N.B: it was O until 16
        ' October 2026, when sdo chose [ (and } for the live monitor, which the core takes)
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_MINIMAP , UB_LIB_MINIMAP_CYCLE , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = 93 Then
        ' ] (symbol shift and U), ours, not Moria's (] is no command in either of Moria's key sets, nor the wizard's):
        ' the map's colours off and on, the same as "Plain map, no colours" on the options screen, it takes no turn
        ' (sdo, 23 October 2026, it was } for the morning, and ] the live monitor's)
        guw_game_options = guw_game_options bXor MW_OPTION_PLAIN_MAP
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
        gub_game_free_turn = true
    ElseIf pub_key = Code( "V" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_SHOW , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "C" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_CHARACTER , false , 0 )
        s_cm_block()
        gub_game_free_turn = true
    ElseIf pub_key = Code( "L" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_LOCATE , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "M" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_MAP , 0 , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = Code( "?" ) Or pub_key = Code( "h" ) Or ( pub_key = 22 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 ) Then
        ' N.B: with the rogue like commands on, it is their page that is shown...
        ' ...and Ctrl-V is help too, NOT Moria's (its Ctrl-V shows the licence, ours is the file zxmoria.lic beside the
        ' game): the ? of a PC keyboard is shift and /, and the emulator hands that over as caps shift, symbol shift
        ' and V, which is our Ctrl-V
        If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) <> 0 Then
            gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW , UB_TEXT_ROGUE_HELP , 0 )
        Else
            gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW , UB_TEXT_HELP , 0 )
        End If
        gub_game_free_turn = true
    ElseIf pub_key = Code( "v" ) Then
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW , UB_TEXT_VERSIONS , 0 )
        gub_game_free_turn = true
    ElseIf pub_key = 16 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then
        ' Ctrl-P: the last message again, and asked for twice running, all that are remembered
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_MESSAGES , gub_cm_last_was_ctrl_p , 0 )
        gub_game_free_turn = true
        gub_cm_last_was_ctrl_p = true
        Return lub_answer
    ElseIf pub_key = 24 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then
        ' Ctrl-X: Moria's commandSaveAndExit(), the save library writes the game to the SD card, and if that
        ' worked the walking stage hands back to the core, which goes back to NextZXOS
        gub_game_free_turn = true
        If gub_game_total_winner Then
            s_core_message( UW_MSG_YOU_ARE_A_TOTAL_WINNER_YOUR )
            ' N.B: Moria's words, but for its "Use 'Q' to when", mended, see umoria-oddities.md
            If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) <> 0 Then
                s_core_message( UW_MSG_USE_Q_WHEN_YOU_ARE_READY_TO_QUIT )
            Else
                s_core_message( UW_MSG_USE_CONTROL_K_WHEN_YOU_ARE_READY_TO_QUIT )
            End If
        Else
            s_msg_flush()
            gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_SAVE , UB_LIB_SAVE_SAVE , 0 , 0 )
            If gsw_lib_result = 0 Then
                ' the save has put the character in the high scores, and they are shown, as Moria's endGame() does
                gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_SHOW , 0 , 0 )
                gub_core_end = true
            Else
                s_msg( "The game could not be saved, page " + fs_core_number( gsw_lib_result ) + " would not write." )
            End If
        End If
    ElseIf pub_key = 18 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then
        ' Ctrl-R: everything is drawn again
        lub_answer = lub_answer bOr MB_COMMAND_DRAW_ALL
        gub_game_free_turn = true
    ElseIf pub_key = 32 Or pub_key = 27 Then
        ' space and escape do nothing, and take no time doing it
        gub_game_free_turn = true
    ElseIf pub_key = Code( "R" ) Then
        s_cm_rest()
    ElseIf pub_key = Code( "S" ) Then
        s_cm_search_toggle()
        gub_game_free_turn = true
    Else
        ' any other key: Ctrl-W, and while wizard mode is on the wizard's own commands, the wizard library answers
        ' as this routine does, it is the end of Moria's doCommand()
        gub_shared_1 = fub_cm_call( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_KEY , pub_key , 0 )
        lub_answer = gsw_lib_result
    End If
    Return lub_answer
End Function


Sub s_lib_commands()
    If gub_lib_function = UB_LIB_COMMANDS_KEY Then
        gsw_lib_result = fub_cm_key( gub_key_char )
    ElseIf gub_lib_function = UB_LIB_COMMANDS_DISTURB Then
        s_cm_disturb()
    End If
End Sub
