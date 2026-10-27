' file: constants.bas
'##################################################################################################################################
' facts, in "ZX Next" speak:
'   a 16KB block is known as a "bank", but we won't be using banks as this is a ZX Basic interpreter term
'   a  8KB block is known as a "page", for use via MMU, and we will be using a poor man's virtual memory system to swap pages in and out
'##################################################################################################################################
' the Z80's 64KB as eight 8KB MMU slots, where core means always mapped in, and paged means swapped as needed:
'   MMU 0   $0000   paged data   monsters (dungeon, town), and the corridor scratchpad      } these three are lent back to the system
'   MMU 1   $2000   paged data   items (dungeon, town, store), and the scent map             } for the length of any file call, as ROM,
'   MMU 2   $4000   paged data   the databases, the strings, and the maps                    } ROM, and the system variables page (10)
'   MMU 3   $6000   paged code   the stages
'   MMU 4   $8000   core  code   main loop, core subs and functions, the API jump table
'   MMU 5   $A000   core  code   second page, with the interrupt handler and its table at the very top
'   MMU 6   $C000   core  data   fixed variables growing up from $C000, the heap in the last 1024 bytes
'   MMU 7   $E000   core  screen 80 x 32 x word = 5120 bytes of tile map ($E000-$F3FF), then 3070 bytes of Z80 stack ($F400-$FFFD, grows downwards)
' why this order: everything that must never disappear (core code, core data, stack, screen) is above $8000...
' ...so the bottom of memory can be handed to NextZXOS whenever it is needed, a file call needs the ROM at $0000-$3FFF...
' ...and nothing of ours has to live at $0000, which is why interrupts use mode 2 (see A_IM2_TABLE below) and not mode 1
' N.B: MMU 0, 1 and 2 start out exactly as the system left them (ROM, ROM, and page 10), the first call to
' s_core_swap_paged_data() for a slot is what puts one of our own pages there...
' ...once our data is in MMU 0 there is nothing sensible at $0066, where a non maskable interrupt jumps to,
' so the loader switches off the two buttons that can cause one (see nextreg $06 in load.bas)
'##################################################################################################################################
' notes re screen components:
'   component	size    where it lives          paged or core?
'   ---------   ----    --------------          --------------
'   font        2048    physical RAM page 10	never mapped by us, the display hardware reads it directly, it sits in the old Spectrum display file area, below the system variables
'   tile map    5120	physical RAM page 11	core, at the start of the page that is permanently mapped to MMU7 ($E000), the Next can only display tiles from pages 10, 11 or 14
'   palette      512    internal FPGA RAM	    neither, instead we populate the palette using NextReg $44 (data port)
'##################################################################################################################################
' --- DATA TYPES ---
' N.B: from this point onwards all defines and constants must use this naming convention...
'   prefix      meaning             intent                                      typical Z80 target
'   ------      -------             ------                                      ------------------
'   MMU_        special use         for page swapping                           (well, it's used by ZX Next extensions really)
'   T_          custom structures   structured data layout                      (used in Boriel basic to reference data in pages in slots)
'   UB_         unsigned byte       counters, indices, small values (0-255)     A, B, C, L
'   UW_         unsigned word       large counts, 16-bit math values            BC, DE, HL
'   UL_         unsigned long       very large counts, 32-bit integers          (used for Boriel basic variables only)
'   UC_         unsigned byte       but naming is used to denote an ASCII code  typically A, but could be used in any half of a register pair
'   SB_ SW_     signed byte/word	offsets, relative movements (-128 to 127)   A or IX+d
'   MB_ MW_     masked byte/word    flags for bit masks                         AND, OR, BIT
'   A_          address             fixed & derived memory locations            HL, DE, BC, IX, IY
'##################################################################################################################################
'   N.B: only the NEXTREG and MMU constants can start with NEXTREG_ and MMU_
'   ...all other defines and constants must follow the naming convention...
'##################################################################################################################################

Const   true    As UByte = 1
Const   false   As UByte = 0

' --- HUNGER AND HEALING, Moria's own constants, by Moria's names (config.cpp) ---
Const   UW_PLAYER_FOOD_FULL         As UInteger = 10000     ' getting full
Const   UW_PLAYER_FOOD_MAX          As UInteger = 15000     ' the most food, beyond is wasted
Const   UW_PLAYER_FOOD_FAINT        As UInteger = 300       ' the character begins fainting
Const   UW_PLAYER_FOOD_WEAK         As UInteger = 1000      ' warned of getting weak
Const   UW_PLAYER_FOOD_ALERT        As UInteger = 2000      ' warned of getting low on food
Const   UB_PLAYER_REGEN_FAINT       As UByte    = 33        ' how fast the character heals, times 2^16, when fainting
Const   UB_PLAYER_REGEN_WEAK        As UByte    = 98        ' ...when weak
Const   UB_PLAYER_REGEN_NORMAL      As UByte    = 197       ' ...when fed
Const   UW_PLAYER_REGEN_HPBASE      As UInteger = 1442      ' the least that hit points heal, times 2^16
Const   UW_PLAYER_REGEN_MNBASE      As UInteger = 524       ' the least that mana heals, times 2^16

' --- MORE OF MORIA'S OWN CONSTANTS, by Moria's names ---
#define UB_ITEM_SINGLE_STACK_MIN    64          ' items with a sub category from here up can be stacked...
#define UB_ITEM_SINGLE_STACK_MAX    192         ' ...up to here they stack singly...
#define UB_ITEM_GROUP_MIN           192         ' ...and above this they are a batch, like arrows, that only stacks with itself
Const   UW_OBJECTS_RUNE_PROTECTION  As UInteger = 3000      ' a monster breaks a glyph of warding if 1 in this many is below its level
Const   UL_PLAYER_MAX_EXP           As ULong    = 9999999   ' the most experience a character can have
Const   UW_OBJECT_LAMP_MAX_CAPACITY As UInteger = 15000     ' the most turns of light a lamp holds
Const   UB_MON_CHANCE_OF_NEW        As UByte    = 160       ' a new monster appears on 1 turn in this many

' --- MORIA'S ENUMS, by Moria's names: what each kind of food, potion, staff, wand, spell, prayer and trap does ---
' ...FoodMagicTypes, player_eat.cpp
Const   UB_FOOD_POISON                       As UByte = 1
Const   UB_FOOD_BLINDNESS                    As UByte = 2
Const   UB_FOOD_PARANOIA                     As UByte = 3
Const   UB_FOOD_CONFUSION                    As UByte = 4
Const   UB_FOOD_HALLUCINATION                As UByte = 5
Const   UB_FOOD_CURE_POISON                  As UByte = 6
Const   UB_FOOD_CURE_BLINDNESS               As UByte = 7
Const   UB_FOOD_CURE_PARANOIA                As UByte = 8
Const   UB_FOOD_CURE_CONFUSION               As UByte = 9
Const   UB_FOOD_WEAKNESS                     As UByte = 10
Const   UB_FOOD_UNHEALTH                     As UByte = 11
Const   UB_FOOD_RESTORE_STR                  As UByte = 16
Const   UB_FOOD_RESTORE_CON                  As UByte = 17
Const   UB_FOOD_RESTORE_INT                  As UByte = 18
Const   UB_FOOD_RESTORE_WIS                  As UByte = 19
Const   UB_FOOD_RESTORE_DEX                  As UByte = 20
Const   UB_FOOD_RESTORE_CHR                  As UByte = 21
Const   UB_FOOD_FIRST_AID                    As UByte = 22
Const   UB_FOOD_MINOR_CURES                  As UByte = 23
Const   UB_FOOD_LIGHT_CURES                  As UByte = 24
Const   UB_FOOD_MAJOR_CURES                  As UByte = 26
Const   UB_FOOD_POISONOUS_FOOD               As UByte = 27
' ...PotionSpellTypes, player_quaff.cpp
Const   UB_POTION_STRENGTH                   As UByte = 1
Const   UB_POTION_WEAKNESS                   As UByte = 2
Const   UB_POTION_RESTORE_STRENGTH           As UByte = 3
Const   UB_POTION_INTELLIGENCE               As UByte = 4
Const   UB_POTION_LOSE_INTELLIGENCE          As UByte = 5
Const   UB_POTION_RESTORE_INTELLIGENCE       As UByte = 6
Const   UB_POTION_WISDOM                     As UByte = 7
Const   UB_POTION_LOSE_WISDOM                As UByte = 8
Const   UB_POTION_RESTORE_WISDOM             As UByte = 9
Const   UB_POTION_CHARISMA                   As UByte = 10
Const   UB_POTION_UGLINESS                   As UByte = 11
Const   UB_POTION_RESTORE_CHARISMA           As UByte = 12
Const   UB_POTION_CURE_LIGHT_WOUNDS          As UByte = 13
Const   UB_POTION_CURE_SERIOUS_WOUNDS        As UByte = 14
Const   UB_POTION_CURE_CRITICAL_WOUNDS       As UByte = 15
Const   UB_POTION_HEALING                    As UByte = 16
Const   UB_POTION_CONSTITUTION               As UByte = 17
Const   UB_POTION_GAIN_EXPERIENCE            As UByte = 18
Const   UB_POTION_SLEEP                      As UByte = 19
Const   UB_POTION_BLINDNESS                  As UByte = 20
Const   UB_POTION_CONFUSION                  As UByte = 21
Const   UB_POTION_POISON                     As UByte = 22
Const   UB_POTION_HASTE_SELF                 As UByte = 23
Const   UB_POTION_SLOWNESS                   As UByte = 24
Const   UB_POTION_DEXTERITY                  As UByte = 26
Const   UB_POTION_RESTORE_DEXTERITY          As UByte = 27
Const   UB_POTION_RESTORE_CONSTITUTION       As UByte = 28
Const   UB_POTION_CURE_BLINDNESS             As UByte = 29
Const   UB_POTION_CURE_CONFUSION             As UByte = 30
Const   UB_POTION_CURE_POISON                As UByte = 31
Const   UB_POTION_LOSE_EXPERIENCE            As UByte = 34
Const   UB_POTION_SALT_WATER                 As UByte = 35
Const   UB_POTION_INVULNERABILITY            As UByte = 36
Const   UB_POTION_HEROISM                    As UByte = 37
Const   UB_POTION_SUPER_HEROISM              As UByte = 38
Const   UB_POTION_BOLDNESS                   As UByte = 39
Const   UB_POTION_RESTORE_LIFE_LEVELS        As UByte = 40
Const   UB_POTION_RESIST_HEAT                As UByte = 41
Const   UB_POTION_RESIST_COLD                As UByte = 42
Const   UB_POTION_DETECT_INVISIBLE           As UByte = 43
Const   UB_POTION_SLOW_POISON                As UByte = 44
Const   UB_POTION_NEUTRALIZE_POISON          As UByte = 45
Const   UB_POTION_RESTORE_MANA               As UByte = 46
Const   UB_POTION_INFRA_VISION               As UByte = 47
' ...StaffSpellTypes, staves.cpp
Const   UB_STAFF_STAFF_LIGHT                 As UByte = 1
Const   UB_STAFF_DETECT_DOORS_STAIRS         As UByte = 2
Const   UB_STAFF_TRAP_LOCATION               As UByte = 3
Const   UB_STAFF_TREASURE_LOCATION           As UByte = 4
Const   UB_STAFF_OBJECT_LOCATION             As UByte = 5
Const   UB_STAFF_TELEPORTATION               As UByte = 6
Const   UB_STAFF_EARTHQUAKES                 As UByte = 7
Const   UB_STAFF_SUMMONING                   As UByte = 8
Const   UB_STAFF_DESTRUCTION                 As UByte = 10
Const   UB_STAFF_STARLIGHT                   As UByte = 11
Const   UB_STAFF_HASTE_MONSTERS              As UByte = 12
Const   UB_STAFF_SLOW_MONSTERS               As UByte = 13
Const   UB_STAFF_SLEEP_MONSTERS              As UByte = 14
Const   UB_STAFF_CURE_LIGHT_WOUNDS           As UByte = 15
Const   UB_STAFF_DETECT_INVISIBLE            As UByte = 16
Const   UB_STAFF_SPEED                       As UByte = 17
Const   UB_STAFF_SLOWNESS                    As UByte = 18
Const   UB_STAFF_MASS_POLYMORPH              As UByte = 19
Const   UB_STAFF_REMOVE_CURSE                As UByte = 20
Const   UB_STAFF_DETECT_EVIL                 As UByte = 21
Const   UB_STAFF_CURING                      As UByte = 22
Const   UB_STAFF_DISPEL_EVIL                 As UByte = 23
Const   UB_STAFF_DARKNESS                    As UByte = 25
Const   UB_STAFF_STORE_BOUGHT_FLAG           As UByte = 32
' ...WandSpellTypes, staves.cpp
Const   UB_WAND_WAND_LIGHT                   As UByte = 1
Const   UB_WAND_LIGHTNING_BOLT               As UByte = 2
Const   UB_WAND_FROST_BOLT                   As UByte = 3
Const   UB_WAND_FIRE_BOLT                    As UByte = 4
Const   UB_WAND_STONE_TO_MUD                 As UByte = 5
Const   UB_WAND_POLYMORPH                    As UByte = 6
Const   UB_WAND_HEAL_MONSTER                 As UByte = 7
Const   UB_WAND_HASTE_MONSTER                As UByte = 8
Const   UB_WAND_SLOW_MONSTER                 As UByte = 9
Const   UB_WAND_CONFUSE_MONSTER              As UByte = 10
Const   UB_WAND_SLEEP_MONSTER                As UByte = 11
Const   UB_WAND_DRAIN_LIFE                   As UByte = 12
Const   UB_WAND_TRAP_DOOR_DESTRUCTION        As UByte = 13
Const   UB_WAND_WAND_MAGIC_MISSILE           As UByte = 14
Const   UB_WAND_WALL_BUILDING                As UByte = 15
Const   UB_WAND_CLONE_MONSTER                As UByte = 16
Const   UB_WAND_TELEPORT_AWAY                As UByte = 17
Const   UB_WAND_DISARMING                    As UByte = 18
Const   UB_WAND_LIGHTNING_BALL               As UByte = 19
Const   UB_WAND_COLD_BALL                    As UByte = 20
Const   UB_WAND_FIRE_BALL                    As UByte = 21
Const   UB_WAND_STINKING_CLOUD               As UByte = 22
Const   UB_WAND_ACID_BALL                    As UByte = 23
Const   UB_WAND_WONDER                       As UByte = 24
' ...MageSpellId, mage_spells.cpp
' what magic a class has, Moria's config::spells::SPELL_TYPE_NONE, _MAGE and _PRIEST
Const   UB_SPELL_TYPE_NONE                   As UByte = 0
Const   UB_SPELL_TYPE_MAGE                   As UByte = 1
Const   UB_SPELL_TYPE_PRIEST                 As UByte = 2

Const   UB_MAGE_MAGIC_MISSILE                As UByte = 1
Const   UB_MAGE_DETECT_MONSTERS              As UByte = 2
Const   UB_MAGE_PHASE_DOOR                   As UByte = 3
Const   UB_MAGE_LIGHT_AREA                   As UByte = 4
Const   UB_MAGE_CURE_LIGHT_WOUNDS            As UByte = 5
Const   UB_MAGE_FIND_HIDDEN_TRAPS_DOORS      As UByte = 6
Const   UB_MAGE_STINKING_CLOUD               As UByte = 7
Const   UB_MAGE_CONFUSION                    As UByte = 8
Const   UB_MAGE_LIGHTNING_BOLT               As UByte = 9
Const   UB_MAGE_TRAP_DOOR_DESTRUCTION        As UByte = 10
Const   UB_MAGE_SLEEP1                       As UByte = 11
Const   UB_MAGE_CURE_POISON                  As UByte = 12
Const   UB_MAGE_TELEPORT_SELF                As UByte = 13
Const   UB_MAGE_REMOVE_CURSE                 As UByte = 14
Const   UB_MAGE_FROST_BOLT                   As UByte = 15
Const   UB_MAGE_WALL_TO_MUD                  As UByte = 16
Const   UB_MAGE_CREATE_FOOD                  As UByte = 17
Const   UB_MAGE_RECHARGE_ITEM1               As UByte = 18
Const   UB_MAGE_SLEEP2                       As UByte = 19
Const   UB_MAGE_POLYMORPH_OTHER              As UByte = 20
Const   UB_MAGE_IDENTIFY_ITEM                As UByte = 21
Const   UB_MAGE_SLEEP3                       As UByte = 22
Const   UB_MAGE_FIRE_BOLT                    As UByte = 23
Const   UB_MAGE_SPEED_MONSTER                As UByte = 24
Const   UB_MAGE_FROST_BALL                   As UByte = 25
Const   UB_MAGE_RECHARGE_ITEM2               As UByte = 26
Const   UB_MAGE_TELEPORT_OTHER               As UByte = 27
Const   UB_MAGE_HASTE_SELF                   As UByte = 28
Const   UB_MAGE_FIRE_BALL                    As UByte = 29
Const   UB_MAGE_WORD_OF_DESTRUCTION          As UByte = 30
Const   UB_MAGE_GENOCIDE                     As UByte = 31
' ...PriestSpellTypes, player_pray.cpp
Const   UB_PRIEST_DETECT_EVIL                As UByte = 1
Const   UB_PRIEST_CURE_LIGHT_WOUNDS          As UByte = 2
Const   UB_PRIEST_BLESS                      As UByte = 3
Const   UB_PRIEST_REMOVE_FEAR                As UByte = 4
Const   UB_PRIEST_CALL_LIGHT                 As UByte = 5
Const   UB_PRIEST_FIND_TRAPS                 As UByte = 6
Const   UB_PRIEST_DETECT_DOORS_STAIRS        As UByte = 7
Const   UB_PRIEST_SLOW_POISON                As UByte = 8
Const   UB_PRIEST_BLIND_CREATURE             As UByte = 9
Const   UB_PRIEST_PORTAL                     As UByte = 10
Const   UB_PRIEST_CURE_MEDIUM_WOUNDS         As UByte = 11
Const   UB_PRIEST_CHANT                      As UByte = 12
Const   UB_PRIEST_SANCTUARY                  As UByte = 13
Const   UB_PRIEST_CREATE_FOOD                As UByte = 14
Const   UB_PRIEST_REMOVE_CURSE               As UByte = 15
Const   UB_PRIEST_RESIST_HEAD_COLD           As UByte = 16
Const   UB_PRIEST_NEUTRALIZE_POISON          As UByte = 17
Const   UB_PRIEST_ORB_OF_DRAINING            As UByte = 18
Const   UB_PRIEST_CURE_SERIOUS_WOUNDS        As UByte = 19
Const   UB_PRIEST_SENSE_INVISIBLE            As UByte = 20
Const   UB_PRIEST_PROTECT_FROM_EVIL          As UByte = 21
Const   UB_PRIEST_EARTHQUAKE                 As UByte = 22
Const   UB_PRIEST_SENSE_SURROUNDINGS         As UByte = 23
Const   UB_PRIEST_CURE_CRITICAL_WOUNDS       As UByte = 24
Const   UB_PRIEST_TURN_UNDEAD                As UByte = 25
Const   UB_PRIEST_PRAYER                     As UByte = 26
Const   UB_PRIEST_DISPEL_UNDEAD              As UByte = 27
Const   UB_PRIEST_HEAL                       As UByte = 28
Const   UB_PRIEST_DISPEL_EVIL                As UByte = 29
Const   UB_PRIEST_GLYPH_OF_WARDING           As UByte = 30
Const   UB_PRIEST_HOLY_WORD                  As UByte = 31
' ...TrapTypes, player_move.cpp
Const   UB_TRAP_OPEN_PIT                     As UByte = 1
Const   UB_TRAP_ARROW_PIT                    As UByte = 2
Const   UB_TRAP_COVERED_PIT                  As UByte = 3
Const   UB_TRAP_TRAP_DOOR                    As UByte = 4
Const   UB_TRAP_SLEEPING_GAS                 As UByte = 5
Const   UB_TRAP_HIDDEN_OBJECT                As UByte = 6
Const   UB_TRAP_DART_OF_STR                  As UByte = 7
Const   UB_TRAP_TELEPORT                     As UByte = 8
Const   UB_TRAP_ROCKFALL                     As UByte = 9
Const   UB_TRAP_CORRODING_GAS                As UByte = 10
Const   UB_TRAP_SUMMON_MONSTER               As UByte = 11
Const   UB_TRAP_FIRE_TRAP                    As UByte = 12
Const   UB_TRAP_ACID_TRAP                    As UByte = 13
Const   UB_TRAP_POISON_GAS_TRAP              As UByte = 14
Const   UB_TRAP_BLINDING_GAS                 As UByte = 15
Const   UB_TRAP_CONFUSE_GAS                  As UByte = 16
Const   UB_TRAP_SLOW_DART                    As UByte = 17
Const   UB_TRAP_DART_OF_CON                  As UByte = 18
Const   UB_TRAP_SECRET_DOOR                  As UByte = 19
Const   UB_TRAP_SCARE_MONSTER                As UByte = 99
Const   UB_TRAP_GENERAL_STORE                As UByte = 101
Const   UB_TRAP_ARMORY                       As UByte = 102
Const   UB_TRAP_WEAPONSMITH                  As UByte = 103
Const   UB_TRAP_TEMPLE                       As UByte = 104
Const   UB_TRAP_ALCHEMIST                    As UByte = 105
Const   UB_TRAP_MAGIC_SHOP                   As UByte = 106

' --- MORIA'S ENUMS, by Moria's names: what each kind of food, potion, staff, wand, spell, prayer and trap does ---
' ...InnerRoomTypes, dungeon_generate.cpp
Const   UB_INNER_ROOM_PLAIN                  As UByte = 1
Const   UB_INNER_ROOM_TREASURE_VAULT         As UByte = 2
Const   UB_INNER_ROOM_PILLARS                As UByte = 3
Const   UB_INNER_ROOM_MAZE                   As UByte = 4
Const   UB_INNER_ROOM_FOUR_SMALL_ROOMS       As UByte = 5

' --- THE WALKING STAGE'S OWN ---
#define MB_REPEAT_DONE              128     ' gub_game_repeat_key: the command has been done once, use the direction it had (use_last_direction)
#define UB_HOLD_FRAMES              16      ' a key held this many frames, a third of a second, goes on repeating its command
#define UB_STEP_NONE                0       ' gub_game_step_code, what the walking stage does after a command: nothing...
#define UB_STEP_DISARMED            1       ' ...step on to the trap just disarmed
#define UB_STEP_SET_OFF             2       ' ...step on to the trap just set off
#define UB_STEP_PLAIN               3       ' ...a plain step that picks nothing up

