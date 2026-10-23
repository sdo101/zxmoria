#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_player()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-player-include.bas"
#include "stage-lib-character-calls.bas"
' making a new character is Moria's characterCreate() (character.cpp) routine for routine, it takes two stages because it
' does not fit in one page, this is the first: choose a race and a sex, then roll the stats as often as you like...
' ...stage-player-class.bas is the second: choose a class, and give the character a name
' the screen is laid out exactly as Moria lays it out, on rows 0 to 23 of our 32, and the random numbers are asked for
' in exactly the order Moria asks for them
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, and what Moria does once the character is made is in core.bas, after the class
'     stage: the starting equipment (into the pack, unworn, as in Moria, so there are no bonuses from it to work
'     out), the food, and how many spells a new mage or priest may learn, with their mana

Sub s_pl_generate_stats()
    ' Moria's characterGenerateStats(): eighteen dice, six each of three, four and five sides, rolled again and again until
    ' they add up to something between 43 and 53, then each stat is 5 plus one die of each kind
    Dim i , lub_die     As UByte
    Dim luw_total       As UInteger

    Do
        luw_total = 0
        For i = 0 To 17
            lub_die = fuw_pl_random( 3 + i Mod 3 )
            Poke A_TEXT_BUFFER + i , lub_die
            luw_total = luw_total + lub_die
        Next
    Loop While luw_total <= 42 Or luw_total >= 54

    For i = 0 To 5
        Poke A_PLAYER_STATS_MAX + i , 5 + Peek( A_TEXT_BUFFER + 3 * i ) + Peek( A_TEXT_BUFFER + 3 * i + 1 ) + Peek( A_TEXT_BUFFER + 3 * i + 2 )
    Next
End Sub


Sub s_pl_stats_and_race()
    ' rolls the stats and applies everything the race gives, Moria's characterGenerateStatsAndRace()
    Dim i As UByte

    s_pl_generate_stats()
    For i = 0 To 5
        Poke A_PLAYER_STATS_MAX + i , fub_pl_modify_stat( Peek( A_PLAYER_STATS_MAX + i ) , Cast( Byte , Peek( A_RACE_ADJUSTMENTS + i ) ) )
    Next

    guw_player_level = 1
    s_pl_set_and_use_stats()

    gsw_player_search       = gsw_race_search
    gsw_player_bth          = gsw_race_bth
    gsw_player_bth_bows     = gsw_race_bth_bows
    gsw_player_fos          = gsw_race_fos
    gsw_player_stealth      = gsw_race_stealth
    gsw_player_saving_throw = gsw_race_saving_throw
    gub_player_hit_die      = gub_race_hit_die
    gsw_player_to_damage    = fsw_pl_damage_adjustment()
    gsw_player_to_hit       = fsw_pl_to_hit_adjustment()
    gsw_player_magical_ac   = 0
    gsw_player_ac           = fsw_pl_ac_adjustment()
    gub_player_exp_factor   = gub_race_exp_factor
    gsw_player_see_infra    = gub_race_infra_vision
End Sub


