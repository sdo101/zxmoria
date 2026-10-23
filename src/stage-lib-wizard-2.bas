#PRAGMA push(case_insensitive)
#PRAGMA case_insensitive = True
#define STANDALONE  ' remove ROM initialization and SysVars...

' N.B: this must be the very first code in the file, the core calls address $6000 to run this page...
' ...the build script checks that the compiled code really does start at $6000
s_lib_wizard_2()
Asm
    ret
End Asm


#include "constants.bas"
#include "globals.bas"
#include "stage-include.bas"
#include "stage-message-include.bas"
#include "stage-level-include.bas"

' this page is a LIBRARY, not a stage: the two wizard commands that ask a long list of questions, the wizard
' library, stage-lib-wizard.bas, has no room for them, it sends for them through the core:
' s_core_call_library( UB_PAGED_CODE_LIB_WIZARD_2 , <which routine> ), the routines are:
'
'   UB_LIB_WIZARD_2_CHARACTER   Ctrl-E: the character's stats, hit points, mana, gold, skills, weight and speed are
'                               asked for one after another, ENTER on its own leaves one as it is and ESCAPE
'                               leaves that one and the rest, Moria's wizardCharacterAdjustment()
'   UB_LIB_WIZARD_2_OBJECT      @ : an object is made up field by field and put under the player, Moria's
'                               wizardCreateObjects(), which warns that it "can cause a fatal error", nothing
'                               checks that the fields make sense together
'
' N.B: one thing is not as Moria 5.7.15 has it: there the answer to "Searching" is thrown away, and the skill is
' set to the length of the question instead, a slip in Moria's source, here it is set to the answer


' --- its working storage is in globals.bas, under "private to stage-lib-wizard-2.bas", moved there on 22 October 2026 ---


Function fub_w2_call( pub_page As UByte , pub_function As UByte , pub_param As UByte , puw_param As UInteger ) As UByte
    ' one of another library's routines, with its answer, the core has the routine, see fub_core_lib_call()
    Asm
        pop ix
        jp A_JUMP_LIB_CALL
    End Asm
    Return 0        ' never reached, it is only here because the compiler expects a Function to end with a Return
End Function


#include "stage-wizard-include.bas"


Function fs_w2_signed( psl_value As Long ) As String
    If psl_value < 0 Then Return "-" + fs_core_number( 0 - psl_value )
    Return fs_core_number( psl_value )
End Function


Function fub_w2_value( ps_prompt As String , pub_max As UByte , psl_low As Long , psl_high As Long ) As UByte
    ' asks for one number: 0 if the player escaped, 2 if they gave a number from psl_low to psl_high, which is
    ' then in gsl_wz_number, and 1 for anything else, which leaves things as they are
    If fub_wz_ask( ps_prompt , pub_max ) = false Then Return 0
    If gub_wz_valid = false Then Return 1
    If gsl_wz_number < psl_low Or gsl_wz_number > psl_high Then Return 1
    Return 2
End Function


'##################################################################################################################################
' --- the character ---

Function fub_w2_stat( ps_prompt As String , pub_stat As UByte ) As UByte
    ' one of the six stats, false if the player escaped
    Dim lub_answer As UByte

    lub_answer = fub_w2_value( ps_prompt , 3 , 3 , 118 )
    If lub_answer = 0 Then Return false
    If lub_answer = 2 Then
        Poke A_PLAYER_STATS_MAX + pub_stat , Cast( UByte , gsl_wz_number )
        gub_shared_1 = fub_w2_call( UB_PAGED_CODE_LIB_EFFECTS , UB_LIB_EFFECTS_STAT_RESTORE , pub_stat , 0 )
    End If
    Return true
End Function


Function fub_w2_skill( ps_name As String , puw_where As UInteger , psl_low As Long , psl_high As Long ) As UByte
    ' one of the skills, a signed 2 byte value at puw_where, false if the player escaped
    Dim lub_answer As UByte

    lub_answer = fub_w2_value( "Current=" + fs_w2_signed( Peek( Integer , puw_where ) ) + "  " + ps_name + " = " , 3 , psl_low , psl_high )
    If lub_answer = 0 Then Return false
    If lub_answer = 2 Then Poke UInteger puw_where , Cast( UInteger , gsl_wz_number )
    Return true
End Function