' --- FILES, see fub_core_file_transfer() in core.bas ---
Const   UB_FILE_NAME_MAX            As UByte    = 63
Const   UB_FILE_SLOT_WHOLE          As UByte    = 255   ' gub_core_file_slot: a file of one page and no more
Const   UB_FILE_SLOT_DONE           As UByte    = 254   ' ...the file of many pages is finished with, it is closed
Const   UB_FILE_RESULT_BAD_NAME     As UByte    = 254   ' what the file routines answer: 0 if it worked, this for a name too long or empty
Const   UB_FILE_RESULT_SHORT        As UByte    = 255   ' ...or this for fewer bytes than a page read or written
Const   MB_FILE_PLAN_OPEN           As UByte    = 1     ' gub_core_file_plan, the steps a call takes: open the file
Const   MB_FILE_PLAN_SEEK           As UByte    = 2     ' seek to the page's place in it
Const   MB_FILE_PLAN_CLOSE          As UByte    = 4     ' close it afterwards
Const   MB_FILE_PLAN_NO_DATA        As UByte    = 8     ' read or write nothing at all
Const   UB_FILE_MODE_WRITE_NEW      As UByte    = $0E   ' NextZXOS: open for writing ($02), creating it and deleting any there was ($0C)
Const   UB_FILE_MODE_READ           As UByte    = $01   ' open for reading, it must exist
Const   UB_ESX_ENOENT               As UByte    = 5     ' esxDOS's error for \"No such file or dir\"
' what the save library answers to UB_LIB_SAVE_RESTORE, besides false and true
Const   UB_RESTORE_RESURRECTED      As UByte    = 2     ' a dead character brought back, in a game started as a wizard
Const   UB_RESTORE_BAD_FILE         As UByte    = 3     ' Moria's "Error during reading of file."

' the waits
Const   UL_FRAMES_PER_HOUR          As ULong    = 180000    ' s_core_get_key() gives up after an hour, at 50 frames a second
Const   UW_PAUSE_COUNT              As UInteger = 20000     ' s_core_pause(), about a second
Const   UB_ENTROPY_MULTIPLIER       As UByte    = 33        ' each key's wait is stirred into gul_core_entropy so
Const   UC_MONITOR_KEY              As UByte    = 125       ' }, the core's own key: the live monitor, the memory, then with MMU 2's misses, then off

' --- ZX NEXT HARDWARE ---
' some addresses are an IO address, other addresses are a RAM address
#define A_NEXTREG_SELECT    $243B
#define A_NEXTREG_DATA      $253B
#define UB_DIVMMC_PORT      $E3     ' divMMC control
#define A_Z80_CPU_STACK     $FFFE   ' i.e. one byte before last byte to cater for 16-bit width of 'SP' (the Stack Pointer)

' the Next registers this program writes or reads, by their names in the official list, docs\nextzxos\registers.txt
#define NEXTREG_MACHINE_ID           $00         ' Machine ID
#define NEXTREG_VERSION              $01         ' Core Version
#define NEXTREG_RESET                $02         ' Reset
#define NEXTREG_PERIPHERAL_1         $05         ' Peripheral 1 Setting: joysticks, 50/60Hz, scandoubler
#define NEXTREG_PERIPHERAL_2         $06         ' Peripheral 2 Setting
#define NEXTREG_CPU_SPEED            $07         ' CPU Speed, see UB_CPU_SPEED_ below
#define NEXTREG_PERIPHERAL_3         $08         ' Peripheral 3 Setting
#define NEXTREG_JOYSTICK_IO          $0B         ' Joystick I/O Mode
#define NEXTREG_VIDEO_TIMING         $11         ' Video Timing, writable in config mode only
#define NEXTREG_LAYER2_BANK          $12         ' Layer 2 Active RAM bank
#define NEXTREG_TRANSPARENCY         $14         ' Global Transparency Colour
#define NEXTREG_SPRITES_LAYERS       $15         ' Sprite and Layers System
#define NEXTREG_CLIP_LAYER2          $18         ' Clip Window Layer 2
#define NEXTREG_CLIP_ULA             $1A         ' Clip Window ULA
#define NEXTREG_CLIP_TILEMAP         $1B         ' Clip Window Tilemap
#define NEXTREG_CLIP_CONTROL         $1C         ' Clip Window control
#define NEXTREG_LINE_INTERRUPT       $22         ' Line Interrupt control
#define NEXTREG_TILEMAP_X_MSB        $2F         ' Tilemap X Scroll MSB
#define NEXTREG_TILEMAP_X_LSB        $30         ' Tilemap X Scroll LSB
#define NEXTREG_TILEMAP_Y            $31         ' Tilemap Offset Y
#define NEXTREG_PALETTE_INDEX        $40         ' Palette Index
#define NEXTREG_PALETTE_VALUE        $41         ' Palette Value, 8 bit colour
#define NEXTREG_PALETTE_CONTROL      $43         ' Palette Control
#define NEXTREG_PALETTE_VALUE_9      $44         ' Palette Value, 9 bit colour
#define NEXTREG_FALLBACK_COLOUR      $4A         ' Fallback Colour
#define NEXTREG_SPRITE_TRANSPARENCY  $4B         ' Sprite Transparency Index
#define NEXTREG_COPPER_CONTROL       $62         ' Copper Control
#define NEXTREG_ULA_CONTROL          $68         ' ULA Control
#define NEXTREG_DISPLAY_CONTROL_1    $69         ' Display Control 1
#define NEXTREG_TILEMAP_CONTROL      $6B         ' Tilemap Control
#define NEXTREG_TILEMAP_ATTRIBUTE    $6C         ' Default Tilemap Attribute
#define NEXTREG_TILEMAP_BASE         $6E         ' Tilemap Base Address
#define NEXTREG_TILE_DEFINITIONS     $6F         ' Tile Definitions Base Address
#define NEXTREG_LAYER2_CONTROL       $70         ' Layer 2 Control
#define NEXTREG_MEMORY_128K          $8E         ' Spectrum 128K Memory Mapping
#define NEXTREG_MEMORY_MAPPING       $8F         ' Memory Mapping Mode
#define NEXTREG_EXT_KEYS_0           $B0         ' Extended Keys 0: bit 7 ;   6 "   5 ,   4 .   3 up   2 down   1 left   0 right
#define NEXTREG_EXT_KEYS_1           $B1         ' Extended Keys 1: bit 7 delete   6 edit   5 break   4 inv video   3 true video   2 graph   1 caps lock   0 extend
#define MB_RESET_SOFT               %00000001   ' NEXTREG_RESET: a soft reset
' NEXTREG_TILEMAP_CONTROL's bits
#define MB_TILEMAP_ENABLE           %10000000
#define MB_TILEMAP_80_COLS          %01000000   ' 80 x 32, not 40 x 32
#define MB_TILEMAP_NO_ATTRIBUTES    %00100000   ' one byte a cell, the attribute from NEXTREG_TILEMAP_ATTRIBUTE
#define MB_TILEMAP_PALETTE_2        %00010000   ' the second tilemap palette
#define MB_TILEMAP_TEXT_MODE        %00001000   ' one bit a pixel, 8 bytes a character
#define MB_TILEMAP_512_TILES        %00000010   ' an attribute's bit 0 is the ninth bit of the character
#define MB_TILEMAP_ON_TOP           %00000001   ' the tilemap on top of the ULA

' machine speed, NEXTREG_CPU_SPEED
Const   UB_CPU_SPEED_3MHZ           As UByte    = 0          ' 00 =  3.5 MHz (original Z80 speed)
Const   UB_CPU_SPEED_7MHZ           As UByte    = 1          ' 01 =  7 MHz mode
Const   UB_CPU_SPEED_14MHZ          As UByte    = 2          ' 10 = 14 MHz mode
Const   UB_CPU_SPEED_28MHZ          As UByte    = 3          ' 11 = 28 MHz mode
' N.B: the bits of the tilemap's and Peripheral 1's registers were here until 21 October 2026, unused, and wrong
' for all but a few of them, as were the keyboard's port masks, unused since fub_core_scan_key() in core.bas came

' --- ZX NEXT / Z80 MMU SLOTS ---
' the slot numbers
#define MMU_SLOT_0                  $50
#define MMU_SLOT_1                  $51
#define MMU_SLOT_2                  $52
#define MMU_SLOT_3                  $53
#define MMU_SLOT_4                  $54
#define MMU_SLOT_5                  $55
#define MMU_SLOT_6                  $56
#define MMU_SLOT_7                  $57

' slot principal usage
Const   MMU_SLOT_CORE_CODE          As UByte = MMU_SLOT_4  ' and also slot 5...
Const   MMU_SLOT_CORE_DATA          As UByte = MMU_SLOT_6
#define MMU_SLOT_PAGED_CODE         MMU_SLOT_3
Const   MMU_SLOT_CORE_SCREEN        As UByte = MMU_SLOT_7
Const   MMU_SLOT_PAGED_MONSTERS     As UByte = MMU_SLOT_0  ' the three paged data slots, each known by the names of what goes in it...
Const   MMU_SLOT_PAGED_CORRIDORS    As UByte = MMU_SLOT_0  ' ...the corridor scratchpad shares MMU 0 with the monsters, it is only needed while a dungeon is being dug
Const   MMU_SLOT_PAGED_ITEMS        As UByte = MMU_SLOT_1
Const   MMU_SLOT_PAGED_SCENT_MAP    As UByte = MMU_SLOT_1  ' ...the scent map shares MMU 1 with the items, while scent is being worked out no items are needed
Const   MMU_SLOT_PAGED_DB_MAPS       As UByte = MMU_SLOT_2

' slot addresses
#define A_MMU_SLOT_0    $0000   ' to $1FFF
#define A_MMU_SLOT_1    $2000   ' to $3FFF
#define A_MMU_SLOT_2    $4000   ' to $5FFF
#define A_MMU_SLOT_3    $6000   ' to $7FFF
#define A_MMU_SLOT_4    $8000   ' to $9FFF
#define A_MMU_SLOT_5    $A000   ' to $BFFF
#define A_MMU_SLOT_6    $C000   ' to $DFFF, size 8192
#define A_MMU_SLOT_7    $E000   ' to $FFFF

' slot principal usage
#define A_MMU_SLOT_PAGED_MONSTERS   A_MMU_SLOT_0
#define A_MMU_SLOT_PAGED_CORRIDORS  A_MMU_SLOT_0
#define A_MMU_SLOT_PAGED_ITEMS      A_MMU_SLOT_1
#define A_MMU_SLOT_PAGED_SCENT_MAP  A_MMU_SLOT_1
#define A_MMU_SLOT_PAGED_DB_MAPS    A_MMU_SLOT_2
#define A_MMU_SLOT_PAGED_CODE       A_MMU_SLOT_3
#define A_MMU_SLOT_CORE_CODE        A_MMU_SLOT_4    ' and also slot 5...
#define A_MMU_SLOT_CORE_DATA        A_MMU_SLOT_6    ' size 8192
#define A_MMU_SLOT_CORE_SCREEN      A_MMU_SLOT_7

'#################################################################################################################################
' the 8KB page layout, for a ZX Next with 2MB RAM, i.e. 256 pages, of which we may use 30 to 223...
' ...the data is packed together at the bottom of that range, so that everything above it, 128 pages, is free for paged code
'   0-17        reserved by NextZXOS for itself (its API document says so), of which we use only these two:
'   10          font, in its first 2KB only             never mapped by us (the rest of the page holds the system variables)
'   11          core  screen cells, Z80 stack           MMU 7
'   18-29       NextZXOS's Layer 2 screen and its shadow, we do not use Layer 2 but we leave them alone
'   30,31       core  code                              MMU 4,5
'   32          core  data, heap                        MMU 6
'   33          paged dungeon   monsters    1 page      MMU 0   125 monsters of 64 bytes (128 fit)
'   34          paged town      monsters    1 page      "
'   35          paged dungeon   corridors   1 page      "       the level maker's working lists, used only while a dungeon level is being dug
'   36-37       paged dungeon   items       2 pages     MMU 1   175 items of 64 bytes (256 fit)
'   38-39       paged town      items       2 pages     "
'   40-41       paged store     items       2 pages     "       6 stores of 24 items
'   42-46       paged scent     map         5 pages     "       80 rows of 256 squares of 2 bytes, i.e. 16 rows to a page (a level is 66 rows)
'   47-49       paged creatures DB          3 pages     MMU 2   279 creature types of 64 bytes (384 fit)
'   50-53       paged objects   DB          4 pages     "       420 object types of 64 bytes (512 fit)
'   54          paged game      tables      1 page      "       small tables that never change: the store owners, what the stores stock, race prices
'   55-56       paged strings   index       2 pages     "       room for 4096 strings, 4 bytes each: page, offset (2 bytes), length + 1
'   57-62       paged strings   text        6 pages     "       packed end to end, each ending in a 0, none crossing a page boundary
'   63          paged knowledge             1 page      "       what the player has learnt: about each creature type (279 of 20 bytes), and about items
'   64-65       paged screens               2 pages     "       whole screens of text: the opening screen and the credits
'   66-82       paged dungeon   map        17 pages     "       68 rows of 256 squares of 8 bytes, i.e. 4 rows to a page (a level is 66 rows)
'                                                               N.B: until the game runs, 66-75 hold the Next's opening picture and 76 the font,
'                                                               the loader's, see sjasmplus.cfg and load.bas
'   83-88       paged town      map         6 pages     "       laid out exactly as the dungeon map is, so that one routine serves both, 24 rows (the town is 22)
'   89-94       scratch pages: the saved game list, a file's page on its way to or from the card
'   95          paged character DB          1 page      MMU 2   races, classes and backgrounds, for making a new character
'   96-223      paged game      code      128 pages     MMU 3   one stage to a page
'   224-255     must not use beyond 1.75 MB, as these pages are too slow on older ZX Next models
'##################################################################################################################################

' --- ZX NEXT 8KB PAGE NUMBERS WITHIN THE 2MB RAM ---
#define UB_PAGE_CORE_CODE           30   '  2 pages, 16KB
#define UB_PAGE_ROM                 255  ' the Next's number for the ROM in an MMU slot, as the system's file calls want it
#define UB_PAGE_NONE                255  ' ...and so, kept for a slot, nothing of ours is in it (see the gub_core_MMU0_page_number and so on)
#define UB_PAGE_SYSTEM_VARIABLES    10   ' the system's own page, which the file calls need in MMU 2, see fub_core_file_transfer()
#define UW_PAGE_SIZE                8192
#define UB_PAGE_CORE_DATA           32
#define UB_PAGE_FONT                10   ' never mapped by us, the display hardware reads it directly
#define UB_PAGE_CORE_SCREEN         11   ' the screen cells, and above them the core's stack

' the paged game data, the first page of each kind, see the plan above for how many pages each has...
#define UB_PAGE_DUNGEON_MONSTERS    33
#define UB_PAGE_TOWN_MONSTERS       34
#define UB_PAGE_CORRIDORS           35
#define UB_PAGE_DUNGEON_ITEMS       36
#define UB_PAGE_TOWN_ITEMS          38
#define UB_PAGE_STORE_ITEMS         40
#define UB_PAGE_SCENT_MAP           42
#define UB_PAGE_MESSAGES            42    ' the last messages, for Ctrl-P, see s_core_history_push() in core.bas, N.B: the scent map was never used, Umoria has no such thing, this is its first page
Const   UB_MESSAGE_HISTORY          As UByte    = 22    ' how many messages are kept, 80 bytes each (MESSAGE_HISTORY_SIZE)
Const   UB_MESSAGE_SIZE             As UByte    = 80    ' the bytes each message is kept in, Moria's MORIA_MESSAGE_SIZE
#define UB_PAGE_SCORES              43    ' the high scores, as they are in the file scores.dat, see stage-lib-scores.bas, the second of the unused scent map's pages
#define UB_PAGE_MINIMAP             44    ' ours: the mini map's bitmap, one bit for each square of the level, 32 bytes a row, see stage-lib-minimap.bas
#define A_MESSAGE_LINE              A_MMU_SLOT_CORE_DATA + 6912     ' size 80, the message that is showing, between the player's record and the heap
#define UB_PAGE_CREATURES_DB        47
#define UB_PAGE_OBJECTS_DB          50
#define UB_PAGE_GAME_TABLES         54
#define UB_PAGE_STRINGS_INDEX       55
#define UB_PAGE_STRINGS_TEXT        57
' ...the index: 2048 strings to a page, 4 bytes each: the page of the text, its offset (2 bytes), its length + 1
Const   UB_STRINGS_PAGE_SHIFT       As UByte    = 11    ' a string's number shifted down this far is its index page
Const   UW_STRINGS_PAGE_MASK        As UInteger = 2047  ' and this much of it is its place in that page
Const   UB_STRING_ENTRY_SHIFT       As UByte    = 2     ' 4 bytes an entry
Const   UB_STRING_ENTRY_LENGTH      As UByte    = 3     ' where in an entry the length is
#define UB_PAGE_KNOWLEDGE           63    ' monster memory in its first 5580 bytes, item knowledge from 6144
#define UW_MONSTER_MEMORY_SIZE      5580                ' 279 creature types of 20 bytes, at the start of UB_PAGE_KNOWLEDGE
' ...and each kind's 20 bytes, laid out as Moria's Recall_t, see ful_core_recall() in core.bas
Const   UB_RECALL_SIZE              As UByte    = 20
Const   UB_RECALL_OFFSET_SPELLS     As UByte    = 4     ' after the movement, 4 bytes each
Const   UB_RECALL_OFFSET_KILLS      As UByte    = 8
Const   UB_RECALL_OFFSET_DEATHS     As UByte    = 10
Const   UB_RECALL_OFFSET_DEFENSES   As UByte    = 12
Const   UB_RECALL_OFFSET_WAKE       As UByte    = 14    ' then ignore and the four attacks, a byte each
Const   UW_RECALL_COUNT_MAX         As UInteger = 32767 ' kills and deaths stop here, Moria's SHRT_MAX
Const   UB_RECALL_BYTE_MAX          As UByte    = 255   ' wake, ignore and the attacks stop here
#define UB_PAGE_SCREENS             64
#define UB_PAGE_LOADER_FONT         76    ' where the nex file holds the font, until load.bas copies it to UB_PAGE_FONT, see sjasmplus.cfg
#define UB_BANK_LOADER_PICTURE      33    ' the opening's Next picture, in 16KB banks for Layer 2 (pages 66 to 75), ditto
#define UB_PAGE_DUNGEON_MAP         66
#define UB_PAGE_TOWN_MAP            83

' scratch pages, which hold none of the game's own data: they were the start up tests' (stage-init.bas, a screen of
' tests that ran before the opening screen, taken out on 14 October 2026), they now hold the saved game list, see
' stage-lib-save.bas, and a file's 8KB on its way to or from the card, UB_PAGE_TEST_FILE, the names are as they were
#define UB_PAGE_TEST_SLOT0_1        89
#define UB_PAGE_TEST_SLOT0_2        90
#define UB_PAGE_TEST_SLOT1_1        91
#define UB_PAGE_TEST_SLOT1_2        92
#define UB_PAGE_TEST_SLOT2_1        93
#define UB_PAGE_TEST_SLOT2_2        94
#define UB_PAGE_TEST_FILE           94    ' the file test runs after the slot tests have finished with this page

#define UB_PAGE_RESET_LANDING       222   ' the page put at the bottom of memory for the reset that ends the game, see s_core_return_to_zxos() in core.bas
#define UB_PAGE_HELP_TEXT           223   ' the last page there is: the two rogue like help texts, see stage-lib-text.bas and create-data.ps1, N.B: 219 to 222 held the licence until 13-Oct-2026 and are free
#define UB_PAGE_CHARACTER_DB        95

' the paged game code, one stage to a page, from here up to page 223...
Const   UB_PAGED_CODE_FIRST                 As UByte    = 96
' N.B: page 96 was the start up tests' stage, stage-init.bas, taken out on 14 October 2026, it is free
Const   UB_PAGED_CODE_STAGE_PLAYER          As UByte    = 97
Const   UB_PAGED_CODE_STAGE_STORE           As UByte    = 98
Const   UB_PAGED_CODE_STAGE_CREATE_TOWN     As UByte    = 99
Const   UB_PAGED_CODE_STAGE_CREATE_DUNGEON  As UByte    = 100
Const   UB_PAGED_CODE_STAGE_CRAWL           As UByte    = 101
Const   UB_PAGED_CODE_STAGE_DEATH           As UByte    = 102
Const   UB_PAGED_CODE_STAGE_SAVE            As UByte    = 103
Const   UB_PAGED_CODE_STAGE_RESTORE         As UByte    = 104
Const   UB_PAGED_CODE_STAGE_QUIT            As UByte    = 105
Const   UB_PAGED_CODE_STAGE_SPLASH          As UByte    = 106
Const   UB_PAGED_CODE_STAGE_PLAYER_CLASS    As UByte    = 107
Const   UB_PAGED_CODE_STAGE_NEW_GAME        As UByte    = 108
' ...and the libraries, pages of routines that any stage can call through the core, see s_core_call_library()
Const   UB_PAGED_CODE_LIB_ITEMS             As UByte    = 109
Const   UB_PAGED_CODE_LIB_CHARACTER         As UByte    = 110
Const   UB_PAGED_CODE_LIB_TREASURE          As UByte    = 111
Const   UB_PAGED_CODE_LIB_TREASURE_2        As UByte    = 112   ' its second half, only the first half calls this
Const   UB_PAGED_CODE_LIB_STORES            As UByte    = 113
Const   UB_PAGED_CODE_LIB_INVENTORY         As UByte    = 114
Const   UB_PAGED_CODE_LIB_HAGGLE            As UByte    = 115
Const   UB_PAGED_CODE_LIB_HAGGLE_2          As UByte    = 116   ' its second half, only the first half calls this
Const   UB_PAGED_CODE_LIB_EQUIPMENT         As UByte    = 117
Const   UB_PAGED_CODE_LIB_BONUSES           As UByte    = 118
Const   UB_PAGED_CODE_LIB_MOVES             As UByte    = 119
Const   UB_PAGED_CODE_LIB_OBJECTS           As UByte    = 120
Const   UB_PAGED_CODE_LIB_MONSTERS          As UByte    = 121
Const   UB_PAGED_CODE_LIB_MONSTER_MOVES     As UByte    = 122
Const   UB_PAGED_CODE_LIB_MONSTER_ATTACK    As UByte    = 123
Const   UB_PAGED_CODE_LIB_MONSTER_ATTACK_2  As UByte    = 124   ' its second half, only the first half calls this
Const   UB_PAGED_CODE_LIB_TURN              As UByte    = 125
Const   UB_PAGED_CODE_LIB_PLAYER_ATTACK     As UByte    = 126
Const   UB_PAGED_CODE_LIB_TURN_2            As UByte    = 127   ' its second half, only the first half calls this, and the walking stage for resting
Const   UB_PAGED_CODE_LIB_EFFECTS           As UByte    = 128
Const   UB_PAGED_CODE_LIB_CONSUME           As UByte    = 129
Const   UB_PAGED_CODE_LIB_SPELLS            As UByte    = 130
Const   UB_PAGED_CODE_LIB_SPELLS_2          As UByte    = 131
Const   UB_PAGED_CODE_LIB_READ              As UByte    = 132
Const   UB_PAGED_CODE_LIB_TRAPS             As UByte    = 133
Const   UB_PAGED_CODE_LIB_COMMANDS          As UByte    = 134
Const   UB_PAGED_CODE_LIB_MONSTER_SPELLS    As UByte    = 135
Const   UB_PAGED_CODE_LIB_SPELLS_3          As UByte    = 136
Const   UB_PAGED_CODE_LIB_SPELLS_4          As UByte    = 137
Const   UB_PAGED_CODE_LIB_SPELLS_5          As UByte    = 138
Const   UB_PAGED_CODE_LIB_DEVICES           As UByte    = 139
Const   UB_PAGED_CODE_LIB_FIGHT             As UByte    = 140
Const   UB_PAGED_CODE_LIB_THROW             As UByte    = 141
Const   UB_PAGED_CODE_LIB_MAGIC             As UByte    = 142
Const   UB_PAGED_CODE_LIB_CAST              As UByte    = 143
Const   UB_PAGED_CODE_LIB_BOOKS             As UByte    = 144
Const   UB_PAGED_CODE_LIB_ROOMS             As UByte    = 145
Const   UB_PAGED_CODE_LIB_RUN               As UByte    = 146
Const   UB_PAGED_CODE_LIB_INFO              As UByte    = 147
Const   UB_PAGED_CODE_LIB_TEXT              As UByte    = 148
Const   UB_PAGED_CODE_LIB_RECALL            As UByte    = 149
Const   UB_PAGED_CODE_LIB_RECALL_2          As UByte    = 150
Const   UB_PAGED_CODE_LIB_LOOK              As UByte    = 151
Const   UB_PAGED_CODE_LIB_CHESTS            As UByte    = 152
Const   UB_PAGED_CODE_LIB_COMPACT           As UByte    = 153
Const   UB_PAGED_CODE_LIB_MONSTER_MOVES_2   As UByte    = 154
Const   UB_PAGED_CODE_LIB_COMMANDS_2        As UByte    = 155
Const   UB_PAGED_CODE_LIB_SAVE              As UByte    = 156
Const   UB_PAGED_CODE_LIB_SCORES            As UByte    = 157
Const   UB_PAGED_CODE_LIB_WIZARD            As UByte    = 158
Const   UB_PAGED_CODE_LIB_WIZARD_2          As UByte    = 159   ' its second half, only the first half calls this
Const   UB_PAGED_CODE_LIB_WIZARD_3          As UByte    = 160   ' the superhuman command, ours, for testing
Const   UB_PAGED_CODE_LIB_MONITOR           As UByte    = 161   ' the live monitor, ours, only the core calls it
Const   UB_PAGED_CODE_LIB_CHARACTER_2       As UByte    = 162   ' its second half, only the first half calls this
Const   UB_PAGED_CODE_LIB_MINIMAP           As UByte    = 163   ' the mini map, ours, the walking stage calls it
' how the records are laid out in a page...
Const   UB_RECORD_SIZE              As UByte    = 64    ' every monster, item, creature and object record is this long...
Const   UB_RECORDS_PER_PAGE         As UByte    = 128   ' ...so this many fit in an 8KB page, and none ever crosses a page boundary
' how the whole screens of text are laid out in their pages, see create-data.ps1...
Const   UW_SCREEN_TEXT_SIZE         As UInteger = 2592  ' one screen: 32 rows of a colour byte and 80 characters
Const   UB_SCREEN_TEXT_PER_PAGE     As UByte    = 3
Const   UW_SCREEN_TEXT_COUNT_AT     As UInteger = 8191  ' the number of screens is the last byte of the second page

