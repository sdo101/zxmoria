#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_cast()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: casting a spell and reciting a prayer, Moria's mage_spells.cpp and
' player_pray.cpp...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_CAST , <which routine> ),
' the routines are:
'
'   UB_LIB_CAST_SPELL       the player picks a magic book and a spell from it, and casts it, getAndCastMagicSpell()
'   UB_LIB_CAST_PRAY        the same with a holy book and a prayer, pray()
'
' gsw_lib_result is true if it took the player's turn, false if they could not or changed their mind
'
' which spells the player knows, and the picking of one, is the books library's, stage-lib-books.bas, what the spells
' do is the spells libraries', stage-lib-spells.bas to stage-lib-spells-5.bas, and the effects library's
' anything the walking stage must do afterwards is asked for in gub_game_turn_flags, the MB_TURN_ bits in constants.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_ca_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_ca_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_ca_text( ps_text As String )
    ' leaves text in A_PROMPT: the question another library is to ask, or the name of a bolt or ball
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    If lub_length > 38 Then lub_length = 38
    i = 0
    While i < lub_length
        Poke A_PROMPT + i , Code( ps_text( i ) )
        i = i + 1
    End While
    Poke A_PROMPT + lub_length , 0
End Sub


Function fub_ca_direction() As UByte
    ' asks which way, Moria's getDirectionWithMemory(), 0 if the player thought better of it
    Dim lub_direction As UByte = 0

    s_core_message( UW_MSG_WHICH_DIRECTION )
    Do
        s_core_get_key()
        s_core_direction_key()
        If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) And gub_key_char <> Code( "5" ) Then lub_direction = gub_key_char - Code( "0" )
        If guw_key_code = UW_KEY_UP Then lub_direction = 8
        If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
        If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
        If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
    Loop Until lub_direction <> 0 Or gub_key_char = UC_ESCAPE Or guw_key_code = 0
    ' the question is not a message, Moria asks it with getCommand() and keeps nothing of it for Ctrl-P
    Asm
        call A_JUMP_HISTORY_FORGET
    End Asm
    s_msg_clear()
    If lub_direction <> 0 Then gub_player_prev_dir = lub_direction
    ' backing out takes no time, and s_ca_cast() then spares the mana, Moria's getDirectionWithMemory() sets
    ' player_free_turn itself
    If lub_direction = 0 Then gub_game_free_turn = true
    Return lub_direction
End Function


Sub s_ca_bolt( pub_function As UByte , puw_dice As UInteger , puw_sides As UInteger , puw_damage As UInteger , pub_element As UByte , ps_name As String )
    ' a bolt or a ball, once the player has said which way, the aimed spells library fires it, the damage is
    ' puw_damage and the throw of puw_dice dice, if any, which, as in Moria, are thrown after the player answers
    Dim lub_direction As UByte

    lub_direction = fub_ca_direction()
    If lub_direction = 0 Then Return
    If puw_dice <> 0 Then puw_damage = puw_damage + fuw_core_dice_roll( puw_dice , puw_sides )
    s_ca_text( ps_name )
    gub_lib_param_1 = lub_direction
    guw_lib_param_2 = puw_damage
    gsw_lib_result  = pub_element
    s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_3 , pub_function )
End Sub


Sub s_ca_aimed( pub_page As UByte , pub_function As UByte , puw_param As UInteger )
    ' one of the other aimed spells, once the player has said which way
    Dim lub_direction As UByte

    lub_direction = fub_ca_direction()
    If lub_direction <> 0 Then gub_shared_1 = fub_ca_call( pub_page , pub_function , lub_direction , puw_param )
End Sub


Sub s_ca_heal( puw_amount As UInteger )
    ' Moria's spellChangePlayerHitPoints()
    gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_HP_CHANGE , 0 , puw_amount )
End Sub


Sub s_ca_spell( pub_function As UByte , puw_param As UInteger )
    ' one of the routines of the first spells library
    gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS , pub_function , 0 , puw_param )
End Sub


Sub s_ca_cure( puw_counter As UInteger )
    ' Moria's playerCurePoison() and playerRemoveFear(): whatever it is has one more turn to run
    If Peek( Integer , puw_counter ) > 1 Then Poke UInteger puw_counter , 1
