#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_minimap()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: the mini map, ours, not Moria's, a map of the walls the player remembers, in the
' 16 by 8 characters at the bottom left of the screen (rows 24 to 31, columns 0 to 15), drawn with the upper half of
' the font, characters 128 to 255, each 8 by 8 pixels...
' ...the walking stage calls it, the routines are:
'
'   UB_LIB_MINIMAP_DRAW     the mini map brought up to date, called only as the game waits for the player's command,
'                           so a rest or a run costs nothing
'   UB_LIB_MINIMAP_CYCLE    the [ key: off, 1:1, 1:2, and round again, it takes no turn
'
' it is made in two stages:
'   1) the bitmap, in page UB_PAGE_MINIMAP: one bit for each square of the level, 256 to a row (32 bytes, as the map's
'      pages are 256 squares wide, so a square's bit is found by shifting, row * 32 + column / 8, the top bit is the
'      leftmost, as in the font), set for a wall the player remembers (Moria's permanent_light on a wall): as the
'      player's light moves the walking stage sets the bits itself, see s_cr_minimap_set() in stage-crawl.bas, and
'      everything else that can change what is remembered (a lit room, a spell, a new level, a monster boring
'      through rock) only asks for the bitmap to be made again from the map, gub_minimap_rebuild, which this page
'      does the next time it draws
'   2) the drawing, from the bitmap into the font: at 1:1 a window of 128 by 64 squares that follows the player,
'      across in steps of 8 so that each byte of the bitmap is a byte of a character as it stands, at 1:2 the
'      whole level, each pixel two by two squares, 99 by 33 pixels in the top left 13 by 5 characters, and the
'      player is a pixel of their own in both
' N.B: in the dark Moria remembers the walls, not the floor, a corridor shows as its two walls, a lit room as its walls
' N.B: the pages are put in and taken out of the data slots by writing the Next registers directly, and put back as
' they were, so the memory monitor does not count them: it counts what the game itself does
' N.B: nothing here asks for a random number or changes the game, only the screen and the font


Function fub_mm_slot( pub_reg As UByte ) As UByte
    ' the page that is in a slot now, read from its Next register, $50 for MMU 0
    gub_shared_1 = pub_reg
    Asm
        ld a, (_gub_shared_1)
        ld bc, A_NEXTREG_SELECT
        out (c), a
        inc b                           ; $253B, A_NEXTREG_DATA
        in a, (c)
        ld (_gub_shared_1), a
    End Asm
    Return gub_shared_1
End Function


Sub s_mm_map( pub_reg As UByte , pub_page As UByte )
    ' puts a page in a slot by its Next register, behind the core's back: the core's own record of the slot is not
    ' changed, so whatever is put in must be taken out again, see fub_mm_slot()
    gub_shared_1 = pub_reg
    gub_shared_2 = pub_page
    Asm
        ld a, (_gub_shared_1)
        ld bc, A_NEXTREG_SELECT
        out (c), a
        inc b                           ; $253B, A_NEXTREG_DATA
        ld a, (_gub_shared_2)
        out (c), a
    End Asm
End Sub


Sub s_mm_row( puw_square As UInteger , puw_bits As UInteger , pub_cols As UByte )
    ' one row of the bitmap made from one row of the map: a bit for each wall that is remembered
    ' the parameters: puw_square ix+4 and ix+5 (the row's first square, its feature byte), puw_bits ix+6 and ix+7 (the
    ' row's first byte of the bitmap, which is clear), pub_cols ix+9
    Asm
        ld l, (ix+4)
        ld h, (ix+5)
        ld e, (ix+6)
        ld d, (ix+7)
        ld b, (ix+9)
        ld c, $80                       ; the bit for the first square of the byte, the leftmost
    mm_row_square:
        ld a, (hl)                      ; what the square is made of
        cp UB_TILE_MIN_WALL
        jr c, mm_row_next
        inc hl
        ld a, (hl)                      ; its flags
        dec hl
        and MB_SQUARE_PERM_LIGHT
        jr z, mm_row_next
        ld a, (de)
        or c
        ld (de), a
    mm_row_next:
        ld a, UB_MAP_SQUARE_SIZE
        add hl, a                       ; a Next instruction
        rrc c
        jr nc, mm_row_same
        inc de                          ; eight squares done, the next byte
    mm_row_same:
        djnz mm_row_square
    End Asm
End Sub


