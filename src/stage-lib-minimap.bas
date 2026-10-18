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

#define A_MM_FONT       A_MMU_SLOT_1 + 1024     ' characters 128 to 255 of the font, page 10, while it is in MMU 1
#define A_MM_BITS       A_MMU_SLOT_0            ' the bitmap, while its page is in MMU 0
' ...and in this page's own storage: which of the 128 cells is the green one, the player's, 255 for none, see s_mm_player()
#define A_MM_GREEN      A_LIB_PRIVATE
#define UW_MM_BITS_SIZE 2176                    ' 68 rows of 32 bytes


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
        cp 12                           ; UB_TILE_MIN_WALL, a Const, which Asm cannot see
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
        ld a, 8                         ; a square is 8 bytes
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
    lub_slot_2 = fub_mm_slot( MMU_SLOT_0 + 2 )
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
        If ( y bAnd 3 ) = 0 Then s_mm_map( MMU_SLOT_0 + 2 , gub_level_map_page + ( y >> 2 ) )
        s_mm_row( A_MMU_SLOT_2 + Cast( UInteger , y bAnd 3 ) * 2048 , A_MM_BITS + Cast( UInteger , y ) * 32 , gub_dungeon_cols )
        y = y + 1
    End While
    s_mm_map( MMU_SLOT_0 + 2 , lub_slot_2 )
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
        ld b, 8                         ; rows of characters
    mm_copy_char_row:
        push bc
        push hl
        ld c, 16                        ; characters across
    mm_copy_char:
        push hl
        ld b, 8                         ; the character's eight rows
    mm_copy_byte:
        ld a, (hl)
        ld (de), a
        inc de
        ld a, 32                        ; the bitmap's next row
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
        ld a, 31                        ; ...and the second row's
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
        ld a, 64                        ; two rows of the bitmap down
        add hl, a                       ; a Next instruction
        pop bc
        djnz mm_half_row
    End Asm
End Sub


Sub s_mm_dot( pub_y As UByte , pub_x As UByte )
    ' the player, a pixel of the 128 by 64 that the 16 by 8 characters make
    Dim luw_at As UInteger

    luw_at = A_MM_FONT + ( Cast( UInteger , pub_y >> 3 ) * 16 + Cast( UInteger , pub_x >> 3 ) ) * 8 + ( pub_y bAnd 7 )
    Poke luw_at , Peek( luw_at ) bOr ( 128 >> ( pub_x bAnd 7 ) )
End Sub


Sub s_mm_cells( pub_on As UByte )
    ' the 16 by 8 cells of the screen, showing characters 128 to 255 in dark grey, or rubbed out, the author's colours of 16
    ' October 2026, the player's cell is made green by s_mm_player() afterwards, so none is green now
    Dim y , x As UByte

    Poke A_MM_GREEN , 255
    For y = 0 To 7
        For x = 0 To 15
            If pub_on Then
                s_core_print_char_at( UB_MINIMAP_ROW + y , x , UB_MINIMAP_CHAR + y * 16 + x , UB_DARK_GREY )
            Else
                s_core_print_char_at( UB_MINIMAP_ROW + y , x , 32 , UB_BLACK )
            End If
        Next
    Next
End Sub


Sub s_mm_player( pub_y As UByte , pub_x As UByte )
    ' the cell with the player in it is green, the pixel at pub_y, pub_x, and the one that was green before is dark grey
    ' again, N.B: only the two cells are written, and only when the player has moved into another cell
    Dim lub_cell , lub_old As UByte

    lub_cell = ( pub_y >> 3 ) * 16 + ( pub_x >> 3 )
    lub_old  = Peek( A_MM_GREEN )
    If lub_cell = lub_old Then Return
    If lub_old <> 255 Then s_core_print_char_at( UB_MINIMAP_ROW + ( lub_old >> 4 ) , lub_old bAnd 15 , UB_MINIMAP_CHAR + lub_old , UB_DARK_GREY )
    s_core_print_char_at( UB_MINIMAP_ROW + ( lub_cell >> 4 ) , lub_cell bAnd 15 , UB_MINIMAP_CHAR + lub_cell , UB_GREEN )
    Poke A_MM_GREEN , lub_cell
End Sub


