#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_recall_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: the second half of the paragraph that says what the player knows about a kind
' of creature, Moria's memoryRecall(), stage-lib-recall.bas writes the first half and then calls this page...
' ...through the core: s_core_call_library( UB_PAGED_CODE_LIB_RECALL_2 , UB_LIB_RECALL_2_REST ), the creature is in
' A_CREATURE, and what is remembered of it and the line being filled are in the core's text buffer, see
' stage-recall-include.bas, gsw_lib_result is the key the player pressed to go on

Function fuw_rc_table( pub_which As UByte ) As UInteger
    ' Moria's data_recall.cpp: the lists of phrases this page uses, each phrase ends in a 0
    If pub_which = 0 Then Return @rc_attack_type
    If pub_which = 1 Then Return @rc_attack_method
    If pub_which = 3 Then Return @rc_move
    Return @rc_weakness
rc_attack_type:
    Asm
        defm "do something undefined"
        defb 0
        defm "attack"
        defb 0
        defm "weaken"
        defb 0
        defm "confuse"
        defb 0
        defm "terrify"
        defb 0
        defm "shoot flames"
        defb 0
        defm "shoot acid"
        defb 0
        defm "freeze"
        defb 0
        defm "shoot lightning"
        defb 0
        defm "corrode"
        defb 0
        defm "blind"
        defb 0
        defm "paralyse"
        defb 0
        defm "steal money"
        defb 0
        defm "steal things"
        defb 0
        defm "poison"
        defb 0
        defm "reduce dexterity"
        defb 0
        defm "reduce constitution"
        defb 0
        defm "drain intelligence"
        defb 0
        defm "drain wisdom"
        defb 0
        defm "lower experience"
        defb 0
        defm "call for help"
        defb 0
        defm "disenchant"
        defb 0
        defm "eat your food"
        defb 0
        defm "absorb light"
        defb 0
        defm "absorb charges"
        defb 0
    End Asm
rc_attack_method:
    Asm
        defm "make an undefined advance"
        defb 0
        defm "hit"
        defb 0
        defm "bite"
        defb 0
        defm "claw"
        defb 0
        defm "sting"
        defb 0
        defm "touch"
        defb 0
        defm "kick"
        defb 0
        defm "gaze"
        defb 0
        defm "breathe"
        defb 0
        defm "spit"
        defb 0
        defm "wail"
        defb 0
        defm "embrace"
        defb 0
        defm "crawl on you"
        defb 0
        defm "release spores"
        defb 0
        defm "beg"
        defb 0
        defm "slime you"
        defb 0
        defm "crush"
        defb 0
        defm "trample"
        defb 0
        defm "drool"
        defb 0
        defm "insult"
        defb 0
    End Asm
rc_move:
    Asm
        defm "move invisibly"
        defb 0
        defm "open doors"
        defb 0
        defm "pass through walls"
        defb 0
        defm "kill weaker creatures"
        defb 0
        defm "pick up objects"
        defb 0
        defm "breed explosively"
        defb 0
    End Asm
rc_weakness:
    Asm
        defm "frost"
        defb 0
        defm "fire"
        defb 0
        defm "poison"
        defb 0
        defm "acid"
        defb 0
        defm "bright light"
        defb 0
        defm "rock remover"
        defb 0
    End Asm
    Return 0
End Function


#include "stage-recall-include.bas"


