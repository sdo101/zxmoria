#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_text()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: the pages of text the player can ask for, the text itself is here too...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_TEXT , UB_LIB_TEXT_SHOW ),
' gub_lib_param_1 is 1 for the help, Moria's help.txt, with the commands that are not in yet taken out of the table
' and listed underneath, 2 for the versions and credits, Moria's versions.txt, or 3 for the words of welcome that ? gives
' while a character is being made, Moria's welcome.txt, as it stands, 4 for the wizard's commands, Moria's
' help_wizard.txt, 6 for the commands with the rogue like keys, Moria's rl_help.txt, or 7 for the wizard's with them,
' rl_help_wizard.txt, both of which are not in this page but in a data page of their own, UB_PAGE_HELP_TEXT, this is
' Moria's displayTextHelpFile(), N.B: there is no 5, it was the licence, Moria's Ctrl-V, which the game no longer shows
' ...and UB_LIB_TEXT_MESSAGES shows the last message again, or with gub_lib_param_1 true all 22 that are remembered,
' Moria's commandPreviousMessage(), the core keeps them, see s_core_print_char_at_logged() in core.bas


' --- its working storage is in globals.bas, under "private to stage-lib-text.bas", moved there on 22 October 2026 ---

'##################################################################################################################################
' --- the screen ---

Sub s_in_screen_save()
    ' puts the screen aside, in the corridor scratchpad page, Moria's terminalSaveScreen()
    gub_tx_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , UW_SCREEN_CELLS_SIZE )
End Sub


Sub s_in_screen_restore()
    ' Moria's terminalRestoreScreen()
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , UW_SCREEN_CELLS_SIZE )
    If gub_tx_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_tx_saved_page )
End Sub


'##################################################################################################################################
' --- pages of text ---

Function fuw_in_text( pub_which As UByte ) As UInteger
    ' where a text is: lines that each end in a 13, and a 0 after the last
    If pub_which = UB_TEXT_HELP Then Return @in_help
    If pub_which = UB_TEXT_WELCOME Then Return @in_welcome
    If pub_which = UB_TEXT_WIZARD Then Return @in_wizard
    Return @in_versions
in_help:
    Asm
        defm "Command Summary (~ is direction, ESC aborts, CTRL is the EXTEND key)"
        defb 13
        defm "  a        Aim and fire a wand         |   B ~      Bash item or monster"
        defb 13
        defm "  b        Browse a book               |   C        Character description"
        defb 13
        defm "  c ~      Close a door                |   D ~      Disarm a trap"
        defb 13
        defm "  d        Drop an item                |   E        Eat some food"
        defb 13
        defm "  e        Equipment list              |   F        Fill lamp with oil"
        defb 13
        defm "  f        Fire/Throw an item          |   G        Gain new magic spells"
        defb 13
        defm "  i        Inventory list              |   L        Locate with map"
        defb 13
        defm "  j ~      Jam a door with spike       |   M        Map (shown reduced size)"
        defb 13
        defm "  m        Magic spell casting         |   R        Rest (count or *=restore)"
        defb 13
        defm "  o ~      Open a door                 |   S        Search mode"
        defb 13
        defm "  p        Pray                        |   T ~      Tunnel in a direction"
        defb 13
        defm "  q        Quaff a potion              |   ?        View this page"
        defb 13
        defm "  r        Read a scroll               |   -        Move without pickup"
        defb 13
        defm "  s        Search for traps or doors   |   . ~      Run in direction"
        defb 13
        defm "  t        Take off an item            |   Q        Quit the game"
        defb 13
        defm "  u        Use a staff                 |   CTRL-R   Redraw the screen"
        defb 13
        defm "  v        Version info and credits    |   ~        For movement"
        defb 13
        defm "  w        Wear/Wield an item          |   <        Go up an up-staircase"
        defb 13
        defm "  x        Exchange weapon             |   >        Go down a down-staircase"
        defb 13
        defm "Directions:     7  8  9"
        defb 13
        defm "                4  5  6  [5 to rest]     (the arrow keys move as well)"
        defb 13
        defm "                1  2  3"
        defb 13
        defb 13
        defm "Some commands will prompt for a spell, or an inventory item. Selection is"
        defb 13
        defm "by an alphabetic character."
        defb 13
        defb 13
        defm "Typing R and then * will make you rest until both your mana and your hp"
        defb 13
        defm "reach their maximum values."
        defb 13
        defb 13
        defm "Also: l ~ looks in a direction, 5 for all round, and / identifies a character."
        defb 13
        defm "{ inscribes something carried, V shows the scores, = sets the options (the"
        defb 13
        defm "rogue like commands and the beep are among them). CTRL-P shows"
        defb 13
        defm "the last message, twice for all. CTRL-X saves the game and leaves it, and it"
        defb 13
        defm "carries on from there when next started. CTRL-W is wizard mode."
        defb 13
        defm "A count: type #, the number, then the command (space first if it is a digit)."
        defb 13
        defm "[ cycles the mini map and ] the colours (as = can too), at a command prompt."
        defb 13
        defm "} cycles the live monitor anywhere, even in a menu or a store: the memory,"
        defb 13
        defm "then MMU 2's misses as well, then off. None of the three takes a turn."
        defb 13
        defb 13
        defm "ZXMoria, a port of Umoria 5.7.15 to the ZX Spectrum Next."
        defb 13
        defm "Copyright (c) 1981-86 Robert A. Koeneke, (c) 1987-94 James E. Wilson,"
        defb 13
        defm "(c) 2026 The ZXMoria authors."
        defb 13
        defm "This is free software, and you are welcome to redistribute it under the terms"
        defb 13
        defm "of the GNU General Public License, version 3 or (at your option) any later"
        defb 13
        defm "version: see the file zxmoria.lic. It comes with ABSOLUTELY NO WARRANTY."
        defb 13
        defb 0
    End Asm
