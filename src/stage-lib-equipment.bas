#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_equipment()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: what the player is wearing and wielding, and the commands for looking at
' and changing it, the working parts of Moria's ui_inventory.cpp and the bonus routines of its player.cpp...
' ...any stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , <which routine> ), the routines are:
'
'   UB_LIB_EQUIP_COMMAND    carries out one of the inventory commands, the key pressed is in gub_lib_param_1:
'                               i   list what is in the pack
'                               e   list what is being worn and wielded
'                               w   wear or wield something from the pack
'                               t   take something off
'                               x   exchange the weapon in hand with the spare
'                           a list goes over the screen and the screen is put back afterwards, when the command is
'                           done the player's bonuses are worked out afresh
'   UB_LIB_EQUIP_RECALC     works out the player's bonuses afresh from everything worn, which is passed on to the
'                           bonuses library, stage-lib-bonuses.bas
'   UB_LIB_EQUIP_SHOW       lists what is worn and wielded, from row 1 down, for the inventory library's chooser,
'                           gsw_lib_result is how many lines
'   UB_LIB_EQUIP_THROW_OFF  the thing in equipment place guw_lib_param_2 (22 to 33) is taken off and dropped where the
'                           player stands, for the drop command, gsw_lib_result is true if it was
'   UB_LIB_EQUIP_USE_STAT   the natural value of stat gub_lib_param_1 has changed: works out the value the game
'                           uses, and what follows from it, Moria's playerSetAndUseStat()
'
' N.B: the equipment is places 22 to 33 of the one list of 34 records at A_INVENTORY, in Moria's order, see UB_EQUIP_
' in constants.bas, an empty place is all zeros, i.e. category 0
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - Moria keeps its lists on the screen and lets one command lead straight into another, here each command is
'     asked for, done, and the screen put back


' --- its working storage is in globals.bas, under "private to stage-lib-equipment.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- small helpers ---

Function fuw_eq_record( pub_place As UByte ) As UInteger
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Function fub_eq_category( pub_place As UByte ) As UByte
    Return Peek( fuw_eq_record( pub_place ) + UB_ITEM_CATEGORY_OFFSET )
End Function


Function fub_eq_cursed( pub_place As UByte ) As UByte
    ' Moria's inventoryItemIsCursed()
    If ( Peek( ULong , fuw_eq_record( pub_place ) + UB_ITEM_FLAGS_OFFSET ) bAnd UL_TR_CURSED ) <> 0 Then Return true
    Return false
End Function


Sub s_eq_screen_save()
    ' puts the screen aside, in the corridor scratchpad page, Moria's terminalSaveScreen()
    gub_eq_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , UW_SCREEN_CELLS_SIZE )
    If gub_eq_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_eq_saved_page )
    gub_eq_screen_saved = true
End Sub


Sub s_eq_screen_restore()
    If gub_eq_screen_saved = false Then Return
    gub_eq_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
    If gub_eq_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_eq_saved_page )
    gub_eq_screen_saved = false
    gub_message_length  = 0
End Sub


Sub s_eq_describe( pub_place As UByte , pub_full As UByte )
    ' the description of what is in a place, left in A_TEXT_BUFFER, pub_full false gives just its name
    s_core_ram_copy( fuw_eq_record( pub_place ) , A_ITEM , UB_RECORD_SIZE )
    gub_lib_param_1 = pub_full
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
End Sub


Sub s_eq_say( ps_before As String , ps_after As String )
    ' a message with the description that is in A_TEXT_BUFFER in the middle of it, Moria's printMessage(): put after
    ' the message showing if the two fit, -more- if not, and remembered for Ctrl-P
    ' N.B: until 21 October 2026 it was printed straight on to the top row, after a -more- of its own, and so never
    ' reached the history (found by the bow comparison, Umoria's Ctrl-P had "You are wielding ..." and ours did not)
    s_msg( ps_before + fs_core_text_at( A_TEXT_BUFFER ) + ps_after )
End Sub


