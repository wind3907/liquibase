
/**************************************************************************/
-- Package Specification
/**************************************************************************/

CREATE OR REPLACE PACKAGE swms.pl_alloc_inv IS
/*****************************************************************/
/* sccs_id=@(#) src/schema/plsql/pl_alloc_inv.sql, swms, swms.9, 11.2 4/9/10 1.26 */
/*****************************************************************/

-----------------------------------------------------------------------------
-- Creation Date : 03/20/03
-- Created BY   : NK
-- Initial version contains two procedures
--
-- Get_Group_No returns the group no and related fields for an SSL
-- and location combination. Input parameters are SSL id (i_method_id)
-- and location (i_logi_loc).
--
-- Update_Pallet_Inv finds a pallet with enough quantity to fill the order
-- and allocates the inventory for a specific float. This procedure is
-- called from alloc_inv when it determines that the allocation is done
-- as a whole pallet as opposed to allocating individual cases or splits
-- This procedure will be called for bulk pulls (floats.pallet_pull = 'B')
-- and combined pulls (floats.pallet_pull = 'Y')
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/13/13 prpbcb   TFS
--              R12.5.1--WIB#65--CRQ45941_Original_CRQ45202 Order generation
--              shorting items with inventory because of record lock
--
--                      We are having issues with shorting items even though
--                      there is qoh.  After researching we found one reason
--                      is locks on the records being accessed when executing
--                      the SELECT ... FOR UPDATE ...  NOWAIT.
--                      Changed the NOWAIT to WAIT x 
--                      The basic process flow will be to execute the select
--                      stmts that were using NOWAIT to WAIT x.  If there is
--                      a lock after x seconds then log a message and perform
--                      the select again without the WAIT or NOWAIT option.
--
--                      A REF CURSOR will be used so we cannot use a loop of
--                      type:
--                        FOR r_inv IN c_inv
--                      So a record type will be created for each cursor that
--                      was changed to a REF CURSOR and the loop structure
--                      changed to 
--                         LOOP
--                            FETCH ... INTO <the record variable>
--                            EXIT WHEN ...%NOTFOUND
--                         END LOOP
--
--                      Changed procedures:
--                         - CreateOrdd()
--                         - AllocFloatingCases()
--                         - AllocFloatingSplits()
--                         - AllocMiniloadItems()
--
--                      Created procedures:
--                         - open_rc_create_ordd()
--                         - open_rc_alloc_floating_cases()
--                         - open_rc_floating_cases_inv()
--                         - open_rc_alloc_floating_splits()
--                         - open_rc_floating_splits_inv()
--                         - open_rc_alloc_miniload_items()
--                         - open_rc_miniload_items_inv()
--                         - for_update_success_msg()  -- I decided not to use this.
--                         - for_update_failed_msg()   -- I decided not to use this.
--                         - after_for_update_msg()    -- I decided not to use this.
--                         - open_rc_home_inv()
--                      Some are public because they are used by programs
--                      outside of this package.
-- 
--                      Created record types:
--                         - t_r_create_ordd
--                         - t_r_alloc_floating_cases
--                         - t_r_floating_cases_inv
--                         - t_r_alloc_floating_splits
--                         - t_r_floating_splits_inv
--                         - t_r_alloc_miniload_items
--                         - t_r_miniload_items_inv
--                         - t_r_home_inv
--                      Some are public because they are used by programs
--                      outside of this package.
--
--                      Created public constant:
--                         - ct_sel_for_update_wait_time
--
--                      Created private constant:
--                         - ct_application_function_user
--
--                      Removed the tabs from this file and replaced with
--                      3 spaces.
--    08/21/14 Infosys 	R13.0-Charm#6000000054-European Imports project
--			Specification added for Get_group_no SP. This is being 
--			called from european Imports package.
--                        
--    11/04/14 prpbcb   Symbotic project.
--
--                      Reference pl_log instead of pl_lmc for the swms log
--                      message types.  warn, debug, etc.
--
--    11/25/14 prpbcb   Symbotic project.
--
--                      Changed procedure "CreateFloatDetailRecord()" to
--                      populate float_detail.order_seq in the insert into
--                      float_detail.  We want to populate all relevant
--                      columns in float_detail and not have pl_sos.sql
--                      populate them.
--                      
--    01/15/15 prpbcb   Symbotic project.
--
--                      Matrix items can be bulked pull.
--                      Changed procedure "update_pallet_inv()" to
--                      bulk pull matrix items.  alloc_inv.pc also changed.
--                      Function "AllocPallet()" in alloc.inv.pc calls
--                      "pl_alloc_inv.update_pallet_inv()"
--                      
--    01/19/15 prpbcb   Symbotic project.
--
--                      The select statement in procedure
--                      "open_rc_alloc_floating_cases()" was selecting 
--                      matrix items.  It should not as matrix items are
--                      handled separately.  Add this to the condition:
--                         AND NVL(p.mx_item_assign_flag, 'N') <> 'Y'
--
--    07/08/15 prpbcb   Symbotic project.
--                      TFS work item: 505
--
--                      Procedure "AllocMiniloadItems()"
--                      was not populating float_detail.order_seq
--
--                      Changed procedure "open_rc_miniload_items_inv()"
--                      adding "i.logi_loc" to end of the ORDER BY so that
--                      picks from the induction location will pick the
--                      carrier with the lowest LP.  There can be multiple
--                      carriers at the induction location.
--
--    12/02/15 bnim1623 Fix condition to include only Matrix item. This is
--                      causing batches to have 'NOHOME' as KVI_FROM_LOC
--                      for combine pull items. Due to which the RF device
--                      is getting a 'NO POINT TYPE SET UP' error.
--                      INC3202196 - Prod issue reported
--
--    02/02/16 bben0556 Brian Bent
--                      Project:
--      R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--                      Tag along changes to this project.
--
--                      Only allocate full case qty from a miniloader case
--                      carrier.  Any remaining splits will be left on the
--                      carrier which should show on the miniloader item recon.
--                      For some reason the case carrier sometimes(not often)
--                      has splits which results in allocating less than full case
--                      to the case order which causes SOS RF to crash. 
--                      FLOAT_DETAIL.QTY_ALLOC is not a full case quantity.
--                      Example:
--                         Order for 1 case.  SPC=4
--                         There is one case carrier with has 3 splits(for whatever reason)
--                         FLOAT_DETAIL.QTY_ALLOC will be 3 which is incorrect.
--                         The case order should short(SHT).
--
--                      Modified record type t_r_miniload_items_inv.
--                      Added fields:
--                         effective_qoh        NUMBER
--                         effective_qty_avail  NUMBER
--                         inv_uom              inv.inv_uom%TYPE,
--
--                      Modified procedure "AllocMiniloadItems()" to allocate
--                      only full case quantities off case carriers when
--                      cases ordered.
--
--	 12/13/21 sban3548  Opcof-3838: Fixed issue with FLOAT_DETAIL.qty_order having different
--						quantity than original ORDD.qty_ordered. Also updated the float_detail
--						status to "ALC" instead of "SHT". This issue happened at Brakes 
--						for orders came in splits for item with Ship split only='N', order line 
-- 						is split into cases/splits and case line shorted. 
--		
-----------------------------------------------------------------------------



--------------------------------------------------------------------------
-- Global Variables
--------------------------------------------------------------------------

l_msg         VARCHAR2 (512);  -- Used for aplog messages



--------------------------------------------------------------------------
-- Public Constants
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Cursors
--------------------------------------------------------------------------


--------------------------------------------------------------------------
-- Public Type Declarations
--------------------------------------------------------------------------

--
-- This record is used by alloc_inv.pc
--
TYPE t_r_home_inv IS RECORD
(
   spc              pm.spc%TYPE,
   case_cube        pm.case_cube%TYPE,
   split_cube       pm.split_cube%TYPE,
   plogi_loc        inv.plogi_loc%TYPE,
   logi_loc         inv.logi_loc%TYPE,
   qty_planned      inv.qty_planned%TYPE,
   qoh              inv.qoh%TYPE,
   qty_alloc        inv.qty_alloc%TYPE,
   qty_avail        NUMBER,
   exp_date         inv.exp_date%TYPE,
   mfg_date         inv.mfg_date%TYPE,
   rec_date         inv.rec_date%TYPE,
   rec_id           inv.rec_id%TYPE,
   lot_id           inv.lot_id%TYPE
);


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    for_update_success_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE for_update_success_msg(i_object_name IN VARCHAR2,
                                 i_message     IN VARCHAR2);


---------------------------------------------------------------------------
-- Procedure:
--    for_update_failed_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE for_update_failed_msg(i_object_name IN VARCHAR2,
                                i_message     IN VARCHAR2);


---------------------------------------------------------------------------
-- Procedure:
--    after_for_update_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE after_for_update_msg(i_object_name IN VARCHAR2,
                               i_message     IN VARCHAR2);

PROCEDURE Update_Pallet_Inv (
   i_method_id  IN sel_method.method_id%TYPE,
   i_prod_id    IN float_detail.prod_id%TYPE,
   i_route_no   IN floats.route_no%TYPE,
   i_float_no   IN floats.float_no%TYPE
   );

PROCEDURE AllocFloatingCases (
      pRouteNo   VARCHAR2,
      pStatus    OUT   NUMBER);

PROCEDURE AllocCustStagingItems (
   i_route_no VARCHAR2,
   o_status OUT NUMBER
);

FUNCTION f_cust_item_exists_in_staging (
   i_prod_id IN inv.prod_id%TYPE,
   i_order_id IN inv.inv_order_id%TYPE
) RETURN CHAR;

FUNCTION f_cust_item_exists_in_pit_loc(
   i_prod_id IN inv.prod_id%TYPE,
   i_order_id IN inv.inv_order_id%TYPE
) RETURN CHAR;

PROCEDURE AllocFloatingSplits (
      pRouteNo VARCHAR2,
      pStatus    OUT   NUMBER);

PROCEDURE AllocMiniloadItems (
      pRouteNo        VARCHAR2,
      pStatus    OUT  NUMBER);

PROCEDURE CreateOrdd (
      p_order_id            VARCHAR2,
      p_order_line_id       NUMBER,
      p_prod_id             VARCHAR2,
      p_cust_pref_vendor    VARCHAR2,
      lQtyRemain            NUMBER,
      p_new_ord_lin_id  OUT NUMBER);

PROCEDURE CreateFloatDetailRecord (
   lFloatNo   NUMBER,
   lSeqNo      NUMBER,
   lQtyRemain   NUMBER,
   lUOM      NUMBER,
   lNewOrdLine   NUMBER,
   lNextSeq  OUT   NUMBER);

---------------------------------------------------------------------------
-- Procedure:
--    open_rc_home_inv
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating inventory
--    from a home slot.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
---------------------------------------------------------------------------
PROCEDURE open_rc_home_inv
                (io_rc_home_inv       IN OUT SYS_REFCURSOR,
                 i_prod_id            IN     inv.prod_id%TYPE,
                 i_cust_pref_vendor   IN     inv.cust_pref_vendor%TYPE,
                 i_uom                IN     inv.inv_uom%TYPE);

PROCEDURE Get_Group_No (
   i_method_id        IN    sel_method.method_id%TYPE,
   i_logi_loc         IN    lzone.logi_loc%TYPE,
   o_group_no         OUT   sel_method.group_no%TYPE,
   o_zone_id          OUT   zone.zone_id%TYPE,
   o_equip_id         OUT   floats.equip_id%TYPE,
   o_door_area        OUT   floats.door_area%TYPE,
   o_comp_code        OUT   floats.comp_code%TYPE,
   o_merge_group_no   OUT   floats.merge_group_no%TYPE
   );


END pl_alloc_inv;
/


show errors


/**************************************************************************/
-- Package Body
/**************************************************************************/

CREATE OR REPLACE PACKAGE BODY swms.pl_alloc_inv
IS
-----------------------------------------------------------------------------
-- Creation Date : 03/20/03
-- Created BY   : NK
-- Initial version contains two procedures
--
-- Get_Group_No returns the group no and related fields for an SSL
-- and location combination. Input parameters are SSL id (i_method_id)
-- and location (i_logi_loc).
--
-- Update_Pallet_Inv finds a pallet with enough quantity to fill the order
-- and allocates the inventory for a specific float. This procedure is
-- called from alloc_inv when it determines that the allocation is done
-- as a whole pallet as opposed to allocating individual cases or splits
-- This procedure will be called for bulk pulls (floats.pallet_pull = 'B')
-- and combined pulls (floats.pallet_pull = 'Y')
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/13/13 prpbcb   TFS
--
--                      Removed the tabs and replaced with 3 spaces.
--
--                      We are having issues with shorting items even though
--                      there is qoh.  After researching we found the select
--                      FOR UPDATE statments with NOWAIT were a problem.  These
--                      were changed  to WAIT x seconds.
--                      The basic process flow will be to execute the select
--                      stmt with WAIT x seconds.  If there is a lock after
--                      x seconds then log a message and select without
--                      the WAIT.  Which means if there is a lock the
--                      stmt will sit there until the lock is released.
--  23-Apr-14 sray0453 
--                      Charm#6000001046-- TFS-WIB#396
--                      Changed AllocMiniloadItems procedure to allocate the 
--                      items in itduction location for orders. Earlier this was not
--                      considered for allocation which resulted in missing Shipment.
--		  
-----------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := 'pl_alloc_inv';   -- Package name.
                                                -- Used in error messages.



--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function      VARCHAR2(20) := 'ORDER PROCESSING';

ct_application_function_user VARCHAR2(10) := 'USER MSG';  
                                -- Our poor mans way
                                -- to create a swms_log message
                                -- specifically for the user community.


ct_sel_for_update_wait_time CONSTANT  VARCHAR2(10) := 'WAIT 3';  -- How
                            -- long to wait
                            -- when using SELECT ... FOR UPDATE ... WAIT ...


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

--
-- This record is used by procedure CreateOrdd()
--
TYPE t_r_create_ordd IS RECORD
(
   order_id        ordd.order_id%TYPE,
   order_line_id   ordd.order_line_id%TYPE
);


--
-- This record is used by procedure AllocFloatingCases()
--
TYPE t_r_alloc_floating_cases IS RECORD
(
   prod_id           float_detail.prod_id%TYPE,
   cust_pref_vendor  float_detail.cust_pref_vendor%TYPE,
   float_no          floats.float_no%TYPE,
   door_area         floats.door_area%TYPE,
   seq_no            float_detail.seq_no%TYPE,
   order_id          float_detail.order_id%TYPE,
   order_seq         float_detail.order_seq%TYPE,
   stop_no           float_detail.stop_no%TYPE,
   order_line_id     float_detail.order_line_id%TYPE,
   qty_order         float_detail.qty_order%TYPE,
   qty_alloc         float_detail.qty_alloc%TYPE,
   uom               float_detail.uom%TYPE,
   split_cube        pm.split_cube%TYPE,
   case_cube         pm.case_cube%TYPE,
   spc               pm.spc%TYPE,
   ml_ind            pm.miniload_storage_ind%TYPE,
   split_trk         pm.split_trk%TYPE,
   orig_uom          ordd.original_uom%TYPE
);


--
-- This record is used by procedure AllocFloatingCases()
--
TYPE t_r_floating_cases_inv IS RECORD
(
   logi_loc      inv.logi_loc%TYPE,
   plogi_loc     inv.plogi_loc%TYPE,
   qoh           inv.qoh%TYPE,
   qty_alloc     inv.qty_alloc%TYPE,
   QtyAvail      NUMBER,
   rec_id        inv.rec_id%TYPE,
   exp_date      inv.exp_date%TYPE,
   mfg_date      inv.mfg_date%TYPE,
   lot_id        inv.lot_id%TYPE,
   weight        inv.weight%TYPE,
   inv_order_id  inv.inv_order_id%TYPE,
   status        inv.status%TYPE
);


--
-- This record is used by procedure AllocFloatingSplits()
--
TYPE t_r_alloc_floating_splits IS RECORD
(
   prod_id           float_detail.prod_id%TYPE,
   cust_pref_vendor  float_detail.cust_pref_vendor%TYPE,
   float_no          floats.float_no%TYPE,
   door_area         floats.door_area%TYPE,
   seq_no            float_detail.seq_no%TYPE,
   order_id          float_detail.order_id%TYPE,
   order_seq         float_detail.order_seq%TYPE,
   stop_no           float_detail.stop_no%TYPE,
   order_line_id     float_detail.order_line_id%TYPE,
   qty_order         float_detail.qty_order%TYPE,
   qty_alloc         float_detail.qty_alloc%TYPE,
   uom               float_detail.uom%TYPE,
   split_cube        pm.split_cube%TYPE,
   case_cube         pm.case_cube%TYPE,
   spc               pm.spc%TYPE,
   ml_ind            pm.miniload_storage_ind%TYPE,
   split_trk         pm.split_trk%TYPE
);

--
-- This record is used by procedure AllocFloatingSplits()
--
TYPE t_r_floating_splits_inv IS RECORD
(
   logi_loc      inv.logi_loc%TYPE,
   plogi_loc     inv.plogi_loc%TYPE,
   qoh           inv.qoh%TYPE,
   qty_alloc     inv.qty_alloc%TYPE,
   QtyAvail      NUMBER,
   rec_id        inv.rec_id%TYPE,
   exp_date      inv.exp_date%TYPE,
   mfg_date      inv.mfg_date%TYPE,
   lot_id        inv.lot_id%TYPE,
   weight        inv.weight%TYPE,
   inv_order_id  inv.inv_order_id%TYPE,
   status        inv.status%TYPE
);


--
-- This record is used by procedure AllocMiniloadItems()
--
TYPE t_r_alloc_miniload_items IS RECORD
(
   prod_id           float_detail.prod_id%TYPE,
   cust_pref_vendor  float_detail.cust_pref_vendor%TYPE,
   float_no          floats.float_no%TYPE,
   seq_no            float_detail.seq_no%TYPE,
   order_id          float_detail.order_id%TYPE,
   stop_no           float_detail.stop_no%TYPE,
   order_line_id     float_detail.order_line_id%TYPE,
   qty_order         float_detail.qty_order%TYPE,
   qty_alloc         float_detail.qty_alloc%TYPE,
   uom               float_detail.uom%TYPE,
   split_cube        pm.split_cube%TYPE,
   case_cube         pm.case_cube%TYPE,
   spc               pm.spc%TYPE,
   ml_ind            pm.miniload_storage_ind%TYPE,
   orig_uom          ordd.original_uom%TYPE
);


--
-- This record is used by procedure AllocMiniloadItems()
--
TYPE t_r_miniload_items_inv IS RECORD
(
   logi_loc             inv.logi_loc%TYPE,
   plogi_loc            inv.plogi_loc%TYPE,
   qoh                  inv.qoh%TYPE,
   qty_alloc            inv.qty_alloc%TYPE,
   QtyAvail             NUMBER,
   rec_id               inv.rec_id%TYPE,
   exp_date             inv.exp_date%TYPE,
   mfg_date             inv.mfg_date%TYPE,
   lot_id               inv.lot_id%TYPE,
   pik_level            loc.pik_level%TYPE,
   max_pick_level       zone.max_pick_level%TYPE,
   induction_loc        zone.induction_loc%TYPE,
   effective_qoh        NUMBER,
   effective_qty_avail  NUMBER,
   inv_uom              inv.inv_uom%TYPE
);


