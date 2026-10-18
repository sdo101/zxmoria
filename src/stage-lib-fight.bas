#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_fight()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-map-include.bas"
#include "stage-disturb-include.bas"
#include "stage-combat-include.bas"
#include "stage-fight-include.bas"

' this page is a LIBRARY, not a stage: bashing, and spiking doors shut, Moria's player_bash.cpp and the
' dungeonJamDoor() of its game_run.cpp, throwing is a page of its own, stage-lib-throw.bas...
' ...the commands library reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_FIGHT , <which routine> ),
' the routines are:
'
'   UB_LIB_FIGHT_BASH       the player throws their weight at whatever is in a direction: a monster, which may be
'                           stunned, or a door, which may burst open, Moria's playerBash()
'   UB_LIB_FIGHT_SPIKE      a spike from the pack is driven into a closed door, making it harder to open, Moria's
'                           dungeonJamDoor()
'
' each sets gub_game_free_turn if it took no time, and asks the walking stage, through gub_game_step_direction, to
' step the player forward when a door has been burst open
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - nothing that is known of here about the monster memory
'
' N.B: the order things are done in matters, each random number must be asked for exactly when Moria asks for it


'##################################################################################################################################
' --- bashing ---

Sub s_ft_off_balance( ps_message As String )
    ' the end of a bash: the clumsy may lose their footing, and a turn or two with it
    If Cast( Integer , fuw_cb_random( 150 ) ) > Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) Then
        s_msg( ps_message )
        gsw_player_paralysis = 1 + fuw_cb_random( 2 )
    End If
End Sub


Sub s_ft_bash_monster( pub_monster As UByte )
    ' Moria's playerBashPosition() and playerBashAttack(): the player's weight and their shield against the
    ' monster, a good bash stuns it
    Dim luw_record , luw_shield             As UInteger
    Dim lub_lit                             As UByte
    Dim lsw_base , lsw_damage , lsw_average As Integer
    Dim lsw_stunned , lsw_hp                As Integer
    Dim ls_name                             As String

    If gsw_player_afraid > 0 Then
        s_core_message( UW_MSG_YOU_ARE_AFRAID )
        Return
    End If
    luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
    Poke UInteger luw_record + UB_MONSTER_SLEEP_OFFSET , 0
    lub_lit = Peek( luw_record + UB_MONSTER_LIT_OFFSET )
    s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , luw_record + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
    ' does the player know what they're fighting?
    If lub_lit = 0 Then
        ls_name = "it"
    Else
        ls_name = "the " + fs_core_text_at( A_CREATURE )
    End If

    luw_shield = A_EQUIPMENT + Cast( UInteger , UB_EQUIP_ARM ) * UB_RECORD_SIZE
    lsw_base = Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) + Peek( Integer , luw_shield + UB_ITEM_WEIGHT_OFFSET ) / 2 + Cast( Integer , guw_player_weight ) / 10
    If lub_lit = 0 Then
        lsw_base = lsw_base / 2 - Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) ) * 2 - Cast( Integer , guw_player_level ) * Cast( Integer , gub_class_adj_bth ) / 2
    End If

    If fub_cb_test_hit( lsw_base , Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) , gub_creature_ac , gub_class_adj_bth ) Then
        s_msg( "You hit " + ls_name + "." )
        lsw_damage = fuw_core_dice_roll( Peek( luw_shield + UB_ITEM_DAMAGE_OFFSET ) , Peek( luw_shield + UB_ITEM_DAMAGE_OFFSET + 1 ) )
        lsw_damage = fsw_cb_critical( Peek( Integer , luw_shield + UB_ITEM_WEIGHT_OFFSET ) / 4 + Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) , 0 , lsw_damage , gub_class_adj_bth )
        lsw_damage = lsw_damage + Cast( Integer , guw_player_weight ) / 60 + 3
        If lsw_damage < 0 Then lsw_damage = 0

        ' see if we done it in
        If fub_ft_call( UB_PAGED_CODE_LIB_PLAYER_ATTACK , UB_LIB_PLAYER_ATTACK_TAKE_HIT , pub_monster , Cast( UInteger , lsw_damage ) ) Then
            s_msg( "You have slain " + ls_name + "." )
            s_core_call_library( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_DISPLAY_EXP )
        Else
            ' can not stun the Balrog
            If ( guw_creature_defenses bAnd UW_CD_MAX_HP ) <> 0 Then
                lsw_average = Cast( Integer , gub_creature_hit_dice ) * Cast( Integer , gub_creature_hit_sides )
            Else
                lsw_average = ( Cast( Integer , gub_creature_hit_dice ) * ( Cast( Integer , gub_creature_hit_sides ) + 1 ) ) >> 1
            End If
            luw_record = fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster )
            lsw_hp     = Peek( Integer , luw_record )
            ' capitalize: "The Kobold", "It"
            ls_name = fs_core_char( Code( ls_name( 0 ) ) - 32 ) + ls_name( 1 To Len( ls_name ) - 1 )
            If 100 + Cast( Integer , fuw_cb_random( 400 ) ) + Cast( Integer , fuw_cb_random( 400 ) ) > lsw_hp + lsw_average Then
                lsw_stunned = Cast( Integer , Peek( luw_record + UB_MONSTER_STUNNED_OFFSET ) ) + Cast( Integer , fuw_cb_random( 3 ) ) + 1
                If lsw_stunned > 24 Then lsw_stunned = 24
                Poke fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , pub_monster ) + UB_MONSTER_STUNNED_OFFSET , lsw_stunned
                s_msg( ls_name + " appears stunned!" )
            Else
                s_msg( ls_name + " ignores your bash!" )
            End If
        End If
    Else
        s_msg( "You miss " + ls_name + "." )
    End If
    s_ft_off_balance( "You are off balance." )
