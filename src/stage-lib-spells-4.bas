#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_spells_4()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-aim-include.bas"

' this page is a LIBRARY, not a stage: the spells that do something to a monster other than hurt it with a bolt, the
' aimed ones, which go to the first monster in a line from the player, and the ones that work on every monster in
' sight, which wands, staffs, spell books and prayers all share, from Moria's spells.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SPELLS_4 , <which routine> ), each leaves
' true in gsw_lib_result if the player noticed anything, for the aimed ones the direction, as on a numeric keypad, is
' in gub_lib_param_1, the routines are:
'
'   UB_LIB_SPELLS_4_POLYMORPH       the monster becomes some other kind of creature, spellPolymorphMonster()
'   UB_LIB_SPELLS_4_CHANGE_HP       the monster loses guw_lib_param_2 hit points, a signed number, so a monster is
'                                   healed with a negative one, spellChangeMonsterHitPoints()
'   UB_LIB_SPELLS_4_SPEED           the monster's speed changes by guw_lib_param_2, 1 or -1, spellSpeedMonster()
'   UB_LIB_SPELLS_4_CONFUSE         spellConfuseMonster()
'   UB_LIB_SPELLS_4_SLEEP           spellSleepMonster()
'   UB_LIB_SPELLS_4_DRAIN_LIFE      75 hit points from anything that is alive, spellDrainLifeFromMonster()
'   UB_LIB_SPELLS_4_CLONE           the monster breeds on the spot, spellCloneMonster()
'   UB_LIB_SPELLS_4_TELEPORT_AWAY   every monster in the line is sent away, spellTeleportAwayMonsterInDirection()
'   UB_LIB_SPELLS_4_SPEED_ALL       every monster in sight changes speed by guw_lib_param_2, spellSpeedAllMonsters()
'   UB_LIB_SPELLS_4_SLEEP_ALL       spellSleepAllMonsters()
'   UB_LIB_SPELLS_4_MASS_POLYMORPH  spellMassPolymorph()
'   UB_LIB_SPELLS_4_DETECT          every monster on the screen with any of the "defenses" bits in guw_lib_param_2
'                                   shows for a moment, with 0 it is every monster that is not invisible, Moria's
'                                   spellDetectEvil() and spellDetectMonsters()
'   UB_LIB_SPELLS_4_TURN_UNDEAD     the undead in sight flee, spellTurnUndead()
'
' what is NOT here yet: nothing that is known of
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fub_s4_next_monster( pub_direction As UByte ) As UByte
    ' goes on along the line to the next monster, its number comes back, 0 if the spell ran out of range or into
    ' a wall first, this is the loop that every aimed spell in Moria begins with
    Dim luw_square  As UInteger
    Dim lub_monster As UByte

    Do
        s_aim_step( pub_direction )
        luw_square = fuw_aim_square()
        If gub_aim_distance > UB_AIM_MAX_RANGE Or Peek( luw_square + UB_SQUARE_FEATURE ) >= UB_TILE_MIN_CLOSED Then Return 0
        lub_monster = Peek( luw_square + UB_SQUARE_MONSTER )
    Loop Until lub_monster > 1
    Return lub_monster
End Function


Function fub_s4_resists( pub_monster As UByte ) As UByte
    ' the test Moria makes for confusing and for sleeping: a strong creature may shrug it off, and one that never
    ' sleeps always does, the creature must be in A_CREATURE
    If fuw_aim_random( UB_MON_MAX_LEVELS ) < gub_creature_level Or ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then
        ' a player who can see it learns that this kind of creature never sleeps, if that is why
        If ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) <> 0 Then s_aim_learn( pub_monster , UB_RECALL_DEFENSES , UW_CD_NO_SLEEP , true )
        Return true
    End If
    Return false
End Function


