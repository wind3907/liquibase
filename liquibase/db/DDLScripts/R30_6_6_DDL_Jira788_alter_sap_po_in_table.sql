/****************************************************************************
** File:       R30_6_5_DDL_jira788_alter_SAP_PO_IN_table.sql
*
** Desc: Script creates  column,  to table SAP_PO_IN related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/27/19     xzhe5043     added required column to table SAP_PO_IN        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('SORT_IND')
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD ( SORT_IND VARCHAR2(1))';
	COMMIT; 
  END IF;
  
 END;
/