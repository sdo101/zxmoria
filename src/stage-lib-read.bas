#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_read()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: reading a scroll, Moria's scrolls.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_READ , <which routine> ),
' the one routine is:
'
'   UB_LIB_READ_SCROLL      the player picks a scroll from the pack and reads it, Moria's scrollRead(), gsw_lib_result
'                           is true if it took the player's turn, false if they could not read, had no scrolls, or
'                           changed their mind
'
' what a scroll does is in its flags, one bit for each effect, and all of them happen, lowest bit first, the first
' kind of scroll counts its effects from 1, the second kind from 33
' the scrolls that enchant, curse and name what the player is wearing are done here, the rest are spells that staffs
' and spell books share, and are in the spells libraries, stage-lib-spells.bas and stage-lib-spells-2.bas
' anything the walking stage must do afterwards is asked for in gub_game_turn_flags, the MB_TURN_ bits in constants.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_rd_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_rd_record( pub_place As UByte ) As UInteger
    ' where the record for one place in the pack or the equipment is
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Function fub_rd_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_rd_recalc()
    ' Moria's playerRecalculateBonuses()
    s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
End Sub


Sub s_rd_glows( pub_place As UByte , ps_how As String )
    ' "Your Dagger (Stiletto) glows faintly!", the thing is named without "a" or its numbers
    s_core_ram_copy( fuw_rd_record( pub_place ) , A_ITEM , UB_RECORD_SIZE )
    gub_lib_param_1 = false
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    s_msg( "Your " + fs_core_text_at( A_TEXT_BUFFER ) + " " + ps_how )
End Sub


Function fub_rd_enchant( puw_plusses As UInteger , psw_limit As Integer ) As UByte
    ' Moria's spellEnchantItem(): one of an item's plusses, which is kept at puw_plusses, may go up by one, the
    ' higher it is already the less likely, and never beyond the limit
    Dim lsw_plusses , lsw_chance As Integer

    If psw_limit <= 0 Then Return false
    lsw_plusses = Peek( Integer , puw_plusses )
    lsw_chance  = 0
    If lsw_plusses > 0 Then
        lsw_chance = lsw_plusses
        ' very rarely allow enchantment over limit
        If fuw_rd_random( 100 ) = 1 Then lsw_chance = Cast( Integer , fuw_rd_random( lsw_chance ) ) - 1
    End If
    If Cast( Integer , fuw_rd_random( psw_limit ) ) > lsw_chance Then
        Poke UInteger puw_plusses , Cast( UInteger , lsw_plusses + 1 )
        Return true
    End If
    Return false
End Function


Sub s_rd_enchanted( pub_place As UByte , pub_worked As UByte )
    ' the end of each enchanting scroll: if it worked any curse is lifted and the player's bonuses worked out again
    Dim luw_flags As UInteger

    If pub_worked Then
        luw_flags = fuw_rd_record( pub_place ) + UB_ITEM_FLAGS_OFFSET
        Poke ULong luw_flags , Peek( ULong , luw_flags ) bAnd ( $FFFFFFFF - UL_TR_CURSED )
        s_rd_recalc()
    Else
        s_core_message( UW_MSG_THE_ENCHANTMENT_FAILS )
    End If
End Sub


Function fsw_rd_damage_limit( pub_place As UByte ) As Integer
    ' how far a weapon's damage can be enchanted: the most its dice could roll, for the hafted, pole and edged
    ' weapons and the digging tools, 10 for anything else
    Dim luw_record      As UInteger
    Dim lub_category    As UByte

    luw_record   = fuw_rd_record( pub_place )
    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    If lub_category >= UB_TV_HAFTED And lub_category <= UB_TV_DIGGING Then Return Cast( Integer , Peek( luw_record + UB_ITEM_DAMAGE_OFFSET ) ) * Cast( Integer , Peek( luw_record + UB_ITEM_DAMAGE_OFFSET + 1 ) )
    Return 10
End Function


