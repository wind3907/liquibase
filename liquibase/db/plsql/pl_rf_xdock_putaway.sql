
-------------------------
-------------------------
-- Packge Specification
-------------------------
-------------------------

CREATE OR REPLACE PACKAGE swms.pl_rf_xdock_putaway
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_rf_xdock_putaway
--
-- Description:
--    This package has the procedure/functions, etc for the putaway process
--    for R1 Site 2.  The "putaway" can be a PUT to the staging location
--    or the drop to the door for a XDK.
--
--    The main entry point to this package is function "putaway_main".
--
--    Process Flow:
--       - If PUT
--          - get pallet info   Lock putawylst record.
--            Error if pallet not in putawaylst.
--          - validate pallet   Includes checking it is a XN and pallet not putaway
--                              This is same check as in pre putaway.
--                             
--       - If XDK
--          - Get replenlst.door_no using task_id.  Lock replenlst record. 
--            Error if task_id not in replenlst.
--
--       - Validate RF dest_loc scanned/keyed by user
--          - If PUT
--             - Incorporate strip logic except strip option P which will be treated like option 'Y'
--               Strip option 'Y' matches first 5 characters in the location.
--          - If XDK
--             - RF dest_loc needs to match replenlst.door_no.
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    01/28/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--
--                      Created.
-----------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    putaway_main (public)
--
-- Description:
--    This function performs the putaway processing when a R1 cross dock
--    pallet is confirmed for putaway at Site 2.  This "putaway" can be the scan
--    to the staging locaiton or to the door (XDK)
--
--   This function is what the RF calls.
--
--   It will commit or rollback depending on the status.
--
--   Procedure "putaway" is called to do all the work.  "putaway" does not
--   commit or rollback.
---------------------------------------------------------------------------
FUNCTION putaway_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_putaway_client_obj
   )
RETURN rf.STATUS;

---------------------------------------------------------------------------
-- Procedure:
--    putaway (public)
--
-- Description:
--    This procedure does all the work.
--    It is called by "putaway_main".
--    It does not commit or rollback.
---------------------------------------------------------------------------
PROCEDURE putaway
   (
      i_client_obj                IN   xdock_putaway_client_obj,
      o_rf_status                 OUT  NUMBER
   );

FUNCTION haul_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_haul_client_obj
   )
RETURN rf.STATUS;

---------------------------------------------------------------------------
-- Procedure:
--    haul (public)
--
-- Description:
--    This procedure does all the work.
--    It is called by "haul_main".
--    It does not commit or rollback.
---------------------------------------------------------------------------
PROCEDURE haul
   (
      i_client_obj       IN   xdock_haul_client_obj,
      o_rf_status        OUT  NUMBER

   );

FUNCTION undo_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_putaway_undo_client_obj
   )
RETURN rf.STATUS;

---------------------------------------------------------------------------
-- Procedure:
--    undo (public)
--
-- Description:
--    This procedure does all the work.
--    It is called by "undo_main".
--    It does not commit or rollback.
---------------------------------------------------------------------------
PROCEDURE undo
   (
      i_client_obj       IN   xdock_putaway_undo_client_obj,
      o_rf_status        OUT  NUMBER
   );


END pl_rf_xdock_putaway;
/

/*********
show errors
pause pause
l
pause pause
********/

-------------------------
-------------------------
-- Packge Body
-------------------------
-------------------------

CREATE OR REPLACE PACKAGE BODY swms.pl_rf_xdock_putaway
AS

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

gl_pkg_name          VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.  Used in error messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function CONSTANT  VARCHAR2(30) := 'RECEIVING';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    log_putaway_client_object (private)
--
-- Description:
--    This procedure logs the putaway client object for researching/debugging.
--
-- Parameters:
--    i_client_obj  -   xdock_putaway_server_obj
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/15/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_putaway_client_object
   (
      i_client_obj   IN   xdock_putaway_client_obj
   )
IS
   l_object_name     VARCHAR2(30)      := 'log_putaway_client_object';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                              -- Message buffer
BEGIN
   l_message := 'client object sent from RF:'
             || ' equip_id['      ||  i_client_obj.equip_id    || ']'
             || ' pallet_id['     ||  i_client_obj.pallet_id   || ']'
             || ' task_type['     ||  i_client_obj.task_type   || ']'
             || ' task_id['       ||  i_client_obj.task_id     || ']'
             || ' dest_loc['      ||  i_client_obj.dest_loc    || ']'
             || ' scan_method['   ||  i_client_obj.scan_method || ']';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message.  Don't raise an exception.
      -- Log message failing is not fatal.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred.  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END log_putaway_client_object;


---------------------------------------------------------------------------
-- Procedure:
--    log_haul_client_object (private)
--
-- Description:
--    This procedure logs the haul client object for researching/debugging.
--
-- Parameters:
--    i_client_obj  -   xdock_haul_client_obj
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_haul_client_object
   (
      i_client_obj   IN   xdock_haul_client_obj
   )
IS
   l_object_name     VARCHAR2(30)      := 'log_haul_client_object';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                                   -- Message buffer
