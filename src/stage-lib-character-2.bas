#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_character_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-player-include.bas"
#include "stage-strings-include.bas"

' this page is a LIBRARY, not a stage: the second half of the character library, stage-lib-character.bas, which had
' no room left: the character sheet, and the character's details down the left of the game screen...
' ...nothing calls it but the character library, which passes on to it the routines it used to have itself, by the
' same numbers: UB_LIB_CHAR_PRINT_INFO, _STATS, _VITALS, _HISTORY, _LEVEL, _ABILITIES and _BLOCK, see that page
' for what each one shows


Function fsw_pl_disarm_adjustment() As Integer
    ' the plus to disarming that dexterity gives, the character library works it out
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DISARM )
    Return gsw_lib_result
End Function


Function fsw_pl_wis_int_adjustment( pub_which As UByte ) As Integer
    ' the bonus from wisdom or intelligence, the character library works it out
    gub_lib_param_1 = pub_which
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    Return gsw_lib_result
End Function

Sub s_pl_print_stats()
    ' Moria's printCharacterStats()
    Dim i           As UByte
    Dim ls_name     As String

    For i = 0 To 5
        If i = UB_STAT_STR Then ls_name = "STR : "
        If i = UB_STAT_INT Then ls_name = "INT : "
        If i = UB_STAT_WIS Then ls_name = "WIS : "
        If i = UB_STAT_DEX Then ls_name = "DEX : "
        If i = UB_STAT_CON Then ls_name = "CON : "
        If i = UB_STAT_CHR Then ls_name = "CHR : "
        s_pl_put( 2 + i , 61 , ls_name + fs_pl_stat( Peek( A_PLAYER_STATS_USED + i ) ) )
        If Peek( A_PLAYER_STATS_MAX + i ) > Peek( A_PLAYER_STATS_CURRENT + i ) Then s_pl_put( 2 + i , 73 , fs_pl_stat( Peek( A_PLAYER_STATS_MAX + i ) ) )
    Next
    s_pl_header_number( "+ To Hit    " , gsw_player_display_to_hit , 6 , 9 , 1 )
    s_pl_header_number( "+ To Damage " , gsw_player_display_to_dam , 6 , 10 , 1 )
    s_pl_header_number( "+ To AC     " , gsw_player_display_to_ac , 6 , 11 , 1 )
    s_pl_header_number( "  Total AC  " , gsw_player_display_ac , 6 , 12 , 1 )
End Sub


Sub s_pl_print_information()
    ' Moria's printCharacterInformation()
    s_core_clear_screen()
    s_pl_put( 2 , 1 , "Name        :" )
    s_pl_put( 3 , 1 , "Race        :" )
    s_pl_put( 4 , 1 , "Sex         :" )
    s_pl_put( 5 , 1 , "Class       :" )
End Sub


Sub s_pl_print_history()
    ' Moria's displayCharacterHistory()
    Dim i As UByte

    s_pl_put( 14 , 27 , "Character Background" )
    For i = 0 To 3
        s_core_clear_row( 15 + i , 0 , UB_WHITE )
        s_pl_put( 15 + i , 10 , fs_pl_text( A_PLAYER_HISTORY + Cast( UInteger , i ) * 60 , 60 ) )
    Next
End Sub


Sub s_pl_print_vital_statistics()
    ' Moria's printCharacterVitalStatistics()
    s_pl_header_number( "Age          " , guw_player_age , 6 , 2 , 38 )
    s_pl_header_number( "Height       " , guw_player_height , 6 , 3 , 38 )
    s_pl_header_number( "Weight       " , guw_player_weight , 6 , 4 , 38 )
    s_pl_header_number( "Social Class " , gsw_player_social_class , 6 , 5 , 38 )
End Sub