Function fub_s4_in_sight( pub_monster As UByte ) As UByte
    ' true if a monster is near enough and in a clear line from the player, the test the "all monsters" spells make
    Dim luw_record As UInteger

    luw_record = fuw_aim_monster( pub_monster )
    If Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) > UB_MON_MAX_SIGHT Then Return false
    guw_lib_param_2 = ( Cast( UInteger , gub_player_row ) << 8 ) bOr gub_player_col
    gsw_lib_result  = ( Cast( UInteger , Peek( luw_record + UB_MONSTER_ROW_OFFSET ) ) << 8 ) bOr Peek( luw_record + UB_MONSTER_COL_OFFSET )
    s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_LOS )
    If gsw_lib_result Then Return true
    Return false
End Function


'##################################################################################################################################
' --- aimed at one monster ---

Function fub_s4_polymorph( pub_direction As UByte ) As UByte
    ' Moria's spellPolymorphMonster(): the first monster in the line that cannot resist becomes something else
    Dim lub_monster As UByte
    Dim ls_name     As String

    s_aim_start()
    Do
        lub_monster = fub_s4_next_monster( pub_direction )
        If lub_monster = 0 Then Return false
        ls_name = fs_aim_name( lub_monster )
        If fuw_aim_random( UB_MON_MAX_LEVELS ) > gub_creature_level Then
            ' the old one goes and a new one, of any kind at all, takes its place, the monsters library makes it
            gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE , lub_monster , 0 )
            If fub_aim_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_POLYMORPH_AT , gub_aim_y , gub_aim_x ) = false Then Return false
            ' don't count it unless the player can see where it happened
            If fub_cr_inside_panel( gub_aim_y , gub_aim_x ) And ( Peek( fuw_aim_square() + UB_SQUARE_FLAGS ) bAnd ( MB_SQUARE_TEMP_LIGHT bOr MB_SQUARE_PERM_LIGHT ) ) <> 0 Then Return true
            Return false
        End If
        s_msg( ls_name + " is unaffected." )
    Loop
    ' never reached, it is here because the compiler wants a function to end with a Return
    Return false
End Function


Function fub_s4_change_hp( pub_direction As UByte , psw_damage As Integer ) As UByte
    ' Moria's spellChangeMonsterHitPoints()
    Dim lub_monster As UByte
    Dim ls_name     As String

    s_aim_start()
    lub_monster = fub_s4_next_monster( pub_direction )
    If lub_monster = 0 Then Return false
    ls_name = fs_aim_name( lub_monster )
    If fub_aim_take_hit( lub_monster , psw_damage ) Then
        s_msg( ls_name + " dies in a fit of agony." )
        s_aim_show_experience()
    ElseIf psw_damage > 0 Then
        s_msg( ls_name + " screams in agony." )
    End If
    Return true
End Function


Function fub_s4_speed_one( pub_monster As UByte , psw_speed As Integer , pub_only_if_seen As UByte ) As UByte
    ' what Moria's spellSpeedMonster() and spellSpeedAllMonsters() do to one monster: speeding up always works,
    ' slowing down may be resisted, true if the player noticed
    Dim luw_record          As UInteger
    Dim ls_name             As String
    Dim lub_lit             As UByte
    Dim lub_changed         As UByte = false

    ls_name    = fs_aim_name( pub_monster )
    luw_record = fuw_aim_monster( pub_monster )
    lub_lit    = Peek( luw_record + UB_MONSTER_LIT_OFFSET )
    If pub_only_if_seen = false Then lub_lit = true

    If psw_speed > 0 Then
        lub_changed = true
    ElseIf fuw_aim_random( UB_MON_MAX_LEVELS ) > gub_creature_level Then
        lub_changed = true
    End If

    luw_record = fuw_aim_monster( pub_monster )
    If lub_changed Then
        Poke UInteger luw_record + UB_MONSTER_SPEED_OFFSET , Cast( UInteger , Peek( Integer , luw_record + UB_MONSTER_SPEED_OFFSET ) + psw_speed )
        Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
        If lub_lit Then
            If psw_speed > 0 Then
                s_msg( ls_name + " starts moving faster." )
            Else
                s_msg( ls_name + " starts moving slower." )
            End If
            Return true
        End If
    ElseIf lub_lit Then
        Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
        s_msg( ls_name + " is unaffected." )
    End If
    Return false
