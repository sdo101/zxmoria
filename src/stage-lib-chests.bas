#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_chests()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"

' this page is a LIBRARY, not a stage: chests, from Moria's player.cpp, player_traps.cpp, player_bash.cpp and
' spells.cpp, a chest lies on the floor like anything else, too big to pick up, its flags say whether it is locked
' and how it is trapped (the UL_CH_ bits in constants.bas) and, in the bits a creature's "movement" uses for it,
' what it holds, which is handed out just as if a creature had died there...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_CHESTS , <which routine> ), the
' chest is on the square at row gub_lib_param_1 and column guw_lib_param_2, the routines are:
'
'   UB_LIB_CHESTS_OPEN      the player tries to open it, picking the lock if there is one, any trap goes off,
'                           and what is inside falls out, Moria's openClosedChest()
'   UB_LIB_CHESTS_DISARM    the player tries to disarm it, their skill at that is in gsw_lib_result, Moria's
'                           playerDisarmChestTrap()
'   UB_LIB_CHESTS_BASH      the player bashes it, Moria's playerBashClosedChest()
'   UB_LIB_CHESTS_UNLOCK    a spell unlocks and disarms it, gsw_lib_result is true for the spells that say
'                           "Click!", false for the one that says "You have disarmed the chest.", what comes
'                           back is true if there was anything to undo
'   UB_LIB_CHESTS_SEARCH    the player, searching, looks it over for traps
'   UB_LIB_CHESTS_KNOW      a spell shows what traps it has
'   UB_LIB_CHESTS_BLOCKED   not about a chest at all: says that monster gub_lib_param_1 is in the way, for the
'                           commands that reach for a door or a chest, Moria's objectBlockedByMonster()
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
Dim gub_ch_y                As UByte    At A_LIB_PRIVATE            ' where the chest is
Dim gub_ch_x                As UByte    At A_LIB_PRIVATE + 1


Function fuw_ch_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ch_item() As UByte
    ' the number of whatever lies on the chest's square
    Return Peek( fuw_core_map_square( gub_level_map_page , gub_ch_y , gub_ch_x ) + UB_SQUARE_ITEM )
End Function


Function fuw_ch_record() As UInteger
    ' where the chest's own record is, in the level's list
    Return fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , fub_ch_item() )
End Function


Function ful_ch_flags() As ULong
    Return Peek( ULong , fuw_ch_record() + UB_ITEM_FLAGS_OFFSET )
End Function


Sub s_ch_set_flags( pul_flags As ULong )
    Poke ULong fuw_ch_record() + UB_ITEM_FLAGS_OFFSET , pul_flags
End Sub


Sub s_ch_known( pub_name As UByte )
    ' the player now knows all about the chest, Moria's spellItemIdentifyAndRemoveRandomInscription(), and, if
    ' pub_name is not 0, it is called something new: empty, locked, disarmed, unlocked
    Dim luw_record As UInteger

    luw_record = fuw_ch_record()
    Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bOr MB_ID_KNOWN2
    If pub_name <> 0 Then Poke luw_record + UB_ITEM_SPECIAL_NAME_OFFSET , pub_name
End Sub


Function fub_ch_is_known() As UByte
    ' Moria's spellItemIdentified()
    If ( Peek( fuw_ch_record() + UB_ITEM_IDENTIFICATION_OFFSET ) bAnd MB_ID_KNOWN2 ) <> 0 Then Return true
    Return false
End Function


Sub s_ch_show_experience()
    ' Moria's displayCharacterExperience()
    s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
End Sub


'##################################################################################################################################
' --- the traps ---

Sub s_ch_trap()
    ' Moria's chestTrap(): chests have traps too, which ones is in the flags, and all of them go off
    Dim lul_flags   As ULong
    Dim i           As UByte

    lul_flags = ful_ch_flags()

    If ( lul_flags bAnd UL_CH_LOSE_STR ) <> 0 Then
        s_core_message( UW_MSG_A_SMALL_NEEDLE_HAS_PRICKED_YOU )
        If gub_player_sustain_str Then
            s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
        Else
            gub_lib_param_1 = UB_STAT_STR
            s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_DECREASE )
            s_hit_killer( "a poison needle" )
            s_hit_player( fuw_core_dice_roll( 1 , 4 ) )
            s_core_message( UW_MSG_YOU_FEEL_WEAKENED )
        End If
    End If

    If ( lul_flags bAnd UL_CH_POISON ) <> 0 Then
        s_core_message( UW_MSG_A_SMALL_NEEDLE_HAS_PRICKED_YOU )
        s_hit_killer( "a poison needle" )
        s_hit_player( fuw_core_dice_roll( 1 , 6 ) )
        gsw_player_poisoned = gsw_player_poisoned + 10 + fuw_ch_random( 20 )
    End If

    If ( lul_flags bAnd UL_CH_PARALYSED ) <> 0 Then
        s_core_message( UW_MSG_A_PUFF_OF_YELLOW_GAS_SURROUNDS_YOU )
        If gub_player_free_action Then
            s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
        Else
            s_core_message( UW_MSG_YOU_CHOKE_AND_PASS_OUT )
            gsw_player_paralysis = 10 + fuw_ch_random( 20 )
        End If
    End If

    If ( lul_flags bAnd UL_CH_SUMMON ) <> 0 Then
        ' three monsters beside the chest, awake, the monsters library makes them
        For i = 1 To 3
            gub_lib_param_1 = gub_ch_y
            guw_lib_param_2 = Cast( UInteger , gub_ch_x ) bOr $0100
            s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON_AT )
        Next
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
    End If

    If ( lul_flags bAnd UL_CH_EXPLODE ) <> 0 Then
        s_core_message( UW_MSG_THERE_IS_A_SUDDEN_EXPLOSION )
        ' the chest is gone, Moria's dungeonDeleteObject()
        gub_lib_param_1 = gub_ch_y
        guw_lib_param_2 = gub_ch_x
        s_core_call_library( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT )
        s_hit_killer( "an exploding chest" )
        s_hit_player( fuw_core_dice_roll( 5 , 8 ) )
    End If
