#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monster_moves()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-monster-include.bas"

' this page is a LIBRARY, not a stage: the monsters' turn, each of them waking, and moving, from Moria's monster.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , <which routine> ),
' the one routine is:
'
'   UB_LIB_MONSTER_MOVES_TURN   every monster on the level has its turn, from the newest to the oldest, Moria's
'                               updateMonsters( true ): how far it is from the player is worked out afresh, it moves
'                               as many times as its speed allows, a sleeping one may wake, and whether the player
'                               can see it is worked out again
'
'   UB_LIB_MONSTER_MOVES_DELETE monster number gub_lib_param_1 is taken off the map and out of the level's list,
'                               Moria's dungeonDeleteMonster(), for the player attack library, when a monster dies
'
' how a monster moves is in its creature's "movement" bits: some never move, some wander at random some or all of the
' time, the rest make for the player, by the straightest of five directions that is open to them, and attack when they
' get there, which is the monster attack library's business, stage-lib-monster-attack.bas, some cast spells instead
' (stage-lib-monster-spells.bas) and some breed (the monsters library), some open doors
' and some break them down, some walk through walls, some eat lesser monsters that are in their way, some pick up
' whatever they walk over
'
' while a monster has its turn, its record is in the working monster, A_MONSTER, and its creature's in A_CREATURE,
' the copy in the level's list is brought up to date when its turn is over
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, opening doors and getting out of rock are in stage-lib-monster-moves-2.bas

'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- its working storage is in globals.bas, under "private to stage-lib-monster-moves.bas", moved there on 22 October 2026 ---
#include "stage-monster-moves-include.bas"


Function fuw_mm_record( pub_monster As UByte ) As UInteger
    ' where the record of one of the level's monsters is
    Return fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
End Function


Sub s_mon_update_visibility( pub_monster As UByte )
    ' whether the player can see the working monster is worked out by the monsters library, Moria's
    ' monsterUpdateVisibility(), but only if it could matter: a monster that is not showing, and is too far away
    ' to be seen or the player is blind, stays as it is
    If gub_monster_lit = 0 Then
        If gub_monster_distance > UB_MON_MAX_SIGHT Or ( gul_player_status bAnd UL_PY_BLIND ) <> 0 Then Return
    End If
    gub_lib_param_1 = pub_monster
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_VISIBILITY )
End Sub

'##################################################################################################################################
' --- taking monsters off the level ---

Sub s_mm_remove_from_level( pub_monster As UByte )
    ' Moria's dungeonRemoveMonsterFromLevel(): the monster is gone from the map, its record stays in the list, marked
    ' by having less than no hit points, until the list is next gone through
    Dim luw_record      As UInteger
    Dim lub_y , lub_x   As UByte

    luw_record = fuw_mm_record( pub_monster )
    lub_y = Peek( luw_record + UB_MONSTER_ROW_OFFSET )
    lub_x = Peek( luw_record + UB_MONSTER_COL_OFFSET )
    Poke UInteger luw_record , $FFFF            ' hit points of -1
    Poke fuw_cr_square( lub_y , lub_x ) + UB_SQUARE_MONSTER , 0
    If Peek( luw_record + UB_MONSTER_LIT_OFFSET ) Then s_cr_put( lub_y , lub_x )
    If gsw_game_multiply_total > 0 Then gsw_game_multiply_total = gsw_game_multiply_total - 1
End Sub


Sub s_mm_delete_record( pub_monster As UByte )
    ' Moria's dungeonDeleteMonsterRecord(): the list is kept with no gaps, so the last monster in it moves into the
    ' place of the one that has gone, and the square it stands on is told its new number
    Dim lub_last                    As UByte
    Dim luw_record , luw_last       As UInteger

    lub_last = gub_dungeon_monster_next - 1
    If pub_monster <> lub_last Then
        luw_last   = fuw_mm_record( lub_last )
        luw_record = fuw_mm_record( pub_monster )
        s_core_ram_copy( luw_last , luw_record , UB_RECORD_SIZE )
        Poke fuw_cr_square( Peek( luw_record + UB_MONSTER_ROW_OFFSET ) , Peek( luw_record + UB_MONSTER_COL_OFFSET ) ) + UB_SQUARE_MONSTER , pub_monster
    End If
    gub_dungeon_monster_next = lub_last
