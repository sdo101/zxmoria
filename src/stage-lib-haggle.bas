#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_haggle()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-strings-include.bas"
#include "stage-lib-haggle-include.bas"

' this page is a LIBRARY, not a stage: bargaining with a store owner, the haggling half of Moria's store.cpp...
' ...the store stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_HAGGLE , <which routine> ), the routines are:
'
'   UB_LIB_HAGGLE_PURCHASE  the player wants to buy the working item (A_ITEM) from store gub_core_store, the owner
'                           names a price and the player makes offers until they agree, or do not, Moria's
'                           storePurchaseHaggle(): gsw_lib_result says what came of it, one of the UB_BID_ values,
'                           and if a price was agreed it is in gsl_lib_long_1
'
' the bargaining happens on the top two rows of the screen, and rows 21 to 23 show what the player may do, the store
' stage puts its own commands back there afterwards
'   UB_LIB_HAGGLE_SELL      the player wants to sell the working item to the store, Moria's storeSellHaggle(), the
'                           answers come back the same way, that half is in stage-lib-haggle-2.bas, this page passes it on


'##################################################################################################################################
' --- buying ---

Function fub_hg_purchase() As UByte
    ' Moria's storePurchaseHaggle(), the agreed price is left in gsl_lib_long_1
    Dim lub_status , lub_rejected , lub_bidding_open , lub_no_haggle    As UByte
    Dim lsl_new_price , lsl_max_sell , lsl_min_sell , lsl_cost          As Long
    Dim lsl_max_buy , lsl_final_asking , lsl_current_asking             As Long
    Dim lsl_last_offer , lsl_adjustment , lsl_min_per , lsl_max_per     As Long
    Dim lsw_offers , lsw_final_flag , lsw_charisma                      As Integer
    Dim ls_comment                                                      As String

    lub_status    = UB_BID_RECEIVED
    lsl_new_price = 0

    ' what the store would ask, then what the player's charm does to that, Moria's storePurchaseCustomerAdjustment()
    gub_lib_param_1 = gub_hg_store
    s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_SELL_PRICE )
    lsl_cost     = gsl_lib_long_1
    lsl_min_sell = gsl_lib_long_2
    lsl_max_sell = gsl_lib_long_3
    lsw_charisma = fsw_hg_charisma()
    lsl_max_sell = lsl_max_sell * lsw_charisma / 100
    If lsl_max_sell <= 0 Then lsl_max_sell = 1
    lsl_min_sell = lsl_min_sell * lsw_charisma / 100
    If lsl_min_sell <= 0 Then lsl_min_sell = 1

    ' cast max_inflate to signed so that subtraction works correctly
    lsl_max_buy = lsl_cost * ( 200 - Cast( Long , gub_hg_owner_max_inflate ) ) / 100
    If lsl_max_buy <= 0 Then lsl_max_buy = 1

    ' Moria's displayStoreHaggleCommands()
    s_hg_clear_row( 21 )
    s_hg_clear_row( 22 )
    s_hg_clear_row( 23 )
    s_core_print_string_at( 21 , 0 , "Specify an offer in gold pieces." , UB_WHITE )
    s_core_print_string_at( 22 , 0 , "ESC) Quit Haggling." , UB_WHITE )

    lsl_final_asking   = lsl_min_sell
    lsl_current_asking = lsl_max_sell
    ls_comment         = "Asking"
    lub_no_haggle      = false
    lsw_offers         = 0          ' this prevents incremental haggling on first try

    ' go right to final price if player has bargained well
    If fub_hg_no_need_to_bargain( lsl_final_asking ) Then
        s_core_message( UW_MSG_AFTER_A_LONG_BARGAINING_SESSION )
        lsl_current_asking    = lsl_min_sell
        ls_comment            = "Final offer"
        lub_no_haggle         = true
        ' Set up automatic increment, so that a return will accept the final price.
        gsw_hg_last_increment = lsl_min_sell
        lsw_offers            = 1
    End If

    lsl_last_offer   = lsl_max_buy
    gsl_hg_new_offer = 0
    lsl_min_per      = gub_hg_owner_haggle
    lsl_max_per      = lsl_min_per * 3
    lsw_final_flag   = 0
    lub_rejected     = false

    While lub_rejected = false
        Do
            lub_bidding_open = true
            ' N.B: the row is not cleared first, "Your last offer" is on its right hand half and stays there
            s_core_print_string_at( 1 , 0 , ls_comment + " :  " + fs_core_number( lsl_current_asking ) , UB_BRIGHT_WHITE )
            lub_status = fub_hg_receive_offer( "What do you offer? " , lsl_last_offer , lsw_offers , 1 )
            If lub_status <> UB_BID_RECEIVED Then
                lub_rejected = true
            ElseIf gsl_hg_new_offer > lsl_current_asking Then
                ' more than was asked: the owner begs the player's pardon
                s_hg_say( UW_STR_SORRY + fsw_hg_random( 5 ) - 1 )
                ' rejected, reset new_offer for incremental haggling
                gsl_hg_new_offer = lsl_last_offer
                ' If the automatic increment is large enough to overflow, then the player must have made a mistake.
                ' Clear it because it is useless.
                If lsl_last_offer + gsw_hg_last_increment > lsl_current_asking Then gsw_hg_last_increment = 0
            ElseIf gsl_hg_new_offer = lsl_current_asking Then
                lub_rejected  = true
                lsl_new_price = gsl_hg_new_offer
            Else
                lub_bidding_open = false
            End If
        Loop While lub_rejected = false And lub_bidding_open

        If lub_rejected = false Then
            ' how far the player came towards the asking price, as a percentage, the owner comes down to match
            lsl_adjustment = ( gsl_hg_new_offer - lsl_last_offer ) * 100 / ( lsl_current_asking - lsl_last_offer )
            If lsl_adjustment < lsl_min_per Then
                lub_rejected = fub_hg_haggle_insults()
                If lub_rejected Then lub_status = UB_BID_INSULTED
            ElseIf lsl_adjustment > lsl_max_per Then
                lsl_adjustment = lsl_adjustment * 75 / 100
                If lsl_adjustment < lsl_max_per Then lsl_adjustment = lsl_max_per
            End If
            lsl_adjustment = ( ( lsl_current_asking - gsl_hg_new_offer ) * ( lsl_adjustment + fsw_hg_random( 5 ) - 3 ) / 100 ) + 1
            ' don't let the price go up
            If lsl_adjustment > 0 Then lsl_current_asking = lsl_current_asking - lsl_adjustment

            If lsl_current_asking < lsl_final_asking Then
                lsl_current_asking = lsl_final_asking
                ls_comment = "Final Offer"
                ' Set the automatic haggle increment so that RET will give a new_offer equal to the final_ask price.
                gsw_hg_last_increment = lsl_final_asking - gsl_hg_new_offer
                lsw_final_flag = lsw_final_flag + 1
                If lsw_final_flag > 3 Then
                    If fub_hg_increase_insults() Then
                        lub_status = UB_BID_INSULTED
                    Else
                        lub_status = UB_BID_REJECTED
                    End If
                    lub_rejected = true
                End If
            ElseIf gsl_hg_new_offer >= lsl_current_asking Then
                lub_rejected  = true
                lsl_new_price = gsl_hg_new_offer
            End If

            If lub_rejected = false Then
                lsl_last_offer = gsl_hg_new_offer
                lsw_offers     = lsw_offers + 1         ' enable incremental haggling
                s_hg_clear_row( 1 )
                s_core_print_string_at( 1 , 39 , "Your last offer : " + fs_core_number( lsl_last_offer ) , UB_WHITE )
                ' Moria's printSpeechSellingHaggle(): one of three "final" lines, or one of sixteen ordinary ones
                If lsw_final_flag > 0 Then
                    s_hg_say_with_prices( UW_STR_SELLING_FINAL + fsw_hg_random( 3 ) - 1 , lsl_last_offer , lsl_current_asking )
                Else
                    s_hg_say_with_prices( UW_STR_SELLING_HAGGLE + fsw_hg_random( 16 ) - 1 , lsl_last_offer , lsl_current_asking )
                End If
                ' If the current increment would take you over the store's price, then decrease it to an exact match.
                If lsl_current_asking - lsl_last_offer < gsw_hg_last_increment Then gsw_hg_last_increment = lsl_current_asking - lsl_last_offer
            End If
        End If
    End While

    ' update bargaining info
    If lub_status = UB_BID_RECEIVED And lub_no_haggle = false Then s_hg_update_bargaining( lsl_new_price , lsl_final_asking )

    gsl_lib_long_1 = lsl_new_price
    Return lub_status
End Function


'##################################################################################################################################
' --- the way in ---

Sub s_lib_haggle()
    s_hg_begin()
    If gub_lib_function = UB_LIB_HAGGLE_PURCHASE Then
        gsw_lib_result = fub_hg_purchase()
    ElseIf gub_lib_function = UB_LIB_HAGGLE_SELL Then
        ' selling is the second page of this library
        s_core_call_library( UB_PAGED_CODE_LIB_HAGGLE_2 , UB_LIB_HAGGLE_SELL )
    End If
End Sub
