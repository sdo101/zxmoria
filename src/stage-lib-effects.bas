#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_effects()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: the things that happen to the player's body and mind, which food, potions,
' scrolls, spells, traps and monsters all share, from Moria's spells.cpp, player_stats.cpp, player_magic.cpp and ui.cpp,
' and the end of every routine that uses something up, from player_eat.cpp and identification.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , <which routine> ), the answer,
' where there is one, comes back in gsw_lib_result, and for most of these it means "the player noticed something",
' which is how they come to know what a potion or a mushroom is, the routines are:
'
'   UB_LIB_EFFECTS_HP_CHANGE        the player gains guw_lib_param_2 hit points, a signed number, with "You feel
'                                   better." and the like, Moria's spellChangePlayerHitPoints()
'   UB_LIB_EFFECTS_STAT_RESTORE     stat gub_lib_param_1 goes back to the best it has been, playerStatRestore()
'   UB_LIB_EFFECTS_STAT_INCREASE    stat gub_lib_param_1 goes up, by one below 18 and by more above, playerStatRandomIncrease()
'   UB_LIB_EFFECTS_STAT_DECREASE    stat gub_lib_param_1 goes down, playerStatRandomDecrease()
'   UB_LIB_EFFECTS_LOSE_STAT        stat gub_lib_param_1 goes down unless the player is proof against that, with a
'                                   message either way, Moria's spellLoseSTR() and its five fellows
'   UB_LIB_EFFECTS_LOSE_EXP         the player loses gsl_lib_long_1 experience, and with it perhaps levels, spellLoseEXP()
'   UB_LIB_EFFECTS_RESTORE_LEVELS   experience that was drained comes back, spellRestorePlayerLevels()
'   UB_LIB_EFFECTS_DISPLAY_EXP      the player's experience has changed: they go up a level if they have enough
'                                   for it, perhaps more than one, Moria's displayCharacterExperience()
'   UB_LIB_EFFECTS_INGEST_FOOD      guw_lib_param_2 of food goes into the player's belly, Moria's playerIngestFood()
'   UB_LIB_EFFECTS_USE_DONE         the thing in place gub_lib_param_1 of the pack has just been used, and
'                                   guw_lib_param_2 is true if the player noticed what it did: if they did, and did
'                                   not already know what kind of thing it is, they do now, and gain a little
'                                   experience for it, if they did not, it is marked as tried, the place the
'                                   thing is in afterwards comes back, learning what it is can move it
'   UB_LIB_EFFECTS_CALC_HP          the player's constitution has changed: their hit points are worked out
'                                   afresh, Moria's playerCalculateHitPoints()
'   UB_LIB_EFFECTS_USE_REMAINING    one of what is in place gub_lib_param_1 is used up: "You have 2 Rations of
'                                   Food." and it goes, Moria's itemTypeRemainingCountDescription() and
'                                   inventoryDestroyItem()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of


Function fuw_ef_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_ef_block()
    ' the player's details down the left of the screen are shown again
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


'##################################################################################################################################
' --- experience and levels ---

Function fsl_ef_level_exp( puw_level As UInteger ) As Long
    ' the experience this character needs to reach the level after the one given, Moria's base_exp_levels[] scaled
    ' by how hard the character's race and class find it
    Return Peek( Long , A_EXP_LEVELS + ( puw_level - 1 ) * 4 ) * gub_player_exp_factor / 100
End Function


Sub s_ef_calculate_hit_points()
    ' Moria's playerCalculateHitPoints(): the hit points rolled for this level when the character was made, plus
    ' what constitution gives, the hit points the player has now keep their proportion of the new total
    Dim lsw_hp      As Integer
    Dim lsl_value   As Long

    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_CON )
    lsw_hp = Peek( Integer , A_PLAYER_HP_LEVELS + ( guw_player_level - 1 ) * 2 ) + gsw_lib_result * Cast( Integer , guw_player_level )
    ' always give at least one point per level + 1
    If lsw_hp < Cast( Integer , guw_player_level ) + 1 Then lsw_hp = guw_player_level + 1
    If ( gul_player_status bAnd UL_PY_HERO ) <> 0 Then lsw_hp = lsw_hp + 10
    If ( gul_player_status bAnd UL_PY_SHERO ) <> 0 Then lsw_hp = lsw_hp + 20

    If lsw_hp <> gsw_player_max_hp And gsw_player_max_hp <> 0 Then
        lsl_value = ( ( Cast( Long , gsw_player_current_hp ) << 16 ) + guw_player_hp_fraction ) / gsw_player_max_hp * lsw_hp
        gsw_player_current_hp  = lsl_value >> 16
        guw_player_hp_fraction = lsl_value bAnd $FFFF
        gsw_player_max_hp      = lsw_hp
    End If
