' everything the two pages of the haggle library share (stage-lib-haggle.bas, buying, and stage-lib-haggle-2.bas, selling):
' their working storage, talking to the player, taking an offer, insults, and the record of how well the player bargains...
' ...each page includes this file, so each has its own copy of the routines, and its own storage at the top of its own page

' --- its working storage is in globals.bas, under "private to stage-lib-haggle-include.bas", moved there on 22 October 2026 ---


Function fsw_hg_random( psw_max As Integer ) As Integer
    Return Cast( Integer , ful_core_random_number( Cast( ULong , psw_max ) ) )
End Function


Sub s_hg_clear_row( pub_row As UByte )
    s_core_clear_row( pub_row , 0 , UB_WHITE )
End Sub


Sub s_hg_say( puw_string As UInteger )
    ' the owner says one of the strings from the strings database
    s_string_fetch( puw_string , A_TEXT_BUFFER )
    s_msg_text( A_TEXT_BUFFER )
End Sub


Sub s_hg_say_with_prices( puw_string As UInteger , psl_offer As Long , psl_asking As Long )
    ' the owner says something with the two prices in it: %A1 in the string is the player's offer and %A2 is what the
    ' owner is asking, Moria's insertNumberIntoString(), the text is put together in this page's own storage
    Dim i , lub_out , lub_char  As UByte
    Dim ls_number               As String
    Dim j , lub_length          As UByte

    s_string_fetch( puw_string , A_TEXT_BUFFER + 100 )
    i       = 0
    lub_out = 0
    Do
        lub_char = Peek( A_TEXT_BUFFER + 100 + i )
        If lub_char = 0 Then Exit Do
        If lub_char = Code( "%" ) And Peek( A_TEXT_BUFFER + 101 + i ) = Code( "A" ) And ( Peek( A_TEXT_BUFFER + 102 + i ) = Code( "1" ) Or Peek( A_TEXT_BUFFER + 102 + i ) = Code( "2" ) ) Then
            If Peek( A_TEXT_BUFFER + 102 + i ) = Code( "1" ) Then
                ls_number = fs_core_number( psl_offer )
            Else
                ls_number = fs_core_number( psl_asking )
            End If
            lub_length = Len( ls_number )
            j = 0
            While j < lub_length And lub_out < 99
                Poke A_TEXT_BUFFER + lub_out , Code( ls_number( j ) )
                lub_out = lub_out + 1
                j = j + 1
            End While
            i = i + 3
        Else
            If lub_out < 99 Then
                Poke A_TEXT_BUFFER + lub_out , lub_char
                lub_out = lub_out + 1
            End If
            i = i + 1
        End If
    Loop
    Poke A_TEXT_BUFFER + lub_out , 0
    s_msg_text( A_TEXT_BUFFER )
End Sub


Function fsw_hg_charisma() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_CHARISMA )
    Return gsw_lib_result
End Function


Function fub_hg_increase_insults() As UByte
    ' the owner is insulted, once too often and the player is thrown out and the store shuts for a while,
    ' Moria's storeIncreaseInsults(), true means thrown out
    Dim lsw_insults , lub_comment As Integer

    lsw_insults = Peek( Integer , guw_hg_state + UB_STORE_INSULTS ) + 1
    Poke UInteger guw_hg_state + UB_STORE_INSULTS , Cast( UInteger , lsw_insults )
    If lsw_insults <= Cast( Integer , gub_hg_owner_max_insults ) Then Return false

    ' Moria's printSpeechGetOutOfMyStore(): two lines that go together
    lub_comment = fsw_hg_random( 5 ) - 1
    s_hg_say( UW_STR_INSULTED + lub_comment )
    s_hg_say( UW_STR_GET_OUT + lub_comment )

    Poke UInteger guw_hg_state + UB_STORE_INSULTS , 0
    Poke UInteger guw_hg_state + UB_STORE_BAD_BUYS , Peek( UInteger , guw_hg_state + UB_STORE_BAD_BUYS ) + 1
    Poke ULong guw_hg_state + UB_STORE_TURNS_LEFT , Cast( ULong , gsl_game_turn + 2500 + fsw_hg_random( 2500 ) )
    Return true
End Function


Function fub_hg_haggle_insults() As UByte
    ' Moria's storeHaggleInsults(): an insult, and if the player is not thrown out for it, a request to try again
    If fub_hg_increase_insults() Then Return true
    s_hg_say( UW_STR_TRY_AGAIN + fsw_hg_random( 10 ) - 1 )
    s_msg_flush()
    Return false
End Function


