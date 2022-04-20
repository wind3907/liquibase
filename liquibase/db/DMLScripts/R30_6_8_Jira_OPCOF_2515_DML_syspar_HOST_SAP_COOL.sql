/****************************************************************************************
** Desc: Script to Add Syspar to Enable Country of Origin & Wild farm Description
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    10/01/2019    sban3548    Jira-2515: added syspar "HOST_SAP_COOL" to control 
**								Country of origin & Wild farm Description   
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'HOST_SAP_COOL';

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
                     'HOST_SAP_COOL',
                     'Enable Country of Origin',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'N',
                     'Enable Country of Origin and Wild Farm Description for a specific SAP company like Asaian Foods Only and not to send from other SAP companies',
                     'NONE');
        COMMIT;
    END IF;
END;
/