Function fub_eq_line_of( pub_place As UByte ) As UByte
    ' which line of the equipment list a place is on, 0 for the first, the list leaves out the empty places
    Dim i , lub_line As UByte

    lub_line = 0
    i = UB_EQ_FIRST
    While i < pub_place
        If fub_eq_category( i ) <> 0 Then lub_line = lub_line + 1
        i = i + 1
    End While
    Return lub_line
End Function


'##################################################################################################################################
' --- what wearing a thing does ---

Sub s_eq_use_stat( pub_stat As UByte )
    ' works out the value of one stat that the game uses, from its natural value and what equipment adds or takes away,
    ' Moria's playerModifyStat(), the character library does the same for all six at once when a character is made
    Dim lub_value , lub_step    As UByte
    Dim lsw_amount , lsw_steps  As Integer

    lub_value  = Peek( A_PLAYER_STATS_CURRENT + pub_stat )
    lsw_amount = Peek( Integer , A_PLAYER_STATS_MODIFIED + 2 * Cast( UInteger , pub_stat ) )
    lsw_steps  = Abs( lsw_amount )
    lub_step   = 0
    While lub_step < lsw_steps
        If lsw_amount > 0 Then
            If lub_value < 18 Then
                lub_value = lub_value + 1
            ElseIf lub_value < 108 Then
                lub_value = lub_value + 10
            Else
                lub_value = 118
            End If
        Else
            If lub_value > 27 Then
                lub_value = lub_value - 10
            ElseIf lub_value > 18 Then
                lub_value = 18
            ElseIf lub_value > 3 Then
                lub_value = lub_value - 1
            End If
        End If
        lub_step = lub_step + 1
    End While
    Poke A_PLAYER_STATS_USED + pub_stat , lub_value
End Sub


Sub s_eq_adjust( pub_place As UByte , psw_factor As Integer )
    ' adds, or with a factor of -1 takes away, what the thing in a place does for the player just by being worn,
    ' Moria's playerAdjustBonusesForItem(): only the effects that add up are here, the rest are worked out afresh
    ' from everything worn by s_eq_recalc()
    Dim lul_flags       As ULong
    Dim lsw_amount      As Integer
    Dim i               As UByte
    Dim luw_modified    As UInteger

    lul_flags  = Peek( ULong , fuw_eq_record( pub_place ) + UB_ITEM_FLAGS_OFFSET )
    lsw_amount = Peek( Integer , fuw_eq_record( pub_place ) + UB_ITEM_MISC_USE_OFFSET ) * psw_factor

    If ( lul_flags bAnd UL_TR_STATS ) <> 0 Then
        ' the low six flags are the six stats, in the usual order, Moria's playerStatBoost()
        For i = 0 To 5
            If ( lul_flags bAnd ( Cast( ULong , 1 ) << i ) ) <> 0 Then
                luw_modified = A_PLAYER_STATS_MODIFIED + 2 * Cast( UInteger , i )
                Poke UInteger luw_modified , Cast( UInteger , Peek( Integer , luw_modified ) + lsw_amount )
                s_eq_use_stat( i )
            End If
        Next
    End If
    If ( lul_flags bAnd UL_TR_SEARCH ) <> 0 Then
        gsw_player_search = gsw_player_search + lsw_amount
        gsw_player_fos    = gsw_player_fos - lsw_amount
    End If
    If ( lul_flags bAnd UL_TR_STEALTH ) <> 0 Then gsw_player_stealth = gsw_player_stealth + lsw_amount
    If ( lul_flags bAnd UL_TR_SPEED ) <> 0 Then
        ' Moria's playerChangeSpeed(): the monsters' speeds change by the same amount, the second turn library does it
        guw_lib_param_2 = Cast( UInteger , -lsw_amount )
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
    End If
    If ( lul_flags bAnd UL_TR_BLIND ) <> 0 And psw_factor > 0 Then gsw_player_blind = gsw_player_blind + 1000
    If ( lul_flags bAnd UL_TR_TIMID ) <> 0 And psw_factor > 0 Then gsw_player_afraid = gsw_player_afraid + 50
    If ( lul_flags bAnd UL_TR_INFRA ) <> 0 Then gsw_player_see_infra = gsw_player_see_infra + lsw_amount