Function fub_hg_input( pub_col As UByte ) As UByte
    ' the player types on the top row from the given column, up to 40 characters, Enter to finish, Moria's
    ' getStringInput(): what was typed is left in A_HG_INPUT ending in a 0, false means escape was pressed
    Dim lub_length  As UByte = 0
    Dim i           As UByte

    For i = 0 To 39
        If pub_col + i < UB_SCREEN_COLS Then s_core_print_char_at( 0 , pub_col + i , 32 , UB_WHITE )
    Next
    s_core_print_char_at( 0 , pub_col , Code( "_" ) , UB_WHITE )
    Do
        s_core_get_key()
        ' what was typed is not a message, Moria's getStringInput() keeps nothing of it for Ctrl-P
        If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Or gub_key_char = UC_ENTER Then
            Asm
                call A_JUMP_HISTORY_FORGET
            End Asm
        End If
        If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then Return false
        If gub_key_char = UC_ENTER Then Exit Do
        If gub_key_char = UC_BACKSPACE Then
            If lub_length > 0 Then
                s_core_print_char_at( 0 , pub_col + lub_length , 32 , UB_WHITE )
                lub_length = lub_length - 1
                s_core_print_char_at( 0 , pub_col + lub_length , Code( "_" ) , UB_WHITE )
            End If
        ElseIf gub_key_char >= UC_SPACE And gub_key_char < UC_DELETE And lub_length < 40 And pub_col + lub_length < UB_SCREEN_COLS - 1 Then
            Poke A_HG_INPUT + lub_length , gub_key_char
            s_core_print_char_at( 0 , pub_col + lub_length , gub_key_char , UB_BRIGHT_WHITE )
            lub_length = lub_length + 1
            s_core_print_char_at( 0 , pub_col + lub_length , Code( "_" ) , UB_WHITE )
        End If
    Loop
    s_core_print_char_at( 0 , pub_col + lub_length , 32 , UB_WHITE )
    ' spaces on the end do not count
    While lub_length > 0 And Peek( A_HG_INPUT + lub_length - 1 ) = 32
        lub_length = lub_length - 1
    End While
    Poke A_HG_INPUT + lub_length , 0
    Return true
End Function


Function fsl_hg_number() As Long
    ' what was typed, as a number, Moria's stringToNumber(): an optional + or - and then nothing but digits,
    ' anything else at all makes it 0, which the caller takes to mean "ask again"
    Dim lsl_value       As Long = 0
    Dim i , lub_char    As UByte
    Dim lub_negative    As UByte = false
    Dim lub_digits      As UByte = 0

    i = 0
    While Peek( A_HG_INPUT + i ) = 32
        i = i + 1
    End While
    If Peek( A_HG_INPUT + i ) = Code( "-" ) Then
        lub_negative = true
        i = i + 1
    ElseIf Peek( A_HG_INPUT + i ) = Code( "+" ) Then
        i = i + 1
    End If
    Do
        lub_char = Peek( A_HG_INPUT + i )
        If lub_char = 0 Then Exit Do
        If lub_char < Code( "0" ) Or lub_char > Code( "9" ) Or lub_digits >= 9 Then Return 0
        lsl_value  = lsl_value * 10 + ( lub_char - Code( "0" ) )
        lub_digits = lub_digits + 1
        i = i + 1
    Loop
    If lub_negative Then Return -lsl_value
    Return lsl_value
End Function


Function fub_hg_get_haggle( ps_prompt As String , psw_offer_count As Integer ) As UByte
    ' asks the player for an offer, Moria's storeGetHaggle(): a plain number is the offer itself, a number with a + or -
    ' in front raises or lowers the last offer by that much, and after the first offer just pressing Enter repeats the
    ' last raise, the offer is left in gsl_hg_new_offer, false means the player gave up
    Dim lub_valid , lub_increment , lub_first , i   As UByte
    Dim lsl_adjustment                              As Long
    Dim lub_col , lub_prompt                        As UByte
    Dim ls_last                                     As String

    lub_valid = true
    If psw_offer_count = 0 Then gsw_hg_last_increment = 0
    lub_increment  = false
    lsl_adjustment = 0
    lub_prompt     = Len( ps_prompt )

    While lub_valid And lsl_adjustment = 0
        s_msg_flush()
        s_hg_clear_row( 0 )
        s_core_print_string_at( 0 , 0 , ps_prompt , UB_BRIGHT_WHITE )
        lub_col = lub_prompt
        If psw_offer_count <> 0 And gsw_hg_last_increment <> 0 Then
            If gsw_hg_last_increment < 0 Then
                ls_last = "[-" + fs_core_number( -gsw_hg_last_increment ) + "] "
            Else
                ls_last = "[+" + fs_core_number( gsw_hg_last_increment ) + "] "
            End If
            s_core_print_string_at( 0 , lub_prompt , ls_last , UB_WHITE )
            lub_col = lub_prompt + Len( ls_last )
        End If

        If fub_hg_input( lub_col ) = false Then
            lub_valid = false
            Poke A_HG_INPUT , 0
        End If

        i = 0
        While Peek( A_HG_INPUT + i ) = 32
            i = i + 1
        End While
        lub_first = Peek( A_HG_INPUT + i )
        If lub_first = Code( "+" ) Or lub_first = Code( "-" ) Then lub_increment = true

        If psw_offer_count <> 0 And lub_increment Then
            lsl_adjustment = fsl_hg_number()
            If lsl_adjustment = 0 Then
                lub_increment = false
            Else
                gsw_hg_last_increment = lsl_adjustment
            End If
        ElseIf psw_offer_count <> 0 And Peek( A_HG_INPUT ) = 0 Then
            lsl_adjustment = gsw_hg_last_increment
            lub_increment  = true
        Else
            lsl_adjustment = fsl_hg_number()
        End If

        ' don't allow incremental haggling, if player has not made an offer yet
        If lub_valid And psw_offer_count = 0 And lub_increment Then
            s_core_message( UW_MSG_YOU_HAVENT_EVEN_MADE_YOUR_FIRST )
            lsl_adjustment = 0
            lub_increment  = false
        End If
    End While

    If lub_valid Then
        If lub_increment Then
            gsl_hg_new_offer = gsl_hg_new_offer + lsl_adjustment
        Else
            gsl_hg_new_offer = lsl_adjustment
        End If
    Else
        s_msg_clear()
    End If
    Return lub_valid