--
-- This record is used by procedure AllocCustStagingItems()
--
TYPE t_r_alloc_cust_staging IS RECORD
(
   prod_id           float_detail.prod_id%TYPE,
   cust_pref_vendor  float_detail.cust_pref_vendor%TYPE,
   float_no          floats.float_no%TYPE,
   door_area         floats.door_area%TYPE,
   seq_no            float_detail.seq_no%TYPE,
   order_id          float_detail.order_id%TYPE,
   order_seq         float_detail.order_seq%TYPE,
   stop_no           float_detail.stop_no%TYPE,
   order_line_id     float_detail.order_line_id%TYPE,
   qty_order         float_detail.qty_order%TYPE,
   qty_alloc         float_detail.qty_alloc%TYPE,
   uom               float_detail.uom%TYPE,
   split_cube        pm.split_cube%TYPE,
   case_cube         pm.case_cube%TYPE,
   spc               pm.spc%TYPE,
   ml_ind            pm.miniload_storage_ind%TYPE,
   split_trk         pm.split_trk%TYPE,
   orig_uom          ordd.original_uom%TYPE
);


--
-- This record is used by procedure AllocCustStagingItems()
--
TYPE t_r_cust_staging_inv IS RECORD
(
   logi_loc      inv.logi_loc%TYPE,
   plogi_loc     inv.plogi_loc%TYPE,
   qoh           inv.qoh%TYPE,
   qty_alloc     inv.qty_alloc%TYPE,
   QtyAvail      NUMBER,
   rec_id        inv.rec_id%TYPE,
   exp_date      inv.exp_date%TYPE,
   mfg_date      inv.mfg_date%TYPE,
   lot_id        inv.lot_id%TYPE,
   weight        inv.weight%TYPE,
   inv_order_id  inv.inv_order_id%TYPE,
   status        inv.status%TYPE
);


e_record_locked  EXCEPTION;
PRAGMA EXCEPTION_INIT(e_record_locked, -54);

e_record_locked_after_waiting  EXCEPTION;
PRAGMA EXCEPTION_INIT(e_record_locked_after_waiting, -30006);


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------



---------------------------------------------------------------------------
-- Procedure:
--    open_rc_create_ordd
--
-- Description:
--    This procedure opens a ref cursor used when an ORDD record
--    is created.
--
--    It first attempts to open using FOR UPDATE WAIT x
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_ordd           - 
--    i_sys_order_id       - 
--    i_sys_order_line_id  - 
--    i_route_no           - 
--
-- Called by:
--    - CreateOrdd()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE open_rc_create_ordd
            (io_rc_ordd           IN OUT SYS_REFCURSOR,
             i_sys_order_id       IN     ordd.sys_order_id%TYPE,
             i_sys_order_line_id  IN     ordd.sys_order_line_id%TYPE,
             i_route_no           IN     ordd.route_no%TYPE)
IS
   l_message           VARCHAR2(512);     -- Message buffer
   l_message_2         VARCHAR2(128);     -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_create_ordd';

   l_base_select_stmt       VARCHAR2(2000);  -- ORDD select stmt
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
  pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                 NULL, NULL,
                 ct_application_function, gl_pkg_name);


   l_base_select_stmt :=
  'SELECT order_id,
          order_line_id
     FROM ordd
    WHERE sys_order_id      = :sys_order_id
      AND sys_order_line_id = :sys_order_line_id
      AND route_no          = :route_no
      AND uom               = 1
      FOR UPDATE OF qty_ordered';


   l_message_2 := 
            'sys order id['        || TO_CHAR(i_sys_order_id) || ']'
         || '  sys order line id[' || TO_CHAR(i_sys_order_id) || ']'
         || '  route number['      || i_route_no || ']';

   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log messages to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=ordd'
         || '  KEY=[' || TO_CHAR(i_sys_order_id) || ']'
         ||       '[' || TO_CHAR(i_sys_order_line_id)  || ']'
         ||       '[' || i_route_no || ']'
         || '(i_sys_order_id,i_sys_order_line_id,i_route_no)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF qty_ordered" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_ordd FOR l_select_stmt_with_wait USING i_sys_order_id,
                                                        i_sys_order_line_id,
                                                        i_route_no;

      --
      -- If this point reached then the select FOR UPDATE WAIT x was successful.
      -- Log a message.
      --
      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                        || ct_sel_for_update_wait_time || ' successful');

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-Record(s) not locked using ' 
                     || ct_sel_for_update_wait_time
                     || ' FOR ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

     pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                    NULL, NULL,
                    ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- Encountered lock that was sill there after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the order detail (ORDD) record by another user'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the lock(s) are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the ORDD table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('ORDD', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on ORDD to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_ordd FOR l_base_select_stmt USING i_sys_order_id,
                                                      i_sys_order_line_id,
                                                      i_route_no;
         --
         -- Select for update finished so the lock(s) must have been released.
         -- Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the order detail record (ORDD)'
                     || ' for ' || l_message_2
                     || '.  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

        pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                       NULL, NULL,
                       ct_application_function, gl_pkg_name);

        --
        -- Because of our strange we handle the global variable 
        -- pl_log.g_application_func in pl_log it needs to be set back
        -- to ct_application_function otherwise it could be left at
        -- ct_application_function_user which we do not want.
        --
        pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_ordd,i_sys_order_id,i_sys_order_line_id,i_route_no)'
         || '  i_sys_order_id['        || TO_CHAR(i_sys_order_id) || ']'
         || '  i_sys_order_line_id'    || TO_CHAR(i_sys_order_line_id) || ']'
         || '  i_route_no'             || i_route_no || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                       l_object_name || ': ' || SQLERRM);