End Sub


'##################################################################################################################################
' --- which way to go ---

Sub s_mm_random_directions( pub_first As UByte )
    ' fills the directions from pub_first to the fifth with random ones, 1 to 9, 5 is "stay where you are"
    Dim i As UByte

    For i = pub_first To 4
        Poke A_MM_DIRECTIONS + i , fuw_mm_random( 9 )
    Next
End Sub


Sub s_mm_get_move_direction()
    ' Moria's monsterGetMoveDirection(): the five directions that lead towards the player, the straightest first, then
    ' the two either side of it, then the two either side of those, which of each pair comes first depends on which
    ' side of the straight line the player is
    ' N.B: Moria spells this out as a switch of eight cases, here the same lists are a table, ten directions to a case:
    ' five for when the case's test is true and five for when it is not
    Dim lsw_y , lsw_x , lsw_ay , lsw_ax     As Integer
    Dim lub_movement , lub_row , lub_test   As UByte
    Dim luw_entry                           As UInteger

    lsw_y = Cast( Integer , gub_monster_row ) - Cast( Integer , gub_player_row )
    lsw_x = Cast( Integer , gub_monster_col ) - Cast( Integer , gub_player_col )
    If lsw_y < 0 Then
        lub_movement = 8
        lsw_ay = -lsw_y
    Else
        lub_movement = 0
        lsw_ay = lsw_y
    End If
    If lsw_x > 0 Then
        lub_movement = lub_movement + 4
        lsw_ax = lsw_x
    Else
        lsw_ax = -lsw_x
    End If
    ' this has the advantage of preventing the diamond maneuvre, also faster
    If lsw_ay > ( lsw_ax << 1 ) Then
        lub_movement = lub_movement + 2
    ElseIf lsw_ax > ( lsw_ay << 1 ) Then
        lub_movement = lub_movement + 1
    End If

    ' which case: Moria's 0, 1 and 9, 2 and 6, 4, 5 and 13, 8, 10 and 14, 12
    lub_row = 0
    If lub_movement = 1 Or lub_movement = 9 Then lub_row = 1
    If lub_movement = 2 Or lub_movement = 6 Then lub_row = 2
    If lub_movement = 4 Then lub_row = 3
    If lub_movement = 5 Or lub_movement = 13 Then lub_row = 4
    If lub_movement = 8 Then lub_row = 5
    If lub_movement = 10 Or lub_movement = 14 Then lub_row = 6
    If lub_movement = 12 Then lub_row = 7
    ' ...and its test: the diagonals ask which of the two distances is longer, across asks whether the player is
    ' below, up and down asks whether the player is to the right
    lub_test = false
    If ( lub_movement bAnd 3 ) = 0 Then
        If lsw_ay > lsw_ax Then lub_test = true
    ElseIf ( lub_movement bAnd 3 ) = 1 Then
        If lsw_y < 0 Then lub_test = true
    Else
        If lsw_x < 0 Then lub_test = true
    End If

    luw_entry = @mm_direction_table + Cast( UInteger , lub_row ) * 10
    If lub_test = false Then luw_entry = luw_entry + 5
    s_core_ram_copy( luw_entry , A_MM_DIRECTIONS , 5 )
    Return

    ' the table sits here, after the Return, so that it is part of the code and never runs as instructions
mm_direction_table:
    Asm
        defb 9, 8, 6, 7, 3,   9, 6, 8, 3, 7     ; 0:        up and right
        defb 6, 3, 9, 2, 8,   6, 9, 3, 8, 2     ; 1 and 9:  right
        defb 8, 9, 7, 6, 4,   8, 7, 9, 4, 6     ; 2 and 6:  up
        defb 7, 8, 4, 9, 1,   7, 4, 8, 1, 9     ; 4:        up and left
        defb 4, 1, 7, 2, 8,   4, 7, 1, 8, 2     ; 5 and 13: left
        defb 3, 2, 6, 1, 9,   3, 6, 2, 9, 1     ; 8:        down and right
        defb 2, 3, 1, 6, 4,   2, 1, 3, 4, 6     ; 10 and 14: down
        defb 1, 2, 4, 3, 7,   1, 4, 2, 7, 3     ; 12:       down and left
    End Asm
End Sub


