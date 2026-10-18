#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_wizard()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-level-include.bas"

' this page is a LIBRARY, not a stage: wizard mode, Moria's wizard.cpp, with commandFlipWizardMode() and
' doWizardCommands() from game_run.cpp, it is "for debugging and experimenting", and a game it has been used in is
' never scored...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , <which routine> ),
' the routines are:
'
'   UB_LIB_WIZARD_KEY       carries out the command for the key in gub_lib_param_1, which is any key that is not a
'                           command of the commands library's own, the answer in gsw_lib_result is the
'                           MB_COMMAND_ bits, as the commands library's own answer is
'   UB_LIB_WIZARD_STATUS    puts "Is wizard" or "Was wizard" on the screen, the part of Moria's
'                           printCharacterWinner() that is about wizards, for the walking stage
'   UB_LIB_WIZARD_RESTORED  says that a saved game which has just come back cannot be scored, for the walking
'                           stage, which has no room for the words
'   UB_LIB_WIZARD_ENTER     Moria's enterWizardMode(), for a game started as a wizard, Ctrl-W on the opening screen
'                           (Moria's -w): wizard mode is turned on, after the disclaimer if the game could still be
'                           scored, gsw_lib_result is false if the player said no, and the game then ends, as Moria's does
'
' the commands, all of them take no time:
'   Ctrl-W      wizard mode on and off, the first time it is turned on the player is asked whether they are sure
'   and these only while it is on:
'   Ctrl-A      cure all maladies and remove curses, wizardCureAll()
'   Ctrl-B      a sample of random objects written to a file, outputRandomLevelObjectsToFile(), stage-lib-wizard-3.bas
'   Ctrl-D      jump to a level, the count before the command or the number asked for, wizardJumpLevel()
'   Ctrl-E      edit the character, wizardCharacterAdjustment(), stage-lib-wizard-2.bas
'   Ctrl-F      vanquish the monsters within sight, spellMassGenocide()
'   Ctrl-G      random items near the player, as many as the count before the command, wizardDropRandomItems()
'   Ctrl-H      the list of these commands, Moria's help_wizard.txt (the text library)
'   Ctrl-I      identify an item, spellIdentifyItem()
'   Ctrl-L      light the whole level, or put it out again, wizardLightUpDungeon()
'   Ctrl-T      teleport, playerTeleport( 100 )
'   Ctrl-U      summon a monster, wizardSummonMonster()
'   :           map the area, spellMapCurrentArea()
'   + ENTER     gain experience: the count before the command, or twice what there was, wizardGainExperience()
'   %           one object of a chosen kind near the player, wizardGenerateObject()
'   @           an object made up field by field, wizardCreateObjects(), stage-lib-wizard-2.bas
'   $           NOT Moria's, ours, for testing: the character is made superhuman, stage-lib-wizard-3.bas
'
' N.B: three things are not as Moria 5.7.15 has them, each for the reason given:
'   - % does nothing in Moria unless the roguelike keys are on, it was left out of the table of the original
'     keys, although Moria's own help lists it, here it works as the help says
'   - Moria identifies the object % makes with itemIdentify(), handing it the object's number on the level where
'     a place in the pack is expected, which can put two things in the pack together that have nothing to do with
'     it, here the kind of thing is made known and nothing else is touched
'   - a message that is showing when a question is asked is waited for, with -more-, Moria writes the question
'     straight over it, so its warning before @ is never seen
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- working storage, see also stage-wizard-include.bas ---
#define A_WZ_ROWS           A_MMU_SLOT_PAGED_CORRIDORS              ' three rows of the map, 256 bytes each, while the level is lit


Function fub_wz_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


#include "stage-wizard-include.bas"


'##################################################################################################################################
' --- the commands ---

Sub s_wz_status()
    ' Moria's printCharacterWinner(), the part of it that is about wizards
    If ( gub_game_noscore bAnd 2 ) = 0 Then Return
    If gub_game_wizard Then
        s_core_print_string_at( 22 , 0 , "Is wizard  " , UB_BRIGHT_YELLOW )
    Else
        s_core_print_string_at( 22 , 0 , "Was wizard " , UB_BRIGHT_YELLOW )
    End If
End Sub


Function fub_wz_enter() As UByte
    ' Moria's enterWizardMode(): lets anyone enter wizard mode after a disclaimer, true if they did
    Dim lub_answer As UByte = false

    If gub_game_noscore = 0 Then
        s_core_message( UW_MSG_WIZARD_MODE_IS_FOR_DEBUGGING_AND )
        lub_answer = fub_wz_confirm( "The game will not be scored if you enter wizard mode. Are you sure?" )
    End If
    If gub_game_noscore <> 0 Or lub_answer Then
        gub_game_noscore = gub_game_noscore bOr 2
        gub_game_wizard  = true
        Return true
    End If
    Return false
