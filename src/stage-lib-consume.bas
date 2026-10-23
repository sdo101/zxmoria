#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_consume()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-player-hit-include.bas"

' this page is a LIBRARY, not a stage: eating and drinking, Moria's player_eat.cpp and player_quaff.cpp...
' ...the walking stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_CONSUME , <which routine> ),
' the routines are:
'
'   UB_LIB_CONSUME_EAT      the player picks some food from the pack and eats it, Moria's playerEat()
'   UB_LIB_CONSUME_QUAFF    the player picks a potion from the pack and drinks it, Moria's quaff()
'
' gsw_lib_result is true if it took the player's turn, false if they had nothing to eat or drink, or changed their mind
'
' what a thing does when eaten or drunk is in its flags, one bit for each effect, and all of them happen, lowest bit
' first, food and the first kind of potion count their effects from 1, the second kind of potion from 33
' if the player notices what it did, they know that kind of thing from then on, see UB_LIB_EFFECTS_USE_DONE
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_cn_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_cn_effect( pub_function As UByte , pub_stat As UByte , puw_amount As UInteger ) As UByte
    ' one of the effects library's routines, with its answer
    gub_lib_param_1 = pub_stat
    guw_lib_param_2 = puw_amount
    s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , pub_function )
    If gsw_lib_result Then Return true
    Return false
End Function


Function fub_cn_restore( pub_stat As UByte , ps_message As String ) As UByte
    ' a stat goes back to its best, and if it had been lowered the player is told
    If fub_cn_effect( UB_LIB_EFFECTS_STAT_RESTORE , pub_stat , 0 ) = false Then Return false
    s_msg( ps_message )
    Return true
End Function


Function fub_cn_increase( pub_stat As UByte , ps_message As String ) As UByte
    ' a stat goes up, and if it could the player is told
    If fub_cn_effect( UB_LIB_EFFECTS_STAT_INCREASE , pub_stat , 0 ) = false Then Return false
    s_msg( ps_message )
    Return true
End Function


Function fub_cn_cure( puw_counter As UInteger ) As UByte
    ' Moria's playerCureBlindness(), playerCureConfusion(), playerCurePoison() and playerRemoveFear(): whatever it
    ' is has one more turn to run, puw_counter is where its count is kept
    If Peek( Integer , puw_counter ) > 1 Then
        Poke UInteger puw_counter , 1
        Return true
    End If
    Return false
End Function


Function fub_cn_timed( puw_counter As UInteger , puw_turns As UInteger ) As UByte
    ' something that lasts a while is added to, true if it was not already working, puw_counter is where its count is kept
    Dim lsw_now As Integer

    lsw_now = Peek( Integer , puw_counter )
    Poke UInteger puw_counter , Cast( UInteger , lsw_now ) + puw_turns
    If lsw_now = 0 Then Return true
    Return false
End Function


Function fsw_cn_choose( pub_category_1 As UByte , pub_category_2 As UByte , ps_nothing As String , ps_prompt As String ) As Integer
    ' the start of Moria's playerEat() and quaff(): the player picks one of the things of the right kind from the
    ' pack, they are all together there, Moria's inventoryFindRange(), -1 if there are none or the player backs out
    Dim lsw_first , lsw_last , lsw_i    As Integer
    Dim lub_category , i , lub_length   As UByte

    If gsw_player_pack_unique = 0 Then
        s_core_message( UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING )
        Return -1
    End If
    lsw_first = -1
    lsw_last  = -1
    For lsw_i = 0 To gsw_player_pack_unique - 1
        lub_category = Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET )
        Poke A_INV_MASK + lsw_i , 0
        If lub_category = pub_category_1 Or lub_category = pub_category_2 Then
            If lsw_first < 0 Then lsw_first = lsw_i
            lsw_last = lsw_i
            Poke A_INV_MASK + lsw_i , 1
        End If
    Next
    If lsw_first < 0 Then
        s_msg( ps_nothing )
        Return -1
    End If

    ' the question the inventory library is to ask
    lub_length = Len( ps_prompt )
    For i = 0 To lub_length - 1
        Poke A_PROMPT + i , Code( ps_prompt( i ) )
    Next
    Poke A_PROMPT + lub_length , 0
    gub_lib_param_1 = false
    guw_lib_param_2 = Cast( UInteger , lsw_first ) bOr ( Cast( UInteger , lsw_last ) << 8 )
    s_core_call_library( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_CHOOSE )
    Return gsw_lib_result
