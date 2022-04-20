
-------------------------
-------------------------
-- Packge Specification
-------------------------
-------------------------

CREATE OR REPLACE PACKAGE swms.pl_rf_xdock_pre_putaway
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_rf_xdock_pre_putaway
--
-- Description:
--    This package has the procedure/functions, etc for the pre putaway process
--    for R1 Site 2.
--
--    The main entry point to this package is function "pre_putaway_main".
--
--    Process Flow:
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

--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------

--
-- Cursor to retrieve info about the XN pallet from PUTAWAYLST.
-- It will have all the info needed by the RF for putaway of the XN pallet to the
-- staging location and to create the PPU transaction.
-- It will have all the info needed to drop a XDK to the door.
-- Used the the "pre putaway" processing and in the "putaway" processing.
-- PPU and PUX transactions created using this data.
--
-- For the "XDK" drop to door a record of this cursor type is used to store data
-- from REPLENLST.
--
CURSOR g_c_pallet_info(cp_pallet_id  putawaylst.pallet_id%TYPE)
IS
SELECT p.pallet_id                  pallet_id,
       p.task_id                    task_id,
       p.rec_id                     rec_id,
       p.putaway_put                putaway_put,
       p.prod_id                    prod_id,
       p.cust_pref_vendor           cust_pref_vendor,
       NVL(pm.descrip, 'MULTI')     descrip,            -- Null pm.descrip implies the prod_id is 'MULTI'.
       p.dest_loc                   src_loc,            -- Place for the src_loc.  For a putaway this will be the haul location if pallet hauled otherwise the erm.door_no.
       p.dest_loc                   dest_loc,           -- For a XDK this will be the outbound door number.
       p.inv_dest_loc               inv_dest_loc,
       p.door_no                    door_no,            -- For a XDK this will be the outbound door number.
       erm.door_no                  erm_door_no,
       p.putpath                    putpath,
       p.uom                        uom,                -- Number of pieces on the pallet.
       p.qty                        qty,                -- Number of pieces on the pallet.
       p.qty_expected               qty_expected,       -- Might not use this.
       p.qty_received               qty_received,       -- Might not use this.
       p.exp_date                   exp_date,           -- For the PPU/PUX transsaction.
       p.mfg_date                   mfg_date,           -- For the PPU/PUX transsaction.
       p.lot_id                     lot_id,             -- For the PPU/PUX transsaction.  Probably always null.
       1                            spc,                -- SPC always 1 for Site 2 cross dock pallet.
       p.pallet_batch_no            pallet_batch_no,    -- Forklift putaway labor batch number(FP batch).  Populated when forklfit labor is active. 
                                                        -- trans.labor_batch_no for th PPU and PUX transaction.
       erm.erm_type                 erm_type,
       erm.status                   erm_status,
       'X'                          cross_dock_type     -- Always 'X', ideally this would come from putawaylst if we had this column in the table.
  FROM putawaylst p,
       erm,
       pm
 WHERE p.pallet_id              = cp_pallet_id
   AND erm.erm_id           (+) = p.rec_id
   AND pm.prod_id           (+) = p.prod_id              -- Outer join because putawaylst.prod_id could be 'MULTI'
   AND pm.cust_pref_vendor  (+) = p.cust_pref_vendor;


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------

SUBTYPE t_r_pallet_info  IS  pl_rf_xdock_pre_putaway.g_c_pallet_info%ROWTYPE;


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    pre_putaway_main (public)
--
-- Description:
--    This function performs the pre putaway processing when a R1 cross dock
--    pallet is scanned for putaway at Site 2.
--
--   This function is what the RF calls.
--
--   It will commit or rollback depending on the status.
--
--   Procedure "pre_putaway" is called to do all the work.  "pre_putaway" does not
--   commit or rollback.
---------------------------------------------------------------------------
FUNCTION pre_putaway_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_pre_putaway_client_obj,
      o_server                    OUT     xdock_pre_putaway_server_obj
   )
RETURN rf.STATUS;

---------------------------------------------------------------------------
-- Procedure:
--    pre_putaway (public)
--                (main reason for public is so it can be tested standalone)
--
-- Description:
--    This procedure does all the work.
--    It is called by "pre_putaway_main".
--    It does not commit or rollback.
---------------------------------------------------------------------------
PROCEDURE pre_putaway
   (
      i_client_obj                IN      xdock_pre_putaway_client_obj,
      o_server                    IN OUT  xdock_pre_putaway_server_obj,
      o_rf_status                 OUT     NUMBER
   );

---------------------------------------------------------------------------
-- Procedure:
--    get_pallet_info (public)
--
-- Description:
--    This procedure retrieves the Site 2 R1 Xdock pallet when scanned for putaway
---------------------------------------------------------------------------
PROCEDURE get_pallet_info
   (
      i_task_type       IN      VARCHAR2,
      io_r_pallet_info  IN OUT  t_r_pallet_info,
      o_rf_status       OUT     NUMBER
   );

---------------------------------------------------------------------------
-- Procedure:
--    validate_pallet (public)
--                    (main reason for public is so it can be tested standalone)
--
-- Description:
--    This procedure validates the Site 2 R1 Xdock pallet when scanned for putaway.
---------------------------------------------------------------------------
PROCEDURE validate_pallet
   (
      i_r_pallet_info  IN   t_r_pallet_info,
      o_rf_status      OUT  NUMBER
   );

---------------------------------------------------------------------------
-- Procedure:
--    get_pre_putaway_info (public)
--                         (main reason for public is so it can be tested standalone)
--
-- Description:
--    This procedure retrieves the "pre putaway" info required by the RF.
---------------------------------------------------------------------------
PROCEDURE get_pre_putaway_info
   (
      i_r_pallet_info  IN OUT   t_r_pallet_info,
      io_server        IN OUT   xdock_pre_putaway_server_obj,
      o_rf_status      OUT      NUMBER
   );

END pl_rf_xdock_pre_putaway;   -- end package spec
/


-------------------------
-------------------------
-- Packge Body
-------------------------
-------------------------

CREATE OR REPLACE PACKAGE BODY swms.pl_rf_xdock_pre_putaway
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
--    log_client_object (private)
--
-- Description:
--    This procedure logs the client object for researching/debugging.
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
PROCEDURE log_client_object
   (
      i_client_obj   IN   xdock_pre_putaway_client_obj
   )