End Sub


Sub s_ca_timed( puw_counter As UInteger , puw_turns As UInteger )
    ' something that lasts a while is added to, puw_counter is where its count is kept
    Poke UInteger puw_counter , Cast( UInteger , Peek( Integer , puw_counter ) ) + puw_turns
End Sub


Function fub_ca_can_read( ps_blind As String ) As UByte
    ' the first three tests of Moria's canReadSpells() and playerCanPray()
    Dim lub_flags As UByte

    If gsw_player_blind > 0 Then
        s_msg( ps_blind )
        Return false
    End If
    lub_flags = Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_FLAGS )
    If ( lub_flags bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) = 0 Then
        s_core_message( UW_MSG_YOU_HAVE_NO_LIGHT_TO_READ_BY )
        Return false
    End If
    If gsw_player_confused > 0 Then
        s_core_message( UW_MSG_YOU_ARE_TOO_CONFUSED )
        Return false
    End If
    Return true
End Function


Function fsw_ca_book( pub_category As UByte , ps_nothing As String , ps_prompt As String ) As Integer
    ' the player picks one of their books, they are all together in the pack, Moria's inventoryFindRange(), -1 if
    ' there are none or the player backs out
    Dim lsw_first , lsw_last , lsw_i As Integer

    lsw_first = -1
    lsw_last  = -1
    If gsw_player_pack_unique > 0 Then
        For lsw_i = 0 To gsw_player_pack_unique - 1
            Poke A_INV_MASK + lsw_i , 0
            If Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) = pub_category Then
                If lsw_first < 0 Then lsw_first = lsw_i
                lsw_last = lsw_i
                Poke A_INV_MASK + lsw_i , 1
            End If
        Next
    End If
    If lsw_first < 0 Then
        s_msg( ps_nothing )
        Return -1
    End If
    s_ca_text( ps_prompt )
    gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE , false , Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 ) )
    Return gsw_lib_result
End Function


'##################################################################################################################################
' --- the spells ---

