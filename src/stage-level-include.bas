' routines shared by the stages that make a level, stage-create-dungeon.bas and stage-create-town.bas...
' ...each stage includes this file, so each has its own copy of whichever of these it uses, the compiler leaves out the rest
' N.B: a stage cannot call into another stage, which is why these are not simply in one of them
' N.B: none of these says which map or which item list it works on, they all use the level's own pages, which the stage
' sets up first: gub_level_map_page and gub_level_items_page (see globals.bas), so the same code makes a dungeon level or the town

Function fuw_gen_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_gen_feature( pub_row As UByte , pub_col As UByte ) As UByte
    Return Peek( fuw_core_map_square( gub_level_map_page , pub_row , pub_col ) )
End Function


Sub s_gen_set_feature( pub_row As UByte , pub_col As UByte , pub_feature As UByte )
    Poke fuw_core_map_square( gub_level_map_page , pub_row , pub_col ) , pub_feature
End Sub


Function fub_gen_new_item( puw_object As UInteger ) As UByte
    ' makes a new item of the given kind in the working item, and returns the number it will have on this level...
    ' ...the caller changes anything it wants to in the working item, then calls s_gen_put_item() to put it on the map
    ' this is Moria's popt() followed by inventoryItemCopyTo()
    Dim i           As UByte
    Dim lub_number  As UByte

    ' when the list is full distant items are thrown away to make room, the compact library, Moria's compactObjects()
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_OBJECTS )
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then Return 0
    lub_number            = gub_dungeon_item_next
    gub_dungeon_item_next = gub_dungeon_item_next + 1

    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , puw_object , A_OBJECT )
    For i = 0 To 31
        Poke A_ITEM + i , 0             ' no special name, nothing known about it, no inscription
    Next
    s_core_ram_copy( A_OBJECT + UB_ITEM_OBJECT_FIELDS , A_ITEM + UB_ITEM_OBJECT_FIELDS , UB_RECORD_SIZE - UB_ITEM_OBJECT_FIELDS )
    guw_item_object = puw_object
    Return lub_number
End Function


Sub s_gen_put_item( pub_row As UByte , pub_col As UByte , pub_number As UByte )
    ' stores the working item in the level's item list under the given number, and puts it on a square of the map
    If pub_number = 0 Then Return
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , pub_number , A_ITEM )
    Poke fuw_core_map_square( gub_level_map_page , pub_row , pub_col ) + UB_SQUARE_ITEM , pub_number
End Sub


Sub s_gen_place_gold( pub_row As UByte , pub_col As UByte )
    ' Moria's dungeonPlaceGold(): which of the 18 kinds of gold and gems depends on how deep we are
    Dim lub_number      As UByte
    Dim luw_type        As UInteger

    luw_type = ( ( fuw_gen_random( guw_dungeon_level + 2 ) + 2 ) / 2 ) - 1
    If fuw_gen_random( UB_DUN_GREAT_ITEM ) = 1 Then luw_type = luw_type + fuw_gen_random( guw_dungeon_level + 1 )
    If luw_type >= UB_OBJ_GOLD_TYPES Then luw_type = UB_OBJ_GOLD_TYPES - 1

    lub_number    = fub_gen_new_item( UW_OBJ_GOLD_LIST + luw_type )
    gsl_item_cost = gsl_item_cost + 8 * Cast( Long , ful_core_random_number( Cast( ULong , gsl_item_cost ) ) )
    gsl_item_cost = gsl_item_cost + Cast( Long , fuw_gen_random( 8 ) )
    s_gen_put_item( pub_row , pub_col , lub_number )
End Sub


Sub s_gen_set_room_square( pub_row As UByte , pub_col As UByte , pub_feature As UByte )
    ' sets what a square is made of, and marks it as part of a lit room
    Dim luw_square As UInteger

    luw_square = fuw_core_map_square( gub_level_map_page , pub_row , pub_col )
    Poke luw_square , pub_feature
    Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bOr MB_SQUARE_LIT_ROOM
