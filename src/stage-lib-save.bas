#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_save()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: saving the game to the SD card and bringing it back, Moria's game_save.cpp
' in purpose, though not in form: Moria writes its data out field by field, here the game IS a set of 8KB pages,
' so those pages are what is saved, one after another in the one file zxmoria.sav, with the core's
' fub_core_file_save_page() and its gub_core_file_slot, which says which 8KB of the file a page is...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SAVE , <which routine> ), the routines are:
'
'   UB_LIB_SAVE_SAVE        saves the game, gsw_lib_result is 0 if it worked, otherwise the number of the page
'                           that could not be written
'   UB_LIB_SAVE_RESTORE     brings back a saved game, if there is one and its character is alive, gsw_lib_result
'                           is true if it did, the walking stage can then carry on where the player left off...
'                           ...or, in a game started as a wizard (Ctrl-W on the opening screen, Moria's -w), a dead
'                           character, if the player says so, gsw_lib_result is then 2, they arrive in the town afresh,
'                           or 3 if there is a file that will not do: Moria's "Error during reading of file.", the
'                           game then goes back to NextZXOS and the file is left as it is
'   UB_LIB_SAVE_DEAD        the character has died: the save is put beyond use, as Moria does, so that a dead
'                           character cannot be brought back by loading it again, and the monster memory is saved
'                           in it, for the characters to come, and so are the character and the stores, as in
'                           Moria, for a wizard to bring them back
'   UB_LIB_SAVE_MEMORY      a new character begins: the monster memory on the card, if there is one, is loaded
'
' as Moria has it, the one saved game, for whichever character was played last: saving replaces it, and a new
' character takes its place once the one before has died, N.B: so starting a new character while another is saved
' is not something the game offers, as in Moria, the saved one is always carried on with... a game of our own from
' 14 October 2026, a saved game for each character and a list of them to choose from, was taken out again the
' same day, to keep to Moria's one file
'
' the file is 34 pages of 8KB, 278,528 bytes, these pages in this order:
'   32          the core's data: the game's own variables, the player, the pack, the stores' owners
'   63          what the player knows: the monster memory, and which kinds of thing have been identified
'   33 34       the monsters of the dungeon level and of the town
'   36 to 41    the things lying on the dungeon level, in the town, and for sale in the stores
'   42          the last messages
'   66 to 82    the map of the dungeon level
'   83 to 88    the map of the town
' N.B: the first two come first because they are what a new character wants of a dead one's save, see s_sv_dead(),
' which writes the first ten, to the stores' stock, and a file's pages must first be written in order, see
' fub_core_file_transfer(), which writes a file of many pages from its first page to its last in one go
' the core's data is not put back whole: its first 512 bytes are the core's own workings and its last 1024 are the
' heap, both belong to the program that is running now, so that page is loaded into a spare page and only the
' game's part of it, from 512 to 6999, is copied across
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, a save is checked as Moria's loadGame() checks one, see fub_sv_sane()
' N.B: the walking stage saves the game of its own accord, with UB_LIB_SAVE_SAVE, when no key has been pressed for
' an hour, before it goes back to NextZXOS


Function fub_sv_page( pub_index As UByte ) As UByte
    ' the pages of a saved game, in the order they are written, 0 after the last
    Return Peek( @sv_pages + pub_index )
sv_pages:
    Asm
        defb 32, 63, 33, 34, 36, 37, 38, 39, 40, 41, 42
        defb 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82
        defb 83, 84, 85, 86, 87, 88
        defb 0
    End Asm
    Return 0
End Function


Function fub_sv_transfer( pub_slot As UByte , pub_page As UByte , pub_write As UByte ) As UByte
    ' one page of the saved game, to the file or from it, pub_slot is which of the file's pages it is, 0 if it worked
    Dim lub_result As UByte

    gub_core_file_slot = pub_slot
    If pub_write Then
        lub_result = fub_core_file_save_page( "zxmoria.sav" , pub_page )
    Else
        lub_result = fub_core_file_load_page( "zxmoria.sav" , pub_page )
    End If
    gub_core_file_slot = UB_FILE_SLOT_WHOLE
    Return lub_result
End Function


Sub s_sv_close()
    ' the saved game's file is finished with: the core keeps a file of many pages open from its first page until it
    ' is told this, see fub_core_file_transfer(), N.B: after a page that would not write as well
    gub_core_file_slot = UB_FILE_SLOT_DONE
    gub_shared_1 = fub_core_file_save_page( "zxmoria.sav" , UB_PAGE_TEST_FILE )
    gub_core_file_slot = UB_FILE_SLOT_WHOLE
