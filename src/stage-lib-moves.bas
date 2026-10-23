#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_moves()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: the things the player does to what is on the squares around them, from Moria's
' player.cpp, player_move.cpp and dungeon.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MOVES , <which routine> ), the routines are:
'
'   UB_LIB_MOVES_OPEN       asks which direction, and opens the door there, picking its lock if it has one, Moria's
'                           playerOpenClosedObject()
'   UB_LIB_MOVES_CLOSE      asks which direction, and closes the door there, Moria's playerCloseDoor()
'   UB_LIB_MOVES_SEARCH     looks for secret doors and hidden traps on the nine squares around the player, the chance
'                           of finding each is guw_lib_param_2, a signed number, Moria's playerSearch()
'   UB_LIB_MOVES_CARRY      the player has stepped on something: gold goes in the purse, anything else goes in the
'                           pack if gub_lib_param_1 is true and there is room for it, Moria's carry()
'   UB_LIB_MOVES_DELETE_OBJECT  takes whatever is on a square off the level, the row is gub_lib_param_1 and the
'                           column guw_lib_param_2, Moria's dungeonDeleteObject(), for other pages to use, a monster
'                           that picks things up for one
'
' each leaves true in gsw_lib_result if it changed the map or the player, this page draws nothing but messages, the
' stage then draws the squares around the player again, and the player's details
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   (chests are the chests library's, stage-lib-chests.bas, traps going off the traps library's)


' --- its working storage is in globals.bas, under "private to stage-lib-moves.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- messages with something in the middle of them ---

Sub s_mv_begin()
    gub_mv_length = 0
    Poke A_MV_TEXT , 0
End Sub


Sub s_mv_add( ps_text As String )
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    i = 0
    While i < lub_length And gub_mv_length < 238
        Poke A_MV_TEXT + gub_mv_length , Code( ps_text( i ) )
        gub_mv_length = gub_mv_length + 1
        i = i + 1
    End While
    Poke A_MV_TEXT + gub_mv_length , 0
End Sub


Sub s_mv_add_description( pub_last As UByte )
    ' adds the working item's full description, with pub_last in place of the full stop it ends in
    Dim lub_char As UByte
    Dim i        As UByte = 0

    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    lub_char = Peek( A_TEXT_BUFFER )
    While lub_char <> 0 And gub_mv_length < 238
        Poke A_MV_TEXT + gub_mv_length , lub_char
        gub_mv_length = gub_mv_length + 1
        i = i + 1
        lub_char = Peek( A_TEXT_BUFFER + i )
    End While
    If gub_mv_length > 0 Then Poke A_MV_TEXT + gub_mv_length - 1 , pub_last
    Poke A_MV_TEXT + gub_mv_length , 0
End Sub


Function fub_mv_confirm() As UByte
    ' asks the question that has been built up, true for y, Moria's getInputConfirmation()
    Dim lub_answer As UByte = false

    s_msg_text( A_MV_TEXT )
    If gub_message_length > 72 Then gub_message_length = 72
    s_core_print_string_at( 0 , gub_message_length , " [y/n]" , UB_BRIGHT_WHITE )
    s_core_get_key()
    If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then lub_answer = true
    s_msg_clear()
    Return lub_answer
End Function


'##################################################################################################################################
' --- the map and the level's items ---

Function fuw_mv_square( pub_y As UByte , pub_x As UByte ) As UInteger
    Return fuw_core_map_square( gub_level_map_page , pub_y , pub_x )
End Function


Function fuw_mv_item( pub_item As UByte ) As UInteger
    ' where the record of one of the level's items is
    Return fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item )
End Function


Sub Fastcall s_mv_scan_row( puw_item_byte As UInteger )
    ' goes along one row of the map, from the address given, the "item" byte of its first square, and wherever
    ' the item number is gub_mv_scan_old makes it gub_mv_scan_new
    Asm
        ld a, (A_GAME + 19)             ; gub_dungeon_cols
        ld b, a
        ld a, (A_MV_SCAN_NEW)
        ld c, a
        ld a, (A_MV_SCAN_OLD)
        ld de, UB_MAP_SQUARE_SIZE
    mv_scan_row_loop:
        cp (hl)
        jr nz, mv_scan_row_next
        ld (hl), c
    mv_scan_row_next:
        add hl, de
        djnz mv_scan_row_loop
    End Asm
End Sub


