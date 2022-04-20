/****************************************************************************
**
** Description:
**    Project: R52-Omni
**
**    The goal is to use this script when adding columns to existing tables for omni project
**
**    Creating new tables will be in the DDL script for the card.
**
**
**    New columns:
**       ----------------------------
**       SEL_EQUIP table
**       ----------------------------
**          is_mobile_rack VARCHAR2(1)
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    04/20/21 PDAS8114 Created.
**
****************************************************************************/

DECLARE
   --
   -- Local procedure to add a column to a table.
   --
   PROCEDURE execute_stmt_add_col(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt_add_col;

BEGIN
   --
   -- Add columns to tables.
   --
   execute_stmt_add_col('ALTER TABLE swms.sel_equip  ADD (is_mobile_rack VARCHAR2(1 CHAR))' );

   execute_stmt_add_col('ALTER TABLE swms.ordd ADD (ipo_no VARCHAR2(12 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.ordd ADD (ipo_line_id NUMBER(3))');
   execute_stmt_add_col('ALTER TABLE swms.ordd ADD (end_cust_id VARCHAR2(10 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.ordd ADD (end_cust_name VARCHAR2(30 CHAR))');

   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (ipo_no VARCHAR2(12 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (ipo_line_id NUMBER(3))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (end_cust_id VARCHAR2(10 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (end_cust_name VARCHAR2(30 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (rack_float_zone VARCHAR2(4 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (rack_location VARCHAR2(10 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (pallet_id VARCHAR2(18 CHAR))');
   execute_stmt_add_col('ALTER TABLE swms.float_detail ADD (parent_pallet_id VARCHAR2(18 CHAR))');

   execute_stmt_add_col('ALTER TABLE swms.floats ADD (rack_id VARCHAR2(10 CHAR))');
END;
/



