#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_scores()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"

' this page is a LIBRARY, not a stage: the high scores, Moria's scores.cpp...
' ...a page reaches it through the core: s_core_call_library( UB_PAGED_CODE_LIB_SCORES , <which routine> ), the routines are:
'
'   UB_LIB_SCORES_RECORD    the character's game is over: what it scored is worked out and put in its place in
'                           the table, Moria's recordNewHighScore() and playerCalculateTotalPoints()
'   UB_LIB_SCORES_SHOW      the table, a screenful at a time, ESCAPE stops it, Moria's showScoresScreen()
'   UB_LIB_SCORES_DATE      the date and the time, from the Next's clock: gsw_lib_result true if there is one, and
'                           gsl_lib_long_1 is then both, as files are dated, see fub_sc_date(), and if gub_lib_param_1
'                           is true the day is also put in A_TEXT_BUFFER as Moria shows it, e.g. "Wed Oct 14"
'   UB_LIB_SCORES_DEAD      has the character born at gsl_lib_long_1 died, is it in the table? gsw_lib_result true if so
'   UB_LIB_SCORES_POINTS    what the character would score now, in gsl_lib_long_1, Moria's playerCalculateTotalPoints()
'
' the table is one 8KB page, kept in the file scores.dat on the SD card: a count in its first byte, a T in its
' second, and then the scores, the best first, 88 bytes each, up to 90 of them...
' ...and each time a score is put in it the whole table is written out again as text, as it is shown on the screen,
' in the file scores.txt, for reading on a PC, N.B: ours, Moria has only its scores.dat
' N.B: until 14 October 2026 the table was the file zxmoria.sc, which is still read if there is no scores.dat
'    0  4  points
'    4  1  the character's level
'    5  1  M or F
'    6  1  race, its number, and  7  1  class, its number
'    8 27  name, text ending in a 0
'   35 25  what it died of, text ending in a 0
'   60 11  the name of its race, and  71  9  the name of its class, both text ending in a 0
'   80  4  when the character was made, gsl_player_birth, Moria's birth_date, which tells it from every other
'   84  4  when it died, as the clock had it, 0 if there is no clock
' N.B: until 14 October 2026 the scores were 80 bytes, up to 100 of them, with an S in the second byte, such a table
' is made over into this one as it is read, see s_sc_load()
'
' a character that is saved is put in the table too, as in Moria, with "(saved)" for what it died of, and when it
' does die, or is saved again, its new score takes the place of that one: the same date of birth, sex, race and class,
' see s_sc_record()
'
' what is NOT here yet, each is marked "NOT YET" where it belongs:
'   - Moria keeps up to 1000 scores, we keep the best 90


#define UB_SC_ENTRY         88
#define UB_SC_MAX           90
#define UB_SC_OLD_ENTRY     80                      ' the scores as they were until 14 October 2026...
#define UB_SC_OLD_MAX       100                     ' ...and as many as there were
#define A_SC_FILE_NAME      A_LIB_PRIVATE + 200     ' 16 bytes, the name of the text file while it is being written
#define A_SC_CLOCK          A_LIB_PRIVATE + 300     ' 7 bytes, the clock's own, as they were read from it

#include "stage-textfile-include.bas"

Declare Function fub_sc_date() As UByte


Function fuw_sc_entry( pub_index As UByte ) As UInteger
    ' where one score is, the table's page must be in the second data slot
    Return A_MMU_SLOT_1 + 2 + Cast( UInteger , pub_index ) * UB_SC_ENTRY
End Function


