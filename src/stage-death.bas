#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_death()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-strings-include.bas"

' this stage is the end of a character: the player has died, or has given up, or has won and is retiring, the core
' comes here from the walking stage, and goes on from here to the opening screen and a new game, unless the player
' quit, when it goes back to NextZXOS, it is Moria's endGame() (game_death.cpp): the winner's crown, and the
' tombstone, the pictures are Moria's own, death_royal.txt and death_tomb.txt
'
' what is NOT here yet:
'   - nothing that is known of
' N.B: the date on the tombstone comes from the Next's clock, a Next without one has none, see stage-lib-scores.bas



Function fuw_dt_art( pub_which As UByte ) As UInteger
    ' where a picture is: lines that each end in a 13, and a 0 after the last
    If pub_which = 1 Then Return @dt_tomb
    Return @dt_royal
dt_tomb:
    Asm
        defb 13
        defm "               _______________________"
        defb 13
        defm "              /                       "
        defb 92
        defm "         ___"
        defb 13
        defm "             /                         "
        defb 92
        defm " ___   /   "
        defb 92
        defm "      ___"
        defb 13
        defm "            /            RIP            "
        defb 92
        defm "   "
        defb 92
        defm "  :   :     /   "
        defb 92
        defb 13
        defm "           /                             "
        defb 92
        defm "  : _;,,,;_    :   :"
        defb 13
        defm "          /                               "
        defb 92
        defm ",;_          _;,,,;_"
        defb 13
        defm "         |               the               |   ___"
        defb 13
        defm "         |                                 |  /   "
        defb 92
        defb 13
        defm "         |                                 |  :   :"
        defb 13
        defm "         |                                 | _;,,,;_   ____"
        defb 13
        defm "         |            Level :              |          /    "
        defb 92
        defb 13
        defm "         |                                 |          :    :"
        defb 13
        defm "         |                                 |          :    :"
        defb 13
        defm "         |        Died on Level :          |         _;,,,,;_"
        defb 13
        defm "         |            killed by            |"
        defb 13
        defm "         |                                 |"
        defb 13
        defm "         |                                 |"
        defb 13
        defm "        *|   *     *     *    *   *     *  | *"
        defb 13
        defm "________)/"
        defb 92
        defb 92
        defm "_)_/___("
        defb 92
        defm "/___(//_"
        defb 92
        defm ")/_"
        defb 92
        defm "//__"
        defb 92
        defb 92
        defm "(/_|_)_______"
        defb 13
        defb 0
    End Asm
dt_royal:
    Asm
        defb 13
        defm "                                     #"
        defb 13
        defm "                                   #####"
        defb 13
        defm "                                     #"
        defb 13
        defm "                               ,,,  $$$  ,,,"
        defb 13
        defm "                           ,,=$   "
        defb 34
        defm "$$$$$"
        defb 34
        defm "   $=,,"
        defb 13
        defm "                         ,$$        $$$        $$,"
        defb 13
        defm "                         *>         <*>         <*"
        defb 13
        defm "                         $$         $$$         $$"
        defb 13
        defm "                         "
        defb 34
        defm "$$        $$$        $$"
        defb 34
        defb 13
        defm "                          "
        defb 34
        defm "$$       $$$       $$"
        defb 34
        defb 13
        defm "                           *#########*#########*"
        defb 13
        defm "                           *#########*#########*"
        defb 13
        defb 13
        defb 13
        defm "                             Veni, Vidi, Vici!"
        defb 13
        defm "                        I came, I saw, I conquered!"
        defb 13
        defm "                         All Hail the Mighty"
        defb 13
        defb 0
    End Asm
    Return 0
End Function


Sub s_dt_show( pub_which As UByte )
    ' Moria's displayDeathFile(): the screen is cleared and a picture drawn on it
    Dim luw_at                          As UInteger
    Dim lub_row , lub_col , lub_char    As UByte

    s_core_clear_screen()
    luw_at  = fuw_dt_art( pub_which )
    lub_row = 0
    lub_col = 0
    While Peek( luw_at ) <> 0
        lub_char = Peek( luw_at )
        luw_at   = luw_at + 1
        If lub_char = 13 Then
            lub_row = lub_row + 1
            lub_col = 0
        Else
            If lub_col < 80 Then s_core_print_char_at( lub_row , lub_col , lub_char , UB_WHITE )
            lub_col = lub_col + 1
        End If
    End While
End Sub


Sub s_dt_centred( pub_row As UByte , ps_text As String )
    ' text on the stone, about its middle, as Moria places it
    s_core_print_string_at( pub_row , 26 - Len( ps_text ) / 2 , ps_text , UB_BRIGHT_WHITE )
End Sub


