/******************************************************************
*  AUTO_MANIFEST_CLOSE: Syspar for  
*  for auto close manifest. The default value will be 7.
*
******************************************************************/ 

DECLARE
v_row_count NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO  v_row_count
    FROM  swms.sys_config
    WHERE config_flag_name = 'AUTO_MANIFEST_CLOSE';

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
                     validation_type,
                     range_low, 
                     range_high) 
               VALUES
                     ((SELECT MAX(seq_no)+1 FROM swms.sys_config),
                     'DRIVER CHECK IN',
                     'AUTO_MANIFEST_CLOSE',
                     'Days until Auto Manifest CLS',
                     '7',
                     'Y',
                     'Y',
                     'N',
                     'NUMBER',
                     1,
                     'L',
                     'Number of days to wait before closing open manifests',
                     'LIST',
                     NULL,
                     NULL);
        COMMIT;
    END IF;
END;
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'AUTO_MANIFEST_CLOSE'            config_flag_name,
   '5'                              config_flag_val,
   'Days until Auto Manifest CLS'   description
FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config_valid_values WHERE config_flag_name='AUTO_MANIFEST_CLOSE'
  AND config_flag_val = '5' );
  commit;
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'AUTO_MANIFEST_CLOSE'           config_flag_name,
   '7'                             config_flag_val,
   'Days until Auto Manifest CLS'  description
FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config_valid_values WHERE config_flag_name= 'AUTO_MANIFEST_CLOSE'
  AND config_flag_val = '7' );
  commit;
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'AUTO_MANIFEST_CLOSE'           config_flag_name,
   '10'                             config_flag_val,
   'Days until Auto Manifest CLS'   description
FROM DUAL
WHERE NOT EXISTS ( SELECT 1
 FROM sys_config_valid_values WHERE config_flag_name= 'AUTO_MANIFEST_CLOSE'
  AND config_flag_val = '10' );
commit;
/




