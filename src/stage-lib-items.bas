#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_items()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: routines to do with items that every part of the game needs...
' ...any stage reaches them through the core: s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , <which routine> ), the core puts
' this page into the code slot in place of the stage, calls it, and puts the stage back before it returns
' what goes in and what comes out is passed in fixed places, see "the library" in globals.bas, the routines are:
'
'   UB_LIB_ITEMS_DESCRIBE       describes the working item (A_ITEM) in words, e.g. "a Flask of Oil." or "3 Blue Potions.",
'                               the text is left in A_TEXT_BUFFER, ending in a 0, this is Moria's itemDescription()...
'                               ...gub_lib_param_1 is true for the full description, false for just the name
'   UB_LIB_ITEMS_NEW_GAME       decides what the unidentified items look like in this game: which colour each potion is,
'                               which wood each staff, the title of each scroll..., Moria's magicInitializeItemNames()
'   UB_LIB_ITEMS_FROM_OBJECT    makes the working item a brand new one of the kind in guw_lib_param_2, a number in the
'                               objects database, Moria's inventoryItemCopyTo()
'   UB_LIB_ITEMS_TEST           shows a screenful of sample descriptions, for checking this page
'   UB_LIB_ITEMS_KIND_KNOWN     gsw_lib_result is true if the player knows what kind of thing the working item is
'   UB_LIB_ITEMS_STORE_BOUGHT   marks the working item as bought in a store, and so fully known, Moria's
'                               itemIdentifyAsStoreBought()
'
' N.B: these routines use the third paged data slot for the objects database, the game tables and the item knowledge,
' whatever page the caller had in that slot is put back before returning


' --- its working storage is in globals.bas, under "private to stage-lib-items.bas", moved there on 22 October 2026 ---


'##################################################################################################################################
' --- building text a byte at a time, without using the heap ---

Sub s_d_begin( puw_base As UInteger )
    guw_d_base = puw_base
    gub_d_len  = 0
    Poke puw_base , 0
End Sub


Sub s_d_char( pub_char As UByte )
    ' guard: nothing Moria describes is anywhere near this long, but a full buffer simply stops growing
    If gub_d_len >= 170 Then Return
    Poke guw_d_base + gub_d_len , pub_char
    gub_d_len = gub_d_len + 1
    Poke guw_d_base + gub_d_len , 0
End Sub


Sub s_d_text( puw_address As UInteger )
    ' adds text held in memory, up to its 0
    Dim lub_char    As UByte
    Dim i           As UByte = 0

    Do
        lub_char = Peek( puw_address + i )
        If lub_char = 0 Then Exit Do
        s_d_char( lub_char )
        i = i + 1
    Loop Until i = 170
End Sub


Sub s_d_str( ps_text As String )
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    i = 0
    While i < lub_length
        s_d_char( Code( ps_text( i ) ) )
        i = i + 1
    End While
End Sub


Sub s_d_number( psw_value As Integer )
    ' a number, with a minus sign if it needs one
    If psw_value < 0 Then
        s_d_char( Code( "-" ) )
        s_d_str( fs_core_number( -psw_value ) )
    Else
        s_d_str( fs_core_number( psw_value ) )
    End If
End Sub


Sub s_d_signed( psw_value As Integer )
    ' a number that always shows its sign, e.g. +3 or -2 or +0
    If psw_value < 0 Then
        s_d_char( Code( "-" ) )
        s_d_str( fs_core_number( -psw_value ) )
    Else
        s_d_char( Code( "+" ) )
        s_d_str( fs_core_number( psw_value ) )
    End If
End Sub


Sub s_d_replace_first( ps_find As String , ps_with As String )
    ' replaces the first place ps_find appears in the text with ps_with, or does nothing if it is not there,
    ' Moria's insertStringIntoString()
    Dim lub_find , lub_at , i , lub_found  As UByte

    lub_find = Len( ps_find )
    If lub_find = 0 Or lub_find > gub_d_len Then Return
    lub_found = false
    lub_at    = 0
    While lub_at + lub_find <= gub_d_len
        lub_found = true
        For i = 0 To lub_find - 1
            If Peek( guw_d_base + lub_at + i ) <> Code( ps_find( i ) ) Then
                lub_found = false
                Exit For
            End If
        Next
        If lub_found Then Exit While
        lub_at = lub_at + 1
    End While
    If lub_found = false Then Return

    ' put what follows it aside, cut the text off where it starts, add the replacement, and put the rest back
    i = 0
    Do
        Poke A_D_TAIL + i , Peek( guw_d_base + lub_at + lub_find + i )
        If Peek( A_D_TAIL + i ) = 0 Then Exit Do
        i = i + 1
    Loop
    gub_d_len = lub_at
    Poke guw_d_base + gub_d_len , 0
    s_d_str( ps_with )
    s_d_text( A_D_TAIL )
