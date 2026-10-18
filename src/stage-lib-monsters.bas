#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_monsters()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-map-include.bas"
#include "stage-monster-include.bas"
#include "stage-disturb-include.bas"

' this page is a LIBRARY, not a stage: the monsters on a level, putting them there and working out which of them the
' player can see, from Moria's monster_manager.cpp, monster.cpp and dungeon_los.cpp...
' ...a stage reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_MONSTERS , <which routine> ), the routines are:
'
'   UB_LIB_MONSTERS_PLACE_ASLEEP    puts guw_lib_param_2 monsters, of kinds fit for this depth, on open squares picked
'                                   at random that are more than gub_lib_param_1 from the player, asleep, Moria's
'                                   monsterPlaceNewWithinDistance()
'   UB_LIB_MONSTERS_PLACE_AWAKE     the same, but awake, all but the dragons
'   UB_LIB_MONSTERS_PLACE_WINNING   puts one of the two end game creatures, Evil Iggy or the Balrog, somewhere out
'                                   of sight, Moria's monsterPlaceWinning()
'   UB_LIB_MONSTERS_UPDATE          works out afresh how far each monster is from the player and whether the player
'                                   can see it, and draws the ones that have come into view or gone out of it, Moria's
'                                   updateMonsters() when it is told not to move them
'
'   UB_LIB_MONSTERS_VISIBILITY      works out whether the player can see the working monster (A_MONSTER), which is
'                                   number gub_lib_param_1 on the level, and draws it if that has changed, Moria's
'                                   monsterUpdateVisibility(), for the monster moves library
'
'   UB_LIB_MONSTERS_SUMMON          a monster from a little deeper than here appears beside the player, awake,
'                                   Moria's monsterSummon(), gsw_lib_result is true if there was room for it
'   UB_LIB_MONSTERS_SUMMON_UNDEAD   the same, but one of the undead, of any depth, Moria's monsterSummonUndead()
'   UB_LIB_MONSTERS_SUMMON_AT       as UB_LIB_MONSTERS_SUMMON, but beside the square at row gub_lib_param_1 and
'                                   column guw_lib_param_2, and asleep, for when a level is being made, or awake
'                                   if the high byte of guw_lib_param_2 is not 0, for a chest's trap
'   UB_LIB_MONSTERS_MULTIPLY        the working monster, number gub_lib_param_1, may breed, Moria's
'                                   monsterMultiplyCritter()
'   UB_LIB_MONSTERS_CLONE           monster number gub_lib_param_1 breeds at once, Moria's monsterMultiply(), for a spell
'   UB_LIB_MONSTERS_POLYMORPH_AT    a creature of a kind picked at random from all there are appears on the square
'                                   at row gub_lib_param_1 and column guw_lib_param_2, awake, for the polymorph spells
'   UB_LIB_MONSTERS_LOS             gsw_lib_result is true if there is a clear line of sight between two squares,
'                                   Moria's los(): one is in guw_lib_param_2 and the other in gsw_lib_result, each
'                                   as its row in the high byte and its column in the low byte
'
' a level's monsters are a list of 64 byte records in the level's monsters page (gub_level_monsters_page), in the first
' paged data slot, numbered from 2, as in Moria: on the map 0 means nobody is on a square and 1 means the player is,
' the record's layout is in globals.bas, "the working monster"
'
' which kinds can turn up depends on the depth: the creatures database is in order of level, and a table says how many
' of them are of each level or less (A_TABLE_MONSTER_LEVELS)
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of, making room when the list is full is the compact library's, stage-lib-compact.bas
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


Function fuw_mon_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Function fuw_mon_levels( puw_level As UInteger ) As UInteger
    ' how many kinds of creature are of this level or less, Moria's monster_levels[], N.B: the table is in the core data
    Return Peek( UInteger , A_TABLE_MONSTER_LEVELS + puw_level * 2 )
End Function


'##################################################################################################################################
' --- putting monsters on a level ---

