#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_throw()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-disturb-include.bas"
#include "stage-combat-include.bas"
#include "stage-fight-include.bas"

' this page is a LIBRARY, not a stage: throwing and firing, Moria's player_throw.cpp...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_THROW , <which routine> ),
' the one routine is:
'
'   UB_LIB_THROW_ITEM       the player picks something from the pack and throws it, or fires it if it is the
'                           ammunition for the bow or sling in hand, Moria's playerThrowItem()
'
' what is NOT here yet:
'   - what the player learns about a kind of creature when it dies of a thrown thing is the player attack library's doing
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- its working storage is in globals.bas, under "private to stage-lib-throw.bas", moved there on 22 October 2026 ---

Function fs_ft_thrown_name() As String
    ' what the thing in flight is called, without "a" or its numbers
    s_core_ram_copy( A_FT_THROWN , A_ITEM , UB_RECORD_SIZE )
    gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , false , 0 )
    Return fs_core_text_at( A_TEXT_BUFFER )
End Function


Sub s_ft_lands( pub_y As UByte , pub_x As UByte )
    ' Moria's inventoryDropOrThrowItem(): the thing comes to rest on the square, or on one beside it, or, one time
    ' in ten and whenever there is no room, is lost
    Dim lsw_y , lsw_x       As Integer
    Dim luw_square          As UInteger
    Dim lub_tries , lub_ok  As UByte
    Dim lub_number          As UByte

    lsw_y  = pub_y
    lsw_x  = pub_x
    lub_ok = false
    If fuw_cb_random( 10 ) > 1 Then
        lub_tries = 0
        While lub_ok = false And lub_tries <= 9
            If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                luw_square = fuw_cr_square( lsw_y , lsw_x )
                If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_ITEM ) = 0 Then lub_ok = true
            End If
            If lub_ok = false Then
                lsw_y = Cast( Integer , pub_y ) + Cast( Integer , fuw_cb_random( 3 ) ) - 2
                lsw_x = Cast( Integer , pub_x ) + Cast( Integer , fuw_cb_random( 3 ) ) - 2
                lub_tries = lub_tries + 1
            End If
        End While
    End If
    ' the level's list of items may be full, room is made by throwing distant things away, the compact library
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_OBJECTS )
    If gub_dungeon_item_next >= UB_DUN_MAX_ITEMS Then lub_ok = false

    If lub_ok Then
        lub_number = gub_dungeon_item_next
        gub_dungeon_item_next = gub_dungeon_item_next + 1
        s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , lub_number , A_FT_THROWN )
        Poke fuw_cr_square( lsw_y , lsw_x ) + UB_SQUARE_ITEM , lub_number
        s_cr_put( lsw_y , lsw_x )
    Else
        s_msg( "The " + fs_ft_thrown_name() + " disappears." )
    End If
End Sub


