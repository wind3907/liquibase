--CRQ #34708, Day Close-Item Recon

COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar ITEM_RECON_AFTER_DAY_CLS
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
'ORDER PROCESSING' APPLICATION_FUNC, 
'ITEM_RECON_AFTER_DAY_CLS'  CONFIG_FLAG_NAME,
'Closing the Day'  CONFIG_FLAG_DESC, 
'N'                             CONFIG_FLAG_VAL,
'Y'                             VALUE_REQUIRED, 
'N'                             VALUE_UPDATEABLE, 
'N'                             VALUE_IS_BOOLEAN, 
'CHAR'                          DATA_TYPE,
'1'                             DATA_PRECISION,
'R'                             SYS_CONFIG_LIST,
'For Closing the Day according to need'   SYS_CONFIG_HELP, 
'NONE'                          VALIDATION_TYPE from DUAL
/
