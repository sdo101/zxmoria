#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_turn_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-disturb-include.bas"

' this page is the second half of the turn LIBRARY, see stage-lib-turn.bas, which is the page the walking stage calls,
' that page hands on to this one, at the right moments, the rest of what Moria's playDungeon() does as each turn
' begins, its playerUpdate...() routines (game_run.cpp), so that everything happens in Moria's order:
'
'   UB_LIB_TURN_2_HERO      heroism and super heroism: more hit points and a better aim while they last
'   UB_LIB_TURN_2_SPEED     being fast, being slow, resting, and hallucination
'   UB_LIB_TURN_2_LATE      protection from evil, invulnerability, being blessed, resistance to heat and to cold,
'                           seeing the invisible, infravision and the word of recall each count down, the weight of
'                           the pack is felt, and the words along the bottom of the screen are brought up to date
'
' what the walking stage must do afterwards is left in gub_game_turn_flags, see MB_TURN_ in constants.bas
'
' the words on the bottom row of the screen are at Moria's columns: Paralysed, Rest, Searching 38, Fast or Slow 49, Study 59
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of
'
' N.B: each change that Moria answers with playerDisturb() does so here too, at the same moment, s_dst_disturb() in
' stage-disturb-include.bas


Sub s_t2_block()
    ' the player's details down the left of the screen are shown again
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Sub s_t2_change_speed( psw_speed As Integer )
    ' Moria's playerChangeSpeed(): the player's speed changes, and every monster's by as much, speed is relative
    Dim lub_monster     As UByte
    Dim luw_record      As UInteger

    gsw_player_speed  = gsw_player_speed + psw_speed
    gul_player_status = gul_player_status bOr UL_PY_SPEED
    ' the working monster too: if it is out of its page it will be put back over its record, and it must take the
    ' change with it, and if it is not, changing it does no harm... this is what lets the speed change in the middle
    ' of a monster's turn, or of an attack, as Moria's does when the player is disturbed while searching
    gsw_monster_speed = gsw_monster_speed + psw_speed
    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster ) + UB_MONSTER_SPEED_OFFSET
        Poke UInteger luw_record , Cast( UInteger , Peek( Integer , luw_record ) + psw_speed )
    End While
End Sub


Sub s_t2_detect_enchantment()
    ' Moria's playerDetectEnchantment(), with its itemEnchanted(): now and then the player senses that something
    ' they carry or wear is more than it seems, and it is marked as magic
    Dim i , lub_category , lub_id   As UByte
    Dim luw_record , luw_chance     As UInteger
    Dim lul_flags                   As ULong
    Dim lub_enchanted               As UByte
    Dim ls_where                    As String

    i = 0
    While i < UB_INVENTORY_SIZE
        If Cast( Integer , i ) = gsw_player_pack_unique Then i = UB_PACK_SIZE
        luw_record   = A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE
        lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lub_id       = Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET )
        lul_flags    = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
        ' only things that can be enchanted, 10 to 39 of Moria's categories, not cursed, not already known
        lub_enchanted = false
        If lub_category >= 10 And lub_category <= 39 And ( lul_flags bAnd UL_TR_CURSED ) = 0 And ( lub_id bAnd ( MB_ID_KNOWN2 bOr MB_ID_MAGIK ) ) = 0 Then
            If Peek( Integer , luw_record + UB_ITEM_TO_HIT_OFFSET ) > 0 Or Peek( Integer , luw_record + UB_ITEM_TO_DAMAGE_OFFSET ) > 0 Or Peek( Integer , luw_record + UB_ITEM_TO_AC_OFFSET ) > 0 Then
                lub_enchanted = true
            ElseIf ( lul_flags bAnd $4000107F ) <> 0 And Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) > 0 Then
                lub_enchanted = true
            ElseIf ( lul_flags bAnd $07FFE980 ) <> 0 Then
                lub_enchanted = true
            End If
        End If
        ' if in inventory, succeed 1 out of 50 times, if in equipment list, success 1 out of 10 times
        ' N.B: as in Moria the dice are thrown only for a thing that is enchanted
        If lub_enchanted Then
            luw_chance = 10
            If i < UB_PACK_SIZE Then luw_chance = 50
            If ful_core_random_number( luw_chance ) = 1 Then
                ls_where = "carrying in your pack"
                If i = UB_PACK_SIZE + UB_EQUIP_WIELD Then ls_where = "wielding"
                If i = UB_PACK_SIZE + UB_EQUIP_HEAD Then ls_where = "wearing on your head"
                If i = UB_PACK_SIZE + UB_EQUIP_NECK Then ls_where = "wearing around your neck"
                If i = UB_PACK_SIZE + UB_EQUIP_BODY Then ls_where = "wearing on your body"
                If i = UB_PACK_SIZE + UB_EQUIP_ARM Then ls_where = "wearing on your arm"
                If i = UB_PACK_SIZE + UB_EQUIP_HANDS Then ls_where = "wearing on your hands"
                If i = UB_PACK_SIZE + UB_EQUIP_RIGHT Then ls_where = "wearing on your right hand"
                If i = UB_PACK_SIZE + UB_EQUIP_LEFT Then ls_where = "wearing on your left hand"
                If i = UB_PACK_SIZE + UB_EQUIP_FEET Then ls_where = "wearing on your feet"
                If i = UB_PACK_SIZE + UB_EQUIP_OUTER Then ls_where = "wearing about your body"
                If i = UB_PACK_SIZE + UB_EQUIP_LIGHT Then ls_where = "using to light the way"
                If i = UB_PACK_SIZE + UB_EQUIP_AUXILIARY Then ls_where = "holding ready by your side"
                s_dst_disturb( false , false )
                s_msg( "There's something about what you are " + ls_where + "..." )
                Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , lub_id bOr MB_ID_MAGIK
            End If
        End If
        i = i + 1
    End While
