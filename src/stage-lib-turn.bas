#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_turn()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: what happens to the player as each turn begins, the things that wear off, from
' the start of Moria's playDungeon() (game_run.cpp)...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_TURN , <which routine> ),
' the one routine is:
'
'   UB_LIB_TURN_EFFECTS     a turn goes by: the player gets hungrier, and a little of their hit points comes back,
'                           then whatever they are suffering from: blindness, confusion, fear,
'                           poison and paralysis each count down, poison hurts, and the words along the bottom of
'                           the screen that say so come and go, what the walking stage must do afterwards comes
'                           back in gsw_lib_result, the MB_TURN_ bits in constants.bas
'
' the words are on the bottom row of the screen, at Moria's columns: Hungry or Weak 0, Blind 7, Confused 13, Afraid 22, Poisoned 29,
' the rest are the second page's
'
' the rest of what Moria does as a turn begins is in the second page, stage-lib-turn-2.bas, this page calls it at the
' right moments, so that everything happens in Moria's order
'
' what is NOT here yet:
'   - nothing that is known of
'
' N.B: each change that Moria answers with playerDisturb() does so here too, at the same moment, s_dst_disturb() in
' stage-disturb-include.bas: a rest it ends must be over before this turn's healing, which goes by it

Sub s_tn_word( pub_col As UByte , ps_word As String , pub_on As UByte )
    ' shows one of the words along the bottom of the screen, or rubs it out
    Dim i As UByte

    If pub_on Then
        s_core_print_string_at( 23 , pub_col , ps_word , UB_BRIGHT_WHITE )
    Else
        For i = 0 To Len( ps_word ) - 1
            s_core_print_char_at( 23 , pub_col + i , 32 , UB_WHITE )
        Next
    End If
End Sub


Function fub_tn_blindness() As UByte
    ' Moria's playerUpdateBlindness(), true if the map needs drawing again
    Dim lub_redraw As UByte = false

    If gsw_player_blind <= 0 Then Return false
    If ( gul_player_status bAnd UL_PY_BLIND ) = 0 Then
        gul_player_status = gul_player_status bOr UL_PY_BLIND
        s_tn_word( 7 , "Blind" , true )
        lub_redraw = true
        s_dst_disturb( false , true )
    End If
    gsw_player_blind = gsw_player_blind - 1
    If gsw_player_blind = 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_BLIND )
        s_tn_word( 7 , "Blind" , false )
        lub_redraw = true
        s_dst_disturb( false , true )
        s_core_message( UW_MSG_THE_VEIL_OF_DARKNESS_LIFTS )
    End If
    Return lub_redraw
End Function


Sub s_tn_confusion()
    ' Moria's playerUpdateConfusion()
    If gsw_player_confused <= 0 Then Return
    If ( gul_player_status bAnd UL_PY_CONFUSED ) = 0 Then
        gul_player_status = gul_player_status bOr UL_PY_CONFUSED
        s_tn_word( 13 , "Confused" , true )
    End If
    gsw_player_confused = gsw_player_confused - 1
    If gsw_player_confused = 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_CONFUSED )
        s_tn_word( 13 , "Confused" , false )
        s_core_message( UW_MSG_YOU_FEEL_LESS_CONFUSED_NOW )
        ' N.B: not a disturbance, Moria only ends a rest here
        If gsw_player_rest <> 0 Then s_dst_rest_off()
    End If
End Sub


Sub s_tn_fear()
    ' Moria's playerUpdateFearState(): a hero is never afraid for long
    If gsw_player_afraid <= 0 Then Return
    If ( gul_player_status bAnd UL_PY_FEAR ) = 0 Then
        If gsw_player_super_heroism + gsw_player_heroism > 0 Then
            gsw_player_afraid = 0
        Else
            gul_player_status = gul_player_status bOr UL_PY_FEAR
            s_tn_word( 22 , "Afraid" , true )
        End If
    ElseIf gsw_player_super_heroism + gsw_player_heroism > 0 Then
        gsw_player_afraid = 1
    End If
    gsw_player_afraid = gsw_player_afraid - 1
    If gsw_player_afraid = 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_FEAR )
        s_tn_word( 22 , "Afraid" , false )
        s_core_message( UW_MSG_YOU_FEEL_BOLDER_NOW )
        s_dst_disturb( false , false )
    End If
