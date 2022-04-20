
/****************************************************************************
**
** Description:
**    Project:
**        RDC-CMU
**    Add new columns added to ORDD tables needs to be added the ORDD_BCKUP table
**
**    Columns added:
**			product_out_qty
**       qty_ordered_original  
**       original_order_line_id
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    10/09/19 sban3548 Jira-OPCOF-2602- Include CMU columns to backup tables
**
****************************************************************************/

--------------------------------------------------------------------------
-- Add columns to ORDD_BCKUP
--------------------------------------------------------------------------

DECLARE
   PROCEDURE execute_stmt(i_stmt IN VARCHAR2)
   IS
      e_column_already_exists  EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_column_already_exists, -1430);
   BEGIN
      EXECUTE IMMEDIATE(i_stmt);
   EXCEPTION
      WHEN e_column_already_exists THEN NULL;
      WHEN OTHERS THEN RAISE;
   END execute_stmt;

BEGIN
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (product_out_qty   NUMBER )');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (master_order_id	VARCHAR2(25))');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (remote_local_flg  VARCHAR2(1))');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (remote_qty  		NUMBER(7))');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (rdc_po_no  		VARCHAR2(16))');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (qty_ordered_original    NUMBER(7))');
   execute_stmt('ALTER TABLE swms.ordd_bckup ADD (original_order_line_id  NUMBER(3))');
   
   execute_stmt('ALTER TABLE swms.ordcw_bckup ADD (pkg_short_used         VARCHAR(1))');

   execute_stmt('ALTER TABLE swms.sos_batch_bckup ADD  (sym05_add_date          DATE)');
   execute_stmt('ALTER TABLE swms.sos_batch_bckup ADD  (sym05_sequence_number   NUMBER(10))');
END;
/

