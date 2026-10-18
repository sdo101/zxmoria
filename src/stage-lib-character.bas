#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_character()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-player-include.bas"
#include "stage-strings-include.bas"

' this page is a LIBRARY, not a stage: what the character's stats are worth, and the character sheet...
' ...any stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , <which routine> ),
' stage-lib-character-calls.bas has a ready made routine for each of these, a stage includes that and calls them by name
' every routine works on the player record, the answers come back in gsw_lib_result, the routines are:
'
'   UB_LIB_CHAR_TO_HIT          the plus to hit that dexterity and strength give
'   UB_LIB_CHAR_DAMAGE          the plus to damage that strength gives
'   UB_LIB_CHAR_AC              the plus to armour class that dexterity gives
'   UB_LIB_CHAR_DISARM          the plus to disarming that dexterity gives
'   UB_LIB_CHAR_CON             the hit points per level that constitution gives
'   UB_LIB_CHAR_WIS_INT         the bonus from wisdom or intelligence, gub_lib_param_1 says which stat
'   UB_LIB_CHAR_MODIFY_STAT     the stat in gub_lib_param_1 changed by the steps in guw_lib_param_2 (a signed number),
'                               with Moria's randomness above 18, as when a race or class is applied
'   UB_LIB_CHAR_SET_STATS       makes every stat's natural value its full value, and works out the value the game uses
'   UB_LIB_CHAR_PRINT_INFO      the headings: Name, Race, Sex, Class
'   UB_LIB_CHAR_PRINT_STATS     the six stats, and the plusses to hit, damage and armour class
'   UB_LIB_CHAR_PRINT_VITALS    age, height, weight and social class
'   UB_LIB_CHAR_PRINT_HISTORY   the character's background
'   UB_LIB_CHAR_PRINT_LEVEL     level, experience, gold, hit points and mana
'   UB_LIB_CHAR_PRINT_ABILITIES the "Fighting: Poor ... Saving Throw: Excellent" ratings
'   UB_LIB_CHAR_PRINT_BLOCK     the character's details down the left of the game screen: race, class, title, stats,
'                               level, experience, mana, hit points, armour class and gold
'   UB_LIB_CHAR_CHARISMA        what charisma does to prices, a percentage, 100 is no change, a charming character pays less
'
' N.B: the PRINT routines are in stage-lib-character-2.bas, this page passes them on, it had no room left for them

Function fsw_pl_to_hit_adjustment() As Integer
    ' Moria's playerToHitAdjustment(): dexterity and strength both help
    Dim lub_stat    As UByte
    Dim lsw_total   As Integer

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_DEX )
    If lub_stat < 4 Then
        lsw_total = -3
    ElseIf lub_stat < 6 Then
        lsw_total = -2
    ElseIf lub_stat < 8 Then
        lsw_total = -1
    ElseIf lub_stat < 16 Then
        lsw_total = 0
    ElseIf lub_stat < 17 Then
        lsw_total = 1
    ElseIf lub_stat < 18 Then
        lsw_total = 2
    ElseIf lub_stat < 69 Then
        lsw_total = 3
    ElseIf lub_stat < 118 Then
        lsw_total = 4
    Else
        lsw_total = 5
    End If

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_STR )
    If lub_stat < 4 Then
        lsw_total = lsw_total - 3
    ElseIf lub_stat < 5 Then
        lsw_total = lsw_total - 2
    ElseIf lub_stat < 7 Then
        lsw_total = lsw_total - 1
    ElseIf lub_stat < 18 Then
        ' no change
    ElseIf lub_stat < 94 Then
        lsw_total = lsw_total + 1
    ElseIf lub_stat < 109 Then
        lsw_total = lsw_total + 2
    ElseIf lub_stat < 117 Then
        lsw_total = lsw_total + 3
    Else
        lsw_total = lsw_total + 4
    End If
    Return lsw_total
End Function


Function fsw_pl_damage_adjustment() As Integer
    ' Moria's playerDamageAdjustment(), from strength
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_STR )
    If lub_stat < 4 Then Return -2
    If lub_stat < 5 Then Return -1
    If lub_stat < 16 Then Return 0
    If lub_stat < 17 Then Return 1
    If lub_stat < 18 Then Return 2
    If lub_stat < 94 Then Return 3
    If lub_stat < 109 Then Return 4
    If lub_stat < 117 Then Return 5
    Return 6
End Function


