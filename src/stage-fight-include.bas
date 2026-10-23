

Function fub_ft_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ft_direction() As UByte
    ' asks which way, Moria's getDirectionWithMemory(), 0 if the player thought better of it
    Dim lub_direction As UByte = 0
    Dim luw_count     As UInteger

    ' a command that is being repeated uses the direction it had the first time, without asking, and asking
    ' does not end a count that has just been given, Moria's use_last_direction
    luw_count = guw_game_command_count
    If gub_game_repeat_key >= MB_REPEAT_DONE Then
        lub_direction = gub_player_prev_dir
    Else
        s_core_message( UW_MSG_WHICH_DIRECTION )
        Do
            s_core_get_key()
            s_core_direction_key()
            If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) And gub_key_char <> Code( "5" ) Then lub_direction = gub_key_char - Code( "0" )
            If guw_key_code = UW_KEY_UP Then lub_direction = 8
            If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
            If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
            If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
        Loop Until lub_direction <> 0 Or gub_key_char = UC_ESCAPE Or guw_key_code = 0
        ' the question is not a message, Moria asks it with getCommand() and keeps nothing of it for Ctrl-P
        Asm
            call A_JUMP_HISTORY_FORGET
        End Asm
        s_msg_clear()
    End If
    guw_game_command_count = luw_count
    If lub_direction <> 0 Then gub_player_prev_dir = lub_direction
    ' backing out takes no time, Moria's getDirectionWithMemory() sets player_free_turn itself
    If lub_direction = 0 Then gub_game_free_turn = true
    Return lub_direction
End Function


Function fub_ft_confused_direction( pub_direction As UByte ) As UByte
    ' a confused player throws or bashes any which way, Moria's getRandomDirection()
    If gsw_player_confused <= 0 Then Return pub_direction
    s_core_message( UW_MSG_YOU_ARE_CONFUSED )
    Do
        pub_direction = fuw_cb_random( 9 )
    Loop Until pub_direction <> 5
    Return pub_direction
End Function


Sub s_ft_step( pub_direction As UByte )
    ' one square on from gub_ft_y and gub_ft_x, Moria's playerMovePosition(), which will not go off the edge of the map
    Dim lsw_y , lsw_x As Integer

    lsw_y = Cast( Integer , gub_ft_y ) + 1 - Cast( Integer , ( pub_direction - 1 ) / 3 )       ' 1 2 3 go down, 7 8 9 go up
    lsw_x = Cast( Integer , gub_ft_x ) + Cast( Integer , ( pub_direction - 1 ) Mod 3 ) - 1     ' 1 4 7 go left, 3 6 9 go right
    If lsw_y >= 0 And lsw_x >= 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) And lsw_x < Cast( Integer , gub_dungeon_cols ) Then
        gub_ft_y = lsw_y
        gub_ft_x = lsw_x
    End If
End Sub