'##################################################################################################################################
' --- making a move ---

Sub s_mm_open_door( pub_y As UByte , pub_x As UByte , pub_item As UByte )
    ' Moria's monsterOpenDoor(), there is no room for it here, it is in the second monster moves library
    gub_lib_param_1 = pub_y
    guw_lib_param_2 = ( Cast( UInteger , pub_item ) << 8 ) bOr pub_x
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES_2 , UB_LIB_MONSTER_MOVES_2_DOOR )
End Sub


Sub s_mm_moves_on_player( pub_y As UByte , pub_x As UByte , pub_other As UByte )
    ' Moria's monsterMovesOnPlayer(): who is on the square the monster wants: the player is attacked, another monster
    ' is in the way, unless this one eats its lessers
    Dim luw_theirs  As UInteger

    If pub_other = 1 Then
        ' the player sees who is hitting them
        If gub_monster_lit = 0 Then s_mon_update_visibility( gub_mm_monster )
        ' Moria's monsterAttackPlayer()
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_ATTACK , UB_LIB_MONSTER_ATTACK_PLAYER )
        gub_mm_do_move = false
        gub_mm_do_turn = true
    ElseIf pub_other > 1 Then
        If pub_y <> gub_monster_row Or pub_x <> gub_monster_col Then
            gub_mm_do_move = false
            If ( gul_creature_movement bAnd UL_CM_EATS_OTHER ) <> 0 Then
                ' the other monster's worth in experience, read straight from its creature's record
                luw_theirs = Peek( UInteger , fuw_mm_record( pub_other ) + UB_MONSTER_CREATURE_OFFSET )
                luw_theirs = Peek( UInteger , fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_theirs ) + UB_CREATURE_KILL_EXP_OFFSET )
                If guw_creature_kill_exp >= luw_theirs Then
                    gub_mm_seen_high = gub_mm_seen_high bOr $08     ' UL_CM_EATS_OTHER
                    gub_mm_do_move = true
                    ' it ate an already processed monster, handle normally, if it eats this one, an already
                    ' processed monster will take its place, causing all kinds of havoc: delay the kill a bit
                    s_mm_remove_from_level( pub_other )
                    If gub_mm_monster < pub_other Then s_mm_delete_record( pub_other )
                End If
            End If
        End If
    End If
End Sub


Sub s_mm_allowed_to_move( pub_y As UByte , pub_x As UByte )
    ' Moria's monsterAllowedToMove(): the monster goes to the square, taking whatever lies there if it is that kind
    Dim lub_item As UByte

    If ( gul_creature_movement bAnd UL_CM_PICKS_UP ) <> 0 Then
        lub_item = Peek( fuw_cr_square( pub_y , pub_x ) + UB_SQUARE_ITEM )
        If lub_item <> 0 Then
            If fub_cr_item_category( lub_item ) <= UB_TV_MAX_OBJECT Then
                gub_mm_seen_high = gub_mm_seen_high bOr $10     ' UL_CM_PICKS_UP
                gub_lib_param_1 = pub_y
                guw_lib_param_2 = pub_x
                s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT )
                s_cr_put( pub_y , pub_x )
            End If
        End If
    End If

    ' Moria's dungeonMoveCreatureRecord()
    Poke fuw_cr_square( gub_monster_row , gub_monster_col ) + UB_SQUARE_MONSTER , 0
    Poke fuw_cr_square( pub_y , pub_x ) + UB_SQUARE_MONSTER , gub_mm_monster

    If gub_monster_lit Then
        gub_monster_lit = 0
        Poke fuw_mm_record( gub_mm_monster ) + UB_MONSTER_LIT_OFFSET , 0
        s_cr_put( gub_monster_row , gub_monster_col )
    End If
    gub_monster_row      = pub_y
    gub_monster_col      = pub_x
    Poke fuw_mm_record( gub_mm_monster ) + UB_MONSTER_ROW_OFFSET , pub_y
    Poke fuw_mm_record( gub_mm_monster ) + UB_MONSTER_COL_OFFSET , pub_x
    gub_monster_distance = fub_mon_distance( gub_player_row , gub_player_col , pub_y , pub_x )
    gub_mm_do_turn       = true
End Sub


