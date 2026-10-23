#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_inventory()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: what the player is carrying, Moria's inventory.cpp...
' ...any stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , <which routine> ), the routines are:
'
'   UB_LIB_INV_CAN_CARRY    gsw_lib_result is true if there is a place in the pack for the working item (A_ITEM):
'                           a free place, or some of the same thing to put it with, Moria's inventoryCanCarryItemCount()
'   UB_LIB_INV_CARRY        puts the working item in the pack, Moria's inventoryCarryItem(), which place it went to
'                           comes back in gsw_lib_result, the pack is kept in order of category, highest first
'   UB_LIB_INV_STRENGTH     works out whether the pack is now heavy enough to slow the player down, and says so if
'                           that has changed, Moria's playerStrength()
'
'   UB_LIB_INV_NEW_CHARACTER    empties the pack and gives a new character what their class starts with, Moria's
'                               initializeCharacterInventory()
'   UB_LIB_INV_DESTROY          one of what is in place guw_lib_param_2 of the pack goes (all of them if they do not
'                               stack singly), Moria's inventoryDestroyItem()
'   UB_LIB_INV_IDENTIFY         the player learns what kind of thing is in place guw_lib_param_2, and if that makes
'                               it the same as something else in the pack the two are put together, Moria's
'                               itemIdentify(), the place it is in afterwards comes back in gsw_lib_result
'   UB_LIB_INV_KNOW_FULLY       the working item becomes fully known, its plusses and charges, Moria's
'                               spellItemIdentifyAndRemoveRandomInscription()
'   UB_LIB_INV_IDENTIFY_WORKING the player learns what kind of thing the working item is, which is not in the pack,
'                               the start of Moria's itemIdentify(), for the wizard's % command
'   UB_LIB_INV_TRIED            the kind of thing in place guw_lib_param_2 has been tried, and the player is none
'                               the wiser, Moria's itemSetAsTried(), its description says so from now on
'   UB_LIB_INV_SHOW             lists the pack on the screen from row 1, the first and last places to list are the low
'                               and high bytes of guw_lib_param_2, leaving out those A_INV_MASK rules out
'   UB_LIB_INV_CHOOSE           asks the player to pick something from the pack, Moria's inventoryGetInputForItemId():
'                               the first and last places that may be picked are the low and high bytes of
'                               guw_lib_param_2, A_INV_MASK has a byte for each place, 0 for those that may not be,
'                               and gub_lib_param_1 is one of the UB_INV_CHOOSE_ values, * shows the list, a digit
'                               picks the thing inscribed with just that digit, a capital letter picks after
'                               "are you sure", the place picked comes back in gsw_lib_result, -1 for none, the
'                               question asked is "Which one?" unless the caller has left its own in A_PROMPT,
'                               a last place of UB_INVENTORY_SIZE means anything carried, worn or not: / then goes
'                               between the pack and the equipment, and the answer may be a place from 22 to 33
'   UB_LIB_INV_VERIFY           Moria's verifyAction(), "Take off a Cloak [1,+0]?", for the place in
'                               guw_lib_param_2, gub_lib_param_1 says which word, true for y
'
' N.B: the pack and the equipment are one list of 34 records in the core data, A_INVENTORY, places 0 to 21 are the pack
' and 22 to 33 the equipment, so nothing here needs a page swapped in to look at them
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, wearing and wielding, taking off, dropping, and the inventory and equipment
'     screens are the equipment library's, stage-lib-equipment.bas, UB_LIB_EQUIP_COMMAND