Sub s_w2_character()
    ' Moria's wizardCharacterAdjustment()
    Dim lub_answer As UByte

    If fub_w2_stat( "(3 - 118) Strength     = " , UB_STAT_STR ) = false Then Return
    If fub_w2_stat( "(3 - 118) Intelligence = " , UB_STAT_INT ) = false Then Return
    If fub_w2_stat( "(3 - 118) Wisdom       = " , UB_STAT_WIS ) = false Then Return
    If fub_w2_stat( "(3 - 118) Dexterity    = " , UB_STAT_DEX ) = false Then Return
    If fub_w2_stat( "(3 - 118) Constitution = " , UB_STAT_CON ) = false Then Return
    If fub_w2_stat( "(3 - 118) Charisma     = " , UB_STAT_CHR ) = false Then Return

    lub_answer = fub_w2_value( "(1 - 32767) Hit points = " , 5 , 1 , 32767 )
    If lub_answer = 0 Then Return
    If lub_answer = 2 Then
        gsw_player_max_hp      = gsl_wz_number
        gsw_player_current_hp  = gsl_wz_number
        guw_player_hp_fraction = 0
    End If

    lub_answer = fub_w2_value( "(0 - 32767) Mana       = " , 5 , 0 , 32767 )
    If lub_answer = 0 Then Return
    If lub_answer = 2 Then
        gsw_player_mana           = gsl_wz_number
        gsw_player_current_mana   = gsl_wz_number
        guw_player_mana_fraction  = 0
    End If

    lub_answer = fub_w2_value( "Current=" + fs_w2_signed( gsl_player_gold ) + "  Gold = " , 7 , 0 , 9999999 )
    If lub_answer = 0 Then Return
    If lub_answer = 2 Then gsl_player_gold = gsl_wz_number

    ' N.B: see the note at the top of this page about the first of these
    If fub_w2_skill( "(0-200) Searching" , @gsw_player_search , 0 , 200 ) = false Then Return
    If fub_w2_skill( "(-1-18) Stealth" , @gsw_player_stealth , -1 , 18 ) = false Then Return
    If fub_w2_skill( "(0-200) Disarming" , @gsw_player_disarm , 0 , 200 ) = false Then Return
    ' N.B: as in Moria, the question says 100 and up to 200 is taken
    If fub_w2_skill( "(0-100) Save" , @gsw_player_saving_throw , 0 , 200 ) = false Then Return
    If fub_w2_skill( "(0-200) Base to hit" , @gsw_player_bth , 0 , 200 ) = false Then Return
    If fub_w2_skill( "(0-200) Bows/Throwing" , @gsw_player_bth_bows , 0 , 200 ) = false Then Return

    lub_answer = fub_w2_value( "Current=" + fs_core_number( guw_player_weight ) + "  Weight = " , 3 , 0 , 999 )
    If lub_answer = 0 Then Return
    If lub_answer = 2 Then guw_player_weight = gsl_wz_number

    ' Moria's getCommand(): + is faster, - is slower, anything else ends it
    Do
        s_msg_clear()
        s_core_print_string_at( 0 , 0 , "Alter speed? (+/-)" , UB_WHITE )
        s_core_get_key()
        s_msg_clear()
        If gub_key_char = Code( "+" ) Then
            gub_shared_1 = fub_w2_call( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED , 0 , $FFFF )
        ElseIf gub_key_char = Code( "-" ) Then
            gub_shared_1 = fub_w2_call( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_CHANGE_SPEED , 0 , 1 )
        End If
        s_core_call_library( UB_PAGED_CODE_LIB_TURN_2 , UB_LIB_TURN_2_STATUS_LINE )
    Loop While gub_key_char = Code( "+" ) Or gub_key_char = Code( "-" )
End Sub


'##################################################################################################################################
' --- an object ---


Function ful_w2_hex() As ULong
    ' what the player typed, read as a number in hexadecimal, as far as it goes, Moria's sscanf( "%lx" )
    Dim lul_value   As ULong = 0
    Dim i , c , d   As UByte

    i = 0
    While Peek( A_PROMPT + i ) = 32
        i = i + 1
    End While
    If Peek( A_PROMPT + i ) = Code( "0" ) And ( Peek( A_PROMPT + i + 1 ) bOr 32 ) = Code( "x" ) Then i = i + 2
    Do
        c = Peek( A_PROMPT + i )
        d = 255
        If c >= Code( "0" ) And c <= Code( "9" ) Then d = c - Code( "0" )
        c = c bOr 32
        If c >= Code( "a" ) And c <= Code( "f" ) Then d = c - Code( "a" ) + 10
        If d <> 255 Then lul_value = ( lul_value << 4 ) bOr d
        i = i + 1
    Loop Until d = 255
    Return lul_value
End Function


