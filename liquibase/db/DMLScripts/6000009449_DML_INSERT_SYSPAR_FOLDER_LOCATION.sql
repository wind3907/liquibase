COL maxseq_no NOPRINT NEW_VALUE maxseq;

/**********************************************************************************
** Create syspar for MOD_MNT_DIR_LOC (Folder location)FOR charm No: 6000009449
***********************************************************************************/

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
	 SYS_CONFIG_LIST,
	 SYS_CONFIG_HELP,
	 LOV_QUERY,
	 VALIDATION_TYPE,
	 RANGE_LOW,
	 RANGE_HIGH,
	 DISABLED_FLAG)
VALUES(
     &maxseq + 1,
	 'GENERAL', 
	 'MOD_MNT_DIR_LOC',
	 'Module Maintainence Dir Loc',
	 '/tmp', 
     'Y',
	 'Y',
	 'Y',
	 'CHAR', 
	 20, 
     'N',
	 'This syspar is to define the path of the DML file to be generated',
	 NULL, 
	 'NONE',
	 NULL, 
     NULL,
	 NULL);
	 
COMMIT;