Function fuw_mon_suitable( puw_level As UInteger ) As UInteger
    ' picks a kind of creature fit for the given depth, Moria's monsterGetOneSuitableForLevel(): one time in fifty
    ' something from deeper down, otherwise the level of the higher of two picks from everything found this deep,
    ' and then any creature of that level
    Dim luw_number , luw_i , luw_j , luw_below  As UInteger
    Dim lsw_extra                               As Integer

    If puw_level = 0 Then Return fuw_mon_random( fuw_mon_levels( 0 ) ) - 1

    If puw_level > UB_MON_MAX_LEVELS Then puw_level = UB_MON_MAX_LEVELS

    If fuw_mon_random( UB_MON_CHANCE_OF_NASTY ) = 1 Then
        lsw_extra = fsw_core_random_normal( 0 , 4 )
        If lsw_extra < 0 Then lsw_extra = -lsw_extra
        puw_level = puw_level + lsw_extra + 1
        If puw_level > UB_MON_MAX_LEVELS Then puw_level = UB_MON_MAX_LEVELS
    Else
        ' this code has been added to make it slightly more likely to get the higher level monsters
        luw_below  = fuw_mon_levels( 0 )
        luw_number = fuw_mon_levels( puw_level ) - luw_below
        luw_i = fuw_mon_random( luw_number ) - 1
        luw_j = fuw_mon_random( luw_number ) - 1
        If luw_j > luw_i Then luw_i = luw_j
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_i + luw_below , A_CREATURE )
        puw_level = gub_creature_level
    End If

    luw_below = fuw_mon_levels( puw_level - 1 )
    Return fuw_mon_random( fuw_mon_levels( puw_level ) - luw_below ) - 1 + luw_below
End Function


Function fub_mon_place_new( pub_y As UByte , pub_x As UByte , puw_creature As UInteger , pub_sleeping As UByte ) As UByte
    ' makes a monster of the given kind on a square, Moria's monsterPlaceNew(), false if the level can hold no more
    ' N.B: the creature's own record must already be in A_CREATURE
    Dim lub_number  As UByte
    Dim i           As UByte

    ' when the list is full the furthest monsters are thrown away to make room, the compact library, Moria's
    ' compactMonsters(), N.B: it puts the working creature back as it found it
    If gub_dungeon_monster_next >= UB_MON_TOTAL_ALLOCATIONS Then
        s_core_call_library( UB_PAGED_CODE_LIB_COMPACT , UB_LIB_COMPACT_MONSTERS )
        If gsw_lib_result = false Then Return false
    End If
    If gub_dungeon_monster_next >= UB_MON_TOTAL_ALLOCATIONS Then Return false
    lub_number               = gub_dungeon_monster_next
    gub_dungeon_monster_next = gub_dungeon_monster_next + 1

    For i = 0 To UB_RECORD_SIZE - 1
        Poke A_MONSTER + i , 0
    Next
    gub_monster_row      = pub_y
    gub_monster_col      = pub_x
    guw_monster_creature = puw_creature
    If ( guw_creature_defenses bAnd UW_CD_MAX_HP ) <> 0 Then
        gsw_monster_hp = Cast( Integer , gub_creature_hit_dice ) * Cast( Integer , gub_creature_hit_sides )
    Else
        gsw_monster_hp = fuw_core_dice_roll( gub_creature_hit_dice , gub_creature_hit_sides )
    End If
    ' the speed is the creature's own, the database holds it with 10 added, and the player's speed counts against it
    gsw_monster_speed    = Cast( Integer , gub_creature_speed ) - 10 + gsw_player_speed
    gub_monster_distance = fub_mon_distance( gub_player_row , gub_player_col , pub_y , pub_x )
    ' ours, not Moria's: what it looks like, kept with the monster so that drawing the map need not look the creature up
    gub_monster_sprite   = gub_creature_sprite

    If pub_sleeping And gub_creature_sleep <> 0 Then
        gsw_monster_sleep = Cast( Integer , gub_creature_sleep ) * 2 + fuw_mon_random( Cast( UInteger , gub_creature_sleep ) * 10 )
    End If

    s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_number , A_MONSTER )
    Poke fuw_core_map_square( gub_level_map_page , pub_y , pub_x ) + UB_SQUARE_MONSTER , lub_number
    Return true
