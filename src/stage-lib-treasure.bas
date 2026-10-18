#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_treasure()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-lib-treasure-include.bas"

' this page is a LIBRARY, not a stage: it gives a newly made item its magic, Moria's treasure.cpp...
' ...any stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_TREASURE , <which routine> ), the routines are:
'
'   UB_LIB_TREASURE_MAGIC   works on the working item (A_ITEM), which must be fresh from the objects database: armour
'                           and weapons may get plusses and a special name, or a curse, rings and amulets get their
'                           strength, wands and staffs their charges, arrows their number..., guw_lib_param_2 is the
'                           level to make it for, the deeper the level the better (and the worse) things get,
'                           this is Moria's magicTreasureMagicalAbility()
'   UB_LIB_TREASURE_TEST    shows a screenful of items made this way, for checking this page
'
' it takes two pages: this one has body armour, shields, gloves, boots, cloaks and weapons, stage-lib-treasure-2.bas has helms,
' rings, amulets, wands, staffs, chests and missiles, and this page hands those on to it, a stage only ever calls this one
'
' N.B: nearly all of this file was turned into BASIC from the Moria source by a script, statement for statement, so
' that nothing was mistyped, which is why it reads a little mechanically: a C "switch" has become a chain of
' If ... ElseIf on a variable called lsw_select_n, and every routine says which of Moria's it is
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Sub s_mt_magical_armor( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalArmor()
    Dim lsw_select_1 As Integer

    gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 30, psw_level) )
    If fub_mt_should(psw_special) = false Then
        Return
    End If
    lsw_select_1 = fsw_mt_random(9)
    If lsw_select_1 = 1 Then
        gul_item_flags = gul_item_flags bOr ( (UL_TR_RES_LIGHT bOr UL_TR_RES_COLD bOr UL_TR_RES_ACID bOr UL_TR_RES_FIRE) )
        gub_item_special_name = UB_SN_R
        gsw_item_to_ac = gsw_item_to_ac + ( 5 )
        gsl_item_cost = gsl_item_cost + ( 2500 )
    ElseIf lsw_select_1 = 2 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_RES_ACID )
        gub_item_special_name = UB_SN_RA
        gsl_item_cost = gsl_item_cost + ( 1000 )
    ElseIf lsw_select_1 = 3 Or lsw_select_1 = 4 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_RES_FIRE )
        gub_item_special_name = UB_SN_RF
        gsl_item_cost = gsl_item_cost + ( 600 )
    ElseIf lsw_select_1 = 5 Or lsw_select_1 = 6 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_RES_COLD )
        gub_item_special_name = UB_SN_RC
        gsl_item_cost = gsl_item_cost + ( 600 )
    ElseIf lsw_select_1 = 7 Or lsw_select_1 = 8 Or lsw_select_1 = 9 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_RES_LIGHT )
        gub_item_special_name = UB_SN_RL
        gsl_item_cost = gsl_item_cost + ( 500 )
    End If
End Sub


Sub s_mt_cursed_armor( psw_level As Integer )
    ' Moria's cursedArmor()
    gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(1, 40, psw_level) )
    gsl_item_cost = 0
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
End Sub


