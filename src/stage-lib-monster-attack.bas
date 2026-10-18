#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monster_attack()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: a monster attacking the player, from Moria's monster.cpp and player.cpp...
' ...the monster moves library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_ATTACK , <which routine> ),
' the one routine is:
'
'   UB_LIB_MONSTER_ATTACK_PLAYER    the working monster (A_MONSTER), whose creature is in A_CREATURE, makes each of
'                                   its attacks on the player in turn, up to four, Moria's monsterAttackPlayer():
'                                   each may miss, depending on the player's armour, and each that lands says what
'                                   it was, does its damage, and does whatever else that kind of attack does
'
' a creature's attacks are numbers of entries in the monster attacks table, in the core data (A_ATTACKS), four bytes
' to an entry: the kind of attack, how it is described, and the dice of damage
'
' it takes two pages: this one has the attacks that only hurt, weaken or bewilder the player, stage-lib-monster-attack-2.bas
' has the ones that get at what the player is wearing and carrying, fire and acid and thieves, and this page hands
' those on to it
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, what the player learns from being attacked goes into the monster memory, see
'     ful_core_recall() in core.bas, and a level lost to drained experience, and hit points, spells and mana
'     changing with a stat, are the effects library's, stage-lib-effects.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
#define A_MA_NAME           A_LIB_PRIVATE               ' 40 bytes, how the attacker is spoken of: "The Kobold " or "It "


Function fuw_ma_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ma_being_hit( psw_base As Integer , psw_armour As Integer ) As UByte
    ' Moria's playerTestBeingHit(): a 20 sided die, 1 always misses and 20 always hits, otherwise the creature's
    ' level, and the player's class, against the player's armour
    Dim lsw_chance  As Integer
    Dim luw_die     As UInteger

    ' as every test of being hit in Moria, it disturbs the player first, whether or not it hits
    s_mon_disturb()
    lsw_chance = psw_base + Cast( Integer , gub_creature_level ) * Cast( Integer , gub_class_adj_save )
    luw_die    = fuw_ma_random( 20 )
    If luw_die = 1 Then Return false
    If luw_die = 20 Then Return true
    If lsw_chance > 0 Then
        If Cast( Integer , fuw_ma_random( lsw_chance ) ) > psw_armour Then Return true
    End If
    Return false
End Function


Function fub_ma_test_hits( pub_type As UByte ) As UByte
    ' Moria's playerTestAttackHits(): each kind of attack has its own chance of landing, most are against the
    ' player's armour, thieves are against the player's level, and some cannot miss
    Dim lsw_base    As Integer
    Dim lub_hit     As UByte

    If pub_type = 20 Or pub_type = 99 Then Return true          ' aggravate monsters, and an attack that is repelled
    If pub_type = 0 Or pub_type > 24 Then Return false
    lsw_base = Cast( Byte , Peek( @ma_base_table + pub_type ) )

    If pub_type = 12 Or pub_type = 13 Then
        lub_hit = fub_ma_being_hit( lsw_base , guw_player_level )
    Else
        lub_hit = fub_ma_being_hit( lsw_base , gsw_player_ac + gsw_player_magical_ac )
    End If
    ' a thief with nothing to steal, or nothing to drain
    If pub_type = 12 And gsl_player_gold <= 0 Then lub_hit = false
    If ( pub_type = 13 Or pub_type = 24 ) And gsw_player_pack_unique <= 0 Then lub_hit = false
    Return lub_hit

    ' the table sits here, after the Return, so that it is part of the code and never runs as instructions...
    ' ...one signed byte for each kind of attack, 0 to 24, -3 is 253
ma_base_table:
    Asm
        defb   0,  60, 253,  10,  10      ;  0 none, 1 normal, 2 lose strength, 3 confusion, 4 fear
        defb  10,   0,  10,  10,   0      ;  5 fire, 6 acid, 7 cold, 8 lightning, 9 corrosion
        defb   2,   2,   5,   2,   5      ; 10 blindness, 11 paralysis, 12 steal money, 13 steal object, 14 poison
        defb   0,   0,   2,   2,   5      ; 15 lose dexterity, 16 lose constitution, 17 lose intelligence, 18 lose wisdom, 19 lose experience
        defb   0,  20,   5,   5,  15      ; 20 aggravate, 21 disenchant, 22 eat food, 23 eat light, 24 eat charges
    End Asm
    ' never reached, it is here because the compiler wants a function to end with a Return
    Return false
End Function


