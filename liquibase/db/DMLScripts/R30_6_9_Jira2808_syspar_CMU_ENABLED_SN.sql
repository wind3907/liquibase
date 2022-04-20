/****************************************************************************************
** Desc: Script to Add Syspar to Enable Country of Origin & Wild farm Description
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    02/14/2020   xzhe5043    Jira-2808: added syspar "CMU_ENABLED_SN " to control 
**			       when the SN CMU logics has been changed to by-pass
**                             opcos that receive SNs from NE RDC.
**
*****************************************************************************************/

DECLARE
	v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'CMU_ENABLED_SN';

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
                     'CMU_ENABLED_SN',
                     'SN reader with CMU info (Y/N)',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'N',
                     'SN reader utilize Syspar control in CMU logic',
                     'NONE');
        COMMIT;
    END IF;
END;
/
