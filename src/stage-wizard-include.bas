' what the two wizard libraries share, stage-lib-wizard.bas and stage-lib-wizard-2.bas: asking the player a question
' on the top row of the screen, each page has its own copy of these routines

' --- its working storage is in globals.bas, under "private to stage-wizard-include.bas", moved there on 22 October 2026 ---


Function fub_wz_confirm( ps_prompt As String ) As UByte
    ' Moria's getInputConfirmation(): true only for y
    s_msg_flush()
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , ps_prompt + " [y/n]" , UB_WHITE )
    Do
        s_core_get_key()
    Loop While gub_key_char = UC_SPACE
    s_msg_clear()
    If gub_key_char = Code( "y" ) Or gub_key_char = Code( "Y" ) Then Return true
    Return false
End Function


Function fub_wz_ask( ps_prompt As String , pub_max As UByte ) As UByte
    ' Moria's putStringClearToEOL() and getStringInput(), and then stringToNumber(): the question, and an answer
    ' of up to pub_max characters typed after it, false if the player escaped, otherwise gub_wz_valid says
    ' whether the answer was a number and gsl_wz_number is the number
    Dim lub_col , lub_length , i    As UByte
    Dim lub_char , lub_minus        As UByte
    Dim lub_digits                  As UByte

    s_msg_flush()
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , ps_prompt , UB_WHITE )
    lub_col    = Len( ps_prompt )
    lub_length = 0
    Do
        s_core_get_key()
        If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Then
            s_msg_clear()
            Return false
        End If
        If gub_key_char = UC_BACKSPACE Then
            If lub_length > 0 Then
                lub_length = lub_length - 1
                s_core_print_char_at( 0 , lub_col + lub_length , 32 , UB_WHITE )
            End If
        ElseIf gub_key_char >= UC_SPACE And gub_key_char < UC_DELETE And lub_length < pub_max Then
            Poke A_PROMPT + lub_length , gub_key_char
            s_core_print_char_at( 0 , lub_col + lub_length , gub_key_char , UB_WHITE )
            lub_length = lub_length + 1
        End If
    Loop Until gub_key_char = UC_ENTER
    Poke A_PROMPT + lub_length , 0
    ' N.B: Moria leaves the question and its answer on the screen until something else is written there
    s_msg_clear()

    ' the number: spaces, a sign, digits, and nothing else
    gsl_wz_number = 0
    gub_wz_valid  = false
    lub_minus     = false
    lub_digits    = 0
    i = 0
    While Peek( A_PROMPT + i ) = 32
        i = i + 1
    End While
    lub_char = Peek( A_PROMPT + i )
    If lub_char = Code( "-" ) Or lub_char = Code( "+" ) Then
        If lub_char = Code( "-" ) Then lub_minus = true
        i = i + 1
    End If
    lub_char = Peek( A_PROMPT + i )
    While lub_char >= Code( "0" ) And lub_char <= Code( "9" )
        gsl_wz_number = gsl_wz_number * 10 + ( lub_char - Code( "0" ) )
        lub_digits    = lub_digits + 1
        i = i + 1
        lub_char = Peek( A_PROMPT + i )
    End While
    ' N.B: getStringInput() has taken off any spaces after it
    While lub_char = UC_SPACE
        i = i + 1
        lub_char = Peek( A_PROMPT + i )
    End While
    If lub_digits > 0 And lub_char = 0 Then gub_wz_valid = true
    If lub_minus Then gsl_wz_number = 0 - gsl_wz_number
    Return true
End Function
