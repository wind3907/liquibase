----------------------------------------------------------------------------
-- DDL to add column ADD_DATE to putawaylst_hist table
--
-- Modification history
--
--    Date           Author           Comment
--   ------------   ---------      -----------------------------------------
--   03-Feb-2022    pkab6563       Created - Jira 3867
----------------------------------------------------------------------------

DECLARE
   l_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO l_column_exists
   FROM user_tab_cols
   WHERE column_name = 'ADD_DATE'
     AND table_name  = 'PUTAWAYLST_HIST';

   IF l_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST_HIST ADD ADD_DATE DATE';
   END IF;

EXCEPTION
    WHEN OTHERS THEN
        pl_log.ins_msg('WARN', 'OPCOF3867_DDL_add_add_date_to_put_hist', 
                       'Deployment DDL to add ADD_DATE to PUTAWAYLST_HIST failed', 
                       SQLCODE, SQLERRM);
        RAISE;
END;
/
