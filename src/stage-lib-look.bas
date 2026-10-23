#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_look()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"

' this page is a LIBRARY, not a stage: looking about, and asking what a character on the map stands for, neither
' takes any time...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_LOOK , <which routine> ),
' the routines are:
'
'   UB_LIB_LOOK_LOOK        asks for a direction, 5 for all round, and then tells of every monster and thing that
'                           can be seen within a cone of vision that way, one at a time, a monster's memory can be
'                           asked for with r, and ESCAPE stops the look, Moria's look() (dungeon_los.cpp)
'   UB_LIB_LOOK_IDENTIFY    asks for a character and says what it stands for, then offers what is remembered of
'                           each kind of creature drawn with it, Moria's identifyGameObject()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - Moria puts the cursor on the thing being told of, we have no cursor


' --- its working storage is in globals.bas, under "private to stage-lib-look.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- looking ---

Sub s_lk_ask( ps_text As String )
    ' something on the top row, and a key
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , ps_text , UB_BRIGHT_WHITE )
    s_core_get_key()
End Sub


Function fub_lk_see( psw_y As Integer , psw_x As Integer ) As UByte
    ' Moria's lookSee(): one square of the cone, true if the player has had enough
    Dim lsw_row , lsw_col                               As Integer
    Dim luw_square , luw_creature                       As UInteger
    Dim lub_feature , lub_flags , lub_item , lub_monster As UByte
    Dim lub_category , lub_first                        As UByte
    Dim lub_shown                                       As UByte = false
    Dim lub_key                                         As UByte = 27
    Dim ls_description , ls_wall , ls_name              As String

    ls_description = "You see"
    If psw_x = 0 And psw_y = 0 Then ls_description = "You are on"

    lsw_col = Cast( Integer , gub_player_col ) + gsb_lk_fxx * psw_x + gsb_lk_fxy * psw_y
    lsw_row = Cast( Integer , gub_player_row ) + gsb_lk_fyx * psw_x + gsb_lk_fyy * psw_y
    gub_lk_transparent = false
    If lsw_row < 0 Or lsw_col < 0 Or lsw_row > 255 Or lsw_col > 255 Then Return false
    If fub_cr_inside_panel( lsw_row , lsw_col ) = false Then Return false
    If lsw_row >= Cast( Integer , gub_dungeon_rows ) Or lsw_col >= Cast( Integer , gub_dungeon_cols ) Then Return false

    luw_square  = fuw_cr_square( lsw_row , lsw_col )
    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )
    lub_flags   = Peek( luw_square + UB_SQUARE_FLAGS )
    lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
    lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
    If lub_feature <= UB_TILE_MAX_OPEN Then gub_lk_transparent = true

    ' don't look at a direct line of sight, a hack
    If gub_lk_no_query Then Return false

    If lub_monster > 1 And gub_lk_rocks = 0 Then
        luw_square = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
        If Peek( luw_square + UB_MONSTER_LIT_OFFSET ) Then
            luw_creature = Peek( UInteger , luw_square + UB_MONSTER_CREATURE_OFFSET )
            ls_name      = fs_core_text_at( fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature ) )
            lub_first    = Code( ls_name( 0 ) ) bOr 32
            If lub_first = Code( "a" ) Or lub_first = Code( "e" ) Or lub_first = Code( "i" ) Or lub_first = Code( "o" ) Or lub_first = Code( "u" ) Then
                ls_name = "an " + ls_name
            Else
                ls_name = "a " + ls_name
            End If
            s_lk_ask( ls_description + " " + ls_name + ". [(r)ecall]" )
            ls_description = "It is on"
            lub_shown = true
            lub_key   = gub_key_char
            If lub_key = Code( "r" ) Or lub_key = Code( "R" ) Then
                ' the recall library shows what is remembered, and puts the screen back
                guw_lib_param_2 = luw_creature
                s_core_call_library( UB_PAGED_CODE_LIB_RECALL , UB_LIB_RECALL_SHOW )
                lub_key = gsw_lib_result
            End If
        End If
    End If

    If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) <> 0 Then
        ls_wall = ""
        lub_category = 0
        If lub_item <> 0 Then lub_category = fub_cr_item_category( lub_item )
        If lub_category = UB_TV_SECRET_DOOR Then
            ' it looks like the wall it is hidden in, and granite is only interesting if it contains something
            If lub_shown Then ls_wall = "a granite wall"
        Else
            If lub_item <> 0 And lub_category <> UB_TV_INVIS_TRAP And gub_lk_rocks = 0 Then
                ' what the thing is, the items library says
                s_core_fetch_record( UB_SLOT_ITEMS , gub_level_items_page , lub_item , A_ITEM )
                gub_lib_param_1 = true
                guw_lib_param_2 = 0
                s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
                s_lk_ask( ls_description + " " + fs_core_text_at( A_TEXT_BUFFER ) + " ---pause---" )
                ls_description = "It is in"
                lub_shown = true
                lub_key   = gub_key_char
            End If
            If ( gub_lk_rocks <> 0 Or lub_shown ) And lub_feature >= UB_TILE_MIN_CLOSED Then
                ' granite is only interesting if it contains something
                If lub_shown And ( lub_feature = UB_TILE_BOUNDARY_WALL Or lub_feature = UB_TILE_GRANITE_WALL ) Then ls_wall = "a granite wall"
                If lub_feature = UB_TILE_MAGMA_WALL Then ls_wall = "some dark rock"
                If lub_feature = UB_TILE_QUARTZ_WALL Then ls_wall = "a quartz vein"
            End If
        End If
        If Len( ls_wall ) > 0 Then
            s_lk_ask( ls_description + " " + ls_wall + " ---pause---" )
            lub_key   = gub_key_char
            lub_shown = true
        End If
    End If

    If lub_shown Then
        gub_lk_seen = gub_lk_seen + 1
        If lub_key = UC_ESCAPE Then Return true
    End If
    Return false