Function fub_sc_table() As UByte
    ' true if the page holds a table of ours, a table as it was until 14 October 2026 is made over into one as it is
    ' now: each score moves up to its new place, the last first, with no birth and no death date, and any past the
    ' 90th are lost
    Dim lub_count , i As UByte

    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_SCORES )
    lub_count = Peek( A_MMU_SLOT_1 )
    If Peek( A_MMU_SLOT_1 + 1 ) = Code( "T" ) And lub_count <= UB_SC_MAX Then Return true
    If Peek( A_MMU_SLOT_1 + 1 ) <> Code( "S" ) Or lub_count > UB_SC_OLD_MAX Then Return false
    If lub_count > UB_SC_MAX Then lub_count = UB_SC_MAX
    i = lub_count
    While i > 0
        i = i - 1
        s_core_ram_copy( A_MMU_SLOT_1 + 2 + Cast( UInteger , i ) * UB_SC_OLD_ENTRY , A_LIB_PRIVATE , UB_SC_OLD_ENTRY )
        Poke ULong A_LIB_PRIVATE + 80 , 0
        Poke ULong A_LIB_PRIVATE + 84 , 0
        s_core_ram_copy( A_LIB_PRIVATE , fuw_sc_entry( i ) , UB_SC_ENTRY )
    End While
    Poke A_MMU_SLOT_1 , lub_count
    Poke A_MMU_SLOT_1 + 1 , Code( "T" )
    Return true
End Function


Sub s_sc_load()
    ' the table is brought in from the card, if it is not there, or is not ours, it starts empty
    If fub_core_file_load_page( "scores.dat" , UB_PAGE_SCORES ) = 0 Then
        If fub_sc_table() Then Return
    End If
    ' ...or under the name it had before
    If fub_core_file_load_page( "zxmoria.sc" , UB_PAGE_SCORES ) = 0 Then
        If fub_sc_table() Then Return
    End If
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_SCORES )
    Poke A_MMU_SLOT_1 , 0
    Poke A_MMU_SLOT_1 + 1 , Code( "T" )
End Sub


Sub s_sc_text( puw_from As UInteger , puw_to As UInteger , pub_room As UByte )
    ' copies text that ends in a 0, no more of it than there is room for
    Dim i As UByte = 0

    While i < pub_room - 1 And Peek( puw_from + i ) <> 0
        Poke puw_to + i , Peek( puw_from + i )
        i = i + 1
    End While
    Poke puw_to + i , 0
End Sub


Function fsl_sc_points() As Long
    ' Moria's playerCalculateTotalPoints(): experience, how deep the character got, their gold, and what
    ' everything they carry and wear is worth, the stores library does the valuing
    Dim lsl_total   As Long
    Dim i           As UByte
    Dim luw_record  As UInteger

    lsl_total = gsl_player_max_exp + 100 * Cast( Long , guw_player_max_depth )
    lsl_total = lsl_total + gsl_player_gold / 100
    For i = 0 To UB_INVENTORY_SIZE - 1
        luw_record = A_INVENTORY + Cast( UInteger , i ) * UB_RECORD_SIZE
        If Peek( luw_record + UB_ITEM_CATEGORY_OFFSET ) <> 0 Then
            s_core_ram_copy( luw_record , A_ITEM , UB_RECORD_SIZE )
            s_core_call_library( UB_PAGED_CODE_LIB_STORES , UB_LIB_STORES_VALUE )
            lsl_total = lsl_total + gsl_lib_long_1
        End If
    Next
    lsl_total = lsl_total + Cast( Long , guw_dungeon_level ) * 50
    ' don't ever let the score decrease from one save to the next
    If gsl_player_max_score > lsl_total Then lsl_total = gsl_player_max_score
    Return lsl_total
End Function


Function fs_sc_pad( ps_text As String , pub_width As UByte , pub_left As UByte ) As String
    ' text cut or made up to a width, with spaces after it or before it
    If Len( ps_text ) > pub_width Then Return ps_text( 0 To pub_width - 1 )
    While Len( ps_text ) < pub_width
        If pub_left Then
            ps_text = ps_text + " "
        Else
            ps_text = " " + ps_text
        End If
    End While
    Return ps_text
End Function


