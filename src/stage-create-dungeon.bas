#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_create_dungeon()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-level-include.bas"

' this stage makes a new dungeon level, it is Moria's dungeonGenerate() (dungeon_generate.cpp) routine for routine...
' ...and it asks for its random numbers in exactly the order Moria does, so that one seed gives one level, as it does there
' N.B: where Moria's "if" tests two things with && and the second one uses a random number, the tests here are nested Ifs,
' so that the random number is only asked for when the first test passes, do not join them up with And
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing of the level's shape: the two most unusual kinds of room, with inner rooms and cross shaped, are in the
'     rooms library, stage-lib-rooms.bas
'   (making room when a level's item list is full is the compact library's, stage-lib-compact.bas, called by
'   fub_gen_new_item(), Moria's popt(), in stage-level-include.bas)

' --- its working storage is in globals.bas, under "private to stage-create-dungeon.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- items ---
' N.B: the small helpers, and putting down one particular kind of door, are in stage-level-include.bas, the rooms
' library uses them too

Sub s_gen_place_door( pub_row As UByte , pub_col As UByte )
    ' puts a door on a square, of a kind chosen at random, Moria's dungeonPlaceDoor()
    Dim luw_type    As UInteger
    Dim lsw_misc    As Integer

    luw_type = fuw_gen_random( 3 )
    If luw_type = 1 Then
        If fuw_gen_random( 4 ) = 1 Then
            s_gen_place_door_of( pub_row , pub_col , UW_OBJ_OPEN_DOOR , UB_TILE_CORR_FLOOR , 1 )       ' a broken door
        Else
            s_gen_place_door_of( pub_row , pub_col , UW_OBJ_OPEN_DOOR , UB_TILE_CORR_FLOOR , 0 )       ' an open door
        End If
    ElseIf luw_type = 2 Then
        luw_type = fuw_gen_random( 12 )
        If luw_type > 3 Then
            s_gen_place_door_of( pub_row , pub_col , UW_OBJ_CLOSED_DOOR , UB_TILE_BLOCKED_FLOOR , 0 )  ' a closed door
        ElseIf luw_type = 3 Then
            lsw_misc = -Cast( Integer , fuw_gen_random( 10 ) ) - 10
            s_gen_place_door_of( pub_row , pub_col , UW_OBJ_CLOSED_DOOR , UB_TILE_BLOCKED_FLOOR , lsw_misc )   ' a stuck door
        Else
            lsw_misc = Cast( Integer , fuw_gen_random( 10 ) ) + 10
            s_gen_place_door_of( pub_row , pub_col , UW_OBJ_CLOSED_DOOR , UB_TILE_BLOCKED_FLOOR , lsw_misc )   ' a locked door
        End If
    Else
        s_gen_place_door_of( pub_row , pub_col , UW_OBJ_SECRET_DOOR , UB_TILE_BLOCKED_FLOOR , 0 )      ' a secret door
    End If
End Sub


'##################################################################################################################################
' --- rooms ---

Sub s_gen_build_room( pub_y As UByte , pub_x As UByte , pub_overlap As UByte )
    ' builds a room around the given middle...
    ' ...with pub_overlap false it is one plain rectangle, Moria's dungeonBuildRoom()...
    ' ...with pub_overlap true it is two or three rectangles on top of each other, Moria's dungeonBuildRoomOverlappingRectangles(),
    ' where a wall is only put down if an earlier rectangle has not already made that square into floor
    Dim lub_floor , lub_height , lub_depth , lub_left , lub_right   As UByte
    Dim lub_count , lub_limit , y , x                               As UByte

    lub_floor = fub_gen_floor_tile()
    lub_limit = 1
    If pub_overlap Then lub_limit = 1 + fuw_gen_random( 2 )

    For lub_count = 1 To lub_limit
        lub_height = pub_y - fuw_gen_random( 4 )
        lub_depth  = pub_y + fuw_gen_random( 3 )
        lub_left   = pub_x - fuw_gen_random( 11 )
        lub_right  = pub_x + fuw_gen_random( 11 )

        For y = lub_height To lub_depth
            For x = lub_left To lub_right
                s_gen_set_room_square( y , x , lub_floor )
            Next
        Next

        For y = lub_height - 1 To lub_depth + 1
            If pub_overlap = false Or fub_gen_feature( y , lub_left - 1 ) <> lub_floor Then s_gen_set_room_square( y , lub_left - 1 , UB_TILE_GRANITE_WALL )
            If pub_overlap = false Or fub_gen_feature( y , lub_right + 1 ) <> lub_floor Then s_gen_set_room_square( y , lub_right + 1 , UB_TILE_GRANITE_WALL )
        Next

        For x = lub_left To lub_right
            If pub_overlap = false Or fub_gen_feature( lub_height - 1 , x ) <> lub_floor Then s_gen_set_room_square( lub_height - 1 , x , UB_TILE_GRANITE_WALL )
            If pub_overlap = false Or fub_gen_feature( lub_depth + 1 , x ) <> lub_floor Then s_gen_set_room_square( lub_depth + 1 , x , UB_TILE_GRANITE_WALL )
        Next
    Next