Sub s_mm_make_move()
    ' Moria's makeMove(): the directions are tried in order until one of them uses up the monster's turn
    Dim i , lub_direction , lub_y , lub_x   As UByte
    Dim lub_feature , lub_item              As UByte
    Dim luw_square                          As UInteger

    gub_mm_do_turn = false
    gub_mm_do_move = false
    i = 0
    While gub_mm_do_turn = false And i < 5
        lub_direction = Peek( A_MM_DIRECTIONS + i )
        i = i + 1
        ' Moria's playerMovePosition(), 5 is the square the monster is on, a monster is never on the edge of the map
        lub_y = gub_monster_row + 1 - ( lub_direction - 1 ) / 3
        lub_x = gub_monster_col + ( lub_direction - 1 ) Mod 3 - 1

        luw_square  = fuw_cr_square( lub_y , lub_x )
        lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
        lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
        If lub_feature <> UB_TILE_BOUNDARY_WALL Then
            If lub_feature <= UB_TILE_MAX_OPEN Then
                ' floor is open?
                gub_mm_do_move = true
            ElseIf ( gul_creature_movement bAnd UL_CM_PHASE ) <> 0 Then
                ' creature moves through walls?
                gub_mm_seen_high = gub_mm_seen_high bOr $04     ' UL_CM_PHASE
                gub_mm_do_move = true
            ElseIf lub_item <> 0 Then
                ' creature can open doors?
                s_mm_open_door( lub_y , lub_x , lub_item )
            End If

            ' a rune of protection on the square, Moria's glyphOfWardingProtection(): it holds unless the creature
            ' is strong enough to break it
            If gub_mm_do_move And lub_item <> 0 Then
                luw_square = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
                If Peek( luw_square + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_VIS_TRAP And Peek( luw_square + UB_ITEM_SUB_CATEGORY_OFFSET ) = 99 Then
                    If fuw_mm_random( UW_OBJECTS_RUNE_PROTECTION ) < gub_creature_level Then
                        If lub_y = gub_player_row And lub_x = gub_player_col Then s_core_message( UW_MSG_THE_RUNE_OF_PROTECTION_IS_BROKEN )
                        gub_lib_param_1 = lub_y
                        guw_lib_param_2 = lub_x
                        s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT )
                    Else
                        gub_mm_do_move = false
                        ' if the creature moves only to attack, don't let it move if the rune saves the player
                        If ( gul_creature_movement bAnd UL_CM_ATTACK_ONLY ) <> 0 Then gub_mm_do_turn = true
                    End If
                End If
            End If

            ' creature has attempted to move on player?
            If gub_mm_do_move Then s_mm_moves_on_player( lub_y , lub_x , Peek( fuw_cr_square( lub_y , lub_x ) + UB_SQUARE_MONSTER ) )

            ' creature has been allowed move
            If gub_mm_do_move Then s_mm_allowed_to_move( lub_y , lub_x )
        End If
    End While
End Sub