Function fs_sc_line( pub_rank As UByte ) As String
    ' one score as a line of text, as the screen and the text file both have it
    ' N.B: the table's page is fetched afresh each time, the text routines may have used the data slots
    Dim luw_entry   As UInteger
    Dim ls_line     As String

    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_SCORES )
    luw_entry = fuw_sc_entry( pub_rank )
    ls_line = fs_sc_pad( fs_core_number( pub_rank + 1 ) , 4 , true ) + fs_sc_pad( fs_core_number( Peek( ULong , luw_entry ) ) , 8 , false ) + " "
    ls_line = ls_line + fs_sc_pad( fs_core_text_at( luw_entry + 8 ) , 19 , true ) + " " + fs_core_char( Peek( luw_entry + 5 ) ) + " "
    ls_line = ls_line + fs_sc_pad( fs_core_text_at( luw_entry + 60 ) , 10 , true ) + " " + fs_sc_pad( fs_core_text_at( luw_entry + 71 ) , 7 , true )
    ls_line = ls_line + fs_sc_pad( fs_core_number( Peek( luw_entry + 4 ) ) , 3 , false ) + " " + fs_sc_pad( fs_core_text_at( luw_entry + 35 ) , 22 , true )
    Return ls_line
End Function


#define S_SC_HEADING    "Rank  Points Name              Sex Race       Class  Lvl Killed By"

Sub s_sc_write_text()
    ' the whole table as a text file, scores.txt, for reading away from the game, N.B: the table must be in its page
    Dim lub_count , lub_rank , i    As UByte
    Dim ls_name                     As String = "scores.txt"

    For i = 0 To Len( ls_name ) - 1
        Poke A_SC_FILE_NAME + i , Code( ls_name( i ) )
    Next
    Poke A_SC_FILE_NAME + Len( ls_name ) , 0
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_SCORES )
    lub_count = Peek( A_MMU_SLOT_1 )

    s_tf_begin( A_SC_FILE_NAME )
    s_tf_write( "ZXMoria high scores" )
    s_tf_write( "" )
    s_tf_write( S_SC_HEADING )
    lub_rank = 0
    While lub_rank < lub_count
        s_tf_write( fs_sc_line( lub_rank ) )
        lub_rank = lub_rank + 1
    End While
    gub_shared_1 = fub_tf_end()
End Sub


Function fub_sc_is_saved( puw_entry As UInteger ) As UByte
    ' true if what a score died of is "(saved)"
    Return fs_core_text_at( puw_entry + 35 ) = "(saved)"
End Function


Function fub_sc_saved( pub_index As UByte ) As UByte
    ' true if a score in the table is this character's, from when it was saved: what it died of is "(saved)", and its
    ' date of birth, sex, race and class are this character's, as Moria's recordNewHighScore() tells it
    Dim luw_entry   As UInteger
    Dim lub_sex     As UByte

    luw_entry = fuw_sc_entry( pub_index )
    If Peek( ULong , luw_entry + 80 ) <> gsl_player_birth Then Return false
    lub_sex = Code( "F" )
    If gub_player_male Then lub_sex = Code( "M" )
    If Peek( luw_entry + 5 ) <> lub_sex Or Peek( luw_entry + 6 ) <> gub_player_race Or Peek( luw_entry + 7 ) <> gub_player_class Then Return false
    Return fub_sc_is_saved( luw_entry )
End Function