End Function


Function fub_s4_confuse( pub_direction As UByte ) As UByte
    ' Moria's spellConfuseMonster()
    Dim lub_monster , lub_confused  As UByte
    Dim luw_record                  As UInteger
    Dim ls_name                     As String

    s_aim_start()
    lub_monster = fub_s4_next_monster( pub_direction )
    If lub_monster = 0 Then Return false
    ls_name    = fs_aim_name( lub_monster )
    luw_record = fuw_aim_monster( lub_monster )
    If fub_s4_resists( lub_monster ) Then
        ' monsters which resisted the attack should wake up, monsters with innate resistance ignore the attack
        If ( guw_creature_defenses bAnd UW_CD_NO_SLEEP ) = 0 Then Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
        s_msg( ls_name + " is unaffected." )
        Return false
    End If
    lub_confused = Peek( luw_record + UB_MONSTER_CONFUSED_OFFSET )
    If lub_confused <> 0 Then
        lub_confused = lub_confused + 3
    Else
        lub_confused = 2 + fuw_aim_random( 16 )
    End If
    luw_record = fuw_aim_monster( lub_monster )
    Poke luw_record + UB_MONSTER_CONFUSED_OFFSET , lub_confused
    Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
    s_msg( ls_name + " appears confused." )
    Return true
End Function


Function fub_s4_sleep_one( pub_monster As UByte , pub_only_if_seen As UByte ) As UByte
    ' what Moria's spellSleepMonster() and spellSleepAllMonsters() do to one monster, true if the player noticed
    ' it fall asleep
    Dim ls_name As String
    Dim lub_lit As UByte

    ls_name = fs_aim_name( pub_monster )
    lub_lit = Peek( fuw_aim_monster( pub_monster ) + UB_MONSTER_LIT_OFFSET )
    If pub_only_if_seen = false Then lub_lit = true
    If fub_s4_resists( pub_monster ) Then
        If lub_lit Then s_msg( ls_name + " is unaffected." )
        Return false
    End If
    Poke UInteger fuw_aim_monster( pub_monster ) + UB_MONSTER_SLEEP_OFFSET , 500
    If lub_lit Then
        s_msg( ls_name + " falls asleep." )
        Return true
    End If
    Return false
End Function


Function fub_s4_drain_life( pub_direction As UByte ) As UByte
    ' Moria's spellDrainLifeFromMonster(): the undead have no life to drain
    Dim lub_monster As UByte
    Dim ls_name     As String

    s_aim_start()
    lub_monster = fub_s4_next_monster( pub_direction )
    If lub_monster = 0 Then Return false
    ls_name = fs_aim_name( lub_monster )
    If ( guw_creature_defenses bAnd UW_CD_UNDEAD ) <> 0 Then
        ' and so the player learns that it is one of them
        s_aim_learn( lub_monster , UB_RECALL_DEFENSES , UW_CD_UNDEAD , false )
        Return false
    End If
    If fub_aim_take_hit( lub_monster , 75 ) Then
        s_msg( ls_name + " dies in a fit of agony." )
        s_aim_show_experience()
    Else
        s_msg( ls_name + " screams in agony." )
    End If
    Return true
End Function


Function fub_s4_teleport_away( pub_direction As UByte ) As UByte
    ' Moria's spellTeleportAwayMonsterInDirection(): every monster along the line goes
    Dim lub_monster     As UByte
    Dim lub_teleported  As UByte = false

    s_aim_start()
    lub_monster = fub_s4_next_monster( pub_direction )
    While lub_monster <> 0
        ' wake it up, and send it away, the second monster attack page knows how, it works on the working monster
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        gsw_monster_sleep = 0
        gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_MONSTER_ATTACK_2 , UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY , 0 , UB_MON_MAX_SIGHT )
        s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        lub_teleported = true
        lub_monster = fub_s4_next_monster( pub_direction )
    End While
    Return lub_teleported
