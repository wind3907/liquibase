/****************************************************************************
** File:       JIRA419_DDL_ALTER_ROUTE_INFO.sql
**
** Desc: Script creates 1 column,  to table ROUTE_INFO related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    -----------    --------     ------------------------------------------
**    June 14th 2018  vkal9662          1 columns added to table ROUTE_INFO            
****************************************************************************/

DECLARE
  v_column_exists NUMBER := 0;  
  BEGIN
  SELECT COUNT(*)
  INTO v_column_exists
  FROM user_tab_cols
  WHERE column_name = 'AUTO_GEN_FLAG'
        AND table_name = 'ROUTE_INFO';

  IF (v_column_exists = 0)
  THEN
    EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ROUTE_INFO ADD AUTO_GEN_FLAG VARCHAR2(3)';
  END IF;
 END;
/ 