End Sub


'##################################################################################################################################
' --- taking off and putting on ---

Sub s_eq_take_off( pub_place As UByte , psw_pack_place As Integer )
    ' the thing in an equipment place stops being worn, Moria's playerTakeOff(), psw_pack_place is where in the pack
    ' it has gone, for the message, or -1
    Dim luw_record  As UInteger
    Dim i           As UByte
    Dim ls_how      As String

    luw_record = fuw_eq_record( pub_place )
    ' something has changed, so this command takes the player's turn
    gub_game_free_turn = false
    gul_player_status = gul_player_status bOr UL_PY_STR_WGT
    gsw_player_pack_weight = gsw_player_pack_weight - Peek( UInteger , luw_record + UB_ITEM_WEIGHT_OFFSET ) * Peek( luw_record + UB_ITEM_COUNT_OFFSET )
    gsw_player_equipment_count = gsw_player_equipment_count - 1

    If pub_place = UB_EQ_FIRST + UB_EQUIP_WIELD Or pub_place = UB_EQ_FIRST + UB_EQUIP_AUXILIARY Then
        ls_how = "Was wielding "
    ElseIf pub_place = UB_EQ_FIRST + UB_EQUIP_LIGHT Then
        ls_how = "Light source was "
    Else
        ls_how = "Was wearing "
    End If
    s_eq_describe( pub_place , true )
    If psw_pack_place >= 0 Then
        s_eq_say( ls_how , " (" + fs_core_char( 97 + psw_pack_place ) + ")" )
    Else
        s_eq_say( ls_how , "" )
    End If

    ' no extra bonuses for the spare weapon, so none to take away
    If pub_place <> UB_EQ_FIRST + UB_EQUIP_AUXILIARY Then s_eq_adjust( pub_place , -1 )
    For i = 0 To UB_RECORD_SIZE - 1
        Poke luw_record + i , 0
    Next
End Sub


Function fsw_eq_slot_for( pub_category As UByte ) As Integer
    ' which equipment place a thing of this category goes in, Moria's inventoryGetSlotToWearEquipment(), -1 for nowhere
    Dim lsw_hand As Integer

    If pub_category = UB_TV_SLING_AMMO Or pub_category = UB_TV_BOLT Or pub_category = UB_TV_ARROW Or pub_category = UB_TV_BOW Or pub_category = UB_TV_HAFTED Or pub_category = UB_TV_POLEARM Or pub_category = UB_TV_SWORD Or pub_category = UB_TV_DIGGING Or pub_category = UB_TV_SPIKE Then Return UB_EQ_FIRST + UB_EQUIP_WIELD
    If pub_category = UB_TV_LIGHT Then Return UB_EQ_FIRST + UB_EQUIP_LIGHT
    If pub_category = UB_TV_BOOTS Then Return UB_EQ_FIRST + UB_EQUIP_FEET
    If pub_category = UB_TV_GLOVES Then Return UB_EQ_FIRST + UB_EQUIP_HANDS
    If pub_category = UB_TV_CLOAK Then Return UB_EQ_FIRST + UB_EQUIP_OUTER
    If pub_category = UB_TV_HELM Then Return UB_EQ_FIRST + UB_EQUIP_HEAD
    If pub_category = UB_TV_SHIELD Then Return UB_EQ_FIRST + UB_EQUIP_ARM
    If pub_category = UB_TV_HARD_ARMOR Or pub_category = UB_TV_SOFT_ARMOR Then Return UB_EQ_FIRST + UB_EQUIP_BODY
    If pub_category = UB_TV_AMULET Then Return UB_EQ_FIRST + UB_EQUIP_NECK
    If pub_category = UB_TV_RING Then
        If fub_eq_category( UB_EQ_FIRST + UB_EQUIP_RIGHT ) = 0 Then Return UB_EQ_FIRST + UB_EQUIP_RIGHT
        If fub_eq_category( UB_EQ_FIRST + UB_EQUIP_LEFT ) = 0 Then Return UB_EQ_FIRST + UB_EQUIP_LEFT
        ' both hands have a ring already: ask which to change, Moria's requestPutRingOnWhichHand()
        lsw_hand = 0
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "Put ring on which hand (l/r/L/R)?" , UB_BRIGHT_WHITE )
        While lsw_hand = 0
            s_core_get_key()
            If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then lsw_hand = -1
            If gub_key_char = Code( "l" ) Or gub_key_char = Code( "L" ) Then lsw_hand = UB_EQ_FIRST + UB_EQUIP_LEFT
            If gub_key_char = Code( "r" ) Or gub_key_char = Code( "R" ) Then lsw_hand = UB_EQ_FIRST + UB_EQUIP_RIGHT
        End While
        s_msg_clear()
        Return lsw_hand
    End If
    s_core_message( UW_MSG_IMPOSSIBLE_I_DONT_SEE_HOW_YOU_CAN )
    Return -1