End Sub


Sub s_ef_display_experience()
    ' Moria's displayCharacterExperience() and playerGainLevel()
    Dim lsl_new_exp As Long

    If gsl_player_exp > 9999999 Then gsl_player_exp = 9999999
    While guw_player_level < 40 And fsl_ef_level_exp( guw_player_level ) <= gsl_player_exp
        guw_player_level = guw_player_level + 1
        s_msg( "Welcome to level " + fs_core_number( guw_player_level ) + "." )
        s_ef_calculate_hit_points()
        ' lose some of the 'extra' exp when gaining several levels at once: half of anything over what the level after
        ' this one needs is lost, Moria's base_exp_levels[ level - 1 ] with the level already gone up, which is
        ' fsl_ef_level_exp( level ) here (it was level - 1 until 16 October 2026, so that every level gained cost half of
        ' anything over what that level had needed, found by comparing a fight with Umoria's: 14 became 12)
        lsl_new_exp = fsl_ef_level_exp( guw_player_level )
        If gsl_player_exp > lsl_new_exp Then gsl_player_exp = lsl_new_exp + ( gsl_player_exp - lsl_new_exp ) / 2
        ' those who use spells may learn new ones, and gain mana
        s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
    End While
    If gsl_player_exp > gsl_player_max_exp Then gsl_player_max_exp = gsl_player_exp
    s_ef_block()
End Sub


Sub s_ef_lose_exp( psl_amount As Long )
    ' Moria's spellLoseEXP(): experience goes, and the player is whatever level what is left makes them
    Dim luw_level As UInteger

    If psl_amount > gsl_player_exp Then
        gsl_player_exp = 0
    Else
        gsl_player_exp = gsl_player_exp - psl_amount
    End If

    luw_level = 1
    While luw_level < 40 And fsl_ef_level_exp( luw_level ) <= gsl_player_exp
        luw_level = luw_level + 1
    End While
    If guw_player_level <> luw_level Then
        guw_player_level = luw_level
        s_ef_calculate_hit_points()
        ' those who use spells may forget some, and lose mana
        s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
    End If
    s_ef_block()
End Sub


'##################################################################################################################################
' --- the six stats ---

Sub s_ef_use_stat( pub_stat As UByte )
    ' the value the game uses, and what hangs on it, Moria's playerSetAndUseStat(), then the stats are shown again
    gub_lib_param_1 = pub_stat
    s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_USE_STAT )
    If pub_stat = UB_STAT_CON Then s_ef_calculate_hit_points()
    s_ef_block()
End Sub


Function fub_ef_stat_decrease( pub_stat As UByte ) As UByte
    ' Moria's playerStatRandomDecrease(): a stat goes down, by one below 18, by a good deal more above it
    Dim lsw_stat , lsw_loss As Integer

    lsw_stat = Peek( A_PLAYER_STATS_CURRENT + pub_stat )
    If lsw_stat <= 3 Then Return false
    If lsw_stat >= 19 And lsw_stat < 117 Then
        lsw_loss = ( ( ( 118 - lsw_stat ) >> 1 ) + 1 ) >> 1
        lsw_stat = lsw_stat - Cast( Integer , fuw_ef_random( lsw_loss ) ) - lsw_loss
        If lsw_stat < 18 Then lsw_stat = 18
    Else
        lsw_stat = lsw_stat - 1
    End If
    Poke A_PLAYER_STATS_CURRENT + pub_stat , lsw_stat
    s_ef_use_stat( pub_stat )
    Return true
End Function


Function fub_ef_stat_increase( pub_stat As UByte ) As UByte
    ' Moria's playerStatRandomIncrease()
    Dim lsw_stat , lsw_gain As Integer

    lsw_stat = Peek( A_PLAYER_STATS_CURRENT + pub_stat )
    If lsw_stat >= 118 Then Return false
    If lsw_stat >= 18 And lsw_stat < 116 Then
        ' stat increases by 1/6 to 1/3 of difference from max
        lsw_gain = ( ( 118 - lsw_stat ) / 3 + 1 ) >> 1
        lsw_stat = lsw_stat + Cast( Integer , fuw_ef_random( lsw_gain ) ) + lsw_gain
    Else
        lsw_stat = lsw_stat + 1
    End If
    Poke A_PLAYER_STATS_CURRENT + pub_stat , lsw_stat
    If lsw_stat > Peek( A_PLAYER_STATS_MAX + pub_stat ) Then Poke A_PLAYER_STATS_MAX + pub_stat , lsw_stat
    s_ef_use_stat( pub_stat )
    Return true
End Function