Sub s_ma_describe( pub_description As UByte )
    ' Moria's monsterPrintAttackDescription()
    Dim luw_insult As UInteger

    If pub_description = 1 Then
        s_core_message_after( A_MA_NAME , UW_MSG_HITS_YOU )
    ElseIf pub_description = 2 Then
        s_core_message_after( A_MA_NAME , UW_MSG_BITES_YOU )
    ElseIf pub_description = 3 Then
        s_core_message_after( A_MA_NAME , UW_MSG_CLAWS_YOU )
    ElseIf pub_description = 4 Then
        s_core_message_after( A_MA_NAME , UW_MSG_STINGS_YOU )
    ElseIf pub_description = 5 Then
        s_core_message_after( A_MA_NAME , UW_MSG_TOUCHES_YOU )
    ElseIf pub_description = 7 Then
        s_core_message_after( A_MA_NAME , UW_MSG_GAZES_AT_YOU )
    ElseIf pub_description = 8 Then
        s_core_message_after( A_MA_NAME , UW_MSG_BREATHES_ON_YOU )
    ElseIf pub_description = 9 Then
        s_core_message_after( A_MA_NAME , UW_MSG_SPITS_ON_YOU )
    ElseIf pub_description = 10 Then
        s_core_message_after( A_MA_NAME , UW_MSG_MAKES_A_HORRIBLE_WAIL )
    ElseIf pub_description = 12 Then
        s_core_message_after( A_MA_NAME , UW_MSG_CRAWLS_ON_YOU )
    ElseIf pub_description = 13 Then
        s_core_message_after( A_MA_NAME , UW_MSG_RELEASES_A_CLOUD_OF_SPORES )
    ElseIf pub_description = 14 Then
        s_core_message_after( A_MA_NAME , UW_MSG_BEGS_YOU_FOR_MONEY )
    ElseIf pub_description = 15 Then
        s_core_message( UW_MSG_YOUVE_BEEN_SLIMED )
    ElseIf pub_description = 16 Then
        s_core_message_after( A_MA_NAME , UW_MSG_CRUSHES_YOU )
    ElseIf pub_description = 17 Then
        s_core_message_after( A_MA_NAME , UW_MSG_TRAMPLES_YOU )
    ElseIf pub_description = 18 Then
        s_core_message_after( A_MA_NAME , UW_MSG_DROOLS_ON_YOU )
    ElseIf pub_description = 19 Then
        luw_insult = fuw_ma_random( 9 )
        If luw_insult = 1 Then
            s_core_message_after( A_MA_NAME , UW_MSG_INSULTS_YOU )
        ElseIf luw_insult = 2 Then
            s_core_message_after( A_MA_NAME , UW_MSG_INSULTS_YOUR_MOTHER )
        ElseIf luw_insult = 3 Then
            s_core_message_after( A_MA_NAME , UW_MSG_GIVES_YOU_THE_FINGER )
        ElseIf luw_insult = 4 Then
            s_core_message_after( A_MA_NAME , UW_MSG_HUMILIATES_YOU )
        ElseIf luw_insult = 5 Then
            s_core_message_after( A_MA_NAME , UW_MSG_WETS_ON_YOUR_LEG )
        ElseIf luw_insult = 6 Then
            s_core_message_after( A_MA_NAME , UW_MSG_DEFILES_YOU )
        ElseIf luw_insult = 7 Then
            s_core_message_after( A_MA_NAME , UW_MSG_DANCES_AROUND_YOU )
        ElseIf luw_insult = 8 Then
            s_core_message_after( A_MA_NAME , UW_MSG_MAKES_OBSCENE_GESTURES )
        Else
            s_core_message_after( A_MA_NAME , UW_MSG_MOONS_YOU )
        End If
    ElseIf pub_description = 99 Then
        s_core_message_after( A_MA_NAME , UW_MSG_IS_REPELLED )
    End If
End Sub


Function fub_ma_saving_throw() As UByte
    ' Moria's playerSavingThrow()
    Dim lsw_saving As Integer

    gub_lib_param_1 = UB_STAT_WIS
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_saving = gsw_player_saving_throw + gsw_lib_result + Cast( Integer , gub_class_adj_save ) * Cast( Integer , guw_player_level ) / 3
    If Cast( Integer , fuw_ma_random( 100 ) ) <= lsw_saving Then Return true
    Return false
End Function


