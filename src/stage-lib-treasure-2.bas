#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_treasure_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-lib-treasure-include.bas"

' this page is the second half of the treasure LIBRARY, see stage-lib-treasure.bas, which is the page a stage calls...
' ...that page hands on to this one the kinds of item whose magic is worked out here: helms, rings, amulets, wands, staffs,
' chests, and arrows, bolts, shots and spikes
' N.B: like the first page, nearly all of this was turned into BASIC from the Moria source by a script

Sub s_mt_process_rings( psw_level As Integer , psw_cursed As Integer )
    ' Moria's processRings()
    Dim lsw_select_1 As Integer

    lsw_select_1 = gub_item_sub_category
    If lsw_select_1 = 0 Or lsw_select_1 = 1 Or lsw_select_1 = 2 Or lsw_select_1 = 3 Then
        If fub_mt_should(psw_cursed) Then
            gsw_item_misc_use = -fsw_mt_bonus(1, 20, psw_level)
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        Else
            gsw_item_misc_use = fsw_mt_bonus(1, 10, psw_level)
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 100 )
        End If
    ElseIf lsw_select_1 = 4 Then
        If fub_mt_should(psw_cursed) Then
            gsw_item_misc_use = -fsw_mt_random(3)
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        Else
            gsw_item_misc_use = 1
        End If
    ElseIf lsw_select_1 = 5 Then
        gsw_item_misc_use = (5 * fsw_mt_bonus(1, 20, psw_level))
        gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 50 )
        If fub_mt_should(psw_cursed) Then
            gsw_item_misc_use = -gsw_item_misc_use
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        End If
    ElseIf lsw_select_1 = 19 Then
        gsw_item_to_damage = gsw_item_to_damage + ( fsw_mt_bonus(1, 20, psw_level) )
        gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_to_damage ) * 100 )
        If fub_mt_should(psw_cursed) Then
            gsw_item_to_damage = -gsw_item_to_damage
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        End If
    ElseIf lsw_select_1 = 20 Then
        gsw_item_to_hit = gsw_item_to_hit + ( fsw_mt_bonus(1, 20, psw_level) )
        gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_to_hit ) * 100 )
        If fub_mt_should(psw_cursed) Then
            gsw_item_to_hit = -gsw_item_to_hit
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        End If
    ElseIf lsw_select_1 = 21 Then
        gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
        gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_to_ac ) * 100 )
        If fub_mt_should(psw_cursed) Then
            gsw_item_to_ac = -gsw_item_to_ac
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        End If
    ElseIf lsw_select_1 = 24 Or lsw_select_1 = 25 Or lsw_select_1 = 26 Or lsw_select_1 = 27 Or lsw_select_1 = 28 Or lsw_select_1 = 29 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_NO_SHOW_P1 )
    ElseIf lsw_select_1 = 30 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        gsw_item_to_damage = gsw_item_to_damage + ( fsw_mt_bonus(1, 25, psw_level) )
        gsw_item_to_hit = gsw_item_to_hit + ( fsw_mt_bonus(1, 25, psw_level) )
        gsl_item_cost = gsl_item_cost + ( (Cast( Long , gsw_item_to_hit ) + Cast( Long , gsw_item_to_damage )) * 100 )
        If fub_mt_should(psw_cursed) Then
            gsw_item_to_hit = -gsw_item_to_hit
            gsw_item_to_damage = -gsw_item_to_damage
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        End If
    End If
End Sub


Sub s_mt_process_amulets( psw_level As Integer , psw_cursed As Integer )
    ' Moria's processAmulets()
    If gub_item_sub_category < 2 Then
        If fub_mt_should(psw_cursed) Then
            gsw_item_misc_use = -fsw_mt_bonus(1, 20, psw_level)
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
            gsl_item_cost = -gsl_item_cost
        Else
            gsw_item_misc_use = fsw_mt_bonus(1, 10, psw_level)
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 100 )
        End If
    ElseIf gub_item_sub_category = 2 Then
        gsw_item_misc_use = (5 * fsw_mt_bonus(1, 25, psw_level))
        If fub_mt_should(psw_cursed) Then
            gsw_item_misc_use = -gsw_item_misc_use
            gsl_item_cost = -gsl_item_cost
            gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
        Else
            gsl_item_cost = gsl_item_cost + ( 50 * Cast( Long , gsw_item_misc_use ) )
        End If
    ElseIf gub_item_sub_category = 8 Then
        gsw_item_misc_use = (5 * fsw_mt_bonus(1, 25, psw_level))
        gsl_item_cost = gsl_item_cost + ( 20 * Cast( Long , gsw_item_misc_use ) )
    End If
