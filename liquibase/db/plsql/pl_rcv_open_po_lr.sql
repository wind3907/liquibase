
SET DOC OFF

--------------------------------------------------------------------------
-- Package Specification
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE swms.pl_rcv_open_po_lr
AS


---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_lr
--
-- Description:
--    Live Receiving
--    This package has the objects for live receiving processing.
--
--    General process flow when Live Receiving is active:
--    1. Open PO. A putawaylst record is created for each LP.
--       The dest_loc will be 'LR'. No inventory created at this time.
--       No LP's are printed.
--       The 'LR' is defined in this constant definition in
--       pl_rcv_open_po_types.sql:
--       ct_lr_dest_loc  CONSTANT VARCHAR2(2) := 'LR';
--
--    2. The receiver checks in the pallets on the RF which now consists
--       of finding the putaway slot for the putawaylst record which will
--       update the putawaylst.dest_loc, create the inventory and send the
--       dest_loc to the RF. The LP is then printed on a belt printer.
--       The other pl_rcv_open_po* are modified to handle live receiving.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/06/16 prpbcb   Brian Bent
--                      Project:
--               R30.6--WIE#669--CRQ000000008118_Live_receiving_story_15_cron_open_PO
--
--                      Created for Live Receiving.
--
--                      Changed to use the pallet list record qty received
--                      instead of the qty.
--                      We want to use the actual qty on the pallet.
--                      This comes into play when checking-in a live
--                      receiving pallet on the RF.  Otherwise the pallet list
--                      record qty and qty_received are the same.
--
--    09/06/16 prpbcb   Brian Bent
--                      Project:
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_33_find_dest_loc
--
--                      Add procedure:
--                      - find_putaway_location
--
--    10/06/16 prpbcb   Brian Bent
--                      Project: 
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
--
--                      Change to set o_status to
--                      "pl_swms_error_codes.sel_putawaylst_fail" instead of
--                      "pl_swms_error_codes.data_error" if the select from
--                      PUTAWAYLST fails.
--
--    01/06/17 bben0556 Bent Bent
--                      Project:
--    R30.6--WIE#669--CRQ000000008118_Live_receiving_story_235_find_put_dest_loc_when_worksheet_printed
--
--                      Added other overloaded procedure "find_putaway_location"
--                      which takes erm_id and status as parameters.
--
--
--    02/06/17 bben0556 Brian Bent
--      R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
--
--                      With Live Receiving, if 2 putaway or receiving
--                      associates are requesting a put location at the same
--                      time, or someone is requesting a location at the same
--                      time the receiver is asking for one we want to
--                      process the requests sequentially.
--
--                      Changed procedure "build_pallet_list_from_tasks()"
--                      to first attempt to lock the putawaylst record when
--                      processing the record(s) selected by cursor
--                      "c_putawaylst".
--                      This procedure is used in the processing of finding
--                      the destination location for the putawaylst tasks.
--                      Basically if we cannot initially lock the putawaylst
--                      task we skip that that task so the dest_loc will main
--                      at 'LR' or '*'.
--                      This logic should be acceptable, I believe.
--                      What we do not want to do is wait for a lock on the
--                      putawaylst table to be released as the task could be
--                      locked in the screen for an extended period of time.
--
--                      Created procedure "lock_putawaylst_record()"
--
--    07/20/17 bben0556 Brian Bent
--                      Project: 
--         30_6_Story_2030_Direct_miniload_items_to_induction_location_when_PO_opened
--
--                      Live Receiving change.
--                      Always set the putawaylst.dest_loc to the miniloader
--                      induction location and create inventory for pallets
--                      directed to the miniloader when the PO is opened
--                      regardless if Live Receiving is active.
--                      We don't want the pallets to "LR". 
--                      We need to do this because for the miniloader
--                      the expected receipts are sent to the
--                      miniloader when the PO is opened and syspar
--                      MINILOAD_AUTO_FLAG is set to Y.  If we use the
--                      "LR" logic then the creating of the expected receipts
--                      will fail because "LR" is not a valid location.
--                      Also since we know what pallets are going to the miniloader
--                      why use the "LR" logic.
--
--                      Modified "pl_rcv_open_po_types.sql"
--                         Added field "direct_to_ml_induction_loc_bln" to the pallet RECORD.
--                         The build pallet processing in "pl_rcv_open_po_list.sql"
--                         changed to set this to TRUE when the pallet is going to the miniloader
--                         induction location.
--
--                      Modified "pl_rcv_open_po_list.sql"
--                         Changed procedure "build_pallet_list_from_po" to
--                         populate "direct_to_ml_induction_loc_bln" in the
--                         pallet RECORD.
--
--                      Modified "pl_rcv_open_po_lr.sql"
--                         Changed procedure "create_putaway_task" adding
--                         parameter pl_rcv_open_po_types.t_r_item_info_table
--                         and calling "pl_rcv_open_po_ml.direct_ml_plts_to_induct_loc"
--
--                      Modified "pl_rcv_open_po_find_slot.sql"
--                         Changed call to pl_rcv_open_po_lr.create_putaway_task
--                         from
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (l_r_item_info_table,
--                                  l_r_pallet_table);
--                         to
--                            pl_rcv_open_po_lr.create_putaway_task
--                                 (i_r_syspars         => l_r_syspars,
--                                  i_r_item_info_table => l_r_item_info_table,
--                                  io_r_pallet_table   => l_r_pallet_table);
--
--                      Modified "pl_rcv_open_po_ml.sql"
--                         Created procedure "direct_ml_plts_to_induct_loc"
--                         It is called by procedure
--                         "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                         send the pallets to the miniloader induction location.
--                         The pallets to send have been flagged in package
--                         package "pl_rcv_open_po_pallet_list.sql" when
--                         building the pallet list
--
--    01/25/18 mpha8134 Jira card OPCOF-289: Always set putawaylst.dest_loc to the matrix 
--                      induction location and create inventory pallets
--                      directed to the miniloader when the PO is opened
--                      regardless if Live Receiving is active. We don't
--                      want the pallets to "LR".
--                      
--                      Modified "pl_rcv_open_po_types.sql"
--                        Added field "direct_to_mx_induction_loc_bln" to the pallet RECORD.
--                        The build pallet processing in "pl_rcv_open_po_pallet_list.sql"
--                        chagned to set this to TRUE when the pallet is going to the
--                        matrix induction location.
--
--                      Modified "pl_rcv_open_po_list.sql"
--                        Changed procedure "build_pallet_list_from_po" to
--                        populate "direct_to_mx_induction_loc_bln" in the
--                        pallet RECORD.
--
--                      Modified "pl_rcv_open_po_lr.sql"
--                        Changed procedure "create_putaway_task to call
--                        "pl_rcv_open_po_ml.direct_mx_plts_to_induct_loc"
--
--                      Modified "pl_rcv_open_po_matrix.sql"
--                         Created procedure "direct_mx_plts_to_induct_loc"
--                         It is called by procedure
--                         "pl_rcv_open_po_lr.sql.create_putaway_task" to
--                         send the pallets to the matrix induction location.
--                         The pallets to send have been flagged in package
--                         package "pl_rcv_open_po_pallet_list.sql" when
--                         building the pallet list.
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    get_number_of_lps_to_print (Public)
--
-- Description:
--    Live Receiving
--    This function determines the number of LP's to print for the
--    live receiving pallet when checked-in on the RF.
--
--    For a pallet directed to a reserve pallet flow slot we want to print
--    2 LP's.  For any other slot we want to print 1 LP.
---------------------------------------------------------------------------
FUNCTION get_number_of_lps_to_print
             (i_pallet_id               IN  putawaylst.pallet_id%TYPE)
RETURN PLS_INTEGER;