End Sub


Sub s_sv_progress( pub_index As UByte )
    ' a dot for each page, the SD card takes a few seconds over this
    s_core_print_char_at( 0 , UB_SV_DOTS_COL + pub_index , Code( "." ) , UB_WHITE )
End Sub


Function fub_sv_ours() As UByte
    ' true if the page in the second data slot, the core's data from a saved game, has our marks on it and this version
    ' of the save, the rest is fub_sv_sane()'s
    Dim luw_marks As UInteger

    luw_marks = A_MMU_SLOT_PAGED_DB_MAPS + UW_SV_AT_MARKS
    If Peek( luw_marks ) <> Code( "Z" ) Or Peek( luw_marks + UB_SV_MARK_LETTER_2 ) <> Code( "M" ) Or Peek( luw_marks + UB_SV_MARK_VERSION ) <> UB_SAVE_VERSION Then Return false
    Return true
End Function


'##################################################################################################################################
' --- SAVING ---

Sub s_sv_died_from( ps_text As String )
    ' what the character died of, Moria's character_died_from, which a save and a load change
    Dim i As UByte

    For i = 0 To Len( ps_text ) - 1
        Poke A_DIED_FROM + i , Code( ps_text( i ) )
    Next
    Poke A_DIED_FROM + Len( ps_text ) , 0
End Sub


Function fub_sv_save() As UByte
    ' saves every page, 0 if it worked, otherwise the page that failed, and if it worked the character is put in the
    ' high scores as "(saved)", as Moria's commandSaveAndExit() and endGame() do
    Dim i , lub_page    As UByte
    Dim lsl_max_score   As Long

    s_core_print_string_at( 0 , 0 , "Saving game...                                                                  " , UB_WHITE )
    ' as Moria's saveChar(): resting and searching are turned off, and the weight of the pack is taken out of the
    ' speeds, everyone's, the game that comes back works it out again, see the walking stage
    s_dst_disturb( true , false )
    guw_lib_param_2 = Cast( UInteger , -gsw_player_pack_heaviness )
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
    gsw_player_pack_heaviness = 0
    ' ...and the save holds "(saved)" for what the character died of, and its score now as the least it may ever score,
    ' Moria writes playerCalculateTotalPoints() into the save as max_score, the scores library works it out
    s_sv_died_from( "(saved)" )
    lsl_max_score = gsl_player_max_score
    s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_POINTS )
    gsl_player_max_score = gsl_lib_long_1
    ' what marks the save as ours, and its character as alive
    gub_save_letter_1 = Code( "Z" )
    gub_save_letter_2 = Code( "M" )
    gub_save_version  = UB_SAVE_VERSION
    gub_save_alive    = true
    gub_save_used     = true
    i = 0
    lub_page = fub_sv_page( 0 )
    While lub_page <> 0
        s_sv_progress( i )
        If fub_sv_transfer( i , lub_page , true ) <> 0 Then
            s_sv_close()
            ' the game carries on, so the pack's weight is worked out again (Moria does not, its speed stays wrong), and
            ' the character is alive and well, as Moria puts it, with the score it had
            gul_player_status = gul_player_status bOr UL_PY_STR_WGT
            s_sv_died_from( "(alive and well)" )
            gsl_player_max_score = lsl_max_score
            Return lub_page
        End If
        i = i + 1
        lub_page = fub_sv_page( i )
    End While
    s_sv_close()
    ' the game is over for now: its score goes in the table, as "(saved)", Moria's endGame() after a save, a game in
    ' which wizard mode was used is not scored, the scores library sees to that
    s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_RECORD )
    Return 0
End Function


'##################################################################################################################################
' --- WHAT BRINGING A GAME BACK, AND BRINGING BACK THE DEAD, SHARE ---

Function fub_sv_byte( puw_address As UInteger ) As UByte
    ' one byte of the saved core's data, in the second data slot, by where it lives in the game's own
    Return Peek( A_MMU_SLOT_PAGED_DB_MAPS + ( puw_address - A_MMU_SLOT_CORE_DATA ) )
End Function