Sub s_ma_stat_decrease( pub_stat As UByte )
    ' Moria's playerStatRandomDecrease(): a stat goes down, by one below 18, by a good deal more above it
    Dim lsw_stat , lsw_loss As Integer

    lsw_stat = Peek( A_PLAYER_STATS_CURRENT + pub_stat )
    If lsw_stat <= 3 Then Return
    If lsw_stat >= 19 And lsw_stat < 117 Then
        lsw_loss = ( ( ( 118 - lsw_stat ) >> 1 ) + 1 ) >> 1
        lsw_stat = lsw_stat - Cast( Integer , fuw_ma_random( lsw_loss ) ) - lsw_loss
        If lsw_stat < 18 Then lsw_stat = 18
    Else
        lsw_stat = lsw_stat - 1
    End If
    Poke A_PLAYER_STATS_CURRENT + pub_stat , lsw_stat
    ' the value the game uses, and what hangs on it, Moria's playerSetAndUseStat(), then the stat is shown again
    gub_lib_param_1 = pub_stat
    s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_USE_STAT )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Sub s_ma_aggravate()
    ' Moria's spellAggravateMonsters( 20 ): every monster on the level wakes, and the near ones speed up
    Dim lub_monster     As UByte
    Dim luw_record      As UInteger
    Dim lsw_speed       As Integer
    Dim lub_aggravated  As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
        Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
        lsw_speed = Peek( Integer , luw_record + UB_MONSTER_SPEED_OFFSET )
        If Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) <= 20 And lsw_speed < 2 Then
            Poke UInteger luw_record + UB_MONSTER_SPEED_OFFSET , Cast( UInteger , lsw_speed + 1 )
            lub_aggravated = true
        End If
    End While
    ' the attacker itself is in the working monster, which is what gets kept when its turn is over
    gsw_monster_sleep = 0
    If gub_monster_distance <= 20 And gsw_monster_speed < 2 Then gsw_monster_speed = gsw_monster_speed + 1
    If lub_aggravated Then s_core_message( UW_MSG_YOU_HEAR_A_SUDDEN_STIRRING_IN_THE )
End Sub


