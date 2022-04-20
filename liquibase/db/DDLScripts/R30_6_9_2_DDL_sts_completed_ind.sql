/****************************************************************************
** File: R30_6_9_1_Jira2873_alter_manifests.sql
*
** Desc: Script makes changes to table MANIFESTS and add new column
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    05/14/2020   knha8378	adding new column called sts_completed_ind
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('STS_COMPLETED_IND')
        AND table_name = 'MANIFESTS';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFESTS ADD (STS_COMPLETED_IND VARCHAR2(1 CHAR))';
	COMMIT;
  END IF;

END;
/
