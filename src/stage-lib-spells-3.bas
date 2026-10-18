#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_spells_3()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-monster-include.bas"
#include "stage-element-include.bas"
#include "stage-aim-include.bas"

' this page is a LIBRARY, not a stage: the spells that are aimed and travel in a line from the player, light, bolts and
' balls, which wands, staffs, spell books and prayers all share, from Moria's spells.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_3 , <which routine> ), the direction,
' as on a numeric keypad, is in gub_lib_param_1, the routines are:
'
'   UB_LIB_SPELLS_3_LIGHT_LINE  a line of light, as far as the first wall, creatures that cannot bear light are
'                               hurt by it, Moria's spellLightLine()
'   UB_LIB_SPELLS_3_STARLITE    a line of light in all eight directions, Moria's spellStarlite()
'   UB_LIB_SPELLS_3_BOLT        a bolt that hurts the first monster in its way, Moria's spellFireBolt()
'   UB_LIB_SPELLS_3_BALL        a ball that bursts on the first monster or wall in its way and hurts everything
'                               within two squares, Moria's spellFireBall()
'
' for a bolt or a ball the damage is in guw_lib_param_2, what it is made of in gsw_lib_result, one of the UB_ELEMENT_
' numbers, and its name, "Fire Bolt" say, is text in A_PROMPT
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing more that is known of


Sub s_s3_pause()
    ' the star that marks a bolt on its way shows for a moment
    ' N.B: a counted loop and not a wait for the next frame, interrupts are off while a page of code runs
    Dim luw_i As UInteger

    For luw_i = 1 To 1500
    Next
End Sub


Sub s_s3_star()
    ' marks the square the spell has reached, if the player can see it
    If fub_cr_inside_panel( gub_aim_y , gub_aim_x ) And gsw_player_blind < 1 Then
        s_core_print_char_at( gub_aim_y - gub_panel_top + UB_VIEW_SCREEN_ROW , gub_aim_x - gub_panel_left + UB_VIEW_SCREEN_COL , Code( "*" ) , UB_BRIGHT_YELLOW )
    End If
End Sub


Function fub_s3_lit_up( pub_monster As UByte ) As UByte
    ' a monster struck by a spell is seen in its flash: the square is lit for a moment while whether the player can
    ' see the monster is worked out, what the square's light really was is put back, true if the monster shows
    Dim luw_square  As UInteger
    Dim lub_flags   As UByte

    luw_square = fuw_aim_square() + UB_SQUARE_FLAGS
    lub_flags  = Peek( luw_square )
    Poke luw_square , lub_flags bOr MB_SQUARE_PERM_LIGHT
    s_aim_visibility( pub_monster )
    Poke fuw_aim_square() + UB_SQUARE_FLAGS , lub_flags
    Return Peek( fuw_aim_monster( pub_monster ) + UB_MONSTER_LIT_OFFSET )
End Function


Function fsw_s3_adjust( psw_damage As Integer , pub_monster As UByte , pub_element As UByte ) As Integer
    ' twice the damage to a creature this hurts, a quarter to one that breathes it itself
    Dim luw_record As UInteger

    luw_record = fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , fuw_aim_monster( pub_monster ) + UB_MONSTER_CREATURE_OFFSET ) )
    ' in either case the player learns it about this kind of creature, if they can see it
    If ( Peek( UInteger , luw_record + UB_CREATURE_DEFENSES_OFFSET ) bAnd fuw_el_harms( pub_element ) ) <> 0 Then
        s_aim_learn( pub_monster , UB_RECALL_DEFENSES , fuw_el_harms( pub_element ) , true )
        Return psw_damage * 2
    End If
    If ( Peek( ULong , luw_record + UB_CREATURE_SPELLS_OFFSET ) bAnd ful_el_resists( pub_element ) ) <> 0 Then
        s_aim_learn( pub_monster , UB_RECALL_SPELLS , ful_el_resists( pub_element ) , true )
        Return psw_damage / 4
    End If
    Return psw_damage
End Function


'##################################################################################################################################
' --- light ---

