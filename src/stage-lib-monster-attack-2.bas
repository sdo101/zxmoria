#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monster_attack_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"
#include "stage-monster-include.bas"

' this page is the second half of the monster attack LIBRARY, see stage-lib-monster-attack.bas, which is the page
' the monster moves library calls, that page hands on to this one the attacks that get at what the player is
' wearing and carrying, from Moria's monster.cpp, inventory.cpp and spells.cpp:
'
'   UB_LIB_MONSTER_ATTACK_2_EXECUTE     the attack of kind gub_lib_param_1, which has already landed, with damage
'                                       guw_lib_param_2, by the working monster (A_MONSTER, creature in A_CREATURE):
'                                            5 fire             burns things in the pack
'                                            6 acid             eats at armour, and at things in the pack
'                                            7 cold             shatters potions and flasks
'                                            8 lightning        destroys rings, wands and spikes
'                                            9 corrosion        rusts armour, and metal things in the pack
'                                           12 steal money      and the thief may vanish
'                                           13 steal object     ditto
'                                           21 disenchant       takes the plusses off something worn
'                                           22 eat food
'                                           23 eat light        the torch or lamp burns down
'                                           24 eat charges      a wand or staff is emptied, and the monster is healed by it
'
'   UB_LIB_MONSTER_ATTACK_2_DAMAGE      the same damage with none of the monster's words, for traps: gub_lib_param_1
'                                       is 5 fire, 6 acid, 7 cold, 8 lightning, 9 corroding gas or 10 poison gas, guw_lib_param_2
'                                       the damage, what is doing it must already be in A_KILLER, Moria's
'                                       damageFire(), damageAcid(), damageCold(), damageLightningBolt() and
'                                       damageCorrodingGas()
'
'   UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY   the working monster (A_MONSTER) goes to an open square within
'                                       guw_lib_param_2 of where it is, Moria's spellTeleportAwayMonster()
'
' what is NOT here yet:
'   - nothing that is known of
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Dim gub_m2_quiet            As UByte    At A_LIB_PRIVATE + 16       ' true when the damage is a trap's, which has said its own piece

#define UB_SET_FLAMMABLE    1       ' which things in the pack a kind of damage can destroy, Moria's setFlammableItems()...
#define UB_SET_ACID         2
#define UB_SET_CORRODABLE   3
#define UB_SET_FROST        4
#define UB_SET_LIGHTNING    5


Function fuw_m2_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_m2_record( pub_place As UByte ) As UInteger
    ' where the record for one place in the pack or the equipment is
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Sub s_m2_destroy( pub_place As UByte )
    ' one of what is in a place of the pack goes, Moria's inventoryDestroyItem()
    guw_lib_param_2 = pub_place
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY )
End Sub


Function fub_m2_in_set( pub_place As UByte , pub_set As UByte ) As UByte
    ' true if the thing in a place of the pack is of a kind this damage destroys, Moria's five "set" routines
    Dim luw_record      As UInteger
    Dim lub_category    As UByte
    Dim lul_flags       As ULong

    luw_record   = fuw_m2_record( pub_place )
    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    lul_flags    = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )

    If pub_set = UB_SET_FLAMMABLE Then
        If lub_category = UB_TV_STAFF Or lub_category = UB_TV_SCROLL1 Or lub_category = UB_TV_SCROLL2 Then Return true
        If lub_category = UB_TV_ARROW Or lub_category = UB_TV_BOW Or lub_category = UB_TV_HAFTED Or lub_category = UB_TV_POLEARM Or lub_category = UB_TV_BOOTS Or lub_category = UB_TV_GLOVES Or lub_category = UB_TV_CLOAK Or lub_category = UB_TV_SOFT_ARMOR Then
            If ( lul_flags bAnd UL_TR_RES_FIRE ) = 0 Then Return true
        End If
    ElseIf pub_set = UB_SET_ACID Then
        If lub_category = UB_TV_MISC Or lub_category = UB_TV_CHEST Then Return true
        If lub_category = UB_TV_BOLT Or lub_category = UB_TV_ARROW Or lub_category = UB_TV_BOW Or lub_category = UB_TV_HAFTED Or lub_category = UB_TV_POLEARM Or lub_category = UB_TV_BOOTS Or lub_category = UB_TV_GLOVES Or lub_category = UB_TV_CLOAK Or lub_category = UB_TV_SOFT_ARMOR Then
            If ( lul_flags bAnd UL_TR_RES_ACID ) = 0 Then Return true
        End If
    ElseIf pub_set = UB_SET_CORRODABLE Then
        If lub_category = UB_TV_SWORD Or lub_category = UB_TV_HELM Or lub_category = UB_TV_SHIELD Or lub_category = UB_TV_HARD_ARMOR Or lub_category = UB_TV_WAND Then Return true
    ElseIf pub_set = UB_SET_FROST Then
        If lub_category = UB_TV_POTION1 Or lub_category = UB_TV_POTION2 Or lub_category = UB_TV_FLASK Then Return true
    Else
        If lub_category = UB_TV_RING Or lub_category = UB_TV_WAND Or lub_category = UB_TV_SPIKE Then Return true
    End If
    Return false
