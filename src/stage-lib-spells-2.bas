#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_spells_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: the spells that work on the monsters of the level, and on the things the player
' carries, which scrolls, staffs, spell books and prayers all share, from Moria's spells.cpp and monster.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_2 , <which routine> ), each leaves
' true in gsw_lib_result if the player noticed anything, the routines are:
'
'   UB_LIB_SPELLS_2_SLEEP_ADJACENT  the monsters beside the player fall asleep, those that can, monsterSleep()
'   UB_LIB_SPELLS_2_AGGRAVATE       every monster wakes, and the near ones speed up, spellAggravateMonsters( 20 )
'   UB_LIB_SPELLS_2_MASS_GENOCIDE   every monster within sight is destroyed, spellMassGenocide()
'   UB_LIB_SPELLS_2_GENOCIDE        every monster of a kind the player names by its symbol is destroyed, spellGenocide()
'   UB_LIB_SPELLS_2_DISPEL          every monster in sight with any of the "defenses" bits in guw_lib_param_2 is
'                                   hurt, by up to gub_lib_param_1, spellDispelCreature()
'   UB_LIB_SPELLS_2_IDENTIFY        the player picks something from the pack and learns all about it,
'                                   spellIdentifyItem(), false if they backed out
'   UB_LIB_SPELLS_2_RECHARGE        the player picks a wand or staff and it gains charges, or is destroyed,
'                                   guw_lib_param_2 is how strong the recharging is, spellRechargeItem(), false if
'                                   there was nothing to recharge or they backed out
'   UB_LIB_SPELLS_2_REMOVE_CURSE    the curse comes off everything worn, spellRemoveCurseFromAllWornItems()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - what the player learns from genocide, nothing in Moria either
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_s2_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_s2_monster( pub_monster As UByte ) As UInteger
    ' where the record of one of the level's monsters is
    Return fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
End Function


Function fs_s2_name( pub_monster As UByte ) As String
    ' how a monster is spoken of, Moria's monsterNameDescription(), its creature is fetched into A_CREATURE
    Dim luw_record As UInteger

    luw_record = fuw_s2_monster( pub_monster )
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
    If Peek( fuw_s2_monster( pub_monster ) + UB_MONSTER_LIT_OFFSET ) Then Return "The " + fs_core_text_at( A_CREATURE )
    Return "It"
End Function


Sub s_s2_delete_monster( pub_monster As UByte )
    ' Moria's dungeonDeleteMonster(), the monster moves library keeps the level's list of monsters
    gub_lib_param_1 = pub_monster
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
End Sub


Sub s_s2_prompt( ps_prompt As String )
    ' leaves the question the inventory library is to ask
    Dim i , lub_length As UByte

    lub_length = Len( ps_prompt )
    For i = 0 To lub_length - 1
        Poke A_PROMPT + i , Code( ps_prompt( i ) )
    Next
    Poke A_PROMPT + lub_length , 0
End Sub


'##################################################################################################################################
' --- the monsters ---

Function fub_s2_sleep_adjacent() As UByte
    ' Moria's monsterSleep()
    Dim y , x , lub_monster As UByte
    Dim ls_name             As String
    Dim lub_asleep          As UByte = false
    Dim luw_learn           As UInteger

    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            lub_monster = Peek( fuw_core_map_square( gub_level_map_page , y , x ) + UB_SQUARE_MONSTER )
            If lub_monster > 1 Then
                ls_name = fs_s2_name( lub_monster )
                If fuw_s2_random( UB_MON_MAX_LEVELS ) < gub_creature_level Or ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then
                    ' a player who can see it learns that this kind of creature never sleeps, if that is why
                    luw_learn = fuw_s2_monster( lub_monster )
                    If Peek( luw_learn + UB_MONSTER_LIT_OFFSET ) <> 0 And ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then
                        ful_core_recall( Peek( UInteger , luw_learn + UB_MONSTER_CREATURE_OFFSET ) , UB_RECALL_DEFENSES , UW_CD_NO_SLEEP )
                    End If
                    s_msg( ls_name + " is unaffected." )
                Else
                    Poke UInteger fuw_s2_monster( lub_monster ) + UB_MONSTER_SLEEP_OFFSET , 500
                    lub_asleep = true
                    s_msg( ls_name + " falls asleep." )
                End If
            End If
        Next
    Next
    Return lub_asleep