Sub s_pl_get_history()
    ' makes up the character's background, and from it the social class, Moria's characterGetHistory()...
    ' ...the history is a chain of pieces, e.g. "You are the first child " + "of a Yeoman.  " + "You are a credit to the family.  "...
    ' ...each piece is one of several choices from a "chart", picked by a 1 to 100 roll, and says which chart comes next
    Dim lub_history_id , lub_background , lub_next , lub_char   As UByte
    Dim luw_roll , luw_record , luw_length                      As UInteger
    Dim lsw_social                                              As Integer
    Dim lsw_start , lsw_end , lsw_new_start , lsw_count         As Integer
    Dim lub_line , lub_done , i                                 As UByte

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )

    lub_history_id = gub_player_race * 3 + 1
    lsw_social     = fuw_pl_random( 4 )
    luw_length     = 0
    lub_background = 0

    ' get a block of history text, built up in the text buffer
    Do
        lub_done = false
        While lub_done = false
            luw_record = A_CHARACTER_BACKGROUNDS + Cast( UInteger , lub_background ) * UB_BACKGROUND_SIZE
            If Peek( luw_record + UB_BACKGROUND_CHART ) = lub_history_id Then
                luw_roll = fuw_pl_random( 100 )
                While luw_roll > Peek( luw_record + UB_BACKGROUND_ROLL )
                    lub_background = lub_background + 1
                    luw_record     = luw_record + UB_BACKGROUND_SIZE
                End While

                i = UB_BACKGROUND_TEXT
                Do
                    lub_char = Peek( luw_record + i )
                    If lub_char = 0 Or luw_length >= 240 Then Exit Do
                    Poke A_TEXT_BUFFER + luw_length , lub_char
                    luw_length = luw_length + 1
                    i = i + 1
                Loop
                lsw_social = lsw_social + Cast( Integer , Peek( luw_record + UB_BACKGROUND_BONUS ) ) - 50

                lub_next = Peek( luw_record + UB_BACKGROUND_NEXT )
                If lub_history_id > lub_next Then lub_background = 0
                lub_history_id = lub_next
                lub_done = true
            Else
                lub_background = lub_background + 1
            End If
        End While
    Loop While lub_history_id >= 1

    ' clear the previous history
    For i = 0 To 3
        Poke A_PLAYER_HISTORY + Cast( UInteger , i ) * 60 , 0
    Next

    ' break the block into lines of no more than 60 characters, at spaces
    lsw_start = 0
    lsw_end   = Cast( Integer , luw_length ) - 1
    While Peek( A_TEXT_BUFFER + lsw_end ) = UC_SPACE
        lsw_end = lsw_end - 1
    End While
    lub_line      = 0
    lsw_new_start = 0
    lub_done      = false
    While lub_done = false
        While Peek( A_TEXT_BUFFER + lsw_start ) = UC_SPACE
            lsw_start = lsw_start + 1
        End While
        lsw_count = lsw_end - lsw_start + 1
        If lsw_count > 60 Then
            lsw_count = 60
            While Peek( A_TEXT_BUFFER + lsw_start + lsw_count - 1 ) <> UC_SPACE
                lsw_count = lsw_count - 1
            End While
            lsw_new_start = lsw_start + lsw_count
            While Peek( A_TEXT_BUFFER + lsw_start + lsw_count - 1 ) = UC_SPACE
                lsw_count = lsw_count - 1
            End While
        Else
            lub_done = true
        End If

        ' guard: Moria's histories never need more than four lines, but make sure of it
        If lub_line < 4 Then
            luw_record = A_PLAYER_HISTORY + Cast( UInteger , lub_line ) * 60
            For i = 0 To lsw_count - 1
                Poke luw_record + i , Peek( A_TEXT_BUFFER + lsw_start + i )
            Next
            If lsw_count < 60 Then Poke luw_record + lsw_count , 0
        End If
        lub_line  = lub_line + 1
        lsw_start = lsw_new_start
    End While

    ' the social class, from 1 to 100
    If lsw_social > 100 Then lsw_social = 100
    If lsw_social < 1 Then lsw_social = 1
    gsw_player_social_class = lsw_social
End Sub


Sub s_pl_age_height_weight()
    ' Moria's characterSetAgeHeightWeight()
    guw_player_age = gub_race_base_age + fuw_pl_random( gub_race_max_age )
    If gub_player_male Then
        guw_player_height = fsw_core_random_normal( gub_race_male_height , gub_race_male_height_mod )
        guw_player_weight = fsw_core_random_normal( gub_race_male_weight , gub_race_male_weight_mod )
    Else
        guw_player_height = fsw_core_random_normal( gub_race_female_height , gub_race_female_height_mod )
        guw_player_weight = fsw_core_random_normal( gub_race_female_weight , gub_race_female_weight_mod )
    End If
    gsw_player_disarm = gsw_race_disarm + fsw_pl_disarm_adjustment()
End Sub


