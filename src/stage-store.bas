#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_store()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-strings-include.bas"

' this stage is the inside of a store, Moria's storeEnter() (store.cpp): the owner, what is for sale and for how much,
' and the commands to buy, the store is gub_core_store, 0 to 5, the core comes here when the crawl stage asks for it
' the screen is laid out exactly as Moria lays it out, on rows 0 to 23 of our 32
' the stock itself is looked after by the stores library, the bargaining by the haggle library, and the player's
' pack by the inventory library, this stage is the conversation between them
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, ^R draws the store again, see s_stage_store()


Dim gub_store_top   As UByte    At A_TEXT_BUFFER + 240      ' which item is at the top of the list on screen, 0 or 12 (current_top_item_id)


'##################################################################################################################################
' --- small helpers ---

Function fuw_store_state() As UInteger
    Return A_STORES + Cast( UInteger , gub_core_store ) * UB_STORE_STATE_SIZE
End Function


Function fub_store_count() As UByte
    Return Peek( fuw_store_state() + UB_STORE_ITEM_COUNT )
End Function


Sub s_store_fetch( pub_item As UByte )
    ' one item of this store's stock, into the working item
    s_core_fetch_record( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , Cast( UInteger , gub_core_store ) * UB_STORE_MAX_ITEMS + pub_item , A_ITEM )
End Sub


Sub s_store_clear_row( pub_row As UByte , pub_from As UByte )
    s_core_clear_row( pub_row , pub_from , UB_WHITE )
End Sub


Sub s_store_put( pub_row As UByte , pub_col As UByte , ps_text As String )
    ' text at a place, with the rest of the row cleared, Moria's putStringClearToEOL()
    s_store_clear_row( pub_row , pub_col )
    s_core_print_string_at( pub_row , pub_col , ps_text , UB_WHITE )
End Sub


Function fs_store_number( psl_value As Long , pub_width As UByte ) As String
    ' a number with spaces in front to make it up to the given width, as C's %9d does
    Dim ls_text As String

    ls_text = fs_core_number( psl_value )
    While Len( ls_text ) < pub_width
        ls_text = " " + ls_text
    End While
    Return ls_text
End Function


Function fsw_store_charisma() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_CHARISMA )
    Return gsw_lib_result
End Function


Sub s_store_say( puw_string As UInteger )
    s_string_fetch( puw_string , A_TEXT_BUFFER )
    s_msg_text( A_TEXT_BUFFER )
End Sub


'##################################################################################################################################
' --- the screen ---

Sub s_store_commands()
    ' Moria's displayStoreCommands()
    s_store_put( 20 , 0 , "You may:" )
    s_store_put( 21 , 0 , " p) Purchase an item.           b) Browse store's inventory." )
    s_store_put( 22 , 0 , " s) Sell an item.               i/e/t/w/x) Inventory/Equipment Lists." )
    s_store_put( 23 , 0 , "ESC) Exit from Building.        ^R) Redraw the screen." )
End Sub


Sub s_store_price( pub_item As UByte , psw_charisma As Integer )
    ' the price column for one item, whose record is in the working item: what the owner starts at, which depends on
    ' the player's charm, or the fixed price once one has been agreed, Moria's displaySingleCost()
    Dim lsl_value   As Long
    Dim lub_row     As UByte

    lub_row = ( pub_item Mod 12 ) + 5
    If gsl_item_store_cost <= 0 Then
        lsl_value = -gsl_item_store_cost
        lsl_value = lsl_value * psw_charisma / 100
        If lsl_value <= 0 Then lsl_value = 1
        s_store_put( lub_row , 59 , fs_store_number( lsl_value , 9 ) )
    Else
        s_store_put( lub_row , 59 , fs_store_number( gsl_item_store_cost , 9 ) + " [Fixed]" )
    End If
End Sub


