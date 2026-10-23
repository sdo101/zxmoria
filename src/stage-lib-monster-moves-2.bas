#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monster_moves_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-disturb-include.bas"
#include "stage-monster-moves-include.bas"

' this page is a LIBRARY, not a stage: the parts of a monster's move that the monster moves library,
' stage-lib-monster-moves.bas, has no room for, from Moria's monster.cpp, they work on the monster having its
' turn, A_MONSTER, and its creature, A_CREATURE...
' ...that library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES_2 , <which routine> ),
' the routines are:
'
'   UB_LIB_MONSTER_MOVES_2_DOOR         the monster has come to a door, at row gub_lib_param_1 and the column in
'                                       the low byte of guw_lib_param_2, the door's item number is in the high
'                                       byte, Moria's monsterOpenDoor()
'   UB_LIB_MONSTER_MOVES_2_WALL         the monster is inside rock that it cannot pass through: the ways out are
'                                       put in the list of directions to try, a random one first, gsw_lib_result
'                                       is how many there are, the first half of Moria's monsterMoveOutOfWall()
'   UB_LIB_MONSTER_MOVES_2_WALL_AFTER   the second half, after the move: if it is still in rock it digs itself
'                                       out, and is hurt, perhaps killed, by it
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it

Sub s_mm_open_door( pub_y As UByte , pub_x As UByte , pub_item As UByte )
    ' Moria's monsterOpenDoor(): a creature that can open doors opens one that is merely shut, may pick a lock, and
    ' may force a stuck door, a secret door is no secret to it, any other creature can only try to break a door down
    Dim luw_record                  As UInteger
    Dim lub_category , i            As UByte
    Dim lsw_misc_use , lsw_abs      As Integer
    Dim lsl_hp                      As Long
    Dim lub_stuck                   As UByte = false
    Dim lub_open                    As UByte = false

    luw_record   = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item )
    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    lsw_misc_use = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
    lsl_hp       = gsw_monster_hp

    If ( gul_creature_movement bAnd UL_CM_OPEN_DOOR ) <> 0 Then
        ' the creature can open doors
        If lub_category = UB_TV_CLOSED_DOOR Then
            gub_mm_do_turn = true
            If lsw_misc_use = 0 Then
                ' closed doors
                gub_mm_do_move = true
            ElseIf lsw_misc_use > 0 Then
                ' locked doors
                If Cast( Long , ful_core_random_number( ( lsl_hp + 1 ) * ( 50 + lsw_misc_use ) ) ) < 40 * ( lsl_hp - 10 - lsw_misc_use ) Then
                    Poke UInteger luw_record + UB_ITEM_MISC_USE_OFFSET , 0
                End If
            Else
                ' stuck doors
                If Cast( Long , ful_core_random_number( ( lsl_hp + 1 ) * ( 50 - lsw_misc_use ) ) ) < 40 * ( lsl_hp - 10 + lsw_misc_use ) Then
                    s_core_message( UW_MSG_YOU_HEAR_A_DOOR_BURST_OPEN )
                    s_mon_disturb()
                    lub_stuck      = true
                    gub_mm_do_move = true
                End If
            End If
        ElseIf lub_category = UB_TV_SECRET_DOOR Then
            gub_mm_do_turn = true
            gub_mm_do_move = true
        End If
        If gub_mm_do_move Then
            lub_open = true
            gub_mm_seen_high = gub_mm_seen_high bOr $02     ' UL_CM_OPEN_DOOR
            ' the monster has only opened the door, it goes through on its next move
            gub_mm_do_move = false
        End If
    ElseIf lub_category = UB_TV_CLOSED_DOOR Then
        ' the creature cannot open doors, it must bash them
        gub_mm_do_turn = true
        lsw_abs = lsw_misc_use
        If lsw_abs < 0 Then lsw_abs = -lsw_abs
        If Cast( Long , ful_core_random_number( ( lsl_hp + 1 ) * ( 80 + lsw_abs ) ) ) < 40 * ( lsl_hp - 20 - lsw_abs ) Then
            lub_open  = true
            lub_stuck = true
            s_core_message( UW_MSG_YOU_HEAR_A_DOOR_BURST_OPEN )
            s_mon_disturb()
        End If
    End If

    If lub_open Then
        ' the door becomes an open one, Moria's inventoryItemCopyTo(), a door that was forced may be left broken
        s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_OPEN_DOOR , A_OBJECT )
        For i = 0 To 31
            Poke A_ITEM + i , 0
        Next
        s_core_ram_copy( A_OBJECT + UB_ITEM_OBJECT_FIELDS , A_ITEM + UB_ITEM_OBJECT_FIELDS , UB_RECORD_SIZE - UB_ITEM_OBJECT_FIELDS )
        guw_item_object = UW_OBJ_OPEN_DOOR
        If lub_stuck Then gsw_item_misc_use = 1 - Cast( Integer , fuw_mm_random( 2 ) )
        s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , pub_item , A_ITEM )
        Poke fuw_cr_square( pub_y , pub_x ) + UB_SQUARE_FEATURE , UB_TILE_CORR_FLOOR
        ' a wall gone, the mini map is made again before it is next drawn, ours
        gub_minimap_rebuild = true
        s_cr_put( pub_y , pub_x )
    End If
