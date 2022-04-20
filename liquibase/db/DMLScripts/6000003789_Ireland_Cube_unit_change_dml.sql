/****************************************************************************
** Date:       20-NOV-2014
** File:       6000003789_Ireland_Cube_unit_change_dml.sql
**
** Script to insert SYSPAR valeus for Ireland Cubic value metric conversion
**
** Create below SYSPAR entries for below table
** 		1.SYSCO_LOGO_TYPE
** 		2.PRINT_LOGO_ON_SOS_LABEL
** 		3.LENGTH_UNIT
**		4.LOC_CUBE_KEY_VALUE
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    11/20/14 Infosys  SYSPAR for Ireland metric conversion
**
****************************************************************************/
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'ORDER PROCESSING', 'PRINT_LOGO_ON_SOS_LABEL', 'Print Logo on SOS Label', 'N', 'Y',
                       'N', 'Y', 'CHAR', 1, NULL, 'L',
                       'Print Logo on SOS Label Y/N', NULL,
                       'LIST', NULL, NULL, NULL);

INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('PRINT_LOGO_ON_SOS_LABEL', 'N', 'Print Logo on SOS Label - No');
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('PRINT_LOGO_ON_SOS_LABEL', 'Y', 'Print Logo on SOS Label - Yes');
                               
                               
                               
                               
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'GENERAL', 'LENGTH_UNIT', 'Length Measurement Unit', 'IN', 'Y',
                       'N', 'N', 'CHAR', 2, NULL, 'L',
                       'Length Measurement Unit IN/CM', NULL,
                       'LIST', NULL, NULL, NULL);   
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('LENGTH_UNIT', 'IN', 'Length Measurement Unit - Inch');     
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('LENGTH_UNIT', 'CM', 'Length Measurement Unit - Centimeter');
                               
                               
                               
INSERT INTO sys_config (SEQ_NO,APPLICATION_FUNC,CONFIG_FLAG_NAME,CONFIG_FLAG_DESC,CONFIG_FLAG_VAL,VALUE_REQUIRED,
                        VALUE_UPDATEABLE,VALUE_IS_BOOLEAN,DATA_TYPE,DATA_PRECISION,DATA_SCALE,SYS_CONFIG_LIST,
                        SYS_CONFIG_HELP,LOV_QUERY,
                        VALIDATION_TYPE,RANGE_LOW,RANGE_HIGH,DISABLED_FLAG) 
                VALUES ((SELECT MAX(seq_no) + 1 FROM sys_config), 
                       'GENERAL', 'SYSCO_LOGO_TYPE', 'Sysco Logo Type', 'Sysco English', 'Y',
                       'N', 'N', 'CHAR', 20, NULL, 'L',
                       'Sysco Logo Type - Sysco English (1)/ Sysco French(2)/ Pallas(3)', NULL,
                       'LIST', NULL, NULL, NULL);         
                       
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Sysco English', 'Sysco Logo Type - Sysco English');    
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Sysco French', 'Sysco Logo Type - Sysco French');   
                               
INSERT INTO sys_config_valid_values (config_flag_name, config_flag_val, description)
                              VALUES('SYSCO_LOGO_TYPE', 'Pallas', 'Sysco Logo Type - Pallas');
							  
INSERT INTO sys_config (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME,CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, VALUE_REQUIRED,
             		    VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION,DATA_SCALE, SYS_CONFIG_LIST,
             		    SYS_CONFIG_HELP,VALIDATION_TYPE)
     		   VALUES  ((SELECT MAX(seq_no) + 1 FROM sys_config), 'GENERAL', 'LOC_CUBE_KEY_VALUE',
             		   'Location Cube exception value', '999', 'Y',
             		   'N', 'N', 'NUMBER', 0,0, 'N',
             		   'Location cube value used for DMG Location/PUTAWAY logic extended cube/European Imports(CDK) special location','NONE');