End Sub


Sub s_t2_movement_state()
    ' Moria's printCharacterMovementState()

    If gsw_player_paralysis > 1 Then
        s_core_print_string_at( 23 , 38 , "Paralysed" , UB_BRIGHT_WHITE )
    ElseIf ( gul_player_status bAnd UL_PY_REST ) <> 0 Then
        If gsw_player_rest < 0 Then
            s_core_print_string_at( 23 , 38 , "Rest *    " , UB_BRIGHT_WHITE )
        ElseIf ( guw_game_options bAnd MW_OPTION_DISPLAY_COUNTS ) = 0 Then
            s_core_print_string_at( 23 , 38 , "Rest      " , UB_BRIGHT_WHITE )
        Else
            s_core_print_string_at( 23 , 38 , "Rest " + fs_core_number( gsw_player_rest ) + "    " , UB_BRIGHT_WHITE )
        End If
    ElseIf ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then
        s_core_print_string_at( 23 , 38 , "Searching " , UB_BRIGHT_WHITE )
    ElseIf guw_game_command_count > 0 Then
        ' a command is being repeated, N.B: as in Moria "Searching" is shown instead when both are so
        If ( guw_game_options bAnd MW_OPTION_DISPLAY_COUNTS ) = 0 Then
            s_core_print_string_at( 23 , 38 , "Repeat    " , UB_BRIGHT_WHITE )
        Else
            s_core_print_string_at( 23 , 38 , "Repeat " + fs_core_number( guw_game_command_count ) + "  " , UB_BRIGHT_WHITE )
        End If
    Else
        s_core_print_string_at( 23 , 38 , "          " , UB_WHITE )
    End If
End Sub


Sub s_t2_speed_word()
    ' Moria's printCharacterSpeed(), searching does not count as being slow
    Dim lsw_speed As Integer

    lsw_speed = gsw_player_speed
    If ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then lsw_speed = lsw_speed - 1
    If lsw_speed > 1 Then
        s_core_print_string_at( 23 , 49 , "Very Slow" , UB_BRIGHT_WHITE )
    ElseIf lsw_speed = 1 Then
        s_core_print_string_at( 23 , 49 , "Slow     " , UB_BRIGHT_WHITE )
    ElseIf lsw_speed = 0 Then
        s_core_print_string_at( 23 , 49 , "         " , UB_WHITE )
    ElseIf lsw_speed = -1 Then
        s_core_print_string_at( 23 , 49 , "Fast     " , UB_BRIGHT_WHITE )
    Else
        s_core_print_string_at( 23 , 49 , "Very Fast" , UB_BRIGHT_WHITE )
    End If