End Function


Function fub_hg_receive_offer( ps_prompt As String , psl_last_offer As Long , psw_offer_count As Integer , psw_factor As Integer ) As UByte
    ' gets an offer that is no worse than the last one, Moria's storeReceiveOffer(): going backwards insults the owner,
    ' psw_factor is 1 when the player is buying (offers must rise) and -1 when selling (asking prices must fall)
    Do
        If fub_hg_get_haggle( ps_prompt , psw_offer_count ) = false Then Return UB_BID_REJECTED
        If gsl_hg_new_offer * psw_factor >= psl_last_offer * psw_factor Then Return UB_BID_RECEIVED
        If fub_hg_haggle_insults() Then Return UB_BID_INSULTED
        gsl_hg_new_offer = psl_last_offer
    Loop
    Return UB_BID_REJECTED      ' never reached
End Function


Function fub_hg_no_need_to_bargain( psl_min_price As Long ) As UByte
    ' true if the player has bargained well here so often that the owner goes straight to their best price,
    ' Moria's storeNoNeedToBargain()
    Dim lsl_record As Long

    If Peek( UInteger , guw_hg_state + UB_STORE_GOOD_BUYS ) = 32767 Then Return true
    lsl_record = Cast( Long , Peek( UInteger , guw_hg_state + UB_STORE_GOOD_BUYS ) ) - 3 * Cast( Long , Peek( UInteger , guw_hg_state + UB_STORE_BAD_BUYS ) ) - 5
    If lsl_record > 0 Then
        If lsl_record * lsl_record > psl_min_price / 50 Then Return true
    End If
    Return false
End Function


Sub s_hg_update_bargaining( psl_price As Long , psl_min_price As Long )
    ' remembers how the player did, Moria's storeUpdateBargainingSkills(): getting the owner all the way down to their
    ' best price counts for the player, anything else counts against, cheap things do not count at all
    Dim luw_count As UInteger

    If psl_min_price < 10 Then Return
    If psl_price = psl_min_price Then
        luw_count = Peek( UInteger , guw_hg_state + UB_STORE_GOOD_BUYS )
        If luw_count < 32767 Then Poke UInteger guw_hg_state + UB_STORE_GOOD_BUYS , luw_count + 1
    Else
        luw_count = Peek( UInteger , guw_hg_state + UB_STORE_BAD_BUYS )
        If luw_count < 32767 Then Poke UInteger guw_hg_state + UB_STORE_BAD_BUYS , luw_count + 1
    End If
End Sub


Sub s_hg_begin()
    ' every routine of the library starts here: which store, where its state is, and what is wanted to know about its owner
    Dim luw_owner As UInteger

    gub_hg_store = gub_core_store
    guw_hg_state = A_STORES + Cast( UInteger , gub_hg_store ) * UB_STORE_STATE_SIZE
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    luw_owner = A_TABLE_OWNERS + Cast( UInteger , Peek( guw_hg_state + UB_STORE_OWNER ) ) * UB_OWNER_SIZE
    gub_hg_owner_haggle      = Peek( luw_owner + UB_OWNER_HAGGLE )
    gub_hg_owner_max_inflate = Peek( luw_owner + UB_OWNER_MAX_INFLATE )
    gub_hg_owner_min_inflate = Peek( luw_owner + UB_OWNER_MIN_INFLATE )
    gub_hg_owner_max_insults = Peek( luw_owner + UB_OWNER_MAX_INSULTS )
    gub_hg_owner_race        = Peek( luw_owner + UB_OWNER_RACE )
    gsw_hg_owner_max_cost    = Peek( Integer , luw_owner + UB_OWNER_MAX_COST )
End Sub