Function fub_ef_stat_restore( pub_stat As UByte ) As UByte
    ' Moria's playerStatRestore()
    If Peek( A_PLAYER_STATS_MAX + pub_stat ) = Peek( A_PLAYER_STATS_CURRENT + pub_stat ) Then Return false
    Poke A_PLAYER_STATS_CURRENT + pub_stat , Peek( A_PLAYER_STATS_MAX + pub_stat )
    s_ef_use_stat( pub_stat )
    Return true
End Function


Sub s_ef_lose_stat( pub_stat As UByte )
    ' Moria's spellLoseSTR(), spellLoseINT(), spellLoseWIS(), spellLoseDEX(), spellLoseCON() and spellLoseCHR()
    Dim lub_sustained As UByte

    lub_sustained = Peek( @ef_sustain_table + pub_stat )
    lub_sustained = Peek( A_PLAYER + 437 + lub_sustained )      ' the six "sustain" flags, gub_player_sustain_str and the five after it
    If lub_sustained = false Then gub_shared_1 = fub_ef_stat_decrease( pub_stat )

    If pub_stat = UB_STAT_STR Or pub_stat = UB_STAT_CON Then
        If lub_sustained Then
            s_core_message( UW_MSG_YOU_FEEL_SICK_FOR_A_MOMENT_IT )
        Else
            s_core_message( UW_MSG_YOU_FEEL_VERY_SICK )
        End If
    ElseIf pub_stat = UB_STAT_INT Then
        If lub_sustained Then
            s_core_message( UW_MSG_YOU_BECOME_DIZZY_FOR_A_MOMENT_IT )
        Else
            s_core_message( UW_MSG_YOU_BECOME_VERY_DIZZY )
        End If
    ElseIf pub_stat = UB_STAT_WIS Then
        If lub_sustained Then
            s_core_message( UW_MSG_YOU_FEEL_NAIVE_FOR_A_MOMENT_IT )
        Else
            s_core_message( UW_MSG_YOU_FEEL_VERY_NAIVE )
        End If
    ElseIf pub_stat = UB_STAT_DEX Then
        If lub_sustained Then
            s_core_message( UW_MSG_YOU_FEEL_SORE_FOR_A_MOMENT_IT )
        Else
            s_core_message( UW_MSG_YOU_FEEL_VERY_SORE )
        End If
    Else
        If lub_sustained Then
            s_core_message( UW_MSG_YOUR_SKIN_STARTS_TO_ITCH_BUT )
        Else
            s_core_message( UW_MSG_YOUR_SKIN_STARTS_TO_ITCH )
        End If
    End If
    Return

    ' where each stat's "sustain" flag is among the six in the player's record, which are in the order strength,
    ' intelligence, wisdom, constitution, dexterity, charisma, the stats themselves are str, int, wis, dex, con, chr...
    ' ...the table sits here, after the Return, so that it is part of the code and never runs as instructions
ef_sustain_table:
    Asm
        defb 0, 1, 2, 4, 3, 5
    End Asm
End Sub


'##################################################################################################################################
' --- hit points and food ---

Function fub_ef_hp_change( psw_amount As Integer ) As UByte
    ' Moria's spellChangePlayerHitPoints()
    If gsw_player_current_hp >= gsw_player_max_hp Then Return false
    gsw_player_current_hp = gsw_player_current_hp + psw_amount
    If gsw_player_current_hp > gsw_player_max_hp Then
        gsw_player_current_hp  = gsw_player_max_hp
        guw_player_hp_fraction = 0
    End If
    s_ef_block()

    psw_amount = psw_amount / 5
    If psw_amount < 3 Then
        If psw_amount = 0 Then
            s_core_message( UW_MSG_YOU_FEEL_A_LITTLE_BETTER )
        Else
            s_core_message( UW_MSG_YOU_FEEL_BETTER )
        End If
    ElseIf psw_amount < 7 Then
        s_core_message( UW_MSG_YOU_FEEL_MUCH_BETTER )
    Else
        s_core_message( UW_MSG_YOU_FEEL_VERY_GOOD )
    End If
    Return true
End Function


Sub s_ef_ingest_food( psw_amount As Integer )
    ' Moria's playerIngestFood(): too much, and the player is bloated and slowed
    Dim lsl_food                    As Long
    Dim lsw_extra , lsw_penalty     As Integer

    If gsw_player_food < 0 Then gsw_player_food = 0
    lsl_food = Cast( Long , gsw_player_food ) + psw_amount
    If lsl_food > 15000 Then                        ' PLAYER_FOOD_MAX
        s_core_message( UW_MSG_YOU_ARE_BLOATED_FROM_OVEREATING )
        ' calculate how much of amount is responsible for the bloating, give the player food credit for 1/50,
        ' and slow them for that many turns also
        lsw_extra = lsl_food - 15000
        If lsw_extra > psw_amount Then lsw_extra = psw_amount
        lsw_penalty = lsw_extra / 50
        gsw_player_slow = gsw_player_slow + lsw_penalty
        If lsw_extra = psw_amount Then
            gsw_player_food = lsl_food - psw_amount + lsw_penalty
        Else
            gsw_player_food = 15000 + lsw_penalty
        End If
    Else
        gsw_player_food = lsl_food
        If lsl_food > 10000 Then s_core_message( UW_MSG_YOU_ARE_FULL )       ' PLAYER_FOOD_FULL
    End If