End Sub


'##################################################################################################################################
' --- tunnels ---

Sub s_gen_correct_direction()
    ' heads the tunnel towards where it is going, Moria's pickCorrectDirection()
    gsb_gen_dir_y = 0
    If gub_gen_y < gub_gen_end_y Then gsb_gen_dir_y = 1
    If gub_gen_y > gub_gen_end_y Then gsb_gen_dir_y = -1
    gsb_gen_dir_x = 0
    If gub_gen_x < gub_gen_end_x Then gsb_gen_dir_x = 1
    If gub_gen_x > gub_gen_end_x Then gsb_gen_dir_x = -1

    ' never diagonally, pick one of the two
    If gsb_gen_dir_y <> 0 And gsb_gen_dir_x <> 0 Then
        If fuw_gen_random( 2 ) = 1 Then
            gsb_gen_dir_y = 0
        Else
            gsb_gen_dir_x = 0
        End If
    End If
End Sub


Sub s_gen_random_direction()
    ' heads the tunnel up, down, left or right at random, Moria's chanceOfRandomDirection()
    Dim luw_direction As UInteger

    luw_direction = fuw_gen_random( 4 )
    gsb_gen_dir_y = 0
    gsb_gen_dir_x = 0
    If luw_direction = 1 Then gsb_gen_dir_y = -1
    If luw_direction = 2 Then gsb_gen_dir_y = 1
    If luw_direction = 3 Then gsb_gen_dir_x = -1
    If luw_direction = 4 Then gsb_gen_dir_x = 1
End Sub


Sub s_gen_new_direction()
    If fuw_gen_random( UB_DUN_RANDOM_DIR ) = 1 Then
        s_gen_random_direction()
    Else
        s_gen_correct_direction()
    End If
End Sub


