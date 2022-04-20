/****************************************************************************
** File:       JIRA460_DDL_ALTER ERD_table.sql
**
** Desc: Script creates 3 columns,  to table ERD related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    June4th2018  vkal9662          3 columns added to tables SWMS.ERD             
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PRD_WEIGHT'
        AND table_name = 'ERD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD ADD PRD_WEIGHT  NUMBER(9,3)';
  END IF;
END;
/  

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'EXP_DATE'
        AND table_name = 'ERD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD ADD EXP_DATE DATE';
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
        AND table_name = 'ERD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD ADD MFG_DATE   DATE';
  END IF;
  
END;
/




