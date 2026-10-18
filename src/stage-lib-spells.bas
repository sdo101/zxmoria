#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_spells()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-monster-include.bas"
#include "stage-level-include.bas"

' this page is a LIBRARY, not a stage: the spells that work on the map around the player, light, detection, moving
' about and making things, which scrolls, staffs, spell books and prayers all share, from Moria's spells.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SPELLS , <which routine> ), each leaves
' true in gsw_lib_result if the player noticed anything, which is how they come to know what a scroll is, and each
' draws the squares it changes, anything more the walking stage must do is asked for in gub_game_turn_flags, the
' MB_TURN_ bits in constants.bas, the routines are:
'
'   UB_LIB_SPELLS_LIGHT_AREA        lights the squares around the player, and the room they are in, spellLightArea()
'   UB_LIB_SPELLS_DARKEN_AREA       the opposite, spellDarkenArea()
'   UB_LIB_SPELLS_MAP_AREA          shows the walls, doors and stairs of what is on the screen and a little
'                                   beyond it, spellMapCurrentArea()
'   UB_LIB_SPELLS_DETECT_TREASURE   shows the gold on the screen, spellDetectTreasureWithinVicinity()
'   UB_LIB_SPELLS_DETECT_OBJECTS    shows the things lying about on the screen, spellDetectObjectsWithinVicinity()
'   UB_LIB_SPELLS_DETECT_TRAPS      shows the traps on the screen, spellDetectTrapsWithinVicinity()
'   UB_LIB_SPELLS_DETECT_DOORS      shows the secret doors and stairs on the screen, spellDetectSecretDoorssWithinVicinity()
'   UB_LIB_SPELLS_DETECT_INVISIBLE  shows the invisible creatures on the screen, for a moment,
'                                   spellDetectInvisibleCreaturesWithinVicinity()
'   UB_LIB_SPELLS_TELEPORT          the player goes somewhere open within guw_lib_param_2 squares, playerTeleport()
'   UB_LIB_SPELLS_GLYPH             a rune of protection under the player, spellWardingGlyph()
'   UB_LIB_SPELLS_CREATE_FOOD       a mushroom under the player, spellCreateFood()
'   UB_LIB_SPELLS_TRAPS             a trap on every open square round the player, spellSurroundPlayerWithTraps()
'   UB_LIB_SPELLS_DOORS             a door on every open square round the player, spellSurroundPlayerWithDoors()
'   UB_LIB_SPELLS_DESTROY_DOORS     the doors and traps round the player go, spellDestroyAdjacentDoorsTraps()
'   UB_LIB_SPELLS_DESTROY_AREA      everything within 15 squares is laid waste, spellDestroyArea()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of