Sub s_ma_execute( pub_type As UByte , psw_damage As Integer )
    ' Moria's executeAttackOnPlayer(): what each kind of attack does once it has landed
    Dim lsl_loss As Long

    If pub_type = 1 Then
        ' normal attack, armour takes some of it
        psw_damage = psw_damage - ( ( gsw_player_ac + gsw_player_magical_ac ) * psw_damage ) / 200
        s_hit_player( psw_damage )
    ElseIf pub_type = 2 Then
        ' lose strength
        s_hit_player( psw_damage )
        If gub_player_sustain_str Then
            s_core_message( UW_MSG_YOU_FEEL_WEAKER_FOR_A_MOMENT_BUT )
        ElseIf fuw_ma_random( 2 ) = 1 Then
            s_core_message( UW_MSG_YOU_FEEL_WEAKER )
            s_ma_stat_decrease( UB_STAT_STR )
        Else
            gub_game_noticed = false
        End If
    ElseIf pub_type = 3 Then
        ' confusion attack
        s_hit_player( psw_damage )
        If fuw_ma_random( 2 ) = 1 Then
            If gsw_player_confused < 1 Then
                s_core_message( UW_MSG_YOU_FEEL_CONFUSED )
                gsw_player_confused = gsw_player_confused + fuw_ma_random( gub_creature_level )
            Else
                gub_game_noticed = false
            End If
            gsw_player_confused = gsw_player_confused + 3
        Else
            gub_game_noticed = false
        End If
    ElseIf pub_type = 4 Then
        ' fear attack
        s_hit_player( psw_damage )
        If fub_ma_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS )
        ElseIf gsw_player_afraid < 1 Then
            s_core_message( UW_MSG_YOU_ARE_SUDDENLY_AFRAID )
            gsw_player_afraid = gsw_player_afraid + 3 + fuw_ma_random( gub_creature_level )
        Else
            gsw_player_afraid = gsw_player_afraid + 3
            gub_game_noticed  = false
        End If
    ElseIf pub_type = 10 Then
        ' blindness attack
        s_hit_player( psw_damage )
        If gsw_player_blind < 1 Then
            gsw_player_blind = gsw_player_blind + 10 + fuw_ma_random( gub_creature_level )
            s_core_message( UW_MSG_YOUR_EYES_BEGIN_TO_STING )
        Else
            gsw_player_blind = gsw_player_blind + 5
            gub_game_noticed = false
        End If
    ElseIf pub_type = 11 Then
        ' paralysis attack
        s_hit_player( psw_damage )
        If fub_ma_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS )
        ElseIf gsw_player_paralysis < 1 Then
            If gub_player_free_action Then
                s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
            Else
                gsw_player_paralysis = fuw_ma_random( gub_creature_level ) + 3
                s_core_message( UW_MSG_YOU_ARE_PARALYZED )
            End If
        Else
            gub_game_noticed = false
        End If
    ElseIf pub_type = 14 Then
        ' poison
        s_hit_player( psw_damage )
        s_core_message( UW_MSG_YOU_FEEL_VERY_SICK )
        gsw_player_poisoned = gsw_player_poisoned + fuw_ma_random( gub_creature_level ) + 5
    ElseIf pub_type = 15 Then
        ' lose dexterity
        s_hit_player( psw_damage )
        If gub_player_sustain_dex Then
            s_core_message( UW_MSG_YOU_FEEL_CLUMSY_FOR_A_MOMENT_BUT )
        Else
            s_core_message( UW_MSG_YOU_FEEL_MORE_CLUMSY )
            s_ma_stat_decrease( UB_STAT_DEX )
        End If
    ElseIf pub_type = 16 Then
        ' lose constitution
        s_hit_player( psw_damage )
        If gub_player_sustain_con Then
            s_core_message( UW_MSG_YOUR_BODY_RESISTS_THE_EFFECTS_OF )
        Else
            s_core_message( UW_MSG_YOUR_HEALTH_IS_DAMAGED )
            s_ma_stat_decrease( UB_STAT_CON )
        End If
    ElseIf pub_type = 17 Then
        ' lose intelligence
        s_hit_player( psw_damage )
        s_core_message( UW_MSG_YOU_HAVE_TROUBLE_THINKING_CLEARLY )
        If gub_player_sustain_int Then
            s_core_message( UW_MSG_BUT_YOUR_MIND_QUICKLY_CLEARS )
        Else
            s_ma_stat_decrease( UB_STAT_INT )
        End If
    ElseIf pub_type = 18 Then
        ' lose wisdom
        s_hit_player( psw_damage )
        If gub_player_sustain_wis Then
            s_core_message( UW_MSG_YOUR_WISDOM_IS_SUSTAINED )
        Else
            s_core_message( UW_MSG_YOUR_WISDOM_IS_DRAINED )
            s_ma_stat_decrease( UB_STAT_WIS )
        End If
    ElseIf pub_type = 19 Then
        ' lose experience, Moria's spellLoseEXP(): 2% of what the player has, and the damage on top
        s_core_message( UW_MSG_YOU_FEEL_YOUR_LIFE_DRAINING_AWAY )
        lsl_loss = psw_damage + ( gsl_player_exp / 100 ) * 2
        ' the effects library takes it away, and with it perhaps a level, with its hit points and spells
        gsl_lib_long_1 = lsl_loss
        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_LOSE_EXP )
    ElseIf pub_type = 20 Then
        s_ma_aggravate()
    ElseIf pub_type >= 5 And pub_type <= 24 Then
        ' fire, acid, cold, lightning, corrosion, the thieves, disenchantment, and the eaters of food, light and charges
        ' N.B: the last four are only noticed if they come to something, the other library says so when they do
        If pub_type >= 21 Then gub_game_noticed = false
        gub_lib_param_1 = pub_type
        guw_lib_param_2 = Cast( UInteger , psw_damage )
        s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_EXECUTE )
    Else
        ' an attack that was turned aside
        gub_game_noticed = false
    End If
End Sub


Sub s_ma_confuse_on_attack( pub_description As UByte , pub_visible As UByte )
    ' Moria's monsterConfuseOnAttack(): a player whose hands glow confuses the monster that touches them
    If gub_player_confuse_monster = false Or pub_description = 99 Then Return
    s_core_message( UW_MSG_YOUR_HANDS_STOP_GLOWING )
    gub_player_confuse_monster = false
    If fuw_ma_random( UB_MON_MAX_LEVELS ) < gub_creature_level Or ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then
        s_core_message_after( A_MA_NAME , UW_MSG_IS_UNAFFECTED )
    Else
        s_core_message_after( A_MA_NAME , UW_MSG_APPEARS_CONFUSED )
        If gub_monster_confused <> 0 Then
            gub_monster_confused = gub_monster_confused + 3
        Else
            gub_monster_confused = 2 + fuw_ma_random( 16 )
        End If
    End If
    ' one time in four the player learns whether this kind of creature can be confused
    ' N.B: as in Moria the dice are thrown only if the monster can be seen and the player still lives
    If pub_visible And gub_game_character_dead = false Then
        If fuw_ma_random( 4 ) = 1 Then ful_core_recall( guw_monster_creature , UB_RECALL_DEFENSES , guw_creature_defenses bAnd UW_CD_NO_SLEEP )
    End If
