#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_info()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"

' this page is a LIBRARY, not a stage: the commands that only show the player something, and take no time...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_INFO , <which routine> ),
' the routines are:
'
'   UB_LIB_INFO_CHARACTER   the character's sheet, and the chance to give them another name, Moria's
'                           changeCharacterName(), or, if gub_lib_param_1 is true, the sheet of a character
'                           whose game is over, the key pressed to go on is then left in gub_key_char
'   UB_LIB_INFO_LOCATE      the player looks at the other parts of the map, a sector at a time, Moria's
'                           commandLocateOnMap()
'   UB_LIB_INFO_MAP         the whole level on one screen, each square of it standing for nine, Moria's
'                           dungeonDisplayMap()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
#define A_IN_MAP_ROW        A_LIB_PRIVATE               ' 66 bytes, one row of the reduced map while it is worked out
Dim gub_in_saved_page       As UByte    At A_LIB_PRIVATE + 70       ' the page the caller had in the first data slot, while the screen is put aside there


'##################################################################################################################################
' --- the screen ---

Sub s_in_screen_save()
    ' puts the screen aside, in the corridor scratchpad page, Moria's terminalSaveScreen()
    gub_in_saved_page = gub_core_MMU0_page_number
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , 5120 )
End Sub


Sub s_in_screen_restore()
    ' Moria's terminalRestoreScreen()
    s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
    s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , 5120 )
    If gub_in_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_CORRIDORS , gub_in_saved_page )
End Sub


'##################################################################################################################################
' --- the character's sheet ---

Sub s_in_name()
    ' Moria's getCharacterName()
    Dim lub_length As UByte = 0

    s_core_print_string_at( 21 , 0 , "  Enter your player's name  [press <RETURN> when finished]                      " , UB_WHITE )
    s_core_print_string_at( 2 , 15 , "_                      " , UB_WHITE )
    Do
        s_core_get_key()
        If gub_key_char = 13 Then Exit Do
        If gub_key_char = 27 Then           ' escape: give up, and take the default name
            lub_length = 0
            Exit Do
        End If
        If gub_key_char = 8 Then            ' delete
            If lub_length > 0 Then
                s_core_print_char_at( 2 , 15 + lub_length , 32 , UB_WHITE )
                lub_length = lub_length - 1
                s_core_print_char_at( 2 , 15 + lub_length , Code( "_" ) , UB_WHITE )
            End If
        ElseIf gub_key_char >= 32 And gub_key_char < 127 And lub_length < 23 Then
            Poke A_PLAYER_NAME + lub_length , gub_key_char
            s_core_print_char_at( 2 , 15 + lub_length , gub_key_char , UB_BRIGHT_WHITE )
            lub_length = lub_length + 1
            If lub_length < 23 Then s_core_print_char_at( 2 , 15 + lub_length , Code( "_" ) , UB_WHITE )
        End If
    Loop
    If lub_length = 0 Then
        ' the same default as when a character is made
        Poke A_PLAYER_NAME , Code( "X" )
        lub_length = 1
    End If
    Poke A_PLAYER_NAME + lub_length , 0
End Sub


#include "stage-playerfile-include.bas"
#include "stage-textfile-include.bas"


Function fs_in_placement( pub_place As UByte ) As String
    ' Moria's equipmentPlacementDescription(), pub_place is one of the UB_EQUIP_ values
    If pub_place = UB_EQUIP_WIELD Then Return "You are wielding   "
    If pub_place = UB_EQUIP_HEAD Then Return "Worn on head       "
    If pub_place = UB_EQUIP_NECK Then Return "Worn around neck   "
    If pub_place = UB_EQUIP_BODY Then Return "Worn on body       "
    If pub_place = UB_EQUIP_ARM Then Return "Worn on shield arm "
    If pub_place = UB_EQUIP_HANDS Then Return "Worn on hands      "
    If pub_place = UB_EQUIP_RIGHT Then Return "Right ring finger  "
    If pub_place = UB_EQUIP_LEFT Then Return "Left  ring finger  "
    If pub_place = UB_EQUIP_FEET Then Return "Worn on feet       "
    If pub_place = UB_EQUIP_OUTER Then Return "Worn about body    "
    If pub_place = UB_EQUIP_LIGHT Then Return "Light source is    "
    Return "Secondary weapon   "
End Function