#define UB_MAP_SQUARE_SIZE          8           ' every map square is this long, and a row of 256 of them is 2048 bytes, 4 rows to a page
#define UW_MAP_ROW_SIZE             2048        ' ...a row of the map's pages
#define UB_MAP_ROWS_PER_PAGE        4
#define UB_MAP_ROWS_SHIFT           2           ' a row's number shifted down this far is its page, the rest of it its place there

' the three paged data slots by number, as s_core_swap_paged_data() and the record routines in the core want them...
#define UB_SLOT_MONSTERS            0     ' MMU 0
#define UB_SLOT_CORRIDORS           0
#define UB_SLOT_ITEMS               1     ' MMU 1
#define UB_SLOT_CREATURES           1     ' MMU 1 too: the creatures database, which the monsters' turn reads for every monster, shares the items' slot and not the maps', so that a monster, its creature and the map are all there at once (the live monitor counted the changes of page before and after, 13 October 2026)
#define UB_SLOT_SCENT_MAP           1
#define UB_SLOT_DB_MAPS             2     ' MMU 2

' how many records the databases hold, these are Moria's own MON_MAX_CREATURES and MAX_OBJECTS_IN_GAME
Const   UW_CREATURES_IN_GAME        As UInteger = 279
Const   UW_OBJECTS_IN_GAME          As UInteger = 420

' what the crawl stage can ask the core for when it returns...
Const   UB_REQUEST_NEW_LEVEL        As UByte    = 0     ' make the level guw_dungeon_level says, and come back
Const   UB_REQUEST_STORE            As UByte    = 1     ' go into store gub_core_store, and come back to this same level
Const   UB_REQUEST_RESUME           As UByte    = 3     ' a saved game has been brought back: carry on exactly where it was left
Const   UB_REQUEST_DEATH            As UByte    = 2     ' the player has died
Const   UB_REQUEST_RESURRECTED      As UByte    = 4     ' a dead character has been brought back by a wizard: they arrive in the town, made afresh

' --- MAIN STAGES OF PROCESSING ---
' N.B: 0 was UB_STAGE_INIT, the start up tests, taken out on 14 October 2026
Const   UB_STAGE_PLAYER             As UByte    = 1
Const   UB_STAGE_STORE              As UByte    = 2
Const   UB_STAGE_CREATE_TOWN        As UByte    = 3
Const   UB_STAGE_CREATE_DUNGEON     As UByte    = 4
Const   UB_STAGE_CRAWL              As UByte    = 5
Const   UB_STAGE_DEATH              As UByte    = 6
Const   UB_STAGE_SAVE               As UByte    = 7
Const   UB_STAGE_RESTORE            As UByte    = 8
Const   UB_STAGE_QUIT               As UByte    = 9
Const   UB_STAGE_SPLASH             As UByte    = 10
Const   UB_STAGE_PLAYER_CLASS       As UByte    = 11    ' the second half of making a character
Const   UB_STAGE_NEW_GAME           As UByte    = 12    ' what Moria sets up before the character is made


' --- DIMENSIONS OF VIEWPORT AND MAPS ---
' ...the viewport, i.e. the part of the screen that shows the map...
Const   UB_PANEL_ROWS           As UByte    = 30
Const   UB_PANEL_COLS           As UByte    = 66

' ...how the map is held in its pages, rounded up so that a square is found by shifting and never by multiplying...
Const   UW_MAP_MAX_ROWS         As UInteger = 68        ' 17 pages of 4 rows
Const   UW_MAP_MAX_COLS         As UInteger = 256

' ...the part of that which a dungeon level really uses, these are Moria's own MAX_HEIGHT and MAX_WIDTH...
Const   UW_MAP_ROWS             As UInteger = 66
Const   UW_MAP_COLS             As UInteger = 198

' ...the town...
Const   UB_STORES               As UByte    = 6         ' General Store, Armory, Weapon Smiths, Temple, Alchemy Shop, Magic Shop
Const   UB_TOWN_ROWS            As UByte    = 22        ' Moria's town is 22 rows of 66 columns, one of Moria's own screens
Const   UB_TOWN_COLS            As UByte    = UB_PANEL_COLS


' --- THE MAP SQUARE ---
' every square of a map is 8 bytes, the first four are Moria's Tile_t, find a square with fuw_core_map_square()...
Const   UB_SQUARE_FEATURE       As UByte    = 0     ' what the square is made of, one of the UB_TILE_ values below (Moria's feature_id)
Const   UB_SQUARE_FLAGS         As UByte    = 1     ' the MB_SQUARE_ bits below
Const   UB_SQUARE_MONSTER       As UByte    = 2     ' the number of the monster standing here, 0 for none (Moria's creature_id)
Const   UB_SQUARE_ITEM          As UByte    = 3     ' the number of the item lying here, 0 for none (Moria's treasure_id)
' ...bytes 4 to 7 are spare for now

' the flags, these are Moria's four...
#define MB_SQUARE_LIT_ROOM      %00000001   ' part of a room that is lit, walls with this set are lit once tunnelled out (perma_lit_room)
#define MB_SQUARE_FIELD_MARK    %00000010   ' the trap, door or stairs here has been found, it is hidden until this is set (field_mark)
#define MB_SQUARE_PERM_LIGHT    %00000100   ' permanently lit, used for walls and lit rooms (permanent_light)
#define MB_SQUARE_TEMP_LIGHT    %00001000   ' lit for the moment, by the player's lamp etc. (temporary_light)

' what a square is made of, Moria's "fval" numbers, the order matters: everything up to UB_TILE_MAX_OPEN can be walked through,
' and everything from UB_TILE_MIN_WALL upwards is wall
Const   UB_TILE_NULL_WALL       As UByte    = 0     ' nothing here yet
Const   UB_TILE_DARK_FLOOR      As UByte    = 1
Const   UB_TILE_LIGHT_FLOOR     As UByte    = 2
Const   UB_TILE_CORR_FLOOR      As UByte    = 3
Const   UB_TILE_BLOCKED_FLOOR   As UByte    = 4     ' a corridor square with a closed, stuck or secret door, or rubble
Const   UB_TILE_MAX_OPEN        As UByte    = 3
Const   UB_TILE_MIN_CLOSED      As UByte    = 4
Const   UB_TILE_TMP1_WALL       As UByte    = 8     ' used only while a level is being made
Const   UB_TILE_TMP2_WALL       As UByte    = 9     ' ditto
#define UB_TILE_MIN_WALL        12
Const   UB_TILE_GRANITE_WALL    As UByte    = 12
Const   UB_TILE_MAGMA_WALL      As UByte    = 13
Const   UB_TILE_QUARTZ_WALL     As UByte    = 14
Const   UB_TILE_BOUNDARY_WALL   As UByte    = 15    ' the edge of the level, it can never be dug through


' --- HOW A DUNGEON LEVEL IS MADE ---
' these are Moria's own settings (config.cpp), change them and the levels stop matching the original game
Const   UB_DUN_RANDOM_DIR           As UByte    = 9     ' 1 in this many chance of a tunnel going in a random direction
Const   UB_DUN_DIR_CHANGE           As UByte    = 70    ' chance of a tunnel changing direction (99 max)
Const   UB_DUN_TUNNELING            As UByte    = 15    ' chance of extra tunnelling
Const   UB_DUN_ROOMS_MEAN           As UByte    = 32    ' mean number of rooms, with a standard deviation of 2
Const   UB_DUN_ROOM_DOORS           As UByte    = 25    ' % chance of a door where a tunnel enters a room
Const   UB_DUN_TUNNEL_DOORS         As UByte    = 15    ' % chance of a door at a tunnel junction
Const   UB_DUN_STREAMER_DENSITY     As UByte    = 5
Const   UB_DUN_STREAMER_WIDTH       As UByte    = 2
Const   UB_DUN_MAGMA_STREAMER       As UByte    = 3     ' number of magma streamers
Const   UB_DUN_MAGMA_TREASURE       As UByte    = 90    ' 1 in this many chance of treasure in each square of magma
Const   UB_DUN_QUARTZ_STREAMER      As UByte    = 2     ' number of quartz streamers
Const   UB_DUN_QUARTZ_TREASURE      As UByte    = 40    ' 1 in this many chance of treasure in each square of quartz
Const   UW_DUN_UNUSUAL_ROOMS        As UInteger = 300   ' the deeper the level the likelier an unusual room, level in this many
Const   UB_DUN_GREAT_ITEM           As UByte    = 12    ' 1 in this many chance of an item being a great one
' ...rooms are placed on a grid of half screens, Moria's screen being 22 rows of 66 columns
Const   UB_DUN_SCREEN_ROWS          As UByte    = 22
Const   UB_DUN_SCREEN_COLS          As UByte    = 66
Const   UB_DUN_MAX_ITEMS            As UByte    = 175   ' the most items a level can hold (LEVEL_MAX_OBJECTS)
Const   UB_DUN_OBJECTS_PER_ROOM     As UByte    = 7     ' mean number of objects put in the rooms of a level (LEVEL_OBJECTS_PER_ROOM)
Const   UB_DUN_OBJECTS_PER_CORRIDOR As UByte    = 2     ' ...and anywhere at all, corridors included (LEVEL_OBJECTS_PER_CORRIDOR)
Const   UB_DUN_TOTAL_GOLD           As UByte    = 2     ' mean number of heaps of gold and gems (LEVEL_TOTAL_GOLD_AND_GEMS)
Const   UB_DUN_TREASURE_MAX_LEVELS  As UByte    = 50    ' the deepest level that objects are graded for (TREASURE_MAX_LEVELS)

' which objects are found at which depth, these two tables share the last page of the objects database, after the last object...
' ...see "object levels" in create-data.ps1
#define UB_PAGE_OBJECT_LEVELS       53
#define A_TABLE_TREASURE_LEVELS     A_MMU_SLOT_PAGED_DB_MAPS + 4096     ' 51 entries of 2 bytes: how many objects are found at this depth or above (treasure_levels)
#define A_TABLE_SORTED_OBJECTS      A_MMU_SLOT_PAGED_DB_MAPS + 4224     ' 344 object numbers of 2 bytes, in order of depth (sorted_objects)
' ...and so do the spells, see "spells" in create-data.ps1
#define A_TABLE_SPELLS              A_MMU_SLOT_PAGED_DB_MAPS + 5120     ' 5 classes of 31 spells of 4 bytes: level, mana, chance of failing, experience / 4 (magic_spells), the class is its number less 1
#define A_TABLE_SPELL_NAMES         A_MMU_SLOT_PAGED_DB_MAPS + 5760     ' 62 names of 28 bytes, the 31 spells then the 31 prayers (spell_names)
#define UB_SPELL_SIZE               4       ' a spell in A_TABLE_SPELLS
#define UB_CLASS_SPELLS_SIZE        124     ' a class's 31 spells in A_TABLE_SPELLS
#define UB_SPELL_NAME_SIZE          28      ' a name in A_TABLE_SPELL_NAMES

' the objects database numbers of the things the level maker puts down, and the object categories it asks about
Const   UW_OBJ_OPEN_DOOR            As UInteger = 367
Const   UW_OBJ_CLOSED_DOOR          As UInteger = 368
Const   UW_OBJ_SECRET_DOOR          As UInteger = 369
Const   UW_OBJ_UP_STAIR             As UInteger = 370
Const   UW_OBJ_DOWN_STAIR           As UInteger = 371
Const   UW_OBJ_STORE_DOOR           As UInteger = 372   ' the first of the 6 store doors, in the order of the stores
Const   UW_OBJ_GOLD_LIST            As UInteger = 399   ' the first of the 18 kinds of gold and gems
Const   UW_OBJ_TRAP_LIST            As UInteger = 378   ' the first of the 18 kinds of trap
Const   UB_OBJ_MAX_TRAPS            As UByte    = 18
Const   UW_OBJ_RUBBLE               As UInteger = 396
Const   UW_OBJ_MUSH                 As UInteger = 397   ' the mushroom that the create food spell makes
Const   UW_OBJ_SCARE_MON            As UInteger = 398   ' the rune of protection
Const   UB_OBJ_GOLD_TYPES           As UByte    = 18
Const   UB_TV_GOLD                  As UByte    = 100
Const   UB_TV_MIN_DOORS             As UByte    = 104   ' categories from here up are doors and stairs
' --- SCREEN TILE CHARACTERS ---
Const   UC_CHAR_WALL        As UByte = 35  ' #
Const   UC_CHAR_WALL_PERM   As UByte = 35  ' #
Const   UC_CHAR_WALL_DIG    As UByte = 37  ' % (optional for diggable rock)
Const   UC_CHAR_FLOOR_ROOM  As UByte = 46  ' .
Const   UC_CHAR_FLOOR_CORR  As UByte = 46  ' .
Const   UC_CHAR_DOOR_OPEN   As UByte = 39  ' '
Const   UC_CHAR_DOOR_CLOSED As UByte = 43  ' +
Const   UC_CHAR_STAIRS_UP   As UByte = 60  ' <
Const   UC_CHAR_STAIRS_DOWN As UByte = 62  ' >


' --- PLAYER CONSTANTS ---
Const   UB_PACK_SIZE        As UByte = 22   ' the places in the pack, and so the number of the first piece of equipment in the one list (Moria's PlayerEquipment::Wield)
Const   UB_INVENTORY_SIZE   As UByte = 34   ' the pack and the equipment together (PLAYER_INVENTORY_SIZE)
Const   UB_MAX_EQUIPMENT    As UByte = 11   ' i.e. 12 items of player's worn equipment and clothing
Const   UB_MAX_INVENTORY    As UByte = 21   ' i.e. 22 items in player's pack, items "a" to "v"

' equipment slot constants (a-l)
' N.B: these are in Moria's own order (PlayerEquipment in inventory.h), the order the slots are stored and listed in
Const   UB_EQUIP_WIELD      As UByte = 0   ' the weapon in hand
Const   UB_EQUIP_HEAD       As UByte = 1   ' cap, helmet, crown
Const   UB_EQUIP_NECK       As UByte = 2   ' amulet
Const   UB_EQUIP_BODY       As UByte = 3   ' armour
Const   UB_EQUIP_ARM        As UByte = 4   ' shield
Const   UB_EQUIP_HANDS      As UByte = 5   ' gloves, gauntlets
Const   UB_EQUIP_RIGHT      As UByte = 6   ' ring on the right hand
Const   UB_EQUIP_LEFT       As UByte = 7   ' ring on the left hand
Const   UB_EQUIP_FEET       As UByte = 8   ' shoes, boots
Const   UB_EQUIP_OUTER      As UByte = 9   ' cloak, robe
Const   UB_EQUIP_LIGHT      As UByte = 10  ' torch, lamp
Const   UB_EQUIP_AUXILIARY  As UByte = 11  ' a spare weapon, swapped with the one in hand

' --- SOME KEYBOARD CONSTANTS ---
' ...for the extended keys (above 127 to avoid standard ASCII)
Const   UW_KEY_UP           As UInteger = 130
Const   UW_KEY_DOWN         As UInteger = 131
Const   UW_KEY_LEFT         As UInteger = 132
Const   UW_KEY_RIGHT        As UInteger = 133
Const   UW_KEY_INSERT       As UInteger = 134
Const   UW_KEY_DELETE       As UInteger = 135
Const   UW_KEY_HOME         As UInteger = 136
Const   UW_KEY_END          As UInteger = 137
Const   UW_KEY_PGUP         As UInteger = 138
Const   UW_KEY_PGDN         As UInteger = 139
' ...and the Spectrum's own special keys, a real Next has a dedicated key for each, a classic keyboard uses caps shift + a digit
Const   UW_KEY_EDIT         As UInteger = 140   ' caps shift + 1
Const   UW_KEY_CAPS_LOCK    As UInteger = 141   ' caps shift + 2
Const   UW_KEY_TRUE_VIDEO   As UInteger = 142   ' caps shift + 3
Const   UW_KEY_INV_VIDEO    As UInteger = 143   ' caps shift + 4
Const   UW_KEY_GRAPH        As UInteger = 144   ' caps shift + 9
' N.B: there is no key code for extend (caps shift + symbol shift), it is our Ctrl key, see MB_KEY_CTRL and fub_core_scan_key() in core.bas

' the two registers that hold the Next keyboard's extra keys, in both a bit is 1 while its key is down
Const   UB_EXT_KEYS_ABSENT          As UByte    = 255   ' what either register reads where there is none, as if every key were down
' ...their bits, the first register's
Const   MB_EXT0_SEMICOLON           As UByte    = %10000000
Const   MB_EXT0_QUOTE               As UByte    = %01000000
Const   MB_EXT0_COMMA               As UByte    = %00100000
Const   MB_EXT0_FULL_STOP           As UByte    = %00010000
Const   MB_EXT0_UP                  As UByte    = %00001000
Const   MB_EXT0_DOWN                As UByte    = %00000100
Const   MB_EXT0_LEFT                As UByte    = %00000010
Const   MB_EXT0_RIGHT               As UByte    = %00000001
' ...and the second's
Const   MB_EXT1_DELETE              As UByte    = %10000000
Const   MB_EXT1_EDIT                As UByte    = %01000000
Const   MB_EXT1_BREAK               As UByte    = %00100000
Const   MB_EXT1_INV_VIDEO           As UByte    = %00010000
Const   MB_EXT1_TRUE_VIDEO          As UByte    = %00001000
Const   MB_EXT1_GRAPH               As UByte    = %00000100
Const   MB_EXT1_CAPS_LOCK           As UByte    = %00000010
Const   MB_EXT1_EXTEND              As UByte    = %00000001

' the 8 x 5 matrix every Spectrum keyboard has: eight half rows read through port $FE, five keys in each, a key's
' bit is 0 while it is down; a key's place in it is its half row times 5 plus its bit, as in fub_core_scan_key()
Const   UB_KEY_MATRIX_ROWS          As UByte    = 8
Const   UB_KEY_MATRIX_COLS          As UByte    = 5
Const   MB_KEY_MATRIX_ROW           As UByte    = %00011111     ' the five keys of a half row
#define UB_ULA_PORT                 $FE         ' the ULA's port, the low byte: the keyboard, the border's colour (bits 2-0) and the speaker (bit 4)
#define UB_KEY_HALF_ROW_SPACE       $7F         ' the high byte that reads the half row with space, $7FFE...
#define UB_KEY_HALF_ROW_CAPS        $FE         ' ...and the one with caps shift, $FEFE, both of them down is BREAK
#define UB_BORDER_BLACK             0           ' the border's colours, the Spectrum's own numbers
#define UB_BORDER_RED               2
#define UB_BORDER_MAGENTA           3
Const   UB_KEY_NONE                 As UByte    = 255           ' no key found, as a place in the matrix
Const   UB_KEYPOS_CAPS_SHIFT        As UByte    = 0
Const   UB_KEYPOS_1                 As UByte    = 15
Const   UB_KEYPOS_2                 As UByte    = 16
Const   UB_KEYPOS_3                 As UByte    = 17
Const   UB_KEYPOS_4                 As UByte    = 18
Const   UB_KEYPOS_5                 As UByte    = 19
Const   UB_KEYPOS_0                 As UByte    = 20
Const   UB_KEYPOS_9                 As UByte    = 21
Const   UB_KEYPOS_8                 As UByte    = 22
Const   UB_KEYPOS_7                 As UByte    = 23
Const   UB_KEYPOS_6                 As UByte    = 24
Const   UB_KEYPOS_SPACE             As UByte    = 35
Const   UB_KEYPOS_SYMBOL_SHIFT      As UByte    = 36