Sub s_mv_delete_object( pub_y As UByte , pub_x As UByte )
    ' takes what is on a square off the level, Moria's dungeonDeleteObject() and its pusht(): the level's items are
    ' kept as a list with no gaps, so the last item in the list moves into the place of the one that has gone, and
    ' the square that last item lies on is found and told its new number
    Dim luw_square              As UInteger
    Dim lub_item , lub_last , y As UByte

    luw_square = fuw_mv_square( pub_y , pub_x )
    lub_item   = Peek( luw_square + UB_SQUARE_ITEM )
    If lub_item = 0 Then Return
    If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_BLOCKED_FLOOR Then Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_CORR_FLOOR
    Poke luw_square + UB_SQUARE_ITEM , 0
    Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bAnd ( 255 - MB_SQUARE_FIELD_MARK )

    lub_last = gub_dungeon_item_next - 1
    If lub_item <> lub_last Then
        s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_last , A_OBJECT )
        s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , lub_item , A_OBJECT )
        gub_mv_scan_old = lub_last
        gub_mv_scan_new = lub_item
        For y = 0 To gub_dungeon_rows - 1
            s_mv_scan_row( fuw_mv_square( y , 0 ) + UB_SQUARE_ITEM )
        Next
    End If
    gub_dungeon_item_next = lub_last
End Sub


Sub s_mv_change_item( pub_item As UByte , puw_object As UInteger )
    ' one of the level's items becomes a brand new one of another kind, Moria's inventoryItemCopyTo()
    Dim i As UByte

    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , puw_object , A_OBJECT )
    For i = 0 To 31
        Poke A_ITEM + i , 0
    Next
    s_core_ram_copy( A_OBJECT + UB_ITEM_OBJECT_FIELDS , A_ITEM + UB_ITEM_OBJECT_FIELDS , UB_RECORD_SIZE - UB_ITEM_OBJECT_FIELDS )
    guw_item_object = puw_object
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , pub_item , A_ITEM )
End Sub


'##################################################################################################################################
' --- directions ---

Function fub_mv_direction() As UByte
    ' asks which way, Moria's getDirectionWithMemory(): the answer is as on a numeric keypad, 0 if the player thought
    ' better of it, and the square that way from the player is left in gub_mv_y and gub_mv_x
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
    ' backing out takes no time, Moria's getDirectionWithMemory() sets player_free_turn itself
    If lub_direction = 0 Then
        gub_game_free_turn = true
        Return 0
    End If

    gub_player_prev_dir = lub_direction
    ' Moria's playerMovePosition(), the player is never on the edge of the map, so the square is always on it
    gub_mv_y = gub_player_row + 1 - ( lub_direction - 1 ) / 3       ' 1 2 3 go down, 7 8 9 go up
    gub_mv_x = gub_player_col + ( lub_direction - 1 ) Mod 3 - 1     ' 1 4 7 go left, 3 6 9 go right
    Return lub_direction
End Function


'##################################################################################################################################
' --- doors ---

Function fsw_mv_lock_picking_skill() As Integer
    ' Moria's playerLockPickingSkill()
    Dim lsw_skill As Integer

    lsw_skill = gsw_player_disarm
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DISARM )
    lsw_skill = lsw_skill + 2 * gsw_lib_result
    gub_lib_param_1 = UB_STAT_INT
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_skill = lsw_skill + gsw_lib_result
    lsw_skill = lsw_skill + Cast( Integer , gub_class_adj_disarm ) * Cast( Integer , guw_player_level ) / 3
    Return lsw_skill
End Function


Function fub_mv_open() As UByte
    ' Moria's playerOpenClosedObject() and openClosedDoor()
    Dim luw_record              As UInteger
    Dim lub_item , lub_category As UByte
    Dim lsw_misc_use            As Integer

    If fub_mv_direction() = 0 Then Return false
    lub_item = Peek( fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_ITEM )
    lub_category = 0
    If lub_item <> 0 Then
        luw_record   = fuw_mv_item( lub_item )
        lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lsw_misc_use = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
    End If
    If lub_category = UB_TV_CLOSED_DOOR Or lub_category = UB_TV_CHEST Then
        ' a monster in the way? and chests are the chests library's
        gub_lib_param_1 = Peek( fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_MONSTER )
        If gub_lib_param_1 > 1 Then
            s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_BLOCKED )
            Return true
        End If
        If lub_category = UB_TV_CHEST Then
            gub_lib_param_1 = gub_mv_y
            guw_lib_param_2 = gub_mv_x
            s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_OPEN )
            Return true
        End If
    Else
        s_core_message( UW_MSG_I_DO_NOT_SEE_ANYTHING_YOU_CAN )
        Return false
    End If

    If lsw_misc_use > 0 Then
        ' it is locked
        If gsw_player_confused > 0 Then
            s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED_TO_PICK_THE )
        ElseIf fsw_mv_lock_picking_skill() - lsw_misc_use > Cast( Integer , ful_core_random_number( 100 ) ) Then
            s_core_message( UW_MSG_YOU_HAVE_PICKED_THE_LOCK )
            gsl_player_exp = gsl_player_exp + 1
            s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
            lsw_misc_use   = 0
        Else
            s_msg_quiet( "You failed to pick the lock." )
        End If
    ElseIf lsw_misc_use < 0 Then
        s_core_message( UW_MSG_IT_APPEARS_TO_BE_STUCK )
    End If

    If lsw_misc_use = 0 Then
        s_mv_change_item( lub_item , UW_OBJ_OPEN_DOOR )
        Poke fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_FEATURE , UB_TILE_CORR_FLOOR
        ' it is open, there is no more to repeat
        guw_game_command_count = 0
    End If
    Return true
