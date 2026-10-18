#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_stores()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: what the six stores have in stock, and what things are worth, Moria's
' store_inventory.cpp...
' ...any stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_STORES , <which routine> ), the routines are:
'
'   UB_LIB_STORES_MAINTAIN      every store sells off some of its stock and buys some in, Moria's storeMaintenance(),
'                               which it does each time the town is made
'   UB_LIB_STORES_VALUE         what the working item (A_ITEM) is worth, Moria's storeItemValue(), in gsl_lib_long_1
'   UB_LIB_STORES_SELL_PRICE    what store gub_lib_param_1 would ask the player for the working item, Moria's
'                               storeItemSellPrice(): the price in gsl_lib_long_1, 0 if the store would not deal in it,
'                               and the least and the most it would take in gsl_lib_long_2 and gsl_lib_long_3
'   UB_LIB_STORES_CARRY         store gub_lib_param_1 takes the working item into its stock, Moria's storeCarryItem(),
'                               where it ended up in the stock comes back in gsw_lib_result, -1 if it was not taken
'   UB_LIB_STORES_DESTROY       item guw_lib_param_2 of store gub_lib_param_1 leaves its stock, Moria's
'                               storeDestroyItem(): just one of them if gsw_lib_result is true on the way in,
'                               otherwise a random number of them
'   UB_LIB_STORES_TEST          shows what each store has in stock, for checking this page
'   UB_LIB_STORES_HAS_ROOM      gsw_lib_result is true if store gub_lib_param_1 has room for the working item, Moria's
'                               storeCheckPlayerItemsCount()
'
' N.B: a store's stock is in the store items pages, in the second paged data slot, 24 records to a store: item i of
' store n is record n * 24 + i, whatever page the caller had in that slot is put back before returning
' N.B: the working item is used freely in here, a caller that needs it afterwards must keep its own copy


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
Dim gub_st_saved_page       As UByte    At A_LIB_PRIVATE            ' the page the caller had in the second data slot
Dim gsl_st_price            As Long     At A_LIB_PRIVATE + 1        ' the three answers of the sell price routine...
Dim gsl_st_min_price        As Long     At A_LIB_PRIVATE + 5
Dim gsl_st_max_price        As Long     At A_LIB_PRIVATE + 9

#define UB_ITEM_SINGLE_STACK_MIN    64      ' items with a sub category from here up can be stacked...
#define UB_ITEM_SINGLE_STACK_MAX    192     ' ...up to here they stack singly...
#define UB_ITEM_GROUP_MIN           192     ' ...and above this they are a batch, like arrows, that only stacks with itself


'##################################################################################################################################
' --- small helpers ---

Function fsw_st_random( psw_max As Integer ) As Integer
    Return Cast( Integer , ful_core_random_number( Cast( ULong , psw_max ) ) )
End Function


Function fuw_st_state( pub_store As UByte ) As UInteger
    ' where a store's 16 bytes of state are
    Return A_STORES + Cast( UInteger , pub_store ) * UB_STORE_STATE_SIZE
End Function


Function fub_st_count( pub_store As UByte ) As UByte
    ' how many different items a store has in stock
    Return Peek( fuw_st_state( pub_store ) + UB_STORE_ITEM_COUNT )
End Function


Function fuw_st_record( pub_store As UByte , pub_item As UByte ) As UInteger
    ' pages in one item of a store's stock and returns where it is, good until something else uses the second data slot
    Return fuw_core_record_address( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , Cast( UInteger , pub_store ) * UB_STORE_MAX_ITEMS + pub_item )
End Function


Sub s_st_fetch( pub_store As UByte , pub_item As UByte , puw_address As UInteger )
    s_core_fetch_record( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , Cast( UInteger , pub_store ) * UB_STORE_MAX_ITEMS + pub_item , puw_address )
End Sub


Sub s_st_store( pub_store As UByte , pub_item As UByte , puw_address As UInteger )
    s_core_store_record( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , Cast( UInteger , pub_store ) * UB_STORE_MAX_ITEMS + pub_item , puw_address )
