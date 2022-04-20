/****************************************************************************
** File:       JIRA438_DDL_ALTER_INV_table.sql
**
** Desc: Script creates 2 columns,  to table INV/INV_HIST related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ---------   --------     ------------------------------------------
**    20-JUN-18   mpha8134     2 columns added to tables SWMS.INV and SWMS.INV_HIST             
****************************************************************************/
DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'INV_CUST_ID'
        AND table_name = 'INV';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD INV_CUST_ID VARCHAR2(10)';
  END IF;
END;
/  

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'INV_ORDER_ID'
        AND table_name = 'INV';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD INV_ORDER_ID VARCHAR2(14)';
  END IF;
END;
/



DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'INV_CUST_ID'
        AND table_name = 'INV_HIST';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV_HIST ADD INV_CUST_ID VARCHAR2(10)';
  END IF;
END;
/  

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'INV_ORDER_ID'
        AND table_name = 'INV_HIST';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV_HIST ADD INV_ORDER_ID VARCHAR2(14)';
  END IF;
END;
/