END open_rc_create_ordd;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_alloc_floating_cases
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating cases
--    for a floating item.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_ordd           - 
--    i_sys_order_id       - 
--    i_sys_order_line_id  - 
--    i_route_no           - 
--
-- Called by:
--    - AllocFloatingCases()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
--    01/19/14 prpbcb   Exclude matrix items as matrix items are handled
--                      by there own procedures.
---------------------------------------------------------------------------
PROCEDURE open_rc_alloc_floating_cases
            (io_rc_alloc_floating_cases  IN OUT SYS_REFCURSOR,
             i_route_no                  IN     floats.route_no%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_alloc_floating_cases';
   l_count NUMBER;
   l_float_no floats.float_no%TYPE;
   l_pal_pul floats.pallet_pull%TYPE;
   l_fd_order float_detail.order_id%TYPE;
   l_fd_line float_detail.order_line_id%TYPE;
   l_base_select_stmt       VARCHAR2(2000);
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);


   --
   -- This statement selects the order detail records on the route for
   -- orders for cases of floating items.
   --
   -- If this is a finish good company, **don't check if float item has home slot.** 
   IF pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y' THEN
    l_base_select_stmt :=
      'SELECT d.prod_id,
              d.cust_pref_vendor,
              f.float_no,
              f.door_area,
              d.seq_no,
              d.order_id,
              d.order_seq,
              d.stop_no,
              d.order_line_id,
              d.qty_order,
              d.qty_alloc,
              d.uom,
              p.split_cube,
              p.case_cube,
              p.spc,
              NVL(p.miniload_storage_ind, ''N'') ml_ind,
              p.split_trk,
              NVL(od.original_uom, -1) orig_uom
        FROM ordd od,
              pm p,
              float_detail d,
              floats f
        WHERE f.route_no         = :route_no
          AND f.float_no         = d.float_no
          AND f.pallet_pull      = ''N''
          AND NVL (p.miniload_storage_ind, ''N'') IN (''N'', ''S'')
          AND NVL(p.mx_item_assign_flag, ''N'') <> ''Y''
          AND d.uom              = 2
          AND d.status           = ''NEW''
          AND d.merge_alloc_flag IN (''X'',''Y'')
          AND d.prod_id          = p.prod_id
          AND d.cust_pref_vendor = p.cust_pref_vendor
          AND p.status           = ''AVL''
          AND od.order_id        = d.order_id
          AND od.order_line_id   = d.order_line_id
          AND od.qty_ordered - od.qty_alloc > 0
        ORDER BY d.stop_no desc, d.prod_id, d.cust_pref_vendor
          FOR UPDATE OF d.qty_alloc';

   ELSE -- Normal logic.

    l_base_select_stmt :=
      'SELECT d.prod_id,
              d.cust_pref_vendor,
              f.float_no,
              f.door_area,
              d.seq_no,
              d.order_id,
              d.order_seq,
              d.stop_no,
              d.order_line_id,
              d.qty_order,
              d.qty_alloc,
              d.uom,
              p.split_cube,
              p.case_cube,
              p.spc,
              NVL(p.miniload_storage_ind, ''N'') ml_ind,
              p.split_trk,
              NVL(od.original_uom, -1) orig_uom
        FROM ordd od,
              pm p,
              float_detail d,
              floats f
        WHERE f.route_no         = :route_no
          AND f.float_no         = d.float_no
          AND f.pallet_pull      = ''N''
          AND NVL (p.miniload_storage_ind, ''N'') IN (''N'', ''S'')
          AND NVL(p.mx_item_assign_flag, ''N'') <> ''Y''
          AND d.uom              = 2
          AND d.status           = ''NEW''
          AND d.merge_alloc_flag IN (''X'',''Y'')
          AND d.prod_id          = p.prod_id
          AND d.cust_pref_vendor = p.cust_pref_vendor
          AND p.status           = ''AVL''
          AND od.order_id        = d.order_id
          AND od.order_line_id   = d.order_line_id
          AND od.qty_ordered - od.qty_alloc > 0
          AND NOT EXISTS 
                    (SELECT 0
                      FROM inv
                      WHERE inv.prod_id          = d.prod_id
                        AND inv.cust_pref_vendor = d.cust_pref_vendor
                        AND inv.logi_loc         = inv.plogi_loc)
        ORDER BY d.stop_no desc, d.prod_id, d.cust_pref_vendor
          FOR UPDATE OF d.qty_alloc';
   END IF;
   l_message_2 := 'ROUTE[' || i_route_no || ']';

   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=ordd,pm,float_detail,floats'
         || '  KEY=[' || i_route_no || ']'
         || '(i_route_no)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF float_detail.qty_alloc" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_alloc_floating_cases FOR l_select_stmt_with_wait
         USING i_route_no;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the float details (FLOAT_DETAIL)'
                     || ' when allocating inventory for cases ordered for floating items'
                     || ' for ' || l_message_2 || '.'
                     || ' Who has the locks are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the FLOAT_DETAIL table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('FLOAT_DETAIL', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on FLOAT_DETAIL to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_alloc_floating_cases FOR l_base_select_stmt
            USING i_route_no;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the float details (FLOAT_DETAIL)'
                     || ' for ' || l_message_2
                     || '.  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_alloc_floating_cases,i_route_no)'
         || '  i_route_no[' || i_route_no || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_alloc_floating_cases;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_floating_cases_inv
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating cases
--    for a floating item.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_ordd           - 
--    i_sys_order_id       - 
--    i_sys_order_line_id  - 
--    i_route_no           - 
--
-- Called by:
--    - AllocFloatingCases()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
--    07/23/18 mpha8134 Meat company changes: IF syspar ENABLE_FINISH_GOODS = 'Y' then Allocate
--                        inventory based on specific customers. Added a separate base select
--                        statement to select inventory where inventory has been solely specified
--                        for a particular customer (pre-allocated) AND also select inv where
--                        it is not going to a particular customer (free inv where
--                        inv.inv_cust_id is null AND inv.inv_order_id is null)
--                        Cursor grabs inventory in the order of pre-allocated, then free inventory.
---------------------------------------------------------------------------
PROCEDURE open_rc_floating_cases_inv
            (io_rc_floating_cases_inv  IN OUT SYS_REFCURSOR,
             i_prod_id                 IN     inv.prod_id%TYPE,
             i_cust_pref_vendor        IN     inv.cust_pref_vendor%TYPE,
             i_spc                     IN     pm.spc%TYPE,
             i_order_id                IN     ordm.order_id%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_floating_cases_inv';

   l_base_select_stmt       VARCHAR2(2000);
   l_base_select_stmt_cust  VARCHAR2(2000);
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
   l_finish_good_syspar sys_config.config_flag_val%TYPE;
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   l_finish_good_syspar := pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N');

   --
   -- This statement selects the inventory record(s) to allocate inventory
   -- against for case orders for floating items.
   --
   l_base_select_stmt :=
  'SELECT i.logi_loc,
          i.plogi_loc,
          i.qoh,
          i.qty_alloc,
          (i.qoh - i.qty_alloc) QtyAvail,
          i.rec_id,
          i.exp_date,
          i.mfg_date,
          i.lot_id,
          i.weight,
          i.inv_order_id,
          i.status
     FROM loc l, inv i
    WHERE i.prod_id          = :prod_id
      AND i.cust_pref_vendor = :cust_pref_vendor
      AND i.status           = ''AVL''
      AND l.logi_loc         = i.plogi_loc
      AND i.inv_uom          IN (0, 2)
      AND TRUNC ((i.qoh - i.qty_alloc) / :spc) > 0
    ORDER BY i.exp_date, l.pik_level, l.pik_path
     FOR UPDATE OF i.qoh';

    --
    -- 4/24/2013 Brian Bent This was already commented out.  I left it.
    --
/*
         DECODE (SIGN ((i.qoh - i.qty_alloc) - pQtyReqd),
             -1, 999999, (i.qoh - i.qty_alloc)),
         (i.qoh - i.qty_alloc),
*/

   --
   -- This statement selects the inventory record(s) based on specific customers 
   -- (inv.inv_cust_id = ordm.cust_id and inv.inv_order_id = ordm.order_id)
   -- but also inv with no inv_order_id or inv_cust_id allocated,
   -- to allocate inventory against for case orders for floating items. If
   --
   l_base_select_stmt_cust :=
    'SELECT i.logi_loc,
          i.plogi_loc,
          i.qoh,
          i.qty_alloc,
          (i.qoh - i.qty_alloc) QtyAvail,
          i.rec_id,
          i.exp_date,
          i.mfg_date,
          i.lot_id,
          i.weight,
          i.inv_order_id,
          i.status
     FROM loc l, inv i
    WHERE i.prod_id          = :prod_id
      AND i.cust_pref_vendor = :cust_pref_vendor
      AND (
        i.status = ''AVL'' OR (
          i.status = ''OSS'' AND EXISTS ( --Allocate AVL status and only OSS when an inv_order_id is set.
            SELECT 1
            FROM ordm m, ordd d
            WHERE m.order_id = d.order_id
              AND d.order_id = :order_id
              AND m.order_id = i.inv_order_id
          )
        )
      )
      AND l.logi_loc         = i.plogi_loc
      AND i.inv_uom          IN (0, 2)
      AND TRUNC ((i.qoh - i.qty_alloc) / :spc) > 0
      AND EXISTS (
            SELECT 1 
            FROM ordm om, ordd od 
            WHERE od.order_id = om.order_id 
              AND od.order_id = :order_id 
              AND (om.order_id = i.inv_order_id OR i.inv_order_id IS NULL)
          )
    ORDER BY i.inv_order_id, i.status, i.exp_date, l.pik_level, l.pik_path
     FOR UPDATE OF i.qoh';

   l_message_2 :=
            'ITEM['  || i_prod_id || ']'
         || '  CPV[' || i_cust_pref_vendor || ']'
         || '  SPC[' || TO_CHAR(i_spc) || ']';


   --
   -- First wait x seconds if there is a lock.
   --
   --l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;
   IF l_finish_good_syspar = 'Y' THEN
      l_select_stmt_with_wait := l_base_select_stmt_cust || ' ' || ct_sel_for_update_wait_time;
   ELSE
      l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;
   END IF;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=loc,inv'
         || '  KEY=[' || i_prod_id || ']'
         ||       '[' || i_cust_pref_vendor || ']'
         || '(i_route_no,i_cust_pref_vendor)'
         || '  i_spc[' || TO_CHAR(i_spc) || ']'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF i.qoh" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      IF l_finish_good_syspar = 'Y' THEN
        
        OPEN io_rc_floating_cases_inv FOR l_select_stmt_with_wait
          USING i_prod_id,
                i_cust_pref_vendor,
                i_order_id,
                i_spc,
                i_order_id;
      
      ELSE
        
         OPEN io_rc_floating_cases_inv FOR l_select_stmt_with_wait
          USING i_prod_id,
                i_cust_pref_vendor,
                i_spc;

      END IF;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the inventory (INV) by another user'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the lock(s) are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the INV table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('INV', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on INV to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);
        
        IF l_finish_good_syspar = 'Y' THEN
          
          OPEN io_rc_floating_cases_inv FOR l_base_select_stmt_cust
            USING i_prod_id,
                  i_cust_pref_vendor,
                  i_spc,
                  i_order_id;      
        ELSE

          OPEN io_rc_floating_cases_inv FOR l_base_select_stmt
            USING i_prod_id,
                  i_cust_pref_vendor,
                  i_spc;
        END IF;
        
         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the inventory (INV)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_floating_cases_inv,i_prod_id,i_cust_pref_vendor,i_spc)'
         || '  i_prod_id'           || i_prod_id || ']'
         || '  i_cust_pref_vendor'  || i_cust_pref_vendor || ']'
         || '  i_spc'               || TO_CHAR(i_spc) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_floating_cases_inv;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_alloc_floating_splits
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating splits
--    for a floating item.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_alloc_floating_splits
--    i_route_no
--
-- Called by:
--    - AllocFloatingSplits()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE open_rc_alloc_floating_splits
            (io_rc_alloc_floating_splits  IN OUT SYS_REFCURSOR,
             i_route_no                   IN     floats.route_no%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_alloc_floating_splits';
   l_finish_good_syspar sys_config.config_flag_val%TYPE;

   l_base_select_stmt       VARCHAR2(2000);
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   l_finish_good_syspar := pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N');

   --
   -- This statement selects the order detail records on the route for
   -- orders for splits of floating items.
   --
   -- If this is a finish good company, **don't check if float item has home slot.** 
   IF l_finish_good_syspar = 'Y' THEN
     l_base_select_stmt :=
      'SELECT d.prod_id,
              d.cust_pref_vendor,
              f.float_no,
              f.door_area,
              d.seq_no,
              d.order_id,
              d.order_seq,
              d.stop_no,
              d.order_line_id,
              d.qty_order,
              d.qty_alloc,
              d.uom,
              p.split_cube,
              p.case_cube,
              p.spc,
              NVL(p.miniload_storage_ind, ''N'') ML_Ind,
              p.split_trk
        FROM ordd od,
              pm p,
              float_detail d,
              floats f
        WHERE f.route_no         = :route_no
          AND f.float_no         = d.float_no
          AND f.pallet_pull      = ''N''
          AND NVL(p.miniload_storage_ind, ''N'') = ''N''
          AND d.uom              = 1
          AND d.status           = ''NEW''
          AND d.merge_alloc_flag IN (''X'',''Y'')
          AND d.prod_id          = p.prod_id
          AND d.cust_pref_vendor = p.cust_pref_vendor
          AND p.status           = ''AVL''
          AND od.order_id        = d.order_id
          AND od.order_line_id   = d.order_line_id
          AND od.qty_ordered - od.qty_alloc > 0
          ORDER BY d.stop_no desc, d.prod_id, d.cust_pref_vendor
          FOR UPDATE OF d.qty_alloc';

   ELSE
   
     l_base_select_stmt :=
      'SELECT d.prod_id,
              d.cust_pref_vendor,
              f.float_no,
              f.door_area,
              d.seq_no,
              d.order_id,
              d.order_seq,
              d.stop_no,
              d.order_line_id,
              d.qty_order,
              d.qty_alloc,
              d.uom,
              p.split_cube,
              p.case_cube,
              p.spc,
              NVL(p.miniload_storage_ind, ''N'') ML_Ind,
              p.split_trk
        FROM ordd od,
              pm p,
              float_detail d,
              floats f
        WHERE f.route_no         = :route_no
          AND f.float_no         = d.float_no
          AND f.pallet_pull      = ''N''
          AND NVL(p.miniload_storage_ind, ''N'') = ''N''
          AND d.uom              = 1
          AND d.status           = ''NEW''
          AND d.merge_alloc_flag IN (''X'',''Y'')
          AND d.prod_id          = p.prod_id
          AND d.cust_pref_vendor = p.cust_pref_vendor
          AND p.status           = ''AVL''
          AND od.order_id        = d.order_id
          AND od.order_line_id   = d.order_line_id
          AND od.qty_ordered - od.qty_alloc > 0
          AND NOT EXISTS
                (SELECT 0
                  FROM inv
                  WHERE inv.prod_id          = d.prod_id
                    AND inv.cust_pref_vendor = d.cust_pref_vendor
                    AND inv.logi_loc         = inv.plogi_loc)
          ORDER BY d.stop_no desc, d.prod_id, d.cust_pref_vendor
          FOR UPDATE OF d.qty_alloc';
   END IF;
   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=ordd,pm,float_detail,floats'
         || '  KEY=[' || i_route_no || ']'
         || '(i_route_no)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF float_detail.qty_alloc" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_alloc_floating_splits FOR l_select_stmt_with_wait
         USING i_route_no;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the float details (FLOAT_DETAIL)'
                     || ' when allocating inventory for splits ordered for floating items'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the lock(s) are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the ORDD table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('FLOAT_DETAIL', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on FLOAT_DETAIL to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_alloc_floating_splits FOR l_base_select_stmt
            USING i_route_no;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the order details (FLOAT_DETAIL)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_alloc_floating_splits,i_route_no)'
         || '  i_route_no[' || i_route_no || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_alloc_floating_splits;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_floating_splits_inv
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating splits
--    for a floating item.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--
-- Called by:
--    - AllocFloatingSplits()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE open_rc_floating_splits_inv
            (io_rc_floating_splits_inv IN OUT SYS_REFCURSOR,
             i_prod_id                 IN     inv.prod_id%TYPE,
             i_cust_pref_vendor        IN     inv.cust_pref_vendor%TYPE,
             i_order_id                IN     ordm.order_id%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_floating_splits_inv';
   l_finish_good_syspar sys_config.config_flag_val%TYPE;
   l_base_select_stmt       VARCHAR2(2000); 
   l_base_select_stmt_cust  VARCHAR2(2000);  -- Select inv based on the inv_order_id/inv_cust_id
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   l_finish_good_syspar := pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N');

   --
   -- This statement selects the inventory record(s) to allocate inventory
   -- against for case orders for floating items.
   --
   l_base_select_stmt :=
  'SELECT i.logi_loc,
          i.plogi_loc,
          i.qoh,
          i.qty_alloc, (i.qoh - i.qty_alloc) QtyAvail,
          i.rec_id,
          i.exp_date,
          i.mfg_date,
          i.lot_id,
          i.weight,
          i.inv_order_id,
          i.status
     FROM loc l, inv i
    WHERE i.prod_id          = :prod_id
      AND i.cust_pref_vendor = :cust_prev_vendor
      AND l.logi_loc         = i.plogi_loc
      AND i.status           = ''AVL''
      AND i.inv_uom          IN (0, 1)
      AND (i.qoh - NVL (i.qty_alloc, 0)) > 0 -- This line is added for CRQ17837
      AND EXISTS
             (SELECT 0
                FROM zone z, lzone lz
               WHERE lz.logi_loc     = l.logi_loc
                 AND z.zone_id       = lz.zone_id
                 AND z.zone_type     = ''PUT''
                 AND z.induction_loc IS NULL)
    ORDER BY  i.qoh, i.exp_date, l.pik_level, l.pik_path 	-- OPCOF-3357: added qoh in order by clause
      FOR UPDATE OF i.qoh';

    --
    -- 4/24/2013 Brian Bent This was already commented out.  I left it.
    --
/*
         DECODE (SIGN ((i.qoh - i.qty_alloc) - pQtyReqd),
             -1, 999999, (i.qoh - i.qty_alloc)),
         (i.qoh - i.qty_alloc),
*/  

   --
   -- This statement selects the inventory record(s) based on specific customers
   -- to allocate inventory against for case orders for floating items.
   --
   l_base_select_stmt_cust :=
   'SELECT i.logi_loc,
          i.plogi_loc,
          i.qoh,
          i.qty_alloc, (i.qoh - i.qty_alloc) QtyAvail,
          i.rec_id,
          i.exp_date,
          i.mfg_date,
          i.lot_id,
          i.weight,
          i.inv_order_id,
          i.status
     FROM loc l, inv i
    WHERE i.prod_id          = :prod_id
      AND i.cust_pref_vendor = :cust_prev_vendor
      AND l.logi_loc         = i.plogi_loc
      AND (
        i.status = ''AVL'' OR (
          i.status = ''OSS'' AND EXISTS ( --Allocate AVL status and only OSS when an inv_order_id is set.
            SELECT 1
            FROM ordm m, ordd d
            WHERE m.order_id = d.order_id
              AND d.order_id = :order_id
              AND m.order_id = i.inv_order_id
          )
        )
      )
      AND i.inv_uom          IN (0, 1)
      AND (i.qoh - NVL (i.qty_alloc, 0)) > 0 -- This line is added for CRQ17837
      AND EXISTS (
            SELECT 1 
            FROM ordm m, ordd d
            WHERE d.order_id = m.order_id 
              AND d.order_id = :order_id 
              AND (m.order_id = i.inv_order_id OR i.inv_order_id IS NULL)
          )
      AND EXISTS
             (SELECT 0
                FROM zone z, lzone lz
               WHERE lz.logi_loc     = l.logi_loc
                 AND z.zone_id       = lz.zone_id
                 AND z.zone_type     = ''PUT''
                 AND z.induction_loc IS NULL)
    ORDER BY i.inv_order_id, i.status, i.exp_date, l.pik_level, l.pik_path
      FOR UPDATE OF i.qoh';

   l_message_2 :=
            'ITEM['  || i_prod_id || ']'
         || '  CPV[' || i_cust_pref_vendor || ']';

   --
   -- First wait x seconds if there is a lock.
   --
   IF l_finish_good_syspar = 'Y' THEN
     l_select_stmt_with_wait := l_base_select_stmt_cust || ' ' || ct_sel_for_update_wait_time;

      pl_log.ins_msg('INFO', l_object_name, 'Allocating splits based on cust_id and order_id',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   ELSE
     l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

     pl_log.ins_msg('INFO', l_object_name, 'Normal allocation',
                    NULL, NULL,
                    ct_application_function, gl_pkg_name);
   END IF;

   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=loc,inv'
         || '  KEY=[' || i_prod_id || ']'
         ||       '[' || i_cust_pref_vendor || ']'
         || '(i_route_no,i_cust_pref_vendor)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF i.qoh" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      IF l_finish_good_syspar = 'Y' THEN
        
        OPEN io_rc_floating_splits_inv FOR l_select_stmt_with_wait
          USING i_prod_id,
                i_cust_pref_vendor,
                i_order_id,
                i_order_id;
      ELSE

        OPEN io_rc_floating_splits_inv FOR l_select_stmt_with_wait
          USING i_prod_id,
                i_cust_pref_vendor;
      END IF;
      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                        'LOCK MSG-Order generation is held up due to a lock(s) on the inventory (INV) by another user'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the lock(s) are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the INV table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('INV', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on INV to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         IF l_finish_good_syspar = 'Y' THEN
        
           OPEN io_rc_floating_splits_inv FOR l_base_select_stmt_cust
             USING i_prod_id,
                   i_cust_pref_vendor,
                   i_order_id;
         ELSE

           OPEN io_rc_floating_splits_inv FOR l_base_select_stmt
             USING i_prod_id,
                   i_cust_pref_vendor;
         END IF;
         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the inventory (INV)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_floating_splits_inv,i_prod_id,i_cust_pref_vendor,i_spc)'
         || '  i_prod_id'           || i_prod_id || ']'
         || '  i_cust_pref_vendor'  || i_cust_pref_vendor || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_floating_splits_inv;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_alloc_cust_staging
--
-- Description:
--    This procedure will open the cursor for the float_detail 

---------------------------------------------------------------------------
PROCEDURE open_rc_alloc_cust_staging (
   io_rc_alloc_cust_stage_cases IN OUT SYS_REFCURSOR,
   i_route_no IN floats.route_no%TYPE
)
IS
   l_message VARCHAR2(512); -- Message buffer
   l_message_2 VARCHAR2(512);
   l_procedure_name VARCHAR2(30) := 'open_rc_alloc_cust_staging';
   l_count NUMBER;
   l_float_no floats.float_no%TYPE;
   l_order_id float_detail.order_id%TYPE;
   l_order_line_id float_detail.order_line_id%TYPE;
   l_base_select_stmt VARCHAR2(2000);
   l_select_stmt_with_wait VARCHAR2(2000);

BEGIN

   pl_log.ins_msg(pl_log.ct_debug_msg, l_procedure_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   l_base_select_stmt := 
      'SELECT  fd.prod_id,
               fd.cust_pref_vendor,
               f.float_no,
               f.door_area,
               fd.seq_no,
               fd.order_id,
               fd.order_seq,
               fd.stop_no,
               fd.order_line_id,
               fd.qty_order,
               fd.qty_alloc,
               fd.uom,
               p.split_cube,
               p.case_cube,
               p.spc,
               NVL(p.miniload_storage_ind, ''N'') ml_ind,
               p.split_trk,
               NVL(od.original_uom, -1) orig_uom
          FROM ordd od,
               pm p,
               float_detail fd,  
               floats f
         WHERE f.route_no         = :route_no
           AND f.float_no         = fd.float_no
           AND f.pallet_pull      = ''N''
           AND NVL (p.miniload_storage_ind, ''N'') IN (''N'', ''S'')
           AND NVL(p.mx_item_assign_flag, ''N'') <> ''Y''
           AND fd.uom              in (1, 2)
           AND fd.status           = ''NEW''
           AND fd.merge_alloc_flag IN (''X'',''Y'')
           AND fd.prod_id          = p.prod_id
           AND fd.cust_pref_vendor = p.cust_pref_vendor
           AND p.status           = ''AVL''
           AND od.order_id        = fd.order_id
           AND od.order_line_id   = fd.order_line_id
           AND od.qty_ordered - od.qty_alloc > 0
           --AND (  pl_alloc_inv.f_cust_item_exists_in_staging(od.prod_id, od.order_id) = ''Y'' OR
           --       pl_alloc_inv.f_cust_item_exists_in_pit_loc(od.prod_id, od.order_id) = ''Y''   )
         ORDER BY fd.stop_no desc, fd.prod_id, fd.cust_pref_vendor
           FOR UPDATE OF fd.qty_alloc';

   l_message_2 := 'ROUTE[' || i_route_no || ']';

   --
   -- First wait x seconds if there is a lock
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   pl_log.ins_msg(pl_log.ct_fatal_msg, l_procedure_name, l_select_stmt_with_wait,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   --
   -- Start a new block so the record lock expcetion can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=ordd,pm,float_detail,floats'
         || '  KEY=[' || i_route_no || ']'
         || '(i_route_no)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF float_detail.qty_alloc" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_procedure_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_procedure_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_alloc_cust_stage_cases FOR l_select_stmt_with_wait USING i_route_no;

      --
      -- If this point is reached, then the select for update wait x was successful.
      -- Log a message
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_procedure_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_procedure_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_procedure_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the float details (FLOAT_DETAIL)'
                     || ' when allocating inventory for cases ordered for floating items'
                     || ' for ' || l_message_2 || '.'
                     || ' Who has the locks are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the FLOAT_DETAIL table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('FLOAT_DETAIL', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_procedure_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on FLOAT_DETAIL to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_alloc_cust_stage_cases FOR l_select_stmt_with_wait USING i_route_no;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_procedure_name,
                     'LOCK MSG-Lock released on the float details (FLOAT_DETAIL)'
                     || ' for ' || l_message_2
                     || '.  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_procedure_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);          

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;
      
      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_procedure_name
         || '(io_rc_alloc_floating_cases,i_route_no)'
         || '  i_route_no[' || i_route_no || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_procedure_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_procedure_name || ': ' || SQLERRM);

END open_rc_alloc_cust_staging;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_cust_staging_inv
-- 
-- Description:
--    This procedure opens a ref cursor used when allocating cases for 
--    items in the customer staging location.
--
---------------------------------------------------------------------------
PROCEDURE open_rc_cust_staging_inv (
   io_rc_cust_staging_cases_inv IN OUT SYS_REFCURSOR,
   i_prod_id IN inv.prod_id%TYPE,
   i_cust_pref_vendor IN inv.cust_pref_vendor%TYPE,
   i_order_id IN ordm.order_id%TYPE
)
IS
   l_message varchar2(512);
   l_message_2 varchar2(512);
   l_object_name varchar2(30) := 'open_rc_cust_staging_inv';

   l_base_select_stmt varchar2(2000);
   l_select_stmt_with_wait varchar2(2000);
BEGIN

   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   --
   -- This statement selects the inv records to allocate inventory
   -- for customer specific items.
   --
   l_base_select_stmt :=
         'SELECT i.logi_loc,
            i.plogi_loc,
            i.qoh,
            i.qty_alloc, (i.qoh - i.qty_alloc) QtyAvail,
            i.rec_id,
            i.exp_date,
            i.mfg_date,
            i.lot_id,
            i.weight,
            i.inv_order_id,
            i.status
         FROM inv i, loc, lzone lz, zone z
         WHERE i.prod_id = :prod_id
         and i.cust_pref_vendor = :cust_pref_vendor
         and i.inv_order_id = :inv_order_id
         and i.status = ''AVL''
         and i.inv_uom in (0, 1, 2)
         and i.plogi_loc = loc.logi_loc
         and loc.logi_loc = lz.logi_loc
         and lz.zone_id = z.zone_id
         and z.zone_type = ''PUT''
         and z.rule_id in (9, 11) -- Customer staging and pit locations
         FOR UPDATE OF i.qoh';

   l_message_2 := 'ITEM['  || i_prod_id || ']'
      || '  CPV[' || i_cust_pref_vendor || ']';

   --
   -- First wait X seconds if there is a lock
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;
   pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_select_stmt_with_wait,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=loc,inv'
         || '  KEY=[' || i_prod_id || ']'
         ||       '[' || i_cust_pref_vendor || ']'
         || '(i_route_no,i_cust_pref_vendor)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF i.qoh" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
      
      OPEN io_rc_cust_staging_cases_inv FOR l_select_stmt_with_wait
         USING i_prod_id, i_cust_pref_vendor, i_order_id;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   
   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                        'LOCK MSG-Order generation is held up due to a lock(s) on the inventory (INV) by another user'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the lock(s) are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the INV table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('INV', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on INV to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_cust_staging_cases_inv FOR l_select_stmt_with_wait
            USING i_prod_id, i_cust_pref_vendor, i_order_id;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the inventory (INV)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;   
   END;

EXCEPTION
   WHEN OTHERS THEN
       l_message := l_object_name
         || '(io_rc_floating_splits_inv,i_prod_id,i_cust_pref_vendor,i_spc)'
         || '  i_prod_id'           || i_prod_id || ']'
         || '  i_cust_pref_vendor'  || i_cust_pref_vendor || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);
END open_rc_cust_staging_inv;

---------------------------------------------------------------------------
-- Function:
--    f_cust_item_exists_in_staging
--
-- Description:
--    This function will return Y or N depending on if an item dedicated to
--    a particular customer/order exists in inventory at a customer staging
--    location (customer staging location is defined as a location in a 
--    customer staging zone: rule 9)
--    
---------------------------------------------------------------------------
FUNCTION f_cust_item_exists_in_staging (
   i_prod_id inv.prod_id%TYPE,
   i_order_id inv.inv_order_id%TYPE
) RETURN CHAR
IS
   l_count NUMBER := 0;
BEGIN

   IF (pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'N') THEN
      return 'N';
   END IF;
   SELECT count(inv.prod_id)
   INTO l_count
   FROM inv, lzone lz, zone z, loc
   WHERE inv.prod_id = i_prod_id
   AND inv.inv_order_id = i_order_id
   AND inv.plogi_loc = loc.logi_loc
   AND loc.logi_loc = lz.logi_loc
   AND lz.zone_id = z.zone_id
   AND z.zone_type = 'PUT'
   AND z.rule_id = 9;

   IF l_count > 0 THEN
      return 'Y';
   ELSE 
      return 'N';
   END IF;

END f_cust_item_exists_in_staging;


---------------------------------------------------------------------------
-- Function:
--    f_cust_item_exists_in_pit_loc
--
-- Description:
--    This function will return Y or N depending on if an item dedicated to
--    a particular customer/order exists in inventory at a PIT
--    location (pit location is defined as a location in a PIT zone: rule 11)
--    
---------------------------------------------------------------------------
FUNCTION f_cust_item_exists_in_pit_loc (
   i_prod_id IN inv.prod_id%TYPE,
   i_order_id IN inv.inv_order_id%TYPE
) 
RETURN CHAR
IS
   l_count NUMBER := 0;
BEGIN

   IF (pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'N') THEN
      return 'N';
   END IF;

   SELECT count(inv.prod_id)
   INTO l_count
   FROM inv, lzone lz, zone z, loc
   WHERE inv.prod_id = i_prod_id
   AND inv.inv_order_id = i_order_id
   AND inv.plogi_loc = loc.logi_loc
   AND loc.logi_loc = lz.logi_loc
   AND lz.zone_id = z.zone_id
   AND z.zone_type = 'PUT'
   AND z.rule_id = 11;

   IF l_count > 0 THEN
      return 'Y';
   ELSE 
      return 'N';
   END IF;  

END f_cust_item_exists_in_pit_loc;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_alloc_miniload_items
--
-- Description:
--
--    This procedure opens a ref cursor selecting what float details need
--    inventory allocated for miniload items.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_ordd           - 
--    i_sys_order_id       - 
--    i_sys_order_line_id  - 
--    i_route_no           - 
--
-- Called by:
--    - AllocMiniloadItems()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE open_rc_alloc_miniload_items
            (io_rc_alloc_miniload_items  IN OUT SYS_REFCURSOR,
             i_route_no                  IN     floats.route_no%TYPE,
             i_uom                       IN     float_detail.uom%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_alloc_miniload_items';

   l_base_select_stmt       VARCHAR2(2000);
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);


   --
   -- This statement selects the order detail records on the route for
   -- orders for miniload items.
   --
   l_base_select_stmt :=
  'SELECT d.prod_id,
          d.cust_pref_vendor,
          f.float_no,
          d.seq_no,
          d.order_id,
          d.stop_no,
          d.order_line_id,
          d.qty_order,
          d.qty_alloc,
          d.uom,
          p.split_cube,
          p.case_cube,
          p.spc,
          p.miniload_storage_ind ML_ind,
          o.original_uom 
     FROM ordd o,
          pm p,
          float_detail d,
          floats f
    WHERE f.route_no         = :route_no
      AND f.float_no         = d.float_no
      AND f.pallet_pull      = ''N''
      AND NVL (p.miniload_storage_ind, ''N'') != ''N''
      AND d.status           = ''NEW''
      AND d.uom              = :uom
      AND d.merge_alloc_flag IN (''X'',''Y'')
      AND d.prod_id          = p.prod_id
      AND d.cust_pref_vendor = p.cust_pref_vendor
      AND p.status           = ''AVL''
      AND o.qty_ordered - o.qty_alloc > 0
      AND o.order_id         = d.order_id
      AND o.order_line_id    = d.order_line_id
    ORDER BY d.stop_no desc, d.prod_id, d.cust_pref_vendor
      FOR UPDATE OF d.qty_alloc';


   l_message_2 := 'ROUTE[' || i_route_no || ']'
                  || '  UOM[' || TO_CHAR(i_uom) || ']';

   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message.
      --
      l_message := 'LOCK MSG-TABLE=ordd,pm,float_detail,floats'
         || '  KEY=[' || i_route_no || ']'
         || '[' || TO_CHAR(i_uom) || ']'
         || '(i_route_no,i_uom)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF float_detail.qty_alloc" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_alloc_miniload_items FOR l_select_stmt_with_wait
         USING i_route_no,
               i_uom;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the float details (FLOAT DETAIL)'
                     || ' when allocating inventory for orders for miniload items'
                     || ' for ' || l_message_2 || '.'
                     || '  Who has the locks are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the FLOAT_DETAIL table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('FLOAT_DETAIL', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on FLOAT_DETAIL to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_alloc_miniload_items FOR l_base_select_stmt
            USING i_route_no,
                  i_uom;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the float details (FLOAT_DETAIL)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);


         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_alloc_miniload_items,i_route_no)'
         || '  i_route_no'     || i_route_no || ']'
         || '  i_uom'          || TO_CHAR(i_route_no) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_alloc_miniload_items;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_miniload_items_inv
--
-- Description:
--
--    This procedure opens a ref cursor selecting the inventory to allocate
--    against for miniload items.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_ordd           - 
--    i_sys_order_id       - 
--    i_sys_order_line_id  - 
--    i_route_no           - 
--
-- Called by:
--    - AllocMiniloadItems()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Created.
--    07/08/15 prpbcb   Added "i.logi_loc" to end of the ORDER BY so that
--                      picks from the induction location will pick the
--                      carrier with the lowest LP.  There can be multiple
--                      carriers at the induction location.
--    02/02/16 bben0556 Add PM table to the select.  Add new columns to the
--                      select "effective_qoh" and "effective_qty_avail".
--                      These columns are are for handing a case carrier
--                      that has splits (for whatever reason).  We only want
--                      to allocate full case quantities from a case carrier.
--                      If the case carrier has splits then the splits stay
--                      on the carrier.
---------------------------------------------------------------------------
PROCEDURE open_rc_miniload_items_inv
            (io_rc_miniload_items_inv  IN OUT SYS_REFCURSOR,
             i_prod_id                 IN     inv.prod_id%TYPE,
             i_cust_pref_vendor        IN     inv.cust_pref_vendor%TYPE,
             i_ml_ind                  IN     pm.miniload_storage_ind%TYPE,
             i_uom                     IN     inv.inv_uom%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_miniload_items_inv';

   l_base_select_stmt       VARCHAR2(2000); 
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);


   --
   -- This statement selects the inventory record(s) to allocate inventory
   -- against for orders for miniload items.
   --
   l_base_select_stmt :=
  'SELECT i.logi_loc,
          i.plogi_loc,
          i.qoh,
          i.qty_alloc,
          (i.qoh - i.qty_alloc) QtyAvail,
          i.rec_id,
          i.exp_date,
          i.mfg_date,
          i.lot_id,
          l.pik_level,
          z.max_pick_level,
          z.induction_loc,
          DECODE(i.inv_uom, 1, i.qoh, TRUNC(i.qoh / pm.spc) * pm.spc) effective_qoh,
          DECODE(i.inv_uom, 1, i.qoh - i.qty_alloc,
                 TRUNC((i.qoh - i.qty_alloc) / pm.spc) * pm.spc)      effective_qty_avail,
          i.inv_uom
     FROM zone z,
          lzone lz,
          loc l,
          inv i,
          pm
    WHERE i.prod_id           = :prod_id
      AND i.cust_pref_vendor  = :cust_pref_vendor
      AND pm.prod_id          = i.prod_id
      AND pm.cust_pref_vendor = i.cust_pref_vendor
      AND l.logi_loc          = i.plogi_loc
      AND lz.logi_loc         = l.logi_loc
      AND z.zone_id           = lz.zone_id
      AND (   (i.inv_uom = :uom)
           OR (i.plogi_loc = z.induction_loc AND i.inv_uom = 0))
      AND i.status            = ''AVL''
      AND z.zone_type         = ''PUT''
      AND z.induction_loc     IS NOT NULL
      AND i.qoh - i.qty_alloc > 0
    ORDER BY DECODE(SIGN (l.pik_level - z.max_pick_level), 1, -1, -2),
             i.exp_date, l.pik_level, l.pik_path, i.logi_loc
      FOR UPDATE OF i.qoh';

    --
    -- 4/24/2013 Brian Bent This was already commented out.  I left it.
    --
      -- AND   ((pML_ind = 'B') OR (pML_ind = 'S' and i.inv_uom != 2))

   l_message_2 :=
            'ITEM['  || i_prod_id || ']'
         || '  CPV[' || i_cust_pref_vendor || ']'
         || '  MINILOAD STORAGE INDICATOR[' || i_ml_ind || ']'
         || '  UOM[' || TO_CHAR(i_uom) || ']';


   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=zone,lzone,loc,inv'
         || '  KEY=[' || i_prod_id || ']'
         ||       '[' || i_cust_pref_vendor || ']'
         ||       '[' || TO_CHAR(i_uom) || ']'
         || '(i_route_no,i_cust_pref_vendor,i_uom)'
         || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF i.qoh" '
         || ct_sel_for_update_wait_time
         || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_miniload_items_inv FOR l_select_stmt_with_wait
         USING i_prod_id,
               i_cust_pref_vendor,
               i_uom;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reach then encountered lock that was sill there
         -- after waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                        'LOCK MSG-Order generation is held up due to a lock(s) on the inventory (INV) by another user'
                     || ' on the inventory for ' || l_message_2 || '.'
                     || '  Who has the locks are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the INV table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('INV', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on INV to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_miniload_items_inv FOR l_base_select_stmt
            USING i_prod_id,
                  i_cust_pref_vendor,
                  i_uom;

         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the inventory (INV)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;

      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_miniload_items_inv,i_prod_id,i_cust_pref_vendor,i_ml_ind,i_uom)'
         || '  i_prod_id'           || i_prod_id || ']'
         || '  i_cust_pref_vendor'  || i_cust_pref_vendor || ']'
         || '  i_ml_ind'            || i_ml_ind || ']'
         || '  i_uom'               || TO_CHAR(i_uom) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_miniload_items_inv;



---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    for_update_success_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE for_update_success_msg(i_object_name IN VARCHAR2,
                                 i_message     IN VARCHAR2)
IS
BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, i_object_name,
            'ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE" '
         || ct_sel_for_update_wait_time
         || ' was successful',
         NULL, NULL,
         ct_application_function_user, gl_pkg_name);