Sub s_sc_record()
    ' Moria's recordNewHighScore()
    Dim lsl_points              As Long
    Dim lub_count , lub_place   As UByte
    Dim lub_move , lub_saved    As UByte
    Dim luw_entry , luw_text    As UInteger

    ' a game that wizard mode has been used in is not scored
    If gub_game_noscore <> 0 Then Return
    lsl_points = fsl_sc_points()
    s_sc_load()
    lub_count = Peek( A_MMU_SLOT_1 )

    ' its place: above the first score it equals or beats... N.B: a score of this character's from when it was saved,
    ' that is better than this one, stays, and this one is not put in, as in Moria
    lub_place = 0
    While lub_place < lub_count And lsl_points < Peek( Long , fuw_sc_entry( lub_place ) )
        If fub_sc_saved( lub_place ) Then Return
        lub_place = lub_place + 1
    End While
    If lub_place >= UB_SC_MAX Then Return

    ' a score of this character's from when it was saved, below this one, is taken out: the scores between move down
    ' one into its place, and the table is no longer
    lub_saved = lub_place
    While lub_saved < lub_count
        If fub_sc_saved( lub_saved ) Then Exit While
        lub_saved = lub_saved + 1
    End While

    ' the scores below it move down one, the last falls off a full table
    If lub_saved < lub_count Then
        lub_move = lub_saved
    Else
        If lub_count < UB_SC_MAX Then lub_count = lub_count + 1
        lub_move = lub_count - 1
    End If
    While lub_move > lub_place
        s_core_ram_copy( fuw_sc_entry( lub_move - 1 ) , A_LIB_PRIVATE , UB_SC_ENTRY )
        s_core_ram_copy( A_LIB_PRIVATE , fuw_sc_entry( lub_move ) , UB_SC_ENTRY )
        lub_move = lub_move - 1
    End While

    luw_entry = fuw_sc_entry( lub_place )
    Poke Long luw_entry , lsl_points
    Poke luw_entry + 4 , guw_player_level
    Poke luw_entry + 5 , Code( "F" )
    If gub_player_male Then Poke luw_entry + 5 , Code( "M" )
    Poke luw_entry + 6 , gub_player_race
    Poke luw_entry + 7 , gub_player_class
    s_sc_text( A_PLAYER_NAME , luw_entry + 8 , 27 )
    ' what it died of, without the "a" or "an" it begins with
    luw_text = A_DIED_FROM
    If Peek( luw_text ) = Code( "a" ) Then
        If Peek( luw_text + 1 ) = 32 Then
            luw_text = luw_text + 2
        ElseIf Peek( luw_text + 1 ) = Code( "n" ) And Peek( luw_text + 2 ) = 32 Then
            luw_text = luw_text + 3
        End If
    End If
    s_sc_text( luw_text , luw_entry + 35 , 25 )
    s_sc_text( A_RACE , luw_entry + 60 , 11 )
    s_sc_text( A_CLASS , luw_entry + 71 , 9 )
    Poke ULong luw_entry + 80 , gsl_player_birth
    gub_shared_1 = fub_sc_date()
    s_core_swap_paged_data( UB_SLOT_ITEMS , UB_PAGE_SCORES )
    Poke ULong luw_entry + 84 , gsl_lib_long_1
    Poke A_MMU_SLOT_1 , lub_count

    gub_shared_1 = fub_core_file_save_page( "scores.dat" , UB_PAGE_SCORES )
    s_sc_write_text()
End Sub


Sub s_sc_show()
    ' Moria's showScoresScreen()
    Dim lub_count , lub_rank , lub_row  As UByte
    Dim luw_entry                       As UInteger
    Dim ls_line                         As String

    s_sc_load()
    lub_count = Peek( A_MMU_SLOT_1 )
    lub_rank  = 0
    Do
        s_core_clear_screen()
        s_core_print_string_at( 0 , 0 , S_SC_HEADING , UB_BRIGHT_WHITE )
        lub_row = 2
        While lub_rank < lub_count And lub_row < 22
            s_core_print_string_at( lub_row , 0 , fs_sc_line( lub_rank ) , UB_WHITE )
            lub_row  = lub_row + 1
            lub_rank = lub_rank + 1
        End While
        s_core_print_string_at( 23 , 23 , "[ press any key to continue ]" , UB_BRIGHT_WHITE )
        s_core_get_key()
    Loop Until lub_rank >= lub_count Or gub_key_char = 27 Or guw_key_code = 0
End Sub


'##################################################################################################################################
' --- THE CLOCK ---

