#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_magic()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-magic-include.bas"

' this page is a LIBRARY, not a stage: how many spells or prayers the player may know, and how much mana they have,
' from Moria's player.cpp, the books themselves, studying, browsing and picking a spell, are another page,
' stage-lib-books.bas, and the casting a third, stage-lib-cast.bas...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , <which routine> ), the routines are:
'
'   UB_LIB_MAGIC_CALC       works out afresh how many spells the player may know, forgetting or remembering some if
'                           that has changed, and how much mana they have, for when their level, or their
'                           intelligence or wisdom, changes, Moria's playerCalculateAllowedSpellsCount() and
'                           playerGainMana(), it does nothing for a class with no spells
'   UB_LIB_MAGIC_MANA       only the mana, Moria's playerGainMana(), for when the first spell is learnt
'
' the spells are numbered 0 to 30, the same numbers for a mage's spells and a priest's prayers, which spells a book
' holds is in its flags, one bit a spell, and what the player knows, has forgotten, and has cast successfully are
' three more sets of 31 bits in the player's record, what each spell costs each class is a table in the paged data
' (A_TABLE_SPELLS), as are the names (A_TABLE_SPELL_NAMES)

'##################################################################################################################################
' --- how many spells, and how much mana ---

Function fsw_mg_levels() As Integer
    ' how many levels the player has had spells for
    Return Cast( Integer , guw_player_level ) - Cast( Integer , gub_class_first_spell_level ) + 1
End Function


Sub s_mg_gain_mana()
    ' Moria's playerGainMana(), with its newMana(): the mana the player's level and their intelligence or wisdom
    ' give them, what they have at the moment keeps its proportion of the new total
    Dim lsw_new , lsw_bonus , lsw_levels    As Integer
    Dim lsl_value                           As Long

    If gul_player_spells_learnt = 0 Then
        If gsw_player_mana <> 0 Then
            gsw_player_mana         = 0
            gsw_player_current_mana = 0
        End If
        Return
    End If

    lsw_bonus  = fsw_mg_stat_bonus()
    lsw_levels = fsw_mg_levels()
    lsw_new    = 0
    If lsw_bonus = 1 Or lsw_bonus = 2 Then lsw_new = lsw_levels
    ' N.B: halved as C halves, towards nought, the levels are below nought for a caster drained under their first
    ' spell's level, see fsw_c_half()
    If lsw_bonus = 3 Then lsw_new = fsw_c_half( 3 * lsw_levels )
    If lsw_bonus = 4 Then lsw_new = 2 * lsw_levels
    If lsw_bonus = 5 Then lsw_new = fsw_c_half( 5 * lsw_levels )
    If lsw_bonus = 6 Then lsw_new = 3 * lsw_levels
    If lsw_bonus = 7 Then lsw_new = 4 * lsw_levels
    ' increment mana by one, so that first level chars have 2 mana
    If lsw_new > 0 Then lsw_new = lsw_new + 1

    If gsw_player_mana <> lsw_new Then
        If gsw_player_mana <> 0 Then
            ' change current mana proportionately to change of max mana, divide first to avoid overflow, little loss of accuracy
            lsl_value = ( ( Cast( Long , gsw_player_current_mana ) << 16 ) + guw_player_mana_fraction ) / gsw_player_mana * lsw_new
            gsw_player_current_mana  = lsl_value >> 16
            guw_player_mana_fraction = lsl_value bAnd $FFFF
        Else
            gsw_player_current_mana  = lsw_new
            guw_player_mana_fraction = 0
        End If
        gsw_player_mana = lsw_new
    End If
End Sub


