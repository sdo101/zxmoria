'##################################################################################################################################
' --- STRUCTURED DATA TYPES ---

' shared scratch variables...
' (A_API + 0 to A_API + 13 used to hold the addresses of the core routines, the jump table at $0040 replaces them)
Dim gub_shared_1                           As UByte    At A_API + 14
Dim gub_shared_2                            As UByte    At A_API + 15
Dim gub_shared_3                            As UByte    At A_API + 16
Dim gub_shared_4                            As UByte    At A_API + 17
Dim guw_shared_1                            As UInteger At A_API + 18
Dim guw_shared_2                            As UInteger At A_API + 20
Dim guw_shared_3                            As UInteger At A_API + 22
Dim guw_shared_4                            As UInteger At A_API + 24

' core data...
' which page is in each paged slot at the moment, and how often asking for a page found it already there (a hit) or had to change it (a swap)...
' ...MMU 3 is the paged code slot, MMU 0, 1 and 2 are the three paged data slots...

Dim gub_core_MMU3_page_number    As UByte    At A_CORE
Dim gul_core_MMU3_cache_hits     As ULong    At A_CORE + 1
Dim gul_core_MMU3_page_swaps     As ULong    At A_CORE + 5

Dim gub_core_MMU0_page_number    As UByte    At A_CORE + 9
Dim gul_core_MMU0_cache_hits     As ULong    At A_CORE + 10
Dim gul_core_MMU0_page_swaps     As ULong    At A_CORE + 14

Dim gub_core_MMU1_page_number    As UByte    At A_CORE + 18
Dim gul_core_MMU1_cache_hits     As ULong    At A_CORE + 19
Dim gul_core_MMU1_page_swaps     As ULong    At A_CORE + 23

Dim gub_core_MMU2_page_number    As UByte    At A_CORE + 27
Dim gul_core_MMU2_cache_hits     As ULong    At A_CORE + 28
Dim gul_core_MMU2_page_swaps     As ULong    At A_CORE + 32

' N.B: this used to be at A_CORE + 34, which is inside the four bytes of the swap counter just above it (A_CORE + 32 to 35)
Dim gub_core_stage               As UByte    At A_CORE + 36
Dim gub_core_to_be_wizard        As UByte    At A_CORE + 37  ' true if the game was started as a wizard, Ctrl-W on the opening screen, Moria's -w, see stage-splash.bas
Dim gub_core_end                 As UByte    At A_CORE + 43  ' flag for end
Dim gub_core_monitor             As UByte    At A_CORE + 44  ' UB_MONITOR_OFF, UB_MONITOR_MEMORY or UB_MONITOR_MISSES, the } key changes it, see s_core_get_key()
Dim guw_core_stack_pos           As UInteger At A_CORE + 45  ' last known stack position
Dim guw_core_heap_top            As UInteger At A_CORE + 47  ' last known top of heap
' the library: which of a library page's routines is wanted, and what is passed to it, see s_core_call_library() in core.bas
Dim gub_lib_function             As UByte    At A_CORE + 53
Dim gub_lib_param_1              As UByte    At A_CORE + 54
Dim guw_lib_param_2              As UInteger At A_CORE + 55
Dim gsw_lib_result               As Integer  At A_CORE + 57  ' a library routine's answer, when it has one
Dim gsl_lib_long_1               As Long     At A_CORE + 59  ' ...and up to three big answers, prices for instance
Dim gsl_lib_long_2               As Long     At A_CORE + 63
Dim gsl_lib_long_3               As Long     At A_CORE + 67

' the message line, the top row of the screen: how long the message showing there is, 0 for none, see stage-message-include.bas
Dim gub_message_length           As UByte    At A_CORE + 71
' which store the player is in, or is going into, 0 to 5
Dim gub_core_store               As UByte    At A_CORE + 72
' what a stage is asking the core to do next, one of the UB_REQUEST_ values in constants.bas
Dim gub_core_request             As UByte    At A_CORE + 73
Dim gub_core_monitor_page        As UByte    At A_CORE + 75  ' the page of code that was running when the live monitor was last drawn, it is itself a page of code
' what the third data slot's page changes were for, seven ULongs, one for each kind of page that was asked for and
' was not there: 0 a map, 1 the creatures, 2 the objects, 3 the tables, 4 the strings, 5 what the player knows (the
' monster memory), 6 anything else, the live monitor shows them, see s_core_swap_paged_data() in core.bas
#define A_CORE_MMU2_KINDS       A_CORE + 76     ' size 28, seven counts of four bytes
' N.B: these two used to be at A_CORE + 76 and 77, which are the first of the 28 bytes of counts just above (A_CORE + 76 to 103),
' so a count going up between two pages of a file changed the handle, and a text file stopped after its first 8KB
Dim gub_core_file_handle         As UByte    At A_CORE + 104 ' the file that fub_core_file_transfer() has open, N.B: between calls too, while a file of many pages is being written
Dim gub_core_file_plan           As UByte    At A_CORE + 105 ' which steps the call under way takes, see fub_core_file_transfer()
Dim gub_core_file_slot           As UByte    At A_CORE + 74  ' which 8KB of a file the next page saved or loaded is, 255 for a file that is one page and no more, see fub_core_file_transfer()
Dim gul_core_entropy             As ULong    At A_CORE + 49  ' a number stirred by how long the player takes over every key press, it seeds the random numbers

' keyboard...
Dim gub_key_char            As UByte    At A_KEY        ' a, A
Dim guw_key_code            As UInteger At A_KEY + 1    ' ASCII code or special numbers
Dim gub_key_modifiers       As UByte    At A_KEY + 3    ' a bitmask of MB_KEY_CTRL, MB_KEY_SHIFT (caps shift) and MB_KEY_SYMBOL (symbol shift)
Dim gs_key_astext           As String   At A_KEY + 4    ' the key as text, e.g. a, Shift-A, Ctrl-A, #, Enter, Left, Backspace

' the game as a whole...
' ...the random number seeds, these are Moria's own: the generator's current value, the value put aside while a fixed seed is in use,
' and the two fixed seeds, which make the town layout and the flavours of the magic items come out the same every time in one game
Dim gul_game_random_seed    As ULong    At A_GAME
Dim gul_game_old_seed       As ULong    At A_GAME + 4
Dim gul_game_magic_seed     As ULong    At A_GAME + 8
Dim gul_game_town_seed      As ULong    At A_GAME + 12

