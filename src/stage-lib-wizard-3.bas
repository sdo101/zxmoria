#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_wizard_3()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: two wizard commands the wizard library, stage-lib-wizard.bas, has no room for,
' it sends for them through the core: s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_3 , <which routine> )
'
'   UB_LIB_WIZARD_3_SAMPLE  Ctrl-B: a sample of random objects written to a file, Moria's
'                           outputRandomLevelObjectsToFile(), see s_w3_sample() below
'
' and one that is NOT Moria's, it is ours, for testing the game without the character dying all the time, the key
' is $ in wizard mode:
'
'   UB_LIB_WIZARD_3_SUPER   makes the character superhuman:
'       - every stat 18/100, experience level 39 and half way to level 40, 30000 hit points and mana, 500000 gold
'       - worn, in place of whatever was worn there: a Holy Avenger of a two-handed sword, 9d9 (+50,+50), that
'         slays everything, burns and freezes, and keeps off fire, cold, acid and lightning, plate armour, shield,
'         helm, gauntlets of free action, boots of slow descent and a cloak, each with a great deal of armour,
'         and a full lantern
'       - in the pack, as far as there is room: three of each book of the character's own magic (the mage's
'         books for a character with none), potions of invulnerability, healing and restore mana, scrolls of
'         word of recall, teleport, identify and magic mapping, food, oil, wands of stone to mud and teleport
'         away, staffs of teleportation and speed, and a ring of speed
'     everything is fully known, the tables at the bottom of this page say what, and how much of it
'
' N.B: hit points and mana are 30000, not the 32767 a number can hold, so that healing a point or two cannot wrap round
' N.B: every spell or prayer the character's level allows is learnt too, in the order they come in the books


Function fuw_w3_table( pub_which As UByte ) As UInteger
    ' the two tables, see below
    If pub_which = 1 Then Return @w3_pack
    Return @w3_worn
w3_worn:
    ' what is worn, 12 bytes each: the equipment place (a UB_EQUIP_ value, 255 ends the table), the object, the
    ' special name, + to hit, + to damage, + to armour, P1 (2 bytes), and the flags (4 bytes)
    Asm
        defb 0                      ; UB_EQUIP_WIELD: a two-handed sword (Zweihander), a Holy Avenger
        defw 50
        defb 6, 50, 50, 10
        defw 1
        defw $E800, $03FF           ; slays, brands, resistances, sustain, free action, see invisible, regeneration
        defb 3                      ; UB_EQUIP_BODY: ribbed plate armour, of Resistance
        defw 122
        defb 1, 0, 0, 50
        defw 0
        defw $0000, $0238           ; resist fire, acid, cold and lightning
        defb 4                      ; UB_EQUIP_ARM: a large metal shield, of Resistance
        defw 131
        defb 1, 0, 0, 30
        defw 0
        defw $0000, $0238
        defb 1                      ; UB_EQUIP_HEAD: a steel helm, of Seeing
        defw 98
        defb 31, 0, 0, 30
        defw 0
        defw $0000, $0100           ; see invisible
        defb 5                      ; UB_EQUIP_HANDS: gauntlets of Free Action
        defw 125
        defb 14, 0, 0, 30
        defw 0
        defw $0000, $0080
        defb 8                      ; UB_EQUIP_FEET: hard leather boots of Slow Descent
        defw 93
        defb 18, 0, 0, 30
        defw 0
        defw $0000, $0400
        defb 9                      ; UB_EQUIP_OUTER: a cloak of Protection
        defw 123
        defb 39, 0, 0, 30
        defw 0
        defw $0000, $0000
        defb 10                     ; UB_EQUIP_LIGHT: a brass lantern, full
        defw 85
        defb 0, 0, 0, 0
        defw 15000
        defw $0000, $0000
        defb 255
    End Asm
w3_pack:
    ' what goes in the pack, 5 bytes each: the object (0 ends the table), how many, and P1 if it is to be set
    ' (charges, for wands and staffs), N.B: the first four are the mage's books, 4 is added to each for a priest
    Asm
        defw 318
        defb 3
        defw 0
        defw 319
        defb 3
        defw 0
        defw 320
        defb 3
        defw 0
        defw 321
        defb 3
        defw 0
        defw 256                    ; potions of invulnerability
        defb 10
        defw 0
        defw 242                    ; potions of healing
        defb 20
        defw 0
        defw 266                    ; potions of restore mana
        defb 10
        defw 0
        defw 220                    ; scrolls of word of recall
        defb 10
        defw 0
        defw 186                    ; scrolls of teleport
        defb 20
        defw 0
        defw 176                    ; scrolls of identify
        defb 30
        defw 0
        defw 189                    ; scrolls of magic mapping
        defb 15
        defw 0
        defw 21                     ; rations of food
        defb 20
        defw 0
        defw 268                    ; flasks of oil
        defb 20
        defw 0
        defw 273                    ; a wand of stone to mud
        defb 1
        defw 50
        defw 285                    ; a wand of teleport away
        defb 1
        defw 50
        defw 298                    ; a staff of teleportation
        defb 1
        defw 50
        defw 309                    ; a staff of speed
        defb 1
        defw 50
        defw 136                    ; a ring of speed
        defb 1
        defw 1
        defw 0
    End Asm
    Return 0
End Function


Sub s_w3_make( puw_object As UInteger )
    ' the working item becomes a new one of a kind, and all is known about it
    guw_lib_param_2 = puw_object
    s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_FROM_OBJECT )
    ' the kind of thing it is, which potion, which scroll, and then its own plusses and charges
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_IDENTIFY_WORKING )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_KNOW_FULLY )
End Sub