End Function


Sub s_wz_flip()
    ' Moria's commandFlipWizardMode()
    If gub_game_wizard Then
        gub_game_wizard = false
        s_core_message( UW_MSG_WIZARD_MODE_OFF )
    ElseIf fub_wz_enter() Then
        s_core_message( UW_MSG_WIZARD_MODE_ON )
    End If
    s_wz_status()
    ' N.B: the wizard sees every monster, and stops seeing them, from the next turn's look at them: Moria's
    ' commandFlipWizardMode() does not update the monsters itself, and ours did until 17 October 2026, a monster
    ' became seen a turn before Umoria's did, found by comparing Ctrl-W in the town
End Sub


Sub s_wz_cure( puw_counter As UInteger )
    ' Moria's playerCureBlindness() and its fellows: whatever it is has one more turn to run
    If Peek( Integer , puw_counter ) > 1 Then Poke UInteger puw_counter , 1
End Sub


Sub s_wz_cure_all()
    ' Moria's wizardCureAll()
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_REMOVE_CURSE , 0 , 0 )
    s_wz_cure( @gsw_player_blind )
    s_wz_cure( @gsw_player_confused )
    s_wz_cure( @gsw_player_poisoned )
    s_wz_cure( @gsw_player_afraid )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_STR , 0 )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_INT , 0 )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_WIS , 0 )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_CON , 0 )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_DEX , 0 )
    gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , UB_STAT_CHR , 0 )
    s_wz_cure( @gsw_player_slow )
    s_wz_cure( @gsw_player_image )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Sub s_wz_random_items()
    ' Moria's wizardDropRandomItems() and dungeonPlaceRandomObjectNear(): things appear near the player, three
    ' times in four an object and otherwise gold
    ' N.B: as in Moria the search for somewhere to put one does not end when one has been put down, it is set
    ' back so that it goes round once more, and so on until a square that will not do is picked, so one "try"
    ' usually leaves several things
    Dim i               As UByte
    Dim luw_tries       As UInteger
    Dim lsw_y , lsw_x   As Integer
    Dim luw_square      As UInteger

    luw_tries = 1
    If guw_game_command_count > 0 Then luw_tries = guw_game_command_count
    guw_game_command_count = 0
    Do
        i = 0
        While i <= 10
            lsw_y = Cast( Integer , gub_player_row ) - 3 + Cast( Integer , fuw_gen_random( 5 ) )
            lsw_x = Cast( Integer , gub_player_col ) - 4 + Cast( Integer , fuw_gen_random( 7 ) )
            If fub_gen_in_bounds( lsw_y , lsw_x ) Then
                luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
                If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then
                    If Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then
                        If fuw_gen_random( 100 ) < 75 Then
                            gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_OBJECT , Cast( UByte , lsw_y ) , Cast( UInteger , lsw_x ) )
                        Else
                            gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_PLACE_GOLD , Cast( UByte , lsw_y ) , Cast( UInteger , lsw_x ) )
                        End If
                        ' N.B: a level whose list of items is full takes no more, and the search must not go on for ever
                        If Peek( fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x ) + UB_SQUARE_ITEM ) = 0 Then
                            i = 10
                        Else
                            i = 9
                        End If
                    End If
                End If
            End If
            i = i + 1
        End While
        luw_tries = luw_tries - 1
    Loop Until luw_tries = 0
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
End Sub


Sub s_wz_jump_level()
    ' Moria's wizardJumpLevel(): go up or down to a given depth, the count before the command or a number asked for
    Dim lsl_level As Long = -1

    If guw_game_command_count > 0 Then
        lsl_level = guw_game_command_count
        If lsl_level > 99 Then lsl_level = 0
        guw_game_command_count = 0
    Else
        If fub_wz_ask( "Go to which level (0-99) ? " , 10 ) Then
            If gub_wz_valid Then lsl_level = gsl_wz_number
        End If
    End If
    If lsl_level >= 0 Then
        If lsl_level > 99 Then lsl_level = 99
        guw_dungeon_level   = lsl_level
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_NEW_LEVEL
    Else
        s_msg_clear()
    End If
End Sub


