#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monster_spells()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"
#include "stage-map-include.bas"
#include "stage-monster-include.bas"
#include "stage-element-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: a monster casting a spell or breathing on the player, from Moria's monster.cpp
' and spells.cpp...
' ...the monster moves library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_SPELLS , <which routine> ),
' the one routine is:
'
'   UB_LIB_MONSTER_SPELLS_CAST      the working monster (A_MONSTER), whose creature is in A_CREATURE and whose number
'                                   on the level is gub_lib_param_1, may cast one of its spells instead of moving,
'                                   Moria's monsterCastSpell(), gsw_lib_result is true if it did
'
' a creature's spells are bits of its "spells" field: the low four bits are how often it casts, one chance in that
' many each move, the rest are the spells it knows, one is picked at random: teleporting itself or the player,
' wounds, holding, blinding, confusing, frightening and slowing the player, summoning, draining mana, and the five
' breaths, which hurt everything within two squares of the player, burn or freeze what is lying there, and do less
' to creatures that breathe the same thing themselves
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


' --- working storage, private to this page, see A_LIB_PRIVATE in constants.bas ---
#define A_MS_NAME           A_LIB_PRIVATE               ' 40 bytes, how the caster is spoken of: "The Kobold " or "It "
#define A_MS_CHOICES        A_LIB_PRIVATE + 40          ' 30 bytes, the spells the caster knows
Dim gub_ms_monster          As UByte    At A_LIB_PRIVATE + 72       ' the caster's number on the level


Function fuw_ms_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ms_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ms_los( pub_y1 As UByte , pub_x1 As UByte , pub_y2 As UByte , pub_x2 As UByte ) As UByte
    ' a clear line between two squares, the monsters library works that out, Moria's los()
    guw_lib_param_2 = ( Cast( UInteger , pub_y1 ) << 8 ) bOr pub_x1
    gsw_lib_result  = ( Cast( UInteger , pub_y2 ) << 8 ) bOr pub_x2
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_LOS )
    If gsw_lib_result Then Return true
    Return false
End Function


Function fub_ms_saving_throw() As UByte
    ' Moria's playerSavingThrow()
    Dim lsw_saving As Integer

    gub_lib_param_1 = UB_STAT_WIS
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_saving = gsw_player_saving_throw + gsw_lib_result + Cast( Integer , gub_class_adj_save ) * Cast( Integer , guw_player_level ) / 3
    If Cast( Integer , fuw_ms_random( 100 ) ) <= lsw_saving Then Return true
    Return false
End Function


Sub s_ms_timed( puw_counter As UInteger , psw_more As Integer , puw_range As UInteger , psw_base As Integer )
    ' the end of the spells that hold, blind, confuse, frighten and slow: if the player is already suffering it
    ' lasts a little longer, otherwise it starts, puw_counter is where the count of turns is kept
    ' N.B: a random number is asked for only when it starts, as in Moria
    Dim lsw_now As Integer

    lsw_now = Peek( Integer , puw_counter )
    If lsw_now > 0 Then
        lsw_now = lsw_now + psw_more
    Else
        lsw_now = lsw_now + Cast( Integer , fuw_ms_random( puw_range ) ) + psw_base
    End If
    Poke UInteger puw_counter , Cast( UInteger , lsw_now )
End Sub


'##################################################################################################################################
' --- breath ---