' the level the player is on...
Dim guw_dungeon_level       As UInteger At A_GAME + 16      ' how deep, 0 is the town, 1 is 50 feet (Moria's current_level)
Dim gub_dungeon_rows        As UByte    At A_GAME + 18      ' how much of the map this level uses, 66 by 198 for a dungeon level
Dim gub_dungeon_cols        As UByte    At A_GAME + 19
Dim gub_dungeon_item_next   As UByte    At A_GAME + 20      ' the number the next item made on this level will get, they start at 1
' ...which pages hold the level the player is on: the dungeon and the town each have their own map, items and monsters,
' and everything that works on "the level" goes through these, so that the same code serves both
Dim gub_level_map_page      As UByte    At A_GAME + 21      ' UB_PAGE_DUNGEON_MAP or UB_PAGE_TOWN_MAP
Dim gub_level_items_page    As UByte    At A_GAME + 22      ' UB_PAGE_DUNGEON_ITEMS or UB_PAGE_TOWN_ITEMS
Dim gub_level_monsters_page As UByte    At A_GAME + 23      ' UB_PAGE_DUNGEON_MONSTERS or UB_PAGE_TOWN_MONSTERS
Dim gsw_game_missile_counter As Integer At A_GAME + 28      ' every batch of arrows, bolts and shots gets the next number, so that only like stacks with like (missiles_counter)
Dim gsl_game_turn           As Long     At A_GAME + 24      ' how many turns the game has run, it also decides whether it is day or night in the town
' working storage for the random number routines in core.bas, which are in assembler and so cannot have local variables...
Dim gul_game_rnd_work_lo    As ULong    At A_GAME + 32      ' the 48 bit result of 16807 * the seed, the low four bytes...
Dim guw_game_rnd_work_hi    As UInteger At A_GAME + 36      ' ...and the high two
Dim guw_game_rnd_max        As UInteger At A_GAME + 38      ' the range asked for
Dim guw_game_rnd_result     As UInteger At A_GAME + 40      ' the answer, before 1 is added to it
Dim gub_dungeon_monster_next As UByte   At A_GAME + 42      ' the number the next monster made on this level will get, they start at 2 (next_free_monster_id)
Dim gub_game_total_winner   As UByte    At A_GAME + 43      ' true once the player has won the game (total_winner)
Dim gub_game_free_turn      As UByte    At A_GAME + 44      ' true if what the player just did took no time, so the monsters do not move (player_free_turn)
Dim gub_game_character_dead As UByte    At A_GAME + 45      ' true once the player has died (character_is_dead)
Dim gub_game_turn_flags     As UByte    At A_GAME + 46      ' what the turn library asks of the walking stage, the MB_TURN_ bits
Dim gub_game_disturb        As UByte    At A_GAME + 47      ' not 0 when the player has been disturbed and the screen has yet to say so, the MB_DISTURB_ bits (playerDisturb)
Dim gub_game_step_direction As UByte    At A_GAME + 57      ' after disarming: the direction the player now steps in, 0 for none...
Dim gub_game_step_code      As UByte    At A_GAME + 58      ' ...and 1 if the trap was disarmed, 2 if it was set off, 3 for a plain step that picks nothing up
Dim gsw_game_multiply_total As Integer  At A_GAME + 59      ' how many monsters have bred on this level, there is a limit (monster_multiply_total)
Dim gub_game_running        As UByte    At A_GAME + 61      ' not 0 while the player is running, it counts the steps (running_tracker), see stage-lib-run.bas
Dim gub_game_run_direction  As UByte    At A_GAME + 62      ' the way the next step of a run goes (find_direction)
Dim gub_game_noticed        As UByte    At A_GAME + 63      ' true if the player noticed what a monster's attack did to them, which is how they come to remember it
' the message history, see s_core_print_char_at_logged() in core.bas
Dim gub_log_length          As UByte    At A_MMU_SLOT_CORE_DATA + 6992  ' how long the message that is showing is, 0 once it has gone into the history
Dim gub_log_next            As UByte    At A_MMU_SLOT_CORE_DATA + 6993  ' which of the 22 places the next message goes into
Dim gub_log_count           As UByte    At A_MMU_SLOT_CORE_DATA + 6994  ' how many messages are in the history, up to 22
Dim guw_game_run_limit      As UInteger At A_MMU_SLOT_CORE_DATA + 7000  ' N.B: two bytes, as Moria's find_count is an int, a count may be up to 999, how many more steps a run that was given a count may take, 0 for no limit (find_count)
' what marks a saved game, see stage-lib-save.bas, N.B: these are saved with the rest of the core's data, that is the point of them
Dim gub_save_letter_1       As UByte    At A_MMU_SLOT_CORE_DATA + 6995  ' "Z"...
Dim gub_save_letter_2       As UByte    At A_MMU_SLOT_CORE_DATA + 6996  ' ...and "M"
Dim gub_save_version        As UByte    At A_MMU_SLOT_CORE_DATA + 6997  ' which layout of save this is
Dim gub_save_alive          As UByte    At A_MMU_SLOT_CORE_DATA + 6998  ' false once the saved character has died
Dim gub_save_used           As UByte    At A_MMU_SLOT_CORE_DATA + 6999  ' true if this game has been saved, or came from a save
' N.B: A_GAME is full, the next sixteen bytes of the core's data, after the working map square, carry on from it
Dim gub_game_monster_turn   As UByte    At A_MMU_SLOT_CORE_DATA + 584   ' the number of the monster having its turn, the monsters' turn counts down through them (hack_monptr), see stage-lib-compact.bas
' N.B: + 585 to + 597 are a monster's move, see stage-monster-moves-include.bas
' N.B: + 598 was the repeat count, a byte, until 16 October 2026, see guw_game_command_count below
' how many more times the command being repeated is to be done, 0 for none (Moria's command_count, an unsigned int), any
' message ends it, the core sees to that, N.B: two bytes, a count may be up to 999: it was a byte at + 598 until 16 October
' 2026, and 255 was the most, found by comparing the wizard's + with a count of 300 with Umoria's
Dim guw_game_command_count  As UInteger At A_MMU_SLOT_CORE_DATA + 760
Dim gub_game_repeat_key     As UByte    At A_MMU_SLOT_CORE_DATA + 599   ' the key of that command, with 128 added once it has been done the first time, which is what says "use the last direction" (use_last_direction)
' --- the window on to the map, Moria's "panel", the map is cut into half windows and the window is always two of them ---
' N.B: these sit among the game's own variables in globals.bas, which use A_GAME + 0 to + 47 and + 57 on
Dim gsb_panel_row       As Byte     At A_GAME + 48      ' which half window down the map the window starts at, -1 before it is set
Dim gsb_panel_col       As Byte     At A_GAME + 49      ' ...and which half window across
Dim gub_panel_top       As UByte    At A_GAME + 50      ' the rows and columns of the map that are in the window...
Dim gub_panel_bottom    As UByte    At A_GAME + 51
Dim gub_panel_left      As UByte    At A_GAME + 52
Dim gub_panel_right     As UByte    At A_GAME + 53
Dim gsb_panel_max_rows  As Byte     At A_GAME + 54      ' the last half window the window may start at, down and across
Dim gsb_panel_max_cols  As Byte     At A_GAME + 55
Dim gub_map_colour      As UByte    At A_GAME + 30      ' ours: the colour of the last symbol fub_cr_symbol() gave, 0 for the usual one
Dim gub_map_is_monster  As UByte    At A_GAME + 56      ' true if the last symbol fub_cr_symbol() gave was a monster's
' the player, this is Moria's Player_t, everything about the character except what they carry...
' ...Moria's "misc" part
' N.B: A_PLAYER + 0 to + 26 is the name, 27 bytes of text ending in a 0
Dim gub_player_male             As UByte    At A_PLAYER + 27    ' 1 for male, 0 for female (gender)
Dim gsl_player_birth            As Long     At A_PLAYER + 28    ' when the character was made (date_of_birth)
Dim gsl_player_gold             As Long     At A_PLAYER + 32    ' (au)
Dim gsl_player_max_exp          As Long     At A_PLAYER + 36
Dim gsl_player_exp              As Long     At A_PLAYER + 40
Dim guw_player_exp_fraction     As UInteger At A_PLAYER + 44
Dim guw_player_age              As UInteger At A_PLAYER + 46
Dim guw_player_height           As UInteger At A_PLAYER + 48
Dim guw_player_weight           As UInteger At A_PLAYER + 50
Dim guw_player_level            As UInteger At A_PLAYER + 52
Dim guw_player_max_depth        As UInteger At A_PLAYER + 54    ' the deepest level explored (max_dungeon_depth)
Dim gsw_player_search           As Integer  At A_PLAYER + 56    ' chance in search
Dim gsw_player_fos              As Integer  At A_PLAYER + 58    ' frequency of search
Dim gsw_player_bth              As Integer  At A_PLAYER + 60    ' base to hit
Dim gsw_player_bth_bows         As Integer  At A_PLAYER + 62    ' base to hit with bows
Dim gsw_player_mana             As Integer  At A_PLAYER + 64
Dim gsw_player_max_hp           As Integer  At A_PLAYER + 66
Dim gsw_player_to_hit           As Integer  At A_PLAYER + 68    ' (plusses_to_hit)
Dim gsw_player_to_damage        As Integer  At A_PLAYER + 70    ' (plusses_to_damage)
Dim gsw_player_ac               As Integer  At A_PLAYER + 72    ' total armour class
Dim gsw_player_magical_ac       As Integer  At A_PLAYER + 74
Dim gsw_player_display_to_hit   As Integer  At A_PLAYER + 76    ' the four values as the player is shown them...
Dim gsw_player_display_to_dam   As Integer  At A_PLAYER + 78
Dim gsw_player_display_ac       As Integer  At A_PLAYER + 80
Dim gsw_player_display_to_ac    As Integer  At A_PLAYER + 82
Dim gsw_player_disarm           As Integer  At A_PLAYER + 84    ' % to disarm
Dim gsw_player_saving_throw     As Integer  At A_PLAYER + 86
Dim gsw_player_social_class     As Integer  At A_PLAYER + 88
Dim gsw_player_stealth          As Integer  At A_PLAYER + 90
Dim gub_player_class            As UByte    At A_PLAYER + 92    ' 0 warrior, 1 mage, 2 priest, 3 rogue, 4 ranger, 5 paladin
Dim gub_player_race             As UByte    At A_PLAYER + 93    ' 0 human, 1 half-elf, 2 elf, 3 halfling, 4 gnome, 5 dwarf, 6 half-orc, 7 half-troll
Dim gub_player_hit_die          As UByte    At A_PLAYER + 94
Dim gub_player_exp_factor       As UByte    At A_PLAYER + 95
Dim gsw_player_current_mana     As Integer  At A_PLAYER + 96
Dim guw_player_mana_fraction    As UInteger At A_PLAYER + 98
Dim gsw_player_current_hp       As Integer  At A_PLAYER + 100
Dim guw_player_hp_fraction      As UInteger At A_PLAYER + 102
#define A_PLAYER_NAME           A_PLAYER            ' size 27, UB_PLAYER_NAME_SIZE
#define A_PLAYER_HISTORY        A_PLAYER + 104      ' size 240, the character's background, 4 lines of 60 bytes, each ending in a 0 unless it is full
Const   UB_PLAYER_NAME_SIZE     As UByte    = 27

