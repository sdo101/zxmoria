' the player being hurt, any page that can hurt the player includes this file, each has its own copy of the routine...
' ...what did the hurting is text in the core data, A_KILLER, ending in a 0, e.g. "a Kobold" or "poison", whoever is
' about to hurt the player puts it there first, and if the player dies of it, that is what they died from

Sub s_hit_killer( ps_text As String )
    ' says what is about to hurt the player
    Dim i , lub_length As UByte

    lub_length = Len( ps_text )
    If lub_length > 38 Then lub_length = 38
    i = 0
    While i < lub_length
        Poke A_KILLER + i , Code( ps_text( i ) )
        i = i + 1
    End While
    Poke A_KILLER + lub_length , 0
End Sub


Sub s_hit_player( psw_damage As Integer )
    ' Moria's playerTakesHit(): the damage comes off the player's hit points, and below nothing they are dead,
    ' the walking stage sees that when the page that called this hands back to it
    Dim ls_number As String

    If gsw_player_invulnerability > 0 Then psw_damage = 0
    gsw_player_current_hp = gsw_player_current_hp - psw_damage
    If gsw_player_current_hp >= 0 Then
        ' Moria's printCharacterCurrentHitPoints(), the number is right aligned in 6 columns, as the character library does it
        ls_number = fs_core_number( gsw_player_current_hp )
        While Len( ls_number ) < 6
            ls_number = " " + ls_number
        End While
        s_core_print_string_at( 17 , 0 , "CHP : " + ls_number , UB_WHITE )
        Return
    End If

    If gub_game_character_dead = false Then
        gub_game_character_dead = true
        s_core_ram_copy( A_KILLER , A_DIED_FROM , 40 )
        gub_game_total_winner = false
    End If
End Sub