Sub s_pl_choose_race()
    ' Moria's displayCharacterRaces() and characterChooseRace()
    Dim i , lub_row , lub_col   As UByte
    Dim lub_chosen              As UByte = UB_PL_NOT_CHOSEN

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )
    s_pl_clear_to_bottom( 20 )
    s_pl_put( 20 , 2 , "Choose a race (? for Help):" )
    lub_row = 21
    lub_col = 2
    For i = 0 To UB_PLAYER_MAX_RACES - 1
        s_pl_put( lub_row , lub_col , fs_core_char( Code( "a" ) + i ) + ") " + fs_core_text_at( A_CHARACTER_RACES + Cast( UInteger , i ) * UB_CHARACTER_RECORD_SIZE ) )
        lub_col = lub_col + 15
        If lub_col > 70 Then
            lub_col = 2
            lub_row = lub_row + 1
        End If
    Next

    Do
        s_core_get_key()
        If gub_key_char >= Code( "a" ) And gub_key_char < Code( "a" ) + UB_PLAYER_MAX_RACES Then lub_chosen = gub_key_char - Code( "a" )
        If gub_key_char = Code( "?" ) Then s_pl_welcome()
    Loop Until lub_chosen <> UB_PL_NOT_CHOSEN

    gub_player_race = lub_chosen
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )
    s_core_ram_copy( A_CHARACTER_RACES + Cast( UInteger , lub_chosen ) * UB_CHARACTER_RECORD_SIZE , A_RACE , UB_CHARACTER_RECORD_SIZE )
    s_pl_put( 3 , 15 , fs_core_text_at( A_RACE ) )
End Sub


Sub s_pl_choose_sex()
    ' Moria's characterSetGender()
    Dim lub_done As UByte = false

    s_pl_clear_to_bottom( 20 )
    s_pl_put( 20 , 2 , "Choose a sex (? for Help):" )
    s_pl_put( 21 , 2 , "m) Male       f) Female" )
    Do
        s_core_get_key()
        If gub_key_char = Code( "f" ) Or gub_key_char = Code( "F" ) Then
            gub_player_male = 0
            s_pl_put( 4 , 15 , "Female" )
            lub_done = true
        ElseIf gub_key_char = Code( "m" ) Or gub_key_char = Code( "M" ) Then
            gub_player_male = 1
            s_pl_put( 4 , 15 , "Male" )
            lub_done = true
        ElseIf gub_key_char = Code( "?" ) Then
            s_pl_welcome()
        End If
    Loop Until lub_done
End Sub


Function fub_pl_ask_least( pub_stat As UByte ) As UByte
    ' asks for the least that will do for one stat, typed as the player sees stats, 15 or 18/50...
    ' ...gives back the stat as it is held (18/50 is 68), 0 if anything will do, or 255 if ESC was pressed
    Dim ls_names                        As String = "STR INT WIS DEX CON CHR"
    Dim lub_length , lub_col , i        As UByte
    Dim luw_value , luw_percent         As UInteger
    Dim lub_slash                       As UByte

    s_core_clear_row( 21 , 0 , UB_WHITE )
    s_pl_put( 21 , 2 , "Least " + ls_names( pub_stat * 4 To pub_stat * 4 + 2 ) + " to take, as 15 or 18/50, RETURN for any: " )
    lub_col    = 53
    lub_length = 0
    Do
        s_core_get_key()
        If gub_key_char = UC_ESCAPE Then Return UB_PL_LEAST_ESCAPED
        If gub_key_char = UC_ENTER Then Exit Do
        If gub_key_char = UC_BACKSPACE Then
            If lub_length > 0 Then
                lub_length = lub_length - 1
                s_core_print_char_at( 21 , lub_col + lub_length , UC_SPACE , UB_WHITE )
            End If
        ElseIf lub_length < UB_PL_LEAST_DIGITS And ( gub_key_char = Code( "/" ) Or ( gub_key_char >= Code( "0" ) And gub_key_char <= Code( "9" ) ) ) Then
            Poke A_TEXT_BUFFER + lub_length , gub_key_char
            s_core_print_char_at( 21 , lub_col + lub_length , gub_key_char , UB_BRIGHT_WHITE )
            lub_length = lub_length + 1
        End If
    Loop

    luw_value   = 0
    luw_percent = 0
    lub_slash   = false
    For i = 0 To lub_length - 1
        If lub_length = 0 Then Exit For
        If Peek( A_TEXT_BUFFER + i ) = Code( "/" ) Then
            lub_slash = true
        ElseIf lub_slash Then
            If luw_percent < 100 Then luw_percent = luw_percent * 10 + Peek( A_TEXT_BUFFER + i ) - Code( "0" )
        Else
            If luw_value < 100 Then luw_value = luw_value * 10 + Peek( A_TEXT_BUFFER + i ) - Code( "0" )
        End If
    Next
    If luw_value > 18 Then luw_value = 18
    If luw_percent > 100 Then luw_percent = 100
    If lub_slash Then luw_value = 18 + luw_percent
    Return Cast( UByte , luw_value )