Sub s_mt_magical_sword( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalSword()
    Dim lsw_damage_bonus , lsw_select_1 As Integer

    gsw_item_to_hit = gsw_item_to_hit + ( fsw_mt_bonus(0, 40, psw_level) )
    lsw_damage_bonus = ( Cast( Integer , gub_item_damage_dice ) * gub_item_damage_sides )
    gsw_item_to_damage = gsw_item_to_damage + ( fsw_mt_bonus(0, 4 * lsw_damage_bonus, lsw_damage_bonus * psw_level / 10) )
    If fub_mt_should(3 * psw_special / 2) Then
        lsw_select_1 = fsw_mt_random(16)
        If lsw_select_1 = 1 Then
            gul_item_flags = gul_item_flags bOr ( (UL_TR_SEE_INVIS bOr UL_TR_SUST_STAT bOr UL_TR_SLAY_UNDEAD bOr UL_TR_SLAY_EVIL bOr UL_TR_STR) )
            gsw_item_to_hit = gsw_item_to_hit + ( 5 )
            gsw_item_to_damage = gsw_item_to_damage + ( 5 )
            gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_random(4) )
            gsw_item_misc_use = fsw_mt_random(4)
            gub_item_special_name = UB_SN_HA
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 500 )
            gsl_item_cost = gsl_item_cost + ( 10000 )
        ElseIf lsw_select_1 = 2 Then
            gul_item_flags = gul_item_flags bOr ( (UL_TR_FFALL bOr UL_TR_RES_LIGHT bOr UL_TR_SEE_INVIS bOr UL_TR_FREE_ACT bOr UL_TR_RES_COLD bOr UL_TR_RES_ACID bOr UL_TR_RES_FIRE bOr UL_TR_REGEN bOr UL_TR_STEALTH) )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gsw_item_to_ac = gsw_item_to_ac + ( 5 + fsw_mt_random(5) )
            gub_item_special_name = UB_SN_DF
            gsw_item_misc_use = fsw_mt_random(3)
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 500 )
            gsl_item_cost = gsl_item_cost + ( 7500 )
        ElseIf lsw_select_1 = 3 Or lsw_select_1 = 4 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_ANIMAL )
            gsw_item_to_hit = gsw_item_to_hit + ( 2 )
            gsw_item_to_damage = gsw_item_to_damage + ( 2 )
            gub_item_special_name = UB_SN_SA
            gsl_item_cost = gsl_item_cost + ( 3000 )
        ElseIf lsw_select_1 = 5 Or lsw_select_1 = 6 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_DRAGON )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_SD
            gsl_item_cost = gsl_item_cost + ( 4000 )
        ElseIf lsw_select_1 = 7 Or lsw_select_1 = 8 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_EVIL )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_SE
            gsl_item_cost = gsl_item_cost + ( 4000 )
        ElseIf lsw_select_1 = 9 Or lsw_select_1 = 10 Then
            gul_item_flags = gul_item_flags bOr ( (UL_TR_SEE_INVIS bOr UL_TR_SLAY_UNDEAD) )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_SU
            gsl_item_cost = gsl_item_cost + ( 5000 )
        ElseIf lsw_select_1 = 11 Or lsw_select_1 = 12 Or lsw_select_1 = 13 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_FLAME_TONGUE )
            gsw_item_to_hit = gsw_item_to_hit + 1
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_FT
            gsl_item_cost = gsl_item_cost + ( 2000 )
        ElseIf lsw_select_1 = 14 Or lsw_select_1 = 15 Or lsw_select_1 = 16 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_FROST_BRAND )
            gsw_item_to_hit = gsw_item_to_hit + 1
            gsw_item_to_damage = gsw_item_to_damage + 1
            gub_item_special_name = UB_SN_FB
            gsl_item_cost = gsl_item_cost + ( 1200 )
        End If
    End If
End Sub