END for_update_success_msg;


---------------------------------------------------------------------------
-- Procedure:
--    for_update_failed_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE for_update_failed_msg(i_object_name IN VARCHAR2,
                                i_message     IN VARCHAR2)
IS
BEGIN
   pl_log.ins_msg(pl_log.ct_warn_msg, i_object_name,
            'ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE" '
         || ct_sel_for_update_wait_time
         || ' failed because record(s) locked by another session.'
         || '  Now waiting for the lock to be released before'
         || ' continuing processing...',
         NULL, NULL,
         ct_application_function_user, gl_pkg_name);
END for_update_failed_msg;


---------------------------------------------------------------------------
-- Procedure:
--    after_for_update_msg
--
-- Description:
--    Common log message when opening REF CURSOR.
--
---------------------------------------------------------------------------
PROCEDURE after_for_update_msg(i_object_name IN VARCHAR2,
                               i_message     IN VARCHAR2)
IS
BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, i_object_name,
            'ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE"'
         || '  Statement completed',
         NULL, NULL,
         ct_application_function_user, gl_pkg_name);
END after_for_update_msg;


PROCEDURE Get_Group_No (
   i_method_id        IN    sel_method.method_id%TYPE,
   i_logi_loc         IN    lzone.logi_loc%TYPE,
   o_group_no         OUT   sel_method.group_no%TYPE,
   o_zone_id          OUT   zone.zone_id%TYPE,
   o_equip_id         OUT   floats.equip_id%TYPE,
   o_door_area        OUT   floats.door_area%TYPE,
   o_comp_code        OUT   floats.comp_code%TYPE,
   o_merge_group_no   OUT   floats.merge_group_no%TYPE
   )
IS
BEGIN
   SELECT sm.group_no, smz.zone_id, sm.equip_id, sm.door_area,
          sm.comp_code, sm.merge_group_no
     INTO o_group_no, o_zone_id, o_equip_id, o_door_area,
          o_comp_code, o_merge_group_no
     FROM zone z, sel_method_zone smz, sel_method sm, lzone l
    WHERE l.logi_loc    = i_logi_loc
      AND z.zone_id     = l.zone_id
      AND z.zone_type   = 'PIK'
      AND smz.zone_id   = z.zone_id
      AND smz.method_id = i_method_id
      AND sm.method_id  = smz.method_id
      AND sm.group_no   = smz.group_no
      AND sm.sel_type   = 'PAL';
EXCEPTION
   WHEN OTHERS THEN
      o_group_no       := 0;
      o_zone_id        := 'UNKP';
      o_equip_id       := 'UNKP';
      o_door_area      := 'D';
      o_comp_code      := 'D';
      o_merge_group_no := 0;
END Get_Group_No;


---------------------------------------------------------------------------
-- Procedure:
--    Update_Pallet_Inv
--
-- Description:
--    Bulk pull processing
--
-- Parameters:
--
-- Called By:
--    AllocPallet in alloc_inv.pc
--
-- Exceptions raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/14/15 bben0556 Bulk pull matrix item.
--                      Added a UNION and SELECT in cursor c_inv for bulk
--                      pull of matrix items from the main warehouse.
--                      The oldest pallet will be the one pulk pulled.
--                      As of this time the order qty must match the qty
--                      on the oldest pallet otherwise no bulk pull.
--
--                      FOr the matrix bulk pull logic
--                      it is important the logic here follows the logic in
--                      cursor get_alloc in bulk_pull.pc.  Cursor c_inv needs
--                      to select the same inventory record as that in
--                      bulk_pull.pc
--    08/22/18 mpha8134 Add check for bulk pulling inventory in OSS status and
--                      inv_order_id = sales order_id. If there exists inventory
--                      with AVL + inv_order_id = sales order_id, then don't bulk pull
---------------------------------------------------------------------------
PROCEDURE Update_Pallet_Inv (
   i_method_id  IN sel_method.method_id%TYPE,
   i_prod_id    IN float_detail.prod_id%TYPE,
   i_route_no   IN floats.route_no%TYPE,
   i_float_no   IN floats.float_no%TYPE
   )
