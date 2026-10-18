' what every page that lets the player hurt a monster with a weapon shares, from Moria's player.cpp and
' player_magic.cpp: whether a blow lands, what a slaying weapon adds, and critical hits, the player attack library,
' stage-lib-player-attack.bas, and the fight library, stage-lib-fight.bas, include this file, each has its own copy
' of these routines
' pub_class_skill is what each level adds for the player's class: gub_class_adj_bth hand to hand, or
' gub_class_adj_bth_bows for anything thrown or fired
' N.B: the creature being fought must be in A_CREATURE

Function fuw_cb_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function

Function fub_cb_test_hit( psw_base As Integer , psw_plus As Integer , psw_armour As Integer , pub_class_skill As UByte ) As UByte
    ' Moria's playerTestBeingHit(), for the player's own blows: a 20 sided die, 1 always misses and 20 always hits,
    ' otherwise the player's skill, their level and the plusses of the weapon against the creature's armour
    Dim lsw_chance  As Integer
    Dim luw_die     As UInteger

    ' as every test of being hit in Moria, the player's own blows too, it disturbs the player first: a player who
    ' fights stops searching (s_dst_disturb() is in stage-disturb-include.bas, each page that includes this one
    ' includes that first)
    s_dst_disturb( true , false )
    lsw_chance = psw_base + psw_plus * 3 + Cast( Integer , guw_player_level ) * Cast( Integer , pub_class_skill )
    luw_die    = fuw_cb_random( 20 )
    If luw_die = 1 Then Return false
    If luw_die = 20 Then Return true
    If lsw_chance > 0 Then
        If Cast( Integer , fuw_cb_random( lsw_chance ) ) > psw_armour Then Return true
    End If
    Return false
End Function


Function fsw_cb_magic_damage( puw_weapon As UInteger , psw_damage As Integer , puw_creature As UInteger ) As Integer
    ' Moria's itemMagicAbilityDamage(): a weapon made to slay does more to the creatures it was made for
    Dim lul_flags       As ULong
    Dim lub_category    As UByte
    Dim luw_learn       As UInteger

    lul_flags    = Peek( ULong , puw_weapon + UB_ITEM_FLAGS_OFFSET )
    lub_category = Peek( puw_weapon + UB_ITEM_CATEGORY_OFFSET )
    If ( lul_flags bAnd UL_TR_EGO_WEAPON ) = 0 Then Return psw_damage
    If ( lub_category < UB_TV_SLING_AMMO Or lub_category > UB_TV_ARROW ) And ( lub_category < UB_TV_HAFTED Or lub_category > UB_TV_SWORD ) And lub_category <> UB_TV_FLASK Then Return psw_damage

    ' in each case the player learns this about the kind of creature, luw_learn is which of its "defenses"

    luw_learn = 0
    If ( guw_creature_defenses bAnd UW_CD_DRAGON ) <> 0 And ( lul_flags bAnd UL_TR_SLAY_DRAGON ) <> 0 Then
        luw_learn  = UW_CD_DRAGON
        psw_damage = psw_damage * 4
    ElseIf ( guw_creature_defenses bAnd UW_CD_UNDEAD ) <> 0 And ( lul_flags bAnd UL_TR_SLAY_UNDEAD ) <> 0 Then
        luw_learn  = UW_CD_UNDEAD
        psw_damage = psw_damage * 3
    ElseIf ( guw_creature_defenses bAnd UW_CD_ANIMAL ) <> 0 And ( lul_flags bAnd UL_TR_SLAY_ANIMAL ) <> 0 Then
        luw_learn  = UW_CD_ANIMAL
        psw_damage = psw_damage * 2
    ElseIf ( guw_creature_defenses bAnd UW_CD_EVIL ) <> 0 And ( lul_flags bAnd UL_TR_SLAY_EVIL ) <> 0 Then
        luw_learn  = UW_CD_EVIL
        psw_damage = psw_damage * 2
    ElseIf ( guw_creature_defenses bAnd UW_CD_FROST ) <> 0 And ( lul_flags bAnd UL_TR_FROST_BRAND ) <> 0 Then
        luw_learn  = UW_CD_FROST
        psw_damage = psw_damage * 3 / 2
    ElseIf ( guw_creature_defenses bAnd UW_CD_FIRE ) <> 0 And ( lul_flags bAnd UL_TR_FLAME_TONGUE ) <> 0 Then
        luw_learn  = UW_CD_FIRE
        psw_damage = psw_damage * 3 / 2
    End If
    If luw_learn <> 0 Then ful_core_recall( puw_creature , UB_RECALL_DEFENSES , luw_learn )
    Return psw_damage
End Function


Function fsw_cb_critical( psw_weight As Integer , psw_plus As Integer , psw_damage As Integer , pub_class_skill As UByte ) As Integer
    ' Moria's playerWeaponCriticalBlow(): a heavy weapon, well made, in skilled hands, now and then does far more
    If Cast( Integer , fuw_cb_random( 5000 ) ) > psw_weight + 5 * psw_plus + Cast( Integer , pub_class_skill ) * Cast( Integer , guw_player_level ) Then Return psw_damage

    psw_weight = psw_weight + Cast( Integer , fuw_cb_random( 650 ) )
    If psw_weight < 400 Then
        s_core_message( UW_MSG_IT_WAS_A_GOOD_HIT_X2_DAMAGE )
        Return 2 * psw_damage + 5
    ElseIf psw_weight < 700 Then
        s_core_message( UW_MSG_IT_WAS_AN_EXCELLENT_HIT_X3_DAMAGE )
        Return 3 * psw_damage + 10
    ElseIf psw_weight < 900 Then
        s_core_message( UW_MSG_IT_WAS_A_SUPERB_HIT_X4_DAMAGE )
        Return 4 * psw_damage + 15
    End If
    s_core_message( UW_MSG_IT_WAS_A_GREAT_HIT_X5_DAMAGE )
    Return 5 * psw_damage + 20
End Function