Function fuw_inv_record( pub_place As UByte ) As UInteger
    ' where the record for one place in the pack or the equipment is
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Function fub_inv_kind_is_known( pub_category As UByte , pub_sub_category As UByte , pub_identification As UByte ) As UByte
    ' true if the player knows what kind of thing an item with these details is, Moria's itemSetColorlessAsIdentified(),
    ' the same test the items library makes for the working item, it is here as well because this page needs to ask
    ' it about the things already in the pack
    Dim lub_family , lub_page , lub_flags As UByte

    If ( pub_identification bAnd MB_ID_STORE_BOUGHT ) <> 0 Then Return true
    lub_family = 255
    If pub_category = UB_TV_AMULET Then lub_family = 0
    If pub_category = UB_TV_RING Then lub_family = 1
    If pub_category = UB_TV_STAFF Then lub_family = 2
    If pub_category = UB_TV_WAND Then lub_family = 3
    If pub_category = UB_TV_SCROLL1 Or pub_category = UB_TV_SCROLL2 Then lub_family = 4
    If pub_category = UB_TV_POTION1 Or pub_category = UB_TV_POTION2 Then lub_family = 5
    If pub_category = UB_TV_FOOD Then
        If ( pub_sub_category bAnd 63 ) < UB_MAX_MUSHROOMS Then lub_family = 6
    End If
    If lub_family = 255 Then Return true

    ' the knowledge page is looked at in the third data slot, and whatever was there is put straight back
    lub_page = gub_core_MMU2_page_number
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
    lub_flags = Peek( A_KNOW_IDENTIFIED + ( Cast( UInteger , lub_family ) << 6 ) + ( pub_sub_category bAnd 63 ) )
    If lub_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_page )
    If ( lub_flags bAnd MB_OD_KNOWN1 ) <> 0 Then Return true
    Return false
End Function


Function fub_inv_stacks_with( pub_place As UByte , pub_known As UByte ) As UByte
    ' true if the working item can be added to what is in the given place: the same thing, not too many altogether,
    ' the same batch if it is the kind that comes in batches, and both known or both unknown
    Dim luw_record As UInteger

    luw_record = fuw_inv_record( pub_place )
    If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> gub_item_category Then Return false
    If Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET ) <> gub_item_sub_category Then Return false
    If Cast( UInteger , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) ) + gub_item_count >= 256 Then Return false
    If gub_item_sub_category >= UB_ITEM_GROUP_MIN Then
        If Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) <> gsw_item_misc_use Then Return false
    End If
    If fub_inv_kind_is_known( Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) , Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET ) , Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) ) <> pub_known Then Return false
    Return true
End Function


Function fub_inv_can_carry() As UByte
    ' Moria's inventoryCanCarryItemCount()
    Dim i , lub_known As UByte

    If gsw_player_pack_unique < UB_PACK_SIZE Then Return true
    If gub_item_sub_category < UB_ITEM_SINGLE_STACK_MIN Then Return false
    lub_known = fub_inv_kind_is_known( gub_item_category , gub_item_sub_category , gub_item_identification )
    For i = 0 To gsw_player_pack_unique - 1
        If fub_inv_stacks_with( i , lub_known ) Then Return true
    Next
    Return false
End Function


Function fub_inv_carry() As UByte
    ' Moria's inventoryCarryItem(): the working item goes on to a stack of the same thing if there is one, and otherwise
    ' in front of the first thing of a lower category (or of the same category and a higher sub category, for the
    ' kinds that are always known), everything from there on moving down a place
    ' N.B: like Moria this looks through all 34 places, an empty place holds "nothing", category 0, and anything goes in
    ' front of that, so the pack fills from the top
    Dim lub_place , lub_known , lub_always_known    As UByte
    Dim lub_their_category , lub_their_sub          As UByte
    Dim luw_record                                  As UInteger
    Dim lsw_i                                       As Integer

    lub_known        = fub_inv_kind_is_known( gub_item_category , gub_item_sub_category , gub_item_identification )
    ' "always known" means it is not one of the seven families of things that start out unknown
    lub_always_known = true
    If gub_item_category = UB_TV_AMULET Or gub_item_category = UB_TV_RING Or gub_item_category = UB_TV_STAFF Or gub_item_category = UB_TV_WAND Then lub_always_known = false
    If gub_item_category = UB_TV_SCROLL1 Or gub_item_category = UB_TV_SCROLL2 Or gub_item_category = UB_TV_POTION1 Or gub_item_category = UB_TV_POTION2 Then lub_always_known = false
    If gub_item_category = UB_TV_FOOD Then
        If ( gub_item_sub_category bAnd 63 ) < UB_MAX_MUSHROOMS Then lub_always_known = false
    End If

    lub_place = 0
    While lub_place < UB_INVENTORY_SIZE
        luw_record         = fuw_inv_record( lub_place )
        lub_their_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        lub_their_sub      = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET )

        If gub_item_sub_category >= UB_ITEM_SINGLE_STACK_MIN Then
            If fub_inv_stacks_with( lub_place , lub_known ) Then
                Poke luw_record + UB_ITEM_COUNT_OFFSET , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) + gub_item_count
                Exit While
            End If
        End If

        If ( gub_item_category = lub_their_category And gub_item_sub_category < lub_their_sub And lub_always_known ) Or gub_item_category > lub_their_category Then
            ' make room: everything from here to the end of the pack moves down one place...
            ' ...N.B: each record goes by way of the working monster, 64 bytes nothing else is using in here, because
            ' neighbouring records touch and the core's copy routine will not copy between areas that touch
            lsw_i = gsw_player_pack_unique - 1
            While lsw_i >= Cast( Integer , lub_place )
                s_core_ram_copy( fuw_inv_record( lsw_i ) , A_MONSTER , UB_RECORD_SIZE )
                s_core_ram_copy( A_MONSTER , fuw_inv_record( lsw_i + 1 ) , UB_RECORD_SIZE )
                lsw_i = lsw_i - 1
            End While
            s_core_ram_copy( A_ITEM , fuw_inv_record( lub_place ) , UB_RECORD_SIZE )
            gsw_player_pack_unique = gsw_player_pack_unique + 1
            Exit While
        End If
        lub_place = lub_place + 1
    End While

    gsw_player_pack_weight = gsw_player_pack_weight + Cast( Integer , gub_item_count ) * guw_item_weight
    gul_player_status      = gul_player_status bOr UL_PY_STR_WGT
    Return lub_place