Sub s_store_inventory( pub_start As UByte )
    ' lists up to twelve items of the stock, from the given one, Moria's displayStoreInventory()
    Dim lub_item , lub_end , lub_line , lub_count , lub_rows , lub_have As UByte
    Dim lsw_charisma                                                    As Integer

    lub_count = fub_store_count()
    lub_end   = ( ( pub_start / 12 ) + 1 ) * 12
    If lub_end > lub_count Then lub_end = lub_count
    lsw_charisma = fsw_store_charisma()

    lub_item = pub_start
    lub_line = pub_start Mod 12
    While lub_item < lub_end
        s_store_fetch( lub_item )
        ' things that stack are sold one at a time, and so are described one at a time
        lub_have = gub_item_count
        If gub_item_sub_category >= 64 And gub_item_sub_category <= 192 Then gub_item_count = 1
        gub_lib_param_1 = true
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
        gub_item_count = lub_have

        s_store_clear_row( lub_line + 5 , 0 )
        s_core_print_string_at( lub_line + 5 , 0 , fs_core_char( 97 + lub_line ) + ")" , UB_WHITE )
        lub_rows = fub_core_print_text_at( lub_line + 5 , 3 , A_TEXT_BUFFER , UB_WHITE )
        s_store_price( lub_item , lsw_charisma )
        lub_item = lub_item + 1
        lub_line = lub_line + 1
    End While

    While lub_line < 12
        s_store_clear_row( lub_line + 5 , 0 )
        lub_line = lub_line + 1
    End While

    If lub_count > 12 Then
        s_core_print_string_at( 17 , 60 , "- cont. -" , UB_WHITE )
    Else
        s_store_clear_row( 17 , 60 )
    End If
End Sub


Sub s_store_gold()
    ' Moria's displayPlayerRemainingGold()
    s_store_put( 18 , 17 , "Gold Remaining : " + fs_core_number( gsl_player_gold ) )
End Sub


Sub s_store_display()
    ' Moria's displayStore()
    Dim lub_rows As UByte

    s_core_clear_screen()
    gub_message_length = 0
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    lub_rows = fub_core_print_text_at( 3 , 9 , A_TABLE_OWNERS + Cast( UInteger , Peek( fuw_store_state() + UB_STORE_OWNER ) ) * UB_OWNER_SIZE , UB_BRIGHT_WHITE )
    s_core_print_string_at( 4 , 3 , "Item" , UB_WHITE )
    s_core_print_string_at( 4 , 60 , "Asking Price" , UB_WHITE )
    s_store_gold()
    s_store_commands()
    s_store_inventory( gub_store_top )
End Sub


'##################################################################################################################################
' --- buying ---

Function fsw_store_choose( ps_prompt As String , pub_last As UByte ) As Integer
    ' asks which item, a to the given letter, Moria's storeGetItemId(), -1 means the player thought better of it
    Dim lsw_item As Integer = -1

    s_msg_flush()
    s_store_put( 0 , 0 , "(Items a-" + fs_core_char( 97 + pub_last ) + ", ESC to exit) " + ps_prompt )
    Do
        s_core_get_key()
        If gub_key_char = 27 Or guw_key_code = 0 Then Exit Do
        If gub_key_char >= 97 And gub_key_char <= 97 + pub_last Then
            lsw_item = gub_key_char - 97
            Exit Do
        End If
    Loop
    s_msg_clear()
    Return lsw_item
End Function


Function fub_store_increase_insults() As UByte
    ' Moria's storeIncreaseInsults(), as it is in the haggle library, it is needed here for the player who agrees
    ' a price and then turns out not to have the gold
    Dim luw_state , luw_owner           As UInteger
    Dim lsw_insults , lsw_comment       As Integer

    luw_state   = fuw_store_state()
    lsw_insults = Peek( Integer , luw_state + UB_STORE_INSULTS ) + 1
    Poke UInteger luw_state + UB_STORE_INSULTS , Cast( UInteger , lsw_insults )
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    luw_owner = A_TABLE_OWNERS + Cast( UInteger , Peek( luw_state + UB_STORE_OWNER ) ) * UB_OWNER_SIZE
    If lsw_insults <= Cast( Integer , Peek( luw_owner + UB_OWNER_MAX_INSULTS ) ) Then Return false

    lsw_comment = Cast( Integer , ful_core_random_number( 5 ) ) - 1
    s_store_say( UW_STR_INSULTED + lsw_comment )
    s_store_say( UW_STR_GET_OUT + lsw_comment )
    Poke UInteger luw_state + UB_STORE_INSULTS , 0
    Poke UInteger luw_state + UB_STORE_BAD_BUYS , Peek( UInteger , luw_state + UB_STORE_BAD_BUYS ) + 1
    Poke ULong luw_state + UB_STORE_TURNS_LEFT , Cast( ULong , gsl_game_turn + 2500 + Cast( Long , ful_core_random_number( 2500 ) ) )
    Return true
End Function


