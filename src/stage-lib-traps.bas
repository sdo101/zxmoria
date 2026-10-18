#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_traps()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: traps, and digging, from Moria's player_move.cpp, player_traps.cpp and
' player_tunnel.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_TRAPS , <which routine> ),
' the routines are:
'
'   UB_LIB_TRAPS_STEP       the player has stepped on a trap, it is the one under them, Moria's playerStepsOnTrap()
'   UB_LIB_TRAPS_DISARM     asks which direction and tries to disarm the trap there, Moria's playerDisarmTrap(),
'                           what the walking stage must then do comes back in gsw_lib_result: 0 for nothing,
'                           otherwise the direction to step in in its low byte and in its high byte 1 if the trap
'                           was disarmed, 2 if it was set off, the player walks on to the square either way
'   UB_LIB_TRAPS_TUNNEL     asks which direction and digs there, through rubble or rock, Moria's playerTunnel()
'
'   UB_LIB_TRAPS_DIG_WALL   the wall at row gub_lib_param_1 and column guw_lib_param_2 is dug out, for a spell,
'                           Moria's playerTunnelWall()
'
' each sets gub_game_free_turn if it took no time, and asks the walking stage for anything more through
' gub_game_turn_flags, the MB_TURN_ bits in constants.bas, the walking stage draws the squares round the player again
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, a chest's traps are the chests library's, stage-lib-chests.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
Dim gub_tr_y                As UByte    At A_LIB_PRIVATE            ' the square a direction leads to
Dim gub_tr_x                As UByte    At A_LIB_PRIVATE + 1


Function fuw_tr_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_tr_square( pub_y As UByte , pub_x As UByte ) As UInteger
    Return fuw_core_map_square( gub_level_map_page , pub_y , pub_x )
End Function


Function fuw_tr_item( pub_item As UByte ) As UInteger
    ' where the record of one of the level's items is
    Return fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item )
End Function


Function fub_tr_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_tr_delete_object( pub_y As UByte , pub_x As UByte )
    ' Moria's dungeonDeleteObject(), the moves library keeps the level's list of items
    gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT , pub_y , pub_x )
End Sub


Sub s_tr_change_item( pub_item As UByte , puw_object As UInteger )
    ' one of the level's items becomes a brand new one of another kind, Moria's inventoryItemCopyTo()
    Dim i As UByte

    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , puw_object , A_OBJECT )
    For i = 0 To 31
        Poke A_ITEM + i , 0
    Next
    s_core_ram_copy( A_OBJECT + 32 , A_ITEM + 32 , 32 )
    guw_item_object = puw_object
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , pub_item , A_ITEM )
End Sub


Function fub_tr_direction() As UByte
    ' asks which way, Moria's getDirectionWithMemory(), 0 if the player thought better of it, the square that way
    ' from the player is left in gub_tr_y and gub_tr_x
    Dim lub_direction As UByte = 0
    Dim luw_count     As UInteger

    ' a command that is being repeated uses the direction it had the first time, without asking, and asking
    ' does not end a count that has just been given, Moria's use_last_direction
    luw_count = guw_game_command_count
    If gub_game_repeat_key >= 128 Then
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
        Loop Until lub_direction <> 0 Or gub_key_char = 27 Or guw_key_code = 0
        s_msg_clear()
    End If
    guw_game_command_count = luw_count
    If lub_direction <> 0 Then gub_player_prev_dir = lub_direction
    ' backing out takes no time, Moria's getDirectionWithMemory() sets player_free_turn itself
    If lub_direction = 0 Then gub_game_free_turn = true
    Return lub_direction
End Function


Sub s_tr_target( pub_direction As UByte )
    ' Moria's playerMovePosition(), the player is never on the edge of the map, so the square is always on it
    gub_tr_y = gub_player_row + 1 - ( pub_direction - 1 ) / 3       ' 1 2 3 go down, 7 8 9 go up
    gub_tr_x = gub_player_col + ( pub_direction - 1 ) Mod 3 - 1     ' 1 4 7 go left, 3 6 9 go right
End Sub


'##################################################################################################################################
' --- stepping on a trap ---

Sub s_tr_killer( pub_item As UByte )
    ' says that the trap is what is about to hurt the player, by its description: "an arrow trap"
    Dim i As UByte

    s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , pub_item , A_ITEM )
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    i = 0
    While Peek( A_TEXT_BUFFER + i ) <> 0 And i < 38
        Poke A_KILLER + i , Peek( A_TEXT_BUFFER + i )
        i = i + 1
    End While
    Poke A_KILLER + i , 0