Sub s_pl_print_level_experience()
    ' Moria's printCharacterLevelExperience()
    Dim lul_to_advance As ULong

    s_pl_header_number( "Level      " , guw_player_level , 7 , 9 , 28 )
    s_pl_header_number( "Experience " , gsl_player_exp , 7 , 10 , 28 )
    s_pl_header_number( "Max Exp    " , gsl_player_max_exp , 7 , 11 , 28 )
    If guw_player_level >= UB_PLAYER_MAX_LEVEL Then
        s_pl_put( 12 , 28 , "Exp to Adv.: *******" )
    Else
        lul_to_advance = Peek( ULong , A_EXP_LEVELS + ( guw_player_level - 1 ) * 4 ) * gub_player_exp_factor / 100
        s_pl_header_number( "Exp to Adv." , lul_to_advance , 7 , 12 , 28 )
    End If
    s_pl_header_number( "Gold       " , gsl_player_gold , 7 , 13 , 28 )
    s_pl_header_number( "Max Hit Points " , gsw_player_max_hp , 6 , 9 , 52 )
    s_pl_header_number( "Cur Hit Points " , gsw_player_current_hp , 6 , 10 , 52 )
    s_pl_header_number( "Max Mana       " , gsw_player_mana , 6 , 11 , 52 )
    s_pl_header_number( "Cur Mana       " , gsw_player_current_mana , 6 , 12 , 52 )
End Sub


Function fs_pl_rating( psw_value As Integer , psw_per As Integer ) As String
    ' turns an ability into a word, Moria's statRating()
    Dim lsw_rating As Integer

    lsw_rating = psw_value / psw_per
    If lsw_rating < 0 Then Return "Very Bad"
    If lsw_rating < 2 Then Return "Bad"
    If lsw_rating = 2 Then Return "Poor"
    If lsw_rating < 5 Then Return "Fair"
    If lsw_rating = 5 Then Return "Good"
    If lsw_rating = 6 Then Return "Very Good"
    If lsw_rating < 9 Then Return "Excellent"
    Return "Superb"
End Function


Sub s_pl_print_abilities()
    ' Moria's printCharacterAbilities()
    Dim lsw_bth , lsw_bthb , lsw_fos , lsw_dis , lsw_save , lsw_dev As Integer

    s_pl_clear_to_bottom( 14 )
    lsw_bth  = gsw_player_bth + gsw_player_to_hit * 3 + Cast( Integer , gub_class_adj_bth ) * guw_player_level
    lsw_bthb = gsw_player_bth_bows + gsw_player_to_hit * 3 + Cast( Integer , gub_class_adj_bth_bows ) * guw_player_level
    lsw_fos  = 40 - gsw_player_fos
    If lsw_fos < 0 Then lsw_fos = 0
    lsw_dis  = gsw_player_disarm + 2 * fsw_pl_disarm_adjustment() + fsw_pl_wis_int_adjustment( UB_STAT_INT ) + ( Cast( Integer , gub_class_adj_disarm ) * guw_player_level / 3 )
    lsw_save = gsw_player_saving_throw + fsw_pl_wis_int_adjustment( UB_STAT_WIS ) + ( Cast( Integer , gub_class_adj_save ) * guw_player_level / 3 )
    lsw_dev  = gsw_player_saving_throw + fsw_pl_wis_int_adjustment( UB_STAT_INT ) + ( Cast( Integer , gub_class_adj_device ) * guw_player_level / 3 )

    s_pl_put( 15 , 25 , "(Miscellaneous Abilities)" )
    s_pl_put( 16 , 1 , "Fighting    : " + fs_pl_rating( lsw_bth , 12 ) )
    s_pl_put( 17 , 1 , "Bows/Throw  : " + fs_pl_rating( lsw_bthb , 12 ) )
    s_pl_put( 18 , 1 , "Saving Throw: " + fs_pl_rating( lsw_save , 6 ) )
    s_pl_put( 16 , 28 , "Stealth     : " + fs_pl_rating( gsw_player_stealth + 1 , 1 ) )
    s_pl_put( 17 , 28 , "Disarming   : " + fs_pl_rating( lsw_dis , 8 ) )
    s_pl_put( 18 , 28 , "Magic Device: " + fs_pl_rating( lsw_dev , 6 ) )
    s_pl_put( 16 , 55 , "Perception  : " + fs_pl_rating( lsw_fos , 3 ) )
    s_pl_put( 17 , 55 , "Searching   : " + fs_pl_rating( gsw_player_search , 6 ) )
    s_pl_put( 18 , 55 , "Infra-Vision: " + fs_core_number( gsw_player_see_infra * 10 ) + " feet" )