Sub s_mt_cursed_sword( psw_level As Integer )
    ' Moria's cursedSword()
    Dim lsw_damage_bonus As Integer

    gsw_item_to_hit = gsw_item_to_hit - ( fsw_mt_bonus(1, 55, psw_level) )
    lsw_damage_bonus = ( Cast( Integer , gub_item_damage_dice ) * gub_item_damage_sides )
    gsw_item_to_damage = gsw_item_to_damage - ( fsw_mt_bonus(1, 11 * lsw_damage_bonus / 2, lsw_damage_bonus * psw_level / 10) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
    gsl_item_cost = 0
End Sub


Sub s_mt_magical_bow( psw_level As Integer )
    ' Moria's magicalBow()
    gsw_item_to_hit = gsw_item_to_hit + ( fsw_mt_bonus(1, 30, psw_level) )
    gsw_item_to_damage = gsw_item_to_damage + ( fsw_mt_bonus(1, 20, psw_level) )
End Sub


Sub s_mt_cursed_bow( psw_level As Integer )
    ' Moria's cursedBow()
    gsw_item_to_hit = gsw_item_to_hit - ( fsw_mt_bonus(1, 50, psw_level) )
    gsw_item_to_damage = gsw_item_to_damage - ( fsw_mt_bonus(1, 30, psw_level) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
    gsl_item_cost = 0
End Sub


Sub s_mt_magical_digging_tool( psw_level As Integer )
    ' Moria's magicalDiggingTool()
    gsw_item_misc_use = gsw_item_misc_use + ( fsw_mt_bonus(0, 25, psw_level) )
End Sub


Sub s_mt_cursed_digging_tool( psw_level As Integer )
    ' Moria's cursedDiggingTool()
    gsw_item_misc_use = -fsw_mt_bonus(1, 30, psw_level)
    gsl_item_cost = 0
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
End Sub


Sub s_mt_magical_gloves( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalGloves()
    gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
    If fub_mt_should(psw_special) = false Then
        Return
    End If
    If fsw_mt_random(2) = 1 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_FREE_ACT )
        gub_item_special_name = UB_SN_FREE_ACTION
        gsl_item_cost = gsl_item_cost + ( 1000 )
    Else
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        gsw_item_to_hit = gsw_item_to_hit + ( 1 + fsw_mt_random(3) )
        gsw_item_to_damage = gsw_item_to_damage + ( 1 + fsw_mt_random(3) )
        gub_item_special_name = UB_SN_SLAYING
        gsl_item_cost = gsl_item_cost + ( (Cast( Long , gsw_item_to_hit ) + Cast( Long , gsw_item_to_damage )) * 250 )
    End If
End Sub


Sub s_mt_cursed_gloves( psw_special As Integer , psw_level As Integer )
    ' Moria's cursedGloves()
    If fub_mt_should(psw_special) Then
        If fsw_mt_random(2) = 1 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_DEX )
            gub_item_special_name = UB_SN_CLUMSINESS
        Else
            gul_item_flags = gul_item_flags bOr ( UL_TR_STR )
            gub_item_special_name = UB_SN_WEAKNESS
        End If
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -fsw_mt_bonus(1, 10, psw_level)
    End If
    gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(1, 40, psw_level) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
    gsl_item_cost = 0
End Sub


Sub s_mt_magical_boots( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalBoots()
    Dim lsw_magic_type As Integer

    gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
    If fub_mt_should(psw_special) = false Then
        Return
    End If
    lsw_magic_type = fsw_mt_random(12)
    If lsw_magic_type > 5 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_FFALL )
        gub_item_special_name = UB_SN_SLOW_DESCENT
        gsl_item_cost = gsl_item_cost + ( 250 )
    ElseIf lsw_magic_type = 1 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_SPEED )
        gub_item_special_name = UB_SN_SPEED
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = 1
        gsl_item_cost = gsl_item_cost + ( 5000 )
    Else
        gul_item_flags = gul_item_flags bOr ( UL_TR_STEALTH )
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = fsw_mt_random(3)
        gub_item_special_name = UB_SN_STEALTH
        gsl_item_cost = gsl_item_cost + ( 500 )
    End If
End Sub


Sub s_mt_cursed_boots( psw_level As Integer )
    ' Moria's cursedBoots()
    Dim lsw_magic_type , lsw_select_1 As Integer

    lsw_magic_type = fsw_mt_random(3)
    lsw_select_1 = lsw_magic_type
    If lsw_select_1 = 1 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_SPEED )
        gub_item_special_name = UB_SN_SLOWNESS
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -1
    ElseIf lsw_select_1 = 2 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_AGGRAVATE )
        gub_item_special_name = UB_SN_NOISE
    Else
        gub_item_special_name = UB_SN_GREAT_MASS
        guw_item_weight = (guw_item_weight * 5)
    End If
    gsl_item_cost = 0
    gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(2, 45, psw_level) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
End Sub


Sub s_mt_magical_cloak( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalCloak()
    If fub_mt_should(psw_special) = false Then
        gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
        Return
    End If
    If fsw_mt_random(2) = 1 Then
        gub_item_special_name = UB_SN_PROTECTION
        gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(2, 40, psw_level) )
        gsl_item_cost = gsl_item_cost + ( 250 )
        Return
    End If
    gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
    gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
    gsw_item_misc_use = fsw_mt_random(3)
    gul_item_flags = gul_item_flags bOr ( UL_TR_STEALTH )
    gub_item_special_name = UB_SN_STEALTH
    gsl_item_cost = gsl_item_cost + ( 500 )