End Sub


Function fsw_mt_wand_magic( psw_id As Integer ) As Integer
    ' Moria's wandMagic()
    Dim lsw_select_1 As Integer

    lsw_select_1 = psw_id
    If lsw_select_1 = 0 Then
        Return fsw_mt_random(10) + 6
    ElseIf lsw_select_1 = 1 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 2 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 3 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 4 Then
        Return fsw_mt_random(4) + 3
    ElseIf lsw_select_1 = 5 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 6 Or lsw_select_1 = 7 Then
        Return fsw_mt_random(20) + 12
    ElseIf lsw_select_1 = 8 Then
        Return fsw_mt_random(10) + 6
    ElseIf lsw_select_1 = 9 Then
        Return fsw_mt_random(12) + 6
    ElseIf lsw_select_1 = 10 Then
        Return fsw_mt_random(10) + 12
    ElseIf lsw_select_1 = 11 Then
        Return fsw_mt_random(3) + 3
    ElseIf lsw_select_1 = 12 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 13 Then
        Return fsw_mt_random(10) + 6
    ElseIf lsw_select_1 = 14 Or lsw_select_1 = 15 Then
        Return fsw_mt_random(5) + 3
    ElseIf lsw_select_1 = 16 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 17 Then
        Return fsw_mt_random(5) + 4
    ElseIf lsw_select_1 = 18 Then
        Return fsw_mt_random(8) + 4
    ElseIf lsw_select_1 = 19 Then
        Return fsw_mt_random(6) + 2
    ElseIf lsw_select_1 = 20 Then
        Return fsw_mt_random(4) + 2
    ElseIf lsw_select_1 = 21 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 22 Then
        Return fsw_mt_random(5) + 2
    ElseIf lsw_select_1 = 23 Then
        Return fsw_mt_random(12) + 12
    Else
        Return -1
    End If
    Return -1
End Function


Function fsw_mt_staff_magic( psw_id As Integer ) As Integer
    ' Moria's staffMagic()
    Dim lsw_select_1 As Integer

    lsw_select_1 = psw_id
    If lsw_select_1 = 0 Then
        Return fsw_mt_random(20) + 12
    ElseIf lsw_select_1 = 1 Then
        Return fsw_mt_random(8) + 6
    ElseIf lsw_select_1 = 2 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 3 Then
        Return fsw_mt_random(20) + 12
    ElseIf lsw_select_1 = 4 Then
        Return fsw_mt_random(15) + 6
    ElseIf lsw_select_1 = 5 Then
        Return fsw_mt_random(4) + 5
    ElseIf lsw_select_1 = 6 Then
        Return fsw_mt_random(5) + 3
    ElseIf lsw_select_1 = 7 Or lsw_select_1 = 8 Then
        Return fsw_mt_random(3) + 1
    ElseIf lsw_select_1 = 9 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 10 Then
        Return fsw_mt_random(10) + 12
    ElseIf lsw_select_1 = 11 Or lsw_select_1 = 12 Or lsw_select_1 = 13 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 14 Then
        Return fsw_mt_random(10) + 12
    ElseIf lsw_select_1 = 15 Then
        Return fsw_mt_random(3) + 4
    ElseIf lsw_select_1 = 16 Or lsw_select_1 = 17 Then
        Return fsw_mt_random(5) + 6
    ElseIf lsw_select_1 = 18 Then
        Return fsw_mt_random(3) + 4
    ElseIf lsw_select_1 = 19 Then
        Return fsw_mt_random(10) + 12
    ElseIf lsw_select_1 = 20 Or lsw_select_1 = 21 Then
        Return fsw_mt_random(3) + 4
    ElseIf lsw_select_1 = 22 Then
        Return fsw_mt_random(10) + 6
    Else
        Return -1
    End If
    Return -1
End Function


