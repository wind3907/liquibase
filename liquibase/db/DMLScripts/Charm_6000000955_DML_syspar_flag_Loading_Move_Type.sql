--Charm 6000000955: Syspar created for setting up default loading move typ

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar LOADING_MOVE_TYPE
********************************************************************/
-- Get the max sequence number used in sys_config table.
SELECT MAX(seq_no) maxseq_no FROM sys_config
/

INSERT INTO SWMS.SYS_CONFIG
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
'LOADING MOVE TYPE' APPLICATION_FUNC,
'LOADING_MOVE_TYPE'  CONFIG_FLAG_NAME,
'Default SLS/Loading Move Type' CONFIG_FLAG_DESC,
'C'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED,
'Y'                             VALUE_UPDATEABLE,
'N'                             VALUE_IS_BOOLEAN,
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'For setting up the default loading move type'   SYS_CONFIG_HELP,
'NONE'                          VALIDATION_TYPE from DUAL
/

INSERT INTO SYS_CONFIG_VALID_VALUES
   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
VALUES
   ('LOADING_MOVE_TYPE', 'C', 'Case Move Type')
/

INSERT INTO SYS_CONFIG_VALID_VALUES
   (CONFIG_FLAG_NAME, CONFIG_FLAG_VAL, DESCRIPTION)
VALUES
   ('LOADING_MOVE_TYPE', 'S', 'Stop Move Type')
/

