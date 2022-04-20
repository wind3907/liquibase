--OPCOF-4050 Populate DISABLE_IXDOCK_SOS_BARCODE sysconfig
DECLARE
    config_available Number;
    seq_no Number;
BEGIN
        SELECT count(*) INTO config_available FROM sys_config
            WHERE config_flag_name = 'DISABLE_IXDOCK_SOS_BARCODE';
        IF config_available = 0 THEN
            --insert
            SELECT NVL(max(seq_no),0)+1 INTO seq_no FROM sys_config;
            insert into sys_config (seq_no,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,
            DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,SYS_CONFIG_HELP)
            values
            (seq_no,'ORDER_PROCESSING','DISABLE_IXDOCK_SOS_BARCODE','Suppress Pick Label BarCode','Y','Y','N','Y',
            'CHAR',1,0,'L',
            ' Y (Yes) - Barcode will not appear on the pick label for Partial Xdock Orders at the fulfillment site.  N (No)  - Barcode will appear on the pick label for Partial Xdock Orders. For this Syspar to be set to Y, the ENABLE_PARTIAL_ORDER_XDOCK must be set to Y. The Syspar value needs to be sent to the client with the SOS_Login output to the client for the linked story.'
             );
        END IF;
        commit;
END;
/