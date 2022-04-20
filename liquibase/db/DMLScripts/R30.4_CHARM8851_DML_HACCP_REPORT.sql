/****************************************************************************
** Date:       28-OCT-2015
** File:       Charm-6000008851_DML_UPD_HACCP_CODES.sql
**
**             Script to 
**             Udate haccp_codes for HACCP RECEIVED ITEMS REPORT
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    28-OCT-2015 AKLU6632 Init
**
****************************************************************************/

UPDATE haccp_codes
   SET report_type = 'RVHA'
 WHERE haccp_code IN
                ('HS00072', 'HS0075', 'HS0100', 'HS0101', 'HF0065', 'HF0066');

delete from GLOBAL_REPORT_DICT where REPORT_NAME = 'rp1rm';

INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',1, 'HACCP RECEIVED ITEMS REPORT', 28);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',2, '''Vendor ID''', 9);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',3, '''PO#''', 3);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',4, '''Load#''', 5);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',5, '''SN#''', 3);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',6, '''LINE''', 8);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',7, '''ITEM#''', 5);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',8, '''ITEM Description''', 16);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (3,'rp1rm',9, '''HACCP Code''', 10);

INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',1, 'HACCP Recu comme Article Eeauc?Eeauc', 28);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',2, '''Code Frs''', 9);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',3, '''BCs''', 3);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',4, '''N? Charge''', 5);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',5, '''NS''', 3);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',6, '''Lign''', 8);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',7, '''N? Article''', 5);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',8, '''Article Description''', 16);
INSERT INTO GLOBAL_REPORT_DICT(LANG_ID, REPORT_NAME, FLD_LBL_NAME,FLD_LBL_DESC,MAX_LEN)
VALUES (12,'rp1rm',9, '''HACCP Code''', 10);

delete from SWMS.PRINT_REPORTS where  REPORT = 'rp1rm';

Insert into SWMS.PRINT_REPORTS
   (REPORT, QUEUE_TYPE, DESCRIP, COMMAND, FIFO, COPIES, DUPLEX)
 Values
   ('rp1rm', 'SQLP', 'HACCP Received Item Report', 'runsqlrpt -c :c :p/:f :r', 'N', 1, 'N');


COMMIT;
