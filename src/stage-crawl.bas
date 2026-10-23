#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_crawl()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-disturb-include.bas"

' this stage is the game itself: the player walking about a level, the town or the dungeon alike, it is the beginning of
' Moria's playDungeon() (game_run.cpp), with its map display (ui.cpp, dungeon.cpp) and its playerMove() (player_move.cpp)
' the screen is Moria's: a message line on row 0, the character's details down the left hand 13 columns, the map in a
' window of 22 rows by 66 columns from row 1 and column 13, and the depth at the bottom right, that is 24 rows of the
' Next's 32: the eight below them belong to the core's live monitor, which the } key turns on and off
' the map shows only what the player has seen or can see, a square appears when it is lit, permanently or by the
' player's own light, or when the thing on it has been found
'
' the commands this stage keeps for itself:
'   1 to 9      move, laid out as on a numeric keypad: 8 up, 2 down, 4 left, 6 right, 7 9 1 3 the diagonals, and
'               5 stays where it is, picking up whatever lies there
'   arrow keys  move up, down, left and right
'   < and >     take a staircase up or down, when standing on one

' every other key goes to the commands library, stage-lib-commands.bas, which has the list
' walking on to a store's door goes into the store, walking into a monster attacks it (the player attack library),
' walking on to a trap sets it off (the traps library), walking on to anything else picks it up, and every step may
' turn up a secret door beside the player, how often depends on how good they are at noticing things
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, what is missing is listed where it belongs, see not-yet.md


'##################################################################################################################################
' --- the map, the routines that draw it, and move its window, are in stage-map-include.bas ---

'##################################################################################################################################
' --- light ---