End Function


Sub s_eq_wear( pub_pack_place As UByte )
    ' the player puts on, or takes up, the thing in a place in the pack, Moria's executeWearItemCommand():
    ' whatever was in its place before goes back into the pack
    Dim lsw_slot , lsw_carried      As Integer
    Dim lub_slot , lub_count , i    As UByte
    Dim luw_record                  As UInteger
    Dim ls_how                      As String

    lsw_slot = fsw_eq_slot_for( fub_eq_category( pub_pack_place ) )
    If lsw_slot < 0 Then Return
    lub_slot = lsw_slot

    If fub_eq_category( lub_slot ) <> 0 Then
        If fub_eq_cursed( lub_slot ) Then
            ' Moria's inventoryItemIsCursedMessage(), N.B: it says "wielding" for what is on the head and "wearing"
            ' for everything else, the weapon included, that is how Moria has it
            s_eq_describe( lub_slot , false )
            If lub_slot = UB_EQ_FIRST + UB_EQUIP_HEAD Then
                s_eq_say( "The " , " you are wielding appears to be cursed." )
            Else
                s_eq_say( "The " , " you are wearing appears to be cursed." )
            End If
            Return
        End If
        luw_record = fuw_eq_record( pub_pack_place )
        If Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET ) = UB_ITEM_GROUP_MIN And Peek( luw_record + UB_ITEM_COUNT_OFFSET ) > 1 Then
            s_core_ram_copy( fuw_eq_record( lub_slot ) , A_ITEM , UB_RECORD_SIZE )
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CAN_CARRY )
            If gsw_lib_result = false Then
                s_core_message( UW_MSG_YOU_WILL_HAVE_TO_DROP_SOMETHING )
                Return
            End If
        End If
    End If

    ' something is being put on, so this command takes the player's turn
    gub_game_free_turn = false

    ' the thing itself, one of it if it is the kind that stacks singly, is kept aside while its place is made ready
    s_core_ram_copy( fuw_eq_record( pub_pack_place ) , A_EQ_SAVED , UB_RECORD_SIZE )
    lub_count = Peek( A_EQ_SAVED + UB_ITEM_COUNT_OFFSET )
    If lub_count > 1 And Peek( A_EQ_SAVED + UB_ITEM_SUB_CATEGORY_OFFSET ) <= UB_ITEM_SINGLE_STACK_MAX Then
        lub_count = 1
        Poke A_EQ_SAVED + UB_ITEM_COUNT_OFFSET , 1
    End If
    ' it leaves the pack, taking it out subtracts its weight, which is still being carried, so that is added first
    gsw_player_pack_weight = gsw_player_pack_weight + Peek( UInteger , A_EQ_SAVED + UB_ITEM_WEIGHT_OFFSET ) * lub_count
    guw_lib_param_2 = pub_pack_place
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY )

    ' second, add old item to inv and remove from equipment list, if necessary
    If fub_eq_category( lub_slot ) <> 0 Then
        s_core_ram_copy( fuw_eq_record( lub_slot ) , A_ITEM , UB_RECORD_SIZE )
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CARRY )
        lsw_carried = gsw_lib_result
        s_eq_take_off( lub_slot , lsw_carried )
    End If

    ' third, wear new item
    s_core_ram_copy( A_EQ_SAVED , fuw_eq_record( lub_slot ) , UB_RECORD_SIZE )
    gsw_player_equipment_count = gsw_player_equipment_count + 1
    s_eq_adjust( lub_slot , 1 )

    If lub_slot = UB_EQ_FIRST + UB_EQUIP_WIELD Then
        ls_how = "You are wielding "
    ElseIf lub_slot = UB_EQ_FIRST + UB_EQUIP_LIGHT Then
        ls_how = "Your light source is "
    Else
        ls_how = "You are wearing "
    End If
    s_eq_describe( lub_slot , true )
    s_eq_say( ls_how , " (" + fs_core_char( 97 + fub_eq_line_of( lub_slot ) ) + ")" )

    ' this is a new weapon, so clear the heavy flag
    If lub_slot = UB_EQ_FIRST + UB_EQUIP_WIELD Then gub_player_weapon_heavy = false
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )

    If fub_eq_cursed( lub_slot ) Then
        s_core_message( UW_MSG_OOPS_IT_FEELS_DEATHLY_COLD )
        luw_record = fuw_eq_record( lub_slot )
        Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bOr MB_ID_DAMD
        ' To force a cost of 0, even if unidentified.
        Poke ULong luw_record + UB_ITEM_COST_OFFSET , $FFFFFFFF
    End If