End Sub

Function fub_m2_wall_directions() As UByte
    ' the first half of Moria's monsterMoveOutOfWall(): every open square beside the monster that is not the
    ' player's, the direction of the for loops matches the directions of a keypad from 1 to 9
    Dim lsw_y , lsw_x               As Integer
    Dim lub_count , lub_direction   As UByte
    Dim lub_pick , lub_first        As UByte
    Dim luw_square                  As UInteger

    lub_count     = 0
    lub_direction = 1
    For lsw_y = Cast( Integer , gub_monster_row ) + 1 To Cast( Integer , gub_monster_row ) - 1 Step -1
        For lsw_x = Cast( Integer , gub_monster_col ) - 1 To Cast( Integer , gub_monster_col ) + 1
            ' do not allow attack on the player, must skip the center position
            If lub_direction <> 5 And lsw_y >= 0 And lsw_x >= 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) And lsw_x < Cast( Integer , gub_dungeon_cols ) Then
                luw_square = fuw_cr_square( lsw_y , lsw_x )
                If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_MONSTER ) <> 1 Then
                    Poke A_MM_DIRECTIONS + lub_count , lub_direction
                    lub_count = lub_count + 1
                End If
            End If
            lub_direction = lub_direction + 1
        Next
    Next
    If lub_count <> 0 Then
        ' put a random direction first
        lub_pick  = fuw_mm_random( lub_count ) - 1
        lub_first = Peek( A_MM_DIRECTIONS )
        Poke A_MM_DIRECTIONS , Peek( A_MM_DIRECTIONS + lub_pick )
        Poke A_MM_DIRECTIONS + lub_pick , lub_first
        ' N.B: the monster moves library tries five directions, the ones past the end of this list are the
        ' square the monster is on, which uses up no turn
        While lub_count < 5
            Poke A_MM_DIRECTIONS + lub_count , 5
            lub_count = lub_count + 1
        End While
    End If
    Return lub_count
End Function


Sub s_m2_wall_after()
    ' the second half of Moria's monsterMoveOutOfWall(): if still in a wall, let it dig itself out, but also
    ' apply some more damage
    Dim lub_monster As UByte

    If Peek( fuw_cr_square( gub_monster_row , gub_monster_col ) + UB_SQUARE_FEATURE ) < UB_TILE_MIN_WALL Then Return
    lub_monster = gub_mm_monster
    ' the player attack library does the hurting, on the monster as it is in the level's list, so the working
    ' copy is put there first, and taken out again afterwards
    s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
    gub_lib_param_1 = lub_monster
    guw_lib_param_2 = fuw_core_dice_roll( 8 , 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_TAKE_HIT )
    If gsw_lib_result Then
        s_core_message( UW_MSG_YOU_HEAR_A_SCREAM_MUFFLED_BY_ROCK )
        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
        ' it is dead, and is struck from the list when its turn ends
        gsw_monster_hp = -1
    Else
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        s_core_message( UW_MSG_A_CREATURE_DIGS_ITSELF_OUT_FROM )
        ' Moria's playerTunnelWall( 1 , 0 ), the traps library has it
        gub_lib_param_1 = gub_monster_row
        guw_lib_param_2 = gub_monster_col
        s_core_call_library( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_DIG_WALL )
    End If
End Sub


Sub s_lib_monster_moves_2()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_y , lub_x , lub_item                                As UByte
    Dim lub_answer                                              As UByte = 0

    lub_y    = gub_lib_param_1
    lub_x    = guw_lib_param_2 bAnd 255
    lub_item = guw_lib_param_2 >> 8
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_MONSTER_MOVES_2_DOOR Then
        s_mm_open_door( lub_y , lub_x , lub_item )
    ElseIf gub_lib_function = UB_LIB_MONSTER_MOVES_2_WALL Then
        lub_answer = fub_m2_wall_directions()
    ElseIf gub_lib_function = UB_LIB_MONSTER_MOVES_2_WALL_AFTER Then
        s_m2_wall_after()
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_answer
End Sub