Sub s_w2_object()
    ' Moria's wizardCreateObjects(): every field of the object is asked for, ESCAPE at any of them gives up
    Dim i           As UByte
    Dim lub_number  As UByte
    Dim ls_text     As String

    s_core_message( UW_MSG_WARNING_THIS_ROUTINE_CAN_CAUSE_A )

    ' Moria's "forge": nothing in it but what it is, its inscription, and that all is known about it
    For i = 0 To UB_RECORD_SIZE - 1
        Poke A_W2_ITEM + i , 0
    Next
    Poke UInteger A_W2_ITEM , UW_OBJ_WIZARD
    ls_text = "wizard item"
    For i = 0 To Len( ls_text ) - 1
        Poke A_W2_ITEM + UB_ITEM_INSCRIPTION_OFFSET + i , Code( ls_text( i ) )
    Next
    Poke A_W2_ITEM + UB_ITEM_IDENTIFICATION_OFFSET , MB_ID_KNOWN2 bOr MB_ID_STORE_BOUGHT

    If fub_wz_ask( "Tval   : " , 3 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_CATEGORY_OFFSET , Cast( UByte , gsl_wz_number )

    If fub_wz_ask( "Tchar  : " , 1 ) = false Then Return
    Poke A_W2_ITEM + UB_ITEM_SPRITE_OFFSET , Peek( A_PROMPT )

    If fub_wz_ask( "Subval : " , 5 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_SUB_CATEGORY_OFFSET , Cast( UByte , gsl_wz_number )

    If fub_wz_ask( "Weight : " , 5 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_WEIGHT_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "Number : " , 5 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_COUNT_OFFSET , Cast( UByte , gsl_wz_number )

    If fub_wz_ask( "Damage (dice): " , 3 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_DAMAGE_OFFSET , Cast( UByte , gsl_wz_number )

    If fub_wz_ask( "Damage (sides): " , 3 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_DAMAGE_OFFSET + 1 , Cast( UByte , gsl_wz_number )

    If fub_wz_ask( "+To hit: " , 3 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_TO_HIT_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "+To dam: " , 3 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_TO_DAMAGE_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "AC     : " , 3 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_AC_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "+To AC : " , 3 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_TO_AC_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "P1     : " , 5 ) = false Then Return
    If gub_wz_valid Then Poke UInteger A_W2_ITEM + UB_ITEM_MISC_USE_OFFSET , Cast( UInteger , gsl_wz_number )

    If fub_wz_ask( "Flags (In HEX): " , 8 ) = false Then Return
    Poke ULong A_W2_ITEM + UB_ITEM_FLAGS_OFFSET , ful_w2_hex()

    If fub_wz_ask( "Cost :   " , 8 ) = false Then Return
    If gub_wz_valid Then Poke Long A_W2_ITEM + UB_ITEM_COST_OFFSET , gsl_wz_number

    If fub_wz_ask( "Level :   " , 3 ) = false Then Return
    If gub_wz_valid Then Poke A_W2_ITEM + UB_ITEM_DEPTH_OFFSET , Cast( UByte , gsl_wz_number )

    If fub_wz_confirm( "Allocate?" ) Then
        ' delete object first if any, before call popt()
        If Peek( fuw_core_map_square( gub_level_map_page , gub_player_row , gub_player_col ) + UB_SQUARE_ITEM ) <> 0 Then
            gub_shared_1 = fub_w2_call( UB_PAGED_CODE_LIB_MOVES , UB_LIB_MOVES_DELETE_OBJECT , gub_player_row , gub_player_col )
        End If
        lub_number = fub_gen_new_item( UW_OBJ_WIZARD )
        If lub_number <> 0 Then
            s_core_ram_copy( A_W2_ITEM , A_ITEM , UB_RECORD_SIZE )
            s_gen_put_item( gub_player_row , gub_player_col , lub_number )
            s_core_message( UW_MSG_ALLOCATED )
            Return
        End If
    End If
    s_core_message( UW_MSG_ABORTED )
End Sub


Sub s_lib_wizard_2()
    Dim lub_saved_page_2 As UByte

    ' ours: the wizard may light the level, or change it, the mini map is made again before it is next drawn
    gub_minimap_rebuild = true
    lub_saved_page_2 = gub_core_MMU2_page_number
    If gub_lib_function = UB_LIB_WIZARD_2_CHARACTER Then
        s_w2_character()
        s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_BLOCK )
    ElseIf gub_lib_function = UB_LIB_WIZARD_2_OBJECT Then
        s_w2_object()
    End If
    If lub_saved_page_2 <> UB_PAGE_NONE Then s_core_swap_paged_data( UB_SLOT_DB_MAPS , lub_saved_page_2 )
End Sub
