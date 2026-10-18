#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_spells_5()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-aim-include.bas"

' this page is a LIBRARY, not a stage: the spells that change the dungeon itself, its walls, doors and traps, which
' wands, staffs, spell books and prayers all share, from Moria's spells.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_5 , <which routine> ), each leaves
' true in gsw_lib_result if the player noticed anything, for the aimed ones the direction, as on a numeric keypad, is
' in gub_lib_param_1, the routines are:
'
'   UB_LIB_SPELLS_5_WALL_TO_MUD     the first wall, rubble or door in the line is gone, and a creature of stone is
'                                   hurt, spellWallToMud()
'   UB_LIB_SPELLS_5_DESTROY_DOORS   every door and trap in the line is gone, spellDestroyDoorsTrapsInDirection()
'   UB_LIB_SPELLS_5_BUILD_WALL      every open square in the line becomes rock, burying what is there, spellBuildWall()
'   UB_LIB_SPELLS_5_DISARM_ALL      every trap in the line is gone, every door unlocked, every secret door found,
'                                   spellDisarmAllInDirection()
'   UB_LIB_SPELLS_5_EARTHQUAKE      one square in eight within 8 of the player changes, floor to rock and rock to
'                                   floor, spellEarthquake()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, chests in the line are unlocked and disarmed, see fub_s5_chest()
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fub_s5_visible() As UByte
    ' true if what is on the square the spell has reached shows, Moria's caveTileVisible()
    If ( Peek( fuw_aim_square() + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then Return true
    Return false
End Function


Function fub_s5_item_category() As UByte
    ' the category of what lies on the square the spell has reached, 0 for nothing
    Dim lub_item As UByte

    lub_item = Peek( fuw_aim_square() + UB_SQUARE_ITEM )
    If lub_item = 0 Then Return 0
    Return fub_cr_item_category( lub_item )
End Function


Sub s_s5_bury( pub_monster As UByte )
    ' a monster caught where rock appears, Moria's earthquakeHitsMonster(), and the same lines of its spellBuildWall():
    ' those that pass through walls take no harm, and the creatures of earth and stone are the stronger for it
    Dim luw_record  As UInteger
    Dim lsw_damage  As Integer
    Dim ls_name     As String

    ls_name = fs_aim_name( pub_monster )
    If ( gul_creature_movement bAnd UL_CM_PHASE ) = 0 Then
        ' monster can not move, can not escape the wall
        If ( gul_creature_movement bAnd UL_CM_ATTACK_ONLY ) <> 0 Then
            lsw_damage = 3000
        Else
            lsw_damage = fuw_core_dice_roll( 4 , 8 )
        End If
        s_msg( ls_name + " wails out in pain!" )
        If fub_aim_take_hit( pub_monster , lsw_damage ) Then
            s_msg( ls_name + " is embedded in the rock." )
            s_aim_show_experience()
        End If
    ElseIf gub_creature_sprite = Code( "E" ) Or gub_creature_sprite = Code( "X" ) Then
        ' must be an earth elemental, an earth spirit, or a xorn, increase its hit points
        luw_record = fuw_aim_monster( pub_monster )
        Poke UInteger luw_record , Cast( UInteger , Peek( Integer , luw_record ) + Cast( Integer , fuw_core_dice_roll( 4 , 8 ) ) )
    End If
End Sub


Function fub_s5_wall_to_mud( pub_direction As UByte ) As UByte
    ' Moria's spellWallToMud()
    Dim luw_square                              As UInteger
    Dim lub_feature , lub_category , lub_item   As UByte
    Dim lub_monster                             As UByte
    Dim ls_name                                 As String
    Dim lub_turned                              As UByte = false
    Dim lub_finished                            As UByte = false

    s_aim_start()
    While lub_finished = false
        s_aim_step( pub_direction )
        ' note, this ray can move through walls as it turns them to mud
        If gub_aim_distance = UB_AIM_MAX_RANGE Then lub_finished = true
        luw_square  = fuw_aim_square()
        lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
        lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
        lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )

        If lub_feature >= UB_TILE_MIN_WALL And lub_feature <> UB_TILE_BOUNDARY_WALL Then
            lub_finished = true
            ' the traps library digs the wall out, Moria's playerTunnelWall( 1 , 0 )
            gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_DIG_WALL , gub_aim_y , gub_aim_x )
            s_cr_put( gub_aim_y , gub_aim_x )
            If fub_s5_visible() Then
                lub_turned = true
                s_core_message( UW_MSG_THE_WALL_TURNS_INTO_MUD )
            End If
        ElseIf lub_item <> 0 And lub_feature >= UB_TILE_MIN_CLOSED Then
            lub_finished = true
            lub_category = fub_cr_item_category( lub_item )
            If fub_cr_inside_panel( gub_aim_y , gub_aim_x ) And fub_s5_visible() Then
                lub_turned = true
                s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_item , A_ITEM )
                gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , false , 0 )
                s_msg( "The " + fs_core_text_at( A_TEXT_BUFFER ) + " turns into mud." )
            End If
            s_aim_delete_object()
            If lub_category = UB_TV_RUBBLE Then
                If fuw_aim_random( 10 ) = 1 Then
                    gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT , gub_aim_y , gub_aim_x )
                    If fub_s5_visible() Then s_core_message( UW_MSG_YOU_HAVE_FOUND_SOMETHING )
                End If
            End If
            s_cr_put( gub_aim_y , gub_aim_x )
        End If

        If lub_monster > 1 Then
            ls_name = fs_aim_name( lub_monster )
            If ( guw_creature_defenses bAnd UW_CD_STONE ) <> 0 Then
                s_aim_learn( lub_monster , UB_RECALL_DEFENSES , UW_CD_STONE , false )
                ' should get these messages even if the monster is not visible
                If fub_aim_take_hit( lub_monster , 100 ) Then
                    s_msg( ls_name + " dissolves!" )
                    s_aim_show_experience()
                Else
                    s_msg( ls_name + " grunts in pain!" )
                End If
                lub_finished = true
            End If
        End If
    End While
    Return lub_turned