End Function


Function fub_m2_damage_items( pub_set As UByte , pub_chance As UByte ) As UByte
    ' Moria's inventoryDamageItem(): each thing in the pack of the kind in danger has a small chance of being
    ' destroyed, how many were comes back
    ' N.B: as in Moria, when something goes the things after it move up a place and the next one is passed over
    Dim lub_damage  As UByte = 0
    Dim lsw_i       As Integer = 0

    While lsw_i < gsw_player_pack_unique
        If fub_m2_in_set( lsw_i , pub_set ) Then
            If fuw_m2_random( 100 ) < pub_chance Then
                s_m2_destroy( lsw_i )
                lub_damage = lub_damage + 1
            End If
        End If
        lsw_i = lsw_i + 1
    End While
    Return lub_damage
End Function


Function fub_m2_minus_ac( pul_resists As ULong ) As UByte
    ' Moria's damageMinusAC(): one of the pieces of armour the player has on takes the damage for them, it either
    ' resists it or loses a point of armour class, true if a piece of armour was in the way
    Dim lub_count , lub_place   As UByte
    Dim luw_record              As UInteger
    Dim ls_name                 As String

    ' which pieces are being worn, in Moria's order: body, arm, outer, hands, head, feet
    lub_count = 0
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_BODY ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_BODY
        lub_count = lub_count + 1
    End If
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_ARM ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_ARM
        lub_count = lub_count + 1
    End If
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_OUTER ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_OUTER
        lub_count = lub_count + 1
    End If
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_HANDS ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_HANDS
        lub_count = lub_count + 1
    End If
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_HEAD ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_HEAD
        lub_count = lub_count + 1
    End If
    If Peek( fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_FEET ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        Poke A_LIB_PRIVATE + lub_count , UB_PACK_SIZE + UB_EQUIP_FEET
        lub_count = lub_count + 1
    End If
    If lub_count = 0 Then Return false

    lub_place  = Peek( A_LIB_PRIVATE + fuw_m2_random( lub_count ) - 1 )
    luw_record = fuw_m2_record( lub_place )
    If ( Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET ) bAnd pul_resists ) = 0 Then
        If Peek( Integer , luw_record + UB_ITEM_AC_OFFSET ) + Peek( Integer , luw_record + UB_ITEM_TO_AC_OFFSET ) <= 0 Then Return false
    End If

    ' its name, without "a" or the numbers
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    gub_lib_param_1 = false
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    ls_name = fs_core_text_at( A_TEXT_BUFFER )
    If ( Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET ) bAnd pul_resists ) <> 0 Then
        s_msg( "Your " + ls_name + " resists damage!" )
    Else
        s_msg( "Your " + ls_name + " is damaged!" )
        Poke UInteger luw_record + UB_ITEM_TO_AC_OFFSET , Cast( UInteger , Peek( Integer , luw_record + UB_ITEM_TO_AC_OFFSET ) - 1 )
        s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
    End If
    Return true
End Function


Sub s_m2_visibility()
    ' whether the player can see the working monster, worked out by the monsters library
    gub_lib_param_1 = Peek( fuw_core_map_square( gub_level_map_page , gub_monster_row , gub_monster_col ) + UB_SQUARE_MONSTER )
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_VISIBILITY )
End Sub


