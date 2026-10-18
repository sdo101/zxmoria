#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_create_town()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-level-include.bas"

' this stage makes the town, level 0, it is Moria's townGeneration() (dungeon_generate.cpp) routine for routine...
' ...the town is laid out from the game's fixed "town seed", so it is the same town every time it is visited in one game,
' six stores in two rows of three, each a block of solid wall with one door, and a single staircase down
' the town has its own map and its own item list, apart from the dungeon's, see the page plan in constants.bas
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing, the townspeople are put down by the monsters library, stage-lib-monsters.bas


Sub s_town_build_store( pub_store As UByte , pub_y As UByte , pub_x As UByte )
    ' builds one store in one of the six plots, pub_y is the row of plots (0 or 1) and pub_x the plot along it (0 to 2),
    ' Moria's dungeonBuildStore(): a block of wall that can never be dug, of a random size, with a door at a random
    ' place on one of its four sides, the door is an item, a different one for each store
    Dim lub_yval , lub_xval , lub_height , lub_depth , lub_left , lub_right As UByte
    Dim y , x , lub_number                                                  As UByte
    Dim luw_side                                                            As UInteger

    lub_yval   = pub_y * 10 + 5
    lub_xval   = pub_x * 16 + 16
    lub_height = lub_yval - fuw_gen_random( 3 )
    lub_depth  = lub_yval + fuw_gen_random( 4 )
    lub_left   = lub_xval - fuw_gen_random( 6 )
    lub_right  = lub_xval + fuw_gen_random( 6 )

    For y = lub_height To lub_depth
        For x = lub_left To lub_right
            s_gen_set_feature( y , x , UB_TILE_BOUNDARY_WALL )
        Next
    Next

    ' which side the door is on: 1 left, 2 right, 3 bottom, 4 top, and how far along it
    luw_side = fuw_gen_random( 4 )
    If luw_side < 3 Then
        y = fuw_gen_random( lub_depth - lub_height ) + lub_height - 1
        If luw_side = 1 Then
            x = lub_left
        Else
            x = lub_right
        End If
    Else
        x = fuw_gen_random( lub_right - lub_left ) + lub_left - 1
        If luw_side = 3 Then
            y = lub_depth
        Else
            y = lub_height
        End If
    End If

    s_gen_set_feature( y , x , UB_TILE_CORR_FLOOR )
    lub_number = fub_gen_new_item( UW_OBJ_STORE_DOOR + pub_store )
    s_gen_put_item( y , x , lub_number )
End Sub


Sub s_town_place_stores()
    ' puts the six stores into the six plots in a random order, Moria's dungeonPlaceTownStores()...
    ' ...the stores not yet placed are a short list, kept in the text buffer, one is picked and taken out of the list each time
    Dim i , y , x , lub_count , lub_pick As UByte

    For i = 0 To 5
        Poke A_TEXT_BUFFER + i , i
    Next
    lub_count = 6
    For y = 0 To 1
        For x = 0 To 2
            lub_pick = fuw_gen_random( lub_count ) - 1
            s_town_build_store( Peek( A_TEXT_BUFFER + lub_pick ) , y , x )
            i = lub_pick
            While i < lub_count - 1
                Poke A_TEXT_BUFFER + i , Peek( A_TEXT_BUFFER + i + 1 )
                i = i + 1
            End While
            lub_count = lub_count - 1
        Next
    Next
End Sub


Sub s_town_light()
    ' lights the town, Moria's lightTown(): by day every square is lit, by night only the buildings are,
    ' day and night change every 5000 game turns
    ' N.B: a whole row of squares is in one page, so each row is found once and then stepped along, 8 bytes to a square
    Dim y , x , lub_night   As UByte
    Dim luw_square          As UInteger

    lub_night = Cast( UByte , gsl_game_turn / 5000 ) bAnd 1
    For y = 0 To gub_dungeon_rows - 1
        luw_square = fuw_core_map_square( gub_level_map_page , y , 0 )
        For x = 0 To gub_dungeon_cols - 1
            If lub_night = 0 Or Peek( luw_square ) <> UB_TILE_DARK_FLOOR Then
                Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bOr MB_SQUARE_PERM_LIGHT
            End If
            luw_square = luw_square + UB_MAP_SQUARE_SIZE
        Next
    Next

    ' the townspeople, more of them by night, none within 3 squares of the player, all asleep to begin with
    guw_lib_param_2 = UB_MON_MIN_TOWNSFOLK_DAY
    If lub_night Then guw_lib_param_2 = UB_MON_MIN_TOWNSFOLK_NIGHT
    gub_lib_param_1 = 3
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_PLACE_ASLEEP )
End Sub


Sub s_stage_create_town()
    s_core_clear_screen()
    s_core_print_string_at( 14 , 30 , "Making the town" , UB_BRIGHT_WHITE )

    ' Moria's generateCave() for level 0: an empty item list, and an empty map the size of one of Moria's screens
    gub_level_map_page      = UB_PAGE_TOWN_MAP
    gub_level_items_page    = UB_PAGE_TOWN_ITEMS
    gub_level_monsters_page = UB_PAGE_TOWN_MONSTERS
    gub_dungeon_item_next   = 1
    gub_dungeon_monster_next = UB_MON_MIN_INDEX
    gsw_game_multiply_total  = 0
    gub_dungeon_rows        = UB_TOWN_ROWS
    gub_dungeon_cols        = UB_TOWN_COLS
    s_gen_blank_level()

    ' --- from here on it is Moria's townGeneration() ---
    ' the layout comes from the town seed, so that it is the same every visit, the generator's own state is put aside
    ' meanwhile and picked up again afterwards, Moria's seedSet() and seedResetToOldSeed()
    gul_game_old_seed = gul_game_random_seed
    s_core_random_seed( gul_game_town_seed )

    s_town_place_stores()
    s_gen_fill_empty_with( UB_TILE_DARK_FLOOR )
    ' the stairs are made before the seed is put back, so that they do not move around
    s_gen_place_boundary_walls()
    s_gen_place_stairs( true , 1 , 0 )

    s_core_random_seed( gul_game_old_seed )

    ' somewhere for the player to arrive, this does change from visit to visit
    s_gen_new_spot()
    s_town_light()

    ' every store sells some of its stock off and buys some in, each time the town is made
    s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_MAINTAIN )
End Sub