IS
   l_object_name  VARCHAR2(30) := 'Update_Pallet_Inv';

   /**************************************************************************************
   * Find a pallet with enough quantity. This will select pallets from
   * reserves first if there is one available. If it cannot find any 
   * reserve pallet with enough quantity, it return the home location
   * ORDER BY:
   *   5 - Expiration Date
   *   9 - Quantity On Hand
   *   7 - Pallet Id
   *
   * c_inv cursor finds out the pallet that can be dropped.
   * If there are no reserve pallets, it will try to bulk-pull from home slot.
   *
   *************************************************************************************/

   CURSOR c_inv (cp_float_no NUMBER) IS
      SELECT i.exp_date,
             i.qoh,
             bulk.pallet_id,
             bulk.src_loc,
             i.prod_id,
             i.cust_pref_vendor,
             i.rec_date,
             i.mfg_date,
             i.rec_id,
             i.plogi_loc,
             i.lot_id,
             i.temperature,
             i.status,
             i.inv_order_id,
             bulk.uom,
             p.case_cube,
             p.spc,
             bulk.perm,
             bulk.stop_no,
             bulk.order_id,
             bulk.order_line_id,
             bulk.order_qty,
             bulk.home_slot,
             NVL(p.mx_item_assign_flag, 'N') mx_item_assign_flag
        FROM -- OSS status added for Meat company. OSS status inventory only allocated if inv.inv_order_id = ordd.order_id.
             -- Should not affect broadline opcos since there is no OSS status and inv.inv_order_id will be null.
            (SELECT decode(rsrv.reserve_status, 'OSS', reserve_loc, decode(pm.fifo_trk, 'N', NVL (reserve_loc, home_slot), home_slot) ) SRC_LOC,
                    decode(rsrv.reserve_status, 'OSS', reserve_uom, decode(pm.fifo_trk, 'N', NVL (reserve_uom, home_uom), home_uom) ) UOM,
                    decode(rsrv.reserve_status, 'OSS', rsrv.prod_id, decode(pm.fifo_trk, 'N', NVL (rsrv.prod_id, hom.prod_id), hom.prod_id) ) PROD_ID,
                    
                    decode(rsrv.reserve_status, 'OSS', rsrv.cust_pref_vendor, 
                        decode(pm.fifo_trk, 'N', NVL (rsrv.cust_pref_vendor, hom.cust_pref_vendor), hom.cust_pref_vendor) 
                    ) CUST_PREF_VENDOR,

                    decode(rsrv.reserve_status, 'OSS', rsrv.float_no, decode(pm.fifo_trk, 'N', NVL (rsrv.float_no, hom.float_no), hom.float_no) ) FLOAT_NO,
                    decode(rsrv.reserve_status, 'OSS', rsrv.order_qty, decode(pm.fifo_trk, 'N', NVL (rsrv.order_qty, hom.order_qty), hom.order_qty) ) ORDER_QTY,
                    decode(rsrv.reserve_status, 'OSS', rsrv.stop_no, decode(pm.fifo_trk, 'N', NVL (rsrv.stop_no, hom.stop_no), hom.stop_no) ) STOP_NO,
                    decode(rsrv.reserve_status, 'OSS', rsrv.order_id, decode(pm.fifo_trk, 'N', NVL (rsrv.order_id, hom.order_id),  hom.order_id) ) ORDER_ID,

                    decode(rsrv.reserve_status, 'OSS', rsrv.order_line_id, 
                        decode(pm.fifo_trk, 'N', NVL (rsrv.order_line_id, hom.order_line_id), hom.order_line_id) 
                    ) ORDER_LINE_ID,

                    hom.perm,
                    decode(rsrv.reserve_status, 'OSS', rsrv.pallet_id, decode(pm.fifo_trk, 'N', rsrv.pallet_id, home_slot) ) PALLET_ID,
                    home_slot
              FROM
                  (SELECT   logi_loc pallet_id, plogi_loc reserve_loc, inv_uom reserve_uom, prod_id, cust_pref_vendor,
                        float_no, order_qty, stop_no, order_id, order_line_id, inv_status reserve_status
                    FROM   (
                        SELECT   i.logi_loc, i.plogi_loc, i.inv_uom, v.prod_id, v.cust_pref_vendor,
                              float_no, order_qty, v.stop_no, v.order_id, v.order_line_id, i.status inv_status
                          FROM   inv i, ordm, (
                              SELECT   fd.prod_id, fd.cust_pref_vendor, f.float_no, SUM (fd.qty_order) order_qty,
                                    MIN (fd.stop_no) stop_no, MIN (fd.order_id) order_id,
                                    MIN (fd.order_line_id) order_line_id
                                FROM float_detail fd, floats f
                               WHERE f.pallet_pull IN ('B', 'Y')
                                 AND fd.float_no = f.float_no
                                 AND f.float_no = cp_float_no
                               GROUP BY fd.prod_id, fd.cust_pref_vendor, f.float_no) v
                         WHERE   i.prod_id = v.prod_id
                           AND   NVL (i.inv_uom, 0) != 1
                           AND  i.logi_loc != i.plogi_loc
                           AND  NVL (i.qoh, 0) >= v.order_qty
                           AND  (NVL (i.status, 'AVL') = 'AVL' 
                                 OR
                                 (NVL(i.status, 'AVL') = 'OSS' AND ordm.order_id = i.inv_order_id)
                                ) 
                           AND  ordm.order_id = v.order_id
                           -- added for Jira528 Meat company changes
                           AND  (ordm.order_id = i.inv_order_id OR i.inv_order_id IS NULL)
                         ORDER  BY i.inv_order_id, i.status, i.exp_date, i.qoh, i.logi_loc)
                   WHERE ROWNUM = 1) rsrv,
                   --
                  (SELECT   l.logi_loc home_slot, l.uom home_uom, v1.prod_id, v1.cust_pref_vendor,
                        float_no, order_qty, stop_no, order_id, order_line_id, perm
                     FROM loc l,
                        (SELECT fd.prod_id, fd.cust_pref_vendor, f.float_no, SUM (fd.qty_order) order_qty,
                              MIN (fd.stop_no) stop_no, MIN (fd.order_id) order_id,
                              MIN (fd.order_line_id) order_line_id
                           FROM float_detail fd, floats f
                          WHERE f.pallet_pull IN ('B', 'Y')
                            AND fd.float_no = f.float_no
                            AND f.float_no = cp_float_no
                          GROUP BY fd.prod_id, fd.cust_pref_vendor, f.float_no) v1
                    WHERE l.prod_id = v1.prod_id
                      AND l.perm = 'Y'
                      AND l.rank = 1
                      AND l.uom != 1) hom, pm
             WHERE   hom.prod_id = rsrv.prod_id (+)
               AND   pm.prod_id = hom.prod_id) bulk,
             pm p, inv i
       WHERE   p.prod_id = bulk.prod_id
         AND   p.cust_pref_vendor = bulk.cust_pref_vendor
         AND   i.logi_loc = NVL (bulk.pallet_id, bulk.src_loc)
      UNION
      --
      -- Matrix bulk pulls
      -- Get the oldest reserve pallet matching the qty ordered.
      --
      -- README  README  README  README  README
      -- It is important the logic here follows the logic in cursor get_alloc
      -- in bulk_pull.pc.  This cursor needs to select the same inventory record
      -- as that in bulk_pull.pc
      --
      SELECT exp_date,
             qoh,
             pallet_id,
             src_loc,
             prod_id,
             cust_pref_vendor,
             rec_date,
             mfg_date,
             rec_id,
             plogi_loc,
             lot_it,
             temperature,
             status,
             inv_order_id,
             uom,           -- INV uom
             case_cube,
             spc,
             perm,
             stop_no, 
             order_id,
             order_line_id,
             order_qty,
             home_slot,
             mx_item_assign_flag
      FROM
      ( -- start inline view.  Inline view used do that we can order by exp_date and then
        -- select only the 1st record
      SELECT inv.exp_date                                   exp_date,
             inv.qoh                                        qoh,
             inv.logi_loc                                   pallet_id,
             inv.plogi_loc                                  src_loc,
             inv.prod_id                                    prod_id,
             inv.cust_pref_vendor                           cust_pref_vendor,
             inv.rec_date                                   rec_date,
             inv.mfg_date                                   mfg_date,
             inv.rec_id                                     rec_id,
             inv.plogi_loc                                  plogi_loc,
             inv.lot_id                                     lot_it,
             inv.temperature                                temperature,
             inv.status                                     status,
             inv.inv_order_id                               inv_order_id,
             inv.inv_uom                                    uom,           -- INV uom
             pm.case_cube                                   case_cube,
             pm.spc                                         spc,
             loc.perm                                       perm,
             float_detail_group.stop_no                     stop_no, 
             float_detail_group.order_id                    order_id,
             float_detail_group.order_line_id               order_line_id,
             float_detail_group.sum_float_detail_order_qty  order_qty,
             'NOHOME'                                       home_slot,   -- We need a value
             NVL(pm.mx_item_assign_flag, 'N')               mx_item_assign_flag
        FROM inv,
             loc,
             lzone,
             zone,
             pm,
             --
             -- Start inline view summing up float detail.  For combine pulls
             -- a float can have more than 1 float detail record which is
             -- why the records are grouped.
             (SELECT fd.prod_id,
                     fd.cust_pref_vendor    cust_pref_vendor,
                     f.float_no             float_no,
                     SUM(fd.qty_order)      sum_float_detail_order_qty,
                     MIN(fd.stop_no)        stop_no,
                     MIN(fd.order_id)       order_id,
                     MIN(fd.order_line_id)  order_line_id
                FROM float_detail fd,
                     floats f
               WHERE f.pallet_pull IN ('B', 'Y')
                 AND fd.float_no   = f.float_no
                 AND f.float_no    = cp_float_no
               GROUP BY fd.prod_id, fd.cust_pref_vendor, f.float_no) float_detail_group
             -- end inline view "float_detail_group"
             --
       WHERE inv.prod_id          = float_detail_group.prod_id
         AND inv.cust_pref_vendor = float_detail_group.cust_pref_vendor
         AND inv.qoh              = float_detail_group.sum_float_detail_order_qty  -- pallet qty and order qty must match
         AND inv.status           = 'AVL'
         AND inv.qty_alloc        = 0        -- cannot have qty_alloc
         AND inv.qty_planned      = 0        -- cannot have qty_planned
         AND loc.logi_loc         = inv.plogi_loc
         AND loc.perm             = 'N'      -- Exclude home slots.
         AND lzone.logi_loc       = loc.logi_loc
         AND lzone.zone_id        = zone.zone_id
         AND zone.zone_type       = 'PUT'
         AND pm.prod_id           = inv.prod_id
         AND pm.cust_pref_vendor  = inv.cust_pref_vendor
         -- Add condition to include only Matrix assigned item. Due to prod issue INC3202196
         AND pm.mx_item_assign_flag = 'Y'
         --
         -- Pallet needs to be in a regular zone, floating zone
         -- or bulk rule zone or in the matrix staging location.
         AND (   zone.rule_id  IN (0, 1, 2)
              OR loc.slot_type = 'MXT')
       ORDER BY inv.exp_date, inv.qoh, inv.logi_loc
     )  -- end inline view
    WHERE ROWNUM <= 1    -- Only want 1 record which will be the oldest one as 
                         -- the inline view orders by exp_date.
    UNION -- This last part is only applicable for Meat companies (companies with ENABLE_FINISH_GOODS = 'Y' syspar)
    SELECT exp_date,
             qoh,
             pallet_id,
             src_loc,
             prod_id,
             cust_pref_vendor,
             rec_date,
             mfg_date,
             rec_id,
             plogi_loc,
             lot_it,
             temperature,
             status,
             inv_order_id,
             uom,           -- INV uom
             case_cube,
             spc,
             perm,
             stop_no, 
             order_id,
             order_line_id,
             order_qty,
             home_slot,
             mx_item_assign_flag
      FROM
      ( -- start inline view.  Inline view used do that we can order by exp_date and then
        -- select only the 1st record
      SELECT inv.exp_date                                   exp_date,
             inv.qoh                                        qoh,
             inv.logi_loc                                   pallet_id,
             inv.plogi_loc                                  src_loc,
             inv.prod_id                                    prod_id,
             inv.cust_pref_vendor                           cust_pref_vendor,
             inv.rec_date                                   rec_date,
             inv.mfg_date                                   mfg_date,
             inv.rec_id                                     rec_id,
             inv.plogi_loc                                  plogi_loc,
             inv.lot_id                                     lot_it,
             inv.temperature                                temperature,
             inv.status                                     status,
             inv.inv_order_id                               inv_order_id,
             inv.inv_uom                                    uom,           -- INV uom
             pm.case_cube                                   case_cube,
             pm.spc                                         spc,
             loc.perm                                       perm,
             float_detail_group.stop_no                     stop_no, 
             float_detail_group.order_id                    order_id,
             float_detail_group.order_line_id               order_line_id,
             float_detail_group.sum_float_detail_order_qty  order_qty,
             'NOHOME'                                       home_slot,   -- We need a value
             NVL(pm.mx_item_assign_flag, 'N')               mx_item_assign_flag
        FROM inv,
             loc,
             lzone,
             zone,
             pm,
             --
             -- Start inline view summing up float detail.  For combine pulls
             -- a float can have more than 1 float detail record which is
             -- why the records are grouped.
             (SELECT fd.prod_id,
                     fd.cust_pref_vendor    cust_pref_vendor,
                     f.float_no             float_no,
                     SUM(fd.qty_order)      sum_float_detail_order_qty,
                     MIN(fd.stop_no)        stop_no,
                     MIN(fd.order_id)       order_id,
                     MIN(fd.order_line_id)  order_line_id
                FROM float_detail fd,
                     floats f
               WHERE f.pallet_pull IN ('B', 'Y')
                 AND fd.float_no   = f.float_no
                 AND f.float_no    = cp_float_no
               GROUP BY fd.prod_id, fd.cust_pref_vendor, f.float_no) float_detail_group
             -- end inline view "float_detail_group"
             --
       WHERE inv.prod_id          =  float_detail_group.prod_id
         AND inv.cust_pref_vendor =  float_detail_group.cust_pref_vendor
         AND inv.qoh              >= float_detail_group.sum_float_detail_order_qty  -- pallet qty and order qty must match
         --AND inv.status           = 'AVL'
         AND (NVL (inv.status, 'AVL') = 'AVL' 
              OR
              (NVL(inv.status, 'AVL') = 'OSS' AND inv.inv_order_id = float_detail_group.order_id)
         )
         AND  (float_detail_group.order_id = inv.inv_order_id OR inv.inv_order_id IS NULL)
         AND inv.qty_alloc        = 0        -- cannot have qty_alloc
         AND inv.qty_planned      = 0        -- cannot have qty_planned
         AND loc.logi_loc         = inv.plogi_loc
         AND loc.perm             = 'N'      -- Exclude home slots.
         AND lzone.logi_loc       = loc.logi_loc
         AND lzone.zone_id        = zone.zone_id
         AND zone.zone_type       = 'PUT'
         AND pm.prod_id           = inv.prod_id
         AND pm.cust_pref_vendor  = inv.cust_pref_vendor
         AND zone.rule_id  IN (0, 1, 2, 9, 10) -- 9 and 10 used for Meat companies (customer staging rule and meat company outside storage rule)
         AND pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y'                 
       ORDER BY inv.inv_order_id, inv.status, inv.exp_date, inv.qoh, inv.logi_loc
     )  -- end inline view
    WHERE ROWNUM <= 1
    ORDER BY inv_order_id; -- Added for the meat company change. This ORDER BY is needed so that it bulk pulls the inventory that is made for a specific customer.
                           -- made for a specific customer. Without it, the program would drop the inventory to the homeslot if the FIFO was S or A.
                           -- This should not affect broadline opcos since they are not using inv.inv_order_id.


   CURSOR c_fd (cp_route_no  VARCHAR2,
                cp_prod_id   VARCHAR2,
                cp_float_no  NUMBER) IS
      SELECT float_no, prod_id, qty_order, qty_alloc, status
        FROM float_detail
       WHERE route_no           = cp_route_no
         AND prod_id            = cp_prod_id
         AND float_no           = cp_float_no
         AND NVL (qty_alloc, 0) = 0
       ORDER BY stop_no desc
         FOR UPDATE OF qty_order;



   l_upd_qty      NUMBER;
   l_qty_remain      NUMBER;
   l_group_no      NUMBER;
   l_qty_short      NUMBER := 0;
   l_seq_no      NUMBER := 0;
   upd_seq_no      NUMBER := 0;
   FIRST_TIME      BOOLEAN := TRUE;
   l_zone_id      zone.zone_id%TYPE;
   l_cpv         float_detail.cust_pref_vendor%TYPE;
   l_qty_repld      NUMBER;
   l_equip_id      floats.equip_id%TYPE;
   l_door_area      floats.door_area%TYPE;
   l_comp_code      floats.comp_code%TYPE;
   l_merge_group_no   floats.merge_group_no%TYPE;
   dod_seq         NUMBER := 0;
   l_home_slot      inv.plogi_loc%TYPE;
   skip_rest      EXCEPTION;
   l_avl_inv_order_id_count NUMBER := 0;
   l_finish_good_syspar sys_config.config_flag_val%TYPE;

   r_inv      c_inv%ROWTYPE;
   
BEGIN
    pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
       'Starting update pallet inv', 
        NULL, NULL, ct_application_function, gl_pkg_name);

   OPEN c_inv (i_float_no);
   FETCH c_inv INTO r_inv;
    pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
       'After fetch c_inv src:' || r_inv.src_loc || ' qoh:' || r_inv.qoh || 'prod:' || r_inv.prod_id || ' order_qty:' || r_inv.order_qty, 
        NULL, NULL, ct_application_function, gl_pkg_name);
   IF (c_inv%NOTFOUND) THEN
      DBMS_OUTPUT.PUT_LINE('INFO Cursor c_inv using float number'
           || '[' || TO_CHAR(i_float_no) || '](i_float_no) found no record');

      CLOSE c_inv;
      RAISE skip_rest;
   END IF;

   l_finish_good_syspar := pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N');
   
   l_avl_inv_order_id_count := 0;

   IF l_finish_good_syspar = 'Y' THEN
      SELECT COUNT(*) 
      INTO l_avl_inv_order_id_count
      FROM inv
      WHERE status = 'AVL'
      AND inv_order_id = r_inv.inv_order_id
      AND prod_id = r_inv.prod_id
      AND cust_pref_vendor = r_inv.cust_pref_vendor;
   END IF;

   IF l_avl_inv_order_id_count > 0 and r_inv.status = 'OSS' THEN
     pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 
       'AVL Inventory with inv_order_id exists. Will not bulk pull OSS inventory with inv_order_id', 
        NULL, NULL, ct_application_function, gl_pkg_name);

     CLOSE c_inv;
     RAISE skip_rest;
   END IF;


   CLOSE c_inv;

   DBMS_OUTPUT.PUT_LINE(
              '[' || TO_CHAR(i_float_no) || '](i_float_no)'
           || '  r_inv.prod_id['   || r_inv.prod_id      || ']'
           || '  r_inv.pallet_id[' || r_inv.pallet_id    || ']'  
           || '  r_inv.qoh['       || TO_CHAR(r_inv.qoh) || ']'  
           || '  r_inv.perm['      || r_inv.perm         || ']'  
                       );

   IF (r_inv.perm = 'Y' AND r_inv.order_qty > r_inv.qoh) THEN
      pl_replenishments.create_case_home_repl (r_inv.src_loc, r_inv.order_qty, i_prod_id,
            i_route_no, r_inv.stop_no, r_inv.uom, r_inv.order_id, r_inv.order_line_id,
            r_inv.cust_pref_vendor, l_qty_repld,'Y');
      r_inv.qoh := r_inv.qoh + l_qty_repld;
   END IF;

   IF (r_inv.qoh = 0) THEN

pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'xxx at 1111', NULL, NULL, ct_application_function, gl_pkg_name);

      UPDATE   float_detail
         SET   status = 'SHT'
       WHERE   float_no = i_Float_No;
      RAISE skip_rest;
   ELSIF (r_inv.qoh < r_inv.order_qty) THEN
      l_qty_short := r_inv.order_qty - r_inv.qoh;
   END IF;

      Get_Group_No (i_method_id, r_inv.src_loc, l_group_no, l_zone_id, l_equip_id,
                    l_door_area, l_comp_code, l_merge_group_no);
   
   FOR r_fd IN c_fd (i_route_no, i_prod_id, i_float_no)
   LOOP
   BEGIN

      l_upd_qty := LEAST (r_fd.qty_order, r_inv.qoh);

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'xxx at 2222', NULL, NULL, ct_application_function, gl_pkg_name);

      UPDATE float_detail
         SET qty_alloc = l_upd_qty,
             status    = DECODE (qty_order, l_upd_qty, 'ALC', 'SHT'),
             src_loc   = r_inv.src_loc,
             cube      = (l_upd_qty / NVL (r_inv.spc, 1)) * NVL (r_inv.case_cube, 0)
       WHERE CURRENT OF c_fd;

      r_inv.qoh := r_inv.qoh - l_upd_qty;
   END;
   END LOOP;

   UPDATE floats
      SET drop_qty       = DECODE (r_inv.src_loc, r_inv.home_slot, 0, r_inv.qoh),
          home_slot      = r_inv.home_slot,
          pallet_id      = DECODE (r_inv.src_loc, r_inv.home_slot, r_inv.home_slot, r_inv.pallet_id),
          group_no       = l_group_no,
          zone_id        = l_zone_id,
          equip_id       = l_equip_id,
          door_area      = l_door_area,
          comp_code      = l_comp_code,
          merge_group_no = l_merge_group_no
    WHERE float_no = i_float_no;

   pl_replenishments.Insert_Replenishment (i_float_no);

   IF (r_inv.src_loc != r_inv.home_slot) THEN
   BEGIN
      DELETE   inv
       WHERE   logi_loc = r_inv.pallet_id;

      IF (r_inv.qoh > 0) THEN
      BEGIN
         UPDATE   inv
            SET   qoh = qoh + r_inv.qoh
          WHERE   logi_loc = r_inv.home_slot;
      END;
      END IF;
   END;
   ELSE
      UPDATE   inv
         SET   qoh = r_inv.qoh
       WHERE   logi_loc = r_inv.home_slot;
   END IF;

   dod_seq := dod_seq + 1;


   BEGIN
      INSERT INTO float_hist (batch_no, route_no, user_id, prod_id,
               cust_pref_vendor, order_id, order_line_id,
               qty_order, qty_alloc, stop_no, src_loc, uom,
               exp_date, mfg_date, rec_date,
               lot_id, container_temperature, float_no, qty_short)
      VALUES ('DOD' || dod_seq, i_route_no, 'ORDER', i_prod_id,
         r_inv.cust_pref_vendor, r_inv.order_id,
         r_inv.order_line_id, r_inv.order_qty,
         r_inv.order_qty - l_qty_short, r_inv.stop_no, r_inv.src_loc,
         r_inv.uom, r_inv.exp_date, r_inv.mfg_date, r_inv.rec_date,
         r_inv.lot_id, r_inv.temperature, i_float_no, l_qty_short);
      EXCEPTION
         WHEN OTHERS THEN 
            l_msg := 'Prod = ' || i_prod_id || ', CPV = ' || r_inv.cust_pref_vendor ||
                'Order Id = ' || r_inv.order_id || ', Line Id = ' ||
                r_inv.order_line_id || ', UOM = ' || r_inv.uom;
            pl_log.ins_msg ('FATAL', 'Update_Pallet_Inv', l_msg, NULL, SQLERRM);
   END;

   BEGIN
      INSERT INTO op_trans (trans_id, trans_type, trans_date, prod_id, cust_pref_vendor,
            qty_expected, qty, user_id, order_id, src_loc, route_no, pallet_id,
            uom, rec_id, lot_id, exp_date, upload_time, float_no, truck_no)
      VALUES (trans_id_seq.NEXTVAL, 'PIK', sysdate, i_prod_id, r_inv.cust_pref_vendor, 0,
         l_upd_qty, 'ORDER', 'PP', r_inv.src_loc, i_route_no, r_inv.pallet_id, 0,
         r_inv.rec_id, r_inv.lot_id, r_inv.exp_date, NULL, i_float_no,
         SUBSTR (i_route_no, 2));

      EXCEPTION
         WHEN OTHERS THEN 
            l_msg := 'Error Inserting Trans Record for bulk pull. Float No ' || i_float_no;
            pl_log.ins_msg ('FATAL', 'Update_Pallet_Inv', l_msg, NULL, SQLERRM);
      
   END;


   EXCEPTION
      WHEN skip_rest THEN
         IF (c_inv%ISOPEN) THEN
            CLOSE c_inv;
         END IF;


END Update_Pallet_Inv;


PROCEDURE CreateFloatDetailRecord (
   lFloatNo   NUMBER,
   lSeqNo      NUMBER,
   lQtyRemain   NUMBER,
   lUOM      NUMBER,
   lNewOrdLine   NUMBER,
   lNextSeq  OUT   NUMBER) IS

   lFNo      NUMBER;
BEGIN
   lNextSeq := -1;
   /*
   ** Here is why the following SQL is needed.
   ** The customer ordered in splits, but SWMS cased it up.
   **
   ** Two conditions can occur:
   ** 1. The order quantity was an exact multiple of SPC.
   **    In this case, SWMS changes the UOM on ordd to 2.
   **
   ** 2. the order quantity was not an exact multiple. In
   **    this case SWMS updates the UOM to 2 on this existing
   **    row, updates its quantity to the max cases that can
   **    be picked for the order, and then creates a new ORDD
   **    record for the remaining splits.
   **
   ** During allocation SWMS finds that it doesn't have enough
   ** cases to fill the order. At this point, since the original
   ** order was in splits, SWMS will try to select the remaining
   ** in splits. The following situations may occur:
   ** 
   ** If originally condition 1 had occured, then ORDD record for
   ** uom = 1 would not have got created and so there won't be   
   ** any float details either. So, a new float detail record will
   ** have to be created. If originally condition 2 had occured,
   ** then there already is an ORDD and float detail record, so
   ** update the quantity on the existing record.
   **
   */
   IF (lNewOrdLine != -1)
   THEN
   BEGIN
      SELECT   fd1.float_no, fd1.seq_no
        INTO   lFNo, lNextSeq
        FROM   float_detail fd1,
         float_detail fd2,
         floats f
       WHERE   fd2.float_no = lFloatNo
         AND   fd2.seq_no = lSeqNo
         AND   fd1.prod_id = fd2.prod_id
         AND   fd1.cust_pref_vendor = fd2.cust_pref_vendor
         AND   fd1.uom = lUOM
         AND   fd1.order_id = fd2.order_id
         AND   fd1.order_line_id = lNewOrdLine
         AND   fd1.status = 'NEW'
         AND   f.float_no = fd1.float_no
         AND   f.pallet_pull = 'N'
         AND   ROWNUM = 1;

      UPDATE   float_detail
         SET   qty_order = qty_order + lQtyRemain
       WHERE   float_no = lFNo
         AND   seq_no = lNextSeq;

      /*
      ** If no quantity was allocated for the original float detail record
      ** (which means cases were not there at all, delete the float detail
      **  record)
      */

      DELETE   float_detail
       WHERE   float_no = lFloatNo
         AND   seq_no = lSeqNo
         AND   qty_alloc = 0
         AND   uom = 2;

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            NULL;
   END;
   END IF;
   IF (lNextSeq = -1 )
   THEN
      SELECT   MAX (seq_no) + 1
        INTO   lNextSeq
        FROM   float_detail
       WHERE   float_no = lFloatNo;

      INSERT   INTO float_detail
         (float_no, seq_no, zone, stop_no, prod_id, src_loc,
          multi_home_seq, uom, qty_order, qty_alloc,
          merge_alloc_flag, merge_loc, status, order_id,
          order_line_id, cube, copy_no, merge_float_no,
          merge_seq_no, cust_pref_vendor, clam_bed_trk,
          route_no, route_batch_no,
          order_seq)
      SELECT    float_no, lNextSeq, zone, stop_no, prod_id, NULL,
          multi_home_seq, lUOM, lQtyRemain, 0,
          merge_alloc_flag, merge_loc, 'NEW', order_id,
          DECODE (lNewOrdLine, -1, order_line_id, lNewOrdLine),
          0, copy_no, merge_float_no,
          merge_seq_no, cust_pref_vendor, clam_bed_trk,
          route_no, route_batch_no,
          order_seq
        FROM    float_detail
       WHERE    float_no = lFloatNo
         AND    seq_no = lSeqNo;
   END IF;
