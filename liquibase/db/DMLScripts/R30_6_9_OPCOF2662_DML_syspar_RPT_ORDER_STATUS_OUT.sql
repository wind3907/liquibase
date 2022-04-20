/****************************************************************************************
**
** Desc: Script to Add Syspar to enable/disable syspar for controlling the functionality of staging SWMS order status
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     -----------------------------------------------------------------------
**    01/08/2020    sban3548    Jira-2662: added syspar "ENABLE_RPT_ORDER_STATUS_OUT" to turn ON/OFF  
**								Staging the order status   
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'ENABLE_RPT_ORDER_STATUS_OUT';

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
                     validation_type
					 ) 
               VALUES
                     ((SELECT MAX(seq_no)+1 FROM swms.sys_config),
                     'INTERFACE',
                     'ENABLE_RPT_ORDER_STATUS_OUT',
                     'Enable Staging of order status',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'N',
                     'Enable populating staging table with SWMS order status at route level for other teams to consume',
                     'NONE');
        COMMIT;
    END IF;
END;
/
