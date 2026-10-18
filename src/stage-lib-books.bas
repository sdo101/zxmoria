#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_books()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-magic-include.bas"

' this page is a LIBRARY, not a stage: the books of spells and prayers, studying them, looking through them, and
' picking a spell from one, from Moria's player.cpp, spells.cpp and ui.cpp, the casting itself is another page,
' stage-lib-cast.bas, and how many spells the player may know a third, stage-lib-magic.bas...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_BOOKS , <which routine> ), the routines are:
'
'   UB_LIB_BOOKS_GAIN       the player studies: a mage picks new spells from the books in the pack, a priest is
'                           granted prayers at random, Moria's playerGainSpells()
'   UB_LIB_BOOKS_CHOOSE     the player picks a spell from the book in place gub_lib_param_1 of the pack, the
'                           question to ask is text in A_PROMPT, Moria's castSpellGetId(): gsw_lib_result is the
'                           spell's number, 0 to 30, or -1 if they know none in that book, or -2 if they backed
'                           out, the chance of the spell failing, a percentage, is left in gsl_lib_long_1
'   UB_LIB_BOOKS_BROWSE     the player looks through a book, Moria's examineBook()
'
' the spells are numbered 0 to 30, the same numbers for a mage's spells and a priest's prayers, which spells a book
' holds is in its flags, one bit a spell, and what the player knows, has forgotten, and has cast successfully are
' three more sets of 31 bits in the player's record
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it

'##################################################################################################################################
' --- studying ---