End Sub


Function fub_gen_in_bounds( psw_row As Integer , psw_col As Integer ) As UByte
    ' true if the square is inside the level and not on its edge, Moria's coordInBounds()
    If psw_row < 1 Then Return false
    If psw_col < 1 Then Return false
    If psw_row >= Cast( Integer , gub_dungeon_rows ) - 1 Then Return false
    If psw_col >= Cast( Integer , gub_dungeon_cols ) - 1 Then Return false
    Return true
End Function


Function fub_gen_floor_tile() As UByte
    ' a lit or a dark floor, the deeper the level the more often dark, Moria's dungeonFloorTileForLevel()
    If guw_dungeon_level <= fuw_gen_random( 25 ) Then Return UB_TILE_LIGHT_FLOOR
    Return UB_TILE_DARK_FLOOR
End Function


Sub s_gen_place_door_of( pub_row As UByte , pub_col As UByte , puw_object As UInteger , pub_feature As UByte , psw_misc_use As Integer )
    ' puts one particular kind of door on a square, psw_misc_use is how hard it is to open (0 for the object's own value)
    Dim lub_number As UByte

    lub_number = fub_gen_new_item( puw_object )
    If psw_misc_use <> 0 Then gsw_item_misc_use = psw_misc_use
    s_gen_put_item( pub_row , pub_col , lub_number )
    s_gen_set_feature( pub_row , pub_col , pub_feature )
End Sub


Sub s_gen_fill_empty_with( pub_rock As UByte )
    ' turns every square that is still nothing, or still marked as temporary wall, into rock, Moria's dungeonFillEmptyTilesWith()
    ' N.B: a whole row of squares is in one page, so each row is found once and then stepped along, 8 bytes to a square
    Dim y , j , lub_feature     As UByte
    Dim luw_square              As UInteger

    For y = gub_dungeon_rows - 2 To 1 Step -1
        luw_square = fuw_core_map_square( gub_level_map_page , y , 1 )
        For j = 1 To gub_dungeon_cols - 2
            lub_feature = Peek( luw_square )
            If lub_feature = UB_TILE_NULL_WALL Or lub_feature = UB_TILE_TMP1_WALL Or lub_feature = UB_TILE_TMP2_WALL Then Poke luw_square , pub_rock
            luw_square = luw_square + UB_MAP_SQUARE_SIZE
        Next
    Next
End Sub


Sub s_gen_place_boundary_walls()
    ' puts rock that can never be dug around the edge of the level, Moria's dungeonPlaceBoundaryWalls()
    Dim i As UByte

    For i = 0 To gub_dungeon_rows - 1
        s_gen_set_feature( i , 0 , UB_TILE_BOUNDARY_WALL )
        s_gen_set_feature( i , gub_dungeon_cols - 1 , UB_TILE_BOUNDARY_WALL )
    Next
    For i = 0 To gub_dungeon_cols - 1
        s_gen_set_feature( 0 , i , UB_TILE_BOUNDARY_WALL )
        s_gen_set_feature( gub_dungeon_rows - 1 , i , UB_TILE_BOUNDARY_WALL )
    Next
End Sub


Function fub_gen_walls_next_to( pub_row As UByte , pub_col As UByte ) As UByte
    ' how many of the four squares beside this one are wall, Moria's coordWallsNextTo()
    Dim lub_walls As UByte = 0

    If fub_gen_feature( pub_row - 1 , pub_col ) >= UB_TILE_MIN_WALL Then lub_walls = lub_walls + 1
    If fub_gen_feature( pub_row + 1 , pub_col ) >= UB_TILE_MIN_WALL Then lub_walls = lub_walls + 1
    If fub_gen_feature( pub_row , pub_col - 1 ) >= UB_TILE_MIN_WALL Then lub_walls = lub_walls + 1
    If fub_gen_feature( pub_row , pub_col + 1 ) >= UB_TILE_MIN_WALL Then lub_walls = lub_walls + 1
    Return lub_walls
