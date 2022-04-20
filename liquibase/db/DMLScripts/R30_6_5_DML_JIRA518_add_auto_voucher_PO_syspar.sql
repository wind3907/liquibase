/******************************************************************
*  AUTO_VOUCHER_INTERNAL_PO: Syspar for  
*  for auto vourcher internal FoodPro PO. 
*  The default value will be 3.
*  07/18/2018 xzhe5043
******************************************************************/ 

DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
     INTO  v_row_count
     FROM swms.sys_config
    WHERE config_flag_name = 'AUTO_VOUCHER_INTERNAL_PO'
      AND APPLICATION_FUNC = 'RECEIVING';
     
    IF v_row_count = 0 THEN
          INSERT
          INTO sys_config 
            (
              SEQ_NO,
              APPLICATION_FUNC,
              CONFIG_FLAG_NAME,
              CONFIG_FLAG_DESC,
              CONFIG_FLAG_VAL,
              VALUE_REQUIRED,
              VALUE_UPDATEABLE,
              VALUE_IS_BOOLEAN,
              DATA_TYPE,
              DATA_PRECISION,
              DATA_SCALE,
              SYS_CONFIG_LIST,
              SYS_CONFIG_HELP,
              LOV_QUERY,
              VALIDATION_TYPE,
              RANGE_LOW,
              RANGE_HIGH,
              DISABLED_FLAG
            )
            VALUES
            (
              (SELECT MAX(seq_no) + 1 FROM sys_config),
              'RECEIVING',
              'AUTO_VOUCHER_INTERNAL_PO',
              'Days wait to auto voucher PO',
              3,
              'Y',
              'Y',
              'Y',
              'NUMBER',
              1,
              NULL,
              'N',
              'Days wait to auto voucher PO',
              NULL,
              'RANGE',
              1,
              10,
              NULL
            );
  
   End If;
  commit;
END;
/




