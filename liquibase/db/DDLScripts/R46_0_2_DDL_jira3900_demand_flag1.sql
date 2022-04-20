/***********************************************************************
**
**  Modification History:
**  
**   Date         Author        Comment
**   -------------------------------------------------------------------
**   13-Dec-2021  pkab6563      Created - Jira 3900 - Drop demand_flag1
**                              from putawaylst and putawaylst_hist.
**
************************************************************************/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'DEMAND_FLAG1'
     AND table_name  = 'PUTAWAYLST';

   IF (v_column_exists != 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST DROP COLUMN DEMAND_FLAG1';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'DEMAND_FLAG1'
     AND table_name  = 'PUTAWAYLST_HIST';

   IF (v_column_exists != 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST_HIST DROP COLUMN DEMAND_FLAG1';
   END IF;
END;
/