---------------------------------------------------------------------------
-- Procedure:
--    create_putaway_task
--
-- Description:
--    This procedure creates the PUTAWAYLST record setting the dest_loc 
--    to 'LR'.
---------------------------------------------------------------------------
PROCEDURE create_putaway_task
     (i_r_syspars          IN            pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info_table  IN            pl_rcv_open_po_types.t_r_item_info_table,
      io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_tasks
--
-- Description:
--    Live Receiving
--    This procedure builds the list of pallets to putaway for existing
--    Live Receiving putawaylst tasks for a PO or LP that does not yet
--    have the dest loc determined.
--
--    When the Live Receiving syspar is active and a PO is opened only
--    the putaway tasks are created with the dest loc set to 'LR'.
--    No inventory is created.
--    During RF check-in of a LP the dest loc is determined and the inventory
--    is created for the pallet.  This procedure is one of the procedures
--    used in the process.
--
--    Also the user will have the option on the CRT to have the system
--    find the dest loc for the pallet for a specified LP or PO.
--
--    *************************************************************
--    ***** Remember the PUTAWAYLST record already exists     *****
--    ***** and when a dest loc is found inventory is created *****
--    ***** if the pallet is directed to a reserve slot       *****
--    ***** and if the pallet is directed to a home slot      *****
--    ***** inventory is updatad.  Also the pallet can '*'    *****
--    *************************************************************
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_tasks
      (i_r_syspars          IN         pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN         erm.erm_id%TYPE,
       i_pallet_id          IN         putawaylst.pallet_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table);


---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--    Live Receiving
--    This procedure determines the putaway location for a specified LP
--    or PO.
--
--    This is the procedure that does all the work.  The other overloaded
--    "find_putaway_location" procedures call this procedure.
--
--    The inventory is created when a valid slot is found for the putaway task.
--    Note that the putaway task could be assigned a '*' for the location if
--    no location is found.
--    
--    The main use of this procedure is to find the slot for the pallet
--    during live receiving check-in on the RF.  When the the Live Receiving
--    PO was first opened the PUTAWYLST.DEST_LOC was set to 'LR'.  During
--    the receiving check-in process on the RF we find the location for the
--    pallet updating 'LR' to the location (which could be a '*') and create
--    the inventory.
--    
--    If the putawaylst record already has a valid location then that pallet
--    is left alone.
--    If the putawaylst record has '*' for the location then an attempt is
--    made to find the putaway location so this procedure can be called for
--    a pallet which currenly has a '*' putaway location.  Note the location
--    could '*' again.
--
--    The PO needs to be in open status and have a putawaylst record.
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_erm_id                  IN  erm.erm_id%TYPE,
              i_pallet_id               IN  putawaylst.pallet_id%TYPE DEFAULT NULL,
              o_dest_loc                OUT putawaylst.dest_loc%TYPE,
              o_number_of_lps_to_print  OUT PLS_INTEGER,
              o_status                  OUT PLS_INTEGER);


---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--   The live receiving RF check-in processing needs to call this procedure
--   to find the slot for the LP.
--
--   This procedure calls the "main" find_putaway_location procedure which
--   does the work.
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_pallet_id               IN  putawaylst.pallet_id%TYPE,
              o_dest_loc                OUT putawaylst.dest_loc%TYPE,
              o_number_of_lps_to_print  OUT PLS_INTEGER,
              o_status                  OUT PLS_INTEGER);

---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--    Live Receiving
--    This procedure determines the putaway location for a specified PO
--    for the putawaylst records with dest_loc = 'LR' or '*'.
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_erm_id     IN  erm.erm_id%TYPE,
              o_status     OUT PLS_INTEGER);


END pl_rcv_open_po_lr;  -- end package specification
/

SHOW ERRORS



--------------------------------------------------------------------------
-- Package Body
--------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY swms.pl_rcv_open_po_lr
AS


---------------------------------------------------------------------------
-- Package Name:
--    pl_rcv_open_po_lr
--
-- Description:
--    This package is for live receiving processing.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/06/16 prpbcb   Brian Bent
--                      Project:
--               R30.6--WIE#669--CRQ000000008118_Live_receiving_story_15_cron_open_PO
--
--                      Created.
--                      
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
                                              -- Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or
                                 -- function is null.


---------------------------------------------------------------------------
-- Private Constants
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

e_record_locked  EXCEPTION;
PRAGMA EXCEPTION_INIT(e_record_locked, -54);


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Proceudre:
--    lock_putawaylst_record (Private)
--
-- Description:
--    This procedure locks the PUTAWAYLST record for a specified pallet
--    and gets the PUTAWAYLST.DEST_LOC
--
-- Parameters:
--    i_pallet_id  - Pallet to lock in PUTAWAYLST table.
--    o_locked_bln - TRUE   The record was locked successfully.
--                   FALSE  Record could ot be locked.
--    o_dest_loc   - The putawaylst.dest_loc   Defined only when
--                   o_locked_bln is TRUE.
--
-- Return Values:
--    TRUE  - Putawaylst record locked successfully.
--    FALSE - Putawaylst record not locked successfully.
--
-- Called by:
--    is_ok_to_process_putaway_task
--
-- Exceptions raised:
--    None.  If an exception occurrs then it is logged and FALSE returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/07/17 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE lock_putawaylst_record
             (i_pallet_id    IN putawaylst.pallet_id%TYPE,
              o_locked_bln   OUT BOOLEAN,
              o_dest_loc     OUT putawaylst.dest_loc%TYPE)
IS
BEGIN
   --
   -- Initialization
   --
   o_locked_bln := FALSE;

   --
   -- Start new block to trap record locked exception.
   --
   BEGIN
      SELECT dest_loc 
        INTO o_dest_loc
        FROM putawaylst p
       WHERE p.pallet_id = i_pallet_id
        FOR UPDATE OF p.dest_loc NOWAIT;

      o_locked_bln := TRUE;

   EXCEPTION
      WHEN e_record_locked THEN
         --
         -- Record locked by another session.
         --
         o_locked_bln := FALSE;

         --
         -- Log the locks on the table.
         --
         pl_log.ins_msg(pl_log.ct_fatal_msg, 'lock_putawaylst_record',
                     'i_pallet_id[' || i_pallet_id || ']'
                     || '  Could not lock the PUTAWAYLST record using NOWAIT because of a'
                     || ' lock by another user.'
                     || '  Who has the lock is in the next message.',
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);
         --
         -- This procedure logs the locks on the specified table.
         --
         pl_log.locks_on_a_table('PUTAWAYLST', SYS_CONTEXT('USERENV', 'SID'));
   END;

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'lock_putawaylst_record',
                     'i_pallet_id[' || i_pallet_id || ']'
                     || '  Error locking PUTAWAYLST record.  Returning FALSE'
                     || ' to indicate the record could not be locked.',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      o_locked_bln := FALSE;
END lock_putawaylst_record;


---------------------------------------------------------------------------
-- Function:
--    is_ok_to_process_putaway_task (Private)
--
-- Description:
--    This function decides if the putaway task task be processed.
--
--    There are 2 reasons why we will not process it:
--    1. If the putawaylst record cannot be locked.
--    2. If after locking the putawaylst record the dest_loc is
--       is not 'LR or '*'.  This would indicate that between the time
--       the cursor "c_putaway_tasks" was opened and the lock made some
--       other process updated the dest_loc to a valid location.
--    Our definition of not processing the putawaylst is to skip it.
--
-- Parameters:
--    i_pallet_id - pallet in PUTAWAYLST table.
--
-- Return Values:
--    TRUE  - Putawaylst record locked successfully.
--    FALSE - Putawaylst record not locked successfully.
--
-- Called by:
--    build_pallet_list_from_tasks
--
-- Exceptions raised:
--    None.  If an exception occurrs then it is logged and FALSE returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/21/17 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
FUNCTION is_ok_to_process_putaway_task
            (i_pallet_id IN putawaylst.pallet_id%TYPE)
RETURN BOOLEAN
IS
   l_locked_bln        BOOLEAN;
   l_dest_loc          putawaylst.dest_loc%TYPE;
   l_return_value_bln  BOOLEAN := TRUE;
