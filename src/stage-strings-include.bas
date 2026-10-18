' getting a string out of the strings database, any stage or library that needs one includes this file...
' ...the strings are in the paged data: an index of 4 bytes per string (which page of text, where in it, and its length
' with the 0 on its end), and the text itself, see create-data.ps1 for how they are built
' N.B: this uses the third paged data slot, and leaves the page of text in it

Sub s_string_fetch( puw_string As UInteger , puw_to As UInteger )
    ' copies string number puw_string, with the 0 on its end, to puw_to, which will usually be A_TEXT_BUFFER
    Dim luw_entry , luw_offset      As UInteger
    Dim lub_page , lub_length       As UByte

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_STRINGS_INDEX + Cast( UByte , puw_string >> 11 ) )
    luw_entry  = A_MMU_SLOT_PAGED_DB_MAPS + ( ( puw_string bAnd 2047 ) << 2 )
    lub_page   = Peek( luw_entry )
    luw_offset = Peek( UInteger , luw_entry + 1 )
    lub_length = Peek( luw_entry + 3 )
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_STRINGS_TEXT + lub_page )
    s_core_ram_copy( A_MMU_SLOT_PAGED_DB_MAPS + luw_offset , puw_to , lub_length )
End Sub