Sub s_mt_magical_chests( psw_level As Integer )
    ' Moria's magicalChests()
    Dim lsw_magic_type , lsw_select_1 As Integer

    lsw_magic_type = fsw_mt_random(psw_level + 4)
    lsw_select_1 = lsw_magic_type
    If lsw_select_1 = 1 Then
        gul_item_flags = 0
        gub_item_special_name = UB_SN_EMPTY
    ElseIf lsw_select_1 = 2 Then
        gul_item_flags = gul_item_flags bOr ( UL_CH_LOCKED )
        gub_item_special_name = UB_SN_LOCKED
    ElseIf lsw_select_1 = 3 Or lsw_select_1 = 4 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_LOSE_STR bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_POISON_NEEDLE
    ElseIf lsw_select_1 = 5 Or lsw_select_1 = 6 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_POISON bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_POISON_NEEDLE
    ElseIf lsw_select_1 = 7 Or lsw_select_1 = 8 Or lsw_select_1 = 9 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_PARALYSED bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_GAS_TRAP
    ElseIf lsw_select_1 = 10 Or lsw_select_1 = 11 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_EXPLODE bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_EXPLOSION_DEVICE
    ElseIf lsw_select_1 = 12 Or lsw_select_1 = 13 Or lsw_select_1 = 14 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_SUMMON bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_SUMMONING_RUNES
    ElseIf lsw_select_1 = 15 Or lsw_select_1 = 16 Or lsw_select_1 = 17 Then
        gul_item_flags = gul_item_flags bOr ( (UL_CH_PARALYSED bOr UL_CH_POISON bOr UL_CH_LOSE_STR bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_MULTIPLE_TRAPS
    Else
        gul_item_flags = gul_item_flags bOr ( (UL_CH_SUMMON bOr UL_CH_EXPLODE bOr UL_CH_LOCKED) )
        gub_item_special_name = UB_SN_MULTIPLE_TRAPS
    End If
End Sub


Sub s_mt_magical_projectile_adjustment( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalProjectileAdjustment()
    Dim lsw_select_1 As Integer

    gsw_item_to_hit = gsw_item_to_hit + ( fsw_mt_bonus(1, 35, psw_level) )
    gsw_item_to_damage = gsw_item_to_damage + ( fsw_mt_bonus(1, 35, psw_level) )
    If fub_mt_should(3 * psw_special / 2) Then
        lsw_select_1 = fsw_mt_random(10)
        If lsw_select_1 = 1 Or lsw_select_1 = 2 Or lsw_select_1 = 3 Then
            gub_item_special_name = UB_SN_SLAYING
            gsw_item_to_hit = gsw_item_to_hit + ( 5 )
            gsw_item_to_damage = gsw_item_to_damage + ( 5 )
            gsl_item_cost = gsl_item_cost + ( 20 )
        ElseIf lsw_select_1 = 4 Or lsw_select_1 = 5 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_FLAME_TONGUE )
            gsw_item_to_hit = gsw_item_to_hit + ( 2 )
            gsw_item_to_damage = gsw_item_to_damage + ( 4 )
            gub_item_special_name = UB_SN_FIRE
            gsl_item_cost = gsl_item_cost + ( 25 )
        ElseIf lsw_select_1 = 6 Or lsw_select_1 = 7 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_EVIL )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_SLAY_EVIL
            gsl_item_cost = gsl_item_cost + ( 25 )
        ElseIf lsw_select_1 = 8 Or lsw_select_1 = 9 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_ANIMAL )
            gsw_item_to_hit = gsw_item_to_hit + ( 2 )
            gsw_item_to_damage = gsw_item_to_damage + ( 2 )
            gub_item_special_name = UB_SN_SLAY_ANIMAL
            gsl_item_cost = gsl_item_cost + ( 30 )
        ElseIf lsw_select_1 = 10 Then
            gul_item_flags = gul_item_flags bOr ( UL_TR_SLAY_DRAGON )
            gsw_item_to_hit = gsw_item_to_hit + ( 3 )
            gsw_item_to_damage = gsw_item_to_damage + ( 3 )
            gub_item_special_name = UB_SN_DRAGON_SLAYING
            gsl_item_cost = gsl_item_cost + ( 35 )
        End If
    End If
End Sub


Sub s_mt_cursed_projectile_adjustment( psw_level As Integer )
    ' Moria's cursedProjectileAdjustment()
    gsw_item_to_hit = gsw_item_to_hit - ( fsw_mt_bonus(5, 55, psw_level) )
    gsw_item_to_damage = gsw_item_to_damage - ( fsw_mt_bonus(5, 55, psw_level) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
    gsl_item_cost = 0
End Sub


Sub s_mt_magical_projectile( psw_special As Integer , psw_level As Integer , psw_chance As Integer , psw_cursed As Integer )
    ' Moria's magicalProjectile(): arrows, bolts and shots may be enchanted or cursed, and they and spikes come in
    ' batches of 7 to 42, each batch numbered so that it only ever stacks with itself
    Dim i As UByte

    If gub_item_category = UB_TV_SLING_AMMO Or gub_item_category = UB_TV_BOLT Or gub_item_category = UB_TV_ARROW Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_HIT_DAM )
        If fub_mt_should( psw_chance ) Then
            s_mt_magical_projectile_adjustment( psw_special , psw_level )
        ElseIf fub_mt_should( psw_cursed ) Then
            s_mt_cursed_projectile_adjustment( psw_level )
        End If
    End If

    gub_item_count = 0
    For i = 1 To 7
        gub_item_count = gub_item_count + fsw_mt_random( 6 )
    Next

    If gsw_game_missile_counter = 32767 Then
        gsw_game_missile_counter = -32768
    Else
        gsw_game_missile_counter = gsw_game_missile_counter + 1
    End If
    gsw_item_misc_use = gsw_game_missile_counter
