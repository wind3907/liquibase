/****************************************************************************
** File: JIRA505_DML_Add_Syspar_Enable_Foodpro.sql
**
** Desc: Script to add syspar ENABLE_FOODPRO 
**        
**
** Modification History:
**    Date      Designer           Comments
**  ---------- ---------- -----------------------------------------
**  26-Jun-2018 sban3548   Script to add syspar ENABLE_FOODPRO
**                                   
****************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'ENABLE_FOODPRO';

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
                     sys_config_help,
                     validation_type,
                     range_low, 
                     range_high) 
               VALUES
                     ((SELECT MAX(seq_no)+1 FROM swms.sys_config),
                     'ORDER PROCESSING',
                     'ENABLE_FOODPRO',
                     'Enable FoodPro',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'L',
                     'Enable FoodPro',
                     'NONE',
                     NULL,
                     NULL);
        COMMIT;
    END IF;
END;
/