End Sub


Sub s_t2_status_line()
    ' every word along the bottom of the screen that applies, for when the whole screen is drawn afresh, the end
    ' of Moria's printCharacterStatsBlock()
    If ( gul_player_status bAnd UL_PY_WEAK ) <> 0 Then
        s_core_print_string_at( 23 , 0 , "Weak  " , UB_BRIGHT_WHITE )
    ElseIf ( gul_player_status bAnd UL_PY_HUNGRY ) <> 0 Then
        s_core_print_string_at( 23 , 0 , "Hungry" , UB_BRIGHT_WHITE )
    End If
    If ( gul_player_status bAnd UL_PY_BLIND ) <> 0 Then s_core_print_string_at( 23 , 7 , "Blind" , UB_BRIGHT_WHITE )
    If ( gul_player_status bAnd UL_PY_CONFUSED ) <> 0 Then s_core_print_string_at( 23 , 13 , "Confused" , UB_BRIGHT_WHITE )
    If ( gul_player_status bAnd UL_PY_FEAR ) <> 0 Then s_core_print_string_at( 23 , 22 , "Afraid" , UB_BRIGHT_WHITE )
    If ( gul_player_status bAnd UL_PY_POISONED ) <> 0 Then s_core_print_string_at( 23 , 29 , "Poisoned" , UB_BRIGHT_WHITE )
    s_t2_movement_state()
    s_t2_speed_word()
    If gub_player_new_spells <> 0 Then s_core_print_string_at( 23 , 59 , "Study" , UB_BRIGHT_WHITE )
End Sub


Sub s_t2_rest_off()
    ' Moria's playerRestOff()
    ' N.B: a monster's turn may already have ended the rest itself, s_mon_disturb() in stage-disturb-include.bas, and
    ' left only the screen to be done
    ' N.B: a rest a monster's turn ended has had its messages flushed already, at that moment, as in Moria
    If gub_game_rest_broken = false Then
        gsw_player_rest   = 0
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_REST )
        gsw_player_food_digested = gsw_player_food_digested + 1
        s_t2_movement_state()
        s_msg_flush()
        s_msg_clear()
    Else
        gub_game_rest_broken = false
        s_t2_movement_state()
    End If
End Sub


'##################################################################################################################################

Sub s_t2_hero()
    ' Moria's playerUpdateHeroStatus(), with the four routines that turn heroism and super heroism on and off
    If gsw_player_heroism > 0 Then
        If ( gul_player_status bAnd UL_PY_HERO ) = 0 Then
            gul_player_status     = gul_player_status bOr UL_PY_HERO
            s_dst_disturb( false , false )
            gsw_player_max_hp     = gsw_player_max_hp + 10
            gsw_player_current_hp = gsw_player_current_hp + 10
            gsw_player_bth        = gsw_player_bth + 12
            gsw_player_bth_bows   = gsw_player_bth_bows + 12
            s_core_message( UW_MSG_YOU_FEEL_LIKE_A_HERO )
            s_t2_block()
        End If
        gsw_player_heroism = gsw_player_heroism - 1
        If gsw_player_heroism = 0 Then
            gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_HERO )
            s_dst_disturb( false , false )
            gsw_player_max_hp = gsw_player_max_hp - 10
            If gsw_player_current_hp > gsw_player_max_hp Then
                gsw_player_current_hp  = gsw_player_max_hp
                guw_player_hp_fraction = 0
            End If
            gsw_player_bth      = gsw_player_bth - 12
            gsw_player_bth_bows = gsw_player_bth_bows - 12
            s_core_message( UW_MSG_THE_HEROISM_WEARS_OFF )
            s_t2_block()
        End If
    End If

    If gsw_player_super_heroism > 0 Then
        If ( gul_player_status bAnd UL_PY_SHERO ) = 0 Then
            gul_player_status     = gul_player_status bOr UL_PY_SHERO
            s_dst_disturb( false , false )
            gsw_player_max_hp     = gsw_player_max_hp + 20
            gsw_player_current_hp = gsw_player_current_hp + 20
            gsw_player_bth        = gsw_player_bth + 24
            gsw_player_bth_bows   = gsw_player_bth_bows + 24
            s_core_message( UW_MSG_YOU_FEEL_LIKE_A_SUPER_HERO )
            s_t2_block()
        End If
        gsw_player_super_heroism = gsw_player_super_heroism - 1
        If gsw_player_super_heroism = 0 Then
            gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_SHERO )
            s_dst_disturb( false , false )
            gsw_player_max_hp = gsw_player_max_hp - 20
            If gsw_player_current_hp > gsw_player_max_hp Then
                gsw_player_current_hp  = gsw_player_max_hp
                guw_player_hp_fraction = 0
            End If
            gsw_player_bth      = gsw_player_bth - 24
            gsw_player_bth_bows = gsw_player_bth_bows - 24
            s_core_message( UW_MSG_THE_SUPER_HEROISM_WEARS_OFF )
            s_t2_block()
        End If
    End If