End Function


Function fub_lk_ray( psw_y As Integer , psw_from As Integer , psw_to As Integer ) As UByte
    ' Moria's lookRay(): look at everything within a cone of vision between two ray lines emanating from the
    ' player, and psw_y or more places away from the direct line of view, this is recursive
    ' rays are specified by gradients, y over x, multiplied by 2 * SW_GRADF, this is ONLY called with gradients
    ' between 2 * SW_GRADF (45 degrees) and 1 (almost horizontal)
    Dim lsw_x , lsw_max_x   As Integer
    Dim lub_into_window     As UByte

    ' from is the larger angle of the ray, since we scan towards the center line, if from is smaller, then the
    ' ray does not exist
    If psw_from <= psw_to Or psw_y > UB_MON_MAX_SIGHT Then Return false

    ' find first visible location along this line
    lsw_x = Cast( Long , SW_GRADF ) * ( 2 * psw_y - 1 ) / psw_from + 1
    If lsw_x <= 0 Then lsw_x = 1
    ' find last visible location along this line
    lsw_max_x = ( Cast( Long , SW_GRADF ) * ( 2 * psw_y + 1 ) - 1 ) / psw_to
    If lsw_max_x > UB_MON_MAX_SIGHT Then lsw_max_x = UB_MON_MAX_SIGHT
    If lsw_max_x < lsw_x Then Return false

    ' if "to" is greater than 1, we do not really look at stuff along the direct line of sight, but we do have
    ' to see what is opaque for the purposes of obscuring other objects
    gub_lk_no_query = false
    If psw_y = 0 And psw_to > 1 Then gub_lk_no_query = true
    If psw_y = lsw_x And psw_from < SW_GRADF * 2 Then gub_lk_no_query = true

    If fub_lk_see( psw_y , lsw_x ) Then Return true
    If psw_y = lsw_x Then gub_lk_no_query = false

    ' N.B: where Moria jumps into the middle of its loop, lub_into_window says to start there
    lub_into_window = gub_lk_transparent
    Do
        If lub_into_window = false Then
            ' look down the window we've found
            If fub_lk_ray( psw_y + 1 , psw_from , ( 2 * psw_y + 1 ) * Cast( Long , SW_GRADF ) / lsw_x ) Then Return true
            ' find the start of next window
            Do
                If lsw_x = lsw_max_x Then Return false
                ' see if this seals off the scan (if y is zero, then it will)
                psw_from = ( 2 * psw_y - 1 ) * Cast( Long , SW_GRADF ) / lsw_x
                If psw_from <= psw_to Then Return false
                lsw_x = lsw_x + 1
                If fub_lk_see( psw_y , lsw_x ) Then Return true
            Loop Until gub_lk_transparent
        End If
        lub_into_window = false
        ' find the end of this window of visibility
        Do
            ' the window is trimmed by an earlier limit
            If lsw_x = lsw_max_x Then Return fub_lk_ray( psw_y + 1 , psw_from , psw_to )
            lsw_x = lsw_x + 1
            If fub_lk_see( psw_y , lsw_x ) Then Return true
        Loop While gub_lk_transparent
    Loop
    ' never reached, it is here because the compiler wants a function to end with a Return
    Return false
