#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this stage...
' ...the build script checks that the compiled code really does start at $6000
s_stage_new_game()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this stage does what Moria does at the start of a new game, after the random numbers are seeded and before the
' character is made (the first part of startMoria() in game_run.cpp), in the same order, because some of it uses
' random numbers and the character's rolls come after it
'
' what is NOT here yet:
'   - the tables of which creatures and which objects belong to which dungeon level (initializeMonsterLevels,
'     initializeTreasureLevels), they use no random numbers, they will come with the monsters and the treasure


Sub s_new_game_stores()
    ' gives each store one of its three possible owners, and empties it, Moria's storeInitializeOwners()
    ' the owners are in the table in threes: owners 0, 6 and 12 keep the General Store, 1, 7 and 13 the Armory, and so on
    Dim lub_store , i   As UByte
    Dim luw_state       As UInteger

    For lub_store = 0 To UB_STORES - 1
        luw_state = A_STORES + Cast( UInteger , lub_store ) * UB_STORE_STATE_SIZE
        For i = 0 To UB_STORE_STATE_SIZE - 1
            Poke luw_state + i , 0
        Next
        Poke luw_state + UB_STORE_OWNER , UB_STORES * ( Cast( UByte , ful_core_random_number( UB_OWNERS / UB_STORES ) ) - 1 ) + lub_store
    Next

    ' nothing in stock anywhere: both pages of store items wiped
    For i = 0 To 1
        s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_STORE_ITEMS + i )
        Asm
            ld hl, A_MMU_SLOT_PAGED_ITEMS
            ld de, A_MMU_SLOT_PAGED_ITEMS + 1
            ld bc, 8191
            ld (hl), 0
            ldir
        End Asm
    Next
End Sub


Sub s_stage_new_game()
    s_new_game_stores()
End Sub