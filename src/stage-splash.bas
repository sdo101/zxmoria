#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_splash()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this stage shows the opening screen, and then the credits, a screenful at a time...
' ...the screens are not in here, they are whole screens of text in the paged data, made by create-data.ps1:
' the opening screen from src\splash.txt, and the credits from the AUTHORS file in the Umoria source
' Ctrl-W on any of them starts the game as a wizard, as Moria's -w on its command line does, a nex file has no command
' line: a dead character in the saved game may then be brought back, see the save library, and any other game begins
' in wizard mode, see core.bas

Sub s_splash_show( pub_screen As UByte )
    ' puts one whole screen of text up, each row has its own colour, spaces are not drawn (the screen has just been cleared)
    Dim lub_row , lub_col , lub_char , lub_colour   As UByte
    Dim luw_at                                      As UInteger

    s_core_clear_screen()
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_SCREENS + pub_screen / UB_SCREEN_TEXT_PER_PAGE )
    luw_at = A_MMU_SLOT_PAGED_DB_MAPS + Cast( UInteger , pub_screen Mod UB_SCREEN_TEXT_PER_PAGE ) * UW_SCREEN_TEXT_SIZE
    For lub_row = 0 To UB_SCREEN_ROWS - 1
        lub_colour = Peek( luw_at )
        luw_at     = luw_at + 1
        For lub_col = 0 To UB_SCREEN_COLS - 1
            lub_char = Peek( luw_at )
            If lub_char <> UC_SPACE Then s_core_print_char_at( lub_row , lub_col , lub_char , lub_colour )
            luw_at = luw_at + 1
        Next
    Next
End Sub


Function fub_splash_is_blank( pub_screen As UByte ) As UByte
    ' true if a screen has nothing on it at all, i.e. every one of its characters is a space (a row's colour does not count)
    Dim lub_row , lub_col   As UByte
    Dim luw_at              As UInteger

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_SCREENS + pub_screen / UB_SCREEN_TEXT_PER_PAGE )
    luw_at = A_MMU_SLOT_PAGED_DB_MAPS + Cast( UInteger , pub_screen Mod UB_SCREEN_TEXT_PER_PAGE ) * UW_SCREEN_TEXT_SIZE
    For lub_row = 0 To UB_SCREEN_ROWS - 1
        luw_at = luw_at + 1                 ' step over the row's colour
        For lub_col = 0 To UB_SCREEN_COLS - 1
            If Peek( luw_at ) <> 32 And Peek( luw_at ) <> 0 Then Return false
            luw_at = luw_at + 1
        Next
    Next
    Return true
End Function


Sub s_stage_splash()
    Dim lub_screen , lub_count As UByte

    ' how many screens there are is the last byte of the second page of them
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_SCREENS + 1 )
    lub_count = Peek( A_MMU_SLOT_PAGED_DB_MAPS + UW_SCREEN_TEXT_COUNT_AT )

    ' not a wizard, unless Ctrl-W is pressed below, N.B: each time, a character that dies comes back here
    gub_core_to_be_wizard = false

    ' the opening screen first, then the credits, any key moves on, Q skips whatever is left
    ' N.B: a screen with nothing on it is passed over without waiting for a key, and a count of more screens than there is
    ' room for (which would mean the screens did not come in with the NEX) is not believed
    If lub_count > 6 Then lub_count = 0
    lub_screen = 0
    While lub_screen < lub_count
        If fub_splash_is_blank( lub_screen ) = false Then
            s_splash_show( lub_screen )
            s_core_get_key()
            If gub_key_char = Code( "q" ) Or gub_key_char = Code( "Q" ) Or gub_key_char = UC_ESCAPE Then Exit While      ' Q, or escape (break)
            ' Ctrl-W, Moria's -w: the game is started as a wizard, straight away
            If gub_key_char = 23 And ( gub_key_modifiers bAnd MB_KEY_CTRL ) <> 0 Then
                gub_core_to_be_wizard = true
                Exit While
            End If
            If guw_key_code = 0 Then Exit While     ' nobody pressed anything for an hour
        End If
        lub_screen = lub_screen + 1
    End While
End Sub