End Function


Function fub_pl_ask_all_least() As UByte
    ' asks for all six, true if the rolling is to begin, false if the player backed out with ESC
    Dim i , lub_least As UByte

    s_pl_clear_to_bottom( 20 )
    s_pl_put( 20 , 2 , "Roll until the stats are at least what you ask for (ESC to go back)." )
    For i = 0 To 5
        lub_least = fub_pl_ask_least( i )
        If lub_least = UB_PL_LEAST_ESCAPED Then Return false
        Poke A_PL_AUTO_LEAST + i , lub_least
    Next
    s_pl_clear_to_bottom( 20 )
    s_pl_put( 20 , 2 , "Rolling, any key stops: " )
    Return true
End Function


Function fub_pl_least_met() As UByte
    ' true if the character just rolled has every stat that was asked for
    Dim i As UByte

    For i = 0 To 5
        If Peek( A_PLAYER_STATS_MAX + i ) < Peek( A_PL_AUTO_LEAST + i ) Then Return false
    Next
    Return true
End Function


Sub s_stage_player()
    Dim luw_i       As UInteger
    Dim lub_done    As UByte
    Dim lub_auto , lub_let_go , lub_was_auto    As UByte
    Dim lul_rolls               As ULong

    ' a blank character, every part of it, as Moria's starts out
    For luw_i = 0 To UW_PLAYER_SIZE - 1
        Poke A_PLAYER + luw_i , 0
    Next

    s_pl_print_information()
    s_pl_choose_race()
    s_pl_choose_sex()

    ' roll, show, and roll again for as long as the player likes, or, with R, until the stats asked for come up,
    ' see fub_pl_ask_least() above
    lub_done = false
    lub_auto = false
    lub_was_auto = false
    While lub_done = false
        s_pl_stats_and_race()

        If lub_auto Then
            lub_was_auto = true
            lul_rolls = lul_rolls + 1
            ' the RETURN that began it is still down for the first rolls, a key only stops it once the keyboard has been let go
            If fub_core_scan_key() = 0 Then
                lub_let_go = true
            ElseIf lub_let_go Then
                lub_auto = false
            End If
            If fub_pl_least_met() Then lub_auto = false
            ' while it rolls only the stats are rolled and shown, a roll with all the rest takes a quarter of a second,
            ' the background, age, height and weight are made up for the character it stops at
            ' ...and they are shown one roll in eight, showing them is most of the time a roll takes
            If lub_auto And ( lul_rolls bAnd UB_PL_SHOW_ROLLS ) = 0 Then
                s_pl_print_stats()
                s_pl_put( 20 , 26 , fs_core_number( lul_rolls ) )
            End If
        End If

        If lub_auto = false Then
            s_pl_get_history()
            s_pl_age_height_weight()
            s_pl_print_history()
            s_pl_print_vital_statistics()
            s_pl_print_stats()

            s_pl_clear_to_bottom( 20 )
            s_pl_put( 20 , 2 , "Hit space to re-roll or ESC to accept characteristics: " )
            If lub_was_auto Then s_pl_put( 21 , 2 , "The auto roller stopped after " + fs_core_number( lul_rolls ) + " rolls." )
            lub_was_auto = false
            Do
                s_core_get_key()
                If gub_key_char = UC_ESCAPE Then lub_done = true
                If gub_key_char = Code( "R" ) Then
                    If fub_pl_ask_all_least() Then
                        lub_auto   = true
                        lub_let_go = false
                        lul_rolls  = 0
                    Else
                        ' backed out: the question again, N.B: the ESC that backed out must not also accept the character
                        s_pl_clear_to_bottom( 20 )
                        s_pl_put( 20 , 2 , "Hit space to re-roll or ESC to accept characteristics: " )
                        gub_key_char = 0
                    End If
                End If
            Loop Until gub_key_char = UC_ESCAPE Or gub_key_char = UC_SPACE Or lub_auto
        End If
    End While

    ' the screen is left as it is, the next stage carries on from it
End Sub