End Sub


Sub s_tn_poison()
    ' Moria's playerUpdatePoisonedState(): poison hurts every turn, or every few turns if the player is hardy
    Dim lsw_con , lsw_damage As Integer

    If gsw_player_poisoned <= 0 Then Return
    If ( gul_player_status bAnd UL_PY_POISONED ) = 0 Then
        gul_player_status = gul_player_status bOr UL_PY_POISONED
        s_tn_word( 29 , "Poisoned" , true )
    End If
    gsw_player_poisoned = gsw_player_poisoned - 1
    If gsw_player_poisoned = 0 Then
        gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_POISONED )
        s_tn_word( 29 , "Poisoned" , false )
        s_core_message( UW_MSG_YOU_FEEL_BETTER )
        s_dst_disturb( false , false )
        Return
    End If

    ' what constitution does for hit points, it does for this too
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_CON )
    lsw_con    = gsw_lib_result
    lsw_damage = 0
    If lsw_con = -4 Then
        lsw_damage = 4
    ElseIf lsw_con = -3 Or lsw_con = -2 Then
        lsw_damage = 3
    ElseIf lsw_con = -1 Then
        lsw_damage = 2
    ElseIf lsw_con = 0 Then
        lsw_damage = 1
    ElseIf lsw_con >= 1 And lsw_con <= 3 Then
        If ( gsl_game_turn Mod 2 ) = 0 Then lsw_damage = 1
    ElseIf lsw_con = 4 Or lsw_con = 5 Then
        If ( gsl_game_turn Mod 3 ) = 0 Then lsw_damage = 1
    ElseIf lsw_con = 6 Then
        If ( gsl_game_turn Mod 4 ) = 0 Then lsw_damage = 1
    End If
    s_hit_killer( "poison" )
    s_hit_player( lsw_damage )
    s_dst_disturb( true , false )
End Sub


Sub s_tn_hunger_word()
    ' Moria's printCharacterHungerStatus()
    If ( gul_player_status bAnd UL_PY_WEAK ) <> 0 Then
        s_core_print_string_at( 23 , 0 , "Weak  " , UB_BRIGHT_WHITE )
    ElseIf ( gul_player_status bAnd UL_PY_HUNGRY ) <> 0 Then
        s_core_print_string_at( 23 , 0 , "Hungry" , UB_BRIGHT_WHITE )
    Else
        s_core_print_string_at( 23 , 0 , "      " , UB_WHITE )
    End If
End Sub


Function fsw_tn_food() As Integer
    ' Moria's playerFoodConsumption(): the food in the player's belly is used up a little each turn, as it runs low
    ' they are warned, then weaken, then faint, and with none left they starve, what comes back is how fast they
    ' will heal this turn, a hungry player heals slowly
    Dim lsw_regen As Integer = 197              ' PLAYER_REGEN_NORMAL

    If gsw_player_food < 2000 Then              ' PLAYER_FOOD_ALERT
        If gsw_player_food < 1000 Then          ' PLAYER_FOOD_WEAK
            If gsw_player_food < 0 Then
                lsw_regen = 0
            ElseIf gsw_player_food < 300 Then   ' PLAYER_FOOD_FAINT
                lsw_regen = 33                  ' PLAYER_REGEN_FAINT
            Else
                lsw_regen = 98                  ' PLAYER_REGEN_WEAK
            End If
            If ( gul_player_status bAnd UL_PY_WEAK ) = 0 Then
                gul_player_status = gul_player_status bOr UL_PY_WEAK
                s_core_message( UW_MSG_YOU_ARE_GETTING_WEAK_FROM_HUNGER )
                s_dst_disturb( false , false )
                s_tn_hunger_word()
            End If
            If gsw_player_food < 300 Then
                If ful_core_random_number( 8 ) = 1 Then
                    gsw_player_paralysis = gsw_player_paralysis + ful_core_random_number( 5 )
                    s_core_message( UW_MSG_YOU_FAINT_FROM_THE_LACK_OF_FOOD )
                    s_dst_disturb( true , false )
                End If
            End If
        ElseIf ( gul_player_status bAnd UL_PY_HUNGRY ) = 0 Then
            gul_player_status = gul_player_status bOr UL_PY_HUNGRY
            s_core_message( UW_MSG_YOU_ARE_GETTING_HUNGRY )
            s_dst_disturb( false , false )
            s_tn_hunger_word()
        End If
    End If

    ' food consumption, note: sped up characters really burn up the food!
    If gsw_player_speed < 0 Then gsw_player_food = gsw_player_food - gsw_player_speed * gsw_player_speed
    gsw_player_food = gsw_player_food - gsw_player_food_digested
    If gsw_player_food < 0 Then
        s_hit_killer( "starvation" )
        s_hit_player( -gsw_player_food / 16 )
        s_dst_disturb( true , false )
    End If
    Return lsw_regen
