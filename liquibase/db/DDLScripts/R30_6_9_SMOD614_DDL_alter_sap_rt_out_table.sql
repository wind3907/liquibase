/****************************************************************************
** File: R30_6_9_SMOD614_DDL_alter_sap_rt_out_table.sql
*
** Desc: Script makes changes to table SAP_RT_OUT related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    10/10/19     igoo9289     added CUST_ID columns to table SAP_RT_OUT
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('CUST_ID')
        AND table_name = 'SAP_RT_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_RT_OUT ADD ( CUST_ID VARCHAR2(14 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('POD_RTN_IND')
        AND table_name = 'SAP_RT_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_RT_OUT ADD ( POD_RTN_IND VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

END;
/