Sub s_gen_build_tunnel( pub_start_y As UByte , pub_start_x As UByte , pub_end_y As UByte , pub_end_x As UByte )
    ' digs a tunnel from one room to another, Moria's dungeonBuildTunnel()...
    ' ...the squares it passes through are only listed while it is being dug, and turned into corridor at the end
    Dim lub_door_flag , lub_stop_flag               As UByte
    Dim lub_feature , y , x                         As UByte
    Dim luw_loop_count , luw_tunnels , luw_walls    As UInteger
    Dim luw_i                                       As UInteger
    Dim lsw_row , lsw_col                           As Integer

    lub_door_flag  = false
    lub_stop_flag  = false
    luw_loop_count = 0
    luw_tunnels    = 0
    luw_walls      = 0
    gub_gen_y      = pub_start_y
    gub_gen_x      = pub_start_x
    gub_gen_end_y  = pub_end_y
    gub_gen_end_x  = pub_end_x
    s_gen_correct_direction()

    Do
        ' prevent infinite loops, just in case
        luw_loop_count = luw_loop_count + 1
        If luw_loop_count > 2000 Then lub_stop_flag = true

        If fuw_gen_random( 100 ) > UB_DUN_DIR_CHANGE Then s_gen_new_direction()

        lsw_row = Cast( Integer , gub_gen_y ) + gsb_gen_dir_y
        lsw_col = Cast( Integer , gub_gen_x ) + gsb_gen_dir_x
        While fub_gen_in_bounds( lsw_row , lsw_col ) = false
            s_gen_new_direction()
            lsw_row = Cast( Integer , gub_gen_y ) + gsb_gen_dir_y
            lsw_col = Cast( Integer , gub_gen_x ) + gsb_gen_dir_x
        End While

        lub_feature = fub_gen_feature( lsw_row , lsw_col )
        If lub_feature = UB_TILE_NULL_WALL Then
            gub_gen_y = lsw_row
            gub_gen_x = lsw_col
            If luw_tunnels < 1000 Then
                Poke A_GEN_TUNNELS + luw_tunnels * 2     , gub_gen_y
                Poke A_GEN_TUNNELS + luw_tunnels * 2 + 1 , gub_gen_x
                luw_tunnels = luw_tunnels + 1
            End If
            lub_door_flag = false

        ElseIf lub_feature = UB_TILE_TMP2_WALL Then
            ' do nothing, the tunnel may not go through here

        ElseIf lub_feature = UB_TILE_GRANITE_WALL Then
            ' the wall of a room: go through it, and mark the wall around the hole so that no other tunnel comes in right beside it
            gub_gen_y = lsw_row
            gub_gen_x = lsw_col
            If luw_walls < 1000 Then
                Poke A_GEN_WALLS + luw_walls * 2     , gub_gen_y
                Poke A_GEN_WALLS + luw_walls * 2 + 1 , gub_gen_x
                luw_walls = luw_walls + 1
            End If
            For y = gub_gen_y - 1 To gub_gen_y + 1
                For x = gub_gen_x - 1 To gub_gen_x + 1
                    If fub_gen_in_bounds( y , x ) Then
                        If fub_gen_feature( y , x ) = UB_TILE_GRANITE_WALL Then s_gen_set_feature( y , x , UB_TILE_TMP2_WALL )
                    End If
                Next
            Next

        ElseIf lub_feature = UB_TILE_CORR_FLOOR Or lub_feature = UB_TILE_BLOCKED_FLOOR Then
            ' another tunnel: remember where we met it, a door may go there later
            gub_gen_y = lsw_row
            gub_gen_x = lsw_col
            If lub_door_flag = false Then
                If guw_gen_door_count < 100 Then
                    Poke A_GEN_DOORS + guw_gen_door_count * 2     , gub_gen_y
                    Poke A_GEN_DOORS + guw_gen_door_count * 2 + 1 , gub_gen_x
                    guw_gen_door_count = guw_gen_door_count + 1
                End If
                lub_door_flag = true
            End If

            If fuw_gen_random( 100 ) > UB_DUN_TUNNELING Then
                ' make sure that the tunnel has gone a reasonable distance before stopping it, this helps prevent isolated rooms
                lsw_row = Abs( Cast( Integer , gub_gen_y ) - Cast( Integer , pub_start_y ) )
                lsw_col = Abs( Cast( Integer , gub_gen_x ) - Cast( Integer , pub_start_x ) )
                If lsw_row > 10 Or lsw_col > 10 Then lub_stop_flag = true
            End If

        Else
            ' anything else, the floor of a room for instance: just walk across it
            gub_gen_y = lsw_row
            gub_gen_x = lsw_col
        End If

        If gub_gen_y = gub_gen_end_y And gub_gen_x = gub_gen_end_x Then lub_stop_flag = true
    Loop Until lub_stop_flag

    If luw_tunnels > 0 Then
        For luw_i = 0 To luw_tunnels - 1
            s_gen_set_feature( Peek( A_GEN_TUNNELS + luw_i * 2 ) , Peek( A_GEN_TUNNELS + luw_i * 2 + 1 ) , UB_TILE_CORR_FLOOR )
        Next
    End If

    If luw_walls > 0 Then
        For luw_i = 0 To luw_walls - 1
            y = Peek( A_GEN_WALLS + luw_i * 2 )
            x = Peek( A_GEN_WALLS + luw_i * 2 + 1 )
            If fub_gen_feature( y , x ) = UB_TILE_TMP2_WALL Then
                If fuw_gen_random( 100 ) < UB_DUN_ROOM_DOORS Then
                    s_gen_place_door( y , x )
                Else
                    ' these have to be doorways to rooms
                    s_gen_set_feature( y , x , UB_TILE_CORR_FLOOR )
                End If
            End If
        Next
    End If
End Sub


'##################################################################################################################################
' --- finishing the level ---

