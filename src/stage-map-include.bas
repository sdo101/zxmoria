' the map as the player sees it, any stage or library that draws squares of the map includes this file: the walking
' stage, stage-crawl.bas, and the monsters library, stage-lib-monsters.bas, which draws a monster as it comes into view...
' ...the routines themselves are in the core now, one copy of them, see "THE MAP AS THE PLAYER SEES IT" in core.bas,
' and what is here is the way to them: each of the five below has the name a page has always used for it, and jumps
' to the core's routine through the jump table, exactly as the shims in stage-include.bas do
' N.B: the window's own variables, gsb_panel_row and the rest, are in globals.bas, and its size, UB_VIEW_ROWS and
' the rest, in constants.bas, the core needs them too
' the three small ones at the top are still each page's own, they are a line apiece


Function fuw_cr_square( pub_y As UByte , pub_x As UByte ) As UInteger
    Return fuw_core_map_square( gub_level_map_page , pub_y , pub_x )
End Function


Function fub_cr_item_category( pub_item As UByte ) As UByte
    ' the category of one of the level's items, read straight from its record
    Return Peek( fuw_core_record_address( UB_SLOT_ITEMS , gub_level_items_page , pub_item ) + UB_ITEM_CATEGORY_OFFSET )
End Function


Function fub_cr_inside_panel( pub_y As UByte , pub_x As UByte ) As UByte
    ' Moria's coordInsidePanel()
    If pub_y < gub_panel_top Or pub_y > gub_panel_bottom Then Return false
    If pub_x < gub_panel_left Or pub_x > gub_panel_right Then Return false
    Return true
End Function


Function fub_cr_symbol( pub_y As UByte , pub_x As UByte ) As UByte
    ' what the player sees on one square of the map, Moria's caveGetTileSymbol(), gub_map_is_monster says whether
    ' it is a monster
    Asm
        pop ix
        jp A_JUMP_MAP_SYMBOL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


Sub s_cr_put( pub_y As UByte , pub_x As UByte )
    ' draws one square of the map, if it is in the window, Moria's dungeonLiteSpot()
    Asm
        pop ix
        jp A_JUMP_MAP_PUT
    End Asm
End Sub


Sub s_cr_light_room( pub_y As UByte , pub_x As UByte )
    ' lights up the room the given square is in, Moria's dungeonLightRoom()
    Asm
        pop ix
        jp A_JUMP_MAP_LIGHT_ROOM
    End Asm
End Sub


Sub s_cr_draw_panel()
    ' draws the whole window, Moria's drawDungeonPanel()
    Asm
        jp A_JUMP_MAP_DRAW_PANEL
    End Asm
End Sub


Function fub_cr_outside_panel( pub_y As UByte , pub_x As UByte , pub_force As UByte ) As UByte
    ' moves the window if the given square is near its edge or outside it, true if it moved and so needs drawing
    ' again, Moria's coordOutsidePanel() and panelBounds()
    Asm
        pop ix
        jp A_JUMP_MAP_OUTSIDE_PANEL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function