Sub s_cr_light_rooms_around( pub_y As UByte , pub_x As UByte )
    ' on arriving at a square: lights the room it is in, or the room it is at the door of, the part of Moria's
    ' playerMove() and dungeonResetView() that does this
    Dim luw_square              As UInteger
    Dim y , x , lub_flags       As UByte

    luw_square = fuw_cr_square( pub_y , pub_x )
    lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
    If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_LIGHT_FLOOR Then
        If ( lub_flags bAnd MB_SQUARE_PERM_LIGHT ) = 0 Then s_cr_light_room( pub_y , pub_x )
    ElseIf ( lub_flags bAnd MB_SQUARE_LIT_ROOM ) <> 0 Then
        For y = pub_y - 1 To pub_y + 1
            For x = pub_x - 1 To pub_x + 1
                luw_square = fuw_cr_square( y , x )
                If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_LIGHT_FLOOR And ( Peek( luw_square + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_PERM_LIGHT ) = 0 Then s_cr_light_room( y , x )
            Next
        Next
    End If
End Sub


Sub s_cr_minimap_set( pub_row As UByte , pub_col As UByte )
    ' ours: the mini map's bit for a wall that is now remembered, see stage-lib-minimap.bas: its page is put in MMU 0
    ' by writing the Next register directly, and what was there put back, so the memory monitor does not count it
    ' the parameters: pub_row ix+5, pub_col ix+7
    Asm
        ld bc, A_NEXTREG_SELECT
        ld a, MMU_SLOT_0
        out (c), a
        inc b                           ; $253B, A_NEXTREG_DATA
        in a, (c)
        push af                         ; the page that was there
        nextreg MMU_SLOT_0, UB_PAGE_MINIMAP
        ld l, (ix+5)                    ; the row's first byte: row * 32
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
        ld a, (ix+7)                    ; ...and the column's: column / 8
        ld e, a
        srl a
        srl a
        srl a
        add hl, a                       ; a Next instruction
        ld a, e                         ; the bit: the top one for column 0 of the byte
        and 7
        ld e, $80
        jr z, cr_minimap_bit
    cr_minimap_shift:
        srl e
        dec a
        jr nz, cr_minimap_shift
    cr_minimap_bit:
        ld a, (hl)
        or e
        ld (hl), a
        pop af
        nextreg MMU_SLOT_0, a           ; the page that was there, back
    End Asm
End Sub


Sub s_cr_move_light( pub_from_y As UByte , pub_from_x As UByte , pub_to_y As UByte , pub_to_x As UByte )
    ' the player's own light moves with them, Moria's dungeonMoveCharacterLight(): with a light, sub1MoveLight(), the
    ' eight squares around them are lit, walls seen stay seen, and doors and stairs are found, without one,
    ' sub3MoveLight(), only the player moves
    Dim y , x , lub_flags , lub_item , lub_category     As UByte
    Dim lub_top , lub_bottom , lub_left , lub_right     As UByte
    Dim luw_square                                      As UInteger

    If gsw_player_blind > 0 Or gub_player_carrying_light = false Then
        ' no light
        If gub_player_temp_light_only Then
            For y = pub_from_y - 1 To pub_from_y + 1
                For x = pub_from_x - 1 To pub_from_x + 1
                    luw_square = fuw_cr_square( y , x )
                    Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bAnd ( 255 - MB_SQUARE_TEMP_LIGHT )
                    s_cr_put( y , x )
                Next
            Next
            gub_player_temp_light_only = false
        Else
            s_cr_put( pub_from_y , pub_from_x )
        End If
        s_cr_put( pub_to_y , pub_to_x )
        Return
    End If

    ' with a light: the squares that were lit only by it go dark...
    If gub_player_temp_light_only Then
        For y = pub_from_y - 1 To pub_from_y + 1
            For x = pub_from_x - 1 To pub_from_x + 1
                luw_square = fuw_cr_square( y , x )
                Poke luw_square + UB_SQUARE_FLAGS , Peek( luw_square + UB_SQUARE_FLAGS ) bAnd ( 255 - MB_SQUARE_TEMP_LIGHT )
            Next
        Next
    Else
        gub_player_temp_light_only = true
    End If

    ' ...and the squares around the new place are lit
    For y = pub_to_y - 1 To pub_to_y + 1
        For x = pub_to_x - 1 To pub_to_x + 1
            luw_square = fuw_cr_square( y , x )
            lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
            If gub_player_temp_light_only Then lub_flags = lub_flags bOr MB_SQUARE_TEMP_LIGHT
            lub_item = Peek( luw_square + UB_SQUARE_ITEM )
            If Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_WALL Then
                lub_flags = lub_flags bOr MB_SQUARE_PERM_LIGHT
                Poke luw_square + UB_SQUARE_FLAGS , lub_flags
                ' a wall the player now remembers goes on the mini map, ours
                s_cr_minimap_set( y , x )
            Else
                Poke luw_square + UB_SQUARE_FLAGS , lub_flags
                If ( lub_flags bAnd MB_SQUARE_FIELD_MARK ) = 0 And lub_item <> 0 Then
                    lub_category = fub_cr_item_category( lub_item )
                    If lub_category >= UB_TV_VIS_TRAP And lub_category <= UB_TV_STORE_DOOR Then
                        luw_square = fuw_cr_square( y , x )
                        Poke luw_square + UB_SQUARE_FLAGS , lub_flags bOr MB_SQUARE_FIELD_MARK
                    End If
                End If
            End If
        Next
    Next

    ' draw everything that may have changed: the box around both places
    If pub_from_y < pub_to_y Then
        lub_top    = pub_from_y - 1
        lub_bottom = pub_to_y + 1
    Else
        lub_top    = pub_to_y - 1
        lub_bottom = pub_from_y + 1
    End If
    If pub_from_x < pub_to_x Then
        lub_left  = pub_from_x - 1
        lub_right = pub_to_x + 1
    Else
        lub_left  = pub_to_x - 1
        lub_right = pub_from_x + 1
    End If
    For y = lub_top To lub_bottom
        For x = lub_left To lub_right
            s_cr_put( y , x )
        Next
    Next
End Sub


'##################################################################################################################################
' --- the screen around the map ---

Sub s_cr_depth()
    ' Moria's printCharacterCurrentDepth()
    s_core_clear_row( 23 , 65 , UB_WHITE )
    If guw_dungeon_level = 0 Then
        s_core_print_string_at( 23 , 65 , "Town level" , UB_WHITE )
    Else
        s_core_print_string_at( 23 , 65 , fs_core_number( guw_dungeon_level * 50 ) + " feet" , UB_WHITE )
    End If
End Sub


Sub s_cr_draw_all()
    ' the whole screen afresh, Moria's drawCavePanel()
    s_core_clear_screen()
    gub_message_length = 0
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
    s_cr_draw_panel()
    s_cr_depth()
    ' Moria's printCharacterWinner()
    If ( gub_game_noscore bAnd 2 ) <> 0 Then
        ' "Is wizard" or "Was wizard", the wizard library has the words, there is no room for them here
        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_STATUS )
    ElseIf ( gub_game_noscore bAnd 1 ) <> 0 Then
        ' a dead character brought back by a wizard, see the save library
        s_core_print_string_at( 22 , 0 , "Resurrected" , UB_BRIGHT_YELLOW )
    ElseIf gub_game_total_winner Then
        s_core_print_string_at( 22 , 0 , "*Winner*" , UB_BRIGHT_YELLOW )
    End If
    ' the words along the bottom: hungry, blind, fast...
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_STATUS_LINE )
End Sub


Sub s_cr_draw_around()
    ' draws the player's square and the eight around it again, and the player's details, after the moves library
    ' has changed something
    Dim y , x As UByte

    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            s_cr_put( y , x )
        Next
    Next
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Function fub_cr_after_flags() As UByte
    ' does what a library has asked for in gub_game_turn_flags, the MB_TURN_ bits: the turn library as each turn
    ' begins, and the spells, true if the player is to leave for another level
    Dim lub_flags As UByte

    lub_flags = gub_game_turn_flags
    gub_game_turn_flags = 0
    If lub_flags = 0 Then Return false
    If ( lub_flags bAnd MB_TURN_LIGHT_ROOM ) <> 0 Then s_cr_light_room( gub_player_row , gub_player_col )
    If ( lub_flags bAnd MB_TURN_RESET_VIEW ) <> 0 Then
        ' the player has been moved, Moria's dungeonResetView()
        If fub_cr_outside_panel( gub_player_row , gub_player_col , false ) Then lub_flags = lub_flags bOr MB_TURN_REDRAW_MAP
    End If
    If ( lub_flags bAnd MB_TURN_REDRAW_MAP ) <> 0 Then s_cr_draw_panel()
    If ( lub_flags bAnd MB_TURN_RESET_VIEW ) <> 0 Then
        s_cr_move_light( gub_player_row , gub_player_col , gub_player_row , gub_player_col )
        s_cr_light_rooms_around( gub_player_row , gub_player_col )
    End If
    If ( lub_flags bAnd ( MB_TURN_REDRAW_MAP bOr MB_TURN_UPDATE_MONSTERS bOr MB_TURN_RESET_VIEW ) ) <> 0 Then
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_UPDATE )
    End If
    If ( lub_flags bAnd MB_TURN_NEW_LEVEL ) <> 0 Then
        s_msg_flush()
        gub_core_request = UB_REQUEST_NEW_LEVEL
        Return true
    End If
    Return false