Sub s_mg_calculate()
    ' Moria's playerCalculateAllowedSpellsCount(), and the six routines it calls
    Dim lsw_i , lsw_allowed , lsw_known , lsw_new   As Integer
    Dim lsw_bonus , lsw_levels , lsw_count          As Integer
    Dim lul_mask , lul_flags                        As ULong
    Dim lub_order                                   As UByte
    Dim ls_kind                                     As String

    ls_kind = fs_mg_kind()

    ' Moria's eliminateKnownSpellsGreaterThanLevel(): the spells the player is no longer of a level to know are
    ' forgotten, the highest first, as when life is drained
    lul_mask = $80000000
    lsw_i = 31
    While lul_mask <> 0
        If ( lul_mask bAnd gul_player_spells_learnt ) <> 0 Then
            If Peek( fuw_mg_spell( lsw_i ) ) > guw_player_level Then
                gul_player_spells_learnt    = gul_player_spells_learnt bAnd ( $FFFFFFFF - lul_mask )
                gul_player_spells_forgotten = gul_player_spells_forgotten bOr lul_mask
                s_msg( "You have forgotten the " + ls_kind + " of " + fs_mg_name( lsw_i ) + "." )
            Else
                lul_mask = 0
            End If
        End If
        lul_mask = lul_mask >> 1
        lsw_i = lsw_i - 1
    End While

    ' Moria's numberOfSpellsAllowed()
    lsw_bonus   = fsw_mg_stat_bonus()
    lsw_levels  = fsw_mg_levels()
    lsw_allowed = 0
    If lsw_bonus >= 1 And lsw_bonus <= 3 Then lsw_allowed = lsw_levels
    ' N.B: halved as C halves, see above
    If lsw_bonus = 4 Or lsw_bonus = 5 Then lsw_allowed = fsw_c_half( 3 * lsw_levels )
    If lsw_bonus = 6 Then lsw_allowed = 2 * lsw_levels
    If lsw_bonus = 7 Then lsw_allowed = fsw_c_half( 5 * lsw_levels )

    ' Moria's numberOfSpellsKnown()
    lsw_known = 0
    lul_mask  = 1
    While lul_mask <> 0
        If ( lul_mask bAnd gul_player_spells_learnt ) <> 0 Then lsw_known = lsw_known + 1
        lul_mask = lul_mask << 1
    End While

    lsw_new = lsw_allowed - lsw_known
    If lsw_new > 0 Then
        ' Moria's rememberForgottenSpells(): in the order they were first learnt
        lsw_i = 0
        While gul_player_spells_forgotten <> 0 And lsw_new <> 0 And lsw_i < lsw_allowed And lsw_i < 32
            lub_order = Peek( A_PLAYER_SPELL_ORDER + lsw_i )
            lul_mask  = 0
            If lub_order <> 99 Then lul_mask = ful_mg_mask( lub_order )
            If ( lul_mask bAnd gul_player_spells_forgotten ) <> 0 Then
                If Peek( fuw_mg_spell( lub_order ) ) <= guw_player_level Then
                    lsw_new = lsw_new - 1
                    gul_player_spells_forgotten = gul_player_spells_forgotten bAnd ( $FFFFFFFF - lul_mask )
                    gul_player_spells_learnt    = gul_player_spells_learnt bOr lul_mask
                    s_msg( "You have remembered the " + ls_kind + " of " + fs_mg_name( lub_order ) + "." )
                Else
                    lsw_allowed = lsw_allowed + 1
                End If
            End If
            lsw_i = lsw_i + 1
        End While

        If lsw_new > 0 Then
            ' Moria's learnableSpells(): no more than there are spells left to learn at this level
            lul_flags = $7FFFFFFF bAnd ( $FFFFFFFF - gul_player_spells_learnt )
            lsw_count = 0
            lul_mask  = 1
            lsw_i     = 0
            While lul_flags <> 0
                If ( lul_flags bAnd lul_mask ) <> 0 Then
                    lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
                    If Peek( fuw_mg_spell( lsw_i ) ) <= guw_player_level Then lsw_count = lsw_count + 1
                End If
                lul_mask = lul_mask << 1
                lsw_i = lsw_i + 1
            End While
            If lsw_new > lsw_count Then lsw_new = lsw_count
        End If
    ElseIf lsw_new < 0 Then
        ' Moria's forgetSpells(): the last learnt go first
        lsw_i = 31
        While lsw_new <> 0 And gul_player_spells_learnt <> 0 And lsw_i >= 0
            lub_order = Peek( A_PLAYER_SPELL_ORDER + lsw_i )
            lul_mask  = 0
            If lub_order <> 99 Then lul_mask = ful_mg_mask( lub_order )
            If ( lul_mask bAnd gul_player_spells_learnt ) <> 0 Then
                gul_player_spells_learnt    = gul_player_spells_learnt bAnd ( $FFFFFFFF - lul_mask )
                gul_player_spells_forgotten = gul_player_spells_forgotten bOr lul_mask
                lsw_new = lsw_new + 1
                s_msg( "You have forgotten the " + ls_kind + " of " + fs_mg_name( lub_order ) + "." )
            End If
            lsw_i = lsw_i - 1
        End While
        lsw_new = 0
    End If

    If lsw_new <> gub_player_new_spells Then
        If lsw_new > 0 And gub_player_new_spells = 0 Then s_msg( "You can learn some new " + ls_kind + "s now." )
        gub_player_new_spells = lsw_new
        gul_player_status     = gul_player_status bOr UL_PY_STUDY
    End If
End Sub


Sub s_lib_magic()
    gub_mg_saved_page_2 = gub_core_MMU2_page_number
    ' only for those who have spells at all
    If gub_class_spell_type <> 0 Then
        If gub_lib_function = UB_LIB_MAGIC_CALC Then s_mg_calculate()
        s_mg_gain_mana()
    End If
    If gub_mg_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , gub_mg_saved_page_2 )
End Sub