End Sub


Function fub_eq_throw_off( pub_place As UByte ) As UByte
    ' the thing in an equipment place is taken off and put down where the player stands, Moria's inventoryDropItem()
    ' for something worn, false if it is cursed, or the level can hold no more things
    ' N.B: the caller has seen to it that nothing lies there already
    Dim lub_number As UByte

    If fub_eq_cursed( pub_place ) Then
        s_core_message( UW_MSG_HMMM_IT_SEEMS_TO_BE_CURSED )
        Return false
    End If
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_OBJECTS )
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then Return false
    lub_number = gub_dungeon_item_next
    gub_dungeon_item_next = gub_dungeon_item_next + 1
    s_core_ram_copy( fuw_eq_record( pub_place ) , A_ITEM , UB_RECORD_SIZE )
    s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , lub_number , A_ITEM )
    Poke fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_ITEM , lub_number
    s_eq_take_off( pub_place , -1 )

    s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_number , A_ITEM )
    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    s_eq_say( "Dropped " , "" )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
    ' as a safety measure, set the player's pack weight to 0 when the last object is dropped
    If gsw_player_pack_unique = 0 And gsw_player_equipment_count = 0 Then gsw_player_pack_weight = 0
    Return true
End Function


Sub s_eq_remove( pub_line As UByte , pub_capital As UByte )
    ' the player takes off the thing on the given line of the equipment list, Moria's executeRemoveItemCommand(),
    ' pub_capital is true if it was picked with a capital letter, which asks "are you sure"
    Dim lub_place   As UByte
    Dim lsw_line    As Integer

    ' the list leaves out the empty places, so count along to the one meant
    lsw_line  = pub_line
    lub_place = UB_EQ_FIRST - 1
    Do
        lub_place = lub_place + 1
        If fub_eq_category( lub_place ) <> 0 Then lsw_line = lsw_line - 1
    Loop While lsw_line >= 0 And lub_place < UB_INVENTORY_SIZE - 1
    If lsw_line >= 0 Then Return

    If pub_capital Then
        gub_lib_param_1 = UB_INV_CHOOSE_TAKE_OFF
        guw_lib_param_2 = lub_place
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_VERIFY )
        If gsw_lib_result = false Then Return
    End If
    If fub_eq_cursed( lub_place ) Then
        s_core_message( UW_MSG_HMMM_IT_SEEMS_TO_BE_CURSED )
        Return
    End If
    s_core_ram_copy( fuw_eq_record( lub_place ) , A_ITEM , UB_RECORD_SIZE )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CAN_CARRY )
    If gsw_lib_result = false Then
        ' there is no room for it in the pack: it may be dropped instead, if nothing lies here already
        If Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_ITEM ) <> 0 Then
            s_core_message( UW_MSG_YOU_CANT_CARRY_IT )
            Return
        End If
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "You can't carry it.  Drop it? [y/n]" , UB_BRIGHT_WHITE )
        Do
            s_core_get_key()
        Loop While gub_key_char = UC_SPACE
        s_msg_clear()
        If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then gub_shared_1 = fub_eq_throw_off( lub_place )
        Return
    End If

    s_core_ram_copy( fuw_eq_record( lub_place ) , A_ITEM , UB_RECORD_SIZE )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CARRY )
    s_eq_take_off( lub_place , gsw_lib_result )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
