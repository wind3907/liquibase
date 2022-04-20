
COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create sypar for ITEM_LEVEL_WEIGHT_UNIT FOR charm No: 6000005313
********************************************************************/

/* Get the max sequence number used in sys_config table. */


SELECT MAX(seq_no) maxseq_no FROM sys_config;


INSERT INTO SYS_CONFIG(
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
	 SYS_CONFIG_LIST)
VALUES(
     &maxseq + 1,
	 'ORDER PROCESSING',
	 'AUTO_ROUTE_CLOSE_ENABLE',
	 'Enable Auto Route Close',
	 'Y',
	 'Y',
	 'N',
	 'Y',
	 'CHAR',
	 1,
	 'L');
	 
COMMIT;