End Function


'##################################################################################################################################
' --- moving ---

Function fub_cr_move( pub_direction As UByte , pub_pickup As UByte ) As UByte
    ' the player tries to take a step, Moria's playerMove(), the directions are those of a numeric keypad,
    ' true if this stage should hand back to the core, to go into a store
    Dim lsw_y , lsw_x                                   As Integer
    Dim lub_old_y , lub_old_x , lub_feature , lub_item  As UByte
    Dim lub_category , lub_search                       As UByte
    Dim luw_square                                      As UInteger

    ' Moria's playerRandomMovement(): a confused player staggers three times in four, the dice are thrown whether
    ' they are confused or not... but not for standing still, 5, "never random if sitting", no die is thrown at all
    ' (found 16 October 2026 by comparing a fight with Umoria's, tools\test\compare-level.ps1: each 5 asked for one
    ' random number too many, and from then on the two games went their own ways)
    lub_search = false
    If pub_direction <> 5 Then
        If ful_core_random_number( 4 ) > 1 Then lub_search = true
    End If
    If gsw_player_confused > 0 And lub_search Then
        pub_direction    = ful_core_random_number( 9 )
        gub_game_running = 0
    End If

    ' Moria's playerMovePosition()
    lsw_y = Cast( Integer , gub_player_row ) + 1 - Cast( Integer , ( pub_direction - 1 ) / 3 )      ' 1 2 3 go down, 7 8 9 go up
    lsw_x = Cast( Integer , gub_player_col ) + Cast( Integer , ( pub_direction - 1 ) Mod 3 ) - 1    ' 1 4 7 go left, 3 6 9 go right
    If lsw_y < 0 Or lsw_x < 0 Or lsw_y >= Cast( Integer , gub_dungeon_rows ) Or lsw_x >= Cast( Integer , gub_dungeon_cols ) Then Return false

    luw_square  = fuw_cr_square( lsw_y , lsw_x )
    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
    lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
    ' a monster in the way is attacked, unless it is one the player cannot see that is inside a wall or a door,
    ' then it is the wall the player walks into
    lub_category = Peek( luw_square + UB_SQUARE_MONSTER )
    If lub_category > 1 Then
        lub_search = Peek( fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_category ) + UB_MONSTER_LIT_OFFSET )
        If lub_search <> 0 Or lub_feature < UB_TILE_MIN_CLOSED Then
            ' a runner stops, and if they can see what is in the way that is all they do
            If gub_game_running <> 0 Then
                gub_game_running = 0
                If lub_search <> 0 Then
                    gub_game_free_turn = true
                    Return false
                End If
            End If
            gub_lib_param_1 = lsw_y
            guw_lib_param_2 = lsw_x
            s_core_call_library( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_MONSTER )
            If gsw_lib_result Then
                ' it died: whatever it dropped is within two squares of where it stood, so within three of the player
                For lsw_y = Cast( Integer , gub_player_row ) - 3 To Cast( Integer , gub_player_row ) + 3
                    For lsw_x = Cast( Integer , gub_player_col ) - 3 To Cast( Integer , gub_player_col ) + 3
                        If lsw_y >= 0 And lsw_x >= 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) And lsw_x < Cast( Integer , gub_dungeon_cols ) Then s_cr_put( lsw_y , lsw_x )
                    Next
                Next
            End If
            s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
            Return false
        End If
    End If

    If lub_feature > UB_TILE_MAX_OPEN Then
        ' something solid, a runner just stops
        If lub_item <> 0 And gub_game_running = 0 Then
            lub_category = fub_cr_item_category( lub_item )
            If lub_category = UB_TV_RUBBLE Then s_core_message( UW_MSG_RUBBLE_BLOCKS )
            If lub_category = UB_TV_CLOSED_DOOR Then s_core_message( UW_MSG_DOOR_BLOCKS )
        End If
        gub_game_running   = 0
        gub_game_free_turn = true
        Return false
    End If

    ' the step is taken
    lub_old_y      = gub_player_row
    lub_old_x      = gub_player_col
    gub_player_row = lsw_y
    gub_player_col = lsw_x
    Poke fuw_cr_square( lub_old_y , lub_old_x ) + UB_SQUARE_MONSTER , 0
    Poke fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_MONSTER , 1

    If fub_cr_outside_panel( gub_player_row , gub_player_col , false ) Then
        s_cr_draw_panel()
        ' the "stop when map sector changes" option ends a run here, Moria's find_bound
        If ( guw_game_options bAnd MW_OPTION_FIND_BOUND ) <> 0 Then gub_game_running = 0
    End If
    ' a runner looks about: which way next, or is this the place to stop? the run library, Moria's playerAreaAffect()
    If gub_game_running <> 0 Then s_core_call_library( UB_PAGED_CODE_LIB_RUN , UB_LIB_RUN_AREA )

    ' have they noticed something? always, if they are that sharp, otherwise one step in so many
    ' N.B: as in Moria no dice are thrown for a player who always notices, and in search mode every step is a search
    lub_search = false
    If gsw_player_fos <= 1 Then
        lub_search = true
    ElseIf ful_core_random_number( gsw_player_fos ) = 1 Then
        lub_search = true
    ElseIf ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then
        lub_search = true
    End If
    If lub_search Then
        guw_lib_param_2 = Cast( UInteger , gsw_player_search )
        s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_SEARCH )
    End If

    s_cr_light_rooms_around( gub_player_row , gub_player_col )
    s_cr_move_light( lub_old_y , lub_old_x , gub_player_row , gub_player_col )

    If lub_item <> 0 Then
        ' Moria's carry(): a store's door is walked through, anything that can be picked up is
        luw_square   = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
        lub_category = Peek( luw_square + UB_ITEM_CATEGORY_OFFSET )
        If lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_VIS_TRAP Then
            ' a trap, the traps library, Moria's playerStepsOnTrap()
            gub_game_turn_flags = 0
            s_core_call_library( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_STEP )
            ' if stepped on falling rock trap, and space contains rubble, then step back into a clear area
            lub_item = Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
            If lub_item <> 0 Then
                If fub_cr_item_category( lub_item ) = UB_TV_RUBBLE Then
                    Poke fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_MONSTER , 0
                    Poke fuw_cr_square( lub_old_y , lub_old_x ) + UB_SQUARE_MONSTER , 1
                    s_cr_move_light( gub_player_row , gub_player_col , lub_old_y , lub_old_x )
                    lsw_y = gub_player_row
                    lsw_x = gub_player_col
                    gub_player_row = lub_old_y
                    gub_player_col = lub_old_x
                    s_cr_put( lsw_y , lsw_x )
                    ' check to see if we have stepped back onto another trap, if so, set it off
                    ' N.B: Moria also walks back in at a store's door here, a falling rock at a shop's door is not catered for
                    lub_item = Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
                    If lub_item <> 0 Then
                        lub_category = fub_cr_item_category( lub_item )
                        If lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_VIS_TRAP Then s_core_call_library( UB_PAGED_CODE_LIB_TRAPS , UB_LIB_TRAPS_STEP )
                    End If
                End If
            End If
            s_cr_draw_around()
            Return fub_cr_after_flags()
        End If
        If lub_category <= UB_TV_MAX_PICK_UP Then
            gub_lib_param_1 = pub_pickup
            s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_CARRY )
            If gsw_lib_result Then s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
            Return false
        End If
        If lub_category = UB_TV_STORE_DOOR Then
            ' a store's door: which store is in the door's sub category, 101 for the first of them
            gub_core_store   = Peek( luw_square + UB_ITEM_SUB_CATEGORY_OFFSET ) - 101
            gub_core_request = UB_REQUEST_STORE
            Return true
        End If
    End If
    Return false