' ...Moria's "stats" part, each is six values in the order STR, INT, WIS, DEX, CON, CHR
#define A_PLAYER_STATS_MAX      A_PLAYER + 344      ' 6 bytes, what each stat is restored to
#define A_PLAYER_STATS_CURRENT  A_PLAYER + 350      ' 6 bytes, what each stat naturally is at the moment
#define A_PLAYER_STATS_MODIFIED A_PLAYER + 356      ' 12 bytes, 6 signed 2 byte values, what equipment adds or takes away
#define A_PLAYER_STATS_USED     A_PLAYER + 368      ' 6 bytes, what each stat works out to, this is the one the game uses

' ...Moria's "flags" part, the counters run down by one each turn
Dim gul_player_status           As ULong    At A_PLAYER + 374   ' bit field
Dim gsw_player_rest             As Integer  At A_PLAYER + 378
Dim gsw_player_blind            As Integer  At A_PLAYER + 380
Dim gsw_player_paralysis        As Integer  At A_PLAYER + 382
Dim gsw_player_confused         As Integer  At A_PLAYER + 384
Dim gsw_player_food             As Integer  At A_PLAYER + 386
Dim gsw_player_food_digested    As Integer  At A_PLAYER + 388   ' food used per round
Dim gsw_player_protection       As Integer  At A_PLAYER + 390
Dim gsw_player_speed            As Integer  At A_PLAYER + 392
Dim gsw_player_fast             As Integer  At A_PLAYER + 394
Dim gsw_player_slow             As Integer  At A_PLAYER + 396
Dim gsw_player_afraid           As Integer  At A_PLAYER + 398
Dim gsw_player_poisoned         As Integer  At A_PLAYER + 400
Dim gsw_player_image            As Integer  At A_PLAYER + 402   ' hallucinating
Dim gsw_player_protect_evil     As Integer  At A_PLAYER + 404
Dim gsw_player_invulnerability  As Integer  At A_PLAYER + 406
Dim gsw_player_heroism          As Integer  At A_PLAYER + 408
Dim gsw_player_super_heroism    As Integer  At A_PLAYER + 410
Dim gsw_player_blessed          As Integer  At A_PLAYER + 412
Dim gsw_player_heat_resistance  As Integer  At A_PLAYER + 414
Dim gsw_player_cold_resistance  As Integer  At A_PLAYER + 416
Dim gsw_player_detect_invisible As Integer  At A_PLAYER + 418
Dim gsw_player_word_of_recall   As Integer  At A_PLAYER + 420
Dim gsw_player_see_infra        As Integer  At A_PLAYER + 422   ' how far warm creatures can be seen in the dark
Dim gsw_player_timed_infra      As Integer  At A_PLAYER + 424
' ...the yes or no ones
Dim gub_player_see_invisible    As UByte    At A_PLAYER + 426
Dim gub_player_teleport         As UByte    At A_PLAYER + 427   ' random teleportation
Dim gub_player_free_action      As UByte    At A_PLAYER + 428   ' never paralysed
Dim gub_player_slow_digest      As UByte    At A_PLAYER + 429
Dim gub_player_aggravate        As UByte    At A_PLAYER + 430
Dim gub_player_resist_fire      As UByte    At A_PLAYER + 431
Dim gub_player_resist_cold      As UByte    At A_PLAYER + 432
Dim gub_player_resist_acid      As UByte    At A_PLAYER + 433
Dim gub_player_regenerate_hp    As UByte    At A_PLAYER + 434
Dim gub_player_resist_light     As UByte    At A_PLAYER + 435
Dim gub_player_free_fall        As UByte    At A_PLAYER + 436
#define A_PLAYER_SUSTAIN        A_PLAYER + 437      ' size 6, the six sustain flags, strength first, in the order of the stats
Dim gub_player_sustain_str      As UByte    At A_PLAYER_SUSTAIN
Dim gub_player_sustain_int      As UByte    At A_PLAYER + 438
Dim gub_player_sustain_wis      As UByte    At A_PLAYER + 439
Dim gub_player_sustain_con      As UByte    At A_PLAYER + 440
Dim gub_player_sustain_dex      As UByte    At A_PLAYER + 441
Dim gub_player_sustain_chr      As UByte    At A_PLAYER + 442
Dim gub_player_confuse_monster  As UByte    At A_PLAYER + 443   ' glowing hands
' ...the spells
Dim gub_player_new_spells       As UByte    At A_PLAYER + 444   ' how many spells can be learnt (new_spells_to_learn)
Dim gul_player_spells_learnt    As ULong    At A_PLAYER + 445   ' one bit per spell
Dim gul_player_spells_worked    As ULong    At A_PLAYER + 449   ' tried and worked
Dim gul_player_spells_forgotten As ULong    At A_PLAYER + 453
#define A_PLAYER_SPELL_ORDER    A_PLAYER + 457      ' 32 bytes, the order the spells were learnt in
#define UB_SPELL_ORDER_SIZE     32                  ' Moria's spells_learned_order[32]
#define UB_SPELL_ORDER_END      99                  ' marks the first free place in that order, as Moria's 99 does

