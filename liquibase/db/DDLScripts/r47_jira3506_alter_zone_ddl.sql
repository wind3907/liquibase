/****************************************************************************
** File:       r47_jira3394_alter_rtn_ddl.sql
**
** Desc: Script creates column,  to table RETURNS related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**   Jul8th 2021  vkal9662        xdock column added to table ZONE
**       
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  

  
  BEGIN
  
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'SITE_FROM'
        AND table_name = 'ZONE';

  IF (v_column_exists = 0)   THEN
 	
	   EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ZONE ADD SITE_FROM VARCHAR2(5)';
	 
	END IF;
  
  
  
 END;
/ 