Sub s_wz_gain_experience()
    ' Moria's wizardGainExperience()
    If guw_game_command_count > 0 Then
        gsl_player_exp = guw_game_command_count
        guw_game_command_count = 0
    ElseIf gsl_player_exp = 0 Then
        gsl_player_exp = 1
    Else
        gsl_player_exp = gsl_player_exp * 2
    End If
    s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Sub s_wz_light()
    ' Moria's wizardLightUpDungeon(): every open square of the level, and the eight squares round each, is lit
    ' for good, or, if the player's own square was lit already, the light is put out and what had been found
    ' there forgotten
    ' N.B: Moria goes over the level once, changing the squares round every open square as it comes to it, here
    ' the level is gone over a row at a time, because only one page of the map can be in memory at once: which
    ' squares of a row have an open square beside them in that row is noted, for the row above, the row itself
    ' and the row below, in the scratchpad page, and a square is changed if any of the three notes say so, the
    ' result is the same
    Dim lub_on , lub_flags , lub_near       As UByte
    Dim lsw_y , lsw_row                     As Integer
    Dim lub_x , lub_cols                    As UByte
    Dim luw_square , luw_note               As UInteger
    Dim luw_above , luw_here , luw_below    As UInteger
    Dim lub_saved_page                      As UByte

    lub_on = true
    If ( Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS ) bAnd MB_SQUARE_PERM_LIGHT ) <> 0 Then lub_on = false

    lub_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    lub_cols = gub_dungeon_cols
    ' nothing is known yet of any of the three rows, N.B: a note has a column either side of the level's own
    For luw_note = 0 To 767
        Poke A_WZ_ROWS + luw_note , 0
    Next

    ' lsw_row is the row whose squares are noted this time round, lsw_y, the one before it, the row that is changed
    For lsw_row = 0 To gub_dungeon_rows
        lsw_y     = lsw_row - 1
        luw_below = A_WZ_ROWS + ( Cast( UInteger , lsw_row ) Mod 3 ) * 256
        luw_here  = A_WZ_ROWS + ( Cast( UInteger , lsw_row + 2 ) Mod 3 ) * 256
        luw_above = A_WZ_ROWS + ( Cast( UInteger , lsw_row + 1 ) Mod 3 ) * 256
        For luw_note = 0 To 255
            Poke luw_below + luw_note , 0
        Next
        If lsw_row < gub_dungeon_rows Then
            luw_square = fuw_core_map_square( gub_level_map_page , lsw_row , 0 )
            For lub_x = 0 To lub_cols - 1
                If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then
                    ' N.B: the note for column x is at x + 1, so the square to the left of column 0 has somewhere to go
                    Poke luw_below + lub_x , 1
                    Poke luw_below + lub_x + 1 , 1
                    Poke luw_below + lub_x + 2 , 1
                End If
                luw_square = luw_square + 8
            Next
        End If
        If lsw_y >= 0 Then
            luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , 0 )
            For lub_x = 0 To lub_cols - 1
                lub_near = Peek( luw_above + lub_x + 1 ) bOr Peek( luw_here + lub_x + 1 ) bOr Peek( luw_below + lub_x + 1 )
                If lub_near <> 0 Then
                    lub_flags = Peek( luw_square + UB_SQUARE_FLAGS )
                    If lub_on Then
                        lub_flags = lub_flags bOr MB_SQUARE_PERM_LIGHT
                    Else
                        lub_flags = lub_flags bAnd ( 255 - ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK ) )
                    End If
                    Poke luw_square + UB_SQUARE_FLAGS , lub_flags
                End If
                luw_square = luw_square + 8
            Next
        End If
    Next
    If lub_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , lub_saved_page )
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
End Sub


Sub s_wz_generate_object()
    ' Moria's wizardGenerateObject() and wizardRequestObjectId(): one object of a kind chosen by its number in
    ' the list of objects, with whatever magic the depth gives it, somewhere near the player, ten tries are made
    ' to find it a square
    Dim luw_object      As UInteger
    Dim i , lub_number  As UByte
    Dim lsw_y , lsw_x   As Integer
    Dim luw_square      As UInteger

    If fub_wz_ask( "Dungeon/Store object ID (0-366): " , 3 ) = false Then Return
    If gub_wz_valid = false Then Return
    If gsl_wz_number < 0 Or gsl_wz_number > 366 Then
        s_core_print_string_at( 0 , 0 , "Invalid ID. Must be 0-366" , UB_WHITE )
        gub_message_length = 25
        Return
    End If
    luw_object = gsl_wz_number

    i = 0
    While i < 10
        lsw_y = Cast( Integer , gub_player_row ) - 3 + Cast( Integer , fuw_gen_random( 5 ) )
        lsw_x = Cast( Integer , gub_player_col ) - 4 + Cast( Integer , fuw_gen_random( 7 ) )
        If fub_gen_in_bounds( lsw_y , lsw_x ) Then
            luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
            If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then
                If Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then
                    ' place the object
                    lub_number = fub_gen_new_item( luw_object )
                    If lub_number <> 0 Then
                        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_TREASURE , UB_LIB_TREASURE_MAGIC , 0 , guw_dungeon_level )
                        ' auto identify the item, see the note at the top of this page
                        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY_WORKING )
                        s_gen_put_item( lsw_y , lsw_x , lub_number )
                    End If
                    i = 9
                End If
            End If
        End If
        i = i + 1
    End While
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
End Sub


