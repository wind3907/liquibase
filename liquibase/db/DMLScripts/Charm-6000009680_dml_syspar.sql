/****************************************************************************
** Date:       09-FEB-2015
** File:       Charm-6000009680_dml_syspar.sql
**
**             Script to insert the data into SAP_INTERFACE_PURGE 
**				for purging the data after 5 days.
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    09-FEB-15 SPOT3255 Charm#6000005076
**                       Project: Charm-6000005076_dml_schema.sql 
**  		         STS Upgrade Phase II Development with SCI011,SCI012 interfaces.                 
**
****************************************************************************/
  
Insert into SYS_CONFIG(
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
	SYS_CONFIG_LIST,                          
	SYS_CONFIG_HELP)                          
Values (
	(SELECT MAX(seq_no) + 1 FROM sys_config),    
	'STS',
	'STS_PROCESS_RUN_FLAG',
	'STS Process Flag',
	'N',
	'Y',
	'N',
	'N',
	'CHAR',
	 1,
	'L',
	'Set to Y if route building is in process ')
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'STS_PROCESS_RUN_FLAG' config_flag_name,
   'N' config_flag_val,
   'Do not start route build process. This is default.' description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'STS_PROCESS_RUN_FLAG' config_flag_name,
   'Y' config_flag_val,
   'starting route build process' description
FROM DUAL;  
   
COMMIT;