Sub s_mm_rebuild()
    ' the whole bitmap made again from the map, MMU 0 has the bitmap's page and MMU 2 each page of the map in turn
    Dim lub_slot_0 , lub_slot_2 , y As UByte

    lub_slot_0 = fub_mm_slot( MMU_SLOT_0 )
    lub_slot_2 = fub_mm_slot( MMU_SLOT_2 )
    s_mm_map( MMU_SLOT_0 , UB_PAGE_MINIMAP )
    Asm
        ld hl, A_MM_BITS
        ld de, A_MM_BITS + 1
        ld bc, UW_MM_BITS_SIZE - 1
        ld (hl), 0
        ldir
    End Asm
    y = 0
    While y < gub_dungeon_rows
        If ( y bAnd ( UB_MAP_ROWS_PER_PAGE - 1 ) ) = 0 Then s_mm_map( MMU_SLOT_2 , gub_level_map_page + ( y >> UB_MAP_ROWS_SHIFT ) )
        s_mm_row( A_MMU_SLOT_2 + Cast( UInteger , y bAnd ( UB_MAP_ROWS_PER_PAGE - 1 ) ) * UW_MAP_ROW_SIZE , A_MM_BITS + Cast( UInteger , y ) * UB_MM_BITS_ROW , gub_dungeon_cols )
        y = y + 1
    End While
    s_mm_map( MMU_SLOT_2 , lub_slot_2 )
    s_mm_map( MMU_SLOT_0 , lub_slot_0 )
    gub_minimap_rebuild = false
End Sub


Sub s_mm_copy( puw_from As UInteger )
    ' 1:1: the 128 characters copied from the bitmap, each character's eight bytes are eight rows of the bitmap one
    ' above the other, the characters go across 16 to a row of them, 8 rows of them
    ' the parameter: puw_from ix+4 and ix+5, the bitmap byte at the window's top left
    Asm
        ld l, (ix+4)
        ld h, (ix+5)
        ld de, A_MM_FONT
        ld b, UB_MM_CHARS_DOWN
    mm_copy_char_row:
        push bc
        push hl
        ld c, UB_MM_CHARS_ACROSS
    mm_copy_char:
        push hl
        ld b, UB_FONT_CHAR_SIZE
    mm_copy_byte:
        ld a, (hl)
        ld (de), a
        inc de
        ld a, UB_MM_BITS_ROW
        add hl, a                       ; a Next instruction
        djnz mm_copy_byte
        pop hl
        inc hl                          ; the next byte across
        dec c
        jr nz, mm_copy_char
        pop hl
        inc h                           ; 256 on, eight rows of the bitmap down
        pop bc
        djnz mm_copy_char_row
    End Asm
End Sub


Sub s_mm_half( puw_from As UInteger , puw_to As UInteger , pub_rows As UByte )
    ' 1:2: one character, from 16 squares across and 2 * pub_rows down: each pixel is lit if any of its two by two
    ' squares is, two bytes of two rows of the bitmap make each byte of the character
    ' the parameters: puw_from ix+4 and ix+5, puw_to ix+6 and ix+7, pub_rows ix+9
    Asm
        ld l, (ix+4)
        ld h, (ix+5)
        ld e, (ix+6)
        ld d, (ix+7)
        ld b, (ix+9)
    mm_half_row:
        push bc
        push hl
        ld b, (hl)                      ; the first row's two bytes...
        inc hl
        ld c, (hl)
        ld a, UB_MM_BITS_ROW - 1        ; ...and the second row's
        add hl, a
        ld a, (hl)
        or b
        ld b, a
        inc hl
        ld a, (hl)
        or c
        ld c, a
        ld l, 0                         ; the character's byte: each pair of bits in B makes one of its top four
        ld a, b
        and $C0
        jr z, mm_half_1
        set 7, l
    mm_half_1:
        ld a, b
        and $30
        jr z, mm_half_2
        set 6, l
    mm_half_2:
        ld a, b
        and $0C
        jr z, mm_half_3
        set 5, l
    mm_half_3:
        ld a, b
        and $03
        jr z, mm_half_4
        set 4, l
    mm_half_4:                          ; ...and each pair in C one of its bottom four
        ld a, c
        and $C0
        jr z, mm_half_5
        set 3, l
    mm_half_5:
        ld a, c
        and $30
        jr z, mm_half_6
        set 2, l
    mm_half_6:
        ld a, c
        and $0C
        jr z, mm_half_7
        set 1, l
    mm_half_7:
        ld a, c
        and $03
        jr z, mm_half_8
        set 0, l
    mm_half_8:
        ld a, l
        ld (de), a
        inc de
        pop hl
        ld a, UB_MM_BITS_ROW * 2        ; two rows of the bitmap down
        add hl, a                       ; a Next instruction
        pop bc
        djnz mm_half_row
    End Asm