Sub s_w3_super()
    Dim luw_at , luw_record , luw_object    As UInteger
    Dim lub_place , i , lub_tries           As UByte
    Dim lul_mask                            As ULong

    ' --- the character ---
    For i = UB_STAT_STR To UB_STAT_CHR
        Poke A_PLAYER_STATS_MAX + i , 118
        gub_lib_param_1 = i
        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE )
    Next
    ' experience, and so the levels, one at a time, as far as level 39, the last but one, and then half way from
    ' there to level 40, so that the last level is still there to be gained
    lub_tries = 0
    While guw_player_level < 39 And lub_tries < 60
        ' just enough for the next level, Moria's player_base_exp_levels[] and the character's own factor
        gsl_player_exp = Peek( Long , A_EXP_LEVELS + ( guw_player_level - 1 ) * 4 ) * Cast( Long , gub_player_exp_factor ) / 100 + 1
        s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
        ' "Welcome to level 2." is not waited for, there would be 39 of them
        gub_message_length = 0
        lub_tries = lub_tries + 1
    End While
    ' N.B: level 40 is reached at the 39th entry of the table, level 39 at the 38th, each times the character's
    ' own factor, which goes by race and class
    gsl_player_exp           = ( Peek( Long , A_EXP_LEVELS + 37 * 4 ) + Peek( Long , A_EXP_LEVELS + 38 * 4 ) ) / 2 * Cast( Long , gub_player_exp_factor ) / 100
    gsl_player_max_exp       = gsl_player_exp
    gsw_player_max_hp        = 30000
    gsw_player_current_hp    = 30000
    guw_player_hp_fraction   = 0
    gsw_player_mana          = 30000
    gsw_player_current_mana  = 30000
    guw_player_mana_fraction = 0
    gsl_player_gold          = 500000

    ' --- what is worn ---
    luw_at = fuw_w3_table( 0 )
    While Peek( luw_at ) <> 255
        lub_place  = UB_PACK_SIZE + Peek( luw_at )
        luw_record = A_INVENTORY + Cast( UInteger , lub_place ) * UB_RECORD_SIZE
        If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
            ' whatever was worn there is gone
            gsw_player_pack_weight = gsw_player_pack_weight - Peek( Integer , luw_record + UB_ITEM_WEIGHT_OFFSET ) * Cast( Integer , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) )
        Else
            gsw_player_equipment_count = gsw_player_equipment_count + 1
        End If
        s_w3_make( Peek( UInteger , luw_at + 1 ) )
        gub_item_special_name = Peek( luw_at + 3 )
        gsw_item_to_hit       = Peek( luw_at + 4 )
        gsw_item_to_damage    = Peek( luw_at + 5 )
        gsw_item_to_ac        = Peek( luw_at + 6 )
        If Peek( UInteger , luw_at + 7 ) <> 0 Then gsw_item_misc_use = Peek( Integer , luw_at + 7 )
        gul_item_flags        = gul_item_flags bOr Peek( ULong , luw_at + 9 )
        If Peek( luw_at ) = UB_EQUIP_WIELD Then
            gub_item_damage_dice  = 9
            gub_item_damage_sides = 9
        End If
        gub_item_identification = gub_item_identification bOr MB_ID_KNOWN2 bOr MB_ID_STORE_BOUGHT bOr MB_ID_SHOW_HIT_DAM
        s_core_ram_copy( A_ITEM , luw_record , UB_RECORD_SIZE )
        gsw_player_pack_weight = gsw_player_pack_weight + Cast( Integer , guw_item_weight )
        luw_at = luw_at + 13
    End While
    gub_player_weapon_heavy = false
    s_core_call_library( UB_PAGED_CODE_LIB_EQUIPMENT , UB_LIB_EQUIP_RECALC )

    ' --- the pack ---
    luw_at = fuw_w3_table( 1 )
    i = 0
    While Peek( UInteger , luw_at ) <> 0
        luw_object = Peek( UInteger , luw_at )
        ' the first four are books, a priest or a paladin gets the prayer books instead of the mage's
        If i < 4 And gub_class_spell_type = 2 Then luw_object = luw_object + 4
        s_w3_make( luw_object )
        gub_item_count = Peek( luw_at + 2 )
        If Peek( UInteger , luw_at + 3 ) <> 0 Then gsw_item_misc_use = Peek( Integer , luw_at + 3 )
        s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CAN_CARRY )
        If gsw_lib_result Then s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CARRY )
        luw_at = luw_at + 5
        i = i + 1
    End While
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_STRENGTH )
    ' the spells and the mana that go with the new level and stats...
    s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
    ' ...and every spell or prayer the character's level allows is learnt, in the order they come in the books, so
    ' that nothing has to be studied: the table has four bytes for each spell, the first is the level it comes at
    If gub_class_spell_type <> 0 Then
        lul_mask = 1
        For i = 0 To 30
            s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
            If Peek( A_TABLE_SPELLS + Cast( UInteger , gub_player_class - 1 ) * 124 + Cast( UInteger , i ) * 4 ) <= guw_player_level Then
                If ( gul_player_spells_learnt bAnd lul_mask ) = 0 Then
                    gul_player_spells_learnt    = gul_player_spells_learnt bOr lul_mask
                    gul_player_spells_forgotten = gul_player_spells_forgotten bAnd ( $FFFFFFFF - lul_mask )
                    ' the first free place in the order they were learnt in, 99 marks one
                    lub_place = 0
                    While lub_place < 31 And Peek( A_PLAYER_SPELL_ORDER + lub_place ) <> 99
                        lub_place = lub_place + 1
                    End While
                    Poke A_PLAYER_SPELL_ORDER + lub_place , i
                End If
            End If
            lul_mask = lul_mask << 1
        Next
        s_core_call_library( UB_PAGED_CODE_LIB_MAGIC , UB_LIB_MAGIC_CALC )
    End If
    gsw_player_mana         = 30000
    gsw_player_current_mana = 30000
    gsw_player_max_hp       = 30000
    gsw_player_current_hp   = 30000
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
    ' the words along the bottom, "Study" has gone
    gul_player_status = gul_player_status bOr UL_PY_STUDY
    s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_STATUS_LINE )
    gub_message_length = 0
    s_msg( "You feel superhuman." )