BEGIN


   lock_putawaylst_record(i_pallet_id  => i_pallet_id,
                          o_locked_bln => l_locked_bln,
                          o_dest_loc   => l_dest_loc);

   IF (l_locked_bln = TRUE)
   THEN

      IF (l_dest_loc IN (pl_rcv_open_po_types.ct_lr_dest_loc, '*') OR pl_putaway_utilities.f_check_pit_location(l_dest_loc) = 'Y') THEN
         
         l_return_value_bln := TRUE;

      ELSE
         --
         -- The putawaylst record locked OK but the dest_loc is not 'LR' or '*'
         -- So do not processes the task.
         --
         l_return_value_bln := FALSE;

         --
         -- Lets log a message.
         --
         pl_log.ins_msg(pl_log.ct_info_msg, 'is_ok_to_process_putaway_task',
                  'i_pallet_id[' || i_pallet_id || ']  Locked the putawaylst'
                  || ' record but the dest_loc[' || l_dest_loc || '] not ''LR'' or ''*''.'
                  || '  Returning FALSE to designate to skip the task.',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
      END IF;
   ELSE
      --
      -- Could not lock the putaway task.
      --
      l_return_value_bln := FALSE;
      pl_log.ins_msg(pl_log.ct_info_msg, 'is_ok_to_process_putaway_task',
                  'i_pallet_id[' || i_pallet_id || ']  Could not lock the putawaylst record.'
                  || '  Returning FALSE to designate to skip the task',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);
   END IF;

   RETURN(l_return_value_bln);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and return FALSE.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, 'is_ok_to_process_putaway_task',
                     'i_pallet_id[' || i_pallet_id || ']'
                     || '  Oracle Error.  Returning FALSE'
                     || ' to indicate to skip the record.',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RETURN(FALSE);
END is_ok_to_process_putaway_task;


---------------------------------------------------------------------------
-- End Private Modules
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    get_number_of_lps_to_print (Public)
--
-- Description:
--    Live Receiving
--    This function determines the number of LP's to print for the
--    receiving pallet.
--
--    For a pallet directed to a reserve pallet flow slot we want to print
--    2 LP's.  For any other slot we want to print 1 LP.
--
-- Parameters:
--    i_pallet_id            - LP being processed.
--
-- Return Value:
--    Number of LP's to print.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - find_putaway_location
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/23/16 bben0556 Brian Bent
--                      Created
---------------------------------------------------------------------------
FUNCTION get_number_of_lps_to_print
             (i_pallet_id               IN  putawaylst.pallet_id%TYPE)
RETURN PLS_INTEGER
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'get_number_of_lps_to_print';

   l_perm          loc.perm%TYPE;
   l_return_value  PLS_INTEGER;
BEGIN
   BEGIN
      SELECT loc.perm
        INTO l_perm
        FROM putawaylst    put,
             loc           loc,
             loc_reference lr
       WHERE put.pallet_id       = i_pallet_id
         AND loc.logi_loc        = put.dest_loc
         AND lr.bck_logi_loc     = put.dest_loc;

   IF (l_perm = 'N') THEN
      l_return_value := 2;
   ELSE
      l_return_value := 1;
   END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_return_value := 1;
   END;

   RETURN(l_return_value);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and raise an error.
      --
      l_message := l_object_name
         || '(i_pallet_id)'
         || '  i_pallet_id[' || i_pallet_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END get_number_of_lps_to_print;



---------------------------------------------------------------------------
-- Procedure:
--    create_putaway_task (Public)
--
-- Description:
--    This procedure creates putaway tasks for each pallet on the PO
--    assigning 'LR' to the PUTAWAYLST.DEST_LOC.
--
--    No inventory is created at this time.  The inventory is created when
--    a slot is found for the putaway task.
--   
--    
-- Parameters:
--    i_r_syspars          - Relevant syspars
--    i_r_item_info        - Table of item info for the pallets.
--    io_r_pallet_table    - Table of pallet records to find slots for.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pl_rcv_open_po_find_slot.find_slot
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Created
--    07/14/07 bben0556 Use the regular logic for pallets going to the
--                      miniloader induction location.
--    01/25/18 mpha8134 Use the regular logic for pallets going to the
--                      matrix induction location.
---------------------------------------------------------------------------
PROCEDURE create_putaway_task
     (i_r_syspars          IN            pl_rcv_open_po_types.t_r_putaway_syspars,
      i_r_item_info_table  IN            pl_rcv_open_po_types.t_r_item_info_table,
      io_r_pallet_table    IN OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'create_putaway_task';

   l_done_bln        BOOLEAN;      -- Flag when done processing
   l_pallet_index    PLS_INTEGER;
   l_status          PLS_INTEGER;
BEGIN
   --
   -- Log how many pallets will be processed.
   --
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                     'Number of pallets to create putaway task'
                  || ' with dest_loc set to ' ||  pl_rcv_open_po_types.ct_lr_dest_loc
                  || ': ' || TO_CHAR(io_r_pallet_table.COUNT),
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);


   --
   -- For pallets going to the miniloader induction location use the regular
   -- logic.  They will be assigned to the induction location and inventory
   -- created.  There will be no "LR" logic.
   --
   pl_rcv_open_po_ml.direct_ml_plts_to_induct_loc
            (i_r_syspars          => i_r_syspars,
             i_r_item_info_table  => i_r_item_info_table,
             io_r_pallet_table    => io_r_pallet_table,
             o_status             => l_status);

   --
   -- For pallets going to the matrix induction location, user the regular
   -- logic. They will be assigned to the induction location and inventory
   -- created. There will be no 'LR' logic.
   --
   pl_rcv_open_po_matrix.direct_mx_plts_to_induct_loc
            (i_r_syspars          => i_r_syspars,
             i_r_item_info_table  => i_r_item_info_table,
             io_r_pallet_table    => io_r_pallet_table,
             o_status             => l_status);

   --
   -- Now process the pallets not going to the miniloader or matrix
   -- induction location. These will use the "LR" logic.
   -- Create the PUTAWAYLST records setting the dest_loc to 'LR'
   --
   l_pallet_index := io_r_pallet_table.FIRST;

   WHILE (l_pallet_index <= io_r_pallet_table.LAST)
   LOOP
      IF (io_r_pallet_table(l_pallet_index).direct_to_ml_induction_loc_bln = TRUE OR
            io_r_pallet_table(l_pallet_index).direct_to_mx_induction_loc_bln = TRUE)
      THEN
         NULL; -- Pallet going to the miniloader or matrix induction location, do nothing.
      ELSE
         io_r_pallet_table(l_pallet_index).dest_loc := pl_rcv_open_po_types.ct_lr_dest_loc;

         pl_rcv_open_po_find_slot.insert_records
                                  (i_r_item_info_table(io_r_pallet_table(l_pallet_index).item_index),
                                   io_r_pallet_table(l_pallet_index));
     END IF;

      --
      -- Advance to the next pallet.
      --
      l_pallet_index := io_r_pallet_table.NEXT(l_pallet_index);
   END LOOP;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, 'Error creating putaway tasks',
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, 
                                    l_object_name || ': ' || SQLERRM);
END create_putaway_task;


