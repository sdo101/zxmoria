' what the magic library and the books library share: the tables of spells, and showing a list of them,
' stage-lib-magic.bas and stage-lib-books.bas include this file, each has its own copy of these routines
' N.B: the page's own storage at A_LIB_PRIVATE, 75 bytes of it, is used here
' --- its working storage is in globals.bas, under "private to stage-magic-include.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- the tables ---

Function fuw_mg_spell( pub_spell As UByte ) As UInteger
    ' where one spell's four bytes are, for the player's class: level, mana, chance of failing, experience
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
    Return A_TABLE_SPELLS + Cast( UInteger , gub_player_class - 1 ) * UB_CLASS_SPELLS_SIZE + Cast( UInteger , pub_spell ) * UB_SPELL_SIZE
End Function


Function fs_mg_name( pub_spell As UByte ) As String
    ' what a spell is called, the prayers' names follow the spells'
    Dim luw_name As UInteger

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
    luw_name = A_TABLE_SPELL_NAMES + Cast( UInteger , pub_spell ) * UB_SPELL_NAME_SIZE
    If gub_class_spell_type <> UB_SPELL_TYPE_MAGE Then luw_name = luw_name + 31 * UB_SPELL_NAME_SIZE
    Return fs_core_text_at( luw_name )
End Function


Function ful_mg_mask( pub_spell As UByte ) As ULong
    ' the bit for one spell
    Return Cast( ULong , 1 ) << pub_spell
End Function


Function fsw_mg_stat_bonus() As Integer
    ' what the player's intelligence, for a mage's spells, or wisdom, for prayers, does for them
    gub_lib_param_1 = UB_STAT_WIS
    If gub_class_spell_type = UB_SPELL_TYPE_MAGE Then gub_lib_param_1 = UB_STAT_INT
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    Return gsw_lib_result
End Function


Function fs_mg_kind() As String
    If gub_class_spell_type = UB_SPELL_TYPE_MAGE Then Return "spell"
    Return "prayer"
End Function


Function fsw_mg_chance( pub_spell As UByte ) As Integer
    ' Moria's spellChanceOfSuccess(), which is the chance of failing: less with each level above the spell's
    ' own, less for the clever or the wise, and a good deal more without the mana for it
    Dim luw_spell   As UInteger
    Dim lsw_chance  As Integer
    Dim lsw_mana    As Integer

    lsw_chance = 3 * ( fsw_mg_stat_bonus() - 1 )
    luw_spell  = fuw_mg_spell( pub_spell )
    lsw_mana   = Peek( luw_spell + 1 )
    lsw_chance = Cast( Integer , Peek( luw_spell + 2 ) ) - 3 * ( Cast( Integer , guw_player_level ) - Cast( Integer , Peek( luw_spell ) ) ) - lsw_chance
    If lsw_mana > gsw_player_current_mana Then lsw_chance = lsw_chance + 5 * ( lsw_mana - gsw_player_current_mana )
    If lsw_chance > 95 Then lsw_chance = 95
    If lsw_chance < 5 Then lsw_chance = 5
    Return lsw_chance
End Function


'##################################################################################################################################
' --- the screen ---

Sub s_mg_screen_save()
    ' puts the screen aside, in the corridor scratchpad page, Moria's terminalSaveScreen()
    If gub_mg_screen_saved Then Return
    gub_mg_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , UW_SCREEN_CELLS_SIZE )
    gub_mg_screen_saved = true
End Sub


Sub s_mg_screen_restore()
    ' Moria's terminalRestoreScreen()
    If gub_mg_screen_saved = false Then Return
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
    If gub_mg_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_mg_saved_page )
    gub_mg_screen_saved = false
End Sub


Function fs_mg_pad( ps_text As String , pub_width As UByte , pub_left As UByte ) As String
    ' text made up to a width with spaces, after it or before it
    While Len( ps_text ) < pub_width
        If pub_left Then
            ps_text = ps_text + " "
        Else
            ps_text = " " + ps_text
        End If
    End While
    Return ps_text
End Function


Sub s_mg_show_list( pub_count As UByte , pub_comment As UByte , psw_first As Integer )
    ' Moria's displaySpellsList(): the spells in A_MG_LIST, with their level, mana and chance of failing, when
    ' pub_comment is set it says of each whether the player knows it, the letters run from a, or, when psw_first
    ' is not -1, each spell has the letter of its place in its book, of which psw_first is the first spell
    Dim i , lub_spell , lub_col     As UByte
    Dim luw_spell                   As UInteger
    Dim ls_line , ls_note           As String
    Dim lul_mask                    As ULong
    Dim lub_letter                  As UByte

    lub_col = 31
    If pub_comment Then lub_col = 22
    s_core_print_string_at( 1 , lub_col , fs_mg_pad( "     Name" , 35 , true ) + "Lv Mana Fail              " , UB_BRIGHT_WHITE )
    If pub_count > 22 Then pub_count = 22
    If pub_count = 0 Then Return
    For i = 0 To pub_count - 1
        lub_spell = Peek( A_MG_LIST + i )
        ls_note   = ""
        If pub_comment Then
            lul_mask = ful_mg_mask( lub_spell )
            If ( gul_player_spells_forgotten bAnd lul_mask ) <> 0 Then
                ls_note = " forgotten"
            ElseIf ( gul_player_spells_learnt bAnd lul_mask ) = 0 Then
                ls_note = " unknown"
            ElseIf ( gul_player_spells_worked bAnd lul_mask ) = 0 Then
                ls_note = " untried"
            End If
        End If
        lub_letter = Code( "a" ) + i
        If psw_first <> -1 Then lub_letter = Code( "a" ) + lub_spell - psw_first
        ls_line   = "  " + fs_core_char( lub_letter ) + ") " + fs_mg_pad( fs_mg_name( lub_spell ) , 30 , true )
        ls_line   = ls_line + fs_mg_pad( fs_core_number( fsw_mg_chance( lub_spell ) ) , 3 , false ) + "%" + ls_note
        luw_spell = fuw_mg_spell( lub_spell )
        ' the level and the mana go between the name and the chance
        ls_line = ls_line( 0 To 34 ) + fs_mg_pad( fs_core_number( Peek( luw_spell ) ) , 2 , false ) + " " + fs_mg_pad( fs_core_number( Peek( luw_spell + 1 ) ) , 4 , false ) + " " + ls_line( 35 To Len( ls_line ) - 1 )
        s_core_print_string_at( 2 + i , lub_col , fs_mg_pad( ls_line , 80 - lub_col , true ) , UB_WHITE )
    Next
End Sub