End Sub


Sub s_mt_magical_helms( psw_special As Integer , psw_level As Integer )
    ' Moria's magicalHelms()
    Dim lsw_magic_type , lsw_select_1 , lsw_select_2 As Integer

    gsw_item_to_ac = gsw_item_to_ac + ( fsw_mt_bonus(1, 20, psw_level) )
    If fub_mt_should(psw_special) = false Then
        Return
    End If
    If gub_item_sub_category < 6 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        lsw_magic_type = fsw_mt_random(3)
        lsw_select_1 = lsw_magic_type
        If lsw_select_1 = 1 Then
            gsw_item_misc_use = fsw_mt_random(2)
            gul_item_flags = gul_item_flags bOr ( UL_TR_INT )
            gub_item_special_name = UB_SN_INTELLIGENCE
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 500 )
        ElseIf lsw_select_1 = 2 Then
            gsw_item_misc_use = fsw_mt_random(2)
            gul_item_flags = gul_item_flags bOr ( UL_TR_WIS )
            gub_item_special_name = UB_SN_WISDOM
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 500 )
        Else
            gsw_item_misc_use = (1 + fsw_mt_random(4))
            gul_item_flags = gul_item_flags bOr ( UL_TR_INFRA )
            gub_item_special_name = UB_SN_INFRAVISION
            gsl_item_cost = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) * 250 )
        End If
        Return
    End If
    lsw_select_2 = fsw_mt_random(6)
    If lsw_select_2 = 1 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = fsw_mt_random(3)
        gul_item_flags = gul_item_flags bOr ( (UL_TR_FREE_ACT bOr UL_TR_CON bOr UL_TR_DEX bOr UL_TR_STR) )
        gub_item_special_name = UB_SN_MIGHT
        gsl_item_cost = gsl_item_cost + ( 1000 + Cast( Long , gsw_item_misc_use ) * 500 )
    ElseIf lsw_select_2 = 2 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = fsw_mt_random(3)
        gul_item_flags = gul_item_flags bOr ( (UL_TR_CHR bOr UL_TR_WIS) )
        gub_item_special_name = UB_SN_LORDLINESS
        gsl_item_cost = gsl_item_cost + ( 1000 + Cast( Long , gsw_item_misc_use ) * 500 )
    ElseIf lsw_select_2 = 3 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = fsw_mt_random(3)
        gul_item_flags = gul_item_flags bOr ( (UL_TR_RES_LIGHT bOr UL_TR_RES_COLD bOr UL_TR_RES_ACID bOr UL_TR_RES_FIRE bOr UL_TR_INT) )
        gub_item_special_name = UB_SN_MAGI
        gsl_item_cost = gsl_item_cost + ( 3000 + Cast( Long , gsw_item_misc_use ) * 500 )
    ElseIf lsw_select_2 = 4 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = fsw_mt_random(3)
        gul_item_flags = gul_item_flags bOr ( UL_TR_CHR )
        gub_item_special_name = UB_SN_BEAUTY
        gsl_item_cost = gsl_item_cost + ( 750 )
    ElseIf lsw_select_2 = 5 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = (5 * (1 + fsw_mt_random(4)))
        gul_item_flags = gul_item_flags bOr ( (UL_TR_SEE_INVIS bOr UL_TR_SEARCH) )
        gub_item_special_name = UB_SN_SEEING
        gsl_item_cost = gsl_item_cost + ( 1000 + Cast( Long , gsw_item_misc_use ) * 100 )
    ElseIf lsw_select_2 = 6 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_REGEN )
        gub_item_special_name = UB_SN_REGENERATION
        gsl_item_cost = gsl_item_cost + ( 1500 )
    End If
End Sub