BEGIN
   l_message := 'client object sent from RF:'
             || ' pallet_id['     ||  i_client_obj.pallet_id   || ']'
             || ' task_type['     ||  i_client_obj.task_type   || ']'
             || ' task_id['       ||  i_client_obj.task_id     || ']'
             || ' drop_point['    ||  i_client_obj.drop_point  || ']'
             || ' scan_method['   ||  i_client_obj.scan_method || ']';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message.  Don't raise an exception.
      -- Log message failing is not fatal.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred.  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END log_haul_client_object;


---------------------------------------------------------------------------
-- Procedure:
--    log_undo_client_object (private)
--
-- Description:
--    This procedure logs the haul client object for researching/debugging.
--
-- Parameters:
--    i_client_obj  -   xdock_putaway_undo_client_obj
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_undo_client_object
   (
      i_client_obj   IN   xdock_putaway_undo_client_obj
   )
IS
   l_object_name     VARCHAR2(30)      := 'log_undo_client_object';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                                   -- Message buffer
BEGIN
   l_message := 'client object sent from RF:'
             || ' pallet_id['     ||  i_client_obj.pallet_id   || ']'
             || ' task_type['     ||  i_client_obj.task_type   || ']'
             || ' task_id['       ||  i_client_obj.task_id     || ']'
             || ' drop_point['    ||  i_client_obj.drop_point  || ']';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message.  Don't raise an exception.
      -- Log message failing is not fatal.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred.  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END log_undo_client_object;


---------------------------------------------------------------------------
-- Procedure:
--    validate_location (private)
--
-- Description:
--    This procedure validates the location the user scanned
--    for putaway or for the XDK drop.
--
--   For a putaway the strip location is in effect except option 'P'
--   is treated like option 'Y'
--
--   For a XDK there is no strip logic.  The door scaanned needs to match
--   the door the pallet is directed to.
--
-- Parameters:
--    i_client_obj    - dat sent form RF.  Includes the destination location scanned.
--    i_r_pallet_info - Pallet info.
--    o_rf_status     - 
--                      Set To                   When
--                      --------------------------------------------------------------------
--                      rf.status_normal         Passed valiation.
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/14/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE validate_location
   (
      i_client_obj     IN    xdock_putaway_client_obj,
      i_r_pallet_info  IN    pl_rf_xdock_pre_putaway.t_r_pallet_info,
      o_rf_status      OUT   NUMBER
   )
IS
   l_object_name     VARCHAR2(30) := 'validate_location';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(512);                         -- Message buffer

   l_check_to_length       NUMBER;                          -- Strip location logic check to this length.
   l_syspar_strip_loc      sys_config.config_flag_val%TYPE;
   l_locations_match_bln   BOOLEAN;
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.task_type['       ||  i_client_obj.task_type    || ']'
                      || '  i_client_obj.pallet_id['       ||  i_client_obj.pallet_id    || ']'
                      || '  i_client_obj.dest_loc['        ||  i_client_obj.dest_loc     || ']'
                      || '  i_r_pallet_info.pallet_id['    ||  i_r_pallet_info.pallet_id || ']'
                      || '  i_r_pallet_info.dest_loc['     ||  i_r_pallet_info.dest_loc  || ']'
                      || '  i_r_pallet_info.door_no['      ||  i_r_pallet_info.door_no   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status        := rf.status_normal;
   l_syspar_strip_loc := pl_common.f_get_syspar('STRIP_LOC', 'N');

   -- 
   -- Check the task destination location against what the user scanned/keyed.
   -- Apply strip logic for a putaway.
   --
dbms_output.put_line('000000000');
   IF (i_client_obj.task_type = 'PUT' AND l_syspar_strip_loc = 'Y') THEN
      l_check_to_length := LENGTH(i_r_pallet_info.dest_loc) - 1;
   ELSE
      l_check_to_length := LENGTH(i_r_pallet_info.dest_loc);
   END IF;
 
dbms_output.put_line('111111111');

   IF (SUBSTR(i_r_pallet_info.dest_loc, 1, l_check_to_length) = SUBSTR(i_client_obj.dest_loc, 1, l_check_to_length))
   THEN
      l_locations_match_bln := TRUE;
   ELSE
      l_locations_match_bln := FALSE;
   END IF;

dbms_output.put_line('222222222');

   IF (l_locations_match_bln = FALSE) THEN
      --
      -- Destination location scanned/keyed by the user does not match the task destination.
      --
      o_rf_status := rf.status_inv_dest_location;
dbms_output.put_line('333333333');

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Location not matching.'
                      || '  Pallet['                                      || i_r_pallet_info.pallet_id  || ']'
                      || '  Destination location user scanned/keyed['     || i_client_obj.dest_loc      || ']'
                      || ' does not match the task destination location[' || i_r_pallet_info.dest_loc   || ']'
                      || '  o_rf_status['                                 || TO_CHAR(o_rf_status)       || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;
dbms_output.put_line('444444444');

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_r_pallet_info.pallet_id['  || i_r_pallet_info.pallet_id  || ']'
                      || '  o_rf_status['                || TO_CHAR(o_rf_status)       || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
