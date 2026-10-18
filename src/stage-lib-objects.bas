#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_objects()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-level-include.bas"

' this page is a LIBRARY, not a stage: it scatters things about a newly made level, the end of Moria's dungeonGenerate()
' (dungeon_generate.cpp), with dungeonAllocateAndPlaceObject() and dungeonPlaceRandomObjectAt() (dungeon.cpp) and
' itemGetRandomObjectId() (game_objects.cpp)...
' ...the stage that makes a level reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , <which routine> ),
' the one routine is:
'
'   UB_LIB_OBJECTS_LEVEL    puts down what a dungeon level has lying about it: rubble in the corridors, objects in the
'                           rooms, objects anywhere, heaps of gold, and traps, guw_lib_param_2 is Moria's "alloc_level", a third of the depth, kept
'                           between 2 and 10, it must be called after the player's own place has been chosen, nothing
'                           is put there
'
'   UB_LIB_OBJECTS_PLACE_OBJECT     puts one object of a kind picked for this depth on the square at row
'                           gub_lib_param_1 and column the low byte of guw_lib_param_2, and gives it its magic, if
'                           the high byte is not 0 it is nothing too big to fit in a chest, Moria's
'                           dungeonPlaceRandomObjectAt(), used when a monster dies
'   UB_LIB_OBJECTS_RANDOM           gsw_lib_result is the number of an object picked for depth guw_lib_param_2,
'                           nothing too big for a chest if gub_lib_param_1 is true, Moria's itemGetRandomObjectId()
'                           and its sorted_objects[], for the wizard's sample of objects
'   UB_LIB_OBJECTS_PLACE_GOLD       puts a heap of gold on a square, given the same way, Moria's dungeonPlaceGold()
'
' which objects can turn up depends on the depth: every object has a depth it is first found at, the objects are listed
' in order of that depth (A_TABLE_SORTED_OBJECTS), and a second table says how many of them are found at each depth or
' above (A_TABLE_TREASURE_LEVELS), so "an object for level 5" is a random pick from the start of the list
'
' the monsters, which Moria puts down in the same breath, are the monsters library's, stage-lib-monsters.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


#define UB_SET_ROOMS        1       ' only on the floor of a room, Moria's setRooms()
#define UB_SET_CORRIDORS    2       ' only in a corridor, Moria's setCorridors()
#define UB_SET_FLOORS       3       ' on any floor, room or corridor, Moria's setFloors()

#define UB_ALLOC_TRAP       1       ' Moria's own numbers for what to put down...
#define UB_ALLOC_RUBBLE     3
#define UB_ALLOC_GOLD       4
#define UB_ALLOC_OBJECT     5


Function fuw_ob_levels( puw_level As UInteger ) As UInteger
    ' how many of the sorted objects are found at this depth or above, Moria's treasure_levels[]
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
    Return Peek( UInteger , A_TABLE_TREASURE_LEVELS + puw_level * 2 )
End Function


Function fuw_ob_sorted( puw_index As UInteger ) As UInteger
    ' the object number of an entry in the list of objects in order of depth, Moria's sorted_objects[]
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
    Return Peek( UInteger , A_TABLE_SORTED_OBJECTS + puw_index * 2 )
End Function


Function fub_ob_bigger_than_chest() As UByte
    ' true if the object in A_OBJECT is too big to be found inside a chest, Moria's itemBiggerThanChest()
    Dim lub_category As UByte

    lub_category = Peek( A_OBJECT + UB_ITEM_CATEGORY_OFFSET )
    If lub_category = UB_TV_CHEST Or lub_category = UB_TV_BOW Or lub_category = UB_TV_POLEARM Then Return true
    If lub_category = UB_TV_HARD_ARMOR Or lub_category = UB_TV_SOFT_ARMOR Or lub_category = UB_TV_STAFF Then Return true
    If lub_category = UB_TV_HAFTED Or lub_category = UB_TV_SWORD Or lub_category = UB_TV_DIGGING Then
        If Peek( UInteger , A_OBJECT + UB_ITEM_WEIGHT_OFFSET ) > 150 Then Return true
    End If
    Return false
End Function


