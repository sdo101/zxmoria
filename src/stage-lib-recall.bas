#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_recall()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: showing the monster memory, Moria's recall.cpp, what the player has learnt
' about a kind of creature is kept by ful_core_recall() in the core, this page turns it into a paragraph...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_RECALL , <which routine> ), the routines are:
'
'   UB_LIB_RECALL_SHOW      everything known about creature guw_lib_param_2, Moria's memoryRecall(), the screen is
'                           put back afterwards, gsw_lib_result is the key the player pressed to go on
'   UB_LIB_RECALL_SYMBOL    asks "You recall those details?" and then shows each kind of creature drawn with the
'                           character in gub_lib_param_1 that anything is known about, Moria's
'                           recallMonsterAttributes()
'
' in wizard mode everything is known, Moria's memoryWizardModeInit()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of
'
' N.B: the paragraph is too much for one page, this page writes the first half of it and stage-lib-recall-2.bas the
' second, the line being filled is in the core's text buffer, where both can get at it


Function fuw_rc_table( pub_which As UByte ) As UInteger
    ' Moria's data_recall.cpp: the lists of phrases this page uses, each phrase ends in a 0
    If pub_which = 2 Then Return @rc_how_much
    If pub_which = 4 Then Return @rc_spell
    Return @rc_breath
rc_how_much:
    Asm
        defm " not at all"
        defb 0
        defm " a bit"
        defb 0
        defb 0
        defm " quite"
        defb 0
        defm " very"
        defb 0
        defm " most"
        defb 0
        defm " highly"
        defb 0
        defm " extremely"
        defb 0
    End Asm
rc_spell:
    Asm
        defm "teleport short distances"
        defb 0
        defm "teleport long distances"
        defb 0
        defm "teleport its prey"
        defb 0
        defm "cause light wounds"
        defb 0
        defm "cause serious wounds"
        defb 0
        defm "paralyse its prey"
        defb 0
        defm "induce blindness"
        defb 0
        defm "confuse"
        defb 0
        defm "terrify"
        defb 0
        defm "summon a monster"
        defb 0
        defm "summon the undead"
        defb 0
        defm "slow its prey"
        defb 0
        defm "drain mana"
        defb 0
        defm "unknown 1"
        defb 0
        defm "unknown 2"
        defb 0
    End Asm
rc_breath:
    Asm
        defm "lightning"
        defb 0
        defm "poison gases"
        defb 0
        defm "acid"
        defb 0
        defm "frost"
        defb 0
        defm "fire"
        defb 0
    End Asm
    Return 0
End Function


#include "stage-recall-include.bas"


'##################################################################################################################################
' --- what is known about one kind of creature ---

