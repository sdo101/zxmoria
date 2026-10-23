#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_rooms()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-level-include.bas"

' this page is a LIBRARY, not a stage: the two most unusual kinds of room a dungeon level can have, from Moria's
' dungeon_generate.cpp, the stage that makes a level, stage-create-dungeon.bas, has no room left for them...
' ...it reaches this page through the core: s_core_call_library( UB_PAGED_CODE_LIB_ROOMS , <which routine> ), the
' middle of the room is at row gub_lib_param_1 and column guw_lib_param_2, the routines are:
'
'   UB_LIB_ROOMS_INNER      a big room with a room inside it, which may be plain, a treasure vault, have pillars,
'                           be a maze, or be four small rooms, Moria's dungeonBuildRoomWithInnerRooms()
'   UB_LIB_ROOMS_CROSS      a cross shaped room, which may have a pillar or a vault in the middle, Moria's
'                           dungeonBuildRoomCrossShaped()
'
' the inner walls are made of "temporary wall", which the stage turns into granite once the tunnels are dug, so that
' no tunnel is dug through them, and the monsters, traps and treasure inside are put there now, as in Moria, long
' before the rest of the level gets its own
'
' N.B: the random numbers are asked for in exactly the order Moria asks for them, so that one seed gives one level,
' where Moria's "if" tests two things with && and the second one uses a random number, the tests here are nested Ifs


Sub s_rm_block( psw_top As Integer , psw_bottom As Integer , psw_left As Integer , psw_right As Integer , pub_feature As UByte )
    ' every square of a rectangle becomes one thing, the squares are not marked as part of a lit room
    Dim lsw_y , lsw_x As Integer

    For lsw_y = psw_top To psw_bottom
        For lsw_x = psw_left To psw_right
            s_gen_set_feature( lsw_y , lsw_x , pub_feature )
        Next
    Next
End Sub


Sub s_rm_floor( psw_top As Integer , psw_bottom As Integer , psw_left As Integer , psw_right As Integer , pub_floor As UByte , pub_overlap As UByte )
    ' a rectangle of floor with a wall of granite round it, all of it part of a lit room, with pub_overlap the wall
    ' is not put where an earlier rectangle has already made floor
    Dim lsw_y , lsw_x As Integer

    For lsw_y = psw_top To psw_bottom
        For lsw_x = psw_left To psw_right
            s_gen_set_room_square( lsw_y , lsw_x , pub_floor )
        Next
    Next
    For lsw_y = psw_top - 1 To psw_bottom + 1
        If pub_overlap = false Or fub_gen_feature( lsw_y , psw_left - 1 ) <> pub_floor Then s_gen_set_room_square( lsw_y , psw_left - 1 , UB_TILE_GRANITE_WALL )
        If pub_overlap = false Or fub_gen_feature( lsw_y , psw_right + 1 ) <> pub_floor Then s_gen_set_room_square( lsw_y , psw_right + 1 , UB_TILE_GRANITE_WALL )
    Next
    For lsw_x = psw_left To psw_right
        If pub_overlap = false Or fub_gen_feature( psw_top - 1 , lsw_x ) <> pub_floor Then s_gen_set_room_square( psw_top - 1 , lsw_x , UB_TILE_GRANITE_WALL )
        If pub_overlap = false Or fub_gen_feature( psw_bottom + 1 , lsw_x ) <> pub_floor Then s_gen_set_room_square( psw_bottom + 1 , lsw_x , UB_TILE_GRANITE_WALL )
    Next
End Sub


Sub s_rm_secret_door( psw_y As Integer , psw_x As Integer )
    ' Moria's dungeonPlaceSecretDoor()
    s_gen_place_door_of( psw_y , psw_x , UW_OBJ_SECRET_DOOR , UB_TILE_BLOCKED_FLOOR , 0 )
End Sub


Sub s_rm_random_secret_door( psw_y As Integer , psw_x As Integer , psw_depth As Integer , psw_height As Integer , psw_left As Integer , psw_right As Integer )
    ' a secret door in the middle of one of the four walls, Moria's dungeonPlaceRandomSecretDoor()
    Dim luw_side As UInteger

    luw_side = fuw_gen_random( 4 )
    If luw_side = 1 Then
        s_rm_secret_door( psw_height - 1 , psw_x )
    ElseIf luw_side = 2 Then
        s_rm_secret_door( psw_depth + 1 , psw_x )
    ElseIf luw_side = 3 Then
        s_rm_secret_door( psw_y , psw_left - 1 )
    Else
        s_rm_secret_door( psw_y , psw_right + 1 )
    End If