Sub s_mg_gain_spells()
    ' Moria's playerGainSpells()
    Dim lsw_new , lsw_missing , lsw_count , lsw_i   As Integer
    Dim lsw_last , lsw_pick                         As Integer
    Dim lul_flags , lul_mask                        As ULong
    Dim lub_flags , lub_spell                       As UByte

    If gsw_player_confused > 0 Then
        s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED )
        Return
    End If
    If gub_class_spell_type = 1 Then
        ' a mage must read, Moria's playerCanRead()
        If gsw_player_blind > 0 Then
            s_core_message( UW_MSG_YOU_CANT_SEE_TO_READ_YOUR_SPELL )
            Return
        End If
        lub_flags = Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
        If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then
            s_core_message( UW_MSG_YOU_HAVE_NO_LIGHT_TO_READ_BY )
            Return
        End If
    End If

    lsw_new     = gub_player_new_spells
    lsw_missing = 0
    ' Moria's lastKnownSpell(): where the next spell learnt goes in the order
    lsw_last = 0
    lsw_i = 0
    While lsw_i < 32
        If Peek( A_PLAYER_SPELL_ORDER + lsw_i ) = 99 Then
            lsw_last = lsw_i
            lsw_i = 32
        End If
        lsw_i = lsw_i + 1
    End While

    If lsw_new = 0 Then
        s_msg( "You can't learn any new " + fs_mg_kind() + "s!" )
        gub_game_free_turn = true
        Return
    End If

    ' determine which spells the player can learn: mages need the book to learn a spell, priests do not need the book
    lul_flags = $7FFFFFFF
    If gub_class_spell_type = 1 Then
        lul_flags = 0
        If gsw_player_pack_unique > 0 Then
            For lsw_i = 0 To gsw_player_pack_unique - 1
                If Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_MAGIC_BOOK Then
                    lul_flags = lul_flags bOr Peek( ULong , A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_FLAGS_OFFSET )
                End If
            Next
        End If
    End If
    ' clear bits for spells already learnt
    lul_flags = lul_flags bAnd ( $FFFFFFFF - gul_player_spells_learnt )

    lsw_count = 0
    lul_mask  = 1
    lsw_i     = 0
    While lul_flags <> 0
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
            If Peek( fuw_mg_spell( lsw_i ) ) <= guw_player_level Then
                Poke A_MG_LIST + lsw_count , lsw_i
                lsw_count = lsw_count + 1
            End If
        End If
        lul_mask = lul_mask << 1
        lsw_i = lsw_i + 1
    End While

    If lsw_new > lsw_count Then
        s_core_message( UW_MSG_YOU_SEEM_TO_BE_MISSING_A_BOOK )
        lsw_missing = lsw_new - lsw_count
        lsw_new     = lsw_count
    End If

    If lsw_new <> 0 Then
        If gub_class_spell_type = 1 Then
            ' the mage picks from the list
            s_msg_flush()
            s_mg_screen_save()
            s_mg_show_list( lsw_count , false , -1 )
            While lsw_new <> 0
                s_msg_clear()
                s_core_print_string_at( 0 , 0 , "Learn which spell?" , UB_BRIGHT_WHITE )
                s_core_get_key()
                If gub_key_char = 27 Or guw_key_code = 0 Then
                    lsw_i = lsw_new
                    lsw_missing = lsw_missing + lsw_new
                    lsw_new = 0
                Else
                    lsw_pick = Cast( Integer , gub_key_char ) - Code( "a" )
                    If lsw_pick >= 0 And lsw_pick < lsw_count And lsw_pick < 22 Then
                        lsw_new   = lsw_new - 1
                        lub_spell = Peek( A_MG_LIST + lsw_pick )
                        gul_player_spells_learnt = gul_player_spells_learnt bOr ful_mg_mask( lub_spell )
                        Poke A_PLAYER_SPELL_ORDER + lsw_last , lub_spell
                        lsw_last = lsw_last + 1
                        ' the spell comes out of the list, the ones after it move up
                        While lsw_pick < lsw_count - 1
                            Poke A_MG_LIST + lsw_pick , Peek( A_MG_LIST + lsw_pick + 1 )
                            lsw_pick = lsw_pick + 1
                        End While
                        lsw_count = lsw_count - 1
                        s_core_print_string_at( 2 + lsw_count , 31 , fs_mg_pad( "" , 49 , true ) , UB_WHITE )
                        s_mg_show_list( lsw_count , false , -1 )
                    End If
                End If
            End While
            s_mg_screen_restore()
            s_msg_clear()
        Else
            ' the priest is granted them, pick a prayer at random
            While lsw_new <> 0
                lsw_pick  = Cast( Integer , ful_core_random_number( lsw_count ) ) - 1
                lub_spell = Peek( A_MG_LIST + lsw_pick )
                gul_player_spells_learnt = gul_player_spells_learnt bOr ful_mg_mask( lub_spell )
                Poke A_PLAYER_SPELL_ORDER + lsw_last , lub_spell
                lsw_last = lsw_last + 1
                s_msg( "You have learned the prayer of " + fs_mg_name( lub_spell ) + "." )
                While lsw_pick < lsw_count - 1
                    Poke A_MG_LIST + lsw_pick , Peek( A_MG_LIST + lsw_pick + 1 )
                    lsw_pick = lsw_pick + 1
                End While
                lsw_count = lsw_count - 1
                lsw_new   = lsw_new - 1
            End While
        End If
    End If

    gub_player_new_spells = lsw_new + lsw_missing
    If gub_player_new_spells = 0 Then gul_player_status = gul_player_status bOr UL_PY_STUDY
    ' set the mana for first level characters when they learn their first spell
    If gsw_player_mana = 0 Then s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_MANA )
End Sub


'##################################################################################################################################
' --- choosing a spell from a book ---