End Sub


Function fub_st_kind_is_known() As UByte
    ' true if the player knows what kind of thing the working item is, the items library works that out
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_KIND_KNOWN )
    Return Cast( UByte , gsw_lib_result )
End Function


'##################################################################################################################################
' --- what things are worth ---

Function fsl_st_item_value() As Long
    ' what the working item is worth, before any store's mark up, Moria's storeItemValue() and the seven routines it calls
    ' N.B: the object the item is one of is fetched, for the price an unidentified one is taken to be worth
    Dim lsl_value       As Long
    Dim lub_category    As UByte
    Dim lub_identified  As UByte = false

    lub_category = gub_item_category
    If ( gub_item_identification bAnd MB_ID_KNOWN2 ) <> 0 Then lub_identified = true
    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , guw_item_object , A_OBJECT )

    If ( gub_item_identification bAnd MB_ID_DAMD ) <> 0 Then
        lsl_value = 0

    ElseIf ( lub_category >= UB_TV_BOW And lub_category <= UB_TV_SWORD ) Or ( lub_category >= UB_TV_BOOTS And lub_category <= UB_TV_SOFT_ARMOR ) Then
        ' weapons and armour
        If lub_identified = false Then
            lsl_value = gsl_object_cost
        ElseIf lub_category >= UB_TV_BOW And lub_category <= UB_TV_SWORD Then
            If gsw_item_to_hit < 0 Or gsw_item_to_damage < 0 Or gsw_item_to_ac < 0 Then
                lsl_value = 0
            Else
                lsl_value = gsl_item_cost + ( Cast( Long , gsw_item_to_hit ) + gsw_item_to_damage + gsw_item_to_ac ) * 100
            End If
        ElseIf gsw_item_to_ac < 0 Then
            lsl_value = 0
        Else
            lsl_value = gsl_item_cost + Cast( Long , gsw_item_to_ac ) * 100
        End If

    ElseIf lub_category >= UB_TV_SLING_AMMO And lub_category <= UB_TV_SPIKE Then
        ' ammunition
        If lub_identified = false Then
            lsl_value = gsl_object_cost
        ElseIf gsw_item_to_hit < 0 Or gsw_item_to_damage < 0 Or gsw_item_to_ac < 0 Then
            lsl_value = 0
        Else
            lsl_value = gsl_item_cost + ( Cast( Long , gsw_item_to_hit ) + gsw_item_to_damage + gsw_item_to_ac ) * 5
        End If

    ElseIf lub_category = UB_TV_SCROLL1 Or lub_category = UB_TV_SCROLL2 Or lub_category = UB_TV_POTION1 Or lub_category = UB_TV_POTION2 Then
        If fub_st_kind_is_known() Then
            lsl_value = gsl_item_cost
        Else
            lsl_value = 20
        End If

    ElseIf lub_category = UB_TV_FOOD Then
        lsl_value = gsl_item_cost
        If gub_item_sub_category < UB_ITEM_SINGLE_STACK_MIN + UB_MAX_MUSHROOMS Then
            If fub_st_kind_is_known() = false Then lsl_value = 1
        End If

    ElseIf lub_category = UB_TV_AMULET Or lub_category = UB_TV_RING Then
        If fub_st_kind_is_known() = false Then
            lsl_value = 45
        ElseIf lub_identified = false Then
            lsl_value = gsl_object_cost
        Else
            lsl_value = gsl_item_cost
        End If

    ElseIf lub_category = UB_TV_STAFF Or lub_category = UB_TV_WAND Then
        If fub_st_kind_is_known() = false Then
            If lub_category = UB_TV_WAND Then
                lsl_value = 50
            Else
                lsl_value = 70
            End If
        ElseIf lub_identified Then
            lsl_value = gsl_item_cost + ( gsl_item_cost / 20 ) * gsw_item_misc_use
        Else
            lsl_value = gsl_item_cost
        End If

    ElseIf lub_category = UB_TV_DIGGING Then
        If lub_identified = false Then
            lsl_value = gsl_object_cost
        ElseIf gsw_item_misc_use < 0 Then
            lsl_value = 0
        Else
            lsl_value = gsl_item_cost + ( Cast( Long , gsw_item_misc_use ) - gsw_object_misc_use ) * 100
            If lsl_value < 0 Then lsl_value = 0
        End If

    Else
        lsl_value = gsl_item_cost
    End If

    ' a batch, of arrows say, is worth that much each
    If gub_item_sub_category > UB_ITEM_GROUP_MIN Then lsl_value = lsl_value * gub_item_count
    Return lsl_value