End Function


Sub s_inv_strength()
    ' Moria's playerStrength(): how much the player can carry is 130 for each point of strength plus their own weight,
    ' to a limit of 3000, and the pack slows them down by one for every time its weight goes into that again
    Dim lsw_limit   As Integer
    Dim luw_weapon  As UInteger
    Dim lub_heavy   As UByte

    ' is the weapon too heavy to wield properly? the bonuses library takes it off the chance to hit, a category of 0 is no weapon at all
    luw_weapon = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_WIELD ) * UB_RECORD_SIZE
    lub_heavy  = false
    If Peek( luw_weapon + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
        If Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) * 15 < Peek( Integer , luw_weapon + UB_ITEM_WEIGHT_OFFSET ) Then lub_heavy = true
    End If
    If lub_heavy Then
        If gub_player_weapon_heavy = false Then
            s_core_message( UW_MSG_YOU_HAVE_TROUBLE_WIELDING_SUCH_A )
            gub_player_weapon_heavy = true
            s_core_call_library( UB_PAGED_CODE_LIB_BONUSES , UB_LIB_BONUSES_RECALC )
        End If
    ElseIf gub_player_weapon_heavy Then
        gub_player_weapon_heavy = false
        If Peek( luw_weapon + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then s_core_message( UW_MSG_YOU_ARE_STRONG_ENOUGH_TO_WIELD )
        s_core_call_library( UB_PAGED_CODE_LIB_BONUSES , UB_LIB_BONUSES_RECALC )
    End If

    lsw_limit = Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) * UB_PLAYER_WEIGHT_CAP + guw_player_weight
    If lsw_limit > 3000 Then lsw_limit = 3000
    If lsw_limit < gsw_player_pack_weight Then
        lsw_limit = gsw_player_pack_weight / ( lsw_limit + 1 )
    Else
        lsw_limit = 0
    End If
    If gsw_player_pack_heaviness <> lsw_limit Then
        If gsw_player_pack_heaviness < lsw_limit Then
            s_core_message( UW_MSG_YOUR_PACK_IS_SO_HEAVY_THAT_IT )
        Else
            s_core_message( UW_MSG_YOU_MOVE_MORE_EASILY_UNDER_THE )
        End If
        ' Moria's playerChangeSpeed(): the monsters' speeds change by the same amount, the second turn library does it
        guw_lib_param_2 = Cast( UInteger , lsw_limit - gsw_player_pack_heaviness )
        gsw_player_pack_heaviness = lsw_limit
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
    End If
    gul_player_status = gul_player_status bAnd ( $FFFFFFFF - UL_PY_STR_WGT )
End Sub