END CreateFloatDetailRecord;


---------------------------------------------------------------------------
-- Procedure:
--    CreateOrdd
--
-- Description:
--
-- Parameters:
--
-- Called By:
-- 
--
-- Exceptions raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/27/13 prpbcb   Use a REF CURSOR.
---------------------------------------------------------------------------
PROCEDURE CreateOrdd (
      p_order_id              VARCHAR2,
      p_order_line_id         NUMBER,
      p_prod_id               VARCHAR2,
      p_cust_pref_vendor      VARCHAR2,
      lQtyRemain              NUMBER,
      p_new_ord_lin_id    OUT NUMBER
   )
IS
   l_o_uom      NUMBER (4);
   l_s_o_id     VARCHAR2 (14);
   l_s_o_l_id   NUMBER (4) := 0;
   lSpZoneId    VARCHAR2 (10);
   lRouteNo     VARCHAR2 (10);
   l_temp       NUMBER (2) := 0;
   l_qty_alloc  NUMBER (8) := 0;
   l_prod_id	ordd.prod_id%TYPE;
   l_cpv		ordd.cust_pref_vendor%TYPE := '-';
   l_qty_ordered	ordd.qty_ordered%TYPE := 0;
   l_home_item	NUMBER := 0;
   skip_rest    EXCEPTION;

   l_rc_ordd  SYS_REFCURSOR;
   l_r_ordd   t_r_create_ordd;
   l_object_name	VARCHAR2(30) := 'CreateOrdd';
BEGIN
   DBMS_OUTPUT.PUT_LINE ('Called CreateOrdd with order id = ' || p_order_id || ' line id = ' || p_order_line_id);
 
   BEGIN
   SELECT original_uom,
          sys_order_id,
          sys_order_line_id,
          route_no,
          qty_alloc,
		  prod_id,
		  cust_pref_vendor,
		  qty_ordered
     INTO l_o_uom,
          l_s_o_id,
          l_s_o_l_id,
          lRouteNo,
          l_qty_alloc,
		  l_prod_id,
		  l_cpv,
		  l_qty_ordered
     FROM ordd
    WHERE order_id      = p_order_id
      AND order_line_id = p_order_line_id
	  AND ROWNUM = 1;
	EXCEPTION
			WHEN OTHERS THEN
				 RAISE skip_rest;
	END;

   IF (l_o_uom IS NOT NULL AND l_o_uom = 1) THEN
   BEGIN
      open_rc_create_ordd(l_rc_ordd,
                          l_s_o_id,
                          l_s_o_l_id,
                          lRouteNo);

      FETCH l_rc_ordd INTO l_r_ordd;

      IF (l_rc_ordd%FOUND)
      THEN
         p_new_ord_lin_id := l_r_ordd.order_line_id;
         DBMS_OUTPUT.PUT_LINE ('l_rc_ordd FOUND. LINE = ' || p_new_ord_lin_id);

         UPDATE ordd
            SET qty_ordered = qty_ordered - lQtyRemain,
                qty_alloc    = DECODE(SIGN (qty_alloc - lQtyRemain),
                                      -1, 0,
                                      qty_alloc - lQtyRemain)
          WHERE order_id      = p_order_id
            AND order_line_id = p_order_line_id;

         UPDATE ordd
            SET qty_ordered = qty_ordered + lQtyRemain
          WHERE ordd.order_id      = l_r_ordd.order_id
            AND ordd.order_line_id = l_r_ordd.order_line_id;
          -- WHERE CURRENT OF l_rc_ordd;
		
		-- OPCOF-3838: Update order qty on float to sync with ORDD.qty_ordered and status to allocated.
		-- Check if item is a home slot item and then update float_detail order qty and status.		
		BEGIN
			SELECT COUNT (l.logi_loc)
			  INTO l_home_item 
				 FROM loc l,
					  inv i
				WHERE i.prod_id          = l_prod_id
				  AND i.cust_pref_vendor = l_cpv
				  AND i.status           = 'AVL'
				  AND i.plogi_loc        = i.logi_loc
				  AND l.logi_loc         = i.plogi_loc
				  AND l.perm             = 'Y'
				  AND l.status           = 'AVL';
	
		EXCEPTION
			WHEN OTHERS THEN
				l_home_item	:= 0;
		END;
		
		IF l_home_item > 0 THEN 
			 pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'A home item: '|| l_prod_id 
                     ||' ,lQtyRemain='||lQtyRemain,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
			 UPDATE float_detail
				SET qty_order = DECODE(SIGN (qty_order - lQtyRemain),
                                      1, (qty_order - lQtyRemain),
									  qty_alloc)
			  WHERE order_id = p_order_id
				AND order_line_id = p_order_line_id
				AND uom = 2
				AND qty_order != qty_alloc; --2/1/22
			
			 UPDATE float_detail
				SET status = 'ALC' 
			  WHERE order_id = p_order_id
				AND order_line_id = p_order_line_id
				AND qty_order = qty_alloc;
		END IF;
		-- OPCOF-3838 end
	
      ELSE
	  
         IF (l_qty_alloc = 0) THEN
            UPDATE ordd
               SET uom = 1
             WHERE order_id = p_order_id
               AND order_line_id = p_order_line_id;

            UPDATE float_detail
               SET uom = 1
             WHERE order_id = p_order_id
               AND order_line_id = p_order_line_id;

            RAISE skip_rest;
         END IF;

         SELECT max (order_line_id) + 1
           INTO p_new_ord_lin_id
           FROM ordd
          WHERE order_id      = p_order_id
            AND order_line_id = p_order_line_id;

         DBMS_OUTPUT.PUT_LINE ('Before Insert ORDD LINE = ' || p_new_ord_lin_id);

         pl_order_processing.GetSplitPickZone(p_prod_id,
                                              p_cust_pref_vendor,
                                              lSpZoneId);

         INSERT INTO ordd (
            order_id,
            order_line_id,
            prod_id,
            cust_pref_vendor,
            lot_id,
            status,
            qty_ordered,
            qty_shipped,
            uom,
            partial,
            page,
            inck_key, 
            seq,
            area,
            route_no,
            stop_no,
            qty_alloc,
            zone_id,
            pallet_pull,
            sys_order_id,
            sys_order_line_id,
            cw_type,
            original_uom)
         SELECT order_id,
                p_new_ord_lin_id,
                prod_id,
                cust_pref_vendor,
                lot_id,
                status,
                lQtyRemain    qty_ordered,
                0             qty_shipped,
                1             uom,
                partial,
                page,
                inck_key,
                seq,
                area,
                route_no,
                stop_no,
                0          qty_alloc,
                zone_id,
                pallet_pull,
                sys_order_id,
                sys_order_line_id,
                cw_type,
                original_uom
           FROM ordd
          WHERE order_id = p_order_id
            AND order_line_id = p_order_line_id;
			
      END IF;
   END;
   END IF;

   IF (l_rc_ordd%ISOPEN) THEN
      CLOSE l_rc_ordd;
   END IF;
EXCEPTION
   WHEN skip_rest THEN
      IF (l_rc_ordd%ISOPEN) THEN
         CLOSE l_rc_ordd;
      END IF;
END CreateOrdd;


---------------------------------------------------------------------------
-- Procedure:
--    AllocFloatingCases
--
-- Description:
--
-- Parameters:
--
-- Called By:
--
-- Exceptions raised:
--

-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Modify processing if a lock in encountered.
--                      Use a REF CURSOR.
--    11/07/15 bben0556 Added the stmt below in the update of the
--                      FLOAT_DETAIL.STATUS to SHT.  Matrix items are
--                      handled by different routines.
--                         AND NVL(p.mx_item_assign_flag, 'N') = 'N'
--    08/21/18 mpha8134 Add ability to allocate inv based on the inv_order_id
--                      It will alloc inv in OSS status (outside storage for FoodPro)
--                      only if the OSS inventory is set up with a sales order_id
---------------------------------------------------------------------------
PROCEDURE AllocFloatingCases
     (pRouteNo   VARCHAR2,
      pStatus    OUT NUMBER)
IS
   l_object_name  VARCHAR2(30) := 'AllocFloatingCases';

   l_rc_alloc_floating_cases  SYS_REFCURSOR;
   recCases                   t_r_alloc_floating_cases;

   l_rc_inv   SYS_REFCURSOR;
   recInv     t_r_floating_cases_inv;

   l_finish_good_ind pm.finish_good_ind%TYPE;

   l_alloc_oss_order BOOLEAN := TRUE;

   --
   -- The previous main cursor (curCases) picks up the floating
   -- items in the main warehouse only. If the splits of an item are
   -- in the miniload, it picks up only the float details for case
   -- orders for that item. The cursor curInv repsonds to it in the 
   -- same way.
   --

   lv_fname   VARCHAR2 (24) := 'AllocFloatingCases';
   lQtyAlloc   NUMBER := 0;
   lFloatNo    NUMBER := 0;
   lSeqNo       NUMBER := 0;
   lQtyReq    NUMBER := 0;
   lQtyOrder    NUMBER := 0;
   lQtyRemain    NUMBER := 0;
   lNextSeq   NUMBER := 0;
   lNewOrdLine   NUMBER := 0;
BEGIN
   pStatus := 0;
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting AllocFloatingCases',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   open_rc_alloc_floating_cases
            (l_rc_alloc_floating_cases,
             pRouteNo);

   LOOP
      FETCH l_rc_alloc_floating_cases INTO recCases;
      EXIT WHEN l_rc_alloc_floating_cases%NOTFOUND;
      
      lFloatNo  := recCases.float_no;
      lSeqNo    := recCases.seq_no;
      lQtyReq   := recCases.qty_order;
      lQtyOrder := recCases.qty_order;

      open_rc_floating_cases_inv(l_rc_inv, 
                                recCases.prod_id,
                                recCases.cust_pref_vendor,
                                recCases.spc,
                                recCases.order_id);

      LOOP
         FETCH l_rc_inv INTO recInv;
         EXIT WHEN l_rc_inv%NOTFOUND;
         
         -- If AVL inventory has order_id set up, then set the alloc OSS status flag to FALSE.
         IF recInv.inv_order_id is not null AND recInv.inv_order_id = recCases.order_id AND recInv.status = 'AVL' THEN
           pl_log.ins_msg(pl_log.ct_fatal_msg, lv_fname, 
             '''AVL'' Inventory exists with inv_order_id.', NULL, NULL, ct_application_function, gl_pkg_name);
           l_alloc_oss_order := FALSE;
         END IF;
         
         -- If inventory in AVL and OSS status with inv_order_id set-up, then only allocate AVL inventory. 
         -- Cursor returns the inventory sorted by status.
         IF l_alloc_oss_order = FALSE AND recInv.status = 'OSS' THEN
           pl_log.ins_msg(pl_log.ct_fatal_msg, lv_fname, 
             '''AVL'' and ''OSS'' inventory exists with inv_order_id. ''OSS'' inventory will not be allocated. Exiting loop', 
             NULL, NULL, ct_application_function, gl_pkg_name);
           EXIT;
         END IF;

         IF (recInv.QtyAvail < lQtyOrder)
         THEN
            lQtyAlloc := recInv.QtyAvail - MOD (recInv.QtyAvail, recCases.spc);
            lQtyRemain := lQtyOrder - lQtyAlloc;
         ELSE
            lQtyAlloc := lQtyOrder;
            lQtyRemain := 0;
         END IF;

         IF (lQtyAlloc != 0)
         THEN
		 		 
            UPDATE float_detail
               SET qty_alloc = lQtyAlloc,
                   qty_order = lQtyAlloc,
                   status = 'ALC',
                   cube = DECODE(uom, 1,
                             recCases.split_cube, recCases.case_cube) * lQtyAlloc /
                          DECODE (uom, 1, 1, recCases.spc),
                   src_loc      = recInv.plogi_loc,
                   alloc_time   = SYSDATE,
                   rec_id       = recInv.rec_id,
                   mfg_date     = recInv.mfg_date,
                   exp_date     = recInv.exp_date,
                   lot_id       = recInv.lot_id,
                   carrier_id   = recInv.logi_loc
             WHERE float_no = lFloatNo
               AND seq_no   = lSeqNo;

            --
            -- Added for meat company changes OPCOF-528
            --
            BEGIN
              SELECT NVL(finish_good_ind, 'N')
              INTO l_finish_good_ind
              FROM pm
              WHERE prod_id = recCases.prod_id;
            EXCEPTION WHEN OTHERS THEN
              l_finish_good_ind := 'N';
            END;

            
            IF l_finish_good_ind = 'Y' THEN
              INSERT INTO sos_finish_good_short (
                float_no,
                float_detail_seq_no,
                orderseq,
                picktype,
                area,
                prod_id,
                weight,
                qty_total,
                qty_short,
                location,
                pallet_id,
                uom,
                order_id)
              VALUES (
                lFloatNo,
                lSeqNo,
                recCases.order_seq,
                '00',
                recCases.door_area,
                recCases.prod_id,
                recInv.weight,
                lQtyAlloc,
                0,
                recInv.plogi_loc,
                recInv.logi_loc,
                recCases.uom,
                recCases.order_id);
            END IF;
            -- End meat company changes

            IF (    lQtyAlloc = recInv.qoh
                AND recInv.qty_alloc = 0) THEN
               DELETE inv
                WHERE inv.logi_loc = recInv.logi_loc;
                -- WHERE CURRENT OF l_rc_inv;
            ELSE
               UPDATE inv
                  SET qoh = qoh - lQtyAlloc
                WHERE inv.logi_loc = recInv.logi_loc;
                -- WHERE CURRENT OF l_rc_inv;
            END IF;

            UPDATE ordd
               SET qty_alloc = NVL (qty_alloc, 0) + lQtyAlloc
             WHERE order_id      = recCases.order_id
               AND order_line_id = recCases.order_line_id;

            UPDATE pm
               SET last_ship_slot = recInv.plogi_loc
             WHERE prod_id          = recCases.prod_id
               AND cust_pref_vendor = recCases.cust_pref_vendor;

            IF (lQtyRemain = 0)
            THEN
               EXIT;
            END IF;
         END IF;
         /*
         ** Didn't complete the pick. Try remaining from
         ** the next location
         */

         l_msg := 'Calling From AllocFloatingCases Loop 1: ' ||
             'CreateFloatDetailRecord ( lFloatNo= ' || lFloatNo || ', lSeqNo= ' ||
             lSeqNo || ', lQtyRemain= ' || lQtyRemain || ', 2 , -1, lNextSeq= ' ||
             lNextSeq || ')';
         pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);
		 pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, l_msg,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

         CreateFloatDetailRecord (lFloatNo, lSeqNo, lQtyRemain, 2, -1, lNextSeq);

         lSeqNo := lNextSeq;
         lQtyReq := lQtyReq - lQtyAlloc;
         lQtyOrder := lQtyRemain;
      END LOOP;  -- end FETCH l_rc_inv INTO recInv

      IF (l_rc_inv%ISOPEN) THEN
         CLOSE l_rc_inv;
      END IF;

      /*
      ** If quantity was not fully allocated and the UOM is case,
      ** and if the original order was in splits, then see if the
      ** remaining quantity can be filled as splits.
      */

      IF (lQtyRemain != 0 AND recCases.split_trk = 'Y' AND recCases.orig_uom = 1)
      THEN

         l_msg := 'Calling From AllocFloatingCases: ' ||
             'pl_alloc_inv.CreateOrdd ( ' || recCases.order_id || ', ' ||
             recCases.order_line_id || ', ' || recCases.prod_id ||
             ', ' || recCases.cust_pref_vendor || ', ' ||
             lQtyRemain || ', ' || lNewOrdLine || ')';

         pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);
		 pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, l_msg,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

         CreateOrdd (
            recCases.order_id,
            recCases.order_line_id,
            recCases.prod_id,
            recCases.cust_pref_vendor,
            lQtyRemain, lNewOrdLine);

         l_msg := 'Calling From AllocFloatingCases Loop 2: ' ||
             'CreateFloatDetailRecord ( ' || lFloatNo || ', ' ||
             lSeqNo || ', ' || lQtyRemain || ', 1, ' ||
             lNewOrdLine || ', ' || lNextSeq || ')';
         pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);

         CreateFloatDetailRecord (lFloatNo, lSeqNo, lQtyRemain, 1, lNewOrdLine, lNextSeq);

      END IF;
   END LOOP;  -- end FETCH l_rc_inv INTO recIn;

   IF (l_rc_inv%ISOPEN) THEN
      CLOSE l_rc_inv;
   END IF;

   --
   -- If there are any more floating items for this route that are
   -- not still fully allocated, change all their statuses to SHT.
   --
   FOR r IN
     (SELECT f.float_no, d.seq_no
        FROM pm p,
             float_detail d,
             floats f
       WHERE f.route_no         = pRouteNo
         AND f.float_no         = d.float_no
         AND f.pallet_pull      = 'N'
         AND d.uom              = 2
         AND NVL(p.miniload_storage_ind, 'N') IN ('N', 'S')
         AND NVL(p.mx_item_assign_flag, 'N') = 'N'
         AND d.status           IN ('NEW', 'ALC')
         AND d.merge_alloc_flag IN ('X','Y')
         AND d.prod_id          = p.prod_id
         AND d.cust_pref_vendor = p.cust_pref_vendor
         AND p.status           = 'AVL'
         AND NVL (d.qty_alloc, 0) < d.qty_order)
   LOOP
	pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, 'xxx at 3333', NULL, NULL, ct_application_function, gl_pkg_name);

      UPDATE   float_detail
         SET   status = 'SHT'
       WHERE   float_no = r.float_no
         AND   seq_no = r.seq_no;
   END LOOP;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      pStatus := sqlcode;

END AllocFloatingCases;