Function fsw_mg_choose( pub_place As UByte ) As Integer
    ' Moria's castSpellGetId() and spellGetId()
    Dim lul_book , lul_flags , lul_mask     As ULong
    Dim lsw_first , lsw_count , lsw_i       As Integer
    Dim lsw_spell , lsw_found               As Integer
    Dim lub_listed , lub_done , lub_key     As UByte
    Dim luw_spell                           As UInteger
    Dim ls_prompt , ls_question             As String

    ls_question = fs_core_text_at( A_PROMPT )
    Poke A_PROMPT , 0
    lul_book = Peek( ULong , A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE + UB_ITEM_FLAGS_OFFSET )

    ' the first spell in the book, the letters are counted from it, and the ones the player can cast
    lsw_first = -1
    lsw_count = 0
    lul_flags = lul_book bAnd gul_player_spells_learnt
    lul_mask  = 1
    For lsw_i = 0 To 30
        If ( lul_book bAnd lul_mask ) <> 0 And lsw_first < 0 Then lsw_first = lsw_i
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            If Peek( fuw_mg_spell( lsw_i ) ) <= guw_player_level Then
                Poke A_MG_LIST + lsw_count , lsw_i
                lsw_count = lsw_count + 1
            End If
        End If
        lul_mask = lul_mask << 1
    Next
    If lsw_count = 0 Then Return -1

    ls_prompt = "(Spells " + fs_core_char( Code( "a" ) + Peek( A_MG_LIST ) - lsw_first ) + "-" + fs_core_char( Code( "a" ) + Peek( A_MG_LIST + lsw_count - 1 ) - lsw_first ) + ", *=List, <ESCAPE>=exit) " + ls_question
    lsw_found  = -2
    lub_listed = false
    lub_done   = false
    While lub_done = false
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , ls_prompt , UB_BRIGHT_WHITE )
        s_core_get_key()
        lub_key = gub_key_char
        If lub_key = 27 Or guw_key_code = 0 Then
            lub_done = true
        ElseIf lub_key = Code( "*" ) Then
            If lub_listed = false Then
                s_mg_screen_save()
                lub_listed = true
                s_mg_show_list( lsw_count , false , lsw_first )
            End If
        ElseIf ( lub_key >= Code( "a" ) And lub_key <= Code( "z" ) ) Or ( lub_key >= Code( "A" ) And lub_key <= Code( "Z" ) ) Then
            lsw_spell = Cast( Integer , lub_key bOr 32 ) - Code( "a" ) + lsw_first
            lsw_found = -2
            For lsw_i = 0 To lsw_count - 1
                If Peek( A_MG_LIST + lsw_i ) = lsw_spell Then lsw_found = lsw_spell
            Next
            If lsw_found < 0 Then
                s_msg( "You don't know that " + fs_mg_kind() + "." )
            ElseIf lub_key < Code( "a" ) Then
                ' a capital letter asks first
                luw_spell = fuw_mg_spell( lsw_found )
                s_msg_clear()
                s_core_print_string_at( 0 , 0 , "Cast " + fs_mg_name( lsw_found ) + " (" + fs_core_number( Peek( luw_spell + 1 ) ) + " mana, " + fs_core_number( fsw_mg_chance( lsw_found ) ) + "% fail)? [y/n]" , UB_BRIGHT_WHITE )
                s_core_get_key()
                If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then
                    lub_done = true
                Else
                    lsw_found = -2
                End If
            Else
                lub_done = true
            End If
        End If
    End While
    If lub_listed Then s_mg_screen_restore()
    s_msg_clear()
    If lsw_found < 0 Then Return -2

    gsl_lib_long_1 = fsw_mg_chance( lsw_found )
    ' not enough mana for it? the player may still try
    If Peek( fuw_mg_spell( lsw_found ) + 1 ) > gsw_player_current_mana Then
        If gub_class_spell_type = 1 Then
            s_core_print_string_at( 0 , 0 , "You summon your limited strength to cast this one! Confirm? [y/n]" , UB_BRIGHT_WHITE )
        Else
            s_core_print_string_at( 0 , 0 , "The gods may think you presumptuous for this! Confirm? [y/n]" , UB_BRIGHT_WHITE )
        End If
        s_core_get_key()
        s_msg_clear()
        If gub_key_char <> Code( "y" ) And gub_key_char <> Code( "Y" ) Then Return -2
    End If
    Return lsw_found
