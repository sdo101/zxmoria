' the name of a file that belongs to one character, a library that reads or writes one includes this file: the
' character's record, player-<name>.txt, stage-lib-info.bas
' NOT Moria's, ours: Moria asks for the name of every file it writes

Sub s_pf_name( puw_to As UInteger , puw_name As UInteger , ps_before As String , ps_after As String )
    ' puts at puw_to, as text ending in a 0: ps_before, the character's name, and ps_after, e.g. "player-", the
    ' name, ".txt", puw_name is where the name is, text ending in a 0, A_PLAYER_NAME for the character being played...
    ' ...the name goes in as it is but for whatever is not a letter or a digit, which becomes an underline, so that
    ' any name a player can type makes a file name that the SD card will take, N.B: so two names that differ only
    ' in such characters share a file, "Bob the 2nd" and "Bob-the-2nd" are both Bob_the_2nd
    ' N.B: at most 23 characters of name, which is as long as a name can be, and 63 in all is the most a file name may be
    Dim i , lub_at , lub_char As UByte

    lub_at = 0
    i = 0
    While i < Len( ps_before )
        Poke puw_to + lub_at , Code( ps_before( i ) )
        lub_at = lub_at + 1
        i = i + 1
    End While
    i = 0
    While i < 23 And Peek( puw_name + i ) <> 0
        lub_char = Peek( puw_name + i )
        If lub_char < Code( "0" ) Or ( lub_char > Code( "9" ) And lub_char < Code( "A" ) ) Or ( lub_char > Code( "Z" ) And lub_char < Code( "a" ) ) Or lub_char > Code( "z" ) Then lub_char = Code( "_" )
        Poke puw_to + lub_at , lub_char
        lub_at = lub_at + 1
        i = i + 1
    End While
    i = 0
    While i < Len( ps_after )
        Poke puw_to + lub_at , Code( ps_after( i ) )
        lub_at = lub_at + 1
        i = i + 1
    End While
    Poke puw_to + lub_at , 0
End Sub