Function fub_sc_bcd( pub_value As UByte ) As UByte
    ' a number as the clock keeps it, two decimal digits of four bits each, as an ordinary number, 99 if it is not one
    If ( pub_value bAnd 15 ) > 9 Or ( pub_value >> 4 ) > 9 Then Return 99
    Return ( pub_value >> 4 ) * 10 + ( pub_value bAnd 15 )
End Function


Function fub_sc_date() As UByte
    ' what the date and the time are, from the Next's clock: true if it told us, and then gsl_lib_long_1 is both, as
    ' files are dated: the date in its top half, the year less 1980 in 7 bits, the month in 4, the day in 5, and the
    ' time in its bottom half, the hour in 5 bits, the minute in 6, half the seconds in 5, so a later moment is a
    ' bigger number...
    ' ...false, and gsl_lib_long_1 is 0, if the Next has no clock, it is a part that not every Next was sold with, or
    ' its clock has stopped, or has never been set
    ' N.B: the clock is a DS1307 chip on the Next's i2c lines, two ports, and we read it ourselves. The system has a
    ' call for this, M_GETDATE, but the ZEsarUX emulator hangs in it, both when it answers the system's calls itself
    ' and under NextZXOS, found on 14 October 2026, and the emulator has the chip, so the chip it is...
    ' ...the chip's answers to each byte sent to it, the acknowledgements, are clocked but never read: the emulator
    ' gives none, and every read of the data line has it hand out the next bit of the clock, so reading them took
    ' bits from the time. A Next without the chip reads all ones, which is no time at all, and that is how it is told
    ' ...the lines are worked at 3.5MHz, which is slow enough for the chip, the speed the game runs at is put back after
    Dim lub_seconds , lub_minutes , lub_hours , lub_day , lub_month , lub_year As UByte

    gsl_lib_long_1 = 0
    Asm
        push ix
        ld bc, A_NEXTREG_SELECT     ; the speed the game runs at, nextreg $07, kept in IXL, and 3.5MHz meanwhile
        ld a, $07
        out (c), a
        inc b                       ; $253B, the data port
        in a, (c)
        and 3
        ld ixl, a
        xor a
        out (c), a

        ; the chip is at i2c address $D0: register 0 is where the reading starts...
        call sc_i2c_start
        ld d, $D0
        call sc_i2c_write
        ld d, 0
        call sc_i2c_write
        ; ...and seven bytes are read from there, $D1: seconds, minutes, hours, day of the week, day, month, year
        call sc_i2c_start
        ld d, $D1
        call sc_i2c_write
        ld hl, A_SC_CLOCK
        ld b, 7
sc_clock_next:
        push bc
        xor a                       ; each byte but the last is acknowledged, 0, the last is not, 1
        dec b
        jr nz, sc_clock_more
        inc a
sc_clock_more:
        call sc_i2c_read
        ld (hl), d
        inc hl
        pop bc
        djnz sc_clock_next
        call sc_i2c_stop

        ld bc, A_NEXTREG_SELECT     ; the game's own speed back
        ld a, $07
        out (c), a
        inc b
        ld a, ixl
        out (c), a
        pop ix
        jp sc_clock_end

        ; the i2c lines: SCL the clock, port $103B, and SDA the data, port $113B, bit 0 of each, 1 lets the line go high
sc_i2c_scl:
        ld bc, $103B
        out (c), a
        ret
sc_i2c_sda:
        ld bc, $113B
        out (c), a
        ret
sc_i2c_start:                       ; both high, then the data goes low while the clock is high, then the clock
        ld a, 1
        call sc_i2c_sda
        ld a, 1
        call sc_i2c_scl
        xor a
        call sc_i2c_sda
        xor a
        jr sc_i2c_scl
sc_i2c_stop:                        ; the data goes high while the clock is high
        xor a
        call sc_i2c_sda
        ld a, 1
        call sc_i2c_scl
        ld a, 1
        jr sc_i2c_sda
sc_i2c_write:                       ; the byte in D goes out, the highest bit first, and a clock for the chip's acknowledgement
        ld e, 8