Function fub_rd_worn( pub_slot As UByte ) As UByte
    ' true if something is being worn in one of the equipment's places
    If Peek( fuw_rd_record( UB_PACK_SIZE + pub_slot ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then Return true
    Return false
End Function


Function fub_rd_cursed( pub_slot As UByte ) As UByte
    ' Moria's playerWornItemIsCursed()
    If ( Peek( ULong , fuw_rd_record( UB_PACK_SIZE + pub_slot ) + UB_ITEM_FLAGS_OFFSET ) bAnd UL_TR_CURSED ) <> 0 Then Return true
    Return false
End Function


Function fub_rd_armour_to_enchant() As UByte
    ' Moria's inventoryItemIdOfCursedEquipment(): which piece of armour a scroll works on, one of those worn picked
    ' at random, but a cursed piece comes first, the place in the one list of pack and equipment, 0 for none
    Dim lub_count , lub_place As UByte

    lub_count = 0
    If fub_rd_worn( UB_EQUIP_BODY ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_BODY
        lub_count = lub_count + 1
    End If
    If fub_rd_worn( UB_EQUIP_ARM ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_ARM
        lub_count = lub_count + 1
    End If
    If fub_rd_worn( UB_EQUIP_OUTER ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_OUTER
        lub_count = lub_count + 1
    End If
    If fub_rd_worn( UB_EQUIP_HANDS ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_HANDS
        lub_count = lub_count + 1
    End If
    If fub_rd_worn( UB_EQUIP_HEAD ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_HEAD
        lub_count = lub_count + 1
    End If
    If fub_rd_worn( UB_EQUIP_FEET ) Then
        Poke A_LIB_PRIVATE + lub_count , UB_EQUIP_FEET
        lub_count = lub_count + 1
    End If

    lub_place = 255
    If lub_count > 0 Then lub_place = Peek( A_LIB_PRIVATE + fuw_rd_random( lub_count ) - 1 )
    If fub_rd_cursed( UB_EQUIP_BODY ) Then
        lub_place = UB_EQUIP_BODY
    ElseIf fub_rd_cursed( UB_EQUIP_ARM ) Then
        lub_place = UB_EQUIP_ARM
    ElseIf fub_rd_cursed( UB_EQUIP_OUTER ) Then
        lub_place = UB_EQUIP_OUTER
    ElseIf fub_rd_cursed( UB_EQUIP_HEAD ) Then
        lub_place = UB_EQUIP_HEAD
    ElseIf fub_rd_cursed( UB_EQUIP_HANDS ) Then
        lub_place = UB_EQUIP_HANDS
    ElseIf fub_rd_cursed( UB_EQUIP_FEET ) Then
        lub_place = UB_EQUIP_FEET
    End If
    If lub_place = 255 Then Return 0
    Return UB_PACK_SIZE + lub_place
End Function


Function fub_rd_armour_to_curse() As UByte
    ' the start of Moria's scrollCurseArmor(): which piece of armour is cursed, each in turn has a chance, and
    ' failing that the first that is worn, 0 for none
    ' N.B: a random number is asked for only for a piece that is being worn, as in Moria
    If fub_rd_worn( UB_EQUIP_BODY ) Then
        If fuw_rd_random( 4 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_BODY
    End If
    If fub_rd_worn( UB_EQUIP_ARM ) Then
        If fuw_rd_random( 3 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_ARM
    End If
    If fub_rd_worn( UB_EQUIP_OUTER ) Then
        If fuw_rd_random( 3 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_OUTER
    End If
    If fub_rd_worn( UB_EQUIP_HEAD ) Then
        If fuw_rd_random( 3 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_HEAD
    End If
    If fub_rd_worn( UB_EQUIP_HANDS ) Then
        If fuw_rd_random( 3 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_HANDS
    End If
    If fub_rd_worn( UB_EQUIP_FEET ) Then
        If fuw_rd_random( 3 ) = 1 Then Return UB_PACK_SIZE + UB_EQUIP_FEET
    End If
    If fub_rd_worn( UB_EQUIP_BODY ) Then Return UB_PACK_SIZE + UB_EQUIP_BODY
    If fub_rd_worn( UB_EQUIP_ARM ) Then Return UB_PACK_SIZE + UB_EQUIP_ARM
    If fub_rd_worn( UB_EQUIP_OUTER ) Then Return UB_PACK_SIZE + UB_EQUIP_OUTER
    If fub_rd_worn( UB_EQUIP_HEAD ) Then Return UB_PACK_SIZE + UB_EQUIP_HEAD
    If fub_rd_worn( UB_EQUIP_HANDS ) Then Return UB_PACK_SIZE + UB_EQUIP_HANDS
    If fub_rd_worn( UB_EQUIP_FEET ) Then Return UB_PACK_SIZE + UB_EQUIP_FEET
    Return 0
End Function


Function fub_rd_weapon_scroll( pub_effect As UByte ) As UByte
    ' the scrolls that work on the weapon in hand: 1 enchant to hit, 2 enchant to damage, 33 enchant weapon,
    ' 34 curse weapon, Moria's scrollEnchantWeaponToHit(), scrollEnchantWeaponToDamage(), scrollEnchantWeapon()
    ' and scrollCurseWeapon(), false if the player's hands are empty
    Dim lub_place , lub_worked  As UByte
    Dim luw_record              As UInteger
    Dim luw_i                   As UInteger

    lub_place  = UB_PACK_SIZE + UB_EQUIP_WIELD
    luw_record = fuw_rd_record( lub_place )
    If fub_rd_worn( UB_EQUIP_WIELD ) = false Then Return false

    If pub_effect = 1 Then
        s_rd_glows( lub_place , "glows faintly!" )
        s_rd_enchanted( lub_place , fub_rd_enchant( luw_record + UB_ITEM_TO_HIT_OFFSET , 10 ) )
    ElseIf pub_effect = 2 Then
        s_rd_glows( lub_place , "glows faintly!" )
        s_rd_enchanted( lub_place , fub_rd_enchant( luw_record + UB_ITEM_TO_DAMAGE_OFFSET , fsw_rd_damage_limit( lub_place ) ) )
    ElseIf pub_effect = 33 Then
        s_rd_glows( lub_place , "glows brightly!" )
        lub_worked = false
        ' N.B: as in Moria the dice are thrown afresh each time round, so it is one try or, sometimes, two
        luw_i = 0
        While luw_i < fuw_rd_random( 2 )
            If fub_rd_enchant( luw_record + UB_ITEM_TO_HIT_OFFSET , 10 ) Then lub_worked = true
            luw_i = luw_i + 1
        End While
        luw_i = 0
        While luw_i < fuw_rd_random( 2 )
            If fub_rd_enchant( luw_record + UB_ITEM_TO_DAMAGE_OFFSET , fsw_rd_damage_limit( lub_place ) ) Then lub_worked = true
            luw_i = luw_i + 1
        End While
        s_rd_enchanted( lub_place , lub_worked )
    Else
        s_rd_glows( lub_place , "glows black, fades." )
        ' Moria's itemRemoveMagicNaming(), "of Slay Evil" and the like goes
        Poke luw_record + UB_ITEM_SPECIAL_NAME_OFFSET , 0
        Poke UInteger luw_record + UB_ITEM_TO_HIT_OFFSET , Cast( UInteger , -Cast( Integer , fuw_rd_random( 5 ) ) - Cast( Integer , fuw_rd_random( 5 ) ) )
        Poke UInteger luw_record + UB_ITEM_TO_DAMAGE_OFFSET , Cast( UInteger , -Cast( Integer , fuw_rd_random( 5 ) ) - Cast( Integer , fuw_rd_random( 5 ) ) )
        Poke UInteger luw_record + UB_ITEM_TO_AC_OFFSET , 0
        ' must call this before the flags are set to cursed, what the weapon did for the player is undone,
        ' Moria's playerAdjustBonusesForItem()
        gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_ADJUST , lub_place , $FFFF )
        Poke ULong luw_record + UB_ITEM_FLAGS_OFFSET , UL_TR_CURSED
        s_rd_recalc()
    End If
    Return true
End Function


Function fub_rd_armour_scroll( pub_effect As UByte ) As UByte
    ' the scrolls that work on a piece of armour: 3 enchant armour, 35 the stronger one, 36 curse armour, Moria's
    ' scrollEnchantItemToAC(), scrollEnchantArmor() and scrollCurseArmor(), false if the player wears none
    Dim lub_place , lub_worked  As UByte
    Dim luw_record              As UInteger
    Dim luw_i                   As UInteger

    If pub_effect = 36 Then
        lub_place = fub_rd_armour_to_curse()
    Else
        lub_place = fub_rd_armour_to_enchant()
    End If
    If lub_place = 0 Then Return false
    luw_record = fuw_rd_record( lub_place )

    If pub_effect = 3 Then
        s_rd_glows( lub_place , "glows faintly!" )
        s_rd_enchanted( lub_place , fub_rd_enchant( luw_record + UB_ITEM_TO_AC_OFFSET , 10 ) )
    ElseIf pub_effect = 35 Then
        s_rd_glows( lub_place , "glows brightly!" )
        lub_worked = false
        luw_i = 0
        While luw_i < fuw_rd_random( 2 ) + 1
            If fub_rd_enchant( luw_record + UB_ITEM_TO_AC_OFFSET , 10 ) Then lub_worked = true
            luw_i = luw_i + 1
        End While
        s_rd_enchanted( lub_place , lub_worked )
    Else
        s_rd_glows( lub_place , "glows black, fades." )
        Poke luw_record + UB_ITEM_SPECIAL_NAME_OFFSET , 0
        Poke ULong luw_record + UB_ITEM_FLAGS_OFFSET , UL_TR_CURSED
        Poke UInteger luw_record + UB_ITEM_TO_HIT_OFFSET , 0
        Poke UInteger luw_record + UB_ITEM_TO_DAMAGE_OFFSET , 0
        Poke UInteger luw_record + UB_ITEM_TO_AC_OFFSET , Cast( UInteger , -Cast( Integer , fuw_rd_random( 5 ) ) - Cast( Integer , fuw_rd_random( 5 ) ) )
        s_rd_recalc()
    End If
    Return true
End Function


Function fub_rd_summon( pub_function As UByte ) As UByte
    ' Moria's scrollSummonMonster() and scrollSummonUndead(): one, two or three of them, beside the player
    ' N.B: as in Moria the dice are thrown afresh each time round
    Dim luw_i           As UInteger = 0
    Dim lub_identified  As UByte = false

    While luw_i < fuw_rd_random( 3 )
        If fub_rd_call( UB_PAGED_CODE_LIB_MONSTERS , pub_function , 0 , 0 ) Then lub_identified = true
        luw_i = luw_i + 1
    End While
    Return lub_identified
End Function


Function fub_rd_read() As UByte
    ' Moria's scrollRead(), with its playerCanReadScroll()
    Dim lsw_place , lsw_first , lsw_last , lsw_i    As Integer
    Dim luw_record                                  As UInteger
    Dim lul_flags , lul_mask                        As ULong
    Dim lub_effect , lub_category , lub_flags       As UByte
    Dim lub_identified                              As UByte = false
    Dim lub_used_up                                 As UByte = true
    Dim ls_prompt                                   As String

    If gsw_player_blind > 0 Then
        s_core_message( UW_MSG_YOU_CANT_SEE_TO_READ_THE_SCROLL )
        Return false
    End If
    ' Moria's playerNoLight()
    lub_flags = Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then
        s_core_message( UW_MSG_YOU_HAVE_NO_LIGHT_TO_READ_BY )
        Return false
    End If
    If gsw_player_confused > 0 Then
        s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED_TO_READ_A )
        Return false
    End If
    If gsw_player_pack_unique = 0 Then
        s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING_2 )
        Return false
    End If

    ' the scrolls in the pack, they are all together there, Moria's inventoryFindRange()
    lsw_first = -1
    lsw_last  = -1
    For lsw_i = 0 To gsw_player_pack_unique - 1
        lub_category = Peek( fuw_rd_record( lsw_i ) + UB_ITEM_CATEGORY_OFFSET )
        Poke A_INV_MASK + lsw_i , 0
        If lub_category = UB_TV_SCROLL1 Or lub_category = UB_TV_SCROLL2 Then
            If lsw_first < 0 Then lsw_first = lsw_i
            lsw_last = lsw_i
            Poke A_INV_MASK + lsw_i , 1
        End If
    Next
    If lsw_first < 0 Then
        s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANY_SCROLLS )
        Return false
    End If
    ls_prompt = "Read which scroll?"
    For lsw_i = 0 To Len( ls_prompt ) - 1
        Poke A_PROMPT + lsw_i , Code( ls_prompt( lsw_i ) )
    Next
    Poke A_PROMPT + Len( ls_prompt ) , 0
    gub_lib_param_1 = false
    guw_lib_param_2 = Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    lsw_place = gsw_lib_result
    If lsw_place < 0 Then Return false

    luw_record = fuw_rd_record( lsw_place )
    lul_flags  = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
    lub_effect = 1
    If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_SCROLL2 Then lub_effect = 33
    lul_mask = 1
    While lul_flags <> 0
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
            If lub_effect = 1 Or lub_effect = 2 Or lub_effect = 33 Or lub_effect = 34 Then
                lub_identified = fub_rd_weapon_scroll( lub_effect )
            ElseIf lub_effect = 3 Or lub_effect = 35 Or lub_effect = 36 Then
                lub_identified = fub_rd_armour_scroll( lub_effect )
            ElseIf lub_effect = 4 Then
                ' identify, Moria's scrollIdentifyItem(): the scroll is not used up if the player backs out
                s_core_message( UW_MSG_THIS_IS_AN_IDENTIFY_SCROLL )
                lub_used_up = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_IDENTIFY , 0 , 0 )
                ' the identify may merge objects, causing the identify scroll to move to a different place:
                ' check for that here, it can only move up
                luw_record = fuw_rd_record( lsw_place )
                While lsw_place > 0 And ( Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> UB_TV_SCROLL1 Or Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET ) <> 8 )
                    lsw_place  = lsw_place - 1
                    luw_record = fuw_rd_record( lsw_place )
                End While
                lub_identified = true
            ElseIf lub_effect = 5 Then
                ' remove curse
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_REMOVE_CURSE , 0 , 0 )
                If lub_identified Then s_core_message( UW_MSG_YOU_FEEL_AS_IF_SOMEONE_IS )
            ElseIf lub_effect = 6 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_LIGHT_AREA , 0 , 0 )
            ElseIf lub_effect = 7 Then
                lub_identified = fub_rd_summon( UB_LIB_MONSTERS_SUMMON )
            ElseIf lub_effect = 8 Then
                ' teleport short, aka phase door
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT , 0 , 10 )
                lub_identified = true
            ElseIf lub_effect = 9 Then
                ' teleport long
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT , 0 , 100 )
                lub_identified = true
            ElseIf lub_effect = 10 Then
                ' teleport level, Moria's scrollTeleportLevel(): one level up or one down
                lsw_i = Cast( Integer , guw_dungeon_level ) - 3 + 2 * Cast( Integer , fuw_rd_random( 2 ) )
                If lsw_i < 1 Then lsw_i = 1
                guw_dungeon_level   = lsw_i
                gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_NEW_LEVEL
                lub_identified = true
            ElseIf lub_effect = 11 Then
                ' confuse monster
                lub_identified = false
                If gub_player_confuse_monster = false Then
                    s_core_message( UW_MSG_YOUR_HANDS_BEGIN_TO_GLOW )
                    gub_player_confuse_monster = true
                    lub_identified = true
                End If
            ElseIf lub_effect = 12 Then
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_MAP_AREA , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 13 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_SLEEP_ADJACENT , 0 , 0 )
            ElseIf lub_effect = 14 Then
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_GLYPH , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 15 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_TREASURE , 0 , 0 )
            ElseIf lub_effect = 16 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_OBJECTS , 0 , 0 )
            ElseIf lub_effect = 17 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_TRAPS , 0 , 0 )
            ElseIf lub_effect = 18 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_DOORS , 0 , 0 )
            ElseIf lub_effect = 19 Then
                s_core_message( UW_MSG_THIS_IS_A_MASS_GENOCIDE_SCROLL )
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_MASS_GENOCIDE , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 20 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_INVISIBLE , 0 , 0 )
            ElseIf lub_effect = 21 Then
                s_core_message( UW_MSG_THERE_IS_A_HIGH_PITCHED_HUMMING )
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_AGGRAVATE , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 22 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TRAPS , 0 , 0 )
            ElseIf lub_effect = 23 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DESTROY_DOORS , 0 , 0 )
            ElseIf lub_effect = 24 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DOORS , 0 , 0 )
            ElseIf lub_effect = 25 Then
                s_core_message( UW_MSG_THIS_IS_A_RECHARGE_ITEM_SCROLL )
                ' the scroll is not used up if there is nothing to recharge or the player backs out
                lub_used_up = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_RECHARGE , 0 , 60 )
                lub_identified = true
            ElseIf lub_effect = 26 Then
                s_core_message( UW_MSG_THIS_IS_A_GENOCIDE_SCROLL )
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_GENOCIDE , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 27 Then
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DARKEN_AREA , 0 , 0 )
            ElseIf lub_effect = 28 Then
                ' protection from evil, Moria's playerProtectEvil()
                lub_identified = false
                If gsw_player_protect_evil = 0 Then lub_identified = true
                gsw_player_protect_evil = gsw_player_protect_evil + fuw_rd_random( 25 ) + 3 * guw_player_level
            ElseIf lub_effect = 29 Then
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_CREATE_FOOD , 0 , 0 )
                lub_identified = true
            ElseIf lub_effect = 30 Then
                ' dispel undead
                lub_identified = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_DISPEL , 60 , UW_CD_UNDEAD )
            ElseIf lub_effect = 37 Then
                lub_identified = fub_rd_summon( UB_LIB_MONSTERS_SUMMON_UNDEAD )
            ElseIf lub_effect = 38 Then
                ' blessing, holy chant and holy prayer, Moria's playerBless()
                gsw_player_blessed = gsw_player_blessed + fuw_rd_random( 12 ) + 6
                lub_identified = true
            ElseIf lub_effect = 39 Then
                gsw_player_blessed = gsw_player_blessed + fuw_rd_random( 24 ) + 12
                lub_identified = true
            ElseIf lub_effect = 40 Then
                gsw_player_blessed = gsw_player_blessed + fuw_rd_random( 48 ) + 24
                lub_identified = true
            ElseIf lub_effect = 41 Then
                ' word of recall, Moria's scrollWordOfRecall()
                If gsw_player_word_of_recall = 0 Then gsw_player_word_of_recall = 25 + fuw_rd_random( 30 )
                s_core_message( UW_MSG_THE_AIR_ABOUT_YOU_BECOMES_CHARGED )
                lub_identified = true
            ElseIf lub_effect = 42 Then
                gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DESTROY_AREA , 0 , 0 )
                lub_identified = true
            Else
                s_core_message( UW_MSG_INTERNAL_ERROR_IN_SCROLL )
            End If
        End If
        lub_effect = lub_effect + 1
        lul_mask   = lul_mask << 1
    End While

    ' what the player has learnt about it, and then it is gone
    gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_USE_DONE , lsw_place , lub_identified )
    lsw_place = gsw_lib_result
    If lub_used_up Then gub_shared_1 = fub_rd_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_USE_REMAINING , lsw_place , 0 )
    Return true
End Function


Sub s_lib_read()
    Dim lub_used As UByte = false

    If gub_lib_function = UB_LIB_READ_SCROLL Then lub_used = fub_rd_read()
    gsw_lib_result = lub_used
End Sub