Sub s_ms_breath( psw_damage As Integer , pub_element As UByte )
    ' Moria's spellBreath(), centred on the player: everything within two squares that can be seen from there
    Dim lsw_y , lsw_x , lsw_hurt , lsw_hp   As Integer
    Dim lub_item , lub_victim , lub_range   As UByte
    Dim luw_square , luw_record             As UInteger
    Dim lul_resists                         As ULong
    Dim luw_harms , luw_defenses            As UInteger
    ' the creatures it does double to, and those that breathe it themselves
    lul_resists = ful_el_resists( pub_element )
    luw_harms   = fuw_el_harms( pub_element )

    For lsw_y = Cast( Integer , gub_player_row ) - 2 To Cast( Integer , gub_player_row ) + 2
        For lsw_x = Cast( Integer , gub_player_col ) - 2 To Cast( Integer , gub_player_col ) + 2
            If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                lub_range = fub_mon_distance( gub_player_row , gub_player_col , lsw_y , lsw_x )
                If lub_range <= 2 Then
                    If fub_ms_los( gub_player_row , gub_player_col , lsw_y , lsw_x ) Then
                        luw_square = fuw_cr_square( lsw_y , lsw_x )
                        lub_item   = Peek( luw_square + UB_SQUARE_ITEM )
                        If lub_item <> 0 Then
                            If fub_el_destroys( lub_item , pub_element ) Then gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT , lsw_y , lsw_x )
                        End If
                        luw_square = fuw_cr_square( lsw_y , lsw_x )
                        If Peek( luw_square + UB_SQUARE_FEATURE ) <= UB_TILE_MAX_OPEN Then
                            ' must test status bit, not the blind counter, otherwise the player can see the breath
                            If fub_cr_inside_panel( lsw_y , lsw_x ) And ( gul_player_status bAnd UL_PY_BLIND ) = 0 Then
                                s_core_print_char_at( lsw_y - gub_panel_top + UB_VIEW_SCREEN_ROW , lsw_x - gub_panel_left + UB_VIEW_SCREEN_COL , Code( "*" ) , UB_BRIGHT_YELLOW )
                            End If
                            lub_victim = Peek( luw_square + UB_SQUARE_MONSTER )
                            If lub_victim > 1 Then
                                ' a monster in the breath, the breather itself perhaps
                                luw_record   = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_victim )
                                luw_defenses = Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET )
                                luw_record   = fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_defenses )
                                lsw_hurt = psw_damage
                                If ( Peek( UInteger , luw_record + UB_CREATURE_DEFENSES_OFFSET ) bAnd luw_harms ) <> 0 Then
                                    lsw_hurt = lsw_hurt * 2
                                ElseIf ( Peek( ULong , luw_record + UB_CREATURE_SPELLS_OFFSET ) bAnd lul_resists ) <> 0 Then
                                    lsw_hurt = lsw_hurt / 4
                                End If
                                lsw_hurt = lsw_hurt / ( Cast( Integer , lub_range ) + 1 )
                                If lub_victim = gub_ms_monster Then
                                    ' the breather is in the working monster, which is what gets kept when its turn is over
                                    gsw_monster_hp = gsw_monster_hp - lsw_hurt
                                    lsw_hp         = gsw_monster_hp
                                Else
                                    luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_victim )
                                    lsw_hp     = Peek( Integer , luw_record ) - lsw_hurt
                                    Poke UInteger luw_record , Cast( UInteger , lsw_hp )
                                    Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
                                End If
                                If lsw_hp < 0 Then
                                    ' it dies, and leaves what it carried, the player gains nothing by it: one that
                                    ' has not had its turn yet comes off the list later, when its turn would have been
                                    If gub_ms_monster < lub_victim Then
                                        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_KILL , lub_victim , 0 )
                                    Else
                                        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_KILL , lub_victim , 1 )
                                    End If
                                End If
                            ElseIf lub_victim = 1 Then
                                ' the player
                                lsw_hurt = psw_damage / ( Cast( Integer , lub_range ) + 1 )
                                ' let's do at least one point of damage, prevents randint(0) problem with damagePoisonedGas, also
                                If lsw_hurt = 0 Then lsw_hurt = 1
                                gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_DAMAGE , pub_element , lsw_hurt )
                            End If
                        End If
                    End If
                End If
            End If
        Next
    Next

    ' the breath shows for a moment, then the squares are drawn as they now are
    ' N.B: a counted loop and not a wait for the next frame, interrupts are off while a page of code runs
    For luw_harms = 1 To 8000
    Next
    For lsw_y = Cast( Integer , gub_player_row ) - 2 To Cast( Integer , gub_player_row ) + 2
        For lsw_x = Cast( Integer , gub_player_col ) - 2 To Cast( Integer , gub_player_col ) + 2
            If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
                If fub_mon_distance( gub_player_row , gub_player_col , lsw_y , lsw_x ) <= 2 Then s_cr_put( lsw_y , lsw_x )
            End If
        Next
    Next
End Sub


'##################################################################################################################################
' --- the spells ---

