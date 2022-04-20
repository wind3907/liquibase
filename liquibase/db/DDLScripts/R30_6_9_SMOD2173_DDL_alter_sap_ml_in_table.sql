/****************************************************************************
** File: R30_6_9_SMOD2173_DDL_alter_sap_ml_in_table.sql
*
** Desc: Script makes changes to table SAP_ML_IN related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/08/20     igoo9289     added MSG_SEQ_NO column to table SAP_ML_IN
**    03/24/20     igoo9289     added MSG_ID column to table SAP_ML_IN
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MSG_ID')
        AND table_name = 'SAP_ML_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_ML_IN ADD ( MSG_ID VARCHAR2(36 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MSG_SEQ_NO')
        AND table_name = 'SAP_ML_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_ML_IN ADD ( MSG_SEQ_NO NUMBER(10,0))';
	COMMIT;
  END IF;

END;
/