Function fuw_sp_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_sp_visible( puw_square As UInteger ) As UByte
    ' true if what is on a square of the map shows, Moria's caveTileVisible()
    If ( Peek( puw_square + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then Return true
    Return false
End Function


Sub s_sp_set_flag( pub_y As UByte , pub_x As UByte , pub_flag As UByte )
    ' sets one of the MB_SQUARE_ flags on a square
    Dim luw_square As UInteger

    luw_square = fuw_cr_square( pub_y , pub_x ) + UB_SQUARE_FLAGS
    Poke luw_square , Peek( luw_square ) bOr pub_flag
End Sub


Sub s_sp_delete_object( pub_y As UByte , pub_x As UByte )
    ' whatever is on a square goes, Moria's dungeonDeleteObject(), the moves library keeps the level's list of items
    gub_lib_param_1 = pub_y
    guw_lib_param_2 = pub_x
    s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT )
End Sub


'##################################################################################################################################
' --- light ---

Function fub_sp_light_area() As UByte
    ' Moria's spellLightArea()
    Dim y , x As UByte

    If gsw_player_blind < 1 Then s_core_message( UW_MSG_YOU_ARE_SURROUNDED_BY_A_WHITE )
    ' NOTE: this is not changed anywhere, a bug or correct?
    If ( Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_LIT_ROOM ) <> 0 And guw_dungeon_level > 0 Then
        ' the whole room, the walking stage knows how, Moria's dungeonLightRoom()
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_LIGHT_ROOM
    End If
    ' must always light immediate area, because one might be standing on the edge of a room, or next to a
    ' destroyed area, etc.
    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            s_sp_set_flag( y , x , MB_SQUARE_PERM_LIGHT )
            s_cr_put( y , x )
        Next
    Next
    Return true
End Function


Function fub_sp_darken_area() As UByte
    ' Moria's spellDarkenArea(): a lit room goes dark, anywhere else it is the corridor squares round the player
    Dim y , x , lub_top , lub_left  As UByte
    Dim luw_square                  As UInteger
    Dim lub_flags                   As UByte
    Dim lub_darkened                As UByte = false

    If ( Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_LIT_ROOM ) <> 0 And guw_dungeon_level > 0 Then
        lub_top  = ( gub_player_row / ( UB_VIEW_ROWS / 2 ) ) * ( UB_VIEW_ROWS / 2 ) + 1
        lub_left = ( gub_player_col / ( UB_VIEW_COLS / 2 ) ) * ( UB_VIEW_COLS / 2 ) + 1
        For y = lub_top To lub_top + UB_VIEW_ROWS / 2 - 1
            For x = lub_left To lub_left + UB_VIEW_COLS / 2 - 1
                luw_square = fuw_cr_square( y , x )
                lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
                If ( lub_flags bAnd MB_SQUARE_LIT_ROOM ) <> 0 And Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_BLOCKED_FLOOR Then
                    Poke luw_square + UB_SQUARE_FLAGS , lub_flags bAnd ( 255 - MB_SQUARE_PERM_LIGHT )
                    Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_DARK_FLOOR
                    s_cr_put( y , x )
                    If fub_sp_visible( fuw_cr_square( y , x ) ) = false Then lub_darkened = true
                End If
            Next
        Next
    Else
        For y = gub_player_row - 1 To gub_player_row + 1
            For x = gub_player_col - 1 To gub_player_col + 1
                luw_square = fuw_cr_square( y , x )
                lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
                If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_CORR_FLOOR And ( lub_flags bAnd MB_SQUARE_PERM_LIGHT ) <> 0 Then
                    ' the square could still be lit by the player's own light, so it is not drawn again here
                    Poke luw_square + UB_SQUARE_FLAGS , lub_flags bAnd ( 255 - MB_SQUARE_PERM_LIGHT )
                    lub_darkened = true
                End If
            Next
        Next
    End If
    If lub_darkened And gsw_player_blind < 1 Then s_core_message( UW_MSG_DARKNESS_SURROUNDS_YOU )
    Return lub_darkened
End Function


Sub s_sp_map_area()
    ' Moria's spellMapCurrentArea(), with its dungeonLightAreaAroundFloorTile(): round every square of floor on the
    ' screen, and for a random way beyond its edges, the walls are lit and the doors and stairs found
    Dim lsw_row_min , lsw_row_max , lsw_col_min , lsw_col_max   As Integer
    Dim lsw_y , lsw_x                                           As Integer
    Dim y , x , lub_item , lub_category                         As UByte
    Dim luw_square                                              As UInteger

    lsw_row_min = Cast( Integer , gub_panel_top ) - Cast( Integer , fuw_sp_random( 10 ) )
    lsw_row_max = Cast( Integer , gub_panel_bottom ) + Cast( Integer , fuw_sp_random( 10 ) )
    lsw_col_min = Cast( Integer , gub_panel_left ) - Cast( Integer , fuw_sp_random( 20 ) )
    lsw_col_max = Cast( Integer , gub_panel_right ) + Cast( Integer , fuw_sp_random( 20 ) )
    ' Moria's coordInBounds(): anywhere but the edge of the map
    If lsw_row_min < 1 Then lsw_row_min = 1
    If lsw_col_min < 1 Then lsw_col_min = 1
    If lsw_row_max > Cast( Integer , gub_dungeon_rows ) - 2 Then lsw_row_max = Cast( Integer , gub_dungeon_rows ) - 2
    If lsw_col_max > Cast( Integer , gub_dungeon_cols ) - 2 Then lsw_col_max = Cast( Integer , gub_dungeon_cols ) - 2

    For lsw_y = lsw_row_min To lsw_row_max
        For lsw_x = lsw_col_min To lsw_col_max
            If Peek( fuw_cr_square( lsw_y , lsw_x ) ) <= UB_TILE_BLOCKED_FLOOR Then
                For y = lsw_y - 1 To lsw_y + 1
                    For x = lsw_x - 1 To lsw_x + 1
                        luw_square = fuw_cr_square( y , x )
                        If Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_WALL Then
                            Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bOr MB_SQUARE_PERM_LIGHT
                        Else
                            lub_item = Peek( luw_square + UB_SQUARE_ITEM )
                            If lub_item <> 0 Then
                                lub_category = fub_cr_item_category( lub_item )
                                If lub_category >= UB_TV_VIS_TRAP And lub_category <= UB_TV_STORE_DOOR Then s_sp_set_flag( y , x , MB_SQUARE_FIELD_MARK )
                            End If
                        End If
                    Next
                Next
            End If
        Next
    Next
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
End Sub


'##################################################################################################################################
' --- detection ---

Function fub_sp_detect( pub_what As UByte ) As UByte
    ' Moria's spellDetectTreasureWithinVicinity(), spellDetectObjectsWithinVicinity(), spellDetectTrapsWithinVicinity()
    ' and spellDetectSecretDoorssWithinVicinity(): every square on the screen is looked at for the kind of thing wanted
    Dim y , x , lub_item , lub_category , lub_show  As UByte
    Dim luw_square , luw_record                     As UInteger
    Dim lub_detected                                As UByte = false

    For y = gub_panel_top To gub_panel_bottom
        For x = gub_panel_left To gub_panel_right
            If y < gub_dungeon_rows And x < gub_dungeon_cols Then
                luw_square = fuw_cr_square( y , x )
                lub_item   = Peek( luw_square + UB_SQUARE_ITEM )
                If lub_item <> 0 Then
                    lub_show     = false
                    luw_record   = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
                    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
                    If pub_what = UB_LIB_SPELLS_DETECT_TREASURE Then
                        If lub_category = UB_TV_GOLD And fub_sp_visible( luw_square ) = false Then lub_show = true
                    ElseIf pub_what = UB_LIB_SPELLS_DETECT_OBJECTS Then
                        If lub_category < UB_TV_MAX_OBJECT And fub_sp_visible( luw_square ) = false Then lub_show = true
                    ElseIf pub_what = UB_LIB_SPELLS_DETECT_TRAPS Then
                        If lub_category = UB_TV_INVIS_TRAP Then
                            ' Moria's trapChangeVisibility()
                            Poke luw_record + UB_ITEM_CATEGORY_OFFSET , UB_TV_VIS_TRAP
                            lub_show = true
                        End If
                        If lub_category = UB_TV_CHEST Then
                            ' a chest's traps become known, the chests library
                            gub_lib_param_1 = y
                            guw_lib_param_2 = x
                            s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_KNOW )
                        End If
                    Else
                        If lub_category = UB_TV_SECRET_DOOR Then
                            ' Moria's trapChangeVisibility(): the secret door becomes a closed one
                            s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_CLOSED_DOOR , A_OBJECT )
                            luw_record = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
                            Poke UInteger luw_record , UW_OBJ_CLOSED_DOOR
                            Poke luw_record + UB_ITEM_CATEGORY_OFFSET , Peek( A_OBJECT + UB_ITEM_CATEGORY_OFFSET )
                            Poke luw_record + UB_ITEM_SPRITE_OFFSET , Peek( A_OBJECT + UB_ITEM_SPRITE_OFFSET )
                            lub_show = true
                        ElseIf lub_category = UB_TV_UP_STAIR Or lub_category = UB_TV_DOWN_STAIR Then
                            If ( Peek( fuw_cr_square( y , x ) + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_FIELD_MARK ) = 0 Then lub_show = true
                        End If
                    End If
                    If lub_show Then
                        s_sp_set_flag( y , x , MB_SQUARE_FIELD_MARK )
                        s_cr_put( y , x )
                        lub_detected = true
                    End If
                End If
            End If
        Next
    Next
    Return lub_detected
End Function


Function fub_sp_detect_invisible() As UByte
    ' Moria's spellDetectInvisibleCreaturesWithinVicinity(): they show until the player has read the message
    Dim lub_monster     As UByte
    Dim luw_record      As UInteger
    Dim lub_detected    As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
        If fub_cr_inside_panel( Peek( luw_record + UB_MONSTER_ROW_OFFSET ) , Peek( luw_record + UB_MONSTER_COL_OFFSET ) ) Then
            s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
            If ( gul_creature_movement bAnd UL_CM_INVISIBLE ) <> 0 Then
                luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
                Poke luw_record + UB_MONSTER_LIT_OFFSET , 1
                s_cr_put( Peek( luw_record + UB_MONSTER_ROW_OFFSET ) , Peek( luw_record + UB_MONSTER_COL_OFFSET ) )
                lub_detected = true
            End If
        End If
    End While
    If lub_detected Then
        s_core_message( UW_MSG_YOU_SENSE_THE_PRESENCE_OF )
        s_msg_flush()
        ' must unlight every monster just lighted
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
    End If
    Return lub_detected
End Function


'##################################################################################################################################
' --- moving about ---

Sub s_sp_teleport( puw_distance As UInteger )
    ' Moria's playerTeleport(): somewhere on the level is picked at random and brought nearer, halving the gap,
    ' until it is within the distance, until that lands somewhere open and empty
    Dim lsw_y , lsw_x       As Integer
    Dim y , x               As UByte
    Dim luw_square          As UInteger
    Dim lub_found           As UByte

    Do
        lsw_y = Cast( Integer , fuw_sp_random( gub_dungeon_rows ) ) - 1
        lsw_x = Cast( Integer , fuw_sp_random( gub_dungeon_cols ) ) - 1
        While fub_mon_distance( lsw_y , lsw_x , gub_player_row , gub_player_col ) > puw_distance
            ' N.B: as C halves, towards nought, the gap is as often negative as not, see fsw_c_half()
            lsw_y = lsw_y + fsw_c_half( Cast( Integer , gub_player_row ) - lsw_y )
            lsw_x = lsw_x + fsw_c_half( Cast( Integer , gub_player_col ) - lsw_x )
        End While
        luw_square = fuw_cr_square( lsw_y , lsw_x )
        lub_found  = true
        If Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_CLOSED Then lub_found = false
        If Peek( luw_square + UB_SQUARE_MONSTER ) >= 2 Then lub_found = false
    Loop Until lub_found

    ' Moria's dungeonMoveCreatureRecord()
    Poke fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_MONSTER , 0
    Poke fuw_cr_square( lsw_y , lsw_x ) + UB_SQUARE_MONSTER , 1
    ' the player's own light goes from where they were
    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            luw_square = fuw_cr_square( y , x ) + UB_SQUARE_FLAGS
            Poke luw_square , Peek( luw_square ) bAnd ( 255 - MB_SQUARE_TEMP_LIGHT )
            s_cr_put( y , x )
        Next
    Next
    gub_player_row = lsw_y
    gub_player_col = lsw_x
    gub_player_temp_light_only = false
    ' the walking stage moves the window if it must, lights the player's new surroundings, and sees which monsters
    ' show, Moria's dungeonResetView() and updateMonsters()
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_RESET_VIEW bOr MB_TURN_UPDATE_MONSTERS
End Sub


'##################################################################################################################################
' --- making and unmaking things ---

Sub s_sp_new_item_at( pub_y As UByte , pub_x As UByte , puw_object As UInteger )
    ' a brand new item of the given kind on a square, Moria's popt() and inventoryItemCopyTo()
    Dim lub_number As UByte

    lub_number = fub_gen_new_item( puw_object )
    s_gen_put_item( pub_y , pub_x , lub_number )
End Sub


Sub s_sp_glyph()
    ' Moria's spellWardingGlyph()
    If Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM ) = 0 Then s_sp_new_item_at( gub_player_row , gub_player_col , UW_OBJ_SCARE_MON )