Function fub_sv_sane() As UByte
    ' the checks Moria's loadGame() makes of what it reads, on the saved core's data in the second data slot, false
    ' if any fails: no more in the pack than it can hold, nor in any store, the player and the level inside the map,
    ' and no more items or monsters on the level than a level can hold
    Dim i       As UByte
    Dim lsw_n   As Integer

    lsw_n = Peek( Integer , A_MMU_SLOT_PAGED_DB_MAPS + ( @gsw_player_pack_unique - A_MMU_SLOT_CORE_DATA ) )
    If lsw_n < 0 Or lsw_n > UB_PACK_SIZE Then Return false
    For i = 0 To UB_STORES - 1
        If fub_sv_byte( A_STORES + Cast( UInteger , i ) * UB_STORE_STATE_SIZE + UB_STORE_ITEM_COUNT ) > UB_STORE_MAX_ITEMS Then Return false
    Next
    If fub_sv_byte( @gub_dungeon_rows ) > UW_MAP_ROWS Or fub_sv_byte( @gub_dungeon_cols ) > UW_MAP_COLS Then Return false
    If fub_sv_byte( @gub_player_row ) >= fub_sv_byte( @gub_dungeon_rows ) Then Return false
    If fub_sv_byte( @gub_player_col ) >= fub_sv_byte( @gub_dungeon_cols ) Then Return false
    If fub_sv_byte( @gub_dungeon_item_next ) > UB_DUN_MAX_ITEMS Then Return false
    If fub_sv_byte( @gub_dungeon_monster_next ) > UB_MON_TOTAL_ALLOCATIONS Then Return false
    Return true
End Function


Function fub_sv_bad( pub_version As UByte ) As UByte
    ' Moria's "goto error" in loadGame(): it says so, and the game ends, N.B: so the file is not written over by a
    ' new character's game, the player may yet put it right, 3 is what UB_LIB_SAVE_RESTORE answers, pub_version is
    ' true when the save is ours but of another version: as sdo put it on 16 October 2026, the version must match or
    ' it is "a no go no show", we do not convert one save into another
    s_core_clear_screen()
    s_core_print_string_at( 0 , 0 , "Error during reading of file." , UB_WHITE )
    s_core_print_string_at( 1 , 0 , "Please try again without that save file." , UB_WHITE )
    ' N.B: Moria's words, but for its name, umoria
    If pub_version Then s_core_print_string_at( 2 , 0 , "Sorry. This save file is from a different version of ZXMoria." , UB_WHITE )
    s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
    s_core_get_key()
    Return UB_RESTORE_BAD_FILE
End Function

Sub s_sv_core_data()
    ' the game's part of the core's data, from the spare page it was loaded into, and nothing left half done
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_TEST_FILE )
    s_core_ram_copy( A_MMU_SLOT_PAGED_DB_MAPS + UW_SV_GAME_FROM , A_MMU_SLOT_CORE_DATA + UW_SV_GAME_FROM , UW_SV_GAME_SIZE )
    gub_save_used = true
    ' wizard mode is never brought back switched on, as in Moria, that it was ever used is (gub_game_noscore)
    gub_game_wizard = false
    ' nothing is half done: no message waiting, no run, no count, nobody's turn
    gub_message_length     = 0
    gub_game_running       = 0
    guw_game_command_count = 0
    gub_game_repeat_key    = 0
    gub_game_monster_turn  = 0
    gub_game_disturb       = 0
    gub_game_rest_broken   = false
    gub_game_turn_flags    = 0
End Sub


Function fub_sv_confirm( ps_prompt As String ) As UByte
    ' Moria's getInputConfirmation(): true only for y
    s_core_clear_screen()
    s_core_print_string_at( 0 , 0 , ps_prompt + " [y/n]" , UB_WHITE )
    Do
        s_core_get_key()
    Loop While gub_key_char = UC_SPACE
    If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then Return true
    Return false
End Function


'##################################################################################################################################
' --- BRINGING BACK THE DEAD ---

