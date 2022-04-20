/*********************************************************************
**
**  DDL script to: 
**    Add new column master_order_id to 4 tables:
**      - erd_lpn 
**      - erd
**      - putawaylst 
**      - inv
**    Add new column cmu_indicator to 1 table:
**      - erd_lpn   
** 
**  Modification History:
**  
**   Date       Author        Comment
**   ----------------------------------------------------------------
**   7/05/19    pkab6563      created
**
**********************************************************************/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'MASTER_ORDER_ID'
     AND table_name  = 'ERD_LPN';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD_LPN ADD MASTER_ORDER_ID VARCHAR2(25 CHAR)';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'MASTER_ORDER_ID'
     AND table_name  = 'ERD';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD ADD MASTER_ORDER_ID VARCHAR2(25 CHAR)';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'MASTER_ORDER_ID'
     AND table_name  = 'PUTAWAYLST';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST ADD MASTER_ORDER_ID VARCHAR2(25 CHAR)';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'MASTER_ORDER_ID'
     AND table_name  = 'INV';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV ADD MASTER_ORDER_ID VARCHAR2(25 CHAR)';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'CMU_INDICATOR'
     AND table_name  = 'ERD_LPN';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.ERD_LPN ADD CMU_INDICATOR VARCHAR2(1 CHAR)';
   END IF;
END;
/