---------------------------------------------------------------------------
-- Procedure:
--    build_pallet_list_from_tasks
--
-- Description:
--    Live Receiving
--    This procedure builds the list of pallets for existing
--    Live Receiving putawaylst tasks for a PO or LP that do not yet
--    have the destination location determined.  Putawaylst task
--    with dest_loc of 'LR or '*' are selected.  We select the tasks
--    with '*' so that we can we have a method to attempt again to
--    find the destination location for a pallet the previously '*'.
--
--    Cursor "c_putaway_tasks" selects the putawaylst tasks.  It is
--    possible the putaway task is locked by another user so inside
--    the curror loop a function is called to lock the putawaylst record.
--    If the record cannot be locked then it is skipped.
--    We do not lock the putawaylst records in the cursor select statement
--    since it is possible only 1 or a few tasks are locked for a PO
--    and we want to process the putwaylst records not locked.
--
--
--    When the Live Receiving syspar is active and a PO is opened only
--    the putaway tasks are created with the dest loc set to 'LR'.
--    No inventory is created.
--    During RF check-in of a LP the dest loc is determined and the inventory
--    is created for the pallet.  This procedure is one of the procedures
--    used in the process.
--
--    Also the user will have the option on the CRT to have the system
--    find the dest loc for a Live Receiving LP or PO.
--    
--    *************************************************************
--    ***** Remember the PUTAWAYLST record already exists     *****
--    ***** and when a dest loc is found inventory is created *****
--    ***** if the pallet is directed to a reserve slot       *****
--    ***** and if the pallet is directed to a home slot      *****
--    ***** inventory is updatad. Also the pallet can '*'     *****
--    ***** if no location is found.                          *****
--    *************************************************************
--
--
-- Parameters:
--    i_r_syspars          - Syspars
--    i_erm_id             - PO/SN number to build pallet list for.
--    i_pallet_id          - LP to build pallet list for.
--    o_r_item_info_table  - Item info for all items on the PO/SN.  The
--                           pallet record stores the index of the item.
--    o_r_pallet_table     - List of pallets to putaway.
--
-- Exceptions Raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:
--    - pl_rcv_open_po_pallet_list.sql.build_pallet_list
--
-- ModIFication History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/15/16 bben0556 Brian Bent
--                      Live Receiving
--    02/06/17 bben0556 Brian Bent
--                      Live Receiving
--                      Added locking each putawaylst record individually.
--                      If the record cannot be locked then it will be 
--                      skipped.  The end result is no destination location
--                      is found for the putawaylst record.  It remains at
--                      'LR' or '*'.
---------------------------------------------------------------------------
PROCEDURE build_pallet_list_from_tasks
      (i_r_syspars          IN         pl_rcv_open_po_types.t_r_putaway_syspars,
       i_erm_id             IN         erm.erm_id%TYPE,
       i_pallet_id          IN         putawaylst.pallet_id%TYPE,
       o_r_item_info_table  OUT NOCOPY pl_rcv_open_po_types.t_r_item_info_table,
       o_r_pallet_table     OUT NOCOPY pl_rcv_open_po_types.t_r_pallet_table)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'build_pallet_list_from_tasks';

   l_item_index            PLS_INTEGER;  -- Index of item IN item plsql table.
   l_num_full_pallets      PLS_INTEGER;  -- Number of full pallets for
                                         -- the item.
   l_num_pallets           PLS_INTEGER;  -- Number of pallets of the item
                                         -- including full and partial.
   l_pallet_index          PLS_INTEGER;  -- Index
   l_partial_pallet_qty    PLS_INTEGER;  -- Partial pallet qty (IN splits).
   l_previous_prod_id      pm.prod_id%TYPE := 'x';  -- Previous item
                                                    -- processed.
   l_previous_cust_pref_vendor  pm.cust_pref_vendor%TYPE := 'x'; --Previous CPV
                                                                 -- processed.
   l_qty_in_mx             PLS_INTEGER;
   l_num_mx_full_pallets   PLS_INTEGER;
   l_partial_mx_pallet_qty PLS_INTEGER;
   l_overflow_qty          PLS_INTEGER;
   l_qty_in_wh             PLS_INTEGER;
   l_partial_wh_pallet_qty PLS_INTEGER;
   l_qty_added_to_mx       PLS_INTEGER;                 -- Vani Reddy added on 9/30/2014


   --
   -- This cursor selects the PUTAWAYLST record(s) to use
   -- in building the pallet list.
   -- For each record a pallet is created IN the pallet list.
   -- Only records with a dest_loc of 'LR' or '*' are selected.
   --
   -- The ordering is important.
   --
   CURSOR c_putaway_tasks
                 (cp_erm_id     erd.erm_id%TYPE             DEFAULT NULL,
                  cp_pallet_id  putawaylst.pallet_id%TYPE   DEFAULT NULL)
   IS
   SELECT put.rec_id,
          put.prod_id,
          put.cust_pref_vendor,
          put.dest_loc,
          put.qty,
          put.uom,
          put.status,
          put.inv_status,
          put.pallet_id,
          put.qty_expected,
          put.qty_received,
          put.qty_produced,
          put.temp_trk,
          put.temp,
          put.catch_wt,
          put.lot_trk,
          put.exp_date_trk,
          put.date_code,
          put.equip_id,
          put.rec_lane_id,
          put.seq_no,
          put.putaway_put,
          put.exp_date,
          put.clam_bed_trk,
          put.lot_id,
          put.weight,
          put.mfg_date,
          put.sn_no,
          put.po_no,
          put.erm_line_id,
          put.po_line_id,
          put.tti_trk,
          put.cool_trk,
          put.from_splitting_sn_pallet_flag,
          erm.erm_type,
          erd_lpn.shipped_ti,
          erd_lpn.shipped_hi,
          erd_lpn.pallet_type
     FROM putawaylst put,
          pm,
          erm,
          erd_lpn  -- Need some info from ERD_LPN for a SN
    WHERE erm.erm_id              = put.rec_id
      AND pm.prod_id              = put.prod_id
      AND pm.cust_pref_vendor     = put.cust_pref_vendor
      AND erd_lpn.pallet_id (+)   = put.pallet_id
      --
      AND put.rec_id              = NVL(cp_erm_id, put.rec_id)
      AND put.pallet_id           = NVL(cp_pallet_id, put.pallet_id)
      --
      --
      -- Only include in the list the Live Receiving pallets not yet
      -- assigned a slot.  Also select '*' pallets being aware the pallet
      -- could '*' again.
      AND 
      (
         put.dest_loc            IN (pl_rcv_open_po_types.ct_lr_dest_loc, '*')
         OR
         -- If this is a finish good company, and if this is an internal production PO, then
         -- check if the dest_loc is in a rule 11 location/zone. This means it's in a PIT zone.
         -- Allow find_slot for pallets in the PIT locations.
         pl_putaway_utilities.f_check_pit_location(put.dest_loc) = 'Y'
      )
    ORDER BY put.uom DESC,
             put.prod_id,
             put.cust_pref_vendor,
             put.exp_date,
             put.qty_expected,   -- 9/28/16  Brian Bent  Was put.qty
             pm.brand,
             pm.mfg_sku,
             pm.category,
             put.pallet_id;

   --
   -- This cursor counts the PUTAWAYLST records that are live receiving tasks
   -- not yet assigned a location, those assigned a location and those that '*'.
   -- This information is used for a "info" log message.
   --
   CURSOR c_putawaylst_dest_loc_count
                 (cp_erm_id     erd.erm_id%TYPE           DEFAULT NULL,
                  cp_pallet_id  putawaylst.pallet_id%TYPE DEFAULT NULL)
   IS
   SELECT SUM(DECODE(put.dest_loc, pl_rcv_open_po_types.ct_lr_dest_loc, 1,
                                   0)) live_receiving_count,
          --
          SUM(DECODE(put.dest_loc, '*', 1,
                                   0)) asterisk_count,
          --
          SUM(DECODE(put.dest_loc, pl_rcv_open_po_types.ct_lr_dest_loc, 0,
                                   '*', 0,
                                   1)) assigned_location_count
     FROM putawaylst put
    WHERE put.rec_id      = NVL(cp_erm_id, put.rec_id)
      AND put.pallet_id   = NVL(cp_pallet_id, put.pallet_id);

   --
   -- Record for cursor c_putawaylst_dest_loc_count.
   --
   r_putawaylst_dest_loc_count    c_putawaylst_dest_loc_count%ROWTYPE;
