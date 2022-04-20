
COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar OSD_REASON_CODE
********************************************************************/

/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config;


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
        DATA_SCALE,
	SYS_CONFIG_LIST,                          
	SYS_CONFIG_HELP)                          
Values (
	&maxseq + 1,    
	'GENERAL',
	'WEIGHT_UNIT',
	'Weight Unit (KG or LB)',
	'LB',
	'Y',
	'Y',
	'Y',
	'CHAR',
	2,
        0,
	'L',
	'Unit of Weight ')
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'WEIGHT_UNIT' config_flag_name,
   'KG' config_flag_val,
   'Entered/Displayed Weight is in Kilograms' description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'WEIGHT_UNIT' config_flag_name,
   'LB' config_flag_val,
   'Entered/Displayed Weight is in pounds' description
FROM DUAL
/
