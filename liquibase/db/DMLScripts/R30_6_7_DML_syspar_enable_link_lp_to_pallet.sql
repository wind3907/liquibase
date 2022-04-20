/****************************************************************************
**
** Script to create syspar ENABLE_LINK_LP_TO_PALLET
** Jira card #OPCOF-759
**
**
****************************************************************************/

DECLARE
        v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'ENABLE_LINK_LP_TO_PALLET';

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
                     'RECEIVING',
                     'ENABLE_LINK_LP_TO_PALLET',
                     'Enable Parent/Child LP link',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'R',
                     'For Meat Build To Pallet, Enable Parent LP pallet to link with child LP#'
                    );

        COMMIT;
    END IF;
END;
/

