CREATE OR REPLACE PACKAGE swms.pl_ml_cleanup
AS
-- sccs_id=%Z% %W% %G% %I%
-----------------------------------------------------------------------------
-- Package Name:
--   
--
-- Description:
--    This package is used to cleanup miniload replenishment tasks.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    08/22/07 prpbcb   DN: 12275
--                      Ticket: 443793
--                      Project: 443793-Miniload Replenishment Cleanup
--                      Created.
--
--    03/20/10 prpbcb   DN: 12571
--                      Project: CRQ15757-Miniload In Reserve Fixes
--
--                      Modified procedure cleanup_replenishments()
--                      to handle the new ML replenishment priorities.
--                      Modified to look at columns delete_at_start_of_day
--                      and retention_days in table PRIORITY_CODE.  These
--                      control if and when to cleanup the replenishments.
--                      Before anything older than 1 day was deleted.
--                      Following is a description of these columns:
--       - delete_at_start_of_day VARCHAR2(1) -- Delete the replenishments?
--                                               Valid values are Y, N or null.
--                                               If N or null then the
--                                               replenishments will not get
--                                               deleted.
--       - retention_days         NUMBER      -- How many days to keep the
--                                               replenishments before deleting
--                                               when delete_at_start_of_day is
--                                               Y.  A fraction of a day can be
--                                               entered so 1.5 is valid.
--
-----------------------------------------------------------------------------

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    cleanup_ndm_replenishments
--
-- Description:
--    This procedure cleans-up the miniloader non-demand replenishments which
--    consists of backing them out.
---------------------------------------------------------------------------
PROCEDURE cleanup_ndm_replenishments(i_effective_date IN DATE,
                                     i_priority       IN PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    cleanup_dmd_replenishments
--
-- Description:
--    This procedure cleans-up the miniloader demand replenishments which
--    consists of deleting them from the replenishment table.
---------------------------------------------------------------------------
PROCEDURE cleanup_dmd_replenishments(i_effective_date IN DATE,
                                     i_priority       IN PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    cleanup_replenishments
--
-- Description:
--    This procedure cleans-up the miniloader non-demand and demand
--    replenishments.
---------------------------------------------------------------------------
PROCEDURE cleanup_replenishments(i_effective_date IN DATE DEFAULT NULL);



END pl_ml_cleanup;
/

show errors

CREATE OR REPLACE PACKAGE BODY swms.pl_ml_cleanup
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_ml_cleanup';   -- Package name.
                                                 -- Used in error messages.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

   -- Application function for the log messages.
   ct_application_function   CONSTANT VARCHAR2 (9)  := 'INVENTORY';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------
   --
   -- This cursor selects the replenishment task information required
   -- to cleanup the replenishment.
   --
   -- The replenishment qty is in splits if the uom = 0 otherwise it is in
   -- cases.
   --
   CURSOR gl_c_replenishment(cp_priority        replenlst.priority%TYPE,
                             cp_effective_date  DATE) IS
      SELECT r.task_id,
             r.prod_id,
             r.cust_pref_vendor,
             r.uom,
             r.qty,
             r.type,
             r.status,
             r.src_loc,
             r.dest_loc,
             r.pallet_id,
             r.orig_pallet_id,
             r.parent_pallet_id,
             r.priority,
             r.op_acquire_flag,
             r.add_date,
             r.add_user,
             DECODE(r.uom, 1, r.qty, r.qty * pm.spc) qty_in_splits
        FROM pm,
             replenlst r
       WHERE r.type               =  'MNL'
         AND r.priority           =  cp_priority 
         AND r.add_date           <= cp_effective_date
         AND pm.prod_id           =  r.prod_id
         AND pm.cust_pref_vendor  =  r.cust_pref_vendor
       ORDER BY r.prod_id, r.cust_pref_vendor, r.add_date, r.task_id;


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

-------------------------------------------------------------------------
-- Procedure:
--    cleanup_ndm_replenishments
--
-- Description:
--    This procedure cleans-up the miniloader non-demand (NDM) replenishments
--    which consists of backing them out.  These will have
--    replenlst.priority = 20.
--    
--   There will be different situations for the cleanup.  The one common thing
--   will be the replenishment record with priority = 20.  We will not worry
--   about the repl status.
--   The cleanup will be to undo the repl.  The situations to handle are:
--    1.  Inv has the qty alloc record and the qty planned record.
--        The qty planned inv record (destination record) will be at the
--        induction location.
--    2.  The repl status = PIK, there are no inv records.
--    3.  There is no inv qty alloc record.
--    4.  There is no destination inv record.
--  
--
--
-- Parameters:
--    i_effective_date  - Cleanup the NDM repl that were created up through
--                        this date.
--
-- Called By:
--
-- Exceptions Raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    xx/xx/xx          Created
--    04/28/10          Modified to look at the op_acquire_flag and if it
--                      is Y to leave inventory alone.
---------------------------------------------------------------------------
PROCEDURE cleanup_ndm_replenishments(i_effective_date IN DATE,
                                     i_priority       IN PLS_INTEGER)
IS
   l_object_name  VARCHAR2(30) := 'cleanup_ndm_replenishments';


   l_continue_processing_bln BOOLEAN;  -- Flag if to continue processing the
                               -- cleanup of a replenishment or stop because
                               -- of some error or data value mismatch.
                               -- 08/22/07 Brian Bent  As of this time this
                               -- will always be TRUE.

   l_ndm_priority  PLS_INTEGER;

   --
   -- This cursor is used to select the inventory record at the
   -- replenishment source location and the replenishment destination
   -- location.
   --
   CURSOR c_inv(cp_logi_loc          inv.logi_loc%TYPE,
                cp_prod_id           inv.prod_id%TYPE,
                cp_cust_pref_vendor  inv.cust_pref_vendor%TYPE) IS
      SELECT i.prod_id,
             i.cust_pref_vendor,
             i.logi_loc,
             i.plogi_loc,
             i.qoh,
             i.qty_planned,
             i.qty_alloc,
             i.add_date
        FROM inv i
       WHERE i.logi_loc          = cp_logi_loc
         AND i.prod_id           = cp_prod_id
         AND i.cust_pref_vendor  = cp_cust_pref_vendor;

   r_inv        c_inv%ROWTYPE;
   r_dummy_inv  c_inv%ROWTYPE := NULL;

   ------------------------------------------------------------------------
   -- Local Procedure:
   --    write_log_message
   --
   -- Description:
   --    This procedure writes a swms log message.  It is used for
   --    most of the log messages since they are all pretty much the same
   --    except for the initial text.
   --
   -- Parameters:
   --    i_message_type      - Type of message. INFO, FATAL, etc.
   --    i_object_name       - Object creating the message.
   --    i_message           - Text to put at the beginning of message.
   --    i_r_repl            - Replenishment information.
   --    i_r_inv             - Inventory information.
   --
   -- Exceptions raised:
   --    None.  An error will be written to swms log.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ------------------------------------------------
   --    08/22/07 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE write_log_message
               (i_message_type         IN VARCHAR2,  
                i_object_name          IN VARCHAR2,
                i_message              IN VARCHAR2,
                i_r_repl               IN gl_c_replenishment%ROWTYPE,
                i_r_inv                IN c_inv%ROWTYPE)
   IS
   BEGIN
      pl_log.ins_msg(i_message_type, i_object_name,
               i_message
               || '  Repl Task ID[' || TO_CHAR(i_r_repl.task_id) || ']'
               || '  Repl LP[' || i_r_repl.pallet_id || ']'
               || '  Repl Original LP[' || i_r_repl.orig_pallet_id || ']'
               || '  Repl Item[' || i_r_repl.prod_id || ']'
               || '  Repl CPV[' || i_r_repl.cust_pref_vendor || ']'
               || '  Repl Src Loc[' || i_r_repl.src_loc || ']'
               || '  Repl Dest Loc[' || i_r_repl.dest_loc || ']'
               || '  Repl UOM[' || TO_CHAR(i_r_repl.uom) || ']'
               || '  Repl Qty[' || TO_CHAR(i_r_repl.qty) || ']'
               || '  Repl Qty(in splits)['
               || TO_CHAR(i_r_repl.qty_in_splits) || ']'
               || '  Repl Status[' || i_r_repl.status || ']'
               || '  Repl Priority[' || TO_CHAR(i_r_repl.priority) || ']'
               || '  Repl OP Acquire Flag[' || i_r_repl.op_acquire_flag || ']'
               || '  Inv Item[' || i_r_inv.prod_id || ']'
               || '  Inv CPV[' || i_r_inv.cust_pref_vendor || ']'
               || '  Inv Loc[' || i_r_inv.plogi_loc || ']'
               || '  Initial Inv QOH[' || TO_CHAR(i_r_inv.qoh) || ']'
        || '  Initial Inv Qty Planned[' || TO_CHAR(i_r_inv.qty_planned) || ']'
        || '  Initial Inv Qty Alloc[' || TO_CHAR(i_r_inv.qty_alloc) || ']'
               || '  Inv Add Date['
               || TO_CHAR(i_r_inv.add_date, 'DD-MON-YYYY HH24:MI:SS') || ']',
               NULL, NULL,
               'INVENTORY', gl_pkg_name );
   EXCEPTION
     WHEN OTHERS THEN
        pl_log.ins_msg ('WARN', 'write_log_message',
                  'WHEN OTHERS EXCEPTION.  THIS WILL NOT STOP PROCESSING.',
                  SQLCODE, SQLERRM,
                  'INVENTORY', gl_pkg_name );
          
   END write_log_message;  -- end local procedure

BEGIN
   l_ndm_priority  := i_priority;
   -- 
   -- Make sure a date was given.
   -- 
   IF (i_effective_date IS NOT NULL) THEN
      FOR r_repl IN gl_c_replenishment(l_ndm_priority, i_effective_date) LOOP
         l_continue_processing_bln := TRUE;

         DBMS_OUTPUT.PUT_LINE
              ('  Repl Task ID[' || TO_CHAR(r_repl.task_id) || ']'
               || '  Repl Priority[' || TO_CHAR(r_repl.priority) || ']'
               || '  Repl Add Date[' || TO_CHAR(r_repl.add_date, 'MM/DD/YYYY HH24:MI:SS') || ']'
               || '  Repl LP[' || r_repl.pallet_id || ']'
               || '  Repl Original LP[' || r_repl.orig_pallet_id || ']'
               || '  Repl Item[' || r_repl.prod_id || ']'
               || '  Repl CPV[' || r_repl.cust_pref_vendor || ']'
               || '  Repl Src Loc[' || r_repl.src_loc || ']'
               || '  Repl Dest Loc[' || r_repl.dest_loc || ']'
               || '  Repl UOM[' || TO_CHAR(r_repl.uom) || ']'
               || '  Repl Qty[' || TO_CHAR(r_repl.qty) || ']'
               || '  Repl OP Acquire Flag[' || r_repl.op_acquire_flag || ']');

         --
         -- Delete the destination inventory record but only if the
         -- op_acquire_flag is not Y.
         --
         -- It has been observed that this inventory record did not always
         -- exist when cleaning up replenishments manually.  If it does not
         -- exist an aplog message is written and the cleanup processing
         -- will continue.
         --
         r_inv := NULL;

         IF (NVL(r_repl.op_acquire_flag, 'N') <> 'Y') THEN
            OPEN c_inv(r_repl.pallet_id, r_repl.prod_id, r_repl.cust_pref_vendor);
            FETCH c_inv INTO r_inv;
            IF (c_inv%FOUND) THEN
               --
               -- The replenishment destination inventory record exists based
               -- on selecting by the LP and item.
               -- Delete it if the item and qty matches the replenishment record.
               --
               CLOSE c_inv;

               IF (    r_inv.qoh = 0
                   AND r_inv.qty_planned = r_repl.qty_in_splits
                   AND r_inv.plogi_loc = r_repl.dest_loc) THEN

                  DELETE FROM inv i
                   WHERE i.logi_loc         = r_repl.pallet_id
                     AND i.prod_id          = r_repl.prod_id
                     AND i.cust_pref_vendor = r_repl.cust_pref_vendor
                     AND i.plogi_loc        = r_repl.dest_loc;

                  IF (SQL%FOUND) THEN
                     --
                     -- Replenishment destination inventory record
                     -- deleted successfully.
                     --
                     write_log_message('INFO', l_object_name,
                             'MINILOADER NON-DEMAND REPL CLEANUP.'
                             || ' DESTINATION INV DELETED.', r_repl, r_inv);
                  ELSE
                     --
                     -- Did not find LP to delete.
                     -- Ideally should never reach this point because the
                     -- inventory record was just selected.  This will not
                     -- stop processing.
                     --
                     write_log_message('INFO', l_object_name,
                             'MINILOADER NON-DEMAND REPL CLEANUP.'
                             || ' DESTINATION INV LP WAS JUST SELECTED BUT'
                             || ' NOW IT IS NOT FOUND TO DELETE.'
                             || ' REPL CLEANUP PROCESSING WILL CONTINUE.',
                             r_repl, r_inv);
                  END IF;
               ELSE
                  --
                  -- One or more values in the destination inventory record
                  -- do not match the replenishment record.  Write an aplog
                  -- message and skip cleaning up this replenishment.
                  --
                  write_log_message('WARNING', l_object_name,
                          'MINILOADER NON-DEMAND REPL CLEANUP.'
                          || ' ONE OR MORE REPL RECORD VALUES AND DESTINATION'
                          || ' INV VALUES DO NOT MATCH THEREFORE THE'
                          || ' DESTINATION INVENTORY WILL NOT BE DELETED.'
                          || '  REPL CLEANUP PROCESSING WILL CONTINUE.',
                          r_repl, r_inv);

                  l_continue_processing_bln := TRUE;
               END IF;

            ELSE
               --
               -- The destination inventory record does not exist.
               -- Write an aplog message and keep processing.
               -- Ideally this should not happend but if it does
               -- it is not considered a fatal error.
               --
               CLOSE c_inv;

               write_log_message('INFO', l_object_name,
                          'MINILOADER NON-DEMAND REPL CLEANUP.'
                          || ' DESTINATION INV LP NOT FOUND'
                          || ' TO DELETE.  THIS IS NOT AN ERROR.  REPL'
                          || ' CLEANUP PROCESSING WILL CONTINUE.',
                          r_repl, r_inv);
            END IF;
         END IF;  -- end IF (NVL(r_repl.op_acquire_flag, 'N') <> 'Y')


         IF (l_continue_processing_bln = TRUE) THEN
            --
            -- Cleanup the source inventory but only if op_acquire_flag is
            -- not 'Y'.
            --
            -- The cleanup of the destination inventory was successful.
            -- Cleanup the source inventory which will consist of
            -- substracting the repl qty from the inv qty planned.  If the
            -- inv qty planned will go negative then it will be set to 0.
            --
            -- It has been observed that this inventory record did not always
            -- exist when cleaning up replenishments manually.  If it does not
            -- exist an aplog message is written and the cleanup processing
            -- will continue.
            --
            r_inv := NULL;

            IF (NVL(r_repl.op_acquire_flag, 'N') <> 'Y') THEN

               OPEN c_inv(r_repl.orig_pallet_id, r_repl.prod_id,
                          r_repl.cust_pref_vendor);
               FETCH c_inv INTO r_inv;

               IF (c_inv%FOUND) THEN
                  --
                  -- The replenishment source inventory record exists based
                  -- on selecting by the LP.
                  -- Update the qty alloc if the item matches the replenishment
                  -- record.
                  --
                  CLOSE c_inv;

                  IF (r_inv.plogi_loc = r_repl.src_loc) THEN
                     --
                     -- The inventory and replenishment records match.
                     -- Update the inventory qty alloc.  Do not let the qty alloc
                     -- go negative.
                     --
                     UPDATE inv i
                        SET i.qty_alloc =
                           DECODE(SIGN(i.qty_alloc - r_repl.qty_in_splits), -1, 0,
                                       i.qty_alloc - r_repl.qty_in_splits)
                      WHERE i.prod_id          = r_repl.prod_id
                        AND i.cust_pref_vendor = r_repl.cust_pref_vendor
                        AND i.logi_loc         = r_repl.orig_pallet_id
                        AND i.plogi_loc        = r_repl.src_loc;

                     IF (SQL%FOUND) THEN
                        --
                        -- Replenishment source inventory record updated
                        -- successfully.
                        --
                        write_log_message('INFO', l_object_name,
                             'MINILOADER NON-DEMAND REPL CLEANUP.'
                             || ' SOURCE INV RECORD UPDATED.',
                             r_repl, r_inv);
                     ELSE
                        --
                        -- Did not find source inventory LP to update.
                        -- Ideally should never reach this point because the
                        -- inventory record was just selected.  This will not
                        -- stop processing.
                        --
                        write_log_message('INFO', l_object_name,
                             'MINILOADER NON-DEMAND REPL CLEANUP.'
                             || '  SOURCE INV LP WAS JUST SELECTED BUT'
                             || ' NOW IT IS NOT FOUND TO UPDATE.'
                             || '  REPL CLEANUP PROCESSING WILL CONTINUE.',
                             r_repl, r_inv);
                     END IF;
                  ELSE
                     --
                     -- One or more values in the destination inventory record
                     -- do not match the replenishment record.  Write an aplog
                     -- message and continue processing.
                     --
                     write_log_message('WARNING', l_object_name,
                             'MINILOADER NON-DEMAND REPL CLEANUP.'
                             || ' ONE OR MORE REPL RECORD VALUES AND SOURCE'
                             || ' INV VALUES DO NOT MATCH.  THE'
                             || ' SOURCE INV RECORD WILL NOT BE UPDATED.'
                             || '  REPL CLEANUP PROCESSING WILL CONTINUE.',
                              r_repl, r_inv);
                  END IF;
               ELSE
                  --
                  -- The destination inventory record does not exist.
                  -- Write an aplog message and keep processing.
                  -- Ideally this should not happend but if it does
                  -- it is not considered a fatal error.
                  --
                  CLOSE c_inv;

                  write_log_message('INFO', l_object_name,
                          'MINILOADER NON-DEMAND REPL CLEANUP.'
                          || ' SOURCE INV LP NOT FOUND'
                          || ' TO UPDATE.  THIS IS NOT AN ERROR.  REPL'
                          || ' CLEANUP PROCESSING WILL CONTINUE.',
                          r_repl, r_inv);

               END IF;  -- end IF (c_inv%FOUND) THEN
            END IF;  -- end IF (NVL(r_repl.op_acquire_flag, 'N') <> 'Y')

            --
            -- Delete the replenishment task.
            --
            DELETE FROM replenlst r
             WHERE r.task_id = r_repl.task_id;

            IF (SQL%FOUND) THEN
               --
               -- Replenishment task deleted successfully.
               --
               write_log_message('INFO', l_object_name,
                          'MINILOADER NON-DEMAND REPL CLEANUP.'
                          || '  REPL TASK DELETED.',
                          r_repl, r_dummy_inv);
            ELSE
               --
               -- Did not find the replenishmment task to delete.
               -- Ideally should never reach this point because the
               -- record was just selected.  This will not stop processing.
               --
               write_log_message('INFO', l_object_name,
                          'MINILOADER NON-DEMAND REPL CLEANUP.'
                          || '  REPLENLST RECORD WAS JUST SELECTED BUT'
                          || ' NOW IT IS NOT FOUND TO DELETE.'
                          || '  REPL CLEANUP PROCESSING WILL CONTINUE.',
                          r_repl, r_dummy_inv);
            END IF;
         END IF;  -- end IF (l_continue_processing_bln = TRUE) THEN
      END LOOP;
   
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg ('WARN', l_object_name,
                  'Error occurred in cleanup.',
                  SQLCODE, SQLERRM,
                  'INVENTORY', gl_pkg_name );
      RAISE;
END cleanup_ndm_replenishments;


-------------------------------------------------------------------------
-- Procedure:
--    cleanup_dmd_replenishments
--
-- Description:
--    This procedure cleans-up the miniloader demand (DMD) replenishments
--    which consists of deleting them.
--    These will have replenlst.priority = 15.
--
-- Parameters:
--    i_effective_date  - Cleanup the DMD repl that were created up through
--                        this date.
--
-- Called By:
--
-- Exceptions Raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    xx/xx/xx          Created
---------------------------------------------------------------------------
PROCEDURE cleanup_dmd_replenishments(i_effective_date IN DATE,
                                     i_priority       IN PLS_INTEGER)
IS
   l_object_name  VARCHAR2(30) := 'cleanup_dmd_replenishments';

   l_dmd_priority  PLS_INTEGER;

   ------------------------------------------------------------------------
   -- Local Procedure:
   --    write_log_message
   --
   -- Description:
   --    This procedure writes a swms log message.  It is used for
   --    most of the log messages since they are all pretty much the same
   --    except for the initial text.
   --
   -- Parameters:
   --    i_message_type      - Type of message. INFO, FATAL, etc.
   --    i_object_name       - Object creating the message.
   --    i_message           - Text to put at the beginning of message.
   --    i_r_repl            - Replenishment information.
   --
   -- Exceptions raised:
   --    None.  An error will be written to swms log.
   --
   -- Called by:
   --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ------------------------------------------------
   --    08/22/07 prpbcb   Created.
   ------------------------------------------------------------------------
   PROCEDURE write_log_message
               (i_message_type         IN VARCHAR2,  
                i_object_name          IN VARCHAR2,
                i_message              IN VARCHAR2,
                i_r_repl               IN gl_c_replenishment%ROWTYPE)
   IS
   BEGIN
      pl_log.ins_msg(i_message_type, i_object_name,
               i_message
               || '  Repl Task ID[' || TO_CHAR(i_r_repl.task_id) || ']'
               || '  Repl LP[' || i_r_repl.pallet_id || ']'
               || '  Repl Original LP[' || i_r_repl.orig_pallet_id || ']'
               || '  Repl Item[' || i_r_repl.prod_id || ']'
               || '  Repl CPV[' || i_r_repl.cust_pref_vendor || ']'
               || '  Repl Src Loc[' || i_r_repl.src_loc || ']'
               || '  Repl Dest Loc[' || i_r_repl.dest_loc || ']'
               || '  Repl UOM[' || TO_CHAR(i_r_repl.uom) || ']'
               || '  Repl Qty[' || TO_CHAR(i_r_repl.qty) || ']'
               || '  Repl Qty(in splits)['
               || '  Repl Priority[' || TO_CHAR(i_r_repl.priority) || ']'
               || '  Repl OP Acquire Flag[' || i_r_repl.op_acquire_flag || ']'
               || TO_CHAR(i_r_repl.qty_in_splits) || ']'
               || '  Repl Status[' || i_r_repl.status || ']',
               NULL, NULL,
               'INVENTORY', gl_pkg_name );
   EXCEPTION
     WHEN OTHERS THEN
        pl_log.ins_msg ('WARN', 'write_log_message',
                  'WHEN OTHERS EXCEPTION.  THIS WILL NOT STOP PROCESSING.',
                  SQLCODE, SQLERRM,
                  'INVENTORY', gl_pkg_name );
          
   END write_log_message;  -- end local procedure
BEGIN
   l_dmd_priority := i_priority;

   IF (i_effective_date IS NOT NULL) THEN
      FOR r_repl IN gl_c_replenishment(l_dmd_priority, i_effective_date) LOOP

         DBMS_OUTPUT.PUT_LINE(
               '  Repl Task ID[' || TO_CHAR(r_repl.task_id) || ']'
               || '  Repl Priority[' || TO_CHAR(r_repl.priority) || ']'
               || '  Repl Add Date[' || TO_CHAR(r_repl.add_date, 'MM/DD/YYYY HH24:MI:SS') || ']'
               || '  Repl LP[' || r_repl.pallet_id || ']'
               || '  Repl Original LP[' || r_repl.orig_pallet_id || ']'
               || '  Repl Item[' || r_repl.prod_id || ']'
               || '  Repl CPV[' || r_repl.cust_pref_vendor || ']'
               || '  Repl Src Loc[' || r_repl.src_loc || ']'
               || '  Repl Dest Loc[' || r_repl.dest_loc || ']'
               || '  Repl UOM[' || TO_CHAR(r_repl.uom) || ']'
               || '  Repl Qty[' || TO_CHAR(r_repl.qty) || ']');


         --
         -- Delete the replenishment task.
         --
         DELETE FROM replenlst r
          WHERE r.task_id = r_repl.task_id;

         IF (SQL%FOUND) THEN
            --
            -- Replenishment task deleted successfully.
            --
            write_log_message('INFO', l_object_name,
                          'MINILOADER DEMAND REPL CLEANUP.'
                          || '  REPL TASK DELETED.',
                          r_repl);
         ELSE
            --
            -- Did not find the replenishmment task to delete.
            -- Ideally should never reach this point because the
            -- record was just selected.  This will not stop processing.
            --
            write_log_message('INFO', l_object_name,
                          'MINILOADER DEMAND REPL CLEANUP.'
                          || '  REPLENLST RECORD WAS JUST SELECTED BUT'
                          || ' NOW IT IS NOT FOUND TO DELETE.'
                          || '  REPL CLEANUP PROCESSING WILL CONTINUE.',
                          r_repl);
         END IF;
      END LOOP;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg ('WARN', l_object_name,
                  'Error occurred in cleanup.',
                  SQLCODE, SQLERRM,
                  'INVENTORY', gl_pkg_name );
   RAISE;

END cleanup_dmd_replenishments;



-------------------------------------------------------------------------
-- Procedure:
--    cleanup_replenishments
--
-- Description:
--    This procedure cleans up the miniloader non-demand (NDM) and
--    demand (DMD) replenishments.  What gets cleaned up depends on if
--    i_effective_date has a value.
--
--    If i_effective_date is not null then replenishments created through
--    i_effective_date are cleaned up.
--    If i_effective_date is null or not given then replenishments are
--    cleaned up based on the values of  DELETE_AT_START_OF_DAY and
--    RETENTION_DAYS in table PRIORITY_CODE.
--
--    This procedure when called with no parameter is intended to be run
--    as part of the miniload picking complete processing.
--
--    **********************************************************
--    ***** Priority 45 replenishments are not cleaned up. *****
--    **********************************************************
--
-- Parameters:
--    i_effective_date  - Cleanup the NDM and DMD replenishments that were
--                        created up through this date.  If this is null
--                        or not provided then table PRIORITY_CODE is used
--                        to determine what gets cleaned up.
--
-- Called By:
--    - pl_miniiload_processing.p_send_pending_pickcomp_msg (4/27/2010)
--
-- Exceptions Raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/07 prpbcb   Created
--    04/27/10 prpbcb   Modified to look at the PRIORITY_CODE table
--                      if i_effective_date is null or not provided.
---------------------------------------------------------------------------
PROCEDURE cleanup_replenishments(i_effective_date IN DATE DEFAULT NULL)
IS

   l_buf   VARCHAR2(140);  -- Work area.

   --
   -- This cursor selects the replenishment priority and the date to cleanup
   -- through.
   --
   CURSOR c_ml_repl_cleanup IS
      -- This select is when i_effective_date is null so
      -- delete_at_start_of_day and retention_days will be used.
      -- The retention_days defaults to 10.
      SELECT priority_value                     priority_value,
             delete_at_start_of_day             delete_at_start_of_day,
             NVL(retention_days, 10)            retention_days,
             SYSDATE - NVL(retention_days, 10)  cleanup_date
        FROM priority_code
       WHERE delete_at_start_of_day = 'Y'
         AND NVL(retention_days, 10) >= 0
         AND i_effective_date IS NULL
       UNION
       -- This select is when i_effective_date has a value.
      SELECT priority_value    priority_value,
             'Y'               delete_at_start_of_day,-- Don't care about this.
             0                 retention_days,        -- Don't care about this
             i_effective_date  cleanup_date
       FROM priority_code
       WHERE delete_at_start_of_day = 'Y'
         AND retention_days >= 0
         AND i_effective_date IS NOT NULL
       ORDER BY 1;
BEGIN
   --
   -- Build a message for logging.
   --
   IF (i_effective_date IS NULL) THEN
      l_buf := 'CLEANUP MINILOAD REPLENISHMENTS BASED ON THE CURRENT DATE AND'
               || ' THE SETTINGS OF DELETE_AT_START_OF_DAY AND RETENTION_DAYS'
               || ' FOR THE PRIORITY.';
   ELSE
      l_buf := 'CLEANUP MINILOAD REPLENISHMENTS CREATED ON OR BEFORE'
               || TO_CHAR(i_effective_date, 'MM/DD/YYYY HH24:MI:SS')
               || '(I_EFFECTIVE_DATE)';
   END IF;

   pl_log.ins_msg('INFO', 'cleanup_replenishments',
          l_buf, NULL, NULL,
          ct_application_function, gl_pkg_name);

   FOR r_ml_repl_cleanup IN c_ml_repl_cleanup LOOP
      --
      -- Write a log message to track what is happening.
      --
      pl_log.ins_msg('INFO', 'cleanup_replenishments',
          'Processing priority '
          || TO_CHAR(r_ml_repl_cleanup.priority_value)
          || ', CLEANUP DATE '
          || TO_CHAR(r_ml_repl_cleanup.cleanup_date, 'MM/DD/YYYY HH24:MI:SS'),
          NULL, NULL,
          ct_application_function, gl_pkg_name);

      IF (r_ml_repl_cleanup.priority_value IN (18, 20, 48, 50)) THEN
         cleanup_ndm_replenishments(r_ml_repl_cleanup.cleanup_date,
                                    r_ml_repl_cleanup.priority_value);
      ELSIF (r_ml_repl_cleanup.priority_value IN (12, 15)) THEN
         cleanup_dmd_replenishments(r_ml_repl_cleanup.cleanup_date,
                                    r_ml_repl_cleanup.priority_value);
      ELSE
         -- 
         -- Unhandled priority code.  Write a log message and keep going.
         -- 
         pl_log.ins_msg ('WARN', 'cleanup_replenishments',
                  'Unhandled replenlist priority['
                  || TO_CHAR(r_ml_repl_cleanup.priority_value) || '].'
                  || '  This will not stop processing.',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name );
       END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg ('WARN', 'cleanup_replenishments',
                  'Error occurred in cleanup.',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name );
   RAISE;
END cleanup_replenishments;


END pl_ml_cleanup;
/

show errors