Sub s_ca_mage_spell( pub_spell As UByte )
    ' Moria's castSpell(), the spells are numbered from 1 here, as there
    If pub_spell = UB_MAGE_MAGIC_MISSILE Then
        s_ca_bolt( UB_LIB_SPELLS_3_BOLT , 2 , 6 , 0 , 0 , "Magic Missile" )
    ElseIf pub_spell = UB_MAGE_DETECT_MONSTERS Then
        ' detect monsters
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_DETECT , 0 , 0 )
    ElseIf pub_spell = UB_MAGE_PHASE_DOOR Then
        ' phase door
        s_ca_spell( UB_LIB_SPELLS_TELEPORT , 10 )
    ElseIf pub_spell = UB_MAGE_LIGHT_AREA Then
        s_ca_spell( UB_LIB_SPELLS_LIGHT_AREA , 0 )
    ElseIf pub_spell = UB_MAGE_CURE_LIGHT_WOUNDS Then
        ' cure light wounds
        s_ca_heal( fuw_core_dice_roll( 4 , 4 ) )
    ElseIf pub_spell = UB_MAGE_FIND_HIDDEN_TRAPS_DOORS Then
        ' find hidden traps and doors
        s_ca_spell( UB_LIB_SPELLS_DETECT_DOORS , 0 )
        s_ca_spell( UB_LIB_SPELLS_DETECT_TRAPS , 0 )
    ElseIf pub_spell = UB_MAGE_STINKING_CLOUD Then
        s_ca_bolt( UB_LIB_SPELLS_3_BALL , 0 , 0 , 12 , UB_ELEMENT_GAS , "Stinking Cloud" )
    ElseIf pub_spell = UB_MAGE_CONFUSION Then
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_CONFUSE , 0 )
    ElseIf pub_spell = UB_MAGE_LIGHTNING_BOLT Then
        s_ca_bolt( UB_LIB_SPELLS_3_BOLT , 4 , 8 , 0 , UB_ELEMENT_LIGHTNING , "Lightning Bolt" )
    ElseIf pub_spell = UB_MAGE_TRAP_DOOR_DESTRUCTION Then
        ' trap and door destruction
        s_ca_spell( UB_LIB_SPELLS_DESTROY_DOORS , 0 )
    ElseIf pub_spell = UB_MAGE_SLEEP1 Then
        ' sleep I
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SLEEP , 0 )
    ElseIf pub_spell = UB_MAGE_CURE_POISON Then
        s_ca_cure( @gsw_player_poisoned )
    ElseIf pub_spell = UB_MAGE_TELEPORT_SELF Then
        ' teleport self
        s_ca_spell( UB_LIB_SPELLS_TELEPORT , guw_player_level * 5 )
    ElseIf pub_spell = UB_MAGE_REMOVE_CURSE Then
        ' remove curse, from what is worn
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_REMOVE_CURSE , 0 , 0 )
    ElseIf pub_spell = UB_MAGE_FROST_BOLT Then
        s_ca_bolt( UB_LIB_SPELLS_3_BOLT , 6 , 8 , 0 , UB_ELEMENT_FROST , "Frost Bolt" )
    ElseIf pub_spell = UB_MAGE_WALL_TO_MUD Then
        ' turn stone to mud
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_WALL_TO_MUD , 0 )
    ElseIf pub_spell = UB_MAGE_CREATE_FOOD Then
        s_ca_spell( UB_LIB_SPELLS_CREATE_FOOD , 0 )
    ElseIf pub_spell = UB_MAGE_RECHARGE_ITEM1 Then
        ' recharge item I
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_RECHARGE , 0 , 20 )
    ElseIf pub_spell = UB_MAGE_SLEEP2 Then
        ' sleep II
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_SLEEP_ADJACENT , 0 , 0 )
    ElseIf pub_spell = UB_MAGE_POLYMORPH_OTHER Then
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_POLYMORPH , 0 )
    ElseIf pub_spell = UB_MAGE_IDENTIFY_ITEM Then
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_IDENTIFY , 0 , 0 )
    ElseIf pub_spell = UB_MAGE_SLEEP3 Then
        ' sleep III
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SLEEP_ALL , 0 , 0 )
    ElseIf pub_spell = UB_MAGE_FIRE_BOLT Then
        s_ca_bolt( UB_LIB_SPELLS_3_BOLT , 9 , 8 , 0 , UB_ELEMENT_FIRE , "Fire Bolt" )
    ElseIf pub_spell = UB_MAGE_SPEED_MONSTER Then
        ' slow monster
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SPEED , $FFFF )
    ElseIf pub_spell = UB_MAGE_FROST_BALL Then
        s_ca_bolt( UB_LIB_SPELLS_3_BALL , 0 , 0 , 48 , UB_ELEMENT_FROST , "Frost Ball" )
    ElseIf pub_spell = UB_MAGE_RECHARGE_ITEM2 Then
        ' recharge item II
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_RECHARGE , 0 , 60 )
    ElseIf pub_spell = UB_MAGE_TELEPORT_OTHER Then
        ' teleport other
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_TELEPORT_AWAY , 0 )
    ElseIf pub_spell = UB_MAGE_HASTE_SELF Then
        ' haste self
        s_ca_timed( @gsw_player_fast , fuw_ca_random( 20 ) + guw_player_level )
    ElseIf pub_spell = UB_MAGE_FIRE_BALL Then
        s_ca_bolt( UB_LIB_SPELLS_3_BALL , 0 , 0 , 72 , UB_ELEMENT_FIRE , "Fire Ball" )
    ElseIf pub_spell = UB_MAGE_WORD_OF_DESTRUCTION Then
        ' word of destruction
        s_ca_spell( UB_LIB_SPELLS_DESTROY_AREA , 0 )
    ElseIf pub_spell = UB_MAGE_GENOCIDE Then
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_GENOCIDE , 0 , 0 )
    End If
End Sub


'##################################################################################################################################
' --- the prayers ---