---------------------------------------------------------------------------
-- Procedure:
--    AllocFloatingSplits
--
-- Description:
--
-- Parameters:
--
-- Called By:
--
-- Exceptions raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Modify processing if a lock in encountered.
--                      Use a REF CURSOR.
--    11/07/15 bben0556 Added the stmt below in the update of the
--                      FLOAT_DETAIL.STATUS to SHT.  Matrix items are
--                      handled by different routines.
--                         AND NVL(p.mx_item_assign_flag, 'N') = 'N'
--    08/21/18 mpha8134 Add ability to allocate inv based on the inv_order_id
--                      It will alloc inv in OSS status (outside storage for FoodPro)
--                      only if the OSS inventory is set up with a sales order_id
---------------------------------------------------------------------------
PROCEDURE AllocFloatingSplits
     (pRouteNo   VARCHAR2,
      pStatus    OUT NUMBER)
IS

   l_rc_alloc_floating_splits  SYS_REFCURSOR;
   recSplits                   t_r_alloc_floating_splits;

   l_rc_inv   SYS_REFCURSOR;
   recInv     t_r_floating_splits_inv;

   l_finish_good_ind pm.finish_good_ind%TYPE;

   l_alloc_oss_order BOOLEAN := TRUE;


   --
   -- The previous main cursor (curSplits) picks up the floating
   -- items in the main warehouse only. If the splits of an item are
   -- in the miniload, those float details are not picked up.
   -- The cursor curInv repsonds to it in the same way.

   lv_fname   VARCHAR2 (24) := 'AllocFloatingSplits';
   lQtyAlloc   NUMBER := 0;
   lFloatNo    NUMBER := 0;
   lSeqNo       NUMBER := 0;
   lQtyReq    NUMBER := 0;
   lQtyOrder    NUMBER := 0;
   lQtyRemain    NUMBER := 0;
   lNextSeq   NUMBER := 0;
BEGIN
   pStatus := 0;

	pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, 'Starting AllocFloatingSplits',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
  
   open_rc_alloc_floating_splits(l_rc_alloc_floating_splits,
                                 pRouteNo);

   LOOP
      FETCH l_rc_alloc_floating_splits INTO recSplits;
      EXIT WHEN l_rc_alloc_floating_splits%NOTFOUND;

      lFloatNo  := recSplits.float_no;
      lSeqNo    := recSplits.seq_no;
      lQtyReq   := recSplits.qty_order;
      lQtyOrder := recSplits.qty_order;

      open_rc_floating_splits_inv(l_rc_inv,
                                 recSplits.prod_id,
                                 recSplits.cust_pref_vendor,
                                 recSplits.order_id);
      LOOP
         FETCH l_rc_inv INTO recInv;
         EXIT WHEN l_rc_inv%NOTFOUND;
         
         -- If AVL inventory has order_id set up, then set the alloc OSS status flag to FALSE.
         IF recInv.inv_order_id is not null AND recInv.inv_order_id = recSplits.order_id AND recInv.status = 'AVL' THEN
           pl_log.ins_msg(pl_log.ct_fatal_msg, lv_fname, 
             '''AVL'' Inventory exists with inv_order_id.', NULL, NULL, ct_application_function, gl_pkg_name);
           l_alloc_oss_order := FALSE;
         END IF;
         
         -- If inventory in AVL and OSS status with inv_order_id set-up, then only allocate AVL inventory. 
         -- Cursor returns the inventory sorted by status.
         IF l_alloc_oss_order = FALSE AND recInv.status = 'OSS' THEN
           pl_log.ins_msg(pl_log.ct_fatal_msg, lv_fname, 
             '''AVL'' and ''OSS'' inventory exists with inv_order_id.''OSS'' inventory will not be allocated. Exiting loop', 
             NULL, NULL, ct_application_function, gl_pkg_name);
           EXIT;
         END IF;

         IF (recInv.QtyAvail < lQtyOrder)
         THEN
            lQtyAlloc := recInv.QtyAvail;
            lQtyRemain := lQtyOrder - recInv.QtyAvail;
         ELSE
            lQtyAlloc := lQtyOrder;
            lQtyRemain := 0;
         END IF;
	
         IF (lQtyAlloc != 0)
         THEN
		 
            UPDATE float_detail
               SET qty_alloc = lQtyAlloc,
                   qty_order = lQtyAlloc,
                   status    = 'ALC',
                   cube = DECODE(uom, 1,
                         recSplits.split_cube, recSplits.case_cube) * lQtyAlloc /
                         DECODE (uom, 1, 1, recSplits.spc),
                   src_loc    = recInv.plogi_loc,
                   alloc_time = SYSDATE,
                   rec_id     = recInv.rec_id,
                   mfg_date   = recInv.mfg_date,
                   exp_date   = recInv.exp_date,
                   lot_id     = recInv.lot_id,
                   carrier_id = recInv.logi_loc
             WHERE float_no = lFloatNo
               AND seq_no   = lSeqNo;

            --
            -- Added for meat company changes OPCOF-528
            --
            BEGIN
              SELECT NVL(finish_good_ind, 'N')
              INTO l_finish_good_ind
              FROM pm
              WHERE prod_id = recSplits.prod_id;
            EXCEPTION WHEN OTHERS THEN
              l_finish_good_ind := 'N';
            END;

            IF l_finish_good_ind = 'Y' THEN
              INSERT INTO sos_finish_good_short (
                float_no,
                float_detail_seq_no,
                orderseq,
                picktype,
                area,
                prod_id,
                weight,
                qty_total,
                qty_short,
                location,
                pallet_id,
                uom,
                order_id)
              VALUES (
                lFloatNo,
                lSeqNo,
                recSplits.order_seq,
                '00',
                recSplits.door_area,
                recSplits.prod_id,
                recInv.weight,
                lQtyAlloc,
                0,
                recInv.plogi_loc,
                recInv.logi_loc,
                recSplits.uom,
                recSplits.order_id);
            END IF;


            IF (    lQtyAlloc = recInv.qoh
                AND recInv.qty_alloc = 0)
            THEN
               DELETE inv
                WHERE inv.logi_loc = recInv.logi_loc;
                -- WHERE CURRENT OF curInv;
            ELSE
               UPDATE inv
                  SET qoh = qoh - lQtyAlloc
                WHERE inv.logi_loc = recInv.logi_loc;
                -- WHERE CURRENT OF curInv;
            END IF;

            UPDATE ordd
               SET qty_alloc = NVL (qty_alloc, 0) + lQtyAlloc
             WHERE order_id      = recSplits.order_id
               AND order_line_id = recSplits.order_line_id;

            UPDATE pm
               SET last_ship_slot = recInv.plogi_loc
             WHERE prod_id          = recSplits.prod_id
               AND cust_pref_vendor = recSplits.cust_pref_vendor;

            IF (lQtyRemain = 0)
            THEN
               EXIT;
            END IF;
         END IF;

         /*
         ** Didn't complete the pick. Try remaining from
         ** the next location
         */
         l_msg := 'Calling From AllocFloatingSplits: ' ||
             'CreateFloatDetailRecord ( ' || lFloatNo || ', ' ||
             lSeqNo || ', ' || lQtyRemain || ', 1, -1, ' ||
             lNextSeq || ')';
         pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);
		 pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, l_msg,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
		 
		l_msg := 'Calling From AllocFloatingSplits Loop 2 .... )';
        pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);
		 pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, l_msg,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
		 
         CreateFloatDetailRecord (lFloatNo, lSeqNo, lQtyRemain, 1, -1, lNextSeq);
         lSeqNo := lNextSeq;
         lQtyReq := lQtyReq - lQtyAlloc;
         lQtyOrder := lQtyRemain;
      END LOOP;  -- end FETCH l_rc_inv INTO Recinv

      IF (l_rc_inv%ISOPEN) THEN
         CLOSE l_rc_inv;
      END IF;
   END LOOP;  -- end FETCH l_rc_alloc_floating_splits INTO recSplits

   IF (l_rc_alloc_floating_splits%ISOPEN) THEN
      CLOSE l_rc_alloc_floating_splits;
   END IF;

   --
   -- If there are any more floating items for this route that are
   -- not still fully allocated, change all their statuses to SHT.
   --

   FOR r IN (SELECT f.float_no, d.seq_no
               FROM pm p,
                    float_detail d,
                    floats f
              WHERE f.route_no         = pRouteNo
                AND f.float_no         = d.float_no
                AND f.pallet_pull      = 'N'
                AND d.uom              = 1
                AND p.miniload_storage_ind = 'N'
                AND NVL(p.mx_item_assign_flag, 'N') = 'N'
                AND d.status           IN ('NEW', 'ALC')
                AND d.merge_alloc_flag IN ('X','Y')
                AND d.prod_id          = p.prod_id
                AND d.cust_pref_vendor = p.cust_pref_vendor
                AND p.status           = 'AVL'
                AND NVL (d.qty_alloc, 0) < d.qty_order)
   LOOP
		pl_log.ins_msg(pl_log.ct_debug_msg, lv_fname, 'xxx at 4444', NULL, NULL, ct_application_function, gl_pkg_name);

      UPDATE float_detail
         SET status = 'SHT'
       WHERE float_no = r.float_no
         AND seq_no   = r.seq_no;
   END LOOP;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      pStatus := sqlcode;

END AllocFloatingSplits;


---------------------------------------------------------------------------------------------
-- Procedure:
--    AllocCustStagingItems
-- 
-- Description:
--    This procedure processes the float_detail records and tries to allocate
--    inventory from the customer staging locations. A customer staging location
--    is defined as a location inside of a zone that has rule_id = 9. This procedure
--    was created similar to AllocFloatingCases, but one key difference is that the end of
--    the loop for processing each float_detail, we do not want to set the status to SHT
--    if the inventory is not fully allocated. Keep it in NEW or ALC status so that
--    the other procedures/functions downstream can try and fill the order.
--    This procedure is called from the alloc_inv.pc program after the update_pallet_inv
--    procedure (bulk pulls).
--    
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------------------------
--    02/18/19 mpha8134 Created.
---------------------------------------------------------------------------------------------
PROCEDURE AllocCustStagingItems (
   i_route_no VARCHAR2,
   o_status OUT NUMBER
) 
IS

   l_object_name  VARCHAR2(30) := 'AllocCustStagingItems';
   l_message varchar(2000);
   l_rc_alloc_cust_staging SYS_REFCURSOR;
   recFD t_r_alloc_cust_staging;

   l_rc_inv SYS_REFCURSOR;
   recInv t_r_cust_staging_inv;

   lQtyAlloc NUMBER := 0;
   lFloatNo NUMBER := 0;
   lSeqNo NUMBER := 0;
   lQtyReq NUMBER := 0;
   lQtyOrder NUMBER := 0;
   lQtyRemain NUMBER := 0;
   lNextSeq NUMBER := 0;

BEGIN
   o_status := 0;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Starting procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
   
   IF (pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'N') THEN
      --
      -- This procedure should only run through if this is an ENABLE_FINISH_GOODS = Y company (e.g. Meat company)
      -- Otherwise, do nothing and return.
      --         
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'ENABLE_FINISH_GOODS syspar = N. Ending procedure.',
         NULL, NULL, ct_application_function, gl_pkg_name);

      RETURN;
   END IF;                     

   open_rc_alloc_cust_staging(l_rc_alloc_cust_staging, i_route_no);

   LOOP
      FETCH l_rc_alloc_cust_staging INTO recFD;
      EXIT WHEN l_rc_alloc_cust_staging%NOTFOUND;

      lFloatNo := recFD.float_no;
      lSeqNo := recFD.seq_no;
      lQtyReq := recFD.qty_order;
      lQtyOrder := recFD.qty_order;

      open_rc_cust_staging_inv(l_rc_inv, recFD.prod_id, recFD.cust_pref_vendor, recFD.order_id);

      LOOP
         FETCH l_rc_inv into recInv;
         EXIT WHEN l_rc_inv%NOTFOUND;
         
         l_message := 'order_id[' || recFd.order_id || ']' 
            || ' prod_id[' || recFd.prod_id || ']'
            || ' plogi_loc[' || recInv.plogi_loc || ']'
            || ' logi_loc[' || recInv.logi_loc || ']'
            || ' recInv.QtyAvail[' || recInv.QtyAvail || ']'
            || ' lQtyOrder[' || lQtyOrder || ']';

         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message, NULL, NULL, ct_application_function, gl_pkg_name);

         IF (recInv.QtyAvail < lQtyOrder) THEN
            lQtyAlloc := recInv.QtyAvail - MOD(recInv.QtyAvail, recFD.spc);
            lQtyRemain := lQtyOrder - lQtyAlloc;
         ELSE
            lQtyAlloc := lQtyOrder;
            lQtyRemain := 0;
         END IF;

         IF (lQtyAlloc != 0) THEN
            UPDATE float_detail
            SET qty_alloc = lQtyAlloc,
                qty_order = lQtyAlloc,
                status = 'ALC',
                cube = DECODE(uom, 1,
                             recFD.split_cube, recFD.case_cube) * lQtyAlloc /
                     DECODE (uom, 1, 1, recFD.spc),
                src_loc      = recInv.plogi_loc,
                alloc_time   = SYSDATE,
                rec_id       = recInv.rec_id,
                mfg_date     = recInv.mfg_date,
                exp_date     = recInv.exp_date,
                lot_id       = recInv.lot_id,
                carrier_id   = recInv.logi_loc
          WHERE float_no = lFloatNo
            AND seq_no   = lSeqNo;
         END IF;

         --
         -- Relieve the inventory by deleting or subtracting the quantity
         -- allocated from the quantity on hand.
         --
         IF (lQtyAlloc = recInv.qoh and recInv.qty_alloc = 0) THEN
            DELETE inv WHERE inv.logi_loc = recInv.logi_loc;
         ELSE
            UPDATE inv 
            SET qoh = qoh - lQtyAlloc
            WHERE inv.logi_loc = recInv.logi_loc;
         END IF; 

         UPDATE ordd
         SET qty_alloc = NVL(qty_alloc, 0) + lQtyAlloc
         WHERE order_id = recFD.order_id
         AND order_line_id = recFD.order_line_id;

         --
         -- Exit if all of the quantity for the float_detail record has been allocated.
         --
         IF lQtyRemain = 0 THEN
            EXIT;
         END IF;

         --
         -- If it reaches this point, it did not completely fill the order,
         -- try to fill the remaining on the next inventory record.
         --
         CreateFloatDetailRecord(lFloatNo, lSeqNo, lQtyRemain, 2, -1, lNextSeq);
         lSeqNo := lNextSeq;
         lQtyReq := lQtyReq - lQtyAlloc;
         lQtyOrder := lQtyRemain;

      END LOOP; -- End inventory loop
   END LOOP; -- End float_detail loop

   IF (l_rc_inv%ISOPEN) THEN
      CLOSE l_rc_inv;
   END IF;

   --
   -- Don't update the float_detail.status to SHT, leave it as is so that
   -- the alloc from home or the alloc floating process can continue to try
   -- to fill the order from there.
   --

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      o_status := sqlcode;

END AllocCustStagingItems;

---------------------------------------------------------------------------
-- Procedure:
--    AllocMiniloadItems
--
-- Description:
--    Ths procedures allocates inventory for miniload items.
--
-- Parameters:
--
-- Called By:
--
-- Exceptions raised:
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/13 prpbcb   Modify processing if a lock in encountered.
--                      Use a REF CURSOR.
--    04/23/13 sray0453 Charm#6000001046
--                      Items at induction location with INV_UOM as 0 
--                      also need to be considered for allocation.
--    01/27/16 bben0556 Brian Bent
--                      Only allocate full case quantities from a miniloader case
--                      carrier for case orders.  Any remaining splits will be
--                      left on the carrier which should show on the miniloader
--                      item recon.  For some reason the case carrier sometimes(not often)
--                      has splits which results in allocating not a full case
--                      to the case order which causes SOS RF to crash. 
---------------------------------------------------------------------------
PROCEDURE AllocMiniloadItems
     (pRouteNo   IN  VARCHAR2,
      pStatus    OUT NUMBER)
IS

   l_object_name  VARCHAR2(30) := 'AllocMiniloadItems';
   l_message      VARCHAR2(1000);

   l_rc_alloc_miniload_items  SYS_REFCURSOR;
   recML                      t_r_alloc_miniload_items;

   l_rc_inv   SYS_REFCURSOR;
   recInv     t_r_miniload_items_inv;

   lv_fname   VARCHAR2 (30) := 'AllocMiniloadItems';
   lQtyAlloc   NUMBER := 0;
   lFloatNo    NUMBER := 0;
   lUOM       NUMBER := 0;
   lSeqNo       NUMBER := 0;
   lNextSeq    NUMBER := 0;
   lQtyReq    NUMBER := 0;
   lQtyOrder    NUMBER := 0;
   lQtyRemain    NUMBER := 0;
   l_priority   INTEGER;
   lStatus      VARCHAR2 (10);
   l_rec      pl_miniload_processing.t_exp_receipt_info;
   numStatus   NUMBER;
   CreateNewFD      NUMBER (1) := 1;
   p_new_ord_lin_id   NUMBER;
   lInv_UOM   NUMBER (2) := 0;
   pRouteBatchNo   NUMBER;
   l_o_uom      NUMBER (2) := NULL;