End Function


Function fub_mv_close() As UByte
    ' Moria's playerCloseDoor()
    Dim luw_record              As UInteger
    Dim lub_item , lub_category As UByte

    If fub_mv_direction() = 0 Then Return false
    lub_item = Peek( fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_ITEM )
    lub_category = 0
    If lub_item <> 0 Then
        luw_record   = fuw_mv_item( lub_item )
        lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    End If
    If lub_category <> UB_TV_OPEN_DOOR Then
        s_core_message( UW_MSG_I_DO_NOT_SEE_ANYTHING_YOU_CAN_2 )
        Return false
    End If
    ' a monster in the doorway? the chests library has the words for that
    gub_lib_param_1 = Peek( fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_MONSTER )
    If gub_lib_param_1 <> 0 Then
        s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_BLOCKED )
        Return true
    End If
    luw_record = fuw_mv_item( lub_item )
    If Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) <> 0 Then
        ' N.B: finding this out takes the player's turn, so this is true, "something happened"
        s_core_message( UW_MSG_THE_DOOR_APPEARS_TO_BE_BROKEN )
        Return true
    End If
    s_mv_change_item( lub_item , UW_OBJ_CLOSED_DOOR )
    Poke fuw_mv_square( gub_mv_y , gub_mv_x ) + UB_SQUARE_FEATURE , UB_TILE_BLOCKED_FLOOR
    Return true
End Function


'##################################################################################################################################
' --- searching ---

Function fub_mv_search( psw_chance As Integer ) As UByte
    ' Moria's playerSearch(), with its trapChangeVisibility(), true if anything was found
    Dim y , x , lub_item , lub_category , lub_flags     As UByte
    Dim luw_record                                      As UInteger
    Dim lub_found                                       As UByte = false

    lub_flags = Peek( fuw_mv_square( gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If gsw_player_confused > 0 Then psw_chance = psw_chance / 10
    ' blind, or standing in the dark, Moria's playerNoLight()
    If gsw_player_blind > 0 Or ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then psw_chance = psw_chance / 10
    If gsw_player_image > 0 Then psw_chance = psw_chance / 10

    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            If Cast( Integer , ful_core_random_number( 100 ) ) < psw_chance Then
                lub_item = Peek( fuw_mv_square( y , x ) + UB_SQUARE_ITEM )
                If lub_item <> 0 Then
                    luw_record   = fuw_mv_item( lub_item )
                    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
                    If lub_category = UB_TV_INVIS_TRAP Then
                        ' "You have found a trap door.", the items library has the words
                        s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
                        gub_lib_param_1 = true
                        guw_lib_param_2 = 0
                        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
                        s_msg( "You have found " + fs_core_text_at( A_TEXT_BUFFER ) )
                        luw_record = fuw_mv_item( lub_item )
                        Poke luw_record + UB_ITEM_CATEGORY_OFFSET , UB_TV_VIS_TRAP
                        lub_found = true
                    ElseIf lub_category = UB_TV_SECRET_DOOR Then
                        s_core_message( UW_MSG_YOU_HAVE_FOUND_A_SECRET_DOOR )
                        ' the secret door becomes a closed one: its number, its category and what it looks like
                        s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_CLOSED_DOOR , A_OBJECT )
                        luw_record = fuw_mv_item( lub_item )
                        Poke UInteger luw_record , UW_OBJ_CLOSED_DOOR
                        Poke luw_record + UB_ITEM_CATEGORY_OFFSET , Peek( A_OBJECT + UB_ITEM_CATEGORY_OFFSET )
                        Poke luw_record + UB_ITEM_SPRITE_OFFSET , Peek( A_OBJECT + UB_ITEM_SPRITE_OFFSET )
                        lub_found = true
                    End If
                    If lub_category = UB_TV_CHEST Then
                        ' a chest is looked over for traps, the chests library
                        gub_lib_param_1 = y
                        guw_lib_param_2 = x
                        s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_SEARCH )
                    End If
                End If
            End If
        Next
    Next
    Return lub_found