End Function


Function fub_s2_aggravate() As UByte
    ' Moria's spellAggravateMonsters( 20 )
    Dim lub_monster     As UByte
    Dim luw_record      As UInteger
    Dim lsw_speed       As Integer
    Dim lub_aggravated  As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_s2_monster( lub_monster )
        Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
        lsw_speed = Peek( Integer , luw_record + UB_MONSTER_SPEED_OFFSET )
        If Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) <= 20 And lsw_speed < 2 Then
            Poke UInteger luw_record + UB_MONSTER_SPEED_OFFSET , Cast( UInteger , lsw_speed + 1 )
            lub_aggravated = true
        End If
    End While
    If lub_aggravated Then s_core_message( UW_MSG_YOU_HEAR_A_SUDDEN_STIRRING_IN_THE )
    Return lub_aggravated
End Function


Function fub_s2_genocide( pub_mass As UByte ) As UByte
    ' Moria's spellMassGenocide() and spellGenocide(): every monster within sight, or every monster of the kind
    ' whose symbol the player gives, wherever it is, is destroyed, all but the one whose death wins the game
    Dim lub_monster , lub_symbol    As UByte
    Dim luw_record                  As UInteger
    Dim lub_killed                  As UByte = false

    If pub_mass = false Then
        ' Moria's getTileCharacter()
        s_msg_flush()
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "Which type of creature do you wish exterminated?" , UB_BRIGHT_WHITE )
        s_core_get_key()
        s_msg_clear()
        If gub_key_char = 27 Or guw_key_code = 0 Then Return false
        lub_symbol = gub_key_char
    End If

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_s2_monster( lub_monster )
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
        If pub_mass Then
            If Peek( fuw_s2_monster( lub_monster ) + UB_MONSTER_DISTANCE_OFFSET ) <= UB_MON_MAX_SIGHT And ( gul_creature_movement bAnd UL_CM_WIN ) = 0 Then
                lub_killed = true
                s_s2_delete_monster( lub_monster )
            End If
        ElseIf gub_creature_sprite = lub_symbol Then
            If ( gul_creature_movement bAnd UL_CM_WIN ) = 0 Then
                lub_killed = true
                s_s2_delete_monster( lub_monster )
            Else
                ' genocide is a powerful spell, so we will let the player know the names of the creatures they did not destroy
                s_msg( "The " + fs_core_text_at( A_CREATURE ) + " is unaffected." )
            End If
        End If
    End While
    Return lub_killed
End Function


Function fub_s2_dispel( puw_defense As UInteger , pub_damage As UByte ) As UByte
    ' Moria's spellDispelCreature(): every monster of the kind, within sight and in a clear line, is hurt
    Dim lub_monster     As UByte
    Dim luw_record      As UInteger
    Dim ls_name         As String
    Dim lub_dispelled   As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_s2_monster( lub_monster )
        If Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) <= UB_MON_MAX_SIGHT Then
            ls_name = fs_s2_name( lub_monster )
            If ( guw_creature_defenses bAnd puw_defense ) <> 0 Then
                luw_record = fuw_s2_monster( lub_monster )
                guw_lib_param_2 = ( Cast( UInteger , gub_player_row ) << 8 ) bOr gub_player_col
                gsw_lib_result  = ( Cast( UInteger , Peek( luw_record + UB_MONSTER_ROW_OFFSET ) ) << 8 ) bOr Peek( luw_record + UB_MONSTER_COL_OFFSET )
                s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_LOS )
                If gsw_lib_result Then
                    ' the player learns that this kind of creature is of this kind
                    ful_core_recall( Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , UB_RECALL_DEFENSES , puw_defense )
                    lub_dispelled = true
                    ' the player attack library does the hurting, and the dying, Moria's monsterTakeHit()
                    gub_lib_param_1 = lub_monster
                    guw_lib_param_2 = fuw_s2_random( pub_damage )
                    s_core_call_library( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_TAKE_HIT )
                    If gsw_lib_result Then
                        s_msg( ls_name + " dissolves!" )
                        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
                    Else
                        s_msg( ls_name + " shudders." )
                    End If
                End If
            End If
        End If
    End While
    Return lub_dispelled
End Function


'##################################################################################################################################
' --- what the player carries ---