End Function


'##################################################################################################################################
' --- browsing ---

Sub s_mg_browse()
    ' Moria's examineBook()
    Dim lsw_first , lsw_last , lsw_i    As Integer
    Dim lub_category , lub_flags        As UByte
    Dim lub_count , lub_can_read        As UByte
    Dim lul_flags , lul_mask            As ULong
    Dim ls_prompt                       As String

    lsw_first = -1
    lsw_last  = -1
    If gsw_player_pack_unique > 0 Then
        For lsw_i = 0 To gsw_player_pack_unique - 1
            lub_category = Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET )
            Poke A_INV_MASK + lsw_i , 0
            If lub_category = UB_TV_MAGIC_BOOK Or lub_category = UB_TV_PRAYER_BOOK Then
                If lsw_first < 0 Then lsw_first = lsw_i
                lsw_last = lsw_i
                Poke A_INV_MASK + lsw_i , 1
            End If
        Next
    End If
    If lsw_first < 0 Then
        s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANY_BOOKS )
        Return
    End If
    If gsw_player_blind > 0 Then
        s_core_message( UW_MSG_YOU_CANT_SEE_TO_READ_YOUR_SPELL )
        Return
    End If
    lub_flags = Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then
        s_core_message( UW_MSG_YOU_HAVE_NO_LIGHT_TO_READ_BY )
        Return
    End If
    If gsw_player_confused > 0 Then
        s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED )
        Return
    End If

    ls_prompt = "Which Book?"
    For lsw_i = 0 To Len( ls_prompt ) - 1
        Poke A_PROMPT + lsw_i , Code( ls_prompt( lsw_i ) )
    Next
    Poke A_PROMPT + Len( ls_prompt ) , 0
    gub_lib_param_1 = false
    guw_lib_param_2 = Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    lsw_i = gsw_lib_result
    If lsw_i < 0 Then Return

    lub_category = Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET )
    lub_can_read = false
    If gub_class_spell_type = 1 And lub_category = UB_TV_MAGIC_BOOK Then lub_can_read = true
    If gub_class_spell_type = 2 And lub_category = UB_TV_PRAYER_BOOK Then lub_can_read = true
    If lub_can_read = false Then
        s_core_message( UW_MSG_YOU_DO_NOT_UNDERSTAND_THE_LANGUAGE )
        Return
    End If

    lul_flags = Peek( ULong , A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_FLAGS_OFFSET )
    lub_count = 0
    lul_mask  = 1
    For lsw_i = 0 To 30
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            ' a level of 99 means a spell this class never has
            If Peek( fuw_mg_spell( lsw_i ) ) < 99 Then
                Poke A_MG_LIST + lub_count , lsw_i
                lub_count = lub_count + 1
            End If
        End If
        lul_mask = lul_mask << 1
    Next
    s_mg_screen_save()
    s_mg_show_list( lub_count , true , -1 )
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
    s_core_get_key()
    s_mg_screen_restore()
    s_msg_clear()
End Sub


Sub s_lib_books()
    Dim lub_place   As UByte
    Dim lsw_answer  As Integer = 0

    lub_place = gub_lib_param_1
    gub_mg_screen_saved = false
    gub_mg_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_BOOKS_GAIN Then
        If gub_class_spell_type = 0 Then
            s_core_message( UW_MSG_YOU_CANT_LEARN_ANY_NEW_SPELLS )
            gub_game_free_turn = true
        Else
            s_mg_gain_spells()
        End If
    ElseIf gub_lib_function = UB_LIB_BOOKS_CHOOSE Then
        lsw_answer = fsw_mg_choose( lub_place )
    ElseIf gub_lib_function = UB_LIB_BOOKS_BROWSE Then
        s_mg_browse()
    End If
    If gub_mg_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , gub_mg_saved_page_2 )
    gsw_lib_result = lsw_answer
End Sub