Sub s_inv_set_kind_known( pub_category As UByte , pub_sub_category As UByte , pub_tried_only As UByte )
    ' marks a kind of thing as known to the player and no longer just "tried", Moria's itemSetAsIdentified(), or with
    ' pub_tried_only just clears "tried", the last line of Moria's unsample()
    Dim lub_family , lub_page   As UByte
    Dim luw_flags               As UInteger

    lub_family = 255
    If pub_category = UB_TV_AMULET Then lub_family = 0
    If pub_category = UB_TV_RING Then lub_family = 1
    If pub_category = UB_TV_STAFF Then lub_family = 2
    If pub_category = UB_TV_WAND Then lub_family = 3
    If pub_category = UB_TV_SCROLL1 Or pub_category = UB_TV_SCROLL2 Then lub_family = 4
    If pub_category = UB_TV_POTION1 Or pub_category = UB_TV_POTION2 Then lub_family = 5
    If pub_category = UB_TV_FOOD Then
        If ( pub_sub_category bAnd 63 ) < UB_MAX_MUSHROOMS Then lub_family = 6
    End If
    If lub_family = 255 Then Return

    lub_page = gub_core_MMU2_page_number
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
    luw_flags = A_KNOW_IDENTIFIED + ( Cast( UInteger , lub_family ) << 6 ) + ( pub_sub_category bAnd 63 )
    If pub_tried_only = 2 Then
        ' Moria's itemSetAsTried()
        Poke luw_flags , Peek( luw_flags ) bOr MB_OD_TRIED
    ElseIf pub_tried_only Then
        Poke luw_flags , Peek( luw_flags ) bAnd ( 255 - MB_OD_TRIED )
    Else
        Poke luw_flags , ( Peek( luw_flags ) bOr MB_OD_KNOWN1 ) bAnd ( 255 - MB_OD_TRIED )
    End If
    If lub_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_page )
End Sub


Sub s_inv_close_gap( pub_place As UByte )
    ' takes one place out of the pack altogether: everything after it moves up one, and the place left at the end is blanked
    Dim i As UByte

    i = pub_place
    While Cast( Integer , i ) + 1 < gsw_player_pack_unique
        s_core_ram_copy( fuw_inv_record( i + 1 ) , fuw_inv_record( i ) , UB_RECORD_SIZE )
        i = i + 1
    End While
    For i = 0 To UB_RECORD_SIZE - 1
        Poke fuw_inv_record( gsw_player_pack_unique - 1 ) + i , 0
    Next
    gsw_player_pack_unique = gsw_player_pack_unique - 1
End Sub


Sub s_inv_destroy( pub_place As UByte )
    ' Moria's inventoryDestroyItem()
    Dim luw_record              As UInteger
    Dim lub_count , lub_sub     As UByte
    Dim luw_weight              As UInteger

    luw_record = fuw_inv_record( pub_place )
    lub_count  = Peek( luw_record + UB_ITEM_COUNT_OFFSET )
    lub_sub    = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET )
    luw_weight = Peek( UInteger , luw_record + UB_ITEM_WEIGHT_OFFSET )
    If lub_count > 1 And lub_sub <= UB_ITEM_SINGLE_STACK_MAX Then
        Poke luw_record + UB_ITEM_COUNT_OFFSET , lub_count - 1
        gsw_player_pack_weight = gsw_player_pack_weight - luw_weight
    Else
        gsw_player_pack_weight = gsw_player_pack_weight - luw_weight * lub_count
        s_inv_close_gap( pub_place )
    End If
    gul_player_status = gul_player_status bOr UL_PY_STR_WGT
End Sub


Function fub_inv_identify( pub_place As UByte ) As UByte
    ' Moria's itemIdentify(): the player now knows what kind of thing this is, a cursed one is marked "damned", and if
    ' the pack already holds the same kind, bought in a store say, the two lots are put together
    Dim luw_record , luw_other              As UInteger
    Dim lub_category , lub_sub , i , j      As UByte
    Dim lub_place                           As UByte

    lub_place    = pub_place
    luw_record   = fuw_inv_record( lub_place )
    lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
    lub_sub      = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET )

    If ( Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET ) bAnd UL_TR_CURSED ) <> 0 Then
        Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bOr MB_ID_DAMD
    End If
    If fub_inv_kind_is_known( lub_category , lub_sub , Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) ) Then Return lub_place

    s_inv_set_kind_known( lub_category , lub_sub , false )

    ' cmp tval first, because tval/subval is not unique for the things that never stack
    If lub_sub < UB_ITEM_SINGLE_STACK_MIN Or lub_sub > UB_ITEM_SINGLE_STACK_MAX Then Return lub_place

    i = 0
    While Cast( Integer , i ) < gsw_player_pack_unique
        luw_other = fuw_inv_record( i )
        If i <> lub_place And Peek( luw_other + UB_ITEM_CATEGORY_OFFSET ) = lub_category And Peek( luw_other + UB_ITEM_SUB_CATEGORY_OFFSET ) = lub_sub Then
            If Cast( UInteger , Peek( luw_other + UB_ITEM_COUNT_OFFSET ) ) + Peek( fuw_inv_record( lub_place ) + UB_ITEM_COUNT_OFFSET ) < 256 Then
                ' make *item_id the smaller number
                If lub_place > i Then
                    j = lub_place
                    lub_place = i
                    i = j
                End If
                s_core_message( UW_MSG_YOU_COMBINE_SIMILAR_OBJECTS_FROM )
                Poke fuw_inv_record( lub_place ) + UB_ITEM_COUNT_OFFSET , Peek( fuw_inv_record( lub_place ) + UB_ITEM_COUNT_OFFSET ) + Peek( fuw_inv_record( i ) + UB_ITEM_COUNT_OFFSET )
                s_inv_close_gap( i )
            End If
        End If
        i = i + 1
    End While
    Return lub_place
