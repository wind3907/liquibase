COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create syspar MINILAOD_AUTO_FLAG
********************************************************************/

/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config;

Insert into SWMS.SYS_CONFIG
   (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME, CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, 
    VALUE_REQUIRED, VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION, 
    SYS_CONFIG_LIST, VALIDATION_TYPE)
 Values
   (&maxseq + 1, 'RECEIVING MINILOAD', 'MINILOAD_AUTO_FLAG', 'Miniload Automatic Flag', 'Y', 
    'Y', 'N', 'Y', 'CHAR', 1, 
    'L', 'LIST');

COMMIT;