End Sub


Sub s_ft_bash_door( pub_direction As UByte , pub_item As UByte )
    ' Moria's playerBashClosedDoor(): the heavier and stronger the player, and the less firmly the door is shut,
    ' the better the chance
    Dim luw_record                  As UInteger
    Dim lsw_chance , lsw_holds      As Integer
    Dim i                           As UByte

    s_msg_quiet( "You smash into the door!" )
    luw_record = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item )
    lsw_holds  = Abs( Peek( Integer , luw_record + UB_ITEM_MISC_USE_OFFSET ) )
    lsw_chance = Cast( Integer , Peek( A_PLAYER_STATS_USED + UB_STAT_STR ) ) + Cast( Integer , guw_player_weight ) / 2

    ' use (roughly) similar method as for monsters
    If Cast( Long , ful_core_random_number( Cast( Long , lsw_chance ) * ( 20 + lsw_holds ) ) ) < 10 * ( Cast( Long , lsw_chance ) - lsw_holds ) Then
        s_core_message( UW_MSG_THE_DOOR_CRASHES_OPEN )
        ' it becomes an open door, Moria's inventoryItemCopyTo(), 50% chance of breaking it
        s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , UW_OBJ_OPEN_DOOR , A_OBJECT )
        For i = 0 To 31
            Poke A_ITEM + i , 0
        Next
        s_core_ram_copy( A_OBJECT + 32 , A_ITEM + 32 , 32 )
        guw_item_object   = UW_OBJ_OPEN_DOOR
        gsw_item_misc_use = 1 - Cast( Integer , fuw_cb_random( 2 ) )
        s_core_store_record( UB_SLOT_ITEMS , gub_level_items_page , pub_item , A_ITEM )
        Poke fuw_cr_square( gub_ft_y , gub_ft_x ) + UB_SQUARE_FEATURE , UB_TILE_CORR_FLOOR
        If gsw_player_confused = 0 Then
            ' the player goes through with it, the walking stage does the step
            gub_game_step_direction = pub_direction
            gub_game_step_code      = 2
        End If
        s_cr_put( gub_ft_y , gub_ft_x )
        Return
    End If
    If Cast( Integer , fuw_cb_random( 150 ) ) > Peek( A_PLAYER_STATS_USED + UB_STAT_DEX ) Then
        s_core_message( UW_MSG_YOU_ARE_OFF_BALANCE )
        gsw_player_paralysis = 1 + fuw_cb_random( 2 )
        Return
    End If
    ' N.B: not said while the bashing is being repeated
    If guw_game_command_count = 0 Then s_core_message( UW_MSG_THE_DOOR_HOLDS_FIRM )
End Sub


Sub s_ft_bash()
    ' Moria's playerBash()
    Dim lub_direction , lub_item , lub_category As UByte
    Dim luw_square                              As UInteger

    lub_direction = fub_ft_direction()
    ' N.B: backing out takes no time, fub_ft_direction() sees to that, as in Moria
    If lub_direction = 0 Then Return
    lub_direction = fub_ft_confused_direction( lub_direction )
    gub_ft_y = gub_player_row
    gub_ft_x = gub_player_col
    s_ft_step( lub_direction )

    luw_square = fuw_cr_square( gub_ft_y , gub_ft_x )
    If Peek( luw_square + UB_SQUARE_MONSTER ) > 1 Then
        s_ft_bash_monster( Peek( luw_square + UB_SQUARE_MONSTER ) )
        Return
    End If
    lub_item = Peek( luw_square + UB_SQUARE_ITEM )
    If lub_item <> 0 Then
        lub_category = fub_cr_item_category( lub_item )
        If lub_category = UB_TV_CLOSED_DOOR Then
            s_ft_bash_door( lub_direction , lub_item )
        ElseIf lub_category = UB_TV_CHEST Then
            ' a chest may be broken open, or ruined, the chests library
            gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_CHESTS , UB_LIB_CHESTS_BASH , gub_ft_y , gub_ft_x )
        Else
            ' Can't give free turn, or else player could try directions until they find the invisible creature
            s_core_message( UW_MSG_YOU_BASH_IT_BUT_NOTHING )
        End If
        Return
    End If
    If Peek( fuw_cr_square( gub_ft_y , gub_ft_x ) + UB_SQUARE_FEATURE ) < UB_TILE_MIN_WALL Then
        s_core_message( UW_MSG_YOU_BASH_AT_EMPTY_SPACE )
        Return
    End If
    ' same message for wall as for secret door
    s_core_message( UW_MSG_YOU_BASH_IT_BUT_NOTHING )