End Function


Sub s_mon_place_within( puw_number As UInteger , pub_distance As UByte , pub_sleeping As UByte )
    ' Moria's monsterPlaceNewWithinDistance()
    ' N.B: as in Moria, once a dragon has been put down asleep, everything after it in the same batch is asleep too
    Dim luw_i , luw_creature , luw_square   As UInteger
    Dim lub_y , lub_x , lub_found           As UByte

    If puw_number = 0 Then Return
    For luw_i = 1 To puw_number
        Do
            lub_y = fuw_mon_random( gub_dungeon_rows - 2 )
            lub_x = fuw_mon_random( gub_dungeon_cols - 2 )
            luw_square = fuw_core_map_square( gub_level_map_page , lub_y , lub_x )
            lub_found  = true
            If Peek( luw_square ) >= UB_TILE_MIN_CLOSED Then lub_found = false
            If Peek( luw_square + UB_SQUARE_MONSTER ) <> 0 Then lub_found = false
            If fub_mon_distance( lub_y , lub_x , gub_player_row , gub_player_col ) <= pub_distance Then lub_found = false
        Loop Until lub_found

        luw_creature = fuw_mon_suitable( guw_dungeon_level )
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature , A_CREATURE )
        ' dragons are always created sleeping
        If gub_creature_sprite = Code( "d" ) Or gub_creature_sprite = Code( "D" ) Then pub_sleeping = true
        gub_shared_1 = fub_mon_place_new( lub_y , lub_x , luw_creature , pub_sleeping )
    Next
End Sub


Sub s_mon_place_winning()
    ' Moria's monsterPlaceWinning(): one of the last two creatures in the database, somewhere open and empty that
    ' the player cannot see from where they arrive, awake
    Dim luw_creature , luw_square   As UInteger
    Dim lub_y , lub_x , lub_found   As UByte

    If gub_game_total_winner Then Return
    Do
        lub_y = fuw_mon_random( gub_dungeon_rows - 2 )
        lub_x = fuw_mon_random( gub_dungeon_cols - 2 )
        luw_square = fuw_core_map_square( gub_level_map_page , lub_y , lub_x )
        lub_found  = true
        If Peek( luw_square ) >= UB_TILE_MIN_CLOSED Then lub_found = false
        If Peek( luw_square + UB_SQUARE_MONSTER ) <> 0 Then lub_found = false
        If Peek( luw_square + UB_SQUARE_ITEM ) <> 0 Then lub_found = false
        If fub_mon_distance( lub_y , lub_x , gub_player_row , gub_player_col ) <= UB_MON_MAX_SIGHT Then lub_found = false
    Loop Until lub_found

    luw_creature = fuw_mon_random( UB_MON_ENDGAME_MONSTERS ) - 1 + fuw_mon_levels( UB_MON_MAX_LEVELS )
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature , A_CREATURE )
    ' N.B: Moria stops dead if there is no room in the list for it, we carry on without it
    gub_shared_1 = fub_mon_place_new( lub_y , lub_x , luw_creature , false )
End Sub