End Sub


'##################################################################################################################################
' --- what the player knows about each kind of item ---

Function fsw_items_position_offset( pub_category As UByte , pub_sub_category As UByte ) As Integer
    ' which of the seven families of "unknown until tried" items this is, or -1 if it is none of them,
    ' Moria's objectPositionOffset()
    If pub_category = UB_TV_AMULET Then Return 0
    If pub_category = UB_TV_RING Then Return 1
    If pub_category = UB_TV_STAFF Then Return 2
    If pub_category = UB_TV_WAND Then Return 3
    If pub_category = UB_TV_SCROLL1 Or pub_category = UB_TV_SCROLL2 Then Return 4
    If pub_category = UB_TV_POTION1 Or pub_category = UB_TV_POTION2 Then Return 5
    If pub_category = UB_TV_FOOD Then
        If ( pub_sub_category bAnd 63 ) < UB_MAX_MUSHROOMS Then Return 6
    End If
    Return -1
End Function


Function fub_items_knowledge( pub_category As UByte , pub_sub_category As UByte ) As UByte
    ' the knowledge flags for this kind of item (MB_OD_TRIED, MB_OD_KNOWN1), or 255 if it is not a kind that has any
    Dim lsw_offset As Integer

    lsw_offset = fsw_items_position_offset( pub_category , pub_sub_category )
    If lsw_offset < 0 Then Return 255
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
    Return Peek( A_KNOW_IDENTIFIED + ( Cast( UInteger , lsw_offset ) << 6 ) + ( pub_sub_category bAnd 63 ) )
End Function


Function fub_items_kind_is_known() As UByte
    ' true if the player knows what kind of thing the working item is, e.g. that the blue potion is a Potion of
    ' Cure Light Wounds, Moria's itemSetColorlessAsIdentified(): anything bought in a store is known, and so is
    ' anything that is not one of the "unknown until tried" kinds
    Dim lub_flags As UByte

    If ( gub_item_identification bAnd MB_ID_STORE_BOUGHT ) <> 0 Then Return true
    lub_flags = fub_items_knowledge( gub_item_category , gub_item_sub_category )
    If lub_flags = 255 Then Return true
    If ( lub_flags bAnd MB_OD_KNOWN1 ) <> 0 Then Return true
    Return false
End Function


'##################################################################################################################################
' --- describing an item ---

Sub s_d_flavour( puw_order As UInteger , puw_names As UInteger , pub_index As UByte )
    ' adds the name this game has given to one of the unknown kinds, e.g. the colour of potion number pub_index...
    ' ...puw_order is this game's shuffled order for that family, in the knowledge page, puw_names is the list of
    ' names, in the game tables page
    Dim lub_name As UByte

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
    lub_name = Peek( puw_order + pub_index )
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
    s_d_text( puw_names + Cast( UInteger , lub_name ) * UB_FLAVOUR_NAME_SIZE )
End Sub


Sub s_d_damage_dice( pub_dice As UByte , pub_sides As UByte )
    ' makes the damage part, e.g. " (2d5)", it is added to the description later
    Dim luw_base    As UInteger
    Dim lub_len     As UByte

    luw_base = guw_d_base
    lub_len  = gub_d_len
    s_d_begin( A_D_DAM )
    s_d_str( " (" )
    s_d_number( pub_dice )
    s_d_char( Code( "d" ) )
    s_d_number( pub_sides )
    s_d_char( Code( ")" ) )
    guw_d_base = luw_base
    gub_d_len  = lub_len
End Sub


