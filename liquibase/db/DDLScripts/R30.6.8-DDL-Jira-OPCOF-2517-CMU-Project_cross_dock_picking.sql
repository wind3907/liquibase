
/****************************************************************************
**
** Description:
**    Project:
**        xxx
**    Add columns to table ORDD to save the original values when a CMU
**    order is being filled from both the RDC and the OpCo.
**    A new ORDD record is created for the qty to be filled from the OpCo.
**
**    ORDD record initially:
**                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
**    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
**    --------------------------------------------------------------------------------------------------------------------------
**    1234567   908200001     1        10       84320000   1234568888888     B           6
**
**    ORDD after the new ORDD record is created:
**                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
**    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
**    --------------------------------------------------------------------------------------------------------------------------
**    1234567   908200001     1        6        10000001   1234568888888     B           6           10
**    1234567   908200001     2        4        84320000                                                              1
**
**
**    Valid values for ORDD.REMOTE_LOCAL_FLG:
**       L - Qty to be filled at the OpCo.
**       R - Qty to be filled entirely from the RDC
**       B - Qty to be filled from the OpCo and from the RDC
**
**
**    Columns added:
**       qty_ordered_original  
**       original_order_line_id
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    08/22/19 bben0556 Brian Bent
**                      Project: R30.6.8-DDL-Jira-OPCOF-2517-CMU-Project_cross_dock_picking.sql
**                      Created.
30.6.8-DDL-Jira-OPCOF-2517-CMU-Project_cross_dock_picking.sql is a colums we
**                      added for the RDC.  We now need it for the CMU project.
**
**    10/08/19 bben0556 Brian Bent
**                      Project: R30.6.8-DDL-Jira-OPCOF-2517-CMU-Project_cross_dock_picking.sql
**                      Because we update the ORDD.SEQ to match the RDC SEQ lets
**                      save the original ORDD.SEQ.  Add column ORIGINAL_SEQ to ORDD table.
**                      It will be populated by "pl_cross_dock_order_processing.sql".
**
****************************************************************************/


--------------------------------------------------------------------------
-- Add columns to ORDD
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
   execute_stmt('ALTER TABLE swms.ordd ADD (qty_ordered_original          NUMBER(7))'       );
   execute_stmt('ALTER TABLE swms.ordd ADD (original_order_line_id        NUMBER(3))'       );
   execute_stmt('ALTER TABLE swms.ordd ADD (original_seq                  NUMBER(8))'       );
END;
/

