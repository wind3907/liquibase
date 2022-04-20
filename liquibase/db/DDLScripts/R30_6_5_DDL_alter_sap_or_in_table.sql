/****************************************************************************
** File:       R30_6_5_DDL_alter_sap_or_in_table.sql
**
** Desc: Script creates  column,  to table SAP_OR_IN related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    8/14/18     mcha1213     error_msg columns added to table SAP_OR_IN        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/