End Sub


Sub s_eq_exchange()
    ' swaps the weapon in hand with the spare, Moria's uiCommandInventoryUnwieldItem()
    Dim lub_wield , lub_spare As UByte

    lub_wield = UB_EQ_FIRST + UB_EQUIP_WIELD
    lub_spare = UB_EQ_FIRST + UB_EQUIP_AUXILIARY
    If fub_eq_category( lub_wield ) = 0 And fub_eq_category( lub_spare ) = 0 Then
        s_core_message( UW_MSG_BUT_YOU_ARE_WIELDING_NO_WEAPONS )
        Return
    End If
    If fub_eq_cursed( lub_wield ) Then
        s_eq_describe( lub_wield , false )
        s_eq_say( "The " , " you are wielding appears to be cursed." )
        Return
    End If

    ' the weapons change hands, so this command takes the player's turn
    gub_game_free_turn = false
    s_core_ram_copy( fuw_eq_record( lub_spare ) , A_EQ_SAVED , UB_RECORD_SIZE )
    s_core_ram_copy( fuw_eq_record( lub_wield ) , A_ITEM , UB_RECORD_SIZE )
    s_core_ram_copy( A_ITEM , fuw_eq_record( lub_spare ) , UB_RECORD_SIZE )
    s_core_ram_copy( A_EQ_SAVED , fuw_eq_record( lub_wield ) , UB_RECORD_SIZE )
    s_eq_adjust( lub_spare , -1 )
    s_eq_adjust( lub_wield , 1 )

    If fub_eq_category( lub_wield ) <> 0 Then
        s_eq_describe( lub_wield , true )
        s_eq_say( "Primary weapon   : " , "" )
    Else
        s_core_message( UW_MSG_NO_PRIMARY_WEAPON )
    End If
    ' this is a new weapon, so clear the heavy flag
    gub_player_weapon_heavy = false
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
End Sub


'##################################################################################################################################
' --- the lists, and the commands ---

