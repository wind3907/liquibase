--OPCOF-3712 Populate BY_GOAL_TIME_ENABLED sysconfig
DECLARE
    config_available Number;
    seq_no Number;

    l_enabled VARCHAR2(20):= 'N';

BEGIN
        SELECT count(*) INTO config_available FROM sys_config
            WHERE config_flag_name = 'BY_GOAL_TIME_ENABLED';
        IF config_available = 0 THEN
            --insert
            SELECT NVL(max(seq_no),0)+1 INTO seq_no FROM sys_config;
            insert into sys_config (seq_no,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,
            DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,SYS_CONFIG_HELP)
            values
            (seq_no,'LABOR MGMT','BY_GOAL_TIME_ENABLED','Enable BlueYonder goaltime',l_enabled,'Y','N','Y',
            'CHAR',1,0,'L','The syspar is used to control updating goal_time column in batch table from blueyonder goaltime value. Y - update goal_time column from blueyonder goaltime,N - do not update goal_time column from blueyonder goaltime. This flag is controlled by corporate office. '
             );
        END IF;
        commit;
END;
/