End Function


Sub s_gen_place_stairs( pub_down As UByte , puw_number As UInteger , psb_walls As Byte )
    ' puts down a number of staircases, each somewhere open with at least psb_walls walls beside it, so that they tend
    ' to end up in corners and dead ends, Moria's dungeonPlaceStairs()...
    ' ...a 12 by 12 patch of the level is picked at random and searched, after 30 patches without luck one wall fewer will do
    Dim luw_i                                   As UInteger
    Dim lub_placed , lub_tries , lub_number     As UByte
    Dim lub_y1 , lub_x1 , lub_y2 , lub_x2       As UByte
    Dim luw_square                              As UInteger

    If puw_number = 0 Then Return
    For luw_i = 1 To puw_number
        lub_placed = false
        While lub_placed = false
            lub_tries = 0
            Do
                lub_y1 = fuw_gen_random( gub_dungeon_rows - 14 )
                lub_x1 = fuw_gen_random( gub_dungeon_cols - 14 )
                lub_y2 = lub_y1 + 12
                lub_x2 = lub_x1 + 12
                Do
                    Do
                        luw_square = fuw_core_map_square( gub_level_map_page , lub_y1 , lub_x1 )
                        If Peek( luw_square ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then
                            If Cast( Byte , fub_gen_walls_next_to( lub_y1 , lub_x1 ) ) >= psb_walls Then
                                lub_placed = true
                                If pub_down Then
                                    lub_number = fub_gen_new_item( UW_OBJ_DOWN_STAIR )
                                Else
                                    lub_number = fub_gen_new_item( UW_OBJ_UP_STAIR )
                                End If
                                s_gen_put_item( lub_y1 , lub_x1 , lub_number )
                            End If
                        End If
                        lub_x1 = lub_x1 + 1
                    Loop Until lub_x1 = lub_x2 Or lub_placed
                    lub_x1 = lub_x2 - 12
                    lub_y1 = lub_y1 + 1
                Loop Until lub_y1 = lub_y2 Or lub_placed
                lub_tries = lub_tries + 1
            Loop Until lub_placed Or lub_tries > 30
            psb_walls = psb_walls - 1
        End While
    Next
End Sub


Sub s_gen_new_spot()
    ' finds somewhere open and empty for the player to start, Moria's dungeonNewSpot()
    Dim lub_y , lub_x   As UByte
    Dim luw_square      As UInteger
    Dim lub_found       As UByte = false

    Do
        lub_y = fuw_gen_random( gub_dungeon_rows - 2 )
        lub_x = fuw_gen_random( gub_dungeon_cols - 2 )
        luw_square = fuw_core_map_square( gub_level_map_page , lub_y , lub_x )
        If Peek( luw_square ) < UB_TILE_MIN_CLOSED Then
            If Peek( luw_square + UB_SQUARE_MONSTER ) = 0 And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then lub_found = true
        End If
    Loop Until lub_found
    gub_player_row = lub_y
    gub_player_col = lub_x
End Sub


Sub s_gen_blank_level()
    ' wipes the level's map, a page at a time, as many pages as the level has rows, Moria's dungeonBlankEntireCave()
    Dim lub_page As UByte

    For lub_page = 0 To ( ( gub_dungeon_rows - 1 ) >> UB_MAP_ROWS_SHIFT )
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , gub_level_map_page + lub_page )
        Asm
            ld hl, A_MMU_SLOT_PAGED_DB_MAPS
            ld de, A_MMU_SLOT_PAGED_DB_MAPS + 1
            ld bc, 8191
            ld (hl), 0
            ldir
        End Asm
    Next
End Sub


Sub s_gen_progress( ps_text As String )
    s_core_print_string_at( 16 , 30 , ps_text + "          " , UB_WHITE )
End Sub