End Sub


Function fub_sp_create_food() As UByte
    ' Moria's spellCreateFood(): a mushroom appears under the player, false if there was something there already
    ' N.B: Moria makes a random object there first, magic and all, and then turns it into the mushroom, so do we,
    ' it uses the same random numbers that way
    Dim lub_item , i As UByte

    If Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM ) <> 0 Then
        s_core_message( UW_MSG_THERE_IS_ALREADY_AN_OBJECT_UNDER )
        Return false
    End If
    gub_lib_param_1 = gub_player_row
    guw_lib_param_2 = gub_player_col
    s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT )
    lub_item = Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
    If lub_item = 0 Then Return true            ' the level's list of items is full
    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_MUSH , A_OBJECT )
    For i = 0 To 31
        Poke A_ITEM + i , 0
    Next
    s_core_ram_copy( A_OBJECT + 32 , A_ITEM + 32 , 32 )
    guw_item_object = UW_OBJ_MUSH
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , lub_item , A_ITEM )
    Return true
End Function


Function fub_sp_surround( pub_doors As UByte ) As UByte
    ' Moria's spellSurroundPlayerWithTraps() and spellSurroundPlayerWithDoors(): every open square beside the
    ' player gets a trap, or a closed door, in place of whatever was on it
    Dim y , x , lub_item    As UByte
    Dim luw_square          As UInteger
    Dim lub_created         As UByte = false

    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            If y <> gub_player_row Or x <> gub_player_col Then
                luw_square = fuw_cr_square( y , x )
                If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_BLOCKED_FLOOR Then
                    If Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then s_sp_delete_object( y , x )
                    If pub_doors Then
                        Poke fuw_cr_square( y , x ) + UB_SQUARE_FEATURE , UB_TILE_BLOCKED_FLOOR
                        s_sp_new_item_at( y , x , UW_OBJ_CLOSED_DOOR )
                    Else
                        s_sp_new_item_at( y , x , UW_OBJ_TRAP_LIST + fuw_sp_random( UB_OBJ_MAX_TRAPS ) - 1 )
                        ' don't let player gain exp from the newly created traps
                        lub_item = Peek( fuw_cr_square( y , x ) + UB_SQUARE_ITEM )
                        If lub_item <> 0 Then Poke UInteger fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item ) + UB_ITEM_MISC_USE_OFFSET , 0
                    End If
                    ' open pits etc. can change visibility of the square
                    s_cr_put( y , x )
                    lub_created = true
                End If
            End If
        Next
    Next
    ' N.B: making traps always counts as noticed, making doors only if one was made
    If pub_doors = false Then Return true
    Return lub_created
