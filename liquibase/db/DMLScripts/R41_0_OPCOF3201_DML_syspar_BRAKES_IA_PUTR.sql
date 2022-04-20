/****************************************************************************************
**
** Desc: Script to add Syspar for controlling the expected_qty of return PUTs in IA writer for SAP Brakes 
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     -----------------------------------------------------------------------
**    09/23/2020    sban3548    OPCOF-3201: Created syspar "BRAKES_IA_PUTR_ENABLE" to turn ON/OFF ERM_ID,  
**				Expected_qty with correct values instead of "R", "I/P" for Return PUTs to SAP.
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'BRAKES_IA_PUTR_ENABLE';

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
                     'BRAKES_IA_PUTR_ENABLE',
                     'Enable PUTR Expected_qty',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'N',
                     'Valid values are Y or N(default). Enable SAP Brakes site to populate ERM_ID, Expected_qty with correct values instead of "R", "I/P" for Return PUT transactions to SAP',
                     'NONE');
        COMMIT;
    END IF;
END;
/
