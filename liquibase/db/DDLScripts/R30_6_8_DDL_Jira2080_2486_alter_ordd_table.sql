/****************************************************************************
** File:       JIRA2080_2486_DDL_ALTER_OR_tables.sql
**
** Desc: Script add columns to table ORDD, SAP_OR_IN for RDC cross-docking
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    May28,2019  xzhe5043     MASTER_ORDER_ID, REMOTE_LOCAL_FLG, REMOTE_QTY added to table SWMS.ORDD
**	  Aug16,2019  sban3548	   Add RDC_PO_NO to ORDD and 4 columns to SAP_OR_IN table	
**
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
   WHERE column_name IN ( 'MASTER_ORDER_ID','REMOTE_LOCAL_FLG','REMOTE_QTY', 'RDC_PO_NO')
     AND table_name = 'ORDD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ORDD 
	ADD ( MASTER_ORDER_ID  VARCHAR2(25),
	      REMOTE_LOCAL_FLG VARCHAR2(1),
		  REMOTE_QTY       NUMBER(7,0),
		  RDC_PO_NO 	   VARCHAR2(16)
		)';
  END IF;
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
    INTO v_column_exists
    FROM user_tab_cols
   WHERE column_name IN ( 'MASTER_ORDER_ID','REMOTE_LOCAL_FLG','REMOTE_QTY', 'RDC_PO_NO')
     AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN  
	ADD ( MASTER_ORDER_ID  VARCHAR2(25),
	      REMOTE_LOCAL_FLG VARCHAR2(1),
		  REMOTE_QTY       NUMBER(7,0),
		  RDC_PO_NO 	   VARCHAR2(16)
		)';
  END IF;
END;
/
