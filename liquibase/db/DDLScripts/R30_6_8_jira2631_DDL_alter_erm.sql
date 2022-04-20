/****************************************************************************
** File:       R30_6_8_jira2631_DDL_alter_erm
**
** Desc: Script creates column,  to table ERM related to CMU to detect need process
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    10/24/2019     knha8378	  process CMU SN Yes or No
**       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'CMU_PROCESS_COMPLETE'
        AND table_name = 'ERM';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERM ADD CMU_PROCESS_COMPLETE VARCHAR2(1)';
  END IF;
 END;
/ 



