/****************************************************************************
** File: R30_6_9_SMOD614_DDL_alter_sap_or_in_table.sql
*
** Desc: Script makes changes to table SAP_OR_IN related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    10/10/19     igoo9289     added DOD_CONTRACT_NO, DOD_ITEM_BC, DOD_FIC, CMT column to table SAP_OR_IN
**    03/08/20     igoo9289     added MSG_SEQ_NO column to table SAP_OR_IN
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('DOD_CONTRACT_NO')
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ( DOD_CONTRACT_NO VARCHAR2(13 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('DOD_ITEM_BC')
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ( DOD_ITEM_BC VARCHAR2(13 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('DOD_FIC')
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ( DOD_FIC VARCHAR2(3 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('CMT')
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ( CMT VARCHAR2(75 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MSG_SEQ_NO')
        AND table_name = 'SAP_OR_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_OR_IN ADD ( MSG_SEQ_NO NUMBER(10,0))';
	COMMIT;
  END IF;

END;
/