End Sub


'##################################################################################################################################
' --- opening, disarming, bashing ---

Function fsw_ch_lock_picking_skill() As Integer
    ' Moria's playerLockPickingSkill()
    Dim lsw_skill As Integer

    lsw_skill = gsw_player_disarm
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DISARM )
    lsw_skill = lsw_skill + 2 * gsw_lib_result
    gub_lib_param_1 = UB_STAT_INT
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_skill = lsw_skill + gsw_lib_result
    lsw_skill = lsw_skill + Cast( Integer , gub_class_adj_disarm ) * Cast( Integer , guw_player_level ) / 3
    Return lsw_skill
End Function


Sub s_ch_open()
    ' Moria's openClosedChest()
    Dim lul_flags   As ULong
    Dim luw_record  As UInteger
    Dim lsw_depth   As Integer
    Dim lub_success As UByte = false

    lul_flags = ful_ch_flags()
    If ( lul_flags bAnd UL_CH_LOCKED ) <> 0 Then
        lsw_depth = Peek( fuw_ch_record() + UB_ITEM_DEPTH_OFFSET )
        If gsw_player_confused > 0 Then
            s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED_TO_PICK_THE )
        ElseIf fsw_ch_lock_picking_skill() - lsw_depth > Cast( Integer , fuw_ch_random( 100 ) ) Then
            s_core_message( UW_MSG_YOU_HAVE_PICKED_THE_LOCK )
            gsl_player_exp = gsl_player_exp + lsw_depth
            s_ch_show_experience()
            lub_success = true
        Else
            s_msg_quiet( "You failed to pick the lock." )
        End If
    Else
        lub_success = true
    End If

    ' was chest still trapped?
    If lub_success = false Then Return
    s_ch_set_flags( lul_flags bAnd ( $FFFFFFFF - UL_CH_LOCKED ) )
    s_ch_known( UB_SN_EMPTY )
    luw_record = fuw_ch_record() + UB_ITEM_COST_OFFSET
    Poke ULong luw_record , 0

    ' oh, yes it was...   (snicker)
    s_ch_trap()

    If fub_ch_item() <> 0 Then
        ' chest treasure is allocated as if a creature had been killed, the player attack library does that,
        ' the cursed chest / monster win flag is cleared first, so that people can not win by opening a cursed chest
        gsl_lib_long_1  = ful_ch_flags() bAnd $7FFFFFFF
        gub_lib_param_1 = gub_ch_y
        guw_lib_param_2 = gub_ch_x
        s_core_call_library( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_DROP )
        s_ch_set_flags( 0 )
    End If
End Sub


Sub s_ch_disarm( psw_total As Integer )
    ' Moria's playerDisarmChestTrap()
    Dim lul_flags   As ULong
    Dim lsw_level   As Integer
    Dim lub_failed  As UByte

    If fub_ch_is_known() = false Then
        gub_game_free_turn = true
        s_core_message( UW_MSG_I_DONT_SEE_A_TRAP )
        Return
    End If
    lul_flags = ful_ch_flags()
    If ( lul_flags bAnd UL_CH_TRAPPED ) = 0 Then
        s_core_message( UW_MSG_THE_CHEST_WAS_NOT_TRAPPED )
        gub_game_free_turn = true
        Return
    End If

    lsw_level = Peek( fuw_ch_record() + UB_ITEM_DEPTH_OFFSET )
    If psw_total - lsw_level > Cast( Integer , fuw_ch_random( 100 ) ) Then
        lul_flags = lul_flags bAnd ( $FFFFFFFF - UL_CH_TRAPPED )
        s_ch_set_flags( lul_flags )
        If ( lul_flags bAnd UL_CH_LOCKED ) <> 0 Then
            s_ch_known( UB_SN_LOCKED )
        Else
            s_ch_known( UB_SN_DISARMED )
        End If
        s_core_message( UW_MSG_YOU_HAVE_DISARMED_THE_CHEST )
        gsl_player_exp = gsl_player_exp + lsw_level
        s_ch_show_experience()
        Return
    End If
    ' N.B: nested as it is so that the dice are thrown only when Moria throws them
    lub_failed = false
    If psw_total > 5 Then
        If Cast( Integer , fuw_ch_random( psw_total ) ) > 5 Then lub_failed = true
    End If
    If lub_failed Then
        s_msg_quiet( "You failed to disarm the chest." )
    Else
        s_core_message( UW_MSG_YOU_SET_A_TRAP_OFF )
        s_ch_known( 0 )
        s_ch_trap()
    End If