Function fub_store_purchase() As UByte
    ' the player buys something, Moria's storePurchaseAnItem(), true means the owner has thrown them out
    Dim lub_count , lub_last , lub_item , lub_status    As UByte
    Dim lub_new_place , lub_saved_count , lub_rows      As UByte
    Dim lsw_choice                                      As Integer
    Dim lsl_price                                       As Long
    Dim luw_state                                       As UInteger
    Dim lub_kick                                        As UByte = false

    luw_state = fuw_store_state()
    lub_count = fub_store_count()
    If lub_count < 1 Then
        s_core_message( UW_MSG_I_AM_CURRENTLY_OUT_OF_STOCK )
        Return false
    End If

    ' how many of the items on screen can be asked for, Moria's storeItemsToDisplay()
    If gub_store_top = 12 Then
        lub_last = lub_count - 1 - 12
    ElseIf lub_count > 11 Then
        lub_last = 11
    Else
        lub_last = lub_count - 1
    End If
    lsw_choice = fsw_store_choose( "Which item are you interested in? " , lub_last )
    If lsw_choice < 0 Then Return false
    lub_item = lsw_choice + gub_store_top

    ' one of them, as the working item, Moria's inventoryTakeOneItem()
    s_store_fetch( lub_item )
    If gub_item_count > 1 And gub_item_sub_category >= 64 And gub_item_sub_category <= 192 Then gub_item_count = 1
    lsl_price = gsl_item_store_cost

    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CAN_CARRY )
    If gsw_lib_result = false Then
        s_store_put( 0 , 0 , "You cannot carry that many different items." )
        Return false
    End If

    ' a price already agreed for this item stands, otherwise it is haggled over
    lub_status = UB_BID_RECEIVED
    If lsl_price <= 0 Then
        s_core_call_library( UB_PAGED_CODE_LIB_HAGGLE , UB_LIB_HAGGLE_PURCHASE )
        lub_status = gsw_lib_result
        lsl_price  = gsl_lib_long_1
    End If

    If lub_status = UB_BID_INSULTED Then
        lub_kick = true
    ElseIf lub_status = UB_BID_RECEIVED Then
        If gsl_player_gold >= lsl_price Then
            ' the owner says "Done!", or one of the other thirteen things they say
            s_store_say( UW_STR_SALE_ACCEPTED + Cast( UInteger , ful_core_random_number( 14 ) ) - 1 )
            If Peek( Integer , luw_state + UB_STORE_INSULTS ) <> 0 Then Poke UInteger luw_state + UB_STORE_INSULTS , Peek( UInteger , luw_state + UB_STORE_INSULTS ) - 1
            gsl_player_gold = gsl_player_gold - lsl_price

            ' into the pack with it: the haggling used the working item freely, so take it from the stock again
            s_store_fetch( lub_item )
            If gub_item_count > 1 And gub_item_sub_category >= 64 And gub_item_sub_category <= 192 Then gub_item_count = 1
            gsl_item_store_cost = 0
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CARRY )
            lub_new_place = gsw_lib_result

            ' and out of the store's stock
            lub_saved_count = fub_store_count()
            gub_lib_param_1 = gub_core_store
            guw_lib_param_2 = lub_item
            gsw_lib_result  = true
            s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_DESTROY )

            ' "You have 3 Flasks of Oil (c)": what the pack now holds of it
            s_core_ram_copy( A_INVENTORY + Cast( UInteger , lub_new_place ) * UB_RECORD_SIZE , A_ITEM , UB_RECORD_SIZE )
            gub_lib_param_1 = true
            s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
            s_msg_flush()
            s_store_clear_row( 0 , 0 )
            s_core_print_string_at( 0 , 0 , "You have " , UB_BRIGHT_WHITE )
            lub_rows = fub_core_print_text_at( 0 , 9 , A_TEXT_BUFFER , UB_BRIGHT_WHITE )
            gub_message_length = 9
            While Peek( A_TEXT_BUFFER + gub_message_length - 9 ) <> 0 And gub_message_length < 66
                gub_message_length = gub_message_length + 1
            End While
            s_core_print_string_at( 0 , gub_message_length , " (" + fs_core_char( 97 + lub_new_place ) + ")" , UB_BRIGHT_WHITE )
            gub_message_length = gub_message_length + 4

            ' is the pack now heavy enough to slow the player down
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )

            ' show what the purchase did to the stock
            lub_count = fub_store_count()
            If gub_store_top >= lub_count Then
                gub_store_top = 0
                s_store_inventory( gub_store_top )
            ElseIf lub_saved_count = lub_count Then
                ' there are more of it left: the price just agreed becomes its fixed price
                s_store_fetch( lub_item )
                If gsl_item_store_cost < 0 Then
                    gsl_item_store_cost = lsl_price
                    s_core_store_record( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , Cast( UInteger , gub_core_store ) * UB_STORE_MAX_ITEMS + lub_item , A_ITEM )
                    s_store_price( lub_item , 100 )
                End If
            Else
                s_store_inventory( lub_item )
            End If
            s_store_gold()
        Else
            If fub_store_increase_insults() Then
                lub_kick = true
            Else
                s_store_say( UW_STR_SALE_ACCEPTED + Cast( UInteger , ful_core_random_number( 14 ) ) - 1 )
                s_core_message( UW_MSG_LIAR_YOU_HAVE_NOT_THE_GOLD )
            End If
        End If
    End If

    ' Less intuitive, but looks better here than in storePurchaseHaggle.
    s_store_commands()
    s_store_clear_row( 1 , 0 )
    Return lub_kick