Function fuw_s2_record( pub_place As UByte ) As UInteger
    ' where the record for one place in the pack or the equipment is
    Return A_INVENTORY + Cast( UInteger , pub_place ) * UB_RECORD_SIZE
End Function


Function fsw_s2_choose( pub_category_1 As UByte , pub_category_2 As UByte , ps_prompt As String ) As Integer
    ' the player picks something from the pack, of one of two categories, or of any if the first is 0, -1 if there
    ' is nothing of the kind, -2 if the player backed out
    Dim lsw_first , lsw_last , lsw_i    As Integer
    Dim lub_category                    As UByte

    lsw_first = -1
    lsw_last  = -1
    If gsw_player_pack_unique > 0 Then
        For lsw_i = 0 To gsw_player_pack_unique - 1
            lub_category = Peek( fuw_s2_record( lsw_i ) + UB_ITEM_CATEGORY_OFFSET )
            Poke A_INV_MASK + lsw_i , 0
            If pub_category_1 = 0 Or lub_category = pub_category_1 Or lub_category = pub_category_2 Then
                If lsw_first < 0 Then lsw_first = lsw_i
                lsw_last = lsw_i
                Poke A_INV_MASK + lsw_i , 1
            End If
        Next
    End If
    If lsw_first < 0 Then Return -1
    s_s2_prompt( ps_prompt )
    gub_lib_param_1 = false
    guw_lib_param_2 = Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    If gsw_lib_result < 0 Then Return -2
    Return gsw_lib_result
End Function


Function fs_s2_wearing( pub_where As UByte ) As String
    ' Moria's playerItemWearingDescription(), pub_where is one of the UB_EQUIP_ values
    If pub_where = UB_EQUIP_WIELD Then Return "wielding"
    If pub_where = UB_EQUIP_HEAD Then Return "wearing on your head"
    If pub_where = UB_EQUIP_NECK Then Return "wearing around your neck"
    If pub_where = UB_EQUIP_BODY Then Return "wearing on your body"
    If pub_where = UB_EQUIP_ARM Then Return "wearing on your arm"
    If pub_where = UB_EQUIP_HANDS Then Return "wearing on your hands"
    If pub_where = UB_EQUIP_RIGHT Then Return "wearing on your right hand"
    If pub_where = UB_EQUIP_LEFT Then Return "wearing on your left hand"
    If pub_where = UB_EQUIP_FEET Then Return "wearing on your feet"
    If pub_where = UB_EQUIP_OUTER Then Return "wearing about your body"
    If pub_where = UB_EQUIP_LIGHT Then Return "using to light the way"
    Return "holding ready by your side"
End Function


Function fub_s2_identify() As UByte
    ' Moria's spellIdentifyItem(): the kind of thing becomes known, and then everything about this one
    ' N.B: / in the question goes over to what is being worn
    Dim lsw_place   As Integer
    Dim luw_record  As UInteger
    Dim i           As UByte

    For i = 0 To UB_PACK_SIZE - 1
        Poke A_INV_MASK + i , 1
    Next
    s_s2_prompt( "Item you wish identified?" )
    gub_lib_param_1 = UB_INV_CHOOSE_TRY
    guw_lib_param_2 = Cast( UInteger , UB_INVENTORY_SIZE ) << 8
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    lsw_place = gsw_lib_result
    If lsw_place < 0 Then Return false

    guw_lib_param_2 = lsw_place
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY )
    lsw_place  = gsw_lib_result
    luw_record = fuw_s2_record( lsw_place )
    s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_KNOW_FULLY )
    s_core_ram_copy( A_ITEM , luw_record , UB_RECORD_SIZE )

    gub_lib_param_1 = true
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
    If lsw_place >= UB_PACK_SIZE Then
        ' something that is being worn: what it does for the player may have changed, and it is spoken of by
        ' where it is worn, Moria's playerItemWearingDescription()
        s_core_ram_copy( A_TEXT_BUFFER , A_LIB_PRIVATE + 256 , 160 )
        s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
        s_msg( fs_s2_wearing( lsw_place - UB_PACK_SIZE ) + ": " + fs_core_text_at( A_LIB_PRIVATE + 256 ) )
    Else
        s_msg( fs_core_char( 97 + lsw_place ) + " " + fs_core_text_at( A_TEXT_BUFFER ) )
    End If
    Return true
End Function