End Sub


'##################################################################################################################################
' --- spiking a door ---

Sub s_ft_spike()
    ' Moria's dungeonJamDoor(): each spike makes the door harder to open, the first by most
    Dim lub_direction , lub_item , lub_category     As UByte
    Dim luw_square , luw_record                     As UInteger
    Dim lsw_i , lsw_spikes , lsw_holds              As Integer

    gub_game_free_turn = true
    lub_direction = fub_ft_direction()
    If lub_direction = 0 Then Return
    gub_ft_y = gub_player_row
    gub_ft_x = gub_player_col
    s_ft_step( lub_direction )

    luw_square = fuw_cr_square( gub_ft_y , gub_ft_x )
    lub_item   = Peek( luw_square + UB_SQUARE_ITEM )
    lub_category = 0
    If lub_item <> 0 Then lub_category = fub_cr_item_category( lub_item )
    If lub_category <> UB_TV_CLOSED_DOOR And lub_category <> UB_TV_OPEN_DOOR Then
        s_core_message( UW_MSG_THAT_ISNT_A_DOOR )
        Return
    End If
    If lub_category = UB_TV_OPEN_DOOR Then
        s_core_message( UW_MSG_THE_DOOR_MUST_BE_CLOSED_FIRST )
        Return
    End If

    ' N.B: Moria's test is for nobody at all on the square, so the name is asked for even of the player
    lub_category = Peek( fuw_cr_square( gub_ft_y , gub_ft_x ) + UB_SQUARE_MONSTER )
    If lub_category > 1 Then
        gub_game_free_turn = false
        s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , Peek( UInteger , fuw_core_record_address( UB_SLOT_MONSTERS , gub_level_monsters_page , lub_category ) + UB_MONSTER_CREATURE_OFFSET ) , A_CREATURE )
        s_msg( "The " + fs_core_text_at( A_CREATURE ) + " is in your way!" )
        Return
    End If

    ' the spikes in the pack, Moria's inventoryFindRange()
    lsw_spikes = -1
    lsw_i = 0
    While lsw_i < gsw_player_pack_unique And lsw_spikes < 0
        If Peek( A_INVENTORY + Cast( UInteger , lsw_i ) * UB_RECORD_SIZE + UB_ITEM_CATEGORY_OFFSET ) = UB_TV_SPIKE Then lsw_spikes = lsw_i
        lsw_i = lsw_i + 1
    End While
    If lsw_spikes < 0 Then
        s_core_message( UW_MSG_BUT_YOU_HAVE_NO_SPIKES )
        Return
    End If

    gub_game_free_turn = false
    s_msg_quiet( "You jam the door with a spike." )
    luw_record = fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , lub_item ) + UB_ITEM_MISC_USE_OFFSET
    lsw_holds  = Peek( Integer , luw_record )
    If lsw_holds > 0 Then lsw_holds = -lsw_holds                ' make locked to stuck
    ' successive spikes have progressively smaller effect: series is 0 20 30 37 43 48 52 56 60 64 67 70 ...
    lsw_holds = lsw_holds - ( 1 + 190 / ( 10 - lsw_holds ) )
    Poke UInteger luw_record , Cast( UInteger , lsw_holds )

    luw_record = A_INVENTORY + Cast( UInteger , lsw_spikes ) * UB_RECORD_SIZE
    If Peek( luw_record + UB_ITEM_COUNT_OFFSET ) > 1 Then
        Poke luw_record + UB_ITEM_COUNT_OFFSET , Peek( luw_record + UB_ITEM_COUNT_OFFSET ) - 1
        gsw_player_pack_weight = gsw_player_pack_weight - Peek( Integer , luw_record + UB_ITEM_WEIGHT_OFFSET )
    Else
        gub_shared_1 = fub_ft_call( UB_PAGED_CODE_LIB_INVENTORY , UB_LIB_INV_DESTROY , 0 , lsw_spikes )
    End If
End Sub


Sub s_lib_fight()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_FIGHT_BASH Then
        s_ft_bash()
    ElseIf gub_lib_function = UB_LIB_FIGHT_SPIKE Then
        s_ft_spike()
    End If
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
