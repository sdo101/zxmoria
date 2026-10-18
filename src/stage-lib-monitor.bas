#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monitor()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: the live monitor, ours, not Moria's, the last five rows of the screen show how
' the memory is being used while the game runs, the ] key (symbol shift and U) turns it on and off...
' ...only the core calls it, from s_core_get_key(), through s_core_monitor(), the routines are:
'
'   UB_LIB_MONITOR_SHOW     draws it, every time the game waits for a key while it is on
'   UB_LIB_MONITOR_CLEAR    rubs it out, when it is turned off
'
' N.B: it was part of the core, and was moved here to leave the core's own two pages for what every page needs
' N.B: being a page of code that is fetched to draw it, it adds two to the count of the code slot each time

Function fub_mn_read_next_reg( pub_reg As UByte ) As UByte
    ' what a Next register holds now, asked of the machine itself
    gub_shared_1 = pub_reg
    Asm
        ld a, (_gub_shared_1)   ; load register number
        ld bc, A_NEXTREG_SELECT
        out (c), a              ; select register
        ld bc, A_NEXTREG_DATA
        in a, (c)               ; read value
        ld (_gub_shared_1), a
    End Asm
    Return gub_shared_1
End Function


Function fs_mn_number_wide( pul_value As ULong , pub_width As UByte ) As String
    ' a number as text, with spaces in front of it to make it up to a width, so that a column of them lines up
    Dim ls_text As String

    ls_text = fs_core_number( pul_value )
    While Len( ls_text ) < pub_width
        ls_text = " " + ls_text
    End While
    Return ls_text
End Function


