/*********************************************************************
**
**  DDL script to:
**    Add new columns BY_GOAL_TIME , BY_SWMS_GOAL_TIME ,BY_FUTURE_GOAL_TIME ,BY_COMPLETE_UPD_TIME ,
**    BY_FUTURE_UPD_TIME to ARCH_BATCH table.
**    needed to maintain for BY goal-time
**    (Blue Yonder) project.
**
**  Modification History:
**
**   Date         Author            Comment
**   ----------------------------------------------------------------
**   21-Oct-2021  salakanavinda     created for Jira story 3712.
**
**********************************************************************/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'BY_COMPLETE_GOAL_TIME'
     AND  table_name  = 'ARCH_BATCH';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ARCH_BATCH ADD BY_COMPLETE_GOAL_TIME NUMBER(8,2) DEFAULT 0 NOT NULL';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'BY_SWMS_GOAL_TIME'
     AND  table_name  = 'ARCH_BATCH';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ARCH_BATCH ADD BY_SWMS_GOAL_TIME NUMBER(8,2) DEFAULT 0 NOT NULL';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'BY_FUTURE_GOAL_TIME'
     AND  table_name  = 'ARCH_BATCH';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ARCH_BATCH ADD BY_FUTURE_GOAL_TIME NUMBER(8,2) DEFAULT 0 NOT NULL';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'BY_COMPLETE_UPD_TIME'
     AND  table_name  = 'ARCH_BATCH';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ARCH_BATCH ADD BY_COMPLETE_UPD_TIME DATE';
   END IF;
END;
/

DECLARE
   v_column_exists PLS_INTEGER := 0;
BEGIN
   SELECT COUNT(*)
   INTO   v_column_exists
   FROM   user_tab_cols
   WHERE  column_name = 'BY_FUTURE_UPD_TIME'
     AND  table_name  = 'ARCH_BATCH';

   IF v_column_exists = 0 THEN
      EXECUTE IMMEDIATE 'ALTER TABLE ARCH_BATCH ADD BY_FUTURE_UPD_TIME DATE';
   END IF;
END;
/
