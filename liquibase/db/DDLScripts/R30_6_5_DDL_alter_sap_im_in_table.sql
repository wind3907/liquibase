/****************************************************************************
** File:       R30_6_5_DDL_alter_sap_im_in_table.sql
**
** Desc: Script creates  column,  to table SAP_PO_IN related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    8/14/18     mcha1213     error_msg columns added to table SAP_IM_IN        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'ERROR_MSG'
        AND table_name = 'SAP_IM_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_IM_IN ADD ERROR_MSG VARCHAR2(100 CHAR)';
  END IF;
 END;
/