Function fub_mon_place_adjacent( pub_y As UByte , pub_x As UByte , puw_creature As UInteger , pub_sleeping As UByte ) As UByte
    ' Moria's placeMonsterAdjacentTo(): a monster of the given kind on an open, empty square beside the one
    ' given, ten tries at finding one
    Dim lsw_y , lsw_x   As Integer
    Dim luw_square      As UInteger
    Dim i               As UByte

    For i = 0 To 9
        lsw_y = Cast( Integer , pub_y ) - 2 + Cast( Integer , fuw_mon_random( 3 ) )
        lsw_x = Cast( Integer , pub_x ) - 2 + Cast( Integer , fuw_mon_random( 3 ) )
        If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 Then
            luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
            If Peek( luw_square ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_MONSTER ) = 0 Then
                s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , puw_creature , A_CREATURE )
                Return fub_mon_place_new( lsw_y , lsw_x , puw_creature , pub_sleeping )
            End If
        End If
    Next
    Return false
End Function


Function fub_mon_multiply_now( pub_parent As UByte ) As UByte
    ' Moria's monsterMultiply(): another of the working monster's kind (A_MONSTER, its creature in A_CREATURE) is
    ' made on an open square near it, eating whatever lesser monster is in the way if it is that kind, true if the
    ' player saw it happen, pub_parent is its number on the level, or 0 for a spell's doing
    ' N.B: making a monster uses the working monster, so the parent is put aside meanwhile, in this page's own storage
    Dim lsw_y , lsw_x               As Integer
    Dim i                           As UByte
    Dim lub_other , lub_new         As UByte
    Dim luw_square , luw_theirs     As UInteger
    Dim lub_place , lub_seen        As UByte
    s_core_ram_copy( A_MONSTER , A_LIB_PRIVATE , UB_RECORD_SIZE )
    lub_seen = false
    i = 0
    While i <= 18
        i = i + 1
        lsw_y = Cast( Integer , Peek( A_LIB_PRIVATE + UB_MONSTER_ROW_OFFSET ) ) - 2 + Cast( Integer , fuw_mon_random( 3 ) )
        lsw_x = Cast( Integer , Peek( A_LIB_PRIVATE + UB_MONSTER_COL_OFFSET ) ) - 2 + Cast( Integer , fuw_mon_random( 3 ) )
        ' don't create a new creature on top of the old one, that causes invincible/invisible creatures to appear
        If lsw_y > 0 And lsw_x > 0 And lsw_y < Cast( Integer , gub_dungeon_rows ) - 1 And lsw_x < Cast( Integer , gub_dungeon_cols ) - 1 And ( lsw_y <> Peek( A_LIB_PRIVATE + UB_MONSTER_ROW_OFFSET ) Or lsw_x <> Peek( A_LIB_PRIVATE + UB_MONSTER_COL_OFFSET ) ) Then
            luw_square = fuw_core_map_square( gub_level_map_page , lsw_y , lsw_x )
            lub_other  = Peek( luw_square + UB_SQUARE_MONSTER )
            If Peek( luw_square ) <= UB_TILE_MAX_OPEN And Peek( luw_square + UB_SQUARE_ITEM ) = 0 And lub_other <> 1 Then
                lub_place = true
                If lub_other > 1 Then
                    ' some critters are cannibalistic, check the experience level, as in the monster moves library
                    lub_place = false
                    If ( gul_creature_movement bAnd UL_CM_EATS_OTHER ) <> 0 Then
                        luw_theirs = Peek( UInteger , fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_other ) + UB_MONSTER_CREATURE_OFFSET )
                        luw_theirs = Peek( UInteger , fuw_core_record_address( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_theirs ) + UB_CREATURE_KILL_EXP_OFFSET )
                        If guw_creature_kill_exp >= luw_theirs Then
                            gub_lib_param_1 = lub_other
                            If pub_parent < lub_other Then
                                s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_DELETE )
                            Else
                                s_core_call_library( UB_PAGED_CODE_LIB_MONSTER_MOVES , UB_LIB_MONSTER_MOVES_REMOVE )
                            End If
                            lub_place = true
                        End If
                    End If
                End If
                If lub_place Then
                    ' in case the new monster is created
                    lub_new = gub_dungeon_monster_next
                    If fub_mon_place_new( lsw_y , lsw_x , Peek( UInteger , A_LIB_PRIVATE + UB_MONSTER_CREATURE_OFFSET ) , false ) Then
                        gsw_game_multiply_total = gsw_game_multiply_total + 1
                        ' Moria's monsterMakeVisible()
                        s_mon_update_visibility( lub_new )
                        If gub_monster_lit Then lub_seen = true
                        ' N.B: if the player saw it the monster moves library notes that this kind of creature breeds
                    End If
                    i = 99
                End If
            End If
        End If
    End While
    s_core_ram_copy( A_LIB_PRIVATE , A_MONSTER , UB_RECORD_SIZE )
    Return lub_seen
