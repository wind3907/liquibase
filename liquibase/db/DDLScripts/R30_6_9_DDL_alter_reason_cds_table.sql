/****************************************************************************
** File: R30_6_9_DDL_alter_sts_route_in_table.sql
*
** Desc: Script makes changes to table sts_route_in related to POD enhancement
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    06/03/20     mch1213     added new columns SUPPRESS_IMM_CREDIT to table reason_cds
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('SUPPRESS_IMM_CREDIT')
        AND table_name = 'REASON_CDS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.REASON_CDS ADD ( SUPPRESS_IMM_CREDIT VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;


END;
/