Function fub_eq_show_equipment( pub_weighted As UByte ) As UByte
    ' lists what is being worn and wielded, from row 1 down, Moria's displayEquipment(), the answer is how many lines,
    ' pub_weighted is true if each thing's weight is to be shown too, at the right hand edge
    Dim i , lub_line , lub_rows As UByte
    Dim ls_where                    As String
    Dim luw_weight                  As UInteger

    lub_line = 0
    For i = UB_EQ_FIRST To UB_INVENTORY_SIZE - 1
        If fub_eq_category( i ) <> 0 Then
            ' Moria's equipmentPositionDescription()
            ls_where = "Unknown"
            If i = UB_EQ_FIRST + UB_EQUIP_WIELD Then
                ls_where = "Wielding"
                If Cast( UInteger , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) * 15 < Peek( UInteger , fuw_eq_record( i ) + UB_ITEM_WEIGHT_OFFSET ) Then ls_where = "Just lifting"
            End If
            If i = UB_EQ_FIRST + UB_EQUIP_HEAD Then ls_where = "On head"
            If i = UB_EQ_FIRST + UB_EQUIP_NECK Then ls_where = "Around neck"
            If i = UB_EQ_FIRST + UB_EQUIP_BODY Then ls_where = "On body"
            If i = UB_EQ_FIRST + UB_EQUIP_ARM Then ls_where = "On arm"
            If i = UB_EQ_FIRST + UB_EQUIP_HANDS Then ls_where = "On hands"
            If i = UB_EQ_FIRST + UB_EQUIP_RIGHT Then ls_where = "On right hand"
            If i = UB_EQ_FIRST + UB_EQUIP_LEFT Then ls_where = "On left hand"
            If i = UB_EQ_FIRST + UB_EQUIP_FEET Then ls_where = "On feet"
            If i = UB_EQ_FIRST + UB_EQUIP_OUTER Then ls_where = "About body"
            If i = UB_EQ_FIRST + UB_EQUIP_LIGHT Then ls_where = "Light source"
            If i = UB_EQ_FIRST + UB_EQUIP_AUXILIARY Then ls_where = "Spare weapon"
            While Len( ls_where ) < 14
                ls_where = ls_where + " "
            End While

            s_eq_describe( i , true )
            Poke A_TEXT_BUFFER + 56 , 0                 ' a line is cut to fit
            If pub_weighted Then Poke A_TEXT_BUFFER + 49 , 0
            s_core_clear_row( lub_line + 1 , 0 , UB_WHITE )
            s_core_print_string_at( lub_line + 1 , 2 , fs_core_char( 97 + lub_line ) + ") " + ls_where + ": " , UB_WHITE )
            lub_rows = fub_core_print_text_at( lub_line + 1 , 21 , A_TEXT_BUFFER , UB_WHITE )
            If pub_weighted Then
                luw_weight = Peek( UInteger , fuw_eq_record( i ) + UB_ITEM_WEIGHT_OFFSET ) * Peek( fuw_eq_record( i ) + UB_ITEM_COUNT_OFFSET )
                s_core_print_string_at( lub_line + 1 , 71 , fs_core_number( luw_weight / 10 ) + "." + fs_core_number( luw_weight Mod 10 ) + " lb" , UB_WHITE )
            End If
            lub_line = lub_line + 1
        End If
    Next
    s_core_clear_row( lub_line + 1 , 0 , UB_WHITE )
    Return lub_line
End Function


Sub s_eq_recalc()
    ' works the player's bonuses out afresh from everything worn, the bonuses library does it
    s_core_call_library( UB_PAGED_CODE_LIB_BONUSES , UB_LIB_BONUSES_RECALC )
End Sub


