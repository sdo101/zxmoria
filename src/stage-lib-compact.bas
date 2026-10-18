#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_compact()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-monster-include.bas"

' this page is a LIBRARY, not a stage: making room when one of a level's two lists is full, a level holds no more
' than UB_DUN_MAX_ITEMS things and UB_MON_TOTAL_ALLOCATIONS monsters, and when another is wanted and there is no
' room Moria throws away some of the ones furthest from the player, from its game_objects.cpp and
' monster_manager.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , <which routine> ), the
' routines are:
'
'   UB_LIB_COMPACT_OBJECTS      things lying far from the player are taken off the level, at random, traps and
'                               doors less readily than treasure, stairs and shop doors never, Moria's
'                               compactObjects(), the walking stage is asked to draw the map again
'   UB_LIB_COMPACT_MONSTERS     monsters far from the player are taken off the level, one in three of them,
'                               never the one whose death wins the game, Moria's compactMonsters(),
'                               gsw_lib_result is true if that made any room
'
' N.B: Moria does this in the middle of making a monster, or a thing, whatever else is going on, so everything
' this page disturbs is put back as it was: the working monster, creature and object, and the data pages
' N.B: the random numbers are asked for exactly as Moria asks for them


Sub s_cp_objects()
    ' Moria's compactObjects()
    Dim lsw_counter , lsw_distance  As Integer
    Dim luw_at                      As UInteger
    Dim y , x , lub_item            As UByte
    Dim lub_category , lub_chance   As UByte

    s_core_message( UW_MSG_COMPACTING_OBJECTS )
    lsw_counter  = 0
    lsw_distance = 66
    ' N.B: Moria would go round for ever on a level with nothing that can go, we stop when everything has been asked
    While lsw_counter <= 0 And lsw_distance >= -6
        For y = 0 To gub_dungeon_rows - 1
            For x = 0 To gub_dungeon_cols - 1
                luw_at   = fuw_core_map_square( gub_level_map_page , y , x )
                lub_item = Peek( luw_at + UB_SQUARE_ITEM )
                If lub_item <> 0 Then
                    If Cast( Integer , fub_mon_distance( y , x , gub_player_row , gub_player_col ) ) > lsw_distance Then
                        lub_category = Peek( fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item ) + UB_ITEM_CATEGORY_OFFSET )
                        lub_chance = 10
                        If lub_category = UB_TV_VIS_TRAP Then lub_chance = 15
                        If lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_RUBBLE Or lub_category = UB_TV_OPEN_DOOR Or lub_category = UB_TV_CLOSED_DOOR Then lub_chance = 5
                        ' stairs, don't delete them, shop doors, don't delete them
                        If lub_category = UB_TV_UP_STAIR Or lub_category = UB_TV_DOWN_STAIR Or lub_category = UB_TV_STORE_DOOR Then lub_chance = 0
                        If lub_category = UB_TV_SECRET_DOOR Then lub_chance = 3
                        If ful_core_random_number( 100 ) <= lub_chance Then
                            ' Moria's dungeonDeleteObject(), the moves library does it
                            gub_lib_param_1 = y
                            guw_lib_param_2 = x
                            s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT )
                            lsw_counter = lsw_counter + 1
                        End If
                    End If
                End If
            Next
        Next
        If lsw_counter = 0 Then lsw_distance = lsw_distance - 6
    End While
    If lsw_distance < 66 Then gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
End Sub


Function fub_cp_monsters() As UByte
    ' Moria's compactMonsters(): true if any monsters were deleted, false if could not delete any
    Dim lsw_distance            As Integer
    Dim lub_monster             As UByte
    Dim luw_record , luw_kind   As UInteger
    Dim lub_any                 As UByte = false

    s_core_message( UW_MSG_COMPACTING_MONSTERS )
    lsw_distance = 66
    While lub_any = false
        lub_monster = gub_dungeon_monster_next
        While lub_monster > UB_MON_MIN_INDEX
            lub_monster = lub_monster - 1
            luw_record  = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
            ' N.B: nested as it is so that the dice are thrown only when Moria throws them
            If lsw_distance < Cast( Integer , Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) ) Then
                If ful_core_random_number( 3 ) = 1 Then
                    luw_kind = fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) )
                    gub_lib_param_1 = lub_monster
                    ' never compact away the Balrog!! 26 is where a creature's record has its "movement"
                    If ( Peek( ULong , luw_kind + 26 ) bAnd UL_CM_WIN ) = 0 Then
                        If gub_game_monster_turn < lub_monster Then
                            ' in case this is called from within the monsters' turn: one that has already had
                            ' its go can be struck from the list at once
                            s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
                            lub_any = true
                        Else
                            ' one that has not is only taken off the map, the monsters' turn strikes it from
                            ' the list when it comes to it, so this makes no room yet
                            s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_REMOVE )
                        End If
                    End If
                End If
            End If
        End While
        If lub_any = false Then
            lsw_distance = lsw_distance - 6
            ' can't delete any monsters, return failure
            If lsw_distance < 0 Then Return false
        End If
    End While
    Return true
End Function


Sub s_lib_compact()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_answer                                              As UByte = false

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    s_core_ram_copy( A_MONSTER , A_LIB_PRIVATE , UB_RECORD_SIZE )
    s_core_ram_copy( A_CREATURE , A_LIB_PRIVATE + 64 , UB_RECORD_SIZE )
    s_core_ram_copy( A_OBJECT , A_LIB_PRIVATE + 128 , UB_RECORD_SIZE )
    s_core_ram_copy( A_ITEM , A_LIB_PRIVATE + 192 , UB_RECORD_SIZE )
    If gub_lib_function = UB_LIB_COMPACT_OBJECTS Then
        s_cp_objects()
    ElseIf gub_lib_function = UB_LIB_COMPACT_MONSTERS Then
        lub_answer = fub_cp_monsters()
    End If
    s_core_ram_copy( A_LIB_PRIVATE , A_MONSTER , UB_RECORD_SIZE )
    s_core_ram_copy( A_LIB_PRIVATE + 64 , A_CREATURE , UB_RECORD_SIZE )
    s_core_ram_copy( A_LIB_PRIVATE + 128 , A_OBJECT , UB_RECORD_SIZE )
    s_core_ram_copy( A_LIB_PRIVATE + 192 , A_ITEM , UB_RECORD_SIZE )
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_answer
End Sub