' character codes, ASCII, as the keys give them and the text holds them
Const   UC_BACKSPACE                As UByte    = 8     ' delete on a Spectrum, caps shift + 0
Const   UC_ENTER                    As UByte    = 13
Const   UC_CONTROL_Z                As UByte    = 26    ' the last control code that is Ctrl and a letter, Ctrl-A is 1
Const   UC_ESCAPE                   As UByte    = 27    ' break on a Spectrum, caps shift + space
Const   UC_SPACE                    As UByte    = 32
Const   UC_FIRST_PRINTABLE          As UByte    = 33    ' !, the first character that shows something
Const   UC_QUOTE                    As UByte    = 34    ' "
Const   UC_COMMA                    As UByte    = 44
Const   UC_FULL_STOP                As UByte    = 46
Const   UC_DIGIT_0                  As UByte    = 48
Const   UC_SEMICOLON                As UByte    = 59
Const   UC_LOWER_A                  As UByte    = 97
Const   UC_LOWER_Z                  As UByte    = 122
Const   UC_LAST_PRINTABLE           As UByte    = 126   ' ~
Const   UC_DELETE                   As UByte    = 127   ' the ASCII delete, as some keyboards send it
Const   UC_CONTROL_TO_LETTER        As UByte    = 64    ' added to Ctrl and a letter's code gives the upper case letter, 1 + 64 = A
Const   UC_LOWER_TO_CONTROL         As UByte    = 96    ' taken from a lower case letter gives Ctrl and that letter, 97 - 96 = 1
Const   UC_LOWER_TO_UPPER           As UByte    = 32    ' taken from a lower case letter gives the upper case one

Const   MB_KEY_CTRL         As UByte    = %00000001     ' extend held, i.e. caps shift + symbol shift, or the Next's EXTEND key
Const   MB_KEY_SHIFT        As UByte    = %00000010
Const   MB_KEY_SYMBOL       As UByte    = %00001000

' --- SCREEN GEOMETRY ---
Const   UB_SCREEN_ROWS          As UByte    = 32
Const   UB_SCREEN_COLS          As UByte    = 80
' the crash report on the bottom rows, see s_core_crash()
Const   UB_CRASH_FIRST_ROW      As UByte    = 29    ' the rows cleared for it, from here to the bottom
Const   UB_CRASH_ROW            As UByte    = 30
' the screen when the game has ended and the emulator cannot go back to NextZXOS, see s_core_nothing_to_return_to()
Const   UB_ENDED_TITLE_ROW      As UByte    = 14
Const   UB_ENDED_TITLE_COL      As UByte    = 31
Const   UB_ENDED_TEXT_ROW       As UByte    = 16
Const   UB_ENDED_TEXT_COL       As UByte    = 7
' text printed from memory: a guard against a missing 0, fub_core_print_text_at() prints no more than this
Const   UB_TEXT_PRINT_MAX       As UByte    = 250
Const   UB_TEXT_STRING_MAX      As UByte    = 160   ' and fs_core_text_at() makes no longer a string, Moria's longest description

' --- SCREEN ADDRESSING ---
#define A_SCREEN_BASE           $E000   ' the screen cells start at the very beginning of MMU 7 (page 14)
#define UW_SCREEN_CELLS_SIZE    5120    ' 80 columns x 32 rows of a character and an attribute byte, $E000 to $F3FF

' --- PROGRAM CRASH AND ERROR CONSTANTS ---
Const   UB_CRASH_BAD_CORE_STAGE             As UByte = 1
Const   UB_CRASH_BAD_DATA_STRUCTURE_SIZE    As UByte = 2
Const   UB_CRASH_RAMCOPY_OVERLAP            As UByte = 3

' --- PALETTE COLOURS ---
' color attribute constants for 80x32 text mode
Const UB_BLACK          As UByte = 0                ' pair 0: black ink
Const UB_BLUE           As UByte = 2                ' pair 1: blue ink
Const UB_RED            As UByte = 4                ' pair 2: red ink
Const UB_MAGENTA        As UByte = 6                ' pair 3: magenta ink
Const UB_GREEN          As UByte = 8                ' pair 4: green ink
Const UB_CYAN           As UByte = 10               ' pair 5: cyan ink
Const UB_YELLOW         As UByte = 12               ' pair 6: yellow ink
Const UB_WHITE          As UByte = 14               ' pair 7: white ink
Const UB_DARK_GREY      As UByte = 16               ' pair 8: dark grey ink
Const UB_BRIGHT_BLUE    As UByte = 18               ' pair 9: bright blue
Const UB_BRIGHT_RED     As UByte = 20               ' pair 10: bright red
Const UB_BRIGHT_MAGENTA As UByte = 22               ' pair 11: bright magenta
Const UB_BRIGHT_GREEN   As UByte = 24               ' pair 12: bright green
Const UB_BRIGHT_CYAN    As UByte = 26               ' pair 13: bright cyan
Const UB_BRIGHT_YELLOW  As UByte = 28               ' pair 14: bright yellow
Const UB_BRIGHT_WHITE   As UByte = 30               ' pair 15: bright white

' the 9-bit RGB values (%RRRGGGBBB)
' ...spaced-out 9-bit RGB constants (%RRR, %GGG, %BBB)
' ...each component is %000 to %111 (0-7)
Const   UW_BLACK_RGB          As UInteger = ( %000 Shl 6 ) Or ( %000 Shl 3 ) Or %000
Const   UW_BLUE_RGB           As UInteger = ( %000 Shl 6 ) Or ( %000 Shl 3 ) Or %101
Const   UW_RED_RGB            As UInteger = ( %101 Shl 6 ) Or ( %000 Shl 3 ) Or %000
Const   UW_MAGENTA_RGB        As UInteger = ( %101 Shl 6 ) Or ( %000 Shl 3 ) Or %101
Const   UW_GREEN_RGB          As UInteger = ( %000 Shl 6 ) Or ( %101 Shl 3 ) Or %000
Const   UW_CYAN_RGB           As UInteger = ( %000 Shl 6 ) Or ( %101 Shl 3 ) Or %101
Const   UW_YELLOW_RGB         As UInteger = ( %101 Shl 6 ) Or ( %101 Shl 3 ) Or %000
Const   UW_WHITE_RGB          As UInteger = ( %101 Shl 6 ) Or ( %101 Shl 3 ) Or %101
Const   UW_DARK_GREY_RGB      As UInteger = ( %010 Shl 6 ) Or ( %010 Shl 3 ) Or %010
Const   UW_BRIGHT_BLUE_RGB    As UInteger = ( %000 Shl 6 ) Or ( %000 Shl 3 ) Or %111
Const   UW_BRIGHT_RED_RGB     As UInteger = ( %111 Shl 6 ) Or ( %000 Shl 3 ) Or %000
Const   UW_BRIGHT_MAGENTA_RGB As UInteger = ( %111 Shl 6 ) Or ( %000 Shl 3 ) Or %111
Const   UW_BRIGHT_GREEN_RGB   As UInteger = ( %000 Shl 6 ) Or ( %111 Shl 3 ) Or %000
Const   UW_BRIGHT_CYAN_RGB    As UInteger = ( %000 Shl 6 ) Or ( %111 Shl 3 ) Or %111
Const   UW_BRIGHT_YELLOW_RGB  As UInteger = ( %111 Shl 6 ) Or ( %111 Shl 3 ) Or %000
Const   UW_BRIGHT_WHITE_RGB   As UInteger = ( %111 Shl 6 ) Or ( %111 Shl 3 ) Or %111

'##################################################################################################################################
' --- CORE API JUMP TABLE ---
' core.bas places one "jp <routine>" every three bytes starting at $8010, in exactly this order...
' ...the paged stages reach the core routines through these fixed addresses (see stage-include.bas)...
' ...so the core can be recompiled, and its routines can move around, without recompiling the stages...
#define A_JUMP_NEXT_REG            $8010
#define A_JUMP_CRASH               $8013
#define A_JUMP_RAM_COPY            $8016
#define A_JUMP_CLEAR_SCREEN        $8019
#define A_JUMP_PRINT_CHAR_AT       $801C
#define A_JUMP_PRINT_STRING_AT     $801F
#define A_JUMP_GET_KEY             $8022
#define A_JUMP_SPARE1              $8025     ' spare, free for a new core routine: was s_core_countdown(), taken out 21 October 2026, goes to s_core_crash() meanwhile
#define A_JUMP_NUMBER              $8028
#define A_JUMP_SCAN_KEY            $802B
#define A_JUMP_KEY_NAME            $802E
#define A_JUMP_SWAP_PAGED_DATA      $8031
#define A_JUMP_FILE_SAVE_PAGE       $8034
#define A_JUMP_FILE_LOAD_PAGE       $8037
#define A_JUMP_RANDOM_SEED          $803A
#define A_JUMP_RANDOM               $803D
#define A_JUMP_RANDOM_NUMBER        $8040
#define A_JUMP_DICE_ROLL            $8043
#define A_JUMP_RECORD_ADDRESS       $8046
#define A_JUMP_FETCH_RECORD         $8049
#define A_JUMP_STORE_RECORD         $804C
#define A_JUMP_MAP_SQUARE           $804F
#define A_JUMP_TEXT_AT              $8052
#define A_JUMP_RANDOM_NORMAL        $8055
#define A_JUMP_CALL_LIBRARY         $8058
#define A_JUMP_PRINT_TEXT_AT        $805B
#define A_JUMP_RECALL               $805E
#define A_JUMP_MESSAGE              $8061
#define A_JUMP_MESSAGE_AFTER        $8064
#define A_JUMP_DIRECTION_KEY        $8067
#define A_JUMP_MAP_SYMBOL           $806A
#define A_JUMP_MAP_PUT              $806D
#define A_JUMP_MAP_DRAW_PANEL       $8070
#define A_JUMP_MAP_LIGHT_ROOM       $8073
#define A_JUMP_MAP_OUTSIDE_PANEL    $8076
#define A_JUMP_MSG_TEXT             $8079
#define A_JUMP_MSG_CLEAR            $807C
#define A_JUMP_MSG_FLUSH            $807F
#define A_JUMP_MSG                  $8082
#define A_JUMP_LIB_CALL             $8085
#define A_JUMP_RANDOM_WORD          $8088
#define A_JUMP_CHAR                 $808B
#define A_JUMP_CLEAR_ROW            $808E
#define A_JUMP_HISTORY_FORGET       $8091
#define A_JUMP_BEEP                 $8094

' --- INTERRUPTS ---
' we use interrupt mode 2, so that the handler can live in the core and nothing of ours is needed at $0038...
' ...in mode 2 the Z80 jumps to the address it reads from a table, at ( I register * 256 ) + whatever byte is on the data bus...
' ...that byte is not predictable on a Spectrum, so the table is 257 copies of one value, and the handler sits at the address
' made of that value twice, then it does not matter which entry gets read...
' ...both live at the top of the second core code page, the loader builds them (see s_load_set_interrupts() in load.bas),
' and build.ps1 checks that the core's own code stops short of them
#define A_IM2_HANDLER           $BDBD   ' the handler itself, a single "reti"
#define A_IM2_TABLE             $BE00   ' 257 bytes, $BE00 to $BF00, every one of them $BD

' --- THE STACK ---
#define A_STACK_BOTTOM          $F400   ' the lowest address the stack may reach, directly above the 5120 bytes of screen cells
#define UB_STACK_FILL           $A5     ' the core fills the stack area with this at start up, so the memory monitor can see how deep it has ever been
#define UB_MONITOR_ROW          27      ' the live monitor's main rows, 27 to 31, with 24 to 26 above them for MMU 2's misses, Moria's own 24 line screen ends at row 23
#define UB_MONITOR_ROWS         5       ' ...five of them
#define UB_MN_MISSES_ROWS       3       ' ...and the three above
#define UB_MONITOR_OFF          0       ' gub_core_monitor: the live monitor is off...
#define UB_MONITOR_MEMORY       1       ' ...shows the slots, the heap and the stack...
#define UB_MONITOR_MISSES       2       ' ...and MMU 2's misses by page above them as well, the } key goes round the three
#define UB_MN_MISSES_LEFT       34      ' where the misses by kind of page start
#define UB_MN_SLOTS_LEFT        29      ' the table of the four slots
#define UB_MN_HEAP_LEFT         61      ' the heap's column
#define UB_MN_STACK_LEFT        71      ' the stack's
#define UB_MN_SLOTS             4       ' MMU 0 to 3, the three paged data slots and the code's
#define UB_MN_COLUMN_WIDTH      7       ' each slot's column
#define UB_MN_HEAP_WIDTH        5
#define UB_MN_STACK_WIDTH       6
#define UL_MN_COUNT_WRAP        1000000 ' the counts are shown to six figures
#define UB_MN_KIND_SIZE         4       ' each count of misses by kind, A_CORE_MMU2_KINDS
#define A_CORE_SLOTS            A_CORE + 9      ' size 0, only where the slots' own bytes begin, gub_core_MMU0_page_number, see globals.bas
#define UB_MN_SLOT_SIZE         9       ' each slot's own bytes from gub_core_MMU0_page_number: its page, hits and swaps
#define UB_MN_SLOT_HITS         1       ' four bytes
#define UB_MN_SLOT_SWAPS        5       ' four bytes
#define UB_MN_HEAP_BLOCKS_MAX   64      ' a guard, in case the heap's chain of free blocks has been damaged
' the heap, as Boriel's runtime keeps it: a 4 byte header, the same shape as a free block (size 0, then the address of
' the first free block), and a chain of free blocks, each its size and the address of the next
#define UB_HEAP_HEADER_SIZE     4
#define UB_HEAP_NEXT_OFFSET     2       ' where in a block, or the header, the next free block's address is
#define UB_HEAP_FIRST_UNUSED    8       ' the header and the first free block's two words, the first byte ever handed out
#define UB_MONITOR_LEFT         17      ' ...and none of it left of column 17, the mini map has columns 0 to 15, see stage-lib-minimap.bas
#define UB_HEAP_FILL            $5A     ' ...and the heap with this, for the same reason

' --- THE HEAP ---
' there is one heap (for strings), shared by the core and all of the stages, the core prepares it once at start up...
' ...so a stage can build a string and hand it to a core routine, e.g. s_core_print_string_at( 2 , 38 , "INIT" , UB_BRIGHT_WHITE )...
' ...it lives in the last 1024 bytes of the core data page ($DC00 to $DFFF), as set by --heap-address and --heap-size for core.bas and the stages in build.ps1...
' ...so the fixed variables below (which grow upwards from $C000) must stay under $DC00

' --- CORE DATA and WORKING STORAGE ---
#define A_API           A_MMU_SLOT_CORE_DATA            'size 100, allow for the address of up to 50 different subs and functions
#define A_CORE          A_MMU_SLOT_CORE_DATA +  232     'size 106, see globals.bas
#define A_KEY           A_MMU_SLOT_CORE_DATA +  400     'size  50
#define A_GAME          A_MMU_SLOT_CORE_DATA +  512     'size  64, things that belong to the game as a whole, e.g. the random number seeds
#define A_MAP           A_MMU_SLOT_CORE_DATA +  576     'size   8, a working copy of one map square
#define A_KILLER        A_MMU_SLOT_CORE_DATA +  600     'size  40, text: what is about to hurt the player, e.g. "a Kobold", see stage-player-hit-include.bas
#define A_PROMPT        A_MMU_SLOT_CORE_DATA +  704     'size  40, text: the question UB_LIB_INV_CHOOSE is to ask, e.g. "Eat what?", empty for "Which one?"
#define A_DIED_FROM     A_MMU_SLOT_CORE_DATA +  656     'size  40, text: what the player died from (character_died_from), N.B: not hard up against A_KILLER, s_core_ram_copy() would call that an overlap
' ...one working copy of each kind of 64 byte record, the core's record routines copy between these and the paged data...
#define A_MONSTER       A_MMU_SLOT_CORE_DATA + 1024     'size  64
#define A_ITEM          A_MMU_SLOT_CORE_DATA + 1088     'size  64
#define A_CREATURE      A_MMU_SLOT_CORE_DATA + 1152     'size  64
#define A_OBJECT        A_MMU_SLOT_CORE_DATA + 1216     'size  64
#define A_EGO           A_MMU_SLOT_CORE_DATA + 1280     'size  64
#define A_RACE          A_MMU_SLOT_CORE_DATA + 1408     'size  64, the player's race, a record from the character database
#define A_CLASS         A_MMU_SLOT_CORE_DATA + 1472     'size  64, the player's class, ditto
' ...what the player carries is always in memory, it is used far too often to be paged...
#define A_INVENTORY     A_MMU_SLOT_CORE_DATA + 2048     'size 2176 = 34 * 64, which ends at + 4224: the 22 places in the pack, then the 12 pieces of equipment...
#define A_EQUIPMENT     A_MMU_SLOT_CORE_DATA + 3456     '...the equipment is places 22 to 33 of that one list, as it is in Moria, UB_EQUIP_... + 22, size 768
' ...small tables from the Moria source, they come in with the NEX, already in place (see create-data.ps1 and sjasmplus.cfg)...
#define A_TABLE_MONSTER_LEVELS  A_MMU_SLOT_CORE_DATA + 4480 'size   82, 41 entries of 2 bytes, how many kinds of creature are of each level or less (monster_levels), N.B: it was in the creatures' last page, and is here so that it is never paged
#define A_NORMAL_TABLE  A_MMU_SLOT_CORE_DATA + 4608     'size  512, 256 entries of 2 bytes, used by fsw_core_random_normal()
#define A_ATTACKS       A_MMU_SLOT_CORE_DATA + 5120     'size  860, 215 monster attacks of 4 bytes
#define A_EXP_LEVELS    A_MMU_SLOT_CORE_DATA + 5980     'size  160, the experience needed for each of the 40 levels, 4 bytes each, which ends at + 6140
' ...when the player is asked to pick something from the pack: a byte for each of the 22 places, 0 for those that may not be picked
#define A_INV_MASK      A_MMU_SLOT_CORE_DATA + 1536 + 100   'size   22
' ...a scratch buffer for building text a byte at a time, without using the heap
#define A_TEXT_BUFFER   A_MMU_SLOT_CORE_DATA + 4224     'size  256
' ...the player, everything about the character except what they carry, see globals.bas for what is in it
#define A_PLAYER        A_MMU_SLOT_CORE_DATA + 6144     'size  768, which ends at + 6912, the heap starts at + 7168
#define UW_PLAYER_SIZE  768                             ' the player's record, see globals.bas for what is in it

' ...working storage for a library page: the top 512 bytes of the library's own page, $7E00 to $7FFF while it is running...
' ...it belongs to that library alone, it is in view exactly when the library is, and it costs no page swap,
' so one library calling another cannot disturb the first one's work, build.ps1 checks that a library's code stops short of it
' N.B: it goes out of view when the library returns, so anything handed back to the caller must be put in the core data
#define A_LIB_PRIVATE           A_MMU_SLOT_PAGED_CODE + 7680
#define UW_LIB_CODE_LIMIT       7680
' the routines in the items library, see stage-lib-items.bas...
Const   UB_LIB_ITEMS_DESCRIBE       As UByte    = 1
Const   UB_LIB_ITEMS_NEW_GAME       As UByte    = 2
Const   UB_LIB_ITEMS_FROM_OBJECT    As UByte    = 3
Const   UB_LIB_ITEMS_TEST           As UByte    = 4
Const   UB_LIB_ITEMS_KIND_KNOWN     As UByte    = 5
Const   UB_LIB_ITEMS_STORE_BOUGHT   As UByte    = 6

' the routines in the inventory library, see stage-lib-inventory.bas...
Const   UB_LIB_INV_CAN_CARRY        As UByte    = 1
Const   UB_LIB_INV_CARRY            As UByte    = 2
Const   UB_LIB_INV_STRENGTH         As UByte    = 3
Const   UB_LIB_INV_NEW_CHARACTER    As UByte    = 4
Const   UB_LIB_INV_DESTROY          As UByte    = 5
Const   UB_LIB_INV_IDENTIFY         As UByte    = 6
Const   UB_LIB_INV_KNOW_FULLY       As UByte    = 7
Const   UB_LIB_INV_CHOOSE           As UByte    = 8
Const   UB_LIB_INV_SHOW             As UByte    = 9
Const   UB_LIB_INV_TRIED            As UByte    = 10
Const   UB_LIB_INV_REMOVE_ALL       As UByte    = 11
Const   UB_LIB_INV_IDENTIFY_WORKING As UByte    = 12
Const   UB_LIB_INV_VERIFY           As UByte    = 13
' what UB_LIB_INV_CHOOSE and UB_LIB_INV_VERIFY are told in gub_lib_param_1: the word for the "are you sure" question...
Const   UB_INV_CHOOSE_TRY           As UByte    = 0     ' "Try"
Const   UB_INV_CHOOSE_REFUSE        As UByte    = 1     ' "Try", and picking something that may not be picked gets "I do not buy such items."
Const   UB_INV_CHOOSE_WEAR          As UByte    = 2     ' "Wear/Wield"
Const   UB_INV_CHOOSE_DROP          As UByte    = 3     ' "Drop", or "Throw off" for something worn
Const   UB_INV_CHOOSE_TAKE_OFF      As UByte    = 4     ' "Take off"

' the routines in the equipment library, see stage-lib-equipment.bas...
Const   UB_LIB_EQUIP_COMMAND        As UByte    = 1
Const   UB_LIB_EQUIP_RECALC         As UByte    = 2
Const   UB_LIB_EQUIP_USE_STAT       As UByte    = 3
Const   UB_LIB_EQUIP_ADJUST         As UByte    = 4
Const   UB_LIB_EQUIP_SHOW           As UByte    = 5
Const   UB_LIB_EQUIP_THROW_OFF      As UByte    = 6

' the routine in the bonuses library, see stage-lib-bonuses.bas...
Const   UB_LIB_BONUSES_RECALC       As UByte    = 1

' the routines in the moves library, see stage-lib-moves.bas...
Const   UB_LIB_MOVES_OPEN           As UByte    = 1
Const   UB_LIB_MOVES_CLOSE          As UByte    = 2
Const   UB_LIB_MOVES_SEARCH         As UByte    = 3
Const   UB_LIB_MOVES_CARRY          As UByte    = 4
Const   UB_LIB_MOVES_DELETE_OBJECT  As UByte    = 5

' the routine in the objects library, see stage-lib-objects.bas...
Const   UB_LIB_OBJECTS_LEVEL        As UByte    = 1
Const   UB_LIB_OBJECTS_PLACE_OBJECT As UByte    = 2
Const   UB_LIB_OBJECTS_RANDOM       As UByte    = 4
Const   UB_LIB_OBJECTS_PLACE_GOLD   As UByte    = 3
Const   UB_LIB_OBJECTS_FLAVOUR_COLOURS As UByte = 5

' the routines in the monsters library, see stage-lib-monsters.bas...
Const   UB_LIB_MONSTERS_PLACE_ASLEEP    As UByte    = 1
Const   UB_LIB_MONSTERS_PLACE_AWAKE     As UByte    = 2
Const   UB_LIB_MONSTERS_PLACE_WINNING   As UByte    = 3
Const   UB_LIB_MONSTERS_UPDATE          As UByte    = 4
Const   UB_LIB_MONSTERS_VISIBILITY      As UByte    = 5
Const   UB_LIB_MONSTERS_LOS             As UByte    = 6
Const   UB_LIB_MONSTERS_SUMMON          As UByte    = 7
Const   UB_LIB_MONSTERS_SUMMON_UNDEAD   As UByte    = 8
#define UB_MON_KEPT             128     ' the monsters library's own: from here in its private storage, 64 bytes, the working
                                        ' monster, kept while a monster's spell summons
Const   UB_LIB_MONSTERS_MULTIPLY        As UByte    = 9
Const   UB_LIB_MONSTERS_POLYMORPH_AT    As UByte    = 10
Const   UB_LIB_MONSTERS_CLONE           As UByte    = 11
Const   UB_LIB_MONSTERS_SUMMON_AT       As UByte    = 12
Const   UB_LIB_PLAYER_ATTACK_DROP       As UByte    = 4     ' see stage-lib-player-attack.bas, the others are with the other fighting constants

' the routine in the monster moves library, see stage-lib-monster-moves.bas...
Const   UB_LIB_MONSTER_MOVES_TURN       As UByte    = 1
Const   UB_LIB_MONSTER_MOVES_DELETE     As UByte    = 2
Const   UB_LIB_MONSTER_MOVES_REMOVE     As UByte    = 3

' the routines in the monster attack library, see stage-lib-monster-attack.bas and stage-lib-monster-attack-2.bas...
Const   UB_LIB_MONSTER_ATTACK_PLAYER    As UByte    = 1
Const   UB_LIB_MONSTER_ATTACK_2_EXECUTE As UByte    = 1
Const   UB_LIB_MONSTER_ATTACK_2_DAMAGE  As UByte    = 2
Const   UB_LIB_MONSTER_ATTACK_2_TELEPORT_AWAY   As UByte = 3

' the routine in the monster spells library, see stage-lib-monster-spells.bas...
Const   UB_LIB_MONSTER_SPELLS_CAST      As UByte    = 1
' ...and the kinds of harm that fire, acid and the rest do, the numbers are the monster attacks' own, see
' UB_LIB_MONSTER_ATTACK_2_DAMAGE, with one more for poison gas
Const   UB_ELEMENT_FIRE                 As UByte    = 5
Const   UB_ELEMENT_ACID                 As UByte    = 6
Const   UB_ELEMENT_FROST                As UByte    = 7
Const   UB_ELEMENT_LIGHTNING            As UByte    = 8
Const   UB_ELEMENT_GAS                  As UByte    = 10

' the routine in the turn library, see stage-lib-turn.bas...
Const   UB_LIB_TURN_EFFECTS             As UByte    = 1
Const   UB_LIB_TURN_2_HERO              As UByte    = 1
Const   UB_LIB_TURN_2_SPEED             As UByte    = 2
Const   UB_LIB_TURN_2_LATE              As UByte    = 3
Const   UB_LIB_TURN_2_REST_OFF          As UByte    = 4
Const   UB_LIB_TURN_2_MOVEMENT_STATE    As UByte    = 5
Const   UB_LIB_TURN_2_CHANGE_SPEED      As UByte    = 6
Const   UB_LIB_TURN_2_STATUS_LINE       As UByte    = 7
' ...and what the turn library asks the walking stage to do afterwards, bits of gub_game_turn_flags
#define MB_TURN_REDRAW_MAP          %00000001   ' draw the whole map again, and then see which monsters show
#define MB_TURN_UPDATE_MONSTERS     %00000010   ' see which monsters show
#define MB_TURN_NEW_LEVEL           %00000100   ' leave for another level, guw_dungeon_level has been set
#define MB_TURN_LIGHT_ROOM          %00001000   ' light the room the player is in
#define MB_TURN_RESET_VIEW          %00010000   ' the player has been moved: the window, their light, the room they are now in

' what gub_game_disturb holds, the player has been disturbed (Moria's playerDisturb()) and the screen has yet to say so, see
' stage-disturb-include.bas, which changes the game at once, and the commands library's UB_LIB_COMMANDS_DISTURB, which does the rest
#define MB_DISTURB_SCREEN           %00000001   ' a count, a rest or a run may have ended
#define MB_DISTURB_SEARCH_OFF       %00000010   ' searching has been turned off

