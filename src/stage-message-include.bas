' the message line, the top row of the screen, any stage or library that talks to the player includes this file...
' ...this is a first, small version of Moria's printMessage(): one message shows at a time, and if another comes
' before the player has had a chance to read it, "-more-" is put after the first and a key is waited for
' the length of the message showing is kept in the core data (gub_message_length), so that it carries from one
' page of code to the next
' N.B: the routines themselves are in the core now, one copy of them, see "THE MESSAGE LINE" in core.bas, what is
' here is the way to them: each has the name a page has always used for it, and jumps to the core's routine through
' the jump table, exactly as the shims in stage-include.bas do

Sub s_msg_clear()
    ' blanks the message line, Moria's messageLineClear()
    Asm
        jp A_JUMP_MSG_CLEAR
    End Asm
End Sub


Sub s_msg_flush()
    ' if a message is showing, waits for the player to have read it, and clears it
    Asm
        jp A_JUMP_MSG_FLUSH
    End Asm
End Sub


Sub s_msg_text( puw_address As UInteger )
    ' shows the text at puw_address, bytes ending in a 0, as a message
    Asm
        pop ix
        jp A_JUMP_MSG_TEXT
    End Asm
End Sub


Sub s_msg( ps_text As String )
    ' shows a message, N.B: any message ends a command that is being repeated, the core does that as the message
    ' is printed, see s_core_print_char_at_logged() in core.bas
    Asm
        pop ix
        jp A_JUMP_MSG
    End Asm
End Sub


Sub s_msg_quiet( ps_text As String )
    ' shows a message without ending a command that is being repeated, Moria's printMessageNoCommandInterrupt()
    Dim luw_count As UInteger

    luw_count = guw_game_command_count
    s_msg( ps_text )
    guw_game_command_count = luw_count
End Sub