Function fsw_pl_ac_adjustment() As Integer
    ' Moria's playerArmorClassAdjustment(), from dexterity
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_DEX )
    If lub_stat < 4 Then Return -4
    If lub_stat = 4 Then Return -3
    If lub_stat = 5 Then Return -2
    If lub_stat = 6 Then Return -1
    If lub_stat < 15 Then Return 0
    If lub_stat < 18 Then Return 1
    If lub_stat < 59 Then Return 2
    If lub_stat < 94 Then Return 3
    If lub_stat < 117 Then Return 4
    Return 5
End Function


Function fsw_pl_disarm_adjustment() As Integer
    ' Moria's playerDisarmAdjustment(), from dexterity
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_DEX )
    If lub_stat < 4 Then Return -8
    If lub_stat = 4 Then Return -6
    If lub_stat = 5 Then Return -4
    If lub_stat = 6 Then Return -2
    If lub_stat = 7 Then Return -1
    If lub_stat < 13 Then Return 0
    If lub_stat < 16 Then Return 1
    If lub_stat < 18 Then Return 2
    If lub_stat < 59 Then Return 4
    If lub_stat < 94 Then Return 5
    If lub_stat < 117 Then Return 6
    Return 8
End Function


Function fsw_pl_con_adjustment() As Integer
    ' Moria's playerStatAdjustmentConstitution(), hit points per level
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_CON )
    If lub_stat < 7 Then Return Cast( Integer , lub_stat ) - 7
    If lub_stat < 17 Then Return 0
    If lub_stat = 17 Then Return 1
    If lub_stat < 94 Then Return 2
    If lub_stat < 117 Then Return 3
    Return 4
End Function


Function fsw_pl_wis_int_adjustment( pub_which As UByte ) As Integer
    ' Moria's playerStatAdjustmentWisdomIntelligence(), for whichever of the two stats is asked about
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + pub_which )
    If lub_stat > 117 Then Return 7
    If lub_stat > 107 Then Return 6
    If lub_stat > 87 Then Return 5
    If lub_stat > 67 Then Return 4
    If lub_stat > 17 Then Return 3
    If lub_stat > 14 Then Return 2
    If lub_stat > 7 Then Return 1
    Return 0
End Function


Function fub_pl_modify_stat( pub_stat As UByte , psb_adjustment As Byte ) As UByte
    ' changes a stat by so many steps for the character's race or class, with a little randomness, Moria's createModifyPlayerStat()...
    ' ...up to 18 a step is one point, above that a step is a random part of the way through the 18/01 to 18/100 range
    Dim lsw_stat    As Integer
    Dim i           As Byte

    lsw_stat = pub_stat
    If psb_adjustment < 0 Then
        For i = -1 To psb_adjustment Step -1
            If lsw_stat > 108 Then
                lsw_stat = lsw_stat - 1
            ElseIf lsw_stat > 88 Then
                lsw_stat = lsw_stat - Cast( Integer , fuw_pl_random( 6 ) ) - 2
            ElseIf lsw_stat > 18 Then
                lsw_stat = lsw_stat - Cast( Integer , fuw_pl_random( 15 ) ) - 5
                If lsw_stat < 18 Then lsw_stat = 18
            ElseIf lsw_stat > 3 Then
                lsw_stat = lsw_stat - 1
            End If
        Next
    ElseIf psb_adjustment > 0 Then
        For i = 1 To psb_adjustment
            If lsw_stat < 18 Then
                lsw_stat = lsw_stat + 1
            ElseIf lsw_stat < 88 Then
                lsw_stat = lsw_stat + Cast( Integer , fuw_pl_random( 15 ) ) + 5
            ElseIf lsw_stat < 108 Then
                lsw_stat = lsw_stat + Cast( Integer , fuw_pl_random( 6 ) ) + 2
            ElseIf lsw_stat < 118 Then
                lsw_stat = lsw_stat + 1
            End If
        Next
    End If
    Return Cast( UByte , lsw_stat )
End Function


