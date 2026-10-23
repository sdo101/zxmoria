' Moria's playerDisturb(): what a page needs that can disturb the player, which is any page where something happens
' that Moria answers with it: the turn's own changes (a light going out, hunger, poison, paralysis, heroism, speed...),
' a hit test (a monster's blow, a trap's dart, the player's own blow, a bash, a throw), a monster coming into view,
' casting, or bursting a door open, and saving the game...
' ...each page that includes this file has its own copy of the routines


Sub s_dst_rest_off()
    ' the part of Moria's playerRestOff() that must happen at once, the rest of it (the word on the screen, the
    ' messages) is done by the commands library's UB_LIB_COMMANDS_DISTURB, whose rest off knows from
    ' gub_game_rest_broken that this part has been done
    ' N.B: it must be at once: whether the player is resting decides how fast they heal this turn, how much they eat
    ' next turn, and, in the monsters' turn, whether the monsters still to move notice them at all
    If gsw_player_rest <> 0 Then
        gsw_player_rest          = 0
        gul_player_status        = gul_player_status bAnd ( $FFFFFFFF - UL_PY_REST )
        gsw_player_food_digested = gsw_player_food_digested + 1
        gub_game_rest_broken     = true
        ' and Moria's printMessage( CNIL ), at once too: a message showing waits for -more- now, before whatever
        ' disturbed the rest says its piece (found 20 October 2026: done later, by the commands library, it waited
        ' after a monster's messages instead, and the key that answered it was a key lost, a turn short of Moria)
        ' N.B: through the core's jump table, not every page that includes this file has stage-message-include.bas
        Asm
            call A_JUMP_MSG_FLUSH
            call A_JUMP_MSG_CLEAR
        End Asm
    End If
    gub_game_disturb = gub_game_disturb bOr MB_DISTURB_SCREEN
End Sub


Sub s_dst_disturb( pub_major As UByte , pub_light As UByte )
    ' Moria's playerDisturb( major , light ), all of it that changes the game, at once, where Moria does it:
    '   any disturbance     ends a count, a rest, and a run
    '   a major one         (being hit at, or the chance of it) also turns searching off
    '   a light one         (the player's light or sight has changed) also ends a run and puts the view right
    ' what is left for the screen is done by the commands library's UB_LIB_COMMANDS_DISTURB, which the walking stage
    ' calls when it finds gub_game_disturb set
    Dim lub_function    As UByte
    Dim lub_param_1     As UByte
    Dim luw_param_2     As UInteger

    guw_game_command_count = 0

    If pub_major And ( gul_player_status bAnd UL_PY_SEARCH ) <> 0 Then
        ' Moria's playerSearchOff(): the player's speed, and so every monster's, goes back by one, the second turn
        ' library does that, and puts the working monster's speed right too, so this may happen in the middle of a
        ' monster's turn or an attack... the library's parameters are kept, the routine that called this needs them
        lub_function = gub_lib_function
        lub_param_1  = gub_lib_param_1
        luw_param_2  = guw_lib_param_2
        guw_lib_param_2 = $FFFF                     ' -1
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED )
        gub_lib_function = lub_function
        gub_lib_param_1  = lub_param_1
        guw_lib_param_2  = luw_param_2
        gul_player_status        = gul_player_status bAnd ( $FFFFFFFF - UL_PY_SEARCH )
        gsw_player_food_digested = gsw_player_food_digested - 1
        gub_game_turn_flags      = gub_game_turn_flags bOr MB_TURN_RESET_VIEW
        gub_game_disturb         = gub_game_disturb bOr MB_DISTURB_SEARCH_OFF
    End If

    s_dst_rest_off()

    If pub_light Or gub_game_running <> 0 Then
        gub_game_running    = 0
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_RESET_VIEW
    End If
End Sub


Sub s_mon_disturb()
    ' what a monster does to the player is always a major disturbance: being attacked, a monster coming into view,
    ' its spell, a door bursting open
    s_dst_disturb( true , false )
End Sub