End Function


Sub s_tn_regenerate( psw_amount As Integer )
    ' Moria's playerUpdateRegeneration() and playerRegenerateHitPoints(): a little of the player's hit points
    ' comes back each turn, in 65536ths of a point, faster for those who heal fast, are searching or resting, and
    ' not at all while poisoned
    Dim lsl_new         As Long
    Dim lsw_old         As Integer

    If gub_player_regenerate_hp Then psw_amount = psw_amount * 3 / 2
    If ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Or gsw_player_rest <> 0 Then psw_amount = psw_amount * 2

    If gsw_player_poisoned < 1 And gsw_player_current_hp < gsw_player_max_hp Then
        lsw_old = gsw_player_current_hp
        lsl_new = Cast( Long , gsw_player_max_hp ) * psw_amount + 1442         ' PLAYER_REGEN_HPBASE
        gsw_player_current_hp = gsw_player_current_hp + ( lsl_new >> 16 )
        lsl_new = ( lsl_new bAnd $FFFF ) + guw_player_hp_fraction
        If lsl_new >= 65536 Then
            guw_player_hp_fraction = lsl_new - 65536
            gsw_player_current_hp  = gsw_player_current_hp + 1
        Else
            guw_player_hp_fraction = lsl_new
        End If
        If gsw_player_current_hp >= gsw_player_max_hp Then
            gsw_player_current_hp  = gsw_player_max_hp
            guw_player_hp_fraction = 0
        End If
        ' the new figure is shown, Moria's printCharacterCurrentHitPoints(), by way of a hit of nothing
        If lsw_old <> gsw_player_current_hp And gsw_player_invulnerability <= 0 Then s_hit_player( 0 )
    End If

    ' mana comes back the same way, Moria's playerRegenerateMana()
    If gsw_player_current_mana < gsw_player_mana Then
        lsw_old = gsw_player_current_mana
        lsl_new = Cast( Long , gsw_player_mana ) * psw_amount + 524            ' PLAYER_REGEN_MNBASE
        gsw_player_current_mana = gsw_player_current_mana + ( lsl_new >> 16 )
        lsl_new = ( lsl_new bAnd $FFFF ) + guw_player_mana_fraction
        If lsl_new >= 65536 Then
            guw_player_mana_fraction = lsl_new - 65536
            gsw_player_current_mana  = gsw_player_current_mana + 1
        Else
            guw_player_mana_fraction = lsl_new
        End If
        If gsw_player_current_mana >= gsw_player_mana Then
            gsw_player_current_mana  = gsw_player_mana
            guw_player_mana_fraction = 0
        End If
        If lsw_old <> gsw_player_current_mana Then s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
    End If
End Sub


Sub s_lib_turn()
    If gub_lib_function <> UB_LIB_TURN_EFFECTS Then Return
    ' everything is done in the order Moria does it, the parts that are in the second page are called for in their turn
    ' N.B: gub_game_turn_flags is not cleared here, the walking stage clears it as it acts on it, and it may already
    ' hold what this turn's light asked for
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_HERO )
    s_tn_regenerate( fsw_tn_food() )
    If fub_tn_blindness() Then gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_REDRAW_MAP
    s_tn_confusion()
    s_tn_fear()
    s_tn_poison()
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_SPEED )
    ' Moria's playerUpdateParalysis()
    If gsw_player_paralysis > 0 Then
        gsw_player_paralysis = gsw_player_paralysis - 1
        s_dst_disturb( true , false )
    End If
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_LATE )
    gsw_lib_result = gub_game_turn_flags
End Sub