/****************************************************************************************
** Desc: Script to Add Syspar to Enable Staging table communication for Linux
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    11/19/2019    igoo9289    SMOD-1255: added syspar "HOST_COMM" to control
**								Staging table communication for Linux
**
**    04/02/2020    igoo9289    SMOD-2427: Check the HOST_TYPE and insert HOST_COMM as
**								'STAGING TABLES' when HOST_TYPE is 'SAP'. Else the HOST_COMM
**								is 'APCOM'.
**
*****************************************************************************************/

DECLARE
	v_host_comm_exists NUMBER := 0;
	v_host_type_sap_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_host_comm_exists
    FROM  swms.sys_config
    WHERE config_flag_name = 'HOST_COMM';

    IF v_host_comm_exists = 0 THEN
        SELECT COUNT(*)
        INTO  v_host_type_sap_exists
        FROM  swms.sys_config
        WHERE config_flag_name = 'HOST_TYPE' AND config_flag_val = 'SAP';

        IF v_host_type_sap_exists = 1 THEN
            INSERT INTO swms.sys_config
                (seq_no, application_func, config_flag_name, config_flag_desc,
                 config_flag_val, value_required, value_updateable, value_is_boolean, data_type,
                 data_precision, sys_config_list, sys_config_help, validation_type)
            VALUES
                 ((SELECT MAX(seq_no)+1 FROM swms.sys_config), 'GENERAL', 'HOST_COMM', 'Host communication mechanism',
                  'STAGING TABLES', 'Y', 'N', 'N', 'CHAR',
                  20, 'N', 'Host communication mechanism. Possible values are ''STAGING TABLES'' and ''APCOM''.', 'NONE');
            COMMIT;
        ELSE
            INSERT INTO swms.sys_config
                (seq_no, application_func, config_flag_name, config_flag_desc,
                 config_flag_val, value_required, value_updateable, value_is_boolean, data_type,
                 data_precision, sys_config_list, sys_config_help, validation_type)
            VALUES
                 ((SELECT MAX(seq_no)+1 FROM swms.sys_config), 'GENERAL', 'HOST_COMM', 'Host communication mechanism',
                  'APCOM', 'Y', 'N', 'N', 'CHAR',
                  20, 'N', 'Host communication mechanism. Possible values are ''STAGING TABLES'' and ''APCOM''.', 'NONE');
            COMMIT;
        END IF;
    END IF;
END;
/