' ...the rest of Moria's Player_t
Dim gub_player_row              As UByte    At A_PLAYER + 489   ' where the player is on the map (pos)
Dim gub_player_col              As UByte    At A_PLAYER + 490
Dim gub_player_prev_dir         As UByte    At A_PLAYER + 491   ' direction memory
Dim gub_player_running          As UByte    At A_PLAYER + 492   ' turns taken during one run (running_tracker)
Dim gub_player_temp_light_only  As UByte    At A_PLAYER + 493
Dim gsl_player_max_score        As Long     At A_PLAYER + 494
Dim gsw_player_pack_unique      As Integer  At A_PLAYER + 498   ' different items in the pack (unique_items)
Dim gsw_player_pack_weight      As Integer  At A_PLAYER + 500
Dim gsw_player_pack_heaviness   As Integer  At A_PLAYER + 502
Dim gsw_player_equipment_count  As Integer  At A_PLAYER + 504
Dim gub_player_weapon_heavy     As UByte    At A_PLAYER + 506
Dim gub_player_carrying_light   As UByte    At A_PLAYER + 507
#define A_PLAYER_HP_LEVELS      A_PLAYER + 508      ' 80 bytes, 40 values of 2 bytes, the hit points the character has at each level, rolled when it is made
Dim gub_game_wizard             As UByte    At A_PLAYER + 588   ' true while wizard mode is on (wizard_mode), N.B: it is here to be wiped with the character, it does not belong to them
Dim gub_game_noscore            As UByte    At A_PLAYER + 589   ' not 0 if this game cannot be scored, bit 1 is set once wizard mode has been used (noscore)
Dim guw_game_options            As UInteger At A_PLAYER + 590   ' the player's options, the MW_OPTION_ bits in constants.bas, = sets them, N.B: here so that they are saved with the game
Dim gub_minimap_mode            As UByte    At A_PLAYER + 593   ' ours: the mini map, 0 off, 1 one square to a pixel, 2 two by two squares to a pixel, see stage-lib-minimap.bas
Dim gub_minimap_rebuild         As UByte    At A_PLAYER + 594   ' ours: true when the mini map's bitmap must be made again from the map before it is next drawn
Dim gub_game_rest_broken        As UByte    At A_PLAYER + 592   ' true when a monster's turn has ended a rest and the screen has yet to be told, see s_mon_disturb() in stage-disturb-include.bas
#define UW_PLAYER_USED          595                 ' how much of the UW_PLAYER_SIZE bytes is used so far

' the player's race and class, 64 byte records from the character database, kept in the core data once chosen...
' ...the layouts are set by create-data.ps1, the names are 16 bytes of text ending in a 0 at A_RACE and A_CLASS themselves
' N.B: A_RACE + 16 to + 21 are the six stat adjustments, signed bytes, in the usual order
Dim gub_race_base_age           As UByte    At A_RACE + 22
Dim gub_race_max_age            As UByte    At A_RACE + 23
Dim gub_race_male_height        As UByte    At A_RACE + 24
Dim gub_race_male_height_mod    As UByte    At A_RACE + 25
Dim gub_race_male_weight        As UByte    At A_RACE + 26
Dim gub_race_male_weight_mod    As UByte    At A_RACE + 27
Dim gub_race_female_height      As UByte    At A_RACE + 28
Dim gub_race_female_height_mod  As UByte    At A_RACE + 29
Dim gub_race_female_weight      As UByte    At A_RACE + 30
Dim gub_race_female_weight_mod  As UByte    At A_RACE + 31
Dim gsw_race_disarm             As Integer  At A_RACE + 32
Dim gsw_race_search             As Integer  At A_RACE + 34
Dim gsw_race_stealth            As Integer  At A_RACE + 36
Dim gsw_race_fos                As Integer  At A_RACE + 38
Dim gsw_race_bth                As Integer  At A_RACE + 40
Dim gsw_race_bth_bows           As Integer  At A_RACE + 42
Dim gsw_race_saving_throw       As Integer  At A_RACE + 44
Dim gub_race_hit_die            As UByte    At A_RACE + 46
Dim gub_race_infra_vision       As UByte    At A_RACE + 47
Dim gub_race_exp_factor         As UByte    At A_RACE + 48
Dim gub_race_classes            As UByte    At A_RACE + 49      ' one bit per class the race may be
#define A_RACE_ADJUSTMENTS      A_RACE + 16         ' 6 bytes, see above

Dim gub_class_hit_die           As UByte    At A_CLASS + 16
Dim gub_class_disarm            As UByte    At A_CLASS + 17
Dim gub_class_search            As UByte    At A_CLASS + 18
Dim gub_class_stealth           As UByte    At A_CLASS + 19
Dim gub_class_fos               As UByte    At A_CLASS + 20
Dim gub_class_bth               As UByte    At A_CLASS + 21
Dim gub_class_bth_bows          As UByte    At A_CLASS + 22
Dim gub_class_saving_throw      As UByte    At A_CLASS + 23
' N.B: A_CLASS + 24 to + 29 are the six stat adjustments, signed bytes, in the usual order
Dim gub_class_spell_type        As UByte    At A_CLASS + 30     ' a UB_SPELL_TYPE_ value: none, the mage's spells or the priest's prayers
Dim gub_class_exp_factor        As UByte    At A_CLASS + 31
Dim gub_class_first_spell_level As UByte    At A_CLASS + 32
Dim gub_class_adj_bth           As UByte    At A_CLASS + 33     ' what each level adds: to hit...
Dim gub_class_adj_bth_bows      As UByte    At A_CLASS + 34     ' ...to hit with bows...
Dim gub_class_adj_device        As UByte    At A_CLASS + 35     ' ...using magic devices...
Dim gub_class_adj_disarm        As UByte    At A_CLASS + 36     ' ...disarming...
Dim gub_class_adj_save          As UByte    At A_CLASS + 37     ' ...and saving throws
#define A_CLASS_ADJUSTMENTS     A_CLASS + 24        ' 6 bytes, see above

' the working item, i.e. one actual thing lying in the dungeon, in a store or being carried, a 64 byte record...
' ...the fields are Moria's Inventory_t, from + 32 onwards it is laid out exactly as the working object is, so that
' making an item from its kind of object is one copy of those 32 bytes
Dim guw_item_object             As UInteger At A_ITEM           ' which kind of object it is, a number in the objects database (Moria's id)
Dim gub_item_special_name       As UByte    At A_ITEM + 2       ' e.g. "of Slay Evil", 0 for none
Dim gub_item_identification     As UByte    At A_ITEM + 3       ' what the player knows about it, bit field
' N.B: A_ITEM + 4 to + 16 is the inscription, 13 bytes of text ending in a 0, + 17 to + 31 are spare
Dim gul_item_flags              As ULong    At A_ITEM + 32
Dim gub_item_category           As UByte    At A_ITEM + 36
Dim gub_item_sprite             As UByte    At A_ITEM + 37
Dim gsw_item_misc_use           As Integer  At A_ITEM + 38
Dim gsl_item_cost               As Long     At A_ITEM + 40
Dim gub_item_sub_category       As UByte    At A_ITEM + 44
Dim gub_item_count              As UByte    At A_ITEM + 45
Dim guw_item_weight             As UInteger At A_ITEM + 46
Dim gsw_item_to_hit             As Integer  At A_ITEM + 48
Dim gsw_item_to_damage          As Integer  At A_ITEM + 50
Dim gsw_item_ac                 As Integer  At A_ITEM + 52
Dim gsw_item_to_ac              As Integer  At A_ITEM + 54
Dim gub_item_damage_dice        As UByte    At A_ITEM + 56
Dim gub_item_damage_sides       As UByte    At A_ITEM + 57
Dim gub_item_depth              As UByte    At A_ITEM + 58
Dim gsl_item_store_cost         As Long     At A_ITEM + 20      ' in a store's stock only: what the store paid, Moria keeps this beside the item (InventoryRecord_t)