Function fuw_ob_random_object( puw_level As UInteger , pub_must_be_small As UByte ) As UInteger
    ' picks a kind of object fit for the given depth, Moria's itemGetRandomObjectId(), what comes back is the object's
    ' number in the objects database: half the time anything found down to that depth, the other half the best of
    ' three such picks, and then anything first found at that pick's own depth, so deeper things turn up more often
    Dim luw_pick , luw_other , luw_found_level  As UInteger
    Dim luw_object                              As UInteger
    Dim lub_again                               As UByte

    If puw_level = 0 Then Return fuw_ob_sorted( fuw_gen_random( fuw_ob_levels( 0 ) ) - 1 )

    If puw_level >= UB_DUN_TREASURE_MAX_LEVELS Then
        puw_level = UB_DUN_TREASURE_MAX_LEVELS
    ElseIf fuw_gen_random( UB_DUN_GREAT_ITEM ) = 1 Then
        ' a great item: from much deeper than here
        puw_level = puw_level * UB_DUN_TREASURE_MAX_LEVELS / fuw_gen_random( UB_DUN_TREASURE_MAX_LEVELS ) + 1
        If puw_level > UB_DUN_TREASURE_MAX_LEVELS Then puw_level = UB_DUN_TREASURE_MAX_LEVELS
    End If

    Do
        If fuw_gen_random( 2 ) = 1 Then
            luw_pick = fuw_gen_random( fuw_ob_levels( puw_level ) ) - 1
        Else
            luw_pick  = fuw_gen_random( fuw_ob_levels( puw_level ) ) - 1
            luw_other = fuw_gen_random( fuw_ob_levels( puw_level ) ) - 1
            If luw_pick < luw_other Then luw_pick = luw_other
            luw_other = fuw_gen_random( fuw_ob_levels( puw_level ) ) - 1
            If luw_pick < luw_other Then luw_pick = luw_other

            s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , fuw_ob_sorted( luw_pick ) , A_OBJECT )
            luw_found_level = Peek( A_OBJECT + UB_ITEM_DEPTH_OFFSET )
            If luw_found_level = 0 Then
                luw_pick = fuw_gen_random( fuw_ob_levels( 0 ) ) - 1
            Else
                luw_other = fuw_ob_levels( luw_found_level - 1 )
                luw_pick  = fuw_gen_random( fuw_ob_levels( luw_found_level ) - luw_other ) - 1 + luw_other
            End If
        End If

        luw_object = fuw_ob_sorted( luw_pick )
        lub_again  = false
        If pub_must_be_small Then
            s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , luw_object , A_OBJECT )
            lub_again = fub_ob_bigger_than_chest()
        End If
    Loop While lub_again
    Return luw_object
End Function


Sub s_ob_place_random_object( pub_row As UByte , pub_col As UByte , pub_must_be_small As UByte )
    ' puts an object of a kind picked for this depth on a square, and gives it its magic, Moria's dungeonPlaceRandomObjectAt()
    Dim luw_object  As UInteger
    Dim lub_number  As UByte

    luw_object = fuw_ob_random_object( guw_dungeon_level , pub_must_be_small )
    lub_number = fub_gen_new_item( luw_object )
    If lub_number = 0 Then Return           ' the level's list of items is full
    guw_lib_param_2 = guw_dungeon_level
    s_core_call_library( UB_PAGED_CODE_LIB_TREASURE , UB_LIB_TREASURE_MAGIC )
    s_gen_put_item( pub_row , pub_col , lub_number )
    If Peek( fuw_core_map_square( gub_level_map_page , pub_row , pub_col ) + UB_SQUARE_MONSTER ) = 1 Then s_core_message( UW_MSG_YOU_FEEL_SOMETHING_ROLL_BENEATH )
End Sub