IS
   l_object_name     VARCHAR2(30)      := 'log_client_object';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                              -- Messsage buffer
BEGIN
   l_message := 'client object sent from RF:'
             || ' equip_id['      ||  i_client_obj.equip_id    || ']'
             || ' pallet_id['     ||  i_client_obj.pallet_id   || ']'
             || ' merge_flag['    ||  i_client_obj.merge_flag  || ']'
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
END log_client_object;



-------------------------------------------
-- PROCEDURE show_server_object     -- private
-- Procedure for unit testing.
--
-------------------------------------------
PROCEDURE show_server_object
   (
      i_server   IN   xdock_pre_putaway_server_obj
   )
IS
BEGIN
   dbms_output.put_line
           (
                'i_server:'
             || ' pallet_id['          || i_server.pallet_id         || ']'
             || ' task_type['          || i_server.task_type         || ']'
             || ' task_id['            || i_server.task_id           || ']'
             || ' prod_id['            || i_server.prod_id           || ']'
             || ' cpv['                || i_server.cpv               || ']'
             || ' descrip['            || i_server.descrip           || ']'
             || ' src_loc['            || i_server.src_loc           || ']'
             || ' dest_loc['           || i_server.dest_loc          || ']'
             || ' door_no['            || i_server.door_no           || ']'
             || ' put_path_val['       || i_server.put_path_val      || ']'
             || ' spc['                || i_server.spc               || ']'
             || ' qty['                || i_server.qty               || ']'
             || ' cross_dock_type['    || i_server.cross_dock_type   || ']'
             || ' route_no['           || i_server.route_no          || ']'
             || ' truck_no['           || i_server.truck_no          || ']'
             || ' float_seq['          || i_server.float_seq         || ']'
             || ' brand['              || i_server.brand             || ']'
             || ' bp_type['            || i_server.bp_type           || ']'
             || ' pack['               || i_server.pack              || ']'
             || ' batch_no['           || i_server.batch_no          || ']'
             || ' catch_wt_trk['       || i_server.catch_wt_trk      || ']'
             || ' avg_wt['             || i_server.avg_wt            || ']'
             || ' tolerance['          || i_server.tolerance         || ']'
             || ' numcust['            || i_server.NumCust           || ']'
             || ' instructions['       || i_server.instructions      || ']'
             || ' priority['           || i_server.priority          || ']'
             || ' order_seq['          || i_server.order_seq         || ']'
             || ' order_id['           || i_server.order_id          || ']'
             || ' inv_date['           || i_server.inv_date          || ']'
             || ' cust_id['            || i_server.cust_id           || ']'
             || ' cust_name['          || i_server.cust_name         || ']'
             || ' stopno['             || i_server.stop_no           || ']'
          );
END show_server_object;


---------------------------------------------------------------------------
-- Procedure:
--    log_server_object (private)
--
-- Description:
--    This procedure logs the server object.for researching/debugging.
--
-- Parameters:
--    i_server   -   xdock_pre_putaway_server_obj
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/09/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
---------------------------------------------------------------------------
PROCEDURE log_server_object
   (
      i_server   IN   xdock_pre_putaway_server_obj
   )
IS
   l_object_name     VARCHAR2(30)      := 'log_server_object';   -- Procedure name, used in log messages
   l_message         VARCHAR2(1500);                             -- Messsage buffer
BEGIN
   l_message := 'server object sent to RF:'
             || ' pallet_id['          || i_server.pallet_id         || ']'
             || ' task_type['          || i_server.task_type         || ']'
             || ' task_id['            || i_server.task_id           || ']'
             || ' prod_id['            || i_server.prod_id           || ']'
             || ' cpv['                || i_server.cpv               || ']'
             || ' descrip['            || i_server.descrip           || ']'
             || ' src_loc['            || i_server.src_loc           || ']'
             || ' dest_loc['           || i_server.dest_loc          || ']'
             || ' door_no['            || i_server.door_no           || ']'
             || ' put_path_val['       || i_server.put_path_val      || ']'
             || ' spc['                || i_server.spc               || ']'
             || ' qty['                || i_server.qty               || ']'
             || ' cross_dock_type['    || i_server.cross_dock_type   || ']'
             || ' route_no['           || i_server.route_no          || ']'
             || ' truck_no['           || i_server.truck_no          || ']'
             || ' float_seq['          || i_server.float_seq         || ']'
             || ' brand['              || i_server.brand             || ']'
             || ' bp_type['            || i_server.bp_type           || ']'
             || ' pack['               || i_server.pack              || ']'
             || ' batch_no['           || i_server.batch_no          || ']'
             || ' catch_wt_trk['       || i_server.catch_wt_trk      || ']'
             || ' avg_wt['             || i_server.avg_wt            || ']'
             || ' tolerance['          || i_server.tolerance         || ']'
             || ' numcust['            || i_server.NumCust           || ']'
             || ' instructions['       || i_server.instructions      || ']'
             || ' priority['           || i_server.priority          || ']'
             || ' order_seq['          || i_server.order_seq         || ']'
             || ' order_id['           || i_server.order_id          || ']'
             || ' inv_date['           || i_server.inv_date          || ']'
             || ' cust_id['            || i_server.cust_id           || ']'
             || ' cust_name['          || i_server.cust_name         || ']'
             || ' stopno['             || i_server.stop_no           || ']';

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
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred.  i_server.pallet_id[' ||  i_server.pallet_id || ']'
                             || ' This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END log_server_object;