End Sub


Sub s_ma_attack_player()
    ' Moria's monsterAttackPlayer()
    Dim i , lub_attack , lub_type , lub_description As UByte
    Dim luw_entry                                   As UInteger
    Dim lub_first , lub_visible                     As UByte
    Dim ls_name                                     As String

    If gub_game_character_dead Then Return

    ' how the attacker is spoken of, and what the player will have died from if this kills them, Moria's
    ' playerDiedFromString(): "a Kobold", "an Orc", and for the one whose death wins the game "The Balrog"
    ls_name = fs_core_text_at( A_CREATURE )
    If gub_monster_lit = 0 Then
        Poke A_MA_NAME     , Code( "I" )
        Poke A_MA_NAME + 1 , Code( "t" )
        Poke A_MA_NAME + 2 , 32
        Poke A_MA_NAME + 3 , 0
    Else
        s_hit_killer( "The " + ls_name + " " )
        s_core_ram_copy( A_KILLER , A_MA_NAME , 40 )
    End If
    lub_first = Peek( A_CREATURE ) bOr 32           ' the first letter of its name, in lower case
    If ( gul_creature_movement bAnd UL_CM_WIN ) <> 0 Then
        s_hit_killer( "The " + ls_name )
    ElseIf lub_first = Code( "a" ) Or lub_first = Code( "e" ) Or lub_first = Code( "i" ) Or lub_first = Code( "o" ) Or lub_first = Code( "u" ) Then
        s_hit_killer( "an " + ls_name )
    Else
        s_hit_killer( "a " + ls_name )
    End If

    For i = 0 To 3
        lub_attack = Peek( A_CREATURE + UB_CREATURE_ATTACKS_OFFSET + i )
        If lub_attack = 0 Or gub_game_character_dead Then Return
        luw_entry       = A_ATTACKS + Cast( UInteger , lub_attack ) * 4
        lub_type        = Peek( luw_entry )
        lub_description = Peek( luw_entry + 1 )

        If gsw_player_protect_evil > 0 And ( guw_creature_defenses bAnd UW_CD_EVIL ) <> 0 Then
            If guw_player_level + 1 > gub_creature_level Then
                If gub_monster_lit Then ful_core_recall( guw_monster_creature , UB_RECALL_DEFENSES , UW_CD_EVIL )
                lub_type        = 99
                lub_description = 99
            End If
        End If

        If fub_ma_test_hits( lub_type ) Then
            s_mon_disturb()
            s_ma_describe( lub_description )
            ' always fail to notice attack if creature invisible, set notice and visible here since creature may
            ' be visible when attacking and then teleport afterwards (becoming effectively invisible)
            lub_visible      = gub_monster_lit
            gub_game_noticed = gub_monster_lit
            s_ma_execute( lub_type , fuw_core_dice_roll( Peek( luw_entry + 2 ) , Peek( luw_entry + 3 ) ) )
            s_ma_confuse_on_attack( lub_description , lub_visible )
            ' the player remembers the attack if they noticed it, or if they could see and have noticed it
            ' before, which is how they come to learn the damage, and that this kind of creature killed them
            If gub_game_noticed = false And lub_visible <> 0 And lub_type <> 99 Then
                If ful_core_recall( guw_monster_creature , UB_RECALL_ATTACK + i , 0 ) <> 0 Then gub_game_noticed = true
            End If
            If gub_game_noticed Then ful_core_recall( guw_monster_creature , UB_RECALL_ATTACK + i , 1 )
            If gub_game_character_dead Then ful_core_recall( guw_monster_creature , UB_RECALL_DEATHS , 1 )
        ElseIf ( lub_description >= 1 And lub_description <= 3 ) Or lub_description = 6 Then
            s_mon_disturb()
            s_core_message_after( A_MA_NAME , UW_MSG_MISSES_YOU )
        End If
    Next
End Sub


Sub s_lib_monster_attack()
    If gub_lib_function = UB_LIB_MONSTER_ATTACK_PLAYER Then s_ma_attack_player()
End Sub
