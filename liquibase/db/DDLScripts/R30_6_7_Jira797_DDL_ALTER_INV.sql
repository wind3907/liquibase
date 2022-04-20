/****************************************************************************
** File:       R30_6_7_Jira797_DDL_ALTER_INV.sql
**
** Desc: Script creates column,  to table INV related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    June4th 2018  vkal9662          one column  SIGMA_PRDC_QTY added to table INV    
**       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'SIGMA_QTY_PRODUCED'
        AND table_name = 'INV';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD SIGMA_QTY_PRODUCED NUMBER';
  END IF;
 END;
/ 



