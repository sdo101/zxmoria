' the three small routines that both pages of the treasure library need (stage-lib-treasure.bas and stage-lib-treasure-2.bas)...
' ...each page includes this file, so each has its own copy


Function fsw_mt_random( psw_max As Integer ) As Integer
    ' a random number from 1 to psw_max, Moria's randomNumber()
    Return Cast( Integer , ful_core_random_number( Cast( ULong , psw_max ) ) )
End Function


Function fub_mt_should( psw_chance As Integer ) As UByte
    ' true psw_chance times in a hundred, Moria's magicShouldBeEnchanted()
    If fsw_mt_random( 100 ) <= psw_chance Then Return true
    Return false
End Function


Function fsw_mt_bonus( psw_base As Integer , psw_max_standard As Integer , psw_level As Integer ) As Integer
    ' how big a plus (or a minus) to give, Moria's magicEnchantmentBonus(): a number from a normal distribution that
    ' widens with the level, a tenth of it, on top of the base
    Dim lsw_deviation , lsw_bonus As Integer

    lsw_deviation = ( LEVEL_STD_OBJECT_ADJUST * psw_level / 100 ) + LEVEL_MIN_OBJECT_STD
    If lsw_deviation > psw_max_standard Or psw_level > psw_max_standard Then lsw_deviation = psw_max_standard
    lsw_bonus = ( Abs( fsw_core_random_normal( 0 , lsw_deviation ) ) / 10 ) + psw_base
    If lsw_bonus < psw_base Then Return psw_base
    Return lsw_bonus
End Function
