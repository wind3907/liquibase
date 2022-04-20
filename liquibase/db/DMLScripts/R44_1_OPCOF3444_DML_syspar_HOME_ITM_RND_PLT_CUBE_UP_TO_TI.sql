/****************************************************************************************
**
** Desc: Script to add Syspar to control the logic of rounding up the home item partial pallet cube to TI.
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     -----------------------------------------------------------------------
**    05/13/2010    sban3548    OPCOF-3444: Created syspar "HOME_ITM_RND_PLT_CUBE_UP_TO_TI" to turn ON/OFF 
**								the round up home slot item pallet cube to Tier, in case of partial pallet.
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'HOME_ITM_RND_PLT_CUBE_UP_TO_TI';

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
                     'RECEIVING',
                     'HOME_ITM_RND_PLT_CUBE_UP_TO_TI',
                     'Round Home Pallet Cube to Tier',
                     'Y',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'N',
                     'Valid values are N or Y(default). Disable the syspar to turn off the rounding of partial Pallet cube to TI for Home slot item',
                     'NONE');
        COMMIT;
    END IF;
END;
/