in_welcome:
    Asm
        defm "                       Welcome to Moria!"
        defb 13
        defb 13
        defm "Your first task is to generate a character. You must specify a gender,"
        defb 13
        defm "a race, and a class. Anytime before you have made these specifications,"
        defb 13
        defm "you can interrupt with control-C. You can also specify the race as"
        defb 13
        defm "often as you like by entering '%' to the class request. This will also"
        defb 13
        defm "regenerate your attributes."
        defb 13
        defb 13
        defm "If this is your first time playing, you may want to read the manual first."
        defb 13
        defb 0
    End Asm
in_versions:
    Asm
        defm "                               Umoria 5.7.15"
        defb 13
        defb 13
        defm "Previous major releases:"
        defb 13
        defb 13
        defm "            2016-11-27 : v5.7.0"
        defb 13
        defm "            2008-10-13 : v5.6.0"
        defb 13
        defm "            1994-07-21 : v5.5.2"
        defb 13
        defm "            1992-08-13 : v5.5.0"
        defb 13
        defm "            1991-10-12 : v5.4.0"
        defb 13
        defm "            1991-03-25 : v5.3.0"
        defb 13
        defm "            1990-05-09 : v5.2.0"
        defb 13
        defm "            1989-02-26 : v5.0.0"
        defb 13
        defm "            1988-05-26 : v4.87"
        defb 13
        defm "            1987-10-26 : v4.85"
        defb 13
        defb 13
        defb 13
        defm "Umoria 5.7.x developed and maintained by Michael R. Cook."
        defb 13
        defm "Bug reports and contributions can be made to the Umoria repository:"
        defb 13
        defm "https://github.com/dungeons-of-moria/umoria"
        defb 13
        defb 13
        defb 13
        defm "               Umoria is free software released under GPL-3.0"
        defb 13
        defb 13
        defm "                            VMS Moria Version 4.8"
        defb 13
        defb 13
        defm "      Version 4.0  :  1985-01-20"
        defb 13
        defm "      Version 3.0  :  1984-11-20"
        defb 13
        defm "      Version 2.0  :  1984-07-10"
        defb 13
        defm "      Version 1.0  :  1984-05-01"
        defb 13
        defm "      Version 0.1  :  1983-03-25"
        defb 13
        defb 13
        defm "VMS Moria Modules :"
        defb 13
        defb 13
        defm "      V1.0  Dungeon Generator      - RAK"
        defb 13
        defm "            Character Generator    - RAK & JWT"
        defb 13
        defm "            Moria Module           - RAK"
        defb 13
        defm "            Miscellaneous          - RAK & JWT"
        defb 13
        defm "      V2.0  Town Level & Misc      - RAK"
        defb 13
        defm "      V3.0  Internal Help & Misc   - RAK"
        defb 13
        defm "      V4.0  Source Release Version - RAK"
        defb 13
        defb 13
        defm "    Umoria is free software released under GNU General Public License v3.0"
        defb 13
        defm "                   See LICENSE and AUTHORS for more details"
        defb 13
        defb 13
        defm "               Copyright (c) Robert A. Koeneke, James E. Wilson"
        defb 13
        defb 13
        defm "   ZXMoria, the port to the ZX Spectrum Next: Copyright (c) 2026 The ZXMoria"
        defb 13
        defm "   authors, released under the same licence, version 3 or later. The licence"
        defb 13
        defm "   is the file zxmoria.lic. There is ABSOLUTELY NO WARRANTY."
        defb 13
        defb 0
    End Asm