End Sub


Sub s_ch_bash()
    ' Moria's playerBashClosedChest()
    Dim lul_flags   As ULong
    Dim lub_broke   As UByte

    If fuw_ch_random( 10 ) = 1 Then
        s_core_message( UW_MSG_YOU_HAVE_DESTROYED_THE_CHEST )
        s_core_message( UW_MSG_AND_ITS_CONTENTS )
        ' it is a ruined chest now, in name
        Poke UInteger fuw_ch_record() , UW_OBJ_RUINED_CHEST
        s_ch_set_flags( 0 )
        Return
    End If
    lul_flags = ful_ch_flags()
    ' N.B: nested as it is so that the dice are thrown only when Moria throws them
    lub_broke = false
    If ( lul_flags bAnd UL_CH_LOCKED ) <> 0 Then
        If fuw_ch_random( 10 ) = 1 Then lub_broke = true
    End If
    If lub_broke Then
        s_core_message( UW_MSG_THE_LOCK_BREAKS_OPEN )
        s_ch_set_flags( lul_flags bAnd ( $FFFFFFFF - UL_CH_LOCKED ) )
    Else
        s_msg_quiet( "The chest holds firm." )
    End If
End Sub


'##################################################################################################################################
' --- what spells and searching do ---

Function fub_ch_unlock( pub_click As UByte ) As UByte
    ' the part of Moria's spellDestroyAdjacentDoorsTraps(), spellDisarmAllInDirection() and
    ' spellDestroyDoorsTrapsInDirection() that is about a chest: its traps and its lock are undone
    Dim lul_flags As ULong

    lul_flags = ful_ch_flags()
    If lul_flags = 0 Then Return false
    If pub_click Then s_core_message( UW_MSG_CLICK )
    s_ch_set_flags( lul_flags bAnd ( $FFFFFFFF - ( UL_CH_TRAPPED bOr UL_CH_LOCKED ) ) )
    If pub_click = false Then s_core_message( UW_MSG_YOU_HAVE_DISARMED_THE_CHEST )
    s_ch_known( UB_SN_UNLOCKED )
    Return true
End Function


Sub s_ch_search()
    ' the chest's part of Moria's playerSearch(): is it trapped? the treasure bits are masked out
    If ( ful_ch_flags() bAnd UL_CH_TRAPPED ) > 1 Then
        If fub_ch_is_known() = false Then
            s_ch_known( 0 )
            s_core_message( UW_MSG_YOU_HAVE_DISCOVERED_A_TRAP_ON_THE )
        Else
            s_core_message( UW_MSG_THE_CHEST_IS_TRAPPED )
        End If
    End If
End Sub


Sub s_ch_blocked( pub_monster As UByte )
    ' Moria's objectBlockedByMonster()
    Dim luw_record As UInteger

    luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
    If Peek( luw_record + UB_MONSTER_LIT_OFFSET ) Then
        s_msg( "The " + fs_core_text_at( fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) ) ) + " is in your way!" )
    Else
        s_core_message( UW_MSG_SOMETHING_IS_IN_YOUR_WAY )
    End If
End Sub


Sub s_lib_chests()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte
    Dim lsw_extra                                               As Integer
    Dim lub_answer                                              As UByte = false

    ' N.B: these are taken out first, the routines here call other libraries, which use the same places
    gub_ch_y  = gub_lib_param_1
    gub_ch_x  = guw_lib_param_2
    lsw_extra = gsw_lib_result
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_CHESTS_OPEN Then
        s_ch_open()
    ElseIf gub_lib_function = UB_LIB_CHESTS_DISARM Then
        s_ch_disarm( lsw_extra )
    ElseIf gub_lib_function = UB_LIB_CHESTS_BASH Then
        s_ch_bash()
    ElseIf gub_lib_function = UB_LIB_CHESTS_UNLOCK Then
        lub_answer = fub_ch_unlock( lsw_extra )
    ElseIf gub_lib_function = UB_LIB_CHESTS_SEARCH Then
        s_ch_search()
    ElseIf gub_lib_function = UB_LIB_CHESTS_KNOW Then
        s_ch_known( 0 )
    ElseIf gub_lib_function = UB_LIB_CHESTS_BLOCKED Then
        s_ch_blocked( gub_ch_y )
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_answer
End Sub