Sub s_eq_command( pub_key As UByte )
    ' one of the inventory commands, see the top of this file
    Dim lub_first , lub_last , i , lub_lines    As UByte
    Dim lsw_choice                              As Integer

    gub_eq_screen_saved = false

    If pub_key = Code( "i" ) Then
        If gsw_player_pack_unique = 0 Then
            s_core_message( UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING )
        Else
            s_eq_screen_save()
            s_msg_clear()
            s_core_print_string_at( 0 , 0 , "You are carrying " + fs_core_number( gsw_player_pack_weight / 10 ) + "." + fs_core_number( gsw_player_pack_weight Mod 10 ) + " pounds. In your pack there is -" , UB_BRIGHT_WHITE )
            For i = 0 To UB_PACK_SIZE - 1
                Poke A_INV_MASK + i , 1
            Next
            guw_lib_param_2 = ( Cast( UInteger , gsw_player_pack_unique - 1 ) << 8 )
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_SHOW )
            s_core_get_key()
            s_eq_screen_restore()
        End If

    ElseIf pub_key = Code( "e" ) Then
        If gsw_player_equipment_count = 0 Then
            s_core_message( UW_MSG_YOU_ARE_NOT_USING_ANY_EQUIPMENT )
        Else
            s_eq_screen_save()
            s_msg_clear()
            s_core_print_string_at( 0 , 0 , "You are using -" , UB_BRIGHT_WHITE )
            lub_lines = fub_eq_show_equipment( ( guw_game_options bAnd MW_OPTION_SHOW_WEIGHTS ) <> 0 )
            s_core_get_key()
            s_eq_screen_restore()
        End If

    ElseIf pub_key = Code( "w" ) Then
        ' what can be worn or wielded is all together in the pack, between the things of a higher category and
        ' those of a lower one, Moria's uiCommandInventoryWearWieldItem()
        lub_first = 0
        While Cast( Integer , lub_first ) < gsw_player_pack_unique And fub_eq_category( lub_first ) > UB_TV_MAX_WEAR
            lub_first = lub_first + 1
        End While
        lub_last = lub_first
        While Cast( Integer , lub_last ) < gsw_player_pack_unique And fub_eq_category( lub_last ) >= UB_TV_MIN_WEAR
            lub_last = lub_last + 1
        End While
        If lub_last = lub_first Then
            s_core_message( UW_MSG_YOU_HAVE_NOTHING_TO_WEAR_OR_WIELD )
        Else
            lub_last = lub_last - 1
            For i = 0 To UB_PACK_SIZE - 1
                Poke A_INV_MASK + i , 0
            Next
            For i = lub_first To lub_last
                Poke A_INV_MASK + i , 1
            Next
            gub_lib_param_1 = UB_INV_CHOOSE_WEAR
            guw_lib_param_2 = Cast( UInteger , lub_first ) + ( Cast( UInteger , lub_last ) << 8 )
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
            lsw_choice = gsw_lib_result
            If lsw_choice >= 0 Then s_eq_wear( lsw_choice )
        End If

    ElseIf pub_key = Code( "t" ) Then
        If gsw_player_equipment_count = 0 Then
            s_core_message( UW_MSG_YOU_ARE_NOT_USING_ANY_EQUIPMENT )
        Else
            s_eq_screen_save()
            lub_lines = fub_eq_show_equipment( false )
            s_msg_clear()
            s_core_print_string_at( 0 , 0 , "(Items a-" + fs_core_char( 96 + lub_lines ) + ", ESC to exit) Take off which one?" , UB_BRIGHT_WHITE )
            lsw_choice = -1
            Do
                s_core_get_key()
                If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then Exit Do
                i = gub_key_char bOr 32
                If i >= 97 And i < 97 + lub_lines Then
                    lsw_choice = i - 97
                    Exit Do
                End If
            Loop
            ' N.B: a capital letter is the same letter with bit 5 clear
            i = ( gub_key_char bAnd 32 ) = 0
            s_eq_screen_restore()
            If lsw_choice >= 0 Then s_eq_remove( lsw_choice , i )
        End If

    ElseIf pub_key = Code( "x" ) Then
        s_eq_exchange()
    End If

    ' Moria works the bonuses out afresh whenever the inventory commands are left
    s_eq_recalc()
End Sub


'##################################################################################################################################
' --- the way in ---

Sub s_lib_equipment()
    If gub_lib_function = UB_LIB_EQUIP_COMMAND Then
        s_eq_command( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_EQUIP_SHOW Then
        gsw_lib_result = fub_eq_show_equipment( false )
    ElseIf gub_lib_function = UB_LIB_EQUIP_THROW_OFF Then
        gsw_lib_result = fub_eq_throw_off( Cast( UByte , guw_lib_param_2 ) )
        s_eq_recalc()
    ElseIf gub_lib_function = UB_LIB_EQUIP_RECALC Then
        s_eq_recalc()
    ElseIf gub_lib_function = UB_LIB_EQUIP_ADJUST Then
        ' Moria's playerAdjustBonusesForItem()
        s_eq_adjust( gub_lib_param_1 , Cast( Integer , guw_lib_param_2 ) )
    ElseIf gub_lib_function = UB_LIB_EQUIP_USE_STAT Then
        ' Moria's playerSetAndUseStat()
        s_eq_use_stat( gub_lib_param_1 )
        If gub_lib_param_1 = UB_STAT_STR Then gul_player_status = gul_player_status bOr UL_PY_STR_WGT
        If gub_lib_param_1 = UB_STAT_STR Or gub_lib_param_1 = UB_STAT_DEX Then s_eq_recalc()
        ' intelligence changes the spells and mana of those who cast spells, wisdom of those who pray
        If ( gub_lib_param_1 = UB_STAT_INT And gub_class_spell_type = UB_SPELL_TYPE_MAGE ) Or ( gub_lib_param_1 = UB_STAT_WIS And gub_class_spell_type = UB_SPELL_TYPE_PRIEST ) Then
            s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
        End If
        ' constitution changes the hit points
        If gub_lib_param_1 = UB_STAT_CON Then s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_CALC_HP )
    End If
End Sub