Sub s_mm_move()
    ' Moria's monsterMove(): which kind of move this creature makes this time
    Dim lub_random As UByte

    ' does the critter multiply? rest could be negative, to be safe, only use mod with positive values
    If ( gul_creature_movement bAnd UL_CM_MULTIPLY ) <> 0 And gsw_game_multiply_total <= 75 Then
        If ( Abs( gsw_player_rest ) Mod 7 ) = 0 Then
            ' the monsters library puts the new one down, Moria's monsterMultiplyCritter()
            gub_lib_param_1 = gub_mm_monster
            s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_MULTIPLY )
            If gsw_lib_result Then gub_mm_seen_high = gub_mm_seen_high bOr $20     ' UL_CM_MULTIPLY
        End If
    End If
    ' if in wall, must immediately escape to a clear area, Moria's monsterMoveOutOfWall(), the second monster
    ' moves library works out the ways out, and what happens if there are none
    If ( gul_creature_movement bAnd UL_CM_PHASE ) = 0 Then
        If Peek( fuw_cr_square( gub_monster_row , gub_monster_col ) + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_WALL Then
            ' if the monster is already dead, don't kill it again!
            If gsw_monster_hp >= 0 Then
                s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES_2 , UB_LIB_MONSTER_MOVES_2_WALL )
                If gsw_lib_result Then s_mm_make_move()
                s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES_2 , UB_LIB_MONSTER_MOVES_2_WALL_AFTER )
            End If
            Return
        End If
    End If

    ' Moria's monsterDoMove(): a confused creature staggers, an undead one that has been frightened backs away
    If gub_monster_confused <> 0 Then
        If ( guw_creature_defenses bAnd UW_CD_UNDEAD ) <> 0 Then
            s_mm_get_move_direction()
            Poke A_MM_DIRECTIONS     , 10 - Peek( A_MM_DIRECTIONS )
            Poke A_MM_DIRECTIONS + 1 , 10 - Peek( A_MM_DIRECTIONS + 1 )
            Poke A_MM_DIRECTIONS + 2 , 10 - Peek( A_MM_DIRECTIONS + 2 )
            s_mm_random_directions( 3 )         ' may attack only if cornered
        Else
            s_mm_random_directions( 0 )
        End If
        ' don't move him if he is not supposed to move!
        If ( gul_creature_movement bAnd UL_CM_ATTACK_ONLY ) = 0 Then s_mm_make_move()
        gub_monster_confused = gub_monster_confused - 1
        Return
    End If
    ' a creature that casts spells may do that instead of moving, Moria's monsterCastSpell()
    If ( gul_creature_spells bAnd UL_CS_FREQ ) <> 0 Then
        gub_lib_param_1 = gub_mm_monster
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_SPELLS , UB_LIB_MONSTER_SPELLS_CAST )
        If gsw_lib_result Then
            ' the player remembers that this kind of creature casts this spell, how often they have seen one
            ' cast, and that one killed them, the spell's number is the answer, 1 to 17
            If gub_monster_lit Then
                ful_core_recall( guw_monster_creature , UB_RECALL_SPELLS , Cast( ULong , 1 ) << ( gsw_lib_result - 1 ) )
                ful_core_recall( guw_monster_creature , UB_RECALL_SPELL_SEEN , 0 )
                If gub_game_character_dead Then ful_core_recall( guw_monster_creature , UB_RECALL_DEATHS , 1 )
            End If
            Return
        End If
    End If

    ' the creatures that wander some or all of the time: 75% random movement, 40%, 20%
    ' N.B: lub_random is the bit of the creature's "movement" that made it wander, 75%, 40% or 20%, for the monster memory
    lub_random = 0
    If ( gul_creature_movement bAnd UL_CM_75_RANDOM ) <> 0 Then
        If fuw_mm_random( 100 ) < 75 Then lub_random = $20
    End If
    If lub_random = 0 And ( gul_creature_movement bAnd UL_CM_40_RANDOM ) <> 0 Then
        If fuw_mm_random( 100 ) < 40 Then lub_random = $10
    End If
    If lub_random = 0 And ( gul_creature_movement bAnd UL_CM_20_RANDOM ) <> 0 Then
        If fuw_mm_random( 100 ) < 20 Then lub_random = $08
    End If
    If lub_random Then
        ' Moria's monsterMoveRandomly()
        gub_mm_seen_low = gub_mm_seen_low bOr lub_random
        s_mm_random_directions( 0 )
        s_mm_make_move()
        Return
    End If

    If ( gul_creature_movement bAnd UL_CM_MOVE_NORMAL ) <> 0 Then
        ' Moria's monsterMoveNormally(): towards the player, but one time in 200 anywhere
        If fuw_mm_random( 200 ) = 1 Then
            s_mm_random_directions( 0 )
        Else
            s_mm_get_move_direction()
        End If
        gub_mm_seen_low = gub_mm_seen_low bOr 2
        s_mm_make_move()
        Return
    End If

    If ( gul_creature_movement bAnd UL_CM_ATTACK_ONLY ) <> 0 Then
        ' Moria's monsterAttackWithoutMoving(): it never moves, but it attacks a player who is beside it
        If gub_monster_distance < 2 Then
            s_mm_get_move_direction()
            s_mm_make_move()
        Else
            ' learn that the monster does not move when it should have moved, but didn't
            gub_mm_seen_low = gub_mm_seen_low bOr 1
        End If
        Return
    End If
    If ( gul_creature_movement bAnd UL_CM_ONLY_MAGIC ) <> 0 And gub_monster_distance < 2 Then
        ' a little hack for Quylthulgs, so that one will eventually notice that they have no physical attacks,
        ' and another so that one can eventually learn their speed
        If ful_core_recall( guw_monster_creature , UB_RECALL_ATTACK , 1 ) > 20 Then ful_core_recall( guw_monster_creature , UB_RECALL_MOVEMENT , UL_CM_ONLY_MAGIC )
    End If
