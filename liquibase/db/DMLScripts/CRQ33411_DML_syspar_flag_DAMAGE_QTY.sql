--CRQ #33411, created for keeping track of damage quantity

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar DAMAGE_QTY
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
'CYCLE COUNT' APPLICATION_FUNC, 
'DAMAGE_QTY'  CONFIG_FLAG_NAME,
'Damage qty'  CONFIG_FLAG_DESC, 
'DMG'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'N'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'For keeping track of damage qty'   SYS_CONFIG_HELP, 
'NONE'                          VALIDATION_TYPE from DUAL
/