End Function


'##################################################################################################################################
' --- picking things up ---

Function fub_mv_can_carry_weight() As UByte
    ' true if the working item can be picked up without slowing the player down any more, Moria's inventoryCanCarryItem()
    Dim lsl_limit , lsl_weight As Long

    ' Moria's playerCarryingLoadLimit()
    lsl_limit = Cast( Long , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) * UB_PLAYER_WEIGHT_CAP + guw_player_weight
    If lsl_limit > 3000 Then lsl_limit = 3000
    lsl_weight = Cast( Long , gub_item_count ) * guw_item_weight + gsw_player_pack_weight
    If lsl_limit < lsl_weight Then
        lsl_limit = lsl_weight / ( lsl_limit + 1 )
    Else
        lsl_limit = 0
    End If
    If lsl_limit = gsw_player_pack_heaviness Then Return true
    Return false
End Function


Function fub_mv_carry( pub_pickup As UByte ) As UByte
    ' Moria's carry(): what the player is standing on is taken up, true if it was
    Dim lub_item    As UByte
    Dim lsw_place   As Integer

    lub_item = Peek( fuw_mv_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
    If lub_item = 0 Then Return false
    s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_item , A_ITEM )
    ' N.B: traps and the stores' doors never come here, the walking stage sees to them itself
    If gub_item_category > UB_TV_MAX_PICK_UP Then Return false

    If gub_item_category = UB_TV_GOLD Then
        ' there's GOLD in them thar hills!
        gsl_player_gold = gsl_player_gold + gsl_item_cost
        s_mv_begin()
        s_mv_add( "You have found " + fs_core_number( gsl_item_cost ) + " gold pieces worth of " )
        s_mv_add_description( Code( "." ) )
        s_mv_delete_object( gub_player_row , gub_player_col )
        s_msg_text( A_MV_TEXT )
        Return true
    End If

    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CAN_CARRY )
    If gsw_lib_result = 0 Then
        s_mv_begin()
        s_mv_add( "You can't carry " )
        s_mv_add_description( Code( "." ) )
        s_msg_text( A_MV_TEXT )
        Return false
    End If

    ' the "prompt to pick up" option asks first
    If pub_pickup And ( guw_game_options bAnd MW_OPTION_PROMPT_PICKUP ) <> 0 Then
        s_mv_begin()
        s_mv_add( "Pick up " )
        s_mv_add_description( Code( "?" ) )
        pub_pickup = fub_mv_confirm()
    End If
    If pub_pickup Then
        ' will it slow the player down?
        If fub_mv_can_carry_weight() = false Then
            s_mv_begin()
            s_mv_add( "Exceed your weight limit to pick up " )
            s_mv_add_description( Code( "?" ) )
            pub_pickup = fub_mv_confirm()
        End If
    End If
    If pub_pickup = false Then Return false

    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CARRY )
    lsw_place = gsw_lib_result
    ' it is described as it now is in the pack, it may have joined others of its kind there
    s_core_ram_copy( A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE , A_ITEM , UB_RECORD_SIZE )
    s_mv_begin()
    s_mv_add( "You have " )
    s_mv_add_description( Code( "." ) )
    s_mv_add( " (" + fs_core_char( Code( "a" ) + lsw_place ) + ")" )
    s_msg_text( A_MV_TEXT )
    s_mv_delete_object( gub_player_row , gub_player_col )
    ' the pack is heavier, Moria does this at the start of the next turn
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
    Return true
End Function


Sub s_lib_moves()
    Dim lub_changed As UByte = false

    gub_mv_saved_page = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_MOVES_OPEN Then
        lub_changed = fub_mv_open()
    ElseIf gub_lib_function = UB_LIB_MOVES_CLOSE Then
        lub_changed = fub_mv_close()
    ElseIf gub_lib_function = UB_LIB_MOVES_SEARCH Then
        lub_changed = fub_mv_search( Cast( Integer , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_MOVES_CARRY Then
        lub_changed = fub_mv_carry( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_MOVES_DELETE_OBJECT Then
        s_mv_delete_object( gub_lib_param_1 , guw_lib_param_2 )
        lub_changed = true
    End If
    If gub_mv_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , gub_mv_saved_page )
    gsw_lib_result = lub_changed
End Sub