in_wizard:
    Asm
        defm "Wizard commands (CTRL is the EXTEND key)"
        defb 13
        defb 13
        defm ":  - Map area (panel)"
        defb 13
        defm "^A - Cure all maladies and remove curses"
        defb 13
        defm "^B - Print random objects sample to file"
        defb 13
        defm "^D - Jump to depth # (level)"
        defb 13
        defm "^E - Edit character stats"
        defb 13
        defm "^F - Vanquish monsters within sight"
        defb 13
        defm "^G - Generate random items"
        defb 13
        defm "^H - Wizard Help"
        defb 13
        defm "^I - Identify an item"
        defb 13
        defm "^L - Wizard light"
        defb 13
        defm "^T - Teleport player randomly"
        defb 13
        defm "^U - Summon random monster"
        defb 13
        defm "^W - Wizard mode on/off"
        defb 13
        defm "+  - Gain experience"
        defb 13
        defm "%  - Generate a dungeon item"
        defb 13
        defm "@  - Create an object *CAN CAUSE FATAL ERROR*"
        defb 13
        defm "$  - Superhuman: stats, level, gold, arms, armour and a full pack (not Moria's)"
        defb 13
        defb 13
        defm "A count before ^D, ^G or + is the level, how many, or the experience."
        defb 13
        defb 0
    End Asm
    Return 0
End Function


Sub s_in_text( pub_which As UByte )
    ' Moria's displayTextHelpFile(): the text a screen at a time, escape stops it
    Dim luw_at                      As UInteger
    Dim lub_row , lub_col , lub_char As UByte
    Dim lub_done                    As UByte = false
    Dim lub_page                    As UByte = 0
    Dim lub_saved_page              As UByte

    s_in_screen_save()
    luw_at = fuw_in_text( pub_which )
    lub_saved_page = gub_core_MMU2_page_number
    If pub_which >= UB_TEXT_ROGUE_HELP Then
        ' the two rogue like help texts are not in this page, they are a data page of their own, read through the third
        ' data slot, see create-data.ps1 for where in it each begins
        lub_page = UB_PAGE_HELP_TEXT
        luw_at   = A_MMU_SLOT_PAGED_DB_MAPS
        If pub_which = UB_TEXT_ROGUE_WIZARD Then luw_at = A_MMU_SLOT_PAGED_DB_MAPS + UW_HELP_ROGUE_WIZARD_AT
    End If
    While lub_done = false
        s_core_clear_screen()
        lub_row = 0
        lub_col = 0
        If lub_page <> 0 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_page )
        While lub_row < 23 And Peek( luw_at ) <> 0
            lub_char = Peek( luw_at )
            luw_at   = luw_at + 1

            If lub_char = UC_ENTER Then
                lub_row = lub_row + 1
                lub_col = 0
            Else
                If lub_col < UB_SCREEN_COLS Then s_core_print_char_at( lub_row , lub_col , lub_char , UB_WHITE )
                lub_col = lub_col + 1
            End If
        End While
        s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
        s_core_get_key()
        If gub_key_char = UC_ESCAPE Or guw_key_code = 0 Or Peek( luw_at ) = 0 Then lub_done = true
    End While
    If lub_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page )
    s_in_screen_restore()
End Sub


Sub s_in_message( pub_back As UByte , pub_row As UByte , pub_col As UByte )
    ' one message of the history on a row of the screen, pub_back is how far back it is, 0 for the latest
    Dim lsw_place   As Integer
    Dim luw_at      As UInteger
    Dim i , lub_char As UByte

    lsw_place = Cast( Integer , gub_log_next ) - 1 - pub_back
    If lsw_place < 0 Then lsw_place = lsw_place + UB_MESSAGE_HISTORY
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_MESSAGES )
    luw_at = A_MMU_SLOT_1 + Cast( UInteger , lsw_place ) * UB_MESSAGE_SIZE
    For i = 0 To UB_MESSAGE_SIZE - 1 - pub_col
        lub_char = Peek( luw_at + i )
        If lub_char = 0 Then lub_char = UC_SPACE
        ' N.B: plain white, so that this is not taken for a new message
        s_core_print_char_at( pub_row , pub_col + i , lub_char , UB_WHITE )
    Next
End Sub


Sub s_in_messages( pub_all As UByte )
    ' Moria's commandPreviousMessage(): the last message again, marked with a >, or, asked for twice running,
    ' all that are remembered, the oldest at the top
    Dim lub_count , lub_row , lub_saved As UByte

    If gub_log_count = 0 Then Return
    lub_saved = gub_core_MMU1_page_number
    If pub_all = false Or gub_log_count = 1 Then
        ' distinguish real and recovered messages with a '>'
        s_core_print_char_at( 0 , 0 , Code( ">" ) , UB_WHITE )
        s_in_message( 0 , 0 , 1 )
    Else
        s_in_screen_save()
        lub_count = gub_log_count
        lub_row   = lub_count
        While lub_row > 0
            lub_row = lub_row - 1
            s_in_message( lub_count - 1 - lub_row , lub_row , 0 )
        End While
        s_core_print_string_at( lub_count , 0 , "[ press any key to continue ]                                                   " , UB_WHITE )
        s_core_get_key()
        s_in_screen_restore()
    End If
    If lub_saved <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved )
End Sub


Sub s_lib_text()
    If gub_lib_function = UB_LIB_TEXT_SHOW Then
        s_in_text( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_TEXT_MESSAGES Then
        s_in_messages( gub_lib_param_1 )
    End If
End Sub