Sub s_in_file()
    ' <f>ile character description, Moria's outputPlayerCharacterToFile(): the character sheet, what is worn and
    ' what is carried, written to a file on the SD card, the sheet must be on the screen
    ' N.B: NOT as Moria has it, which asks for the file's name: ours is always player-<name>.txt, after the character,
    ' see stage-playerfile-include.bas, and a file of that name already there is replaced
    ' N.B: the sheet is taken from the screen, where it is already laid out as Moria lays it out in the file, so the
    ' file has everything the screen has: Moria's file also has the character's title, which the screen has not
    Dim lub_row , lub_col , lub_last , i    As UByte
    Dim luw_cell , luw_record               As UInteger
    Dim lub_line                            As UByte
    s_pf_name( A_PROMPT , A_PLAYER_NAME , "player-" , ".txt" )
    s_core_clear_row( 0 , 0 , UB_WHITE )
    s_core_print_string_at( 0 , 0 , "Writing " + fs_core_text_at( A_PROMPT ) + "..." , UB_WHITE )
    s_tf_begin( A_PROMPT )
    s_tf_char( 12 )
    s_tf_write( "" )
    s_tf_write( "" )
    ' the sheet, rows 2 to 18 of the screen, each as far as its last character, 2 bytes to a cell
    For lub_row = 2 To 18
        luw_cell = A_SCREEN_BASE + Cast( UInteger , lub_row ) * 160
        lub_last = 0
        For lub_col = 0 To UB_SCREEN_COLS - 1
            If Peek( luw_cell + 2 * Cast( UInteger , lub_col ) ) <> 32 Then lub_last = lub_col + 1
        Next
        lub_col = 0
        While lub_col < lub_last
            s_tf_char( Peek( A_SCREEN_BASE + Cast( UInteger , lub_row ) * 160 + 2 * Cast( UInteger , lub_col ) ) )
            lub_col = lub_col + 1
        End While
        s_tf_char( 10 )
    Next
    s_tf_write( "" )
    ' write out the character's history
    s_tf_write( "Character Background" )
    For i = 0 To 3
        s_tf_char( 32 )
        lub_col = 0
        While lub_col < 60 And Peek( A_PLAYER_HISTORY + Cast( UInteger , i ) * 60 + lub_col ) <> 0
            s_tf_char( Peek( A_PLAYER_HISTORY + Cast( UInteger , i ) * 60 + lub_col ) )
            lub_col = lub_col + 1
        End While
        s_tf_char( 10 )
    Next

    ' Moria's writeEquipmentListToFile()
    s_tf_write( "" )
    s_tf_write( "  [Character's Equipment List]" )
    s_tf_write( "" )
    If gsw_player_equipment_count = 0 Then
        s_tf_write( "  Character has no equipment in use." )
    Else
        lub_line = 0
        For i = UB_PACK_SIZE To UB_INVENTORY_SIZE - 1
            luw_record = A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE
            If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
                s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
                gub_lib_param_1 = true
                s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
                s_tf_write( "  " + fs_core_char( 97 + lub_line ) + ") " + fs_in_placement( i - UB_PACK_SIZE ) + ": " + fs_core_text_at( A_TEXT_BUFFER ) )
                lub_line = lub_line + 1
            End If
        Next
        s_tf_char( 12 )
        s_tf_write( "" )
        s_tf_write( "" )
    End If

    ' Moria's writeInventoryToFile()
    s_tf_write( "  [General Inventory List]" )
    s_tf_write( "" )
    If gsw_player_pack_unique = 0 Then
        s_tf_write( "  Character has no objects in inventory." )
    Else
        For i = 0 To gsw_player_pack_unique - 1
            s_core_ram_copy( A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE , A_ITEM , UB_RECORD_SIZE )
            gub_lib_param_1 = true
            s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
            s_tf_write( fs_core_char( 97 + i ) + ") " + fs_core_text_at( A_TEXT_BUFFER ) )
        Next
        s_tf_char( 12 )
    End If

    s_core_clear_row( 0 , 0 , UB_WHITE )
    If fub_tf_end() Then
        s_pf_name( A_PROMPT , A_PLAYER_NAME , "player-" , ".txt" )
        s_core_print_string_at( 0 , 0 , "Written to " + fs_core_text_at( A_PROMPT ) + "." , UB_WHITE )
    Else
        s_core_print_string_at( 0 , 0 , "The file could not be written." , UB_WHITE )
    End If
    Poke A_PROMPT , 0
End Sub


Sub s_in_sheet()
    ' the character sheet, Moria's printCharacter(), on a screen of its own
    s_core_clear_screen()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_INFO )
    ' the library prints the headings, who the character is goes beside them
    s_core_print_string_at( 2 , 15 , fs_core_text_at( A_PLAYER_NAME ) , UB_BRIGHT_WHITE )
    s_core_print_string_at( 3 , 15 , fs_core_text_at( A_RACE ) , UB_BRIGHT_WHITE )
    If gub_player_male Then
        s_core_print_string_at( 4 , 15 , "Male" , UB_BRIGHT_WHITE )
    Else
        s_core_print_string_at( 4 , 15 , "Female" , UB_BRIGHT_WHITE )
    End If
    s_core_print_string_at( 5 , 15 , fs_core_text_at( A_CLASS ) , UB_BRIGHT_WHITE )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_VITALS )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_STATS )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_LEVEL )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_ABILITIES )