End Sub


'##################################################################################################################################
' --- a sample of random objects, written to a file ---

#include "stage-wizard-include.bas"

#include "stage-textfile-include.bas"


Sub s_w3_sample()
    ' Ctrl-B, or Ctrl-O with the rogue like commands: Moria's outputRandomLevelObjectsToFile(), a list of the things
    ' that would be found lying about on a level, as many as asked for, written to a file on the SD card for looking
    ' at afterwards, each line is the depth the thing is first found at, and its full description
    ' N.B: the file is written 8KB at a time, see stage-textfile-include.bas, so it ends with spaces
    Dim luw_level , luw_count , luw_i   As UInteger
    Dim lub_small , i                   As UByte

    If fub_wz_ask( "Produce objects on what level?: " , 10 ) = false Then Return
    If gub_wz_valid = false Then Return
    If gsl_wz_number < 0 Or gsl_wz_number > 1200 Then
        s_msg( "Parameters no good." )
        Return
    End If
    luw_level = gsl_wz_number
    If fub_wz_ask( "Produce how many objects?: " , 10 ) = false Then Return
    If gub_wz_valid = false Then Return
    If gsl_wz_number < 1 Then
        s_msg( "Parameters no good." )
        Return
    End If
    If gsl_wz_number > 10000 Then gsl_wz_number = 10000
    luw_count = gsl_wz_number
    lub_small = fub_wz_confirm( "Small objects only?" )
    If fub_wz_ask( "File name: " , 30 ) = false Then Return
    If Peek( A_PROMPT ) = 0 Then Return

    s_msg_clear()
    s_core_print_string_at( 0 , 0 , fs_core_number( luw_count ) + " random objects being produced..." , UB_WHITE )
    s_tf_begin( A_PROMPT )

    s_tf_write( "*** Random Object Sampling:" )
    s_tf_write( "*** " + fs_core_number( luw_count ) + " objects" )
    s_tf_write( "*** For Level " + fs_core_number( luw_level ) )
    s_tf_write( "" )
    s_tf_write( "" )
    For luw_i = 1 To luw_count
        gub_lib_param_1 = lub_small
        guw_lib_param_2 = luw_level
        s_core_call_library( UB_PAGED_CODE_LIB_OBJECTS , UB_LIB_OBJECTS_RANDOM )
        guw_lib_param_2 = gsw_lib_result
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_FROM_OBJECT )
        guw_lib_param_2 = luw_level
        s_core_call_library( UB_PAGED_CODE_LIB_TREASURE , UB_LIB_TREASURE_MAGIC )
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_STORE_BOUGHT )
        If ( gul_item_flags bAnd UL_TR_CURSED ) <> 0 Then gub_item_identification = gub_item_identification bOr MB_ID_DAMD
        i = gub_item_depth
        gub_lib_param_1 = true
        s_core_call_library( UB_PAGED_CODE_LIB_ITEMS , UB_LIB_ITEMS_DESCRIBE )
        s_tf_write( fs_core_number( i ) + " " + fs_core_text_at( A_TEXT_BUFFER ) )
        If gub_tf_failed Then Exit For
    Next
    s_msg_clear()
    If fub_tf_end() Then
        s_msg( "Completed." )
    Else
        s_msg( "File could not be opened." )
    End If
End Sub


Sub s_lib_wizard_3()
    Dim lub_saved_page_2 As UByte

    ' ours: the wizard may light the level, or change it, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_WIZARD_3_SUPER Then s_w3_super()
    If gub_lib_function = UB_LIB_WIZARD_3_SAMPLE Then s_w3_sample()
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
