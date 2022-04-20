/****************************************************************************
** File:       r47_jira3394_alter_rtn_ddl.sql
**
** Desc: Script creates column,  to table RETURNS related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    May24th 2021  vkal9662          one xdock column added to table RETURNS
**       
****************************************************************************/

DECLARE
  v_column_exists1 NUMBER := 0;    
  v_column_exists2 NUMBER := 0;  
  v_column_exists3 NUMBER := 0;  
  v_column_exists4 NUMBER := 0;  
  v_column_exists5 NUMBER := 0;  
  v_column_exists6 NUMBER := 0;  
  
  
  BEGIN
  
  SELECT COUNT(*)
  INTO v_column_exists1
  FROM user_tab_cols
  WHERE column_name = 'XDOCK_IND'
        AND table_name = 'RETURNS';

  IF (v_column_exists1 = 0)   THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD XDOCK_IND VARCHAR2(2)';
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists2
  FROM user_tab_cols
  WHERE column_name = 'SITE_FROM'
        AND table_name = 'RETURNS';  
	
  IF (v_column_exists2 = 0)   THEN	
	EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD SITE_FROM VARCHAR2(5)';
   END IF;

  SELECT COUNT(*)
  INTO v_column_exists3
  FROM user_tab_cols
  WHERE column_name = 'SITE_TO'
        AND table_name = 'RETURNS';  
	
  IF (v_column_exists3 = 0)   THEN	 
	EXECUTE IMMEDIATE 'ALTER TABLE SWMS.RETURNS ADD SITE_TO VARCHAR2(5)';
  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists4
  FROM user_tab_cols
  WHERE column_name = 'XDOCK_IND'
        AND table_name = 'MANIFEST_DTLS';

  IF (v_column_exists4 = 0)  THEN
  
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_DTLS ADD XDOCK_IND VARCHAR2(2)';
  END IF;

  SELECT COUNT(*)
  INTO v_column_exists5
  FROM user_tab_cols
  WHERE column_name = 'SITE_FROM'
        AND table_name = 'MANIFEST_DTLS';

  IF (v_column_exists5 = 0)  THEN 
	EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_DTLS ADD SITE_FROM VARCHAR2(5)';
  END IF;
  
  SELECT COUNT(*)
  INTO v_column_exists6
  FROM user_tab_cols
  WHERE column_name = 'SITE_TO'
        AND table_name = 'MANIFEST_DTLS';

  IF (v_column_exists6 = 0)  THEN
	 
	EXECUTE IMMEDIATE 'ALTER TABLE SWMS.MANIFEST_DTLS ADD SITE_TO VARCHAR2(5)';
	
  END IF;
  
 END;
/ 