Sub s_items_describe()
    ' Moria's itemDescription(), for the working item, the result is left in A_TEXT_BUFFER
    ' the name in the objects database has marks in it: & where "a", "an" or a number goes, and ~ where an "s" goes
    ' if there is more than one
    Dim lub_category , lub_index , lub_modify , lub_append , lub_misc   As UByte
    Dim lub_known2 , lub_flags , lub_char , i                           As UByte
    Dim lsw_bow                                                         As Integer


    lub_category = gub_item_category
    lub_index    = gub_item_sub_category bAnd 63
    lub_modify   = false
    If fub_items_kind_is_known() = false Then lub_modify = true
    lub_known2   = false
    If ( gub_item_identification bAnd MB_ID_KNOWN2 ) <> 0 Then lub_known2 = true
    lub_append   = false
    lub_misc     = UB_MISC_IGNORED

    ' the object the item is one of, for its name
    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , guw_item_object , A_OBJECT )
    Poke A_D_DAM , 0
    s_d_begin( A_D_VAL )

    ' --- the things that are simply named, and that is all ---
    If lub_category = UB_TV_GOLD Or lub_category = UB_TV_INVIS_TRAP Or lub_category = UB_TV_VIS_TRAP Or lub_category = UB_TV_UP_STAIR Or lub_category = UB_TV_DOWN_STAIR Then
        s_d_begin( A_TEXT_BUFFER )
        s_d_text( A_OBJECT )
        s_d_char( Code( "." ) )
        Return
    End If
    If lub_category = UB_TV_STORE_DOOR Then
        s_d_begin( A_TEXT_BUFFER )
        s_d_str( "the entrance to the " )
        s_d_text( A_OBJECT )
        s_d_char( Code( "." ) )
        Return
    End If

    ' --- the name, by kind of item ---
    If lub_category = UB_TV_SLING_AMMO Or lub_category = UB_TV_BOLT Or lub_category = UB_TV_ARROW Then
        s_d_damage_dice( gub_item_damage_dice , gub_item_damage_sides )
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_LIGHT Then
        lub_misc = UB_MISC_LIGHT
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_BOW Then
        ' a bow is described by how much it multiplies the damage of what it fires, Moria's bowDamageValue()
        lsw_bow = -1
        If gsw_item_misc_use = 1 Or gsw_item_misc_use = 2 Then lsw_bow = 2
        If gsw_item_misc_use = 3 Or gsw_item_misc_use = 5 Then lsw_bow = 3
        If gsw_item_misc_use = 4 Or gsw_item_misc_use = 6 Then lsw_bow = 4
        s_d_begin( A_D_DAM )
        s_d_str( " (x" )
        s_d_number( lsw_bow )
        s_d_char( Code( ")" ) )
        s_d_begin( A_D_VAL )
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_HAFTED Or lub_category = UB_TV_POLEARM Or lub_category = UB_TV_SWORD Then
        s_d_damage_dice( gub_item_damage_dice , gub_item_damage_sides )
        lub_misc = UB_MISC_FLAGS
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_DIGGING Then
        lub_misc = UB_MISC_ZPLUSSES
        ' N.B: Moria shows the sides twice here, e.g. (3d3) for a 1d3 shovel, it is copied faithfully
        s_d_damage_dice( gub_item_damage_sides , gub_item_damage_sides )
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_AMULET Then
        If lub_modify Then
            s_d_str( "& " )
            s_d_flavour( A_KNOW_AMULETS , A_TABLE_AMULETS , lub_index )
            s_d_str( " Amulet" )
        Else
            s_d_str( "& Amulet" )
            lub_append = true
        End If
        lub_misc = UB_MISC_PLUSSES

    ElseIf lub_category = UB_TV_RING Then
        If lub_modify Then
            s_d_str( "& " )
            s_d_flavour( A_KNOW_ROCKS , A_TABLE_ROCKS , lub_index )
            s_d_str( " Ring" )
        Else
            s_d_str( "& Ring" )
            lub_append = true
        End If
        lub_misc = UB_MISC_PLUSSES

    ElseIf lub_category = UB_TV_STAFF Then
        If lub_modify Then
            s_d_str( "& " )
            s_d_flavour( A_KNOW_WOODS , A_TABLE_WOODS , lub_index )
            s_d_str( " Staff" )
        Else
            s_d_str( "& Staff" )
            lub_append = true
        End If
        lub_misc = UB_MISC_CHARGES

    ElseIf lub_category = UB_TV_WAND Then
        If lub_modify Then
            s_d_str( "& " )
            s_d_flavour( A_KNOW_METALS , A_TABLE_METALS , lub_index )
            s_d_str( " Wand" )
        Else
            s_d_str( "& Wand" )
            lub_append = true
        End If
        lub_misc = UB_MISC_CHARGES

    ElseIf lub_category = UB_TV_SCROLL1 Or lub_category = UB_TV_SCROLL2 Then
        If lub_modify Then
            s_d_str( "& Scroll~ titled " )
            s_d_char( 34 )
            s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
            s_d_text( A_KNOW_TITLES + Cast( UInteger , lub_index ) * UB_TITLE_SIZE )
            s_d_char( 34 )
        Else
            s_d_str( "& Scroll~" )
            lub_append = true
        End If

    ElseIf lub_category = UB_TV_POTION1 Or lub_category = UB_TV_POTION2 Then
        If lub_modify Then
            s_d_str( "& " )
            s_d_flavour( A_KNOW_COLOURS , A_TABLE_COLOURS , lub_index )
            s_d_str( " Potion~" )
        Else
            s_d_str( "& Potion~" )
            lub_append = true
        End If

    ElseIf lub_category = UB_TV_FOOD Then
        If lub_modify Then
            If lub_index <= 15 Then
                s_d_str( "& " )
                s_d_flavour( A_KNOW_MUSHROOMS , A_TABLE_MUSHROOMS , lub_index )
                s_d_str( " Mushroom~" )
            ElseIf lub_index <= 20 Then
                s_d_str( "& Hairy " )
                s_d_flavour( A_KNOW_MUSHROOMS , A_TABLE_MUSHROOMS , lub_index )
                s_d_str( " Mold~" )
            Else
                s_d_text( A_OBJECT )
            End If
        Else
            lub_append = true
            If lub_index <= 15 Then
                s_d_str( "& Mushroom~" )
            ElseIf lub_index <= 20 Then
                s_d_str( "& Hairy Mold~" )
            Else
                lub_append = false
                s_d_text( A_OBJECT )
            End If
        End If

    ElseIf lub_category = UB_TV_MAGIC_BOOK Then
        s_d_str( "& Book~ of Magic Spells " )
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_PRAYER_BOOK Then
        s_d_str( "& Holy Book~ of Prayers " )
        s_d_text( A_OBJECT )

    ElseIf lub_category = UB_TV_MISC Or lub_category = UB_TV_CHEST Or lub_category = UB_TV_SPIKE Or lub_category = UB_TV_FLASK Or ( lub_category >= UB_TV_BOOTS And lub_category <= UB_TV_SOFT_ARMOR ) Or lub_category = UB_TV_OPEN_DOOR Or lub_category = UB_TV_CLOSED_DOOR Or lub_category = UB_TV_SECRET_DOOR Or lub_category = UB_TV_RUBBLE Then
        s_d_text( A_OBJECT )

    Else
        s_d_begin( A_TEXT_BUFFER )
        s_d_str( "Error in objdes()" )
        Return
    End If

    ' the fetches above may have changed the page in the data slot, the object's name is wanted once more
    If lub_append Then
        s_d_str( " of " )
        s_d_text( A_OBJECT )
    End If

    ' --- one or many ---
    If gub_item_count <> 1 Then
        s_d_replace_first( "ch~" , "ches" )
        s_d_replace_first( "~" , "s" )
    Else
        s_d_replace_first( "~" , "" )
    End If

    ' --- just the name was asked for: without its "& " or its "some " ---
    If gub_lib_param_1 = false Then
        s_d_begin( A_TEXT_BUFFER )
        If Peek( A_D_VAL ) = Code( "s" ) And Peek( A_D_VAL + 1 ) = Code( "o" ) And Peek( A_D_VAL + 2 ) = Code( "m" ) And Peek( A_D_VAL + 3 ) = Code( "e" ) Then
            s_d_text( A_D_VAL + 5 )
        ElseIf Peek( A_D_VAL ) = Code( "&" ) Then
            s_d_text( A_D_VAL + 2 )
        Else
            s_d_text( A_D_VAL )
        End If
        Return
    End If

    ' --- its special name, e.g. "of Slay Evil", once the item has been identified ---
    If gub_item_special_name <> 0 And lub_known2 Then
        s_d_char( 32 )
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
        s_d_text( A_TABLE_SPECIAL_NAMES + Cast( UInteger , gub_item_special_name - 1 ) * UB_SPECIAL_NAME_SIZE )
    End If

    ' --- its damage ---
    s_d_text( A_D_DAM )

    ' --- its plusses to hit and to damage, once identified ---
    If lub_known2 Then
        If ( gub_item_identification bAnd MB_ID_SHOW_HIT_DAM ) <> 0 Then
            s_d_str( " (" )
            s_d_signed( gsw_item_to_hit )
            s_d_char( Code( "," ) )
            s_d_signed( gsw_item_to_damage )
            s_d_char( Code( ")" ) )
        ElseIf gsw_item_to_hit <> 0 Then
            s_d_str( " (" )
            s_d_signed( gsw_item_to_hit )
            s_d_char( Code( ")" ) )
        ElseIf gsw_item_to_damage <> 0 Then
            s_d_str( " (" )
            s_d_signed( gsw_item_to_damage )
            s_d_char( Code( ")" ) )
        End If
    End If

    ' --- its armour class, and the plus to that once identified ---
    If gsw_item_ac <> 0 Or lub_category = UB_TV_HELM Then
        s_d_str( " [" )
        s_d_number( gsw_item_ac )
        If lub_known2 Then
            s_d_char( Code( "," ) )
            s_d_signed( gsw_item_to_ac )
        End If
        s_d_char( Code( "]" ) )
    ElseIf gsw_item_to_ac <> 0 And lub_known2 Then
        s_d_str( " [" )
        s_d_signed( gsw_item_to_ac )
        s_d_char( Code( "]" ) )
    End If

    ' --- its misc use number, shown according to what it means ---
    If ( gub_item_identification bAnd MB_ID_NO_SHOW_P1 ) <> 0 Then
        lub_misc = UB_MISC_IGNORED
    ElseIf ( gub_item_identification bAnd MB_ID_SHOW_P1 ) <> 0 Then
        lub_misc = UB_MISC_ZPLUSSES
    End If
    If lub_misc = UB_MISC_LIGHT Then
        s_d_str( " with " )
        s_d_number( gsw_item_misc_use )
        s_d_str( " turns of light" )
    ElseIf lub_misc <> UB_MISC_IGNORED And lub_known2 Then
        If lub_misc = UB_MISC_ZPLUSSES Then
            s_d_str( " (" )
            s_d_signed( gsw_item_misc_use )
            s_d_char( Code( ")" ) )
        ElseIf lub_misc = UB_MISC_CHARGES Then
            s_d_str( " (" )
            s_d_number( gsw_item_misc_use )
            s_d_str( " charges)" )
        ElseIf gsw_item_misc_use <> 0 Then
            If lub_misc = UB_MISC_PLUSSES Then
                s_d_str( " (" )
                s_d_signed( gsw_item_misc_use )
                s_d_char( Code( ")" ) )
            ElseIf lub_misc = UB_MISC_FLAGS Then
                If ( gul_item_flags bAnd UL_TR_STR ) <> 0 Then
                    s_d_str( " (" )
                    s_d_signed( gsw_item_misc_use )
                    s_d_str( " to STR)" )
                ElseIf ( gul_item_flags bAnd UL_TR_STEALTH ) <> 0 Then
                    s_d_str( " (" )
                    s_d_signed( gsw_item_misc_use )
                    s_d_str( " to stealth)" )
                End If
            End If
        End If
    End If

    ' --- the finished description goes into the text buffer, with "a", "an", a number or "no more" in front ---
    s_d_begin( A_TEXT_BUFFER )
    If Peek( A_D_VAL ) = Code( "&" ) Then
        If gub_item_count > 1 Then
            s_d_number( gub_item_count )
        ElseIf gub_item_count < 1 Then
            s_d_str( "no more" )
        Else
            lub_char = Peek( A_D_VAL + 2 ) bOr 32           ' the first letter of the name, as a small letter
            If lub_char = Code( "a" ) Or lub_char = Code( "e" ) Or lub_char = Code( "i" ) Or lub_char = Code( "o" ) Or lub_char = Code( "u" ) Then
                s_d_str( "an" )
            Else
                s_d_char( Code( "a" ) )
            End If
        End If
        s_d_text( A_D_VAL + 1 )
    ElseIf gub_item_count < 1 Then
        s_d_str( "no more " )
        If Peek( A_D_VAL ) = Code( "s" ) And Peek( A_D_VAL + 1 ) = Code( "o" ) And Peek( A_D_VAL + 2 ) = Code( "m" ) And Peek( A_D_VAL + 3 ) = Code( "e" ) Then
            s_d_text( A_D_VAL + 5 )
        Else
            s_d_text( A_D_VAL )
        End If
    Else
        s_d_text( A_D_VAL )
    End If

    ' --- the notes in curly brackets: tried, magik, empty, damned, and anything the player has written on it ---
    s_d_begin( A_D_VAL )
    lub_flags = fub_items_knowledge( lub_category , gub_item_sub_category )
    If lub_flags <> 255 Then
        If ( lub_flags bAnd MB_OD_TRIED ) <> 0 And ( gub_item_identification bAnd MB_ID_STORE_BOUGHT ) = 0 Then s_d_str( "tried " )
    End If
    If ( gub_item_identification bAnd MB_ID_MAGIK ) <> 0 Then s_d_str( "magik " )
    If ( gub_item_identification bAnd MB_ID_EMPTY ) <> 0 Then s_d_str( "empty " )
    If ( gub_item_identification bAnd MB_ID_DAMD ) <> 0 Then s_d_str( "damned " )
    If Peek( A_ITEM + UB_ITEM_INSCRIPTION_OFFSET ) <> 0 Then
        i = 0
        While i < 12 And Peek( A_ITEM + UB_ITEM_INSCRIPTION_OFFSET + i ) <> 0
            s_d_char( Peek( A_ITEM + UB_ITEM_INSCRIPTION_OFFSET + i ) )
            i = i + 1
        End While
    ElseIf gub_d_len > 0 Then
        gub_d_len = gub_d_len - 1               ' take off the space after the last note
        Poke A_D_VAL + gub_d_len , 0
    End If
    If Peek( A_D_VAL ) <> 0 Then
        ' N.B: the notes were built in A_D_VAL, move them out of the way so the description can be added to again
        i = 0
        Do
            Poke A_D_TAIL + i , Peek( A_D_VAL + i )
            If Peek( A_D_TAIL + i ) = 0 Then Exit Do
            i = i + 1
        Loop
    Else
        Poke A_D_TAIL , 0
    End If

    ' pick the description up where it was left: find its end
    guw_d_base = A_TEXT_BUFFER
    gub_d_len  = 0
    While Peek( A_TEXT_BUFFER + gub_d_len ) <> 0
        gub_d_len = gub_d_len + 1
    End While
    If Peek( A_D_TAIL ) <> 0 Then
        s_d_str( " {" )
        s_d_text( A_D_TAIL )
        s_d_char( Code( "}" ) )
    End If
    s_d_char( Code( "." ) )