End Function


'##################################################################################################################################
' --- every monster in sight ---

Function fub_s4_turn_one( pub_monster As UByte ) As UByte
    ' what Moria's spellTurnUndead() does to one monster in sight: the undead flee, confused, unless they are of a
    ' higher level than the player, and even then one in five does, true if the player saw it run
    Dim ls_name     As String
    Dim lub_lit     As UByte
    Dim lub_turns   As UByte = false

    ls_name = fs_aim_name( pub_monster )
    If ( guw_creature_defenses bAnd UW_CD_UNDEAD ) = 0 Then Return false
    lub_lit = Peek( fuw_aim_monster( pub_monster ) + UB_MONSTER_LIT_OFFSET )
    ' N.B: as in Moria the dice are thrown only for a creature above the player's level
    If guw_player_level + 1 > gub_creature_level Then
        lub_turns = true
    ElseIf fuw_aim_random( 5 ) = 1 Then
        lub_turns = true
    End If
    If lub_turns Then
        If lub_lit Then
            s_aim_learn( pub_monster , UB_RECALL_DEFENSES , UW_CD_UNDEAD , false )
            s_msg( ls_name + " runs frantically!" )
        End If
        Poke fuw_aim_monster( pub_monster ) + UB_MONSTER_CONFUSED_OFFSET , guw_player_level
        If lub_lit Then Return true
    ElseIf lub_lit Then
        s_msg( ls_name + " is unaffected." )
    End If
    Return false
End Function


Function fub_s4_all( pub_function As UByte , psw_speed As Integer ) As UByte
    ' Moria's spellSpeedAllMonsters(), spellSleepAllMonsters() and spellMassPolymorph(), every monster from the
    ' newest to the oldest
    Dim lub_monster , lub_y , lub_x As UByte
    Dim luw_record                  As UInteger
    Dim lub_noticed                 As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        If pub_function = UB_LIB_SPELLS_4_MASS_POLYMORPH Then
            luw_record = fuw_aim_monster( lub_monster )
            If Peek( luw_record + UB_MONSTER_DISTANCE_OFFSET ) <= UB_MON_MAX_SIGHT Then
                lub_y = Peek( luw_record + UB_MONSTER_ROW_OFFSET )
                lub_x = Peek( luw_record + UB_MONSTER_COL_OFFSET )
                s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
                If ( gul_creature_movement bAnd UL_CM_WIN ) = 0 Then
                    gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE , lub_monster , 0 )
                    ' place_monster() should always return true here
                    lub_noticed = fub_aim_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_POLYMORPH_AT , lub_y , lub_x )
                End If
            End If
        ElseIf fub_s4_in_sight( lub_monster ) Then
            If pub_function = UB_LIB_SPELLS_4_TURN_UNDEAD Then
                If fub_s4_turn_one( lub_monster ) Then lub_noticed = true
            ElseIf pub_function = UB_LIB_SPELLS_4_SPEED_ALL Then
                If fub_s4_speed_one( lub_monster , psw_speed , true ) Then lub_noticed = true
            Else
                If fub_s4_sleep_one( lub_monster , true ) Then lub_noticed = true
            End If
        End If
    End While
    Return lub_noticed
End Function