End Function


Function fub_cr_stairs( pub_down As UByte ) As UByte
    ' Moria's dungeonGoUpLevel() and dungeonGoDownLevel(), true if the player is on their way to another level
    Dim lub_item        As UByte
    Dim lub_category    As UByte = 0

    lub_item = Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_ITEM )
    If lub_item <> 0 Then lub_category = fub_cr_item_category( lub_item )

    If pub_down Then
        If lub_category <> UB_TV_DOWN_STAIR Then
            s_core_message( UW_MSG_NO_DOWN_STAIR )
            gub_game_free_turn = true
            Return false
        End If
        guw_dungeon_level = guw_dungeon_level + 1
        s_core_message( UW_MSG_MAZE_DOWN )
    Else
        If lub_category <> UB_TV_UP_STAIR Then
            s_core_message( UW_MSG_NO_UP_STAIR )
            gub_game_free_turn = true
            Return false
        End If
        guw_dungeon_level = guw_dungeon_level - 1
        s_core_message( UW_MSG_MAZE_UP )
    End If
    s_core_message( UW_MSG_ONE_WAY_DOOR )
    s_msg_flush()
    gub_core_request = UB_REQUEST_NEW_LEVEL
    Return true
End Function


Sub s_cr_update_light()
    ' the player's light burns down by one each turn, Moria's playerUpdateLightStatus(): it goes out when there is
    ' nothing left, and a torch or lamp just taken up starts to shine
    Dim luw_light   As UInteger
    Dim lsw_turns   As Integer
    Dim lub_change  As UByte = false

    luw_light = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_LIGHT ) * UB_RECORD_SIZE + UB_ITEM_MISC_USE_OFFSET
    lsw_turns = Peek( Integer , luw_light )
    If gub_player_carrying_light Then
        If lsw_turns > 0 Then
            lsw_turns = lsw_turns - 1
            Poke UInteger luw_light , Cast( UInteger , lsw_turns )
            If lsw_turns = 0 Then
                gub_player_carrying_light = false
                s_core_message( UW_MSG_LIGHT_OUT )
                lub_change = true
            ElseIf lsw_turns < 40 Then
                If ful_core_random_number( 5 ) = 1 Then
                    If gsw_player_blind < 1 Then
                        s_dst_disturb( false , false )
                        s_core_message( UW_MSG_LIGHT_FAINT )
                    End If
                End If
            End If
        Else
            gub_player_carrying_light = false
            lub_change = true
        End If
    ElseIf lsw_turns > 0 Then
        lsw_turns = lsw_turns - 1
        Poke UInteger luw_light , Cast( UInteger , lsw_turns )
        gub_player_carrying_light = true
        lub_change = true
    End If
    ' what can be seen has changed: the player is disturbed, and the view put right, which also shows or hides the
    ' monsters, as Moria's playerDisturb( 0 , 1 ) and updateMonsters( false )
    If lub_change Then
        s_dst_disturb( false , true )
        s_cr_move_light( gub_player_row , gub_player_col , gub_player_row , gub_player_col )
    End If