End Sub


Sub s_in_character( pub_dead As UByte )
    ' Moria's changeCharacterName(), with its printCharacter(), and, with pub_dead, the sheet of a character whose
    ' game is over, which is only to be looked at
    Dim lub_done As UByte = false

    s_in_screen_save()
    s_in_sheet()
    If pub_dead Then
        s_core_print_string_at( 23 , 0 , "Type ESC to skip the inventory:" , UB_WHITE )
        s_core_get_key()
        lub_done = true
    End If
    While lub_done = false
        s_core_print_string_at( 21 , 0 , "  <f>ile character description. <c>hange character name.                        " , UB_WHITE )
        s_core_get_key()
        If gub_key_char = Code( "f" ) Then
            s_in_file()
        ElseIf gub_key_char = Code( "c" ) Then
            s_in_name()
            lub_done = true
        ElseIf gub_key_char = 27 Or gub_key_char = 32 Or gub_key_char = 13 Or guw_key_code = 0 Then
            lub_done = true
        End If
    End While
    s_in_screen_restore()
End Sub





'##################################################################################################################################
' --- the reduced map ---

Function fsb_in_priority( pub_symbol As UByte ) As Byte
    ' which of the nine squares that share a place on the reduced map is shown there: the one that matters most
    If pub_symbol = Code( "@" ) Then Return 10
    If pub_symbol = Code( "<" ) Or pub_symbol = Code( ">" ) Then Return 5
    If pub_symbol = 92 Then Return -3           ' a backslash
    If pub_symbol = Code( "#" ) Then Return -5
    If pub_symbol = Code( "." ) Then Return -10
    If pub_symbol = 32 Then Return -15
    Return 0
End Function


Sub s_in_map_row( psw_line As Integer , pub_width As UByte )
    ' one finished row of the reduced map goes on the screen
    Dim i , lub_symbol As UByte

    If psw_line < 0 Then Return
    For i = 0 To pub_width - 1
        lub_symbol = Peek( A_IN_MAP_ROW + i )
        If lub_symbol = Code( "@" ) Then
            s_core_print_char_at( psw_line + 1 , i + 1 , lub_symbol , UB_BRIGHT_WHITE )
        ElseIf lub_symbol <> 32 Then
            s_core_print_char_at( psw_line + 1 , i + 1 , lub_symbol , UB_WHITE )
        End If
    Next
End Sub


Sub s_in_map()
    ' Moria's dungeonDisplayMap(): shrinks the dungeon to a single screen
    ' N.B: as in Moria the frame is always that of a full size level, the town sits in its top left corner
    Dim lub_width , lub_height , lub_symbol , lub_col   As UByte
    Dim y , x , i                                       As UByte
    Dim lsw_line                                        As Integer

    s_in_screen_save()
    s_core_clear_screen()
    lub_width  = UW_MAP_COLS / 3
    lub_height = UW_MAP_ROWS / 3

    ' add screen border
    For i = 0 To lub_width - 1
        s_core_print_char_at( 0 , i + 1 , Code( "-" ) , UB_WHITE )
        s_core_print_char_at( lub_height + 1 , i + 1 , Code( "-" ) , UB_WHITE )
    Next
    For i = 0 To lub_height - 1
        s_core_print_char_at( i + 1 , 0 , Code( "|" ) , UB_WHITE )
        s_core_print_char_at( i + 1 , lub_width + 1 , Code( "|" ) , UB_WHITE )
    Next
    s_core_print_char_at( 0 , 0 , Code( "+" ) , UB_WHITE )
    s_core_print_char_at( 0 , lub_width + 1 , Code( "+" ) , UB_WHITE )
    s_core_print_char_at( lub_height + 1 , 0 , Code( "+" ) , UB_WHITE )
    s_core_print_char_at( lub_height + 1 , lub_width + 1 , Code( "+" ) , UB_WHITE )
    s_core_print_string_at( 23 , 23 , "Hit any key to continue" , UB_BRIGHT_WHITE )

    ' shrink the dungeon!
    lsw_line = -1
    If gub_dungeon_rows > 0 Then
        For y = 0 To gub_dungeon_rows - 1
            If Cast( Integer , y / 3 ) <> lsw_line Then
                s_in_map_row( lsw_line , lub_width )
                For i = 0 To lub_width - 1
                    Poke A_IN_MAP_ROW + i , 32
                Next
                lsw_line = y / 3
            End If
            For x = 0 To gub_dungeon_cols - 1
                lub_col    = x / 3
                lub_symbol = fub_cr_symbol( y , x )
                If fsb_in_priority( Peek( A_IN_MAP_ROW + lub_col ) ) < fsb_in_priority( lub_symbol ) Then Poke A_IN_MAP_ROW + lub_col , lub_symbol
            Next
        Next
    End If
    s_in_map_row( lsw_line , lub_width )

    ' wait for any keypress
    s_core_get_key()
    s_in_screen_restore()