' the routine in the player attack library, see stage-lib-player-attack.bas...
Const   UB_LIB_PLAYER_ATTACK_MONSTER    As UByte    = 1
Const   UB_LIB_PLAYER_ATTACK_TAKE_HIT   As UByte    = 2
Const   UB_LIB_PLAYER_ATTACK_KILL       As UByte    = 3

' the routines in the effects library, see stage-lib-effects.bas...
Const   UB_LIB_EFFECTS_HP_CHANGE        As UByte    = 1
Const   UB_LIB_EFFECTS_STAT_RESTORE     As UByte    = 2
Const   UB_LIB_EFFECTS_STAT_INCREASE    As UByte    = 3
Const   UB_LIB_EFFECTS_STAT_DECREASE    As UByte    = 4
Const   UB_LIB_EFFECTS_LOSE_STAT        As UByte    = 5
Const   UB_LIB_EFFECTS_LOSE_EXP         As UByte    = 6
Const   UB_LIB_EFFECTS_RESTORE_LEVELS   As UByte    = 7
Const   UB_LIB_EFFECTS_DISPLAY_EXP      As UByte    = 8
Const   UB_LIB_EFFECTS_INGEST_FOOD      As UByte    = 9
Const   UB_LIB_EFFECTS_USE_DONE         As UByte    = 10
Const   UB_LIB_EFFECTS_USE_REMAINING    As UByte    = 11
Const   UB_LIB_EFFECTS_CALC_HP          As UByte    = 12

' the routines in the consume library, see stage-lib-consume.bas...
Const   UB_LIB_CONSUME_EAT              As UByte    = 1
Const   UB_LIB_CONSUME_QUAFF            As UByte    = 2

' the routines in the spells libraries, see stage-lib-spells.bas and stage-lib-spells-2.bas...
' N.B: the four detections must stay together and in this order
Const   UB_LIB_SPELLS_LIGHT_AREA        As UByte    = 1
Const   UB_LIB_SPELLS_DARKEN_AREA       As UByte    = 2
Const   UB_LIB_SPELLS_MAP_AREA          As UByte    = 3
Const   UB_LIB_SPELLS_DETECT_TREASURE   As UByte    = 4
Const   UB_LIB_SPELLS_DETECT_OBJECTS    As UByte    = 5
Const   UB_LIB_SPELLS_DETECT_TRAPS      As UByte    = 6
Const   UB_LIB_SPELLS_DETECT_DOORS      As UByte    = 7
Const   UB_LIB_SPELLS_DETECT_INVISIBLE  As UByte    = 8
Const   UB_LIB_SPELLS_TELEPORT          As UByte    = 9
Const   UB_LIB_SPELLS_GLYPH             As UByte    = 10
Const   UB_LIB_SPELLS_CREATE_FOOD       As UByte    = 11
Const   UB_LIB_SPELLS_TRAPS             As UByte    = 12
Const   UB_LIB_SPELLS_DOORS             As UByte    = 13
Const   UB_LIB_SPELLS_DESTROY_DOORS     As UByte    = 14
Const   UB_LIB_SPELLS_DESTROY_AREA      As UByte    = 15
Const   UB_LIB_SPELLS_2_SLEEP_ADJACENT  As UByte    = 1
Const   UB_LIB_SPELLS_2_AGGRAVATE       As UByte    = 2
Const   UB_LIB_SPELLS_2_MASS_GENOCIDE   As UByte    = 3
Const   UB_LIB_SPELLS_2_GENOCIDE        As UByte    = 4
Const   UB_LIB_SPELLS_2_DISPEL          As UByte    = 5
Const   UB_LIB_SPELLS_2_IDENTIFY        As UByte    = 6
Const   UB_LIB_SPELLS_2_RECHARGE        As UByte    = 7
Const   UB_LIB_SPELLS_2_REMOVE_CURSE    As UByte    = 8
Const   UB_LIB_SPELLS_3_LIGHT_LINE      As UByte    = 1
Const   UB_LIB_SPELLS_3_STARLITE        As UByte    = 2
Const   UB_LIB_SPELLS_3_BOLT            As UByte    = 3
Const   UB_LIB_SPELLS_3_BALL            As UByte    = 4
Const   UB_LIB_SPELLS_4_POLYMORPH       As UByte    = 1
Const   UB_LIB_SPELLS_4_CHANGE_HP       As UByte    = 2
Const   UB_LIB_SPELLS_4_SPEED           As UByte    = 3
Const   UB_LIB_SPELLS_4_CONFUSE         As UByte    = 4
Const   UB_LIB_SPELLS_4_SLEEP           As UByte    = 5
Const   UB_LIB_SPELLS_4_DRAIN_LIFE      As UByte    = 6
Const   UB_LIB_SPELLS_4_CLONE           As UByte    = 7
Const   UB_LIB_SPELLS_4_TELEPORT_AWAY   As UByte    = 8
Const   UB_LIB_SPELLS_4_SPEED_ALL       As UByte    = 9
Const   UB_LIB_SPELLS_4_SLEEP_ALL       As UByte    = 10
Const   UB_LIB_SPELLS_4_MASS_POLYMORPH  As UByte    = 11
Const   UB_LIB_SPELLS_4_DETECT          As UByte    = 12
Const   UB_LIB_SPELLS_4_TURN_UNDEAD     As UByte    = 13
Const   UB_LIB_SPELLS_5_WALL_TO_MUD     As UByte    = 1
Const   UB_LIB_SPELLS_5_DESTROY_DOORS   As UByte    = 2
Const   UB_LIB_SPELLS_5_BUILD_WALL      As UByte    = 3
Const   UB_LIB_SPELLS_5_DISARM_ALL      As UByte    = 4
Const   UB_LIB_SPELLS_5_EARTHQUAKE      As UByte    = 5

' the routines in the devices library, see stage-lib-devices.bas...
Const   UB_LIB_DEVICES_USE_STAFF        As UByte    = 1
Const   UB_LIB_DEVICES_AIM_WAND         As UByte    = 2

' the routines in the fight library, see stage-lib-fight.bas...
Const   UB_LIB_FIGHT_BASH               As UByte    = 2
Const   UB_LIB_FIGHT_SPIKE              As UByte    = 3

' the routine in the throw library, see stage-lib-throw.bas...
Const   UB_LIB_THROW_ITEM               As UByte    = 1

' the routines in the magic library, see stage-lib-magic.bas...
Const   UB_LIB_MAGIC_CALC               As UByte    = 1
Const   UB_LIB_MAGIC_MANA               As UByte    = 2

' the routines in the books library, see stage-lib-books.bas...
Const   UB_LIB_BOOKS_GAIN               As UByte    = 1
Const   UB_LIB_BOOKS_CHOOSE             As UByte    = 2
Const   UB_LIB_BOOKS_BROWSE             As UByte    = 3

' the routines in the rooms library, see stage-lib-rooms.bas...
Const   UB_LIB_ROOMS_INNER              As UByte    = 1
Const   UB_LIB_ROOMS_CROSS              As UByte    = 2

' what ful_core_recall() is asked to read or change in the monster memory, see core.bas...
Const   UB_RECALL_MOVEMENT              As UByte    = 0     ' these three are bit fields, the value is added to what is known
Const   UB_RECALL_SPELLS                As UByte    = 1
Const   UB_RECALL_DEFENSES              As UByte    = 2
Const   UB_RECALL_KILLS                 As UByte    = 3     ' these are counts, they go up by one if the value is not 0
Const   UB_RECALL_DEATHS                As UByte    = 4
Const   UB_RECALL_WAKE                  As UByte    = 5
Const   UB_RECALL_IGNORE                As UByte    = 6
Const   UB_RECALL_ATTACK                As UByte    = 7     ' the first of the four attacks, add 1, 2 or 3 for the others
Const   UB_RECALL_SPELL_SEEN            As UByte    = 11    ' it has been seen to cast once more
Const   UB_RECALL_SET_MOVEMENT          As UByte    = 12    ' the movement bits are replaced by the value

' the routines in the recall library, see stage-lib-recall.bas...
Const   UB_LIB_RECALL_SHOW              As UByte    = 1
Const   UB_LIB_RECALL_SYMBOL            As UByte    = 2
Const   UB_LIB_RECALL_2_REST            As UByte    = 1     ' the second recall library, see stage-lib-recall-2.bas

' the routines in the chests library, see stage-lib-chests.bas...
Const   UB_LIB_CHESTS_OPEN              As UByte    = 1
Const   UB_LIB_CHESTS_DISARM            As UByte    = 2
Const   UB_LIB_CHESTS_BASH              As UByte    = 3
Const   UB_LIB_CHESTS_UNLOCK            As UByte    = 4
Const   UB_LIB_CHESTS_SEARCH            As UByte    = 5
Const   UB_LIB_CHESTS_KNOW              As UByte    = 6
Const   UB_LIB_CHESTS_BLOCKED           As UByte    = 7

' the routines in the second monster moves library, see stage-lib-monster-moves-2.bas...
Const   UB_LIB_MONSTER_MOVES_2_DOOR         As UByte    = 1
Const   UB_LIB_MONSTER_MOVES_2_WALL         As UByte    = 2
Const   UB_LIB_MONSTER_MOVES_2_WALL_AFTER   As UByte    = 3

' the routines in the second commands library, see stage-lib-commands-2.bas...
Const   UB_LIB_COMMANDS_2_COUNT         As UByte    = 1
Const   UB_LIB_COMMANDS_2_INSCRIBE      As UByte    = 2
Const   UB_LIB_COMMANDS_2_REFILL        As UByte    = 3
Const   UB_LIB_COMMANDS_2_OPTIONS       As UByte    = 4
Const   UB_LIB_COMMANDS_2_ROGUELIKE     As UByte    = 5

' the player's options, guw_game_options, the bits are the ones Moria keeps them in when it saves a game...
#define MW_OPTION_CUT_CORNERS       $0001       ' running: cut known corners (run_cut_corners)
#define MW_OPTION_EXAMINE_CORNERS   $0002       ' running: examine potential corners (run_examine_corners)
#define MW_OPTION_PRINT_SELF        $0004       ' running: print self during run (run_print_self)
#define MW_OPTION_FIND_BOUND        $0008       ' running: stop when map sector changes (find_bound)
#define MW_OPTION_PROMPT_PICKUP     $0010       ' prompt to pick up objects (prompt_to_pickup)
#define MW_OPTION_ROGUELIKE         $0020       ' rogue like commands (use_roguelike_keys)
#define MW_OPTION_SHOW_WEIGHTS      $0040       ' show weights in inventory (show_inventory_weights)
#define MW_OPTION_SEAMS             $0080       ' highlight and notice mineral seams (highlight_seams)
#define MW_OPTION_IGNORE_DOORS      $0100       ' running: run through open doors (run_ignore_doors)
#define MW_OPTION_BEEP              $0200       ' beep for invalid character (error_beep_sound), see s_core_beep() in core.bas
#define MW_OPTION_DISPLAY_COUNTS    $0400       ' display rest/repeat counts (display_counts)
#define MW_OPTION_PLAIN_MAP         $0800       ' ours: the map without colours, every symbol white as Moria's is (sdo, 22 October),
                                                ' N.B: set means plain, so that a game saved before it was an option keeps its colours
#define MW_OPTION_DEFAULTS          $0603       ' as Moria starts out: corners cut and examined, beep, counts shown

' the routines in the two wizard libraries, see stage-lib-wizard.bas and stage-lib-wizard-2.bas...
Const   UB_LIB_WIZARD_KEY               As UByte    = 1
Const   UB_LIB_WIZARD_STATUS            As UByte    = 2
Const   UB_LIB_WIZARD_RESTORED          As UByte    = 3
Const   UB_LIB_WIZARD_ENTER             As UByte    = 4
Const   UB_LIB_WIZARD_2_CHARACTER       As UByte    = 1
Const   UB_LIB_WIZARD_2_OBJECT          As UByte    = 2
Const   UB_LIB_WIZARD_3_SUPER           As UByte    = 1
Const   UB_LIB_WIZARD_3_SAMPLE          As UByte    = 2
Const   UB_LIB_MONITOR_SHOW             As UByte    = 1
Const   UB_LIB_MONITOR_CLEAR            As UByte    = 2

' the mini map library's routines, see stage-lib-minimap.bas
Const   UB_LIB_MINIMAP_DRAW             As UByte    = 1     ' the mini map brought up to date on the screen, as the game waits for a command
Const   UB_LIB_MINIMAP_CYCLE            As UByte    = 2     ' off, 1:1, 1:2, and round again, the [ key
#define UB_MINIMAP_ROW              24      ' the mini map has rows 24 to 31 of the screen, columns 0 to 15, below Moria's 24 lines
#define UB_MINIMAP_CHAR             128     ' ...and the upper half of the font, characters 128 to 255, one for each of its 16 by 8 cells
#define UB_MM_CHARS_ACROSS          16      ' its 16 by 8 cells
#define UB_MM_CHARS_DOWN            8
#define UB_MM_BITS_ROW              32      ' the bitmap: a bit for each square of a 256 square row
#define UB_MM_WINDOW_COLS           128     ' at 1:1 a window of the level, 128 squares across...
#define UB_MM_WINDOW_ROWS           64      ' ...and 64 down
#define MB_MM_WINDOW_STEP           $F8     ' ...that moves across in steps of 8, a byte of the bitmap
#define UB_MM_HALF_ACROSS           13      ' at 1:2 the whole level, in the top left 13 by 5 cells
#define UB_MM_HALF_DOWN             5
#define UW_MM_FONT_SIZE             1024    ' the 128 characters it draws into, the upper half of the font
#define UB_MM_NO_CELL               255     ' none of the cells is the player's, A_MM_GREEN
#define UB_MM_MODE_OFF              0       ' gub_minimap_mode, the [ key goes round them
#define UB_MM_MODE_FULL             1       ' 1:1
#define UB_MM_MODE_HALF             2       ' 1:2
#define UB_FONT_CHAR_SIZE           8       ' a character of the font, a byte for each of its rows
#define MB_FONT_LEFT_PIXEL          $80     ' a row's top bit is its leftmost pixel
#define UB_SCREEN_ROW_SIZE          160     ' a row of the screen's cells, a character and an attribute each

' the routines in the scores library, see stage-lib-scores.bas...
Const   UB_LIB_SCORES_RECORD            As UByte    = 1
Const   UB_LIB_SCORES_SHOW              As UByte    = 2
Const   UB_LIB_SCORES_DATE              As UByte    = 3     ' the date and the time from the Next's clock, see stage-lib-scores.bas
Const   UB_LIB_SCORES_DEAD              As UByte    = 4     ' has the character born at gsl_lib_long_1 died already?
Const   UB_LIB_SCORES_POINTS            As UByte    = 5     ' what the character would score now, in gsl_lib_long_1

' the routines in the save library, see stage-lib-save.bas...
Const   UB_LIB_SAVE_SAVE                As UByte    = 1
Const   UB_LIB_SAVE_RESTORE             As UByte    = 2
Const   UB_LIB_SAVE_DEAD                As UByte    = 3
Const   UB_LIB_SAVE_MEMORY              As UByte    = 4

' the routines in the compact library, see stage-lib-compact.bas...
Const   UB_LIB_COMPACT_OBJECTS          As UByte    = 1
Const   UB_LIB_COMPACT_MONSTERS         As UByte    = 2

' the routines in the look library, see stage-lib-look.bas...
Const   UB_LIB_LOOK_LOOK                As UByte    = 1
Const   UB_LIB_LOOK_IDENTIFY            As UByte    = 2

' the routines in the info library, see stage-lib-info.bas...
Const   UB_LIB_INFO_CHARACTER           As UByte    = 1
Const   UB_LIB_INFO_LOCATE              As UByte    = 2
Const   UB_LIB_INFO_FILE                As UByte    = 4
Const   UB_LIB_INFO_MAP                 As UByte    = 3

' the routine in the text library, see stage-lib-text.bas...
Const   UB_LIB_TEXT_SHOW                As UByte    = 1
Const   UB_LIB_TEXT_MESSAGES            As UByte    = 2
' ...the texts UB_LIB_TEXT_SHOW shows, gub_lib_param_1, N.B: there is no 5, it was the licence, Moria's Ctrl-V
Const   UB_TEXT_HELP                    As UByte    = 1     ' Moria's help.txt
Const   UB_TEXT_VERSIONS                As UByte    = 2     ' versions.txt, and the credits
Const   UB_TEXT_WELCOME                 As UByte    = 3     ' welcome.txt, ? while a character is being made
Const   UB_TEXT_WIZARD                  As UByte    = 4     ' help_wizard.txt
Const   UB_TEXT_ROGUE_HELP              As UByte    = 6     ' rl_help.txt, from UB_PAGE_HELP_TEXT...
Const   UB_TEXT_ROGUE_WIZARD            As UByte    = 7     ' ...and rl_help_wizard.txt, at UW_HELP_ROGUE_WIZARD_AT in it
Const   UW_HELP_ROGUE_WIZARD_AT         As UInteger = 4096  ' see create-data.ps1
Const   UC_NEWLINE                      As UByte    = 10    ' a line feed, Moria's newline character

' the routines in the run library, see stage-lib-run.bas...
Const   UB_LIB_RUN_START                As UByte    = 1
Const   UB_LIB_RUN_AREA                 As UByte    = 2

' the routines in the cast library, see stage-lib-cast.bas...
Const   UB_LIB_CAST_SPELL               As UByte    = 1
Const   UB_LIB_CAST_PRAY                As UByte    = 2

' the routine in the read library, see stage-lib-read.bas...
Const   UB_LIB_READ_SCROLL              As UByte    = 1

' the routines in the traps library, see stage-lib-traps.bas...
Const   UB_LIB_TRAPS_STEP               As UByte    = 1
Const   UB_LIB_TRAPS_DISARM             As UByte    = 2
Const   UB_LIB_TRAPS_TUNNEL             As UByte    = 3
Const   UB_LIB_TRAPS_DIG_WALL           As UByte    = 4

' the routines in the commands library, see stage-lib-commands.bas...
Const   UB_LIB_COMMANDS_KEY             As UByte    = 1
Const   UB_LIB_COMMANDS_DISTURB         As UByte    = 2
' ...and what it tells the walking stage to do after a command
' the window on to the map, see the map routines in core.bas...
#define UB_VIEW_ROWS        22      ' the window is this many rows of the map, Moria's SCREEN_HEIGHT...
#define UB_VIEW_COLS        66      ' ...by this many columns, SCREEN_WIDTH
#define UB_VIEW_SCREEN_ROW  1       ' and its top left corner is at this row...
#define UB_VIEW_SCREEN_COL  13      ' ...and this column of the screen

#define MB_COMMAND_DONE             %00000001   ' the key was a command
#define MB_COMMAND_DRAW_AROUND      %00000010   ' draw the squares round the player again
#define MB_COMMAND_DRAW_ALL         %00000100   ' draw the whole screen again
#define MB_COMMAND_UNKNOWN          %00001000   ' the key was not a command at all, and "Type '?' for help." has been said