BEGIN
   --
   -- Do some validation of the parameters.
   -- At least one of i_erm_id and i_pallet_id need a value.
   --
   IF (i_erm_id IS NULL AND i_pallet_id IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Initialization
   --
   l_pallet_index := 1;

   --
   -- Log counts for research purposes.
   --
   OPEN c_putawaylst_dest_loc_count(i_erm_id, i_pallet_id);
   FETCH c_putawaylst_dest_loc_count INTO r_putawaylst_dest_loc_count;
   CLOSE c_putawaylst_dest_loc_count;

   l_message := 
         'r_putawaylst_dest_loc_count.live_receiving_count['      || TO_CHAR(r_putawaylst_dest_loc_count.live_receiving_count)    || ']'
      || '  r_putawaylst_dest_loc_count.asterisk_count['          || TO_CHAR(r_putawaylst_dest_loc_count.asterisk_count)          || ']'
      || '  r_putawaylst_dest_loc_count.assigned_location_count[' || TO_CHAR(r_putawaylst_dest_loc_count.assigned_location_count) || ']';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           l_message, NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

   -- Debug stuff
   DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

   --
   -- Process the PUTAWAYLST record(s).
   --
   FOR r_putaway_tasks IN c_putaway_tasks(i_erm_id, i_pallet_id)
   LOOP
      -- Debug stuff
      DBMS_OUTPUT.PUT_LINE('=================================================================');
      DBMS_OUTPUT.PUT_LINE(l_object_name
           || ' Item: '            || r_putaway_tasks.prod_id
           || ' CPV:'              || r_putaway_tasks.cust_pref_vendor
           || ' LP:'               || r_putaway_tasks.pallet_id
           || ' UOM:'              || TO_CHAR(r_putaway_tasks.uom)
           || ' Qty: '             || TO_CHAR(r_putaway_tasks.qty)
           || ' Qty Expected: '    || TO_CHAR(r_putaway_tasks.qty_expected)
           || ' Qty Received: '    || TO_CHAR(r_putaway_tasks.qty_received));

      --
      -- See if we will process the putaway task.
      -- There are 2 reasons why we will not process it:
      -- 1. If the putawaylst record cannot be locked.
      -- 2. If after locking the putawaylst record the dest_loc is
      --    is not 'LR or '*'.  This would indicate that between the time
      --    the cursor "c_putaway_tasks" was opened and the lock made some
      --    other process updated the dest_loc to a valid location.
      -- Our definition of not processing the putawaylst is to skip it.
      -- Function "is_ok_to_process_putaway_task" does the work.

      IF (is_ok_to_process_putaway_task(r_putaway_tasks.pallet_id) = FALSE) THEN
         --
         -- Skip the task.
         --
         -- 2/7/2017  Brian Bent I used CONTINUE to skip the record rather than
         -- IF... ELSE...
         --
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Not OK to process pallet[' || r_putaway_tasks.pallet_id || ']  Skip it',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

         -- Debug stuff
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' Not OK to process the pallet['
                               || r_putaway_tasks.pallet_id || ']  Skip it');

         CONTINUE;
      END IF;

      --
      -- If the first item or a different item then get the item information
      -- and store it in the plsql table of item records.
      -- The index of the item will be put in l_item_index which will be
      -- saved in the pallet table.
      --
      IF (r_putaway_tasks.prod_id != NVL(l_previous_prod_id, 'x') OR
  r_putaway_tasks.cust_pref_vendor != NVL(l_previous_cust_pref_vendor, 'x')) THEN
         pl_rcv_open_po_pallet_list.get_item_info
                      (i_r_syspars,
                       r_putaway_tasks.prod_id,
                       r_putaway_tasks.cust_pref_vendor,
                       i_erm_id,
                       l_item_index,
                       o_r_item_info_table);

         l_num_full_pallets := 1;
         l_num_pallets := 1;
         l_previous_prod_id := r_putaway_tasks.prod_id;
         l_previous_cust_pref_vendor := r_putaway_tasks.cust_pref_vendor;
         l_qty_added_to_mx := 0;

