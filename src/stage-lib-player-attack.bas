#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_player_attack()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-disturb-include.bas"
#include "stage-combat-include.bas"

' this page is a LIBRARY, not a stage: the player fighting a monster hand to hand, and what follows when it dies,
' from Moria's player.cpp, player_magic.cpp, monster.cpp, dungeon.cpp and ui.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_PLAYER_ATTACK , <which routine> ),
' the one routine is:
'
'   UB_LIB_PLAYER_ATTACK_MONSTER    the player attacks the monster on the square at row gub_lib_param_1 and column
'                                   guw_lib_param_2, Moria's playerAttackPosition(): as many blows as their strength
'                                   and dexterity give them with the weapon in hand, or two with bare fists, each may
'                                   miss, a hit may be a critical one, and a weapon made to slay does more to the
'                                   creatures it was made for, a monster that dies leaves what it was carrying, the
'                                   player gains experience for it, and with enough experience a level,
'                                   gsw_lib_result is true if the monster died
'
'   UB_LIB_PLAYER_ATTACK_TAKE_HIT   monster number gub_lib_param_1 takes guw_lib_param_2 of damage, from a spell
'                                   say, Moria's monsterTakeHit(), gsw_lib_result is true if that killed it, in
'                                   which case it has left what it carried and the player has the experience
'
'   UB_LIB_PLAYER_ATTACK_KILL       monster number gub_lib_param_1 has died of something that was not the player's
'                                   doing, another monster's breath say: it leaves what it carried, Moria's
'                                   monsterDeath(), and is taken off the level, at once if guw_lib_param_2 is 0,
'                                   or only off the map, to come out of the list when its turn would have been
'
' while it is being fought the monster's record is in the working monster, A_MONSTER, and its creature's in A_CREATURE
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing more of what the player learns about a kind of creature by fighting it
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_pa_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


'##################################################################################################################################
' --- experience ---

Sub s_pa_gain_kill_experience()
    ' Moria's playerGainKillExperience(): what the creature is worth, times its level, shared out over the
    ' player's level, the part of a point left over is kept for next time
    Dim lsl_exp , lsl_quotient , lsl_remainder As Long

    lsl_exp       = Cast( Long , guw_creature_kill_exp ) * gub_creature_level
    lsl_quotient  = lsl_exp / guw_player_level
    lsl_remainder = lsl_exp Mod guw_player_level
    lsl_remainder = lsl_remainder * 65536 / guw_player_level + guw_player_exp_fraction
    If lsl_remainder >= 65536 Then
        lsl_quotient = lsl_quotient + 1
        guw_player_exp_fraction = lsl_remainder - 65536
    Else
        guw_player_exp_fraction = lsl_remainder
    End If
    gsl_player_exp = gsl_player_exp + lsl_quotient
End Sub


'##################################################################################################################################
' --- a monster dying ---

' --- its working storage is in globals.bas, under "private to stage-lib-player-attack.bas", moved there on 22 October 2026 ---


