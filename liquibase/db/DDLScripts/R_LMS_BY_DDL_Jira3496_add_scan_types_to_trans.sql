/*********************************************************************
**
**  DDL script to:
**    Add new columns SCAN_TYPE1 and SCAN_TYPE2 to TRANS table.
**    SCAN_TYPE1 will not be used at this time. SCAN_TYPE2 is 
**    needed along with existing column SCAN_METHOD2 for BY 
**    (Blue Yonder) project.
**
**  Modification History:
**
**   Date         Author        Comment
**   ----------------------------------------------------------------
**   01-Sep-2021  pkab6563      created for Jira story 3496.
**
**********************************************************************/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'SCAN_TYPE1'
     AND  table_name  = 'TRANS';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.TRANS ADD SCAN_TYPE1 VARCHAR2(1 CHAR)';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'SCAN_TYPE2'
     AND  table_name  = 'TRANS';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.TRANS ADD SCAN_TYPE2 VARCHAR2(1 CHAR)';
   END IF;
END;
/