End Function


Function fub_mon_multiply( pub_parent As UByte ) As UByte
    ' Moria's monsterMultiplyCritter() and monsterMultiply(): the working monster (A_MONSTER, number pub_parent,
    ' its creature in A_CREATURE) may make another of its kind on a square near it, the more crowded it is the
    ' less likely, true if the player saw it happen
    Dim y , x , lub_counter As UByte

    lub_counter = 0
    For y = gub_monster_row - 1 To gub_monster_row + 1
        For x = gub_monster_col - 1 To gub_monster_col + 1
            If Peek( fuw_core_map_square( gub_level_map_page , y , x ) + UB_SQUARE_MONSTER ) > 1 Then lub_counter = lub_counter + 1
        Next
    Next
    ' can't call randint with a value of zero, increment counter to allow creature multiplication
    If lub_counter = 0 Then lub_counter = 1
    If lub_counter >= 4 Then Return false
    If fuw_mon_random( Cast( UInteger , lub_counter ) * 7 ) <> 1 Then Return false
    Return fub_mon_multiply_now( pub_parent )
End Function



Function fub_mon_summon_undead() As UByte
    ' Moria's monsterSummonUndead(): a creature is picked at random and the list searched on from it, twenty
    ' creatures at most, for one of the undead, and so on until one turns up
    Dim luw_max , luw_creature  As UInteger
    Dim i                       As UByte

    luw_max = fuw_mon_levels( UB_MON_MAX_LEVELS )
    Do
        luw_creature = fuw_mon_random( luw_max ) - 1
        i = 0
        While i <= 19
            s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature , A_CREATURE )
            If ( guw_creature_defenses bAnd UW_CD_UNDEAD ) <> 0 Then
                i = 20
                luw_max = 0
            Else
                luw_creature = luw_creature + 1
                If luw_creature > luw_max Then
                    i = 20
                Else
                    i = i + 1
                End If
            End If
        End While
    Loop Until luw_max = 0
    Return fub_mon_place_adjacent( gub_player_row , gub_player_col , luw_creature , false )
End Function


'##################################################################################################################################
' --- which monsters the player can see ---

Function fub_mon_closed( psw_y As Integer , psw_x As Integer ) As UByte
    ' true if a square cannot be seen through
    If Peek( fuw_core_map_square( gub_level_map_page , psw_y , psw_x ) ) >= UB_TILE_MIN_CLOSED Then Return true
    Return false
End Function


