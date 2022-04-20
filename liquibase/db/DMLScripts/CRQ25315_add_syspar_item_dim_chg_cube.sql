
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
	'CUBE_CHG_FOR_DIM_CHG',
	'Chg cube if item dim is chged',
	'N',
	'Y',
	'Y',
	'Y',
	'CHAR',
	2,
        0,
	'L',
	'Change item''s cube value if its dimension(s) is/are changed')
/
INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'CUBE_CHG_FOR_DIM_CHG' config_flag_name,
   'N' config_flag_val,
   'Don''t change the case/split cube when item''s case dimension(s) is/are changed. This is default.' description
FROM DUAL
/

INSERT INTO sys_config_valid_values
   (config_flag_name, config_flag_val, description)
SELECT
   'CUBE_CHG_FOR_DIM_CHG' config_flag_name,
   'Y' config_flag_val,
   'Change the case/split cube when item''s case dimension(s) is/are changed.' description
FROM DUAL
/
