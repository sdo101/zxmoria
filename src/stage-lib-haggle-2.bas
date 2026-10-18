#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_haggle_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-strings-include.bas"
#include "stage-lib-haggle-include.bas"

' this page is the second half of the haggle LIBRARY, see stage-lib-haggle.bas, which is the page a stage calls...
' ...that page hands on to this one the bargaining when the player is selling:
'
'   UB_LIB_HAGGLE_SELL      the player wants to sell the working item (A_ITEM) to store gub_core_store, the owner makes
'                           an offer and the player names prices until they agree, or do not, Moria's storeSellHaggle():
'                           gsw_lib_result says what came of it, one of the UB_BID_ values, and if a price was
'                           agreed it is in gsl_lib_long_1


Function fub_hg_sell() As UByte
    ' Moria's storeSellHaggle(), with its storeSellCustomerAdjustment(), the agreed price is left in gsl_lib_long_1
    ' N.B: here the owner's offer goes up and the player's asking price comes down, the mirror image of buying
    Dim lub_status , lub_rejected , lub_bidding_open , lub_no_haggle    As UByte
    Dim lsl_new_price , lsl_cost , lsl_max_gold                         As Long
    Dim lsl_max_sell , lsl_min_buy , lsl_max_buy                        As Long
    Dim lsl_final_asking , lsl_current_asking                           As Long
    Dim lsl_last_offer , lsl_adjustment , lsl_min_per , lsl_max_per     As Long
    Dim lsw_offers , lsw_final_flag                                     As Integer
    Dim lub_race_adjust                                                 As UByte
    Dim ls_comment                                                      As String

    lub_status     = UB_BID_RECEIVED
    lsl_new_price  = 0
    lub_rejected   = false
    lsw_final_flag = 0
    lub_no_haggle  = false

    s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_VALUE )
    lsl_cost = gsl_lib_long_1

    If lsl_cost < 1 Then
        ' the owner will not have it at any price
        gsl_lib_long_1 = 0
        Return UB_BID_OFFENDED
    End If

    ' Moria's storeSellCustomerAdjustment(): what the owner thinks it is worth to them, from this player
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    lub_race_adjust = Peek( A_TABLE_RACE_PRICES + Cast( UInteger , gub_hg_owner_race ) * 8 + gub_player_race )
    lsl_cost = lsl_cost * ( 200 - fsw_hg_charisma() ) / 100
    lsl_cost = lsl_cost * ( 200 - Cast( Long , lub_race_adjust ) ) / 100
    If lsl_cost < 1 Then lsl_cost = 1
    lsl_max_sell = lsl_cost * gub_hg_owner_max_inflate / 100
    ' cast max_inflate to signed so that subtraction works correctly
    lsl_max_buy  = lsl_cost * ( 200 - Cast( Long , gub_hg_owner_max_inflate ) ) / 100
    lsl_min_buy  = lsl_cost * ( 200 - Cast( Long , gub_hg_owner_min_inflate ) ) / 100
    If lsl_min_buy < 1 Then lsl_min_buy = 1
    If lsl_max_buy < 1 Then lsl_max_buy = 1
    If lsl_min_buy < lsl_max_buy Then lsl_min_buy = lsl_max_buy
    lsl_min_per  = gub_hg_owner_haggle
    lsl_max_per  = lsl_min_per * 3
    lsl_max_gold = gsw_hg_owner_max_cost

    ' Moria's displayStoreHaggleCommands()
    s_hg_clear_row( 21 )
    s_hg_clear_row( 22 )
    s_hg_clear_row( 23 )
    s_core_print_string_at( 21 , 0 , "Specify an asking-price in gold pieces." , UB_WHITE )
    s_core_print_string_at( 22 , 0 , "ESC) Quit Haggling." , UB_WHITE )

    lsw_offers = 0          ' this prevents incremental haggling on first try
    If lsl_max_buy > lsl_max_gold Then
        lsw_final_flag = 1
        ls_comment     = "Final Offer"
        ' Disable the automatic haggle increment on RET.
        gsw_hg_last_increment = 0
        lsl_current_asking = lsl_max_gold
        lsl_final_asking   = lsl_max_gold
        s_core_message( UW_MSG_I_AM_SORRY_BUT_I_HAVE_NOT_THE )
        lub_no_haggle = true
    Else
        lsl_current_asking = lsl_max_buy
        lsl_final_asking   = lsl_min_buy
        If lsl_final_asking > lsl_max_gold Then lsl_final_asking = lsl_max_gold
        ls_comment = "Offer"
        ' go right to final price if player has bargained well
        If fub_hg_no_need_to_bargain( lsl_final_asking ) Then
            s_core_message( UW_MSG_AFTER_A_LONG_BARGAINING_SESSION )
            lsl_current_asking = lsl_final_asking
            ls_comment         = "Final offer"
            lub_no_haggle      = true
            ' Set up automatic increment, so that a return will accept the final price.
            gsw_hg_last_increment = lsl_final_asking
            lsw_offers = 1
        End If
    End If

    lsl_last_offer   = lsl_max_sell
    gsl_hg_new_offer = 0
    If lsl_current_asking < 1 Then lsl_current_asking = 1

    Do
        Do
            lub_bidding_open = true
            ' N.B: the row is not cleared first, "Your last bid" is on its right hand half and stays there
            s_core_print_string_at( 1 , 0 , ls_comment + " :  " + fs_core_number( lsl_current_asking ) , UB_BRIGHT_WHITE )
            lub_status = fub_hg_receive_offer( "What price do you ask? " , lsl_last_offer , lsw_offers , -1 )
            If lub_status <> UB_BID_RECEIVED Then
                lub_rejected = true
            ElseIf gsl_hg_new_offer < lsl_current_asking Then
                ' less than was offered: the owner begs the player's pardon
                s_hg_say( UW_STR_SORRY + fsw_hg_random( 5 ) - 1 )
                ' rejected, reset new_offer for incremental haggling
                gsl_hg_new_offer = lsl_last_offer
                ' If the automatic increment is large enough to overflow, then the player must have made a mistake.
                ' Clear it because it is useless.
                If lsl_last_offer + gsw_hg_last_increment < lsl_current_asking Then gsw_hg_last_increment = 0
            ElseIf gsl_hg_new_offer = lsl_current_asking Then
                lub_rejected  = true
                lsl_new_price = gsl_hg_new_offer
            Else
                lub_bidding_open = false
            End If
        Loop While lub_rejected = false And lub_bidding_open

        If lub_rejected = false Then
            ' how far the player came down towards the offer, as a percentage, the owner comes up to match
            lsl_adjustment = ( lsl_last_offer - gsl_hg_new_offer ) * 100 / ( lsl_last_offer - lsl_current_asking )
            If lsl_adjustment < lsl_min_per Then
                lub_rejected = fub_hg_haggle_insults()
                If lub_rejected Then lub_status = UB_BID_INSULTED
            ElseIf lsl_adjustment > lsl_max_per Then
                lsl_adjustment = lsl_adjustment * 75 / 100
                If lsl_adjustment < lsl_max_per Then lsl_adjustment = lsl_max_per
            End If
            lsl_adjustment = ( ( gsl_hg_new_offer - lsl_current_asking ) * ( lsl_adjustment + fsw_hg_random( 5 ) - 3 ) / 100 ) + 1
            ' don't let the price go down
            If lsl_adjustment > 0 Then lsl_current_asking = lsl_current_asking + lsl_adjustment

            If lsl_current_asking > lsl_final_asking Then
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
            ElseIf gsl_hg_new_offer <= lsl_current_asking Then
                lub_rejected  = true
                lsl_new_price = gsl_hg_new_offer
            End If

            If lub_rejected = false Then
                lsl_last_offer = gsl_hg_new_offer
                lsw_offers     = lsw_offers + 1         ' enable incremental haggling
                s_hg_clear_row( 1 )
                s_core_print_string_at( 1 , 39 , "Your last bid " + fs_core_number( lsl_last_offer ) , UB_WHITE )
                ' Moria's printSpeechBuyingHaggle(): one of three "final" lines, or one of fifteen ordinary ones,
                ' N.B: in these %A1 is what the owner offers and %A2 is what the player asked
                If lsw_final_flag > 0 Then
                    s_hg_say_with_prices( UW_STR_BUYING_FINAL + fsw_hg_random( 3 ) - 1 , lsl_current_asking , lsl_last_offer )
                Else
                    s_hg_say_with_prices( UW_STR_BUYING_HAGGLE + fsw_hg_random( 15 ) - 1 , lsl_current_asking , lsl_last_offer )
                End If
                ' If the current decrement would take you under the store's price, then increase it to an exact match.
                If lsl_current_asking - lsl_last_offer > gsw_hg_last_increment Then gsw_hg_last_increment = lsl_current_asking - lsl_last_offer
            End If
        End If
    Loop While lub_rejected = false

    ' update bargaining info
    If lub_status = UB_BID_RECEIVED And lub_no_haggle = false Then s_hg_update_bargaining( lsl_new_price , lsl_final_asking )

    gsl_lib_long_1 = lsl_new_price
    Return lub_status
End Function


Sub s_lib_haggle_2()
    s_hg_begin()
    If gub_lib_function = UB_LIB_HAGGLE_SELL Then gsw_lib_result = fub_hg_sell()
End Sub