Function fub_s4_detect( puw_defenses As UInteger ) As UByte
    ' Moria's spellDetectEvil() and spellDetectMonsters(): they show until the player has read the message
    Dim lub_monster , lub_show  As UByte
    Dim luw_record              As UInteger
    Dim lub_detected            As UByte = false

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        luw_record  = fuw_aim_monster( lub_monster )
        If fub_cr_inside_panel( Peek( luw_record + UB_MONSTER_ROW_OFFSET ) , Peek( luw_record + UB_MONSTER_COL_OFFSET ) ) Then
            s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
            lub_show = false
            If puw_defenses = 0 Then
                If ( gul_creature_movement bAnd UL_CM_INVISIBLE ) = 0 Then lub_show = true
            Else
                If ( guw_creature_defenses bAnd puw_defenses ) <> 0 Then lub_show = true
            End If
            If lub_show Then
                luw_record = fuw_aim_monster( lub_monster )
                Poke luw_record + UB_MONSTER_LIT_OFFSET , 1
                s_cr_put( Peek( luw_record + UB_MONSTER_ROW_OFFSET ) , Peek( luw_record + UB_MONSTER_COL_OFFSET ) )
                lub_detected = true
            End If
        End If
    End While
    If lub_detected Then
        If puw_defenses = 0 Then
            s_core_message( UW_MSG_YOU_SENSE_THE_PRESENCE_OF_MONSTERS )
        Else
            s_core_message( UW_MSG_YOU_SENSE_THE_PRESENCE_OF_EVIL )
        End If
        s_msg_flush()
        ' must unlight every monster just lighted
        gub_game_turn_flags = gub_game_turn_flags bOr MB_TURN_UPDATE_MONSTERS
    End If
    Return lub_detected
End Function


Sub s_lib_spells_4()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte
    Dim lub_direction , lub_monster         As UByte
    Dim lsw_amount                          As Integer
    Dim lub_noticed                         As UByte = false

    ' N.B: these are taken out first, the routines here call other libraries, which use the same places
    lub_direction = gub_lib_param_1
    lsw_amount    = guw_lib_param_2
    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the creatures database is read through the items' slot, so that slot is put back as it was found too
    lub_saved_page_1 = gub_core_MMU1_page_number
    If gub_lib_function = UB_LIB_SPELLS_4_POLYMORPH Then
        lub_noticed = fub_s4_polymorph( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_CHANGE_HP Then
        lub_noticed = fub_s4_change_hp( lub_direction , lsw_amount )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_SPEED Then
        ' Moria's spellSpeedMonster()
        s_aim_start()
        lub_monster = fub_s4_next_monster( lub_direction )
        If lub_monster <> 0 Then lub_noticed = fub_s4_speed_one( lub_monster , lsw_amount , false )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_CONFUSE Then
        lub_noticed = fub_s4_confuse( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_SLEEP Then
        ' Moria's spellSleepMonster()
        s_aim_start()
        lub_monster = fub_s4_next_monster( lub_direction )
        If lub_monster <> 0 Then lub_noticed = fub_s4_sleep_one( lub_monster , false )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_DRAIN_LIFE Then
        lub_noticed = fub_s4_drain_life( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_CLONE Then
        ' Moria's spellCloneMonster(): the monster wakes, and breeds, the monsters library does the breeding
        s_aim_start()
        lub_monster = fub_s4_next_monster( lub_direction )
        If lub_monster <> 0 Then
            Poke UInteger fuw_aim_monster( lub_monster ) + UB_MONSTER_SLEEP_OFFSET , 0
            lub_noticed = fub_aim_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_CLONE , lub_monster , 0 )
        End If
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_TELEPORT_AWAY Then
        lub_noticed = fub_s4_teleport_away( lub_direction )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_SPEED_ALL Or gub_lib_function = UB_LIB_SPELLS_4_SLEEP_ALL Or gub_lib_function = UB_LIB_SPELLS_4_MASS_POLYMORPH Or gub_lib_function = UB_LIB_SPELLS_4_TURN_UNDEAD Then
        lub_noticed = fub_s4_all( gub_lib_function , lsw_amount )
    ElseIf gub_lib_function = UB_LIB_SPELLS_4_DETECT Then
        lub_noticed = fub_s4_detect( Cast( UInteger , lsw_amount ) )
    End If
    If lub_saved_page_0 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
    gsw_lib_result = lub_noticed
End Sub
