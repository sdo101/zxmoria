#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_devices()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"

' this page is a LIBRARY, not a stage: using a staff and aiming a wand, Moria's staves.cpp...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_DEVICES , <which routine> ),
' the routines are:
'
'   UB_LIB_DEVICES_USE_STAFF    the player picks a staff from the pack and uses it, Moria's staffUse()
'   UB_LIB_DEVICES_AIM_WAND     the player picks a wand, says which way, and fires it, Moria's wandAim()
'
' gsw_lib_result is true if it took the player's turn, false if they had none or changed their mind
'
' a staff or wand may fail to work, the harder it is and the less skilled the player with magic devices the more
' often, and it does nothing with no charges left, what it does is in its flags, one bit for each effect, and all
' of them happen, lowest bit first, the effects themselves are the spells libraries', stage-lib-spells.bas to
' stage-lib-spells-5.bas
' anything the walking stage must do afterwards is asked for in gub_game_turn_flags, the MB_TURN_ bits in constants.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_dv_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_dv_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_dv_text( ps_text As String )
    ' leaves text in A_PROMPT: the question the inventory library is to ask, or the name of a bolt or ball
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


Function fsw_dv_choose( pub_category As UByte , ps_nothing As String , ps_prompt As String ) As Integer
    ' the player picks one of the things of a category from the pack, they are all together there, Moria's
    ' inventoryFindRange(), -1 if there are none or the player backs out
    Dim lsw_first , lsw_last , lsw_i As Integer

    If gsw_player_pack_unique = 0 Then
        s_core_message( UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING )
        Return -1
    End If
    lsw_first = -1
    lsw_last  = -1
    For lsw_i = 0 To gsw_player_pack_unique - 1
        Poke A_INV_MASK + lsw_i , 0
        If Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) = pub_category Then
            If lsw_first < 0 Then lsw_first = lsw_i
            lsw_last = lsw_i
            Poke A_INV_MASK + lsw_i , 1
        End If
    Next
    If lsw_first < 0 Then
        s_msg( ps_nothing )
        Return -1
    End If
    s_dv_text( ps_prompt )
    gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE , false , Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 ) )
    Return gsw_lib_result
End Function


Function fub_dv_works( puw_record As UInteger , psw_easier As Integer , ps_what As String ) As UByte
    ' the test both devices make, the end of Moria's staffPlayerCanUse() and the middle of its wandAim(): the
    ' player's skill with magic devices against how deep the thing comes from, and then whether it has a charge
    Dim lsw_chance As Integer

    gub_lib_param_1 = UB_STAT_INT
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    lsw_chance = gsw_player_saving_throw + gsw_lib_result - Cast( Integer , Peek( puw_record + UB_ITEM_DEPTH_OFFSET ) ) + psw_easier
    lsw_chance = lsw_chance + Cast( Integer , gub_class_adj_device ) * Cast( Integer , guw_player_level ) / 3
    ' N.B: as C halves, towards nought, the chance can be below nought for a deep device, see fsw_c_half()
    If gsw_player_confused > 0 Then lsw_chance = fsw_c_half( lsw_chance )
    ' give everyone a slight chance
    If lsw_chance < 3 Then
        If fuw_dv_random( 3 - lsw_chance + 1 ) = 1 Then lsw_chance = 3
    End If
    If lsw_chance <= 0 Then lsw_chance = 1

    If fuw_dv_random( lsw_chance ) < 3 Then
        s_msg( "You failed to use the " + ps_what + " properly." )
        Return false
    End If
    If Peek( Integer , puw_record + UB_ITEM_MISC_USE_OFFSET ) < 1 Then
        s_msg( "The " + ps_what + " has no charges left." )
        ' unless the player already knows all about it, it is marked as empty
        If ( Peek( puw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bAnd MB_ID_KNOWN2 ) = 0 Then Poke puw_record + UB_ITEM_IDENTIFICATION_OFFSET , Peek( puw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bOr MB_ID_EMPTY
        Return false
    End If
    Return true
End Function


Sub s_dv_done( psw_place As Integer , pub_identified As UByte )
    ' the end of both: what the player has learnt about the thing, and, if they know all about it, how many
    ' charges it has left, Moria's itemChargesRemainingDescription()
    Dim luw_record As UInteger

    gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_USE_DONE , psw_place , pub_identified )
    luw_record = A_INVENTORY + Cast( UInteger , gsw_lib_result ) * UB_RECORD_SIZE
    If ( Peek( luw_record + UB_ITEM_IDENTIFICATION_OFFSET ) bAnd MB_ID_KNOWN2 ) <> 0 Then
        s_msg( "You have " + fs_core_number( Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) ) + " charges remaining." )
    End If