------------------------------------------------
-- PROCEDURE assign_set_put_info   -- private
/***
  These are the fields to populate in the server object.
   pallet_id               VARCHAR2(18),
   task_type               VARCHAR(3),        -- 'PUT'.  Set by host.  For the RF to use in deciding what to do.
   task_id                 VARCHAR2(10),      -- Either putawaylst.task_id or replenlst.task_id depending on the task_type.
   prod_id                 VARCHAR2(9),       -- If one item on the pallet then the prod_id otherwise 'MULTI'.
   cpv                     VARCHAR2(10),      -- If one cpv on the pallet then the cpv otherwise '-'.
   descrip                 VARCHAR2(30),      -- If one item on the pallet then the pm.descrip otherwise 'MULTI'.
   --
   src_loc                 VARCHAR2(10),      -- Current location of the pallet.  Could be a door/haul location/staging location.
   dest_loc                VARCHAR2(10),      -- If the pallet is going to a staging location then the staging location, for a XDK the door number.
   door_no                 VARCHAR2(4),       -- If the pallet is going to a door--XDK--then the door number otherwise null 
   --
   put_path_val            VARCHAR2(10),      -- If the pallet is going to a staging location then the put path of the staging locations otherwise '000000000' ???.
   spc                     VARCHAR2(5),       -- hmmmmm, don't really need since the pallet can have multiple items.  Always set to 1.
   qty                     VARCHAR2(7),       -- The number of pieces on the pallet.
**/
------------------------------------------------
PROCEDURE assign_pre_putaway_put_info
   (
      i_r_pallet_info  IN OUT   t_r_pallet_info,
      io_server        IN OUT   xdock_pre_putaway_server_obj,
      o_rf_status      OUT      NUMBER
   )
IS
   l_object_name     VARCHAR2(30) := 'assign_pre_putaway_put_info';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                                   -- Message buffer
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || '  User will be performing the put.  Assign putaway info to the server object.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   io_server.pallet_id       := i_r_pallet_info.pallet_id;
   io_server.task_type       := 'PUT';
   io_server.task_id         := i_r_pallet_info.task_id;
   io_server.prod_id         := i_r_pallet_info.prod_id;
   io_server.cpv             := i_r_pallet_info.cust_pref_vendor;
   io_server.descrip         := i_r_pallet_info.descrip;
   io_server.src_loc         := i_r_pallet_info.src_loc;
   io_server.dest_loc        := i_r_pallet_info.dest_loc;
   io_server.door_no         := i_r_pallet_info.door_no;
   io_server.put_path_val    := i_r_pallet_info.putpath;
   io_server.spc             := i_r_pallet_info.spc;
   io_server.qty             := i_r_pallet_info.qty;
   io_server.cross_dock_type := i_r_pallet_info.cross_dock_type;
   io_server.bp_type         := 'B';                               -- RF needs a good value so use B' for a PUT.
   io_server.numcust         := '1';                               -- RF needs a value
   io_server.priority        := '50';                              -- RF needs a value
   io_server.order_seq       := '0';                               -- RF needs a value
   io_server.inv_date        := TO_CHAR(SYSDATE, 'MMDDYY');        -- RF needs a value

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and return data error.
      --

      o_rf_status := rf.status_data_error;

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
END assign_pre_putaway_put_info;


---------------------------------------------------------------------------
-- Function:
--    does_pallet_have_new_xdk_task (private)
--
-- Description:
--    This function determines if a pallet has a XDK task in NEW status.
--
--    Having a XDK task implies floats data sent from Site 1 to Site 2,
--    the staging data is processed and the route is open at Site 2.
--
-- Parameters:
--    i_pallet_id - Site 2 xdock pallet.
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
FUNCTION does_pallet_have_new_xdk_task(i_pallet_id  IN  floats.pallet_id%TYPE)
RETURN BOOLEAN
IS
   l_object_name       VARCHAR2(30) := 'does_pallet_have_new_xdk_task';   -- Function name, used in log messages
   l_return_value      BOOLEAN;

   l_count             PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM v_xdock_put_xdk
    WHERE pallet_id = i_pallet_id
      AND status    = 'NEW';

   IF (l_count > 0) THEN
      l_return_value := TRUE;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Pallet has XDK task in NEW status.  Return TRUE.'
                              || '  pallet_id['            || i_pallet_id          || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   ELSE
      l_return_value := FALSE;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Pallet has no XDK task in NEW status or has no XDK.  Return FALSE.'
                              || '  pallet_id['            || i_pallet_id          || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END IF;

   RETURN l_return_value;

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and re-raise exception.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing i_pallet_id [' ||  i_pallet_id || ']'
                             || 'Re-raise exception',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      RAISE;
END does_pallet_have_new_xdk_task;


---------------------------------------------------------------------------
-- Procedure:
--    insert_trans (private)
--
-- Description:
--    This procedures inserts either the PPU or PFK transaction depending if the
--    inbound pallet is going to the staging location or to the outbound door.
--
-- Parameters:
--    i_r_pallet_info  - Pallet info.  has info needed to create the transaction.
--    i_server         - Pallet object.  It has info needed to create the transaction.
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
--    02/04/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE insert_trans
   (
      i_r_pallet_info   IN   t_r_pallet_info,
      i_server          IN   xdock_pre_putaway_server_obj,
      o_rf_status       OUT  NUMBER
   )
IS
   l_object_name     VARCHAR2(30)      := 'insert_trans';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(256);                         -- Messsage buffer
BEGIN
   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   IF (i_server.task_type = 'PUT') THEN
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
                  'PPU',                               -- trans_type
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
                  i_r_pallet_info.pallet_batch_no,     -- labor_batch_no
                  null,                                -- scan_method1     2/16/22 don't have this yet, forgot it.
                  null,                                -- scan_method2     2/16/22 don't have this yet, forgot it.
                  i_r_pallet_info.cross_dock_type,     -- cross_dock_type
                  'THE TRANSACTION QTY IS THE NUMBER OF PIECES ON THE PALLET'   -- cmt
                 );
   ELSIF (i_server.task_type = 'XDK') THEN
      --
      -- Insert PFK transaction.
      -- There is a database trigger that inserts the PFK when the status changes to PIK.
      --
      UPDATE replenlst
         SET status  = 'PIK',
             user_id = REPLACE(USER,'OPS$')
       WHERE task_id = i_server.task_id;

      -- xxxxx add checking if record updated.
   ELSE
      --
      -- Unexpected value for i_server.task_type -xxxxxxxxxxxx
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
--    cancel_put_task (private)
--
-- Description:
--    This procedures cancels the PUT task.
--    This happens if the user is directed to do the XDK instaad of the PUT.
--    The PUT is no longer necessary.  If the PUT task shows completed for whatever reason
--    then it is left alone--at this point in processing the put task should be not complete.
--
--    2/25/22 As of today the definition of cancelling the PUT task is to delete it.
--
-- Parameters:
--    i_r_pallet_info  - Pallet info.
--    o_rf_status      - Insert succedded or failed
--                      Set To                           When
--                      --------------------------------------------------------------------
--                      rf.status_data_error             Task type not PUT or XDK.
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/24/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE cancel_put_task
   (
      i_r_pallet_info   IN   t_r_pallet_info,
      o_rf_status       OUT  NUMBER
   )
