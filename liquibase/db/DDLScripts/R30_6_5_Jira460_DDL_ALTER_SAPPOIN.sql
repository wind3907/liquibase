/****************************************************************************
** File:       JIRA460_DDL_ALTER_SAPPOIN.sql
**
** Desc: Script creates 3 column,  to table SAP_PO_IN related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    June4th 2018  vkal9662          3 columns added to table SAP_PO_IN    
**    Aug 15 2018   mcha1213          add vend_name, vend_addr, vend_citystatezip, error_msg       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'EXP_DATE'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD EXP_DATE VARCHAR2(8)';
  END IF;
 END;
/ 

DECLARE
  v_column_exists NUMBER := 0;
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'MFG_DATE'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD MFG_DATE   VARCHAR2(8)';
  END IF;
  
END;
/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PRD_WEIGHT'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD PRD_WEIGHT  VARCHAR2(9)';
  END IF;
END;
/  

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'VEND_NAME'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD VEND_NAME  VARCHAR2(25)';
  END IF;
END;
/  

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'VEND_ADDR'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD VEND_ADDR  VARCHAR2(25)';
  END IF;
END;
/ 

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'VEND_CITYSTATEZIP'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD VEND_CITYSTATEZIP  VARCHAR2(25)';
  END IF;
END;
/   

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD ERROR_MSG  VARCHAR2(100 CHAR)';
  END IF;
END;
/   