Sub s_dt_tomb()
    ' Moria's printTomb()
    Dim ls_text As String

    s_dt_show( 1 )
    s_dt_centred( 6 , fs_core_text_at( A_PLAYER_NAME ) )
    If gub_game_total_winner Then
        s_dt_centred( 8 , "Magnificent" )
        If gub_player_male Then
            s_dt_centred( 10 , "*King*" )
        Else
            s_dt_centred( 10 , "*Queen*" )
        End If
    Else
        ' what a character of this class and level is called, Moria's playerRankTitle()
        ' N.B: a winner's level is past the end of the table, but a winner is never asked
        s_string_fetch( UW_STR_RANK_TITLES + Cast( UInteger , gub_player_class ) * UB_PLAYER_MAX_LEVEL + guw_player_level - 1 , A_TEXT_BUFFER )
        s_dt_centred( 8 , fs_core_text_at( A_TEXT_BUFFER ) )
        s_dt_centred( 10 , fs_core_text_at( A_CLASS ) )
    End If
    s_core_print_string_at( 11 , 30 , fs_core_number( guw_player_level ) , UB_BRIGHT_WHITE )
    s_dt_centred( 12 , fs_core_number( gsl_player_exp ) + " Exp" )
    s_dt_centred( 13 , fs_core_number( gsl_player_gold ) + " Au" )
    s_core_print_string_at( 14 , 34 , fs_core_number( guw_dungeon_level ) , UB_BRIGHT_WHITE )
    ' some of Moria's causes of death come with their own full stop
    ls_text = fs_core_text_at( A_DIED_FROM )
    s_dt_centred( 16 , ls_text )
    ' the day, e.g. "Wed Oct 14", from the Next's clock, and nothing if it has none
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_DATE )
    If gsw_lib_result Then s_dt_centred( 17 , fs_core_text_at( A_TEXT_BUFFER ) )
End Sub


Sub s_stage_death()
    Dim ls_text     As String
    Dim i           As UByte
    Dim luw_record  As UInteger
    Dim lub_length  As UByte

    If gub_game_total_winner Then
        ' Moria's kingly(): change the player into a King! N.B: before the save below, as Moria's endGame() has it,
        ' so that the save holds the King, the crown is shown after it
        guw_dungeon_level = 0
        ' the same place the walking stage's causes of death are left in
        Poke A_DIED_FROM + 12 , 0
        Asm
            jr dt_age_end
        dt_age:
            defm "Ripe Old Age"
        dt_age_end:
            ld hl, dt_age
            ld de, A_DIED_FROM
            ld bc, 12
            ldir
        End Asm
        ' Moria's spellRestorePlayerLevels(), the effects library
        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_RESTORE_LEVELS )
        guw_player_level   = guw_player_level + UB_PLAYER_MAX_LEVEL
        gsl_player_gold    = gsl_player_gold + 250000
        gsl_player_max_exp = gsl_player_max_exp + 5000000
        gsl_player_exp     = gsl_player_max_exp
    End If

    ' if this game was ever saved the save is put beyond use, a dead character is not to be brought back, N.B: Moria's
    ' endGame() saves after the tombstone, ours before it
    s_core_call_library( UB_PAGED_CODE_LIB_SAVE , UB_LIB_SAVE_DEAD )

    If gub_game_total_winner Then
        ' Moria's printCrown(): let the player know they did good
        s_dt_show( 2 )
        If gub_player_male Then
            s_core_print_string_at( 17 , 45 , "King!" , UB_BRIGHT_YELLOW )
        Else
            s_core_print_string_at( 17 , 45 , "Queen!" , UB_BRIGHT_YELLOW )
        End If
        s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
        s_core_get_key()
    End If

    s_dt_tomb()

    ' Moria's "Character record?": the dead character's sheet, and what they were using and carrying, on the screen,
    ' or written to a file on the SD card, N.B: Moria asks for the file's name here, ours is always
    ' player-<name>.txt, after the character, so the question is a key, f, see s_in_file() in stage-lib-info.bas
    s_core_print_string_at( 23 , 0 , "(ESC to abort, return to print on screen, f to write it to a file)   " , UB_WHITE )
    s_core_print_string_at( 22 , 0 , "Character record?                                         " , UB_BRIGHT_WHITE )
    lub_length = 0
    Do
        s_core_get_key()
        If gub_key_char = Code( "f" ) Or gub_key_char = Code( "F" ) Then
            lub_length   = 1
            gub_key_char = 13
        End If
    Loop Until gub_key_char = 13 Or gub_key_char = 27 Or guw_key_code = 0
    If gub_key_char = 13 Then
        ' everything is identified now, the kind of thing it is and its own plusses and charges: Moria's
        ' itemSetAsIdentified() and spellItemIdentifyAndRemoveRandomInscription() for all 34 places
        For i = 0 To UB_INVENTORY_SIZE - 1
            luw_record = A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE
            If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
                s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
                s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY_WORKING )
                s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_KNOW_FULLY )
                s_core_ram_copy( A_ITEM , luw_record , UB_RECORD_SIZE )
            End If
        Next
        s_core_call_library( UB_PAGED_CODE_LIB_BONUSES , UB_LIB_BONUSES_RECALC )
        If lub_length > 0 Then
            ' N.B: Moria asks again if the file cannot be written, we say so and go on
            s_core_call_library( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_FILE )
            s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
            s_core_get_key()
        Else
            gub_lib_param_1 = true
            s_core_call_library( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_CHARACTER )
            If gub_key_char <> 27 Then
                ' "You are using:" and "You are carrying:", the equipment library has both lists, with the weights
                ' shown, as Moria shows them here whatever the option says
                s_core_clear_screen()
                guw_game_options = guw_game_options bOr MW_OPTION_SHOW_WEIGHTS
                gub_lib_param_1 = Code( "e" )
                s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_COMMAND )
                gub_lib_param_1 = Code( "i" )
                s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_COMMAND )
            End If
        End If
    End If
    ' the score goes into the table, and the table is shown, Moria's recordNewHighScore() and showScoresScreen()
    s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_RECORD )
    s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_SHOW )

    ' a player who quit goes back to NextZXOS, as Moria's leaves the program, anyone else begins again
    If Peek( A_DIED_FROM ) = Code( "Q" ) And Peek( A_DIED_FROM + 1 ) = Code( "u" ) And Peek( A_DIED_FROM + 2 ) = Code( "i" ) Then gub_core_end = true
End Sub