Sub s_s3_light_line( pub_direction As UByte )
    ' Moria's spellLightLine(), with its spellLightLineTouchesMonster()
    Dim luw_square                          As UInteger
    Dim lub_flags , lub_monster             As UByte
    Dim ls_name                             As String
    Dim lub_finished                        As UByte = false

    s_aim_start()
    While lub_finished = false
        luw_square = fuw_aim_square()
        If gub_aim_distance > UB_AIM_MAX_RANGE Or Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_CLOSED Then
            lub_finished = true
        Else
            lub_flags = Peek( luw_square + UB_SQUARE_FLAGS )
            If ( lub_flags bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT ) ) = 0 Then
                ' set the light flag before lighting the room, so that the routine does not light the room twice
                Poke luw_square + UB_SQUARE_FLAGS , lub_flags bOr MB_SQUARE_PERM_LIGHT
                If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_LIGHT_FLOOR Then
                    If fub_cr_inside_panel( gub_aim_y , gub_aim_x ) Then
                        ' N.B: the room lights itself only where it is not yet lit, so this square is given back
                        ' to it unlit, and lit again afterwards
                        Poke luw_square + UB_SQUARE_FLAGS , lub_flags
                        s_cr_light_room( gub_aim_y , gub_aim_x )
                    End If
                Else
                    s_cr_put( gub_aim_y , gub_aim_x )
                End If
            End If
            luw_square = fuw_aim_square()
            Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bOr MB_SQUARE_PERM_LIGHT

            lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
            If lub_monster > 1 Then
                ' light up and draw the monster
                s_aim_visibility( lub_monster )
                ls_name = fs_aim_name( lub_monster )
                If ( guw_creature_defenses bAnd UW_CD_LIGHT ) <> 0 Then
                    s_aim_learn( lub_monster , UB_RECALL_DEFENSES , UW_CD_LIGHT , true )
                    If fub_aim_take_hit( lub_monster , fuw_core_dice_roll( 2 , 8 ) ) Then
                        s_msg( ls_name + " shrivels away in the light!" )
                        s_aim_show_experience()
                    Else
                        s_msg( ls_name + " cringes from the light!" )
                    End If
                End If
            End If
            s_aim_step( pub_direction )
        End If
    End While
End Sub


'##################################################################################################################################
' --- bolts and balls ---

Sub s_s3_bolt( pub_direction As UByte , psw_damage As Integer , pub_element As UByte )
    ' Moria's spellFireBolt(), with its spellFireBoltTouchesMonster() and printBoltStrikesMonsterMessage()
    Dim lub_old_y , lub_old_x , lub_monster As UByte
    Dim luw_square                          As UInteger
    Dim ls_name , ls_bolt                   As String
    Dim lub_finished                        As UByte = false

    ls_bolt = fs_core_text_at( A_PROMPT )
    Poke A_PROMPT , 0
    s_aim_start()
    While lub_finished = false
        lub_old_y = gub_aim_y
        lub_old_x = gub_aim_x
        s_aim_step( pub_direction )
        s_cr_put( lub_old_y , lub_old_x )
        luw_square = fuw_aim_square()
        If gub_aim_distance > UB_AIM_MAX_RANGE Or Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_CLOSED Then
            lub_finished = true
        Else
            lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
            If lub_monster > 1 Then
                lub_finished = true
                If fub_s3_lit_up( lub_monster ) Then
                    ls_name = fs_aim_name( lub_monster )
                    s_msg( "The " + ls_bolt + " strikes the " + fs_core_text_at( A_CREATURE ) + "." )
                Else
                    ls_name = fs_aim_name( lub_monster )
                    s_msg( "The " + ls_bolt + " strikes it." )
                End If
                psw_damage = fsw_s3_adjust( psw_damage , lub_monster , pub_element )
                If fub_aim_take_hit( lub_monster , psw_damage ) Then
                    s_msg( ls_name + " dies in a fit of agony." )
                    s_aim_show_experience()
                ElseIf psw_damage > 0 Then
                    s_msg( ls_name + " screams in agony." )
                End If
            Else
                s_s3_star()
                s_s3_pause()
            End If
        End If
    End While
End Sub


