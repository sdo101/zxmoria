#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_player_class()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-player-include.bas"
#include "stage-lib-character-calls.bas"
' the second of the two stages that make a new character, see stage-player.bas: the race, sex and stats are settled and
' are on the screen, now choose a class, which changes the stats again, and give the character a name


Sub s_pl_generate_class( pub_class As UByte )
    ' applies everything the class gives, and rolls the hit points for every level to come, Moria's generateCharacterClass()
    Dim i                               As UByte
    Dim luw_min , luw_max , luw_total   As UInteger

    gub_player_class = pub_class
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )
    s_core_ram_copy( A_CHARACTER_CLASSES + Cast( UInteger , pub_class ) * 64 , A_CLASS , 64 )

    s_pl_clear_to_bottom( 20 )
    s_pl_put( 5 , 15 , fs_core_text_at( A_CLASS ) )

    ' adjust the stats for the class
    For i = 0 To 5
        Poke A_PLAYER_STATS_MAX + i , fub_pl_modify_stat( Peek( A_PLAYER_STATS_MAX + i ) , Cast( Byte , Peek( A_CLASS_ADJUSTMENTS + i ) ) )
    Next
    s_pl_set_and_use_stats()

    ' the real values...
    gsw_player_to_damage  = fsw_pl_damage_adjustment()
    gsw_player_to_hit     = fsw_pl_to_hit_adjustment()
    gsw_player_magical_ac = fsw_pl_ac_adjustment()
    gsw_player_ac         = 0
    ' ...and the displayed ones
    gsw_player_display_to_dam   = gsw_player_to_damage
    gsw_player_display_to_hit   = gsw_player_to_hit
    gsw_player_display_to_ac    = gsw_player_magical_ac
    gsw_player_display_ac       = gsw_player_ac + gsw_player_display_to_ac

    ' the hit points, this comes after the stats because it depends on constitution
    gub_player_hit_die     = gub_player_hit_die + gub_class_hit_die
    gsw_player_max_hp      = fsw_pl_con_adjustment() + gub_player_hit_die
    gsw_player_current_hp  = gsw_player_max_hp
    guw_player_hp_fraction = 0

    ' roll the hit points gained at each of the 40 levels, and roll them all again unless the total at the top level
    ' is within an eighth of the average
    ' N.B: these must be worked out as 16 bit numbers, a warrior's come to 310 and 490, as bytes they wrap round and the loop below never ends
    luw_min = Cast( UInteger , UB_PLAYER_MAX_LEVEL * 3 / 8 ) * ( Cast( UInteger , gub_player_hit_die ) - 1 ) + UB_PLAYER_MAX_LEVEL
    luw_max = Cast( UInteger , UB_PLAYER_MAX_LEVEL * 5 / 8 ) * ( Cast( UInteger , gub_player_hit_die ) - 1 ) + UB_PLAYER_MAX_LEVEL
    Poke UInteger A_PLAYER_HP_LEVELS , gub_player_hit_die
    Do
        luw_total = gub_player_hit_die
        For i = 1 To UB_PLAYER_MAX_LEVEL - 1
            luw_total = luw_total + fuw_pl_random( gub_player_hit_die )
            Poke UInteger A_PLAYER_HP_LEVELS + 2 * Cast( UInteger , i ) , luw_total
        Next
    Loop While luw_total < luw_min Or luw_total > luw_max

    gsw_player_bth          = gsw_player_bth + gub_class_bth
    gsw_player_bth_bows     = gsw_player_bth_bows + gub_class_bth_bows
    gsw_player_search       = gsw_player_search + gub_class_search
    gsw_player_disarm       = gsw_player_disarm + gub_class_disarm
    gsw_player_fos          = gsw_player_fos + gub_class_fos
    gsw_player_stealth      = gsw_player_stealth + gub_class_stealth
    gsw_player_saving_throw = gsw_player_saving_throw + gub_class_saving_throw
    gub_player_exp_factor   = gub_player_exp_factor + gub_class_exp_factor
End Sub


