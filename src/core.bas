#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: these two includes only declare constants and fixed address variables, they produce no code or data...
' ...they are up here so that the start up code below can use the constants
#include "constants.bas"
#include "globals.bas"

' N.B: this must be the very first code in the file, it is what sits at address $8000, where the loader jumps to...
' ...the build script checks that nothing has been placed in front of it, so the core must not use arrays or ordinary
' variables outside of a Sub or Function, only variables declared with "At <address>" (strings are fine, they live in the heap)
' N.B: the core lives in MMU 4 and 5, not at the bottom of memory, see the notes at the top of constants.bas for why...
' ...so there are no interrupt or restart vectors in here, interrupts use mode 2 and the loader has already set that up
Asm
    jp core_start   ; address $8000: the loader jumps here

    org $8010       ; the API jump table, three bytes per entry, the order must match the A_JUMP_ list in constants.bas...
                    ; ...only ever add new entries at the end, the stages have the addresses of the existing ones compiled in...
                    ; ...(the table can now grow as long as it likes, the start up code simply follows it)
    jp _s_core_next_reg
    jp _s_core_crash
    jp _s_core_ram_copy
    jp _s_core_clear_screen
    jp _s_core_print_char_at_logged     ; N.B: the stages' characters go through the message history first, the core's own do not
    jp _s_core_print_string_at
    jp _s_core_get_key
    jp _s_core_countdown
    jp _fs_core_number
    jp _fub_core_scan_key
    jp _fs_core_key_name
    jp _s_core_swap_paged_data
    jp _fub_core_file_save_page
    jp _fub_core_file_load_page
    jp _s_core_random_seed
    jp _ful_core_random
    jp _ful_core_random_number
    jp _fuw_core_dice_roll
    jp _fuw_core_record_address
    jp _s_core_fetch_record
    jp _s_core_store_record
    jp _fuw_core_map_square
    jp _fs_core_text_at
    jp _fsw_core_random_normal
    jp _s_core_call_library
    jp _fub_core_print_text_at
    jp _ful_core_recall
    jp _s_core_message
    jp _s_core_message_after
    jp _s_core_direction_key
    jp _fub_core_map_symbol
    jp _s_core_map_put
    jp _s_core_map_draw_panel
    jp _s_core_map_light_room
    jp _fub_core_map_outside_panel
    jp _s_core_msg_text
    jp _s_core_msg_clear
    jp _s_core_msg_flush
    jp _s_core_msg
    jp _fub_core_lib_call
    jp _fuw_core_random_word
    jp _fs_core_char
    jp _s_core_clear_row

core_start:
    di                          ; interrupts off, they stay off except while we are deliberately waiting for one
    ld sp, A_Z80_CPU_STACK      ; move the stack to the top of page 11, which the loader mapped into MMU 7

    ; map the core data page (32, UB_PAGE_CORE_DATA in constants.bas) into MMU 6, nextreg $56...
    ; ...the loader could not do this for us, because the loader itself was running in MMU 6, this is what discards it
    ld bc, A_NEXTREG_SELECT
    ld a, $56
    out (c), a
    ld bc, A_NEXTREG_DATA
    ld a, 32
    out (c), a

    ; fill the whole stack area with a known byte, the stack is empty at this moment so nothing is lost...
    ; ...the memory monitor later counts how many of these bytes are still untouched, to show how deep the stack has ever been
    ld hl, A_STACK_BOTTOM
    ld de, A_STACK_BOTTOM + 1
    ld bc, A_Z80_CPU_STACK - A_STACK_BOTTOM - 1
    ld (hl), UB_STACK_FILL
    ldir

    ; fill the heap with a known byte too, before it is prepared, so the memory monitor can show how much of it has ever been used...
    ; ...the compiler knows where the heap is and how big, from the --heap-address and --heap-size options in build.ps1
    ld hl, .core.ZXBASIC_MEM_HEAP
    ld de, .core.ZXBASIC_MEM_HEAP + 1
    ld bc, .core.ZXBASIC_HEAP_SIZE - 1
    ld (hl), UB_HEAP_FILL
    ldir

    ; headerless mode leaves out the compilers own start up code, which is what normally prepares the heap...
    ; ...so we prepare it here ourselves, before any string is used...
    ; ...it takes the heap address and size from the --heap-address and --heap-size options in build.ps1
    call .core.__MEM_INIT
End Asm

s_core_main()


'##################################################################################################################################
' --- BORIEL LANGUAGE TIPS ---
' 1) about FastCall
'   - can be used with Function and/or Sub
'   - a FastCall routine can only ever accept no parameters at all, or only one parameter
'     i.e. am FastCall routine can never accept more than one parameter
'   - if the parameter is a byte it is available upon entry in the A register
'   - if the parameter is a word it is available upon entry in the HL register pair
'   - if the parameter is a long it is available upon entry in the DEHL registers
' 2) @ can be used to acquire address (pointer) and * can be used to dereference the pointer/address
'##################################################################################################################################


'##################################################################################################################################
' --- CORE ROUTINES ---

Function fs_core_char( pub_code As UByte ) As String
    ' a string of one character, given its code, this is what BASIC's own CHR is for, and CHR must NOT be used anywhere in
    ' the game: the compiler's own routine for it keeps a value, while it works, in one of the ZX Spectrum's system
    ' variables, at address $5C4D (DEST), which on our machine is not a system variable at all, it is 7245 bytes
    ' into whatever page is in the third data slot, a map, a database or what the player knows, and two bytes of
    ' it were overwritten every time, found on 12 October 2026 by a garbled spell name
    ' N.B: a string is its length, 2 bytes, and then its characters, so a string of one space is made, and the
    ' space is changed, the build checks that no page uses CHR, see build.ps1
    Dim ls_one As String

    ls_one = " "
    Poke Peek( UInteger , @ls_one ) + 2 , pub_code
    Return ls_one
End Function


Sub s_core_next_reg( pub_reg As UByte , pub_value As UByte )
    gub_shared_1 = pub_reg
    gub_shared_2 = pub_value
    Asm
        ld a, (_gub_shared_1)   ; load register number
        ld bc, A_NEXTREG_SELECT ; use your constant $243B
        out (c), a              ; select register

        ld a, (_gub_shared_2)   ; load value
        ld bc, A_NEXTREG_DATA   ; use your constant $253B
        out (c), a              ; write value
    End Asm
End Sub


Sub s_core_return_to_zxos()
    ' perform hardware soft reset, which on a Next puts the ROM back at the bottom of memory and starts NextZXOS again...
    ' N.B: the ZEsarUX emulator's is not that, tried on 13 October 2026: it starts the processor again at address 0
    ' and leaves every page where it was, the ROM is not put back and nothing is booted, so whatever is in MMU 0 is
    ' run as if it were the ROM, and it hangs, whether or not NextZXOS was booted to begin with. So a page of our
    ' own is put in MMU 0 first, with a jump at address 0 to s_core_nothing_to_return_to(), which says so...
    ' ...a real Next never runs that jump, its reset has replaced the page with the ROM by the time anything runs
    s_core_next_reg( MMU_SLOT_0 , UB_PAGE_RESET_LANDING )
    Asm
        ld hl, core_reset_landing
        ld de, 0
        ld bc, core_reset_landing_end - core_reset_landing
        ldir
        jr core_reset_landing_end
core_reset_landing:
        di
        ld sp, A_Z80_CPU_STACK
        jp _s_core_nothing_to_return_to
core_reset_landing_end:
    End Asm
    ' N.B: the soft reset bit lives in nextreg $02, not in nextreg $00 (which is the read only machine id)
    s_core_next_reg( UB_NEXTREG_RESET_CONFIG , UB_NEXTREG_MACHINE_RESET )
End Sub

Sub s_core_print_char_at( pub_x As UByte , pub_y As UByte , pub_char As UByte , pub_colour As UByte )
    ' puts one character, in one colour, into one cell of the screen
    ' N.B: every caller passes ( row , column ), so pub_x is the row (0 to 31) and pub_y is the column (0 to 79)
    ' N.B: all in Z80, this is the most called routine there is: the compiler has already put the address of the
    ' parameters into IX, and a UByte parameter is the high byte of the pair it was pushed as, which is why the
    ' offsets are the odd numbers: row ix+5, column ix+7, character ix+9, colour ix+11
    Asm
        ; guard: quietly ignore anything off screen, a bad position would otherwise be written over the stack,
        ; which sits just above the screen cells
        ld a, (ix+5)                    ; the row
        cp 32                           ; UB_SCREEN_ROWS
        jr nc, s_core_print_char_at_end
        ld d, a
        ld a, (ix+7)                    ; the column
        cp 80                           ; UB_SCREEN_COLS
        jr nc, s_core_print_char_at_end

        ; the cell is at screen base + row * 160 + column * 2: two bytes a cell, eighty cells a row
        ld e, 160
        mul d, e                        ; DE = row * 160, a Next instruction
        ld hl, A_SCREEN_BASE
        add hl, de
        add a, a                        ; column * 2, 158 at most
        add hl, a                       ; a Next instruction

        ld a, (ix+9)
        ld (hl), a                      ; the character
        inc hl
        ld a, (ix+11)
        ld (hl), a                      ; its colour
    s_core_print_char_at_end:
    End Asm
End Sub


Sub s_core_clear_row( pub_row As UByte , pub_from As UByte , pub_colour As UByte )
    ' fills one row of the screen with spaces of one colour, from the column pub_from to the end of the row (0 for
    ' the whole row): the first cell is written, and LDIR copies it along the others
    ' N.B: this is how any row is cleared, by the core and, through the jump table, by the stages and libraries,
    ' one call instead of eighty to s_core_print_char_at()
    ' N.B: clearing the top row from its first column says the message that was there is finished with, so it is
    ' first put away for Ctrl-P, exactly as s_core_print_char_at_logged() does for a plain space put there
    If pub_row = 0 And pub_from = 0 And gub_log_length <> 0 Then s_core_message_push()

    Asm
        ; guard: quietly ignore anything off screen, as s_core_print_char_at() does
        ld a, (ix+5)                    ; the row
        cp 32                           ; UB_SCREEN_ROWS
        jr nc, s_core_clear_row_end
        ld d, a
        ld a, (ix+7)                    ; the column to start from
        cp 80                           ; UB_SCREEN_COLS
        jr nc, s_core_clear_row_end
        ld c, a

        ld e, 160
        mul d, e                        ; DE = row * 160, a Next instruction
        ld hl, A_SCREEN_BASE
        add hl, de
        add a, a                        ; column * 2
        add hl, a                       ; a Next instruction, HL = the first cell to clear

        ld (hl), 32
        inc hl
        ld a, (ix+9)
        ld (hl), a                      ; the colour
        dec hl

        ; the cells after it, ( 79 - column ) of them, two bytes each
        ld a, 79
        sub c
        jr z, s_core_clear_row_end      ; N.B: none, the last column: LDIR with a count of 0 would copy 65536 bytes
        add a, a
        ld c, a
        ld b, 0
        ld d, h
        ld e, l
        inc de
        inc de                          ; DE = the cell after the first
        ldir
    s_core_clear_row_end:
    End Asm
End Sub


Sub s_core_clear_screen()
    ' fill all 80 x 32 cells with a two byte pair: a space, and attribute 0 (black ink on black paper)
    Asm
        ld hl, A_SCREEN_BASE
        ld (hl), 32
        inc hl
        ld (hl), 0
        ld hl, A_SCREEN_BASE
        ld de, A_SCREEN_BASE + 2
        ld bc, 5118
        ldir
    End Asm
End Sub


Sub s_core_pause()
    ' a crude delay so that the eye can follow the stages taking turns, somewhere around a second
    Dim i , luw_dummy   As UInteger
    For i = 0 To 20000
        luw_dummy = luw_dummy + 1
    Next
End Sub


Sub s_core_print_string_at( pub_x As UByte, pub_y As UByte, ps_text As String, pub_colour As UByte )
    Dim i           As UByte
    Dim lub_char    As UByte
    Dim lub_y       As UByte = pub_y

    ' guard: nothing to do for an empty string, and "Len - 1" below would wrap around to a huge number...
    If Len( ps_text ) = 0 Then Return
    ' guard: quietly ignore a row that is off screen...
    If pub_x >= UB_SCREEN_ROWS Then Return

    For i = 0 To Len( ps_text ) - 1
        lub_char = Code( ps_text( i ) )
        ' stop if we hit a null terminator...
        If lub_char = 0 Then Exit For
        ' prevent writing past the 80th column...
        If lub_y >= UB_SCREEN_COLS Then Exit For
        s_core_print_char_at( pub_x , lub_y , lub_char , pub_colour )
        lub_y = lub_y + 1
    Next
End Sub


Function fs_core_number( pul_value As ULong ) As String
    ' turns a whole number into text, e.g. 1234 into "1234", it is our own replacement for Str$...
    ' N.B: Str$ must not be used anywhere in this program, the compiler implements it by calling the floating point
    ' calculator inside the Spectrum ROM (rst $28), and we have no ROM, our own core is mapped in where the ROM would be...
    ' ...the same goes for anything else that needs floating point, e.g. Val, Float variables, Sin, Sqr, or "/" on non integers
    Dim ls_text     As String
    Dim lul_value   As ULong = pul_value
    ls_text = ""
    Do
        ' peel off the last digit, and put it on the front of the text
        ls_text   = fs_core_char( 48 + Cast( UByte , lul_value Mod 10 ) ) + ls_text       ' 48 = "0"
        lul_value = lul_value / 10
    Loop Until lul_value = 0
    Return ls_text
