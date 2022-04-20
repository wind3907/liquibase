/*********************************************************************
**
**  DDL script to add 3 columns to inv_hist table:
**    - qty_produced 
**    - sigma_qty_produced 
**    - ship_date
** 
**  Modification History:
**  
**   Date       Author        Comment
**   ----------------------------------------------------------------
**   7/15/19    pkab6563      created
**
**********************************************************************/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'QTY_PRODUCED'
     AND table_name  = 'INV_HIST';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV_HIST ADD QTY_PRODUCED NUMBER(7)';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'SIGMA_QTY_PRODUCED'
     AND table_name  = 'INV_HIST';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV_HIST ADD SIGMA_QTY_PRODUCED NUMBER';
   END IF;
END;
/

DECLARE
   v_column_exists NUMBER := 0;
BEGIN
   SELECT COUNT(*)
   INTO v_column_exists
   FROM user_tab_cols
   WHERE column_name = 'SHIP_DATE'
     AND table_name  = 'INV_HIST';

   IF (v_column_exists = 0) THEN
      EXECUTE IMMEDIATE 'ALTER TABLE SWMS.INV_HIST ADD SHIP_DATE DATE';
   END IF;
END;
/