Function fub_mon_los( psw_from_y As Integer , psw_from_x As Integer , psw_to_y As Integer , psw_to_x As Integer ) As UByte
    ' true if there is a clear line of sight from one square to another, Moria's los() (dungeon_los.cpp), which
    ' steps along the longer side of the line a square at a time, keeping count of how far along the shorter side
    ' it has got, in whole numbers only
    ' N.B: the sums fit in 16 bits for any two squares of a map of 66 rows by 198 columns, the largest is under 22000
    Dim lsw_delta_x , lsw_delta_y , lsw_tmp     As Integer
    Dim lsw_xx , lsw_yy                         As Integer
    Dim lsw_scale , lsw_scale_half , lsw_slope  As Integer
    Dim lsw_x_sign , lsw_y_sign                 As Integer
    Dim lsw_abs_x , lsw_abs_y , lsw_part        As Integer

    lsw_delta_x = psw_to_x - psw_from_x
    lsw_delta_y = psw_to_y - psw_from_y

    ' adjacent
    If lsw_delta_x < 2 And lsw_delta_x > -2 And lsw_delta_y < 2 And lsw_delta_y > -2 Then Return true

    ' straight up or down
    If lsw_delta_x = 0 Then
        If lsw_delta_y < 0 Then
            lsw_tmp    = psw_from_y
            psw_from_y = psw_to_y
            psw_to_y   = lsw_tmp
        End If
        lsw_yy = psw_from_y + 1
        While lsw_yy < psw_to_y
            If fub_mon_closed( lsw_yy , psw_from_x ) Then Return false
            lsw_yy = lsw_yy + 1
        End While
        Return true
    End If

    ' straight across
    If lsw_delta_y = 0 Then
        If lsw_delta_x < 0 Then
            lsw_tmp    = psw_from_x
            psw_from_x = psw_to_x
            psw_to_x   = lsw_tmp
        End If
        lsw_xx = psw_from_x + 1
        While lsw_xx < psw_to_x
            If fub_mon_closed( psw_from_y , lsw_xx ) Then Return false
            lsw_xx = lsw_xx + 1
        End While
        Return true
    End If

    ' at a slant
    lsw_abs_x = lsw_delta_x
    lsw_x_sign = 1
    If lsw_delta_x < 0 Then
        lsw_abs_x  = -lsw_delta_x
        lsw_x_sign = -1
    End If
    lsw_abs_y = lsw_delta_y
    lsw_y_sign = 1
    If lsw_delta_y < 0 Then
        lsw_abs_y  = -lsw_delta_y
        lsw_y_sign = -1
    End If
    lsw_scale_half = lsw_abs_x * lsw_abs_y
    lsw_scale      = lsw_scale_half << 1

    If lsw_abs_x >= lsw_abs_y Then
        ' lsw_part is the "fractional" y position
        lsw_part  = lsw_delta_y * lsw_delta_y
        lsw_slope = lsw_part << 1
        lsw_xx    = psw_from_x + lsw_x_sign
        ' consider the special case where the slope is exactly 1
        If lsw_part = lsw_scale_half Then
            lsw_yy   = psw_from_y + lsw_y_sign
            lsw_part = lsw_part - lsw_scale
        Else
            lsw_yy = psw_from_y
        End If
        While psw_to_x - lsw_xx <> 0
            If fub_mon_closed( lsw_yy , lsw_xx ) Then Return false
            lsw_part = lsw_part + lsw_slope
            If lsw_part < lsw_scale_half Then
                lsw_xx = lsw_xx + lsw_x_sign
            ElseIf lsw_part > lsw_scale_half Then
                lsw_yy = lsw_yy + lsw_y_sign
                If fub_mon_closed( lsw_yy , lsw_xx ) Then Return false
                lsw_xx   = lsw_xx + lsw_x_sign
                lsw_part = lsw_part - lsw_scale
            Else
                ' this is the case where the line passes exactly through a corner, both squares are stepped over
                lsw_xx   = lsw_xx + lsw_x_sign
                lsw_yy   = lsw_yy + lsw_y_sign
                lsw_part = lsw_part - lsw_scale
            End If
        End While
        Return true
    End If

    ' lsw_part is the "fractional" x position
    lsw_part  = lsw_delta_x * lsw_delta_x
    lsw_slope = lsw_part << 1
    lsw_yy    = psw_from_y + lsw_y_sign
    If lsw_part = lsw_scale_half Then
        lsw_xx   = psw_from_x + lsw_x_sign
        lsw_part = lsw_part - lsw_scale
    Else
        lsw_xx = psw_from_x
    End If
    While psw_to_y - lsw_yy <> 0
        If fub_mon_closed( lsw_yy , lsw_xx ) Then Return false
        lsw_part = lsw_part + lsw_slope
        If lsw_part < lsw_scale_half Then
            lsw_yy = lsw_yy + lsw_y_sign
        ElseIf lsw_part > lsw_scale_half Then
            lsw_xx = lsw_xx + lsw_x_sign
            If fub_mon_closed( lsw_yy , lsw_xx ) Then Return false
            lsw_yy   = lsw_yy + lsw_y_sign
            lsw_part = lsw_part - lsw_scale
        Else
            lsw_xx   = lsw_xx + lsw_x_sign
            lsw_yy   = lsw_yy + lsw_y_sign
            lsw_part = lsw_part - lsw_scale
        End If
    End While
    Return true