Sub s_ca_prayer( pub_prayer As UByte )
    ' Moria's playerRecitePrayer(), the prayers are numbered from 1 here
    Dim i           As UByte
    Dim luw_record  As UInteger
    Dim lub_category As UByte

    If pub_prayer = UB_PRIEST_DETECT_EVIL Then
        ' detect evil
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_DETECT , 0 , UW_CD_EVIL )
    ElseIf pub_prayer = UB_PRIEST_CURE_LIGHT_WOUNDS Then
        ' cure light wounds
        s_ca_heal( fuw_core_dice_roll( 3 , 3 ) )
    ElseIf pub_prayer = UB_PRIEST_BLESS Then
        ' bless
        s_ca_timed( @gsw_player_blessed , fuw_ca_random( 12 ) + 12 )
    ElseIf pub_prayer = UB_PRIEST_REMOVE_FEAR Then
        s_ca_cure( @gsw_player_afraid )
    ElseIf pub_prayer = UB_PRIEST_CALL_LIGHT Then
        ' call light
        s_ca_spell( UB_LIB_SPELLS_LIGHT_AREA , 0 )
    ElseIf pub_prayer = UB_PRIEST_FIND_TRAPS Then
        s_ca_spell( UB_LIB_SPELLS_DETECT_TRAPS , 0 )
    ElseIf pub_prayer = UB_PRIEST_DETECT_DOORS_STAIRS Then
        s_ca_spell( UB_LIB_SPELLS_DETECT_DOORS , 0 )
    ElseIf pub_prayer = UB_PRIEST_SLOW_POISON Then
        ' slow poison, Moria's spellSlowPoison()
        If gsw_player_poisoned > 0 Then
            gsw_player_poisoned = gsw_player_poisoned / 2
            If gsw_player_poisoned < 1 Then gsw_player_poisoned = 1
            s_core_message( UW_MSG_THE_EFFECT_OF_THE_POISON_HAS_BEEN )
        End If
    ElseIf pub_prayer = UB_PRIEST_BLIND_CREATURE Then
        ' blind creature, which in Moria confuses it
        s_ca_aimed( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_CONFUSE , 0 )
    ElseIf pub_prayer = UB_PRIEST_PORTAL Then
        ' portal
        s_ca_spell( UB_LIB_SPELLS_TELEPORT , guw_player_level * 3 )
    ElseIf pub_prayer = UB_PRIEST_CURE_MEDIUM_WOUNDS Then
        ' cure medium wounds
        s_ca_heal( fuw_core_dice_roll( 4 , 4 ) )
    ElseIf pub_prayer = UB_PRIEST_CHANT Then
        ' chant
        s_ca_timed( @gsw_player_blessed , fuw_ca_random( 24 ) + 24 )
    ElseIf pub_prayer = UB_PRIEST_SANCTUARY Then
        ' sanctuary
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_SLEEP_ADJACENT , 0 , 0 )
    ElseIf pub_prayer = UB_PRIEST_CREATE_FOOD Then
        s_ca_spell( UB_LIB_SPELLS_CREATE_FOOD , 0 )
    ElseIf pub_prayer = UB_PRIEST_REMOVE_CURSE Then
        ' remove curse: unlike the mage's it reaches what is in the pack as well, anything that can be wielded or worn
        For i = 0 To UB_INVENTORY_SIZE - 1
            luw_record   = A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE
            lub_category = Peek( luw_record + UB_ITEM_CATEGORY_OFFSET )
            If lub_category >= UB_TV_MIN_WEAR And lub_category <= UB_TV_MAX_WEAR Then
                Poke luw_record + UB_ITEM_FLAGS_OFFSET + 3 , Peek( luw_record + UB_ITEM_FLAGS_OFFSET + 3 ) bAnd $7F     ' UL_TR_CURSED is the top bit
            End If
        Next
    ElseIf pub_prayer = UB_PRIEST_RESIST_HEAD_COLD Then
        ' resist heat and cold
        s_ca_timed( @gsw_player_heat_resistance , fuw_ca_random( 10 ) + 10 )
        s_ca_timed( @gsw_player_cold_resistance , fuw_ca_random( 10 ) + 10 )
    ElseIf pub_prayer = UB_PRIEST_NEUTRALIZE_POISON Then
        ' neutralize poison
        s_ca_cure( @gsw_player_poisoned )
    ElseIf pub_prayer = UB_PRIEST_ORB_OF_DRAINING Then
        ' orb of draining, 11 is UB_ELEMENT_HOLY_ORB in stage-element-include.bas
        s_ca_bolt( UB_LIB_SPELLS_3_BALL , 3 , 6 , guw_player_level , 11 , "Black Sphere" )
    ElseIf pub_prayer = UB_PRIEST_CURE_SERIOUS_WOUNDS Then
        ' cure serious wounds
        s_ca_heal( fuw_core_dice_roll( 8 , 4 ) )
    ElseIf pub_prayer = UB_PRIEST_SENSE_INVISIBLE Then
        ' sense invisible
        s_ca_timed( @gsw_player_detect_invisible , fuw_ca_random( 24 ) + 24 )
    ElseIf pub_prayer = UB_PRIEST_PROTECT_FROM_EVIL Then
        ' protection from evil, Moria's playerProtectEvil()
        s_ca_timed( @gsw_player_protect_evil , fuw_ca_random( 25 ) + 3 * guw_player_level )
    ElseIf pub_prayer = UB_PRIEST_EARTHQUAKE Then
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_EARTHQUAKE , 0 , 0 )
    ElseIf pub_prayer = UB_PRIEST_SENSE_SURROUNDINGS Then
        ' sense surroundings
        s_ca_spell( UB_LIB_SPELLS_MAP_AREA , 0 )
    ElseIf pub_prayer = UB_PRIEST_CURE_CRITICAL_WOUNDS Then
        ' cure critical wounds
        s_ca_heal( fuw_core_dice_roll( 16 , 4 ) )
    ElseIf pub_prayer = UB_PRIEST_TURN_UNDEAD Then
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_TURN_UNDEAD , 0 , 0 )
    ElseIf pub_prayer = UB_PRIEST_PRAYER Then
        ' prayer
        s_ca_timed( @gsw_player_blessed , fuw_ca_random( 48 ) + 48 )
    ElseIf pub_prayer = UB_PRIEST_DISPEL_UNDEAD Then
        ' dispel undead
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_DISPEL , 3 * guw_player_level , UW_CD_UNDEAD )
    ElseIf pub_prayer = UB_PRIEST_HEAL Then
        ' heal
        s_ca_heal( 200 )
    ElseIf pub_prayer = UB_PRIEST_DISPEL_EVIL Then
        ' dispel evil
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_DISPEL , 3 * guw_player_level , UW_CD_EVIL )
    ElseIf pub_prayer = UB_PRIEST_GLYPH_OF_WARDING Then
        s_ca_spell( UB_LIB_SPELLS_GLYPH , 0 )
    ElseIf pub_prayer = UB_PRIEST_HOLY_WORD Then
        ' holy word
        s_ca_cure( @gsw_player_afraid )
        s_ca_cure( @gsw_player_poisoned )
        s_ca_heal( 1000 )
        For i = UB_STAT_STR To UB_STAT_CHR
            gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , i , 0 )
        Next
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_DISPEL , 4 * guw_player_level , UW_CD_EVIL )
        gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_TURN_UNDEAD , 0 , 0 )
        If gsw_player_invulnerability < 3 Then
            gsw_player_invulnerability = 3
        Else
            gsw_player_invulnerability = gsw_player_invulnerability + 1
        End If
    End If