End Sub


Sub s_mm_dot( pub_y As UByte , pub_x As UByte )
    ' the player, a pixel of the 128 by 64 that the 16 by 8 characters make
    Dim luw_at As UInteger

    luw_at = A_MM_FONT + ( Cast( UInteger , pub_y >> 3 ) * UB_MM_CHARS_ACROSS + Cast( UInteger , pub_x >> 3 ) ) * UB_FONT_CHAR_SIZE + ( pub_y bAnd 7 )
    Poke luw_at , Peek( luw_at ) bOr ( MB_FONT_LEFT_PIXEL >> ( pub_x bAnd 7 ) )
End Sub


Sub s_mm_cells( pub_on As UByte )
    ' the 16 by 8 cells of the screen, showing characters 128 to 255 in dark grey, or rubbed out, sdo's colours of 16
    ' October 2026, the player's cell is made green by s_mm_player() afterwards, so none is green now
    Dim y , x As UByte

    Poke A_MM_GREEN , UB_MM_NO_CELL
    For y = 0 To UB_MM_CHARS_DOWN - 1
        For x = 0 To UB_MM_CHARS_ACROSS - 1
            If pub_on Then
                s_core_print_char_at( UB_MINIMAP_ROW + y , x , UB_MINIMAP_CHAR + y * UB_MM_CHARS_ACROSS + x , UB_DARK_GREY )
            Else
                s_core_print_char_at( UB_MINIMAP_ROW + y , x , UC_SPACE , UB_BLACK )
            End If
        Next
    Next
End Sub


Sub s_mm_player( pub_y As UByte , pub_x As UByte )
    ' the cell with the player in it is green, the pixel at pub_y, pub_x, and the one that was green before is dark grey
    ' again, N.B: only the two cells are written, and only when the player has moved into another cell, or the cell
    ' is not the colour it should be (the second byte of the screen cell), the plain map having been turned on or off
    ' (white then, not green, sdo, 22 October)
    Dim lub_cell , lub_old , lub_colour As UByte

    lub_cell   = ( pub_y >> 3 ) * UB_MM_CHARS_ACROSS + ( pub_x >> 3 )
    lub_old    = Peek( A_MM_GREEN )
    lub_colour = UB_GREEN
    If ( guw_game_options bAnd MW_OPTION_PLAIN_MAP ) <> 0 Then lub_colour = UB_WHITE
    If lub_cell = lub_old And Peek( A_SCREEN_BASE + Cast( UInteger , UB_MINIMAP_ROW + ( lub_cell >> 4 ) ) * UB_SCREEN_ROW_SIZE + ( lub_cell bAnd 15 ) * 2 + 1 ) = lub_colour Then Return
    If lub_old <> UB_MM_NO_CELL Then s_core_print_char_at( UB_MINIMAP_ROW + ( lub_old >> 4 ) , lub_old bAnd 15 , UB_MINIMAP_CHAR + lub_old , UB_DARK_GREY )
    s_core_print_char_at( UB_MINIMAP_ROW + ( lub_cell >> 4 ) , lub_cell bAnd 15 , UB_MINIMAP_CHAR + lub_cell , lub_colour )
    Poke A_MM_GREEN , lub_cell
End Sub


