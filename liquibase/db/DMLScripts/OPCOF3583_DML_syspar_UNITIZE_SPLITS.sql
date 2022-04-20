/****************************************************************************************
**
** Desc: Script to add Syspar to control the logic of unitizing split orders for Brakes.
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     -----------------------------------------------------------------------
**    02/08/2022    sban3548    OPCOF-3583: Created syspar "UNITIZE_SPLITS" to turn ON/OFF 
**								the logic of unitizing the splits and prevent overcubing of floats.
**								Currently Brakes uses this logic.
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'UNITIZE_SPLITS';

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
                     'ORDER_PROCESSING',
                     'UNITIZE_SPLITS',
                     'Unitize split orders',
                     'N',
                     'Y',
                     'N',
                     'N',
                     'CHAR',
                     1,
                     'Y',
                     'Valid values are Y or N(default). Enable the syspar to turn ON the unitize splits logic and prevent overcubing of floats',
                     'NONE');
        COMMIT;
    END IF;
END;
/