End Sub


'##################################################################################################################################
' --- looking at the other sectors of the map ---

Sub s_in_locate()
    ' Moria's commandLocateOnMap()
    Dim lsw_y , lsw_x               As Integer
    Dim lsb_old_row , lsb_old_col   As Byte
    Dim lub_direction , lub_done    As UByte
    Dim lub_flags , lub_moved       As UByte
    Dim ls_where                    As String

    lub_flags = Peek( fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If gsw_player_blind > 0 Or ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then
        s_core_message( UW_MSG_YOU_CANT_SEE_YOUR_MAP )
        Return
    End If

    lsw_y = gub_player_row
    lsw_x = gub_player_col
    If fub_cr_outside_panel( lsw_y , lsw_x , true ) Then s_cr_draw_panel()
    lsb_old_row = gsb_panel_row
    lsb_old_col = gsb_panel_col

    lub_done = false
    While lub_done = false
        ls_where = ""
        If gsb_panel_row <> lsb_old_row Or gsb_panel_col <> lsb_old_col Then
            If gsb_panel_row < lsb_old_row Then ls_where = " North"
            If gsb_panel_row > lsb_old_row Then ls_where = " South"
            If gsb_panel_col < lsb_old_col Then ls_where = ls_where + " West"
            If gsb_panel_col > lsb_old_col Then ls_where = ls_where + " East"
            ls_where = ls_where + " of"
        End If
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "Map sector [" + fs_core_number( gsb_panel_row ) + "," + fs_core_number( gsb_panel_col ) + "], which is" + ls_where + " your sector. Look which direction?" , UB_BRIGHT_WHITE )

        ' Moria's getDirectionWithMemory()
        lub_direction = 0
        Do
            s_core_get_key()
            s_core_direction_key()
            If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) And gub_key_char <> Code( "5" ) Then lub_direction = gub_key_char - Code( "0" )
            If guw_key_code = UW_KEY_UP Then lub_direction = 8
            If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
            If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
            If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
        Loop Until lub_direction <> 0 Or gub_key_char = 27 Or guw_key_code = 0
        s_msg_clear()

        If lub_direction = 0 Then
            lub_done = true
        Else
            ' should really use the move function, but what the hell, this is nicer, as it moves exactly to the
            ' same place in another section
            lub_moved = false
            While lub_moved = false
                lsw_x = lsw_x + ( Cast( Integer , ( lub_direction - 1 ) Mod 3 ) - 1 ) * 40
                lsw_y = lsw_y - ( Cast( Integer , ( lub_direction - 1 ) / 3 ) - 1 ) * 12
                ' N.B: as in Moria it is the width of the level that both of these are held against
                If lsw_x < 0 Or lsw_y < 0 Or lsw_x >= Cast( Integer , gub_dungeon_cols ) Or lsw_y >= Cast( Integer , gub_dungeon_cols ) Then
                    s_core_message( UW_MSG_YOUVE_GONE_PAST_THE_END_OF_YOUR )
                    lsw_x = lsw_x - ( Cast( Integer , ( lub_direction - 1 ) Mod 3 ) - 1 ) * 40
                    lsw_y = lsw_y + ( Cast( Integer , ( lub_direction - 1 ) / 3 ) - 1 ) * 12
                    lub_moved = true
                ElseIf fub_cr_outside_panel( lsw_y , lsw_x , true ) Then
                    s_cr_draw_panel()
                    lub_moved = true
                End If
            End While
        End If
    End While

    ' move to a new panel - but only if really necessary
    If fub_cr_outside_panel( gub_player_row , gub_player_col , false ) Then s_cr_draw_panel()
End Sub


Sub s_lib_info()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2  As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_INFO_FILE Then
        ' the sheet of a character whose game is over, written to the file whose name is in A_PROMPT
        s_in_sheet()
        s_in_file()
    ElseIf gub_lib_function = UB_LIB_INFO_CHARACTER Then
        s_in_character( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_INFO_LOCATE Then
        s_in_locate()
    ElseIf gub_lib_function = UB_LIB_INFO_MAP Then
        s_in_map()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