Sub s_pl_set_and_use_stats()
    ' makes every stat's natural value its full value, and works out the value the game uses, which adds whatever the
    ' equipment gives, this is the loop over Moria's playerSetAndUseStat() and its playerModifyStat()
    Dim i , lub_stat , lub_step     As UByte
    Dim lsw_amount , lsw_steps      As Integer

    For i = 0 To 5
        lub_stat = Peek( A_PLAYER_STATS_MAX + i )
        Poke A_PLAYER_STATS_CURRENT + i , lub_stat

        lsw_amount = Peek( Integer , A_PLAYER_STATS_MODIFIED + 2 * i )
        lsw_steps  = Abs( lsw_amount )
        lub_step   = 0
        While lub_step < lsw_steps
            If lsw_amount > 0 Then
                If lub_stat < 18 Then
                    lub_stat = lub_stat + 1
                ElseIf lub_stat < 108 Then
                    lub_stat = lub_stat + 10
                Else
                    lub_stat = 118
                End If
            Else
                If lub_stat > 27 Then
                    lub_stat = lub_stat - 10
                ElseIf lub_stat > 18 Then
                    lub_stat = 18
                ElseIf lub_stat > 3 Then
                    lub_stat = lub_stat - 1
                End If
            End If
            lub_step = lub_step + 1
        End While
        Poke A_PLAYER_STATS_USED + i , lub_stat

        ' N.B: Moria goes on from here to recalculate the bonuses from equipment (for strength and dexterity), the spells
        ' and mana (for intelligence or wisdom, by class) and the hit points (for constitution)...
        ' ...none of which changes anything while a character is being made: there is no equipment, no spell has been learnt
        ' so mana stays 0, and the hit points are set outright when the class is chosen
    Next
End Sub


Function fsw_pl_charisma_adjustment() As Integer
    ' Moria's playerStatAdjustmentCharisma()
    Dim lub_stat As UByte

    lub_stat = Peek( A_PLAYER_STATS_USED + UB_STAT_CHR )
    If lub_stat > 117 Then Return 90
    If lub_stat > 107 Then Return 92
    If lub_stat > 87 Then Return 94
    If lub_stat > 67 Then Return 96
    If lub_stat > 18 Then Return 98
    If lub_stat = 18 Then Return 100
    If lub_stat = 17 Then Return 101
    If lub_stat = 16 Then Return 102
    If lub_stat = 15 Then Return 103
    If lub_stat = 14 Then Return 104
    If lub_stat = 13 Then Return 106
    If lub_stat = 12 Then Return 108
    If lub_stat = 11 Then Return 110
    If lub_stat = 10 Then Return 112
    If lub_stat = 9 Then Return 114
    If lub_stat = 8 Then Return 116
    If lub_stat = 7 Then Return 118
    If lub_stat = 6 Then Return 120
    If lub_stat = 5 Then Return 122
    If lub_stat = 4 Then Return 125
    If lub_stat = 3 Then Return 130
    Return 100
End Function


'##################################################################################################################################
' --- the way in ---

Sub s_lib_character()
    If gub_lib_function = UB_LIB_CHAR_TO_HIT Then
        gsw_lib_result = fsw_pl_to_hit_adjustment()
    ElseIf gub_lib_function = UB_LIB_CHAR_DAMAGE Then
        gsw_lib_result = fsw_pl_damage_adjustment()
    ElseIf gub_lib_function = UB_LIB_CHAR_AC Then
        gsw_lib_result = fsw_pl_ac_adjustment()
    ElseIf gub_lib_function = UB_LIB_CHAR_DISARM Then
        gsw_lib_result = fsw_pl_disarm_adjustment()
    ElseIf gub_lib_function = UB_LIB_CHAR_CON Then
        gsw_lib_result = fsw_pl_con_adjustment()
    ElseIf gub_lib_function = UB_LIB_CHAR_WIS_INT Then
        gsw_lib_result = fsw_pl_wis_int_adjustment( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_CHAR_MODIFY_STAT Then
        gsw_lib_result = fub_pl_modify_stat( gub_lib_param_1 , Cast( Byte , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_CHAR_SET_STATS Then
        s_pl_set_and_use_stats()
    ElseIf ( gub_lib_function >= UB_LIB_CHAR_PRINT_INFO And gub_lib_function <= UB_LIB_CHAR_PRINT_ABILITIES ) Or gub_lib_function = UB_LIB_CHAR_PRINT_BLOCK Then
        ' the character sheet and the block down the left of the screen are the second character library's, it
        ' goes by the same numbers, so whoever asked need not know
        s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER_2 , gub_lib_function )
    ElseIf gub_lib_function = UB_LIB_CHAR_CHARISMA Then
        gsw_lib_result = fsw_pl_charisma_adjustment()
    End If
End Sub