Sub s_pa_summon_object( pub_y As UByte , pub_x As UByte , psw_amount As Integer , pub_type As UByte )
    ' Moria's dungeonSummonObject(): puts a number of things down near a square, each on an open, empty square
    ' picked at random within two of it that can be seen from it, objects, gold, or either
    Dim lsw_y , lsw_x       As Integer
    Dim lub_tries           As UByte
    Dim lub_gold            As UByte
    Dim luw_square          As UInteger

    lub_gold = true
    If pub_type = 1 Or pub_type = 5 Then lub_gold = false
    Do
        lub_tries = 0
        While lub_tries <= 20
            lsw_y = Cast( Integer , pub_y ) - 3 + Cast( Integer , fuw_pa_random( 5 ) )
            lsw_x = Cast( Integer , pub_x ) - 3 + Cast( Integer , fuw_pa_random( 5 ) )
            ' Moria's coordInBounds(): anywhere but the edge of the map
            If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                ' a clear line from where the monster died, the monsters library works that out
                guw_lib_param_2 = ( Cast( UInteger , pub_y ) << 8 ) bOr pub_x
                gsw_lib_result  = ( lsw_y << 8 ) bOr lsw_x
                s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_LOS )
                If gsw_lib_result Then
                    luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
                    If Peek( luw_square ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then
                        If pub_type = 3 Or pub_type = 7 Then
                            lub_gold = true
                            If fuw_pa_random( 100 ) < 50 Then lub_gold = false
                        End If
                        gub_lib_param_1 = lsw_y
                        guw_lib_param_2 = lsw_x
                        If lub_gold Then
                            s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_GOLD )
                        Else
                            ' a creature that only carries small things drops nothing bigger than fits a chest
                            If pub_type >= 4 Then guw_lib_param_2 = guw_lib_param_2 bOr $0100
                            s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT )
                        End If
                        ' did the player see it fall? Moria's caveTileVisible()
                        If ( Peek( fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x ) + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then
                            If lub_gold Then
                                gub_pa_seen_gold = gub_pa_seen_gold + 1
                            Else
                                gub_pa_seen_objects = gub_pa_seen_objects + 1
                            End If
                        End If
                        lub_tries = 20
                    End If
                End If
            End If
            lub_tries = lub_tries + 1
        End While
        psw_amount = psw_amount - 1
    Loop While psw_amount <> 0
End Sub


Sub s_pa_monster_death()
    ' Moria's monsterDeath(), with its monsterDeathItemDropType() and monsterDeathItemDropCount(): what the
    ' creature leaves behind is in its "movement" bits, what kind of thing and how many
    Dim lub_type    As UByte
    Dim lsw_count   As Integer

    lub_type = 0
    If ( gul_creature_movement bAnd UL_CM_CARRY_OBJ ) <> 0 Then lub_type = 1
    If ( gul_creature_movement bAnd UL_CM_CARRY_GOLD ) <> 0 Then lub_type = lub_type + 2
    If ( gul_creature_movement bAnd UL_CM_SMALL_OBJ ) <> 0 Then lub_type = lub_type + 4

    lsw_count = 0
    If ( gul_creature_movement bAnd UL_CM_60_RANDOM ) <> 0 Then
        If fuw_pa_random( 100 ) < 60 Then lsw_count = lsw_count + 1
    End If
    If ( gul_creature_movement bAnd UL_CM_90_RANDOM ) <> 0 Then
        If fuw_pa_random( 100 ) < 90 Then lsw_count = lsw_count + 1
    End If
    If ( gul_creature_movement bAnd UL_CM_1D2_OBJ ) <> 0 Then lsw_count = lsw_count + fuw_pa_random( 2 )
    If ( gul_creature_movement bAnd UL_CM_2D2_OBJ ) <> 0 Then lsw_count = lsw_count + fuw_core_dice_roll( 2 , 2 )
    If ( gul_creature_movement bAnd UL_CM_4D2_OBJ ) <> 0 Then lsw_count = lsw_count + fuw_core_dice_roll( 4 , 2 )

    gub_pa_seen_objects = 0
    gub_pa_seen_gold    = 0
    If lsw_count > 0 Then s_pa_summon_object( gub_monster_row , gub_monster_col , lsw_count , lub_type )

    ' maybe the player died in mid-turn
    If ( gul_creature_movement bAnd UL_CM_WIN ) <> 0 And gub_game_character_dead = false Then
        gub_game_total_winner = true
        ' Moria's printCharacterWinner(), the walking stage puts it back whenever it draws the screen afresh, N.B: a
        ' wizard is told they are one instead, the wizard library has those words
        If ( gub_game_noscore bAnd 2 ) <> 0 Then
            s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_STATUS )
        Else
            s_core_print_string_at( 22 , 0 , "*Winner*" , UB_BRIGHT_YELLOW )
        End If
        s_core_message( UW_MSG_CONGRATULATIONS_YOU_HAVE_WON_THE )
        s_core_message( UW_MSG_YOU_CANNOT_SAVE_THIS_GAME_BUT_YOU )
    End If
    ' what the player saw it leave, as bits of a creature's "movement": things, small things only, gold, and
    ' how many of them altogether, the callers put it into the monster memory
    gul_pa_treasure = 0
    If gub_pa_seen_objects <> 0 Then
        gul_pa_treasure = UL_CM_CARRY_OBJ
        If ( lub_type bAnd 4 ) <> 0 Then gul_pa_treasure = gul_pa_treasure bOr UL_CM_SMALL_OBJ
    End If
    If gub_pa_seen_gold <> 0 Then gul_pa_treasure = gul_pa_treasure bOr UL_CM_CARRY_GOLD
    gul_pa_treasure = gul_pa_treasure bOr ( Cast( ULong , gub_pa_seen_objects + gub_pa_seen_gold ) << UB_CM_TR_SHIFT )
End Sub