End Sub


Function fub_dv_timed( puw_counter As UInteger , puw_turns As UInteger ) As UByte
    ' something that lasts a while is added to, true if it was not already working, puw_counter is where its count is kept
    Dim lsw_now As Integer

    lsw_now = Peek( Integer , puw_counter )
    Poke UInteger puw_counter , Cast( UInteger , lsw_now ) + puw_turns
    If lsw_now = 0 Then Return true
    Return false
End Function


Function fub_dv_cure( puw_counter As UInteger ) As UByte
    ' Moria's playerCureBlindness() and its fellows: whatever it is has one more turn to run
    If Peek( Integer , puw_counter ) > 1 Then
        Poke UInteger puw_counter , 1
        Return true
    End If
    Return false
End Function


'##################################################################################################################################
' --- staffs ---

Function fub_dv_staff() As UByte
    ' Moria's staffUse(), with its staffDischarge()
    Dim lsw_place                   As Integer
    Dim luw_record , luw_i          As UInteger
    Dim lul_flags , lul_mask        As ULong
    Dim lub_effect                  As UByte
    Dim lub_identified              As UByte = false

    lsw_place = fsw_dv_choose( UB_TV_STAFF , "You are not carrying any staffs." , "Use which staff?" )
    If lsw_place < 0 Then Return false
    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    ' N.B: a staff is 5 easier to use than a wand of the same depth
    If fub_dv_works( luw_record , 5 , "staff" ) = false Then Return true

    Poke UInteger luw_record + UB_ITEM_MISC_USE_OFFSET , Cast( UInteger , Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) - 1 )
    lul_flags  = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
    lub_effect = 1
    lul_mask   = 1
    While lul_flags <> 0
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
            If lub_effect = 1 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_LIGHT_AREA , 0 , 0 )
            ElseIf lub_effect = 2 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_DOORS , 0 , 0 )
            ElseIf lub_effect = 3 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_TRAPS , 0 , 0 )
            ElseIf lub_effect = 4 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_TREASURE , 0 , 0 )
            ElseIf lub_effect = 5 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_OBJECTS , 0 , 0 )
            ElseIf lub_effect = 6 Then
                ' teleportation
                gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_TELEPORT , 0 , 100 )
                lub_identified = true
            ElseIf lub_effect = 7 Then
                lub_identified = true
                gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_EARTHQUAKE , 0 , 0 )
            ElseIf lub_effect = 8 Then
                ' summoning, N.B: as in Moria the dice are thrown afresh each time round
                lub_identified = false
                luw_i = 0
                While luw_i < fuw_dv_random( 4 )
                    If fub_dv_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_SUMMON , 0 , 0 ) Then lub_identified = true
                    luw_i = luw_i + 1
                End While
            ElseIf lub_effect = 10 Then
                lub_identified = true
                gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DESTROY_AREA , 0 , 0 )
            ElseIf lub_effect = 11 Then
                lub_identified = true
                gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_3 , UB_LIB_SPELLS_3_STARLITE , 0 , 0 )
            ElseIf lub_effect = 12 Then
                ' haste monsters
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SPEED_ALL , 0 , 1 )
            ElseIf lub_effect = 13 Then
                ' slow monsters
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SPEED_ALL , 0 , $FFFF )
            ElseIf lub_effect = 14 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SLEEP_ALL , 0 , 0 )
            ElseIf lub_effect = 15 Then
                ' cure light wounds
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_dv_random( 8 ) )
            ElseIf lub_effect = 16 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DETECT_INVISIBLE , 0 , 0 )
            ElseIf lub_effect = 17 Then
                ' speed
                lub_identified = false
                If fub_dv_timed( @gsw_player_fast , fuw_dv_random( 30 ) + 15 ) Then lub_identified = true
            ElseIf lub_effect = 18 Then
                ' slowness
                lub_identified = false
                If fub_dv_timed( @gsw_player_slow , fuw_dv_random( 30 ) + 15 ) Then lub_identified = true
            ElseIf lub_effect = 19 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_MASS_POLYMORPH , 0 , 0 )
            ElseIf lub_effect = 20 Then
                ' remove curse
                If fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_REMOVE_CURSE , 0 , 0 ) Then
                    If gsw_player_blind < 1 Then s_core_message( UW_MSG_THE_STAFF_GLOWS_BLUE_FOR_A_MOMENT )
                    lub_identified = true
                End If
            ElseIf lub_effect = 21 Then
                ' detect evil
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_DETECT , 0 , UW_CD_EVIL )
            ElseIf lub_effect = 22 Then
                ' curing, N.B: as in Moria the second and third are tried only if the one before cured nothing
                If fub_dv_cure( @gsw_player_blind ) Then
                    lub_identified = true
                ElseIf fub_dv_cure( @gsw_player_poisoned ) Then
                    lub_identified = true
                ElseIf fub_dv_cure( @gsw_player_confused ) Then
                    lub_identified = true
                End If
            ElseIf lub_effect = 23 Then
                ' dispel evil
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_2 , UB_LIB_SPELLS_2_DISPEL , 60 , UW_CD_EVIL )
            ElseIf lub_effect = 25 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS , UB_LIB_SPELLS_DARKEN_AREA , 0 , 0 )
            ElseIf lub_effect <> 32 Then
                ' 32 only marks a staff as bought in a store
                s_core_message( UW_MSG_INTERNAL_ERROR_IN_STAFFS )
            End If
        End If
        lub_effect = lub_effect + 1
        lul_mask   = lul_mask << 1
    End While

    s_dv_done( lsw_place , lub_identified )
    Return true
