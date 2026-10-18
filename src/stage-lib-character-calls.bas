' a ready made routine for each routine in the character library (stage-lib-character.bas)...
' ...a stage that includes this file calls them by name, exactly as if they were its own, each one simply hands the
' work to the library through the core and passes the answer back
' N.B: the library itself must NOT include this file, these have the same names as the real routines in it

Function fsw_pl_to_hit_adjustment() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_TO_HIT )
    Return gsw_lib_result
End Function


Function fsw_pl_damage_adjustment() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DAMAGE )
    Return gsw_lib_result
End Function


Function fsw_pl_ac_adjustment() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_AC )
    Return gsw_lib_result
End Function


Function fsw_pl_disarm_adjustment() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_DISARM )
    Return gsw_lib_result
End Function


Function fsw_pl_con_adjustment() As Integer
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_CON )
    Return gsw_lib_result
End Function


Function fsw_pl_wis_int_adjustment( pub_which As UByte ) As Integer
    gub_lib_param_1 = pub_which
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_WIS_INT )
    Return gsw_lib_result
End Function


Function fub_pl_modify_stat( pub_stat As UByte , psb_adjustment As Byte ) As UByte
    gub_lib_param_1 = pub_stat
    guw_lib_param_2 = Cast( UInteger , Cast( Integer , psb_adjustment ) )
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_MODIFY_STAT )
    Return Cast( UByte , gsw_lib_result )
End Function


Sub s_pl_set_and_use_stats()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_SET_STATS )
End Sub


Sub s_pl_print_information()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_INFO )
End Sub


Sub s_pl_print_stats()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_STATS )
End Sub


Sub s_pl_print_vital_statistics()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_VITALS )
End Sub


Sub s_pl_print_history()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_HISTORY )
End Sub


Sub s_pl_print_level_experience()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_LEVEL )
End Sub


Sub s_pl_print_abilities()
    s_core_call_library( UB_PAGED_CODE_LIB_CHARACTER , UB_LIB_CHAR_PRINT_ABILITIES )
End Sub