End Sub


'##################################################################################################################################
' --- a new item, and a new game ---

Sub s_items_from_object( puw_object As UInteger )
    ' makes the working item a brand new one of the given kind, Moria's inventoryItemCopyTo(): the item record is laid
    ' out to match the object record from byte 32 on, so that part is one copy
    Dim i As UByte

    s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , puw_object , A_OBJECT )
    For i = 0 To 31
        Poke A_ITEM + i , 0             ' no special name, nothing known about it, no inscription
    Next
    s_core_ram_copy( A_OBJECT + UB_ITEM_OBJECT_FIELDS , A_ITEM + UB_ITEM_OBJECT_FIELDS , UB_RECORD_SIZE - UB_ITEM_OBJECT_FIELDS )
    guw_item_object = puw_object
End Sub


Sub s_items_store_bought()
    ' Moria's itemIdentifyAsStoreBought(): the item is known for what it is, it is no longer "magik" or "empty", its
    ' kind is no longer "tried", and its plusses and charges are known
    Dim lsw_offset  As Integer
    Dim luw_flags   As UInteger

    gub_item_identification = gub_item_identification bOr MB_ID_STORE_BOUGHT
    gub_item_identification = gub_item_identification bAnd ( 255 - ( MB_ID_MAGIK bOr MB_ID_EMPTY ) )
    lsw_offset = fsw_items_position_offset( gub_item_category , gub_item_sub_category )
    If lsw_offset >= 0 Then
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
        luw_flags = A_KNOW_IDENTIFIED + ( Cast( UInteger , lsw_offset ) << 6 ) + ( gub_item_sub_category bAnd 63 )
        Poke luw_flags , Peek( luw_flags ) bAnd ( 255 - MB_OD_TRIED )
    End If
    gub_item_identification = gub_item_identification bOr MB_ID_KNOWN2
