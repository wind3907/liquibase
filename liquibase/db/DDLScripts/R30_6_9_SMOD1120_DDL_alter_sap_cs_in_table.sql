/****************************************************************************
** File: R30_6_9_SMOD1120_DDL_alter_sap_cs_in_table.sql
*
** Desc: Script makes changes to table SAP_CS_IN related to Migrating
**  Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    05/11/19    nsel0716     Added CUST_PREF_VENDOR, CATCH_WT_TRK, LAST_SHIP_DATE,
**                                AVG_WEIGHT, ERROR_MSG columns to table SAP_CS_IN
**    03/08/20    igoo9289     Added MSG_SEQ_NO column to table SAP_CS_IN
**    06/02/20    nsel0716     Alter AVG_WEIGHT size
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('CUST_PREF_VENDOR')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( CUST_PREF_VENDOR VARCHAR2(10 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('CATCH_WT_TRK')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( CATCH_WT_TRK VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('LAST_SHIP_DATE')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( LAST_SHIP_DATE VARCHAR2(8 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('AVG_WEIGHT')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( AVG_WEIGHT VARCHAR2(8 CHAR))';
	  COMMIT;
  ELSE
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN MODIFY ( AVG_WEIGHT VARCHAR2(8 CHAR))';
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('ERROR_MSG')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( ERROR_MSG VARCHAR2(100 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MSG_SEQ_NO')
        AND table_name = 'SAP_CS_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.SAP_CS_IN ADD ( MSG_SEQ_NO NUMBER(10,0))';
	COMMIT;
  END IF;

END;
/