End Function


Sub s_core_wait_for_vblank()
    ' pause the CPU to save power until the next 20ms tick...
    Asm
        ei          ; enable interrupts to allow wake-up
        halt        ; wait for the jump to $0038
        di          ; disable interrupts again for total control
    End Asm
End Sub


Function fub_core_scan_key() As UByte
    ' looks at the keyboard once, right now, and returns the code of the key that is down, or 0 if there is none...
    ' ...it does not wait, s_core_get_key() is the routine that waits for a key
    ' it also sets gub_key_modifiers, to say whether caps shift and/or symbol shift are being held
    '
    ' how the keyboard is read:
    '   the 40 keys are wired as 8 rows of 5, and a row is chosen by which bit of the HIGH byte of the port address is 0...
    '   ...the low byte of the port address is always $FE, and nothing needs to be written to the port first...
    '   ...in the byte that comes back bits 0 to 4 are the five keys of that row, and a bit is 0 while its key is down.
    '       row 0   port $FEFE   caps shift, Z, X, C, V
    '       row 1   port $FDFE   A, S, D, F, G
    '       row 2   port $FBFE   Q, W, E, R, T
    '       row 3   port $F7FE   1, 2, 3, 4, 5
    '       row 4   port $EFFE   0, 9, 8, 7, 6
    '       row 5   port $DFFE   P, O, I, U, Y
    '       row 6   port $BFFE   enter, L, K, J, H
    '       row 7   port $7FFE   space, symbol shift, M, N, B
    '   every key therefore has an index of ( row * 5 ) + bit, from 0 to 39, e.g. caps shift is 0 and symbol shift is 36
    ' N.B: bAnd and bOr are the bitwise operators, a plain And or Or would only give true or false
    '
    ' what comes back:
    '   on its own a key gives the code in key_table_normal, i.e. lower case letters, digits, 13 for enter, 32 for space
    '   with symbol shift it gives the code in key_table_symbol, where that is not 0
    '   with caps shift a letter comes back in upper case, and these combinations give the traditional Spectrum editing keys...
    '       caps shift + 5, 6, 7, 8  =  left, down, up, right  (UW_KEY_LEFT etc.)
    '       caps shift + 0           =  8  (delete / backspace)
    '       caps shift + space       =  27 (break, which we treat as escape)
    '       caps shift + 1, 2, 3, 4  =  edit, caps lock, true video, inv video  (UW_KEY_EDIT etc.)
    '       caps shift + 9           =  graph
    '
    ' Ctrl:
    '   a Spectrum has no Ctrl key, so we use "extend" as our Ctrl, i.e. caps shift and symbol shift held together...
    '   ...while it is held a letter comes back as the classic control code, Ctrl-A = 1, Ctrl-B = 2 ... Ctrl-Z = 26,
    '   and gub_key_modifiers is set to MB_KEY_CTRL (and to nothing else), any other key comes back as its normal code...
    '   ...on its own it is just a modifier, like the shift keys, and gives 0
    '   how the user types Ctrl-A on each keyboard:
    '       a real Next keyboard     = hold EXTEND, press A
    '       a classic keyboard       = hold caps shift and symbol shift, press A
    '       a PS/2 keyboard          = hold the two keys that the Next treats as caps shift and symbol shift, press A...
    '                                  ...(one PS/2 key cannot be extend, the Next's key table allows a key one shift, not both)
    '       ZEsarUX                  = hold Tab, press A, or hold Shift and Ctrl together, press A...
    '                                  ...(ZEsarUX makes Tab extend, Shift caps shift, and both Ctrl and Alt symbol shift)
    '   N.B: several control codes are the same number as another key, e.g. Ctrl-H = 8 = delete, Ctrl-M = 13 = enter...
    '   ...so always look at MB_KEY_CTRL in gub_key_modifiers to tell them apart
    '
    ' which keyboards this works with:
    '   a classic 40 key Spectrum keyboard        = everything above, the special keys are typed as the combinations
    '   a real Next keyboard                      = the same, plus it has a dedicated key for each special key, and for ; " , .
    '   a PS/2 keyboard plugged into a Next       = the Next turns each of its keys into one of the above before we ever see it
    ' the Next's dedicated keys are read first, from nextreg $B0 and $B1, so they are recognised for what they are...
    ' ...(the Next also presses the matching combination in the 8 x 5 matrix for us, which is why the modifiers are
    ' reported as 0 for these keys, we cannot tell a real caps shift from the one the Next added)
    Dim lub_row , lub_bit , lub_mask , lub_bits     As UByte
    Dim lub_index , lub_found , lub_code            As UByte
    Dim lub_caps , lub_sym , lub_ctrl               As UByte
    Dim luw_row_bit , luw_port                      As UInteger

    ' first the Next keyboard's dedicated keys, in both registers a bit is 1 while its key is down...
    ' ...on anything that does not have these registers they read as 0, so this part simply finds nothing...
    ' ...(a reading of 255 would mean all eight keys at once, so that is treated as "not there" as well)
    Out A_NEXTREG_SELECT , UB_NEXTREG_EXT_KEYS_0
    lub_bits = In( A_NEXTREG_DATA )
    If lub_bits <> 0 And lub_bits <> 255 Then
        gub_key_modifiers = 0
        If ( lub_bits bAnd %00001000 ) <> 0 Then Return Cast( UByte , UW_KEY_UP )
        If ( lub_bits bAnd %00000100 ) <> 0 Then Return Cast( UByte , UW_KEY_DOWN )
        If ( lub_bits bAnd %00000010 ) <> 0 Then Return Cast( UByte , UW_KEY_LEFT )
        If ( lub_bits bAnd %00000001 ) <> 0 Then Return Cast( UByte , UW_KEY_RIGHT )
        If ( lub_bits bAnd %10000000 ) <> 0 Then Return 59      ' ;
        If ( lub_bits bAnd %01000000 ) <> 0 Then Return 34      ' "
        If ( lub_bits bAnd %00100000 ) <> 0 Then Return 44      ' ,
        If ( lub_bits bAnd %00010000 ) <> 0 Then Return 46      ' .
    End If
    lub_ctrl = false
    Out A_NEXTREG_SELECT , UB_NEXTREG_EXT_KEYS_1
    lub_bits = In( A_NEXTREG_DATA )
    If lub_bits = 255 Then lub_bits = 0
    ' the EXTEND key is our Ctrl, so it is noted as a modifier and is not a key in its own right...
    If ( lub_bits bAnd %00000001 ) <> 0 Then lub_ctrl = true
    lub_bits = lub_bits bAnd %11111110
    If lub_bits <> 0 Then
        gub_key_modifiers = 0
        If ( lub_bits bAnd %10000000 ) <> 0 Then Return 8       ' delete, the same code as caps shift + 0
        If ( lub_bits bAnd %00100000 ) <> 0 Then Return 27      ' break, the same code as caps shift + space
        If ( lub_bits bAnd %01000000 ) <> 0 Then Return Cast( UByte , UW_KEY_EDIT )
        If ( lub_bits bAnd %00000010 ) <> 0 Then Return Cast( UByte , UW_KEY_CAPS_LOCK )
        If ( lub_bits bAnd %00001000 ) <> 0 Then Return Cast( UByte , UW_KEY_TRUE_VIDEO )
        If ( lub_bits bAnd %00010000 ) <> 0 Then Return Cast( UByte , UW_KEY_INV_VIDEO )
        If ( lub_bits bAnd %00000100 ) <> 0 Then Return Cast( UByte , UW_KEY_GRAPH )
    End If

    ' now the 8 x 5 matrix that every keyboard has...
    lub_found   = 255       ' 255 = no key found yet
    lub_caps    = false
    lub_sym     = false
    luw_row_bit = 1
    For lub_row = 0 To 7
        ' build the port address for this row: the high byte is all 1s except for this row's bit, the low byte is $FE
        luw_port = ( ( 255 - luw_row_bit ) << 8 ) bOr $FE
        lub_bits = In( luw_port ) bAnd %00011111
        If lub_bits <> %00011111 Then
            lub_mask = 1
            For lub_bit = 0 To 4
                If ( lub_bits bAnd lub_mask ) = 0 Then
                    lub_index = ( lub_row * 5 ) + lub_bit
                    If lub_index = 0 Then
                        lub_caps = true
                    ElseIf lub_index = 36 Then
                        lub_sym = true
                    ElseIf lub_found = 255 Then
                        lub_found = lub_index       ' if several keys are down, the first one found wins
                    End If
                End If
                lub_mask = lub_mask << 1
            Next
        End If
        luw_row_bit = luw_row_bit << 1
    Next

    ' both shift keys together is extend, which is our Ctrl (the Next's EXTEND key presses both of them for us)...
    If lub_caps And lub_sym Then lub_ctrl = true

    gub_key_modifiers = 0
    If lub_ctrl Then
        gub_key_modifiers = MB_KEY_CTRL
    Else
        If lub_caps Then gub_key_modifiers = gub_key_modifiers bOr MB_KEY_SHIFT
        If lub_sym  Then gub_key_modifiers = gub_key_modifiers bOr MB_KEY_SYMBOL
    End If

    ' no ordinary key is down, only modifiers at most...
    If lub_found = 255 Then Return 0

    lub_code = Peek( @key_table_normal + lub_found )
    If lub_ctrl Then
        ' Ctrl + a letter gives the classic control code, Ctrl-A = 1 ... Ctrl-Z = 26, anything else keeps its normal code
        If lub_code >= 97 And lub_code <= 122 Then lub_code = lub_code - 96
        Return lub_code
    End If
    If lub_sym Then
        lub_index = Peek( @key_table_symbol + lub_found )
        If lub_index <> 0 Then lub_code = lub_index
    ElseIf lub_caps Then
        If lub_found = 19 Then                              ' caps shift + 5
            lub_code = Cast( UByte , UW_KEY_LEFT )
        ElseIf lub_found = 24 Then                          ' caps shift + 6
            lub_code = Cast( UByte , UW_KEY_DOWN )
        ElseIf lub_found = 23 Then                          ' caps shift + 7
            lub_code = Cast( UByte , UW_KEY_UP )
        ElseIf lub_found = 22 Then                          ' caps shift + 8
            lub_code = Cast( UByte , UW_KEY_RIGHT )
        ElseIf lub_found = 20 Then                          ' caps shift + 0
            lub_code = 8
        ElseIf lub_found = 35 Then                          ' caps shift + space
            lub_code = 27
        ElseIf lub_found = 15 Then                          ' caps shift + 1
            lub_code = Cast( UByte , UW_KEY_EDIT )
        ElseIf lub_found = 16 Then                          ' caps shift + 2
            lub_code = Cast( UByte , UW_KEY_CAPS_LOCK )
        ElseIf lub_found = 17 Then                          ' caps shift + 3
            lub_code = Cast( UByte , UW_KEY_TRUE_VIDEO )
        ElseIf lub_found = 18 Then                          ' caps shift + 4
            lub_code = Cast( UByte , UW_KEY_INV_VIDEO )
        ElseIf lub_found = 21 Then                          ' caps shift + 9
            lub_code = Cast( UByte , UW_KEY_GRAPH )
        ElseIf lub_code >= 97 And lub_code <= 122 Then      ' a letter, make it upper case
            lub_code = lub_code - 32
        End If
    End If
    ' for the special keys the caps shift was part of typing the key, not a modifier, so do not report it...
    ' ...this also makes a combination typed on a classic keyboard look exactly the same as the Next's dedicated key
    If lub_code = 8 Or lub_code = 27 Or lub_code >= 130 Then gub_key_modifiers = 0
    Return lub_code

    ' the two lookup tables, one byte per key, in key index order, i.e. five keys per row...
    ' ...they sit here, after the Return, so that they are part of the code and never run as instructions...
    ' ...(a Dim'd array would make the compiler put data in front of the code, which the core must not have)
key_table_normal:
    Asm
        defb   0, 122, 120,  99, 118    ; row 0: caps shift, z, x, c, v
        defb  97, 115, 100, 102, 103    ; row 1: a, s, d, f, g
        defb 113, 119, 101, 114, 116    ; row 2: q, w, e, r, t
        defb  49,  50,  51,  52,  53    ; row 3: 1, 2, 3, 4, 5
        defb  48,  57,  56,  55,  54    ; row 4: 0, 9, 8, 7, 6
        defb 112, 111, 105, 117, 121    ; row 5: p, o, i, u, y
        defb  13, 108, 107, 106, 104    ; row 6: enter, l, k, j, h
        defb  32,   0, 109, 110,  98    ; row 7: space, symbol shift, m, n, b
    End Asm
