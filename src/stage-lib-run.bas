#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_run()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-map-include.bas"

' this page is a LIBRARY, not a stage: running, Moria's player_run.cpp, the player keeps moving until something
' interesting happens, following the corners of a corridor, going straight across open ground and stopping at
' its edge, and stopping when a wall they are running beside opens out...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_RUN , <which routine> ), the routines are:
'
'   UB_LIB_RUN_START    the player starts to run in direction gub_lib_param_1, as on a numeric keypad, Moria's
'                       playerFindInitialize(), all but its first step, which the walking stage takes
'   UB_LIB_RUN_AREA     the player has just arrived on a new square while running: which way next, or should
'                       they stop, Moria's playerAreaAffect()
'
' gub_game_running is not 0 while the player is running, it counts the steps (Moria's running_tracker), and
' gub_game_run_direction is the way the next step goes (find_direction), anything may stop a run by setting
' gub_game_running to 0, Moria's playerEndRunning(), the walking stage takes the steps
' the rest of what a run remembers from one step to the next is kept in this page's own storage, which nothing
' else touches
'
' Moria has options about running, which = sets, see guw_game_options: whether corners are examined
' (run_examine_corners) and cut (run_cut_corners), and whether an open door stops a run (run_ignore_doors)
' N.B: a fourth, run_print_self, says whether the player is drawn while they run, the map routines see to that


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
Dim gub_rn_prev_dir         As UByte    At A_LIB_PRIVATE            ' the way the runner is taken to have come from (find_prevdir)
Dim gub_rn_open_area        As UByte    At A_LIB_PRIVATE + 1        ' in the open on at least one side (find_openarea)
Dim gub_rn_break_right      As UByte    At A_LIB_PRIVATE + 2        ' a wall on the right, stop if it opens (find_breakright)
Dim gub_rn_break_left       As UByte    At A_LIB_PRIVATE + 3        ' the same on the left (find_breakleft)
Dim gub_rn_y                As UByte    At A_LIB_PRIVATE + 4        ' the square fub_rn_step() last led to
Dim gub_rn_x                As UByte    At A_LIB_PRIVATE + 5
Dim gub_rn_check_dir        As UByte    At A_LIB_PRIVATE + 6        ' while looking round: the other diagonal beside the first way on
Dim gub_rn_dir_a            As UByte    At A_LIB_PRIVATE + 7        ' the first way on, 0 for none yet
Dim gub_rn_dir_b            As UByte    At A_LIB_PRIVATE + 8        ' the second


Function fub_rn_cycle( pub_index As UByte ) As UByte
    ' the directions in anticlockwise order, for over two complete cycles, Moria's cycle[]
    Return Peek( @rn_cycle + pub_index )
rn_cycle:
    Asm
        defb 1, 2, 3, 6, 9, 8, 7, 4, 1, 2, 3, 6, 9, 8, 7, 4, 1
    End Asm
    Return 0
End Function


Function fub_rn_home( pub_direction As UByte ) As UByte
    ' where a direction is in the cycle, Moria's chome[]
    Return Peek( @rn_home + pub_direction )
rn_home:
    Asm
        defb 0, 8, 9, 10, 7, 0, 11, 6, 5, 4
    End Asm
    Return 0
End Function


Function fub_rn_step( pub_direction As UByte , pub_y As UByte , pub_x As UByte ) As UByte
    ' one square on from a square, left in gub_rn_y and gub_rn_x, Moria's playerMovePosition(), false if that
    ' would be off the edge of the map
    Dim lsw_y , lsw_x As Integer

    lsw_y = Cast( Integer , pub_y ) + 1 - Cast( Integer , ( pub_direction - 1 ) / 3 )       ' 1 2 3 go down, 7 8 9 go up
    lsw_x = Cast( Integer , pub_x ) + Cast( Integer , ( pub_direction - 1 ) Mod 3 ) - 1     ' 1 4 7 go left, 3 6 9 go right
    If lsw_y < 0 Or lsw_x < 0 Or lsw_y >= Cast( Integer , gub_dungeon_rows ) Or lsw_x >= Cast( Integer , gub_dungeon_cols ) Then Return false
    gub_rn_y = lsw_y
    gub_rn_x = lsw_x
    Return true
End Function


Function fub_rn_see_wall( pub_direction As UByte , pub_y As UByte , pub_x As UByte ) As UByte
    ' do we see a wall, one square on from a square? Moria's playerCanSeeDungeonWall()
    ' N.B: every kind of wall is drawn as # here, Moria also asks about %, which it only draws when an option is on
    If fub_rn_step( pub_direction , pub_y , pub_x ) = false Then Return true
    If fub_cr_symbol( gub_rn_y , gub_rn_x ) = Code( "#" ) Then Return true
    Return false
End Function


Function fub_rn_see_nothing( pub_direction As UByte , pub_y As UByte , pub_x As UByte ) As UByte
    ' do we see anything at all there? Moria's playerSeeNothing()
    If fub_rn_step( pub_direction , pub_y , pub_x ) = false Then Return false
    If fub_cr_symbol( gub_rn_y , gub_rn_x ) = 32 Then Return true
    Return false