IS
   l_object_name     VARCHAR2(30)      := 'cancel_put_task';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(256);                            -- Messsage buffer
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || '  This procedures cancels the PUT task.'
                      || '  This happens if the user is directed to do the XDK task instead of the PUT task.'
                      || '  As of today 25-FEB-2022 the definition of cancelling the PUT task is to delete it.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   IF (i_r_pallet_info.pallet_id is NOT NULL)
   THEN
      DELETE
        FROM putawaylst p
       WHERE p.pallet_id   = i_r_pallet_info.pallet_id
         AND p.putaway_put = 'N';

      IF (SQL%FOUND) THEN
         pl_log.ins_msg
                 (i_msg_type         => pl_log.ct_info_msg,
                  i_procedure_name   => l_object_name,
                  i_msg_text         => 'Cancelled PUT task by deleting PUTAWAYLST record.'
                             || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']',
                  i_msg_no           => NULL,
                  i_sql_err_msg      => NULL,
                  i_application_func => ct_application_function,
                  i_program_name     => gl_pkg_name,
                  i_msg_alert        => 'N');
      ELSE
         pl_log.ins_msg
                 (i_msg_type         => pl_log.ct_warn_msg,
                  i_procedure_name   => l_object_name,
                  i_msg_text         => 'Cancelled PUT task failed.'
                             || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                             || '  The record does not exist in PUTAWAYLST or putaway_put is not N.'
                             || '  This will not stop processing.',
                  i_msg_no           => NULL,
                  i_sql_err_msg      => NULL,
                  i_application_func => ct_application_function,
                  i_program_name     => gl_pkg_name,
                  i_msg_alert        => 'N');
      END IF;
   END IF;

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || '  o_rf_status['               || TO_CHAR(o_rf_status)       || ']',
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
                i_msg_text         => 'Error occurred processing i_r_pallet_info.pallet_id [' ||  i_r_pallet_info.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END cancel_put_task;


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    get_pallet_info (public)
--
-- Description:
--    This procedure retrieves info about the pallet scanned for putaway.
--    No validation is done here other than the pallet not existing in putawaylst.
--
-- Parameters:
--    i_task_type      - Task type--PUT or XDK
--    io_r_pallet_info - Pallet info.
--    o_rf_status      - Did validation pass or fail.
--                       Set To                   When
--                       --------------------------------------------------------------------
--                       rf.status_normal         Passed valiation.
--                       rf.status_inv_label      Pallet not in putawaylst.
--                       rf.status_data_error     Unexpected error
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/04/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE get_pallet_info
   (
      i_task_type       IN       VARCHAR2,
      io_r_pallet_info  IN OUT   t_r_pallet_info,
      o_rf_status       OUT      NUMBER
   )