Sub s_pl_choose_class()
    ' Moria's displayRaceClasses() and characterGetClass(): only the classes the race may be are offered
    Dim i , lub_row , lub_col , lub_count , lub_mask    As UByte
    Dim lub_chosen                                      As UByte = 255

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )
    s_pl_clear_to_bottom( 20 )
    s_pl_put( 20 , 2 , "Choose a class (? for Help):" )
    lub_row   = 21
    lub_col   = 2
    lub_count = 0
    lub_mask  = 1
    For i = 0 To UB_PLAYER_MAX_CLASSES - 1
        If ( gub_race_classes bAnd lub_mask ) <> 0 Then
            s_pl_put( lub_row , lub_col , fs_core_char( 97 + lub_count ) + ") " + fs_core_text_at( A_CHARACTER_CLASSES + Cast( UInteger , i ) * 64 ) )
            Poke A_TEXT_BUFFER + lub_count , i          ' which class each letter stands for
            lub_col = lub_col + 15
            If lub_col > 70 Then
                lub_col = 2
                lub_row = lub_row + 1
            End If
            lub_count = lub_count + 1
        End If
        lub_mask = lub_mask << 1
    Next

    gub_player_class = 0
    Do
        s_core_get_key()
        If gub_key_char >= 97 And gub_key_char < 97 + lub_count Then lub_chosen = Peek( A_TEXT_BUFFER + gub_key_char - 97 )
        If gub_key_char = Code( "?" ) Then s_pl_welcome()
    Loop Until lub_chosen <> 255
    s_pl_generate_class( lub_chosen )
End Sub


Sub s_pl_start_gold()
    ' how much gold the character starts with, Moria's playerCalculateStartGold(): good stats mean less of it,
    ' good breeding and charm mean more
    Dim lsl_value , lsl_gold As Long

    lsl_value = 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_STR ) ) - 10 )
    lsl_value = lsl_value + 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_INT ) ) - 10 )
    lsl_value = lsl_value + 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_WIS ) ) - 10 )
    lsl_value = lsl_value + 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_CON ) ) - 10 )
    lsl_value = lsl_value + 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_DEX ) ) - 10 )

    lsl_gold = Cast( Long , gsw_player_social_class ) * 6 + Cast( Long , fuw_pl_random( 25 ) ) + 325
    lsl_gold = lsl_gold - lsl_value
    lsl_gold = lsl_gold + 5 * ( Cast( Long , Peek( A_PLAYER_STATS_MAX + UB_STAT_CHR ) ) - 10 )
    If gub_player_male = 0 Then lsl_gold = lsl_gold + 50        ' she charmed the banker into it! -CJS-
    If lsl_gold < 80 Then lsl_gold = 80
    gsl_player_gold = lsl_gold
End Sub


Sub s_pl_get_name()
    ' Moria's getCharacterName(): up to 23 characters, Enter to finish, and a name of "X" if none is given
    Dim lub_length As UByte = 0

    s_core_clear_row( 21 , 0 , UB_WHITE )
    s_pl_put( 21 , 2 , "Enter your player's name  [press <RETURN> when finished]" )
    s_pl_put( 2 , 15 , "_                      " )
    Do
        s_core_get_key()
        If gub_key_char = 13 Then Exit Do
        If gub_key_char = 27 Then           ' escape: give up, and take the default name
            lub_length = 0
            Exit Do
        End If
        If gub_key_char = 8 Then            ' delete
            If lub_length > 0 Then
                s_core_print_char_at( 2 , 15 + lub_length , 32 , UB_WHITE )
                lub_length = lub_length - 1
                s_core_print_char_at( 2 , 15 + lub_length , Code( "_" ) , UB_WHITE )
            End If
        ElseIf gub_key_char >= 32 And gub_key_char < 127 And lub_length < 23 Then
            Poke A_PLAYER_NAME + lub_length , gub_key_char
            s_core_print_char_at( 2 , 15 + lub_length , gub_key_char , UB_BRIGHT_WHITE )
            lub_length = lub_length + 1
            If lub_length < 23 Then s_core_print_char_at( 2 , 15 + lub_length , Code( "_" ) , UB_WHITE )
        End If
    Loop
    If lub_length = 0 Then
        Poke A_PLAYER_NAME , Code( "X" )
        lub_length = 1
    End If
    Poke A_PLAYER_NAME + lub_length , 0
    s_pl_put( 2 , 15 , "                       " )
    s_core_print_string_at( 2 , 15 , fs_core_text_at( A_PLAYER_NAME ) , UB_BRIGHT_WHITE )
    s_pl_clear_to_bottom( 20 )
End Sub


Sub s_stage_player_class()
    s_pl_choose_class()
    s_pl_start_gold()
    s_pl_print_stats()
    s_pl_print_level_experience()
    s_pl_print_abilities()
    s_pl_get_name()

    s_core_clear_row( 23 , 0 , UB_WHITE )
    s_pl_put( 23 , 17 , "[ press any key to continue, or Q to exit ]" )
    s_core_get_key()
    If gub_key_char = Code( "Q" ) Or guw_key_code = 0 Then gub_core_end = true
End Sub