End Sub


'##################################################################################################################################
' --- using something up ---

Function fuw_ef_record( pub_place As UByte ) As UInteger
    ' where the record for one place in the pack is
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Function fub_ef_use_done( pub_place As UByte , pub_identified As UByte ) As UByte
    ' the end of Moria's playerEat(), quaff() and the rest: what the player has learnt about the thing just used
    Dim lub_known   As UByte
    Dim luw_record  As UInteger

    luw_record = fuw_ef_record( pub_place )
    ' does the player already know what kind of thing it is? Moria's itemSetColorlessAsIdentified()
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_KIND_KNOWN )
    lub_known = gsw_lib_result

    If pub_identified Then
        If lub_known = false Then
            ' round half-way case up
            gsl_player_exp = gsl_player_exp + ( Cast( UInteger , Peek( luw_record + UB_ITEM_DEPTH_OFFSET ) ) + ( guw_player_level >> 1 ) ) / guw_player_level
            s_ef_display_experience()
            guw_lib_param_2 = pub_place
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY )
            pub_place = gsw_lib_result
        End If
    ElseIf lub_known = false Then
        guw_lib_param_2 = pub_place
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_TRIED )
    End If
    Return pub_place
End Function


Sub s_ef_use_remaining( pub_place As UByte )
    ' Moria's itemTypeRemainingCountDescription(), then its inventoryDestroyItem()
    s_core_ram_copy( fuw_ef_record( pub_place ) , A_ITEM , UB_RECORD_SIZE )
    gub_item_count  = gub_item_count - 1
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    s_msg( "You have " + fs_core_text_at( A_TEXT_BUFFER ) )
    guw_lib_param_2 = pub_place
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY )
End Sub


Sub s_lib_effects()
    Dim lub_stat    As UByte
    Dim luw_amount  As UInteger

    ' N.B: these are taken out first, the routines here call other libraries, which use the same places
    lub_stat   = gub_lib_param_1
    luw_amount = guw_lib_param_2
    If gub_lib_function = UB_LIB_EFFECTS_HP_CHANGE Then
        gsw_lib_result = fub_ef_hp_change( Cast( Integer , luw_amount ) )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_STAT_RESTORE Then
        gsw_lib_result = fub_ef_stat_restore( lub_stat )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_STAT_INCREASE Then
        gsw_lib_result = fub_ef_stat_increase( lub_stat )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_STAT_DECREASE Then
        gsw_lib_result = fub_ef_stat_decrease( lub_stat )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_LOSE_STAT Then
        s_ef_lose_stat( lub_stat )
        gsw_lib_result = true
    ElseIf gub_lib_function = UB_LIB_EFFECTS_LOSE_EXP Then
        s_ef_lose_exp( gsl_lib_long_1 )
        gsw_lib_result = true
    ElseIf gub_lib_function = UB_LIB_EFFECTS_RESTORE_LEVELS Then
        ' Moria's spellRestorePlayerLevels()
        gsw_lib_result = false
        If gsl_player_max_exp > gsl_player_exp Then
            s_core_message( UW_MSG_YOU_FEEL_YOUR_LIFE_ENERGIES )
            ' this while loop is not redundant, displaying the experience can lower it by gaining a level
            While gsl_player_exp < gsl_player_max_exp
                gsl_player_exp = gsl_player_max_exp
                s_ef_display_experience()
            End While
            gsw_lib_result = true
        End If
    ElseIf gub_lib_function = UB_LIB_EFFECTS_DISPLAY_EXP Then
        s_ef_display_experience()
    ElseIf gub_lib_function = UB_LIB_EFFECTS_INGEST_FOOD Then
        s_ef_ingest_food( Cast( Integer , luw_amount ) )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_USE_DONE Then
        gsw_lib_result = fub_ef_use_done( lub_stat , luw_amount )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_USE_REMAINING Then
        s_ef_use_remaining( lub_stat )
    ElseIf gub_lib_function = UB_LIB_EFFECTS_CALC_HP Then
        s_ef_calculate_hit_points()
        s_ef_block()
    End If
End Sub
