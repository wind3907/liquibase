--OPCOF-3939 Populate SDV_PALLET_ZONES sysconfig
DECLARE
    config_available Number;
    seq_no Number;
BEGIN
        SELECT count(*) INTO config_available FROM sys_config
            WHERE config_flag_name = 'SDV_PALLET_ZONES';
        IF config_available = 0 THEN
            --insert
            SELECT NVL(max(seq_no),0)+1 INTO seq_no FROM sys_config;
            insert into sys_config (seq_no,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,
            DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,SYS_CONFIG_HELP)
            values
            (seq_no,'LOADING','SDV_PALLET_ZONES','Maintain SDV pallet zones','Z4,Z5','Y','N','Y',
            'CHAR',1,0,'L',
            'The syspar is used to maintain loading pallet zones for blueyonder sdv integration.This flag allows a list of zones separate by a comma (Z4,Z5..). This flag is controlled by corporate office.'
             );
        END IF;
        commit;
END;
/