End Function


Sub s_rn_start( pub_direction As UByte )
    ' Moria's playerFindInitialize(), with its findRunningBreak()
    Dim lub_y , lub_x , lub_index                                           As UByte
    Dim lub_deep_left , lub_deep_right , lub_short_left , lub_short_right   As UByte

    If fub_rn_step( pub_direction , gub_player_row , gub_player_col ) = false Then
        gub_game_running = 0
        Return
    End If
    lub_y = gub_rn_y
    lub_x = gub_rn_x
    gub_game_running       = 1
    gub_game_run_direction = pub_direction
    gub_rn_prev_dir        = pub_direction
    gub_rn_break_right     = false
    gub_rn_break_left      = false
    If gsw_player_blind >= 1 Then Return

    lub_deep_left   = false
    lub_deep_right  = false
    lub_short_left  = false
    lub_short_right = false
    lub_index = fub_rn_home( pub_direction )

    If fub_rn_see_wall( fub_rn_cycle( lub_index + 1 ) , gub_player_row , gub_player_col ) Then
        gub_rn_break_left = true
        lub_short_left    = true
    ElseIf fub_rn_see_wall( fub_rn_cycle( lub_index + 1 ) , lub_y , lub_x ) Then
        gub_rn_break_left = true
        lub_deep_left     = true
    End If

    If fub_rn_see_wall( fub_rn_cycle( lub_index - 1 ) , gub_player_row , gub_player_col ) Then
        gub_rn_break_right = true
        lub_short_right    = true
    ElseIf fub_rn_see_wall( fub_rn_cycle( lub_index - 1 ) , lub_y , lub_x ) Then
        gub_rn_break_right = true
        lub_deep_right     = true
    End If

    If gub_rn_break_left And gub_rn_break_right Then
        gub_rn_open_area = false
        If ( pub_direction bAnd 1 ) <> 0 Then
            ' a hack to allow angled corridor entry
            If lub_deep_left And lub_deep_right = false Then
                gub_rn_prev_dir = fub_rn_cycle( lub_index - 1 )
            ElseIf lub_deep_right And lub_deep_left = false Then
                gub_rn_prev_dir = fub_rn_cycle( lub_index + 1 )
            End If
        ElseIf fub_rn_see_wall( fub_rn_cycle( lub_index ) , lub_y , lub_x ) Then
            ' else if there is a wall two spaces ahead and seem to be in a corridor, then force a turn into the
            ' side corridor, must be moving straight into a corridor here
            If lub_short_left And lub_short_right = false Then
                gub_rn_prev_dir = fub_rn_cycle( lub_index - 2 )
            ElseIf lub_short_right And lub_short_left = false Then
                gub_rn_prev_dir = fub_rn_cycle( lub_index + 2 )
            End If
        End If
    Else
        gub_rn_open_area = true
    End If
End Sub


Function fub_rn_look( psb_i As Byte , pub_direction As UByte , pub_new_dir As UByte , pub_y As UByte , pub_x As UByte ) As UByte
    ' one of the squares the runner has just come beside, Moria's areaAffectStopLookingAtSquares(), true if it
    ' stops the run
    Dim luw_square                                      As UInteger
    Dim lub_flags , lub_item , lub_monster , lub_feature As UByte
    Dim lub_category                                    As UByte
    Dim lub_invisible                                   As UByte = true     ' default: square unseen, treat as open
    Dim lsw_index                                       As Integer

    lsw_index   = Cast( Integer , fub_rn_home( pub_direction ) ) + psb_i
    luw_square  = fuw_cr_square( pub_y , pub_x )
    lub_flags   = Peek( luw_square + UB_SQUARE_FLAGS )
    lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
    lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )

    If gub_player_carrying_light <> 0 Or ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then
        If lub_item <> 0 Then
            lub_category = fub_cr_item_category( lub_item )
            ' N.B: an open door does not stop a run if the player has asked to run through them
            If lub_category <> UB_TV_INVIS_TRAP And lub_category <> UB_TV_SECRET_DOOR Then
                If lub_category <> UB_TV_OPEN_DOOR Or ( guw_game_options bAnd MW_OPTION_IGNORE_DOORS ) = 0 Then Return true
            End If
        End If
        ' also creatures, the monster should be visible since the visibility check deals with running
        If lub_monster > 1 Then
            If Peek( fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster ) + UB_MONSTER_LIT_OFFSET ) Then Return true
        End If
        lub_invisible = false
    End If

    If lub_feature <= UB_TILE_MAX_OPEN Or lub_invisible Then
        If gub_rn_open_area Then
            ' have we found a break?
            If psb_i < 0 Then
                If gub_rn_break_right Then Return true
            ElseIf psb_i > 0 Then
                If gub_rn_break_left Then Return true
            End If
        ElseIf gub_rn_dir_a = 0 Then
            ' the first new direction
            gub_rn_dir_a = pub_new_dir
        ElseIf gub_rn_dir_b <> 0 Then
            ' three new directions, STOP
            Return true
        ElseIf gub_rn_dir_a <> fub_rn_cycle( lsw_index - 1 ) Then
            ' if not adjacent to prev, STOP
            Return true
        Else
            ' two adjacent choices, make dir_b the diagonal, and remember the other diagonal adjacent to the first option
            If ( pub_new_dir bAnd 1 ) = 1 Then
                gub_rn_check_dir = fub_rn_cycle( lsw_index - 2 )
                gub_rn_dir_b     = pub_new_dir
            Else
                gub_rn_check_dir = fub_rn_cycle( lsw_index + 1 )
                gub_rn_dir_b     = gub_rn_dir_a
                gub_rn_dir_a     = pub_new_dir
            End If
        End If
    ElseIf gub_rn_open_area Then
        ' we see an obstacle, in open area, STOP if on a side previously open
        If psb_i < 0 Then
            If gub_rn_break_left Then Return true
            gub_rn_break_right = true
        ElseIf psb_i > 0 Then
            If gub_rn_break_right Then Return true
            gub_rn_break_left = true
        End If
    End If
    Return false
