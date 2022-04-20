-----------------------------------------------------------------
--
-- Script to create syspar to enable/disable omni partial 
-- order xdocking.
--
-- 24-Feb-2022 pkab6563
--
----------------------------------------------------------------

DECLARE
        l_row_count PLS_INTEGER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  l_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'ENABLE_PARTIAL_ORDER_XDOCK';

    IF l_row_count = 0 THEN
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
                     'ENABLE_PARTIAL_ORDER_XDOCK',
                     'Enable Partial Order Xdocking',
                     'N',
                     'Y',
                     'N',
                     'Y',
                     'CHAR',
                     1,
                     'L',
                     'Set Enable Partial Orders to Y to allow Partial Order cross docking. Set to N to disable Partial Order cross docking.'
                    );

        COMMIT;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'OPCOF4016_DML_omni_syspar',
                       'Deployment DML to create syspar ENABLE_PARTIAL_ORDER_XDOCK failed',
                       SQLCODE, SQLERRM);
        RAISE;

END;
/