End Sub


Sub s_mt_cursed_cloak( psw_level As Integer )
    ' Moria's cursedCloak()
    Dim lsw_magic_type , lsw_select_1 As Integer

    lsw_magic_type = fsw_mt_random(3)
    lsw_select_1 = lsw_magic_type
    If lsw_select_1 = 1 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_AGGRAVATE )
        gub_item_special_name = UB_SN_IRRITATION
        gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(1, 10, psw_level) )
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        gsw_item_to_hit = gsw_item_to_hit - ( fsw_mt_bonus(1, 10, psw_level) )
        gsw_item_to_damage = gsw_item_to_damage - ( fsw_mt_bonus(1, 10, psw_level) )
        gsl_item_cost = 0
    ElseIf lsw_select_1 = 2 Then
        gub_item_special_name = UB_SN_VULNERABILITY
        gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(10, 100, psw_level + 50) )
        gsl_item_cost = 0
    Else
        gub_item_special_name = UB_SN_ENVELOPING
        gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(1, 10, psw_level) )
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        gsw_item_to_hit = gsw_item_to_hit - ( fsw_mt_bonus(2, 40, psw_level + 10) )
        gsw_item_to_damage = gsw_item_to_damage - ( fsw_mt_bonus(2, 40, psw_level + 10) )
        gsl_item_cost = 0
    End If
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
End Sub