' the six stores, 16 bytes of state each at A_STORES, this is Moria's Store_t without its stock...
' ...store n's state starts at A_STORES + n * UB_STORE_STATE_SIZE, these are the places within it
' N.B: a store's stock is in the store items pages, 24 records to a store: item i of store n is record n * 24 + i,
' fetched with s_core_fetch_record( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS , n * 24 + i , A_ITEM )
#define UB_STORE_TURNS_LEFT     0       ' 4 bytes, signed: turns until it opens again, after the owner has thrown the player out
#define UB_STORE_INSULTS        4       ' 2 bytes, signed: how often the owner has been insulted this visit
#define UB_STORE_OWNER          6       ' 1 byte: which of the 18 owners runs it
#define UB_STORE_ITEM_COUNT     7       ' 1 byte: how many different items are in stock (unique_items_counter)
#define UB_STORE_GOOD_BUYS      8       ' 2 bytes: bargains the player has struck here
#define UB_STORE_BAD_BUYS       10      ' 2 bytes: and the times they did badly

#define UB_ITEM_IDENTIFICATION_OFFSET 3
#define UB_ITEM_INSCRIPTION_OFFSET 4    ' where the inscription is in an item record, 13 bytes of text ending in a 0
#define UB_ITEM_FLAGS_OFFSET    32      ' 4 bytes
#define UB_ITEM_MISC_USE_OFFSET 38      ' 2 bytes, signed
#define UB_ITEM_WEIGHT_OFFSET   46      ' 2 bytes
#define UB_ITEM_COST_OFFSET     40      ' 4 bytes, signed
#define UB_ITEM_TO_HIT_OFFSET   48      ' 2 bytes, signed, as are the next three
#define UB_ITEM_TO_DAMAGE_OFFSET 50
#define UB_ITEM_AC_OFFSET       52
#define UB_ITEM_TO_AC_OFFSET    54
#define UB_ITEM_SUB_CATEGORY_OFFSET 44
#define UB_ITEM_COUNT_OFFSET    45
#define UB_ITEM_OBJECT_FIELDS   32      ' an item's fields from here on are its object's, Moria's inventoryItemCopyTo() copies them
#define UB_ITEM_COLOUR_OFFSET   59      ' ours: an object's, and so an item's, attribute byte on the map, see colours.txt
#define UB_ITEM_CATEGORY_OFFSET 36      ' where the category is in an item record, for reading it straight from the paged data
#define UB_ITEM_SPRITE_OFFSET   37      ' ...and the sprite
#define UB_ITEM_DEPTH_OFFSET    58      ' the depth this kind of thing is first found at
#define UB_ITEM_DAMAGE_OFFSET   56      ' the damage dice: how many, then how many sides
#define UB_ITEM_SPECIAL_NAME_OFFSET 2       ' e.g. "of Slay Evil", 0 for none
' the working creature, i.e. one kind of creature, a 64 byte record from the creatures database...
' ...filled by s_core_fetch_record( UB_SLOT_CREATURES , UB_PAGE_CREATURES_DB , <number> , A_CREATURE )...
' ...the fields are Moria's Creature_t, the layout is set by create-data.ps1, which builds the database, the two must agree
' N.B: the name is 26 bytes of text ending in a 0, at A_CREATURE itself, turn it into a string with fs_core_text_at( A_CREATURE )
Dim gul_creature_movement       As ULong    At A_CREATURE + 26  ' bit field
Dim gul_creature_spells         As ULong    At A_CREATURE + 30  ' bit field
Dim guw_creature_defenses       As UInteger At A_CREATURE + 34  ' bit field
Dim guw_creature_kill_exp       As UInteger At A_CREATURE + 36  ' experience for a kill
Dim gub_creature_sleep          As UByte    At A_CREATURE + 38  ' inactive counter / 10
Dim gub_creature_area_radius    As UByte    At A_CREATURE + 39  ' area affect radius
Dim gub_creature_ac             As UByte    At A_CREATURE + 40  ' armour class
Dim gub_creature_speed          As UByte    At A_CREATURE + 41  ' movement speed + 10
#define UB_CREATURE_SPRITE_OFFSET   42              ' for reading it straight from another creature's record
Dim gub_creature_sprite         As UByte    At A_CREATURE + UB_CREATURE_SPRITE_OFFSET  ' the character shown on the map
Dim gub_creature_hit_dice       As UByte    At A_CREATURE + 43  ' hit points are this many dice...
Dim gub_creature_hit_sides      As UByte    At A_CREATURE + 44  ' ...of this many sides
#define UB_CREATURE_ATTACKS_OFFSET  45              ' the four attacks, a byte each
Dim gub_creature_attack_1       As UByte    At A_CREATURE + UB_CREATURE_ATTACKS_OFFSET  ' up to four attacks, each the number of an entry in the monster attacks table
Dim gub_creature_attack_2       As UByte    At A_CREATURE + 46
Dim gub_creature_attack_3       As UByte    At A_CREATURE + 47
Dim gub_creature_attack_4       As UByte    At A_CREATURE + 48
Dim gub_creature_level          As UByte    At A_CREATURE + 49  ' the dungeon level it is first found on
Dim gub_creature_colour         As UByte    At A_CREATURE + 50  ' ours: its attribute byte on the map, 0 for red, see colours.txt

' the working monster, i.e. one monster on the level, a 64 byte record from the level's monsters page...
' ...filled by s_core_fetch_record( UB_SLOT_MONSTERS , gub_level_monsters_page , <number> , A_MONSTER )...
' ...the fields are Moria's Monster_t, and one of our own, the rest of the record is spare
Dim gsw_monster_hp              As Integer  At A_MONSTER        ' hit points left
Dim gsw_monster_sleep           As Integer  At A_MONSTER + 2    ' how soundly asleep, 0 is awake (sleep_count)
Dim gsw_monster_speed           As Integer  At A_MONSTER + 4    ' movement speed, set against the player's
Dim guw_monster_creature        As UInteger At A_MONSTER + 6    ' which kind of creature it is, a number in the creatures database
Dim gub_monster_row             As UByte    At A_MONSTER + 8    ' where it is on the map (pos)
Dim gub_monster_col             As UByte    At A_MONSTER + 9
Dim gub_monster_distance        As UByte    At A_MONSTER + 10   ' how far it is from the player
Dim gub_monster_lit             As UByte    At A_MONSTER + 11   ' true while the player can see it
Dim gub_monster_stunned         As UByte    At A_MONSTER + 12
Dim gub_monster_confused        As UByte    At A_MONSTER + 13
Dim gub_monster_sprite          As UByte    At A_MONSTER + 14   ' ours: the creature's symbol, so that drawing the map need not look it up
#define UB_MONSTER_CREATURE_OFFSET  6       ' where these are in a monster record, for reading them straight from the paged data
#define UB_MONSTER_SLEEP_OFFSET     2
#define UB_MONSTER_SPEED_OFFSET     4
#define UB_MONSTER_ROW_OFFSET       8
#define UB_MONSTER_COL_OFFSET       9
#define UB_MONSTER_DISTANCE_OFFSET  10
#define UB_MONSTER_LIT_OFFSET       11
#define UB_MONSTER_SPRITE_OFFSET    14
#define UB_MONSTER_COLOUR_OFFSET    15      ' ours: its creature's colour on the map, beside its symbol
Dim gub_monster_colour          As UByte    At A_MONSTER + UB_MONSTER_COLOUR_OFFSET
#define UB_MONSTER_CONFUSED_OFFSET  13
#define UB_MONSTER_STUNNED_OFFSET   12
#define UB_CREATURE_KILL_EXP_OFFSET 36      ' where the experience for a kill is in a creature record
#define UB_CREATURE_SPELLS_OFFSET   30      ' 4 bytes
#define UB_CREATURE_DEFENSES_OFFSET 34      ' 2 bytes