Sub s_m2_teleport_away( pub_distance As UByte )
    ' Moria's spellTeleportAwayMonster(): the working monster goes to an open square picked at random within a
    ' distance of where it is, the distance grows if nowhere can be found
    Dim lsw_y , lsw_x , lsw_distance    As Integer
    Dim lub_counter , lub_monster       As UByte
    Dim luw_square                      As UInteger
    Dim lub_found                       As UByte

    lsw_distance = pub_distance
    lub_counter  = 0
    Do
        Do
            lsw_y = Cast( Integer , gub_monster_row ) + Cast( Integer , fuw_m2_random( 2 * lsw_distance + 1 ) ) - ( lsw_distance + 1 )
            lsw_x = Cast( Integer , gub_monster_col ) + Cast( Integer , fuw_m2_random( 2 * lsw_distance + 1 ) ) - ( lsw_distance + 1 )
            ' Moria's coordInBounds(): anywhere but the edge of the map
            lub_found = true
            If lsw_y < 1 Or lsw_x < 1 Or lsw_y >= Cast( Integer , gub_dungeon_rows ) - 1 Or lsw_x >= Cast( Integer , gub_dungeon_cols ) - 1 Then lub_found = false
        Loop Until lub_found
        lub_counter = lub_counter + 1
        If lub_counter > 9 Then
            lub_counter  = 0
            lsw_distance = lsw_distance + 5
        End If
        luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
        lub_found  = true
        If Peek( luw_square ) >= UB_TILE_MIN_CLOSED Then lub_found = false
        If Peek( luw_square + UB_SQUARE_MONSTER ) <> 0 Then lub_found = false
    Loop Until lub_found

    ' it vanishes from where it was: too far to be seen, as far as the monsters library can tell, so it is rubbed out
    lub_monster = Peek( fuw_core_map_square( gub_level_map_page , gub_monster_row , gub_monster_col ) + UB_SQUARE_MONSTER )
    gub_monster_distance = 255
    s_m2_visibility()
    ' Moria's dungeonMoveCreatureRecord()
    Poke fuw_core_map_square( gub_level_map_page , gub_monster_row , gub_monster_col ) + UB_SQUARE_MONSTER , 0
    Poke fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x ) + UB_SQUARE_MONSTER , lub_monster
    gub_monster_row      = lsw_y
    gub_monster_col      = lsw_x
    luw_square = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
    Poke luw_square + UB_MONSTER_ROW_OFFSET , gub_monster_row
    Poke luw_square + UB_MONSTER_COL_OFFSET , gub_monster_col
    gub_monster_distance = fub_mon_distance( gub_player_row , gub_player_col , gub_monster_row , gub_monster_col )
    s_m2_visibility()
End Sub