End Function


Sub s_rn_area()
    ' Moria's playerAreaAffect(): determine the next direction for a run, or if we should stop
    Dim lub_direction , lub_new_dir , lub_y , lub_x As UByte
    Dim lsb_i , lsb_max                             As Byte
    Dim lub_closed                                  As UByte

    If gsw_player_blind >= 1 Then Return

    gub_rn_check_dir = 0
    gub_rn_dir_a     = 0
    gub_rn_dir_b     = 0
    lub_direction    = gub_rn_prev_dir
    lsb_max          = ( lub_direction bAnd 1 ) + 1

    ' look at every newly adjacent square
    ' N.B: as in Moria the looking goes on after a square has stopped the run, the sides it marks as walled still count
    For lsb_i = -lsb_max To lsb_max
        lub_new_dir = fub_rn_cycle( Cast( Integer , fub_rn_home( lub_direction ) ) + lsb_i )
        ' objects player can see (including doors?) cause a stop
        If fub_rn_step( lub_new_dir , gub_player_row , gub_player_col ) Then
            If fub_rn_look( lsb_i , lub_direction , lub_new_dir , gub_rn_y , gub_rn_x ) Then gub_game_running = 0
        End If
    Next

    If gub_rn_open_area Then Return

    ' choose a direction
    If gub_rn_dir_b = 0 Or ( guw_game_options bAnd ( MW_OPTION_EXAMINE_CORNERS bOr MW_OPTION_CUT_CORNERS ) ) = MW_OPTION_EXAMINE_CORNERS Then
        ' there is only one option, or if two, then we always examine potential corners and never cut known
        ' corners, so you step into the straight option
        If gub_rn_dir_a <> 0 Then gub_game_run_direction = gub_rn_dir_a
        If gub_rn_dir_b = 0 Then
            gub_rn_prev_dir = gub_rn_dir_a
        Else
            gub_rn_prev_dir = gub_rn_dir_b
        End If
        Return
    End If

    ' two options!
    gub_shared_1 = fub_rn_step( gub_rn_dir_a , gub_player_row , gub_player_col )
    lub_y = gub_rn_y
    lub_x = gub_rn_x
    lub_closed = false
    If fub_rn_see_wall( gub_rn_dir_a , lub_y , lub_x ) Then
        If fub_rn_see_wall( gub_rn_check_dir , lub_y , lub_x ) Then lub_closed = true
    End If
    If lub_closed = false Then
        ' don't see that it is closed off, this could be a potential corner or an intersection
        lub_closed = false
        If ( guw_game_options bAnd MW_OPTION_EXAMINE_CORNERS ) <> 0 Then
            If fub_rn_see_nothing( gub_rn_dir_a , lub_y , lub_x ) Then
                If fub_rn_see_nothing( gub_rn_dir_b , lub_y , lub_x ) Then lub_closed = true
            End If
        End If
        If lub_closed Then
            ' can not see anything ahead and in the direction we are turning, assume that it is a potential corner
            gub_game_run_direction = gub_rn_dir_a
            gub_rn_prev_dir        = gub_rn_dir_b
        Else
            ' STOP: we are next to an intersection or a room
            gub_game_running = 0
        End If
    ElseIf ( guw_game_options bAnd MW_OPTION_CUT_CORNERS ) <> 0 Then
        ' this corner is seen to be enclosed, we cut the corner
        gub_game_run_direction = gub_rn_dir_b
        gub_rn_prev_dir        = gub_rn_dir_b
    Else
        ' this corner is seen to be enclosed, and we deliberately go the long way
        gub_game_run_direction = gub_rn_dir_a
        gub_rn_prev_dir        = gub_rn_dir_b
    End If
End Sub


Sub s_lib_run()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lub_direction                                           As UByte

    lub_direction    = gub_lib_param_1
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_RUN_START Then
        s_rn_start( lub_direction )
    ElseIf gub_lib_function = UB_LIB_RUN_AREA Then
        s_rn_area()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