End Function


Function fsl_st_sell_price( pub_store As UByte ) As Long
    ' what the store would ask the player for the working item, Moria's storeItemSellPrice(): the item's value, adjusted
    ' for how the owner's race feels about the player's, the answer is the price, 0 if the store would not deal in it,
    ' and gsl_st_min_price and gsl_st_max_price are the least and the most the owner would take
    Dim lsl_price               As Long
    Dim luw_owner               As UInteger
    Dim lub_race , lub_adjust   As UByte
    Dim lub_max , lub_min       As UByte

    lsl_price = fsl_st_item_value()
    If gsl_item_cost < 1 Or lsl_price < 1 Then Return 0

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    luw_owner  = A_TABLE_OWNERS + Cast( UInteger , Peek( fuw_st_state( pub_store ) + UB_STORE_OWNER ) ) * UB_OWNER_SIZE
    lub_max    = Peek( luw_owner + UB_OWNER_MAX_INFLATE )
    lub_min    = Peek( luw_owner + UB_OWNER_MIN_INFLATE )
    lub_race   = Peek( luw_owner + UB_OWNER_RACE )
    lub_adjust = Peek( A_TABLE_RACE_PRICES + Cast( UInteger , lub_race ) * 8 + gub_player_race )

    lsl_price = lsl_price * lub_adjust / 100
    If lsl_price < 1 Then lsl_price = 1
    gsl_st_max_price = lsl_price * lub_max / 100
    gsl_st_min_price = lsl_price * lub_min / 100
    If gsl_st_min_price > gsl_st_max_price Then gsl_st_min_price = gsl_st_max_price
    Return lsl_price
End Function


'##################################################################################################################################
' --- a store's stock ---

Function fub_st_has_room( pub_store As UByte ) As UByte
    ' true if the store can take the working item: it has a free place, or it already has some to stack it with,
    ' Moria's storeCheckPlayerItemsCount()
    Dim i , lub_count   As UByte
    Dim lub_found       As UByte = false
    Dim luw_record      As UInteger

    lub_count = fub_st_count( pub_store )
    If lub_count < UB_STORE_MAX_ITEMS Then Return true
    If gub_item_sub_category < UB_ITEM_SINGLE_STACK_MIN Then Return false

    For i = 0 To lub_count - 1
        luw_record = fuw_st_record( pub_store , i )
        If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) = gub_item_category And Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET ) = gub_item_sub_category Then
            If Cast( UInteger , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) ) + gub_item_count < 256 Then
                If gub_item_sub_category < UB_ITEM_GROUP_MIN Or Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) = gsw_item_misc_use Then lub_found = true
            End If
        End If
    Next
    Return lub_found
End Function


Sub s_st_insert( pub_store As UByte , pub_at As UByte , psl_cost As Long )
    ' puts the working item into a store's stock at the given place, moving everything from there on up by one,
    ' Moria's storeItemInsert(), the cost is kept as a negative number, which means "not yet haggled over"
    ' N.B: the records are moved through the working monster, which is simply 64 bytes that nothing else is using in here
    Dim lsw_i       As Integer
    Dim lub_count   As UByte

    lub_count = fub_st_count( pub_store )
    lsw_i = Cast( Integer , lub_count ) - 1
    While lsw_i >= Cast( Integer , pub_at )
        s_st_fetch( pub_store , lsw_i , A_MONSTER )
        s_st_store( pub_store , lsw_i + 1 , A_MONSTER )
        lsw_i = lsw_i - 1
    End While
    gsl_item_store_cost = -psl_cost
    s_st_store( pub_store , pub_at , A_ITEM )
    Poke fuw_st_state( pub_store ) + UB_STORE_ITEM_COUNT , lub_count + 1