IS
   l_object_name     VARCHAR2(30) := 'get_pallet_info';   -- Procedure name, used in log messages
   l_message         VARCHAR2(512);                       -- Message buffer

   l_r_pallet_info   t_r_pallet_info;
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_task_type['                ||  i_task_type                || ']'
                      || '  io_r_pallet_info.pallet_id[' ||  io_r_pallet_info.pallet_id || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   IF (i_task_type = 'PUT') THEN
      --
      -- User performing a putaway.
      -- Retrieve info about the pallet from PUAWAYLST.
      --
      OPEN g_c_pallet_info(io_r_pallet_info.pallet_id);
        --
        -- Pallet found in PUAWAYLST table.
        -- Log message.
        --
      FETCH g_c_pallet_info INTO io_r_pallet_info;
      
      IF (g_c_pallet_info%FOUND) THEN
         --
         -- Pallet in PUAWAYLST table.
         --
         --
         -- Need to assign the src_loc for the putaway.
         -- For a putaway this will be the haul location if pallet hauled otherwise the erm.door_no.
         --
         io_r_pallet_info.src_loc := NVL(pl_rcv_po_close.f_get_haul_location(io_r_pallet_info.pallet_id), NVL(io_r_pallet_info.door_no, io_r_pallet_info.erm_door_no));

         --
         -- Log info about the pallet.
         --
         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Found pallet in PUTAWAYLST.'
                       || '  pallet_id['            || io_r_pallet_info.pallet_id          || ']'
                       || '  putaway_put['          || io_r_pallet_info.putaway_put        || ']'
                       || '  prod_id['              || io_r_pallet_info.prod_id            || ']'
                       || '  cust_pref_vendor['     || io_r_pallet_info.cust_pref_vendor   || ']'
                       || '  descrip['              || io_r_pallet_info.descrip            || ']'
                       || '  src_loc['              || io_r_pallet_info.src_loc            || ']'
                       || '  dest_loc['             || io_r_pallet_info.dest_loc           || ']'
                       || '  door_no['              || io_r_pallet_info.door_no            || ']'
                       || '  putpath['              || TO_CHAR(io_r_pallet_info.putpath)   || ']'
                       || '  qty['                  || TO_CHAR(io_r_pallet_info.qty)       || ']'
                       || '  rec_id['               || io_r_pallet_info.rec_id             || ']'
                       || '  erm_type['             || io_r_pallet_info.erm_type           || ']'
                       || '  erm_status['           || io_r_pallet_info.erm_status         || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      ELSE
         --
         -- Pallet not in PUAWAYLST table.
         -- Log message.
         -- Return invalid lp error to RF.
         --
         o_rf_status := rf.status_inv_label;

         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Pallet not in PUTAWAYLST.'
                           || '  pallet_id['   || io_r_pallet_info.pallet_id  || ']'
                           || '  o_rf_status[' || TO_CHAR(o_rf_status)        || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      END IF;

      CLOSE g_c_pallet_info;
   ELSE
      --
      -- i_task_type = 'XDK';
      -- User performing a XDK.
      -- Info comes from REPLENLST.  Populate both the dest_loc and door_no with the door.
      --
      SELECT r.door_no,
             r.door_no
        INTO io_r_pallet_info.dest_loc,
             io_r_pallet_info.door_no
        FROM replenlst r
       WHERE r.task_id = io_r_pallet_info.task_id;
     -- xxxxxx add exception handling
   END IF;

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_task_type['                ||  i_task_type                || ']'
                      || '  io_r_pallet_info.pallet_id[' ||  io_r_pallet_info.pallet_id || ']'
                      || '  o_rf_status['                || TO_CHAR(o_rf_status)        || ']',
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
      IF (g_c_pallet_info%ISOPEN) THEN    -- Cursor cleanup
         CLOSE g_c_pallet_info;   
      END IF;

      o_rf_status := rf.status_data_error;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred processing io_r_pallet_info.pallet_id [' ||  io_r_pallet_info.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END get_pallet_info;

---------------------------------------------------------------------------
-- Procedure:
--    validate_pallet (public)
--                    (main reason for public is so it can be tested standalone)
--
-- Description:
--    This procedure validates the Site 2 R1 Xdock pallet when scanned for putaway.
--
--    Rules:
--    1.  The pallet exists in putawaylst on a XN and has not been putaway and it
--        has a valid putawaylst dest loc.
--      OR
--    2.  The pallet exists in replenlst as a XDK task (replenlst.cross_dock_type = 'X')
--        and the task has not been done and selection has started on the route.
--
-- Parameters:
--    i_r_pallet_info - Pallet info.
--    o_rf_status     - Did validation pass or fail.
--                      Set To                   When
--                      --------------------------------------------------------------------
--                      rf.status_normal         Passed valiation.
--                      rf.status_inv_label     Pallet not in replenlst. hmmmm   xxxx  maybe don't check this
--                      rf.status_put_done       Pallet already putaway.
--                                               If the putaway already done and there is a XDK 
--                                               task for the pallet we still return putaway already done.
--                                               The user will need to go to the bulk pull screen on the RF.
--                      rf.status_unavl_po;      Not a XN.  -- 02/04/22 xxxxxxx what status to use ???
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/01/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE validate_pallet
   (
      i_r_pallet_info  IN    t_r_pallet_info,
      o_rf_status      OUT   NUMBER
   )
IS
   l_object_name     VARCHAR2(30) := 'validate_pallet';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(512);                       -- Message buffer
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   --
   -- Check that it is a XN.
   -- Check the dest_loc is valid--not '*' or 'LR'.  Though should never be 'LR'.
   -- Check if it is already putaway.
   -- If it is already putaway then check if there is an XDK and the route is being selected
   -- and if so then have the user do the XDK.
   -- If it is already putaway then check if there is an XDK and the route is NOT being selected
   -- and if so have already putaway.
   --
   IF (NVL(i_r_pallet_info.erm_type, 'x') <> 'XN') THEN    -- NVL in case the PO is not is ERM.
      -- 
      -- The pallet is in PUTAWAYLST but it is not on a XN.
      -- 
      o_rf_status := rf.status_unavl_po;    -- 02/04/22 xxxxxxx what status to use ???

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Pallet ' ||  i_r_pallet_info.pallet_id
                      || ' is on PO/SN [' ||  i_r_pallet_info.rec_id || '], erm type [' || i_r_pallet_info.erm_type || ']'
                      || ' which is not a XN.  This operation is only for pallets on a XN.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   IF ((o_rf_status = rf.status_normal) AND (i_r_pallet_info.putaway_put = 'Y')) THEN
      --
      -- Pallet already putaway.
      --
      o_rf_status := rf.status_put_done;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Pallet ' || i_r_pallet_info.pallet_id
                        || ' already putaway.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
   END IF;

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
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
      IF (g_c_pallet_info%ISOPEN) THEN    -- Cursor cleanup
         CLOSE g_c_pallet_info;   
      END IF;

      o_rf_status := rf.status_data_error;

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
END validate_pallet;


---------------------------------------------------------------------------
-- Function:
--    is_selection_started_for_route (public)
--                                   (main reason for public is so it can be tested standalone)
--
-- Description:
--    Site 2 - This determine determines if selection has started for the route
--    the cross dock pallet is going out on.
--
--    Selection has started for the route if any of the following are true:
--       - The route has one or more normal selection batches that are active or complete.
--       - The route has only bulk pull batches and there is a DFK for a pallet on the route.
--
-- Parameters:
--    i_pallet_id - Site 2 cross dock pallet.
--
-- Return Values:
--    TRUE  - Selection has started for the route.
--    FALSE - Selection has not started for the route or encountered an error.
--            Returning FALSE for an error should be fine as we will
--            direct the pallet to the staging location.
--
-- Called By:
--
-- Exceptions Raised:
--    xxxxxxx
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/01/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION is_selection_started_for_route
   (
      i_pallet_id  IN  putawaylst.pallet_id%TYPE
   )
RETURN BOOLEAN
IS
   l_object_name     VARCHAR2(30) := 'is_selection_started_for_route';   -- Procedure name, used in log messages.
   l_message         VARCHAR2(512);                                      -- Messsage buffer

   l_rec_count       PLS_INTEGER;     -- work area
   l_return_value    BOOLEAN;

   --
   -- This cursor gets counts of the SOS batches for the route the pallet is on.
   --
   CURSOR c_sos(cp_pallet_id  floats.pallet_id%TYPE)
   IS
   SELECT MIN(float_route.route_no)   route_no,
          COUNT(sb.status)            total_count,
          SUM((CASE
                 WHEN sb.status = 'F' THEN 1
                 ELSE 0
              END))                   future_count,
          SUM((CASE
                 WHEN sb.status = 'A' THEN 1
                 ELSE 0
              END))                   in_progress_count,
          SUM((CASE
                 WHEN sb.status = 'C' THEN 1
                 ELSE 0
              END))                   completed_count,
          SUM((CASE
                 WHEN sb.status = 'F'   THEN 0
                 WHEN sb.status = 'A'   THEN 0
                 WHEN sb.status = 'C'   THEN 0
                 WHEN sb.status IS NULL THEN 0
                 ELSE 1
              END))                other_count
    FROM sos_batch sb,
         floats f,
         --
         -- start inline view to get the route the pallet is on.
        (SELECT f2.route_no
           FROM floats f2
          WHERE f2.parent_pallet_id = cp_pallet_id) float_route    -- 2/10/22 Could also use xdock_pallet_id instead of parent_pallet_id
                                                                   -- but xdock_paallet_id is not indexed.
                                                                   -- We cannot use floats.pallet_id as this is the Site 1 value.
         -- end inline view
         --
    WHERE sb.batch_no (+) = TRIM(TO_CHAR(f.batch_no))
      AND f.route_no      = float_route.route_no;

   l_r_sos c_sos%ROWTYPE; 

   --
   -- This cursor checks for a DFK transaction for the route the pallet is on.
   -- A DFK transaction indicates a bulk bull was done for the route.
   -- The DFK trans.float_no is populated.
   --
   CURSOR c_trans_dfk_count(cp_pallet_id  floats.pallet_id%TYPE)
   IS
   SELECT COUNT(*) rec_count
     FROM v_trans t, floats f
    WHERE t.route_no    = (select f.route_no FROM floats f WHERE f.parent_pallet_id = cp_pallet_id)
      AND t.float_no    = f.float_no
      AND f.pallet_pull <> 'R'         -- leave out demand replenishments if we do happen to populate the trans.float_no for a demand repl.
      AND t.trans_type  = 'DFK';
BEGIN
   --
   --  Initialization
   --
   l_return_value   := FALSE;

   OPEN c_sos(i_pallet_id); 
   FETCH c_sos INTO l_r_sos;
   CLOSE c_sos; 

   IF ((l_r_sos.in_progress_count + l_r_sos.completed_count > 0)) THEN
      --
      -- Route has one or more SOS active or completed batches.
      -- Selection has started.
      --
      l_return_value := TRUE;
      l_message := 'i_pallet_id[' || i_pallet_id || ']  route_no[' || l_r_sos.route_no || ']'
                   || '  Route has SOS active batches[' || TO_CHAR(l_r_sos.in_progress_count) || ']'
                   || ' or completed batches[' || TO_CHAR(l_r_sos.completed_count) || '].  Selection has started.';
   ELSIF (l_r_sos.total_count = 0) THEN
      --
      -- Route has no SOS batches.  Check if the route has DFK transactions and if so then consider selection in progress.
      --
      l_rec_count := 0;                -- Probably don't need ???

      OPEN c_trans_dfk_count(i_pallet_id);
      FETCH c_trans_dfk_count INTO l_rec_count;
      CLOSE c_trans_dfk_count;

      IF (l_rec_count > 0) THEN
         --
         -- The route has no SOS batches but has a DFK.
         -- Consider selection has started.
         --
         l_return_value := TRUE;
         l_message := 'i_pallet_id[' || i_pallet_id || ']  route_no[' || l_r_sos.route_no || ']'
                      || '  Route has no SOS batches but has DFK transaction(s).  Consider selection has started.';
      ELSE
         --
         -- The route has no SOS batches and no DFK transactions.
         -- Selection has not started.
         --
         l_return_value := FALSE;
         l_message := 'i_pallet_id[' || i_pallet_id || ']  route_no[' || l_r_sos.route_no || ']'
                      || '  Route has no SOS batches and no DFK transactions.  Selection has not started.';
      END IF;
   ELSE
      l_return_value := FALSE;
      l_message := 'i_pallet_id[' || i_pallet_id || ']  route_no[' || l_r_sos.route_no || ']'
                   || '  Route has SOS batches[' || TO_CHAR(l_r_sos.total_count) || '] and none are active or completed.  Selection has not started.';
   END IF;

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'l_return_value[' || pl_common.f_boolean_text(l_return_value) || ']'
                          || '  ' || l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   RETURN l_return_value;

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message and return FALSE.
       -- If any errors then return FALSE.  Returning FALSE should be fine as we will
   -- direct the pallet to the staging location.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error in call to pl_xdock_common.is_route_selection_started.  Return FALSE.'
                             || '  Returning FALSE should be fine as we will direct the pallet to the staging location.'
                             || '  i_pallet_id [' ||  i_pallet_id || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RETURN FALSE;
END is_selection_started_for_route;


---------------------------------------------------------------------------
-- Procedure:
--    get_pre_putaway_info (public)
--                         (main reason for public is so it can be tested standalone)
--
-- Description:
--    This procedure retrieves the "pre putaway" info required by the RF.
--
-- Parameters:
--    i_r_pallet_info - Pallet info.
--    o_rf_status     - pass or fail.
--
-- Called By:
--
-- Exceptions Raised:
--    None.  Any error is trapped and the return status set appropriately.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/04/22 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: ENH-R51_0_OPCOF-3800_Xdock_Site_2_Scanning xdock_lp_at_receiving_will_determine_direct_to_staging_or_door
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE get_pre_putaway_info
   (
      i_r_pallet_info  IN OUT   t_r_pallet_info,
      io_server        IN OUT   xdock_pre_putaway_server_obj,
      o_rf_status      OUT      NUMBER
   )
IS
   l_object_name       VARCHAR2(30) := 'get_pre_putaway_info';   -- Procedure name, used in log messages
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || '  io_server,o_rf_status',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   o_rf_status := rf.status_normal;

   --
   -- If the pallet has a XDK task in NEW status and selection has started for the route
   -- then perform the XDK.
   -- If the pallet has a XDK task in NEW status and there is no put task
   -- then perform the XDK.
   --
   IF (    (does_pallet_have_new_xdk_task(i_r_pallet_info.pallet_id)  = TRUE)
       AND (   (is_selection_started_for_route(i_r_pallet_info.pallet_id) = TRUE)
            OR (i_r_pallet_info.rec_id IS NULL)))
   THEN
      --
      -- The pallet is valid, has a XDK task and the route is being picked.
      -- Have the user do the XDK.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_r_pallet_info.pallet_id[' ||  i_r_pallet_info.pallet_id || ']'
                      || '  io_server,o_rf_status',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
      BEGIN
         --
         -- First update the replenlst src_loc to the door.  But only if there is a put task.
         --
         IF (i_r_pallet_info.src_loc IS NOT NULL) THEN
            UPDATE replenlst r
               SET r.src_loc = i_r_pallet_info.src_loc
             WHERE r.pallet_id = i_r_pallet_info.pallet_id;
         END IF;
   
         SELECT
                vx.pallet_id                   pallet_id,
                'XDK'                          task_type,
                vx.task_id                     task_id,
                vx.prod_id                     prod_id,
                vx.cust_pref_vendor            cust_pref_vendor,
                vx.item_descrip                item_descrip,       -- goes in server object "descrip" field     
                vx.src_loc                     src_loc,
                NVL(vx.dest_loc, vx.door_no)   dest_loc,           -- REPLENLST.dest_loc is null for a XDK, door_no is populated.  Send to the RF the door_on for the dest_loc.
                vx.door_no                     door_no,
                vx.put_path_val                put_path_val,
                vx.spc                         spc,
                vx.qty                         qty,
                vx.cross_dock_type             cross_dock_type,
                vx.route_no                    route_no,
                vx.truck_no                    truck_no,
                vx.float_seq                   float_seq,
                vx.brand                       brand,
                vx.bp_type                     bp_type,
                vx.pack                        pack,
                vx.batch_no                    batch_no,
                vx.catch_wt_trk                catch_wt_trk,
                vx.avg_wt                      avg_wt,
                vx.tolerance                   tolerance,
                vx.NumCust                     numcust,
                vx.instructions                instructions,
                vx.priority                    priority,
                vx.order_seq                   order_seq,
                vx.order_id                    order_id,
                vx.ship_date                   ship_date,
                vx.cust_id                     cust_id,
                vx.cust_name                   cust_name,
                vx.stop_no                     stop_no
           INTO
                io_server.pallet_id,
                io_server.task_type,
                io_server.task_id,
                io_server.prod_id,
                io_server.cpv,
                io_server.descrip,
                io_server.src_loc,
                io_server.dest_loc,
                io_server.door_no,
                io_server.put_path_val,
                io_server.spc,
                io_server.qty,
                io_server.cross_dock_type,
                io_server.route_no,
                io_server.truck_no,
                io_server.float_seq,
                io_server.brand,
                io_server.bp_type,
                io_server.pack,
                io_server.batch_no,
                io_server.catch_wt_trk,
                io_server.avg_wt,
                io_server.tolerance,
                io_server.NumCust,
                io_server.instructions,
                io_server.priority,
                io_server.order_seq,
                io_server.order_id,
                io_server.inv_date,
                io_server.cust_id,
                io_server.cust_name,
                io_server.stop_no
           FROM 
                v_xdock_put_xdk vx
          WHERE
               vx.pallet_id = i_r_pallet_info.pallet_id;

         dbms_output.put_line('found pallet ' || i_r_pallet_info.pallet_id || ' in v_xdock_put_xdk'); --- xxxxx
      EXCEPTION
            WHEN NO_DATA_FOUND THEN
               dbms_output.put_line('did not find pallet ' || i_r_pallet_info.pallet_id || ' in v_xdock_put_xdk');  -- xxxxxxxxxxxxx
               RAISE;  -- xxxxxxxxxxxxxxxxxxx  improve in this
      END;
         ----- retrieve_xdk_data(l_r_pallet_info, o_server, l_rf_status);
         cancel_put_task(i_r_pallet_info  => i_r_pallet_info,
                         o_rf_status      => o_rf_status);
      ELSE
         null;
         ----- retrieve_put_data(l_r_pallet_info, o_server, l_rf_status);
         assign_pre_putaway_put_info(i_r_pallet_info  => i_r_pallet_info,
                                     io_server        => io_server,
                                     o_rf_status      => o_rf_status);
      END IF;

   IF (o_rf_status = rf.status_normal) THEN
      show_server_object(i_server => io_server);
   END IF;

   --
   -- Log ending procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_r_pallet_info.pallet_id[' || i_r_pallet_info.pallet_id  || ']'
                      || '  io_server.pallet_id['       || io_server.pallet_id        || ']'
                      || '  io_server.task_type['       || io_server.task_type        || ']'
                      || '  o_rf_status['               || TO_CHAR(o_rf_status)       || ']',
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
                i_msg_text         => 'Error occurred processing i_r_pallet_info.pallet_id [' ||  i_r_pallet_info.pallet_id || ']'
                             || ' o_rf_status[' || TO_CHAR(o_rf_status) || ']',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END get_pre_putaway_info;



---------------------------------------------------------------------------
-- Function:
--    pre_putaway_main (public)
--
-- Description:
--    This function performs the pre putaway processing when a R1 cross dock
--    pallet is scanned for putaway at Site 2.
--
--    This function is what the RF calls.
--
--    It will commit or rollback depending on the status.
--
--    Procedure "pre_putaway" is called to do all the work.  "pre_putaway" does not
--    commit or rollback.
--
--
--    Process Flow:
--
--    As of 2/08/2022 the server object fields are: (31 fields)
--       pallet_id
--       task_type
--       task_id
--       prod_id
--       cpv
--       descrip
--       src_loc
--       dest_loc
--       door_no
--       put_path_val
--       spc
--       qty
--       cross_dock_type
--       route_no
--       truck_no
--       float_seq
--       brand
--       bp_type
--       pack
--       batch_no
--       catch_wt_trk
--       avg_wt
--       tolerance
--       NumCust
--       instructions
--       priority
--       order_seq
--       order_id
--       inv_date
--       cust_id
--       cust_name
--       stop_no
--
-- Parameters:
--    i_rf_log_init_record
--    i_client_obj           - Client data.
--    o_server               - Pre putaway data for the RF to use in putaway
--                             or directing the pallet to the door(XDK).
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
FUNCTION pre_putaway_main
   (
      i_rf_log_init_record        IN      rf_log_init_record,
      i_client_obj                IN      xdock_pre_putaway_client_obj,
      o_server                    OUT     xdock_pre_putaway_server_obj 
   )
RETURN rf.STATUS
IS
   l_object_name        VARCHAR2(30) := 'pre_putaway_main';

   l_rf_status          NUMBER;     -- Status to send back to RF
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
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      --
      -- Initialize server object.
      --
      o_server := xdock_pre_putaway_server_obj(' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
                                               ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
                                               ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
                                               ' ', ' ');

      --
      -- Call procedure to do all the work.
      --
      pre_putaway(i_client_obj   => i_client_obj,
                  o_server       => o_server,
                  o_rf_status    => l_rf_status);
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id[' || i_client_obj.pallet_id || ']'
                      || '  o_server.pallet_id['     || o_server.pallet_id     || ']'
                      || '  o_server.task_type['     || o_server.task_type     || ']'
                      || '  l_rf_status['            || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   IF (l_rf_status = rf.status_normal) THEN
      COMMIT;
   ELSE
      ROLLBACK;
   END IF;

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

   ROLLBACK;

   rf.complete(l_rf_status);

   RETURN l_rf_status;

END pre_putaway_main;


---------------------------------------------------------------------------
-- Procedure:
--    pre_putaway (public)
--
-- Description:
--    This procedure performs the pre putaway processing when a cross dock
--    pallet is scanned to be putaway at Site 2.
--
--    It is not called directly by the RF.  The RF call function "pre_putaway_main"
--    which then calls this procedure.
--
--    This procedure does all the work.
--
--    No commit or rollback is made in the procedure.
--
--    Process Flow:
--
--    As of 2/08/2022 the server object fields are: (31 fields)
--       pallet_id
--       task_type
--       task_id
--       prod_id
--       cpv
--       descrip
--       src_loc
--       dest_loc
--       door_no
--       put_path_val
--       spc
--       qty
--       cross_dock_type
--       route_no
--       truck_no
--       float_seq
--       brand
--       bp_type
--       pack
--       batch_no
--       catch_wt_trk
--       avg_wt
--       tolerance
--       NumCust
--       instructions
--       priority
--       order_seq
--       order_id
--       inv_date
--       cust_id
--       cust_name
--       stop_no
--
-- Parameters:
--    i_client_obj           - Client data.
--    o_server               - Pre putaway data for the RF to use in putaway
--                             or directing the pallet to the door(XDK).
--    o_rf_status
--
-- Called By:
--    pre_putaway_main
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
PROCEDURE pre_putaway
   (
      i_client_obj      IN      xdock_pre_putaway_client_obj,
      o_server          IN OUT  xdock_pre_putaway_server_obj,
      o_rf_status       OUT     NUMBER
   )
IS
   l_object_name        VARCHAR2(30) := 'pre_putaway';

   l_rf_status          NUMBER;     -- Status to send back to RF
   l_pallet_status      NUMBER;     -- Status if pallet in PUTAWAYLST.  
   l_validation_status  NUMBER;     -- Status validating the pallet

   l_r_pallet_info            t_r_pallet_info;
   l_pallet_has_cdk_task_bln  BOOLEAN;
BEGIN
   --
   -- Log starting procedure
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '  i_client_obj.pallet_id[' ||  i_client_obj.pallet_id || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   log_client_object(i_client_obj => i_client_obj);

   --
   -- Initialization
   --
   l_rf_status         := rf.status_normal;
   l_pallet_status     := rf.status_normal;
   l_validation_status := rf.status_normal;


   l_r_pallet_info.pallet_id := i_client_obj.pallet_id;

   --
   -- Check if the pallet has a XDK task in NEW status.
   --
   l_pallet_has_cdk_task_bln := does_pallet_have_new_xdk_task(l_r_pallet_info.pallet_id);

   dbms_output.put_line('l_pallet_has_cdk_task_bln: ' || pl_common.f_boolean_text(l_pallet_has_cdk_task_bln));

   --
   -- Get info about the pallet from PUTAWAYLST.
   --
   get_pallet_info(i_task_type       => 'PUT',
   io_r_pallet_info  => l_r_pallet_info,
   o_rf_status       => l_pallet_status);

   dbms_output.put_line('aaaaaaaaaaaaa  l_pallet_status:' || l_pallet_status);

   IF (l_pallet_status = rf.status_normal)
   THEN
      dbms_output.put_line('bbbbbbbbbbbbb');
      --
      -- Pallet in PUTAWAYLST
      -- Validate the pallet info.
      --
      validate_pallet(i_r_pallet_info  => l_r_pallet_info,
                      o_rf_status      => l_validation_status);
   ELSE
dbms_output.put_line('ccccccccccccc');
      l_rf_status := l_pallet_status;
   END IF;

dbms_output.put_line('1111111111111  l_pallet_status:' || l_pallet_status);

   --
   --
   --
   IF (   (l_pallet_status     = rf.status_normal)
       OR (l_pallet_status     = rf.status_inv_label  AND l_pallet_has_cdk_task_bln = TRUE)
       OR (l_validation_status = rf.status_put_done   AND l_pallet_has_cdk_task_bln = TRUE))
   THEN
dbms_output.put_line('eeeeeeeeeeeee');
      --
      -- Pallet passed validation.
      --
      get_pre_putaway_info(i_r_pallet_info  => l_r_pallet_info,
                           io_server        => o_server,
                           o_rf_status      => l_rf_status);
   ELSIF (l_pallet_status = rf.status_inv_label)
   THEN
       l_rf_status := l_pallet_status;
dbms_output.put_line('fffffffffffff');
   ELSE
      l_rf_status := l_validation_status;
dbms_output.put_line('ggggggggggggg');
   END IF;

   --  
   -- Insert transaction--either PPU or PFK.
   --  
   IF (l_rf_status = rf.status_normal) THEN
      insert_trans(i_r_pallet_info   => l_r_pallet_info,
                   i_server          => o_server,
                   o_rf_status       => l_rf_status);
   END IF;

   --
   -- If forklift labor is active the sign onto the labor batch.
   --
   IF (l_rf_status = rf.status_normal  AND pl_lmf.f_forklift_active = TRUE) THEN
      null;  -- xxxxxx
   END IF;

   --
   -- Log the server object sent to the RF.
   --
   IF (l_rf_status = rf.status_normal) THEN
      log_server_object(i_server => o_server);
   END IF;

   --
   -- Log ending function
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || '  i_client_obj.pallet_id[' || i_client_obj.pallet_id || ']'
                      || '  o_server.pallet_id['     || o_server.pallet_id     || ']'
                      || '  o_server.task_type['     || o_server.task_type     || ']'
                      || '  l_rf_status['            || TO_CHAR(l_rf_status)   || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   o_rf_status := l_rf_status;
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
                             || ' Returning rf.status_data_error[' || TO_CHAR(rf.status_data_error) || '] to RF.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END pre_putaway;

END pl_rf_xdock_pre_putaway;   -- end package body
/



CREATE OR REPLACE PUBLIC SYNONYM pl_rf_xdock_pre_putaway FOR swms.pl_rf_xdock_pre_putaway;

GRANT EXECUTE ON swms.pl_rf_xdock_pre_putaway TO SWMS_USER;