End Sub


'##################################################################################################################################
' --- casting and praying ---

Sub s_ca_cast( pub_pray As UByte )
    ' Moria's getAndCastMagicSpell() and pray(), which differ only in their words and in which spells they reach
    Dim lsw_place , lsw_spell , lsw_chance , lsw_mana   As Integer
    Dim luw_spell                                       As UInteger
    Dim lul_mask                                        As ULong

    gub_game_free_turn = true
    If pub_pray Then
        If fub_ca_can_read( "You can't see to read your prayer!" ) = false Then Return
        If gub_class_spell_type <> UB_SPELL_TYPE_PRIEST Then
            s_core_message( UW_MSG_PRAY_HARD_ENOUGH_AND_YOUR_PRAYERS )
            Return
        End If
        If gsw_player_pack_unique = 0 Then
            s_core_message( UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING_2 )
            Return
        End If
        lsw_place = fsw_ca_book( UB_TV_PRAYER_BOOK , "You are not carrying any Holy Books!" , "Use which Holy Book?" )
    Else
        If fub_ca_can_read( "You can't see to read your spell book!" ) = false Then Return
        If gub_class_spell_type <> UB_SPELL_TYPE_MAGE Then
            s_core_message( UW_MSG_YOU_CANT_CAST_SPELLS )
            Return
        End If
        lsw_place = fsw_ca_book( UB_TV_MAGIC_BOOK , "But you are not carrying any spell-books!" , "Use which spell-book?" )
    End If
    If lsw_place < 0 Then Return

    If pub_pray Then
        s_ca_text( "Recite which prayer?" )
    Else
        s_ca_text( "Cast which spell?" )
    End If
    gub_lib_param_1 = lsw_place
    s_core_call_library( UB_PAGED_CODE_LIB_BOOKS , UB_LIB_BOOKS_CHOOSE )
    lsw_spell  = gsw_lib_result
    lsw_chance = gsl_lib_long_1
    If lsw_spell = -1 Then
        If pub_pray Then
            s_core_message( UW_MSG_YOU_DONT_KNOW_ANY_PRAYERS_IN_THAT )
        Else
            s_core_message( UW_MSG_YOU_DONT_KNOW_ANY_SPELLS_IN_THAT )
        End If
        Return
    End If
    If lsw_spell < 0 Then Return

    ' N.B: some of the spells set this again, creating food for one, and then the turn, the mana and the
    ' experience are all spared
    gub_game_free_turn = false

    ' what the spell costs, from the table of them, see A_TABLE_SPELLS in constants.bas
    s_core_swap_paged_data( UB_SLOT_DB_MAPS , UB_PAGE_OBJECT_LEVELS )
    luw_spell = A_TABLE_SPELLS + Cast( UInteger , gub_player_class - 1 ) * UB_CLASS_SPELLS_SIZE + Cast( UInteger , lsw_spell ) * UB_SPELL_SIZE
    lsw_mana  = Peek( luw_spell + 1 )
    lul_mask  = Cast( ULong , Peek( luw_spell + 3 ) )       ' the experience for the first time it works, kept for a moment

    If Cast( Integer , fuw_ca_random( 100 ) ) < lsw_chance Then
        If pub_pray Then
            s_core_message( UW_MSG_YOU_LOST_YOUR_CONCENTRATION )
        Else
            s_core_message( UW_MSG_YOU_FAILED_TO_GET_THE_SPELL_OFF )
        End If
    Else
        If pub_pray Then
            s_ca_prayer( lsw_spell + 1 )
        Else
            s_ca_mage_spell( lsw_spell + 1 )
        End If
        If gub_game_free_turn = false Then
            If ( gul_player_spells_worked bAnd ( Cast( ULong , 1 ) << lsw_spell ) ) = 0 Then
                gsl_player_exp = gsl_player_exp + ( lul_mask << 2 )
                gul_player_spells_worked = gul_player_spells_worked bOr ( Cast( ULong , 1 ) << lsw_spell )
                s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
            End If
        End If
    End If
    If gub_game_free_turn Then Return

    If lsw_mana > gsw_player_current_mana Then
        If pub_pray Then
            s_core_message( UW_MSG_YOU_FAINT_FROM_FATIGUE )
        Else
            s_core_message( UW_MSG_YOU_FAINT_FROM_THE_EFFORT )
        End If
        gsw_player_paralysis     = fuw_ca_random( 5 * ( lsw_mana - gsw_player_current_mana ) )
        gsw_player_current_mana  = 0
        guw_player_mana_fraction = 0
        If fuw_ca_random( 3 ) = 1 Then
            s_core_message( UW_MSG_YOU_HAVE_DAMAGED_YOUR_HEALTH )
            gub_shared_1 = fub_ca_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_DECREASE , UB_STAT_CON , 0 )
        End If
    Else
        gsw_player_current_mana = gsw_player_current_mana - lsw_mana
    End If
    ' Moria's printCharacterCurrentMana()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
End Sub


Sub s_lib_cast()
    Dim lub_saved_page_2 As UByte

    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_CAST_SPELL Then
        s_ca_cast( false )
    ElseIf gub_lib_function = UB_LIB_CAST_PRAY Then
        s_ca_cast( true )
    End If
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = false
    If gub_game_free_turn = false Then gsw_lib_result = true
End Sub