End Sub


Function fub_tr_being_hit() As UByte
    ' Moria's playerTestBeingHit( 125 , 0 , 0 , the player's armour ), for arrows and darts: a 20 sided die,
    ' 1 always misses and 20 always hits, otherwise 125 against the player's armour
    Dim luw_die As UInteger

    ' as every test of being hit in Moria, it disturbs the player first, whether or not it hits
    s_dst_disturb( true , false )
    luw_die = fuw_tr_random( 20 )
    If luw_die = 1 Then Return false
    If luw_die = 20 Then Return true
    If Cast( Integer , fuw_tr_random( 125 ) ) > gsw_player_ac + gsw_player_magical_ac Then Return true
    Return false
End Function


Sub s_tr_step()
    ' Moria's playerStepsOnTrap(), and the trap routines it calls
    Dim lub_item , lub_kind , i     As UByte
    Dim luw_record                  As UInteger
    Dim lsw_damage                  As Integer
    Dim luw_count                   As UInteger

    lub_item = Peek( fuw_tr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
    If lub_item = 0 Then Return
    luw_record = fuw_tr_item( lub_item )
    ' Moria's trapChangeVisibility(), the trap is no longer hidden
    If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_INVIS_TRAP Then Poke luw_record + UB_ITEM_CATEGORY_OFFSET , UB_TV_VIS_TRAP
    lub_kind   = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET )
    lsw_damage = fuw_core_dice_roll( Peek( luw_record + UB_ITEM_DAMAGE_OFFSET ) , Peek( luw_record + UB_ITEM_DAMAGE_OFFSET + 1 ) )
    s_tr_killer( lub_item )

    If lub_kind = 1 Then
        ' open pit
        s_core_message( UW_MSG_YOU_FELL_INTO_A_PIT )
        If gub_player_free_fall Then
            s_core_message( UW_MSG_YOU_GENTLY_FLOAT_DOWN )
        Else
            s_hit_player( lsw_damage )
        End If
    ElseIf lub_kind = 2 Then
        ' arrow trap
        If fub_tr_being_hit() Then
            s_hit_player( lsw_damage )
            s_core_message( UW_MSG_AN_ARROW_HITS_YOU )
        Else
            s_core_message( UW_MSG_AN_ARROW_BARELY_MISSES_YOU )
        End If
    ElseIf lub_kind = 3 Then
        ' covered pit, it is an open pit from now on
        s_core_message( UW_MSG_YOU_FELL_INTO_A_COVERED_PIT )
        If gub_player_free_fall Then
            s_core_message( UW_MSG_YOU_GENTLY_FLOAT_DOWN )
        Else
            s_hit_player( lsw_damage )
        End If
        s_tr_change_item( lub_item , UW_OBJ_TRAP_LIST )
    ElseIf lub_kind = 4 Then
        ' trap door
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_NEW_LEVEL
        guw_dungeon_level   = guw_dungeon_level + 1
        s_core_message( UW_MSG_YOU_FELL_THROUGH_A_TRAP_DOOR )
        If gub_player_free_fall Then
            s_core_message( UW_MSG_YOU_GENTLY_FLOAT_DOWN )
        Else
            s_hit_player( lsw_damage )
        End If
        s_msg_flush()
    ElseIf lub_kind = 5 Then
        ' sleeping gas
        If gsw_player_paralysis = 0 Then
            s_core_message( UW_MSG_A_STRANGE_WHITE_MIST_SURROUNDS_YOU )
            If gub_player_free_action Then
                s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
            Else
                gsw_player_paralysis = gsw_player_paralysis + fuw_tr_random( 10 ) + 4
                s_core_message( UW_MSG_YOU_FALL_ASLEEP )
            End If
        End If
    ElseIf lub_kind = 6 Then
        ' a loose rock, with something under it
        s_tr_delete_object( gub_player_row , gub_player_col )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT , gub_player_row , gub_player_col )
        s_core_message( UW_MSG_HMMM_THERE_WAS_SOMETHING_UNDER )
    ElseIf lub_kind = 7 Then
        ' dart of strength loss
        If fub_tr_being_hit() Then
            If gub_player_sustain_str = false Then
                gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_DECREASE , UB_STAT_STR , 0 )
                s_hit_player( lsw_damage )
                s_core_message( UW_MSG_A_SMALL_DART_WEAKENS_YOU )
            Else
                s_core_message( UW_MSG_A_SMALL_DART_HITS_YOU )
            End If
        Else
            s_core_message( UW_MSG_A_SMALL_DART_BARELY_MISSES_YOU )
        End If
    ElseIf lub_kind = 8 Then
        ' teleport, Moria does it at the end of the turn, playerTeleport( 100 )
        s_core_message( UW_MSG_YOU_HIT_A_TELEPORT_TRAP )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT , 0 , 100 )
    ElseIf lub_kind = 9 Then
        ' rockfall, the trap is gone and rubble lies where it was, the walking stage steps the player back off it
        s_hit_killer( "a falling rock" )
        s_hit_player( lsw_damage )
        s_tr_delete_object( gub_player_row , gub_player_col )
        ' Moria's dungeonPlaceRubble(), a new item for the level, Moria's popt(), N.B: there is always room for
        ' it, the trap has just gone from the list
        If gub_dungeon_item_next < UB_DUN_MAX_ITEMS Then
            lub_item = gub_dungeon_item_next
            gub_dungeon_item_next = gub_dungeon_item_next + 1
            s_tr_change_item( lub_item , UW_OBJ_RUBBLE )
            luw_record = fuw_tr_square( gub_player_row , gub_player_col )
            Poke luw_record + UB_SQUARE_ITEM , lub_item
            Poke luw_record + UB_SQUARE_FEATURE , UB_TILE_BLOCKED_FLOOR
        End If
        s_core_message( UW_MSG_YOU_ARE_HIT_BY_FALLING_ROCK )
    ElseIf lub_kind = 10 Then
        ' corrosion gas
        s_core_message( UW_MSG_A_STRANGE_RED_GAS_SURROUNDS_YOU )
        s_hit_killer( "corrosion gas" )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_DAMAGE , 9 , 0 )
    ElseIf lub_kind = 11 Then
        ' summon monster, the rune is used up
        s_tr_delete_object( gub_player_row , gub_player_col )
        luw_count = 2 + fuw_tr_random( 3 )
        For i = 1 To luw_count
            gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON , 0 , 0 )
        Next
    ElseIf lub_kind = 12 Then
        ' fire
        s_core_message( UW_MSG_YOU_ARE_ENVELOPED_IN_FLAMES )
        s_hit_killer( "a fire trap" )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_DAMAGE , 5 , lsw_damage )
    ElseIf lub_kind = 13 Then
        ' acid
        s_core_message( UW_MSG_YOU_ARE_SPLASHED_WITH_ACID )
        s_hit_killer( "an acid trap" )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_DAMAGE , 6 , lsw_damage )
    ElseIf lub_kind = 14 Then
        ' poison gas, Moria's damagePoisonedGas()
        s_core_message( UW_MSG_A_PUNGENT_GREEN_GAS_SURROUNDS_YOU )
        s_hit_killer( "a poison gas trap" )
        s_hit_player( lsw_damage )
        gsw_player_poisoned = gsw_player_poisoned + 12 + fuw_tr_random( lsw_damage )
    ElseIf lub_kind = 15 Then
        ' blinding gas
        s_core_message( UW_MSG_A_BLACK_GAS_SURROUNDS_YOU )
        gsw_player_blind = gsw_player_blind + fuw_tr_random( 50 ) + 50
    ElseIf lub_kind = 16 Then
        ' confusion gas
        s_core_message( UW_MSG_A_GAS_OF_SCINTILLATING_COLORS )
        gsw_player_confused = gsw_player_confused + fuw_tr_random( 15 ) + 15
    ElseIf lub_kind = 17 Then
        ' slow dart
        If fub_tr_being_hit() Then
            s_hit_player( lsw_damage )
            s_core_message( UW_MSG_A_SMALL_DART_HITS_YOU_2 )
            If gub_player_free_action Then
                s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
            Else
                gsw_player_slow = gsw_player_slow + fuw_tr_random( 20 ) + 10
            End If
        Else
            s_core_message( UW_MSG_A_SMALL_DART_BARELY_MISSES_YOU )
        End If
    ElseIf lub_kind = 18 Then
        ' dart of constitution loss
        If fub_tr_being_hit() Then
            If gub_player_sustain_con = false Then
                gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_DECREASE , UB_STAT_CON , 0 )
                s_hit_player( lsw_damage )
                s_core_message( UW_MSG_A_SMALL_DART_SAPS_YOUR_HEALTH )
            Else
                s_core_message( UW_MSG_A_SMALL_DART_HITS_YOU )
            End If
        Else
            s_core_message( UW_MSG_A_SMALL_DART_BARELY_MISSES_YOU )
        End If
    ElseIf lub_kind <> 19 And lub_kind <> 99 Then
        ' 19 is a secret door and 99 the rune of protection, neither does anything to the player
        s_core_message( UW_MSG_UNKNOWN_TRAP_VALUE )
    End If