Sub s_pa_remember_treasure()
    ' the most things one of this kind has ever been seen to leave is what is remembered, with the kinds of thing
    Dim lul_known As ULong

    lul_known = ful_core_recall( guw_monster_creature , UB_RECALL_MOVEMENT , 0 )
    If ( lul_known bAnd UL_CM_TREASURE ) > ( gul_pa_treasure bAnd UL_CM_TREASURE ) Then
        gul_pa_treasure = ( gul_pa_treasure bAnd ( $FFFFFFFF - UL_CM_TREASURE ) ) bOr ( lul_known bAnd UL_CM_TREASURE )
    End If
    ful_core_recall( guw_monster_creature , UB_RECALL_SET_MOVEMENT , ( lul_known bAnd ( $FFFFFFFF - UL_CM_TREASURE ) ) bOr gul_pa_treasure )
End Sub


Function fub_pa_monster_take_hit( pub_monster As UByte , psw_damage As Integer ) As UByte
    ' Moria's monsterTakeHit(): the working monster is hurt, and wakes, true if that killed it
    gsw_monster_sleep = 0
    gsw_monster_hp    = gsw_monster_hp - psw_damage
    If gsw_monster_hp >= 0 Then Return false

    s_pa_monster_death()
    ' the player remembers what this kind of creature was carrying, and that they killed one
    If ( gsw_player_blind < 1 And gub_monster_lit <> 0 ) Or ( gul_creature_movement bAnd UL_CM_WIN ) <> 0 Then
        s_pa_remember_treasure()
        ful_core_recall( guw_monster_creature , UB_RECALL_KILLS , 1 )
    End If
    s_pa_gain_kill_experience()
    ' it is taken off the map and out of the level's list, Moria's dungeonDeleteMonster(), the monster moves
    ' library keeps that list
    ' N.B: in the middle of the monsters' turn one that has not yet had its go is only taken off the map, it is
    ' struck from the list when its turn would have come, Moria's hack_monptr
    gub_lib_param_1 = pub_monster
    If gub_game_monster_turn < pub_monster Then
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
    Else
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_REMOVE )
    End If
    Return true
End Function


'##################################################################################################################################
' --- the player's blows ---

Function fsw_pa_blows( puw_weight As UInteger ) As Integer
    ' Moria's playerAttackBlows(): how many blows a turn with a weapon of this weight, from the player's strength
    ' for its weight and their dexterity, a weapon too heavy to wield properly gets one, and a penalty to hit,
    ' which is left in gsw_lib_result
    Dim lsw_strength , lsw_dexterity , lsw_adjusted As Integer
    Dim lub_row , lub_col                           As UByte

    gsw_lib_result = 0
    lsw_strength   = Peek( A_PLAYER_STATS_USED + UB_STAT_STR )
    If lsw_strength * 15 < Cast( Integer , puw_weight ) Then
        gsw_lib_result = lsw_strength * 15 - Cast( Integer , puw_weight )
        Return 1
    End If

    lsw_dexterity = Peek( A_PLAYER_STATS_USED + UB_STAT_DEX )
    lub_col = 5
    If lsw_dexterity < 118 Then lub_col = 4
    If lsw_dexterity < 108 Then lub_col = 3
    If lsw_dexterity < 68 Then lub_col = 2
    If lsw_dexterity < 19 Then lub_col = 1
    If lsw_dexterity < 10 Then lub_col = 0

    lsw_adjusted = lsw_strength * 10 / Cast( Integer , puw_weight )
    lub_row = 6
    If lsw_adjusted < 9 Then lub_row = 5
    If lsw_adjusted < 7 Then lub_row = 4
    If lsw_adjusted < 5 Then lub_row = 3
    If lsw_adjusted < 4 Then lub_row = 2
    If lsw_adjusted < 3 Then lub_row = 1
    If lsw_adjusted < 2 Then lub_row = 0

    lsw_adjusted = Peek( @pa_blows_table + Cast( UInteger , lub_row ) * 6 + lub_col )
    Return lsw_adjusted

    ' Moria's blows_table[], it sits here, after the Return, so that it is part of the code and never runs as
    ' instructions: a row for each band of strength against weight, a column for each band of dexterity
pa_blows_table:
    Asm
        defb 1, 1, 1, 1, 1, 1
        defb 1, 1, 1, 1, 2, 2
        defb 1, 1, 1, 2, 2, 3
        defb 1, 1, 2, 2, 3, 3
        defb 1, 2, 2, 3, 3, 4
        defb 1, 2, 2, 3, 4, 4
        defb 2, 2, 3, 3, 4, 4
    End Asm
    ' never reached, it is here because the compiler wants a function to end with a Return
    Return 0