Function fub_sv_resurrect() As UByte
    ' Moria's loadGame() for a dead character in a game started as a wizard: the character, their pack, what they
    ' knew and the stores come back, the level does not, they arrive in the town, made afresh, and the game can
    ' never be scored, 2 if it worked, 3 if the file would not read, see fub_sv_bad()
    Dim i , lub_stock   As UByte

    s_core_print_string_at( 0 , 0 , "Attempting a resurrection!                                                      " , UB_WHITE )
    ' what the player knew, N.B: the core's data is in the spare page already
    If fub_sv_transfer( 1 , UB_PAGE_KNOWLEDGE , false ) <> 0 Then Return fub_sv_bad( false )
    ' the stores' stock, N.B: a character who died before 16 October 2026 left a save of two pages, without it, and
    ' their stores are emptied, the owners keep them and stock comes in with the turns, NOT Moria's, ours
    lub_stock = true
    For i = 0 To UB_SV_STOCK_PAGES - 1
        If fub_sv_transfer( UB_SV_DEAD_PAGES - UB_SV_STOCK_PAGES + i , UB_PAGE_STORE_ITEMS + i , false ) <> 0 Then lub_stock = false
    Next
    s_sv_core_data()
    If lub_stock = false Then
        For i = 0 To UB_STORES - 1
            Poke A_STORES + Cast( UInteger , i ) * UB_STORE_STATE_SIZE + UB_STORE_ITEM_COUNT , 0
        Next
        For i = 0 To 1
            s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS + i )
            Asm
                ld hl, A_MMU_SLOT_PAGED_ITEMS
                ld de, A_MMU_SLOT_PAGED_ITEMS + 1
                ld bc, 8191
                ld (hl), 0
                ldir
            End Asm
        Next
    End If

    ' Moria's resurrection: "don't let them starve to death immediately", "don't let them immediately die of poison
    ' again", back to the town, and the game is marked as never to be scored again
    If gsw_player_current_hp < 0 Then
        gsw_player_current_hp  = 0
        guw_player_hp_fraction = 0
    End If
    If gsw_player_food < 0 Then gsw_player_food = 0
    If gsw_player_poisoned > 1 Then gsw_player_poisoned = 1
    guw_dungeon_level       = 0
    gub_game_noscore        = gub_game_noscore bOr 1
    gub_game_character_dead = false
    ' what Moria's saveChar() did as the character died, which s_sv_dead() does not: resting and searching are turned
    ' off, and the pack's weight is taken out of the speed, the walking stage works it out again as they arrive, as it
    ' does for any saved game, N.B: there is no level now, so no monsters whose speeds change with the player's
    gub_dungeon_monster_next = UB_MON_MIN_INDEX
    s_dst_disturb( true , false )
    guw_lib_param_2 = Cast( UInteger , -gsw_player_pack_heaviness )
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
    gsw_player_pack_heaviness = 0
    ' ...and nothing half done, again: the disturbance asked for things to be done on the next turn
    gub_game_disturb    = 0
    gub_game_turn_flags = 0
    Return UB_RESTORE_RESURRECTED
End Function


'##################################################################################################################################
' --- BRINGING A GAME BACK ---

Function fub_sv_restore() As UByte
    ' brings a saved game back, true if there was one to bring and its character is alive
    Dim i , lub_page , lub_error As UByte

    ' the core's data first, into a spare page, to see whether there is a save at all, and whose it is
    lub_error = fub_sv_transfer( 0 , UB_PAGE_TEST_FILE , false )
    ' no save on the card: a new character, as in Moria
    If lub_error = UB_ESX_ENOENT Then Return false
    ' ...a file there that will not read, or is not ours, or not of this version, will not do
    If lub_error <> 0 Then Return fub_sv_bad( false )
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_TEST_FILE )
    If Peek( A_MMU_SLOT_PAGED_DB_MAPS + UW_SV_AT_MARKS ) <> Code( "Z" ) Or Peek( A_MMU_SLOT_PAGED_DB_MAPS + UW_SV_AT_MARKS + UB_SV_MARK_LETTER_2 ) <> Code( "M" ) Then Return fub_sv_bad( false )
    If fub_sv_ours() = false Then Return fub_sv_bad( true )
    ' ...and it is checked as Moria checks one, a dead character's too
    If fub_sv_sane() = false Then Return fub_sv_bad( false )
    ' a dead character stays dead, as in Moria, which then starts a new character with the monster memory alone...
    ' ...unless the game was started as a wizard, then they may be brought back, Moria's loadGame() with -w
    If Peek( A_MMU_SLOT_PAGED_DB_MAPS + UW_SV_AT_MARKS + UB_SV_MARK_ALIVE ) = 0 Then
        If gub_core_to_be_wizard = false Then Return false
        ' ...but not one who has won and retired, Moria: "It causes problems because the character level is out of
        ' the allowed range"
        If Peek( A_MMU_SLOT_PAGED_DB_MAPS + ( @gub_game_total_winner - A_MMU_SLOT_CORE_DATA ) ) Then
            s_core_clear_screen()
            s_core_print_string_at( 10 , 4 , "Sorry, this character is retired from moria." , UB_BRIGHT_YELLOW )
            s_core_print_string_at( 11 , 4 , "You can not resurrect a retired character." , UB_BRIGHT_YELLOW )
            s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
            s_core_get_key()
            Return false
        End If
        If fub_sv_confirm( "Resurrect a dead character?" ) = false Then Return false
        Return fub_sv_resurrect()
    End If
    ' ...and so does one whose save was kept from before it died, put back on the card afterwards, the high scores
    ' know it by when it was made, NOT Moria's, ours, Moria's own check is the one above alone, N.B: a save from before
    ' 14 October 2026 has no birth, 0, and is not looked for, N.B: and nor is a character brought back from the dead,
    ' whose death is in the high scores, and who is alive again and can never be scored anyway
    gsw_lib_result = false
    If ( Peek( A_MMU_SLOT_PAGED_DB_MAPS + ( @gub_game_noscore - A_MMU_SLOT_CORE_DATA ) ) bAnd 1 ) = 0 Then
        gsl_lib_long_1 = Peek( ULong , A_MMU_SLOT_PAGED_DB_MAPS + ( @gsl_player_birth - A_MMU_SLOT_CORE_DATA ) )
        s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_DEAD )
    End If
    If gsw_lib_result Then
        s_core_clear_screen()
        s_core_print_string_at( 10 , 4 , "The character in the saved game has died, it cannot be carried on with." , UB_BRIGHT_YELLOW )
        s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
        s_core_get_key()
        Return false
    End If

    s_core_clear_screen()
    s_core_print_string_at( 0 , 0 , "Restoring game...                                                               " , UB_WHITE )
    ' every other page goes straight back where it came from
    i = 1
    lub_page = fub_sv_page( 1 )
    While lub_page <> 0
        s_sv_progress( i )
        If fub_sv_transfer( i , lub_page , false ) <> 0 Then Return fub_sv_bad( false )
        i = i + 1
        lub_page = fub_sv_page( i )
    End While

    ' and now the game's part of the core's data, N.B: nothing after this may fail, the game is the saved one from here on
    s_sv_core_data()
    ' a character that comes back alive is "(alive and well)", as in Moria's loadGame(), the save said "(saved)"
    s_sv_died_from( "(alive and well)" )
    Return true
