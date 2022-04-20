/******************************************************************
*  Syspar to  
*  Enable temperature track for items flow in SWMS. 
*  The default value will be N. 
*  04/09/2020 xzhe5043
******************************************************************/ 
DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
     INTO  v_row_count
     FROM swms.sys_config
    WHERE config_flag_name = 'ENABLE_PM_TEMP_TRK';
     
    IF v_row_count = 0 THEN
          INSERT
          INTO sys_config 
               (SEQ_NO, 
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
              VALIDATION_TYPE)
            VALUES
            (
              (SELECT MAX(seq_no) + 1 FROM sys_config),
              'MAINTENANCE',
              'ENABLE_PM_TEMP_TRK',
              'Enable PM Temp Track', 
              'N', 
              'N',
              'N', 
              'Y', 
              'CHAR',
              1, 
              0, 
              'L', 
              'LIST');
  
   End If;
  commit;
END;
/