End Function


'##################################################################################################################################
' --- wands ---

Sub s_dv_bolt( pub_function As UByte , pub_direction As UByte , puw_damage As UInteger , pub_element As UByte , ps_name As String )
    ' a bolt or a ball, the aimed spells library fires it
    s_dv_text( ps_name )
    gub_lib_param_1 = pub_direction
    guw_lib_param_2 = puw_damage
    gsw_lib_result  = pub_element
    s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_3 , pub_function )
End Sub


Function fub_dv_wand() As UByte
    ' Moria's wandAim(), with its wandDischarge()
    Dim lsw_place                       As Integer
    Dim luw_record                      As UInteger
    Dim lul_flags , lul_mask            As ULong
    Dim lub_effect , lub_direction      As UByte
    Dim lub_identified                  As UByte = false

    lsw_place = fsw_dv_choose( UB_TV_WAND , "You are not carrying any wands." , "Aim which wand?" )
    If lsw_place < 0 Then Return false

    ' Moria's getDirectionWithMemory()
    lub_direction = 0
    s_core_message( UW_MSG_WHICH_DIRECTION )
    Do
        s_core_get_key()
        s_core_direction_key()
        If gub_key_char >= Code( "1" ) And gub_key_char <= Code( "9" ) And gub_key_char <> Code( "5" ) Then lub_direction = gub_key_char - Code( "0" )
        If guw_key_code = UW_KEY_UP Then lub_direction = 8
        If guw_key_code = UW_KEY_DOWN Then lub_direction = 2
        If guw_key_code = UW_KEY_LEFT Then lub_direction = 4
        If guw_key_code = UW_KEY_RIGHT Then lub_direction = 6
    Loop Until lub_direction <> 0 Or gub_key_char = 27 Or guw_key_code = 0
    s_msg_clear()
    ' backing out takes no time, Moria's getDirectionWithMemory() sets player_free_turn itself
    If lub_direction = 0 Then Return false
    gub_player_prev_dir = lub_direction
    If gsw_player_confused > 0 Then
        s_core_message( UW_MSG_YOU_ARE_CONFUSED )
        ' Moria's getRandomDirection()
        Do
            lub_direction = fuw_dv_random( 9 )
        Loop Until lub_direction <> 5
    End If

    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    If fub_dv_works( luw_record , 0 , "wand" ) = false Then Return true

    Poke UInteger luw_record + UB_ITEM_MISC_USE_OFFSET , Cast( UInteger , Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) - 1 )
    lul_flags  = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
    lub_effect = 1
    lul_mask   = 1
    While lul_flags <> 0
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
            If lub_effect = 1 Then
                s_core_message( UW_MSG_A_LINE_OF_BLUE_SHIMMERING_LIGHT )
                gub_shared_1 = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_3 , UB_LIB_SPELLS_3_LIGHT_LINE , lub_direction , 0 )
                lub_identified = true
            ElseIf lub_effect = 2 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BOLT , lub_direction , fuw_core_dice_roll( 4 , 8 ) , UB_ELEMENT_LIGHTNING , "Lightning Bolt" )
                lub_identified = true
            ElseIf lub_effect = 3 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BOLT , lub_direction , fuw_core_dice_roll( 6 , 8 ) , UB_ELEMENT_FROST , "Frost Bolt" )
                lub_identified = true
            ElseIf lub_effect = 4 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BOLT , lub_direction , fuw_core_dice_roll( 9 , 8 ) , UB_ELEMENT_FIRE , "Fire Bolt" )
                lub_identified = true
            ElseIf lub_effect = 5 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_WALL_TO_MUD , lub_direction , 0 )
            ElseIf lub_effect = 6 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_POLYMORPH , lub_direction , 0 )
            ElseIf lub_effect = 7 Then
                ' heal monster, a hurt of less than nothing
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_CHANGE_HP , lub_direction , Cast( UInteger , -Cast( Integer , fuw_core_dice_roll( 4 , 6 ) ) ) )
            ElseIf lub_effect = 8 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SPEED , lub_direction , 1 )
            ElseIf lub_effect = 9 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SPEED , lub_direction , $FFFF )
            ElseIf lub_effect = 10 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_CONFUSE , lub_direction , 0 )
            ElseIf lub_effect = 11 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_SLEEP , lub_direction , 0 )
            ElseIf lub_effect = 12 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_DRAIN_LIFE , lub_direction , 0 )
            ElseIf lub_effect = 13 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_DESTROY_DOORS , lub_direction , 0 )
            ElseIf lub_effect = 14 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BOLT , lub_direction , fuw_core_dice_roll( 2 , 6 ) , 0 , "Magic Missile" )
                lub_identified = true
            ElseIf lub_effect = 15 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_BUILD_WALL , lub_direction , 0 )
            ElseIf lub_effect = 16 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_CLONE , lub_direction , 0 )
            ElseIf lub_effect = 17 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_4 , UB_LIB_SPELLS_4_TELEPORT_AWAY , lub_direction , 0 )
            ElseIf lub_effect = 18 Then
                lub_identified = fub_dv_call( UB_PAGED_CODE_LIB_SPELLS_5 , UB_LIB_SPELLS_5_DISARM_ALL , lub_direction , 0 )
            ElseIf lub_effect = 19 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BALL , lub_direction , 32 , UB_ELEMENT_LIGHTNING , "Lightning Ball" )
                lub_identified = true
            ElseIf lub_effect = 20 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BALL , lub_direction , 48 , UB_ELEMENT_FROST , "Cold Ball" )
                lub_identified = true
            ElseIf lub_effect = 21 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BALL , lub_direction , 72 , UB_ELEMENT_FIRE , "Fire Ball" )
                lub_identified = true
            ElseIf lub_effect = 22 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BALL , lub_direction , 12 , UB_ELEMENT_GAS , "Stinking Cloud" )
                lub_identified = true
            ElseIf lub_effect = 23 Then
                s_dv_bolt( UB_LIB_SPELLS_3_BALL , lub_direction , 60 , UB_ELEMENT_ACID , "Acid Ball" )
                lub_identified = true
            ElseIf lub_effect = 24 Then
                ' wonder: any one of the others, picked at random, the hunt for it starts again from the first
                lul_flags  = Cast( ULong , 1 ) << ( fuw_dv_random( 23 ) - 1 )
                lub_effect = 0
                lul_mask   = 0
            Else
                s_core_message( UW_MSG_INTERNAL_ERROR_IN_WANDS )
            End If
        End If
        lub_effect = lub_effect + 1
        If lul_mask = 0 Then
            lul_mask = 1
        Else
            lul_mask = lul_mask << 1
        End If
    End While

    s_dv_done( lsw_place , lub_identified )
    Return true
End Function


Sub s_lib_devices()
    Dim lub_used As UByte = false

    If gub_lib_function = UB_LIB_DEVICES_USE_STAFF Then
        lub_used = fub_dv_staff()
    ElseIf gub_lib_function = UB_LIB_DEVICES_AIM_WAND Then
        lub_used = fub_dv_wand()
    End If
    gsw_lib_result = lub_used
End Sub
