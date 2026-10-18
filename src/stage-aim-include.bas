' what the pages of aimed spells share: stepping along a line from the player, speaking of the monster that is hit,
' and hurting it, the aimed spells libraries, stage-lib-spells-3.bas to stage-lib-spells-5.bas, include this file,
' each has its own copy of these routines
' N.B: the page's own storage from A_LIB_PRIVATE + 0 to + 7 is used here

Dim gub_aim_y               As UByte    At A_LIB_PRIVATE            ' the square the spell has reached
Dim gub_aim_x               As UByte    At A_LIB_PRIVATE + 1
Dim gub_aim_distance        As UByte    At A_LIB_PRIVATE + 2        ' how far it has gone

#define UB_AIM_MAX_RANGE    18      ' how far a bolt or ball goes, Moria's OBJECT_BOLTS_MAX_RANGE


Function fuw_aim_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fub_aim_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_aim_square() As UInteger
    ' the map square the spell has reached
    Return fuw_core_map_square( gub_level_map_page , gub_aim_y , gub_aim_x )
End Function


Function fuw_aim_monster( pub_monster As UByte ) As UInteger
    ' where the record of one of the level's monsters is
    Return fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
End Function


Sub s_aim_start()
    ' the spell starts where the player stands
    gub_aim_y        = gub_player_row
    gub_aim_x        = gub_player_col
    gub_aim_distance = 0
End Sub


Sub s_aim_step( pub_direction As UByte )
    ' one square on, Moria's playerMovePosition(), which will not go off the edge of the map
    Dim lsw_y , lsw_x As Integer

    lsw_y = Cast( Integer , gub_aim_y ) + 1 - Cast( Integer , ( pub_direction - 1 ) / 3 )      ' 1 2 3 go down, 7 8 9 go up
    lsw_x = Cast( Integer , gub_aim_x ) + Cast( Integer , ( pub_direction - 1 ) Mod 3 ) - 1    ' 1 4 7 go left, 3 6 9 go right
    If lsw_y >= 0 And lsw_x >= 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) And lsw_x < Cast( Integer , gub_dungeon_cols ) Then
        gub_aim_y = lsw_y
        gub_aim_x = lsw_x
    End If
    gub_aim_distance = gub_aim_distance + 1
End Sub


Function fs_aim_name( pub_monster As UByte ) As String
    ' how a monster is spoken of, Moria's monsterNameDescription(), its creature is fetched into A_CREATURE
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , fuw_aim_monster( pub_monster ) + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
    If Peek( fuw_aim_monster( pub_monster ) + UB_MONSTER_LIT_OFFSET ) Then Return "The " + fs_core_text_at( A_CREATURE )
    Return "It"
End Function


Sub s_aim_learn( pub_monster As UByte , pub_what As UByte , pul_value As ULong , pub_only_if_lit As UByte )
    ' the player learns something about the kind of creature a monster is, see ful_core_recall() in core.bas,
    ' with pub_only_if_lit only if they can see the monster
    Dim luw_record As UInteger

    luw_record = fuw_aim_monster( pub_monster )
    If pub_only_if_lit Then
        If Peek( luw_record + UB_MONSTER_LIT_OFFSET ) = 0 Then Return
    End If
    ful_core_recall( Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , pub_what , pul_value )
End Sub


Function fub_aim_take_hit( pub_monster As UByte , psw_damage As Integer ) As UByte
    ' the monster is hurt, Moria's monsterTakeHit(), the player attack library does it, true if that killed it,
    ' in which case the player's experience is shown again, Moria's displayCharacterExperience()
    If fub_aim_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_TAKE_HIT , pub_monster , Cast( UInteger , psw_damage ) ) Then Return true
    Return false
End Function


Sub s_aim_show_experience()
    s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
End Sub


Sub s_aim_delete_object()
    ' whatever is on the square the spell has reached goes, Moria's dungeonDeleteObject()
    gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT , gub_aim_y , gub_aim_x )
End Sub


Sub s_aim_visibility( pub_monster As UByte )
    ' whether the player can see a monster is worked out again, Moria's monsterUpdateVisibility(), the monsters
    ' library does it, on the working monster
    s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster , A_MONSTER )
    gub_shared_1 = fub_aim_call( UB_PAGED_CODE_LIB_MONSTERS , UB_LIB_MONSTERS_VISIBILITY , pub_monster , 0 )
End Sub