End Sub


Sub s_mm_attacking_update( psw_moves As Integer )
    ' Moria's monsterAttackingUpdate(): the monster has as many goes as its speed gives it, on each a sleeping
    ' one may be woken by the player, the quieter the player the less likely, a stunned one may recover, and one
    ' that is awake and has its wits moves, but only a monster the player can see, or that the player is close
    ' enough to for it to care, does anything at all
    Dim lub_notice  As UByte
    Dim lsl_notice  As Long
    Dim lsl_limit   As Long
    Dim i           As Integer

    While psw_moves > 0
        psw_moves = psw_moves - 1
        gub_mm_seen_low  = 0
        gub_mm_seen_high = 0
        gub_mm_wake      = 0
        ' monsters trapped in rock must be given a turn also, so that they will die or dig out immediately
        lub_notice = false
        If gub_monster_lit <> 0 Or gub_monster_distance <= gub_creature_area_radius Then
            lub_notice = true
        ElseIf ( gul_creature_movement bAnd UL_CM_PHASE ) = 0 Then
            If Peek( fuw_cr_square( gub_monster_row , gub_monster_col ) + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_WALL Then lub_notice = true
        End If
        If lub_notice Then
            If gsw_monster_sleep > 0 Then
                If gub_player_aggravate Then
                    gsw_monster_sleep = 0
                Else
                    lub_notice = false
                    If gsw_player_rest = 0 And gsw_player_paralysis < 1 Then
                        lub_notice = true
                    ElseIf fuw_mm_random( 50 ) = 1 Then
                        lub_notice = true
                    End If
                    If lub_notice Then
                        lsl_notice = fuw_mm_random( 1024 )
                        lsl_limit  = 1
                        i = 29 - gsw_player_stealth
                        While i > 0
                            lsl_limit = lsl_limit << 1
                            i = i - 1
                        End While
                        If lsl_notice * lsl_notice * lsl_notice <= lsl_limit Then
                            gsw_monster_sleep = gsw_monster_sleep - 100 / Cast( Integer , gub_monster_distance )
                            ' the player may remember whether it woke or slept on
                            gub_mm_wake = 2
                            If gsw_monster_sleep <= 0 Then
                                gsw_monster_sleep = 0
                                gub_mm_wake       = 1
                            End If
                        End If
                    End If
                End If
            End If

            If gub_monster_stunned <> 0 Then
                ' NOTE: balrog = 100*100 = 10000, it always recovers instantly
                If fuw_mm_random( 5000 ) < Cast( UInteger , gub_creature_level ) * gub_creature_level Then
                    gub_monster_stunned = 0
                Else
                    gub_monster_stunned = gub_monster_stunned - 1
                End If
                If gub_monster_stunned = 0 And gub_monster_lit <> 0 Then
                    s_msg( "The " + fs_core_text_at( A_CREATURE ) + " recovers and glares at you." )
                End If
            End If

            If gsw_monster_sleep = 0 And gub_monster_stunned = 0 Then s_mm_move()
        End If

        s_mon_update_visibility( gub_mm_monster )
        ' the visibility test reads the creature afresh, it is the same one
        ' what the player has learnt from this, if they can see the monster, Moria's memoryUpdateRecall()
        If gub_monster_lit Then
            If gub_mm_wake = 1 Then ful_core_recall( guw_monster_creature , UB_RECALL_WAKE , 1 )
            If gub_mm_wake = 2 Then ful_core_recall( guw_monster_creature , UB_RECALL_IGNORE , 1 )
            If ( gub_mm_seen_low bOr gub_mm_seen_high ) <> 0 Then ful_core_recall( guw_monster_creature , UB_RECALL_MOVEMENT , ( Cast( ULong , gub_mm_seen_high ) << 16 ) bOr gub_mm_seen_low )
        End If
    End While
End Sub


Sub s_mm_one_monster()
    ' the turn of the monster whose number is in gub_mm_monster, the body of Moria's updateMonsters( true )
    Dim lsw_moves As Integer

    s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , gub_mm_monster , A_MONSTER )
    If gsw_monster_hp < 0 Then
        ' it was eaten since the list was last gone through
        s_mm_delete_record( gub_mm_monster )
        Return
    End If
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , guw_monster_creature , A_CREATURE )
    gub_monster_distance = fub_mon_distance( gub_player_row , gub_player_col , gub_monster_row , gub_monster_col )

    ' how many moves: a monster faster than the player has more than one a turn, one that is slower
    ' has one only every so many turns
    If gsw_monster_speed > 0 Then
        lsw_moves = gsw_monster_speed
        If gsw_player_rest <> 0 Then lsw_moves = 1
    Else
        lsw_moves = 0
        If ( gsl_game_turn Mod ( 2 - gsw_monster_speed ) ) = 0 Then lsw_moves = 1
    End If

    If lsw_moves <= 0 Then
        s_mon_update_visibility( gub_mm_monster )
    Else
        s_mm_attacking_update( lsw_moves )
    End If
    s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , gub_mm_monster , A_MONSTER )
    ' a monster that died on its own turn, of its own breath say, is taken off the list here
    If gsw_monster_hp < 0 Then s_mm_delete_record( gub_mm_monster )