End Sub


Sub s_rm_vault( psw_y As Integer , psw_x As Integer )
    ' the eight squares round one square become wall, Moria's dungeonPlaceVault()
    Dim lsw_i As Integer

    For lsw_i = psw_y - 1 To psw_y + 1
        s_gen_set_feature( lsw_i , psw_x - 1 , UB_TILE_TMP1_WALL )
        s_gen_set_feature( lsw_i , psw_x + 1 , UB_TILE_TMP1_WALL )
    Next
    s_gen_set_feature( psw_y - 1 , psw_x , UB_TILE_TMP1_WALL )
    s_gen_set_feature( psw_y + 1 , psw_x , UB_TILE_TMP1_WALL )
End Sub


Sub s_rm_monsters( psw_y As Integer , psw_x As Integer , puw_number As UInteger )
    ' Moria's dungeonPlaceVaultMonster(): monsters from a little deeper than here, asleep, beside a square
    While puw_number > 0
        gub_lib_param_1 = psw_y
        guw_lib_param_2 = psw_x
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON_AT )
        puw_number = puw_number - 1
    End While
End Sub


Sub s_rm_traps( psw_y As Integer , psw_x As Integer , psw_dy As Integer , psw_dx As Integer , puw_number As UInteger )
    ' Moria's dungeonPlaceVaultTrap(): traps on open, empty squares within a distance of a square, six tries each
    Dim lsw_at_y , lsw_at_x     As Integer
    Dim lub_count , lub_placed  As UByte
    Dim luw_square              As UInteger
    Dim lub_feature             As UByte

    While puw_number > 0
        lub_placed = false
        lub_count  = 0
        While lub_placed = false And lub_count <= 5
            lsw_at_y = psw_y - psw_dy - 1 + Cast( Integer , fuw_gen_random( 2 * psw_dy + 1 ) )
            lsw_at_x = psw_x - psw_dx - 1 + Cast( Integer , fuw_gen_random( 2 * psw_dx + 1 ) )
            luw_square  = fuw_core_map_square( gub_level_map_page , lsw_at_y , lsw_at_x )
            lub_feature = Peek( luw_square )
            If lub_feature <> UB_TILE_NULL_WALL And lub_feature <= UB_TILE_BLOCKED_FLOOR And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then
                ' Moria's dungeonSetTrap(), one of the 18 kinds
                s_gen_put_item( lsw_at_y , lsw_at_x , fub_gen_new_item( UW_OBJ_TRAP_LIST + fuw_gen_random( UB_OBJ_MAX_TRAPS ) - 1 ) )
                lub_placed = true
            End If
            lub_count = lub_count + 1
        End While
        puw_number = puw_number - 1
    End While
End Sub


Sub s_rm_object( psw_y As Integer , psw_x As Integer )
    ' Moria's dungeonPlaceRandomObjectAt(), the objects library does it
    gub_lib_param_1 = psw_y
    guw_lib_param_2 = psw_x
    s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT )
End Sub


Sub s_rm_objects_near( psw_y As Integer , psw_x As Integer , puw_tries As UInteger )
    ' Moria's dungeonPlaceRandomObjectNear(): an object, or one time in four gold, on an open, empty square near
    ' a square, N.B: as in Moria, once something has been put down the hunt goes round once more, so now and then
    ' two things are put down for one try
    Dim lsw_at_y , lsw_at_x , lsw_i     As Integer
    Dim luw_square                      As UInteger
    Dim lub_open                        As UByte

    Do
        lsw_i = 0
        While lsw_i <= 10
            lsw_at_y = psw_y - 3 + Cast( Integer , fuw_gen_random( 5 ) )
            lsw_at_x = psw_x - 4 + Cast( Integer , fuw_gen_random( 7 ) )
            lub_open = false
            If fub_gen_in_bounds( lsw_at_y , lsw_at_x ) Then
                luw_square = fuw_core_map_square( gub_level_map_page , lsw_at_y , lsw_at_x )
                If Peek( luw_square ) <= UB_TILE_BLOCKED_FLOOR And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then lub_open = true
            End If
            If lub_open Then
                If fuw_gen_random( 100 ) < 75 Then
                    s_rm_object( lsw_at_y , lsw_at_x )
                Else
                    s_gen_place_gold( lsw_at_y , lsw_at_x )
                End If
                lsw_i = 9
            End If
            lsw_i = lsw_i + 1
        End While
        puw_tries = puw_tries - 1
    Loop Until puw_tries = 0
