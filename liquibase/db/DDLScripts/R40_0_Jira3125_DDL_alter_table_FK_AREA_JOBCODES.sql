/*********************************************************************
**
**  DDL script to: 
**    Add new column rtn to tables: FK_AREA_JOBCODES

**  Modification History:
**  
**   Date       Author        Comment
**   ----------------------------------------------------------------
**  08/11/20    xzhe5043      created
**
**********************************************************************/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'RTN_JOBCODE'
     AND table_name  = 'FK_AREA_JOBCODES';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.FK_AREA_JOBCODES ADD RTN_JOBCODE VARCHAR2(6 CHAR)';
   END IF;
END;
/