End Function


Sub s_inv_know_fully()
    ' Moria's spellItemIdentifyAndRemoveRandomInscription(), for the working item
    gub_item_identification = gub_item_identification bAnd ( 255 - ( MB_ID_MAGIK bOr MB_ID_EMPTY ) )
    s_inv_set_kind_known( gub_item_category , gub_item_sub_category , true )
    gub_item_identification = gub_item_identification bOr MB_ID_KNOWN2
End Sub


Sub s_inv_new_character()
    ' Moria's initializeCharacterInventory(): nothing carried and nothing worn, then the five things the class starts
    ' with, each known as if bought in a store, and no spell learnt yet
    Dim luw_i , luw_object          As UInteger
    Dim i                           As UByte

    For luw_i = 0 To Cast( UInteger , UB_INVENTORY_SIZE ) * UB_RECORD_SIZE - 1
        Poke A_INVENTORY + luw_i , 0
    Next
    For i = 0 To 4
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_CHARACTER_DB )
        luw_object = Peek( UInteger , A_CHARACTER_PROVISIONS + Cast( UInteger , gub_player_class ) * 10 + Cast( UInteger , i ) * 2 )
        guw_lib_param_2 = luw_object
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_FROM_OBJECT )
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_STORE_BOUGHT )
        If gub_item_category = UB_TV_SWORD Then gub_item_identification = gub_item_identification bOr MB_ID_SHOW_HIT_DAM
        gub_shared_1 = fub_inv_carry()
    Next
    ' weird place for it, but why not?
    For i = 0 To UB_SPELL_ORDER_SIZE - 1
        Poke A_PLAYER_SPELL_ORDER + i , UB_SPELL_ORDER_END
    Next
End Sub


Function fub_inv_show_list( pub_first As UByte , pub_last As UByte , pub_weighted As UByte ) As UByte
    ' lists the pack from one place to another on the screen, from row 1 down, leaving out those the mask rules out,
    ' as far to the right as the longest line allows, Moria's displayInventoryItems(), the answer is how many rows it took
    ' pub_weighted is true if each thing's weight is to be shown too, at the right hand edge, " 12.5 lb"
    Dim i , lub_length , lub_longest , lub_col , lub_row        As UByte
    Dim lub_limit                                               As UByte = 72
    Dim luw_weight                                              As UInteger
    Dim ls_weight                                               As String

    If pub_weighted Then lub_limit = 64

    ' how long the longest line will be
    lub_longest = 0
    For i = pub_first To pub_last
        If Peek( A_INV_MASK + i ) <> 0 Then
            s_core_ram_copy( fuw_inv_record( i ) , A_ITEM , UB_RECORD_SIZE )
            gub_lib_param_1 = true
            s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
            lub_length = 0
            While Peek( A_TEXT_BUFFER + lub_length ) <> 0 And lub_length < lub_limit
                lub_length = lub_length + 1
            End While
            If pub_weighted Then lub_length = lub_length + 9
            If lub_length + 5 > lub_longest Then lub_longest = lub_length + 5
        End If
    Next
    lub_col = 0
    If lub_longest < 79 Then lub_col = 79 - lub_longest

    lub_row = 1
    For i = pub_first To pub_last
        If Peek( A_INV_MASK + i ) <> 0 Then
            s_core_ram_copy( fuw_inv_record( i ) , A_ITEM , UB_RECORD_SIZE )
            gub_lib_param_1 = true
            s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
            Poke A_TEXT_BUFFER + lub_limit , 0          ' a line is cut to fit
            s_core_clear_row( lub_row , lub_col , UB_WHITE )
            s_core_print_string_at( lub_row , lub_col + 2 , fs_core_char( 97 + i ) + ")" , UB_WHITE )
            gub_shared_1 = fub_core_print_text_at( lub_row , lub_col + 5 , A_TEXT_BUFFER , UB_WHITE )
            If pub_weighted Then
                ' Moria's inventoryItemWeightText(): all of them together, in pounds and tenths
                luw_weight = Peek( UInteger , fuw_inv_record( i ) + UB_ITEM_WEIGHT_OFFSET ) * Peek( fuw_inv_record( i ) + UB_ITEM_COUNT_OFFSET )
                ls_weight  = fs_core_number( luw_weight / 10 )
                While Len( ls_weight ) < 3
                    ls_weight = " " + ls_weight
                End While
                s_core_print_string_at( lub_row , 71 , ls_weight + "." + fs_core_number( luw_weight Mod 10 ) + " lb" , UB_WHITE )
            End If
            lub_row = lub_row + 1
        End If
    Next
    Return lub_row - 1