End Function


Function fub_sp_destroy_doors() As UByte
    ' Moria's spellDestroyAdjacentDoorsTraps(): traps, doors and secret doors beside the player, and under them
    Dim y , x , lub_item , lub_category As UByte
    Dim lub_destroyed                   As UByte = false

    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            lub_item = Peek( fuw_cr_square( y , x ) + UB_SQUARE_ITEM )
            If lub_item <> 0 Then
                lub_category = fub_cr_item_category( lub_item )
                If ( lub_category >= UB_TV_INVIS_TRAP And lub_category <= UB_TV_CLOSED_DOOR And lub_category <> UB_TV_RUBBLE ) Or lub_category = UB_TV_SECRET_DOOR Then
                    s_sp_delete_object( y , x )
                    s_cr_put( y , x )
                    ' Moria counts it only if the player can see the square
                    If fub_sp_visible( fuw_cr_square( y , x ) ) Then lub_destroyed = true
                End If
                If lub_category = UB_TV_CHEST Then
                    ' a chest beside the player is unlocked and disarmed, the chests library
                    gub_lib_param_1 = y
                    guw_lib_param_2 = x
                    gsw_lib_result  = false
                    s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_UNLOCK )
                    If gsw_lib_result Then lub_destroyed = true
                End If
            End If
        Next
    Next
    Return lub_destroyed