'##################################################################################################################################

Function fub_wz_key( pub_key As UByte ) As UByte
    ' Moria's doWizardCommands(), and the end of its doCommand(): any key the commands library does not know
    Dim lub_ctrl As UByte = false

    If ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then lub_ctrl = true
    ' N.B: a command that is being repeated with a count comes round again as its code alone, the keys are no longer
    ' down, and a control code other than DELETE (8) and ENTER (13) can only ever have been typed with Ctrl
    If pub_key < 27 And pub_key <> 8 And pub_key <> 13 Then lub_ctrl = true
    ' wizard commands are free moves
    gub_game_free_turn = true

    If lub_ctrl And pub_key = 23 Then
        s_wz_flip()
        Return MB_COMMAND_DONE
    End If
    If gub_game_wizard = false Then
        s_core_message( UW_MSG_TYPE_FOR_HELP )
        Return MB_COMMAND_DONE bOr MB_COMMAND_UNKNOWN
    End If

    ' N.B: as in Moria, ENTER is the same command as +
    If pub_key = 13 Then pub_key = Code( "+" )

    If lub_ctrl And pub_key = 1 Then
        s_wz_cure_all()
    ElseIf lub_ctrl And pub_key = 5 Then
        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_2 , UB_LIB_WIZARD_2_CHARACTER )
        s_msg_clear()
    ElseIf lub_ctrl And pub_key = 6 Then
        ' mass genocide, vanquish all monsters
        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_MASS_GENOCIDE , 0 , 0 )
    ElseIf lub_ctrl And pub_key = 7 Then
        s_wz_random_items()
    ElseIf lub_ctrl And pub_key = 4 Then
        s_wz_jump_level()
    ElseIf lub_ctrl And ( pub_key = 2 Or pub_key = 15 ) Then
        ' Ctrl-B, or Ctrl-O with the rogue like commands: a sample of random objects written to a file
        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_3 , UB_LIB_WIZARD_3_SAMPLE )
    ElseIf lub_ctrl And pub_key = 8 Then
        ' the wizard's help
        If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) <> 0 Then
            gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW , 7 , 0 )
        Else
            gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW , 4 , 0 )
        End If
    ElseIf lub_ctrl And pub_key = 9 Then
        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_IDENTIFY , 0 , 0 )
        s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
    ElseIf lub_ctrl And pub_key = 12 Then
        s_wz_light()
    ElseIf pub_key = Code( ":" ) Then
        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_MAP_AREA , 0 , 0 )
    ElseIf lub_ctrl And pub_key = 20 Then
        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT , 0 , 100 )
    ElseIf pub_key = Code( "%" ) Then
        s_wz_generate_object()
    ElseIf pub_key = Code( "+" ) Then
        s_wz_gain_experience()
    ElseIf lub_ctrl And pub_key = 21 Then
        ' Moria's wizardSummonMonster(): beside the player, and asleep
        gub_shared_1 = fub_wz_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON_AT , gub_player_row , gub_player_col )
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
    ElseIf pub_key = Code( "$" ) Then
        ' NOT Moria's: the character is made superhuman, for testing, see stage-lib-wizard-3.bas
        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_3 , UB_LIB_WIZARD_3_SUPER )
    ElseIf pub_key = Code( "@" ) Then
        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_2 , UB_LIB_WIZARD_2_OBJECT )
    Else
        s_core_message( UW_MSG_TYPE_OR_H_FOR_HELP )
        Return MB_COMMAND_DONE bOr MB_COMMAND_UNKNOWN
    End If
    Return MB_COMMAND_DONE
End Function


Sub s_lib_wizard()
    Dim lub_saved_page_2    As UByte
    Dim lub_answer          As UByte

    ' ours: the wizard may light the level, or change it, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    If gub_lib_function = UB_LIB_WIZARD_STATUS Then
        s_wz_status()
        Return
    ElseIf gub_lib_function = UB_LIB_WIZARD_RESTORED Then
        s_core_message( UW_MSG_THIS_SAVE_FILE_CANNOT_BE_USED_TO )
        Return
    ElseIf gub_lib_function = UB_LIB_WIZARD_ENTER Then
        gsw_lib_result = fub_wz_enter()
        Return
    End If
    lub_saved_page_2 = gub_core_MMU2_page_number
    lub_answer = fub_wz_key( gub_lib_param_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_answer
End Sub