End Sub


Sub s_pl_block_line( pub_row As UByte , ps_header As String , psl_value As Long )
    ' one line of the block: a heading and a number, "LEV :      1"
    s_core_print_string_at( pub_row , 0 , ps_header + ": " + fs_pl_number( psl_value , 6 ) , UB_WHITE )
End Sub


Sub s_pl_print_block()
    ' Moria's printCharacterStatsBlock(), the left hand 13 columns of the game screen
    Dim i           As UByte
    Dim ls_name     As String
    Dim lub_rows    As UByte

    lub_rows = fub_core_print_text_at( 2 , 0 , A_RACE , UB_WHITE )
    lub_rows = fub_core_print_text_at( 3 , 0 , A_CLASS , UB_WHITE )
    ' what a character of this class and level is called, Moria's playerRankTitle()
    If guw_player_level >= 1 And guw_player_level <= UB_PLAYER_MAX_LEVEL Then
        s_string_fetch( UW_STR_RANK_TITLES + Cast( UInteger , gub_player_class ) * UB_PLAYER_MAX_LEVEL + guw_player_level - 1 , A_TEXT_BUFFER )
        ' N.B: the old title is rubbed out first, a shorter one would leave its last letters showing ("Lord Keepert")
        s_core_print_string_at( 4 , 0 , "             " , UB_WHITE )
        lub_rows = fub_core_print_text_at( 4 , 0 , A_TEXT_BUFFER , UB_WHITE )
    End If

    For i = 0 To 5
        If i = UB_STAT_STR Then ls_name = "STR : "
        If i = UB_STAT_INT Then ls_name = "INT : "
        If i = UB_STAT_WIS Then ls_name = "WIS : "
        If i = UB_STAT_DEX Then ls_name = "DEX : "
        If i = UB_STAT_CON Then ls_name = "CON : "
        If i = UB_STAT_CHR Then ls_name = "CHR : "
        s_core_print_string_at( 6 + i , 0 , ls_name + fs_pl_stat( Peek( A_PLAYER_STATS_USED + i ) ) , UB_WHITE )
    Next
    s_pl_block_line( 13 , "LEV " , guw_player_level )
    s_pl_block_line( 14 , "EXP " , gsl_player_exp )
    s_pl_block_line( 15 , "MANA" , gsw_player_current_mana )
    s_pl_block_line( 16 , "MHP " , gsw_player_max_hp )
    s_pl_block_line( 17 , "CHP " , gsw_player_current_hp )
    s_pl_block_line( 19 , "AC  " , gsw_player_display_ac )
    s_pl_block_line( 20 , "GOLD" , gsl_player_gold )
    ' the words along the bottom that come and go, hungry, blind, fast..., are the turn library's, see s_t2_status_line() in stage-lib-turn-2.bas
End Sub

Sub s_lib_character_2()
    If gub_lib_function = UB_LIB_CHAR_PRINT_INFO Then
        s_pl_print_information()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_STATS Then
        s_pl_print_stats()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_VITALS Then
        s_pl_print_vital_statistics()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_HISTORY Then
        s_pl_print_history()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_LEVEL Then
        s_pl_print_level_experience()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_ABILITIES Then
        s_pl_print_abilities()
    ElseIf gub_lib_function = UB_LIB_CHAR_PRINT_BLOCK Then
        s_pl_print_block()
    End If
End Sub
