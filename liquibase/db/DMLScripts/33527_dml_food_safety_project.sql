--CRQ #33527, created for food safety project

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar FOOD_SAFETY_ENABLE
********************************************************************/
-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO SWMS."SYS_CONFIG" 
(SEQ_NO, 
APPLICATION_FUNC, 
CONFIG_FLAG_NAME, 
CONFIG_FLAG_DESC, 
CONFIG_FLAG_VAL, 
VALUE_REQUIRED, 
VALUE_UPDATEABLE, 
VALUE_IS_BOOLEAN, 
DATA_TYPE,DATA_PRECISION, 
SYS_CONFIG_LIST,SYS_CONFIG_HELP, 
VALIDATION_TYPE)
SELECT &maxseq + 1 seq_no, 
'RECEIVING' APPLICATION_FUNC, 
'FOOD_SAFETY_ENABLE'  CONFIG_FLAG_NAME,
'FoodSafety menus enabled?'  CONFIG_FLAG_DESC, 
'N'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'N'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'Enable / disable Food Safety menus'   SYS_CONFIG_HELP, 
'NONE'                          VALIDATION_TYPE from DUAL
/

/********************************************************************
**    Create sypar FOOD_SAFETY_TEMPERATURE_UNIT
********************************************************************/
-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO SWMS."SYS_CONFIG" 
(SEQ_NO, 
APPLICATION_FUNC, 
CONFIG_FLAG_NAME, 
CONFIG_FLAG_DESC, 
CONFIG_FLAG_VAL, 
VALUE_REQUIRED, 
VALUE_UPDATEABLE, 
VALUE_IS_BOOLEAN, 
DATA_TYPE,DATA_PRECISION, 
SYS_CONFIG_LIST,SYS_CONFIG_HELP, 
VALIDATION_TYPE)
SELECT &maxseq + 1 seq_no, 
'RECEIVING' APPLICATION_FUNC, 
'FOOD_SAFETY_TEMPERATURE_UNIT'  CONFIG_FLAG_NAME,
'Food Safety temperature unit'  CONFIG_FLAG_DESC, 
'F'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'N'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'L'                             SYS_CONFIG_LIST,
'Based on the value defined here OPCO can enter Farenheit or Celcius'   SYS_CONFIG_HELP, 
'NONE'                          VALIDATION_TYPE from DUAL
/

/********************************************************************
**    Create sypar FOOD_SAFETY_TEMP_LIMIT
********************************************************************/
-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO SWMS."SYS_CONFIG" 
(SEQ_NO, 
APPLICATION_FUNC, 
CONFIG_FLAG_NAME, 
CONFIG_FLAG_DESC, 
CONFIG_FLAG_VAL, 
VALUE_REQUIRED, 
VALUE_UPDATEABLE, 
VALUE_IS_BOOLEAN, 
DATA_TYPE,DATA_PRECISION, 
SYS_CONFIG_LIST,SYS_CONFIG_HELP, 
VALIDATION_TYPE)
SELECT &maxseq + 1 seq_no, 
'RECEIVING' APPLICATION_FUNC, 
'FOOD_SAFETY_TEMP_LIMIT'  CONFIG_FLAG_NAME,
'FoodSafety temps maximum limit'  CONFIG_FLAG_DESC, 
'40'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'N'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'NUMBER'                          DATA_TYPE,
'3'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'The maximum temperature limit allowed for Food Safety'   SYS_CONFIG_HELP, 
'NONE'                          VALIDATION_TYPE from DUAL
/

/********************************************************************
**    Create sypar FOOD_SAFETY_START_DATE
********************************************************************/
-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/


INSERT INTO SWMS."SYS_CONFIG"
(SEQ_NO,
APPLICATION_FUNC,
CONFIG_FLAG_NAME,
CONFIG_FLAG_DESC,
CONFIG_FLAG_VAL,
VALUE_REQUIRED,
VALUE_UPDATEABLE,
VALUE_IS_BOOLEAN,
DATA_TYPE,DATA_PRECISION,
SYS_CONFIG_LIST,SYS_CONFIG_HELP,
VALIDATION_TYPE)
SELECT &maxseq + 1 seq_no,
'RECEIVING' APPLICATION_FUNC,
'FOOD_SAFETY_START_DATE'  CONFIG_FLAG_NAME,
'FoodSafety starts from date?'  CONFIG_FLAG_DESC,
'01-JUL-2012'                   CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED,
'N'                             VALUE_UPDATEABLE,
'N'                             VALUE_IS_BOOLEAN,
'DATE'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'Effective start date to collect Food Safety temperature should be given here'   SYS_CONFIG_HELP,
'NONE'                          VALIDATION_TYPE from DUAL
/


COMMIT;