End Sub


Sub s_items_shuffle( puw_order As UInteger , pub_count As UByte , pub_first As UByte )
    ' puts one family's names into this game's order: starts with them in their natural order, then swaps each one
    ' from pub_first on with another picked at random, exactly as Moria shuffles its lists...
    ' ...N.B: the potion colours keep their first three in place (pub_first is 3), those are water, apple juice and
    ' slime mold juice, which always look like what they are
    Dim i , lub_other , lub_swap    As UByte

    For i = 0 To pub_count - 1
        Poke puw_order + i , i
    Next
    For i = pub_first To pub_count - 1
        If pub_first = 0 Then
            lub_other = Cast( UByte , ful_core_random_number( pub_count ) ) - 1
        Else
            lub_other = Cast( UByte , ful_core_random_number( pub_count - pub_first ) ) + pub_first - 1
        End If
        lub_swap = Peek( puw_order + i )
        Poke puw_order + i , Peek( puw_order + lub_other )
        Poke puw_order + lub_other , lub_swap
    Next
End Sub


Sub s_items_new_game()
    ' Moria's magicInitializeItemNames(): everything here is drawn from the game's fixed "magic seed", so that a
    ' Blue Potion is the same thing all the way through one game, and something else in the next
    Dim luw_title , luw_i                           As UInteger
    Dim lub_parts , lub_part , lub_syllables , i    As UByte
    Dim lub_syllable , lub_length                   As UByte

    gul_game_old_seed = gul_game_random_seed
    s_core_random_seed( gul_game_magic_seed )

    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
    ' the player knows nothing yet about any kind of item
    For luw_i = 0 To UW_KNOW_IDENTIFIED_SIZE - 1
        Poke A_KNOW_IDENTIFIED + luw_i , 0
    Next

    ' N.B: the order of these six, and of the scroll titles after them, is Moria's, it is the order the random numbers are used in
    s_items_shuffle( A_KNOW_COLOURS , UB_MAX_COLOURS , 3 )
    s_items_shuffle( A_KNOW_WOODS , UB_MAX_WOODS , 0 )
    s_items_shuffle( A_KNOW_METALS , UB_MAX_METALS , 0 )
    s_items_shuffle( A_KNOW_ROCKS , UB_MAX_ROCKS , 0 )
    s_items_shuffle( A_KNOW_AMULETS , UB_MAX_AMULETS , 0 )
    s_items_shuffle( A_KNOW_MUSHROOMS , UB_MAX_MUSHROOMS , 0 )

    ' a title for each kind of scroll: two or three words of one or two random syllables each, cut off at 8 or 9 letters
    For luw_title = 0 To UB_MAX_TITLES - 1
        s_d_begin( A_D_VAL )
        lub_parts = Cast( UByte , ful_core_random_number( 2 ) ) + 1
        For lub_part = 1 To lub_parts
            lub_syllables = Cast( UByte , ful_core_random_number( 2 ) )
            For i = 1 To lub_syllables
                lub_syllable = Cast( UByte , ful_core_random_number( UB_MAX_SYLLABLES ) ) - 1
                s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_GAME_TABLES )
                s_d_text( A_TABLE_SYLLABLES + Cast( UInteger , lub_syllable ) * UB_SYLLABLE_SIZE )
            Next
            If lub_part < lub_parts Then s_d_char( 32 )
        Next
        lub_length = gub_d_len
        If lub_length > 8 Then
            If Peek( A_D_VAL + 8 ) = 32 Then
                lub_length = 8
            Else
                lub_length = 9
            End If
        End If
        s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_KNOWLEDGE )
        For i = 0 To UB_TITLE_SIZE - 1
            If i < lub_length Then
                Poke A_KNOW_TITLES + luw_title * UB_TITLE_SIZE + i , Peek( A_D_VAL + i )
            Else
                Poke A_KNOW_TITLES + luw_title * UB_TITLE_SIZE + i , 0
            End If
        Next
    Next

    s_core_random_seed( gul_game_old_seed )