End Function


Function fub_pa_attack( pub_y As UByte , pub_x As UByte ) As UByte
    ' Moria's playerAttackPosition() and playerAttackMonster(), true if the monster died
    Dim lub_monster , lub_category  As UByte
    Dim luw_weapon                  As UInteger
    Dim lsw_blows , lsw_to_hit      As Integer
    Dim lsw_base , lsw_damage       As Integer
    Dim lsw_weight , lsw_count      As Integer
    Dim ls_name                     As String

    If gsw_player_afraid > 0 Then
        s_core_message( UW_MSG_YOU_ARE_TOO_AFRAID )
        Return false
    End If

    lub_monster = Peek( fuw_core_map_square( gub_level_map_page , pub_y , pub_x ) + UB_SQUARE_MONSTER )
    s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , guw_monster_creature , A_CREATURE )
    gsw_monster_sleep = 0

    ' does the player know what they're fighting?
    If gub_monster_lit = 0 Then
        ls_name = "it"
    Else
        ls_name = "the " + fs_core_text_at( A_CREATURE )
    End If

    ' the weapon in hand, an empty hand is category 0, Moria's playerCalculateToHitBlows()
    luw_weapon   = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_WIELD ) * UB_RECORD_SIZE
    lub_category = Peek( luw_weapon + UB_ITEM_CATEGORY_OFFSET )
    lsw_weight   = Peek( Integer , luw_weapon + UB_ITEM_WEIGHT_OFFSET )
    If lub_category <> 0 Then
        lsw_blows  = fsw_pa_blows( lsw_weight )
        lsw_to_hit = gsw_lib_result
    Else
        ' bare hands
        lsw_blows  = 2
        lsw_to_hit = -3
    End If
    ' fix for arrows
    If lub_category >= UB_TV_SLING_AMMO And lub_category <= UB_TV_SPIKE Then lsw_blows = 1
    lsw_to_hit = lsw_to_hit + gsw_player_to_hit

    ' if the creature is not seen it is harder to hit, Moria's playerCalculateBaseToHit()
    lsw_base = gsw_player_bth
    If gub_monster_lit = 0 Then
        lsw_base = gsw_player_bth / 2 - lsw_to_hit * 2 - Cast( Integer , guw_player_level ) * Cast( Integer , gub_class_adj_bth ) / 2
    End If

    While lsw_blows > 0
        lsw_blows = lsw_blows - 1
        If fub_cb_test_hit( lsw_base , lsw_to_hit , gub_creature_ac , gub_class_adj_bth ) = false Then
            s_msg( "You miss " + ls_name + "." )
        Else
            s_msg( "You hit " + ls_name + "." )
            If lub_category <> 0 Then
                lsw_damage = fuw_core_dice_roll( Peek( luw_weapon + UB_ITEM_DAMAGE_OFFSET ) , Peek( luw_weapon + UB_ITEM_DAMAGE_OFFSET + 1 ) )
                lsw_damage = fsw_cb_magic_damage( luw_weapon , lsw_damage , guw_monster_creature )
                lsw_damage = fsw_cb_critical( lsw_weight , lsw_to_hit , lsw_damage , gub_class_adj_bth )
            Else
                lsw_damage = fuw_core_dice_roll( 1 , 1 )
                lsw_damage = fsw_cb_critical( 1 , 0 , lsw_damage , gub_class_adj_bth )
            End If
            lsw_damage = lsw_damage + gsw_player_to_damage
            If lsw_damage < 0 Then lsw_damage = 0

            If gub_player_confuse_monster Then
                gub_player_confuse_monster = false
                s_core_message( UW_MSG_YOUR_HANDS_STOP_GLOWING )
                ' N.B: Moria asks for no random number here if the creature never sleeps
                If ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then
                    s_msg( ls_name + " is unaffected." )
                ElseIf fuw_pa_random( UB_MON_MAX_LEVELS ) < gub_creature_level Then
                    s_msg( ls_name + " is unaffected." )
                Else
                    s_msg( ls_name + " appears confused." )
                    If gub_monster_confused <> 0 Then
                        gub_monster_confused = gub_monster_confused + 3
                    Else
                        gub_monster_confused = 2 + fuw_pa_random( 16 )
                    End If
                End If
                ' one time in four the player learns whether this kind of creature can be confused
                ' N.B: as in Moria the dice are thrown only if the monster can be seen
                If gub_monster_lit Then
                    If fuw_pa_random( 4 ) = 1 Then ful_core_recall( guw_monster_creature , UB_RECALL_DEFENSES , guw_creature_defenses bAnd UW_CD_NO_SLEEP )
                End If
            End If

            ' see if we done it in
            If fub_pa_monster_take_hit( lub_monster , lsw_damage ) Then
                s_msg( "You have slain " + ls_name + "." )
                ' with enough experience, a new level, Moria's displayCharacterExperience()
                s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
                Return true
            End If

            ' use missiles up
            If lub_category >= UB_TV_SLING_AMMO And lub_category <= UB_TV_SPIKE Then
                lsw_count = Peek( luw_weapon + UB_ITEM_COUNT_OFFSET ) - 1
                Poke luw_weapon + UB_ITEM_COUNT_OFFSET , lsw_count
                gsw_player_pack_weight = gsw_player_pack_weight - lsw_weight
                gul_player_status      = gul_player_status bOr UL_PY_STR_WGT
                If lsw_count = 0 Then
                    ' the last of them, the hand is empty, a record of nothing but zeros
                    gsw_player_equipment_count = gsw_player_equipment_count - 1
                    For lsw_count = 0 To UB_RECORD_SIZE - 1
                        Poke luw_weapon + lsw_count , 0
                    Next
                    lub_category = 0
                    s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
                End If
            End If
        End If
    End While

    ' the monster lives, what has happened to it is kept
    s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
    Return false
