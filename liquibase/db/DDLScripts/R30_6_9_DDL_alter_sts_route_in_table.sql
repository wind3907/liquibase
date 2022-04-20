/****************************************************************************
** File: R30_6_9_DDL_alter_sts_route_in_table.sql
*
** Desc: Script makes changes to table sts_route_in related to POD enhancement
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    01/31/20     mch1213     added new columns to table sts_route_in
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('STOP_CORRECTION')
        AND table_name = 'STS_ROUTE_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.STS_ROUTE_IN ADD ( STOP_CORRECTION VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('MULTI_PICK_IND')
        AND table_name = 'STS_ROUTE_IN';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.STS_ROUTE_IN ADD ( MULTI_PICK_IND VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

END;
/