sc_i2c_write_bit:
        rl d
        ld a, 0
        rla
        call sc_i2c_sda
        ld a, 1
        call sc_i2c_scl
        xor a
        call sc_i2c_scl
        dec e
        jr nz, sc_i2c_write_bit
        ld a, 1                     ; the line is let go for the acknowledgement, which is not read, see above
        call sc_i2c_sda
        ld a, 1
        call sc_i2c_scl
        xor a
        jr sc_i2c_scl
sc_i2c_read:                        ; a byte comes in, into D, and A is sent after it: 0 acknowledges it, 1 does not
        push af
        ld a, 1
        call sc_i2c_sda
        ld e, 8
sc_i2c_read_bit:
        ld a, 1
        call sc_i2c_scl
        ld bc, $113B
        in a, (c)
        rra
        rl d
        xor a
        call sc_i2c_scl
        dec e
        jr nz, sc_i2c_read_bit
        pop af
        call sc_i2c_sda
        ld a, 1
        call sc_i2c_scl
        xor a
        jr sc_i2c_scl
sc_clock_end:
    End Asm

    ' the bytes as numbers: bit 7 of the seconds is set while the clock is stopped, and bit 6 of the hours if the clock
    ' counts in twelves, with bit 5 then the afternoon, the year is 00 to 99, for 2000 to 2099
    lub_seconds = Peek( A_SC_CLOCK )
    If lub_seconds bAnd $80 Then Return false
    lub_seconds = fub_sc_bcd( lub_seconds )
    lub_minutes = fub_sc_bcd( Peek( A_SC_CLOCK + 1 ) )
    lub_hours   = Peek( A_SC_CLOCK + 2 )
    If lub_hours bAnd $40 Then
        lub_day   = lub_hours bAnd $20
        lub_hours = fub_sc_bcd( lub_hours bAnd $1F )
        If lub_hours = 12 Then lub_hours = 0
        If lub_day Then lub_hours = lub_hours + 12
    Else
        lub_hours = fub_sc_bcd( lub_hours bAnd $3F )
    End If
    lub_day   = fub_sc_bcd( Peek( A_SC_CLOCK + 4 ) )
    lub_month = fub_sc_bcd( Peek( A_SC_CLOCK + 5 ) )
    lub_year  = fub_sc_bcd( Peek( A_SC_CLOCK + 6 ) )
    If lub_seconds > 59 Or lub_minutes > 59 Or lub_hours > 23 Or lub_day = 0 Or lub_day > 31 Or lub_month = 0 Or lub_month > 12 Or lub_year > 99 Then Return false
    gsl_lib_long_1 = ( Cast( Long , ( Cast( UInteger , lub_year + 20 ) << 9 ) bOr ( Cast( UInteger , lub_month ) << 5 ) bOr lub_day ) << 16 ) bOr ( ( Cast( UInteger , lub_hours ) << 11 ) bOr ( Cast( UInteger , lub_minutes ) << 5 ) bOr ( lub_seconds >> 1 ) )
    Return true
End Function


Sub s_sc_text_put( ps_text As String , puw_to As UInteger )
    ' text into memory, with a 0 after it
    Dim i As UByte

    For i = 0 To Len( ps_text ) - 1
        Poke puw_to + i , Code( ps_text( i ) )
    Next
    Poke puw_to + Len( ps_text ) , 0
End Sub


