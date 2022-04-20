/****************************************************************************
** File: "R30_6_9_3_DDL_alter_food_safety_outbound.sql"
*
** Desc: Script makes changes to table sts_route_in related to POD enhancement
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    09/30/2020  Kiet Nhan    Adding 2 more columns to food_safety_outbound
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('REASON_CD')
        AND table_name = 'FOOD_SAFETY_OUTBOUND';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.FOOD_SAFETY_OUTBOUND ADD ( REASON_CD VARCHAR2(3 CHAR))';
	COMMIT;
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('REASON_GROUP')
        AND table_name = 'FOOD_SAFETY_OUTBOUND';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.FOOD_SAFETY_OUTBOUND ADD ( REASON_GROUP VARCHAR2(3 CHAR))';
	COMMIT;
  END IF;

END;
/