Sub s_mt_cursed_helms( psw_special As Integer , psw_level As Integer )
    ' Moria's cursedHelms()
    Dim lsw_select_1 As Integer

    gsw_item_to_ac = gsw_item_to_ac - ( fsw_mt_bonus(1, 45, psw_level) )
    gul_item_flags = gul_item_flags bOr ( UL_TR_CURSED )
    gsl_item_cost = 0
    If fub_mt_should(psw_special) = false Then
        Return
    End If
    lsw_select_1 = fsw_mt_random(7)
    If lsw_select_1 = 1 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -fsw_mt_random(5)
        gul_item_flags = gul_item_flags bOr ( UL_TR_INT )
        gub_item_special_name = UB_SN_STUPIDITY
    ElseIf lsw_select_1 = 2 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -fsw_mt_random(5)
        gul_item_flags = gul_item_flags bOr ( UL_TR_WIS )
        gub_item_special_name = UB_SN_DULLNESS
    ElseIf lsw_select_1 = 3 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_BLIND )
        gub_item_special_name = UB_SN_BLINDNESS
    ElseIf lsw_select_1 = 4 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_TIMID )
        gub_item_special_name = UB_SN_TIMIDNESS
    ElseIf lsw_select_1 = 5 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -fsw_mt_random(5)
        gul_item_flags = gul_item_flags bOr ( UL_TR_STR )
        gub_item_special_name = UB_SN_WEAKNESS
    ElseIf lsw_select_1 = 6 Then
        gul_item_flags = gul_item_flags bOr ( UL_TR_TELEPORT )
        gub_item_special_name = UB_SN_TELEPORTATION
    ElseIf lsw_select_1 = 7 Then
        gub_item_identification = gub_item_identification bOr ( MB_ID_SHOW_P1 )
        gsw_item_misc_use = -fsw_mt_random(5)
        gul_item_flags = gul_item_flags bOr ( UL_TR_CHR )
        gub_item_special_name = UB_SN_UGLINESS
    Else
        Return
    End If
End Sub


Sub s_mt_second_half( psw_level As Integer )
    ' the part of Moria's magicTreasureMagicalAbility() for the kinds of item this page looks after
    Dim lsw_chance , lsw_special , lsw_cursed , lsw_magic_amount As Integer

    lsw_chance = OBJECT_BASE_MAGIC + psw_level
    If lsw_chance > OBJECT_MAX_BASE_MAGIC Then lsw_chance = OBJECT_MAX_BASE_MAGIC
    lsw_special = lsw_chance / OBJECT_CHANCE_SPECIAL
    lsw_cursed  = ( 10 * lsw_chance ) / OBJECT_CHANCE_CURSED

    If gub_item_category = UB_TV_HELM Then
        ' crowns are far likelier to be magical, and to be special
        If gub_item_sub_category >= 6 And gub_item_sub_category <= 8 Then
            lsw_chance  = lsw_chance + Cast( Integer , gsl_item_cost / 100 )
            lsw_special = lsw_special + lsw_special
        End If
        If fub_mt_should( lsw_chance ) Then
            s_mt_magical_helms( lsw_special , psw_level )
        ElseIf fub_mt_should( lsw_cursed ) Then
            s_mt_cursed_helms( lsw_special , psw_level )
        End If
    ElseIf gub_item_category = UB_TV_RING Then
        s_mt_process_rings( psw_level , lsw_cursed )
    ElseIf gub_item_category = UB_TV_AMULET Then
        s_mt_process_amulets( psw_level , lsw_cursed )
    ElseIf gub_item_category = UB_TV_WAND Then
        lsw_magic_amount = fsw_mt_wand_magic( gub_item_sub_category )
        If lsw_magic_amount <> -1 Then gsw_item_misc_use = lsw_magic_amount
    ElseIf gub_item_category = UB_TV_STAFF Then
        lsw_magic_amount = fsw_mt_staff_magic( gub_item_sub_category )
        If lsw_magic_amount <> -1 Then gsw_item_misc_use = lsw_magic_amount
        ' change the level the items was first found on value
        If gub_item_sub_category = 7 Then
            gub_item_depth = 10
        ElseIf gub_item_sub_category = 22 Then
            gub_item_depth = 5
        End If
    ElseIf gub_item_category = UB_TV_CHEST Then
        s_mt_magical_chests( psw_level )
    ElseIf gub_item_category = UB_TV_SLING_AMMO Or gub_item_category = UB_TV_SPIKE Or gub_item_category = UB_TV_BOLT Or gub_item_category = UB_TV_ARROW Then
        s_mt_magical_projectile( lsw_special , psw_level , lsw_chance , lsw_cursed )
    End If
End Sub


Sub s_lib_treasure_2()
    If gub_lib_function = UB_LIB_TREASURE_MAGIC Then s_mt_second_half( Cast( Integer , guw_lib_param_2 ) )
End Sub