Sub s_sc_day_text()
    ' the day in gsl_lib_long_1 as Moria's tombstone has it, e.g. "Wed Oct 14", into A_TEXT_BUFFER, N.B: the clock's
    ' own day of the week is not used, the emulator's is always 1, it is worked out from the date
    Dim luw_date , luw_year     As UInteger
    Dim lub_month , lub_day     As UByte
    Dim lub_week                As UByte
    Dim ls_text                 As String
    Dim ls_days                 As String = "SunMonTueWedThuFriSat"
    Dim ls_months               As String = "JanFebMarAprMayJunJulAugSepOctNovDec"
    Dim ls_shift                As String = "032503514624"       ' how far each month's first day is moved on, in the week

    luw_date  = gsl_lib_long_1 >> 16
    luw_year  = 1980 + ( luw_date >> 9 )
    lub_month = ( luw_date >> 5 ) bAnd 15
    lub_day   = luw_date bAnd 31
    ' the day of the week, 0 a Sunday, Tomohiko Sakamoto's way: January and February count as the year before's
    If lub_month < 3 Then luw_year = luw_year - 1
    lub_week = ( luw_year + luw_year / 4 - luw_year / 100 + luw_year / 400 + Code( ls_shift( lub_month - 1 ) ) - 48 + lub_day ) Mod 7
    ls_text = ls_days( lub_week * 3 To lub_week * 3 + 2 ) + " " + ls_months( ( lub_month - 1 ) * 3 To ( lub_month - 1 ) * 3 + 2 ) + " "
    If lub_day < 10 Then ls_text = ls_text + "0"
    ls_text = ls_text + fs_core_number( lub_day )
    s_sc_text_put( ls_text , A_TEXT_BUFFER )
End Sub


Function fub_sc_dead( pul_birth As ULong ) As UByte
    ' is the character born then in the table, has it died? N.B: a game in which wizard mode was used is never put in
    ' the table, so its character is not found here
    Dim lub_count , i As UByte

    If pul_birth = 0 Then Return false
    s_sc_load()
    lub_count = Peek( A_MMU_SLOT_1 )
    i = 0
    While i < lub_count
        ' N.B: a score from when it was saved does not count, the character lived on
        If Peek( ULong , fuw_sc_entry( i ) + 80 ) = pul_birth And fub_sc_is_saved( fuw_sc_entry( i ) ) = false Then Return true
        i = i + 1
    End While
    Return false
End Function


Sub s_lib_scores()
    Dim lub_saved_page_0 , lub_saved_page_1 , lub_saved_page_2 As UByte

    lub_saved_page_0 = gub_core_MMU0_page_number
    lub_saved_page_1 = gub_core_MMU1_page_number
    lub_saved_page_2 = gub_core_MMU2_page_number
    ' N.B: the working item is used for the valuing, and is put back as it was
    s_core_ram_copy( A_ITEM , A_LIB_PRIVATE + 128 , UB_RECORD_SIZE )
    If gub_lib_function = UB_LIB_SCORES_RECORD Then
        s_sc_record()
    ElseIf gub_lib_function = UB_LIB_SCORES_SHOW Then
        ' the screen is put aside, in the corridor scratchpad page, and put back afterwards
        s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
        s_core_ram_copy( A_SCREEN_BASE , A_MMU_SLOT_PAGED_CORRIDORS , 5120 )
        s_sc_show()
        s_core_swap_paged_data( UB_SLOT_CORRIDORS , UB_PAGE_CORRIDORS )
        s_core_ram_copy( A_MMU_SLOT_PAGED_CORRIDORS , A_SCREEN_BASE , 5120 )
    ElseIf gub_lib_function = UB_LIB_SCORES_DATE Then
        gsw_lib_result = fub_sc_date()
        If gsw_lib_result And gub_lib_param_1 Then s_sc_day_text()
    ElseIf gub_lib_function = UB_LIB_SCORES_DEAD Then
        gsw_lib_result = fub_sc_dead( gsl_lib_long_1 )
    ElseIf gub_lib_function = UB_LIB_SCORES_POINTS Then
        gsl_lib_long_1 = fsl_sc_points()
    End If
    s_core_ram_copy( A_LIB_PRIVATE + 128 , A_ITEM , UB_RECORD_SIZE )
    If lub_saved_page_0 <> 255 Then s_core_swap_paged_data( UB_SLOT_MONSTERS , lub_saved_page_0 )
    If lub_saved_page_1 <> 255 Then s_core_swap_paged_data( UB_SLOT_ITEMS , lub_saved_page_1 )
    If lub_saved_page_2 <> 255 Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