End Function


'##################################################################################################################################
' --- eating ---

Function fub_cn_eat() As UByte
    ' Moria's playerEat()
    Dim lsw_place                   As Integer
    Dim luw_record                  As UInteger
    Dim lul_flags , lul_mask        As ULong
    Dim lub_effect , lub_depth      As UByte
    Dim lub_identified              As UByte = false

    lsw_place = fsw_cn_choose( UB_TV_FOOD , UB_TV_FOOD , "You are not carrying any food." , "Eat what?" )
    If lsw_place < 0 Then Return false

    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    lul_flags  = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
    lub_depth  = Peek( luw_record + UB_ITEM_DEPTH_OFFSET )
    lub_effect = 1
    lul_mask   = 1
    While lul_flags <> 0
        If ( lul_flags bAnd lul_mask ) <> 0 Then
            lul_flags = lul_flags bAnd ( $FFFFFFFF - lul_mask )
            If lub_effect = UB_FOOD_POISON Then
                ' poison
                gsw_player_poisoned = gsw_player_poisoned + fuw_cn_random( 10 ) + lub_depth
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_BLINDNESS Then
                ' blindness
                gsw_player_blind = gsw_player_blind + fuw_cn_random( 250 ) + 10 * Cast( UInteger , lub_depth ) + 100
                s_core_message( UW_MSG_A_VEIL_OF_DARKNESS_SURROUNDS_YOU )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_PARANOIA Then
                ' paranoia
                gsw_player_afraid = gsw_player_afraid + fuw_cn_random( 10 ) + lub_depth
                s_core_message( UW_MSG_YOU_FEEL_TERRIFIED )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_CONFUSION Then
                ' confusion
                gsw_player_confused = gsw_player_confused + fuw_cn_random( 10 ) + lub_depth
                s_core_message( UW_MSG_YOU_FEEL_DRUGGED )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_HALLUCINATION Then
                ' hallucination
                gsw_player_image = gsw_player_image + fuw_cn_random( 200 ) + 25 * Cast( UInteger , lub_depth ) + 200
                s_core_message( UW_MSG_YOU_FEEL_DRUGGED )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_CURE_POISON Then
                lub_identified = fub_cn_cure( @gsw_player_poisoned )
            ElseIf lub_effect = UB_FOOD_CURE_BLINDNESS Then
                lub_identified = fub_cn_cure( @gsw_player_blind )
            ElseIf lub_effect = UB_FOOD_CURE_PARANOIA Then
                If fub_cn_cure( @gsw_player_afraid ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_CURE_CONFUSION Then
                lub_identified = fub_cn_cure( @gsw_player_confused )
            ElseIf lub_effect = UB_FOOD_WEAKNESS Then
                ' weakness
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_STR , 0 )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_UNHEALTH Then
                ' unhealth
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_CON , 0 )
                lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_STR Then
                If fub_cn_restore( UB_STAT_STR , "You feel your strength returning." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_CON Then
                If fub_cn_restore( UB_STAT_CON , "You feel your health returning." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_INT Then
                If fub_cn_restore( UB_STAT_INT , "Your head spins a moment." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_WIS Then
                If fub_cn_restore( UB_STAT_WIS , "You feel your wisdom returning." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_DEX Then
                If fub_cn_restore( UB_STAT_DEX , "You feel more dexterous." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_RESTORE_CHR Then
                If fub_cn_restore( UB_STAT_CHR , "Your skin stops itching." ) Then lub_identified = true
            ElseIf lub_effect = UB_FOOD_FIRST_AID Then
                ' first aid
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_cn_random( 6 ) )
            ElseIf lub_effect = UB_FOOD_MINOR_CURES Then
                ' minor cures
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_cn_random( 12 ) )
            ElseIf lub_effect = UB_FOOD_LIGHT_CURES Then
                ' light cures
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_cn_random( 18 ) )
            ElseIf lub_effect = UB_FOOD_MAJOR_CURES Then
                ' major cures
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_core_dice_roll( 3 , 12 ) )
            ElseIf lub_effect = UB_FOOD_POISONOUS_FOOD Then
                ' poisonous food
                s_hit_killer( "poisonous food." )
                s_hit_player( fuw_cn_random( 18 ) )
                lub_identified = true
            Else
                s_core_message( UW_MSG_INTERNAL_ERROR_IN_PLAYEREAT )
            End If
        End If
        lub_effect = lub_effect + 1
        lul_mask   = lul_mask << 1
    End While

    ' what the player has learnt about it
    lsw_place  = fub_cn_effect( UB_LIB_EFFECTS_USE_DONE , lsw_place , lub_identified )
    lsw_place  = gsw_lib_result
    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE

    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_INGEST_FOOD , 0 , Peek( UInteger , luw_record + UB_ITEM_MISC_USE_OFFSET ) )
    ' Moria's printCharacterHungerStatus(), the player is neither hungry nor weak
    gul_player_status = gul_player_status bAnd ( $FFFFFFFF - ( UL_PY_WEAK bOr UL_PY_HUNGRY ) )
    s_core_print_string_at( 23 , 0 , "      " , UB_WHITE )
    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_USE_REMAINING , lsw_place , 0 )
    Return true