' the working object, i.e. one kind of object, a 64 byte record from the objects database...
' ...filled by s_core_fetch_record( UB_SLOT_DB_MAPS , UB_PAGE_OBJECTS_DB , <number> , A_OBJECT )...
' ...the fields are Moria's DungeonObject_t, the layout is again set by create-data.ps1
' N.B: the name is 32 bytes of text ending in a 0, at A_OBJECT itself, with Moria's own markers in it (& for a/an, ~ for a plural s)
Dim gul_object_flags            As ULong    At A_OBJECT + 32    ' bit field
Dim gub_object_category         As UByte    At A_OBJECT + 36    ' Moria's tval
Dim gub_object_sprite           As UByte    At A_OBJECT + 37    ' the character shown on the map
Dim gsw_object_misc_use         As Integer  At A_OBJECT + 38    ' Moria's p1
Dim gsl_object_cost             As Long     At A_OBJECT + 40
Dim gub_object_sub_category     As UByte    At A_OBJECT + 44    ' Moria's subval
Dim gub_object_count            As UByte    At A_OBJECT + 45    ' number of items
Dim guw_object_weight           As UInteger At A_OBJECT + 46
Dim gsw_object_to_hit           As Integer  At A_OBJECT + 48
Dim gsw_object_to_damage        As Integer  At A_OBJECT + 50
Dim gsw_object_ac               As Integer  At A_OBJECT + 52
Dim gsw_object_to_ac            As Integer  At A_OBJECT + 54
Dim gub_object_damage_dice      As UByte    At A_OBJECT + 56    ' damage is this many dice...
Dim gub_object_damage_sides     As UByte    At A_OBJECT + 57    ' ...of this many sides
Dim gub_object_depth            As UByte    At A_OBJECT + 58    ' the dungeon level it is first found on

'##################################################################################################################################

'##################################################################################################################################
' --- EACH STAGE'S AND LIBRARY'S OWN STORAGE, moved here from their own files on 22 October 2026, file by file ---
' N.B: a library's private storage, A_LIB_PRIVATE, is its own and no other's, the heading over each part says whose,
' and tools\check-addresses.ps1 checks each part with that module, see there

' --- private to stage-aim-include.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_aim_y               As UByte    At A_LIB_PRIVATE            ' the square the spell has reached
Dim gub_aim_x               As UByte    At A_LIB_PRIVATE + 1
Dim gub_aim_distance        As UByte    At A_LIB_PRIVATE + 2        ' how far it has gone

' --- private to stage-create-dungeon.bas (its own, moved here from it on 22 October 2026) ---
' Moria keeps its working lists in arrays, we cannot have arrays in a stage (they would sit in front of the code),
' so they live in the corridor scratchpad page, which this stage keeps in the first paged data slot (MMU 0) throughout...
' ...each entry in a list is a row and a column, one byte each
#define A_GEN_TUNNELS       A_MMU_SLOT_PAGED_CORRIDORS              ' 1000 entries, the squares of the tunnel being dug
#define A_GEN_WALLS         A_MMU_SLOT_PAGED_CORRIDORS + 2000       ' 1000 entries, the room walls that tunnel has gone through
#define A_GEN_DOORS         A_MMU_SLOT_PAGED_CORRIDORS + 4000       '  100 entries, where tunnels have met tunnels
#define A_GEN_LOCATIONS     A_MMU_SLOT_PAGED_CORRIDORS + 4200       '  401 entries, the middle of each room
#define A_GEN_ROOM_MAP      A_MMU_SLOT_PAGED_CORRIDORS + 5010       '  400 bytes, 20 by 20, which places on the grid get a room
#define A_GEN_VARS          A_MMU_SLOT_PAGED_CORRIDORS + 5500
Dim gub_gen_y               As UByte    At A_GEN_VARS           ' where the tunnel being dug has got to
Dim gub_gen_x               As UByte    At A_GEN_VARS + 1
Dim gub_gen_end_y           As UByte    At A_GEN_VARS + 2       ' where it is going
Dim gub_gen_end_x           As UByte    At A_GEN_VARS + 3
Dim gsb_gen_dir_y           As Byte     At A_GEN_VARS + 4       ' which way it is heading, -1, 0 or 1 each
Dim gsb_gen_dir_x           As Byte     At A_GEN_VARS + 5
Dim guw_gen_door_count      As UInteger At A_GEN_VARS + 6       ' how many entries are in the doors list

' --- private to stage-fight-include.bas (its own, moved here from it on 22 October 2026) ---
' what the fight library and the throw library share: asking for a direction, and stepping along it, stage-lib-fight.bas
' and stage-lib-throw.bas include this file, each has its own copy of these routines
' N.B: the page's own storage at A_LIB_PRIVATE + 64 and + 65 is used here
Dim gub_ft_y                As UByte    At A_LIB_PRIVATE + 64       ' the square a direction leads to, or the thing in flight has reached
Dim gub_ft_x                As UByte    At A_LIB_PRIVATE + 65

' --- private to stage-lib-chests.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_ch_y                As UByte    At A_LIB_PRIVATE            ' where the chest is
Dim gub_ch_x                As UByte    At A_LIB_PRIVATE + 1

' --- private to stage-lib-commands-2.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_cm_rogue_dir        As UByte    At A_LIB_PRIVATE + 200      ' the direction that came with a rogue like command, 0 for none

' --- private to stage-lib-commands.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_cm_last_was_ctrl_p  As UByte    At A_LIB_PRIVATE + 100      ' true if the last command was Ctrl-P, Moria's last_command

' --- private to stage-lib-compact.bas (its own, moved here from it on 22 October 2026) ---
#define A_CP_MONSTER        A_LIB_PRIVATE                           ' the working records, kept while the list is compacted
#define A_CP_CREATURE       A_LIB_PRIVATE + UB_RECORD_SIZE
#define A_CP_OBJECT         A_LIB_PRIVATE + UB_RECORD_SIZE * 2
#define A_CP_ITEM           A_LIB_PRIVATE + UB_RECORD_SIZE * 3

' --- private to stage-lib-equipment.bas (its own, moved here from it on 22 October 2026) ---
#define A_EQ_SAVED              A_LIB_PRIVATE               ' 64 bytes, the item being put on, while its place is made ready
Dim gub_eq_saved_page           As UByte    At A_LIB_PRIVATE + 64       ' the page the caller had in the first data slot, while the screen is put aside there
Dim gub_eq_screen_saved         As UByte    At A_LIB_PRIVATE + 65

' --- private to stage-lib-haggle-include.bas (its own, moved here from it on 22 October 2026) ---
#define A_HG_INPUT              A_LIB_PRIVATE               ' 44 bytes, what the player has typed
Dim gsw_hg_last_increment       As Integer  At A_LIB_PRIVATE + 44   ' the last "+10" style raise, so that just Enter repeats it (store_last_increment)
Dim gsl_hg_new_offer            As Long     At A_LIB_PRIVATE + 46   ' the offer being made
Dim gub_hg_store                As UByte    At A_LIB_PRIVATE + 50
Dim guw_hg_state                As UInteger At A_LIB_PRIVATE + 51   ' where this store's 16 bytes of state are
Dim gub_hg_owner_haggle         As UByte    At A_LIB_PRIVATE + 53   ' three things about the store's owner...
Dim gub_hg_owner_max_inflate    As UByte    At A_LIB_PRIVATE + 54
Dim gub_hg_owner_max_insults    As UByte    At A_LIB_PRIVATE + 55
Dim gub_hg_owner_min_inflate    As UByte    At A_LIB_PRIVATE + 56
Dim gub_hg_owner_race           As UByte    At A_LIB_PRIVATE + 57
Dim gsw_hg_owner_max_cost       As Integer  At A_LIB_PRIVATE + 58   ' the most the owner will pay for anything