Sub s_ms_teleport_player_to( pub_y As UByte , pub_x As UByte )
    ' Moria's spellTeleportPlayerTo(): the player is brought to an open square beside the monster, or as near as
    ' one can be found
    Dim lsw_y , lsw_x , lsw_distance    As Integer
    Dim lub_counter , lub_found         As UByte
    Dim y , x                           As UByte
    Dim luw_square                      As UInteger

    lsw_distance = 1
    lub_counter  = 0
    Do
        lsw_y = Cast( Integer , pub_y ) + Cast( Integer , fuw_ms_random( 2 * lsw_distance + 1 ) ) - ( lsw_distance + 1 )
        lsw_x = Cast( Integer , pub_x ) + Cast( Integer , fuw_ms_random( 2 * lsw_distance + 1 ) ) - ( lsw_distance + 1 )
        lub_counter = lub_counter + 1
        If lub_counter > 9 Then
            lub_counter  = 0
            lsw_distance = lsw_distance + 1
        End If
        lub_found = false
        If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
            luw_square = fuw_cr_square( lsw_y , lsw_x )
            If Peek( luw_square + UB_SQUARE_FEATURE ) < UB_TILE_MIN_CLOSED And Peek( luw_square + UB_SQUARE_MONSTER ) < 2 Then lub_found = true
        End If
    Loop Until lub_found

    Poke fuw_cr_square( gub_player_row , gub_player_col ) + UB_SQUARE_MONSTER , 0
    Poke fuw_cr_square( lsw_y , lsw_x ) + UB_SQUARE_MONSTER , 1
    ' the player's own light goes from where they were
    For y = gub_player_row - 1 To gub_player_row + 1
        For x = gub_player_col - 1 To gub_player_col + 1
            luw_square = fuw_cr_square( y , x ) + UB_SQUARE_FLAGS
            Poke luw_square , Peek( luw_square ) bAnd ( 255 - MB_SQUARE_TEMP_LIGHT )
            s_cr_put( y , x )
        Next
    Next
    gub_player_row = lsw_y
    gub_player_col = lsw_x
    gub_player_temp_light_only = false
    ' the walking stage does the rest, Moria's dungeonResetView() and updateMonsters()
    gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_RESET_VIEW bOr MB_TURN_UPDATE_MONSTERS
End Sub


Sub s_ms_execute( pub_spell As UByte )
    ' Moria's monsterExecuteCastingOfSpell()
    Dim lsw_drained As Integer

    If pub_spell = 5 Then
        ' teleport short
        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY , 0 , 5 )
    ElseIf pub_spell = 6 Then
        ' teleport long
        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY , 0 , UB_MON_MAX_SIGHT )
    ElseIf pub_spell = 7 Then
        ' teleport to
        s_ms_teleport_player_to( gub_monster_row , gub_monster_col )
    ElseIf pub_spell = 8 Or pub_spell = 9 Then
        ' light wound, serious wound
        If fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        ElseIf pub_spell = 8 Then
            s_hit_player( fuw_core_dice_roll( 3 , 8 ) )
        Else
            s_hit_player( fuw_core_dice_roll( 8 , 8 ) )
        End If
    ElseIf pub_spell = 10 Then
        ' hold person
        If gub_player_free_action Then
            s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
        ElseIf fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        Else
            s_ms_timed( @gsw_player_paralysis , 2 , 5 , 4 )
        End If
    ElseIf pub_spell = 11 Then
        ' cause blindness
        If fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        Else
            s_ms_timed( @gsw_player_blind , 6 , 3 , 12 )
        End If
    ElseIf pub_spell = 12 Then
        ' cause confusion
        If fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        Else
            s_ms_timed( @gsw_player_confused , 2 , 5 , 3 )
        End If
    ElseIf pub_spell = 13 Then
        ' cause fear
        If fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        Else
            s_ms_timed( @gsw_player_afraid , 2 , 5 , 3 )
        End If
    ElseIf pub_spell = 14 Then
        ' summon monster, beside the player
        s_core_message_after( A_MS_NAME , UW_MSG_MAGICALLY_SUMMONS_A_MONSTER )
        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON , 0 , 0 )
    ElseIf pub_spell = 15 Then
        ' summon undead
        s_core_message_after( A_MS_NAME , UW_MSG_MAGICALLY_SUMMONS_AN_UNDEAD )
        gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON_UNDEAD , 0 , 0 )
    ElseIf pub_spell = 16 Then
        ' slow person
        If gub_player_free_action Then
            s_core_message( UW_MSG_YOU_ARE_UNAFFECTED )
        ElseIf fub_ms_saving_throw() Then
            s_core_message( UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE )
        Else
            s_ms_timed( @gsw_player_slow , 2 , 5 , 3 )
        End If
    ElseIf pub_spell = 17 Then
        ' drain mana
        If gsw_player_current_mana > 0 Then
            s_mon_disturb()
            s_core_message_after( A_MS_NAME , UW_MSG_DRAWS_PSYCHIC_ENERGY_FROM_YOU )
            If gub_monster_lit Then s_core_message_after( A_MS_NAME , UW_MSG_APPEARS_HEALTHIER )
            lsw_drained = ( fuw_ms_random( gub_creature_level ) >> 1 ) + 1
            If lsw_drained > gsw_player_current_mana Then
                lsw_drained = gsw_player_current_mana
                gsw_player_current_mana  = 0
                guw_player_mana_fraction = 0
            Else
                gsw_player_current_mana = gsw_player_current_mana - lsw_drained
            End If
            s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
            gsw_monster_hp = gsw_monster_hp + 6 * lsw_drained
        End If
    ElseIf pub_spell = 20 Then
        s_core_message_after( A_MS_NAME , UW_MSG_BREATHES_LIGHTNING )
        s_ms_breath( gsw_monster_hp / 4 , UB_ELEMENT_LIGHTNING )
    ElseIf pub_spell = 21 Then
        s_core_message_after( A_MS_NAME , UW_MSG_BREATHES_GAS )
        s_ms_breath( gsw_monster_hp / 3 , UB_ELEMENT_GAS )
    ElseIf pub_spell = 22 Then
        s_core_message_after( A_MS_NAME , UW_MSG_BREATHES_ACID )
        s_ms_breath( gsw_monster_hp / 3 , UB_ELEMENT_ACID )
    ElseIf pub_spell = 23 Then
        s_core_message_after( A_MS_NAME , UW_MSG_BREATHES_FROST )
        s_ms_breath( gsw_monster_hp / 3 , UB_ELEMENT_FROST )
    ElseIf pub_spell = 24 Then
        s_core_message_after( A_MS_NAME , UW_MSG_BREATHES_FIRE )
        s_ms_breath( gsw_monster_hp / 3 , UB_ELEMENT_FIRE )
    Else
        s_core_message_after( A_MS_NAME , UW_MSG_CAST_UNKNOWN_SPELL )
    End If
