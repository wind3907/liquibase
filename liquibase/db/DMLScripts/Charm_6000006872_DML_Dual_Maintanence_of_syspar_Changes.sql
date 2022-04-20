UPDATE swms.sys_config SET CONFIG_FLAG_VAL = 'Y' WHERE config_flag_name = 'PRINT_LOGO_ON_SOS_LABEL' ;
UPDATE swms.sys_config SET CONFIG_FLAG_VAL = 'Y' WHERE config_flag_name = 'MULTI_LANGUAGE_DATABASE_USE';
UPDATE swms.sys_config SET VALIDATION_TYPE = 'NONE' WHERE config_flag_name = 'DFLT_PRNTR_PO_CLOSURE';  
UPDATE swms.sys_config SET config_flag_desc='Enable item level unit (Y/N)',VALIDATION_TYPE='LIST' WHERE CONFIG_FLAG_NAME = 'ITEM_LEVEL_WEIGHT_UNITS';
Insert into SWMS.SYS_CONFIG_VALID_VALUES
   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
 Values
   ('ITEM_LEVEL_WEIGHT_UNITS', 'N', 'Bhamas changes will not be included');
Insert into SWMS.SYS_CONFIG_VALID_VALUES
   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
 Values
   ('ITEM_LEVEL_WEIGHT_UNITS', 'Y', 'Bhamas changes will be included');
   
COMMIT;