End Function


Function fub_mon_is_visible( puw_creature As UInteger , pub_y As UByte , pub_x As UByte , pub_distance As UByte ) As UByte
    ' Moria's monsterIsVisible(): a monster in the light is seen unless it is invisible and the player cannot see
    ' such things, one in the dark is seen only if it is warm, near, and the player sees heat
    Dim lub_flags As UByte
    Dim lub_light As UByte = false

    lub_flags = Peek( fuw_core_map_square( gub_level_map_page , pub_y , pub_x ) + UB_SQUARE_FLAGS )
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , puw_creature , A_CREATURE )
    If ( lub_flags bAnd ( MB_SQUARE_PERM_LIGHT bOr MB_SQUARE_TEMP_LIGHT ) ) <> 0 Then lub_light = true
    ' a running player with a light also sees whatever is right beside them
    If gub_game_running <> 0 And pub_distance < 2 And gub_player_carrying_light <> 0 Then lub_light = true
    If lub_light Then
        If ( gul_creature_movement bAnd UL_CM_INVISIBLE ) = 0 Then Return true
        If gub_player_see_invisible Then
            ' the player remembers that this kind of creature is invisible
            ful_core_recall( puw_creature , UB_RECALL_MOVEMENT , UL_CM_INVISIBLE )
            Return true
        End If
    ElseIf gsw_player_see_infra > 0 Then
        If Cast( Integer , pub_distance ) <= gsw_player_see_infra And ( guw_creature_defenses bAnd UW_CD_INFRA ) <> 0 Then
            ' the player remembers that this kind of creature is warm
            ful_core_recall( puw_creature , UB_RECALL_DEFENSES , UW_CD_INFRA )
            Return true
        End If
    End If
    Return false
End Function


Sub s_mon_update_visibility( pub_monster As UByte )
    ' Moria's monsterUpdateVisibility(): the monster is seen if it is near enough, in the window, in a clear line
    ' from the player, and visible where it stands, when that changes its square is drawn again
    ' N.B: this works on the working monster, A_MONSTER, pub_monster is its number on the level, and when "lit"
    ' changes the copy in the level's list is changed too, because drawing the square reads it from there
    Dim lub_visible As UByte = false

    If gub_monster_distance <= UB_MON_MAX_SIGHT And gsw_player_blind < 1 Then
        If fub_cr_inside_panel( gub_monster_row , gub_monster_col ) Then
            If gub_game_wizard Then
                ' wizard sight
                lub_visible = true
            ElseIf fub_mon_los( gub_player_row , gub_player_col , gub_monster_row , gub_monster_col ) Then
                lub_visible = fub_mon_is_visible( guw_monster_creature , gub_monster_row , gub_monster_col , gub_monster_distance )
            End If
        End If
    End If

    If lub_visible Then
        If gub_monster_lit = 0 Then
            ' this stops the player resting or searching, Moria's playerDisturb()
            s_mon_disturb()
            gub_monster_lit = 1
            Poke fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster ) + UB_MONSTER_LIT_OFFSET , 1
            s_cr_put( gub_monster_row , gub_monster_col )
        End If
    ElseIf gub_monster_lit <> 0 Then
        gub_monster_lit = 0
        Poke fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster ) + UB_MONSTER_LIT_OFFSET , 0
        s_cr_put( gub_monster_row , gub_monster_col )
    End If