End Sub


Function fsw_st_carry( pub_store As UByte ) As Integer
    ' the store takes the working item into its stock, Moria's storeCarryItem(): the stock is kept in order of
    ' category, highest first, so the item is added to a stack of the same thing if there is one, and otherwise
    ' goes in front of the first item of a lower category, the answer is where it ended up, or -1 if the store
    ' would not deal in it
    Dim lsl_cost                                    As Long
    Dim lub_item , lub_count , lub_flag             As UByte
    Dim lub_category , lub_sub , lub_number         As UByte
    Dim lub_their_category , lub_their_count        As UByte
    Dim lsw_index , lsw_misc                        As Integer
    Dim luw_record                                  As UInteger

    If fsl_st_sell_price( pub_store ) < 1 Then Return -1
    lsl_cost     = gsl_st_max_price
    lub_category = gub_item_category
    lub_sub      = gub_item_sub_category
    lub_number   = gub_item_count
    lsw_misc     = gsw_item_misc_use
    lsw_index    = -1
    lub_item     = 0
    lub_flag     = false
    ' N.B: like Moria, the first place is always looked at, even in an empty store, where it holds "nothing", category 0
    Do
        lub_count          = fub_st_count( pub_store )
        luw_record         = fuw_st_record( pub_store , lub_item )
        lub_their_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
        If lub_category = lub_their_category Then
            If lub_sub = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET ) And lub_sub >= UB_ITEM_SINGLE_STACK_MIN Then
                If lub_sub < UB_ITEM_GROUP_MIN Or Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) = lsw_misc Then
                    ' add to the stack that is there
                    lsw_index       = lub_item
                    lub_their_count = Peek( luw_record + UB_ITEM_COUNT_OFFSET ) + lub_number
                    If lub_sub > UB_ITEM_GROUP_MIN Then
                        ' a bigger batch is worth more: price the whole of it afresh
                        Poke luw_record + UB_ITEM_COUNT_OFFSET , lub_their_count
                        s_st_fetch( pub_store , lub_item , A_ITEM )
                        lsl_cost = fsl_st_sell_price( pub_store )
                        gsl_item_store_cost = -gsl_st_max_price
                        s_st_store( pub_store , lub_item , A_ITEM )
                    Else
                        If lub_their_count > 24 Then lub_their_count = 24
                        Poke luw_record + UB_ITEM_COUNT_OFFSET , lub_their_count
                    End If
                    lub_flag = true
                End If
            End If
        ElseIf lub_category > lub_their_category Then
            s_st_insert( pub_store , lub_item , lsl_cost )
            lub_flag  = true
            lsw_index = lub_item
        End If
        lub_item = lub_item + 1
    Loop While lub_item < fub_st_count( pub_store ) And lub_flag = false

    ' it belongs after everything that is there
    If lub_flag = false Then
        lub_count = fub_st_count( pub_store )
        s_st_insert( pub_store , lub_count , lsl_cost )
        lsw_index = lub_count
    End If
    Return lsw_index
End Function