End Function


Sub s_lk_set( pub_index As UByte , pub_flip As UByte )
    ' one of the four ways the cone can face, Moria's los_dir_set_ tables, pub_flip turns it over
    gsb_lk_fxy = Peek( Byte , @lk_fxy + pub_index )
    gsb_lk_fxx = Peek( Byte , @lk_fxx + pub_index )
    gsb_lk_fyy = Peek( Byte , @lk_fyy + pub_index )
    gsb_lk_fyx = Peek( Byte , @lk_fyx + pub_index )
    If pub_flip Then
        gsb_lk_fxy = -gsb_lk_fxy
        gsb_lk_fyy = -gsb_lk_fyy
    End If
    Return
lk_fxy:
    Asm
        defb 0, 1, 0, 0, -1
    End Asm
lk_fxx:
    Asm
        defb 0, 0, -1, 1, 0
    End Asm
lk_fyy:
    Asm
        defb 0, 0, 1, -1, 0
    End Asm
lk_fyx:
    Asm
        defb 0, 1, 0, 0, -1
    End Asm
End Sub


Function fub_lk_diagonal( pub_which As UByte , pub_index As UByte ) As UByte
    ' Moria's los_map_diagonals1 and los_map_diagonals2
    If pub_which = 1 Then Return Peek( @lk_diagonals_1 + pub_index )
    Return Peek( @lk_diagonals_2 + pub_index )
lk_diagonals_1:
    Asm
        defb 1, 3, 0, 2, 4
    End Asm
lk_diagonals_2:
    Asm
        defb 2, 1, 0, 4, 3
    End Asm
    Return 0
End Function


Sub s_lk_look()
    ' Moria's look()
    Dim lub_direction , i   As UByte
    Dim lub_abort           As UByte = false

    If gsw_player_blind > 0 Then
        s_core_message( UW_MSG_YOU_CANT_SEE_A_DAMN_THING )
        Return
    End If
    If gsw_player_image > 0 Then
        s_core_message( UW_MSG_YOU_CANT_BELIEVE_WHAT_YOU_ARE )
        Return
    End If

    ' Moria's getAllDirections(), 5 is all round
    lub_direction = 0
    s_msg_flush()
    s_msg_clear()
    s_core_print_string_at( 0 , 0 , "Look which direction?" , UB_BRIGHT_WHITE )
    Do
        s_core_get_key()
        s_core_direction_key()
        If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) Then lub_direction = gub_key_char - Code( "0" )
        If guw_key_code = UW_KEY_UP Then lub_direction = 8
        If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
        If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
        If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
    Loop Until lub_direction <> 0 Or gub_key_char = UC_ESCAPE Or guw_key_code = 0
    s_msg_clear()
    If lub_direction = 0 Then Return

    gub_lk_seen     = 0
    gub_lk_rocks    = 0
    ' have to set this up for the first look, at the player's own square
    gub_lk_no_query = false
    If fub_lk_see( 0 , 0 ) Then
        s_msg_clear()
        Return
    End If

    ' looks first at real objects and monsters, and at the kinds of rock only after all other things have been
    ' seen, and only if the player has asked for the mineral seams to be noticed
    Do
        lub_abort = false
        If lub_direction = 5 Then
            i = 1
            While i <= 4 And lub_abort = false
                s_lk_set( i , false )
                If fub_lk_ray( 0 , 2 * SW_GRADF - 1 , 1 ) Then
                    lub_abort = true
                Else
                    s_lk_set( i , true )
                    If fub_lk_ray( 0 , 2 * SW_GRADF , 2 ) Then lub_abort = true
                End If
                i = i + 1
            End While
        ElseIf ( lub_direction bAnd 1 ) = 0 Then
            ' straight directions
            i = lub_direction >> 1
            s_lk_set( i , false )
            If fub_lk_ray( 0 , SW_GRADF , 1 ) Then
                lub_abort = true
            Else
                s_lk_set( i , true )
                lub_abort = fub_lk_ray( 0 , SW_GRADF , 2 )
            End If
        Else
            s_lk_set( fub_lk_diagonal( 1 , lub_direction >> 1 ) , true )
            If fub_lk_ray( 1 , 2 * SW_GRADF , SW_GRADF ) Then
                lub_abort = true
            Else
                s_lk_set( fub_lk_diagonal( 2 , lub_direction >> 1 ) , false )
                lub_abort = fub_lk_ray( 1 , 2 * SW_GRADF - 1 , SW_GRADF )
            End If
        End If
        gub_lk_rocks = gub_lk_rocks + 1
    Loop While lub_abort = false And ( guw_game_options bAnd MW_OPTION_SEAMS ) <> 0 And gub_lk_rocks < 2

    s_msg_clear()
    If lub_abort Then
        s_core_message( UW_MSG_ABORTING_LOOK )
    ElseIf gub_lk_seen <> 0 Then
        If lub_direction = 5 Then
            s_core_message( UW_MSG_THATS_ALL_YOU_SEE )
        Else
            s_core_message( UW_MSG_THATS_ALL_YOU_SEE_IN_THAT )
        End If
    ElseIf lub_direction = 5 Then
        s_core_message( UW_MSG_YOU_SEE_NOTHING_OF_INTEREST )
    Else
        s_core_message( UW_MSG_YOU_SEE_NOTHING_OF_INTEREST_IN )
    End If