key_table_symbol:
    Asm
        defb   0,  58,  35,  63,  47    ; row 0: (caps shift), z = :   x = #   c = ?   v = /
        defb 126, 124,  92, 123, 125    ; row 1: a = ~   s = |   d = \   f = {   g = }
        defb  60,  62,  96,  60,  62    ; row 2: q = <   w = >   e = `   r = <   t = >
        defb  33,  64,  35,  36,  37    ; row 3: 1 = !   2 = @   3 = #   4 = $   5 = %
        defb  95,  41,  40,  39,  38    ; row 4: 0 = _   9 = )   8 = (   7 = '   6 = &
        defb  34,  59,   0,  93,  91    ; row 5: p = "   o = ;   i = none   u = ]   y = [
        defb   0,  61,  43,  45,  94    ; row 6: enter = none   l = =   k = +   j = -   h = ^
        defb   0,   0,  46,  44,  42    ; row 7: space = none   (symbol shift)   m = .   n = ,   b = *
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fs_core_key_name( pub_code As UByte , pub_modifiers As UByte ) As String
    ' turns a key code from fub_core_scan_key(), and the modifiers that came with it, into text for showing to the user...
    ' ...e.g. "a", "Shift-A", "Ctrl-A", "Enter", "Left", "#"
    Dim msg , add       As String

    msg = ""
    If ( pub_modifiers bAnd MB_KEY_CTRL )  <> 0 Then msg = msg + "Ctrl-"
    If ( pub_modifiers bAnd MB_KEY_SHIFT ) <> 0 Then msg = msg + "Shift-"
    If ( pub_modifiers bAnd MB_KEY_CTRL ) <> 0 And pub_code >= 1 And pub_code <= 26 Then
        msg = msg + fs_core_char( pub_code + 64 )       ' a control code, show it as its letter, 1 = "A"
    ElseIf pub_code >= 33 And pub_code <= 126 Then
        msg = msg + fs_core_char( pub_code )
    Else
        add = ""
        If pub_code = 27                                Then add = "ESC"
        If pub_code = 32                                Then add = "Space"
        If pub_code = 13                                Then add = "Enter"
        If pub_code = 8                                 Then add = "Backspace"
        If pub_code = Cast( UByte , UW_KEY_UP )         Then add = "Up"
        If pub_code = Cast( UByte , UW_KEY_DOWN )       Then add = "Down"
        If pub_code = Cast( UByte , UW_KEY_LEFT )       Then add = "Left"
        If pub_code = Cast( UByte , UW_KEY_RIGHT )      Then add = "Right"
        If pub_code = Cast( UByte , UW_KEY_EDIT )       Then add = "Edit"
        If pub_code = Cast( UByte , UW_KEY_CAPS_LOCK )  Then add = "Caps Lock"
        If pub_code = Cast( UByte , UW_KEY_TRUE_VIDEO ) Then add = "True Video"
        If pub_code = Cast( UByte , UW_KEY_INV_VIDEO )  Then add = "Inv Video"
        If pub_code = Cast( UByte , UW_KEY_GRAPH )      Then add = "Graph"
        If add = ""                                     Then add = "c" + fs_core_number( pub_code )
        msg = msg + add
    End If
    Return msg
End Function


Sub s_core_countdown( pub_x As UByte , pub_y As UByte , pub_stay_key As UByte , pub_flip_key As UByte )
    ' shows a countdown  5 4 3 2 1  at ( row , column ), one second per digit, and returns when it runs out...
    ' ...while it runs it watches the keyboard, the two keys are given as upper case character codes, e.g. 76 for "L":
    '   pub_stay_key held or pressed  =  start again from 5, i.e. stay for another five seconds
    '   pub_flip_key pressed          =  give up waiting and return straight away
    ' the name of the last key pressed, e.g. "Ctrl-A", is shown two cells to the right of the digit, and stays there
    ' until another key is pressed or the countdown ends, as a running test of the keyboard routine
    ' the timing comes from the frame interrupt, which arrives 50 times a second whatever speed the CPU is set to
    Dim lub_seconds         As UByte = 5
    Dim lub_ticks           As UByte = 0
    Dim lub_key             As UByte
    Dim lub_shown_key       As UByte = 0        ' the key, and its modifiers, whose name is on screen at the moment
    Dim lub_shown_modifiers As UByte = 0
    Do
        s_core_print_char_at( pub_x , pub_y , 48 + lub_seconds , UB_BRIGHT_WHITE )      ' 48 = "0"
        s_core_wait_for_vblank()

        lub_key = fub_core_scan_key()
        ' show the name of the key, but only when it changes, building the text 50 times a second would be wasteful
        If lub_key <> 0 Then
            If lub_key <> lub_shown_key Or gub_key_modifiers <> lub_shown_modifiers Then
                lub_shown_key       = lub_key
                lub_shown_modifiers = gub_key_modifiers
                s_core_print_string_at( pub_x , pub_y + 2 , "                " , UB_BLACK )       ' rub out the old name, 16 cells
                s_core_print_string_at( pub_x , pub_y + 2 , fs_core_key_name( lub_key , gub_key_modifiers ) , UB_BRIGHT_CYAN )
            End If
        End If

        ' the stay and flip keys are plain letters, a letter arrives in lower case unless caps shift is held,
        ' so make it upper case for the comparisons below (a Ctrl-letter is a control code, so it never matches)
        If lub_key >= 97 And lub_key <= 122 Then lub_key = lub_key - 32

        If lub_key = pub_flip_key And lub_key <> 0 Then Exit Do
        If lub_key = pub_stay_key And lub_key <> 0 Then
            lub_seconds = 5
            lub_ticks   = 0
        Else
            lub_ticks = lub_ticks + 1
            If lub_ticks = 50 Then
                lub_ticks   = 0
                lub_seconds = lub_seconds - 1
            End If
        End If
    Loop Until lub_seconds = 0
    s_core_print_char_at( pub_x , pub_y , 32 , UB_BLACK )                                        ' rub out the digit
    s_core_print_string_at( pub_x , pub_y + 2 , "                " , UB_BLACK )                   ' and the key name
End Sub


Sub s_core_monitor( pub_function As UByte )
    ' the live monitor, the last five rows of the screen, is a library of its own, stage-lib-monitor.bas, to keep it
    ' out of the core's own two pages, this draws it, or rubs it out
    ' N.B: whoever is waiting for a key may be a library in the middle of its own work, so the number of the routine
    ' it was asked for, which our call would overwrite, is put back
    Dim lub_function As UByte

    lub_function = gub_lib_function
    gub_core_monitor_page = gub_core_MMU3_page_number
    s_core_call_library( UB_PAGED_CODE_LIB_MONITOR , pub_function )
    gub_lib_function = lub_function
End Sub

Sub s_core_get_key()
    ' waits for a key to be pressed, and then fills in...
    '   guw_key_code        the code of the key, see fub_core_scan_key() for what the codes are, or 0 if nobody pressed anything for an hour
    '   gub_key_char        the same code as a byte
    '   gub_key_modifiers   MB_KEY_CTRL, MB_KEY_SHIFT and/or MB_KEY_SYMBOL if those were being held
    '   gs_key_astext       the key as text for showing to the user, e.g. "a", "Shift-A", "Ctrl-A", "Enter", "Left"
    Dim lub_code        As UByte
    Dim lul_frames      As ULong

    ' now wait for a new press, looking once per frame, i.e. 50 times a second...
    ' ...and give up after one hour: 60 minutes * 60 seconds * 50 frames = 180000 frames
    lul_frames = 0
    Do
        If gub_core_monitor Then s_core_monitor( UB_LIB_MONITOR_SHOW )

        ' wait for every key to be let go, so that a key still held from before is not taken as a new press...
        Do
            s_core_wait_for_vblank()
        Loop Until fub_core_scan_key() = 0

        Do
            s_core_wait_for_vblank()
            lub_code   = fub_core_scan_key()
            lul_frames = lul_frames + 1
            If lul_frames >= 180000 Then
                guw_key_code = 0        ' signal the timeout
                gub_key_char = 0
                Return
            End If
        Loop Until lub_code <> 0

        ' the ] key (symbol shift and U) is the core's own: it turns the live monitor on and off, whatever stage is
        ' running, and is never handed on, the wait simply carries on for the key the caller wanted, N.B: ] is no command
        ' in either of Moria's key sets, nor the wizard's, and it was the GRAPH key (caps shift and 9) until 16 October 2026,
        ' when the author chose ] (and [ for the mini map)
        If lub_code <> 93 Then Exit Do
        gub_core_monitor = Not gub_core_monitor
        If gub_core_monitor = 0 Then s_core_monitor( UB_LIB_MONITOR_CLEAR )
    Loop

    ' populate the shared structure (fub_core_scan_key() has already set gub_key_modifiers)
    ' nobody presses a key at exactly the same moment twice, so how long this wait took is stirred into the number that seeds a new game
    gul_core_entropy = gul_core_entropy * 33 + lul_frames

    guw_key_code  = lub_code
    gub_key_char  = lub_code
    gs_key_astext = fs_core_key_name( lub_code , gub_key_modifiers )
End Sub


Sub s_core_crash( pub_error_code As UByte , ps_error_text As String )
    Dim x                   As UByte
    Dim lub_error_row       As UByte
    Dim lub_error_col       As UByte
    Dim ls_error_message    As String
    Dim lub_max_length      As UByte = 78

    ' clear the last three lines...
    For x = 29 To 31
        s_core_clear_row( x , 0 , UB_BLACK )
    Next x

    ' construct the error message...
    ls_error_message = "error " + fs_core_number( pub_error_code ) + " : " + ps_error_text

    ' truncate if the message is too wide for the screen...
    If Len( ls_error_message ) > lub_max_length Then 
        ls_error_message = ls_error_message( To ( lub_max_length - 1 ) )
    End If

    ' calculate positions based on the final message length...
    lub_error_row = 30
    lub_error_col = ( 80 - Len( ls_error_message ) ) / 2

    ' display centered error message
    s_core_print_string_at( lub_error_row , lub_error_col , ls_error_message , UB_BRIGHT_RED )

    ' wait for key press...
    s_core_get_key()
    s_core_return_to_zxos()
End Sub


Sub s_core_swap_paged_data( pub_slot As UByte , pub_page_number As UByte )
    ' puts a page into one of the three paged data slots, pub_slot is 0, 1 or 2...
    '   slot 0 = MMU 0 = $0000 to $1FFF     monsters, corridors
    '   slot 1 = MMU 1 = $2000 to $3FFF     items, creatures
    '   slot 2 = MMU 2 = $4000 to $5FFF     maps, strings, objects
    ' ...and keeps count, exactly as s_core_swap_paged_code() does for the code slot, if the page is already there nothing is changed
    ' N.B: all in Z80, every record that is looked up comes through here, and every square of the map whose page is not there:
    ' the compiler has put the address of the parameters into IX, the slot is at ix+5 and the page at ix+7
    ' N.B: each slot has nine bytes in globals.bas, one after another from gub_core_MMU0_page_number: the page it holds, how
    ' often that was the page asked for (hits, four bytes) and how often it had to be changed (swaps, four bytes)
    Asm
        ; guard: there are only three data slots, any other number is ignored, it would remap the code, the data or the screen from under us
        ld a, (ix+5)
        cp 3
        jr nc, core_swap_data_end
        ld e, a                         ; E = the slot
        add a, a
        add a, a
        add a, a
        add a, e                        ; slot * 9
        ld l, a
        ld h, 0
        ld bc, _gub_core_MMU0_page_number
        add hl, bc                      ; HL = where the slot's own nine bytes are
        ld a, (ix+7)                    ; the page that is wanted
        cp (hl)
        jr nz, core_swap_data_fetch
        inc hl                          ; it is there already: one more hit
        call core_swap_data_count
        jr core_swap_data_end

    core_swap_data_fetch:
        ld (hl), a                      ; the page the slot holds from now on
        ld d, a                         ; D = the page
        ld a, e
        add a, $50                      ; the slot's Next register, $50 for MMU 0 (MMU_SLOT_0)
        ld bc, A_NEXTREG_SELECT
        out (c), a
        ld bc, A_NEXTREG_DATA
        out (c), d
        ld bc, 5
        add hl, bc                      ; past the page and the hits: one more swap
        call core_swap_data_count

        ; the third slot only: what kind of page it was that had to be fetched, for the live monitor, seven counts of
        ; four bytes, see A_CORE_MMU2_KINDS in globals.bas, the numbers are the UB_PAGE_ constants
        ld a, e
        cp 2
        jr nz, core_swap_data_end
        ld a, d
        ld c, 24                        ; anything else
        cp 89
        jr nc, core_swap_data_kind
        ld c, 0                         ; 66 to 88, the dungeon's map and the town's
        cp 66
        jr nc, core_swap_data_kind
        ld c, 24                        ; 64 and 65, the screens, count as anything else
        cp 64
        jr nc, core_swap_data_kind
        ld c, 20                        ; 63, what the player knows
        cp 63
        jr nc, core_swap_data_kind
        ld c, 16                        ; 55 to 62, the strings
        cp 55
        jr nc, core_swap_data_kind
        ld c, 12                        ; 53 and 54, the tables
        cp 53
        jr nc, core_swap_data_kind
        ld c, 8                         ; 50 to 52, the objects
        cp 50
        jr nc, core_swap_data_kind
        ld c, 4                         ; 47 to 49, the creatures
        cp 47
        jr nc, core_swap_data_kind
        ld c, 24
    core_swap_data_kind:
        ld b, 0
        ld hl, A_CORE_MMU2_KINDS
        add hl, bc
        call core_swap_data_count
        jr core_swap_data_end

    core_swap_data_count:               ; adds one to the four byte count at HL
        inc (hl)
        ret nz
        inc hl
        inc (hl)
        ret nz
        inc hl
        inc (hl)
        ret nz
        inc hl
        inc (hl)
        ret

    core_swap_data_end:
    End Asm
End Sub
Sub s_core_swap_paged_code( pub_page_number As UByte )
    If gub_core_MMU3_page_number = pub_page_number Then
        gul_core_MMU3_cache_hits = gul_core_MMU3_cache_hits + 1
    Else
        s_core_next_reg( MMU_SLOT_PAGED_CODE , pub_page_number )
        gub_core_MMU3_page_number = pub_page_number
        gul_core_MMU3_page_swaps  = gul_core_MMU3_page_swaps + 1
    End If
End Sub


Sub s_core_call_library( pub_page As UByte , pub_function As UByte )
    ' runs one routine of a library page: a page of code that any stage may use, something one stage cannot be to another...
    ' ...the stage that is running is in the code slot, so the library takes its place for the length of the call:
    ' the library's page goes into the slot, it is called, and the page that was there is put back before we return
    ' the routine wanted is passed in gub_lib_function, and anything it needs in gub_lib_param_1 and guw_lib_param_2,
    ' or in the working records, each library says at its top what it expects and what it gives back
    ' N.B: the page to go back to is kept on the stack, not in a fixed place, so a library may itself call a library
    Dim lub_caller As UByte

    lub_caller       = gub_core_MMU3_page_number
    gub_lib_function = pub_function
    s_core_swap_paged_code( pub_page )
    Asm
        call A_MMU_SLOT_PAGED_CODE
    End Asm
    s_core_swap_paged_code( lub_caller )
End Sub


Sub s_core_ram_copy( puw_src_address As UInteger, puw_dst_address As UInteger, puw_byte_count As UInteger )
    If puw_byte_count = 0 Then 
        Return 
    End If
    If puw_src_address < puw_dst_address Then
        If ( puw_src_address + puw_byte_count ) >= puw_dst_address Then
            s_core_crash( UB_CRASH_RAMCOPY_OVERLAP , "ramcopy buffer overlap: " + fs_core_number( puw_dst_address ) )
        End If
    End If
    guw_shared_1 = puw_src_address
    guw_shared_2 = puw_dst_address
    guw_shared_3 = puw_byte_count
    Asm
        ld hl, (_guw_shared_1)
        ld de, (_guw_shared_2)
        ld bc, (_guw_shared_3)
        ldir
    End Asm
End Sub


Function fub_core_file_transfer( ps_name As String , pub_page As UByte , pub_write As UByte ) As UByte
    ' saves one 8KB page to a file on the SD card, or loads one 8KB page from a file, this is the routine behind
    ' fub_core_file_save_page() and fub_core_file_load_page(), which are the two that other code should call
    ' returns 0 if it worked, otherwise an error number:
    '   1 to 250 = the error number that the system gave us, e.g. 5 means "no such file"
    '   254      = the file name was empty, or longer than 63 characters
    '   255      = the system reported no error, but fewer than 8192 bytes were read or written
    ' a file may hold many pages, one after another: gub_core_file_slot says which of them this call is for, the first
    ' is 0, and such a file is never emptied, a page is written over the one that was there, 255, as it usually is,
    ' means the file is one page and no more, and writing it replaces the whole file
    ' N.B: a file of many pages is WRITTEN from its first page to its last, in order, in one go: page 0 makes the file
    ' afresh, deleting any there was, and it is then kept open while the others follow, each going where the last
    ' ended, until a call with gub_core_file_slot = 254 closes it, which the caller must make, even after a failure...
    ' ...it used to be opened and closed for every page, "open it, or make it if it is not there", which NextZXOS
    ' does, but the ZEsarUX emulator, when it answers the file calls itself, empties a file every time it is opened
    ' for writing, however that is asked for, so a saved game came out all noughts but for its last page, found on
    ' 14 October 2026. Reading is as it was: any page of the file, opened, found and closed in the one call
    '
    ' how file access works on the Next:
    '   a file call is "rst $08" followed by one byte that says which call it is, with the details in registers...
    '   ...and NextZXOS will only answer it if its ROM is at the bottom of memory, where our three paged data slots are...
    '   ...so for the length of the call we lend those three slots back to the system, and then put our own pages back:
    '       MMU 0 and MMU 1 = the ROM
    '       MMU 2           = page 10, which holds the system's own variables
    '   everything of ours that has to survive is above that: this code (MMU 4 and 5), the core data (MMU 6), the stack (MMU 7)
    '   the page being saved or loaded is brought into MMU 3 at $6000 for the call, and the stage that was there is put back after
    '   the file name is copied into a small buffer inside this routine, i.e. in MMU 4 or 5, with a 0 on the end as the system expects
    ' N.B: because MMU 0, 1 and 2 are lent out, nothing in the paged data slots can be reached during the call,
    ' that is why this works in whole pages, the caller says which page and we fetch it ourselves
    Dim i , lub_length , lub_result As UByte

    If Len( ps_name ) = 0 Or Len( ps_name ) > 63 Then Return 254
    lub_length = Len( ps_name )
    For i = 0 To lub_length - 1
        Poke @core_file_name + i , Code( ps_name( i ) )
    Next
    Poke @core_file_name + lub_length , 0

    ' bring the page in question into MMU 3, and lend the bottom of memory to the system...
    ' N.B: file calls need the 48K BASIC ROM in particular, which is the ROM that is selected when a nex file is started,
    ' so we rely on that and do not select it ourselves... nextreg $8E can select it, but writing to $8E also puts
    ' the system's own pages back into MMU 6 and 7, i.e. it swaps our core data and our stack out from under us
    s_core_next_reg( MMU_SLOT_PAGED_CODE , pub_page )
    s_core_next_reg( MMU_SLOT_0 , 255 )         ' 255 = the ROM
    s_core_next_reg( MMU_SLOT_1 , 255 )
    s_core_next_reg( MMU_SLOT_2 , 10 )          ' page 10 = the system variables

    ' N.B: these are set here, and not earlier, because s_core_next_reg() uses the same shared scratch variables
    ' gub_core_file_plan says which of the steps below this call takes: 1 open the file, 2 seek, 4 close it afterwards,
    ' 8 no reading or writing at all
    If pub_write Then
        gub_shared_1 = $0E                      ' open for writing ($02), creating the file and deleting any existing one ($0C)
        If gub_core_file_slot = 255 Then
            gub_core_file_plan = 1 + 4          ' a file of one page: opened, written and closed
        ElseIf gub_core_file_slot = 254 Then
            gub_core_file_plan = 4 + 8          ' the file of many pages is finished with: closed, and nothing else
        ElseIf gub_core_file_slot = 0 Then
            gub_core_file_plan = 1              ' the first page of many: opened, written, and left open for the rest
        Else
            gub_core_file_plan = 0              ' a later page: written where the last one ended
        End If
    Else
        gub_shared_1 = $01                      ' open for reading ($01), the file must exist ($00)
        gub_core_file_plan = 1 + 4
        If gub_core_file_slot <> 255 Then gub_core_file_plan = 1 + 2 + 4
    End If
    gub_shared_4 = pub_write
    guw_shared_1 = A_MMU_SLOT_PAGED_CODE        ' where the page is, $6000
    guw_shared_2 = 8192                         ' how many bytes
    guw_shared_3 = 8192                         ' how many were read or written, set here for the call that only closes

    Asm
        push ix                     ; the compiler uses IX for this routine's own variables, and the calls want it for an address
        push iy
        ld iy, $5C3A                ; some system routines expect IY to point at the system variable ERR_NR

        ; F_OPEN: A = drive ("*" means the default drive), IX = the file name, B = how to open it
        ld a, (_gub_core_file_plan)
        and 1
        jr z, core_file_is_open
        ld a, (_gub_shared_1)
        ld b, a
        ld ix, core_file_name_asm
        ld a, 42                    ; "*"
        rst $08
        defb $9A
        jr c, core_file_failed      ; carry set = failed, with the error number in A
        ld (_gub_core_file_handle), a   ; otherwise A is the file handle, keep it
core_file_is_open:

        ; F_SEEK, to read one page of a file of many: A = the handle, BCDE = how far in, IXL = 0 for "from the start"
        ; the page wanted is gub_core_file_slot, 8192 bytes each, so BCDE = slot * $2000: D = the low 3 bits of the
        ; slot moved up 5, E = 0, C = the slot's other bits, B = 0
        ld a, (_gub_core_file_plan)
        and 2
        jr z, core_file_no_seek
        ld a, (_gub_core_file_slot)
        ld c, a
        and 7
        rrca
        rrca
        rrca
        ld d, a
        ld e, 0
        ld a, c
        srl a
        srl a
        srl a
        ld c, a
        ld b, 0
        ld ix, 0
        ld a, (_gub_core_file_handle)
        rst $08
        defb $9F
        jr c, core_file_close_failed
core_file_no_seek:
        ; F_READ or F_WRITE: A = the handle, IX = the address, BC = the number of bytes
        ld a, (_gub_core_file_plan)
        and 8
        jr nz, core_file_close_only
        ld ix, (_guw_shared_1)
        ld bc, (_guw_shared_2)
        ld a, (_gub_shared_4)
        or a
        ld a, (_gub_core_file_handle)
        jr nz, core_file_write
        rst $08
        defb $9D                    ; F_READ
        jr core_file_transferred
core_file_write:
        rst $08
        defb $9E                    ; F_WRITE
core_file_transferred:
        ld (_guw_shared_3), bc      ; BC = how many bytes were actually read or written
        jr c, core_file_close_failed    ; it failed: the file is closed whatever the plan was, and the failure reported
        ld a, (_gub_core_file_plan)
        and 4
        jr z, core_file_worked      ; a file of many pages is left open for its next page
core_file_close_only:
        ; F_CLOSE: A = the handle
        ld a, (_gub_core_file_handle)
        rst $08
        defb $9B
        jr c, core_file_failed
core_file_worked:
        xor a                       ; it all worked, 0 = no error
        jr core_file_finished
core_file_close_failed:
        push af                     ; the seek or the transfer failed: the file is closed, and that failure is what is reported
        ld a, (_gub_core_file_handle)
        rst $08
        defb $9B
        pop af
core_file_failed:
        or a                        ; make sure that a failure is never reported as 0
        jr nz, core_file_finished
        ld a, 255
core_file_finished:
        ld (_gub_shared_2), a
        di                          ; the system may have switched interrupts on, we keep them off
        pop iy
        pop ix
    End Asm
    lub_result = gub_shared_2

    ' take the bottom of memory back, each slot gets the page that s_core_swap_paged_data() last put there...
    ' ...255 means we never put one of our pages there, which for MMU 0 and 1 is the ROM, and for MMU 2 is page 10, as they already are
    s_core_next_reg( MMU_SLOT_0 , gub_core_MMU0_page_number )
    s_core_next_reg( MMU_SLOT_1 , gub_core_MMU1_page_number )
    If gub_core_MMU2_page_number <> 255 Then s_core_next_reg( MMU_SLOT_2 , gub_core_MMU2_page_number )
    ' ...and put back whichever stage was in MMU 3, it may well be the one that called us
    s_core_next_reg( MMU_SLOT_PAGED_CODE , gub_core_MMU3_page_number )

    If lub_result = 0 And guw_shared_3 <> 8192 Then lub_result = 255
    Return lub_result

    ' the file name, as the system wants it: the characters followed by a 0, this is 64 bytes set aside inside the code...
    ' ...it has to be somewhere that is still mapped in during the call, and that is not in the top two slots
core_file_name:
    Asm
core_file_name_asm:
        defs 64, 0
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_core_file_save_page( ps_name As String , pub_page As UByte ) As UByte
    ' saves the 8KB page pub_page to the file ps_name on the SD card, replacing any file of that name
    ' returns 0 if it worked, otherwise an error number, see fub_core_file_transfer()
    Return fub_core_file_transfer( ps_name , pub_page , true )
End Function


Function fub_core_file_load_page( ps_name As String , pub_page As UByte ) As UByte
    ' loads the file ps_name from the SD card into the 8KB page pub_page
    ' returns 0 if it worked, otherwise an error number, see fub_core_file_transfer()
    Return fub_core_file_transfer( ps_name , pub_page , false )
End Function


Sub s_core_nothing_to_return_to()
    ' the game is over, the machine was reset to hand it back to NextZXOS, and we are still here: this is an emulator
    ' whose reset does not start the Next again, see s_core_return_to_zxos(), which is how this is reached. Say so, and
    ' stop: the processor has been reset, so interrupts are off and stay off, nothing here may wait for one
    s_core_clear_screen()
    s_core_print_string_at( 14 , 31 , "ZXMoria has ended." , UB_BRIGHT_WHITE )
    s_core_print_string_at( 16 , 7 , "This emulator cannot go back to NextZXOS by itself: close it, or reset it," , UB_WHITE )
    s_core_print_string_at( 17 , 7 , "and start the game again to play on." , UB_WHITE )
    Asm
core_ended_for_good:
        di
        jr core_ended_for_good
    End Asm
End Sub

'##################################################################################################################################
' --- GAME ROUTINES ---

Sub s_core_random_seed( pul_seed As ULong )
    ' starts the random numbers off from a given seed, this is Moria's setRandomSeed()...
    ' ...the generator's value must be from 1 to 2147483646, so any seed at all is folded into that range
    gul_game_random_seed = ( pul_seed Mod 2147483646 ) + 1
End Sub


Sub s_core_random_step()
    ' moves the random numbers on by one: the seed becomes ( 16807 * the seed ) mod 2147483647, the "minimal standard"
    ' generator of Park and Miller, which is what Moria's rnd() works out, so this gives exactly the same sequence of numbers
    ' Moria does it with divisions (Schrage's method) because C has no 48 bit numbers, here the multiplication is done in full,
    ' using the Next's own multiply instruction, and then the mod is nearly free because 2147483647 is 2 to the power 31, less 1:
    ' the answer is the low 31 bits of the product plus everything above them, less 2147483647 if that has reached it
    ' N.B: started from a seed value of 1, the 10,000th number must be 1043618065, the start up tests checked exactly that
    ' until they were taken out on 14 October 2026, and the same seed now gives the same characters and objects as Umoria
    Asm
        ; clear the 48 bit product
        ld hl, 0
        ld (_gul_game_rnd_work_lo), hl
        ld (_gul_game_rnd_work_lo + 2), hl
        ld (_guw_game_rnd_work_hi), hl

        ; 16807 is $41A7: add in the seed * $A7, then the seed * $41 one byte further up
        ld c, $A7
        ld hl, _gul_game_rnd_work_lo
        call core_random_row
        ld c, $41
        ld hl, _gul_game_rnd_work_lo + 1
        call core_random_row
        jr core_random_fold

    core_random_row:                    ; adds the four bytes of the seed, each times C, into the product starting at HL
        exx
        ld hl, _gul_game_random_seed
        ld b, 4
        exx
    core_random_byte:
        exx
        ld a, (hl)
        inc hl
        exx
        ld d, a
        ld e, c
        mul d, e                        ; DE = D * E, a Next instruction
        push hl
        ld a, (hl)
        add a, e
        ld (hl), a
        inc hl
        ld a, (hl)
        adc a, d
        ld (hl), a
        jr nc, core_random_no_carry
    core_random_carry:
        inc hl
        inc (hl)
        jr z, core_random_carry
    core_random_no_carry:
        pop hl
        inc hl
        exx
        dec b
        exx
        jr nz, core_random_byte
        ret

    core_random_fold:
        ; DE = everything above bit 30 of the product, it is at most 15 bits
        ld a, (_gul_game_rnd_work_lo + 3)
        add a, a                        ; bit 31 into the carry
        ld a, (_guw_game_rnd_work_hi)
        rla
        ld e, a
        ld a, (_guw_game_rnd_work_hi + 1)
        rla
        ld d, a
        ; add that to the low 31 bits
        ld hl, (_gul_game_rnd_work_lo)
        add hl, de
        ld (_gul_game_random_seed), hl
        ld hl, (_gul_game_rnd_work_lo + 2)
        res 7, h
        ld de, 0
        adc hl, de
        ; if that has reached 2147483648 or more then take off 2147483647, i.e. clear the top bit and add 1
        bit 7, h
        jr z, core_random_store
        res 7, h
        ex de, hl
        ld hl, (_gul_game_random_seed)
        inc hl
        ld (_gul_game_random_seed), hl
        ld a, h
        or l
        ex de, hl
        jr nz, core_random_store
        inc hl
    core_random_store:
        ld (_gul_game_random_seed + 2), hl
    End Asm
End Sub


Function ful_core_random() As ULong
    ' the next random number, from 1 to 2147483646, this is Moria's rnd()
    s_core_random_step()
    Return gul_game_random_seed
End Function


Function ful_core_random_number( pul_max As ULong ) As ULong
    ' a random number from 1 to pul_max, this is Moria's randomNumber(): ( the next random number mod pul_max ) + 1
    If pul_max = 0 Then Return 0        ' guard: there is no such number, and the division below would never end well
    s_core_random_step()
    ' a range too big for 16 bits is rare (large sums of gold), the compiler's own 32 bit division will do for those
    If pul_max > 65535 Then Return ( gul_game_random_seed Mod pul_max ) + 1

    ' the usual case, the remainder of a 32 bit number divided by a 16 bit one, by long division a bit at a time
    guw_game_rnd_max = Cast( UInteger , pul_max )
    Asm
        ld de, (_guw_game_rnd_max)
        exx
        ld hl, (_gul_game_random_seed)          ; the number being divided is in DE' and HL'
        ld de, (_gul_game_random_seed + 2)
        exx
        ld hl, 0                                ; the remainder so far
        ld b, 32
    core_random_divide:
        exx
        add hl, hl                              ; the next bit of the number, from the top, into the carry...
        ex de, hl
        adc hl, hl
        ex de, hl
        exx
        adc hl, hl                              ; ...and from there into the bottom of the remainder
        jr c, core_random_take                  ; too big for 16 bits, so certainly bigger than the divisor
        sbc hl, de
        jr nc, core_random_next
        add hl, de                              ; it did not go, put it back
        jr core_random_next
    core_random_take:
        or a
        sbc hl, de
    core_random_next:
        djnz core_random_divide
        ld (_guw_game_rnd_result), hl
    End Asm
    Return Cast( ULong , guw_game_rnd_result ) + 1
End Function

Sub s_core_seeds_initialize( pul_seed As ULong )
    ' starts a new game's random numbers off, this is Moria's seedsInitialize(): the two fixed seeds, for the flavours of the
    ' magic items and for the town, then the generator itself, which is then run on a random number of times
    Dim lul_count As ULong

    gul_game_magic_seed = pul_seed
    pul_seed            = pul_seed + 8762
    gul_game_town_seed  = pul_seed
    pul_seed            = pul_seed + 113452
    s_core_random_seed( pul_seed )
    lul_count = ful_core_random_number( 100 )
    While lul_count <> 0
        s_core_random_step()
        lul_count = lul_count - 1
    End While
End Sub


Function fsw_core_random_normal( psw_mean As Integer , psw_standard As Integer ) As Integer
    ' a random number from a normal distribution with the given mean and standard deviation, this is Moria's
    ' randomNumberNormalDistribution(), it looks its number up in a table of 256 entries by halving the search each time
    Dim luw_tmp , luw_low , luw_index , luw_high , luw_entry    As UInteger
    Dim lsw_offset                                              As Integer

    luw_tmp = Cast( UInteger , ful_core_random_number( 32767 ) )

    ' off the end of the table: a value between 4 and 5 standard deviations away, half of them below the mean
    If luw_tmp = 32767 Then
        lsw_offset = 4 * psw_standard + Cast( Integer , ful_core_random_number( Cast( ULong , psw_standard ) ) )
        If ful_core_random_number( 2 ) = 1 Then lsw_offset = -lsw_offset
        Return psw_mean + lsw_offset
    End If

    luw_low   = 0
    luw_index = 128
    luw_high  = 256
    Do
        luw_entry = Peek( UInteger , A_NORMAL_TABLE + ( luw_index << 1 ) )
        If luw_entry = luw_tmp Then Exit Do
        If luw_high = luw_low + 1 Then Exit Do
        If luw_entry > luw_tmp Then
            luw_high  = luw_index
            luw_index = luw_low + ( ( luw_index - luw_low ) >> 1 )
        Else
            luw_low   = luw_index
            luw_index = luw_index + ( ( luw_high - luw_index ) >> 1 )
        End If
    Loop
    ' the search can end one below the target
    If Peek( UInteger , A_NORMAL_TABLE + ( luw_index << 1 ) ) < luw_tmp Then luw_index = luw_index + 1

    ' the table is for a standard deviation of 64, so scale to the one asked for, rounding the half way case up
    lsw_offset = ( psw_standard * Cast( Integer , luw_index ) + 32 ) / 64
    If ful_core_random_number( 2 ) = 1 Then lsw_offset = -lsw_offset
    Return psw_mean + lsw_offset
End Function


Function fuw_core_dice_roll( pub_dice As UByte , pub_sides As UByte ) As UInteger
    ' rolls pub_dice dice of pub_sides sides each and adds them up, e.g. 3 , 8 for 3d8, this is Moria's diceRoll()
    Dim i           As UByte
    Dim luw_total   As UInteger = 0

    If pub_dice = 0 Then Return 0
    For i = 1 To pub_dice
        luw_total = luw_total + Cast( UInteger , ful_core_random_number( pub_sides ) )
    Next
    Return luw_total
End Function


Function fuw_core_record_address( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger ) As UInteger
    ' finds one 64 byte record in the paged data: pages it in, and returns the address at which it can now be read and written...
    ' ...pub_slot is the paged data slot to use (UB_SLOT_...), pub_first_page is the first page of that kind of record (UB_PAGE_...),
    ' and puw_index is the number of the record, counting from 0
    ' there are 128 records to a page, so the page is the first page + ( index / 128 ), and the record starts ( index mod 128 ) * 64 bytes into it
    ' N.B: the address is only good until something else is paged into the same slot
    ' N.B: all in Z80, the monsters' turn calls this for every monster, creature and item it touches: the compiler has put the
    ' address of the parameters into IX, the slot is at ix+5, the first page at ix+7 and the index at ix+8 (low) and ix+9 (high)
    Asm
        ; the page: first page + index / 128, and index / 128 is the high byte of index * 2
        ld l, (ix+8)
        ld h, (ix+9)
        add hl, hl
        ld a, h
        add a, (ix+7)
        push af                         ; the page, the second parameter of s_core_swap_paged_data(), goes on first
        ld a, (ix+5)
        push af                         ; the slot, its first
        call _s_core_swap_paged_data

        ; the address: slot * 8192 + ( index mod 128 ) * 64
        ld a, (ix+8)
        and 127
        ld h, a
        ld l, 0                         ; HL = ( index mod 128 ) * 256...
        srl h
        rr l
        srl h
        rr l                            ; ...and a quarter of that is * 64
        ld a, (ix+5)
        rrca
        rrca
        rrca                            ; slot * 32, which is the high byte of slot * 8192, N.B: the slot is 0, 1 or 2
        add a, h
        ld h, a
        jp _fuw_core_record_address__leave      ; the answer is in HL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function

Sub s_core_fetch_record( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger , puw_address As UInteger )
    ' copies one 64 byte record out of the paged data to puw_address, which will normally be one of the working copies
    ' in the core data page, e.g. s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , 17 , A_CREATURE )
    s_core_ram_copy( fuw_core_record_address( pub_slot , pub_first_page , puw_index ) , puw_address , UB_RECORD_SIZE )
End Sub


Sub s_core_store_record( pub_slot As UByte , pub_first_page As UByte , puw_index As UInteger , puw_address As UInteger )
    ' the other way: copies the 64 bytes at puw_address into the paged data
    s_core_ram_copy( puw_address , fuw_core_record_address( pub_slot , pub_first_page , puw_index ) , UB_RECORD_SIZE )
End Sub


Function fuw_core_map_square( pub_first_page As UByte , pub_row As UByte , pub_col As UByte ) As UInteger
    ' finds one square of a map: pages it in, and returns the address of its 8 bytes...
    ' ...pub_first_page says which map, UB_PAGE_DUNGEON_MAP or UB_PAGE_TOWN_MAP, the maps always use the third data slot, MMU 2
    ' a row is 256 squares of 8 bytes = 2048 bytes, so there are 4 rows to a page: the page is the first page + ( row / 4 ),
    ' and the square starts ( row mod 4 ) * 2048 + col * 8 bytes into it
    ' N.B: the address is only good until something else is paged into MMU 2, which the databases and the strings also use
    ' N.B: nearly every call finds the page already there (a row never leaves its page, and 4 rows share one), so that case
    ' is dealt with right here, and s_core_swap_paged_data() is only called when the page really does have to change
    ' N.B: all in Z80, this is called for almost every square of the map that anything looks at: the compiler has put the
    ' address of the parameters into IX, the first page is at ix+5, the row at ix+7 and the column at ix+9
    Asm
        ; the page: first page + row / 4
        ld a, (ix+7)
        srl a
        srl a
        add a, (ix+5)
        ld hl, _gub_core_MMU2_page_number
        cp (hl)
        jr nz, core_map_square_fetch

        ; it is there already: one more hit, a four byte count
        ld hl, _gul_core_MMU2_cache_hits
        inc (hl)
        jr nz, core_map_square_there
        inc hl
        inc (hl)
        jr nz, core_map_square_there
        inc hl
        inc (hl)
        jr nz, core_map_square_there
        inc hl
        inc (hl)
        jr core_map_square_there

    core_map_square_fetch:
        push af                         ; the page, the second parameter of s_core_swap_paged_data(), goes on first
        ld a, 2                         ; UB_SLOT_DB_MAPS, its first
        push af
        call _s_core_swap_paged_data

    core_map_square_there:
        ; the address: $4000 + ( row mod 4 ) * 2048 + column * 8
        ld l, (ix+9)
        ld h, 0
        add hl, hl
        add hl, hl
        add hl, hl                      ; HL = column * 8, 2040 at most, so H is 7 at most
        ld a, (ix+7)
        and 3
        add a, a
        add a, a
        add a, a                        ; ( row mod 4 ) * 8, which is the high byte of ( row mod 4 ) * 2048
        add a, $40                      ; the high byte of A_MMU_SLOT_PAGED_DB_MAPS, $4000
        add a, h
        ld h, a
        jp _fuw_core_map_square__leave  ; the answer is in HL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function

Sub s_core_message_push()
    ' the message that was showing goes into the history, Moria's messages[], the last 22 of them are kept, 80
    ' bytes each, in a page of their own, as a ring: gub_log_next is where the next one will go
    Dim lub_saved   As UByte
    Dim luw_at      As UInteger
    Dim i           As UByte

    lub_saved = gub_core_MMU1_page_number
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_MESSAGES )
    luw_at = A_MMU_SLOT_1 + Cast( UInteger , gub_log_next ) * 80
    For i = 0 To 79
        If i < gub_log_length Then
            Poke luw_at + i , Peek( A_MESSAGE_LINE + i )
        Else
            Poke luw_at + i , 0
        End If
    Next
    gub_log_next = gub_log_next + 1
    If gub_log_next >= UB_MESSAGE_HISTORY Then gub_log_next = 0
    If gub_log_count < UB_MESSAGE_HISTORY Then gub_log_count = gub_log_count + 1
    gub_log_length = 0
    If lub_saved <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved )
End Sub


Sub s_core_print_char_at_logged( pub_x As UByte , pub_y As UByte , pub_char As UByte , pub_colour As UByte )
    ' what the stages and libraries reach through the jump table: s_core_print_char_at(), after a look at whether
    ' this is part of a message, so that the last messages can be shown again, Moria's Ctrl-P
    ' a message is written on the top row a character at a time in bright white (s_msg_text() in
    ' stage-message-include.bas), and the row is wiped with plain white spaces from its first column before the
    ' next one (s_msg_clear()), so: bright white on the top row is kept, and a plain space at its first column
    ' says the message that was there is finished with
    ' N.B: no page of code had to grow for this, which is why it is done here and not in s_msg_text() itself
    If pub_x = 0 Then
        If pub_colour = UB_BRIGHT_WHITE Then
            ' N.B: a message ends a command that is being repeated, as Moria's printMessage() does
            guw_game_command_count = 0
            If pub_y < 80 Then
                Poke A_MESSAGE_LINE + pub_y , pub_char
                If pub_y >= gub_log_length Then gub_log_length = pub_y + 1
            End If
        ElseIf pub_y = 0 And gub_log_length <> 0 Then
            s_core_message_push()
        End If
    End If
    s_core_print_char_at( pub_x , pub_y , pub_char , pub_colour )
End Sub


'##################################################################################################################################
' --- THE MAP AS THE PLAYER SEES IT ---
' the map shows only what the player has seen or can see, a square appears when it is lit, permanently or by the
' player's own light, or when the thing on it has been found, and a monster appears while the player can see it
' N.B: these used to be compiled into every page that draws the map, thirteen of them, a page reaches them now
' through the jump table, by the names it always used, fub_cr_symbol() and so on, see stage-map-include.bas

Function fuw_core_map_at( pub_y As UByte , pub_x As UByte ) As UInteger
    Return fuw_core_map_square( gub_level_map_page , pub_y , pub_x )
End Function


Function fub_core_map_item_category( pub_item As UByte ) As UByte
    ' the category of one of the level's items, read straight from its record
    Return Peek( fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item ) + UB_ITEM_CATEGORY_OFFSET )
End Function


Function fub_core_map_symbol( pub_y As UByte , pub_x As UByte ) As UByte
    ' what the player sees on one square of the map, Moria's caveGetTileSymbol(): themselves, then a monster they can
    ' see, then nothing at all unless the square is lit or what is on it has been found, then whatever lies there,
    ' then floor or wall
    ' N.B: Moria draws magma and quartz as ordinary wall unless an option says otherwise, so do we, see below
    Dim luw_square , luw_record                             As UInteger
    Dim lub_flags , lub_item , lub_feature , lub_monster    As UByte

    gub_map_is_monster = false
    luw_square  = fuw_core_map_at( pub_y , pub_x )
    lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
    ' N.B: a running player is not drawn, unless they have asked to be, Moria's run_print_self
    If lub_monster = 1 Then
        If gub_game_running = 0 Or ( guw_game_options bAnd MW_OPTION_PRINT_SELF ) <> 0 Then Return Code( "@" )
    End If
    If ( gul_player_status bAnd UL_PY_BLIND ) <> 0 Then Return 32
    ' a hallucinating player sees nonsense now and then, one square in twelve, N.B: as in Moria the dice are
    ' thrown only while they are hallucinating
    If gsw_player_image > 0 Then
        If ful_core_random_number( 12 ) = 1 Then Return ful_core_random_number( 95 ) + 31
    End If

    lub_flags   = Peek( luw_square + UB_SQUARE_FLAGS )
    lub_item    = Peek( luw_square + UB_SQUARE_ITEM )
    lub_feature = Peek( luw_square + UB_SQUARE_FEATURE )

    If lub_monster > 1 Then
        luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
        If Peek( luw_record + UB_MONSTER_LIT_OFFSET ) Then
            gub_map_is_monster = true
            Return Peek( luw_record + UB_MONSTER_SPRITE_OFFSET )
        End If
    End If

    If ( lub_flags bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_FIELD_MARK ) ) = 0 Then Return 32

    If lub_item <> 0 Then
        luw_record = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item )
        If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> UB_TV_INVIS_TRAP Then Return Peek( luw_record + UB_ITEM_SPRITE_OFFSET )
    End If
    If lub_feature <= UB_TILE_BLOCKED_FLOOR Then Return Code( "." )
    ' magma and quartz are drawn as % if the player has asked for the mineral seams to be shown
    If lub_feature = UB_TILE_MAGMA_WALL Or lub_feature = UB_TILE_QUARTZ_WALL Then
        If ( guw_game_options bAnd MW_OPTION_SEAMS ) <> 0 Then Return UC_CHAR_WALL_DIG
    End If
    Return Code( "#" )
End Function


Function fub_core_map_inside_panel( pub_y As UByte , pub_x As UByte ) As UByte
    ' Moria's coordInsidePanel()
    If pub_y < gub_panel_top Or pub_y > gub_panel_bottom Then Return false
    If pub_x < gub_panel_left Or pub_x > gub_panel_right Then Return false
    Return true
End Function


Sub s_core_map_put( pub_y As UByte , pub_x As UByte )
    ' draws one square of the map, if it is in the window, Moria's dungeonLiteSpot()
    ' N.B: Moria has no colours, these are ours: monsters red, the player green, the stairs magenta, things lying about cyan...
    Dim lub_symbol , lub_colour As UByte

    If fub_core_map_inside_panel( pub_y , pub_x ) = false Then Return
    lub_symbol = fub_core_map_symbol( pub_y , pub_x )
    If gub_map_is_monster Then
        lub_colour = UB_BRIGHT_RED
    Else
        lub_colour = UB_BRIGHT_CYAN                         ' things lying about
        If lub_symbol = Code( "@" ) Then lub_colour = UB_BRIGHT_GREEN         ' the player
        If lub_symbol = Code( "#" ) Or lub_symbol = UC_CHAR_WALL_DIG Then lub_colour = UB_WHITE
        If lub_symbol = Code( "." ) Then lub_colour = UB_DARK_GREY
        If lub_symbol = Code( "<" ) Or lub_symbol = Code( ">" ) Then lub_colour = UB_BRIGHT_MAGENTA   ' the stairs, the one bright colour nothing else on the map has
        If lub_symbol >= Code( "1" ) And lub_symbol <= Code( "6" ) Then lub_colour = UB_BRIGHT_YELLOW
    End If
    s_core_print_char_at( pub_y - gub_panel_top + UB_VIEW_SCREEN_ROW , pub_x - gub_panel_left + UB_VIEW_SCREEN_COL , lub_symbol , lub_colour )
End Sub


Sub s_core_map_light_room( pub_y As UByte , pub_x As UByte )
    ' lights up the room the given square is in, Moria's dungeonLightRoom(): rooms are built on a grid of half windows,
    ' 11 rows by 33 columns, so "the room" is every square of that part of the grid that was marked as lit room when
    ' the level was made, dark floor in it becomes lit floor, and doors and stairs in it are found
    Dim lub_top , lub_left , y , x          As UByte
    Dim luw_square                          As UInteger
    Dim lub_flags , lub_item , lub_category As UByte

    lub_top  = ( pub_y / ( UB_VIEW_ROWS / 2 ) ) * ( UB_VIEW_ROWS / 2 )
    lub_left = ( pub_x / ( UB_VIEW_COLS / 2 ) ) * ( UB_VIEW_COLS / 2 )
    For y = lub_top To lub_top + UB_VIEW_ROWS / 2 - 1
        For x = lub_left To lub_left + UB_VIEW_COLS / 2 - 1
            luw_square = fuw_core_map_at( y , x )
            lub_flags  = Peek( luw_square + UB_SQUARE_FLAGS )
            If ( lub_flags bAnd MB_SQUARE_LIT_ROOM ) <> 0 And ( lub_flags bAnd MB_SQUARE_PERM_LIGHT ) = 0 Then
                lub_flags = lub_flags bOr MB_SQUARE_PERM_LIGHT
                If Peek( luw_square + UB_SQUARE_FEATURE ) = UB_TILE_DARK_FLOOR Then Poke luw_square + UB_SQUARE_FEATURE , UB_TILE_LIGHT_FLOOR
                ' the room's walls are remembered now, the mini map is made again before it is next drawn, ours
                gub_minimap_rebuild = true
                lub_item = Peek( luw_square + UB_SQUARE_ITEM )
                Poke luw_square + UB_SQUARE_FLAGS , lub_flags
                If ( lub_flags bAnd MB_SQUARE_FIELD_MARK ) = 0 And lub_item <> 0 Then
                    lub_category = fub_core_map_item_category( lub_item )
                    If lub_category >= UB_TV_VIS_TRAP And lub_category <= UB_TV_STORE_DOOR Then
                        luw_square = fuw_core_map_at( y , x )
                        Poke luw_square + UB_SQUARE_FLAGS , lub_flags bOr MB_SQUARE_FIELD_MARK
                    End If
                End If
                s_core_map_put( y , x )
            End If
        Next
    Next
End Sub


Sub s_core_map_draw_panel()
    ' draws the whole window, Moria's drawDungeonPanel()
    Dim y , x As UByte

    For y = gub_panel_top To gub_panel_bottom
        For x = gub_panel_left To gub_panel_right
            If y < gub_dungeon_rows And x < gub_dungeon_cols Then
                s_core_map_put( y , x )
            Else
                s_core_print_char_at( y - gub_panel_top + UB_VIEW_SCREEN_ROW , x - gub_panel_left + UB_VIEW_SCREEN_COL , 32 , UB_WHITE )
            End If
        Next
    Next
End Sub


Function fub_core_map_outside_panel( pub_y As UByte , pub_x As UByte , pub_force As UByte ) As UByte
    ' moves the window if the given square is within 2 rows or 3 columns of its edge, or outside it altogether,
    ' true if the window moved and so needs drawing again, Moria's coordOutsidePanel() and panelBounds()
    Dim lsw_row , lsw_col As Integer

    lsw_row = gsb_panel_row
    lsw_col = gsb_panel_col
    If pub_force Or Cast( Integer , pub_y ) < Cast( Integer , gub_panel_top ) + 2 Or Cast( Integer , pub_y ) > Cast( Integer , gub_panel_bottom ) - 2 Then
        ' N.B: >> and not / 4: the compiler works out 22 / 4 as 5.5, Moria's C as 5, and a player on row 16 (or 5, 27,
        ' 38, 49, 60) got the window above Moria's, which also changes which monsters are in sight and so what they do
        ' (found 15 October 2026 by comparing a level with Umoria's, tools\test\compare-level.ps1), the same for 66 / 4
        lsw_row = ( Cast( Integer , pub_y ) - ( UB_VIEW_ROWS >> 2 ) ) / ( UB_VIEW_ROWS >> 1 )
        If lsw_row > gsb_panel_max_rows Then lsw_row = gsb_panel_max_rows
        If lsw_row < 0 Then lsw_row = 0
    End If
    If pub_force Or Cast( Integer , pub_x ) < Cast( Integer , gub_panel_left ) + 3 Or Cast( Integer , pub_x ) > Cast( Integer , gub_panel_right ) - 3 Then
        lsw_col = ( Cast( Integer , pub_x ) - ( UB_VIEW_COLS >> 2 ) ) / ( UB_VIEW_COLS >> 1 )
        If lsw_col > gsb_panel_max_cols Then lsw_col = gsb_panel_max_cols
        If lsw_col < 0 Then lsw_col = 0
    End If

    If lsw_row = gsb_panel_row And lsw_col = gsb_panel_col Then Return false
    gsb_panel_row    = lsw_row
    gsb_panel_col    = lsw_col
    gub_panel_top    = lsw_row * ( UB_VIEW_ROWS / 2 )
    gub_panel_bottom = gub_panel_top + UB_VIEW_ROWS - 1
    gub_panel_left   = lsw_col * ( UB_VIEW_COLS / 2 )
    gub_panel_right  = gub_panel_left + UB_VIEW_COLS - 1
    Return true
End Function


'##################################################################################################################################
' --- THE MESSAGE LINE ---
' the top row of the screen, Moria's printMessage(): a message stays until the next one comes, short ones are put
' side by side on the row, and when there is no room "-more-" is put after what is showing and a key is waited for
' N.B: these too used to be compiled into every page that talks to the player, see stage-message-include.bas

Sub s_core_msg_clear()
    ' blanks the message line, Moria's messageLineClear()
    ' N.B: through the same door as a stage's characters, so that the message that was there is remembered for
    ' Ctrl-P, see s_core_print_char_at_logged()
    ' N.B: the message that was there is put away for Ctrl-P as the row is cleared, see s_core_clear_row()
    s_core_clear_row( 0 , 0 , UB_WHITE )
    gub_message_length = 0
End Sub


Sub s_core_msg_more()
    ' " -more-" after the message that is showing, and the wait for the player to have read it: SPACE, ESCAPE or
    ' ENTER, nothing else will do, as in Moria
    ' N.B: gub_message_length is how long the message showing is, and Moria puts -more- one column further on
    Dim lub_col As UByte

    lub_col = gub_message_length + 1
    If lub_col > 73 Then lub_col = 73
    s_core_print_string_at( 0 , lub_col , " -more-" , UB_BRIGHT_YELLOW )
    Do
        s_core_get_key()
    Loop Until gub_key_char = 32 Or gub_key_char = 27 Or gub_key_char = 13 Or guw_key_code = 0
End Sub


Sub s_core_msg_flush()
    ' if a message is showing, waits for the player to have read it, and clears it, Moria's printMessage( CNIL )
    If gub_message_length = 0 Then Return
    s_core_msg_more()
    s_core_msg_clear()
End Sub


Sub s_core_msg_text( puw_address As UInteger )
    ' shows the text at puw_address, bytes ending in a 0, as a message, Moria's printMessage():
    '   - if no message is showing it goes at the start of the top row
    '   - if one is, and the two are short enough, the new one goes after it on the same row, and the two are
    '     remembered as one message
    '   - otherwise -more- is put after the one that is showing, a key is waited for, and the new one takes its place
    ' N.B: bright white on the top row is what makes it a message, it is remembered for Ctrl-P, and it ends a
    ' command that is being repeated, see s_core_print_char_at_logged()
    Dim lub_length , lub_col , i As UByte

    ' a message is cut to 79 characters, as Moria's messageLinePrintMessage() cuts it
    lub_length = 0
    While Peek( puw_address + lub_length ) <> 0 And lub_length < 79
        lub_length = lub_length + 1
    End While

    lub_col = 0
    If gub_message_length <> 0 Then
        If Cast( UInteger , lub_length ) + gub_message_length + 3 >= 73 Then
            s_core_msg_more()
            s_core_msg_clear()
        Else
            ' the two together: Moria puts the new one three columns on from where it reckons the old one ends
            lub_col = gub_message_length + 3
        End If
    Else
        s_core_msg_clear()
    End If
    If lub_length = 0 Then Return
    For i = 0 To lub_length - 1
        s_core_print_char_at_logged( 0 , lub_col + i , Peek( puw_address + i ) , UB_BRIGHT_WHITE )
    Next
    If lub_col = 0 Then
        gub_message_length = lub_length
    Else
        ' N.B: as Moria reckons it, the old message, two spaces, and the new one
        gub_message_length = gub_message_length + 2 + lub_length
    End If
End Sub

Sub s_core_msg( ps_text As String )
    ' shows a message
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    i = 0
    While i < lub_length
        Poke A_TEXT_BUFFER + i , Code( ps_text( i ) )
        i = i + 1
    End While
    Poke A_TEXT_BUFFER + lub_length , 0
    s_core_msg_text( A_TEXT_BUFFER )
End Sub


Function fub_core_lib_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of a library's routines, given its two parameters, with its answer as true or false, N.B: a page's own
    ' fub_xx_call() is this
    gub_lib_param_1 = pub_param
    guw_lib_param_2 = puw_param
    s_core_call_library( pub_page , pub_function )
    If gsw_lib_result Then Return true
    Return false
End Function


Function fuw_core_random_word( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), N.B: a page's own fuw_xx_random() is this
    Return Cast( UInteger , ful_core_random_number( puw_max ) )
End Function

Sub s_core_direction_key()
    ' called straight after s_core_get_key() wherever a direction is being asked for: with the rogue like commands
    ' on, a direction may be given by its letter, which is turned into the digit the question is looking for,
    ' Moria's mapRoguelikeKeysToKeypad(), with them off nothing is changed
    Dim lub_digit As UByte = 0

    If ( guw_game_options bAnd MW_OPTION_ROGUELIKE ) = 0 Then Return
    If gub_key_char = Code( "b" ) Then lub_digit = Code( "1" )
    If gub_key_char = Code( "j" ) Then lub_digit = Code( "2" )
    If gub_key_char = Code( "n" ) Then lub_digit = Code( "3" )
    If gub_key_char = Code( "h" ) Then lub_digit = Code( "4" )
    If gub_key_char = Code( "." ) Then lub_digit = Code( "5" )
    If gub_key_char = Code( "l" ) Then lub_digit = Code( "6" )
    If gub_key_char = Code( "y" ) Then lub_digit = Code( "7" )
    If gub_key_char = Code( "k" ) Then lub_digit = Code( "8" )
    If gub_key_char = Code( "u" ) Then lub_digit = Code( "9" )
    If lub_digit <> 0 Then
        gub_key_char = lub_digit
        guw_key_code = lub_digit
    End If
End Sub


Sub s_core_message_after( puw_before As UInteger , puw_string As UInteger )
    ' shows one of our own messages, by its number in the strings database, a UW_MSG_ constant, see src\messages.txt,
    ' with, in front of it, the text at puw_before, bytes ending in a 0, if that is not 0: a monster's name, say,
    ' "The Kobold " and then "hits you."...
    ' ...the text is in the paged data, so a page of code that shows a message this way carries none of it, and it
    ' does not pass through the heap on its way to the screen
    ' this is s_string_fetch() from stage-strings-include.bas followed by s_msg_text() from stage-message-include.bas,
    ' Moria's printMessage(): if a message is showing already, -more- is put after it and a key waited for
    ' N.B: the third data slot is left holding what it held
    Dim luw_entry , luw_offset          As UInteger
    Dim lub_page , lub_length , i       As UByte
    Dim lub_saved_page                  As UByte

    i = 0
    If puw_before <> 0 Then
        While Peek( puw_before + i ) <> 0 And i < UB_SCREEN_COLS
            Poke A_TEXT_BUFFER + i , Peek( puw_before + i )
            i = i + 1
        End While
    End If
    lub_saved_page = gub_core_MMU2_page_number
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_STRINGS_INDEX + Cast( UByte , puw_string >> 11 ) )
    luw_entry  = A_MMU_SLOT_PAGED_DB_MAPS + ( ( puw_string bAnd 2047 ) << 2 )
    lub_page   = Peek( luw_entry )
    luw_offset = Peek( UInteger , luw_entry + 1 )
    lub_length = Peek( luw_entry + 3 )
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_STRINGS_TEXT + lub_page )
    s_core_ram_copy( A_MMU_SLOT_PAGED_DB_MAPS + luw_offset , A_TEXT_BUFFER + i , lub_length )
    If lub_saved_page <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page )

    s_core_msg_text( A_TEXT_BUFFER )
End Sub



Sub s_core_message( puw_string As UInteger )
    ' one of our own messages on its own, see s_core_message_after()
    s_core_message_after( 0 , puw_string )
End Sub


Function ful_core_recall( puw_creature As UInteger , pub_what As UByte , pul_value As ULong ) As ULong
    ' the monster memory, Moria's creature_recall[]: what the player has learnt about each kind of creature by
    ' meeting it, 20 bytes a creature at the start of the knowledge page, laid out as Moria's Recall_t:
    '    0  4  movement      the bits of the creature's "movement" the player has seen for themselves
    '    4  4  spells        the same for its spells, the low 4 bits count how often it has been seen to cast
    '    8  2  kills         how many the player has killed
    '   10  2  deaths        how many times one has killed the player
    '   12  2  defenses      the bits of its "defenses" the player has seen
    '   14  1  wake          how often one has been seen to wake up
    '   15  1  ignore        how often one has been seen to sleep on
    '   16  4  attacks       how often each of its four attacks has been seen
    ' pub_what is one of the UB_RECALL_ numbers in constants.bas, it says which of these and what to do to it:
    ' the bit fields have pul_value added to them, the counts go up by one if pul_value is not 0, and never
    ' past their limit, either way the answer is what is there afterwards, so a 0 simply reads
    Dim lub_saved   As UByte
    Dim luw_at      As UInteger
    Dim luw_count   As UInteger
    Dim lul_answer  As ULong

    lub_saved = gub_core_MMU1_page_number
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_KNOWLEDGE )
    luw_at = A_MMU_SLOT_1 + puw_creature * 20

    If pub_what = UB_RECALL_MOVEMENT Or pub_what = UB_RECALL_SPELLS Then
        luw_at     = luw_at + Cast( UInteger , pub_what ) * 4
        lul_answer = Peek( ULong , luw_at ) bOr pul_value
        Poke ULong luw_at , lul_answer
    ElseIf pub_what = UB_RECALL_SET_MOVEMENT Then
        lul_answer = pul_value
        Poke ULong luw_at , lul_answer
    ElseIf pub_what = UB_RECALL_SPELL_SEEN Then
        ' one more time it has been seen to cast, up to 15
        lul_answer = Peek( ULong , luw_at + 4 )
        If ( lul_answer bAnd 15 ) <> 15 Then lul_answer = lul_answer + 1
        Poke ULong luw_at + 4 , lul_answer
    ElseIf pub_what = UB_RECALL_DEFENSES Then
        luw_count = Peek( UInteger , luw_at + 12 ) bOr Cast( UInteger , pul_value )
        Poke UInteger luw_at + 12 , luw_count
        lul_answer = luw_count
    ElseIf pub_what = UB_RECALL_KILLS Or pub_what = UB_RECALL_DEATHS Then
        luw_at    = luw_at + 8
        If pub_what = UB_RECALL_DEATHS Then luw_at = luw_at + 2
        luw_count = Peek( UInteger , luw_at )
        If pul_value <> 0 And luw_count < 32767 Then luw_count = luw_count + 1
        Poke UInteger luw_at , luw_count
        lul_answer = luw_count
    Else
        ' wake, ignore and the four attacks, a byte each, in that order
        luw_at    = luw_at + 14 + ( pub_what - UB_RECALL_WAKE )
        luw_count = Peek( luw_at )
        If pul_value <> 0 And luw_count < 255 Then luw_count = luw_count + 1
        Poke luw_at , luw_count
        lul_answer = luw_count
    End If

    If lub_saved <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved )
    Return lul_answer
End Function


Function fub_core_print_text_at( pub_row As UByte , pub_col As UByte , puw_address As UInteger , pub_colour As UByte ) As UByte
    ' prints text held in memory, i.e. bytes that end in a 0, such as a description left in A_TEXT_BUFFER...
    ' ...text too long for the row carries on underneath, starting at the same column, and is broken at a space
    ' wherever it can be, the number of rows it took is returned, so the caller knows where the next thing can go
    ' N.B: no string is made, so however long the text is this uses none of the heap
    Dim lub_row , lub_col , lub_char , lub_rows , lub_word  As UByte
    Dim luw_at                                              As UInteger

    lub_row  = pub_row
    lub_col  = pub_col
    lub_rows = 1
    luw_at   = 0
    Do
        lub_char = Peek( puw_address + luw_at )
        If lub_char = 0 Or luw_at = 250 Then Exit Do

        ' at the start of each word: if the whole word will not fit on what is left of this row, start the next row...
        ' ...unless we are already at the start of a row, a word longer than a row just has to be split
        If lub_char <> 32 And lub_col > pub_col Then
            lub_word = 0
            If luw_at = 0 Then
                lub_word = 1
            ElseIf Peek( puw_address + luw_at - 1 ) = 32 Then
                lub_word = 1
            End If
            If lub_word = 1 Then
                While Peek( puw_address + luw_at + lub_word ) <> 0 And Peek( puw_address + luw_at + lub_word ) <> 32 And lub_word < UB_SCREEN_COLS
                    lub_word = lub_word + 1
                End While
                If Cast( UInteger , lub_col ) + lub_word > UB_SCREEN_COLS Then
                    lub_row  = lub_row + 1
                    lub_col  = pub_col
                    lub_rows = lub_rows + 1
                End If
            End If
        End If
        If lub_col >= UB_SCREEN_COLS Then
            lub_row  = lub_row + 1
            lub_col  = pub_col
            lub_rows = lub_rows + 1
        End If

        ' a space is not printed at the start of a row that the text has carried over on to
        If lub_char = 32 And lub_col = pub_col And lub_rows > 1 Then
            ' nothing
        Else
            s_core_print_char_at( lub_row , lub_col , lub_char , pub_colour )
            lub_col = lub_col + 1
        End If
        luw_at = luw_at + 1
    Loop
    Return lub_rows
End Function



Function fs_core_text_at( puw_address As UInteger ) As String
    ' makes a string from text held in memory, i.e. from bytes that end in a 0, which is how the names in the database records
    ' are kept, e.g. fs_core_text_at( A_CREATURE ) is the name of the working creature
    ' N.B: it stops at 160 characters whatever happens, the longest description Moria makes, so a missing 0 cannot run away...
    ' ...text that long takes a good part of the heap while it exists, to put long text on the screen use
    ' fub_core_print_text_at(), which prints straight from memory and uses no heap at all
    Dim ls_text     As String = ""
    Dim lub_char    As UByte
    Dim lub_count   As UByte = 0

    Do
        lub_char = Peek( puw_address + lub_count )
        If lub_char = 0 Or lub_count = 160 Then Exit Do
        ls_text   = ls_text + fs_core_char( lub_char )
        lub_count = lub_count + 1
    Loop
    Return ls_text
End Function


'##################################################################################################################################
' ---MAIN PROGRAM ---

Sub s_core_main_vars()
    gub_core_end              = false     ' the core data page is not cleared for us, so set this explicitly
    gul_core_entropy          = 0
    guw_key_code              = 0
    gub_key_char              = 0
    gub_key_modifiers         = 0
    ' N.B: a String variable is really a two byte pointer into the heap, and assigning to it frees whatever it pointed at before...
    ' ...so the pointer must start out as 0 (meaning "no string yet"), otherwise the first assignment would free a random address
    Poke UInteger A_KEY + 4 , 0             ' gs_key_astext
    gub_core_MMU3_page_number = 0
    gul_core_MMU3_cache_hits  = 0
    gul_core_MMU3_page_swaps  = 0
    ' the three paged data slots, 255 is the number the Next uses for "the ROM", and it is not one of our pages...
    ' ...so it stands for "nothing of ours is in this slot yet", the slots still hold whatever the system left there
    gub_core_MMU0_page_number = 255
    gul_core_MMU0_cache_hits  = 0
    gul_core_MMU0_page_swaps  = 0
    gub_core_MMU1_page_number = 255
    gul_core_MMU1_cache_hits  = 0
    gul_core_MMU1_page_swaps  = 0
    gub_core_MMU2_page_number = 255
    gub_core_file_slot        = 255         ' a file is one page and no more unless a caller says otherwise
    gul_core_MMU2_cache_hits  = 0
    gul_core_MMU2_page_swaps  = 0

    s_core_ram_copy( 0, 0, 0 )           ' to stop the compiler optimizer from dropping this routine...
    s_core_clear_screen()                ' start with a blank screen, and this call also stops the optimizer from dropping the routine...
    If gub_core_end Then s_core_countdown( 0 , 0 , 0 , 0 )      ' never actually runs, it is only here to stop the optimizer from dropping the routine...
    If gub_core_end Then s_core_swap_paged_data( 255 , 0 )     ' ditto
    If gub_core_end Then s_core_nothing_to_return_to()         ' ditto, it is only ever reached by a jump, see s_core_return_to_zxos()
    If gub_core_end Then gub_shared_1 = fub_core_file_save_page( "" , 0 )      ' ditto
    If gub_core_end Then gub_shared_1 = fub_core_file_load_page( "" , 0 )      ' ditto
    If gub_core_end Then guw_shared_1 = fuw_core_dice_roll( 0 , 0 )            ' ditto
    If gub_core_end Then gul_game_old_seed = ful_core_random()                 ' ditto
    If gub_core_end Then s_core_fetch_record( 0 , 0 , 0 , 0 )                  ' ditto
    If gub_core_end Then s_core_store_record( 0 , 0 , 0 , 0 )                  ' ditto
    If gub_core_end Then guw_shared_1 = fuw_core_map_square( 0 , 0 , 0 )       ' ditto
    If gub_core_end Then gub_shared_1 = fub_core_print_text_at( 0 , 0 , 0 , 0 )    ' ditto
    If gub_core_end Then gs_key_astext = fs_core_text_at( 0 )                  ' ditto
    If gub_core_end Then guw_shared_1 = fsw_core_random_normal( 0 , 1 )        ' ditto
    If gub_core_end Then gul_game_old_seed = ful_core_recall( 0 , 0 , 0 )      ' ditto
    If gub_core_end Then s_core_print_char_at_logged( 1 , 0 , 32 , 0 )         ' ditto
    If gub_core_end Then s_core_message( 0 )                                   ' ditto
    If gub_core_end Then s_core_message_after( 0 , 0 )                         ' ditto
    If gub_core_end Then s_core_direction_key()                                ' ditto
    If gub_core_end Then gub_shared_1 = fub_core_map_symbol( 0 , 0 )           ' ditto
    If gub_core_end Then s_core_map_put( 0 , 0 )                               ' ditto
    If gub_core_end Then s_core_map_draw_panel()                               ' ditto
    If gub_core_end Then s_core_map_light_room( 0 , 0 )                        ' ditto
    If gub_core_end Then gub_shared_1 = fub_core_map_outside_panel( 0 , 0 , 0 ) ' ditto
    If gub_core_end Then s_core_msg( "" )                                      ' ditto
    If gub_core_end Then s_core_msg_flush()                                    ' ditto
    If gub_core_end Then gub_shared_1 = fub_core_lib_call( 0 , 0 , 0 , 0 )      ' ditto
    If gub_core_end Then guw_shared_1 = fuw_core_random_word( 1 )              ' ditto

    ' no messages yet
    gub_log_length = 0
    gub_log_next   = 0
    gub_log_count  = 0

    ' nothing is known about any kind of creature yet, the monster memory is the first 5580 bytes of its page
    ' N.B: this is done once, when the program starts, as in Moria what one character learns the next one knows
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_KNOWLEDGE )
    Asm
        ld hl, A_MMU_SLOT_1
        ld de, A_MMU_SLOT_1 + 1
        ld bc, 5579
        ld (hl), 0
        ldir
    End Asm

    ' the random numbers must never start from 0 (the generator would stay at 0 for ever), a proper seed is chosen when a game begins
    gul_game_old_seed   = 0
    gul_game_magic_seed = 0
    gul_game_town_seed  = 0
    s_core_random_seed( 0 )
End Sub


Sub s_core_main()
    s_core_main_vars()
    ' N.B: the game begins at Moria's own first screen. Until 14 October 2026 it began with a screen of start up tests
    ' (the paged data slots, a file saved and loaded, the random numbers, the records, the databases) and "Press any
    ' key to begin...", the stage stage-init.bas, which has been taken out, git has it
    gub_core_stage   = UB_STAGE_SPLASH
    gub_core_monitor = false        ' the live monitor starts out off, the ] key turns it on, see s_core_get_key()
    Do
        ' N.B: gub_core_stage holds a UB_STAGE_ number, which is not the same thing as a UB_PAGED_CODE_ page number
        If gub_core_stage = UB_STAGE_SPLASH Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_SPLASH )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            ' is there a saved game, with a living character? then it carries on where it was left, as Moria's
            ' does, the save library brings it back: the walking stage takes the level as it finds it, as it
            ' does when the player comes out of a store, and the turn that was under way when it was saved goes on
            ' ...and a game started as a wizard, Ctrl-W on the opening screen, Moria's -w, may bring back a character
            ' who has died, the save library asks, they then arrive in the town, made afresh, as Moria's do
            s_core_call_library( UB_PAGED_CODE_LIB_SAVE , UB_LIB_SAVE_RESTORE )
            If gsw_lib_result = 3 Then
                ' a save that will not do, Moria's "Error during reading of file.": the game ends, and leaves it be
                gub_core_end = true
            ElseIf gsw_lib_result <> 0 Then
                If gsw_lib_result = 2 Then
                    ' N.B: a character brought back is not in wizard mode, Moria's resurrection clears to_be_wizard
                    gub_core_to_be_wizard = false
                    gub_core_request = UB_REQUEST_RESURRECTED
                    gub_core_stage   = UB_STAGE_CREATE_TOWN
                Else
                    gub_core_request = UB_REQUEST_RESUME
                    gub_core_stage   = UB_STAGE_CRAWL
                    ' a game started as a wizard is in wizard mode, Moria's enterWizardMode() after loadGame(), and if
                    ' the player thinks better of it the game ends there, as Moria's does
                    If gub_core_to_be_wizard Then
                        s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_ENTER )
                        If gsw_lib_result = false Then gub_core_end = true
                    End If
                End If
                ' ...and then the character's sheet, with the chance to file it or give them another name, Moria's
                ' changeCharacterName(), which its startMoria() calls for every game brought back from a save
                If gub_core_end = false Then
                    gub_lib_param_1 = false
                    s_core_call_library( UB_PAGED_CODE_LIB_INFO , UB_LIB_INFO_CHARACTER )
                End If
            Else
                ' a new game starts here: seed the random numbers, as Moria does from the clock, we use how long the player has
                ' taken over the key presses so far (or the fixed seed in constants.bas, when testing)
                If UL_GAME_FIXED_SEED <> 0 Then
                    s_core_seeds_initialize( UL_GAME_FIXED_SEED )
                Else
                    s_core_seeds_initialize( gul_core_entropy )
                End If
                ' nobody has died yet in this game, and nothing is left over from the last character
                gub_game_character_dead = false
                gub_game_total_winner   = false
                gub_save_used           = false
                ' what earlier characters learnt of the dungeon's creatures, if the card has it
                s_core_call_library( UB_PAGED_CODE_LIB_SAVE , UB_LIB_SAVE_MEMORY )
                Asm
                    ld hl, A_PLAYER
                    ld de, A_PLAYER + 1
                    ld bc, 767
                    ld (hl), 0
                    ldir
                End Asm
                ' a game started as a wizard: Moria's enterWizardMode() comes before the character is made, and if the
                ' player thinks better of it the game ends there, as Moria's does, see the class stage below as well
                If gub_core_to_be_wizard Then
                    s_core_clear_screen()
                    s_core_call_library( UB_PAGED_CODE_LIB_WIZARD , UB_LIB_WIZARD_ENTER )
                    If gsw_lib_result = false Then gub_core_end = true
                End If
                gub_core_stage = UB_STAGE_NEW_GAME
            End If

        ElseIf gub_core_stage = UB_STAGE_NEW_GAME Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_NEW_GAME )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            gub_core_stage = UB_STAGE_PLAYER

        ElseIf gub_core_stage = UB_STAGE_PLAYER Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_PLAYER )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            gub_core_stage = UB_STAGE_PLAYER_CLASS

        ElseIf gub_core_stage = UB_STAGE_PLAYER_CLASS Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_PLAYER_CLASS )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            ' the character gets what their class starts with, and the food in their belly, Moria does this straight after making them
            s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_NEW_CHARACTER )
            gsw_player_food          = 7500
            gsw_player_food_digested = 2
            ' no spells have been learnt yet, 99 marks the end of the order they were learnt in, and then how many
            ' the character may learn, and their mana, are worked out, for those who have spells at all
            Asm
                ld hl, A_PLAYER_SPELL_ORDER
                ld de, A_PLAYER_SPELL_ORDER + 1
                ld bc, 31
                ld (hl), 99
                ldir
            End Asm
            s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
            ' a new character starts with the options as Moria has them to begin with, N.B: here, once the character is
            ' made, because the stage that makes it wipes the player's record first
            guw_game_options = MW_OPTION_DEFAULTS
            ' when the character was made, Moria's date_of_birth, which tells this character from every other: the
            ' date and the time if the Next has a clock, and if it has none a number from how long the player took
            ' over the key presses, with its top bit set, which no date has before the year 2108
            gub_lib_param_1 = false
            s_core_call_library( UB_PAGED_CODE_LIB_SCORES , UB_LIB_SCORES_DATE )
            If gsw_lib_result Then
                gsl_player_birth = gsl_lib_long_1
            Else
                gsl_player_birth = gul_core_entropy bOr $80000000
            End If
            ' what the unidentified items look like in this game is decided now, as in Moria, after the character is made
            s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_NEW_GAME )
            ' a new character starts in the town, level 0, at turn 0, which is by day
            guw_dungeon_level = 0
            ' N.B: -1, as Moria's dg.game_turn starts out, so that the first turn played is turn 0 and not turn 1: it was 0 here
            ' until 14 October 2026, which put every turn one out, found by setting the wizard's sample of objects beside
            ' the real Umoria's from the same seed: on turn 0 Moria throws for the slim chance of sensing an enchantment,
            ' as it does every sixteenth turn, and we, starting at turn 1, did not, see tools\test\compare-objects.ps1
            gsl_game_turn     = -1
            ' a game started as a wizard is in wizard mode from the start, Moria's enterWizardMode() was before the
            ' character was made, N.B: here, because the stages that make the character start their record afresh
            If gub_core_to_be_wizard Then
                gub_game_noscore = gub_game_noscore bOr 2
                gub_game_wizard  = true
            End If
            gub_core_stage    = UB_STAGE_CREATE_TOWN

        ElseIf gub_core_stage = UB_STAGE_CREATE_TOWN Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_CREATE_TOWN )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            gub_core_stage = UB_STAGE_CRAWL

        ElseIf gub_core_stage = UB_STAGE_CREATE_DUNGEON Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_CREATE_DUNGEON )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            gub_core_stage = UB_STAGE_CRAWL

        ElseIf gub_core_stage = UB_STAGE_CRAWL Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_CRAWL )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            ' the crawl stage comes back to stop, or with a request in gub_core_request...
            If gub_core_request = UB_REQUEST_DEATH Then
                ' ...because the player has died
                gub_core_stage = UB_STAGE_DEATH
            ElseIf gub_core_request = UB_REQUEST_STORE Then
                ' ...to go into a store, the level stays as it is, and the crawl stage picks it up again afterwards
                gub_core_stage = UB_STAGE_STORE
            ElseIf guw_dungeon_level = 0 Then
                ' ...or for a new level, it has already changed guw_dungeon_level: level 0 is the town, everything below it is dungeon
                gub_core_stage = UB_STAGE_CREATE_TOWN
            Else
                gub_core_stage = UB_STAGE_CREATE_DUNGEON
            End If

        ElseIf gub_core_stage = UB_STAGE_DEATH Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_DEATH )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            ' and so to the opening screen, and another character
            gub_core_stage = UB_STAGE_SPLASH

        ElseIf gub_core_stage = UB_STAGE_STORE Then
            s_core_swap_paged_code( UB_PAGED_CODE_STAGE_STORE )
            Asm
                call A_MMU_SLOT_PAGED_CODE
            End Asm
            gub_core_stage = UB_STAGE_CRAWL
        End If
    Loop Until gub_core_end
    s_core_return_to_zxos()
End Sub
