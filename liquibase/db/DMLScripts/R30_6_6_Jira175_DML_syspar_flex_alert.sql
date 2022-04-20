/****************************************************************************
**
** Script to create syspar MIN_BATCH_COUNT
** Jira card #OPCOF-175
**
**                                   
****************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'MIN_BATCH_COUNT';
    
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
                     'LABOR MGMT',
                     'MIN_BATCH_COUNT',
                     'Minimum number of batches',
                     '5',
                     'Y',
                     'N',
                     'N',
                     'NUMBER',
                     3,
                     'R',
                     'Minimum number of batches before sending alert for batches not sent to Flex'
                    );

        COMMIT;
    END IF;
END;
/