Function fub_rc_recall( puw_creature As UInteger ) As UByte
    ' Moria's memoryRecall(), the answer is the key the player pressed
    Dim lul_spells , lul_move , lul_value   As ULong
    Dim luw_defense , luw_entry             As UInteger
    Dim lsw_speed , lsw_value               As Integer
    Dim lub_known , i , lub_attack          As UByte
    Dim lub_type , lub_method               As UByte
    Dim lub_dice , lub_sides                As UByte
    Dim lub_count , lub_known_attacks       As UByte
    Dim lub_carry                           As UByte
    Dim ls_text                             As String

    ' what is remembered, and the creature itself
    gul_rc_movement = ful_core_recall( puw_creature , UB_RECALL_MOVEMENT , 0 )
    gul_rc_spells   = ful_core_recall( puw_creature , UB_RECALL_SPELLS , 0 )
    guw_rc_defenses = ful_core_recall( puw_creature , UB_RECALL_DEFENSES , 0 )
    guw_rc_kills    = ful_core_recall( puw_creature , UB_RECALL_KILLS , 0 )
    guw_rc_deaths   = ful_core_recall( puw_creature , UB_RECALL_DEATHS , 0 )
    gub_rc_wake     = ful_core_recall( puw_creature , UB_RECALL_WAKE , 0 )
    gub_rc_ignore   = ful_core_recall( puw_creature , UB_RECALL_IGNORE , 0 )
    For i = 0 To 3
        Poke A_RC_ATTACKS + i , ful_core_recall( puw_creature , UB_RECALL_ATTACK + i , 0 )
    Next
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , puw_creature , A_CREATURE )

    If gub_game_wizard Then
        ' Moria's memoryWizardModeInit(): the wizard is shown all there is to know, N.B: what is really remembered
        ' is not touched, these are working copies, so there is nothing to put back afterwards as Moria must
        guw_rc_kills  = 32767
        gub_rc_wake   = 255
        gub_rc_ignore = 255
        lul_value = 0
        If ( gul_creature_movement bAnd UL_CM_4D2_OBJ ) <> 0 Then lul_value = 8
        If ( gul_creature_movement bAnd UL_CM_2D2_OBJ ) <> 0 Then lul_value = lul_value + 4
        If ( gul_creature_movement bAnd UL_CM_1D2_OBJ ) <> 0 Then lul_value = lul_value + 2
        If ( gul_creature_movement bAnd UL_CM_90_RANDOM ) <> 0 Then lul_value = lul_value + 1
        If ( gul_creature_movement bAnd UL_CM_60_RANDOM ) <> 0 Then lul_value = lul_value + 1
        gul_rc_movement = ( gul_creature_movement bAnd ( $FFFFFFFF - UL_CM_TREASURE ) ) bOr ( lul_value << UB_CM_TR_SHIFT )
        guw_rc_defenses = guw_creature_defenses
        gul_rc_spells   = gul_creature_spells
        If ( gul_creature_spells bAnd UL_CS_FREQ ) <> 0 Then gul_rc_spells = gul_creature_spells bOr UL_CS_FREQ
        i = 0
        While i < 4
            If Peek( A_CREATURE + UB_CREATURE_ATTACKS_OFFSET + i ) = 0 Then
                i = 4
            Else
                Poke A_RC_ATTACKS + i , 255
                i = i + 1
            End If
        End While
        ' a little hack to enable the display of info for Quylthulgs
        If ( gul_rc_movement bAnd UL_CM_ONLY_MAGIC ) <> 0 Then Poke A_RC_ATTACKS , 255
    End If

    gub_rc_row    = 0
    gub_rc_length = 0
    lul_spells  = gul_rc_spells bAnd gul_creature_spells bAnd $FFFFFFF0
    ' the win property is always known, set it if a win monster
    lul_move    = gul_rc_movement bOr ( gul_creature_movement bAnd UL_CM_WIN )
    luw_defense = guw_rc_defenses bAnd guw_creature_defenses

    ' start the paragraph for the core monster description
    s_rc_print( "The " + fs_core_text_at( A_CREATURE ) + ":" )
    s_rc_char( 10 )

    ' conflict history, Moria's memoryConflictHistory()
    If guw_rc_deaths <> 0 Then
        s_rc_number( guw_rc_deaths )
        s_rc_print( " of the contributors to your monster memory " + fs_rc_have( guw_rc_deaths ) + " been killed by this creature, and " )
        If guw_rc_kills = 0 Then
            s_rc_print( "it is not ever known to have been defeated." )
        Else
            s_rc_print( "at least " )
            s_rc_number( guw_rc_kills )
            s_rc_print( " of the beasts " + fs_rc_have( guw_rc_kills ) + " been exterminated." )
        End If
    ElseIf guw_rc_kills <> 0 Then
        s_rc_print( "At least " )
        s_rc_number( guw_rc_kills )
        s_rc_print( " of these creatures " + fs_rc_have( guw_rc_kills ) + " been killed by contributors to your monster memory." )
    Else
        s_rc_print( "No known battles to the death are recalled." )
    End If

    ' immediately obvious, Moria's memoryDepthFoundAt()
    lub_known = false
    If gub_creature_level = 0 Then
        lub_known = true
        s_rc_print( " It lives in the town" )
    ElseIf guw_rc_kills <> 0 Then
        lub_known = true
        ' the Balrog is a level 100 monster, but appears at 50 feet
        i = gub_creature_level
        If i > UB_MON_ENDGAME_LEVEL Then i = UB_MON_ENDGAME_LEVEL
        s_rc_print( " It is normally found at depths of " )
        s_rc_number( Cast( UInteger , i ) * 50 )
        s_rc_print( " feet" )
    End If

    ' Moria's memoryMovement(), the creature's speed is kept 10 greater than it is
    lsw_speed = Cast( Integer , gub_creature_speed ) - 10
    If ( lul_move bAnd $3F ) <> 0 Then
        If lub_known Then
            s_rc_print( ", and" )
        Else
            s_rc_print( " It" )
            lub_known = true
        End If
        s_rc_print( " moves" )
        i = ( lul_move bAnd $38 ) >> 3
        If i <> 0 Then
            s_rc_phrase( 2 , i )
            s_rc_print( " erratically" )
        End If
        If lsw_speed = 1 Then
            s_rc_print( " at normal speed" )
        Else
            If i <> 0 Then s_rc_print( ", and" )
            If lsw_speed <= 0 Then
                If lsw_speed = -1 Then s_rc_print( " very" )
                If lsw_speed < -1 Then s_rc_print( " incredibly" )
                s_rc_print( " slowly" )
            Else
                If lsw_speed = 3 Then s_rc_print( " very" )
                If lsw_speed > 3 Then s_rc_print( " unbelievably" )
                s_rc_print( " quickly" )
            End If
        End If
    End If
    If ( lul_move bAnd UL_CM_ATTACK_ONLY ) <> 0 Then
        If lub_known Then
            s_rc_print( ", but" )
        Else
            s_rc_print( " It" )
            lub_known = true
        End If
        s_rc_print( " does not deign to chase intruders" )
    End If
    If ( lul_move bAnd UL_CM_ONLY_MAGIC ) <> 0 Then
        If lub_known Then
            s_rc_print( ", but" )
        Else
            s_rc_print( " It" )
            lub_known = true
        End If
        s_rc_print( " always moves and attacks by using magic" )
    End If
    ' finish off the paragraph with a period!
    If lub_known Then s_rc_print( "." )

    ' kill it once to know experience, and quality (evil, undead, monstrous), Moria's memoryKillPoints()
    If guw_rc_kills <> 0 Then
        s_rc_print( " A kill of this" )
        If ( guw_creature_defenses bAnd UW_CD_ANIMAL ) <> 0 Then s_rc_print( " natural" )
        If ( guw_creature_defenses bAnd UW_CD_EVIL ) <> 0 Then s_rc_print( " evil" )
        If ( guw_creature_defenses bAnd UW_CD_UNDEAD ) <> 0 Then s_rc_print( " undead" )
        ' the whole part, and the hundredths, of the experience for a kill at the player's level
        lul_value = Cast( ULong , guw_creature_kill_exp ) * gub_creature_level
        lsw_value = ( ( lul_value Mod guw_player_level ) * 1000 / guw_player_level + 5 ) / 10
        lul_value = lul_value / guw_player_level
        s_rc_print( " creature is worth " )
        s_rc_number( lul_value )
        s_rc_print( "." )
        If lsw_value < 10 Then s_rc_print( "0" )
        s_rc_number( lsw_value )
        s_rc_print( " point" )
        If lul_value <> 1 Or lsw_value <> 0 Then s_rc_print( "s" )
        ls_text = "th"
        If guw_player_level / 10 <> 1 Then
            i = guw_player_level Mod 10
            If i = 1 Then ls_text = "st"
            If i = 2 Then ls_text = "nd"
            If i = 3 Then ls_text = "rd"
        End If
        s_rc_print( " for a" )
        If guw_player_level = 8 Or guw_player_level = 11 Or guw_player_level = 18 Then s_rc_print( "n" )
        s_rc_print( " " )
        s_rc_number( guw_player_level )
        s_rc_print( ls_text + " level character." )
    End If

    ' spells known, if have been used against us, breath weapons or resistance might be known only because we
    ' cast spells at it, Moria's memoryMagicSkills()
    ls_text = " It is resistant to "
    If ( gul_rc_spells bAnd UL_CS_FREQ ) <> 0 Then ls_text = " It can breathe "
    lub_known = fub_rc_list( lul_spells >> 19 , 5 , 5 , ls_text , " and " )
    ls_text = " It is"
    If lub_known Then ls_text = ", and is also"
    If fub_rc_list( ( lul_spells >> 4 ) bAnd $1FFF , 15 , 4 , ls_text + " magical, casting spells which " , " or " ) Then lub_known = true
    If lub_known Then
        ' could offset by level
        If ( gul_rc_spells bAnd UL_CS_FREQ ) > 5 Then
            s_rc_print( "; 1 time in " )
            s_rc_number( gul_creature_spells bAnd UL_CS_FREQ )
        End If
        s_rc_print( "." )
    End If

    ' the rest of the paragraph, and the wait for a key, are the other page's
    s_core_call_library( UB_PAGED_CODE_LIB_RECALL_2 , UB_LIB_RECALL_2_REST )
    Return gsw_lib_result