End Function


'##################################################################################################################################
' --- drinking ---

Function fub_cn_potion( pul_flags As ULong , pub_effect As UByte ) As UByte
    ' Moria's playerDrinkPotion(): every effect the potion has, pub_effect is the number of the first, 1 or 33
    Dim lul_mask        As ULong
    Dim lsl_exp         As Long
    Dim lsl_scale       As Long
    Dim lub_identified  As UByte = false

    lul_mask = 1
    While pul_flags <> 0
        If ( pul_flags bAnd lul_mask ) <> 0 Then
            pul_flags = pul_flags bAnd ( $FFFFFFFF - lul_mask )
            If pub_effect = UB_POTION_STRENGTH Then
                If fub_cn_increase( UB_STAT_STR , "Wow!  What bulging muscles!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_WEAKNESS Then
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_STR , 0 )
                lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_STRENGTH Then
                If fub_cn_restore( UB_STAT_STR , "You feel warm all over." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_INTELLIGENCE Then
                If fub_cn_increase( UB_STAT_INT , "Aren't you brilliant!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_LOSE_INTELLIGENCE Then
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_INT , 0 )
                lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_INTELLIGENCE Then
                If fub_cn_restore( UB_STAT_INT , "You have have a warm feeling." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_WISDOM Then
                If fub_cn_increase( UB_STAT_WIS , "You suddenly have a profound thought!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_LOSE_WISDOM Then
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_WIS , 0 )
                lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_WISDOM Then
                If fub_cn_restore( UB_STAT_WIS , "You feel your wisdom returning." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_CHARISMA Then
                If fub_cn_increase( UB_STAT_CHR , "Gee, ain't you cute!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_UGLINESS Then
                gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_LOSE_STAT , UB_STAT_CHR , 0 )
                lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_CHARISMA Then
                If fub_cn_restore( UB_STAT_CHR , "You feel your looks returning." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_CURE_LIGHT_WOUNDS Then
                ' cure light wounds
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_core_dice_roll( 2 , 7 ) )
            ElseIf pub_effect = UB_POTION_CURE_SERIOUS_WOUNDS Then
                ' cure serious wounds
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_core_dice_roll( 4 , 7 ) )
            ElseIf pub_effect = UB_POTION_CURE_CRITICAL_WOUNDS Then
                ' cure critical wounds
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , fuw_core_dice_roll( 6 , 7 ) )
            ElseIf pub_effect = UB_POTION_HEALING Then
                ' healing
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_HP_CHANGE , 0 , 1000 )
            ElseIf pub_effect = UB_POTION_CONSTITUTION Then
                If fub_cn_increase( UB_STAT_CON , "You feel tingly for a moment." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_GAIN_EXPERIENCE Then
                ' gain experience
                If gsl_player_exp < UL_PLAYER_MAX_EXP Then
                    lsl_exp = ( gsl_player_exp / 2 ) + 10
                    If lsl_exp > 100000 Then lsl_exp = 100000
                    gsl_player_exp = gsl_player_exp + lsl_exp
                    s_core_message( UW_MSG_YOU_FEEL_MORE_EXPERIENCED )
                    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_DISPLAY_EXP , 0 , 0 )
                    lub_identified = true
                End If
            ElseIf pub_effect = UB_POTION_SLEEP Then
                ' sleep
                If gub_player_free_action = false Then
                    s_core_message( UW_MSG_YOU_FALL_ASLEEP )
                    gsw_player_paralysis = gsw_player_paralysis + fuw_cn_random( 4 ) + 4
                    lub_identified = true
                End If
            ElseIf pub_effect = UB_POTION_BLINDNESS Then
                ' blindness
                If gsw_player_blind = 0 Then
                    s_core_message( UW_MSG_YOU_ARE_COVERED_BY_A_VEIL_OF )
                    lub_identified = true
                End If
                gsw_player_blind = gsw_player_blind + fuw_cn_random( 100 ) + 100
            ElseIf pub_effect = UB_POTION_CONFUSION Then
                ' confusion
                If gsw_player_confused = 0 Then
                    s_core_message( UW_MSG_HEY_THIS_IS_GOOD_STUFF_HICK )
                    lub_identified = true
                End If
                gsw_player_confused = gsw_player_confused + fuw_cn_random( 20 ) + 12
            ElseIf pub_effect = UB_POTION_POISON Then
                ' poison
                If gsw_player_poisoned = 0 Then
                    s_core_message( UW_MSG_YOU_FEEL_VERY_SICK )
                    lub_identified = true
                End If
                gsw_player_poisoned = gsw_player_poisoned + fuw_cn_random( 15 ) + 10
            ElseIf pub_effect = UB_POTION_HASTE_SELF Then
                ' haste self
                If fub_cn_timed( @gsw_player_fast , fuw_cn_random( 25 ) + 15 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_SLOWNESS Then
                ' slowness
                If fub_cn_timed( @gsw_player_slow , fuw_cn_random( 25 ) + 15 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_DEXTERITY Then
                If fub_cn_increase( UB_STAT_DEX , "You feel more limber!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_DEXTERITY Then
                If fub_cn_restore( UB_STAT_DEX , "You feel less clumsy." ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_RESTORE_CONSTITUTION Then
                If fub_cn_restore( UB_STAT_CON , "You feel your health returning!" ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_CURE_BLINDNESS Then
                lub_identified = fub_cn_cure( @gsw_player_blind )
            ElseIf pub_effect = UB_POTION_CURE_CONFUSION Then
                lub_identified = fub_cn_cure( @gsw_player_confused )
            ElseIf pub_effect = UB_POTION_CURE_POISON Then
                lub_identified = fub_cn_cure( @gsw_player_poisoned )
            ElseIf pub_effect = UB_POTION_LOSE_EXPERIENCE Then
                ' lose experience
                If gsl_player_exp > 0 Then
                    s_core_message( UW_MSG_YOU_FEEL_YOUR_MEMORIES_FADE )
                    lsl_exp = gsl_player_exp / 5
                    If gsl_player_exp > 32767 Then
                        lsl_scale = 2147483647 / gsl_player_exp
                        lsl_exp   = lsl_exp + ( Cast( Long , ful_core_random_number( lsl_scale ) ) * gsl_player_exp ) / ( lsl_scale * 5 )
                    Else
                        lsl_exp = lsl_exp + ful_core_random_number( gsl_player_exp ) / 5
                    End If
                    gsl_lib_long_1 = lsl_exp
                    gub_shared_1   = fub_cn_effect( UB_LIB_EFFECTS_LOSE_EXP , 0 , 0 )
                    lub_identified = true
                End If
            ElseIf pub_effect = UB_POTION_SALT_WATER Then
                ' salt water
                gub_shared_1 = fub_cn_cure( @gsw_player_poisoned )
                If gsw_player_food > 150 Then gsw_player_food = 150
                gsw_player_paralysis = 4
                s_core_message( UW_MSG_THE_POTION_MAKES_YOU_VOMIT )
                lub_identified = true
            ElseIf pub_effect = UB_POTION_INVULNERABILITY Then
                ' invulnerability
                If fub_cn_timed( @gsw_player_invulnerability , fuw_cn_random( 10 ) + 10 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_HEROISM Then
                ' heroism
                If fub_cn_timed( @gsw_player_heroism , fuw_cn_random( 25 ) + 25 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_SUPER_HEROISM Then
                ' super heroism
                If fub_cn_timed( @gsw_player_super_heroism , fuw_cn_random( 25 ) + 25 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_BOLDNESS Then
                ' boldness
                lub_identified = fub_cn_cure( @gsw_player_afraid )
            ElseIf pub_effect = UB_POTION_RESTORE_LIFE_LEVELS Then
                ' restore life levels
                lub_identified = fub_cn_effect( UB_LIB_EFFECTS_RESTORE_LEVELS , 0 , 0 )
            ElseIf pub_effect = UB_POTION_RESIST_HEAT Then
                ' resist heat
                If fub_cn_timed( @gsw_player_heat_resistance , fuw_cn_random( 10 ) + 10 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_RESIST_COLD Then
                ' resist cold
                If fub_cn_timed( @gsw_player_cold_resistance , fuw_cn_random( 10 ) + 10 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_DETECT_INVISIBLE Then
                ' detect invisible
                If fub_cn_timed( @gsw_player_detect_invisible , fuw_cn_random( 12 ) + 12 ) Then lub_identified = true
            ElseIf pub_effect = UB_POTION_SLOW_POISON Then
                ' slow poison, Moria's spellSlowPoison()
                If gsw_player_poisoned > 0 Then
                    gsw_player_poisoned = gsw_player_poisoned / 2
                    If gsw_player_poisoned < 1 Then gsw_player_poisoned = 1
                    s_core_message( UW_MSG_THE_EFFECT_OF_THE_POISON_HAS_BEEN )
                    lub_identified = true
                End If
            ElseIf pub_effect = UB_POTION_NEUTRALIZE_POISON Then
                ' neutralize poison
                lub_identified = fub_cn_cure( @gsw_player_poisoned )
            ElseIf pub_effect = UB_POTION_RESTORE_MANA Then
                ' restore mana
                If gsw_player_current_mana < gsw_player_mana Then
                    gsw_player_current_mana = gsw_player_mana
                    s_core_message( UW_MSG_YOUR_FEEL_YOUR_HEAD_CLEAR )
                    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
                    lub_identified = true
                End If
            ElseIf pub_effect = UB_POTION_INFRA_VISION Then
                ' infravision
                If gsw_player_timed_infra = 0 Then
                    s_core_message( UW_MSG_YOUR_EYES_BEGIN_TO_TINGLE )
                    lub_identified = true
                End If
                gsw_player_timed_infra = gsw_player_timed_infra + 100 + fuw_cn_random( 100 )
            Else
                s_core_message( UW_MSG_INTERNAL_ERROR_IN_POTION )
            End If
        End If
        pub_effect = pub_effect + 1
        lul_mask   = lul_mask << 1
    End While
    Return lub_identified
End Function


Function fub_cn_quaff() As UByte
    ' Moria's quaff()
    Dim lsw_place       As Integer
    Dim luw_record      As UInteger
    Dim lul_flags       As ULong
    Dim lub_identified  As UByte

    lsw_place = fsw_cn_choose( UB_TV_POTION1 , UB_TV_POTION2 , "You are not carrying any potions." , "Quaff which potion?" )
    If lsw_place < 0 Then Return false

    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    lul_flags  = Peek( ULong , luw_record + UB_ITEM_FLAGS_OFFSET )
    If lul_flags = 0 Then
        s_core_message( UW_MSG_YOU_FEEL_LESS_THIRSTY )
        lub_identified = true
    ElseIf Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_POTION2 Then
        lub_identified = fub_cn_potion( lul_flags , 33 )
    Else
        lub_identified = fub_cn_potion( lul_flags , 1 )
    End If

    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_USE_DONE , lsw_place , lub_identified )
    lsw_place  = gsw_lib_result
    luw_record = A_INVENTORY + Cast( UInteger , lsw_place ) * UB_RECORD_SIZE
    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_INGEST_FOOD , 0 , Peek( UInteger , luw_record + UB_ITEM_MISC_USE_OFFSET ) )
    gub_shared_1 = fub_cn_effect( UB_LIB_EFFECTS_USE_REMAINING , lsw_place , 0 )
    Return true
End Function


Sub s_lib_consume()
    Dim lub_used As UByte = false

    If gub_lib_function = UB_LIB_CONSUME_EAT Then
        lub_used = fub_cn_eat()
    ElseIf gub_lib_function = UB_LIB_CONSUME_QUAFF Then
        lub_used = fub_cn_quaff()
    End If
    gsw_lib_result = lub_used
End Sub