End Function


Sub s_sp_destroy_area()
    ' Moria's spellDestroyArea(), with its replaceSpot(): everything within 15 squares of the player becomes a
    ' jumble of rubble and rock, everything lying there and everything living there is gone, the town is spared
    Dim lsw_y , lsw_x               As Integer
    Dim lub_distance , lub_feature  As UByte
    Dim luw_type , luw_square       As UInteger

    If guw_dungeon_level > 0 Then
        For lsw_y = Cast( Integer , gub_player_row ) - 15 To Cast( Integer , gub_player_row ) + 15
            For lsw_x = Cast( Integer , gub_player_col ) - 15 To Cast( Integer , gub_player_col ) + 15
                If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                    luw_square = fuw_cr_square( lsw_y , lsw_x )
                    If Peek( luw_square + UB_SQUARE_FEATURE ) <> UB_TILE_BOUNDARY_WALL Then
                        lub_distance = fub_mon_distance( lsw_y , lsw_x , gub_player_row , gub_player_col )
                        luw_type = 0
                        If lub_distance = 0 Then
                            ' clear the player's square
                            luw_type = 1
                        ElseIf lub_distance < 13 Then
                            luw_type = fuw_sp_random( 6 )
                        ElseIf lub_distance < 16 Then
                            luw_type = fuw_sp_random( 9 )
                        End If
                        If luw_type <> 0 Then
                            ' Moria's replaceSpot()
                            lub_feature = 255
                            If luw_type <= 3 Then lub_feature = UB_TILE_CORR_FLOOR
                            If luw_type = 4 Or luw_type = 7 Then lub_feature = UB_TILE_GRANITE_WALL
                            If luw_type = 5 Or luw_type = 8 Then lub_feature = UB_TILE_MAGMA_WALL
                            If luw_type = 6 Or luw_type = 9 Then lub_feature = UB_TILE_QUARTZ_WALL
                            luw_square = fuw_cr_square( lsw_y , lsw_x )
                            If lub_feature <> 255 Then Poke luw_square + UB_SQUARE_FEATURE , lub_feature
                            ' no longer lit, found, or part of a room
                            Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bAnd ( 255 - ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK bOr MB_SQUARE_LIT_ROOM ) )
                            If Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then s_sp_delete_object( lsw_y , lsw_x )
                            luw_type = Peek( fuw_cr_square( lsw_y , lsw_x ) + UB_SQUARE_MONSTER )
                            If luw_type > 1 Then
                                gub_lib_param_1 = luw_type
                                s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
                            End If
                        End If
                    End If
                End If
            Next
        Next
    End If
    s_core_message( UW_MSG_THERE_IS_A_SEARING_BLAST_OF_LIGHT )
    gsw_player_blind = gsw_player_blind + 10 + fuw_sp_random( 10 )