End Sub


Sub s_t2_speed()
    ' Moria's playerUpdateSpeed(), playerUpdateRestingState() and playerUpdateHallucination()
    If gsw_player_fast > 0 Then
        If ( gul_player_status bAnd UL_PY_FAST ) = 0 Then
            gul_player_status = gul_player_status bOr UL_PY_FAST
            s_t2_change_speed( -1 )
            s_core_message( UW_MSG_YOU_FEEL_YOURSELF_MOVING_FASTER )
            s_dst_disturb( false , false )
        End If
        gsw_player_fast = gsw_player_fast - 1
        If gsw_player_fast = 0 Then
            gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_FAST )
            s_t2_change_speed( 1 )
            s_core_message( UW_MSG_YOU_FEEL_YOURSELF_SLOW_DOWN )
            s_dst_disturb( false , false )
        End If
    End If

    If gsw_player_slow > 0 Then
        If ( gul_player_status bAnd UL_PY_SLOW ) = 0 Then
            gul_player_status = gul_player_status bOr UL_PY_SLOW
            s_t2_change_speed( 1 )
            s_core_message( UW_MSG_YOU_FEEL_YOURSELF_MOVING_SLOWER )
            s_dst_disturb( false , false )
        End If
        gsw_player_slow = gsw_player_slow - 1
        If gsw_player_slow = 0 Then
            gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_SLOW )
            s_t2_change_speed( -1 )
            s_core_message( UW_MSG_YOU_FEEL_YOURSELF_SPEED_UP )
            s_dst_disturb( false , false )
        End If
    End If

    ' resting: for a number of turns, or, when the count is below nothing, until hit points and mana are back
    If gsw_player_rest > 0 Then
        gsw_player_rest = gsw_player_rest - 1
        If gsw_player_rest = 0 Then s_t2_rest_off()
    ElseIf gsw_player_rest < 0 Then
        gsw_player_rest = gsw_player_rest + 1
        If ( gsw_player_current_hp = gsw_player_max_hp And gsw_player_current_mana = gsw_player_mana ) Or gsw_player_rest = 0 Then s_t2_rest_off()
    End If

    If gsw_player_image > 0 Then
        ' Moria's playerEndRunning(): a run ends, nothing else is disturbed
        gub_game_running = 0
        gsw_player_image = gsw_player_image - 1
        If gsw_player_image = 0 Then gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
    End If
End Sub