BEGIN
   --
   --
   -- Create Demand Replenishments for mini load items that
   -- have cases slotted to mini load with reserves in the 
   -- main warehouse.
   --
   SELECT route_batch_no
     INTO pRouteBatchNo
     FROM route
    WHERE route_no = pRouteNo;

   pl_ml_repl.p_create_ml_case_rpl
      (i_call_type       => 'DMD',
       i_route_batch_no  => pRouteBatchNo,
       i_route_no        => pRouteNo,
       o_Status          => pStatus);

   -- This process is modified slightly.
   -- Here is how it works now.
   --
   -- 1.   Check if any of the mini-load items that are on the
   --   current route require replenishments
   -- 2.   If you find any that need replenishment create the
   --   ML replenishments.
   -- 3.   After Step 2, if the product is available in the warehouse,
   --   they will be available for shipment either from the miniload
   --   itself or from the induction location.
   --
   -- 4.   Perform the order allocation
   --
   -- 5.   If there are any records that are not completely allocated,
   --   change their status to 'SHT'
   --

   pStatus := 0;

   BEGIN
      SELECT priority_value
        INTO l_priority
        FROM priority_code
       WHERE priority_code = 'URG'
         AND unpack_code   = 'Y';
      EXCEPTION
         WHEN OTHERS THEN
            l_priority := 15;
   END;

   --
   -- Find all order items on this route that are in the miniload
   -- but do not have enough QOH in the miniload to fill the order
   -- and create miniload replenishments for them
   --
   FOR recNeedRepl IN (SELECT prod_id,
                              cpv,
                              uom,
                              d_order,
                              q_avail,
                              q_0_avail
                         FROM v_ml_spl_rpl_info
                        WHERE route_no = pRouteNo)
   LOOP
      --
      -- This is a mini-load item and there is not enough quantity available
      -- in the mini-load. Try to get replenishment to the miniload.
      --
      lqtyReq := recNeedRepl.d_order - recNeedRepl.q_avail - recNeedRepl.q_0_avail;

      pl_replenishments.create_ML_repl
                           (lQtyReq,
                            recNeedRepl.Prod_Id,
                            recNeedRepl.CPV,
                            l_priority,
                            pRouteNo,
                            NULL,
                            lQtyAlloc,
                            lStatus);
   END LOOP;


   --
   -- Allocate inventory to the miniloader items on the route.
   --
   -- At this point the float detail record(s) are built for the item based
   -- on the qty ordered and how the item is assigned to the float zone.
   -- So if an item is all in the same float and float zone then there will
   -- be 1 FLOAT_DETAIL record.  If the item got broken across 2 zones then
   -- there will be 2 FLOAT_DETAIL records.
   -- The FLOAT_DETAIL SRC_LOC and CARRIER are blank at this point.
   -- Now inventory needs to be allocated.  This is done by looping through
   -- each FLOAT_DETAIL record and allocating inventory to it.
   -- The float detail record will be updated with the location and carrier
   -- allocated to it.  If the carrier did not have enough inventory to
   -- cover the FLOAT_DETAIL QTY_ORDER and additional inventory records are
   -- needed then another FLOAT_DETAIL record is created.
   -- Basically for floating items and miniloader items there will be one
   -- float detail record for each INV record allocated to the order.
   --
   FOR lUOM IN REVERSE 1..2
   LOOP
      DBMS_OUTPUT.PUT_LINE ('In Reverse Loop');
      -- IF (lUOM = 1) THEN EXIT; END IF;

      open_rc_alloc_miniload_items(l_rc_alloc_miniload_items,
                                   pRouteNo,
                                   lUOM);
                                   
      LOOP
         FETCH l_rc_alloc_miniload_items INTO recML;
         EXIT WHEN l_rc_alloc_miniload_items%NOTFOUND;

         DBMS_OUTPUT.PUT_LINE ('In recML Loop');

         lFloatNo   := recML.float_no;
         lSeqNo     := recML.seq_no;
         lQtyReq    := recML.qty_order;
         lQtyOrder  := recML.qty_order;
         lQtyRemain := lQtyOrder;
         l_o_uom    := recML.orig_uom;

         open_rc_miniload_items_inv(l_rc_inv,
                                    recML.prod_id,
                                    recML.cust_pref_vendor,
                                    recML.ml_ind,
                                    recML.UOM);

         LOOP
            FETCH l_rc_inv INTO recInv;
            EXIT WHEN l_rc_inv%NOTFOUND;

            --
            -- Log message if the qty available and/or qoh
            -- are not the same as the effective qty available
            -- and effective qoh.  A difference means we have a
            -- case carrier with splits and/or a screwed up qty alloc.
            --
            IF (   recInv.effective_qty_avail <> recInv.QtyAvail
                OR recInv.effective_qoh <> recInv.qoh)
            THEN
               l_message := 'There is an inventory record that has splits when there should be only cases.'
                    || '  The splits will be left in inventory and not allocated to an order.'
                    || '  The inventory needs to be cycle counted.'
                    || '  prod_id['              || recML.prod_id              || ']'
                    || '  CPV['                  || recML.cust_pref_vendor     || ']'
                    || '  SPC['                  || TO_CHAR(recML.spc)         || ']'
                    || '  order_id['             || recML.order_id             || ']'
                    || '  qty_order['            || TO_CHAR(recML.qty_order)   || ']'
                    || '  LP['                   || recInv.logi_loc            || ']'
                    || '  inv_uom['              || TO_CHAR(recInv.inv_uom)    || ']'
                    || '  qoh['                  || recInv.qoh                 || ']'
                    || '  qty_alloc['            || recInv.qty_alloc           || ']'
                    || '  QtyAvail['             || recInv.QtyAvail            || ']'
                    || '  effective_qoh['        || recInv.effective_qoh       || ']'
                    || '  effective_qty_avail['  || recInv.effective_qty_avail || ']'
                    || '  recML.UOM['            || TO_CHAR(recML.UOM)         || ']';

               pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);
            END IF;


            IF (recInv.effective_qty_avail < lQtyRemain) THEN
               lQtyAlloc := recInv.effective_qty_avail;
               lQtyRemain := lQtyOrder - recInv.effective_qty_avail;
            ELSE
               lQtyAlloc := lQtyOrder;
               lQtyRemain := 0;
            END IF;

      --    IF (lQtyAlloc = 0) THEN    -- 02/02/2016  Comment out
      --       EXIT;
      --    END IF;

            IF (    lQtyAlloc = recInv.effective_qoh
                AND recInv.qty_alloc = 0
                AND recInv.effective_qoh = recInv.qoh)   -- 02/02/2016 Brian Bent Added
            THEN
               DELETE inv
                WHERE logi_loc =  recInv.logi_loc;
                -- WHERE CURRENT OF curInv;
            ELSE
               UPDATE inv
                  SET qoh = qoh - lQtyAlloc
                WHERE logi_loc = recInv.logi_loc;
                -- WHERE CURRENT OF curInv;
            END IF;

            IF (lQtyRemain > 0) THEN
               DECLARE
                  lqoh   NUMBER (6) := 0;
               BEGIN
                  SELECT c1, c2
                    INTO CreateNewFD, lInv_UOM
                    FROM (SELECT 1 c1, inv_uom c2
                            FROM inv
                           WHERE prod_id           = recML.prod_id
                             AND cust_pref_vendor  = recML.cust_pref_vendor
                             AND status            = 'AVL'
                             AND (qoh - qty_alloc) >= DECODE(NVL(recML.orig_uom, recML.uom),
                                                             1, 0,
                                                             recML.spc)
                           ORDER BY inv_uom DESC)
                   WHERE ROWNUM = 1;

               DBMS_OUTPUT.PUT_LINE ('Create New FD = 1 ' || ' o_uom = ' ||
                  recML.orig_uom || ', UOM = ' || recML.uom);
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                     CreateNewFD := 0;
                     lInv_UOM := -1;
               END;
            END IF;

            UPDATE float_detail
               SET qty_alloc = lQtyAlloc,
                   qty_order = DECODE(recML.orig_uom,
                                      1, DECODE(CreateNewFD, 1, lQtyAlloc, qty_order),
                                      DECODE(CreateNewFD, 0, qty_order, lQtyAlloc)),
                   status = 'ALC',
                   cube = DECODE(uom, 1, recML.split_cube, recML.case_cube) * lQtyAlloc
                          / DECODE(uom, 1, 1, recML.spc),
                   src_loc     = recInv.plogi_loc,
                   alloc_time  = SYSDATE,
                   rec_id      = recInv.rec_id,
                   mfg_date    = recInv.mfg_date,
                   exp_date    = recInv.exp_date,
                   lot_id      = recInv.lot_id,
                   carrier_id  = recInv.logi_loc
             WHERE float_no = lFloatNo
               AND seq_no   = lSeqNo;

            UPDATE ordd
               SET qty_alloc = NVL(qty_alloc, 0) + lQtyAlloc
             WHERE order_id      = recML.order_id
               AND order_line_id = recML.order_line_id;

            IF (recInv.induction_loc = recInv.plogi_loc)
            THEN
               BEGIN
                  l_rec.v_msg_type            := pl_miniload_processing.CT_EXP_REC;
                  l_rec.v_expected_receipt_id := recInv.logi_loc;
                  l_rec.v_prod_id             := recML.prod_id;
                  l_rec.v_cust_pref_vendor    := recML.cust_pref_vendor;
                  l_rec.n_uom                 := recML.uom;
                  l_rec.n_qty_expected        := recInv.effective_qoh - lQtyAlloc;
                  l_rec.v_inv_date            := recInv.exp_date;

                  pl_miniload_processing.p_send_exp_receipt (l_rec, lStatus, 'N');

                  IF (lStatus = pl_miniload_processing.ct_er_duplicate) THEN
                     numStatus := pl_miniload_processing.ct_success;
                  END IF;
               END;
            END IF;

            IF (   lQtyRemain = 0
                OR CreateNewFD = 0
                OR (recML.uom = 2 AND lInv_UOM NOT IN (0,2)))
            --    (recML.uom = 2 AND lInv_UOM != 2))
            THEN
               EXIT;
            END IF;

            SELECT   MAX (seq_no) + 1
              INTO   lNextSeq
              FROM   float_detail
             WHERE   float_no = recML.float_no;

            INSERT   INTO float_detail
               (float_no,
                seq_no,
                zone,
                stop_no,
                prod_id,
                src_loc,
                multi_home_seq,
                uom,
                qty_order,
                qty_alloc,
                merge_alloc_flag,
                merge_loc,
                status,
                order_id,
                order_line_id,
                cube,
                copy_no,
                merge_float_no,
                merge_seq_no,
                cust_pref_vendor,
                clam_bed_trk,
                route_no,
                route_batch_no,
                order_seq)
            SELECT float_no,
                   lNextSeq            seq_no,
                   zone,
                   stop_no,
                   prod_id,
                   NULL                src_loc,
                   multi_home_seq,
                   uom,
                   lQtyRemain          qty_order,
                   0                   qty_alloc,
                   merge_alloc_flag,
                   merge_loc,
                   'NEW'               status,
                   order_id,
                   order_line_id,
                   0                   cube,
                   copy_no,
                   merge_float_no,
                   merge_seq_no,
                   cust_pref_vendor,
                   clam_bed_trk,
                   route_no,
                   route_batch_no,
                   order_seq
              FROM float_detail
             WHERE float_no = lFloatNo
               AND seq_no = lSeqNo;

            l_message := 'Created additional FLOAT_DETAIL record from record with float_no=' || TO_CHAR(lFloatNo)
                    || ' and seq_no=[' || TO_CHAR(lSeqNo) || '].  The seq_no of the new record is [' || lNextSeq || ']'
                    || '  prod_id['               || recML.prod_id             || ']'
                    || '  CPV['                   || recML.cust_pref_vendor    || ']'
                    || '  order_id['              || recML.order_id            || ']'
                    || '  qty_order(lQtyRemain)[' || TO_CHAR(lQtyRemain)       || ']';

            pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                           NULL, NULL,
                           ct_application_function, gl_pkg_name);

            lSeqNo := lNextSeq;
            lQtyReq := lQtyReq - lQtyAlloc;
            lQtyOrder := lQtyRemain;

         END LOOP;  -- end FETCH l_rc_inv INTO recInv


         IF (l_rc_inv%ISOPEN) THEN
            CLOSE l_rc_inv;
         END IF;

         IF (lQtyRemain > 0 and lUOM = 2 AND NVL(l_o_uom, -1) = 1)
         THEN
            --
            -- There are no more cases available to fill the order.
            -- Check if the order was originally in splits. If it
            -- was, check if split ordd/float details have been
            -- created for this sys order. If they are there, update
            -- the quantity on them. If they don't exist, create
            -- them.
            --
            l_msg := 'Calling From AllocMiniloadItems: ' ||
                'pl_alloc_inv.CreateOrdd ( ' || recML.order_id || ', ' ||
                recML.order_line_id || ', ' || recML.prod_id ||
                ', ' || recML.cust_pref_vendor || ', ' ||
                lQtyRemain || ', ' || p_new_ord_lin_id || ')';

            pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);

            CreateOrdd ( recML.order_id, recML.order_line_id,
               recML.prod_id, recML.cust_pref_vendor,
               lQtyRemain, p_new_ord_lin_id);

            l_msg := 'Calling From AllocMiniloadItems: ' ||
                'CreateFloatDetailRecord ( ' || recML.Float_No || ', ' ||
                recML.Seq_no || ', ' || lQtyRemain || ', ' ||
                p_new_ord_lin_id || ', ' || lNextSeq || ')';
            pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);

            CreateFloatDetailRecord (recML.Float_No, recML.Seq_No,
               lQtyRemain, 1, p_new_ord_lin_id, lNextSeq);

            l_msg := 'Return From: CreateFloatDetailRecord. Next Seq = ' || lNextSeq;
            pl_text_log.ins_msg ('W', lv_fname, l_msg, NULL, NULL);

         END IF;

      END LOOP;  -- end FETCH l_rc_alloc_miniload_items INTO recML

      IF (l_rc_alloc_miniload_items%ISOPEN) THEN
         CLOSE l_rc_alloc_miniload_items;
      END IF;

   END LOOP;  -- end FOR lUOM IN REVERSE 1..2


   --
   -- If there are any more items for this route that are
   -- not still fully allocated, change all their statuses to SHT.
   --

   DBMS_OUTPUT.PUT_LINE ('AFTER MAIN LOOP');

   FOR r IN (
      SELECT   f.float_no, d.seq_no
        FROM   pm p, float_detail d, floats f
       WHERE   f.route_no                        = pRouteNo
         AND   f.float_no                        = d.float_no
         AND   f.pallet_pull                     = 'N'
         AND   NVL (p.miniload_storage_ind, 'N') != 'N'
         AND   d.status                          IN ('NEW', 'ALC')
         AND   d.merge_alloc_flag                IN ('X','Y')
         AND   d.prod_id                         = p.prod_id
         AND   d.cust_pref_vendor                = p.cust_pref_vendor
         AND   p.status                          = 'AVL'
         AND   NVL (d.qty_alloc, 0)              < d.qty_order)
   LOOP
      UPDATE   float_detail
         SET   status = 'SHT'
       WHERE   float_no = r.float_no
         AND   seq_no = r.seq_no;
   END LOOP;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN NULL;
      WHEN OTHERS THEN
         pStatus := SQLCODE;
END AllocMiniloadItems;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_home_inv
--
-- Description:
--    This procedure opens a ref cursor used when allocating inventory
--    from a home slot.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_home_inv      - 
--    i_prod_id           - 
--    i_cust_prev_vendor  - 
--    i_uom               - 
--
-- Called by:
--    - alloc_inv.pc
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/12/13 prpbcb   Created.
---------------------------------------------------------------------------
PROCEDURE open_rc_home_inv
                (io_rc_home_inv       IN OUT SYS_REFCURSOR,
                 i_prod_id            IN     inv.prod_id%TYPE,
                 i_cust_pref_vendor   IN     inv.cust_pref_vendor%TYPE,
                 i_uom                IN     inv.inv_uom%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(128);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_home_inv';

   l_base_select_stmt       VARCHAR2(2000);  -- ORDD select stmt
   l_select_stmt_with_wait  VARCHAR2(2000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
  pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                 NULL, NULL,
                 ct_application_function, gl_pkg_name);

   --
   -- Build the statement that selects the home slot for the item.
   --
   l_base_select_stmt :=
         'SELECT p.spc,
                 p.case_cube,
                 p.split_cube,
                 i.plogi_loc,
                 i.logi_loc,
                 i.qty_planned,
                 i.qoh,
                 i.qty_alloc,
                 (i.qoh - NVL (i.qty_alloc, 0)) qty_avail,
                 i.exp_date,
                 i.mfg_date,
                 i.rec_date,
                 i.rec_id,
                 i.lot_id
            FROM pm p,
                 loc l,
                 inv i
           WHERE i.prod_id          = :prod_id
             AND i.cust_pref_vendor = :cpv
             AND p.prod_id          = :prod_id
             AND p.cust_pref_vendor = :cpv
             AND i.inv_uom          IN (:uom, 0)
             AND i.plogi_loc        = i.logi_loc
             AND i.status           = ''AVL''
             AND l.logi_loc         = i.plogi_loc
             AND l.perm             = ''Y''
             AND l.status           = ''AVL''
           ORDER BY NVL(l.assign, -1), l.rank
             FOR UPDATE OF i.qoh';
          -- AND i.qoh - NVL (i.qty_alloc, 0) > 0


   l_message_2 :=
            'ITEM['  || i_prod_id || ']'
         || '  CPV[' || i_cust_pref_vendor || ']'
         || '  UOM[' || TO_CHAR(i_uom) || ']';

   --
   -- First wait x seconds if there is a lock.
   --
   l_select_stmt_with_wait := l_base_select_stmt || ' ' || ct_sel_for_update_wait_time;

   --
   -- Start a new block so the record lock exception can be trapped.
   --
   BEGIN
      --
      -- Write log message to track what is going on.
      --
      l_message := 'LOCK MSG-TABLE=pm,loc,inv'
           || '  KEY=[' || i_prod_id || ']'
           ||       '[' || i_cust_pref_vendor || ']'
           ||       '[' ||TO_CHAR(i_uom) || ']'
           || '(i_route_no,i_cust_pref_vendor,i_uom)'
           || '  ACTION="Open Ref Cursor  OPEN ... FOR SELECT ... FOR UPDATE OF i.qoh" '
           || ct_sel_for_update_wait_time
           || '  MESSAGE="Executing select"';

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, l_message,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with ' || ct_sel_for_update_wait_time);

      OPEN io_rc_home_inv FOR l_select_stmt_with_wait
         USING i_prod_id,
               i_cust_pref_vendor,
               i_prod_id,
               i_cust_pref_vendor,
               i_uom;

      --
      -- If this point reached then the select for update wait x was successful.
      --
      -- Log a message.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name,
                     'LOCK MSG-"SELECT FOR UPDATE '
                     || ct_sel_for_update_wait_time || '"'
                     || ' succeeded for ' || l_message_2,
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                     NULL, NULL,
                     ct_application_function, gl_pkg_name);

   EXCEPTION
      WHEN e_record_locked_after_waiting THEN
         --
         -- If this point reached then there was still a lock after
         -- waiting x seconds.
         -- Log a message then wait for the lock to be released.
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name || ' SELECT with '
                  || ct_sel_for_update_wait_time || ' failed, resource busy');

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Order generation is held up due to a lock(s) on the inventory (INV) by another user'
                     || ' on the home slot for ' || l_message_2 || '.'
                     || '  Who has the locks are in the next message(s).',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         --
         -- The CURSOR wants to lock the INV table so list the locks on the
         -- table.
         --
         pl_log.locks_on_a_table('INV', SYS_CONTEXT('USERENV', 'SID'));

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-"Order generation will wait for the lock(s) on INV to be released before continuing processing...',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         OPEN io_rc_home_inv FOR l_base_select_stmt 
            USING i_prod_id,
                  i_cust_pref_vendor,
                  i_prod_id,
                  i_cust_pref_vendor,
                  i_uom;
         --
         -- Select for update finished.  Log a message.
         --
         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name,
                     'LOCK MSG-Lock released on the home slot inventory (INV)'
                     || ' for ' || l_message_2 || '.'
                     || '  Order generation is continuing.',
                     NULL, NULL,
                     ct_application_function_user, gl_pkg_name);

         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         --
         -- Because of our strange we handle the global variable 
         -- pl_log.g_application_func in pl_log it needs to be set back
         -- to ct_application_function otherwise it could be left at
         -- ct_application_function_user which we do not want.
         --
         pl_log.g_application_func := ct_application_function;
 
      WHEN OTHERS THEN
         RAISE;
   END;
EXCEPTION
   WHEN OTHERS THEN
      l_message := l_object_name
         || '(io_rc_home_inv,i_prod_id,i_cust_pref_vendor,i_uom)'
         || '  i_prod_id['           || i_prod_id || ']'
         || '  i_cust_pref_vendor['  || i_cust_pref_vendor || ']'
         || '  i_uo['                || TO_CHAR(i_uom) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                                       l_object_name || ': ' || SQLERRM);
END open_rc_home_inv;


END pl_alloc_inv;
/

show errors

-- CREATE OR REPLACE PUBLIC SYNONYM pl_alloc_inv FOR swms.pl_alloc_inv
-- /
-- GRANT EXECUTE ON pl_alloc_inv TO swms_user
-- /