Sub s_st_destroy( pub_store As UByte , pub_item As UByte , pub_only_one As UByte )
    ' some or all of one item leaves a store's stock, Moria's storeDestroyItem(): of things that stack singly it is one
    ' (when the player buys one) or a random number of them (when the store sells some off), anything else goes entirely
    Dim lub_count , lub_number , lub_have , lub_sub , i As UByte
    Dim luw_record                                      As UInteger

    luw_record = fuw_st_record( pub_store , pub_item )
    lub_have   = Peek( luw_record + UB_ITEM_COUNT_OFFSET )
    lub_sub    = Peek( luw_record + UB_ITEM_SUB_CATEGORY_OFFSET )
    If lub_sub >= UB_ITEM_SINGLE_STACK_MIN And lub_sub <= UB_ITEM_SINGLE_STACK_MAX Then
        If pub_only_one Then
            lub_number = 1
        Else
            lub_number = fsw_st_random( lub_have )
        End If
    Else
        lub_number = lub_have
    End If

    If lub_number <> lub_have Then
        luw_record = fuw_st_record( pub_store , pub_item )
        Poke luw_record + UB_ITEM_COUNT_OFFSET , lub_have - lub_number
    Else
        ' the last of them: close the gap, and blank the place left free at the end
        lub_count = fub_st_count( pub_store )
        i = pub_item
        While i + 1 < lub_count
            s_st_fetch( pub_store , i + 1 , A_MONSTER )
            s_st_store( pub_store , i , A_MONSTER )
            i = i + 1
        End While
        For i = 0 To UB_RECORD_SIZE - 1
            Poke A_MONSTER + i , 0
        Next
        s_st_store( pub_store , lub_count - 1 , A_MONSTER )
        Poke fuw_st_state( pub_store ) + UB_STORE_ITEM_COUNT , lub_count - 1
    End If
End Sub


Sub s_st_create( pub_store As UByte , psw_max_cost As Integer )
    ' the store buys in one new item, Moria's storeItemCreate(): something picked from the list of what this kind of
    ' store stocks, made as for the town's level, it gets up to four tries to come up with something the store has
    ' room for and its owner can afford
    ' N.B: Moria makes the item in a spare place in the level's item list, we make it in the working item
    Dim lsw_tries       As Integer
    Dim luw_object      As UInteger

    lsw_tries = 0
    While lsw_tries <= 3
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
        luw_object = Peek( UInteger , A_TABLE_STORE_CHOICES + Cast( UInteger , pub_store ) * UB_STORE_ITEM_TYPES * 2 + ( fsw_st_random( UB_STORE_ITEM_TYPES ) - 1 ) * 2 )
        guw_lib_param_2 = luw_object
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_FROM_OBJECT )
        guw_lib_param_2 = LEVEL_TOWN_OBJECTS
        s_core_call_library( UB_PAGED_CODE_LIB_TREASURE , UB_LIB_TREASURE_MAGIC )

        If fub_st_has_room( pub_store ) Then
            If gsl_item_cost > 0 And gsl_item_cost < psw_max_cost Then
                s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_STORE_BOUGHT )
                gsw_lib_result = fsw_st_carry( pub_store )
                lsw_tries = 10
            End If
        End If
        lsw_tries = lsw_tries + 1
    End While
End Sub


Sub s_st_maintain()
    ' every store sells off some of its stock and buys some in, Moria's storeMaintenance()...
    ' ...a store with plenty sells more than it buys, and a store that is low buys more than it sells
    Dim lub_store , lub_count   As UByte
    Dim lsw_turnaround          As Integer
    Dim lsw_max_cost            As Integer
    Dim luw_state               As UInteger

    For lub_store = 0 To UB_STORES - 1
        luw_state = fuw_st_state( lub_store )
        Poke UInteger luw_state + UB_STORE_INSULTS , 0

        lub_count = fub_st_count( lub_store )
        If lub_count >= UB_STORE_MIN_AUTO_SELL Then
            lsw_turnaround = fsw_st_random( UB_STORE_TURN_AROUND )
            If lub_count >= UB_STORE_MAX_AUTO_BUY Then lsw_turnaround = lsw_turnaround + 1 + lub_count - UB_STORE_MAX_AUTO_BUY
            lsw_turnaround = lsw_turnaround - 1
            While lsw_turnaround >= 0
                s_st_destroy( lub_store , fsw_st_random( fub_st_count( lub_store ) ) - 1 , false )
                lsw_turnaround = lsw_turnaround - 1
            End While
        End If

        lub_count = fub_st_count( lub_store )
        If lub_count <= UB_STORE_MAX_AUTO_BUY Then
            lsw_turnaround = fsw_st_random( UB_STORE_TURN_AROUND )
            If lub_count < UB_STORE_MIN_AUTO_SELL Then lsw_turnaround = lsw_turnaround + UB_STORE_MIN_AUTO_SELL - lub_count
            s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
            lsw_max_cost = Peek( Integer , A_TABLE_OWNERS + Cast( UInteger , Peek( luw_state + UB_STORE_OWNER ) ) * UB_OWNER_SIZE + UB_OWNER_MAX_COST )
            lsw_turnaround = lsw_turnaround - 1
            While lsw_turnaround >= 0
                s_st_create( lub_store , lsw_max_cost )
                lsw_turnaround = lsw_turnaround - 1
            End While
        End If
    Next