End Function


Function fub_inv_verify( pub_place As UByte , pub_mode As UByte ) As UByte
    ' Moria's verifyAction(), asked when a thing is picked with a capital letter: "Try a Dagger (1d4)?", true for y
    Dim ls_prompt   As String
    Dim i           As UByte

    s_core_ram_copy( fuw_inv_record( pub_place ) , A_ITEM , UB_RECORD_SIZE )
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    ' change the period to a question mark
    i = 0
    While Peek( A_TEXT_BUFFER + i ) <> 0
        i = i + 1
    End While
    If i > 0 Then Poke A_TEXT_BUFFER + i - 1 , Code( "?" )
    Poke A_TEXT_BUFFER + 66 , 0                         ' cut to leave room for the [y/n]
    ls_prompt = "Try "
    If pub_mode = UB_INV_CHOOSE_WEAR Then ls_prompt = "Wear/Wield "
    If pub_mode = UB_INV_CHOOSE_DROP Then
        ls_prompt = "Drop "
        If pub_place >= UB_PACK_SIZE Then ls_prompt = "Throw off "
    End If
    If pub_mode = UB_INV_CHOOSE_TAKE_OFF Then ls_prompt = "Take off "
    ls_prompt = ls_prompt + fs_core_text_at( A_TEXT_BUFFER ) + " [y/n]"
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , ls_prompt , UB_BRIGHT_WHITE )
    Do
        s_core_get_key()
    Loop While gub_key_char = UC_SPACE
    s_msg_clear()
    If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then Return true
    Return false
End Function