Sub s_ft_throw()
    ' Moria's playerThrowItem(), with its inventoryThrow() and weaponMissileFacts()
    Dim lsw_place , lsw_i                       As Integer
    Dim luw_record , luw_bow , luw_square       As UInteger
    Dim lub_direction , lub_category            As UByte
    Dim lsw_base , lsw_plus , lsw_damage        As Integer
    Dim lsw_range , lsw_weight , lsw_flown      As Integer
    Dim lub_old_y , lub_old_x , lub_monster     As UByte
    Dim lub_bow_kind , lub_fired , lub_lit      As UByte
    Dim lsw_multiplier                          As Integer
    Dim ls_name , ls_prompt                     As String
    Dim lub_done                                As UByte = false

    If gsw_player_pack_unique = 0 Then
        s_core_message( UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING )
        gub_game_free_turn = true
        Return
    End If
    For lsw_i = 0 To gsw_player_pack_unique - 1
        Poke A_INV_MASK + lsw_i , 1
    Next
    ls_prompt = "Fire/Throw which one?"
    For lsw_i = 0 To Len( ls_prompt ) - 1
        Poke A_PROMPT + lsw_i , Code( ls_prompt( lsw_i ) )
    Next
    Poke A_PROMPT + Len( ls_prompt ) , 0
    gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE , false , Cast( UInteger , gsw_player_pack_unique - 1 ) << 8 )
    lsw_place = gsw_lib_result
    ' N.B: backing out of either question takes no time, the two questions see to that, as Moria's do
    If lsw_place < 0 Then Return
    lub_direction = fub_ft_direction()
    If lub_direction = 0 Then Return

    ' "You have 4 Flasks of Oil.", Moria's itemTypeRemainingCountDescription()
    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    gub_item_count = gub_item_count - 1
    gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE , true , 0 )
    s_msg( "You have " + fs_core_text_at( A_TEXT_BUFFER ) )

    lub_direction = fub_ft_confused_direction( lub_direction )

    ' one of them leaves the pack, Moria's inventoryThrow()
    s_core_ram_copy( luw_record , A_FT_THROWN , UB_RECORD_SIZE )
    If Peek( luw_record + UB_ITEM_COUNT_OFFSET ) > 1 Then
        Poke A_FT_THROWN + UB_ITEM_COUNT_OFFSET , 1
        Poke luw_record + UB_ITEM_COUNT_OFFSET , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) - 1
        gsw_player_pack_weight = gsw_player_pack_weight - Peek( Integer , luw_record + UB_ITEM_WEIGHT_OFFSET )
        gul_player_status      = gul_player_status bOr UL_PY_STR_WGT
    Else
        gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY , 0 , lsw_place )
    End If

    ' Moria's weaponMissileFacts(): how well it is thrown, how hard it hits and how far it goes, something thrown
    ' by hand goes further the lighter it is, the right ammunition fired from the bow in hand does far more
    lub_category = Peek( A_FT_THROWN + UB_ITEM_CATEGORY_OFFSET )
    lsw_weight   = Peek( Integer , A_FT_THROWN + UB_ITEM_WEIGHT_OFFSET )
    If lsw_weight < 1 Then lsw_weight = 1
    lsw_damage = Cast( Integer , fuw_core_dice_roll( Peek( A_FT_THROWN + UB_ITEM_DAMAGE_OFFSET ) , Peek( A_FT_THROWN + UB_ITEM_DAMAGE_OFFSET + 1 ) ) ) + Peek( Integer , A_FT_THROWN + UB_ITEM_TO_DAMAGE_OFFSET )
    lsw_base   = gsw_player_bth_bows * 75 / 100
    lsw_plus   = gsw_player_to_hit + Peek( Integer , A_FT_THROWN + UB_ITEM_TO_HIT_OFFSET )
    luw_bow    = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_WIELD ) * UB_RECORD_SIZE
    ' get the extra "to hit" from the weapon in hand out of it
    If Peek( luw_bow + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then lsw_plus = lsw_plus - Peek( Integer , luw_bow + UB_ITEM_TO_HIT_OFFSET )
    lsw_range = ( ( Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) + 20 ) * 10 ) / lsw_weight
    If lsw_range > 10 Then lsw_range = 10
    If Peek( luw_bow + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_BOW Then
        ' which bow: 1 sling, 2 short bow, 3 long bow, 4 composite bow, 5 light crossbow, 6 heavy crossbow
        lub_bow_kind   = Peek( luw_bow + UB_ITEM_MISC_USE_OFFSET )
        lub_fired      = false
        lsw_multiplier = 1
        If lub_bow_kind = 1 And lub_category = UB_TV_SLING_AMMO Then
            lub_fired      = true
            lsw_multiplier = 2
            lsw_range      = 20
        ElseIf lub_category = UB_TV_ARROW And lub_bow_kind >= 2 And lub_bow_kind <= 4 Then
            lub_fired      = true
            lsw_multiplier = lub_bow_kind
            lsw_range      = 15 + 5 * Cast( Integer , lub_bow_kind )
        ElseIf lub_category = UB_TV_BOLT And lub_bow_kind = 5 Then
            lub_fired      = true
            lsw_multiplier = 3
            lsw_range      = 25
        ElseIf lub_category = UB_TV_BOLT And lub_bow_kind = 6 Then
            lub_fired      = true
            lsw_multiplier = 4
            lsw_range      = 35
        End If
        If lub_fired Then
            lsw_base   = gsw_player_bth_bows
            lsw_plus   = lsw_plus + 2 * Peek( Integer , luw_bow + UB_ITEM_TO_HIT_OFFSET )
            lsw_damage = ( lsw_damage + Peek( Integer , luw_bow + UB_ITEM_TO_DAMAGE_OFFSET ) ) * lsw_multiplier
        End If
    End If

    ' its flight
    gub_ft_y  = gub_player_row
    gub_ft_x  = gub_player_col
    lub_old_y = gub_ft_y
    lub_old_x = gub_ft_x
    lsw_flown = 0
    While lub_done = false
        s_ft_step( lub_direction )
        lsw_flown = lsw_flown + 1
        s_cr_put( lub_old_y , lub_old_x )
        If lsw_flown > lsw_range Then lub_done = true
        luw_square = fuw_cr_square( gub_ft_y , gub_ft_x )
        If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN And lub_done = false Then
            lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
            If lub_monster > 1 Then
                lub_done = true
                luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster )
                lub_lit    = Peek( luw_record + UB_MONSTER_LIT_OFFSET )
                s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
                lsw_base = lsw_base - lsw_flown
                ' if the monster is not lit, make it much more difficult to hit, subtract off most bonuses, and
                ' reduce the chance by the distance
                If lub_lit = 0 Then
                    lsw_base = lsw_base / ( lsw_flown + 2 )
                    lsw_base = lsw_base - Cast( Integer , guw_player_level ) * Cast( Integer , gub_class_adj_bth_bows ) / 2
                    lsw_base = lsw_base - lsw_plus * 2
                End If
                If fub_cb_test_hit( lsw_base , lsw_plus , gub_creature_ac , gub_class_adj_bth_bows ) Then
                    ls_name = fs_ft_thrown_name()
                    If lub_lit = 0 Then
                        s_msg( "You hear a cry as the " + ls_name + " finds a mark." )
                    Else
                        s_msg( "The " + ls_name + " hits the " + fs_core_text_at( A_CREATURE ) + "." )
                    End If
                    lsw_damage = fsw_cb_magic_damage( A_FT_THROWN , lsw_damage , Peek( UInteger , fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster ) + UB_MONSTER_CREATURE_OFFSET ) )
                    lsw_damage = fsw_cb_critical( Peek( Integer , A_FT_THROWN + UB_ITEM_WEIGHT_OFFSET ) , lsw_plus , lsw_damage , gub_class_adj_bth_bows )
                    If lsw_damage < 0 Then lsw_damage = 0
                    ' N.B: the creature's name is taken before the blow, its record is not there to ask afterwards
                    ls_name = fs_core_text_at( A_CREATURE )
                    If fub_ft_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_TAKE_HIT , lub_monster , Cast( UInteger , lsw_damage ) ) Then
                        If lub_lit = 0 Then
                            s_core_message( UW_MSG_YOU_HAVE_KILLED_SOMETHING )
                        Else
                            s_msg( "You have killed the " + ls_name + "." )
                        End If
                        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
                    End If
                Else
                    s_ft_lands( lub_old_y , lub_old_x )
                End If
            Else
                ' show the thing in flight, where the player can see
                If fub_cr_inside_panel( gub_ft_y , gub_ft_x ) And gsw_player_blind < 1 And ( Peek( luw_square + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) <> 0 Then
                    s_core_print_char_at( gub_ft_y - gub_panel_top + UB_VIEW_SCREEN_ROW , gub_ft_x - gub_panel_left + UB_VIEW_SCREEN_COL , Peek( A_FT_THROWN + UB_ITEM_SPRITE_OFFSET ) , UB_BRIGHT_CYAN )
                    For lsw_i = 1 To 1200
                    Next
                End If
            End If
        Else
            lub_done = true
            s_ft_lands( lub_old_y , lub_old_x )
        End If
        lub_old_y = gub_ft_y
        lub_old_x = gub_ft_x
    End While
End Sub


Sub s_lib_throw()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_THROW_ITEM Then s_ft_throw()
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub