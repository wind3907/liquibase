COL maxseq_no NOPRINT NEW_VALUE maxseq;

/********************************************************************
**    Create syspar SELECTION_BATCH_COUNT
********************************************************************/

/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config;

INSERT INTO SWMS.SYS_CONFIG (SEQ_NO,
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
                             SYS_CONFIG_HELP)
		VALUES (&maxseq + 1,
				'LABOR MGMT',
				'SELECTION_BATCH_COUNT',
				'Limit Sel batch without goal',
				'1',
				'Y',
				'N',
				'N',
				'NUMBER',
				3,
				'R',
				'Set limit on the number of selection labour batches that can wait for goal time from FLEX');

				
/********************************************************************
**    Create syspar FORKLIFT_BATCH_COUNT
********************************************************************/

/* Get the max sequence number used in sys_config table. */
SELECT MAX(seq_no) maxseq_no FROM sys_config;

INSERT INTO SWMS.SYS_CONFIG (SEQ_NO,
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
                             SYS_CONFIG_HELP)
		VALUES (&maxseq + 1,
				'LABOR MGMT',
				'FORKLIFT_BATCH_COUNT',
				'Limit Fork batch without goal',
				'20',
				'Y',
				'N',
				'N',
				'NUMBER',
				3,
				'R',
				'Set limit on the number of forklift labour batches that can wait for goal time from FLEX');
				
COMMIT;