Sub s_mm_draw()
    ' stage 2: the font's upper half made from the bitmap, MMU 0 has the bitmap's page and MMU 1 the font's
    Dim lub_slot_0 , lub_slot_1     As UByte
    Dim lub_left , lub_top , y , x  As UByte
    Dim lub_dot_y , lub_dot_x       As UByte

    If gub_minimap_mode = 0 Then Return
    If gub_minimap_rebuild Then s_mm_rebuild()
    lub_slot_0 = fub_mm_slot( MMU_SLOT_0 )
    lub_slot_1 = fub_mm_slot( MMU_SLOT_0 + 1 )
    s_mm_map( MMU_SLOT_0 , UB_PAGE_MINIMAP )
    s_mm_map( MMU_SLOT_0 + 1 , UB_PAGE_FONT )
    If gub_minimap_mode = 1 Then
        ' the window: 128 squares across, in steps of 8, and 64 down, with the player as near its middle as the
        ' edges of the level allow
        ' N.B: the furthest it goes is the first step of 8 at which the window reaches the level's last column, 72 for 198
        lub_left = 0
        If gub_player_col > 64 Then lub_left = ( gub_player_col - 64 ) bAnd $F8
        If gub_dungeon_cols <= 128 Then
            lub_left = 0
        ElseIf lub_left > ( ( gub_dungeon_cols - 121 ) bAnd $F8 ) Then
            lub_left = ( gub_dungeon_cols - 121 ) bAnd $F8
        End If
        lub_top = 0
        If gub_player_row > 32 Then lub_top = gub_player_row - 32
        If gub_dungeon_rows <= 64 Then
            lub_top = 0
        ElseIf lub_top > gub_dungeon_rows - 64 Then
            lub_top = gub_dungeon_rows - 64
        End If
        s_mm_copy( A_MM_BITS + Cast( UInteger , lub_top ) * 32 + ( lub_left >> 3 ) )
        lub_dot_y = gub_player_row - lub_top
        lub_dot_x = gub_player_col - lub_left
    Else
        ' the whole level, a pixel for each two by two squares, 13 characters across and 5 down, the rest blank
        Asm
            ld hl, A_MM_FONT
            ld de, A_MM_FONT + 1
            ld bc, 1023
            ld (hl), 0
            ldir
        End Asm
        For y = 0 To 4
            For x = 0 To 12
                ' 8 rows of pixels to a character, 16 rows of squares, except the last: 66 rows of squares make 33 of pixels
                If y < 4 Then
                    s_mm_half( A_MM_BITS + Cast( UInteger , y ) * 512 + Cast( UInteger , x ) * 2 , A_MM_FONT + ( Cast( UInteger , y ) * 16 + x ) * 8 , 8 )
                Else
                    s_mm_half( A_MM_BITS + Cast( UInteger , y ) * 512 + Cast( UInteger , x ) * 2 , A_MM_FONT + ( Cast( UInteger , y ) * 16 + x ) * 8 , 1 )
                End If
            Next
        Next
        lub_dot_y = gub_player_row >> 1
        lub_dot_x = gub_player_col >> 1
    End If
    s_mm_dot( lub_dot_y , lub_dot_x )
    s_mm_map( MMU_SLOT_0 + 1 , lub_slot_1 )
    s_mm_map( MMU_SLOT_0 , lub_slot_0 )
    ' the 128 cells are written only when they need to be, when the mini map has just been turned on or the screen
    ' drawn afresh: its first and last cells say whether they still show the mini map's characters, writing them all
    ' each time was more than half of the 1:1 drawing (4.3 ms of 6.7, measured in the emulator)
    If Peek( A_SCREEN_BASE + UB_MINIMAP_ROW * 160 ) <> UB_MINIMAP_CHAR Or Peek( A_SCREEN_BASE + ( UB_MINIMAP_ROW + 7 ) * 160 + 30 ) <> 255 Then s_mm_cells( true )
    s_mm_player( lub_dot_y , lub_dot_x )
End Sub


Sub s_mm_cycle()
    ' the [ key: off, 1:1, 1:2, and round again, the next time the game waits for a command the map is drawn
    gub_minimap_mode = gub_minimap_mode + 1
    If gub_minimap_mode > 2 Then gub_minimap_mode = 0
    If gub_minimap_mode = 0 Then s_mm_cells( false )
End Sub


Sub s_lib_minimap()
    If gub_lib_function = UB_LIB_MINIMAP_DRAW Then
        s_mm_draw()
    ElseIf gub_lib_function = UB_LIB_MINIMAP_CYCLE Then
        s_mm_cycle()
    End If
End Sub
