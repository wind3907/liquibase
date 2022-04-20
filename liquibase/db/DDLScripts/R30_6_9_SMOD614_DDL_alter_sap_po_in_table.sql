/****************************************************************************
** File: R30_6_9_SMOD614_DDL_alter_sap_po_in_table.sql
*
** Desc: Script makes changes to table SAP_PO_IN related to Migrating Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    10/10/19     igoo9289     added SYS_ORDER_ID column to table SAP_PO_IN
**    10/10/19     igoo9289     modified SCHED_TIME column size to 8 CHAR in table SAP_PO_IN
**    03/03/20     igoo9289     added MSG_SEQ_NO column to table SAP_PO_IN
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('SYS_ORDER_ID')
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD ( SYS_ORDER_ID VARCHAR2(10 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MSG_SEQ_NO')
        AND table_name = 'SAP_PO_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_PO_IN ADD ( MSG_SEQ_NO NUMBER(10,0))';
	COMMIT;
  END IF;

END;
/

ALTER TABLE SWMS.SAP_PO_IN MODIFY SCHED_TIME VARCHAR2(8 CHAR);
