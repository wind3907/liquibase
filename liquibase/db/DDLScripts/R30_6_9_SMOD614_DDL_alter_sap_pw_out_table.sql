/****************************************************************************
** File: R30_6_9_SMOD614_DDL_alter_sap_pw_out_table.sql
*
** Desc: Script makes changes to table SAP_PW_OUT related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    10/10/19     igoo9289     added REC_TYPE, WAREHOUSE_ID, RDC_NO, SHIPMENT_ID columns to table SAP_PW_OUT
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('REC_TYPE')
        AND table_name = 'SAP_PW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PW_OUT ADD ( REC_TYPE VARCHAR2(3 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('WAREHOUSE_ID')
        AND table_name = 'SAP_PW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PW_OUT ADD ( WAREHOUSE_ID VARCHAR2(3 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('RDC_NO')
        AND table_name = 'SAP_PW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PW_OUT ADD ( RDC_NO VARCHAR2(5 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('SHIPMENT_ID')
        AND table_name = 'SAP_PW_OUT';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PW_OUT ADD ( SHIPMENT_ID VARCHAR2(20 CHAR))';
	COMMIT;
  END IF;

END;
/