Sub s_t2_late()
    ' Moria's playerUpdateEvilProtection() and the routines that follow it, down to playerUpdateStatusFlags()
    If gsw_player_protect_evil > 0 Then
        gsw_player_protect_evil = gsw_player_protect_evil - 1
        If gsw_player_protect_evil = 0 Then s_core_message( UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_EVIL )
    End If

    If gsw_player_invulnerability > 0 Then
        If ( gul_player_status bAnd UL_PY_INVULN ) = 0 Then
            gul_player_status     = gul_player_status bOr UL_PY_INVULN
            s_dst_disturb( false , false )
            gsw_player_ac         = gsw_player_ac + 100
            gsw_player_display_ac = gsw_player_display_ac + 100
            s_t2_block()
            s_core_message( UW_MSG_YOUR_SKIN_TURNS_INTO_STEEL )
        End If
        gsw_player_invulnerability = gsw_player_invulnerability - 1
        If gsw_player_invulnerability = 0 Then
            gul_player_status     = gul_player_status bAnd ( $FFFFFFFF - UL_PY_INVULN )
            s_dst_disturb( false , false )
            gsw_player_ac         = gsw_player_ac - 100
            gsw_player_display_ac = gsw_player_display_ac - 100
            s_t2_block()
            s_core_message( UW_MSG_YOUR_SKIN_RETURNS_TO_NORMAL )
        End If
    End If

    If gsw_player_blessed > 0 Then
        If ( gul_player_status bAnd UL_PY_BLESSED ) = 0 Then
            gul_player_status     = gul_player_status bOr UL_PY_BLESSED
            s_dst_disturb( false , false )
            gsw_player_bth        = gsw_player_bth + 5
            gsw_player_bth_bows   = gsw_player_bth_bows + 5
            gsw_player_ac         = gsw_player_ac + 2
            gsw_player_display_ac = gsw_player_display_ac + 2
            s_core_message( UW_MSG_YOU_FEEL_RIGHTEOUS )
            s_t2_block()
        End If
        gsw_player_blessed = gsw_player_blessed - 1
        If gsw_player_blessed = 0 Then
            gul_player_status     = gul_player_status bAnd ( $FFFFFFFF - UL_PY_BLESSED )
            s_dst_disturb( false , false )
            gsw_player_bth        = gsw_player_bth - 5
            gsw_player_bth_bows   = gsw_player_bth_bows - 5
            gsw_player_ac         = gsw_player_ac - 2
            gsw_player_display_ac = gsw_player_display_ac - 2
            s_core_message( UW_MSG_THE_PRAYER_HAS_EXPIRED )
            s_t2_block()
        End If
    End If

    If gsw_player_heat_resistance > 0 Then
        gsw_player_heat_resistance = gsw_player_heat_resistance - 1
        If gsw_player_heat_resistance = 0 Then s_core_message( UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_FLAME )
    End If
    If gsw_player_cold_resistance > 0 Then
        gsw_player_cold_resistance = gsw_player_cold_resistance - 1
        If gsw_player_cold_resistance = 0 Then s_core_message( UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_COLD )
    End If

    ' seeing the invisible for a while, when it wears off whether the player still can depends on what they wear
    If gsw_player_detect_invisible > 0 Then
        If ( gul_player_status bAnd UL_PY_DET_INV ) = 0 Then
            gul_player_status        = gul_player_status bOr UL_PY_DET_INV
            gub_player_see_invisible = true
            gub_game_turn_flags      = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
        End If
        gsw_player_detect_invisible = gsw_player_detect_invisible - 1
        If gsw_player_detect_invisible = 0 Then
            gul_player_status   = gul_player_status bAnd ( $FFFFFFFF - UL_PY_DET_INV )
            s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
            gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
        End If
    End If

    If gsw_player_timed_infra > 0 Then
        If ( gul_player_status bAnd UL_PY_TIM_INFRA ) = 0 Then
            gul_player_status    = gul_player_status bOr UL_PY_TIM_INFRA
            gsw_player_see_infra = gsw_player_see_infra + 1
            gub_game_turn_flags  = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
        End If
        gsw_player_timed_infra = gsw_player_timed_infra - 1
        If gsw_player_timed_infra = 0 Then
            gul_player_status    = gul_player_status bAnd ( $FFFFFFFF - UL_PY_TIM_INFRA )
            gsw_player_see_infra = gsw_player_see_infra - 1
            gub_game_turn_flags  = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
        End If
    End If

    ' the word of recall: when its time comes the player is taken to the town, or from the town to the deepest
    ' level they have reached
    If gsw_player_word_of_recall > 0 Then
        If gsw_player_word_of_recall = 1 Then
            gub_game_turn_flags       = gub_game_turn_flags bOr MB_TURN_NEW_LEVEL
            gsw_player_paralysis      = gsw_player_paralysis + 1
            gsw_player_word_of_recall = 0
            If guw_dungeon_level > 0 Then
                guw_dungeon_level = 0
                s_core_message( UW_MSG_YOU_FEEL_YOURSELF_YANKED_UPWARDS )
            ElseIf guw_player_max_depth <> 0 Then
                guw_dungeon_level = guw_player_max_depth
                s_core_message( UW_MSG_YOU_FEEL_YOURSELF_YANKED_DOWNWARDS )
            End If
        Else
            gsw_player_word_of_recall = gsw_player_word_of_recall - 1
        End If
    End If

    ' random teleportation, 1 chance in 100 each turn for those cursed with it
    ' N.B: as in Moria the dice are thrown only for those who are
    If gub_player_teleport Then
        If ful_core_random_number( 100 ) = 1 Then
            s_dst_disturb( false , false )
            guw_lib_param_2  = 40
            s_core_call_library( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT )
        End If
    End If

    ' see if we are too weak to handle the weapon or pack
    If ( gul_player_status bAnd UL_PY_STR_WGT ) <> 0 Then s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )

    ' Moria's printCharacterStudyInstruction()
    If ( gul_player_status bAnd UL_PY_STUDY ) <> 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_STUDY )
        If gub_player_new_spells = 0 Then
            s_core_print_string_at( 23 , 59 , "     " , UB_WHITE )
        Else
            s_core_print_string_at( 23 , 59 , "Study" , UB_BRIGHT_WHITE )
        End If
    End If

    ' Moria's playerUpdateStatusFlags(), the parts of it that are words on the bottom row, the figures on the left
    ' of the screen are shown again by whoever changes them
    If ( gul_player_status bAnd UL_PY_SPEED ) <> 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_SPEED )
        s_t2_speed_word()
    End If

    If ( gul_player_status bAnd UL_PY_PARALYSED ) <> 0 And gsw_player_paralysis < 1 Then
        s_t2_movement_state()
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_PARALYSED )
    ElseIf gsw_player_paralysis > 0 Then
        s_t2_movement_state()
        gul_player_status = gul_player_status bOr UL_PY_PARALYSED
    ElseIf gsw_player_rest <> 0 Then
        s_t2_movement_state()
    End If

    ' allow for a slim chance of detect enchantment: for a 1st level character once every 2160 turns, for a 40th
    ' level one once every 416, N.B: as in Moria the dice are thrown only on every sixteenth turn, and only if
    ' the player has their wits about them
    If ( gsl_game_turn bAnd 15 ) = 0 And gsw_player_confused = 0 Then
        If ful_core_random_number( 10 + 750 / ( 5 + guw_player_level ) ) = 1 Then s_t2_detect_enchantment()
    End If

    ' check the state of the monster list, and delete some monsters if the monster list is nearly full, this
    ' helps to avoid problems when monsters try to multiply
    If UB_MON_TOTAL_ALLOCATIONS - gub_dungeon_monster_next < 10 Then s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_MONSTERS )
End Sub


Sub s_lib_turn_2()
    Dim lub_saved_page As UByte

    lub_saved_page = gub_core_MMU0_page_number
    If gub_lib_function = UB_LIB_TURN_2_HERO Then
        s_t2_hero()
    ElseIf gub_lib_function = UB_LIB_TURN_2_SPEED Then
        s_t2_speed()
    ElseIf gub_lib_function = UB_LIB_TURN_2_LATE Then
        s_t2_late()
    ElseIf gub_lib_function = UB_LIB_TURN_2_REST_OFF Then
        s_t2_rest_off()
    ElseIf gub_lib_function = UB_LIB_TURN_2_MOVEMENT_STATE Then
        s_t2_movement_state()
    ElseIf gub_lib_function = UB_LIB_TURN_2_STATUS_LINE Then
        s_t2_status_line()
    ElseIf gub_lib_function = UB_LIB_TURN_2_CHANGE_SPEED Then
        s_t2_change_speed( Cast( Integer , guw_lib_param_2 ) )
    End If
    If lub_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page )
End Sub