End Sub


Sub s_lib_spells()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_noticed                                             As UByte = true
    Dim luw_amount                                              As UInteger

    ' ours: a spell here may light, map, detect, build or destroy, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    luw_amount       = guw_lib_param_2
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_SPELLS_LIGHT_AREA Then
        lub_noticed = fub_sp_light_area()
    ElseIf gub_lib_function = UB_LIB_SPELLS_DARKEN_AREA Then
        lub_noticed = fub_sp_darken_area()
    ElseIf gub_lib_function = UB_LIB_SPELLS_MAP_AREA Then
        s_sp_map_area()
    ElseIf gub_lib_function >= UB_LIB_SPELLS_DETECT_TREASURE And gub_lib_function <= UB_LIB_SPELLS_DETECT_DOORS Then
        lub_noticed = fub_sp_detect( gub_lib_function )
    ElseIf gub_lib_function = UB_LIB_SPELLS_DETECT_INVISIBLE Then
        lub_noticed = fub_sp_detect_invisible()
    ElseIf gub_lib_function = UB_LIB_SPELLS_TELEPORT Then
        s_sp_teleport( luw_amount )
    ElseIf gub_lib_function = UB_LIB_SPELLS_GLYPH Then
        s_sp_glyph()
    ElseIf gub_lib_function = UB_LIB_SPELLS_CREATE_FOOD Then
        ' N.B: Moria counts this as noticed whether or not there was room for the mushroom
        gub_shared_1 = fub_sp_create_food()
    ElseIf gub_lib_function = UB_LIB_SPELLS_TRAPS Then
        lub_noticed = fub_sp_surround( false )
    ElseIf gub_lib_function = UB_LIB_SPELLS_DOORS Then
        lub_noticed = fub_sp_surround( true )
    ElseIf gub_lib_function = UB_LIB_SPELLS_DESTROY_DOORS Then
        lub_noticed = fub_sp_destroy_doors()
    ElseIf gub_lib_function = UB_LIB_SPELLS_DESTROY_AREA Then
        s_sp_destroy_area()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_noticed
End Sub