End Sub



Sub s_mon_update()
    ' Moria's updateMonsters( false ): every monster, from the newest to the oldest, none of them moves
    Dim lub_monster As UByte

    lub_monster = gub_dungeon_monster_next
    While lub_monster > UB_MON_MIN_INDEX
        lub_monster = lub_monster - 1
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
        gub_monster_distance = fub_mon_distance( gub_player_row , gub_player_col , gub_monster_row , gub_monster_col )
        s_mon_update_visibility( lub_monster )
        s_core_store_record( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_monster , A_MONSTER )
    End While
End Sub

Sub s_lib_monsters()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte
    Dim lub_y , lub_x                       As UByte
    Dim luw_creature                        As UInteger

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the creatures database is read through the items' slot, so that slot is put back as it was found too
    lub_saved_page_1 = gub_core_MMU1_page_number
    If gub_lib_function = UB_LIB_MONSTERS_PLACE_ASLEEP Then
        s_mon_place_within( guw_lib_param_2 , gub_lib_param_1 , true )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_PLACE_AWAKE Then
        s_mon_place_within( guw_lib_param_2 , gub_lib_param_1 , false )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_PLACE_WINNING Then
        s_mon_place_winning()
    ElseIf gub_lib_function = UB_LIB_MONSTERS_UPDATE Then
        s_mon_update()
    ElseIf gub_lib_function = UB_LIB_MONSTERS_VISIBILITY Then
        s_mon_update_visibility( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_MULTIPLY Then
        gsw_lib_result = fub_mon_multiply( gub_lib_param_1 )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_CLONE Then
        ' a spell's doing: the monster and its creature are fetched, and it breeds at once
        s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , gub_lib_param_1 , A_MONSTER )
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , guw_monster_creature , A_CREATURE )
        gsw_lib_result = fub_mon_multiply_now( 0 )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_POLYMORPH_AT Then
        ' a creature of any kind at all, but for the town's, on the square given, awake
        lub_y = gub_lib_param_1
        lub_x = guw_lib_param_2
        luw_creature = fuw_mon_levels( 0 )
        luw_creature = fuw_mon_random( fuw_mon_levels( UB_MON_MAX_LEVELS ) - luw_creature ) - 1 + luw_creature
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , luw_creature , A_CREATURE )
        gsw_lib_result = fub_mon_place_new( lub_y , lub_x , luw_creature , false )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_SUMMON Then
        ' Moria's monsterSummon(): something from a little deeper than here (MON_SUMMONED_LEVEL_ADJUST), awake
        gsw_lib_result = fub_mon_place_adjacent( gub_player_row , gub_player_col , fuw_mon_suitable( guw_dungeon_level + 2 ) , false )
    ElseIf gub_lib_function = UB_LIB_MONSTERS_SUMMON_AT Then
        ' the same beside any square, and asleep, for the level maker's guarded rooms
        lub_y = gub_lib_param_1
        lub_x = guw_lib_param_2
        If ( guw_lib_param_2 >> 8 ) <> 0 Then
            ' awake, for a chest's summoning runes
            gsw_lib_result = fub_mon_place_adjacent( lub_y , lub_x , fuw_mon_suitable( guw_dungeon_level + 2 ) , false )
        Else
            gsw_lib_result = fub_mon_place_adjacent( lub_y , lub_x , fuw_mon_suitable( guw_dungeon_level + 2 ) , true )
        End If
    ElseIf gub_lib_function = UB_LIB_MONSTERS_SUMMON_UNDEAD Then
        gsw_lib_result = fub_mon_summon_undead()
    ElseIf gub_lib_function = UB_LIB_MONSTERS_LOS Then
        gsw_lib_result = fub_mon_los( guw_lib_param_2 >> 8 , guw_lib_param_2 bAnd 255 , Cast( UInteger , gsw_lib_result ) >> 8 , Cast( UInteger , gsw_lib_result ) bAnd 255 )
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