DBMS_OUTPUT.PUT_LINE('o_r_item_info_table.COUNT: ' ||
                  o_r_item_info_table.COUNT);

      END IF;

         l_num_mx_full_pallets := 0;
         l_partial_mx_pallet_qty := 0;
         l_qty_in_mx := 0;
      
      -- Vani Reddy added on 9/30/2014
      IF (o_r_item_info_table(l_item_index).mx_item_assign_flag = 'Y' AND
          NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') = 'Y' )
      THEN
            pl_rcv_open_po_pallet_list.get_mx_item_inventory(o_r_item_info_table(l_item_index), i_erm_id, l_qty_in_mx, l_qty_in_wh);     
      END IF;

      pl_rcv_open_po_pallet_list.show_item_info(l_item_index, o_r_item_info_table);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                ' l_item_index: ' || TO_CHAR(l_item_index));
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' ||
                  ' l_pallet_index: ' || TO_CHAR(l_pallet_index));

      o_r_pallet_table(l_pallet_index).pallet_id   := r_putaway_tasks.pallet_id;
      o_r_pallet_table(l_pallet_index).prod_id     := r_putaway_tasks.prod_id;
      o_r_pallet_table(l_pallet_index).cust_pref_vendor :=
                                             r_putaway_tasks.cust_pref_vendor;
      o_r_pallet_table(l_pallet_index).qty          := r_putaway_tasks.qty;
      o_r_pallet_table(l_pallet_index).qty_expected := r_putaway_tasks.qty_expected;
      o_r_pallet_table(l_pallet_index).qty_received := r_putaway_tasks.qty_received;
      o_r_pallet_table(l_pallet_index).qty_produced := r_putaway_tasks.qty_produced;
      o_r_pallet_table(l_pallet_index).uom          := r_putaway_tasks.uom;
      o_r_pallet_table(l_pallet_index).dest_loc     := r_putaway_tasks.dest_loc;
      o_r_pallet_table(l_pallet_index).item_index   := l_item_index;
      o_r_pallet_table(l_pallet_index).erm_id       := r_putaway_tasks.rec_id;
      o_r_pallet_table(l_pallet_index).erm_type     := r_putaway_tasks.erm_type;
      o_r_pallet_table(l_pallet_index).erm_line_id  := r_putaway_tasks.erm_line_id;
      o_r_pallet_table(l_pallet_index).seq_no       := r_putaway_tasks.seq_no;
      o_r_pallet_table(l_pallet_index).sn_no        := r_putaway_tasks.sn_no;
      o_r_pallet_table(l_pallet_index).po_no        := r_putaway_tasks.po_no;
      o_r_pallet_table(l_pallet_index).po_line_id   := r_putaway_tasks.po_line_id;
      o_r_pallet_table(l_pallet_index).shipped_ti   :=
                                                r_putaway_tasks.shipped_ti;
      o_r_pallet_table(l_pallet_index).shipped_hi   :=
                                                r_putaway_tasks.shipped_hi;
      o_r_pallet_table(l_pallet_index).temp         := r_putaway_tasks.temp;
      o_r_pallet_table(l_pallet_index).sn_pallet_type :=
                                               r_putaway_tasks.pallet_type;
      o_r_pallet_table(l_pallet_index).catch_weight :=
                                               r_putaway_tasks.weight;
      o_r_pallet_table(l_pallet_index).exp_date     := r_putaway_tasks.exp_date;
      o_r_pallet_table(l_pallet_index).mfg_date     := r_putaway_tasks.mfg_date;
      o_r_pallet_table(l_pallet_index).lot_id       := r_putaway_tasks.lot_id;

      o_r_pallet_table(l_pallet_index).collect_temp        := r_putaway_tasks.temp_trk;
      o_r_pallet_table(l_pallet_index).collect_catch_wt    := r_putaway_tasks.catch_wt;
      o_r_pallet_table(l_pallet_index).collect_lot_id      := r_putaway_tasks.lot_trk;
      o_r_pallet_table(l_pallet_index).collect_exp_date    := r_putaway_tasks.exp_date_trk;
      o_r_pallet_table(l_pallet_index).collect_mfg_date    := r_putaway_tasks.date_code;
      o_r_pallet_table(l_pallet_index).collect_temp        := r_putaway_tasks.temp_trk;
      o_r_pallet_table(l_pallet_index).collect_catch_wt    := r_putaway_tasks.catch_wt;
      o_r_pallet_table(l_pallet_index).collect_lot_id      := r_putaway_tasks.lot_trk;
      o_r_pallet_table(l_pallet_index).collect_clam_bed    := r_putaway_tasks.clam_bed_trk;
      o_r_pallet_table(l_pallet_index).collect_tti         := r_putaway_tasks.tti_trk;
      o_r_pallet_table(l_pallet_index).collect_cool        := r_putaway_tasks.cool_trk;

      o_r_pallet_table(l_pallet_index).live_receiving_status := 'SLOT';

      l_message := ' Item['                  || o_r_item_info_table(l_item_index).prod_id              || ']'
           || '  SPC['                       || TO_CHAR(o_r_item_info_table(l_item_index).spc)         || ']'
           || '  Item mx_eligible['          || o_r_item_info_table(l_item_index).mx_eligible          || ']'
           || '  Item mx_item_assign_flag['  || o_r_item_info_table(l_item_index).mx_item_assign_flag  || ']'
           || '  Item mx_max_splits['
           || TO_CHAR(o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc) || ']'
           || '  PO/SN['                     || i_erm_id                           || ']'
           || '  o_mx_qty_in_splits['        || TO_CHAR(l_qty_in_mx)        || ']'
           || '  o_warehouse_qty_in_splits[' || TO_CHAR(l_qty_in_wh) || ']';

      --
      -- Determine IF the pallet should be directed only to empty slots.
      -- This applies when going to reserve or floating.  Does not apply
      -- for bulk rule zones.
      --
      -- Receiving splits will always to an empty reserve/floating slot
      -- IF the splits cannot go to the home slot.
      -- Note: A SN should not have splits.
      --

      IF (o_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y' AND
          NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') = 'Y') THEN  
            IF NVL(l_qty_in_wh, 0) > 0 THEN
                -- pallet goes to main warehouse
                o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;
                l_message := l_message || '  Send to warehouse (item in warehouse)';
                dbms_output.put_line('to warehouse (item in warehouse)');
            ELSIF (NVL(l_qty_in_mx, 0) + l_qty_added_to_mx) >=
                   (o_r_item_info_table(l_item_index).mx_max_case * o_r_item_info_table(l_item_index).spc) THEN
                -- pallet goes to main warehouse
                o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;
                l_message := l_message || '  Send to warehouse (matrix full)';
                dbms_output.put_line('to warehouse (matrix full)');
            ELSE    
                o_r_pallet_table(l_pallet_index).matrix_reserve := FALSE;
                -- pallet goes to matrix             l_qty_added_to_mx := l_qty_added_to_mx + o_r_pallet_table(l_pallet_index).qty_received;
                l_message := l_message || '  Send to matrix';
                dbms_output.put_line('to matrix (qty_in_mx: ' || to_char(l_qty_in_mx) || 
                                  '  qty_added_to_mx: ' || to_char(l_qty_added_to_mx) || ')');
            END IF; 
      ELSIF (o_r_item_info_table(l_item_index).mx_item_assign_flag  = 'Y' AND 
             NVL(o_r_item_info_table(l_item_index).mx_eligible,'N') <> 'Y') THEN  
            o_r_pallet_table(l_pallet_index).matrix_reserve := TRUE;  -- pallet goes to main warehouse
            l_message := l_message || '  Send to warehouse (mx item not eligible)';
            dbms_output.put_line('to warehouse (mx item not eligible)');
      ELSE
         IF (o_r_pallet_table(l_pallet_index).uom = 1) THEN
             o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := TRUE;
             pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  ' Item[' || o_r_item_info_table(l_item_index).prod_id || ']'
                  ||' CPV[' || o_r_item_info_table(l_item_index).cust_pref_vendor
                  || ']'
                  || ' PO/SN[' || i_erm_id || ']'
                  || '  Receiving splits.  The pallet will be directed only to'
                  || ' open slots IF it cannot go to the home slot or it is'
                  || ' a floating item.  The pallet will always be'
                  || ' considered a partial pallet.',
                  NULL, NULL);
         ELSE
             o_r_pallet_table(l_pallet_index).direct_only_to_open_slot_bln := FALSE;
             dbms_output.put_line('do not direct only to open slot');
         END IF;
      END IF;

      --
      -- For a miniload item any pallet designated to go to the induction location
      -- was sent to the induction location when the PO was opened.  So at this
      -- point in processing the pallet needs to do to regular reserve.  Flag the
      -- pallet to goto reserve.
      --
      IF (o_r_item_info_table(l_item_index).miniload_storage_ind = 'B') THEN
         o_r_pallet_table(l_pallet_index).miniload_reserve := TRUE;
      END IF;

      --
      -- Determine if it is a full or partial pallet.
      --
      IF (o_r_pallet_table(l_pallet_index).qty_received >=
                                  (o_r_item_info_table(l_item_index).spc *
                                   o_r_item_info_table(l_item_index).ti *
                                   o_r_item_info_table(l_item_index).hi)) THEN
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'N';
      ELSE
         o_r_pallet_table(l_pallet_index).partial_pallet_flag := 'Y';
      END IF;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
           l_message, NULL, NULL,
           pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      --
      -- Calculate the cube and height of the pallet and other stuff.
      --
      pl_rcv_open_po_pallet_list.determine_pallet_attributes
                                  (o_r_item_info_table(l_item_index),
                                   l_pallet_index,
                                   o_r_pallet_table);

      l_pallet_index := l_pallet_index + 1;

   END LOOP;
EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- Both i_erm_id and i_pallet_id are null.  At least one needs a value.
      --
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,i_pallet_id,i_pallet_id,o_r_item_info_table,o_r_pallet_table)'
         || '  i_erm_id['    || i_erm_id    || ']'
         || '  i_pallet_id[' || i_pallet_id || ']'
         || '  Both i_erm_id and i_pallet_id are null.  At least one needs a value.';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     pl_exc.ct_data_error, NULL,
                     pl_rcv_open_po_types.ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,
                              l_object_name || ': ' || SQLERRM);

   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and raise an error.
      --
      l_message := l_object_name
         || '(i_r_syspars,i_erm_id,i_pallet_id,o_r_item_info_table,o_r_pallet_table)'
         || '  i_erm_id['    || i_erm_id    || ']'
         || '  i_pallet_id[' || i_pallet_id || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END build_pallet_list_from_tasks;