Sub s_ob_allocate( pub_set As UByte , pub_type As UByte , psw_number As Integer )
    ' puts a number of things down, each on a square picked at random until one of the right kind turns up that has
    ' nothing on it and is not where the player is, Moria's dungeonAllocateAndPlaceObject()
    Dim lub_y , lub_x , lub_feature , lub_found As UByte
    Dim luw_square                              As UInteger

    While psw_number > 0
        Do
            lub_y = fuw_gen_random( gub_dungeon_rows ) - 1
            lub_x = fuw_gen_random( gub_dungeon_cols ) - 1
            luw_square  = fuw_core_map_square( gub_level_map_page , lub_y , lub_x )
            lub_feature = Peek( luw_square )
            lub_found   = false
            If pub_set = UB_SET_ROOMS Then
                If lub_feature = UB_TILE_DARK_FLOOR Or lub_feature = UB_TILE_LIGHT_FLOOR Then lub_found = true
            ElseIf pub_set = UB_SET_CORRIDORS Then
                If lub_feature = UB_TILE_CORR_FLOOR Or lub_feature = UB_TILE_BLOCKED_FLOOR Then lub_found = true
            Else
                If lub_feature <= UB_TILE_BLOCKED_FLOOR Then lub_found = true
            End If
            If Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then lub_found = false
            If lub_y = gub_player_row And lub_x = gub_player_col Then lub_found = false
        Loop Until lub_found

        If pub_type = UB_ALLOC_TRAP Then
            ' Moria's dungeonSetTrap(), one of the 18 kinds
            s_gen_put_item( lub_y , lub_x , fub_gen_new_item( UW_OBJ_TRAP_LIST + fuw_gen_random( UB_OBJ_MAX_TRAPS ) - 1 ) )
        ElseIf pub_type = UB_ALLOC_RUBBLE Then
            ' Moria's dungeonPlaceRubble(), it blocks the way
            s_gen_put_item( lub_y , lub_x , fub_gen_new_item( UW_OBJ_RUBBLE ) )
            s_gen_set_feature( lub_y , lub_x , UB_TILE_BLOCKED_FLOOR )
        ElseIf pub_type = UB_ALLOC_GOLD Then
            s_gen_place_gold( lub_y , lub_x )
        Else
            s_ob_place_random_object( lub_y , lub_x , false )
        End If
        psw_number = psw_number - 1
    End While
End Sub


Sub s_ob_level()
    ' what Moria's dungeonGenerate() does once the level is built
    Dim lub_saved_page  As UByte
    Dim luw_alloc_level As UInteger

    luw_alloc_level = guw_lib_param_2
    lub_saved_page  = gub_core_MMU2_page_number

    ' the monsters come first, the stage that makes the level has the monsters library put them down before calling this
    s_ob_allocate( UB_SET_CORRIDORS , UB_ALLOC_RUBBLE , fuw_gen_random( luw_alloc_level ) )
    s_ob_allocate( UB_SET_ROOMS  , UB_ALLOC_OBJECT , fsw_core_random_normal( UB_DUN_OBJECTS_PER_ROOM , 3 ) )
    s_ob_allocate( UB_SET_FLOORS , UB_ALLOC_OBJECT , fsw_core_random_normal( UB_DUN_OBJECTS_PER_CORRIDOR , 3 ) )
    s_ob_allocate( UB_SET_FLOORS , UB_ALLOC_GOLD   , fsw_core_random_normal( UB_DUN_TOTAL_GOLD , 3 ) )
    s_ob_allocate( UB_SET_FLOORS , UB_ALLOC_TRAP , fuw_gen_random( luw_alloc_level ) )

    If lub_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page )
End Sub


Sub s_lib_objects()
    Dim lub_saved_page As UByte

    If gub_lib_function = UB_LIB_OBJECTS_LEVEL Then
        s_ob_level()
    Else
        lub_saved_page = gub_core_MMU2_page_number
        If gub_lib_function = UB_LIB_OBJECTS_PLACE_OBJECT Then
            s_ob_place_random_object( gub_lib_param_1 , guw_lib_param_2 bAnd 255 , guw_lib_param_2 >> 8 )
        ElseIf gub_lib_function = UB_LIB_OBJECTS_RANDOM Then
            gsw_lib_result = fuw_ob_random_object( guw_lib_param_2 , gub_lib_param_1 )
        ElseIf gub_lib_function = UB_LIB_OBJECTS_PLACE_GOLD Then
            s_gen_place_gold( gub_lib_param_1 , guw_lib_param_2 bAnd 255 )
        End If
        If lub_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page )
    End If
End Sub
