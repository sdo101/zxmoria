#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_bonuses()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: what everything the player is wearing adds up to...
' ...any stage or library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_BONUSES , <which routine> ), the routine is:
'
'   UB_LIB_BONUSES_RECALC   works out afresh the player's plusses to hit and damage, their armour class, and the
'                           abilities their equipment gives, from everything worn, Moria's playerRecalculateBonuses(),
'                           it is wanted whenever what is worn changes, and by spells and potions that change these things
'
' N.B: the equipment is places 22 to 33 of the one list of 34 records at A_INVENTORY


Function fuw_bn_record( pub_place As UByte ) As UInteger
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function

Sub s_bn_recalc()
    ' Moria's playerRecalculateBonuses(): everything that depends on all that is worn, taken together, is worked out
    ' afresh: the plusses to hit and damage, the armour class, and the abilities that items give
    Dim i , lub_category , lub_identified   As UByte
    Dim luw_record                          As UInteger
    Dim lul_flags , lul_all                 As ULong
    Dim lsw_misc                            As Integer

    If gub_player_slow_digest Then gsw_player_food_digested = gsw_player_food_digested + 1
    If gub_player_regenerate_hp Then gsw_player_food_digested = gsw_player_food_digested - 3

    ' Moria's playerResetFlags()
    gub_player_see_invisible = false
    gub_player_teleport      = false
    gub_player_free_action   = false
    gub_player_slow_digest   = false
    gub_player_aggravate     = false
    gub_player_sustain_str   = false
    gub_player_sustain_int   = false
    gub_player_sustain_wis   = false
    gub_player_sustain_con   = false
    gub_player_sustain_dex   = false
    gub_player_sustain_chr   = false
    gub_player_resist_fire   = false
    gub_player_resist_acid   = false
    gub_player_resist_cold   = false
    gub_player_regenerate_hp = false
    gub_player_resist_light  = false
    gub_player_free_fall     = false

    ' what the stats alone give, the character library has the tables
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_TO_HIT )
    gsw_player_to_hit = gsw_lib_result
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DAMAGE )
    gsw_player_to_damage = gsw_lib_result
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_AC )
    gsw_player_magical_ac = gsw_lib_result
    gsw_player_ac = 0
    gsw_player_display_to_hit = gsw_player_to_hit
    gsw_player_display_to_dam = gsw_player_to_damage
    gsw_player_display_ac     = 0
    gsw_player_display_to_ac  = gsw_player_magical_ac

    ' ...then everything worn, all but the light and the spare weapon, Moria's playerRecalculateBonusesFromInventory(),
    ' inventoryCollectAllItemFlags() and playerRecalculateSustainStatsFromInventory()
    ' N.B: what the player is shown counts only what they know: an unidentified thing shows its plain armour class
    lul_all = 0
    For i = UB_PACK_SIZE To UB_PACK_SIZE + UB_EQUIP_LIGHT - 1
        luw_record   = fuw_bn_record( i )
        lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lul_flags    = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
        If lub_category <> 0 Then
            lub_identified = false
            If ( Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bAnd MB_ID_KNOWN2 ) <> 0 Then lub_identified = true
            gsw_player_to_hit = gsw_player_to_hit + Peek( Integer , luw_record + UB_ITEM_TO_HIT_OFFSET )
            If lub_category <> UB_TV_BOW Then gsw_player_to_damage = gsw_player_to_damage + Peek( Integer , luw_record + UB_ITEM_TO_DAMAGE_OFFSET )
            gsw_player_magical_ac = gsw_player_magical_ac + Peek( Integer , luw_record + UB_ITEM_TO_AC_OFFSET )
            gsw_player_ac = gsw_player_ac + Peek( Integer , luw_record + UB_ITEM_AC_OFFSET )
            If lub_identified Then
                gsw_player_display_to_hit = gsw_player_display_to_hit + Peek( Integer , luw_record + UB_ITEM_TO_HIT_OFFSET )
                If lub_category <> UB_TV_BOW Then gsw_player_display_to_dam = gsw_player_display_to_dam + Peek( Integer , luw_record + UB_ITEM_TO_DAMAGE_OFFSET )
                gsw_player_display_to_ac = gsw_player_display_to_ac + Peek( Integer , luw_record + UB_ITEM_TO_AC_OFFSET )
                gsw_player_display_ac    = gsw_player_display_ac + Peek( Integer , luw_record + UB_ITEM_AC_OFFSET )
            ElseIf ( lul_flags bAnd UL_TR_CURSED ) = 0 Then
                gsw_player_display_ac = gsw_player_display_ac + Peek( Integer , luw_record + UB_ITEM_AC_OFFSET )
            End If
        End If
        lul_all = lul_all bOr lul_flags
        If ( lul_flags bAnd UL_TR_SUST_STAT ) <> 0 Then
            lsw_misc = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
            If lsw_misc = 1 Then gub_player_sustain_str = true
            If lsw_misc = 2 Then gub_player_sustain_int = true
            If lsw_misc = 3 Then gub_player_sustain_wis = true
            If lsw_misc = 4 Then gub_player_sustain_con = true
            If lsw_misc = 5 Then gub_player_sustain_dex = true
            If lsw_misc = 6 Then gub_player_sustain_chr = true
        End If
    Next
    gsw_player_display_ac = gsw_player_display_ac + gsw_player_display_to_ac

    If gub_player_weapon_heavy Then
        gsw_player_display_to_hit = gsw_player_display_to_hit + ( Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) * 15 - Peek( Integer , fuw_bn_record( UB_PACK_SIZE + UB_EQUIP_WIELD ) + UB_ITEM_WEIGHT_OFFSET ) )
    End If
    ' Add in temporary spell increases
    If gsw_player_invulnerability > 0 Then
        gsw_player_ac         = gsw_player_ac + 100
        gsw_player_display_ac = gsw_player_display_ac + 100
    End If
    If gsw_player_blessed > 0 Then
        gsw_player_ac         = gsw_player_ac + 2
        gsw_player_display_ac = gsw_player_display_ac + 2
    End If
    If gsw_player_detect_invisible > 0 Then gub_player_see_invisible = true

    If ( lul_all bAnd UL_TR_SLOW_DIGEST ) <> 0 Then gub_player_slow_digest = true
    If ( lul_all bAnd UL_TR_AGGRAVATE ) <> 0 Then gub_player_aggravate = true
    If ( lul_all bAnd UL_TR_TELEPORT ) <> 0 Then gub_player_teleport = true
    If ( lul_all bAnd UL_TR_REGEN ) <> 0 Then gub_player_regenerate_hp = true
    If ( lul_all bAnd UL_TR_RES_FIRE ) <> 0 Then gub_player_resist_fire = true
    If ( lul_all bAnd UL_TR_RES_ACID ) <> 0 Then gub_player_resist_acid = true
    If ( lul_all bAnd UL_TR_RES_COLD ) <> 0 Then gub_player_resist_cold = true
    If ( lul_all bAnd UL_TR_FREE_ACT ) <> 0 Then gub_player_free_action = true
    If ( lul_all bAnd UL_TR_SEE_INVIS ) <> 0 Then gub_player_see_invisible = true
    If ( lul_all bAnd UL_TR_RES_LIGHT ) <> 0 Then gub_player_resist_light = true
    If ( lul_all bAnd UL_TR_FFALL ) <> 0 Then gub_player_free_fall = true

    If gub_player_slow_digest Then gsw_player_food_digested = gsw_player_food_digested - 1
    If gub_player_regenerate_hp Then gsw_player_food_digested = gsw_player_food_digested + 3
End Sub


Sub s_lib_bonuses()
    If gub_lib_function = UB_LIB_BONUSES_RECALC Then s_bn_recalc()
End Sub