End Function


Sub s_rc_screen_save()
    ' puts the screen aside, in the corridor scratchpad page, Moria's terminalSaveScreen()
    gub_rc_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , UW_SCREEN_CELLS_SIZE )
End Sub


Sub s_rc_screen_restore()
    ' Moria's terminalRestoreScreen()
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
    If gub_rc_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_rc_saved_page )
End Sub


Function fub_rc_symbol( pub_symbol As UByte ) As UByte
    ' Moria's recallMonsterAttributes(): every kind of creature drawn with this character that anything is known
    ' about, from the last in the list to the first, the answer is the last key pressed
    Dim lsw_creature    As Integer
    Dim luw_creature    As UInteger
    Dim lub_shown       As UByte = false
    Dim lub_key         As UByte = 0
    Dim lub_known , i   As UByte

    lsw_creature = UW_CREATURES_IN_GAME - 1
    While lsw_creature >= 0
        luw_creature = lsw_creature
        If Peek( fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature ) + UB_CREATURE_SPRITE_OFFSET ) = pub_symbol Then
            ' do we know anything about this monster? Moria's memoryMonsterKnown()
            lub_known = false
            If gub_game_wizard Then lub_known = true
            For i = UB_RECALL_MOVEMENT To UB_RECALL_DEATHS
                If ful_core_recall( luw_creature , i , 0 ) <> 0 Then lub_known = true
            Next
            For i = UB_RECALL_ATTACK To UB_RECALL_ATTACK + 3
                If ful_core_recall( luw_creature , i , 0 ) <> 0 Then lub_known = true
            Next
            If lub_known Then
                If lub_shown = false Then
                    ' Moria's getInputConfirmationWithAbort()
                    s_core_print_string_at( 0 , 40 , "You recall those details? [y/n]" , UB_BRIGHT_WHITE )
                    s_core_get_key()
                    s_core_clear_row( 0 , 40 , UB_WHITE )
                    If gub_key_char <> Code( "y" ) And gub_key_char <> Code( "Y" ) Then Return gub_key_char
                    lub_shown = true
                End If
                s_rc_screen_save()
                lub_key = fub_rc_recall( luw_creature )
                s_rc_screen_restore()
                If lub_key = UC_ESCAPE Then Return lub_key
            End If
        End If
        lsw_creature = lsw_creature - 1
    End While
    Return lub_key
End Function


Sub s_lib_recall()
    Dim lub_saved_page_1 , lub_saved_page_2 As UByte
    Dim lub_symbol , lub_key                As UByte
    Dim luw_creature                        As UInteger

    lub_symbol   = gub_lib_param_1
    luw_creature = guw_lib_param_2
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the working creature is put aside too, the caller may be in the middle of using it
    s_core_ram_copy( A_CREATURE , A_LIB_PRIVATE , UB_RECORD_SIZE )
    lub_key = 0
    If gub_lib_function = UB_LIB_RECALL_SHOW Then
        s_rc_screen_save()
        lub_key = fub_rc_recall( luw_creature )
        s_rc_screen_restore()
    ElseIf gub_lib_function = UB_LIB_RECALL_SYMBOL Then
        lub_key = fub_rc_symbol( lub_symbol )
    End If
    s_core_ram_copy( A_LIB_PRIVATE , A_CREATURE , UB_RECORD_SIZE )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_key
End Sub