' ...and Moria's settings for monsters, its MON_ numbers
Const   UB_MON_TOTAL_ALLOCATIONS    As UByte    = 125   ' the most monsters a level can hold, the list has no number 0 or 1
Const   UB_MON_MIN_INDEX            As UByte    = 2     ' the first monster's number, on the map 1 is the player and 0 is nobody
Const   UB_MON_MAX_LEVELS           As UByte    = 40    ' the highest level a creature can be
Const   UB_MON_MAX_SIGHT            As UByte    = 20    ' the furthest away a monster can be seen
Const   UB_MON_CHANCE_OF_NASTY      As UByte    = 50    ' 1 in this many chance of a creature from deeper down
Const   UB_MON_MIN_PER_LEVEL        As UByte    = 14    ' the fewest monsters a new level starts with
Const   UB_MON_MIN_TOWNSFOLK_DAY    As UByte    = 4     ' people in the town by day...
Const   UB_MON_MIN_TOWNSFOLK_NIGHT  As UByte    = 8     ' ...and by night
Const   UB_MON_ENDGAME_MONSTERS     As UByte    = 2     ' the end game creatures, the last ones in the database: Evil Iggy and the Balrog, only killing the Balrog wins
Const   UB_MON_ENDGAME_LEVEL        As UByte    = 50    ' the level they begin to appear on
' ...the bits of a creature's "movement" and "defenses" fields that are used so far, Moria's CM_ and CD_ numbers
#define UL_CM_ATTACK_ONLY           $00000001
#define UL_CM_MOVE_NORMAL           $00000002
#define UL_CM_ONLY_MAGIC            $00000004
#define UL_CM_TREASURE              $7C000000   ' what a creature leaves behind when it dies, and in the monster memory how many things one has been seen to leave, from bit 26 up
#define UB_CM_TR_SHIFT              26          ' where those bits begin, Moria's CM_TR_SHIFT
#define UL_CM_20_RANDOM             $00000008
#define UL_CM_40_RANDOM             $00000010
#define UL_CM_75_RANDOM             $00000020
#define UL_CM_INVISIBLE             $00010000
#define UL_CM_OPEN_DOOR             $00020000
#define UL_CM_PHASE                 $00040000
#define UL_CM_EATS_OTHER            $00080000
#define UL_CM_PICKS_UP              $00100000
#define UL_CM_MULTIPLY              $00200000
#define UL_CM_SMALL_OBJ             $00800000
#define UL_CM_CARRY_OBJ             $01000000
#define UL_CM_CARRY_GOLD            $02000000
#define UL_CM_60_RANDOM             $04000000
#define UL_CM_90_RANDOM             $08000000
#define UL_CM_1D2_OBJ               $10000000
#define UL_CM_2D2_OBJ               $20000000
#define UL_CM_4D2_OBJ               $40000000
#define UL_CM_WIN                   $80000000
#define UW_CD_DRAGON                $0001
#define UW_CD_ANIMAL                $0002
#define UW_CD_FROST                 $0010
#define UW_CD_FIRE                  $0020
#define UW_CD_EVIL                  $0004
#define UW_CD_UNDEAD                $0008
#define UW_CD_POISON                $0040
#define UW_CD_ACID                  $0080
#define UW_CD_LIGHT                 $0100
#define UW_CD_STONE                 $0200
#define UW_CD_NO_SLEEP              $1000
' ...and of its "spells" field: which breath it has, or shrugs off
#define UL_CS_FREQ                  $0000000F   ' the low bits of a creature's spells: 1 in this many turns it casts; in the
                                                ' monster memory, how often one has been seen to cast
#define UL_CS_BR_LIGHT              $00080000
#define UL_CS_BR_GAS                $00100000
#define UL_CS_BR_ACID               $00200000
#define UL_CS_BR_FROST              $00400000
#define UL_CS_BR_FIRE               $00800000
#define UW_CD_INFRA                 $2000
#define UW_CD_MAX_HP                $4000

' how many kinds of creature there are of each level or less is A_TABLE_MONSTER_LEVELS, in the core data page with the
' other small tables, see "creature levels" in create-data.ps1

' the routines in the haggle library, see stage-lib-haggle.bas, and what it says came of the haggling...
Const   UB_LIB_HAGGLE_PURCHASE      As UByte    = 1
Const   UB_LIB_HAGGLE_SELL          As UByte    = 2
Const   UB_BID_RECEIVED             As UByte    = 0     ' a price was agreed
Const   UB_BID_REJECTED             As UByte    = 1     ' no deal, or the player gave up
Const   UB_BID_OFFENDED             As UByte    = 2     ' the player tried to sell something the owner did not want
Const   UB_BID_INSULTED             As UByte    = 3     ' the owner was insulted once too often, and the player is thrown out

' the strings database: every string has a number, these are the first numbers of each group, see create-data.ps1...
Const   UW_STR_SALE_ACCEPTED        As UInteger = 0     ' 14 of them
Const   UW_STR_SELLING_FINAL        As UInteger = 14    '  3
Const   UW_STR_SELLING_HAGGLE       As UInteger = 17    ' 16
Const   UW_STR_BUYING_FINAL         As UInteger = 33    '  3
Const   UW_STR_BUYING_HAGGLE        As UInteger = 36    ' 15
Const   UW_STR_INSULTED             As UInteger = 51    '  5
Const   UW_STR_GET_OUT              As UInteger = 56    '  5
Const   UW_STR_TRY_AGAIN            As UInteger = 61    ' 10
Const   UW_STR_SORRY                As UInteger = 71    '  5
Const   UW_STR_RANK_TITLES          As UInteger = 76    ' 240, what a character of each class is called at each level, 40 for each of the 6 classes

' our own messages in the strings database, from src\messages.txt, shown with s_core_message(), create-data.ps1 checks
' these numbers against that list every time it runs, a new one goes at the end of both
Const   UW_MSG_RUBBLE_BLOCKS       As UInteger = 316
Const   UW_MSG_DOOR_BLOCKS         As UInteger = 317
Const   UW_MSG_NO_DOWN_STAIR       As UInteger = 318
Const   UW_MSG_MAZE_DOWN           As UInteger = 319
Const   UW_MSG_NO_UP_STAIR         As UInteger = 320
Const   UW_MSG_MAZE_UP             As UInteger = 321
Const   UW_MSG_ONE_WAY_DOOR        As UInteger = 322
Const   UW_MSG_LIGHT_OUT           As UInteger = 323
Const   UW_MSG_LIGHT_FAINT         As UInteger = 324
Const   UW_MSG_CATCH_BREATH        As UInteger = 325
Const   UW_MSG_WHICH_DIRECTION                     As UInteger = 326
Const   UW_MSG_YOU_FELL_INTO_A_PIT                 As UInteger = 327
Const   UW_MSG_YOU_GENTLY_FLOAT_DOWN               As UInteger = 328
Const   UW_MSG_AN_ARROW_HITS_YOU                   As UInteger = 329
Const   UW_MSG_AN_ARROW_BARELY_MISSES_YOU          As UInteger = 330
Const   UW_MSG_YOU_FELL_INTO_A_COVERED_PIT         As UInteger = 331
Const   UW_MSG_YOU_FELL_THROUGH_A_TRAP_DOOR        As UInteger = 332
Const   UW_MSG_A_STRANGE_WHITE_MIST_SURROUNDS_YOU  As UInteger = 333
Const   UW_MSG_YOU_ARE_UNAFFECTED                  As UInteger = 334
Const   UW_MSG_YOU_FALL_ASLEEP                     As UInteger = 335
Const   UW_MSG_HMMM_THERE_WAS_SOMETHING_UNDER      As UInteger = 336
Const   UW_MSG_A_SMALL_DART_WEAKENS_YOU            As UInteger = 337
Const   UW_MSG_A_SMALL_DART_HITS_YOU               As UInteger = 338
Const   UW_MSG_A_SMALL_DART_BARELY_MISSES_YOU      As UInteger = 339
Const   UW_MSG_YOU_HIT_A_TELEPORT_TRAP             As UInteger = 340
Const   UW_MSG_YOU_ARE_HIT_BY_FALLING_ROCK         As UInteger = 341
Const   UW_MSG_A_STRANGE_RED_GAS_SURROUNDS_YOU     As UInteger = 342
Const   UW_MSG_YOU_ARE_ENVELOPED_IN_FLAMES         As UInteger = 343
Const   UW_MSG_YOU_ARE_SPLASHED_WITH_ACID          As UInteger = 344
Const   UW_MSG_A_PUNGENT_GREEN_GAS_SURROUNDS_YOU   As UInteger = 345
Const   UW_MSG_A_BLACK_GAS_SURROUNDS_YOU           As UInteger = 346
Const   UW_MSG_A_GAS_OF_SCINTILLATING_COLORS       As UInteger = 347
Const   UW_MSG_A_SMALL_DART_HITS_YOU_2             As UInteger = 348
Const   UW_MSG_A_SMALL_DART_SAPS_YOUR_HEALTH       As UInteger = 349
Const   UW_MSG_UNKNOWN_TRAP_VALUE                  As UInteger = 350
Const   UW_MSG_I_DO_NOT_SEE_ANYTHING_TO_DISARM     As UInteger = 351
Const   UW_MSG_YOU_HAVE_DISARMED_THE_TRAP          As UInteger = 352
Const   UW_MSG_YOU_SET_THE_TRAP_OFF                As UInteger = 353
Const   UW_MSG_YOU_HAVE_FOUND_SOMETHING            As UInteger = 354
Const   UW_MSG_YOU_HAVE_FINISHED_THE_TUNNEL        As UInteger = 355
Const   UW_MSG_TUNNEL_THROUGH_WHAT_EMPTY_AIR       As UInteger = 356
Const   UW_MSG_YOU_CANT_TUNNEL_THROUGH_THAT        As UInteger = 357
Const   UW_MSG_SOMETHING_IS_IN_YOUR_WAY            As UInteger = 358
Const   UW_MSG_YOU_DIG_WITH_YOUR_HANDS_MAKING_NO   As UInteger = 359
Const   UW_MSG_THIS_SEEMS_TO_BE_PERMANENT_ROCK     As UInteger = 360
Const   UW_MSG_YOU_HAVE_REMOVED_THE_RUBBLE         As UInteger = 361
Const   UW_MSG_YOU_RESIST_THE_EFFECTS_OF_THE       As UInteger = 362
Const   UW_MSG_CONGRATULATIONS_YOU_HAVE_WON_THE    As UInteger = 363
Const   UW_MSG_YOU_CANNOT_SAVE_THIS_GAME_BUT_YOU   As UInteger = 364
Const   UW_MSG_YOU_ARE_TOO_AFRAID                  As UInteger = 365
Const   UW_MSG_YOUR_HANDS_STOP_GLOWING             As UInteger = 366
Const   UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING   As UInteger = 367
Const   UW_MSG_A_VEIL_OF_DARKNESS_SURROUNDS_YOU    As UInteger = 368
Const   UW_MSG_YOU_FEEL_TERRIFIED                  As UInteger = 369
Const   UW_MSG_YOU_FEEL_DRUGGED                    As UInteger = 370
Const   UW_MSG_INTERNAL_ERROR_IN_PLAYEREAT         As UInteger = 371
Const   UW_MSG_YOU_FEEL_MORE_EXPERIENCED           As UInteger = 372
Const   UW_MSG_YOU_ARE_COVERED_BY_A_VEIL_OF        As UInteger = 373
Const   UW_MSG_HEY_THIS_IS_GOOD_STUFF_HICK         As UInteger = 374
Const   UW_MSG_YOU_FEEL_VERY_SICK                  As UInteger = 375
Const   UW_MSG_YOU_FEEL_YOUR_MEMORIES_FADE         As UInteger = 376
Const   UW_MSG_THE_POTION_MAKES_YOU_VOMIT          As UInteger = 377
Const   UW_MSG_THE_EFFECT_OF_THE_POISON_HAS_BEEN   As UInteger = 378
Const   UW_MSG_YOUR_FEEL_YOUR_HEAD_CLEAR           As UInteger = 379
Const   UW_MSG_YOUR_EYES_BEGIN_TO_TINGLE           As UInteger = 380
Const   UW_MSG_INTERNAL_ERROR_IN_POTION            As UInteger = 381
Const   UW_MSG_YOU_FEEL_LESS_THIRSTY               As UInteger = 382
Const   UW_MSG_YOU_ARE_TOO_CONFUSED                As UInteger = 383
Const   UW_MSG_YOU_CANT_SEE_TO_READ_YOUR_SPELL     As UInteger = 384
Const   UW_MSG_YOU_HAVE_NO_LIGHT_TO_READ_BY        As UInteger = 385
Const   UW_MSG_YOU_SEEM_TO_BE_MISSING_A_BOOK       As UInteger = 386
Const   UW_MSG_YOU_ARE_NOT_CARRYING_ANY_BOOKS      As UInteger = 387
Const   UW_MSG_YOU_DO_NOT_UNDERSTAND_THE_LANGUAGE  As UInteger = 388
Const   UW_MSG_YOU_CANT_LEARN_ANY_NEW_SPELLS       As UInteger = 389
Const   UW_MSG_IT_WAS_A_GOOD_HIT_X2_DAMAGE         As UInteger = 390
Const   UW_MSG_IT_WAS_AN_EXCELLENT_HIT_X3_DAMAGE   As UInteger = 391
Const   UW_MSG_IT_WAS_A_SUPERB_HIT_X4_DAMAGE       As UInteger = 392
Const   UW_MSG_IT_WAS_A_GREAT_HIT_X5_DAMAGE        As UInteger = 393
Const   UW_MSG_YOU_ARE_CONFUSED                    As UInteger = 394
Const   UW_MSG_PRAY_HARD_ENOUGH_AND_YOUR_PRAYERS   As UInteger = 395
Const   UW_MSG_BUT_YOU_ARE_NOT_CARRYING_ANYTHING_2 As UInteger = 396
Const   UW_MSG_YOU_CANT_CAST_SPELLS                As UInteger = 397
Const   UW_MSG_YOU_DONT_KNOW_ANY_PRAYERS_IN_THAT   As UInteger = 398
Const   UW_MSG_YOU_DONT_KNOW_ANY_SPELLS_IN_THAT    As UInteger = 399
Const   UW_MSG_YOU_LOST_YOUR_CONCENTRATION         As UInteger = 400
Const   UW_MSG_YOU_FAILED_TO_GET_THE_SPELL_OFF     As UInteger = 401
Const   UW_MSG_YOU_FAINT_FROM_FATIGUE              As UInteger = 402
Const   UW_MSG_YOU_FAINT_FROM_THE_EFFORT           As UInteger = 403
Const   UW_MSG_YOU_HAVE_DAMAGED_YOUR_HEALTH        As UInteger = 404
Const   UW_MSG_A_SMALL_NEEDLE_HAS_PRICKED_YOU      As UInteger = 405
Const   UW_MSG_YOU_FEEL_WEAKENED                   As UInteger = 406
Const   UW_MSG_A_PUFF_OF_YELLOW_GAS_SURROUNDS_YOU  As UInteger = 407
Const   UW_MSG_YOU_CHOKE_AND_PASS_OUT              As UInteger = 408
Const   UW_MSG_THERE_IS_A_SUDDEN_EXPLOSION         As UInteger = 409
Const   UW_MSG_YOU_ARE_TOO_CONFUSED_TO_PICK_THE    As UInteger = 410
Const   UW_MSG_YOU_HAVE_PICKED_THE_LOCK            As UInteger = 411
Const   UW_MSG_I_DONT_SEE_A_TRAP                   As UInteger = 412
Const   UW_MSG_THE_CHEST_WAS_NOT_TRAPPED           As UInteger = 413
Const   UW_MSG_YOU_HAVE_DISARMED_THE_CHEST         As UInteger = 414
Const   UW_MSG_YOU_SET_A_TRAP_OFF                  As UInteger = 415
Const   UW_MSG_YOU_HAVE_DESTROYED_THE_CHEST        As UInteger = 416
Const   UW_MSG_AND_ITS_CONTENTS                    As UInteger = 417
Const   UW_MSG_THE_LOCK_BREAKS_OPEN                As UInteger = 418
Const   UW_MSG_CLICK                               As UInteger = 419
Const   UW_MSG_YOU_HAVE_DISCOVERED_A_TRAP_ON_THE   As UInteger = 420
Const   UW_MSG_THE_CHEST_IS_TRAPPED                As UInteger = 421
Const   UW_MSG_INVALID_COMMAND_WITH_A_COUNT        As UInteger = 422
Const   UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING_TO    As UInteger = 423
Const   UW_MSG_BUT_YOU_ARE_NOT_USING_A_LAMP        As UInteger = 424
Const   UW_MSG_YOU_HAVE_NO_OIL                     As UInteger = 425
Const   UW_MSG_YOUR_LAMP_OVERFLOWS_SPILLING_OIL    As UInteger = 426
Const   UW_MSG_YOUR_LAMP_IS_FULL                   As UInteger = 427
Const   UW_MSG_YOUR_LAMP_IS_MORE_THAN_HALF_FULL    As UInteger = 428
Const   UW_MSG_YOUR_LAMP_IS_HALF_FULL              As UInteger = 429
Const   UW_MSG_YOUR_LAMP_IS_LESS_THAN_HALF_FULL    As UInteger = 430
Const   UW_MSG_INVALID_REST_COUNT                  As UInteger = 431
Const   UW_MSG_BUT_YOURE_NOT_CARRYING_ANYTHING     As UInteger = 432
Const   UW_MSG_THERES_NO_ROOM_TO_DROP_ANYTHING     As UInteger = 433
Const   UW_MSG_YOU_ARE_A_TOTAL_WINNER_YOUR         As UInteger = 434
Const   UW_MSG_USE_Q_WHEN_YOU_ARE_READY_TO_QUIT    As UInteger = 435
Const   UW_MSG_COMPACTING_OBJECTS                  As UInteger = 436
Const   UW_MSG_COMPACTING_MONSTERS                 As UInteger = 437
Const   UW_MSG_THE_STAFF_GLOWS_BLUE_FOR_A_MOMENT   As UInteger = 438
Const   UW_MSG_INTERNAL_ERROR_IN_STAFFS            As UInteger = 439
Const   UW_MSG_A_LINE_OF_BLUE_SHIMMERING_LIGHT     As UInteger = 440
Const   UW_MSG_INTERNAL_ERROR_IN_WANDS             As UInteger = 441
Const   UW_MSG_YOU_FEEL_SICK_FOR_A_MOMENT_IT       As UInteger = 442
Const   UW_MSG_YOU_BECOME_DIZZY_FOR_A_MOMENT_IT    As UInteger = 443
Const   UW_MSG_YOU_BECOME_VERY_DIZZY               As UInteger = 444
Const   UW_MSG_YOU_FEEL_NAIVE_FOR_A_MOMENT_IT      As UInteger = 445
Const   UW_MSG_YOU_FEEL_VERY_NAIVE                 As UInteger = 446
Const   UW_MSG_YOU_FEEL_SORE_FOR_A_MOMENT_IT       As UInteger = 447
Const   UW_MSG_YOU_FEEL_VERY_SORE                  As UInteger = 448
Const   UW_MSG_YOUR_SKIN_STARTS_TO_ITCH_BUT        As UInteger = 449
Const   UW_MSG_YOUR_SKIN_STARTS_TO_ITCH            As UInteger = 450
Const   UW_MSG_YOU_FEEL_A_LITTLE_BETTER            As UInteger = 451
Const   UW_MSG_YOU_FEEL_BETTER                     As UInteger = 452
Const   UW_MSG_YOU_FEEL_MUCH_BETTER                As UInteger = 453
Const   UW_MSG_YOU_FEEL_VERY_GOOD                  As UInteger = 454
Const   UW_MSG_YOU_ARE_BLOATED_FROM_OVEREATING     As UInteger = 455
Const   UW_MSG_YOU_ARE_FULL                        As UInteger = 456
Const   UW_MSG_YOU_FEEL_YOUR_LIFE_ENERGIES         As UInteger = 457
Const   UW_MSG_IMPOSSIBLE_I_DONT_SEE_HOW_YOU_CAN   As UInteger = 458
Const   UW_MSG_YOU_WILL_HAVE_TO_DROP_SOMETHING     As UInteger = 459
Const   UW_MSG_OOPS_IT_FEELS_DEATHLY_COLD          As UInteger = 460
Const   UW_MSG_HMMM_IT_SEEMS_TO_BE_CURSED          As UInteger = 461
Const   UW_MSG_YOU_CANT_CARRY_IT                   As UInteger = 462
Const   UW_MSG_BUT_YOU_ARE_WIELDING_NO_WEAPONS     As UInteger = 463
Const   UW_MSG_NO_PRIMARY_WEAPON                   As UInteger = 464
Const   UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING       As UInteger = 465
Const   UW_MSG_YOU_ARE_NOT_USING_ANY_EQUIPMENT     As UInteger = 466
Const   UW_MSG_YOU_HAVE_NOTHING_TO_WEAR_OR_WIELD   As UInteger = 467
Const   UW_MSG_YOU_ARE_AFRAID                      As UInteger = 468
Const   UW_MSG_THE_DOOR_CRASHES_OPEN               As UInteger = 469
Const   UW_MSG_YOU_ARE_OFF_BALANCE                 As UInteger = 470
Const   UW_MSG_THE_DOOR_HOLDS_FIRM                 As UInteger = 471
Const   UW_MSG_YOU_BASH_IT_BUT_NOTHING             As UInteger = 472
Const   UW_MSG_YOU_BASH_AT_EMPTY_SPACE             As UInteger = 473
Const   UW_MSG_THAT_ISNT_A_DOOR                    As UInteger = 474
Const   UW_MSG_THE_DOOR_MUST_BE_CLOSED_FIRST       As UInteger = 475
Const   UW_MSG_BUT_YOU_HAVE_NO_SPIKES              As UInteger = 476
Const   UW_MSG_I_AM_SORRY_BUT_I_HAVE_NOT_THE       As UInteger = 477
Const   UW_MSG_AFTER_A_LONG_BARGAINING_SESSION     As UInteger = 478
Const   UW_MSG_YOU_HAVENT_EVEN_MADE_YOUR_FIRST     As UInteger = 479
Const   UW_MSG_YOU_CANT_SEE_YOUR_MAP               As UInteger = 480
Const   UW_MSG_YOUVE_GONE_PAST_THE_END_OF_YOUR     As UInteger = 481
Const   UW_MSG_YOU_HAVE_TROUBLE_WIELDING_SUCH_A    As UInteger = 482
Const   UW_MSG_YOU_ARE_STRONG_ENOUGH_TO_WIELD      As UInteger = 483
Const   UW_MSG_YOUR_PACK_IS_SO_HEAVY_THAT_IT       As UInteger = 484
Const   UW_MSG_YOU_MOVE_MORE_EASILY_UNDER_THE      As UInteger = 485
Const   UW_MSG_YOU_COMBINE_SIMILAR_OBJECTS_FROM    As UInteger = 486
Const   UW_MSG_I_DO_NOT_BUY_SUCH_ITEMS             As UInteger = 487
Const   UW_MSG_YOU_CANT_SEE_A_DAMN_THING           As UInteger = 488
Const   UW_MSG_YOU_CANT_BELIEVE_WHAT_YOU_ARE       As UInteger = 489
Const   UW_MSG_ABORTING_LOOK                       As UInteger = 490
Const   UW_MSG_THATS_ALL_YOU_SEE                   As UInteger = 491
Const   UW_MSG_THATS_ALL_YOU_SEE_IN_THAT           As UInteger = 492
Const   UW_MSG_YOU_SEE_NOTHING_OF_INTEREST         As UInteger = 493
Const   UW_MSG_YOU_SEE_NOTHING_OF_INTEREST_IN      As UInteger = 494
Const   UW_MSG_THERE_IS_SMOKE_COMING_FROM_YOUR     As UInteger = 495
Const   UW_MSG_YOU_ARE_COVERED_IN_ACID             As UInteger = 496
Const   UW_MSG_THERE_IS_AN_ACRID_SMELL_COMING      As UInteger = 497
Const   UW_MSG_YOU_ARE_COVERED_WITH_FROST          As UInteger = 498
Const   UW_MSG_SOMETHING_SHATTERS_INSIDE_YOUR      As UInteger = 499
Const   UW_MSG_LIGHTNING_STRIKES_YOU               As UInteger = 500
Const   UW_MSG_THERE_ARE_SPARKS_COMING_FROM_YOUR   As UInteger = 501
Const   UW_MSG_A_STINGING_RED_GAS_SWIRLS_ABOUT     As UInteger = 502
Const   UW_MSG_THERE_IS_AN_ACRID_SMELL_COMING_2    As UInteger = 503
Const   UW_MSG_YOU_QUICKLY_PROTECT_YOUR_MONEY      As UInteger = 504
Const   UW_MSG_YOUR_PURSE_FEELS_LIGHTER            As UInteger = 505
Const   UW_MSG_THERE_IS_A_PUFF_OF_SMOKE            As UInteger = 506
Const   UW_MSG_YOU_GRAB_HOLD_OF_YOUR_BACKPACK      As UInteger = 507
Const   UW_MSG_YOUR_BACKPACK_FEELS_LIGHTER         As UInteger = 508
Const   UW_MSG_THERE_IS_A_STATIC_FEELING_IN_THE    As UInteger = 509
Const   UW_MSG_IT_GOT_AT_YOUR_RATIONS              As UInteger = 510
Const   UW_MSG_YOUR_LIGHT_DIMS                     As UInteger = 511
Const   UW_MSG_ENERGY_DRAINS_FROM_YOUR_PACK        As UInteger = 512
Const   UW_MSG_YOUVE_BEEN_SLIMED                   As UInteger = 513
Const   UW_MSG_YOU_HEAR_A_SUDDEN_STIRRING_IN_THE   As UInteger = 514
Const   UW_MSG_YOU_FEEL_WEAKER_FOR_A_MOMENT_BUT    As UInteger = 515
Const   UW_MSG_YOU_FEEL_WEAKER                     As UInteger = 516
Const   UW_MSG_YOU_FEEL_CONFUSED                   As UInteger = 517
Const   UW_MSG_YOU_RESIST_THE_EFFECTS              As UInteger = 518
Const   UW_MSG_YOU_ARE_SUDDENLY_AFRAID             As UInteger = 519
Const   UW_MSG_YOUR_EYES_BEGIN_TO_STING            As UInteger = 520
Const   UW_MSG_YOU_ARE_PARALYZED                   As UInteger = 521
Const   UW_MSG_YOU_FEEL_CLUMSY_FOR_A_MOMENT_BUT    As UInteger = 522
Const   UW_MSG_YOU_FEEL_MORE_CLUMSY                As UInteger = 523
Const   UW_MSG_YOUR_BODY_RESISTS_THE_EFFECTS_OF    As UInteger = 524
Const   UW_MSG_YOUR_HEALTH_IS_DAMAGED              As UInteger = 525
Const   UW_MSG_YOU_HAVE_TROUBLE_THINKING_CLEARLY   As UInteger = 526
Const   UW_MSG_BUT_YOUR_MIND_QUICKLY_CLEARS        As UInteger = 527
Const   UW_MSG_YOUR_WISDOM_IS_SUSTAINED            As UInteger = 528
Const   UW_MSG_YOUR_WISDOM_IS_DRAINED              As UInteger = 529
Const   UW_MSG_YOU_FEEL_YOUR_LIFE_DRAINING_AWAY    As UInteger = 530
Const   UW_MSG_HITS_YOU                            As UInteger = 531
Const   UW_MSG_BITES_YOU                           As UInteger = 532
Const   UW_MSG_CLAWS_YOU                           As UInteger = 533
Const   UW_MSG_STINGS_YOU                          As UInteger = 534
Const   UW_MSG_TOUCHES_YOU                         As UInteger = 535
Const   UW_MSG_GAZES_AT_YOU                        As UInteger = 536
Const   UW_MSG_BREATHES_ON_YOU                     As UInteger = 537
Const   UW_MSG_SPITS_ON_YOU                        As UInteger = 538
Const   UW_MSG_MAKES_A_HORRIBLE_WAIL               As UInteger = 539
Const   UW_MSG_CRAWLS_ON_YOU                       As UInteger = 540
Const   UW_MSG_RELEASES_A_CLOUD_OF_SPORES          As UInteger = 541
Const   UW_MSG_BEGS_YOU_FOR_MONEY                  As UInteger = 542
Const   UW_MSG_CRUSHES_YOU                         As UInteger = 543
Const   UW_MSG_TRAMPLES_YOU                        As UInteger = 544
Const   UW_MSG_DROOLS_ON_YOU                       As UInteger = 545
Const   UW_MSG_INSULTS_YOU                         As UInteger = 546
Const   UW_MSG_INSULTS_YOUR_MOTHER                 As UInteger = 547
Const   UW_MSG_GIVES_YOU_THE_FINGER                As UInteger = 548
Const   UW_MSG_HUMILIATES_YOU                      As UInteger = 549
Const   UW_MSG_WETS_ON_YOUR_LEG                    As UInteger = 550
Const   UW_MSG_DEFILES_YOU                         As UInteger = 551
Const   UW_MSG_DANCES_AROUND_YOU                   As UInteger = 552
Const   UW_MSG_MAKES_OBSCENE_GESTURES              As UInteger = 553
Const   UW_MSG_MOONS_YOU                           As UInteger = 554
Const   UW_MSG_IS_REPELLED                         As UInteger = 555
Const   UW_MSG_IS_UNAFFECTED                       As UInteger = 556
Const   UW_MSG_APPEARS_CONFUSED                    As UInteger = 557
Const   UW_MSG_MISSES_YOU                          As UInteger = 558
Const   UW_MSG_YOU_HEAR_A_DOOR_BURST_OPEN          As UInteger = 559
Const   UW_MSG_YOU_HEAR_A_SCREAM_MUFFLED_BY_ROCK   As UInteger = 560
Const   UW_MSG_A_CREATURE_DIGS_ITSELF_OUT_FROM     As UInteger = 561
Const   UW_MSG_THE_RUNE_OF_PROTECTION_IS_BROKEN    As UInteger = 562
Const   UW_MSG_MAGICALLY_SUMMONS_A_MONSTER         As UInteger = 563
Const   UW_MSG_MAGICALLY_SUMMONS_AN_UNDEAD         As UInteger = 564
Const   UW_MSG_DRAWS_PSYCHIC_ENERGY_FROM_YOU       As UInteger = 565
Const   UW_MSG_APPEARS_HEALTHIER                   As UInteger = 566
Const   UW_MSG_BREATHES_LIGHTNING                  As UInteger = 567
Const   UW_MSG_BREATHES_GAS                        As UInteger = 568
Const   UW_MSG_BREATHES_ACID                       As UInteger = 569
Const   UW_MSG_BREATHES_FROST                      As UInteger = 570
Const   UW_MSG_BREATHES_FIRE                       As UInteger = 571
Const   UW_MSG_CAST_UNKNOWN_SPELL                  As UInteger = 572
Const   UW_MSG_CASTS_A_SPELL                       As UInteger = 573
Const   UW_MSG_I_DO_NOT_SEE_ANYTHING_YOU_CAN       As UInteger = 574
Const   UW_MSG_IT_APPEARS_TO_BE_STUCK              As UInteger = 575
Const   UW_MSG_I_DO_NOT_SEE_ANYTHING_YOU_CAN_2     As UInteger = 576
Const   UW_MSG_THE_DOOR_APPEARS_TO_BE_BROKEN       As UInteger = 577
Const   UW_MSG_YOU_HAVE_FOUND_A_SECRET_DOOR        As UInteger = 578
Const   UW_MSG_YOU_FEEL_SOMETHING_ROLL_BENEATH     As UInteger = 579
Const   UW_MSG_THE_ENCHANTMENT_FAILS               As UInteger = 580
Const   UW_MSG_YOU_CANT_SEE_TO_READ_THE_SCROLL     As UInteger = 581
Const   UW_MSG_YOU_ARE_TOO_CONFUSED_TO_READ_A      As UInteger = 582
Const   UW_MSG_YOU_ARE_NOT_CARRYING_ANYTHING_2     As UInteger = 583
Const   UW_MSG_YOU_ARE_NOT_CARRYING_ANY_SCROLLS    As UInteger = 584
Const   UW_MSG_THIS_IS_AN_IDENTIFY_SCROLL          As UInteger = 585
Const   UW_MSG_YOU_FEEL_AS_IF_SOMEONE_IS           As UInteger = 586
Const   UW_MSG_YOUR_HANDS_BEGIN_TO_GLOW            As UInteger = 587
Const   UW_MSG_THIS_IS_A_MASS_GENOCIDE_SCROLL      As UInteger = 588
Const   UW_MSG_THERE_IS_A_HIGH_PITCHED_HUMMING     As UInteger = 589
Const   UW_MSG_THIS_IS_A_RECHARGE_ITEM_SCROLL      As UInteger = 590
Const   UW_MSG_THIS_IS_A_GENOCIDE_SCROLL           As UInteger = 591
Const   UW_MSG_THE_AIR_ABOUT_YOU_BECOMES_CHARGED   As UInteger = 592
Const   UW_MSG_INTERNAL_ERROR_IN_SCROLL            As UInteger = 593
Const   UW_MSG_YOU_HAVE_NOTHING_TO_RECHARGE        As UInteger = 594
Const   UW_MSG_THERE_IS_A_BRIGHT_FLASH_OF_LIGHT    As UInteger = 595
Const   UW_MSG_THERE_IS_A_SCREAM_OF_AGONY          As UInteger = 596
Const   UW_MSG_THERE_ARE_SEVERAL_SCREAMS_OF_AGONY  As UInteger = 597
Const   UW_MSG_THE_END_OF_THE_STAFF_BURSTS_INTO    As UInteger = 598
Const   UW_MSG_YOU_SENSE_THE_PRESENCE_OF_MONSTERS  As UInteger = 599
Const   UW_MSG_YOU_SENSE_THE_PRESENCE_OF_EVIL      As UInteger = 600
Const   UW_MSG_THE_WALL_TURNS_INTO_MUD             As UInteger = 601
Const   UW_MSG_THERE_IS_A_BRIGHT_FLASH_OF_LIGHT_2  As UInteger = 602
Const   UW_MSG_YOU_ARE_SURROUNDED_BY_A_WHITE       As UInteger = 603
Const   UW_MSG_DARKNESS_SURROUNDS_YOU              As UInteger = 604
Const   UW_MSG_YOU_SENSE_THE_PRESENCE_OF           As UInteger = 605
Const   UW_MSG_THERE_IS_ALREADY_AN_OBJECT_UNDER    As UInteger = 606
Const   UW_MSG_THERE_IS_A_SEARING_BLAST_OF_LIGHT   As UInteger = 607
Const   UW_MSG_YOU_HAVE_KILLED_SOMETHING           As UInteger = 608
Const   UW_MSG_YOU_FEEL_LIKE_A_HERO                As UInteger = 609
Const   UW_MSG_THE_HEROISM_WEARS_OFF               As UInteger = 610
Const   UW_MSG_YOU_FEEL_LIKE_A_SUPER_HERO          As UInteger = 611
Const   UW_MSG_THE_SUPER_HEROISM_WEARS_OFF         As UInteger = 612
Const   UW_MSG_YOU_FEEL_YOURSELF_MOVING_FASTER     As UInteger = 613
Const   UW_MSG_YOU_FEEL_YOURSELF_SLOW_DOWN         As UInteger = 614
Const   UW_MSG_YOU_FEEL_YOURSELF_MOVING_SLOWER     As UInteger = 615
Const   UW_MSG_YOU_FEEL_YOURSELF_SPEED_UP          As UInteger = 616
Const   UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_EVIL   As UInteger = 617
Const   UW_MSG_YOUR_SKIN_TURNS_INTO_STEEL          As UInteger = 618
Const   UW_MSG_YOUR_SKIN_RETURNS_TO_NORMAL         As UInteger = 619
Const   UW_MSG_YOU_FEEL_RIGHTEOUS                  As UInteger = 620
Const   UW_MSG_THE_PRAYER_HAS_EXPIRED              As UInteger = 621
Const   UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_FLAME  As UInteger = 622
Const   UW_MSG_YOU_NO_LONGER_FEEL_SAFE_FROM_COLD   As UInteger = 623
Const   UW_MSG_YOU_FEEL_YOURSELF_YANKED_UPWARDS    As UInteger = 624
Const   UW_MSG_YOU_FEEL_YOURSELF_YANKED_DOWNWARDS  As UInteger = 625
Const   UW_MSG_THE_VEIL_OF_DARKNESS_LIFTS          As UInteger = 626
Const   UW_MSG_YOU_FEEL_LESS_CONFUSED_NOW          As UInteger = 627
Const   UW_MSG_YOU_FEEL_BOLDER_NOW                 As UInteger = 628
Const   UW_MSG_YOU_ARE_GETTING_WEAK_FROM_HUNGER    As UInteger = 629
Const   UW_MSG_YOU_FAINT_FROM_THE_LACK_OF_FOOD     As UInteger = 630
Const   UW_MSG_YOU_ARE_GETTING_HUNGRY              As UInteger = 631
Const   UW_MSG_WARNING_THIS_ROUTINE_CAN_CAUSE_A    As UInteger = 632
Const   UW_MSG_ALLOCATED                           As UInteger = 633
Const   UW_MSG_ABORTED                             As UInteger = 634
Const   UW_MSG_WIZARD_MODE_OFF                     As UInteger = 635
Const   UW_MSG_WIZARD_MODE_IS_FOR_DEBUGGING_AND    As UInteger = 636
Const   UW_MSG_WIZARD_MODE_ON                      As UInteger = 637
Const   UW_MSG_TYPE_FOR_HELP                       As UInteger = 638
Const   UW_MSG_NOT_IN_THIS_VERSION_RANDOM          As UInteger = 639
Const   UW_MSG_TYPE_OR_H_FOR_HELP                  As UInteger = 640
Const   UW_MSG_THIS_SAVE_FILE_CANNOT_BE_USED_TO    As UInteger = 641
Const   UW_MSG_I_AM_CURRENTLY_OUT_OF_STOCK         As UInteger = 642
Const   UW_MSG_LIAR_YOU_HAVE_NOT_THE_GOLD          As UInteger = 643
Const   UW_MSG_YOU_HAVE_NOTHING_TO_SELL_TO_THIS    As UInteger = 644
Const   UW_MSG_I_HAVE_NOT_THE_ROOM_IN_MY_STORE     As UInteger = 645
Const   UW_MSG_HOW_DARE_YOU                        As UInteger = 646
Const   UW_MSG_I_WILL_NOT_BUY_THAT                 As UInteger = 647
Const   UW_MSG_THE_DOORS_ARE_LOCKED                As UInteger = 648
Const   UW_MSG_ENTIRE_INVENTORY_IS_SHOWN           As UInteger = 649
Const   UW_MSG_USE_CONTROL_K_WHEN_YOU_ARE_READY_TO_QUIT As UInteger = 650
Const   UW_MSG_TYPE_OR_BACKSLASH_FOR_HELP          As UInteger = 651