End Function


Sub s_lib_player_attack()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 , lub_died As UByte
    Dim lub_monster                                    As UByte
    Dim lsw_damage                                     As Integer

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the creatures database is read through the items' slot, so that slot is put back as it was found too
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_died = false
    If gub_lib_function = UB_LIB_PLAYER_ATTACK_MONSTER Then
        lub_died = fub_pa_attack( gub_lib_param_1 , guw_lib_param_2 )
    ElseIf gub_lib_function = UB_LIB_PLAYER_ATTACK_KILL Then
        ' the monster's own record and creature are fetched for this, and put back as they were afterwards
        lub_monster = gub_lib_param_1
        lsw_damage  = guw_lib_param_2
        s_core_ram_copy( A_MONSTER , A_PA_MONSTER , UB_RECORD_SIZE )
        s_core_ram_copy( A_CREATURE , A_PA_CREATURE , UB_RECORD_SIZE )
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , guw_monster_creature , A_CREATURE )
        s_pa_monster_death()
        ' killed by another monster's breath: what it left is remembered if the player saw, the kill is not theirs
        If gub_monster_lit Then s_pa_remember_treasure()
        gub_lib_param_1 = lub_monster
        If lsw_damage = 0 Then
            s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
        Else
            s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_REMOVE )
        End If
        s_core_ram_copy( A_PA_MONSTER , A_MONSTER , UB_RECORD_SIZE )
        s_core_ram_copy( A_PA_CREATURE , A_CREATURE , UB_RECORD_SIZE )
        lub_died = true
    ElseIf gub_lib_function = UB_LIB_PLAYER_ATTACK_DROP Then
        ' a chest has been opened: what it holds falls out as if a creature with those "movement" bits had
        ' died on the square at row gub_lib_param_1 and column guw_lib_param_2, the bits are in gsl_lib_long_1
        s_core_ram_copy( A_MONSTER , A_PA_MONSTER , UB_RECORD_SIZE )
        s_core_ram_copy( A_CREATURE , A_PA_CREATURE , UB_RECORD_SIZE )
        gub_monster_row       = gub_lib_param_1
        gub_monster_col       = guw_lib_param_2
        gul_creature_movement = gsl_lib_long_1
        s_pa_monster_death()
        s_core_ram_copy( A_PA_MONSTER , A_MONSTER , UB_RECORD_SIZE )
        s_core_ram_copy( A_PA_CREATURE , A_CREATURE , UB_RECORD_SIZE )
    ElseIf gub_lib_function = UB_LIB_PLAYER_ATTACK_TAKE_HIT Then
        lub_monster = gub_lib_param_1
        lsw_damage  = guw_lib_param_2
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , guw_monster_creature , A_CREATURE )
        lub_died = fub_pa_monster_take_hit( lub_monster , lsw_damage )
        If lub_died = false Then s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_died
End Sub