Sub s_mt_magic_treasure_magical_ability( psw_level As Integer )
    ' Moria's magicTreasureMagicalAbility()
    Dim lsw_chance , lsw_special , lsw_cursed , lsw_select_1 As Integer

    lsw_chance = OBJECT_BASE_MAGIC + psw_level
    If lsw_chance > OBJECT_MAX_BASE_MAGIC Then
        lsw_chance = OBJECT_MAX_BASE_MAGIC
    End If
    lsw_special = lsw_chance / OBJECT_CHANCE_SPECIAL
    lsw_cursed = (10 * lsw_chance) / OBJECT_CHANCE_CURSED
    ' helms, rings, amulets, wands, staffs, chests, and arrows, bolts, shots and spikes are dealt with by the second page of this library
    If gub_item_category = UB_TV_HELM Or gub_item_category = UB_TV_RING Or gub_item_category = UB_TV_AMULET Or gub_item_category = UB_TV_WAND Or gub_item_category = UB_TV_STAFF Or gub_item_category = UB_TV_CHEST Or gub_item_category = UB_TV_SLING_AMMO Or gub_item_category = UB_TV_SPIKE Or gub_item_category = UB_TV_BOLT Or gub_item_category = UB_TV_ARROW Then
        guw_lib_param_2 = psw_level
        s_core_call_library( UB_PAGED_CODE_LIB_TREASURE_2 , UB_LIB_TREASURE_MAGIC )
        Return
    End If
    lsw_select_1 = gub_item_category
    If lsw_select_1 = UB_TV_SHIELD Or lsw_select_1 = UB_TV_HARD_ARMOR Or lsw_select_1 = UB_TV_SOFT_ARMOR Then
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_armor( lsw_special , psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_armor( psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_HAFTED Or lsw_select_1 = UB_TV_POLEARM Or lsw_select_1 = UB_TV_SWORD Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_sword( lsw_special , psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_sword( psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_BOW Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_bow( psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_bow( psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_DIGGING Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        If fub_mt_should(lsw_chance) Then
            If fsw_mt_random(3) < 3 Then
                s_mt_magical_digging_tool( psw_level )
            Else
                s_mt_cursed_digging_tool( psw_level )
            End If
        End If
    ElseIf lsw_select_1 = UB_TV_GLOVES Then
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_gloves( lsw_special , psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_gloves( lsw_special , psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_CLOAK Then
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_cloak( lsw_special , psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_cloak( psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_BOOTS Then
        If fub_mt_should(lsw_chance) Then
            s_mt_magical_boots( lsw_special , psw_level )
        ElseIf fub_mt_should(lsw_cursed) Then
            s_mt_cursed_boots( psw_level )
        End If
    ElseIf lsw_select_1 = UB_TV_LIGHT Then
        If (gub_item_sub_category Mod 2) = 1 Then
            gsw_item_misc_use = fsw_mt_random(gsw_item_misc_use)
            gub_item_sub_category = gub_item_sub_category - ( 1 )
        End If
    ElseIf lsw_select_1 = UB_TV_FOOD Then
        If gub_item_sub_category = 90 Then
            gub_item_depth = 0
        End If
        If gub_item_sub_category = 92 Then
            gub_item_depth = 6
        End If
    ElseIf lsw_select_1 = UB_TV_SCROLL1 Then
        If gub_item_sub_category = 67 Then
            gub_item_depth = 1
        ElseIf gub_item_sub_category = 69 Then
            gub_item_depth = 0
        ElseIf gub_item_sub_category = 80 Then
            gub_item_depth = 5
        ElseIf gub_item_sub_category = 81 Then
            gub_item_depth = 5
        End If
    ElseIf lsw_select_1 = UB_TV_POTION1 Then
        If gub_item_sub_category = 76 Then
            gub_item_depth = 0
        End If
    End If
End Sub


'##################################################################################################################################
' --- a screenful of samples, for checking this page ---

Sub s_mt_test_line( pub_row As UByte , pub_col As UByte , puw_object As UInteger , psw_level As Integer )
    ' makes one item of the given kind for the given level, as fully identified, and shows what it turned out to be...
    ' ...the item comes from the items library and is described by the items library, a library calling a library
    guw_lib_param_2 = puw_object
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_FROM_OBJECT )
    s_mt_magic_treasure_magical_ability( psw_level )
    gub_item_identification = gub_item_identification bOr MB_ID_KNOWN2 bOr MB_ID_STORE_BOUGHT
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    gub_shared_1 = fub_core_print_text_at( pub_row , pub_col , A_TEXT_BUFFER , UB_WHITE )
End Sub


Sub s_mt_test()
    ' the same dozen kinds of thing, made three times each for a shallow level on the left and a deep one on the right
    Dim i , lub_row As UByte

    s_core_clear_screen()
    s_core_print_string_at( 0 , 1 , "Made for level 5" , UB_BRIGHT_WHITE )
    s_core_print_string_at( 0 , 41 , "Made for level 40" , UB_BRIGHT_WHITE )
    lub_row = 1
    For i = 0 To 1
        s_mt_test_line( lub_row      , 1  , 30 + i  , 5 )           ' weapons
        s_mt_test_line( lub_row      , 41 , 30 + i  , 40 )
        s_mt_test_line( lub_row + 2  , 1  , 103 + i , 5 )           ' armour
        s_mt_test_line( lub_row + 2  , 41 , 103 + i , 40 )
        s_mt_test_line( lub_row + 4  , 1  , 91 + i  , 5 )           ' boots and gloves
        s_mt_test_line( lub_row + 4  , 41 , 91 + i  , 40 )
        s_mt_test_line( lub_row + 6  , 1  , 124 + i , 5 )           ' helms and shields
        s_mt_test_line( lub_row + 6  , 41 , 124 + i , 40 )
        s_mt_test_line( lub_row + 8  , 1  , 141 + i , 5 )           ' rings
        s_mt_test_line( lub_row + 8  , 41 , 141 + i , 40 )
        s_mt_test_line( lub_row + 10 , 1  , 282 + i , 5 )           ' wands
        s_mt_test_line( lub_row + 10 , 41 , 282 + i , 40 )
        s_mt_test_line( lub_row + 12 , 1  , 293 + i , 5 )           ' staffs
        s_mt_test_line( lub_row + 12 , 41 , 293 + i , 40 )
        lub_row = lub_row + 14
    Next
    s_core_print_string_at( 30 , 1 , "[ press any key ]" , UB_BRIGHT_GREEN )
    s_core_get_key()
End Sub


'##################################################################################################################################
' --- the way in ---

Sub s_lib_treasure()
    If gub_lib_function = UB_LIB_TREASURE_MAGIC Then
        s_mt_magic_treasure_magical_ability( Cast( Integer , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_TREASURE_TEST Then
        s_mt_test()
    End If
End Sub