End Function


'##################################################################################################################################
' --- selling ---

Function fub_store_buys( pub_category As UByte ) As UByte
    ' true if this store deals in things of the given category, Moria's six setGeneralStoreItems() ... setMagicShopItems()
    Dim lub_scroll_or_potion As UByte = false

    If pub_category = UB_TV_SCROLL1 Or pub_category = UB_TV_SCROLL2 Or pub_category = UB_TV_POTION1 Or pub_category = UB_TV_POTION2 Then lub_scroll_or_potion = true

    If gub_core_store = 0 Then          ' the General Store
        If pub_category = UB_TV_DIGGING Or pub_category = UB_TV_BOOTS Or pub_category = UB_TV_CLOAK Or pub_category = UB_TV_FOOD Or pub_category = UB_TV_FLASK Or pub_category = UB_TV_LIGHT Or pub_category = UB_TV_SPIKE Then Return true
    ElseIf gub_core_store = 1 Then      ' the Armory
        If pub_category = UB_TV_BOOTS Or pub_category = UB_TV_GLOVES Or pub_category = UB_TV_HELM Or pub_category = UB_TV_SHIELD Or pub_category = UB_TV_HARD_ARMOR Or pub_category = UB_TV_SOFT_ARMOR Then Return true
    ElseIf gub_core_store = 2 Then      ' the Weaponsmith
        If pub_category = UB_TV_SLING_AMMO Or pub_category = UB_TV_BOLT Or pub_category = UB_TV_ARROW Or pub_category = UB_TV_BOW Or pub_category = UB_TV_HAFTED Or pub_category = UB_TV_POLEARM Or pub_category = UB_TV_SWORD Then Return true
    ElseIf gub_core_store = 3 Then      ' the Temple
        If pub_category = UB_TV_HAFTED Or pub_category = UB_TV_PRAYER_BOOK Or lub_scroll_or_potion Then Return true
    ElseIf gub_core_store = 4 Then      ' the Alchemist
        If lub_scroll_or_potion Then Return true
    Else                                ' the Magic Shop
        If pub_category = UB_TV_AMULET Or pub_category = UB_TV_RING Or pub_category = UB_TV_STAFF Or pub_category = UB_TV_WAND Or pub_category = UB_TV_MAGIC_BOOK Or lub_scroll_or_potion Then Return true
    End If
    Return false
End Function


Sub s_store_take_one( pub_place As UByte )
    ' one of what is in a place in the pack, as the working item, Moria's inventoryTakeOneItem()
    s_core_ram_copy( A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE , A_ITEM , UB_RECORD_SIZE )
    If gub_item_count > 1 And gub_item_sub_category >= 64 And gub_item_sub_category <= 192 Then gub_item_count = 1
End Sub


Sub s_store_say_item( ps_before As String , ps_after As String )
    ' a message with the description of the working item in the middle of it, e.g. "Selling a Flask of Oil. (c)"
    Dim lub_rows , lub_length As UByte

    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    s_msg_flush()
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , ps_before , UB_BRIGHT_WHITE )
    lub_length = Len( ps_before )
    Poke A_TEXT_BUFFER + 60 , 0                     ' the description is cut to fit on the one row
    lub_rows = fub_core_print_text_at( 0 , lub_length , A_TEXT_BUFFER , UB_BRIGHT_WHITE )
    While Peek( A_TEXT_BUFFER + lub_length - Len( ps_before ) ) <> 0
        lub_length = lub_length + 1
    End While
    s_core_print_string_at( 0 , lub_length , ps_after , UB_BRIGHT_WHITE )
    gub_message_length = lub_length + Len( ps_after )