Function fub_rc_rest() As UByte
    ' the second half of Moria's memoryRecall(), the answer is the key the player pressed
    Dim lul_move , lul_value                As ULong
    Dim luw_defense , luw_entry             As UInteger
    Dim lub_known , i , lub_attack          As UByte
    Dim lub_type , lub_method               As UByte
    Dim lub_dice , lub_sides                As UByte
    Dim lub_count , lub_known_attacks       As UByte
    Dim lub_carry                           As UByte
    Dim ls_text                             As String

    ' the win property is always known, set it if a win monster
    lul_move    = gul_rc_movement bOr ( gul_creature_movement bAnd UL_CM_WIN )
    luw_defense = guw_rc_defenses bAnd guw_creature_defenses
    ' do we know how hard they are to kill? armor class, hit die, Moria's memoryKillDifficulty(): the higher
    ' the level of the monster, the fewer the kills you need
    If guw_rc_kills > 304 / ( 4 + Cast( UInteger , gub_creature_level ) ) Then
        s_rc_print( " It has an armor rating of " )
        s_rc_number( gub_creature_ac )
        s_rc_print( " and a" )
        If ( guw_creature_defenses bAnd UW_CD_MAX_HP ) <> 0 Then s_rc_print( " maximized" )
        s_rc_print( " life rating of " )
        s_rc_number( gub_creature_hit_dice )
        s_rc_print( "d" )
        s_rc_number( gub_creature_hit_sides )
        s_rc_print( "." )
    End If

    ' do we know how clever they are? special abilities, then its special weaknesses, most defenses flags
    If fub_rc_list( ( lul_move >> 16 ) bAnd $3F , 6 , 3 , " It can " , " and " ) Then s_rc_print( "." )
    If fub_rc_list( ( luw_defense >> 4 ) bAnd $3F , 6 , 6 , " It is susceptible to " , " and " ) Then s_rc_print( "." )

    If ( luw_defense bAnd UW_CD_INFRA ) <> 0 Then s_rc_print( " It is warm blooded" )
    If ( luw_defense bAnd UW_CD_NO_SLEEP ) <> 0 Then
        If ( luw_defense bAnd UW_CD_INFRA ) <> 0 Then
            s_rc_print( ", and" )
        Else
            s_rc_print( " It" )
        End If
        s_rc_print( " cannot be charmed or slept" )
    End If
    If ( luw_defense bAnd ( UW_CD_NO_SLEEP bOr UW_CD_INFRA ) ) <> 0 Then s_rc_print( "." )

    ' do we know how aware it is? Moria's memoryAwareness()
    lub_known = false
    If Cast( UInteger , gub_rc_wake ) * gub_rc_wake > gub_creature_sleep Then lub_known = true
    If gub_rc_ignore = 255 Then lub_known = true
    If gub_creature_sleep = 0 And guw_rc_kills >= 10 Then lub_known = true
    If lub_known Then
        s_rc_print( " It " )
        If gub_creature_sleep > 200 Then
            s_rc_print( "prefers to ignore" )
        ElseIf gub_creature_sleep > 95 Then
            s_rc_print( "pays very little attention to" )
        ElseIf gub_creature_sleep > 75 Then
            s_rc_print( "pays little attention to" )
        ElseIf gub_creature_sleep > 45 Then
            s_rc_print( "tends to overlook" )
        ElseIf gub_creature_sleep > 25 Then
            s_rc_print( "takes quite a while to see" )
        ElseIf gub_creature_sleep > 10 Then
            s_rc_print( "takes a while to see" )
        ElseIf gub_creature_sleep > 5 Then
            s_rc_print( "is fairly observant of" )
        ElseIf gub_creature_sleep > 3 Then
            s_rc_print( "is observant of" )
        ElseIf gub_creature_sleep > 1 Then
            s_rc_print( "is very observant of" )
        ElseIf gub_creature_sleep <> 0 Then
            s_rc_print( "is vigilant for" )
        Else
            s_rc_print( "is ever vigilant for" )
        End If
        s_rc_print( " intruders, which it may notice from " )
        s_rc_number( 10 * Cast( UInteger , gub_creature_area_radius ) )
        s_rc_print( " feet." )
    End If

    ' do we know what it might carry? Moria's memoryLootCarried()
    If ( lul_move bAnd ( UL_CM_CARRY_OBJ bOr UL_CM_CARRY_GOLD ) ) <> 0 Then
        s_rc_print( " It may" )
        lub_carry = ( lul_move bAnd UL_CM_TREASURE ) >> UB_CM_TR_SHIFT
        lul_value = gul_creature_movement bAnd UL_CM_TREASURE
        If lub_carry = 1 Then
            If lul_value = UL_CM_60_RANDOM Then
                s_rc_print( " sometimes" )
            Else
                s_rc_print( " often" )
            End If
        ElseIf lub_carry = 2 And lul_value = ( UL_CM_60_RANDOM bOr UL_CM_90_RANDOM ) Then
            s_rc_print( " often" )
        End If
        s_rc_print( " carry" )
        ls_text = " objects"
        If ( lul_move bAnd UL_CM_SMALL_OBJ ) <> 0 Then ls_text = " small objects"
        If lub_carry = 1 Then
            ls_text = " an object"
            If ( lul_move bAnd UL_CM_SMALL_OBJ ) <> 0 Then ls_text = " a small object"
        ElseIf lub_carry = 2 Then
            s_rc_print( " one or two" )
        Else
            s_rc_print( " up to " )
            s_rc_number( lub_carry )
        End If
        If ( lul_move bAnd UL_CM_CARRY_OBJ ) <> 0 Then
            s_rc_print( ls_text )
            If ( lul_move bAnd UL_CM_CARRY_GOLD ) <> 0 Then
                s_rc_print( " or treasure" )
                If lub_carry > 1 Then s_rc_print( "s" )
            End If
            s_rc_print( "." )
        ElseIf lub_carry <> 1 Then
            s_rc_print( " treasures." )
        Else
            s_rc_print( " treasure." )
        End If
    End If

    ' we know about attacks it has used on us, and maybe the damage they do, Moria's memoryAttackNumberAndDamage(),
    ' lub_known_attacks is the total number of known attacks, used for punctuation
    lub_known_attacks = 0
    For i = 0 To 3
        If Peek( A_RC_ATTACKS + i ) <> 0 Then lub_known_attacks = lub_known_attacks + 1
    Next
    ' lub_count counts the attacks as printed, used for punctuation
    lub_count = 0
    i = 0
    While i < 4
        lub_attack = Peek( A_CREATURE + UB_CREATURE_ATTACKS_OFFSET + i )
        If lub_attack = 0 Then
            i = 4
        ElseIf Peek( A_RC_ATTACKS + i ) <> 0 Then
            ' don't print out unknown attacks
            luw_entry  = A_ATTACKS + Cast( UInteger , lub_attack ) * 4
            lub_type   = Peek( luw_entry )
            lub_method = Peek( luw_entry + 1 )
            lub_dice   = Peek( luw_entry + 2 )
            lub_sides  = Peek( luw_entry + 3 )
            lub_count  = lub_count + 1
            If lub_count = 1 Then
                s_rc_print( " It can " )
            ElseIf lub_count = lub_known_attacks Then
                s_rc_print( ", and " )
            Else
                s_rc_print( ", " )
            End If
            If lub_method > 19 Then lub_method = 0
            s_rc_phrase( 1 , lub_method )
            If lub_type <> 1 Or ( lub_dice > 0 And lub_sides > 0 ) Then
                s_rc_print( " to " )
                If lub_type > 24 Then lub_type = 0
                s_rc_phrase( 0 , lub_type )
                If lub_dice <> 0 And lub_sides <> 0 Then
                    ' the number of attacks seen that it takes to know the damage: the higher the level of the
                    ' monster the fewer, the more damage the attack does the more, Moria's knowdamage()
                    If ( 4 + Cast( UInteger , gub_creature_level ) ) * Peek( A_RC_ATTACKS + i ) > 80 * Cast( UInteger , lub_dice ) * lub_sides Then
                        If lub_type = 19 Then
                            ' loss of experience
                            s_rc_print( " by " )
                        Else
                            s_rc_print( " with damage " )
                        End If
                        s_rc_number( lub_dice )
                        s_rc_print( "d" )
                        s_rc_number( lub_sides )
                    End If
                End If
            End If
        End If
        i = i + 1
    End While
    If lub_count <> 0 Then
        s_rc_print( "." )
    ElseIf lub_known_attacks > 0 And Peek( A_RC_ATTACKS ) >= 10 Then
        s_rc_print( " It has no physical attacks." )
    Else
        s_rc_print( " Nothing is known about its attack." )
    End If

    ' always know the win creature
    If ( gul_creature_movement bAnd UL_CM_WIN ) <> 0 Then s_rc_print( " Killing one of these wins the game!" )

    s_rc_char( 10 )
    s_core_print_string_at( gub_rc_row , 0 , "--pause--                                                                       " , UB_BRIGHT_WHITE )
    s_core_get_key()
    Return gub_key_char
End Function


Sub s_lib_recall_2()
    If gub_lib_function = UB_LIB_RECALL_2_REST Then gsw_lib_result = fub_rc_rest()
End Sub
