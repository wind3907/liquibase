/****************************************************************************
**
** Description:
**    Project: R47_0_Xdock_OPCOF-3878_Add_new_columns_to_order_purge_backup_script
**
**    The purge script is changing to add the new R1 columns added to the main table and
**    the backup table.
**
**    The below columns were found missing from the backup table.  Though not part
**    of R1 cross dock they well be added to the backup tables and the purge script
**    so the main table and backup tables match.
**
**    New columns:
**       ----------------------------
**       ORDD_BCKUP table
**       ----------------------------
**          original_seq               NUMBER(8)
**
**       ----------------------------
**       FLOATS_BCKUP table
**       ----------------------------
**          is_sleeve_selection        VARCHAR2(1 CHAR)
**
**
**       ----------------------------
**       SOS_BATCH_BCKUP table
**       ----------------------------
**          is_sleeve_selection        VARCHAR2(1 CHAR)
**
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
   execute_stmt_add_col('ALTER TABLE swms.ordd_bckup         ADD (original_seq             NUMBER(8))'           );
   execute_stmt_add_col('ALTER TABLE swms.floats_bckup       ADD (is_sleeve_selection      VARCHAR2(1  CHAR))'   );
   execute_stmt_add_col('ALTER TABLE swms.sos_batch_bckup    ADD (is_sleeve_selection      VARCHAR2(1  CHAR))'   );
END;
/



