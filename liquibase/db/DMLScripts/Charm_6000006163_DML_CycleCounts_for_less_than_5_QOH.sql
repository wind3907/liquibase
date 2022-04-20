/* Charm 6000006163: Syspar created for setting pik slot qoh value to generate CC */

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/* *******************************************************************
**    Create sypar CC_PIK_SLOT_QOH
******************************************************************* */

/* Get the max sequence number used in sys_config table */
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
DATA_TYPE,
DATA_PRECISION,
DATA_SCALE,
SYS_CONFIG_LIST,
SYS_CONFIG_HELP,
LOV_QUERY,
VALIDATION_TYPE,
RANGE_LOW,
RANGE_HIGH,
DISABLED_FLAG) 
VALUES(&maxseq + 1,
'CYCLE COUNT',
'CC_PIK_SLOT_QOH',
'Generate CC for < pickslot QOH',
'5',
'N',
'Y',
'N',
'NUMBER',
'0',
'0', 
'Y',
'For setting pik slot qoh value for CC',
'', 
'NONE',
'0',
'99',
'')                
/
COMMIT
/






