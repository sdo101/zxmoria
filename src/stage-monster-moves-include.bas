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


Function fuw_mm_random( puw_max As UInteger ) As UInteger
    ' a random number from 1 to puw_max, Moria's randomNumber(), the core has the routine, see fuw_core_random_word()
    Asm
        pop ix
        jp A_JUMP_RANDOM_WORD
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function
