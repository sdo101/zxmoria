' what every page that handles monsters needs, from Moria's dungeon.cpp: how far apart two squares are...
' ...the monsters library, stage-lib-monsters.bas, and the monster moves library, stage-lib-monster-moves.bas, both include
' this file, each has its own copy of the routine


Function fub_mon_distance( pub_y1 As UByte , pub_x1 As UByte , pub_y2 As UByte , pub_x2 As UByte ) As UByte
    ' how far apart two squares are, Moria's coordDistanceBetween(): the longer of the two sides plus half the shorter
    Dim lsw_dy , lsw_dx , lsw_a , lsw_b As Integer

    lsw_dy = Cast( Integer , pub_y1 ) - Cast( Integer , pub_y2 )
    If lsw_dy < 0 Then lsw_dy = -lsw_dy
    lsw_dx = Cast( Integer , pub_x1 ) - Cast( Integer , pub_x2 )
    If lsw_dx < 0 Then lsw_dx = -lsw_dx
    lsw_a = ( lsw_dy + lsw_dx ) << 1
    lsw_b = lsw_dy
    If lsw_dy > lsw_dx Then lsw_b = lsw_dx
    lsw_a = ( lsw_a - lsw_b ) >> 1
    If lsw_a > 255 Then lsw_a = 255
    Return lsw_a
End Function