Function fsw_inv_choose( pub_first As UByte , pub_last As UByte , pub_mode As UByte ) As Integer
    ' Moria's inventoryGetInputForItemId(): the player picks a place by its letter, or by a digit that is the whole
    ' of a thing's inscription, * puts the list up, and a capital letter picks after "are you sure"
    ' pub_last of UB_INVENTORY_SIZE means "anything carried, worn or not": / then goes between the pack and what is
    ' worn, and the place that comes back may be one of the equipment's, 22 to 33
    ' pub_mode is one of the UB_INV_CHOOSE_ values in constants.bas, the word the capital letter question uses,
    ' and whether picking something the mask rules out gets "I do not buy such items."
    ' N.B: while the list is up it covers part of the screen, so the screen is put aside first, in the corridor
    ' scratchpad page, and put back afterwards (Moria's terminalSaveScreen() and terminalRestoreScreen())
    Dim lsw_place , lsw_choice , lsw_line       As Integer
    Dim lub_menu , lub_done , lub_saved_page    As UByte
    Dim lub_full , lub_equip , lub_end          As UByte
    Dim lub_key , lub_capital , i               As UByte
    Dim ls_prompt                               As String

    lsw_place = -1
    lub_full  = false
    lub_equip = false
    lub_end   = pub_last
    If pub_last > UB_PACK_SIZE Then
        lub_full = true
        If gsw_player_pack_unique = 0 Then
            lub_equip = true
            lub_end   = gsw_player_equipment_count - 1
        Else
            lub_end   = gsw_player_pack_unique - 1
        End If
    End If
    If gsw_player_pack_unique < 1 And ( lub_full = false Or gsw_player_equipment_count < 1 ) Then
        s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING )
        Return -1
    End If

    lub_menu = false
    lub_done = false
    While lub_done = false
        If lub_menu Then
            ' N.B: the screen as it was first, the list before may have been the longer
            s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
            s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
            If lub_equip Then
                s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_SHOW )
            Else
                gub_shared_1 = fub_inv_show_list( pub_first , lub_end , false )
            End If
        End If
        If lub_full Then
            If lub_equip Then
                ls_prompt = "(Equip: "
            Else
                ls_prompt = "(Inven: "
            End If
        Else
            ls_prompt = "(Items "
        End If
        ls_prompt = ls_prompt + fs_core_char( 97 + pub_first ) + "-" + fs_core_char( 97 + lub_end ) + ","
        If lub_equip = false Then ls_prompt = ls_prompt + " 0-9,"
        If lub_full Then
            If lub_menu = false Then ls_prompt = ls_prompt + " * to see,"
            If lub_equip Then
                ls_prompt = ls_prompt + " / for Inven, or ESC) "
            Else
                ls_prompt = ls_prompt + " / for Equip, or ESC) "
            End If
        Else
            If lub_menu = false Then ls_prompt = ls_prompt + " * for inventory list,"
            ls_prompt = ls_prompt + " ESC to exit) "
        End If
        ' the question is the caller's, if it left one in A_PROMPT
        If Peek( A_PROMPT ) <> 0 Then
            ls_prompt = ls_prompt + fs_core_text_at( A_PROMPT )
        Else
            ls_prompt = ls_prompt + "Which one? "
        End If
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , ls_prompt , UB_BRIGHT_WHITE )

        s_core_get_key()
        lub_key = gub_key_char
        If lub_key = UC_ESCAPE Or guw_key_code = 0 Then
            ' backing out takes no time, Moria sets player_free_turn here itself
            lub_done = true
            gub_game_free_turn = true
        ElseIf lub_key = Code( "/" ) And lub_full Then
            ' Moria's inventorySwitchPackMenu()
            If lub_equip = false Then
                If gsw_player_equipment_count = 0 Then
                    s_msg_clear()
                    s_core_print_string_at( 0 , 0 , "But you're not using anything -more-" , UB_BRIGHT_WHITE )
                    s_core_get_key()
                Else
                    lub_equip = true
                    lub_end   = gsw_player_equipment_count - 1
                End If
            ElseIf gsw_player_pack_unique = 0 Then
                s_msg_clear()
                s_core_print_string_at( 0 , 0 , "But you're not carrying anything -more-" , UB_BRIGHT_WHITE )
                s_core_get_key()
            Else
                lub_equip = false
                lub_end   = gsw_player_pack_unique - 1
            End If
        ElseIf lub_key = Code( "*" ) Then
            If lub_menu = false Then
                lub_saved_page = gub_core_MMU0_page_number
                s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
                s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , UW_SCREEN_CELLS_SIZE )
                lub_menu = true
            End If
        Else
            lsw_choice  = -1
            lub_capital = false
            If lub_key >= Code( "0" ) And lub_key <= Code( "9" ) And lub_equip = false Then
                ' look for the item whose inscription is this digit and nothing more
                i = pub_first
                While i < UB_PACK_SIZE And lsw_choice < 0
                    If Peek( fuw_inv_record( i ) + UB_ITEM_INSCRIPTION_OFFSET ) = lub_key And Peek( fuw_inv_record( i ) + UB_ITEM_INSCRIPTION_OFFSET + 1 ) = 0 Then lsw_choice = i
                    i = i + 1
                End While
            ElseIf lub_key >= Code( "A" ) And lub_key <= Code( "Z" ) Then
                lub_capital = true
                lsw_choice  = lub_key - Code( "A" )
            ElseIf lub_key >= Code( "a" ) And lub_key <= Code( "z" ) Then
                lsw_choice  = lub_key - Code( "a" )
            End If
            If lsw_choice >= pub_first And lsw_choice <= lub_end Then
                If lub_equip Then
                    ' its place in the equipment list, which leaves out what is empty
                    lsw_line   = lsw_choice
                    lsw_choice = UB_PACK_SIZE - 1
                    Do
                        lsw_choice = lsw_choice + 1
                        If Peek( fuw_inv_record( lsw_choice ) + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then lsw_line = lsw_line - 1
                    Loop While lsw_line >= 0 And lsw_choice < UB_INVENTORY_SIZE - 1
                ElseIf Peek( A_INV_MASK + lsw_choice ) = 0 Then
                    lsw_choice = -1
                End If
            Else
                lsw_choice = -1
            End If
            If lsw_choice >= 0 Then
                lub_done = true
                lsw_place = lsw_choice
                If lub_capital Then
                    If fub_inv_verify( lsw_choice , pub_mode ) = false Then
                        lsw_place = -1
                        gub_game_free_turn = true
                    End If
                End If
            ElseIf pub_mode = UB_INV_CHOOSE_REFUSE Then
                s_core_message( UW_MSG_I_DO_NOT_BUY_SUCH_ITEMS )
            End If
        End If
    End While

    If lub_menu Then
        s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
        s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
        If lub_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , lub_saved_page )
    End If
    s_msg_clear()
    Poke A_PROMPT , 0
    Return lsw_place