' where slot 2's misses by page go, rows 24 to 26: as far to the right as they go, their widest line, four counts of 7
' with their names, is 46 characters, and ends at the screen's last column, 79 (the author, 16 October 2026, they were at
' UB_MONITOR_LEFT, 17, beside the mini map)
#define UB_MN_MISSES_LEFT   34


Function fs_mn_kind( pub_kind As UByte ) As String
    ' one of the counts of what slot 2's page changes were for, seven characters wide
    Return fs_mn_number_wide( Peek( ULong , A_CORE_MMU2_KINDS + 4 * Cast( UInteger , pub_kind ) ) Mod 1000000 , 7 )
End Function


Sub s_mn_clear()
    ' rubs out the eight rows the monitor is drawn in, to the right of the mini map
    Dim x As UByte

    For x = UB_MONITOR_ROW - 3 To UB_MONITOR_ROW + 4
        s_core_clear_row( x , UB_MONITOR_LEFT , UB_BLACK )
    Next x
End Sub


Sub s_mn_show()
    ' the live monitor: the last five rows of the screen, 27 to 31, well below Moria's own 24 lines, show how the memory is being used, it is
    ' drawn again every time the game waits for a key, and the ] key turns it on and off, see s_core_get_key()
    ' on the left, a table with a column for each of the MMU slots 0 to 3, and these rows:
    '   p = the 8KB page that is in the slot now, asked of the machine itself (Next registers $50 to $57)
    '   c = count, how often a page has been asked for in that slot, which is hits + misses
    '   h = hits, how often the slot already held the page that was asked for, so nothing had to be done
    '   m = misses, how often it did not, and the page had to be changed, in slot 3 that is every call of a library and every return from one
    '   ...each of the three counts is shown up to 999999 and then starts again from 0
    ' ...slots 4 to 7 are not shown, they are never changed: they hold the core (4 and 5, pages 30 and 31), its data
    ' and the heap (6, page 32) and the screen and the stack (7, page 11) from start to finish
    ' on the right, the heap and the stack:
    '   heap:   b = the biggest single free block, s = bytes in use now, f = bytes free now, m = the most ever in use
    '   stack:  p = where the stack pointer is now, s = bytes in use now, f = bytes free now, m = the most ever in use
    ' on the far left, slot 2's misses by the kind of page that was wanted: map, cre(atures), obj(ects), tab(les),
    ' str(ings), kno(wledge, the monster memory) and oth(er)
    Dim i                           As Ubyte
    Dim lub_blocks                  As UByte
    Dim luw_counters                As UInteger
    Dim luw_screen_top              As UInteger
    Dim luw_stack_pos               As UInteger
    Dim luw_scan                    As UInteger
    Dim luw_heap_start              As UInteger
    Dim luw_heap_size               As UInteger
    Dim luw_heap_free               As UInteger
    Dim luw_heap_biggest            As UInteger
    Dim luw_block , luw_size        As UInteger
    Dim lul_hits , lul_fetches      As ULong
    Dim ls_head , ls_page           As String
    Dim ls_count , ls_hits          As String
    Dim ls_misses                   As String

    luw_screen_top = A_STACK_BOTTOM         ' i.e. directly above the 5120 bytes of screen cells

    Asm
        ld hl, 0
        add hl, sp
        ld (_guw_shared_1), hl
        ld hl, .core.ZXBASIC_MEM_HEAP       ; where the heap is, and how big, as the compiler was told in build.ps1
        ld (_guw_shared_2), hl
        ld hl, .core.ZXBASIC_HEAP_SIZE
        ld (_guw_shared_3), hl
    End Asm
    luw_stack_pos  = guw_shared_1
    luw_heap_start = guw_shared_2
    luw_heap_size  = guw_shared_3

    ' measure the heap FIRST, before this routine builds any strings of its own, so that what it reports is everybody else's use...
    ' ...the heap begins with a 4 byte header, and after that it is a chain of free blocks, each one starts with two words:
    ' its own size in bytes, and the address of the next free block, or 0 if it is the last one...
    ' ...the header has the same shape, with a size of 0, so the address of the first free block is in its second word
    luw_heap_free    = 0
    luw_heap_biggest = 0
    lub_blocks       = 0
    luw_block        = Peek( UInteger , luw_heap_start + 2 )
    While luw_block <> 0 And lub_blocks < 64        ' the 64 is only a safety limit, in case the chain has been damaged
        luw_size = Peek( UInteger , luw_block )
        luw_heap_free = luw_heap_free + luw_size
        If luw_size > luw_heap_biggest Then luw_heap_biggest = luw_size
        luw_block  = Peek( UInteger , luw_block + 2 )
        lub_blocks = lub_blocks + 1
    End While

    ' the table of slots 0 to 3, a column for each, 7 characters wide, N.B: every line is the same length each time it is
    ' drawn, so nothing of the last one is left showing
    ls_head   = "MMU"
    ls_page   = "p"
    ls_count  = "c"
    ls_hits   = "h"
    ls_misses = "m"
    For i = 0 To 3
        If i = 0 Then
            ls_head = ls_head + fs_mn_number_wide( i , 5 )        ' two fewer, "MMU" is two longer than the other labels
        Else
            ls_head = ls_head + fs_mn_number_wide( i , 7 )
        End If
        If i = 3 Then
            ' N.B: the code slot holds this page just now, what is shown is the page that was running
            ls_page = ls_page + fs_mn_number_wide( gub_core_monitor_page , 7 )
        Else
            ls_page = ls_page + fs_mn_number_wide( fub_mn_read_next_reg( MMU_SLOT_0 + i ) , 7 )
        End If
        ' where the slot's counters are, see globals.bas: the code slot's come first, then those of the three data slots
        luw_counters = A_CORE
        If i < 3 Then luw_counters = A_CORE + 9 + 9 * Cast( UInteger , i )
        ' N.B: the counts themselves are ULongs and are left alone, the map asks for a page for every square anything
        ' looks at and must not be slowed down: it is what is SHOWN that rolls over, 999999 is followed by 0
        lul_hits    = Peek( ULong , luw_counters + 1 ) Mod 1000000
        lul_fetches = Peek( ULong , luw_counters + 5 ) Mod 1000000
        ls_count  = ls_count  + fs_mn_number_wide( ( lul_hits + lul_fetches ) Mod 1000000 , 7 )
        ls_hits   = ls_hits   + fs_mn_number_wide( lul_hits , 7 )
        ls_misses = ls_misses + fs_mn_number_wide( lul_fetches , 7 )
    Next
    ' N.B: it is 29 characters wide, and starts at column 29, which leaves three spaces between it and the heap's figures
    s_core_print_string_at( UB_MONITOR_ROW     , 29 , ls_head   , UB_DARK_GREY )
    s_core_print_string_at( UB_MONITOR_ROW + 1 , 29 , ls_page   , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 2 , 29 , ls_count  , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 3 , 29 , ls_hits   , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 4 , 29 , ls_misses , UB_WHITE )

    ' above the rest, the three rows between Moria's screen and the monitor's own, to the right of the mini map (which
    ' has columns 0 to 15 of rows 24 to 31, see stage-lib-minimap.bas): what slot 2's misses were for, the kind of
    ' page that was asked for and was not there, see A_CORE_MMU2_KINDS in globals.bas, each shown up to 999999
    s_core_print_string_at( UB_MONITOR_ROW - 3 , UB_MN_MISSES_LEFT , "MMU 2 misses, by page" , UB_DARK_GREY )
    s_core_print_string_at( UB_MONITOR_ROW - 2 , UB_MN_MISSES_LEFT , "map" + fs_mn_kind( 0 ) + "  cre" + fs_mn_kind( 1 ) + "  obj" + fs_mn_kind( 2 ) + "  tab" + fs_mn_kind( 3 ) , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW - 1 , UB_MN_MISSES_LEFT , "str" + fs_mn_kind( 4 ) + "  kno" + fs_mn_kind( 5 ) + "  oth" + fs_mn_kind( 6 ) , UB_WHITE )

    ' headers...
    s_core_print_string_at( UB_MONITOR_ROW , 61 , "heap      stack" , UB_DARK_GREY )

    ' the biggest free block in the heap, a string longer than this cannot be built even if the total free is more...
    ' ...and where the stack pointer is
    s_core_print_string_at( UB_MONITOR_ROW + 1 , 61 , "b" + fs_mn_number_wide( luw_heap_biggest , 5 ) , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 1 , 71 , "p" + fs_mn_number_wide( luw_stack_pos , 6 ) , UB_WHITE )

    ' in use now... (the 4 is the heap's own header, which is never available)
    s_core_print_string_at( UB_MONITOR_ROW + 2 , 61 , "s" + fs_mn_number_wide( luw_heap_size - 4 - luw_heap_free , 5 ) , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 2 , 71 , "s" + fs_mn_number_wide( A_Z80_CPU_STACK - luw_stack_pos , 6 ) , UB_WHITE )

    ' free now...
    s_core_print_string_at( UB_MONITOR_ROW + 3 , 61 , "f" + fs_mn_number_wide( luw_heap_free , 5 ) , UB_WHITE )
    s_core_print_string_at( UB_MONITOR_ROW + 3 , 71 , "f" + fs_mn_number_wide( luw_stack_pos - luw_screen_top , 6 ) , UB_WHITE )

    ' the most the heap has ever used...
    ' ...the core filled the heap with UB_HEAP_FILL at start up, and the heap hands out memory from its top end downwards,
    ' so we walk up from just above the header and its first free block until we meet the first byte that has been overwritten
    luw_scan = luw_heap_start + 8
    While luw_scan < luw_heap_start + luw_heap_size And Peek( luw_scan ) = UB_HEAP_FILL
        luw_scan = luw_scan + 1
    End While
    s_core_print_string_at( UB_MONITOR_ROW + 4 , 61 , "m" + fs_mn_number_wide( luw_heap_start + luw_heap_size - luw_scan , 5 ) , UB_WHITE )

    ' the most the stack has ever used...
    ' ...the core filled the whole stack area with UB_STACK_FILL at start up, and the stack grows downwards from the top,
    ' so we walk up from the bottom until we meet the first byte that has been overwritten
    luw_scan = A_STACK_BOTTOM
    While luw_scan < A_Z80_CPU_STACK And Peek( luw_scan ) = UB_STACK_FILL
        luw_scan = luw_scan + 1
    End While
    s_core_print_string_at( UB_MONITOR_ROW + 4 , 71 , "m" + fs_mn_number_wide( A_Z80_CPU_STACK - luw_scan , 6 ) , UB_WHITE )

    If luw_stack_pos <= luw_screen_top Then
        s_core_print_string_at( UB_MONITOR_ROW + 4 , 71 , "COLLISION" , UB_BRIGHT_RED )
        Asm
            di
            halt
        End Asm
    End If
End Sub

Sub s_lib_monitor()
    If gub_lib_function = UB_LIB_MONITOR_SHOW Then
        s_mn_show()
    ElseIf gub_lib_function = UB_LIB_MONITOR_CLEAR Then
        s_mn_clear()
    End If
End Sub