End Sub


'##################################################################################################################################
' --- the stage itself ---

Sub s_cr_arrive()
    ' the player has just arrived on a new level, the start of Moria's playDungeon()
    gub_player_carrying_light = false
    If Peek( Integer , A_EQUIPMENT + Cast( UInteger , UB_EQUIP_LIGHT ) * UB_RECORD_SIZE + UB_ITEM_MISC_USE_OFFSET ) > 0 Then gub_player_carrying_light = true
    gub_player_temp_light_only = false
    If guw_dungeon_level > guw_player_max_depth Then guw_player_max_depth = guw_dungeon_level

    ' the player is on the map as creature number 1
    Poke fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_MONSTER , 1

    ' the window starts wherever the player is, the limits are Moria's: the last half window a window can start at
    ' N.B: forced, which is what Moria's unforced coordOutsidePanel() in dungeonResetView() comes to, because its
    ' generateCave() has set the window's edges to 0 just before
    gsb_panel_max_rows = ( gub_dungeon_rows / UB_VIEW_ROWS ) * 2 - 2
    gsb_panel_max_cols = ( gub_dungeon_cols / UB_VIEW_COLS ) * 2 - 2
    gsb_panel_row = -1
    gsb_panel_col = -1
    gub_shared_1  = fub_cr_outside_panel( gub_player_row , gub_player_col , true )
End Sub