---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--    Live Receiving
--    This procedure determines the putaway location for a specified LP
--    or PO.
--
--    This is the procedure that does all the work.  The other overloaded
--    "find_putaway_location" procedures call this procedure.
--
--    The inventory is created when a valid slot is found for the putaway task.
--    Note that the putaway task could be assigned a '*' for the location if
--    no location is found.
--    
--    The main use of this procedure is to find the slot for the pallet
--    during live receiving check-in on the RF.  When the the Live Receiving
--    PO was first opened the PUTAWYLST.DEST_LOC was set to 'LR'.  During
--    the receiving check-in process on the RF we find the location for the
--    pallet updating 'LR' to the location (which could be a '*') and create
--    the inventory.
--    
--    If the putawaylst record already has a valid location then that pallet
--    is left alone.
--    If the putawaylst record has '*' for the location then an attempt is
--    made to find the putaway location so this procedure can be called for
--    a pallet which currenly has a '*' putaway location.  Note the location
--    could '*' again.
--
--    The PO needs to be in open status and have a putawaylst record.
--
-- Parameters:
--    i_erm_id                 - PO number to find slots for.
--    i_pallet_id              - LP to find slot for.  OPTIONAL
--                               If specified then i_erm_id needs to be
--                               the PO for the LP
--    o_dest_loc               - Putaway location  (PUTAWAYLST.DEST_LOC)
--                               It could be '*' if no slot found
--                               Only applicable when i_pallet_id specified.
--    o_number_of_lps_to_print - Number of LP's to print.  This will be 2
--                               if the pallet is directed to a reserve
--                               pallet flow slot otherwise it will be 1.
--                               Only applicable when i_pallet_id specified.
--    o_status                   Success or some failure.
--
-- Exceptions raised:
--    None.  o_status will be set when an error occurs.
--
-- Called by:
--    - 
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/20/16 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_erm_id                  IN  erm.erm_id%TYPE,
              i_pallet_id               IN  putawaylst.pallet_id%TYPE DEFAULT NULL,
              o_dest_loc                OUT putawaylst.dest_loc%TYPE,
              o_number_of_lps_to_print  OUT PLS_INTEGER,
              o_status                  OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(256);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_putaway_location';

   l_error_bln BOOLEAN := FALSE;
   l_err_msg   VARCHAR2(4000);
   l_find_slot_flag CHAR;
   l_sort_ind erm.sort_ind%TYPE;
   l_finish_good_PO CHAR;
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure'
         || '(i_erm_id,i_pallet_id,o_dest_loc,o_number_of_lps_to_print,o_status)'
         || '  i_erm_id['    || i_erm_id || ']'
         || '  i_pallet_id[' || i_pallet_id || ']'
         || '  This procedure determines the putaway location for a specified LP'
         || ' or PO.';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Initialization
   --
   o_dest_loc               := NULL;
   o_number_of_lps_to_print := NULL;
   o_status := pl_swms_error_codes.normal;

   IF pl_common.f_is_internal_production_po(i_erm_id) = TRUE THEN
      l_finish_good_PO := 'Y';
   ELSE
      l_finish_good_PO := 'N';
   END IF;

   BEGIN
      SELECT NVL(sort_ind, 'N'), dest_loc INTO l_sort_ind, o_dest_loc
      FROM erm, putawaylst p
      WHERE erm_id = i_erm_id
      AND erm_id = rec_id
      AND pallet_id = i_pallet_id;
   EXCEPTION 
      WHEN NO_DATA_FOUND THEN
         l_message := 
            'TABLE=putawaylst'
            || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
            || '  ACTION=SELECT'
            || '  MESSAGE="Pallet not found when attempting to select dest_loc.'
            || '  o_status set to pl_swms_error_codes.inv_label"';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
               l_message, SQLCODE, SQLERRM,
               pl_rcv_open_po_types.ct_application_function,
               gl_pkg_name);

         o_status := pl_swms_error_codes.inv_label;

      WHEN OTHERS THEN
         --
         -- Some Oracle error occured.
         -- Log a message and set o_status.
         --
         l_message := 
            'TABLE=putawaylst'
            || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
            || '  ACTION=SELECT'
            || '  MESSAGE="Error selecting from the table'
            || '  o_status set to pl_swms_error_codes.sel_putawaylst_fail"';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
               l_message,
               SQLCODE, SQLERRM,
               pl_rcv_open_po_types.ct_application_function,
               gl_pkg_name);

         o_status := pl_swms_error_codes.sel_putawaylst_fail;
   END;

   IF l_finish_good_PO = 'Y' THEN
      -- If the pallet is still in pit location, then try to find a location
      IF pl_putaway_utilities.f_check_pit_location(o_dest_loc) = 'Y' THEN
	 --knha8378 comment out because auto confirm is not happening anymore
	 -- and we do not want to find a location for the PIT inventory
	 -- we want the user to do transfer instead
         --l_find_slot_flag := 'Y';
         l_find_slot_flag := 'N';
      ELSE
         l_find_slot_flag := 'N';
      END IF;
   ELSE 
      l_find_slot_flag := 'Y';
   END IF;

   IF l_find_slot_flag = 'Y' THEN
      pl_rcv_open_po_find_slot.find_slot(
         i_erm_id                 => i_erm_id,
         i_pallet_id              => i_pallet_id,
         i_use_existing_tasks_bln => TRUE,
         io_error_bln             => l_error_bln,
         o_crt_msg                => l_err_msg);
   END IF;

   IF (l_error_bln = TRUE) THEN
      --
      -- Some error happened in pl_rcv_open_po_find_slot.find_slot
      -- Log a message and set o_status.
      --
      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name,
                     'Error in pl_rcv_open_po_find_slot.find_slot  ' || l_err_msg,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      o_status := pl_swms_error_codes.data_error;
   ELSE
      --
      -- pl_rcv_open_po_find_slot.find_slot ran OK.
      --
      -- We need to get the putaway location from 
      -- PUTAWAYLST.  The processing in "pl_rcv_open_po_find_slot.find_slot"
      -- would have populated it.  But only get it when i_pallet_id is specified.
      --
      IF (i_pallet_id IS NOT NULL) THEN
         BEGIN

            SELECT put.dest_loc
            INTO o_dest_loc
            FROM putawaylst put
            WHERE put.pallet_id = i_pallet_id;

         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               l_message := 
                  'TABLE=putawaylst'
                  || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
                  || '  ACTION=SELECT'
                  || '  MESSAGE="Pallet not found when attempting to select dest_loc.'
                  || '  o_status set to pl_swms_error_codes.inv_label"';

               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message, SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

               o_status := pl_swms_error_codes.inv_label;

            WHEN OTHERS THEN
               --
               -- Some Oracle error occured.
               -- Log a message and set o_status.
               --
               l_message := 
                  'TABLE=putawaylst'
                  || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
                  || '  ACTION=SELECT'
                  || '  MESSAGE="Error selecting from the table'
                  || '  o_status set to pl_swms_error_codes.sel_putawaylst_fail"';

               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

               o_status := pl_swms_error_codes.sel_putawaylst_fail;
         END;
      END IF;

      IF (o_status = pl_swms_error_codes.normal) THEN
          --
          -- Determine the number of LP's to print.
          -- A pallet directed to a pallet flow reserve slot will
          -- have 2 LP's printed otherwise 1 LP printed.
          --
          o_number_of_lps_to_print := get_number_of_lps_to_print(i_pallet_id);
      END IF;
   END IF;  -- end IF (i_pallet_id IS NOT NULL)

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Ending Procedure'
                  || '  i_erm_id['     || i_erm_id    || ']'
                  || '  i_pallet_id['  || i_pallet_id || ']'
                  || '  o_dest_loc['   || o_dest_loc  || ']'
                  || '  o_number_of_lps_to_print[' || TO_CHAR(o_number_of_lps_to_print) || ']'
                  || '  o_status['     || TO_CHAR(o_status) || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and set o_status.
      --
      l_message := l_object_name
         || '(i_erm_id,i_pallet_id,i_dest_loc,i_number_of_lps_to_print,o_status)'
         || '  i_erm_id['    || i_erm_id    || ']'
         || '  i_pallet_id[' || i_pallet_id || ']'
         || '  o_status set to pl_swms_error_codes.data_error';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      o_status := pl_swms_error_codes.data_error;

END find_putaway_location;


