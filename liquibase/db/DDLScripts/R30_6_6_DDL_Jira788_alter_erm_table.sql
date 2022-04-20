/****************************************************************************
** File:       R30_6_5_DDL_jira788_alter_erm_table.sql
*
** Desc: Script creates  column,  to table ERM related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    03/27/19     xzhe5043     added required column to table ERM        
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name  in ('SORT_IND')
        AND table_name = 'ERM';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERM ADD ( SORT_IND VARCHAR2(1))';
	COMMIT;
  END IF;
  
 END;
/