Sub s_mm_draw()
    ' stage 2: the font's upper half made from the bitmap, MMU 0 has the bitmap's page and MMU 1 the font's
    Dim lub_slot_0 , lub_slot_1     As UByte
    Dim lub_left , lub_top , y , x  As UByte
    Dim lub_dot_y , lub_dot_x       As UByte

    If gub_minimap_mode = UB_MM_MODE_OFF Then Return
    If gub_minimap_rebuild Then s_mm_rebuild()
    lub_slot_0 = fub_mm_slot( MMU_SLOT_0 )
    lub_slot_1 = fub_mm_slot( MMU_SLOT_1 )
    s_mm_map( MMU_SLOT_0 , UB_PAGE_MINIMAP )
    s_mm_map( MMU_SLOT_1 , UB_PAGE_FONT )
    If gub_minimap_mode = UB_MM_MODE_FULL Then
        ' the window: 128 squares across, in steps of 8, and 64 down, with the player as near its middle as the
        ' edges of the level allow
        ' N.B: the furthest it goes is the first step of 8 at which the window reaches the level's last column, 72 for 198
        lub_left = 0
        If gub_player_col > UB_MM_WINDOW_COLS / 2 Then lub_left = ( gub_player_col - UB_MM_WINDOW_COLS / 2 ) bAnd MB_MM_WINDOW_STEP
        If gub_dungeon_cols <= UB_MM_WINDOW_COLS Then
            lub_left = 0
        ElseIf lub_left > ( ( gub_dungeon_cols - ( UB_MM_WINDOW_COLS - 7 ) ) bAnd MB_MM_WINDOW_STEP ) Then
            lub_left = ( gub_dungeon_cols - ( UB_MM_WINDOW_COLS - 7 ) ) bAnd MB_MM_WINDOW_STEP
        End If
        lub_top = 0
        If gub_player_row > UB_MM_WINDOW_ROWS / 2 Then lub_top = gub_player_row - UB_MM_WINDOW_ROWS / 2
        If gub_dungeon_rows <= UB_MM_WINDOW_ROWS Then
            lub_top = 0
        ElseIf lub_top > gub_dungeon_rows - UB_MM_WINDOW_ROWS Then
            lub_top = gub_dungeon_rows - UB_MM_WINDOW_ROWS
        End If
        s_mm_copy( A_MM_BITS + Cast( UInteger , lub_top ) * UB_MM_BITS_ROW + ( lub_left >> 3 ) )
        lub_dot_y = gub_player_row - lub_top
        lub_dot_x = gub_player_col - lub_left
    Else
        ' the whole level, a pixel for each two by two squares, 13 characters across and 5 down, the rest blank
        Asm
            ld hl, A_MM_FONT
            ld de, A_MM_FONT + 1
            ld bc, UW_MM_FONT_SIZE - 1
            ld (hl), 0
            ldir
        End Asm
        For y = 0 To UB_MM_HALF_DOWN - 1
            For x = 0 To UB_MM_HALF_ACROSS - 1
                ' 8 rows of pixels to a character, 16 rows of squares, except the last: 66 rows of squares make 33 of pixels
                If y < UB_MM_HALF_DOWN - 1 Then
                    s_mm_half( A_MM_BITS + Cast( UInteger , y ) * ( UB_MM_BITS_ROW * 2 * UB_FONT_CHAR_SIZE ) + Cast( UInteger , x ) * 2 , A_MM_FONT + ( Cast( UInteger , y ) * UB_MM_CHARS_ACROSS + x ) * UB_FONT_CHAR_SIZE , UB_FONT_CHAR_SIZE )
                Else
                    s_mm_half( A_MM_BITS + Cast( UInteger , y ) * ( UB_MM_BITS_ROW * 2 * UB_FONT_CHAR_SIZE ) + Cast( UInteger , x ) * 2 , A_MM_FONT + ( Cast( UInteger , y ) * UB_MM_CHARS_ACROSS + x ) * UB_FONT_CHAR_SIZE , 1 )
                End If
            Next
        Next
        lub_dot_y = gub_player_row >> 1
        lub_dot_x = gub_player_col >> 1
    End If
    s_mm_dot( lub_dot_y , lub_dot_x )
    s_mm_map( MMU_SLOT_1 , lub_slot_1 )
    s_mm_map( MMU_SLOT_0 , lub_slot_0 )
    ' the 128 cells are written only when they need to be, when the mini map has just been turned on or the screen
    ' drawn afresh: its first and last cells say whether they still show the mini map's characters, writing them all
    ' each time was more than half of the 1:1 drawing (4.3 ms of 6.7, measured in the emulator)
    If Peek( A_SCREEN_BASE + UB_MINIMAP_ROW * UB_SCREEN_ROW_SIZE ) <> UB_MINIMAP_CHAR Or Peek( A_SCREEN_BASE + ( UB_MINIMAP_ROW + UB_MM_CHARS_DOWN - 1 ) * UB_SCREEN_ROW_SIZE + ( UB_MM_CHARS_ACROSS - 1 ) * 2 ) <> UB_MINIMAP_CHAR + UB_MM_CHARS_ACROSS * UB_MM_CHARS_DOWN - 1 Then s_mm_cells( true )
    s_mm_player( lub_dot_y , lub_dot_x )
End Sub


Sub s_mm_cycle()
    ' the [ key: off, 1:1, 1:2, and round again, the next time the game waits for a command the map is drawn
    gub_minimap_mode = gub_minimap_mode + 1
    If gub_minimap_mode > UB_MM_MODE_HALF Then gub_minimap_mode = UB_MM_MODE_OFF
    If gub_minimap_mode = UB_MM_MODE_OFF Then s_mm_cells( false )
End Sub


Sub s_lib_minimap()
    If gub_lib_function = UB_LIB_MINIMAP_DRAW Then
        s_mm_draw()
    ElseIf gub_lib_function = UB_LIB_MINIMAP_CYCLE Then
        s_mm_cycle()
    End If
End Sub