End Sub


'##################################################################################################################################
' --- what a character stands for ---

Function fuw_lk_symbols() As UInteger
    ' Moria's objectDescription(): what each character from space to ~ stands for, in order, each ends in a 0,
    ' the ones Moria does not use have nothing but the 0
    Return @lk_symbols
lk_symbols:
    Asm
        defb 32
        defm " - An open pit."
        defb 0
        defb 33
        defm " - A potion."
        defb 0
        defb 34
        defm " - An amulet, periapt, or necklace."
        defb 0
        defb 35
        defm " - A stone wall."
        defb 0
        defb 36
        defm " - Treasure."
        defb 0
        defb 37
        defm " - Not used."
        defb 0
        defb 38
        defm " - Treasure chest."
        defb 0
        defb 39
        defm " - An open door."
        defb 0
        defb 40
        defm " - Soft armor."
        defb 0
        defb 41
        defm " - A shield."
        defb 0
        defb 42
        defm " - Gems."
        defb 0
        defb 43
        defm " - A closed door."
        defb 0
        defb 44
        defm " - Food or mushroom patch."
        defb 0
        defb 45
        defm " - A wand"
        defb 0
        defb 46
        defm " - Floor."
        defb 0
        defb 47
        defm " - A pole weapon."
        defb 0
        defb 0
        defb 49
        defm " - Entrance to General Store."
        defb 0
        defb 50
        defm " - Entrance to Armory."
        defb 0
        defb 51
        defm " - Entrance to Weaponsmith."
        defb 0
        defb 52
        defm " - Entrance to Temple."
        defb 0
        defb 53
        defm " - Entrance to Alchemy shop."
        defb 0
        defb 54
        defm " - Entrance to Magic-Users store."
        defb 0
        defb 0
        defb 0
        defb 0
        defb 58
        defm " - Rubble."
        defb 0
        defb 59
        defm " - A loose rock."
        defb 0
        defb 60
        defm " - An up staircase."
        defb 0
        defb 61
        defm " - A ring."
        defb 0
        defb 62
        defm " - A down staircase."
        defb 0
        defb 63
        defm " - A scroll."
        defb 0
        defb 64
        defm " - Giant Ant Lion."
        defb 0
        defb 65
        defm " - Giant Ant Lion."
        defb 0
        defb 66
        defm " - The Balrog."
        defb 0
        defb 67
        defm " - Gelatinous Cube."
        defb 0
        defb 68
        defm " - An Ancient Dragon (Beware)."
        defb 0
        defb 69
        defm " - Elemental."
        defb 0
        defb 70
        defm " - Giant Fly."
        defb 0
        defb 71
        defm " - Ghost."
        defb 0
        defb 72
        defm " - Hobgoblin."
        defb 0
        defb 0
        defb 74
        defm " - Jelly."
        defb 0
        defb 75
        defm " - Killer Beetle."
        defb 0
        defb 76
        defm " - Lich."
        defb 0
        defb 77
        defm " - Mummy."
        defb 0
        defb 0
        defb 79
        defm " - Ooze."
        defb 0
        defb 80
        defm " - Giant humanoid."
        defb 0
        defb 81
        defm " - Quylthulg (Pulsing Flesh Mound)."
        defb 0
        defb 82
        defm " - Reptile."
        defb 0
        defb 83
        defm " - Giant Scorpion."
        defb 0
        defb 84
        defm " - Troll."
        defb 0
        defb 85
        defm " - Umber Hulk."
        defb 0
        defb 86
        defm " - Vampire."
        defb 0
        defb 87
        defm " - Wight or Wraith."
        defb 0
        defb 88
        defm " - Xorn."
        defb 0
        defb 89
        defm " - Yeti."
        defb 0
        defb 0
        defb 91
        defm " - Hard armor."
        defb 0
        defb 92
        defm " - A hafted weapon."
        defb 0
        defb 93
        defm " - Misc. armor."
        defb 0
        defb 94
        defm " - A trap."
        defb 0
        defb 95
        defm " - A staff."
        defb 0
        defb 0
        defb 97
        defm " - Giant Ant."
        defb 0
        defb 98
        defm " - Giant Bat."
        defb 0
        defb 99
        defm " - Giant Centipede."
        defb 0
        defb 100
        defm " - Dragon."
        defb 0
        defb 101
        defm " - Floating Eye."
        defb 0
        defb 102
        defm " - Giant Frog."
        defb 0
        defb 103
        defm " - Golem."
        defb 0
        defb 104
        defm " - Harpy."
        defb 0
        defb 105
        defm " - Icky Thing."
        defb 0
        defb 106
        defm " - Jackal."
        defb 0
        defb 107
        defm " - Kobold."
        defb 0
        defb 108
        defm " - Giant Louse."
        defb 0
        defb 109
        defm " - Mold."
        defb 0
        defb 110
        defm " - Naga."
        defb 0
        defb 111
        defm " - Orc or Ogre."
        defb 0
        defb 112
        defm " - Person (Humanoid)."
        defb 0
        defb 113
        defm " - Quasit."
        defb 0
        defb 114
        defm " - Rodent."
        defb 0
        defb 115
        defm " - Skeleton."
        defb 0
        defb 116
        defm " - Giant Tick."
        defb 0
        defb 0
        defb 0
        defb 119
        defm " - Worm or Worm Mass."
        defb 0
        defb 0
        defb 121
        defm " - Yeek."
        defb 0
        defb 122
        defm " - Zombie."
        defb 0
        defb 123
        defm " - Arrow, bolt, or bullet."
        defb 0
        defb 124
        defm " - A sword or dagger."
        defb 0
        defb 125
        defm " - Bow, crossbow, or sling."
        defb 0
        defb 126
        defm " - Miscellaneous item."
        defb 0
    End Asm
    Return 0