End Sub


'##################################################################################################################################
' --- what each store has in stock, for checking this page ---

Sub s_st_test()
    ' one store at a time: its owner, then each item with the price the owner would start at, keys 1 to 6 change store
    Dim lub_store , lub_count , i , lub_rows    As UByte
    Dim lub_owner                               As UByte
    Dim lub_done                                As UByte = false

    lub_store = 0
    While lub_done = false
        s_core_clear_screen()
        lub_owner = Peek( fuw_st_state( lub_store ) + UB_STORE_OWNER )
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
        lub_rows = fub_core_print_text_at( 0 , 1 , A_TABLE_OWNERS + Cast( UInteger , lub_owner ) * UB_OWNER_SIZE , UB_BRIGHT_WHITE )
        lub_count = fub_st_count( lub_store )
        s_core_print_string_at( 1 , 1 , "store " + fs_core_number( lub_store + 1 ) + ", " + fs_core_number( lub_count ) + " different items in stock" , UB_DARK_GREY )
        If lub_count > 0 Then
            For i = 0 To lub_count - 1
                s_st_fetch( lub_store , i , A_ITEM )
                gub_lib_param_1 = true
                s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
                s_core_print_string_at( 3 + i , 1 , fs_core_char( 97 + i ) + ")" , UB_WHITE )
                lub_rows = fub_core_print_text_at( 3 + i , 4 , A_TEXT_BUFFER , UB_WHITE )
                ' the cost is kept as a negative number until it has been haggled over
                s_core_print_string_at( 3 + i , 68 , fs_core_number( Abs( gsl_item_store_cost ) ) , UB_BRIGHT_YELLOW )
            Next
        End If
        s_core_print_string_at( 30 , 1 , "[ 1 to 6 for another store, any other key to go back ]" , UB_BRIGHT_GREEN )
        s_core_get_key()
        If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "6" ) Then
            lub_store = gub_key_char - Code( "1" )
        Else
            lub_done = true
        End If
    End While
End Sub


'##################################################################################################################################
' --- the way in ---

Sub s_lib_stores()
    gub_st_saved_page = gub_core_MMU1_page_number

    If gub_lib_function = UB_LIB_STORES_MAINTAIN Then
        s_st_maintain()
    ElseIf gub_lib_function = UB_LIB_STORES_VALUE Then
        gsl_lib_long_1 = fsl_st_item_value()
    ElseIf gub_lib_function = UB_LIB_STORES_SELL_PRICE Then
        gsl_lib_long_1 = fsl_st_sell_price( gub_lib_param_1 )
        gsl_lib_long_2 = gsl_st_min_price
        gsl_lib_long_3 = gsl_st_max_price
    ElseIf gub_lib_function = UB_LIB_STORES_CARRY Then
        gsw_lib_result = fsw_st_carry( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_STORES_DESTROY Then
        s_st_destroy( gub_lib_param_1 , Cast( UByte , guw_lib_param_2 ) , Cast( UByte , gsw_lib_result ) )
    ElseIf gub_lib_function = UB_LIB_STORES_TEST Then
        s_st_test()
    ElseIf gub_lib_function = UB_LIB_STORES_HAS_ROOM Then
        gsw_lib_result = fub_st_has_room( gub_lib_param_1 )
    End If

    ' the caller gets back the page it had in the second data slot, 255 means it had none of ours there yet
    If gub_st_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , gub_st_saved_page )
End Sub