' --- private to stage-lib-info.bas (its own, moved here from it on 22 October 2026) ---
#define A_IN_MAP_ROW        A_LIB_PRIVATE               ' 66 bytes, one row of the reduced map while it is worked out
Dim gub_in_saved_page       As UByte    At A_LIB_PRIVATE + 70       ' the page the caller had in the first data slot, while the screen is put aside there

' --- private to stage-lib-items.bas (its own, moved here from it on 22 October 2026) ---
#define A_D_VAL             A_LIB_PRIVATE               ' 176 bytes, the description as it is built up
#define A_D_TAIL            A_LIB_PRIVATE + 176         ' 176 bytes, the rest of the text, while something is inserted in front of it
#define A_D_DAM             A_LIB_PRIVATE + 352         '  24 bytes, the damage part, e.g. " (2d5)"
Dim guw_d_base              As UInteger At A_LIB_PRIVATE + 376      ' the text being added to...
Dim gub_d_len               As UByte    At A_LIB_PRIVATE + 378      ' ...and how long it is so far
Dim gub_d_saved_page        As UByte    At A_LIB_PRIVATE + 379      ' the page the caller had in the third data slot

' --- private to stage-lib-look.bas (its own, moved here from it on 22 October 2026) ---
Dim gsb_lk_fxx              As Byte     At A_LIB_PRIVATE            ' how the cone's own x and y turn into columns and rows of the map
Dim gsb_lk_fxy              As Byte     At A_LIB_PRIVATE + 1
Dim gsb_lk_fyx              As Byte     At A_LIB_PRIVATE + 2
Dim gsb_lk_fyy              As Byte     At A_LIB_PRIVATE + 3
Dim gub_lk_no_query         As UByte    At A_LIB_PRIVATE + 4        ' a hack to prevent doubling up on direct lines of sight (los_hack_no_query)
Dim gub_lk_transparent      As UByte    At A_LIB_PRIVATE + 5        ' whether the square last looked at can be seen past
Dim gub_lk_seen             As UByte    At A_LIB_PRIVATE + 6        ' how many places something was seen at (los_num_places_seen)
Dim gub_lk_rocks            As UByte    At A_LIB_PRIVATE + 7        ' 0 while looking at monsters and things, 1 on the second time round, for the kinds of rock (los_rocks_and_objects)

' --- private to stage-lib-minimap.bas (its own, moved here from it on 22 October 2026) ---
#define A_MM_FONT       A_MMU_SLOT_1 + UW_MM_FONT_SIZE     ' characters 128 to 255 of the font, page 10, while it is in MMU 1
#define A_MM_BITS       A_MMU_SLOT_0            ' the bitmap, while its page is in MMU 0
' ...and in this page's own storage: which of the 128 cells is the green one, the player's, 255 for none, see s_mm_player()
#define A_MM_GREEN      A_LIB_PRIVATE

' --- private to stage-lib-monster-attack-2.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_m2_quiet            As UByte    At A_LIB_PRIVATE + 16       ' true when the damage is a trap's, which has said its own piece

' --- private to stage-lib-monster-attack.bas (its own, moved here from it on 22 October 2026) ---
#define A_MA_NAME           A_LIB_PRIVATE               ' 40 bytes, how the attacker is spoken of: "The Kobold " or "It "

' --- private to stage-lib-monster-moves.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_mm_wake             As UByte    At A_LIB_PRIVATE + 21       ' 1 if it woke, 2 if it stirred and slept on

' --- private to stage-lib-monster-spells.bas (its own, moved here from it on 22 October 2026) ---
#define A_MS_NAME           A_LIB_PRIVATE               ' 40 bytes, how the caster is spoken of: "The Kobold " or "It "
#define A_MS_CHOICES        A_LIB_PRIVATE + 40          ' 30 bytes, the spells the caster knows
Dim gub_ms_monster          As UByte    At A_LIB_PRIVATE + 72       ' the caster's number on the level

' --- private to stage-lib-moves.bas (its own, moved here from it on 22 October 2026) ---
#define A_MV_TEXT           A_LIB_PRIVATE               ' 240 bytes, a message as it is built up
#define A_MV_SCAN_OLD       A_LIB_PRIVATE + 240         ' the item number being looked for on the map...
#define A_MV_SCAN_NEW       A_LIB_PRIVATE + 241         ' ...and the number it is changed to
Dim gub_mv_scan_old         As UByte    At A_MV_SCAN_OLD
Dim gub_mv_scan_new         As UByte    At A_MV_SCAN_NEW
Dim gub_mv_length           As UByte    At A_LIB_PRIVATE + 242      ' how long the message is so far
Dim gub_mv_saved_page       As UByte    At A_LIB_PRIVATE + 243      ' the page the caller had in the third data slot
Dim gub_mv_y                As UByte    At A_LIB_PRIVATE + 244      ' the square a direction leads to
Dim gub_mv_x                As UByte    At A_LIB_PRIVATE + 245

' --- private to stage-lib-player-attack.bas (its own, moved here from it on 22 October 2026) ---
#define A_PA_MONSTER            A_LIB_PRIVATE               ' the working monster, put aside...
#define A_PA_CREATURE           A_LIB_PRIVATE + UB_RECORD_SIZE  ' ...and its creature
Dim gub_pa_seen_objects     As UByte    At A_LIB_PRIVATE + 128      ' how many of the things a dead monster left the player could see...
Dim gub_pa_seen_gold        As UByte    At A_LIB_PRIVATE + 129      ' ...and how many piles of its gold
Dim gul_pa_treasure         As ULong    At A_LIB_PRIVATE + 130      ' what that teaches the player about its kind, the bits of its "movement", Moria's monsterDeath() answer

' --- private to stage-lib-run.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_rn_prev_dir         As UByte    At A_LIB_PRIVATE            ' the way the runner is taken to have come from (find_prevdir)
Dim gub_rn_open_area        As UByte    At A_LIB_PRIVATE + 1        ' in the open on at least one side (find_openarea)
Dim gub_rn_break_right      As UByte    At A_LIB_PRIVATE + 2        ' a wall on the right, stop if it opens (find_breakright)
Dim gub_rn_break_left       As UByte    At A_LIB_PRIVATE + 3        ' the same on the left (find_breakleft)
Dim gub_rn_y                As UByte    At A_LIB_PRIVATE + 4        ' the square fub_rn_step() last led to
Dim gub_rn_x                As UByte    At A_LIB_PRIVATE + 5
Dim gub_rn_check_dir        As UByte    At A_LIB_PRIVATE + 6        ' while looking round: the other diagonal beside the first way on
Dim gub_rn_dir_a            As UByte    At A_LIB_PRIVATE + 7        ' the first way on, 0 for none yet
Dim gub_rn_dir_b            As UByte    At A_LIB_PRIVATE + 8        ' the second

' --- private to stage-lib-scores.bas (its own, moved here from it on 22 October 2026) ---
#define A_SC_ENTRY          A_LIB_PRIVATE           ' a score put aside, while the table is made over or moved down
#define A_SC_ITEM           A_LIB_PRIVATE + 128     ' the working item, put aside while the pack is valued
#define A_SC_FILE_NAME      A_LIB_PRIVATE + 200     ' 16 bytes, the name of the text file while it is being written
#define A_SC_CLOCK          A_LIB_PRIVATE + 300     ' 7 bytes, the clock's own, as they were read from it