End Function


Function fub_s5_chest() As UByte
    ' a chest in the way is unlocked and disarmed, "Click!", the chests library does it, true if there was
    ' anything to undo
    gub_lib_param_1 = gub_aim_y
    guw_lib_param_2 = gub_aim_x
    gsw_lib_result  = true
    s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_UNLOCK )
    If gsw_lib_result Then Return true
    Return false
End Function


Function fub_s5_destroy_doors( pub_direction As UByte ) As UByte
    ' Moria's spellDestroyDoorsTrapsInDirection(): it goes on past its range for as long as the way is open
    Dim lub_category    As UByte
    Dim lub_destroyed   As UByte = false
    Dim lub_guard       As UByte = 0

    s_aim_start()
    Do
        s_aim_step( pub_direction )
        lub_category = fub_s5_item_category()
        ' must find any/all traps, doors and secret doors
        If lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_CLOSED_DOOR Or lub_category = UB_TV_VIS_TRAP Or lub_category = UB_TV_OPEN_DOOR Or lub_category = UB_TV_SECRET_DOOR Then
            s_aim_delete_object()
            s_cr_put( gub_aim_y , gub_aim_x )
            If fub_s5_visible() Then
                lub_destroyed = true
                s_core_message( UW_MSG_THERE_IS_A_BRIGHT_FLASH_OF_LIGHT_2 )
            End If
        End If
        If lub_category = UB_TV_CHEST Then
            If fub_s5_chest() Then lub_destroyed = true
        End If
        ' N.B: the count stops at the edge of the map, where the spell can go no further, Moria relies on the rock there
        lub_guard = lub_guard + 1
    Loop While ( gub_aim_distance <= UB_AIM_MAX_RANGE Or Peek( fuw_aim_square() + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN ) And lub_guard < 250
    Return lub_destroyed
End Function


Function fub_s5_build_wall( pub_direction As UByte ) As UByte
    ' Moria's spellBuildWall()
    Dim luw_square              As UInteger
    Dim lub_monster , lub_flags As UByte
    Dim lub_built               As UByte = false
    Dim lub_finished            As UByte = false

    s_aim_start()
    While lub_finished = false
        s_aim_step( pub_direction )
        luw_square = fuw_aim_square()
        If gub_aim_distance > UB_AIM_MAX_RANGE Or Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_CLOSED Then
            lub_finished = true
        Else
            If Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then s_aim_delete_object()
            lub_monster = Peek( fuw_aim_square() + UB_SQUARE_MONSTER )
            If lub_monster > 1 Then
                lub_finished = true
                s_s5_bury( lub_monster )
            End If
            luw_square = fuw_aim_square()
            lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
            Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_MAGMA_WALL
            ' it is no longer "found", and it stays lit if it was lit in any way
            lub_flags = lub_flags bAnd ( 255 - MB_SQUARE_FIELD_MARK )
            If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) <> 0 Then lub_flags = lub_flags bOr MB_SQUARE_PERM_LIGHT
            Poke luw_square + UB_SQUARE_FLAGS , lub_flags
            s_cr_put( gub_aim_y , gub_aim_x )
            lub_built = true
        End If
    End While
    Return lub_built
End Function