End Sub


Function fub_ms_cast() As UByte
    ' Moria's monsterCastSpell(), with its monsterCanCastSpells()
    Dim lul_spells , lul_mask   As ULong
    Dim lub_count , lub_bit     As UByte
    Dim lub_spell , lub_first   As UByte
    Dim ls_name                 As String

    If gub_game_character_dead Then Return false

    ' 1 in x chance of casting spell
    If fuw_ms_random( gul_creature_spells bAnd 15 ) <> 1 Then Return false
    ' must be within certain range, and have unobstructed line of sight
    If gub_monster_distance > UB_MON_MAX_SIGHT Then Return false
    If fub_ms_los( gub_player_row , gub_player_col , gub_monster_row , gub_monster_col ) = false Then Return false

    ' creature is going to cast a spell: check to see if the monster should be lit
    gub_shared_1 = fub_ms_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_VISIBILITY , gub_ms_monster , 0 )

    ' how the caster is spoken of, and what the player will have died from if this kills them
    ls_name = fs_core_text_at( A_CREATURE )
    If gub_monster_lit Then
        s_hit_killer( "The " + ls_name + " " )
    Else
        s_hit_killer( "It " )
    End If
    s_core_ram_copy( A_KILLER , A_MS_NAME , 39 )
    lub_first = Peek( A_CREATURE ) bOr 32           ' the first letter of its name, in lower case
    If ( gul_creature_movement bAnd UL_CM_WIN ) <> 0 Then
        s_hit_killer( "The " + ls_name )
    ElseIf lub_first = Code( "a" ) Or lub_first = Code( "e" ) Or lub_first = Code( "i" ) Or lub_first = Code( "o" ) Or lub_first = Code( "u" ) Then
        s_hit_killer( "an " + ls_name )
    Else
        s_hit_killer( "a " + ls_name )
    End If

    ' extract all possible spells into the list, and choose one at random
    lul_spells = gul_creature_spells bAnd $FFFFFFF0
    lul_mask   = 1
    lub_count  = 0
    lub_bit    = 0
    While lul_spells <> 0
        If ( lul_spells bAnd lul_mask ) <> 0 Then
            lul_spells = lul_spells bAnd ( $FFFFFFFF - lul_mask )
            Poke A_MS_CHOICES + lub_count , lub_bit
            lub_count = lub_count + 1
        End If
        lul_mask = lul_mask << 1
        lub_bit  = lub_bit + 1
    End While
    If lub_count = 0 Then Return false
    lub_spell = Peek( A_MS_CHOICES + fuw_ms_random( lub_count ) - 1 ) + 1

    ' all except teleport away, and drain mana spells, always disturb
    If lub_spell > 6 And lub_spell <> 17 Then s_mon_disturb()
    ' save some code and data space here, with a small time penalty
    If ( lub_spell < 14 And lub_spell > 6 ) Or lub_spell = 16 Then s_core_message_after( A_MS_NAME , UW_MSG_CASTS_A_SPELL )

    s_ms_execute( lub_spell )
    ' N.B: the monster moves library puts this into the monster memory, there is no room for it here
    gub_shared_2 = lub_spell
    Return true
End Function


Sub s_lib_monster_spells()
    Dim lub_cast            As UByte = false
    Dim lub_saved_page_1    As UByte

    ' N.B: the creatures database is read through the items' slot, so that slot is put back as it was found
    lub_saved_page_1 = gub_core_MMU1_page_number
    If gub_lib_function = UB_LIB_MONSTER_SPELLS_CAST Then
        gub_ms_monster = gub_lib_param_1
        lub_cast = fub_ms_cast()
    End If
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    gsw_lib_result = lub_cast
End Sub
