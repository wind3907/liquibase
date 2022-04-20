/****************************************************************************
**
** Script to create syspar LOAD_IM_UPC
** Jira card #OPCOF-2680
**
**                                   
****************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'LOAD_IM_UPC';
    
    IF v_row_count = 0 THEN
        INSERT INTO swms.sys_config
                    (seq_no, 
                     application_func, 
                     config_flag_name, 
                     config_flag_desc,  
                     config_flag_val, 
                     value_required, 
                     value_updateable,
                     value_is_boolean,
                     data_type,
                     data_precision, 
                     sys_config_list, 
                     sys_config_help
                     ) 
               VALUES 
                    ((SELECT MAX(seq_no)+1 FROM swms.sys_config),
                     'GENERAL',
                     'LOAD_IM_UPC',
                     'Using UPC from source system',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'L',
                     'Using UPC from source system (Y/N)'
                    );

        COMMIT;
    END IF;
END;
/
