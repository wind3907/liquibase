/****************************************************************************************
** Desc: Script to Add LAST_FG_PO column to tables ERM, SAP_PO_IN for SUS/PRIME Project
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    12/07/2018    sban3548    Jira-640: added column LAST_FG_PO to ERM,SAP_PO_IN tables   
**
*****************************************************************************************/

DECLARE
  v_column_count NUMBER := 0;  
BEGIN
  SELECT COUNT(*)
  INTO v_column_count
  FROM all_tab_cols
  WHERE column_name = 'LAST_FG_PO'
        AND table_name = 'ERM';

  IF (v_column_count = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERM ADD LAST_FG_PO VARCHAR2(1 CHAR)';
  END IF;
END;
/

/****************************************************************************
 Jira 640: Add new column LAST_FG_PO in ERM table
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'LAST_FG_PO'
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD LAST_FG_PO VARCHAR2(1 CHAR)';
  END IF;
 END;
/ 