Sub s_gen_place_streamer( pub_rock As UByte , pub_treasure_chance As UByte )
    ' runs a vein of magma or quartz through the granite, in a straight line from near the middle to the edge of the level,
    ' with the odd bit of treasure in it, Moria's dungeonPlaceStreamerRock()
    Dim lsw_y , lsw_x , lsw_spot_y , lsw_spot_x     As Integer
    Dim lsw_dir_y , lsw_dir_x                       As Integer
    Dim luw_dir , luw_t1 , luw_t2                   As UInteger
    Dim i                                           As UByte

    ' choose the starting point and the direction, the directions are those of a numeric keypad, 1 to 4 and 6 to 9
    lsw_y   = Cast( Integer , gub_dungeon_rows >> 1 ) + 11 - Cast( Integer , fuw_gen_random( 23 ) )
    lsw_x   = Cast( Integer , gub_dungeon_cols >> 1 ) + 16 - Cast( Integer , fuw_gen_random( 33 ) )
    luw_dir = fuw_gen_random( 8 )
    If luw_dir > 4 Then luw_dir = luw_dir + 1
    lsw_dir_y = 1 - Cast( Integer , ( luw_dir - 1 ) / 3 )           ' 1, 2, 3 go down, 7, 8, 9 go up
    lsw_dir_x = Cast( Integer , ( luw_dir - 1 ) Mod 3 ) - 1         ' 1, 4, 7 go left, 3, 6, 9 go right

    luw_t1 = 2 * UB_DUN_STREAMER_WIDTH + 1
    luw_t2 = UB_DUN_STREAMER_WIDTH + 1

    Do
        For i = 1 To UB_DUN_STREAMER_DENSITY
            lsw_spot_y = lsw_y + Cast( Integer , fuw_gen_random( luw_t1 ) ) - Cast( Integer , luw_t2 )
            lsw_spot_x = lsw_x + Cast( Integer , fuw_gen_random( luw_t1 ) ) - Cast( Integer , luw_t2 )
            If fub_gen_in_bounds( lsw_spot_y , lsw_spot_x ) Then
                If fub_gen_feature( lsw_spot_y , lsw_spot_x ) = UB_TILE_GRANITE_WALL Then
                    s_gen_set_feature( lsw_spot_y , lsw_spot_x , pub_rock )
                    If fuw_gen_random( pub_treasure_chance ) = 1 Then s_gen_place_gold( lsw_spot_y , lsw_spot_x )
                End If
            End If
        Next

        ' one step on, and stop when that would leave the level
        lsw_y = lsw_y + lsw_dir_y
        lsw_x = lsw_x + lsw_dir_x
        If lsw_y < 0 Or lsw_x < 0 Then Exit Do
        If lsw_y >= Cast( Integer , gub_dungeon_rows ) Or lsw_x >= Cast( Integer , gub_dungeon_cols ) Then Exit Do
    Loop
End Sub


Function fub_gen_corridors_next_to( pub_row As UByte , pub_col As UByte ) As UByte
    ' how many of the nine squares here and around are corridor without a door on them, Moria's coordCorridorWallsNextTo()
    Dim y , x , lub_count , lub_item    As UByte
    Dim luw_square                      As UInteger

    lub_count = 0
    For y = pub_row - 1 To pub_row + 1
        For x = pub_col - 1 To pub_col + 1
            luw_square = fuw_core_map_square( gub_level_map_page , y , x )
            If Peek( luw_square ) = UB_TILE_CORR_FLOOR Then
                lub_item = Peek( luw_square + UB_SQUARE_ITEM )
                If lub_item = 0 Then
                    lub_count = lub_count + 1
                ElseIf Peek( fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item ) + UB_ITEM_CATEGORY_OFFSET ) < UB_TV_MIN_DOORS Then
                    lub_count = lub_count + 1
                End If
            End If
        Next
    Next
    Return lub_count
End Function


Function fub_gen_is_next_to( pub_row As UByte , pub_col As UByte ) As UByte
    ' true if this is a place where a door would make sense: corridors meet here, and there is wall on both sides, Moria's dungeonIsNextTo()
    If fub_gen_corridors_next_to( pub_row , pub_col ) > 2 Then
        If fub_gen_feature( pub_row - 1 , pub_col ) >= UB_TILE_MIN_WALL And fub_gen_feature( pub_row + 1 , pub_col ) >= UB_TILE_MIN_WALL Then Return true
        If fub_gen_feature( pub_row , pub_col - 1 ) >= UB_TILE_MIN_WALL And fub_gen_feature( pub_row , pub_col + 1 ) >= UB_TILE_MIN_WALL Then Return true
    End If
    Return false
End Function


Sub s_gen_try_door( pub_row As UByte , pub_col As UByte )
    ' puts a door on a corridor square if it suits one, and if chance allows, Moria's dungeonPlaceDoorIfNextToTwoWalls()
    If fub_gen_feature( pub_row , pub_col ) = UB_TILE_CORR_FLOOR Then
        If fuw_gen_random( 100 ) > UB_DUN_TUNNEL_DOORS Then
            If fub_gen_is_next_to( pub_row , pub_col ) Then s_gen_place_door( pub_row , pub_col )
        End If
    End If
