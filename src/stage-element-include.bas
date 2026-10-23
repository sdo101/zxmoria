' what fire, frost, acid, lightning and gas do to creatures and to things lying on the floor, Moria's
' spellGetAreaAffectFlags() (spells.cpp) and its "set" routines (inventory.cpp), the monster spells library, for
' breath, and the aimed spells library, for bolts and balls, include this file, each has its own copy of these routines
' the kinds are the UB_ELEMENT_ numbers in constants.bas, with two more that only spells use:


Function ful_el_resists( pub_element As UByte ) As ULong
    ' the bit of a creature's "spells" that says it breathes this itself, and so is hurt only a quarter as much
    If pub_element = UB_ELEMENT_LIGHTNING Then Return UL_CS_BR_LIGHT
    If pub_element = UB_ELEMENT_GAS Then Return UL_CS_BR_GAS
    If pub_element = UB_ELEMENT_ACID Then Return UL_CS_BR_ACID
    If pub_element = UB_ELEMENT_FROST Then Return UL_CS_BR_FROST
    If pub_element = UB_ELEMENT_FIRE Then Return UL_CS_BR_FIRE
    Return 0
End Function


Function fuw_el_harms( pub_element As UByte ) As UInteger
    ' the bit of a creature's "defenses" that says this hurts it twice as much
    If pub_element = UB_ELEMENT_LIGHTNING Then Return UW_CD_LIGHT
    If pub_element = UB_ELEMENT_GAS Then Return UW_CD_POISON
    If pub_element = UB_ELEMENT_ACID Then Return UW_CD_ACID
    If pub_element = UB_ELEMENT_FROST Then Return UW_CD_FROST
    If pub_element = UB_ELEMENT_FIRE Then Return UW_CD_FIRE
    If pub_element = UB_ELEMENT_HOLY_ORB Then Return UW_CD_EVIL
    Return 0
End Function

Function fub_el_destroys( pub_item As UByte , pub_element As UByte ) As UByte
    ' true if a breath destroys one of the things lying on the level, Moria's setLightningDestroyableItems(),
    ' setAcidDestroyableItems(), setFrostDestroyableItems() and setFireDestroyableItems(), gas destroys nothing
    Dim luw_record      As UInteger
    Dim lub_category    As UByte
    Dim lul_flags       As ULong

    luw_record   = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item )
    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    lul_flags    = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )

    If pub_element = UB_ELEMENT_LIGHTNING Then
        If lub_category = UB_TV_RING Or lub_category = UB_TV_WAND Or lub_category = UB_TV_SPIKE Then Return true
    ElseIf pub_element = UB_ELEMENT_FROST Then
        If lub_category = UB_TV_POTION1 Or lub_category = UB_TV_POTION2 Or lub_category = UB_TV_FLASK Then Return true
    ElseIf pub_element = UB_ELEMENT_ACID Or pub_element = UB_ELEMENT_FIRE Then
        If lub_category = UB_TV_STAFF Or lub_category = UB_TV_SCROLL1 Or lub_category = UB_TV_SCROLL2 Or lub_category = UB_TV_FOOD Or lub_category = UB_TV_OPEN_DOOR Or lub_category = UB_TV_CLOSED_DOOR Then Return true
        If lub_category = UB_TV_ARROW Or lub_category = UB_TV_BOW Or lub_category = UB_TV_HAFTED Or lub_category = UB_TV_POLEARM Or lub_category = UB_TV_BOOTS Or lub_category = UB_TV_GLOVES Or lub_category = UB_TV_CLOAK Or lub_category = UB_TV_SOFT_ARMOR Then
            If pub_element = UB_ELEMENT_ACID Then
                If ( lul_flags bAnd UL_TR_RES_ACID ) = 0 Then Return true
            Else
                If ( lul_flags bAnd UL_TR_RES_FIRE ) = 0 Then Return true
            End If
        End If
        If pub_element = UB_ELEMENT_ACID Then
            ' acid eats metal armour too
            If lub_category = UB_TV_HELM Or lub_category = UB_TV_SHIELD Or lub_category = UB_TV_HARD_ARMOR Then
                If ( lul_flags bAnd UL_TR_RES_ACID ) = 0 Then Return true
            End If
        Else
            ' fire boils potions and burns flasks of oil
            If lub_category = UB_TV_POTION1 Or lub_category = UB_TV_POTION2 Or lub_category = UB_TV_FLASK Then Return true
        End If
    End If
    Return false
End Function