End Function


'##################################################################################################################################
' --- A DEATH, AND THE NEXT CHARACTER ---

Sub s_sv_dead()
    ' the character has died: the core's data is saved, saying so, so that if there was a save it cannot be
    ' loaded again, and so is what the player knows, because the monster memory outlives the character, as in
    ' Moria, which "saves the memory at least", N.B: the marks are set here too, the game may never have been saved
    Dim i As UByte

    gub_save_letter_1 = Code( "Z" )
    gub_save_letter_2 = Code( "M" )
    gub_save_version  = UB_SAVE_VERSION
    gub_save_alive    = false
    ' N.B: the first two pages of the file, see the list at the top of this page, and then up to the stores' stock:
    ' the character and the stores, which a wizard may bring back, as Moria's save of a dead character keeps everything
    ' but the level, N.B: the pages in between are written too, they cannot be skipped, and are not wanted... the file
    ' is made afresh by its first page, so these are all that is left of the save, a new character's game is made
    ' from scratch
    For i = 0 To UB_SV_DEAD_PAGES - 1
        If fub_sv_transfer( i , fub_sv_page( i ) , true ) <> 0 Then Exit For
    Next
    s_sv_close()
End Sub


Sub s_sv_memory()
    ' a new character begins: what earlier characters learnt about the creatures of the dungeon is brought back
    ' from the card, if anything was ever saved there, N.B: the page also holds what kinds of thing had been
    ' identified, which a new game works out afresh straight afterwards
    ' the core's data is looked at first, in a spare page, to see that the file on the card is ours
    If fub_sv_transfer( 0 , UB_PAGE_TEST_FILE , false ) <> 0 Then Return
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_TEST_FILE )
    If fub_sv_ours() = false Then Return
    ' N.B: into the spare page first, so that a file that will not read leaves what is in memory alone
    If fub_sv_transfer( 1 , UB_PAGE_TEST_FILE , false ) <> 0 Then Return
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_TEST_FILE )
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_KNOWLEDGE )
    s_core_ram_copy( A_MMU_SLOT_PAGED_DB_MAPS , A_MMU_SLOT_1 , UW_MONSTER_MEMORY_SIZE )
End Sub


Sub s_lib_save()
    Dim lub_saved_page_2    As UByte
    Dim lub_saved_page_1    As UByte
    Dim lub_answer          As UByte = 0

    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_SAVE_SAVE Then
        lub_answer = fub_sv_save()
    ElseIf gub_lib_function = UB_LIB_SAVE_RESTORE Then
        lub_answer = fub_sv_restore()
    ElseIf gub_lib_function = UB_LIB_SAVE_DEAD Then
        s_sv_dead()
    ElseIf gub_lib_function = UB_LIB_SAVE_MEMORY Then
        s_sv_memory()
    End If
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_answer
End Sub