' two of the bits of the player's status, and how much each point of strength lets the player carry (config.cpp)
#define UL_PY_HUNGRY            $00000001
#define UL_PY_WEAK              $00000002
#define UL_PY_BLIND             $00000004
#define UL_PY_FAST              $00000040
#define UL_PY_SLOW              $00000080
#define UL_PY_SEARCH            $00000100
#define UL_PY_REST              $00000200
#define UL_PY_STUDY             $00000400
#define UL_PY_INVULN            $00001000
#define UL_PY_HERO              $00002000
#define UL_PY_SHERO             $00004000
#define UL_PY_BLESSED           $00008000
#define UL_PY_DET_INV           $00010000
#define UL_PY_TIM_INFRA         $00020000
#define UL_PY_CONFUSED          $00000008
#define UL_PY_FEAR              $00000010
#define UL_PY_POISONED          $00000020
#define UL_PY_PARALYSED         $00100000
#define UL_PY_SPEED             $00040000
#define UL_PY_STR_WGT           $00080000
#define UB_PLAYER_WEIGHT_CAP    130

' the routines in the stores library, see stage-lib-stores.bas...
Const   UB_LIB_STORES_MAINTAIN      As UByte    = 1
Const   UB_LIB_STORES_VALUE         As UByte    = 2
Const   UB_LIB_STORES_SELL_PRICE    As UByte    = 3
Const   UB_LIB_STORES_CARRY         As UByte    = 4
Const   UB_LIB_STORES_DESTROY       As UByte    = 5
Const   UB_LIB_STORES_TEST          As UByte    = 6
Const   UB_LIB_STORES_HAS_ROOM      As UByte    = 7

' the routines in the treasure library, see stage-lib-treasure.bas...
Const   UB_LIB_TREASURE_MAGIC       As UByte    = 1
Const   UB_LIB_TREASURE_TEST        As UByte    = 2

' the routines in the character library, see stage-lib-character.bas...
Const   UB_LIB_CHAR_TO_HIT          As UByte    = 1
Const   UB_LIB_CHAR_DAMAGE          As UByte    = 2
Const   UB_LIB_CHAR_AC              As UByte    = 3
Const   UB_LIB_CHAR_DISARM          As UByte    = 4
Const   UB_LIB_CHAR_CON             As UByte    = 5
Const   UB_LIB_CHAR_WIS_INT         As UByte    = 6
Const   UB_LIB_CHAR_MODIFY_STAT     As UByte    = 7
Const   UB_LIB_CHAR_SET_STATS       As UByte    = 8
Const   UB_LIB_CHAR_PRINT_INFO      As UByte    = 9
Const   UB_LIB_CHAR_PRINT_STATS     As UByte    = 10
Const   UB_LIB_CHAR_PRINT_VITALS    As UByte    = 11
Const   UB_LIB_CHAR_PRINT_HISTORY   As UByte    = 12
Const   UB_LIB_CHAR_PRINT_LEVEL     As UByte    = 13
Const   UB_LIB_CHAR_PRINT_ABILITIES As UByte    = 14
Const   UB_LIB_CHAR_CHARISMA        As UByte    = 15
Const   UB_LIB_CHAR_PRINT_BLOCK     As UByte    = 16

' the names items go by, in the game tables page, each list is fixed width, see create-data.ps1...
#define A_TABLE_COLOURS         A_MMU_SLOT_PAGED_DB_MAPS + 2048     ' 49 potion colours
#define A_TABLE_MUSHROOMS       A_MMU_SLOT_PAGED_DB_MAPS + 3072     ' 22 mushroom kinds
#define A_TABLE_WOODS           A_MMU_SLOT_PAGED_DB_MAPS + 3584     ' 25 staff woods
#define A_TABLE_METALS          A_MMU_SLOT_PAGED_DB_MAPS + 4096     ' 25 wand metals
#define A_TABLE_ROCKS           A_MMU_SLOT_PAGED_DB_MAPS + 4608     ' 32 ring stones
#define A_TABLE_AMULETS         A_MMU_SLOT_PAGED_DB_MAPS + 5632     ' 11 amulet materials
#define A_TABLE_SYLLABLES       A_MMU_SLOT_PAGED_DB_MAPS + 5888     ' 153 syllables, for scroll titles
#define A_TABLE_SPECIAL_NAMES   A_MMU_SLOT_PAGED_DB_MAPS + 6656     ' 55 special names, e.g. "of Slay Evil", number 1 is the first (0 means none)
Const   UB_FLAVOUR_NAME_SIZE    As UByte    = 16
Const   UB_SYLLABLE_SIZE        As UByte    = 5
Const   UB_SPECIAL_NAME_SIZE    As UByte    = 20
Const   UB_MAX_COLOURS          As UByte    = 49
Const   UB_MAX_MUSHROOMS        As UByte    = 22
Const   UB_MAX_WOODS            As UByte    = 25
Const   UB_MAX_METALS           As UByte    = 25
Const   UB_MAX_ROCKS            As UByte    = 32
Const   UB_MAX_AMULETS          As UByte    = 11
Const   UB_MAX_SYLLABLES        As UByte    = 153
Const   UB_MAX_TITLES           As UByte    = 45

' what the player knows about items, in the knowledge page, this is part of a saved game...
' ...each family's "order" says which name each of its kinds has in this game, kind n looks like name number order( n )
#define A_KNOW_COLOURS          A_MMU_SLOT_PAGED_DB_MAPS + 6144     ' 49 bytes
#define A_KNOW_MUSHROOMS        A_MMU_SLOT_PAGED_DB_MAPS + 6208     ' 22 bytes
#define A_KNOW_WOODS            A_MMU_SLOT_PAGED_DB_MAPS + 6240     ' 25 bytes
#define A_KNOW_METALS           A_MMU_SLOT_PAGED_DB_MAPS + 6272     ' 25 bytes
#define A_KNOW_ROCKS            A_MMU_SLOT_PAGED_DB_MAPS + 6304     ' 32 bytes
#define A_KNOW_AMULETS          A_MMU_SLOT_PAGED_DB_MAPS + 6336     ' 11 bytes
#define A_KNOW_TITLES           A_MMU_SLOT_PAGED_DB_MAPS + 6400     ' 45 scroll titles of 10 bytes, each ending in a 0
#define A_KNOW_IDENTIFIED       A_MMU_SLOT_PAGED_DB_MAPS + 6912     ' 448 bytes, 7 families of 64 kinds, the MB_OD_ flags for each (objects_identified)
Const   UB_TITLE_SIZE           As UByte    = 10
Const   UW_KNOW_IDENTIFIED_SIZE As UInteger = 448
#define MB_OD_TRIED             %00000001   ' the player has tried one, and still does not know what it is
#define MB_OD_KNOWN1            %00000010   ' the player knows what this kind is

' what the player knows about one particular item, the bits of its identification byte, these are Moria's ID_ flags
#define MB_ID_MAGIK             %00000001
#define MB_ID_DAMD              %00000010
#define MB_ID_EMPTY             %00000100
#define MB_ID_KNOWN2            %00001000   ' fully identified, its plusses and charges are known
#define MB_ID_STORE_BOUGHT      %00010000
#define MB_ID_SHOW_HIT_DAM      %00100000
#define MB_ID_NO_SHOW_P1        %01000000
#define MB_ID_SHOW_P1           %10000000

