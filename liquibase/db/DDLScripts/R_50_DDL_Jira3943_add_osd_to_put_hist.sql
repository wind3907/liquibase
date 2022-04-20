----------------------------------------------------------------------------
-- DDL to add column OSD_LR_REASON_CD to putawaylst_hist table
--
-- Modification history
--
--    Date           Author           Comment
--   ------------   ---------      -----------------------------------------
--   14-Jan-2022    pkab6563       Created - Jira 3943
----------------------------------------------------------------------------

DECLARE
   l_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO l_column_exists
   FROM user_tab_cols
   WHERE column_name = 'OSD_LR_REASON_CD'
     AND table_name  = 'PUTAWAYLST_HIST';

   IF l_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST_HIST ADD OSD_LR_REASON_CD VARCHAR2(3 CHAR)';
   END IF;
END;
/