End Function


Sub s_lk_identify()
    ' Moria's identifyGameObject()
    Dim lub_symbol , lub_index , lub_col    As UByte
    Dim luw_at                              As UInteger

    s_msg_flush()
    s_lk_ask( "Enter character to be identified :" )
    s_msg_clear()
    lub_symbol = gub_key_char
    If lub_symbol = 27 Or guw_key_code = 0 Then Return

    luw_at = 0
    If lub_symbol >= 32 And lub_symbol <= 126 Then
        luw_at    = fuw_lk_symbols()
        lub_index = lub_symbol - 32
        While lub_index > 0
            While Peek( luw_at ) <> 0
                luw_at = luw_at + 1
            End While
            luw_at    = luw_at + 1
            lub_index = lub_index - 1
        End While
        If Peek( luw_at ) = 0 Then luw_at = 0
    End If
    If lub_symbol = UC_CHAR_WALL_DIG And ( guw_game_options bAnd MW_OPTION_SEAMS ) <> 0 Then
        s_core_print_string_at( 0 , 0 , "% - A magma or quartz vein." , UB_BRIGHT_WHITE )
    ElseIf luw_at = 0 Then
        s_core_print_string_at( 0 , 0 , "Not Used." , UB_BRIGHT_WHITE )
    Else
        lub_col = 0
        While Peek( luw_at ) <> 0
            s_core_print_char_at( 0 , lub_col , Peek( luw_at ) , UB_BRIGHT_WHITE )
            luw_at  = luw_at + 1
            lub_col = lub_col + 1
        End While
        ' the description is not a message, Moria shows it with putStringClearToEOL() and keeps nothing for Ctrl-P
        Asm
            call A_JUMP_HISTORY_FORGET
        End Asm
    End If
    ' and what is remembered of the creatures drawn with it, the recall library asks first
    gub_lib_param_1 = lub_symbol
    s_core_call_library( UB_PAGED_CODE_LIB_RECALL , UB_LIB_RECALL_SYMBOL )
End Sub


Sub s_lib_look()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_LOOK_LOOK Then
        s_lk_look()
    ElseIf gub_lib_function = UB_LIB_LOOK_IDENTIFY Then
        s_lk_identify()
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