End Sub


Function fub_store_sell() As UByte
    ' the player sells something, Moria's storeSellAnItem(), true means the owner has thrown them out
    Dim lub_first , lub_place , lub_status , i  As UByte
    Dim lsw_last , lsw_choice , lsw_position    As Integer
    Dim lsl_price                               As Long
    Dim luw_state                               As UInteger
    Dim lub_kick                                As UByte = false

    luw_state = fuw_store_state()

    ' which of the things in the pack this store deals in
    lub_first = gsw_player_pack_unique
    lsw_last  = -1
    i = 0
    While Cast( Integer , i ) < gsw_player_pack_unique
        If fub_store_buys( Peek( A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) ) Then
            Poke A_INV_MASK + i , 1
            If i < lub_first Then lub_first = i
            If Cast( Integer , i ) > lsw_last Then lsw_last = i
        Else
            Poke A_INV_MASK + i , 0
        End If
        i = i + 1
    End While
    If lsw_last = -1 Then
        s_core_message( UW_MSG_YOU_HAVE_NOTHING_TO_SELL_TO_THIS )
        Return false
    End If

    gub_lib_param_1 = UB_INV_CHOOSE_REFUSE
    guw_lib_param_2 = Cast( UInteger , lub_first ) + ( Cast( UInteger , lsw_last ) << 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    lsw_choice = gsw_lib_result
    If lsw_choice < 0 Then Return false
    lub_place = lsw_choice

    s_store_take_one( lub_place )
    s_store_say_item( "Selling " , " (" + fs_core_char( 97 + lub_place ) + ")" )

    s_store_take_one( lub_place )
    gub_lib_param_1 = gub_core_store
    s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_HAS_ROOM )
    If gsw_lib_result = false Then
        s_core_message( UW_MSG_I_HAVE_NOT_THE_ROOM_IN_MY_STORE )
        Return false
    End If

    s_store_take_one( lub_place )
    s_core_call_library( UB_PAGED_CODE_LIB_HAGGLE , UB_LIB_HAGGLE_SELL )
    lub_status = gsw_lib_result
    lsl_price  = gsl_lib_long_1

    If lub_status = UB_BID_INSULTED Then
        lub_kick = true
    ElseIf lub_status = UB_BID_OFFENDED Then
        s_core_message( UW_MSG_HOW_DARE_YOU )
        s_core_message( UW_MSG_I_WILL_NOT_BUY_THAT )
        lub_kick = fub_store_increase_insults()
    ElseIf lub_status = UB_BID_RECEIVED Then
        s_store_say( UW_STR_SALE_ACCEPTED + Cast( UInteger , ful_core_random_number( 14 ) ) - 1 )
        If Peek( Integer , luw_state + UB_STORE_INSULTS ) <> 0 Then Poke UInteger luw_state + UB_STORE_INSULTS , Peek( UInteger , luw_state + UB_STORE_INSULTS ) - 1
        gsl_player_gold = gsl_player_gold + lsl_price

        ' identify object in inventory to set objects_identified array, which may put it together with others like it
        guw_lib_param_2 = lub_place
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY )
        lub_place = gsw_lib_result

        ' retake sold_item so that it will be identified, then it leaves the pack and goes on the store's shelf
        s_store_take_one( lub_place )
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_KNOW_FULLY )
        ' N.B: the working item is the one being sold from here on, taking it out of the pack does not disturb it
        guw_lib_param_2 = lub_place
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY )
        ' N.B: describing the item fetches its object, the item itself is left as it is
        s_store_say_item( "You've sold " , "" )

        gub_lib_param_1 = gub_core_store
        s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_CARRY )
        lsw_position = gsw_lib_result
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )

        ' show the part of the stock that now has it
        If lsw_position >= 0 Then
            If lsw_position < 12 Then
                If gub_store_top < 12 Then
                    s_store_inventory( lsw_position )
                Else
                    gub_store_top = 0
                    s_store_inventory( gub_store_top )
                End If
            ElseIf gub_store_top > 11 Then
                s_store_inventory( lsw_position )
            Else
                gub_store_top = 12
                s_store_inventory( gub_store_top )
            End If
        End If
        s_store_gold()
    End If

    s_store_clear_row( 1 , 0 )
    s_store_commands()
    Return lub_kick