End Sub


'##################################################################################################################################
' --- the stage itself ---

Sub s_stage_create_dungeon()
    Dim lub_row_rooms , lub_col_rooms , lub_row , lub_col   As UByte
    Dim lub_y , lub_x , lub_swap                            As UByte
    Dim lsw_room_count , lsw_i                              As Integer
    Dim luw_locations , luw_i , luw_pick1 , luw_pick2       As UInteger
    Dim luw_alloc_level                                     As UInteger

    s_core_clear_screen()
    s_core_print_string_at( 14 , 30 , "Making dungeon level " + fs_core_number( guw_dungeon_level ) , UB_BRIGHT_WHITE )

    ' the working lists live in the corridor scratchpad page, which stays in MMU 0 for the whole of this stage
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )

    ' Moria's generateCave(): an empty item list, an empty map of full size
    gub_level_map_page    = UB_PAGE_DUNGEON_MAP
    gub_level_items_page  = UB_PAGE_DUNGEON_ITEMS
    gub_dungeon_item_next = 1
    gub_level_monsters_page  = UB_PAGE_DUNGEON_MONSTERS
    gub_dungeon_monster_next = UB_MON_MIN_INDEX
    gsw_game_multiply_total  = 0
    gub_dungeon_rows      = UW_MAP_ROWS
    gub_dungeon_cols      = UW_MAP_COLS
    s_gen_progress( "clearing" )
    s_gen_blank_level()

    ' --- from here on it is Moria's dungeonGenerate() ---
    ' rooms go on a grid of half screens, 6 by 6 for a full size level, first choose which places on the grid get one
    s_gen_progress( "rooms" )
    lub_row_rooms = 2 * ( gub_dungeon_rows / UB_DUN_SCREEN_ROWS )
    lub_col_rooms = 2 * ( gub_dungeon_cols / UB_DUN_SCREEN_COLS )
    For luw_i = 0 To 399
        Poke A_GEN_ROOM_MAP + luw_i , false
    Next
    lsw_room_count = fsw_core_random_normal( UB_DUN_ROOMS_MEAN , 2 )
    For lsw_i = 1 To lsw_room_count
        lub_row = fuw_gen_random( lub_row_rooms ) - 1
        lub_col = fuw_gen_random( lub_col_rooms ) - 1
        Poke A_GEN_ROOM_MAP + Cast( UInteger , lub_row ) * 20 + lub_col , true
    Next

    ' build the rooms
    luw_locations = 0
    For lub_row = 0 To lub_row_rooms - 1
        For lub_col = 0 To lub_col_rooms - 1
            If Peek( A_GEN_ROOM_MAP + Cast( UInteger , lub_row ) * 20 + lub_col ) Then
                lub_y = lub_row * ( UB_DUN_SCREEN_ROWS >> 1 ) + ( UB_DUN_SCREEN_ROWS / 4 )
                lub_x = lub_col * ( UB_DUN_SCREEN_COLS >> 1 ) + ( UB_DUN_SCREEN_COLS / 4 )
                Poke A_GEN_LOCATIONS + luw_locations * 2     , lub_y
                Poke A_GEN_LOCATIONS + luw_locations * 2 + 1 , lub_x
                If guw_dungeon_level > fuw_gen_random( UW_DUN_UNUSUAL_ROOMS ) Then
                    luw_i = fuw_gen_random( 3 )
                    If luw_i = 1 Then
                        s_gen_build_room( lub_y , lub_x , true )
                    Else
                        ' a room with inner rooms, or a cross shaped room, the rooms library builds them, with whatever
                        ' monsters, traps and treasure they have inside
                        gub_lib_param_1 = lub_y
                        guw_lib_param_2 = lub_x
                        If luw_i = 2 Then
                            s_core_call_library( UB_PAGED_CODE_LIB_ROOMS , UB_LIB_ROOMS_INNER )
                        Else
                            s_core_call_library( UB_PAGED_CODE_LIB_ROOMS , UB_LIB_ROOMS_CROSS )
                        End If
                    End If
                Else
                    s_gen_build_room( lub_y , lub_x , false )
                End If
                luw_locations = luw_locations + 1
            End If
        Next
    Next

    ' shuffle the rooms, so that the tunnels join them up in no particular order
    For luw_i = 1 To luw_locations
        luw_pick1 = fuw_gen_random( luw_locations ) - 1
        luw_pick2 = fuw_gen_random( luw_locations ) - 1
        lub_swap = Peek( A_GEN_LOCATIONS + luw_pick1 * 2 )
        Poke A_GEN_LOCATIONS + luw_pick1 * 2 , Peek( A_GEN_LOCATIONS + luw_pick2 * 2 )
        Poke A_GEN_LOCATIONS + luw_pick2 * 2 , lub_swap
        lub_swap = Peek( A_GEN_LOCATIONS + luw_pick1 * 2 + 1 )
        Poke A_GEN_LOCATIONS + luw_pick1 * 2 + 1 , Peek( A_GEN_LOCATIONS + luw_pick2 * 2 + 1 )
        Poke A_GEN_LOCATIONS + luw_pick2 * 2 + 1 , lub_swap
    Next

    ' a tunnel from each room to the one before it, with the first room copied to the end so that the last tunnel closes the ring
    s_gen_progress( "tunnels" )
    guw_gen_door_count = 0
    Poke A_GEN_LOCATIONS + luw_locations * 2     , Peek( A_GEN_LOCATIONS )
    Poke A_GEN_LOCATIONS + luw_locations * 2 + 1 , Peek( A_GEN_LOCATIONS + 1 )
    If luw_locations > 0 Then
        For luw_i = 0 To luw_locations - 1
            s_gen_build_tunnel( Peek( A_GEN_LOCATIONS + luw_i * 2 + 2 ) , Peek( A_GEN_LOCATIONS + luw_i * 2 + 3 ) , Peek( A_GEN_LOCATIONS + luw_i * 2 ) , Peek( A_GEN_LOCATIONS + luw_i * 2 + 1 ) )
        Next
    End If

    ' rock everywhere else, with veins of magma and quartz through it
    s_gen_progress( "rock" )
    s_gen_fill_empty_with( UB_TILE_GRANITE_WALL )
    For luw_i = 1 To UB_DUN_MAGMA_STREAMER
        s_gen_place_streamer( UB_TILE_MAGMA_WALL , UB_DUN_MAGMA_TREASURE )
    Next
    For luw_i = 1 To UB_DUN_QUARTZ_STREAMER
        s_gen_place_streamer( UB_TILE_QUARTZ_WALL , UB_DUN_QUARTZ_TREASURE )
    Next
    s_gen_place_boundary_walls()

    ' doors where tunnels met, on each of the four squares around the meeting place
    s_gen_progress( "doors" )
    If guw_gen_door_count > 0 Then
        For luw_i = 0 To guw_gen_door_count - 1
            lub_y = Peek( A_GEN_DOORS + luw_i * 2 )
            lub_x = Peek( A_GEN_DOORS + luw_i * 2 + 1 )
            s_gen_try_door( lub_y , lub_x - 1 )
            s_gen_try_door( lub_y , lub_x + 1 )
            s_gen_try_door( lub_y - 1 , lub_x )
            s_gen_try_door( lub_y + 1 , lub_x )
        Next
    End If

    luw_alloc_level = guw_dungeon_level / 3
    If luw_alloc_level < 2 Then luw_alloc_level = 2
    If luw_alloc_level > 10 Then luw_alloc_level = 10

    ' three or four ways down, one or two ways up, and somewhere for the player to arrive
    s_gen_progress( "stairs" )
    s_gen_place_stairs( true , fuw_gen_random( 2 ) + 2 , 3 )
    s_gen_place_stairs( false , fuw_gen_random( 2 ) , 3 )
    s_gen_new_spot()

    ' the monsters, all asleep to begin with, the monsters library does it
    s_gen_progress( "monsters" )
    guw_lib_param_2 = fuw_gen_random( 8 ) + UB_MON_MIN_PER_LEVEL + luw_alloc_level
    gub_lib_param_1 = 0
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_PLACE_ASLEEP )

    ' what lies about the level: objects in the rooms, objects anywhere, and gold, the objects library does it
    s_gen_progress( "objects" )
    guw_lib_param_2 = luw_alloc_level
    s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_LEVEL )

    ' deep enough, and one of the two end game creatures is here somewhere, Evil Iggy or the Balrog
    If guw_dungeon_level >= UB_MON_ENDGAME_LEVEL Then s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_PLACE_WINNING )
End Sub