' --- private to stage-lib-spells-2.bas (its own, moved here from it on 22 October 2026) ---
#define A_S2_TEXT           A_LIB_PRIVATE + 256     ' a description put aside, while what is worn is worked out again

' --- private to stage-lib-stores.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_st_saved_page       As UByte    At A_LIB_PRIVATE            ' the page the caller had in the second data slot
Dim gsl_st_price            As Long     At A_LIB_PRIVATE + 1        ' the three answers of the sell price routine...
Dim gsl_st_min_price        As Long     At A_LIB_PRIVATE + 5
Dim gsl_st_max_price        As Long     At A_LIB_PRIVATE + 9

' --- private to stage-lib-text.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_tx_saved_page       As UByte    At A_LIB_PRIVATE            ' the page the caller had in the first data slot, while the screen is put aside there

' --- private to stage-lib-throw.bas (its own, moved here from it on 22 October 2026) ---
#define A_FT_THROWN         A_LIB_PRIVATE               ' 64 bytes, the thing in flight

' --- private to stage-lib-traps.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_tr_y                As UByte    At A_LIB_PRIVATE            ' the square a direction leads to
Dim gub_tr_x                As UByte    At A_LIB_PRIVATE + 1

' --- private to stage-lib-wizard-2.bas (its own, moved here from it on 22 October 2026) ---
#define A_W2_ITEM           A_LIB_PRIVATE + 64                      ' 64 bytes, the object being made up

' --- private to stage-lib-wizard.bas (its own, moved here from it on 22 October 2026) ---
#define A_WZ_ROWS           A_MMU_SLOT_PAGED_CORRIDORS              ' three rows of the map, 256 bytes each, while the level is lit

' --- private to stage-magic-include.bas (its own, moved here from it on 22 October 2026) ---
#define A_MG_LIST           A_LIB_PRIVATE               ' 32 bytes, the spells to choose from
#define A_MG_PROMPT         A_LIB_PRIVATE + 32          ' 40 bytes, the caller's question, kept while other libraries are called
Dim gub_mg_saved_page       As UByte    At A_LIB_PRIVATE + 72       ' the page the caller had in the first data slot, while the screen is put aside there
Dim gub_mg_screen_saved     As UByte    At A_LIB_PRIVATE + 73
Dim gub_mg_saved_page_2     As UByte    At A_LIB_PRIVATE + 74       ' the page the caller had in the third data slot

' --- private to stage-monster-moves-include.bas (its own, moved here from it on 22 October 2026) ---
' what the two monster moves libraries share, stage-lib-monster-moves.bas and stage-lib-monster-moves-2.bas: the
' working storage of a monster's move, it is in the core's data, not in either page's own, so that both can get at it
#define A_MM_DIRECTIONS     A_MMU_SLOT_CORE_DATA + 585      ' 9 bytes, the directions a monster will try, in order, only the first 5 are used
' N.B: this one is the same byte as gub_game_monster_turn in globals.bas, so that the compact library and the player
' attack library can tell which monsters have had their turn, it is 0 when it is not the monsters' turn
Dim gub_mm_monster          As UByte    At A_MMU_SLOT_CORE_DATA + 584   ' the number of the monster having its turn, the same byte as gub_game_monster_turn
Dim gub_mm_do_turn          As UByte    At A_MMU_SLOT_CORE_DATA + 594   ' true once the monster has used its move
Dim gub_mm_do_move          As UByte    At A_MMU_SLOT_CORE_DATA + 595   ' true while the square being tried can be moved on to
' what the player may learn from watching this move, Moria's rcmove: the bits of the creature's "movement" that
' showed, in two bytes, the lowest of the four and the third, the only ones any of them are in
Dim gub_mm_seen_low         As UByte    At A_MMU_SLOT_CORE_DATA + 596
Dim gub_mm_seen_high        As UByte    At A_MMU_SLOT_CORE_DATA + 597

' --- private to stage-player.bas (its own, moved here from it on 22 October 2026) ---
' NOT Moria's, ours, and a cheeky one: the auto roller. A capital R at "Hit space to re-roll" asks for the least the
' player will take for each of the six stats, and then rolls again and again, every roll shown, until a character
' comes up with all of them, or a key is pressed. Each roll is an ordinary one, Moria's dice and Moria's rules, so
' nothing can be had this way that patience with the space bar would not bring, N.B: and so asking for more than
' the race can have just rolls for ever, a Halfling's strength, say, is never more than 15
' the six least values are kept at the far end of the text buffer, clear of the dice and of the history
#define A_PL_AUTO_LEAST     A_TEXT_BUFFER + 248     ' 6 bytes, the auto roller's least for each stat

' --- private to stage-recall-include.bas (its own, moved here from it on 22 October 2026) ---
#define A_RC_LINE           A_TEXT_BUFFER               ' 80 bytes, the line being filled, Moria's roff_buffer
#define A_RC_ATTACKS        A_TEXT_BUFFER + 80          ' 4 bytes, how often each attack has been seen
Dim gub_rc_length           As UByte    At A_TEXT_BUFFER + 84       ' how much of the line is filled
Dim gub_rc_row              As UByte    At A_TEXT_BUFFER + 85       ' the row of the screen the line will go on
Dim gub_rc_saved_page       As UByte    At A_TEXT_BUFFER + 86       ' the page the caller had in the first data slot, while the screen is put aside there
Dim gul_rc_movement         As ULong    At A_TEXT_BUFFER + 88       ' what is remembered of the creature, Moria's Recall_t
Dim gul_rc_spells           As ULong    At A_TEXT_BUFFER + 92
Dim guw_rc_kills            As UInteger At A_TEXT_BUFFER + 96
Dim guw_rc_deaths           As UInteger At A_TEXT_BUFFER + 98
Dim guw_rc_defenses         As UInteger At A_TEXT_BUFFER + 100
Dim gub_rc_wake             As UByte    At A_TEXT_BUFFER + 102
Dim gub_rc_ignore           As UByte    At A_TEXT_BUFFER + 103

' --- private to stage-store.bas (its own, moved here from it on 22 October 2026) ---
Dim gub_store_top   As UByte    At A_TEXT_BUFFER + 240      ' which item is at the top of the list on screen, 0 or 12 (current_top_item_id)

' --- private to stage-textfile-include.bas (its own, moved here from it on 22 October 2026) ---
Dim guw_tf_at               As UInteger At A_LIB_PRIVATE + 440      ' how much of the page being filled is full
Dim gub_tf_slot             As UByte    At A_LIB_PRIVATE + 442      ' which 8KB of the file that page is
Dim gub_tf_failed           As UByte    At A_LIB_PRIVATE + 443      ' true once the file would not write
Dim gub_tf_saved_page       As UByte    At A_LIB_PRIVATE + 444      ' the page the caller had in the first data slot
#define A_TF_NAME           A_LIB_PRIVATE + 448                     ' 32 bytes, the name of the file, text ending in a 0

' --- private to stage-wizard-include.bas (its own, moved here from it on 22 October 2026) ---
Dim gsl_wz_number           As Long     At A_LIB_PRIVATE            ' the number the player last typed
Dim gub_wz_valid            As UByte    At A_LIB_PRIVATE + 4        ' true if what they typed was a number, Moria's stringToNumber()

' --- private to stage-lib-objects.bas ---
#define A_OB_ORDER          A_LIB_PRIVATE           ' 164 bytes, this game's order of the six flavour lists, copied from the knowledge page
#define A_OB_COLOURS        A_LIB_PRIVATE + 164     ' 164 bytes, the flavours' colours, copied from the game tables page