Sub s_m2_execute( pub_type As UByte , psw_damage As Integer )
    ' the second half of Moria's executeAttackOnPlayer()
    Dim lsl_gold                        As Long
    Dim lsw_i , lsw_turns               As Integer
    Dim luw_record                      As UInteger
    Dim lub_flag , lub_place , lub_done As UByte

    If pub_type = 5 Then
        ' fire attack, Moria's damageFire()
        If gub_m2_quiet = false Then s_core_message( UW_MSG_YOU_ARE_ENVELOPED_IN_FLAMES )
        If gub_player_resist_fire Then psw_damage = psw_damage / 3
        If gsw_player_heat_resistance > 0 Then psw_damage = psw_damage / 3
        s_hit_player( psw_damage )
        If fub_m2_damage_items( UB_SET_FLAMMABLE , 3 ) > 0 Then s_core_message( UW_MSG_THERE_IS_SMOKE_COMING_FROM_YOUR )

    ElseIf pub_type = 6 Then
        ' acid attack, Moria's damageAcid()
        If gub_m2_quiet = false Then s_core_message( UW_MSG_YOU_ARE_COVERED_IN_ACID )
        lub_flag = 0
        If fub_m2_minus_ac( UL_TR_RES_ACID ) Then lub_flag = 1
        If gub_player_resist_acid Then lub_flag = lub_flag + 2
        s_hit_player( psw_damage / ( lub_flag + 1 ) )
        If fub_m2_damage_items( UB_SET_ACID , 3 ) > 0 Then s_core_message( UW_MSG_THERE_IS_AN_ACRID_SMELL_COMING )

    ElseIf pub_type = 7 Then
        ' cold attack, Moria's damageCold()
        If gub_m2_quiet = false Then s_core_message( UW_MSG_YOU_ARE_COVERED_WITH_FROST )
        If gub_player_resist_cold Then psw_damage = psw_damage / 3
        If gsw_player_cold_resistance > 0 Then psw_damage = psw_damage / 3
        s_hit_player( psw_damage )
        If fub_m2_damage_items( UB_SET_FROST , 5 ) > 0 Then s_core_message( UW_MSG_SOMETHING_SHATTERS_INSIDE_YOUR )

    ElseIf pub_type = 8 Then
        ' lightning attack, Moria's damageLightningBolt()
        If gub_m2_quiet = false Then s_core_message( UW_MSG_LIGHTNING_STRIKES_YOU )
        If gub_player_resist_light Then psw_damage = psw_damage / 3
        s_hit_player( psw_damage )
        If fub_m2_damage_items( UB_SET_LIGHTNING , 3 ) > 0 Then s_core_message( UW_MSG_THERE_ARE_SPARKS_COMING_FROM_YOUR )

    ElseIf pub_type = 9 Then
        ' corrosion attack, Moria's damageCorrodingGas(), then the damage of the attack itself
        If gub_m2_quiet = false Then s_core_message( UW_MSG_A_STINGING_RED_GAS_SWIRLS_ABOUT )
        If fub_m2_minus_ac( UL_TR_RES_ACID ) = false Then s_hit_player( fuw_m2_random( 8 ) )
        If fub_m2_damage_items( UB_SET_CORRODABLE , 5 ) > 0 Then s_core_message( UW_MSG_THERE_IS_AN_ACRID_SMELL_COMING_2 )
        ' a monster's attack does its own damage as well, a trap's gas does not
        If gub_m2_quiet = false Then s_hit_player( psw_damage )

    ElseIf pub_type = UB_ELEMENT_GAS Then
        ' poison gas, from a breath, Moria's damagePoisonedGas()
        s_hit_player( psw_damage )
        gsw_player_poisoned = gsw_player_poisoned + 12 + fuw_m2_random( psw_damage )

    ElseIf pub_type = 12 Then
        ' steal money
        lub_done = false
        If gsw_player_paralysis < 1 Then
            If fuw_m2_random( 124 ) < Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) Then
                s_core_message( UW_MSG_YOU_QUICKLY_PROTECT_YOUR_MONEY )
                lub_done = true
            End If
        End If
        If lub_done = false Then
            lsl_gold = ( gsl_player_gold / 10 ) + fuw_m2_random( 25 )
            If lsl_gold > gsl_player_gold Then
                gsl_player_gold = 0
            Else
                gsl_player_gold = gsl_player_gold - lsl_gold
            End If
            s_core_message( UW_MSG_YOUR_PURSE_FEELS_LIGHTER )
            s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
        End If
        If fuw_m2_random( 2 ) = 1 Then
            s_core_message( UW_MSG_THERE_IS_A_PUFF_OF_SMOKE )
            s_m2_teleport_away( UB_MON_MAX_SIGHT )
        End If

    ElseIf pub_type = 13 Then
        ' steal object
        lub_done = false
        If gsw_player_paralysis < 1 Then
            If fuw_m2_random( 124 ) < Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) Then
                s_core_message( UW_MSG_YOU_GRAB_HOLD_OF_YOUR_BACKPACK )
                lub_done = true
            End If
        End If
        If lub_done = false Then
            s_m2_destroy( fuw_m2_random( gsw_player_pack_unique ) - 1 )
            s_core_message( UW_MSG_YOUR_BACKPACK_FEELS_LIGHTER )
        End If
        If fuw_m2_random( 2 ) = 1 Then
            s_core_message( UW_MSG_THERE_IS_A_PUFF_OF_SMOKE )
            s_m2_teleport_away( UB_MON_MAX_SIGHT )
        End If

    ElseIf pub_type = 21 Then
        ' disenchant, Moria's executeDisenchantAttack(): one of seven things worn loses a little of each plus it has
        lsw_i = fuw_m2_random( 7 )
        lub_place = UB_PACK_SIZE + UB_EQUIP_WIELD
        If lsw_i = 2 Then lub_place = UB_PACK_SIZE + UB_EQUIP_BODY
        If lsw_i = 3 Then lub_place = UB_PACK_SIZE + UB_EQUIP_ARM
        If lsw_i = 4 Then lub_place = UB_PACK_SIZE + UB_EQUIP_OUTER
        If lsw_i = 5 Then lub_place = UB_PACK_SIZE + UB_EQUIP_HANDS
        If lsw_i = 6 Then lub_place = UB_PACK_SIZE + UB_EQUIP_HEAD
        If lsw_i = 7 Then lub_place = UB_PACK_SIZE + UB_EQUIP_FEET
        lub_done = false
        For lsw_i = 0 To 2
            ' to hit, to damage, to armour class, in that order
            luw_record = fuw_m2_record( lub_place ) + UB_ITEM_TO_HIT_OFFSET
            If lsw_i = 1 Then luw_record = fuw_m2_record( lub_place ) + UB_ITEM_TO_DAMAGE_OFFSET
            If lsw_i = 2 Then luw_record = fuw_m2_record( lub_place ) + UB_ITEM_TO_AC_OFFSET
            lsw_turns = Peek( Integer , luw_record )
            If lsw_turns > 0 Then
                lsw_turns = lsw_turns - Cast( Integer , fuw_m2_random( 2 ) )
                If lsw_turns < 0 Then lsw_turns = 0
                Poke UInteger luw_record , Cast( UInteger , lsw_turns )
                lub_done = true
            End If
        Next
        If lub_done Then
            s_core_message( UW_MSG_THERE_IS_A_STATIC_FEELING_IN_THE )
            gub_game_noticed = true
            s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
        End If

    ElseIf pub_type = 22 Then
        ' eat food, the first food in the pack, Moria's inventoryFindRange()
        lsw_i = 0
        While lsw_i < gsw_player_pack_unique
            If Peek( fuw_m2_record( lsw_i ) + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_FOOD Then
                s_m2_destroy( lsw_i )
                s_core_message( UW_MSG_IT_GOT_AT_YOUR_RATIONS )
            gub_game_noticed = true
                lsw_i = gsw_player_pack_unique
            End If
            lsw_i = lsw_i + 1
        End While

    ElseIf pub_type = 23 Then
        ' eat light, Moria's inventoryDiminishLightAttack()
        luw_record = fuw_m2_record( UB_PACK_SIZE + UB_EQUIP_LIGHT ) + UB_ITEM_MISC_USE_OFFSET
        lsw_turns  = Peek( Integer , luw_record )
        If lsw_turns > 0 Then
            lsw_turns = lsw_turns - ( 250 + Cast( Integer , fuw_m2_random( 250 ) ) )
            If lsw_turns < 1 Then lsw_turns = 1
            Poke UInteger luw_record , Cast( UInteger , lsw_turns )
            If gsw_player_blind < 1 Then
                s_core_message( UW_MSG_YOUR_LIGHT_DIMS )
                gub_game_noticed = true
            End If
        End If

    ElseIf pub_type = 24 Then
        ' eat charges, Moria's inventoryDiminishChargesAttack(): the monster feeds on a wand or staff
        luw_record = fuw_m2_record( fuw_m2_random( gsw_player_pack_unique ) - 1 )
        lub_flag   = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lsw_turns  = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
        If ( lub_flag = UB_TV_STAFF Or lub_flag = UB_TV_WAND ) And lsw_turns > 0 Then
            gsw_monster_hp = gsw_monster_hp + Cast( Integer , gub_creature_level ) * lsw_turns
            Poke UInteger luw_record + UB_ITEM_MISC_USE_OFFSET , 0
            ' unless the player already knows all about it, it is marked as empty
            lub_flag = Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET )
            If ( lub_flag bAnd MB_ID_KNOWN2 ) = 0 Then Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , lub_flag bOr MB_ID_EMPTY
            s_core_message( UW_MSG_ENERGY_DRAINS_FROM_YOUR_PACK )
            gub_game_noticed = true
        End If
    End If
End Sub


Sub s_lib_monster_attack_2()
    If gub_lib_function = UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY Then
        s_m2_teleport_away( guw_lib_param_2 )
    Else
        gub_m2_quiet = false
        If gub_lib_function = UB_LIB_MONSTER_ATTACK_2_DAMAGE Then gub_m2_quiet = true
        s_m2_execute( gub_lib_param_1 , Cast( Integer , guw_lib_param_2 ) )
    End If
End Sub