End Function


Sub s_store_beep()
    ' Moria's terminalBellSound(), for a key that is no command here, if the player has "beep for invalid character"
    ' on: the walking stage's beep, s_cr_beep() in stage-crawl.bas, about a tenth of a second at about 800Hz
    ' N.B: the speaker is bit 4 of port $FE, whose low three bits are the border, which is black and stays black
    If ( guw_game_options bAnd MW_OPTION_BEEP ) = 0 Then Return
    Asm
        ld hl, 160              ; how many times the speaker is flipped
        ld e, 0
store_beep_flip:
        ld a, e
        xor 16
        ld e, a
        out ($FE), a
        ld bc, 670              ; 26 clock cycles each time round
store_beep_wait:
        dec bc
        ld a, b
        or c
        jr nz, store_beep_wait
        dec hl
        ld a, h
        or l
        jr nz, store_beep_flip
        xor a
        out ($FE), a
    End Asm
End Sub


'##################################################################################################################################
' --- the stage itself, Moria's storeEnter() ---

Sub s_stage_store()
    Dim lub_exit As UByte = false
    Dim lub_key  As UByte

    gub_message_length = 0

    ' a store whose owner has thrown the player out stays shut for a while
    If Peek( Long , fuw_store_state() + UB_STORE_TURNS_LEFT ) >= gsl_game_turn Then
        s_core_message( UW_MSG_THE_DOORS_ARE_LOCKED )
        s_msg_flush()
        Return
    End If

    gub_store_top = 0
    s_store_display()

    While lub_exit = false
        s_core_get_key()
        lub_key = gub_key_char
        ' the inventory commands may be capitals too, as in Moria's, whose inventoryExecuteCommand() makes them small
        If ( gub_key_modifiers bAnd MB_KEY_CTRL ) = 0 Then
            If lub_key = Code( "E" ) Or lub_key = Code( "I" ) Or lub_key = Code( "T" ) Or lub_key = Code( "W" ) Or lub_key = Code( "X" ) Then lub_key = lub_key + 32
        End If
        ' a message left by the last command is finished with once the next command is given, Moria's storeEnter()
        ' "clear the msg flag just like we do in dungeon.c", and as the walking stage does: without this the next
        ' command's message was put after it on the same row, as if the two were one
        If gub_message_length > 0 Then s_msg_clear()
        If gub_key_char = 27 Or guw_key_code = 0 Then
            lub_exit = true

        ElseIf gub_key_char = Code( "b" ) Then
            ' the other half of the stock, if there is one
            If gub_store_top = 0 Then
                If fub_store_count() > 12 Then
                    gub_store_top = 12
                    s_store_inventory( gub_store_top )
                Else
                    s_core_message( UW_MSG_ENTIRE_INVENTORY_IS_SHOWN )
                End If
            Else
                gub_store_top = 0
                s_store_inventory( gub_store_top )
            End If

        ElseIf gub_key_char = Code( "p" ) Then
            lub_exit = fub_store_purchase()

        ElseIf gub_key_char = Code( "s" ) Then
            lub_exit = fub_store_sell()

        ElseIf lub_key = Code( "i" ) Or lub_key = Code( "e" ) Or lub_key = Code( "w" ) Or lub_key = Code( "t" ) Or lub_key = Code( "x" ) Then
            ' the inventory commands, wearing something may change the player's charisma, and so the prices
            gub_lib_param_1 = lub_key
            s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_COMMAND )
            s_store_inventory( gub_store_top )
            ' "No free moves here", as Moria: the turn the player stepped in on goes on afterwards, see stage-crawl.bas
            gub_game_free_turn = false

        ElseIf gub_key_char = 18 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then
            ' Ctrl-R: the store is drawn again, N.B: in Moria this is not the store's, its getKeyInput() redraws the
            ' screen for ^R at any key, and never returns it
            s_store_display()

        ElseIf guw_key_code <> 0 Then
            ' anything else, Moria's "default: terminalBellSound()", N.B: a modifier on its own is no key at all
            s_store_beep()

        End If
    End While

    s_msg_flush()
End Sub