End Sub

Sub s_mm_turn()
    ' Moria's updateMonsters( true ), with its monsterMovementRate()
    Dim lsw_moves                               As Integer
    Dim luw_record , luw_kind                   As UInteger
    Dim lub_row , lub_col , lub_distance        As UByte
    Dim lub_radius , lub_phase , lub_far        As UByte

    gub_mm_monster = gub_dungeon_monster_next
    While gub_mm_monster > UB_MON_MIN_INDEX And gub_game_character_dead = false
        gub_mm_monster = gub_mm_monster - 1

        ' most of a level's monsters are far away and out of sight, and for those all that Moria does in a turn is
        ' note how far away they now are: nothing wakes, moves, or shows unless the monster can be seen, is within
        ' the distance its kind cares about, or is stuck in rock, so that case is dealt with here, in the level's
        ' list itself, without taking the monster and its creature out and putting the monster back, which is
        ' what takes the time, N.B: no random number is asked for either way, so this changes nothing but the speed
        lub_far    = false
        luw_record = fuw_mm_record( gub_mm_monster )
        If Peek( Integer , luw_record ) >= 0 And Peek( luw_record + UB_MONSTER_LIT_OFFSET ) = 0 Then
            lub_row      = Peek( luw_record + UB_MONSTER_ROW_OFFSET )
            lub_col      = Peek( luw_record + UB_MONSTER_COL_OFFSET )
            lub_distance = fub_mon_distance( gub_player_row , gub_player_col , lub_row , lub_col )
            If lub_distance > UB_MON_MAX_SIGHT Then
                ' 39 is where a creature's record has the distance it cares about, 28 the third byte of its
                ' "movement", where the bit for passing through walls is (UL_CM_PHASE)
                luw_kind   = fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) )
                lub_radius = Peek( luw_kind + 39 )
                lub_phase  = Peek( luw_kind + 28 ) bAnd $04
                If lub_distance > lub_radius Then
                    lub_far = true
                    If lub_phase = 0 Then
                        If Peek( fuw_cr_square( lub_row , lub_col ) + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_WALL Then lub_far = false
                    End If
                End If
            End If
        End If

        If lub_far Then
            Poke fuw_mm_record( gub_mm_monster ) + UB_MONSTER_DISTANCE_OFFSET , lub_distance
        Else
            s_mm_one_monster()
        End If
    End While
    ' it is nobody's turn now, Moria's hack_monptr = -1
    gub_mm_monster = 0
End Sub
Sub s_lib_monster_moves()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_MONSTER_MOVES_TURN Then
        s_mm_turn()
    ElseIf gub_lib_function = UB_LIB_MONSTER_MOVES_REMOVE Then
        ' Moria's dungeonRemoveMonsterFromLevel()
        s_mm_remove_from_level( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_MONSTER_MOVES_DELETE Then
        ' Moria's dungeonDeleteMonster()
        s_mm_remove_from_level( gub_lib_param_1 )
        s_mm_delete_record( gub_lib_param_1 )
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