Function fub_s5_disarm_all( pub_direction As UByte ) As UByte
    ' Moria's spellDisarmAllInDirection(), it starts with the square the player is on
    Dim luw_square , luw_record             As UInteger
    Dim lub_item , lub_category , lub_open  As UByte
    Dim lub_disarmed                        As UByte = false

    s_aim_start()
    Do
        luw_square = fuw_aim_square()
        lub_open   = false
        If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then lub_open = true
        lub_item = Peek( luw_square + UB_SQUARE_ITEM )
        ' note, must continue up to and including the first non open space, because secret doors have a
        ' feature greater than that
        If lub_item <> 0 Then
            lub_category = fub_cr_item_category( lub_item )
            If lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_VIS_TRAP Then
                s_aim_delete_object()
                s_cr_put( gub_aim_y , gub_aim_x )
                If fub_s5_visible() Then lub_disarmed = true
            ElseIf lub_category = UB_TV_CLOSED_DOOR Then
                ' locked or jammed doors become merely closed
                Poke UInteger fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item ) + UB_ITEM_MISC_USE_OFFSET , 0
            ElseIf lub_category = UB_TV_SECRET_DOOR Then
                ' Moria's trapChangeVisibility(): the secret door becomes a closed one, and is found
                s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_CLOSED_DOOR , A_OBJECT )
                luw_record = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
                Poke UInteger luw_record , UW_OBJ_CLOSED_DOOR
                Poke luw_record + UB_ITEM_CATEGORY_OFFSET , Peek( A_OBJECT + UB_ITEM_CATEGORY_OFFSET )
                Poke luw_record + UB_ITEM_SPRITE_OFFSET , Peek( A_OBJECT + UB_ITEM_SPRITE_OFFSET )
                luw_square = fuw_aim_square() + UB_SQUARE_FLAGS
                Poke luw_square , Peek( luw_square ) bOr MB_SQUARE_FIELD_MARK
                s_cr_put( gub_aim_y , gub_aim_x )
                lub_disarmed = true
            End If
            If lub_category = UB_TV_CHEST Then
                If fub_s5_chest() Then lub_disarmed = true
            End If
        End If
        s_aim_step( pub_direction )
    Loop While gub_aim_distance <= UB_AIM_MAX_RANGE And lub_open
    Return lub_disarmed
End Function


Sub s_s5_earthquake()
    ' Moria's spellEarthquake()
    Dim lsw_y , lsw_x               As Integer
    Dim luw_square , luw_roll       As UInteger
    Dim lub_feature , lub_monster   As UByte
    Dim lub_flags                   As UByte

    For lsw_y = Cast( Integer , gub_player_row ) - 8 To Cast( Integer , gub_player_row ) + 8
        For lsw_x = Cast( Integer , gub_player_col ) - 8 To Cast( Integer , gub_player_col ) + 8
            If ( lsw_y <> gub_player_row Or lsw_x <> gub_player_col ) And lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                If fuw_aim_random( 8 ) = 1 Then
                    gub_aim_y = lsw_y
                    gub_aim_x = lsw_x
                    If Peek( fuw_aim_square() + UB_SQUARE_ITEM ) <> 0 Then s_aim_delete_object()
                    lub_monster = Peek( fuw_aim_square() + UB_SQUARE_MONSTER )
                    If lub_monster > 1 Then s_s5_bury( lub_monster )

                    luw_square  = fuw_aim_square()
                    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
                    lub_flags   = Peek( luw_square + UB_SQUARE_FLAGS )
                    If lub_feature >= UB_TILE_MIN_WALL And lub_feature <> UB_TILE_BOUNDARY_WALL Then
                        Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_CORR_FLOOR
                        Poke luw_square + UB_SQUARE_FLAGS , lub_flags bAnd ( 255 - ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK ) )
                    ElseIf lub_feature <= UB_TILE_BLOCKED_FLOOR Then
                        luw_roll = fuw_aim_random( 10 )
                        luw_square = fuw_aim_square()
                        If luw_roll < 6 Then
                            Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_QUARTZ_WALL
                        ElseIf luw_roll < 9 Then
                            Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_MAGMA_WALL
                        Else
                            Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_GRANITE_WALL
                        End If
                        Poke luw_square + UB_SQUARE_FLAGS , lub_flags bAnd ( 255 - MB_SQUARE_FIELD_MARK )
                    End If
                    s_cr_put( lsw_y , lsw_x )
                End If
            End If
        Next
    Next
End Sub


Sub s_lib_spells_5()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_direction                                           As UByte
    Dim lub_noticed                                             As UByte = true

    ' ours: a spell here may light, map, detect, build or destroy, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    lub_direction    = gub_lib_param_1
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_SPELLS_5_WALL_TO_MUD Then
        lub_noticed = fub_s5_wall_to_mud( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_5_DESTROY_DOORS Then
        lub_noticed = fub_s5_destroy_doors( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_5_BUILD_WALL Then
        lub_noticed = fub_s5_build_wall( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_5_DISARM_ALL Then
        lub_noticed = fub_s5_disarm_all( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_5_EARTHQUAKE Then
        s_s5_earthquake()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_noticed
End Sub
