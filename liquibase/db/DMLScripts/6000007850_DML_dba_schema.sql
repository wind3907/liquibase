/****************************************************************************
** Date:       17-Aug-2015
** File:       Charm-6000007850_DML_dba_schema.sql
**
**             Script to 
**             1. insert record to SAP_INTERFACE_PURGE
**                for purge data older than 10 days in table ORDCW_HIST.
**             2. Insert print_reports for new report catch weight scan report.
**             3. Insert table global_report_dict for report columns
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    17-Aug-15 AKLU6632 Charm#6000007850
**                       Project: Catch weight Frequency Scan VS Keying Project
**
****************************************************************************/

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date) 
VALUES ('ORDCW_HIST', 10, 'Hist table for ORDCW', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SWMS.PRINT_REPORTS(REPORT, QUEUE_TYPE, DESCRIP, COMMAND, FIFO, COPIES, DUPLEX)
VALUES ('ob1ri', 'SQLP', 'Catch Weight Scan Report', 'runsqlrpt -c :c :p/:f :r', 'N', 1, 'N');

INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',1, 'Catch Weight frequency of Scan and Keying report', 61);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',2, '''Selector ID''', 12);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',3, '''Total CWT''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',4, '''Scan CWT''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',5, '''Key CWT''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'ob1ri',6, '''CRT CWT''', 7);

INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',1, 'Catch fréquence de poids de numérisation et le rapport Keying', 61);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',2, '''ID Selecteur''', 12);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',3, '''Totale PdP''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',4, '''Balayage PdP''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',5, '''Clé PdP''', 7);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'ob1ri',6, '''CRT PdP''', 7);

COMMIT;