---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--    Live Receiving
--    This procedure determines the putaway location for a specified LP
--    for an existing PUTAWAYLST record.  If the putaway tasks already has
--    a valid location then this procedure effectively does nothing.
--
--    The live receiving RF check-in processing needs to call this procedure
--    to find the slot for a specified LP.  Ideally the procedure is called
--    when the dest_loc is 'LR' or '*'
--    
-- Parameters:
--    i_pallet_id              - LP to find slot for.
--    o_dest_loc               - Putaway location  (PUTAWAYLST.DEST_LOC)
--                               It could be '*' if no slot found
--    o_number_of_lps_to_print - Number of LP's to print.  This will be 2
--                               if the pallet is directed to a reserve
--                               pallet flow slot otherwise it will be 1.
--                               Only applicable when i_pallet_id specified.
--    o_status                 - Status.  Will be set to one of the following:
--                               - pl_swms_error_codes.normal
--                               - pl_swms_error_codes.inv_label     LP not in putawaylst
--                               - pl_swms_error_codes.data_error    Database error
--
-- Exceptions raised:
--    None.  o_status will be set when an error occurs.
--
-- Called by:
--    - 
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_pallet_id               IN  putawaylst.pallet_id%TYPE,
              o_dest_loc                OUT putawaylst.dest_loc%TYPE,
              o_number_of_lps_to_print  OUT PLS_INTEGER,
              o_status                  OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_putaway_location';

   l_dest_loc      putawaylst.dest_loc%TYPE;  -- The current dest_loc for the
                                              -- LP.  Used in log message.  Ideally
                                              -- the procedure is called when the
                                              -- dest_loc is 'LR' or '*'
   l_erm_id        erm.erm_id%TYPE;           -- The PO for the LP.  Needed
                                              -- in call to the overloaded
                                              -- "find_putaway_location" procedure
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure'
         || '(i_pallet_id,o_dest_loc,o_number_of_lps_to_print,o_status)'
         || '  i_pallet_id[' || i_pallet_id || ']'
         || 'This procedure determines the putaway location for a specified LP'
         || ' for an existing PUTAWAYLST record.  If the putaway tasks already has'
         || ' a valid location then this procedure effectively does nothing.';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Initialization
   --
   o_status := pl_swms_error_codes.normal;

   --
   -- We need the PO number for i_pallet_id from the PUTAWAYLST table.
   -- We will not care about the PO status as the status will not have
   -- any affect. Also get the dest_loc to display in log message.
   --
   BEGIN
      SELECT put.rec_id, put.dest_loc
        INTO l_erm_id, l_dest_loc
        FROM putawaylst put
       WHERE put.pallet_id = i_pallet_id;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         --
         -- Did not find the LP in the PUTAWYLAYST table.
         -- Log a message and set o_status.
         --
         l_message := 
                  'TABLE=putawaylst'
                  || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
                  || '  ACTION=SELECT'
                  || '  MESSAGE="Pallet not found when attempting to select rec_id.'
                  || '  o_status set to pl_swms_error_codes.inv_label"';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

         o_status := pl_swms_error_codes.inv_label;
      WHEN OTHERS THEN 
         --
         -- Some Oracle error occured.
         -- Log a message and set o_status.
         --
         l_message := 
                  'TABLE=putawaylst'
                  || '  KEY=[' || i_pallet_id || '](i_pallet_id)'
                  || '  ACTION=SELECT'
                  || '  MESSAGE="Error selecting from the table'
                  || '  o_status set to pl_swms_error_codes.sel_putawaylst_fail"';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

         o_status := pl_swms_error_codes.sel_putawaylst_fail;
   END;

   IF (o_status = pl_swms_error_codes.normal)
   THEN
      --
      -- Got the PO number and dest_loc from PUTAWAYLST.
      -- Log a message
      --
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                     'Retrieved the PO/SN[' || l_erm_id || ']'
                     || ' and dest_loc[' || l_dest_loc || '] from PUTAWAYLST',
                     NULL, NULL,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      --
      -- Start a new block to trap errors.  The plan is set o_status to an
      -- error code if an error is encountered.
      --
      BEGIN
         --
         -- Call the "main" find_putaway_location to do the work.
         --
         find_putaway_location
               (i_erm_id                 => l_erm_id,
                i_pallet_id              => i_pallet_id,
                o_dest_loc               => o_dest_loc,
                o_number_of_lps_to_print => o_number_of_lps_to_print,
                o_status                 => o_status);
      EXCEPTION
         WHEN OTHERS THEN
         --
         -- Got some oracle error.  Log a message and set o_status.
         --
         l_message := 
            '(i_pallet_id,o_dest_loc,o_number_of_lps_to_print,o_status)'
            || '  i_pallet_id[' || i_pallet_id || ']'
            || ' Error after calling the "main" "find_putaway_location"'
            || '  o_status set to pl_swms_error_codes.data_error';
   
         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
   
         o_status := pl_swms_error_codes.data_error;
      END;
   END IF;  -- end IF (o_status = pl_swms_error_codes.normal)

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Ending Procedure'
                  || '  i_pallet_id['  || i_pallet_id || ']'
                  || '  o_dest_loc['   || o_dest_loc  || ']'
                  || '  o_number_of_lps_to_print[' || TO_CHAR(o_number_of_lps_to_print) || ']'
                  || '  o_status['     || TO_CHAR(o_status) || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and set o_status.
      --
      l_message :=
         '(i_pallet_id,o_dest_loc,o_number_of_lps_to_print,o_status)'
         || '  i_pallet_id[' || i_pallet_id || ']'
         || '  o_status set to pl_swms_error_codes.data_error';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      o_status := pl_swms_error_codes.data_error;
END find_putaway_location;


---------------------------------------------------------------------------
-- Procedure:
--    find_putaway_location (Public)  Overloaded
--
-- Description:
--    Live Receiving
--    This procedure determines the putaway location for a specified PO
--    for the putawaylst records with dest_loc = 'LR' or '*'.  If the putaway task
--    already have a valid location then it is not selected.
--    
-- Parameters:
--    i_erm_id                 - PO being procesed.
--    o_status                 - Status.  Will be set to one of the following:
--                               - pl_swms_error_codes.normal
--                               - pl_swms_error_codes.data_error    Database error
--
-- Exceptions raised:
--    None.  o_status will be set when an error occurs.
--
-- Called by:
--    - 
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/20/06 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE find_putaway_location
             (i_erm_id     IN  erm.erm_id%TYPE,
              o_status     OUT PLS_INTEGER)
IS
   l_message       VARCHAR2(512);    -- Message buffer
   l_object_name   VARCHAR2(30) := 'find_putaway_location';

   l_dest_loc                putawaylst.dest_loc%TYPE;  -- Need in procedure call but
                                                        -- otherwise not used.
   l_number_of_lps_to_print  PLS_INTEGER;               -- Need in procedure call but
BEGIN
   --
   -- Log starting the procedure.
   --
   l_message := 'Starting procedure'
         || '(i_pallet_id,o_status)'
         || '  i_erm_id[' || i_erm_id || ']'
         || ' This procedure determines the putaway location for a specified PO'
         || ' for the putawaylst records with dest_loc = ''LR'' or ''*''.';

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);

   --
   -- Initialization
   --
   o_status := pl_swms_error_codes.normal;

   --
   -- Start a new block to trap errors.  The plan is set o_status to an
   -- error code if an error is encountered.
   --
   BEGIN
      --
      -- Call the "main" find_putaway_location to do the work.
      --
      find_putaway_location
               (i_erm_id                 => i_erm_id,
                o_dest_loc               => l_dest_loc,
                o_number_of_lps_to_print => l_number_of_lps_to_print,
                o_status                 => o_status);
   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Got an oracle error.  Log a message and set o_status.
         --
         l_message := 
            '(i_ermm_rd,o_status)'
            || '  i_erm_id[' || i_erm_id || ']'
            || ' Error after calling the "main" "find_putaway_location"'
            || '  o_status set to pl_swms_error_codes.data_error';
   
         pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                        SQLCODE, SQLERRM,
                        pl_rcv_open_po_types.ct_application_function,
                        gl_pkg_name);
   
      o_status := pl_swms_error_codes.data_error;
   END;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'Ending Procedure'
                  || '  i_erm_id[' || i_erm_id || ']'
                  || '  o_status[' || TO_CHAR(o_status) || ']',
                  NULL, NULL,
                  pl_rcv_open_po_types.ct_application_function,
                  gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.  Log a message and set o_status.
      --
      l_message :=
         '(i_erm_id,o_status)'
         || '  i_erm_id[' || i_erm_id || ']  final when others exception'
         || '  o_status set to pl_swms_error_codes.data_error';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     pl_rcv_open_po_types.ct_application_function,
                     gl_pkg_name);

      o_status := pl_swms_error_codes.data_error;
END find_putaway_location;


END pl_rcv_open_po_lr;  -- end package body
/


-- GRANT EXECUTE ON swms.pl_rcv_open_po_lr TO SWMS_USER;

-- CREATE OR REPLACE PUBLIC SYNONYM pl_rcv_open_po_lr FOR swms.pl_rcv_open_po_lr;


