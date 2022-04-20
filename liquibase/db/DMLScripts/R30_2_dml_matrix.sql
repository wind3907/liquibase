INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'GENERAL', 'MX_INV_SYNC_FLAG', 'To Turn Off Order Gen/Inv Sync', 'N', 'Y',
                       'N', 'N', 'CHAR', 1, NULL, 'L',
                       'Prevents Parralel processing of Inv Sync and Order genaration, 
                        Order generation updates to O, Inv Sync updates to I, Default Value is N', NULL,
                       NULL, NULL, NULL, NULL);

COMMIT;
                       