dbms_output.put_line('555555555');

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and return data error.
      --
      o_rf_status := rf.status_data_error;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id [' ||  i_client_obj.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END validate_location;


---------------------------------------------------------------------------
-- Procedure:
--    insert_trans (private)
--
-- Description:
--    This procedures inserts either the PUX or PFK transaction depending if the
--    inbound pallet is going to the staging location or to the outbound door.
--
-- Parameters:
--    i_client_obj     - Data from RF.
--    i_r_pallet_info  - Pallet info.  Has info needed to create the transaction.
--    o_rf_status      - Insert succedded or failed
--                      Set To                           When
--                      --------------------------------------------------------------------
--                      rf.status_normal                 Insert successful.
--                      rf.status_trans_insert_failed    Insert failed.
--                      rf.status_data_error             Task type not PUT or XDK.
--
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/16/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE insert_trans
   (
      i_client_obj      IN   xdock_putaway_client_obj,
      i_r_pallet_info   IN   pl_rf_xdock_pre_putaway.t_r_pallet_info,
      o_rf_status       OUT  NUMBER
   )
IS
   l_object_name     VARCHAR2(30)      := 'insert_trans';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(256);                         -- Message buffer
BEGIN
   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   IF (i_client_obj.task_type = 'PUT') THEN
      --
      -- Insert PPU transaction.
      --
      INSERT INTO trans
                 (
                  trans_id,
                  trans_date,
                  trans_type,
                  user_id,
                  rec_id,
                  po_no,
                  pallet_id,
                  src_loc,
                  dest_loc,
                  prod_id,
                  cust_pref_vendor,
                  exp_date,
                  mfg_date,
                  lot_id,
                  qty,
                  uom,
                  new_status,
                  warehouse_id,
                  batch_no,
                  labor_batch_no,
                  scan_method1,
                  scan_method2,
                  cross_dock_type,
                  cmt
                 )
      VALUES
                 (
                  trans_id_seq.NEXTVAL,                -- trans_id
                  SYSDATE,                             -- trans_date
                  'PUX',                               -- trans_type
                  USER,                                -- user_id
                  i_r_pallet_info.rec_id,              -- rec_id
                  i_r_pallet_info.rec_id,              -- po_no
                  i_r_pallet_info.pallet_id,           -- pallet_id
                  i_r_pallet_info.src_loc,             -- src_loc
                  i_r_pallet_info.dest_loc,            -- dest_loc
                  i_r_pallet_info.prod_id,             -- prod_id
                  i_r_pallet_info.cust_pref_vendor,    -- cust_pref_vendor
                  i_r_pallet_info.exp_date,            -- exp_date
                  i_r_pallet_info.mfg_date,            -- mfg_date
                  i_r_pallet_info.lot_id,              -- lot_id
                  i_r_pallet_info.qty,                 -- qty
                  i_r_pallet_info.uom,                 -- uom
                  'AVL',                               -- new_status
                  '000',                               -- warehouse_id
                  '99',                                -- batch_no
                  i_r_pallet_info.pallet_batch_no,     -- labor_batch_no
                  null,                                -- scan_method1     2/16/22 don't have this yet, forgot it.
                  null,                                -- scan_method2     2/16/22 don't have this yet, forgot it.
                  i_r_pallet_info.cross_dock_type,     -- cross_dock_type
                  'THE TRANSACTION QTY IS THE NUMBER OF PIECES ON THE PALLET'   -- cmt
                 );
   ELSIF (i_client_obj.task_type = 'XDK') THEN
      --
      -- Insert DFK transaction.  Do nothing here.  The DFK transaction is created by a database trigger
      -- when the REPLENLST record is deleted.  The delete from REPLENLST happens after at the end of
      -- processing elsewhere in the package.
      --
      NULL;
   ELSE
      --
      -- Unexpected value for i_server.task_type ---xxxxxxxxxxxx
      --
      null;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and set status to trans insert failed.
      --

      o_rf_status := rf.status_trans_insert_failed;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_r_pallet_info.pallet_id [' ||  i_r_pallet_info.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END insert_trans;


---------------------------------------------------------------------------
-- Procedure:
--    putaway_pallet (private)
--
-- Description:
--    This procedure does the putaway/drop processing for the pallet.
--
-- Parameters:
--    i_client_obj    - dat sent form RF.  Includes the destination location scanned.
--    i_r_pallet_info - Pallet info.
--    o_rf_status     - 
--                      Set To                   When
--                      --------------------------------------------------------------------
--                      rf.status_normal         Passed valiation.
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/14/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE putaway_pallet
   (
      i_client_obj     IN    xdock_putaway_client_obj,
      i_r_pallet_info  IN    pl_rf_xdock_pre_putaway.t_r_pallet_info,
      o_rf_status      OUT   NUMBER
   )
IS
   l_object_name     VARCHAR2(30) := 'putaway_pallet';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(512);                     -- Message buffer
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.task_type['       ||  i_client_obj.task_type    || ']'
                      || '  i_client_obj.pallet_id['       ||  i_client_obj.pallet_id    || ']'
                      || '  i_client_obj.dest_loc['        ||  i_client_obj.dest_loc     || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status        := rf.status_normal;

   --
   -- Initialization
   --
   o_rf_status        := rf.status_normal;

   --  
   -- First create the transaction--either PUX or DFK.
   --  
   dbms_output.put_line('insert transaction:' || i_client_obj.pallet_id || ' ' || i_client_obj.task_type);
   insert_trans(i_client_obj     => i_client_obj,
                i_r_pallet_info  => i_r_pallet_info,
                o_rf_status      => o_rf_status);

   --
   -- Complete the task which consists of deleting it.
   --
   IF (i_client_obj.task_type = 'PUT') THEN
      -- xxxxxxxxx create a common procedure to delete the PUT task since pre_putaway can delete it if the user directed to do the XDK.

      DELETE FROM putawaylst
        WHERE pallet_id = i_client_obj.pallet_id;

      dbms_output.put_line('delete putawaylst record, pallet:' || i_client_obj.pallet_id || ' sql%rowcount: ' || sql%rowcount);

   ELSIF (i_client_obj.task_type = 'XDK') THEN
      DELETE FROM replenlst
        WHERE task_id = i_client_obj.task_id;

      dbms_output.put_line('delete replenlst record, task_id:' || i_client_obj.task_id || ' sql%rowcount: ' || sql%rowcount);
   ELSE
      dbms_output.put_line('Unhandled task_type:' || i_client_obj.task_type);
   END IF;

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['       ||  i_client_obj.pallet_id    || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and return data error.
      --
      o_rf_status := rf.status_data_error;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id [' ||  i_client_obj.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END putaway_pallet;


---------------------------------------------------------------------------
-- Function:
--    is_valid_drop_point (private)
--
-- Description:
--    This function determines if the drop point for a haul is valid.
--
--    The haul can be the result of:
--    - The user selects the haul option for the pallet on the RF.
--    - The user selects the undo option for the pallet on the RF
--      after selecting travel.  This is similar to the haul.  The major
--      difference is the type of forklift labor batches created.
--
--    The drop point is considered value when:
--       - If forklift labor is active. 
--          - The drop point is setup is forklift labor distances.
--          - The drop point is a door or a bay.
--          - When the drop point is a bay it is the complete location and
--            not just the aisle-bay.  Like 'DE23A1' and not 'DE23'.
--       - If forklift labor is not active. 
--          - The drop point is in the LOC table or the drop point length is
--            between 1 and 3 characters--some what of an arbitary check
--            since we do cannot check the DOOR table as the is no requirement
--            to setup the doors in the DOOR table if forklift labor is turned off.
--
-- Parameters:
--    i_location  - the drop point.
--
-- Return Values:
--    TRUE  - Pallet has a XDK task in NEW status.
--    FALSE - Pallet does not have XDK task in NEW status or has no task at all.
--
-- Called By:
--
-- Exceptions Raised:
--    xxxxxxx
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/08/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION is_valid_drop_point(i_location  in loc.logi_loc%TYPE)
RETURN BOOLEAN
IS
   l_location            loc.logi_loc%TYPE;
   l_point_type          point_distance.point_type%TYPE;
   l_dock_num            point_distance.point_dock%TYPE;
   l_valid_location_bln  BOOLEAN;

   l_dummy               VARCHAR2(1);

   CURSOR c_valid_location(cp_location loc.logi_loc%TYPE)
   IS
   SELECT 'x'
     FROM loc
    WHERE loc.logi_loc = cp_location;
BEGIN
   --
   -- Initialization
   --
   l_valid_location_bln := TRUE;
   l_location           := i_location;

   dbms_output.put_line('AAA l_location: ' || l_location);

   IF (pl_lmf.f_forklift_active = TRUE) THEN
      l_location := NVL(pl_lmf.f_get_fk_door_no(l_location), l_location);
   END IF;

   dbms_output.put_line('BBB l_location: ' || l_location);

   IF (pl_lmf.f_forklift_active = TRUE) THEN
      --
      -- Forklift labor is active.
      -- Check the location against the point distance setup.
      --

      dbms_output.put_line('forklift labor is active');

      --
      -- Get the location point type.
      -- The point type needs to be a door('D') or a bay('B')
      -- pl_lmd.sql has the point types defined but they private.
      -- So hardcode 'B' and 'D'.
      -- If the point type is a bay then it needs to be the full location
      -- like 'DE23A1' and not 'DE23'.
      --
      -- "pl_lmd.get_point_type" raises an exception if no point type is found.
      --
      pl_lmd.get_point_type(i_point      => l_location,
                            o_point_type => l_point_type,
                            o_dock_num   => l_dock_num);

      dbms_output.put_line('l_point_type: ' || l_point_type);
      dbms_output.put_line('l_dock_nume: ' || l_dock_num);

      CASE l_point_type
         WHEN 'B' THEN
            --
            -- The location is a bay.  It needs to the complete location.
            --
            OPEN c_valid_location(l_location);
            FETCH c_valid_location INTO l_dummy;

            IF (c_valid_location%FOUND) THEN
               l_valid_location_bln := TRUE;
            ELSE
               l_valid_location_bln := FALSE;
            END IF;

            CLOSE c_valid_location;
         WHEN 'D' THEN
            --
            -- The location is door.
            --
            l_valid_location_bln := TRUE;
         ELSE
            --
            -- The location is not a door or bay so it is invalid.
            --
            l_valid_location_bln := FALSE;
      END CASE;
   ELSE
      --
      -- Forklift labor is not active. 
      -- So we will consider the location valid if one of the following are true:
      --    - The location is in the LOC table.
      --    - The location length is between 1 and 3 characters -- some what of an arbitary check
      --      since we do cannot check the DOOR table as the is no requirement to setup the doors 
      --      in the DOOR table if forklift labor is turned off.
      --
      dbms_output.put_line('forklift labor is not active');

      IF (LENGTH(l_location) BETWEEN 1 and 3) THEN
         l_valid_location_bln := TRUE;
      ELSE
         OPEN c_valid_location(l_location);
         FETCH c_valid_location INTO l_dummy;

         IF (c_valid_location%FOUND) THEN
            l_valid_location_bln := TRUE;
         ELSE
            l_valid_location_bln := FALSE;
         END IF;

         CLOSE c_valid_location;
      END IF;
   END IF;
   
   RETURN l_valid_location_bln;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- If an error return FALSE.
      --
      DBMS_OUTPUT.PUT_LINE(SQLERRM);
      RETURN FALSE;
END is_valid_drop_point;



---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    putaway_main (public)
--
-- Description:
--    Site 2 - This function performs putaway processing when a inbound cross dock
--    pallet is scanned to the staging location or to a door (XDK).
--
--    This function is what the RF calls.
--
--    It will commit or rollback depending on the status.
--
--    Procedure "putaway" is called to do all the work.  "putaway" does not
--    commit or rollback.
--
--    Process Flow:
--
--    The client object "xdock_putaway_client_obj" as of 2/4/22:
--       equip_id                VARCHAR2(10)
--       pallet_id               VARCHAR2(18)
--       task_type               VARCHAR(3)        -- Either PUT or XDK.  To help the host deciding what to do.
--       task_id                 VARCHAR2(10)      -- Either putawaylst.task_id or replenlst.task_id depending on the task_type.
--       dest_loc                VARCHAR2(10)      -- If the task_type is PUT then the staging location.
--
-- Parameters:
--    i_rf_log_init_record
--    i_client_obj           - Client data.
--
-- Return Values:
--    status code
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION putaway_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_putaway_client_obj
   )
RETURN rf.STATUS
IS
   l_object_name      VARCHAR2(30) := 'putaway_main';
   l_rf_status        NUMBER;

   l_r_pallet_info    pl_rf_xdock_pre_putaway.t_r_pallet_info;

BEGIN
   l_rf_status := rf.initialize(i_rf_log_init_record);

   IF (l_rf_status = rf.status_normal) THEN
      --
      -- Initialization
      --

      --
      -- Log starting procedure
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      --
      -- A procedure does all 0the work.
      --
      putaway(i_client_obj  => i_client_obj,
             o_rf_status    => l_rf_status);
   END IF;

   IF (l_rf_status = rf.status_normal) THEN
      COMMIT;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing successful.  COMMIT.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   ELSE
      ROLLBACK;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing failed.  ROLLBACK.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN l_rf_status;
EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   l_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' Returning rf.status_data_error[' || TO_CHAR(rf.status_data_error) || '] to RF.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN rf.status_data_error;
END putaway_main;


---------------------------------------------------------------------------
-- Procedure:
--    putaway (public)
--            (main reason for public is so it can be tested standalone)
--
-- Description:
--    Site 2 - This procedure performs putaway processing when a inbound cross dock
--    pallet is scanned putaway to the staging location or to the outbound door (XDK).
--
--    This procedure does all the work.
--
--    No commit or rollback is made.  It is up to the calling object to commit/rollback.
--
--    Process Flow:
--
--    The client object "xdock_putaway_client_obj" as of 2/4/22:
--       equip_id                VARCHAR2(10)
--       pallet_id               VARCHAR2(18)
--       task_type               VARCHAR(3)        -- Either PUT or XDK.  To help the host deciding what to do.
--       task_id                 VARCHAR2(10)      -- Either putawaylst.task_id or replenlst.task_id depending on the task_type.
--       dest_loc                VARCHAR2(10)      -- If the task_type is PUT then the staging location.
--
-- Parameters:
--    i_client_obj   - Client data.
--    o_rf_status    - Status
--
-- Return Values:
--    status code
--
-- Called By:
--    putaway_main
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE putaway
   (
      i_client_obj                IN   xdock_putaway_client_obj,
      o_rf_status                 OUT  NUMBER
   )
IS
   l_object_name      VARCHAR2(30) := 'putaway';
   l_rf_status        NUMBER;

   l_r_pallet_info    pl_rf_xdock_pre_putaway.t_r_pallet_info;

BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   l_rf_status                := rf.status_normal;
   l_r_pallet_info.pallet_id  := i_client_obj.pallet_id;
   l_r_pallet_info.task_id    := i_client_obj.task_id;

   --
   -- Log the client object sent from the RF.
   --
   log_putaway_client_object(i_client_obj => i_client_obj);

   --
   -- Get pallet info.
   --
   pl_rf_xdock_pre_putaway.get_pallet_info(i_task_type       => i_client_obj.task_type, 
                                           io_r_pallet_info  => l_r_pallet_info,
                                           o_rf_status       => l_rf_status);

   --
   -- Validate the pallet.
   --
   IF (l_rf_status = rf.status_normal)
   THEN
      --
      -- NOTE This procedure is also called by package pl_rf_xdock_pre_putaway.
      --      It does not validate the location.
      --
      IF (i_client_obj.task_type = 'PUT') THEN
         pl_rf_xdock_pre_putaway.validate_pallet(i_r_pallet_info  => l_r_pallet_info,
                                                 o_rf_status      => l_rf_status);
      ELSIF(i_client_obj.task_type = 'XDK') THEN
         NULL;
      END IF;
   END IF;

   --
   -- Validate the destination location scanned by the user.  It needs to match what SWMS is expecting.
   --
   IF (l_rf_status = rf.status_normal)
   THEN
      validate_location(i_client_obj      => i_client_obj,
                        i_r_pallet_info   => l_r_pallet_info,
                        o_rf_status       => l_rf_status);
   END IF;

   --
   -- "Putaway" the pallet.  This could be a PUT to staging or a XDK drop at the door.
   --
   IF (l_rf_status = rf.status_normal) THEN
     null;
      --
      -- Pallet passed validation.  Putaway the pallet which can be a PUT
      -- to the staging location or the drop to the door for XDK.
      --
      putaway_pallet(i_client_obj      => i_client_obj,
                     i_r_pallet_info   => l_r_pallet_info,
                     o_rf_status       => l_rf_status);
   END IF;

   o_rf_status := l_rf_status;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  o_rf_status['             || TO_CHAR(o_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   o_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || '  o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END putaway;


---------------------------------------------------------------------------
-- Function:
--    haul_main (public)
--
-- Description:
--    Site 2 - This function performs putaway processing when a inbound cross dock
--    pallet is hauled.
--
--    This function is what the RF calls.
--
--    It will commit or rollback depending on the status.
--
--    Procedure "haul" is called to do all the work.  "haul" does not
--    commit or rollback.
--
--    Process Flow:
--
-- Parameters:
--    i_rf_log_init_record
--    i_client_obj           - Client data.
--
-- Return Values:
--    status code
--
-- Called By:
--    RF
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/21/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION haul_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_haul_client_obj
   )
RETURN rf.STATUS
IS
   l_object_name      VARCHAR2(30) := 'haul_main';
   l_rf_status        NUMBER;
BEGIN
   l_rf_status := rf.initialize(i_rf_log_init_record);

   IF (l_rf_status = rf.status_normal) THEN
      --
      -- Log starting procedure
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      --
      -- A procedure does all the work.
      --
      haul(i_client_obj  => i_client_obj,
           o_rf_status   => l_rf_status);
   END IF;

   IF (l_rf_status = rf.status_normal) THEN
      COMMIT;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing successful.  COMMIT.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   ELSE
      ROLLBACK;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing failed.  ROLLBACK.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN l_rf_status;
EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   l_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' Returning rf.status_data_error[' || TO_CHAR(rf.status_data_error) || '] to RF.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN rf.status_data_error;
END haul_main;


---------------------------------------------------------------------------
-- Procedure:
--    haul (public)
--         (main reason for public is so it can be tested standalone)
--
-- Description:
--    Site 2 - This procedure performs haul processing when a inbound R1 cross dock
--    pallet is hauled to a location.  The RF prompts the user for a drop point.
--
--    A haul is after the travel button is selected on the RF and the user then selects the
--    haul button.
--    FYI - Before travel the RF user can do an "undo" which is similar to a haul but
--          the RF sends as the drop point the source location of the task.  The haul option is 
--          not available until the RF user selects travel.
--
--    This procedure does all the work.
--
--    No commit or rollback is made.  It is up to the calling object to commit/rollback.
--
--    A haul results in these updates:
--          - If a PUT:
--            No change to the putawaylst record.
--            No change to the XDK replenlst record.
--            If forklift labor is a active:
--               - Update the putaway labor batch kvi_from_loc to the haul location.
--                 The kvi_from_loc needs to include the dock number.  The RF may or may not
--                 include the dock number if the drop point is a door.
--               - Create a HL forklift labor batch from the FP forklift labor batch.
--               - Reset the FP batch.
--                 Pick a new parent batch if the FP batch is a parent batch.
--                 If down to the last batch the put the user on a IFKLFT.
--          - If a XDK:
--            Update replenlst.status from 'PIK' to 'NEW' and clear replenlst.user_id.
--            Update replenlst.src_loc to the haul location.  If the haul location is a door then exclude the
--            dock number if the door includes it.
--            If forklift labor is a active:
--               - Update the putaway labor batch kvi_from_loc to the haul location.
--                 The kvi_from_loc needs to include the dock number.  The RF may or may not
--                 include the dock number if the drop point is a door.
--               - Reset the FU forklift labor batch.
--                 Pick a new parent batch if the FU batch is a parent batch.
--                 Pick a new parent batch if the FP batch is a parent batch.
--                 If down to the last batch the put the user on a IFKLFT.
--
--    Process Flow:
--
-- Parameters:
--    i_client_obj   - Client data.
--    o_rf_status    - Status
--
-- Called By:
--    haul_main
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE haul
   (
      i_client_obj                IN   xdock_haul_client_obj,
      o_rf_status                 OUT  NUMBER
   )
IS
   l_object_name      VARCHAR2(30) := 'haul';

   l_r_pallet_info    pl_rf_xdock_pre_putaway.t_r_pallet_info;
   l_repl_src_loc        replenlst.src_loc%TYPE;


   CURSOR c_repl_door(cp_door VARCHAR2)
   IS
   SELECT physical_door_no              -- xxxxxx 2/23/22 improve on this -- check if FK labor active
     FROM door
    WHERE door_no = cp_door;

BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status                := rf.status_normal;
   l_r_pallet_info.pallet_id  := i_client_obj.pallet_id;
   l_r_pallet_info.task_id    := i_client_obj.task_id;

   --
   -- Log the client object sent from the RF.
   --
   log_haul_client_object(i_client_obj => i_client_obj);

   --
   -- Validate the haul location scanned/keyed by the user.
   -- It needs to be valid door or a valid location.
   --
   IF (is_valid_drop_point(i_location  => i_client_obj.drop_point) = FALSE) THEN
      o_rf_status := rf.status_inv_dest_location;
   END IF;

   --
   -- Drop the pallet at the haul location.
   --
   --
   IF (o_rf_status = rf.status_normal) THEN
     null;
      --
      -- Pallet passed validation.  Putaway the pallet which can be a PUT
      -- to the staging location or the drop to the door for XDK.
      --
--    drop_haul_pallet(i_client_obj      => i_client_obj,
--                     o_rf_status       => o_rf_status);
      IF (i_client_obj.task_type = 'PUT')
      THEN
         --
         -- Haul of a PUT pallet.
         --
         IF (pl_lmf.f_forklift_active = TRUE) THEN
            UPDATE batch b
               SET b.kvi_from_loc = i_client_obj.drop_point
             WHERE b.batch_no =
                         (SELECT p.pallet_batch_no
                            FROM putawaylst p
                           WHERE p.pallet_id = i_client_obj.pallet_id);

         END IF;  -- end if forklift labor active
      ELSIF (i_client_obj.task_type = 'XDK')
      THEN
        --
        -- Haul of XDK pallet.
        --
        -- The replenlst src_loc needs to be the physical door number if
        -- a XDK pallet hauled to a door.
        --
        l_repl_src_loc := NULL;      -- xxxxxx 2/23/22 improve on this -- check if FK labor active
        OPEN c_repl_door(i_client_obj.drop_point);
        FETCH c_repl_door iNTO l_repl_src_loc;
        CLOSE c_repl_door;

        IF (l_repl_src_loc IS NULL) THEN               -- xxxxxx 2/32/22 improve on this
           l_repl_src_loc := i_client_obj.drop_point;
        END IF;

        UPDATE replenlst r
           SET r.src_loc = l_repl_src_loc
         WHERE r.task_id = i_client_obj.task_id
           AND r.type      = 'XDK';

         UPDATE replenlst r                         --- xxxxxx combine with above
            SET status = 'NEW',
                user_id = NULL
          WHERE r.task_id = i_client_obj.task_id;

         --
         -- If forklift labor is active:
         -- Update the bulk pull labor batch source location to the drop point.
         -- If the haul is to a door and forklift labor is active then the door needs to
         -- include the dock number when updating kvi_from_loc.
         --
         IF (pl_lmf.f_forklift_active = TRUE) THEN
            UPDATE batch b
               SET b.kvi_from_loc = i_client_obj.drop_point
             WHERE b.batch_no =
                      (SELECT r.labor_batch_no
                         FROM replenlst r
                        WHERE r.pallet_id = i_client_obj.pallet_id)
               AND b.status =  'F';    -- Sanity check, status should be F. 
         END IF;
      END IF;
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  o_rf_status['             || TO_CHAR(o_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   o_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || '  o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END haul;


---------------------------------------------------------------------------
-- Function:
--    undo_main (public)
--
-- Description:
--    Site 2 - This function performs putaway processing when a inbound cross dock
--    pallet is undoed.
--
--    This function is what the RF calls.
--
--    It will commit or rollback depending on the status.
--
--    Procedure "undo" is called to do all the work.  "undo" does not
--    commit or rollback.
--
--    Process Flow:
--
-- Parameters:
--    i_rf_log_init_record
--    i_client_obj           - Client data.
--
-- Return Values:
--    status code
--
-- Called By:
--    RF
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/21/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION undo_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_putaway_undo_client_obj
   )
RETURN rf.STATUS
IS
   l_object_name      VARCHAR2(30) := 'undo_main';
   l_rf_status        NUMBER;
BEGIN
   l_rf_status := rf.initialize(i_rf_log_init_record);

   IF (l_rf_status = rf.status_normal) THEN
      --
      -- Log starting procedure
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      --
      -- A procedure does all the work.
      --
      undo(i_client_obj  => i_client_obj,
           o_rf_status    => l_rf_status);
   END IF;

   IF (l_rf_status = rf.status_normal) THEN
      COMMIT;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing successful.  COMMIT.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   ELSE
      ROLLBACK;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Processing failed.  ROLLBACK.'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  l_rf_status['             || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN l_rf_status;
EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   l_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || ' Returning rf.status_data_error[' || TO_CHAR(rf.status_data_error) || '] to RF.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   rf.complete(l_rf_status);
   RETURN rf.status_data_error;
END undo_main;


---------------------------------------------------------------------------
-- Procedure:
--    undo (public)
--            (main reason for public is so it can be tested standalone)
--
-- Description:
--    Site 2 - This procedure performs undo processing when a inbound R1 cross dock
--    pallet is "undone".
--
--    The RF user can decide not to do the PUT/XDK for the pallet.  If this is before
--    travel button is selected then we consider this an "undo".  The pallet will remain
--    at it's current location.
--    FYI - The user can do the same after the travel button is selected which we call
--          a haul.  There is a different processing for a haul as the RF will prompt
--          the user for a drop point.
--
--    This procedure does all the work.
--
--    No commit or rollback is made.  It is up to the calling object to commit/rollback.
--
--    A undo results in these updates:
--       - Before travel:
--          - If a PUT
--            No change to the putawaylst record.
--            If forklift labor is a active
--               - Reset the putaway forklift labor batch(FP batch).
--               - If needed pick a new parent batch or if down to the last batch put user on IFKLFT.
--          - If a XDK
--            Update replenlst.status from 'PIK' to 'NEW' and clear replenlst.user_id.
--            If forklift labor is a active
--               - Reset the putaway forklift labor batch(FU batch).
--               - If needed pick a new parent batch or if down to the last batch put user on IFKLFT.
--         
--       - After travel:
--          - If a PUT
--            No change to the putawaylst record.
--            If forklift labor is a active
--               - Update the putaway labor batch kvi_from_loc to the undo location.
--               - Reset the putaway forklift labor batch(FP batch).
--               - If needed pick a new parent batch or if down to the last batch put user on IFKLFT.
--          - If a XDK
--            Update replenlst.status from 'PIK' to 'NEW' and clear replenlst.user_id.
--            Update replenlst.src_loc to the undo location.
--            If forklift labor is a active
--               - Update the FU labor batch kvi_from_loc to the undo location.
--               - Reset the FU forklift labor batch.
--               - If needed pick a new parent batch or if down to the last batch put user on IFKLFT.
--
--    Process Flow:
--
-- Parameters:
--    i_client_obj   - Client data.
--    o_rf_status    - Status
--
-- Called By:
--    undo_main
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/27/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE undo
   (
      i_client_obj                IN   xdock_putaway_undo_client_obj,
      o_rf_status                 OUT  NUMBER
   )
IS
   l_object_name      VARCHAR2(30) := 'undo';

   l_r_pallet_info    pl_rf_xdock_pre_putaway.t_r_pallet_info;

BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type[' ||  i_client_obj.task_type || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status                := rf.status_normal;
   l_r_pallet_info.pallet_id  := i_client_obj.pallet_id;
   l_r_pallet_info.task_id    := i_client_obj.task_id;

   --
   -- Log the client object sent from the RF.
   --
   log_undo_client_object(i_client_obj => i_client_obj);

   --
   -- Validate the haul location scanned/keyed by the user.
   -- It needs to be valid door or a valid location or a valid bay--DA01.
   --
   -- xxxxxxxx

   --
   -- Pallet undo with a drop point specified is same proceossing at a haul as far
   -- as the task goes.  Forklfit labor is different though as we create a HX instead of a HL batch.
   IF (    (i_client_obj.drop_point IS NOT NULL)
       AND (is_valid_drop_point(i_location   => i_client_obj.drop_point) = FALSE))
   THEN
      o_rf_status := rf.status_inv_dest_location;
   END IF;

   --
   -- Undo
   --
   IF (o_rf_status = rf.status_normal) THEN
      --
      -- Pallet passed validation .
      -- Undo the pallet.
      --
      IF (i_client_obj.task_type = 'PUT') THEN
        UPDATE batch b
           SET b.kvi_from_loc = i_client_obj.drop_point
         WHERE b.batch_no =
                  (SELECT p.pallet_batch_no
                     FROM putawaylst p
                    WHERE p.pallet_id = i_client_obj.pallet_id);

        UPDATE replenlst r
           SET r.src_loc = i_client_obj.drop_point
         WHERE r.pallet_id = i_client_obj.pallet_id
           AND r.type      = 'XDK';

        UPDATE batch b
           SET b.kvi_from_loc = i_client_obj.drop_point
         WHERE b.batch_no =
                  (SELECT r.labor_batch_no
                     FROM replenlst r
                    WHERE r.pallet_id = i_client_obj.pallet_id)
           AND b.status =  'F';    -- Sanity check, status should be F. 
      ELSIF (i_client_obj.task_type = 'XDK') THEN  ----- xxxxxxxxxxxxx !!!!!!! finish this and  handle PUT and handle forklift labor
         UPDATE replenlst r
            SET status = 'NEW',
                user_id = NULL
          WHERE r.task_id = i_client_obj.task_id;

      END IF;
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id['  || i_client_obj.pallet_id || ']'
                      || '  i_client_obj.task_type['  || i_client_obj.task_type || ']'
                      || '  o_rf_status['             || TO_CHAR(o_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
   --
   -- Oracle error.  Log a message and return data error.
   --
   o_rf_status := rf.status_data_error;

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']'
                             || '  o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END undo;


END pl_rf_xdock_putaway;    -- end package body
/


CREATE OR REPLACE PUBLIC SYNONYM pl_rf_xdock_putaway FOR swms.pl_rf_xdock_putaway;

GRANT EXECUTE ON swms.pl_rf_xdock_putaway TO SWMS_USER;