Function fub_s2_recharge( psw_charges As Integer ) As UByte
    ' Moria's spellRechargeItem(): the stronger the item and the more charges it still has, the more likely it
    ' is to be destroyed instead
    Dim lsw_place , lsw_fail , lsw_charges  As Integer
    Dim luw_record                          As UInteger
    Dim lub_depth , lub_flags               As UByte

    lsw_place = fsw_s2_choose( UB_TV_STAFF , UB_TV_WAND , "Recharge which item?" )
    If lsw_place = -1 Then s_core_message( UW_MSG_YOU_HAVE_NOTHING_TO_RECHARGE )
    If lsw_place < 0 Then Return false

    luw_record  = fuw_s2_record( lsw_place )
    lub_depth   = Peek( luw_record + UB_ITEM_DEPTH_OFFSET )
    lsw_charges = Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET )
    ' recharge I = recharge(20) = 1/6 failure for empty 10th level wand, recharge II = recharge(60) = 1/10
    ' failure for empty 10th level wand, make it harder to recharge high level, and highly charged wands
    lsw_fail = psw_charges + 50 - Cast( Integer , lub_depth ) - lsw_charges
    If lsw_fail < 19 Then
        ' automatic failure
        lsw_fail = 1
    Else
        lsw_fail = fuw_s2_random( lsw_fail / 10 )
    End If

    If lsw_fail = 1 Then
        s_core_message( UW_MSG_THERE_IS_A_BRIGHT_FLASH_OF_LIGHT )
        guw_lib_param_2 = lsw_place
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY )
    Else
        psw_charges = ( psw_charges / ( Cast( Integer , lub_depth ) + 2 ) ) + 1
        lsw_charges = lsw_charges + 2 + Cast( Integer , fuw_s2_random( psw_charges ) )
        Poke UInteger luw_record + UB_ITEM_MISC_USE_OFFSET , Cast( UInteger , lsw_charges )
        ' how many charges it has is no longer known, nor is it known to be empty
        lub_flags = Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET )
        Poke luw_record + UB_ITEM_IDENTIFICATION_OFFSET , lub_flags bAnd ( 255 - ( MB_ID_KNOWN2 bOr MB_ID_EMPTY ) )
    End If
    Return true
End Function


Function fub_s2_remove_curse() As UByte
    ' Moria's spellRemoveCurseFromAllWornItems(): everything worn, from the weapon in hand to the cloak
    Dim lub_place   As UByte
    Dim luw_flags   As UInteger
    Dim lub_removed As UByte = false

    For lub_place = UB_PACK_SIZE + UB_EQUIP_WIELD To UB_PACK_SIZE + UB_EQUIP_OUTER
        luw_flags = fuw_s2_record( lub_place ) + UB_ITEM_FLAGS_OFFSET
        If ( Peek( ULong , luw_flags ) bAnd UL_TR_CURSED ) <> 0 Then
            Poke ULong luw_flags , Peek( ULong , luw_flags ) bAnd ( $FFFFFFFF - UL_TR_CURSED )
            s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )
            lub_removed = true
        End If
    Next
    Return lub_removed
End Function


Sub s_lib_spells_2()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte
    Dim lub_noticed                         As UByte = false
    Dim luw_amount                          As UInteger
    Dim lub_amount                          As UByte

    luw_amount       = guw_lib_param_2
    lub_amount       = gub_lib_param_1
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the creatures database is read through the items' slot, so that slot is put back as it was found too
    lub_saved_page_1 = gub_core_MMU1_page_number
    If gub_lib_function = UB_LIB_SPELLS_2_SLEEP_ADJACENT Then
        lub_noticed = fub_s2_sleep_adjacent()
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_AGGRAVATE Then
        lub_noticed = fub_s2_aggravate()
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_MASS_GENOCIDE Then
        lub_noticed = fub_s2_genocide( true )
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_GENOCIDE Then
        lub_noticed = fub_s2_genocide( false )
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_DISPEL Then
        lub_noticed = fub_s2_dispel( luw_amount , lub_amount )
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_IDENTIFY Then
        lub_noticed = fub_s2_identify()
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_RECHARGE Then
        lub_noticed = fub_s2_recharge( Cast( Integer , luw_amount ) )
    ElseIf gub_lib_function = UB_LIB_SPELLS_2_REMOVE_CURSE Then
        lub_noticed = fub_s2_remove_curse()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_noticed
End Sub