' the flags an item can have, one bit each, these are Moria's TR_ flags...
#define UL_TR_STATS         $0000003F   ' the stats must be the low 6 bits
#define UL_TR_STR           $00000001
#define UL_TR_INT           $00000002
#define UL_TR_WIS           $00000004
#define UL_TR_DEX           $00000008
#define UL_TR_CON           $00000010
#define UL_TR_CHR           $00000020
#define UL_TR_SEARCH        $00000040
#define UL_TR_SLOW_DIGEST   $00000080
#define UL_TR_STEALTH       $00000100
#define UL_TR_AGGRAVATE     $00000200
#define UL_TR_TELEPORT      $00000400
#define UL_TR_REGEN         $00000800
#define UL_TR_SPEED         $00001000
#define UL_TR_EGO_WEAPON    $0007E000
#define UL_TR_SLAY_DRAGON   $00002000
#define UL_TR_SLAY_ANIMAL   $00004000
#define UL_TR_SLAY_EVIL     $00008000
#define UL_TR_SLAY_UNDEAD   $00010000
#define UL_TR_FROST_BRAND   $00020000
#define UL_TR_FLAME_TONGUE  $00040000
#define UL_TR_RES_FIRE      $00080000
#define UL_TR_RES_ACID      $00100000
#define UL_TR_RES_COLD      $00200000
#define UL_TR_SUST_STAT     $00400000
#define UL_TR_FREE_ACT      $00800000
#define UL_TR_SEE_INVIS     $01000000
#define UL_TR_RES_LIGHT     $02000000
#define UL_TR_FFALL         $04000000
#define UL_TR_BLIND         $08000000
#define UL_TR_TIMID         $10000000
#define UL_TR_TUNNEL        $20000000
#define UL_TR_INFRA         $40000000
#define UL_TR_CURSED        $80000000

' ...a chest uses the same four bytes for its own flags, Moria's CH_ flags...
#define UL_CH_LOCKED        $00000001
#define UL_CH_TRAPPED       $000001F0
#define UL_CH_LOSE_STR      $00000010
#define UL_CH_POISON        $00000020
#define UL_CH_PARALYSED     $00000040
#define UL_CH_EXPLODE       $00000080
#define UL_CH_SUMMON        $00000100

' the special names an item can have, e.g. "of Slay Evil", the numbers are Moria's, 0 is none, see A_TABLE_SPECIAL_NAMES...
Const   UB_SN_NULL                As UByte = 0
Const   UB_SN_R                   As UByte = 1
Const   UB_SN_RA                  As UByte = 2
Const   UB_SN_RF                  As UByte = 3
Const   UB_SN_RC                  As UByte = 4
Const   UB_SN_RL                  As UByte = 5
Const   UB_SN_HA                  As UByte = 6
Const   UB_SN_DF                  As UByte = 7
Const   UB_SN_SA                  As UByte = 8
Const   UB_SN_SD                  As UByte = 9
Const   UB_SN_SE                  As UByte = 10
Const   UB_SN_SU                  As UByte = 11
Const   UB_SN_FT                  As UByte = 12
Const   UB_SN_FB                  As UByte = 13
Const   UB_SN_FREE_ACTION         As UByte = 14
Const   UB_SN_SLAYING             As UByte = 15
Const   UB_SN_CLUMSINESS          As UByte = 16
Const   UB_SN_WEAKNESS            As UByte = 17
Const   UB_SN_SLOW_DESCENT        As UByte = 18
Const   UB_SN_SPEED               As UByte = 19
Const   UB_SN_STEALTH             As UByte = 20
Const   UB_SN_SLOWNESS            As UByte = 21
Const   UB_SN_NOISE               As UByte = 22
Const   UB_SN_GREAT_MASS          As UByte = 23
Const   UB_SN_INTELLIGENCE        As UByte = 24
Const   UB_SN_WISDOM              As UByte = 25
Const   UB_SN_INFRAVISION         As UByte = 26
Const   UB_SN_MIGHT               As UByte = 27
Const   UB_SN_LORDLINESS          As UByte = 28
Const   UB_SN_MAGI                As UByte = 29
Const   UB_SN_BEAUTY              As UByte = 30
Const   UB_SN_SEEING              As UByte = 31
Const   UB_SN_REGENERATION        As UByte = 32
Const   UB_SN_STUPIDITY           As UByte = 33
Const   UB_SN_DULLNESS            As UByte = 34
Const   UB_SN_BLINDNESS           As UByte = 35
Const   UB_SN_TIMIDNESS           As UByte = 36
Const   UB_SN_TELEPORTATION       As UByte = 37
Const   UB_SN_UGLINESS            As UByte = 38
Const   UB_SN_PROTECTION          As UByte = 39
Const   UB_SN_IRRITATION          As UByte = 40
Const   UB_SN_VULNERABILITY       As UByte = 41
Const   UB_SN_ENVELOPING          As UByte = 42
Const   UB_SN_FIRE                As UByte = 43
Const   UB_SN_SLAY_EVIL           As UByte = 44
Const   UB_SN_DRAGON_SLAYING      As UByte = 45
Const   UB_SN_EMPTY               As UByte = 46
Const   UB_SN_LOCKED              As UByte = 47
Const   UB_SN_POISON_NEEDLE       As UByte = 48
Const   UB_SN_GAS_TRAP            As UByte = 49
Const   UB_SN_EXPLOSION_DEVICE    As UByte = 50
Const   UB_SN_SUMMONING_RUNES     As UByte = 51
Const   UB_SN_MULTIPLE_TRAPS      As UByte = 52
Const   UB_SN_DISARMED            As UByte = 53
Const   UB_SN_UNLOCKED            As UByte = 54
Const   UB_SN_SLAY_ANIMAL         As UByte = 55

' Moria's settings for how magical the things it makes are (config.cpp)...
#define OBJECT_BASE_MAGIC        15     ' Base amount of magic
#define OBJECT_MAX_BASE_MAGIC    70     ' Max amount of magic
#define OBJECT_CHANCE_SPECIAL    6      ' magic_chance/# special magic
#define OBJECT_CHANCE_CURSED     13     ' 10*magic_chance/# cursed items
#define LEVEL_STD_OBJECT_ADJUST  125    ' Adjust STD per level * 100
#define LEVEL_MIN_OBJECT_STD     7      ' Minimum STD
#define LEVEL_TOWN_OBJECTS       7      ' Town object generation level


' the categories of object, Moria's "tval" numbers...
Const   UB_TV_MISC              As UByte    = 1
Const   UB_TV_CHEST             As UByte    = 2
Const   UB_TV_SLING_AMMO        As UByte    = 10
Const   UB_TV_BOLT              As UByte    = 11
Const   UB_TV_ARROW             As UByte    = 12
Const   UB_TV_SPIKE             As UByte    = 13
Const   UB_TV_LIGHT             As UByte    = 15
Const   UB_TV_BOW               As UByte    = 20
Const   UB_TV_HAFTED            As UByte    = 21
Const   UB_TV_POLEARM           As UByte    = 22
Const   UB_TV_SWORD             As UByte    = 23
Const   UB_TV_DIGGING           As UByte    = 25
Const   UB_TV_BOOTS             As UByte    = 30
Const   UB_TV_GLOVES            As UByte    = 31
Const   UB_TV_CLOAK             As UByte    = 32
Const   UB_TV_HELM              As UByte    = 33
Const   UB_TV_SHIELD            As UByte    = 34
Const   UB_TV_HARD_ARMOR        As UByte    = 35
Const   UB_TV_SOFT_ARMOR        As UByte    = 36
Const   UB_TV_AMULET            As UByte    = 40
Const   UB_TV_MIN_WEAR          As UByte    = 10    ' things from this category...
Const   UB_TV_MAX_WEAR          As UByte    = 50    ' ...to this one can be worn or wielded
Const   UB_TV_RING              As UByte    = 45
Const   UB_TV_STAFF             As UByte    = 55
Const   UB_TV_WAND              As UByte    = 65
Const   UB_TV_SCROLL1           As UByte    = 70
Const   UB_TV_SCROLL2           As UByte    = 71
Const   UB_TV_POTION1           As UByte    = 75
Const   UB_TV_POTION2           As UByte    = 76
Const   UB_TV_FLASK             As UByte    = 77
Const   UB_TV_FOOD              As UByte    = 80
Const   UB_TV_MAGIC_BOOK        As UByte    = 90
Const   UB_TV_PRAYER_BOOK       As UByte    = 91
Const   UB_TV_INVIS_TRAP        As UByte    = 101
Const   UB_TV_VIS_TRAP          As UByte    = 102
Const   UB_TV_RUBBLE            As UByte    = 103
Const   UB_TV_OPEN_DOOR         As UByte    = 104
Const   UB_TV_CLOSED_DOOR       As UByte    = 105
Const   UB_TV_UP_STAIR          As UByte    = 107
Const   UB_TV_DOWN_STAIR        As UByte    = 108
Const   UB_TV_SECRET_DOOR       As UByte    = 109
Const   UB_TV_STORE_DOOR        As UByte    = 110
Const   UB_TV_MAX_PICK_UP       As UByte    = 100   ' things up to this category can be picked up, above it are traps, doors and stairs
Const   UB_TV_MAX_OBJECT        As UByte    = 99    ' things up to this category can be picked up by monsters, i.e. everything but gold

' ...the six stores: their state is here, what they have in stock is in the store items pages
#define A_STORES        A_MMU_SLOT_CORE_DATA + 1536     'size  96, 6 stores of 16 bytes, see globals.bas

' how the game tables page is laid out, see create-data.ps1...
#define A_TABLE_OWNERS          A_MMU_SLOT_PAGED_DB_MAPS            ' 18 store owners of 64 bytes
#define A_TABLE_STORE_CHOICES   A_MMU_SLOT_PAGED_DB_MAPS + 1152     ' 6 stores of 26 object numbers, 2 bytes each
' ...and the colours of things on the map, ours, from src\colours.txt, see create-data.ps1
#define A_TABLE_FLAVOUR_COLOURS     A_MMU_SLOT_PAGED_DB_MAPS + 1536     ' each flavour's attribute byte, the six lists one after another...
#define UB_FLAVOUR_POTIONS          0       ' ...where each list starts in it: 49 potion colours
#define UB_FLAVOUR_MUSHROOMS        49      ' 22 mushroom kinds
#define UB_FLAVOUR_WOODS            71      ' 25 staff woods
#define UB_FLAVOUR_METALS           96      ' 25 wand metals
#define UB_FLAVOUR_ROCKS            121     ' 32 ring stones
#define UB_FLAVOUR_AMULETS          153     ' 11 amulet materials
#define UB_FLAVOUR_COUNT            164
#define A_TABLE_PALETTE             A_MMU_SLOT_PAGED_DB_MAPS + 1792     ' how many pairs, then each pair's ink, two bytes as NEXTREG_PALETTE_VALUE_9 takes them
#define UB_FIRST_COLOUR_PAIR        16      ' the colours' pairs come after the screen's own 16, see load.bas
#define A_TABLE_RACE_PRICES     A_MMU_SLOT_PAGED_DB_MAPS + 1464     ' 8 rows (the owner's race) of 8 bytes (the player's race)
Const   UB_OWNER_SIZE           As UByte    = 64
' ...where things are in a store owner's record, the name is 52 bytes of text at its start
#define UB_OWNER_MAX_COST       52      ' 2 bytes: the most they will pay for anything
#define UB_OWNER_MAX_INFLATE    54      ' their highest mark up, a percentage
#define UB_OWNER_MIN_INFLATE    55      ' and their lowest
#define UB_OWNER_HAGGLE         56      ' how big their haggling steps are, a percentage
#define UB_OWNER_RACE           57
#define UB_OWNER_MAX_INSULTS    58      ' how many insults they will take before throwing the player out
' ...Moria's settings for how the stores turn their stock over (config.cpp)
#define UB_STORE_MAX_AUTO_BUY   18      ' a store with more different items than this buys nothing in
#define UB_STORE_MIN_AUTO_SELL  10      ' a store with fewer than this sells nothing off
#define UB_STORE_TURN_AROUND    9       ' the most it normally buys or sells at one time
Const   UB_OWNERS               As UByte    = 18        ' three to choose from for each store
Const   UB_STORE_STATE_SIZE     As UByte    = 16
Const   UB_STORE_MAX_ITEMS      As UByte    = 24        ' the most different items a store can hold (STORE_MAX_DISCRETE_ITEMS)
Const   UB_STORE_ITEM_TYPES     As UByte    = 26        ' how many kinds of object each store chooses its stock from
Const   UW_OBJ_NOTHING          As UInteger = 417       ' the object that stands for "no item"
Const   UW_OBJ_RUINED_CHEST     As UInteger = 418       ' what a chest that has been bashed to bits becomes
Const   UW_OBJ_WIZARD           As UInteger = 419       ' what an object made up by the wizard's @ command is (OBJ_WIZARD)

' how the character database page is laid out, see create-data.ps1...
#define A_CHARACTER_RACES       A_MMU_SLOT_PAGED_DB_MAPS            ' 8 races of 64 bytes
#define A_CHARACTER_CLASSES     A_MMU_SLOT_PAGED_DB_MAPS + 512      ' 6 classes of 64 bytes
#define A_CHARACTER_BACKGROUNDS A_MMU_SLOT_PAGED_DB_MAPS + 1024     ' 128 backgrounds of 56 bytes
#define A_CHARACTER_PROVISIONS  A_MMU_SLOT_PAGED_DB_MAPS + 896      ' what each of the 6 classes starts with, 5 object numbers of 2 bytes each
Const   UB_CHARACTER_RECORD_SIZE As UByte   = 64        ' a race or a class, in the database and at A_RACE and A_CLASS
Const   UB_BACKGROUND_SIZE      As UByte    = 56
Const   UB_BACKGROUND_ROLL      As UByte    = 0         ' a background's fields: the d100 roll it is taken up to
Const   UB_BACKGROUND_CHART     As UByte    = 1         ' the chart it belongs to
Const   UB_BACKGROUND_NEXT      As UByte    = 2         ' the chart that comes next, 0 at the end
Const   UB_BACKGROUND_BONUS     As UByte    = 3         ' what it adds to the social class, 50 more than that
Const   UB_BACKGROUND_TEXT      As UByte    = 4         ' its text, ending in a 0
Const   UB_PLAYER_MAX_RACES     As UByte    = 8
Const   UB_PLAYER_MAX_CLASSES   As UByte    = 6
Const   UB_PLAYER_MAX_LEVEL     As UByte    = 40

' the six stats, in Moria's order, which is the order they are held in everywhere
Const   UB_STAT_STR             As UByte    = 0
Const   UB_STAT_INT             As UByte    = 1
Const   UB_STAT_WIS             As UByte    = 2
Const   UB_STAT_DEX             As UByte    = 3
Const   UB_STAT_CON             As UByte    = 4
Const   UB_STAT_CHR             As UByte    = 5

' the seed for the random numbers: 0 means take it from how long the player took over the opening screens, which is what
' a real game wants, any other number is used as it stands, so that the same character rolls and levels come up every time
#define UL_GAME_FIXED_SEED      0
'##################################################################################################################################

'##################################################################################################################################
' --- EACH STAGE'S AND LIBRARY'S OWN CONSTANTS, moved here from their own files on 22 October 2026, file by file ---

' --- stage-aim-include.bas's own ---
#define UB_AIM_MAX_RANGE    18      ' how far a bolt or ball goes, Moria's OBJECT_BOLTS_MAX_RANGE

' --- stage-crawl.bas's own ---
' whether a new character starts with "print self during run" on, which draws the player at every step of a run,
' Moria starts with it off, N.B: it is here, and not in constants.bas, so that changing it compiles this stage alone,
' and it only sets how the option starts out, = changes it in the game
#define UB_CR_PRINT_SELF_AT_START    true
' the same for "beep for invalid character": whether a new character starts with it on, as Moria does, the beep is
' made when a key that is no command at all is pressed, s_core_beep() in core.bas, = turns it on and off in the game
#define UB_CR_BEEP_AT_START          true
' the same for "rogue like commands": whether a new character starts with them on, Moria starts with them off,
' and so do ours, the digits are Moria's directions and a keyboard with a number pad is what they are meant for,
' = turns them on and off in the game
#define UB_CR_ROGUELIKE_AT_START     false

' --- stage-death.bas's own ---
#define UB_DT_ART_TOMB      1       ' the pictures fuw_dt_art() has, the tombstone, Moria's printTomb()
#define UB_DT_ART_CROWN     2       ' and the crown, Moria's printCrown()
#define UB_DT_AGE_LENGTH    12      ' the length of "Ripe Old Age", what a winner died from

' --- stage-player-include.bas's own, for the two stages that make a new character ---
#define UB_PL_NOT_CHOSEN    255     ' no race or class chosen yet
#define UB_PL_LEAST_ESCAPED 255     ' the auto-roller's question about a least stat was left with ESC
#define UB_PL_LEAST_DIGITS  6       ' how long the answer may be, as long as 18/100
#define UB_PL_SHOW_ROLLS    7       ' the auto-roller shows its rolls one in eight, when these bits are 0

' --- stage-element-include.bas's own ---
#define UB_ELEMENT_MISSILE  0       ' a magic missile, nothing resists it and nothing is hurt more by it
#define UB_ELEMENT_HOLY_ORB 11      ' the priest's orb of draining, double to anything evil

' --- stage-lib-commands-2.bas's own ---
#define UB_CM_OPTION_LAST   11      ' the options screen's last line, from 0, see fuw_cm_options()

' --- stage-lib-equipment.bas's own ---
#define UB_EQ_FIRST             22      ' the first equipment place in the one list, Moria's PlayerEquipment::Wield

' --- stage-lib-items.bas's own ---
' what the misc use number of an item means, and so how it is shown...
#define UB_MISC_IGNORED     0
#define UB_MISC_LIGHT       1       ' turns of light left
#define UB_MISC_FLAGS       2       ' to strength or to stealth, the item's flags say which
#define UB_MISC_ZPLUSSES    3       ' a plus that is shown even when it is 0
#define UB_MISC_PLUSSES     4       ' a plus
#define UB_MISC_CHARGES     5       ' charges left

' --- stage-lib-look.bas's own ---
#define SW_GRADF            10000       ' any sufficiently big number will do

' --- stage-lib-minimap.bas's own ---
#define UW_MM_BITS_SIZE 2176                    ' 68 rows of UB_MM_BITS_ROW bytes

' --- stage-lib-monster-attack-2.bas's own ---
#define UB_SET_FLAMMABLE    1       ' which things in the pack a kind of damage can destroy, Moria's setFlammableItems()...
#define UB_SET_ACID         2
#define UB_SET_CORRODABLE   3
#define UB_SET_FROST        4
#define UB_SET_LIGHTNING    5

' --- stage-lib-objects.bas's own ---
#define UB_SET_ROOMS        1       ' only on the floor of a room, Moria's setRooms()
#define UB_SET_CORRIDORS    2       ' only in a corridor, Moria's setCorridors()
#define UB_SET_FLOORS       3       ' on any floor, room or corridor, Moria's setFloors()
#define UB_ALLOC_TRAP       1       ' Moria's own numbers for what to put down...
#define UB_ALLOC_RUBBLE     3
#define UB_ALLOC_GOLD       4
#define UB_ALLOC_OBJECT     5

' --- stage-lib-save.bas's own ---
#define UB_SAVE_VERSION     2       ' N.B: 2 since the table of creature levels came to live in the core data page, which a save holds: a save from before has no such table in it
' where the marks of a saved game are in the core's data, counted from its start, see gub_save_letter_1 in globals.bas
#define UW_SV_AT_MARKS      6995
#define UB_SV_MARK_LETTER_2 1       ' ...counted from the first: the second letter, M
#define UB_SV_MARK_VERSION  2       ' ...the layout, UB_SAVE_VERSION
#define UB_SV_MARK_ALIVE    3       ' ...false once the saved character has died
' the game's part of the core's data, which a save brings back, see above
#define UW_SV_GAME_FROM     512
#define UW_SV_GAME_SIZE     6488    ' to 6999
#define UB_SV_STOCK_PAGES   2       ' the stores' stock, the last two of a dead character's pages
#define UB_SV_DOTS_COL      16      ' the progress, a dot for each page, after "Saving game..."
' how many of the file's pages are written when a character dies: up to and including the stores' stock, pages 40
' and 41, the 9th and 10th, see sv_pages below
#define UB_SV_DEAD_PAGES    10

' --- stage-lib-scores.bas's own ---
#define UB_SC_ENTRY         88
#define UB_SC_MAX           90
#define UB_SC_OLD_ENTRY     80                      ' the scores as they were until 14 October 2026...
' ...a score's fields, as the table above has them
#define UB_SC_POINTS        0                       ' 4 bytes
#define UB_SC_LEVEL         4
#define UB_SC_SEX           5                       ' M or F
#define UB_SC_RACE          6
#define UB_SC_CLASS         7
#define UB_SC_NAME          8
#define UB_SC_NAME_SIZE     27
#define UB_SC_DIED_FROM     35
#define UB_SC_DIED_SIZE     25
#define UB_SC_RACE_NAME     60
#define UB_SC_RACE_SIZE     11
#define UB_SC_CLASS_NAME    71
#define UB_SC_CLASS_SIZE    9
#define UB_SC_BIRTH         80                      ' 4 bytes, gsl_player_birth
#define UB_SC_DEATH         84                      ' 4 bytes, when it died, 0 if there is no clock
#define UB_SC_OLD_MAX       100                     ' ...and as many as there were
#define S_SC_HEADING    "Rank  Points Name              Sex Race       Class  Lvl Killed By"

' --- stage-lib-wizard-3.bas's own ---
#define UB_W3_TABLE_WORN    0       ' fuw_w3_table(): what is worn...
#define UB_W3_TABLE_PACK    1       ' ...and what goes in the pack
#define UB_W3_WORN_END      255     ' the place that ends the table of what is worn
#define UB_W3_WORN_OBJECT   1       ' the fields of what is worn: the place first, then the object (2 bytes)
#define UB_W3_WORN_NAME     3       ' the special name
#define UB_W3_WORN_TO_HIT   4
#define UB_W3_WORN_TO_DAM   5
#define UB_W3_WORN_TO_AC    6
#define UB_W3_WORN_P1       7       ' 2 bytes
#define UB_W3_WORN_FLAGS    9       ' 4 bytes
#define UB_W3_WORN_SIZE     13
#define UB_W3_PACK_COUNT    2       ' the fields of what goes in the pack: the object first (2 bytes, 0 ends it), how many
#define UB_W3_PACK_P1       3       ' and P1, 2 bytes
#define UB_W3_PACK_SIZE     5
#define UB_W3_BOOKS         4       ' the first four in the pack are the mage's books, the priest's are four objects on
#define UB_W3_STAT          118     ' 18/100
#define UB_W3_LEVEL         39      ' the level it goes to, one at a time, the last but one
#define UB_W3_LEVEL_TRIES   60      ' and how many tries it gets at that
#define UW_W3_POINTS        30000   ' hit points and mana, N.B: not the 32767 a number can hold, see the file
#define UL_W3_GOLD          500000
#define UB_W3_WEAPON_DICE   9       ' the weapon's 9d9
#define UB_W3_SPELL_PLACES  31      ' the places in A_PLAYER_SPELL_ORDER

' --- stage-lib-wizard.bas's own ---
#define UW_WZ_ROWS_SIZE     768                                     ' those three rows