Sub s_stage_crawl()
    Dim lub_leave       As UByte = false
    Dim lub_direction   As UByte
    Dim lub_no_command  As UByte
    Dim lub_counted     As UByte
    Dim lub_restored    As UByte
    Dim lub_from_store  As UByte
    Dim lub_answer      As UByte
    Dim lsw_confused    As Integer
    Dim lub_this        As UByte            ' the command this turn
    Dim lub_again       As UByte = 0        ' the command to do again if the key is still down, 0 if it is not one that repeats
    Dim lub_held        As UByte = 0        ' the key that was last pressed, the one that may still be down
    Dim lub_ran         As UByte = false    ' true while a run is going on, so that the player can be drawn again when it ends
    Dim lub_wait        As UByte = 0        ' how long that key has been watched since, in fiftieths of a second, 16 once it has started to repeat

    ' coming back out of a store the level is as it was left, anything else is an arrival on a new level
    If gub_core_request <> UB_REQUEST_STORE And gub_core_request <> UB_REQUEST_RESUME Then s_cr_arrive()
    ' a new character's first arrival, no turn has yet been played: see UB_CR_PRINT_SELF_AT_START above
    If gsl_game_turn < 0 And UB_CR_PRINT_SELF_AT_START Then guw_game_options = guw_game_options bOr MW_OPTION_PRINT_SELF
    If gsl_game_turn < 0 Then
        ' ...and UB_CR_BEEP_AT_START
        guw_game_options = guw_game_options bAnd ( $FFFF - MW_OPTION_BEEP )
        If UB_CR_BEEP_AT_START Then guw_game_options = guw_game_options bOr MW_OPTION_BEEP
        ' ...and UB_CR_ROGUELIKE_AT_START
        If UB_CR_ROGUELIKE_AT_START Then guw_game_options = guw_game_options bOr MW_OPTION_ROGUELIKE
    End If
    lub_counted = false
    If gub_core_request = UB_REQUEST_RESUME Then lub_counted = true
    ' ...a dead character brought back by a wizard has come from a save too, but to a level made afresh
    lub_restored = lub_counted
    If gub_core_request = UB_REQUEST_RESURRECTED Then lub_restored = true
    ' ...and coming back out of a store is the middle of a turn, see below
    lub_from_store = false
    If gub_core_request = UB_REQUEST_STORE Then lub_from_store = true
    gub_core_request = UB_REQUEST_NEW_LEVEL
    s_cr_draw_all()
    ' a saved game that can no longer be scored says so as it comes back, the wizard library has the words
    If lub_restored And gub_game_noscore <> 0 Then s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_RESTORED )
    ' ...and the weight of the pack, and of the weapon, is worked out again, with what it says, as Moria's loadGame()
    ' does: a save has the pack's weight taken out of the speeds, see the save library
    If lub_restored Then
        ' N.B: a save made before 15 October 2026 still has it in, so it is taken out here first
        If gsw_player_pack_heaviness <> 0 Then
            guw_lib_param_2 = Cast( UInteger , -gsw_player_pack_heaviness )
            s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
        End If
        gub_player_weapon_heavy   = false
        gsw_player_pack_heaviness = 0
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
    End If
    ' Moria's dungeonResetView(): the player's light, and the room they are standing in
    s_cr_move_light( gub_player_row , gub_player_col , gub_player_row , gub_player_col )
    s_cr_light_rooms_around( gub_player_row , gub_player_col )
    ' which monsters can be seen from here, Moria's updateMonsters( false ), but not coming out of a store: Moria's
    ' storeEnter() only draws the map again, the monsters' turn that follows sees to them, and when that turn is free
    ' they are left as they were, the distance from the player as it was before the step in (found 17 October 2026)
    If lub_from_store = false Then s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_UPDATE )

    ' N.B: a game brought back from a save carries on with the turn it was saved in, no new one begins
    ' N.B: coming out of a store, the step in always took a turn, NOT Moria's (sdo, 22 October): in Moria an ESCAPE at
    ' "Which one?" when selling leaves its inventoryGetInputForItemId()'s free turn set, and the turn the player stepped
    ' in on is free, the monsters do not have theirs and no new turn begins, Moria's own oddity, see umoria-oddities.md
    ' (found 17 October 2026, comparing an Elf ranger selling)
    If lub_from_store = false Then
        gub_game_free_turn = lub_counted
    Else
        gub_game_free_turn = false
    End If
    gub_game_disturb   = false
    ' the rest of the turn in which the player stepped into a store: Moria's storeEnter() is called in the middle of
    ' the player's move, and when the player comes out that turn goes on, the monsters have theirs, Moria's
    ' updateMonsters( true ), and the next turn begins after it, ours left the turn for the store at once, and the
    ' monsters' turn was lost, found 17 October 2026 by comparing a priest walking into the Magic Shop and out with
    ' Umoria (a townsperson that was awake had not moved)
    If lub_from_store And gub_game_free_turn = false And gub_game_character_dead = false Then
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_TURN )
        If fub_cr_after_flags() Then lub_leave = true
        If gub_game_disturb Then s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , UB_LIB_COMMANDS_DISTURB )
        If gub_game_character_dead Then
            s_msg_flush()
            gub_core_request = UB_REQUEST_DEATH
            lub_leave        = true
        End If
    End If
    ' the mini map is made afresh for this level, ours
    gub_minimap_rebuild = true
    While lub_leave = false
        ' a new turn begins, unless what the player last did took no time, Moria's player_free_turn
        If gub_game_free_turn = false Then
            gsl_game_turn = gsl_game_turn + 1
            ' turn over the store contents every, say, 1000 turns
            If guw_dungeon_level <> 0 Then
                If ( gsl_game_turn Mod 1000 ) = 0 Then s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_MAINTAIN )
            End If
            ' check for creature generation
            If ful_core_random_number( UB_MON_CHANCE_OF_NEW ) = 1 Then
                guw_lib_param_2 = 1
                gub_lib_param_1 = UB_MON_MAX_SIGHT
                s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_PLACE_AWAKE )
                ' one that comes into view disturbs the player at once, before this turn's eating and healing, see
                ' the same after the monsters' turn below
                If gub_game_disturb Then
                    s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , UB_LIB_COMMANDS_DISTURB )
                End If
            End If
            s_cr_update_light()
            ' what the player is suffering from wears off a little, the turn library does it, and if they have
            ' just gone blind, or can just see again, everything is drawn afresh
            s_core_call_library( UB_PAGED_CODE_LIB_TURN , UB_LIB_TURN_EFFECTS )
            ' the word of recall may have come
            If fub_cr_after_flags() Then lub_leave = true
        End If

        ' a run has just ended: the player is drawn again, they are not while they run unless they have asked to be
        If gub_game_running <> 0 Then
            lub_ran = true
        ElseIf lub_ran Then
            lub_ran = false
            s_cr_put( gub_player_row , gub_player_col )
        End If

        ' the player's command, unless they cannot move
        gub_game_free_turn = false
        lub_no_command     = true
        lub_counted        = false
        guw_key_code       = 1
        gub_key_char       = 0
        ' a resting player is stopped by a key, or by anything that disturbs them, Moria's playerDisturb()...
        ' ...a key is a minor disturbance, it does not turn searching off
        If gsw_player_rest <> 0 Or gub_game_running <> 0 Or guw_game_command_count <> 0 Then
            If fub_core_scan_key() <> 0 Then s_dst_disturb( false , false )
        End If
        If gub_game_disturb Then
            s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , UB_LIB_COMMANDS_DISTURB )
            If fub_cr_after_flags() Then lub_leave = true
        End If
        lub_direction = 0
        If gsw_player_paralysis < 1 And gsw_player_rest = 0 And gub_game_character_dead = false And lub_leave = false Then
            If gub_game_running <> 0 Then
                ' a runner takes the next step without being asked, Moria's playerRunAndFind()
                gub_game_running = gub_game_running + 1
                If gub_game_running > 102 Then
                    ' prevent infinite loops in find mode, will stop after moving 100 times
                    ' N.B: and the stop takes a turn, as in Moria, whose playerRunAndFind() leaves player_free_turn
                    ' false (found 22 October 2026 by reading the two, it was a free turn here, a turn short of Moria's)
                    s_core_message( UW_MSG_CATCH_BREATH )
                    gub_game_running   = 0
                Else
                    lub_direction = gub_game_run_direction
                End If
            Else
                lub_no_command = false
                If guw_game_command_count <> 0 Then
                    ' a command that was given a count goes round again, Moria's command_count
                    gub_key_char = gub_game_repeat_key bAnd ( 255 - MB_REPEAT_DONE )
                    guw_key_code = gub_key_char
                    lub_counted  = true
                    ' the last round's message is not run on into this round's, nor waits for -more-, as Moria's
                    ' message_ready_to_print = false at the start of every round (found 17 October 2026, #30T6 stopped
                    ' at the -more- after its second "You tunnel into the granite wall.")
                    If gub_message_length > 0 Then s_msg_clear()
                Else
                    If gub_game_repeat_key <> 0 Then
                        ' the repeating is over, the word for it comes off the bottom row
                        gub_game_repeat_key = 0
                        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
                    End If
                    ' the mini map, ours, is brought up to date here, and only here, as the game waits for the player
                    If gub_minimap_mode <> 0 Then s_core_call_library( UB_PAGED_CODE_LIB_MINIMAP , UB_LIB_MINIMAP_DRAW )
                    ' a key held down: walking, standing, searching, bashing and tunnelling are done again, turn after
                    ' turn, for as long as the key that started them stays down, nothing else is, and anything that
                    ' waits for a key of its own, -more- for one, needs the key let go and pressed again
                    ' N.B: the first time round the key must stay down for a third of a second, so that a tap is one step
                    ' N.B: lub_held is 0 when no key that can carry a repeat on was the last pressed, see below, and a key
                    ' scan that finds no key at all is 0 too, so 0 is never taken for a key held down
                    While lub_again <> 0 And lub_held <> 0 And lub_wait < UB_HOLD_FRAMES And fub_core_scan_key() = lub_held
                        ' the next frame, a fiftieth of a second on, as the core's s_core_wait_for_vblank() waits for it
                        Asm
                            ei
                            halt
                            di
                        End Asm
                        lub_wait = lub_wait + 1
                    End While
                    If lub_again <> 0 And lub_held <> 0 And fub_core_scan_key() = lub_held Then
                        gub_key_char = lub_again
                        guw_key_code = lub_again
                        ' N.B: this is how a command given a count goes round, it uses the direction it had the first time
                        gub_game_repeat_key = lub_again bOr MB_REPEAT_DONE
                    Else
                        s_core_get_key()
                        lub_held = 0
                        lub_wait = 0
                        If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) <> 0 Then
                            ' the rogue like commands: the key is turned into the command of ours that does the
                            ' same, the second commands library has the table, N.B: the key that was really
                            ' pressed is the one that a held key is known by
                            lub_this = gub_key_char
                            s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS_2 , UB_LIB_COMMANDS_2_ROGUELIKE )
                            If gsw_lib_result Then lub_held = lub_this
                        End If
                    End If
                    If gub_message_length > 0 Then s_msg_clear()
                End If
            End If
        End If

        lub_this = gub_key_char
        ' N.B: 5 is a step on the spot, Moria's "stay in one place": whatever lies there is picked up
        If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) Then lub_direction = gub_key_char - Code( "0" )
        If guw_key_code = UW_KEY_UP Then lub_direction = 8
        If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
        If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
        If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6

        If lub_direction <> 0 Then
            lub_leave = fub_cr_move( lub_direction , true )
            ' a run that was given a count stops when it has gone that many steps, the first is not counted here
            If guw_game_run_limit <> 0 And gub_game_running > 2 Then
                guw_game_run_limit = guw_game_run_limit - 1
                If guw_game_run_limit = 0 Then gub_game_running = 0
            End If
        ElseIf gub_key_char = Code( ">" ) Then
            lub_leave = fub_cr_stairs( true )
        ElseIf gub_key_char = Code( "<" ) Then
            lub_leave = fub_cr_stairs( false )
        ElseIf guw_key_code = 0 Then
            ' nobody has pressed a key for an hour: the game is saved, so that nothing is lost, and back to NextZXOS,
            ' N.B: Moria has no saving by the clock, the nearest it has is the save it makes when its input is cut off
            s_core_call_library( UB_PAGED_CODE_LIB_SAVE , UB_LIB_SAVE_SAVE )
            gub_core_end = true
            lub_leave    = true
        ElseIf lub_no_command = false Then
            ' every other command is the commands library's, it says what is to be done here afterwards
            gub_game_turn_flags     = 0
            gub_game_step_direction = 0
            gub_game_step_code      = UB_STEP_NONE
            s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , UB_LIB_COMMANDS_KEY )
            lub_answer = gsw_lib_result
            ' the game has been saved: back to the core, and so to NextZXOS
            If gub_core_end Then lub_leave = true
            If lub_answer = 0 Then
                ' a key that means nothing
                gub_game_free_turn = true
            Else
                If ( lub_answer bAnd MB_COMMAND_UNKNOWN ) <> 0 Then s_core_beep()
                If ( lub_answer bAnd MB_COMMAND_DRAW_AROUND ) <> 0 Then s_cr_draw_around()
                If ( lub_answer bAnd MB_COMMAND_DRAW_ALL ) <> 0 Then s_cr_draw_all()
                If gub_game_step_code = UB_STEP_PLAIN Then
                    ' a step without picking anything up
                    lub_leave = fub_cr_move( gub_game_step_direction , false )
                ElseIf gub_game_step_direction <> 0 Then
                    ' a trap has been disarmed, or set off: the player steps on to its square, and not staggering
                    lsw_confused = gsw_player_confused
                    gsw_player_confused = 0
                    lub_leave = fub_cr_move( gub_game_step_direction , false )
                    If gub_game_step_code = UB_STEP_DISARMED Then
                        gsw_player_confused = lsw_confused
                        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
                    Else
                        gsw_player_confused = gsw_player_confused + lsw_confused
                    End If
                End If
                If fub_cr_after_flags() Then lub_leave = true
            End If
        End If

        If lub_counted Then
            ' the first time round, the command may have asked which way, and the key that answered may still be down:
            ' it must be let go of first, or it is taken for a key pressed to break the count off (found 17 October
            ' 2026, #30T6 tunnelled once and stopped, Moria's count went on: the key it read was gone from its input)
            If ( gub_game_repeat_key bAnd MB_REPEAT_DONE ) = 0 Then
                While fub_core_scan_key() <> 0
                End While
            End If
            ' from now on the command uses the direction it was first given, and one fewer is left to do, or
            ' none if it could not be done at all
            gub_game_repeat_key = gub_game_repeat_key bOr MB_REPEAT_DONE
            If gub_game_free_turn Then
                guw_game_command_count = 0
            ElseIf guw_game_command_count <> 0 Then
                guw_game_command_count = guw_game_command_count - 1
                s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_MOVEMENT_STATE )
            End If
        End If

        ' which command, if any, a key held down does again next turn: one of the few that repeat, that the player
        ' gave, and that took a turn, and which key that is: the last one pressed, which for bashing and tunnelling
        ' is the direction, N.B: the arrow keys are codes 130 to 133
        ' N.B: only a key that can carry the repeat on, a direction or s, and not the key that answered a -more- in the
        ' middle of the command (found 16 October 2026: after a kill, SPACE or ESCAPE held down a moment at the -more-
        ' made the player walk on, a step a turn, for as long as it was held, the attack's direction being repeated)
        If lub_held = 0 Then
            If ( gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) ) Or ( gub_key_char >= Cast( UByte , UW_KEY_UP ) And gub_key_char <= Cast( UByte , UW_KEY_RIGHT ) ) Or gub_key_char = Code( "s" ) Then lub_held = gub_key_char
        End If
        ' N.B: the direction a held key or a rogue like command brought with it is done with, but not a count that
        ' has just been given, which begins next time round
        If lub_counted = false And guw_game_command_count = 0 Then gub_game_repeat_key = 0
        lub_again = 0
        If lub_no_command = false And lub_counted = false And gub_game_free_turn = false Then
            If ( lub_this >= Code( "1" ) And lub_this <= Code( "9" ) ) Or ( lub_this >= Cast( UByte , UW_KEY_UP ) And lub_this <= Cast( UByte , UW_KEY_RIGHT ) ) Then lub_again = lub_this
            If lub_this = Code( "s" ) Or lub_this = Code( "B" ) Or lub_this = Code( "T" ) Then lub_again = lub_this
        End If

        ' the monsters' turn, Moria's updateMonsters( true ), if the player used theirs
        If lub_leave = false And gub_game_free_turn = false And gub_game_character_dead = false Then
            s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_TURN )
            ' a monster's spell may have moved the player
            If fub_cr_after_flags() Then lub_leave = true
            ' a monster that came into view or attacked disturbs the player now, in this turn, as Moria's playerDisturb()
            ' does at once: a rest that it ends must be over before the next turn's eating and healing, which go by
            ' whether the player is resting (found 15 October 2026, a rest broken off by a monster ate one less than
            ' Umoria's, tools\test\compare-level.ps1)
            If gub_game_disturb Then
                s_core_call_library( UB_PAGED_CODE_LIB_COMMANDS , UB_LIB_COMMANDS_DISTURB )
            End If
        End If

        ' that may have been the end of the player
        If gub_game_character_dead Then
            s_msg_flush()
            gub_core_request = UB_REQUEST_DEATH
            lub_leave        = true
        End If
    End While
End Sub