End Function


Sub s_lib_inventory()
    If gub_lib_function = UB_LIB_INV_CAN_CARRY Then
        gsw_lib_result = fub_inv_can_carry()
    ElseIf gub_lib_function = UB_LIB_INV_CARRY Then
        gsw_lib_result = fub_inv_carry()
    ElseIf gub_lib_function = UB_LIB_INV_STRENGTH Then
        s_inv_strength()
    ElseIf gub_lib_function = UB_LIB_INV_NEW_CHARACTER Then
        s_inv_new_character()
    ElseIf gub_lib_function = UB_LIB_INV_DESTROY Then
        s_inv_destroy( Cast( UByte , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_INV_IDENTIFY Then
        gsw_lib_result = fub_inv_identify( Cast( UByte , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_INV_KNOW_FULLY Then
        s_inv_know_fully()
    ElseIf gub_lib_function = UB_LIB_INV_IDENTIFY_WORKING Then
        ' the start of Moria's itemIdentify(), for the working item, which is not in the pack: a cursed one is
        ' marked "damned", and the player now knows what kind of thing it is
        If ( gul_item_flags bAnd UL_TR_CURSED ) <> 0 Then gub_item_identification = gub_item_identification bOr MB_ID_DAMD
        If fub_inv_kind_is_known( gub_item_category , gub_item_sub_category , gub_item_identification ) = false Then s_inv_set_kind_known( gub_item_category , gub_item_sub_category , false )
    ElseIf gub_lib_function = UB_LIB_INV_REMOVE_ALL Then
        ' everything in a place of the pack goes, however many, as when it is all dropped
        gsw_player_pack_weight = gsw_player_pack_weight - Peek( Integer , fuw_inv_record( Cast( UByte , guw_lib_param_2 ) ) + UB_ITEM_WEIGHT_OFFSET ) * Cast( Integer , Peek( fuw_inv_record( Cast( UByte , guw_lib_param_2 ) ) + UB_ITEM_COUNT_OFFSET ) )
        s_inv_close_gap( Cast( UByte , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_INV_TRIED Then
        s_inv_set_kind_known( Peek( fuw_inv_record( Cast( UByte , guw_lib_param_2 ) ) + UB_ITEM_CATEGORY_OFFSET ) , Peek( fuw_inv_record( Cast( UByte , guw_lib_param_2 ) ) + UB_ITEM_SUB_CATEGORY_OFFSET ) , 2 )
    ElseIf gub_lib_function = UB_LIB_INV_SHOW Then
        gsw_lib_result = fub_inv_show_list( Cast( UByte , guw_lib_param_2 bAnd 255 ) , Cast( UByte , guw_lib_param_2 >> 8 ) , ( guw_game_options bAnd MW_OPTION_SHOW_WEIGHTS ) <> 0 )
    ElseIf gub_lib_function = UB_LIB_INV_VERIFY Then
        gsw_lib_result = fub_inv_verify( Cast( UByte , guw_lib_param_2 ) , gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_INV_CHOOSE Then
        gsw_lib_result = fsw_inv_choose( Cast( UByte , guw_lib_param_2 bAnd 255 ) , Cast( UByte , guw_lib_param_2 >> 8 ) , gub_lib_param_1 )
    End If
End Sub
