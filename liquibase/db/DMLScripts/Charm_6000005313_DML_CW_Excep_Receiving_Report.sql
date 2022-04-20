
--Changes for R_30_0 for printing the Catchweight Exception Receiving report automatically once a PO is closed--

--Sysconfig flag created to set a default printer which shall print the report every time.The  CONFIG_FLAG_VAL can be changed in case the default printer is down--
-- Get the max sequence number used in sys_config table.
COL maxseq_no NOPRINT NEW_VALUE maxseq;
SELECT MAX(seq_no) maxseq_no FROM sys_config;


Insert into SWMS.SYS_CONFIG
   (SEQ_NO, APPLICATION_FUNC, CONFIG_FLAG_NAME, CONFIG_FLAG_DESC, CONFIG_FLAG_VAL, VALUE_REQUIRED, VALUE_UPDATEABLE, VALUE_IS_BOOLEAN, DATA_TYPE, DATA_PRECISION, SYS_CONFIG_LIST, VALIDATION_TYPE)
 Values
   (&maxseq + 1 , 'RECEIVING', 'DFLT_PRNTR_PO_CLOSURE', 'Default Printer for PO Close', 'wrkl3', 
    'Y', 'Y', 'Y', 'CHAR', 6, 
    'N', 'LIST');

--Insertion of relevant sql command  in the print_reports table for printing the sql report--
Insert into SWMS.PRINT_REPORTS
   (REPORT, QUEUE_TYPE, DESCRIP, COMMAND, FIFO, COPIES, DUPLEX)
 Values
   ('rp4rb', 'SQLP', 'CW Exception Receiving Report', 'runsqlrpt -c :c :p/:f :r', 'N', 
    1, 'N');

COMMIT;