End Sub


'##################################################################################################################################
' --- disarming ---

Function fuw_tr_disarm() As UInteger
    ' Moria's playerDisarmTrap() and playerDisarmFloorTrap(), what comes back is for the walking stage, see the
    ' top of this file
    Dim lub_direction , lub_item , lub_category     As UByte
    Dim luw_record                                  As UInteger
    Dim lsw_ability , lsw_level , lsw_misc_use      As Integer
    Dim lub_flags                                   As UByte

    lub_direction = fub_tr_direction()
    If lub_direction = 0 Then
        gub_game_free_turn = true
        Return 0
    End If
    s_tr_target( lub_direction )
    lub_item = Peek( fuw_tr_square( gub_tr_y , gub_tr_x ) + UB_SQUARE_ITEM )
    lub_category = 0
    If lub_item <> 0 Then
        luw_record   = fuw_tr_item( lub_item )
        lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lsw_level    = Peek( luw_record + UB_ITEM_DEPTH_OFFSET )
        lsw_misc_use = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
    End If
    If lub_category <> UB_TV_VIS_TRAP And lub_category <> UB_TV_CHEST Then
        s_core_message( UW_MSG_I_DO_NOT_SEE_ANYTHING_TO_DISARM )
        gub_game_free_turn = true
        Return 0
    End If
    ' a monster in the way? the chests library says so
    gub_lib_param_1 = Peek( fuw_tr_square( gub_tr_y , gub_tr_x ) + UB_SQUARE_MONSTER )
    If gub_lib_param_1 > 1 Then
        s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_BLOCKED )
        Return 0
    End If

    ' Moria's playerTrapDisarmAbility()
    lsw_ability = gsw_player_disarm + 2
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DISARM )
    lsw_ability = lsw_ability * gsw_lib_result
    gub_lib_param_1 = UB_STAT_INT
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_ability = lsw_ability + gsw_lib_result
    lsw_ability = lsw_ability + Cast( Integer , gub_class_adj_disarm ) * Cast( Integer , guw_player_level ) / 3
    lub_flags = Peek( fuw_tr_square( gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If gsw_player_blind > 0 Or ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then lsw_ability = lsw_ability / 10
    If gsw_player_confused > 0 Then lsw_ability = lsw_ability / 10
    If gsw_player_image > 0 Then lsw_ability = lsw_ability / 10

    If lub_category = UB_TV_CHEST Then
        ' a chest's traps are the chests library's
        gub_lib_param_1 = gub_tr_y
        guw_lib_param_2 = gub_tr_x
        gsw_lib_result  = lsw_ability
        s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_DISARM )
        Return 0
    End If

    If lsw_ability + 100 - lsw_level > Cast( Integer , fuw_tr_random( 100 ) ) Then
        s_core_message( UW_MSG_YOU_HAVE_DISARMED_THE_TRAP )
        gsl_player_exp = gsl_player_exp + lsw_misc_use
        s_tr_delete_object( gub_tr_y , gub_tr_x )
        ' the player steps on to the square, the walking stage does it, and shows the experience
        Return $0100 bOr lub_direction
    End If
    ' avoid random number call if ability is 5 or less
    If lsw_ability > 5 Then
        If Cast( Integer , fuw_tr_random( lsw_ability ) ) > 5 Then
            s_msg_quiet( "You failed to disarm the trap." )
            Return 0
        End If
    End If
    s_core_message( UW_MSG_YOU_SET_THE_TRAP_OFF )
    Return $0200 bOr lub_direction
End Function


'##################################################################################################################################
' --- digging ---

Function fub_tr_tunnel_wall( psw_ability As Integer , psw_chance As Integer ) As UByte
    ' Moria's playerTunnelWall(): if the player digs well enough the wall is gone, a wall of a lit room becomes
    ' part of the room's floor, anything else becomes corridor
    Dim luw_square , luw_other  As UInteger
    Dim y , x , lub_feature     As UByte
    Dim lub_flags , lub_light   As UByte
    Dim lub_found , lub_done    As UByte

    If psw_ability <= psw_chance Then Return false

    luw_square  = fuw_tr_square( gub_tr_y , gub_tr_x )
    lub_flags   = Peek( luw_square + UB_SQUARE_FLAGS )
    lub_feature = UB_TILE_CORR_FLOOR
    lub_light   = 0
    If ( lub_flags bAnd MB_SQUARE_LIT_ROOM ) <> 0 Then
        ' should become a room space, check to see whether it should be lit or dark floor
        ' N.B: as in Moria each row is searched until a floor is found, and the last row that has one decides
        For y = gub_tr_y - 1 To gub_tr_y + 1
            lub_done = false
            x = gub_tr_x - 1
            While x <= gub_tr_x + 1 And lub_done = false
                luw_other = fuw_tr_square( y , x )
                If Peek( luw_other + UB_SQUARE_FEATURE ) <= UB_TILE_LIGHT_FLOOR Then
                    lub_feature = Peek( luw_other + UB_SQUARE_FEATURE )
                    lub_light   = Peek( luw_other + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_PERM_LIGHT
                    lub_done    = true
                End If
                x = x + 1
            End While
        Next
    End If
    luw_square = fuw_tr_square( gub_tr_y , gub_tr_x )
    lub_flags  = ( lub_flags bAnd ( 255 - ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) ) bOr lub_light
    Poke luw_square + UB_SQUARE_FEATURE , lub_feature
    Poke luw_square + UB_SQUARE_FLAGS , lub_flags
    ' a wall tunnelled through, the mini map is made again before it is next drawn, ours
    gub_minimap_rebuild = true
    If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) <> 0 And Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then s_core_message( UW_MSG_YOU_HAVE_FOUND_SOMETHING )
    Return true
End Function


Sub s_tr_dig_wall( psw_ability As Integer , puw_range As UInteger , psw_base As Integer , ps_into As String )
    ' Moria's dungeonDigGraniteWall(), dungeonDigMagmaWall() and dungeonDigQuartzWall()
    If fub_tr_tunnel_wall( psw_ability , Cast( Integer , fuw_tr_random( puw_range ) ) + psw_base ) Then
        s_core_message( UW_MSG_YOU_HAVE_FINISHED_THE_TUNNEL )
    Else
        s_msg_quiet( ps_into )
    End If
End Sub


Sub s_tr_tunnel()
    ' Moria's playerTunnel()
    Dim lub_direction , lub_feature , lub_item  As UByte
    Dim lub_category , lub_monster              As UByte
    Dim luw_square , luw_weapon                 As UInteger
    Dim lsw_ability , lsw_strength              As Integer

    lub_direction = fub_tr_direction()
    If lub_direction = 0 Then
        gub_game_free_turn = true
        Return
    End If
    ' confused?  75% random movement
    If gsw_player_confused > 0 Then
        If fuw_tr_random( 4 ) > 1 Then lub_direction = fuw_tr_random( 9 )
    End If
    s_tr_target( lub_direction )

    luw_square  = fuw_tr_square( gub_tr_y , gub_tr_x )
    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
    lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
    lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
    lub_category = 0
    If lub_item <> 0 Then lub_category = Peek( fuw_tr_item( lub_item ) + UB_ITEM_CATEGORY_OFFSET )

    ' Moria's playerCanTunnel()
    If lub_feature < UB_TILE_MIN_WALL And lub_category <> UB_TV_RUBBLE And lub_category <> UB_TV_SECRET_DOOR Then
        gub_game_free_turn = true
        If lub_item = 0 Then
            s_core_message( UW_MSG_TUNNEL_THROUGH_WHAT_EMPTY_AIR )
        Else
            s_core_message( UW_MSG_YOU_CANT_TUNNEL_THROUGH_THAT )
        End If
        Return
    End If

    If lub_monster > 1 Then
        ' Moria's objectBlockedByMonster(), and then the player attacks it
        luw_square = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
        If Peek( luw_square + UB_MONSTER_LIT_OFFSET ) Then
            s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_square + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
            s_msg( "The " + fs_core_text_at( A_CREATURE ) + " is in your way!" )
        Else
            s_core_message( UW_MSG_SOMETHING_IS_IN_YOUR_WAY )
        End If
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_MONSTER , gub_tr_y , gub_tr_x )
        Return
    End If

    luw_weapon = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_WIELD ) * UB_RECORD_SIZE
    If Peek( luw_weapon + UB_ITEM_CATEGORY_OFFSET ) = 0 Then
        s_core_message( UW_MSG_YOU_DIG_WITH_YOUR_HANDS_MAKING_NO )
        Return
    End If

    ' Moria's playerDiggingAbility(): a digging tool is far better than a weapon
    lsw_strength = Peek( A_PLAYER_STATS_USED + UB_STAT_STR )
    lsw_ability  = lsw_strength
    If ( Peek( ULong , luw_weapon + UB_ITEM_FLAGS_OFFSET ) bAnd UL_TR_TUNNEL ) <> 0 Then
        lsw_ability = lsw_ability + 25 + Peek( Integer , luw_weapon + UB_ITEM_MISC_USE_OFFSET ) * 50
    Else
        lsw_ability = lsw_ability + Cast( Integer , Peek( luw_weapon + UB_ITEM_DAMAGE_OFFSET ) ) * Cast( Integer , Peek( luw_weapon + UB_ITEM_DAMAGE_OFFSET + 1 ) ) + Peek( Integer , luw_weapon + UB_ITEM_TO_HIT_OFFSET ) + Peek( Integer , luw_weapon + UB_ITEM_TO_DAMAGE_OFFSET )
        ' divide by two so that digging without shovel isn't too easy
        lsw_ability = lsw_ability >> 1
    End If
    ' if this weapon is too heavy for the player to wield properly, then also make it harder to dig with it
    If gub_player_weapon_heavy Then
        lsw_ability = lsw_ability + lsw_strength * 15 - Peek( Integer , luw_weapon + UB_ITEM_WEIGHT_OFFSET )
        If lsw_ability < 0 Then lsw_ability = 0
    End If

    ' Moria's dungeonDigAtLocation()
    If lub_feature = UB_TILE_GRANITE_WALL Then
        s_tr_dig_wall( lsw_ability , 1200 , 80 , "You tunnel into the granite wall." )
    ElseIf lub_feature = UB_TILE_MAGMA_WALL Then
        s_tr_dig_wall( lsw_ability , 600 , 10 , "You tunnel into the magma intrusion." )
    ElseIf lub_feature = UB_TILE_QUARTZ_WALL Then
        s_tr_dig_wall( lsw_ability , 400 , 10 , "You tunnel into the quartz vein." )
    ElseIf lub_feature = UB_TILE_BOUNDARY_WALL Then
        s_core_message( UW_MSG_THIS_SEEMS_TO_BE_PERMANENT_ROCK )
    ElseIf lub_category = UB_TV_RUBBLE Then
        ' Moria's dungeonDigRubble(), rubble is always easier to dig through than rock
        If lsw_ability > Cast( Integer , fuw_tr_random( 180 ) ) Then
            s_tr_delete_object( gub_tr_y , gub_tr_x )
            s_core_message( UW_MSG_YOU_HAVE_REMOVED_THE_RUBBLE )
            If fuw_tr_random( 10 ) = 1 Then
                gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT , gub_tr_y , gub_tr_x )
                If ( Peek( fuw_tr_square( gub_tr_y , gub_tr_x ) + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then s_core_message( UW_MSG_YOU_HAVE_FOUND_SOMETHING )
            End If
        Else
            s_msg_quiet( "You dig in the rubble." )
        End If
    ElseIf lub_category = UB_TV_SECRET_DOOR Then
        ' found it by digging at it
        s_msg_quiet( "You tunnel into the granite wall." )
        gub_shared_1 = fub_tr_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_SEARCH , 0 , Cast( UInteger , gsw_player_search ) )
    End If
End Sub


Sub s_lib_traps()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim luw_result                                              As UInteger = 0

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_TRAPS_STEP Then
        s_tr_step()
    ElseIf gub_lib_function = UB_LIB_TRAPS_DISARM Then
        luw_result = fuw_tr_disarm()
    ElseIf gub_lib_function = UB_LIB_TRAPS_TUNNEL Then
        s_tr_tunnel()
    ElseIf gub_lib_function = UB_LIB_TRAPS_DIG_WALL Then
        ' Moria's playerTunnelWall( 1 , 0 ), which never fails
        gub_tr_y = gub_lib_param_1
        gub_tr_x = guw_lib_param_2
        gub_shared_1 = fub_tr_tunnel_wall( 1 , 0 )
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = luw_result
End Sub