End Sub


'##################################################################################################################################
' --- a screenful of samples, for checking this page ---

Sub s_items_test_line( pub_row As UByte , puw_object As UInteger , pub_count As UByte , pub_identification As UByte )
    Dim ls_text As String

    s_items_from_object( puw_object )
    gub_item_count          = pub_count
    gub_item_identification = pub_identification
    gub_lib_param_1         = true
    s_items_describe()
    ls_text = fs_core_text_at( A_TEXT_BUFFER )
    s_core_print_string_at( pub_row , 2 , fs_core_number( puw_object ) , UB_DARK_GREY )
    s_core_print_string_at( pub_row , 7 , ls_text , UB_WHITE )
End Sub


Sub s_items_test()
    ' each line is an object number from Moria's table, how many of them, and what the player knows about the item
    Dim lub_row As UByte = 3

    s_core_clear_screen()
    s_core_print_string_at( 1 , 2 , "Sample item descriptions (object number, then the description)" , UB_BRIGHT_WHITE )

    s_items_test_line( 3 , 268 , 1 , 0 )                            ' a flask of oil
    s_items_test_line( 4 , 268 , 5 , 0 )                            ' several flasks
    s_items_test_line( 5 , 30 , 1 , 0 )                             ' a weapon, not identified
    s_items_test_line( 6 , 30 , 1 , MB_ID_KNOWN2 )                  ' the same, identified, with no plusses
    gsw_item_to_hit    = 2
    gsw_item_to_damage = -1
    gub_item_identification = MB_ID_KNOWN2 bOr MB_ID_SHOW_HIT_DAM
    gub_lib_param_1 = true
    s_items_describe()
    s_core_print_string_at( 7 , 7 , fs_core_text_at( A_TEXT_BUFFER ) , UB_WHITE )      ' and with plusses
    s_items_test_line( 8 , 103 , 1 , 0 )                            ' armour, not identified
    s_items_test_line( 9 , 103 , 1 , MB_ID_KNOWN2 )                 ' and identified
    s_items_test_line( 10 , 237 , 1 , 0 )                           ' a potion the player does not know
    s_items_test_line( 11 , 237 , 3 , 0 )                           ' several of them
    s_items_test_line( 12 , 237 , 3 , MB_ID_STORE_BOUGHT )          ' bought in a store, so known
    s_items_test_line( 13 , 180 , 1 , 0 )                           ' a scroll the player does not know
    s_items_test_line( 14 , 180 , 2 , MB_ID_STORE_BOUGHT )
    s_items_test_line( 15 , 282 , 1 , 0 )                           ' a wand the player does not know
    s_items_test_line( 16 , 282 , 1 , MB_ID_STORE_BOUGHT bOr MB_ID_KNOWN2 )     ' and one known, with its charges
    s_items_test_line( 17 , 293 , 1 , 0 )                           ' a staff
    s_items_test_line( 18 , 141 , 1 , 0 )                           ' a ring
    s_items_test_line( 19 , 164 , 1 , 0 )                           ' an amulet
    s_items_test_line( 20 , 322 , 1 , 0 )                           ' a prayer book
    s_items_test_line( 21 , 365 , 1 , 0 )                           ' a torch
    s_items_test_line( 22 , 350 , 1 , MB_ID_KNOWN2 )                ' a shovel
    s_items_test_line( 23 , 21 , 1 , 0 )                            ' food
    s_items_test_line( 24 , 372 , 1 , 0 )                           ' a store door
    s_items_test_line( 25 , 399 , 1 , 0 )                           ' gold
    gub_lib_param_1 = false
    s_items_from_object( 345 )                                      ' biscuits come five at a time
    s_items_describe()
    s_core_print_string_at( 26 , 2 , "name only: " + fs_core_text_at( A_TEXT_BUFFER ) , UB_DARK_GREY )

    ' a long one, printed straight from the text buffer from half way across, so that it has to carry on underneath
    s_items_from_object( 30 )
    gub_item_special_name   = 20                            ' special name number 20, "of Stealth"
    gsw_item_to_hit         = 2
    gsw_item_to_damage      = -1
    gub_item_identification = MB_ID_KNOWN2 bOr MB_ID_SHOW_HIT_DAM bOr MB_ID_MAGIK bOr MB_ID_DAMD
    Poke A_ITEM + UB_ITEM_INSCRIPTION_OFFSET , Code( "m" )
    Poke A_ITEM + UB_ITEM_INSCRIPTION_OFFSET + 1 , Code( "i" )
    Poke A_ITEM + UB_ITEM_INSCRIPTION_OFFSET + 2 , Code( "n" )
    Poke A_ITEM + UB_ITEM_INSCRIPTION_OFFSET + 3 , Code( "e" )
    gub_lib_param_1 = true
    s_items_describe()
    lub_row = fub_core_print_text_at( 27 , 50 , A_TEXT_BUFFER , UB_BRIGHT_CYAN )
    s_core_print_string_at( 27 , 2 , "long, from column 50, took " + fs_core_number( lub_row ) + " rows:" , UB_DARK_GREY )
    s_core_print_string_at( 30 , 2 , "[ press any key ]" , UB_BRIGHT_GREEN )
    s_core_get_key()
End Sub


'##################################################################################################################################
' --- the way in ---

Sub s_lib_items()
    gub_d_saved_page = gub_core_MMU2_page_number

    If gub_lib_function = UB_LIB_ITEMS_DESCRIBE Then
        s_items_describe()
    ElseIf gub_lib_function = UB_LIB_ITEMS_NEW_GAME Then
        s_items_new_game()
    ElseIf gub_lib_function = UB_LIB_ITEMS_FROM_OBJECT Then
        s_items_from_object( guw_lib_param_2 )
    ElseIf gub_lib_function = UB_LIB_ITEMS_TEST Then
        s_items_test()
    ElseIf gub_lib_function = UB_LIB_ITEMS_KIND_KNOWN Then
        gsw_lib_result = fub_items_kind_is_known()
    ElseIf gub_lib_function = UB_LIB_ITEMS_STORE_BOUGHT Then
        s_items_store_bought()
    End If

    ' the caller gets back the page it had in the third data slot, 255 means it had none of ours there yet
    If gub_d_saved_page <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , gub_d_saved_page )
End Sub