End Sub


'##################################################################################################################################
' --- a room with inner rooms ---

Sub s_rm_inner( psw_y As Integer , psw_x As Integer )
    ' Moria's dungeonBuildRoomWithInnerRooms()
    Dim lub_floor                                           As UByte
    Dim lsw_height , lsw_depth , lsw_left , lsw_right       As Integer
    Dim lsw_i , lsw_offset                                  As Integer
    Dim luw_kind                                            As UInteger

    lub_floor  = fub_gen_floor_tile()
    lsw_height = psw_y - 4
    lsw_depth  = psw_y + 4
    lsw_left   = psw_x - 11
    lsw_right  = psw_x + 11
    s_rm_floor( lsw_height , lsw_depth , lsw_left , lsw_right , lub_floor , false )

    ' the inner room
    lsw_height = lsw_height + 2
    lsw_depth  = lsw_depth - 2
    lsw_left   = lsw_left + 2
    lsw_right  = lsw_right - 2
    For lsw_i = lsw_height - 1 To lsw_depth + 1
        s_gen_set_feature( lsw_i , lsw_left - 1 , UB_TILE_TMP1_WALL )
        s_gen_set_feature( lsw_i , lsw_right + 1 , UB_TILE_TMP1_WALL )
    Next
    For lsw_i = lsw_left To lsw_right
        s_gen_set_feature( lsw_height - 1 , lsw_i , UB_TILE_TMP1_WALL )
        s_gen_set_feature( lsw_depth + 1 , lsw_i , UB_TILE_TMP1_WALL )
    Next

    ' inner room variations
    luw_kind = fuw_gen_random( 5 )
    If luw_kind = UB_INNER_ROOM_PLAIN Then
        ' just an inner room with one door
        s_rm_random_secret_door( psw_y , psw_x , lsw_depth , lsw_height , lsw_left , lsw_right )
        s_rm_monsters( psw_y , psw_x , 1 )

    ElseIf luw_kind = UB_INNER_ROOM_TREASURE_VAULT Then
        ' a treasure vault, an inner room within the inner room, Moria's dungeonPlaceTreasureVault()
        s_rm_random_secret_door( psw_y , psw_x , lsw_depth , lsw_height , lsw_left , lsw_right )
        s_rm_vault( psw_y , psw_x )
        ' place a locked door
        lsw_offset = fuw_gen_random( 4 )
        If lsw_offset < 3 Then
            ' 1 -> y-1; 2 -> y+1
            lsw_i = psw_y - 3 + ( lsw_offset << 1 )
            s_gen_place_door_of( lsw_i , psw_x , UW_OBJ_CLOSED_DOOR , UB_TILE_BLOCKED_FLOOR , Cast( Integer , fuw_gen_random( 10 ) ) + 10 )
        Else
            lsw_i = psw_x - 7 + ( lsw_offset << 1 )
            s_gen_place_door_of( psw_y , lsw_i , UW_OBJ_CLOSED_DOOR , UB_TILE_BLOCKED_FLOOR , Cast( Integer , fuw_gen_random( 10 ) ) + 10 )
        End If
        ' guard the treasure well
        s_rm_monsters( psw_y , psw_x , 2 + fuw_gen_random( 3 ) )
        ' if the monsters don't get 'em
        s_rm_traps( psw_y , psw_x , 4 , 10 , 2 + fuw_gen_random( 3 ) )

    ElseIf luw_kind = UB_INNER_ROOM_PILLARS Then
        ' an inner room with pillars, Moria's dungeonPlaceInnerPillars()
        s_rm_random_secret_door( psw_y , psw_x , lsw_depth , lsw_height , lsw_left , lsw_right )
        s_rm_block( psw_y - 1 , psw_y + 1 , psw_x - 1 , psw_x + 1 , UB_TILE_TMP1_WALL )
        If fuw_gen_random( 2 ) = 1 Then
            lsw_offset = fuw_gen_random( 2 )
            s_rm_block( psw_y - 1 , psw_y + 1 , psw_x - 5 - lsw_offset , psw_x - 3 - lsw_offset , UB_TILE_TMP1_WALL )
            s_rm_block( psw_y - 1 , psw_y + 1 , psw_x + 3 + lsw_offset , psw_x + 5 + lsw_offset , UB_TILE_TMP1_WALL )
        End If
        If fuw_gen_random( 3 ) = 1 Then
            ' inner rooms
            For lsw_i = psw_x - 5 To psw_x + 5
                s_gen_set_feature( psw_y - 1 , lsw_i , UB_TILE_TMP1_WALL )
                s_gen_set_feature( psw_y + 1 , lsw_i , UB_TILE_TMP1_WALL )
            Next
            s_gen_set_feature( psw_y , psw_x - 5 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y , psw_x + 5 , UB_TILE_TMP1_WALL )
            lsw_i = psw_y - 3 + ( Cast( Integer , fuw_gen_random( 2 ) ) << 1 )
            s_rm_secret_door( lsw_i , psw_x - 3 )
            lsw_i = psw_y - 3 + ( Cast( Integer , fuw_gen_random( 2 ) ) << 1 )
            s_rm_secret_door( lsw_i , psw_x + 3 )
            If fuw_gen_random( 3 ) = 1 Then s_rm_object( psw_y , psw_x - 2 )
            If fuw_gen_random( 3 ) = 1 Then s_rm_object( psw_y , psw_x + 2 )
            s_rm_monsters( psw_y , psw_x - 2 , fuw_gen_random( 2 ) )
            s_rm_monsters( psw_y , psw_x + 2 , fuw_gen_random( 2 ) )
        End If

    ElseIf luw_kind = UB_INNER_ROOM_MAZE Then
        ' the inner room has a maze, Moria's dungeonPlaceMazeInsideRoom()
        s_rm_random_secret_door( psw_y , psw_x , lsw_depth , lsw_height , lsw_left , lsw_right )
        For lsw_i = lsw_height To lsw_depth
            For lsw_offset = lsw_left To lsw_right
                If ( ( lsw_i + lsw_offset ) bAnd 1 ) <> 0 Then s_gen_set_feature( lsw_i , lsw_offset , UB_TILE_TMP1_WALL )
            Next
        Next
        ' monsters just love mazes
        s_rm_monsters( psw_y , psw_x - 5 , fuw_gen_random( 3 ) )
        s_rm_monsters( psw_y , psw_x + 5 , fuw_gen_random( 3 ) )
        ' traps make them entertaining
        s_rm_traps( psw_y , psw_x - 3 , 2 , 8 , fuw_gen_random( 3 ) )
        s_rm_traps( psw_y , psw_x + 3 , 2 , 8 , fuw_gen_random( 3 ) )
        ' mazes should have some treasure too
        For lsw_i = 0 To 2
            s_rm_objects_near( psw_y , psw_x , 1 )
        Next

    Else
        ' a set of four inner rooms, Moria's dungeonPlaceFourSmallRooms()
        For lsw_i = lsw_height To lsw_depth
            s_gen_set_feature( lsw_i , psw_x , UB_TILE_TMP1_WALL )
        Next
        For lsw_i = lsw_left To lsw_right
            s_gen_set_feature( psw_y , lsw_i , UB_TILE_TMP1_WALL )
        Next
        ' place random secret door
        If fuw_gen_random( 2 ) = 1 Then
            lsw_offset = fuw_gen_random( 10 )
            s_rm_secret_door( lsw_height - 1 , psw_x - lsw_offset )
            s_rm_secret_door( lsw_height - 1 , psw_x + lsw_offset )
            s_rm_secret_door( lsw_depth + 1 , psw_x - lsw_offset )
            s_rm_secret_door( lsw_depth + 1 , psw_x + lsw_offset )
        Else
            lsw_offset = fuw_gen_random( 3 )
            s_rm_secret_door( psw_y + lsw_offset , lsw_left - 1 )
            s_rm_secret_door( psw_y - lsw_offset , lsw_left - 1 )
            s_rm_secret_door( psw_y + lsw_offset , lsw_right + 1 )
            s_rm_secret_door( psw_y - lsw_offset , lsw_right + 1 )
        End If
        ' treasure in each one
        s_rm_objects_near( psw_y , psw_x , 2 + fuw_gen_random( 2 ) )
        ' gotta have some monsters
        s_rm_monsters( psw_y + 2 , psw_x - 4 , fuw_gen_random( 2 ) )
        s_rm_monsters( psw_y + 2 , psw_x + 4 , fuw_gen_random( 2 ) )
        s_rm_monsters( psw_y - 2 , psw_x - 4 , fuw_gen_random( 2 ) )
        s_rm_monsters( psw_y - 2 , psw_x + 4 , fuw_gen_random( 2 ) )
    End If