Sub s_s3_ball( pub_direction As UByte , psw_damage As Integer , pub_element As UByte )
    ' Moria's spellFireBall(): the ball goes until it meets a monster or a wall, and bursts there, or just short of
    ' the wall, everything within two squares that can be seen from the burst is caught in it
    Dim lub_old_y , lub_old_x , lub_monster     As UByte
    Dim lub_centre_y , lub_centre_x , lub_item  As UByte
    Dim lub_range , lub_feature                 As UByte
    Dim lsw_y , lsw_x , lsw_hurt                As Integer
    Dim luw_square                              As UInteger
    Dim lub_hits , lub_kills                    As UByte
    Dim ls_ball                                 As String
    Dim lub_finished                            As UByte = false

    ls_ball = fs_core_text_at( A_PROMPT )
    Poke A_PROMPT , 0
    lub_hits  = 0
    lub_kills = 0
    s_aim_start()
    While lub_finished = false
        lub_old_y = gub_aim_y
        lub_old_x = gub_aim_x
        s_aim_step( pub_direction )
        s_cr_put( lub_old_y , lub_old_x )
        If gub_aim_distance > UB_AIM_MAX_RANGE Then
            lub_finished = true
        Else
            luw_square  = fuw_aim_square()
            lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
            If lub_feature >= UB_TILE_MIN_CLOSED Or Peek( luw_square + UB_SQUARE_MONSTER ) > 1 Then
                lub_finished = true
                If lub_feature >= UB_TILE_MIN_CLOSED Then
                    gub_aim_y = lub_old_y
                    gub_aim_x = lub_old_x
                End If
                lub_centre_y = gub_aim_y
                lub_centre_x = gub_aim_x

                ' the area affected, an explosion below, starts at the bottom of the page...
                For lsw_y = Cast( Integer , lub_centre_y ) - 2 To Cast( Integer , lub_centre_y ) + 2
                    For lsw_x = Cast( Integer , lub_centre_x ) - 2 To Cast( Integer , lub_centre_x ) + 2
                        If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                            lub_range = fub_mon_distance( lub_centre_y , lub_centre_x , lsw_y , lsw_x )
                            If lub_range <= 2 Then
                                guw_lib_param_2 = ( Cast( UInteger , lub_centre_y ) << 8 ) bOr lub_centre_x
                                gsw_lib_result  = ( lsw_y << 8 ) bOr lsw_x
                                s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_LOS )
                                If gsw_lib_result Then
                                    gub_aim_y  = lsw_y
                                    gub_aim_x  = lsw_x
                                    luw_square = fuw_aim_square()
                                    lub_item   = Peek( luw_square + UB_SQUARE_ITEM )
                                    If lub_item <> 0 Then
                                        If fub_el_destroys( lub_item , pub_element ) Then s_aim_delete_object()
                                    End If
                                    luw_square = fuw_aim_square()
                                    If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then
                                        lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
                                        If lub_monster > 1 Then
                                            ' lite up the creature, draw it, and hit it
                                            gub_shared_1 = fub_s3_lit_up( lub_monster )
                                            lub_hits = lub_hits + 1
                                            lsw_hurt = fsw_s3_adjust( psw_damage , lub_monster , pub_element ) / ( Cast( Integer , lub_range ) + 1 )
                                            If fub_aim_take_hit( lub_monster , lsw_hurt ) Then lub_kills = lub_kills + 1
                                        Else
                                            s_s3_star()
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    Next
                Next

                ' the burst shows for a moment, then the squares are drawn as they now are
                s_s3_pause()
                s_s3_pause()
                For lsw_y = Cast( Integer , lub_centre_y ) - 2 To Cast( Integer , lub_centre_y ) + 2
                    For lsw_x = Cast( Integer , lub_centre_x ) - 2 To Cast( Integer , lub_centre_x ) + 2
                        If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                            If fub_mon_distance( lub_centre_y , lub_centre_x , lsw_y , lsw_x ) <= 2 Then s_cr_put( lsw_y , lsw_x )
                        End If
                    Next
                Next

                If lub_hits = 1 Then
                    s_msg( "The " + ls_ball + " envelops a creature!" )
                ElseIf lub_hits > 1 Then
                    s_msg( "The " + ls_ball + " envelops several creatures!" )
                End If
                If lub_kills = 1 Then
                    s_core_message( UW_MSG_THERE_IS_A_SCREAM_OF_AGONY )
                ElseIf lub_kills > 1 Then
                    s_core_message( UW_MSG_THERE_ARE_SEVERAL_SCREAMS_OF_AGONY )
                End If
                s_aim_show_experience()
            Else
                s_s3_star()
                s_s3_pause()
            End If
        End If
    End While
End Sub


Sub s_lib_spells_3()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_direction , lub_element                             As UByte
    Dim lsw_damage                                              As Integer

    ' ours: a spell here may light, map, detect, build or destroy, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    ' N.B: these are taken out first, the routines here call other libraries, which use the same places
    lub_direction = gub_lib_param_1
    lsw_damage    = guw_lib_param_2
    lub_element   = gsw_lib_result
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_SPELLS_3_LIGHT_LINE Then
        s_s3_light_line( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_3_STARLITE Then
        ' Moria's spellStarlite()
        If gsw_player_blind < 1 Then s_core_message( UW_MSG_THE_END_OF_THE_STAFF_BURSTS_INTO )
        For lub_direction = 1 To 9
            If lub_direction <> 5 Then s_s3_light_line( lub_direction )
        Next
    ElseIf gub_lib_function = UB_LIB_SPELLS_3_BOLT Then
        s_s3_bolt( lub_direction , lsw_damage , lub_element )
    ElseIf gub_lib_function = UB_LIB_SPELLS_3_BALL Then
        s_s3_ball( lub_direction , lsw_damage , lub_element )
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = true
End Sub
