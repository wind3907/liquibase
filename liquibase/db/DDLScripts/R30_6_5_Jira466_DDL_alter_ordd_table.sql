/****************************************************************************
** File:       JIRA466_DDL_ALTER_ORDD_table.sql
**
** Desc: Script creates a column PRODUCT_OUT_QTY,  to table ORDD to hold 
**       product out quantity
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    May24th2018  vkal9662          PRODUCT_OUT_QTY added to tables 
**                                  SWMS.ORDD              
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'PRODUCT_OUT_QTY'
        AND table_name = 'ORDD';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ORDD ADD PRODUCT_OUT_QTY NUMBER NULL';
  END IF;
END;
/