End Sub


'##################################################################################################################################
' --- a cross shaped room ---

Sub s_rm_cross( psw_y As Integer , psw_x As Integer )
    ' Moria's dungeonBuildRoomCrossShaped()
    Dim lub_floor               As UByte
    Dim lsw_offset              As Integer
    Dim luw_kind                As UInteger

    lub_floor  = fub_gen_floor_tile()
    ' the upright of the cross, then the bar across it
    lsw_offset = 2 + fuw_gen_random( 2 )
    s_rm_floor( psw_y - lsw_offset , psw_y + lsw_offset , psw_x - 1 , psw_x + 1 , lub_floor , false )
    lsw_offset = 2 + fuw_gen_random( 9 )
    s_rm_floor( psw_y - 1 , psw_y + 1 , psw_x - lsw_offset , psw_x + lsw_offset , lub_floor , true )

    ' special features
    luw_kind = fuw_gen_random( 4 )
    If luw_kind = 1 Then
        ' large middle pillar
        s_rm_block( psw_y - 1 , psw_y + 1 , psw_x - 1 , psw_x + 1 , UB_TILE_TMP1_WALL )

    ElseIf luw_kind = 2 Then
        ' inner treasure vault
        s_rm_vault( psw_y , psw_x )
        ' place a secret door
        lsw_offset = fuw_gen_random( 4 )
        If lsw_offset < 3 Then
            s_rm_secret_door( psw_y - 3 + ( lsw_offset << 1 ) , psw_x )
        Else
            s_rm_secret_door( psw_y , psw_x - 7 + ( lsw_offset << 1 ) )
        End If
        ' place a treasure in the vault
        s_rm_object( psw_y , psw_x )
        ' let's guard the treasure well
        s_rm_monsters( psw_y , psw_x , 2 + fuw_gen_random( 2 ) )
        ' traps naturally
        s_rm_traps( psw_y , psw_x , 4 , 4 , 1 + fuw_gen_random( 3 ) )

    ElseIf luw_kind = 3 Then
        ' N.B: nested as they are so that each random number is asked for only when Moria asks for it
        If fuw_gen_random( 3 ) = 1 Then
            s_gen_set_feature( psw_y - 1 , psw_x - 2 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y + 1 , psw_x - 2 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y - 1 , psw_x + 2 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y + 1 , psw_x + 2 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y - 2 , psw_x - 1 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y - 2 , psw_x + 1 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y + 2 , psw_x - 1 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y + 2 , psw_x + 1 , UB_TILE_TMP1_WALL )
            If fuw_gen_random( 3 ) = 1 Then
                s_rm_secret_door( psw_y , psw_x - 2 )
                s_rm_secret_door( psw_y , psw_x + 2 )
                s_rm_secret_door( psw_y - 2 , psw_x )
                s_rm_secret_door( psw_y + 2 , psw_x )
            End If
        ElseIf fuw_gen_random( 3 ) = 1 Then
            s_gen_set_feature( psw_y , psw_x , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y - 1 , psw_x , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y + 1 , psw_x , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y , psw_x - 1 , UB_TILE_TMP1_WALL )
            s_gen_set_feature( psw_y , psw_x + 1 , UB_TILE_TMP1_WALL )
        ElseIf fuw_gen_random( 3 ) = 1 Then
            s_gen_set_feature( psw_y , psw_x , UB_TILE_TMP1_WALL )
        End If
    End If
    ' 4 is no special feature
End Sub


Sub s_lib_rooms()
    Dim lub_saved_page_0 , lub_saved_page_2 As UByte
    Dim lub_y , lub_x                       As UByte

    ' N.B: these are taken out first, the routines here call other libraries, which use the same places
    lub_y = gub_lib_param_1
    lub_x = guw_lib_param_2
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_ROOMS_INNER Then
        s_rm_inner( lub_y , lub_x )
    ElseIf gub_lib_function = UB_LIB_ROOMS_CROSS Then
        s_rm_cross( lub_y , lub_x )
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , lub_saved_page_0 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
