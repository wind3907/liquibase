/************
 Jan-10-2017 Brian Bent Fix the SHT issue that cause when there is NDM case to split replenishment

************/

create or replace PACKAGE      swms.pl_replenishments
IS
/*****************************************************************/
/* sccs_id=%Z% %W% %G% %I% */
/*****************************************************************/
---------------------------------------------------------------------------
-- Package Name:
--    pl_replenishments
--
-- Description:
--    Package for generating demand replenishments during order processing.
--   Invoked from order processing program during inventory allocation.
--
-- Main Procedures:
--  CREATE_CASE_HOME_REPL:  generates replenishments to case homes
--  CREATE_SPLIT_HOME_REPL: generates replenishments to split homes.
-- Sub Procedures:
--  CHECK_FOR_NDR:  checks for any non-demand repls and processes them
--  ACQUIRE_NDM_REPL: Acquire a non-demand replenishment that has already
--                     started
--  DELETE_NDM_REPL:  Delete non-demand replenishments that have not yet
--                     started.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/26/02 prpnxk   Initial Version
--    09/10/02 prpbcb   rss239a DN 11010  rs239b DN 11011  Ticket 342562
--                      Fix bug in procedure create_case_home_repl when
--                      acquiring a non-demand replenishment in PIK status.
--                      When the non-demand replenishment was acquired
--                      the qty that went to the case home slot was not
--                      being assigned to variable io_qty_repld.
--    02/06/03 prpbcb   rs239a DN none
--                      rs239b DN 11179  Ticket 361712
--                      Changed selecting of the dest loc in cursor repl_cur
--                      in procedure delete_ndm_repl
--                      from
--                         r.dest_loc
--                      to
--                         NVL(r.inv_dest_loc, r.dest_loc) dest_loc
--                      to handle carton/pallet flow slots.
--                      What was happening is the home slot qty_planned
--                      was not being reduced by the repl qty.
--   11/17/06  prpakp   Corrected to check qoh-qty_alloc for home locations.
--  04/25/07  prpakp   Added a flag with default N to create_case_home_repl
--           procedure to identify whether this is called from
--         pl_alloc_inv.update_pallet_inv procedure.
--
--    05/11/10 prpbcb   DN 12603
--                      Project:
--                        CRQ20684-Split miniloader replenishments not on RF
--
--                      Miniloader priority 15 replenishments from main
--                      warehouse to the miniloader not showing
--                      on the RF because replenlst.s_pikpath was not
--                      populated.
--                      Added the location pik path to cursor c_ML_Replen
--                      and changed procedure create_ML_rep() to populate
--                      replenlst.s_pikpath.
--
--                      Rearrange parentheses in cursor c_ML_Replen in
--                      procedure create_ML_repl() to fix issue with
--                      replenishments when the cases are stored in the
--                      main warehouse and the splits are in the
--                      miniloader.
--
--    03/18/13 prpbcb00 TFS Project:
-- R12.5.1--WIB#109--CRQ45202:Non-demand replenishments by min/max qty ignoring min qty
--
--                      Created procedure:
--                         - set_replen_type()
--                      Created function:
--                         - get_replen_type()
--
--                      get_replen_type() is used in view V_NDM_REPLEN_INFO.
--                      The view needs to know what
--                      replenishment type is being created in order to process
--                      CF and HS correctly when replenishing by min/max.
--                      The replenishment types are shown below and came from
--                      create_ndm.pc
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--
--                      This type is significant because there is different
--                      processing when creating replenishments by min/max
--                      qty for HS or CF home slot.  The rules for min/max
--                      qty for HS and CF home slots are:
--                         - For historical orders and store orders,
--                           types H and O, create a replenishment if the
--                           qty in the home slot is < order quantity and
--                           the qty in the home slot is < max qty.
--                         - For the other types, L and R, create a
--                           replenishment when the qty in the home slot
--                           is <= min qty.
--
--                      I changed the view 2 months ago per a request by
--                      Distribution Services to create a NDM replenishment
--                      if the qty in the home slot is less than the max qty
--                      when processing historical orders.  The change I made
--                      does it for all NDM replenishments when replenishing
--                      by min/max qty--basically the min qty is ignored.
--                      The view will call get_replen_type to know what type
--                      is being processed.  The type will be set in
--                      create_ndm.pc by calling function set_replen_type
--                      If the replen type is not set then view
--                      V_NDM_REPLEN_INFO will default to 'R'.
--  19-Dec-13 sray0453 CRQ49435:
--             Priority of DMD Replenishment for CF/PF is not moving
--             up to level 15 when batch is Active/Completed.
--             Insert_Replenishment is changed to fetch plogi_loc
--             from loc_reference if Pallet flow is enabled.
--                 V_REPLEN_BULK refers inv_dest_loc for DMD priority.
--
--    11/16/15 chua6448 Charm 6000003010
--                      Project: Modify the Swap Logic
--
--    02/09/16 bben0556 Brian Bent
--                      Project:
--       R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--                      Tag along changes to this project.
--
--                      When creating miniloader case to split demand replenishment
--                      and the case has erroneous splits (for whatever reason)
--                      the replenshment qty is incorrect though the total qty
--                      is allocated to the order which is incorrect too.
--                      The splits on the case carrier needs to be ignored as
--                      far as being available to the replenishment
--
--                      Modified procedure "create_ML_repl()"
--                         Changed cursor c_ML_Replen.
--                         Added:
--                            p.spc * TRUNC(i.qoh / p.spc)        effective_qoh
--                            p.spc * TRUNC(i.qty_alloc / p.spc)  effective_qty_alloc
--
--    07/19/16 bben0556 Brian Bent
--                            Project:
--          R30.4.3--WIB#xxx--Charm_xxxx_Save_what_created_NDM_in_trans_RPL_record
--
--                      Created function:
--                         - get_task_priority()
--                           It gets the forklift task priority from table
--                           USER_DOWNLOADED_TASKS which is then used to
--                           populate TRANS.REPLEN_FORKLIFT_TASK_PRIORITY.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/25/16 bben0556 Brian Bent
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Changed to populate replenlst site_from, site_to, cross_dock_type and replenlst.xdock_pallet_id
--                      with the floats.cross_dock_type and floats.xdock_pallet_id
--                      for bulk/combine pulls.
--
--                      Modified procedure Insert_Replenishment:
--                         Change cursor "c_floats" select:
--                            floats.site_from
--                            floats.site_to
--                            floats.cross_dock type
--                            floats.xdock_pallet_id
--                         Populate
--                            replenlst.site_from
--                            replenlst.site_to
--                            replenlst.cross_dock type
--                            replenlst.xdock_pallet_id
--
--                      README   README   README   README   README   README
--                      README   README   README   README   README   README
--                      There is an issue with replenlst site_from, site_to 
--                      and xdock_pallet_id not getting
--                      populated because floats site_from, site_to and xdock_pallet_id
--                      have yet to be assiged values--they get assigned after the bulk pulls
--                      and normal floats created.  So what I did is change procedure
--                      "pl_xdock_op.update_floats" to update replenlst.
--                      I left my above changes in this file as is.
--
--
---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------
   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------
  g_home_slot_sort     VARCHAR2 (1) := NULL;
  g_bulk_pull      VARCHAR2 (1) := NULL;
  g_enable_pallet_flow    VARCHAR2 (1) := NULL;

   ---------------------------------------------------------------------------
   -- Public Constants
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Procedure Declarations
   ---------------------------------------------------------------------------
   PROCEDURE  check_for_ndr (  i_dest_loc      IN      replenlst.dest_loc%TYPE,
          io_rpl_qty      IN OUT  replenlst.qty%TYPE,
          i_prod_id       IN      replenlst.prod_id%TYPE,
          i_route_no      IN      replenlst.route_no%TYPE);

  PROCEDURE  create_case_home_repl (i_dest_loc  IN  replenlst.dest_loc%TYPE,
          i_qty_reqd  IN  replenlst.qty%TYPE,
          i_prod_id  IN  replenlst.prod_id%TYPE,
          i_route_no  IN  replenlst.route_no%TYPE,
          i_stop_no  IN  float_detail.stop_no%TYPE,
          i_uom    IN  replenlst.uom%TYPE,
          i_order_id  IN  float_detail.order_id%TYPE,
          i_ord_line_id  IN  float_detail.order_line_id%TYPE,
          io_cpv    IN OUT  trans.cust_pref_vendor%TYPE,
          io_qty_repld  IN OUT  replenlst.qty%TYPE,
          i_pallet_pull   IN  floats.pallet_pull%TYPE DEFAULT 'N');

  PROCEDURE  create_split_home_repl (i_dest_loc  IN  replenlst.dest_loc%TYPE,
          i_qty_reqd  IN  replenlst.qty%TYPE,
          i_prod_id  IN  replenlst.prod_id%TYPE,
          i_route_no  IN  replenlst.route_no%TYPE,
          i_stop_no  IN  float_detail.stop_no%TYPE,
          i_uom    IN  replenlst.uom%TYPE,
          i_order_id  IN  float_detail.order_id%TYPE,
          i_ord_line_id  IN  float_detail.order_line_id%TYPE,
          io_cpv    IN OUT  replenlst.cust_pref_vendor%TYPE,
          io_qty_repld  IN OUT  replenlst.qty%TYPE);

  PROCEDURE create_ML_repl  (i_qty_reqd  IN  replenlst.qty%TYPE,
          i_prod_id  IN  replenlst.prod_id%TYPE,
          i_cpv    IN  replenlst.cust_pref_vendor%TYPE,
          i_priority  IN  replenlst.priority%TYPE,
          i_route_no  IN  replenlst.route_no%TYPE,
          i_order_id  IN  replenlst.order_id%TYPE,
          io_qty_repld  IN OUT  replenlst.qty%TYPE,
          io_status  IN OUT  VARCHAR2);

    --   Parameters in create_case_home_repl and create_split_home_repl
    --  ==============================================================
    --
    -- i_dest_loc    Location Being replenished
    -- i_qty_reqd    Requested replenishment qty
    -- i_prod_id    Product being replenished
    -- io_cpv    Customer Prefer Vendor
    -- i_route_no
    -- i_stop_no
    -- i_order_id
    -- i_order_line_id  Order details that caused this replenishment
    -- io_qty_repld    The actual quantity that was replenished. This may be different from the
    --      requested replenishment quantity.
    -- i_pallet_pull        if it is called from pallet_pull (pl_alloc_inv.update_pallet_inv) then this is set to Y.
    --      If this is set to Y, replenishment from rank1 to rank2 or rank2 to rank1 location is allowed.
    --      This is done to prevent shorts when all floats are pallet pull for an order and the case home
    --      doesn't have enough in the rank1 location.

  PROCEDURE delete_ndm_repl (i_task_id  IN replenlst.task_id%TYPE);
  PROCEDURE acquire_ndm_repl (i_task_id  IN replenlst.task_id%TYPE,
          i_route_no IN route.route_no%TYPE,
          o_rpl_qty OUT NUMBER);
  PROCEDURE Insert_Replenishment (i_float_no  floats.float_no%TYPE);


---------------------------------------------------------------------------
-- Procedure:
--    set_replen_type
--
-- Description:
--    This procedure sets the type of NDM replenishment being created.
--    The replen type is used in view V_NDM_REPLEN_INFO which calls
--    function get_replen_type() to get the replen type.
--    The view needs to know what replenishment type is being created in order
--    to process CF and HS correctly when replenishing by min/max.
--    The rules for HS and CF when replenishing by min/max qty are:
--    - For historical orders:
--         - Create a replenishment if the quantity in the home slot
--           is < max qty.
--    - For planned orders(store orders):
--         - Create a replenishment if the quantity in the home slot
--           is < order qty and is < max qty.
--
--    The replenishment types are shown below and came from
--    create_ndm.pc
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--    create_ndm.pc was modified to call this procedure before
--    running the query that selects from V_NDM_REPLEN_INFO.
--
--    I changed the view 2 months ago per a request by
--    Distribution Services to create a NDM replenishment
--    if the qty in the home slot is less than the max qty
--    when processing historical orders.  The change I made
--    does it for all NDM replenishments when replenishing
--    by min/max qty--basically the min qty is ignored.
--
-- Parameters:
--    none  - Local global variable gl_replen_type is set.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - create_ndm.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/18/13 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE set_replen_type(i_replen_type IN VARCHAR2);


---------------------------------------------------------------------------
-- Function:
--    get_replen_type
--
-- Description:
--    This function returns the value in pl_replenishments.gl_replen_type
--    which is the type of NDM replenishment being created.
--    The replen type is used in view V_NDM_REPLEN_INFO.
--    This view calls this function.
--    The view needs to know what replenishment type is being created in order
--    to process CF and HS correctly when replenishing by min/max.
--    The replenishment types are shown below and came from
--    create_ndm.pc
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--
--    create_ndm.pc calls set_replen_type before running the query that
--    selects from V_NDM_REPLEN_INFO.
--
--    I changed the view 2 months ago per a request by
--    Distribution Services to create a NDM replenishment
--    if the qty in the home slot is less than the max qty
--    when processing historical orders.  The change I made
--    does it for all NDM replenishments when replenishing
--    by min/max qty--basically the min qty is ignored.
--    The view will call get_replen_type to know what type
--    is being processed.  The type will be set in
--    create_ndm.pc by calling function set_replen_type
--
-- Parameters:
--    none
--
-- Return Values:
--    pl_replenishments.gl_replen_type
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - view V_NDM_REPLEN_INFO
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/18/13 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION get_replen_type
RETURN VARCHAR2;


--------------------------------------------------
-- Function:
--    get_task_priority
--
-- Description:
--    This functions returns the forklift task priority
--    from USER_DOWNLOADED_TASKS.PRIORITY for the replenishment
--    task id.
--
--    The we want to populate TRANS.FORKLIFT_TASK_PRIORITY with
--    this priority for the relevant transactions for reporting
--    purposes as requested by Distribution Services.
--
--    If the task id is not found in USER_DOWNLOADED_TASKS then
--    -1 is returned.
--    If an error occurs then a log message is created and
--    -1 is returned.
--    Not getting the priority is not a fatal error.
--
--    replen_drop.pc is also getting the priority and will
--    also use -1 if not found.
--
-- Parameters:
--    i_task_id
--    i_user_id
--
-- Return Value:
--    forklift task priority
--    -1 if not found on an error occurs.
--
-- Exceptions raised:
--    None.  An error will be written to swms log.
--
-- Called by:  (list not complete)
--    - pl_insert_replen_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    08/05/16 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_task_priority
              (i_task_id  IN user_downloaded_tasks.task_id%TYPE,
               i_user_id  IN user_downloaded_tasks.user_id%TYPE)
RETURN NUMBER;


--------------------------------------------------
-- Function:  (Public)
--    get_suggested_task_priority
--
-- Description:
--    This functions returns the forklift task priority
--    from USER_DOWNLOADED_TASKS.PRIORITY for the replenishment
--    task id.
--
--    The we want to populate TRANS.FORKLIFT_TASK_PRIORITY with
--    this priority for the relevant transactions for reporting
--    purposes as requested by Distribution Services.
--
--    If the task id is not found in USER_DOWNLOADED_TASKS then
--    -1 is returned.
--    If an error occurs then a log message is created and
--    -1 is returned.
--    Not getting the priority is not a fatal error.
--
--    replen_drop.pc is also getting the priority and will
--    also use -1 if not found.
--
-- Parameters:
--    i_user_id - This needs to include the OPS$ since this is how
--                the user id is stored in USER_DOWNLOADED_TASKS.
--
-- Return Value:
--    forklift task priority
--    -1 if not found on an error occurs.
--
-- Exceptions raised:
--    None.  An error will be written to swms log.
--
-- Called by:  (list not complete)
--    - pl_insert_replen_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    08/05/16 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_suggested_task_priority
              (i_user_id  IN user_downloaded_tasks.user_id%TYPE)
RETURN NUMBER;


---------------------------------------------------------------------------
-- Procedure:
--    p_ndm_repl_inv_swap
--
-- Description:
--    This procedure is used to rollback inventory related to ndm replenishment
--
-- Parameters:
--    i_loc_src_dest  - inventory location
--    o_status        - return status
--
-- Exceptions raised:
--    999 - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - cswap.fmb and swap.fmb
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/16/15 chua6448   Created
---------------------------------------------------------------------------
PROCEDURE p_ndm_repl_inv_swap(i_loc_src_dest IN replenlst.dest_loc%TYPE,
                                 o_status OUT NUMBER);

END pl_replenishments;
/

create or replace PACKAGE BODY      swms.pl_replenishments
IS
   ---------------------------------------------------------------------------
   -- Private Global Variables
   ---------------------------------------------------------------------------
   gl_pkg_name   VARCHAR2(20) := 'pl_replenishments';   -- Package name.  Used in
                                                        -- error messages.

   gl_replen_type  VARCHAR2(1) := NULL;  -- 3/18/2013  Brian Bent
                                 -- Added.  It is used to know what type of NDM
                                 -- replenishment is being created.  The type is needed
                                 -- by view V_NDM_REPLEN_INFO.  It is set by
                                 -- procedure set_replen_type() and retrieved by
                                 -- function get_replen_type().
                                 -- replenishment is being created.  The value can be:
   --       'L' - Created from RF using "Replen By Location" option
   --       'H' - Created from Screen using "Replen by Historical" option
   --       'R' - Created from screen with options other than "Replen by Historical"
   --       'O' - Created from cron when a store-order is received that requires a replenishment


   ---------------------------------------------------------------------------
   -- Private Constants
   ---------------------------------------------------------------------------

   ct_application_function VARCHAR2(15) := 'INVENTORY';  -- For pl_log message





  PROCEDURE  check_for_ndr (  i_dest_loc  IN  replenlst.dest_loc%TYPE,
          io_rpl_qty  IN OUT  replenlst.qty%TYPE,
          i_prod_id  IN  replenlst.prod_id%TYPE,
          i_route_no  IN  replenlst.route_no%TYPE) IS
    --
    --
    -- Check all non-demand replenishments for the product id which goes to the same home location.
    -- If any exists with PIK status, meaning someone has started working on it, but has not completed
    -- the replen yet, acquire that replenishment. If non-demand replen exists but is not in PIK status,
    -- delete the non-demand replen.
    --
    --
    CURSOR c_replenlst (c_prod_id VARCHAR2, c_dest_loc VARCHAR2) IS
      SELECT  status, qty, dest_loc, src_loc, batch_no, task_id, uom, pallet_id
        FROM  replenlst
       WHERE  prod_id = c_prod_id
         AND  NVL (inv_dest_loc, dest_loc) = c_dest_loc
                           AND  type = 'NDM'
         AND  NVL(op_acquire_flag, 'N') = 'N'
         FOR  UPDATE OF status;
    CURSOR c_splrpl (c_prod_id VARCHAR2, c_dest_loc VARCHAR2) IS
      SELECT  status, qty, dest_loc, src_loc, batch_no, task_id, uom, pallet_id
        FROM  replenlst
       WHERE  prod_id = c_prod_id
         AND  src_loc = c_dest_loc
                           AND  type = 'NDM'
                           AND  uom = 1
         AND  NVL(op_acquire_flag, 'N') = 'N'
         FOR  UPDATE OF status;
    ndr_qty    replenlst.qty%TYPE;
    l_msg      VARCHAR2 (2048);

  BEGIN
    io_rpl_qty := 0;
    FOR r_replenlst IN c_replenlst (i_prod_id, i_dest_loc)
    LOOP
      IF (r_replenlst.status = 'PIK') THEN
        pl_replenishments.acquire_ndm_repl (r_replenlst.task_id, i_route_no, ndr_qty);
        io_rpl_qty := io_rpl_qty + ndr_qty;
      ELSE
        pl_replenishments.delete_ndm_repl (r_replenlst.task_id);
      END IF;
    END LOOP;
    FOR r_splrpl IN c_splrpl (i_prod_id, i_dest_loc)
    LOOP
      IF (r_splrpl.status = 'PIK') THEN
        pl_replenishments.acquire_ndm_repl (r_splrpl.task_id, i_route_no, ndr_qty);
      ELSE
        io_rpl_qty := io_rpl_qty + r_splrpl.qty; -- Commented out by spin4795 on 4/13/17.     -- xxxxxxxxxxxx uncomment
        pl_replenishments.delete_ndm_repl (r_splrpl.task_id);
      END IF;

      l_msg := 'check_for_ndr : prod_id = ' || i_prod_id || ', dest_loc = ' || i_dest_loc || ', io_rpl_qty = ' || to_char(io_rpl_qty);
      pl_log.ins_msg ('DEBUG', 'check_for_ndr', l_msg, NULL, SQLERRM);
      DBMS_OUTPUT.PUT_LINE (l_msg);

    END LOOP;
  END;


PROCEDURE create_case_home_repl
            (i_dest_loc     IN      replenlst.dest_loc%TYPE,
             i_qty_reqd     IN      replenlst.qty%TYPE,
             i_prod_id      IN      replenlst.prod_id%TYPE,
             i_route_no     IN      replenlst.route_no%TYPE,
             i_stop_no      IN      float_detail.stop_no%TYPE,
             i_uom          IN      replenlst.uom%TYPE,
             i_order_id     IN      float_detail.order_id%TYPE,
             i_ord_line_id  IN      float_detail.order_line_id%TYPE,
             io_cpv         IN OUT  trans.cust_pref_vendor%TYPE,
             io_qty_repld   IN OUT  replenlst.qty%TYPE,
             i_pallet_pull  IN      floats.pallet_pull%TYPE DEFAULT 'N')
IS
   l_object_name  VARCHAR2(30)  :=   'create_case_home_repl';

    --
    -- Replenish case home.
    -- Here is a brief note on how this procedure works. At this point, the order processing routine
    -- has already decided that it needs to drop inventory to the pick slot before it could continue
    -- the item selection process. The required quantity is passed to this procedure as a parameter.
    -- The calling program does not adjust the required quantity if some of it is already available
    -- in the home slot. So, this procedure does that adjustment to decide the replenishment quantity.
    --
    -- 1. Check if there is any non-demand replenishments that are being processed (status = 'PIK').
    --    If there is, acquire them. If there is one with NEW or PRE status, delete the replenishment.
    --
    -- 2. If any replenishment is acquired, adjust the quantity required.
    --
    -- 3. Transfer quantity to the case home location until the require quantity is filled.
    --
    -- Although replenishment can be performed from any location, there is an order in which
    -- it should be done.
    --
    -- 1. Replenish from reserve locations.
    -- 2. If there is no qty in reserve, replenish from another case home (if it exists).
    -- 3. Replenish from split home (it it exists).
    --
    -- This logic is built into the DECODE statement for sort_exp_date. it gives the highest
    -- number for split home, 1 less for case home and the actual exp date for reserve locations
    -- That way, when it is sorted by exp date, the case and split homes are move to the end.
    --
    -- trunc (qoh / spc) * spc - Replenishments has to be done either as a case or as a pallet.
    -- Adjust the qoh in such a way that it truncates to the maximum number of cases at the location.
    --

   CURSOR c_replen (cp_prod_id VARCHAR2, cp_cpv VARCHAR2, cp_dest_loc VARCHAR2)
   IS
      SELECT i.plogi_loc,
             trunc (qoh / p.spc) * p.spc qoh,
             i.qty_alloc,
             i.qoh - (trunc (qoh / p.spc) * p.spc) qoh_remain,
             i.rec_id,
             i.lot_id,
             NVL (i.exp_date, SYSDATE) exp_date,
             i.exp_ind,
             i.inv_date,
             NVL (i.rec_date, SYSDATE) rec_date,
             i.mfg_date,
             i.logi_loc,
             p.min_qty,
             DECODE(i.logi_loc,
                    i.plogi_loc, DECODE(l.uom, 1, SYSDATE + 1001, SYSDATE + 1000),
                    NVL(i.exp_date, SYSDATE)) sort_exp_date,
             l.uom,
             l.pik_path,
             i.parent_pallet_id
        FROM loc l,
             pm p,
             inv i,
             lzone lz,
             zone z
       WHERE i.prod_id                  = cp_prod_id
         AND i.cust_pref_vendor         = cp_cpv
         AND i.status                   = 'AVL'
         AND i.plogi_loc                != cp_dest_loc
         AND l.logi_loc                 = i.plogi_loc
         AND p.prod_id                  = i.prod_id
         AND p.cust_pref_vendor         = i.cust_pref_vendor
         AND TRUNC(qoh / p.spc) * p.spc > 0
         AND (   (i.plogi_loc = i.logi_loc and inv_uom = 1)
              OR (i.plogi_loc <> i.logi_loc)
              OR (i.plogi_loc = i.logi_loc and i_pallet_pull = 'Y')
             )
         AND i.inv_order_id             is NULL
         AND i.plogi_loc                = lz.logi_loc
         AND lz.zone_id                 = z.zone_id
         AND z.rule_id                  NOT IN ('9', '11', '13', '14')
       ORDER BY DECODE(i.logi_loc,
                       i.plogi_loc, DECODE(l.uom, 1, SYSDATE + 1001, SYSDATE + 1000),
                       NVL(i.exp_date, SYSDATE)),
                i.qoh,
                i.logi_loc
         FOR UPDATE OF qoh;

   CURSOR c_updinv (cp_prod_id VARCHAR2, cp_dest_loc VARCHAR2)
   IS
      SELECT inv.qoh - inv.qty_alloc qoh
        FROM inv
       WHERE inv.prod_id    = cp_prod_id
         AND inv.plogi_loc  = cp_dest_loc
         FOR UPDATE OF inv.qoh;

   r_updinv        c_updinv%ROWTYPE;
   r_replen        c_replen%ROWTYPE;
   l_NOROWS        BOOLEAN;
   l_zone_id       zone.zone_id%TYPE;
   l_equip_id      sel_method.equip_id%TYPE;
   l_group_no      sel_method.group_no%TYPE;
   l_ndr_qty       replenlst.qty%TYPE := 0;
   l_rpl_qty       replenlst.qty%TYPE := i_qty_reqd;
   l_float_no      floats.float_no%TYPE;
   l_msg           VARCHAR2 (2048);
   l_route_batch   NUMBER;
   l_truck_no      VARCHAR2 (10);
   l_bck_logi_loc  replenlst.inv_dest_loc%TYPE := NULL;
BEGIN

-- xxxxxxx
   pl_log.ins_msg (pl_log.ct_info_msg, l_object_name,
       'Starting procedure'
       || '  (i_dest_loc['    || i_dest_loc               || '],'
       || 'i_qty_reqd['       || TO_CHAR(i_qty_reqd)      || '],'
       || 'i_prod_id['        || i_prod_id                || '],'
       || 'i_route_no['       || i_route_no               || '],'
       || 'i_stop_no['        || TO_CHAR(i_stop_no)       || '],'
       || 'i_uom['            || TO_CHAR(i_uom)           || '],'
       || 'i_order_id['       || i_order_id               || '],'
       || 'i_ord_line_id['    || TO_CHAR(i_ord_line_id)   || '],'
       || 'io_cpv['           || io_cpv                   || '],'
       || 'io_qty_repld['     || TO_CHAR(io_qty_repld)    || '],'
       || 'i_pallet_pull['    || i_pallet_pull            || '],'
       || '  NOTE: The quantities are in splits',
       null, null, ct_application_function, gl_pkg_name);


   SELECT route_batch_no, truck_no
     INTO l_route_batch, l_truck_no
     FROM route
    WHERE route_no = i_route_no;

   io_qty_repld := 0;
   --
   -- Step 1. Check if there is any non-demand replenishments that are being processed (status = 'PIK').
   --         If there is, acquire them. If there is one with NEW or PRE status, delete the replenishment.
   --
   check_for_ndr (i_dest_loc, l_ndr_qty, i_prod_id, i_route_no);

   --
   -- The following step is performed as part of label printing requirement. Some companies want their
   -- replenishments to be printed grouping them according to the zone of the pick locations whereas others
   -- want them according to the zone of the put locations. The decision is made at this stage depending on
   -- the SYSPAR setting. If the SYSPAR is set to 'Y', the group number associated to the pick location
   -- is selected. If it is set to 'N' the group number associated to the put (reserve) location is selected.
   -- this is done in a loop because the replenishments to the same pick location may come from many reserve
   -- locations.
   --
   IF (pl_replenishments.g_home_slot_sort IS NULL) THEN
      pl_replenishments.g_home_slot_sort := pl_common.f_get_syspar('SORT_DMD_REPL_BY_HOME_SLOT', 'N');
   END IF;

    -- DBMS_OUTPUT.PUT_LINE ('2. Here');

   IF (pl_replenishments.g_home_slot_sort = 'Y') THEN
   BEGIN
      -- DBMS_OUTPUT.PUT_LINE ('3. Here, KEY = ' || i_route_no || ' ' || i_dest_loc);
      SELECT z.zone_id, s.equip_id, s.group_no
        INTO l_zone_id, l_equip_id, l_group_no
        FROM zone z,
             lzone l,
             sel_method s,
             sel_method_zone sz,
             route r
       WHERE r.route_no  = i_route_no
         AND s.method_id = r.method_id
         AND sz.group_no = s.group_no
         AND sz.zone_id  = l.zone_id
         AND s.method_id = sz.method_id
         AND l.logi_loc  = i_dest_loc
         AND l.zone_id   = z.zone_id
         AND z.zone_type = 'PIK'
         AND s.sel_type  = 'PAL';
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         BEGIN
            SELECT z.zone_id, s.equip_id, s.group_no
              INTO l_zone_id, l_equip_id, l_group_no
              FROM zone z,
                   lzone l,
                   loc_reference lr,
                   sel_method s,
                   sel_method_zone sz,
                   route r
             WHERE r.route_no      = i_route_no
               AND s.method_id     = r.method_id
               AND sz.group_no     = s.group_no
               AND sz.zone_id      = l.zone_id
               AND s.method_id     = sz.method_id
               AND lr.bck_logi_loc = i_dest_loc
               AND l.logi_loc      = lr.plogi_loc
               AND l.zone_id       = z.zone_id
               AND z.zone_type     = 'PIK'
               AND s.sel_type      = 'PAL';
         EXCEPTION
            WHEN OTHERS THEN
               l_msg := 'Case_Home_Repl : Error route_no = ' ||
                  i_route_no || ', Back Loc = ' || i_dest_loc;
              pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

              l_zone_id := 'UNKP';
              l_group_no := 0;
         END;
      WHEN OTHERS THEN
         l_msg := 'Case_Home_Repl : Error route_no = ' || i_route_no || ', Loc = ' || i_dest_loc;
         pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

         l_zone_id := 'UNKP';
         l_group_no := 0;
    END;
    END IF;

-- DBMS_OUTPUT.PUT_LINE ('4. Here');
    --
    -- Step 2. If any replenishment is acquired, adjust the quantity required.
    --
    l_rpl_qty := i_qty_reqd - l_ndr_qty;
    io_qty_repld := l_ndr_qty;   -- 09/10/02  prpbcb Added this.
    L_NOROWS := FALSE;

    l_msg := 'create_case_home_repl : prod_id = ' || i_prod_id || ', dest_loc = ' || i_dest_loc ||
             ', i_qty_reqd = ' || to_char(i_qty_reqd) ||
             ', l_rpl_qty = ' || to_char(l_rpl_qty) || ', io_qty_repld = ' || to_char(io_qty_repld);
    pl_log.ins_msg ('DEBUG', 'create_case_home_repl', l_msg, NULL, SQLERRM);
    DBMS_OUTPUT.PUT_LINE (l_msg);

    --
    -- Step 3. Transfer quantity to the case home location until the require quantity is filled.
    --         l_rpl_qty is decrease every time a replenishment record is created. L_NOROWS is
    --     set to TRUE when there is no more inventory available in the system.
    --
    l_msg := 'Case_Home_Repl : Before Open c_updinv, Home = ' || i_dest_loc;
    pl_log.ins_msg ('DEBUG', 'create_case_home_repl', l_msg, NULL, SQLERRM);
    OPEN  c_updinv (i_prod_id, i_dest_loc);
    FETCH  c_updinv INTO r_updinv;

--    l_rpl_qty := l_rpl_qty - r_updinv.qoh;  -- Commented out by spin4795 5/22/17
    l_rpl_qty := i_qty_reqd - r_updinv.qoh; -- Added by spin4795 5/22/17  Still worried about acquired NDR.

    l_msg := 'create_case_home_repl : prod_id = ' || i_prod_id || ', dest_loc = ' || i_dest_loc ||
             ', qoh = ' || to_char(r_updinv.qoh) || ', l_rpl_qty = ' || to_char(l_rpl_qty);
    pl_log.ins_msg ('DEBUG', 'create_case_home_repl', l_msg, NULL, SQLERRM);
    DBMS_OUTPUT.PUT_LINE (l_msg);

    WHILE (l_rpl_qty > 0 AND L_NOROWS = FALSE)
    LOOP
      OPEN c_replen (i_prod_id, io_cpv, i_dest_loc);
      FETCH c_replen INTO r_replen;
      IF (c_replen%FOUND) THEN
      BEGIN
        IF (pl_replenishments.g_home_slot_sort = 'N') THEN
        BEGIN
-- DBMS_OUTPUT.PUT_LINE ('5. Here, KEY = ' || i_route_no || ' ' || r_replen.plogi_loc);
          SELECT  z.zone_id, s.equip_id, s.group_no
            INTO  l_zone_id, l_equip_id, l_group_no
            FROM  zone z, lzone l, sel_method s,
            sel_method_zone sz, route r
           WHERE  r.route_no = i_route_no
             AND  s.method_id = r.method_id
             AND  sz.group_no = s.group_no
             AND  sz.zone_id = l.zone_id
             AND  s.method_id = sz.method_id
             AND  l.logi_loc = r_replen.plogi_loc
             AND  l.zone_id = z.zone_id
             AND  z.zone_type = 'PIK'
             AND  s.sel_type = 'PAL';
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
            BEGIN
              SELECT  z.zone_id, s.equip_id, s.group_no
                INTO  l_zone_id, l_equip_id, l_group_no
                FROM  zone z, lzone l, loc_reference lr, sel_method s,
                sel_method_zone sz, route r
               WHERE  r.route_no = i_route_no
                 AND  s.method_id = r.method_id
                 AND  sz.group_no = s.group_no
                 AND  sz.zone_id = l.zone_id
                 AND  s.method_id = sz.method_id
                 AND  lr.bck_logi_loc = r_replen.plogi_loc
                 AND  l.logi_loc = lr.plogi_loc
                 AND  l.zone_id = z.zone_id
                 AND  z.zone_type = 'PIK'
                 AND  s.sel_type = 'PAL';
              EXCEPTION
                WHEN OTHERS THEN
                  l_msg := 'Case_Home_Repl : Error Home Slot Sort = N, ' ||
                     'route_no = ' || i_route_no || ', Back Loc = ' ||
                    r_replen.plogi_loc;
                  pl_log.ins_msg ('INFO', 'create_case_home_repl',
                      l_msg, NULL, SQLERRM);
                  l_zone_id := 'UNKP';
                  l_group_no := 0;
            END;
            WHEN OTHERS THEN
              l_msg := 'Case_Home_Repl : Error Home Slot Sort = N, ' ||
                 'route_no = ' || i_route_no || ', Loc = ' || r_replen.plogi_loc;
              pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);
              l_zone_id := 'UNKP';
              l_group_no := 0;
        END;
        END IF;
        SELECT float_no_seq.NEXTVAL
          INTO l_float_no
          FROM dual;
        l_msg := 'Case_Home_Repl : Before Insert to Floats, From = ' ||
          r_replen.logi_loc || ', Home = ' || i_dest_loc;
        pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

        INSERT INTO floats (batch_no, batch_seq, float_no, float_seq,
            route_no, b_stop_no, e_stop_no, group_no,
            equip_id, pallet_pull, pallet_id, home_slot,
            status, zone_id, parent_pallet_id)
        VALUES (0, 0, l_float_no, 0, i_route_no, i_stop_no,
          i_stop_no, l_group_no, l_equip_id, 'R', r_replen.logi_loc,
          i_dest_loc, 'NEW', l_zone_id, r_replen.parent_pallet_id);
        l_msg := 'Case_Home_Repl : Before Insert to Float_Detail, From = ' ||
          r_replen.logi_loc || ', Home = ' || i_dest_loc;
        pl_log.ins_msg ('DEBUG', 'create_case_home_repl', l_msg, NULL, SQLERRM);

        INSERT INTO float_detail (float_no, seq_no, zone, stop_no, prod_id,
            cust_pref_vendor, src_loc, qty_order, qty_alloc,
            status, order_id, order_line_id, route_no)
        VALUES (l_float_no, 1, 1, i_stop_no, i_prod_id, io_cpv, r_replen.plogi_loc,
          r_replen.qoh, r_replen.qoh, 'ALC', i_order_id, i_ord_line_id, i_route_no);

        Insert_Replenishment (l_float_no);

        l_msg := 'Case_Home_Repl : Before Assign io_qty_repld, From = ' ||
          r_replen.logi_loc || ', Home = ' || i_dest_loc;

        pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

        io_qty_repld := io_qty_repld + r_replen.qoh;

        IF (l_rpl_qty - r_replen.qoh) > 0 THEN
          l_rpl_qty := l_rpl_qty - r_replen.qoh;
        ELSE
          l_rpl_qty := 0;
        END IF;

        l_msg := 'Case_Home_Repl : Before Update Inv Home Slot, From = ' ||
          r_replen.logi_loc || ', Home = ' || i_dest_loc;
        pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

        UPDATE  inv
           SET  qoh = qoh + r_replen.qoh,
          exp_date = r_replen.exp_date,
          mfg_date = r_replen.mfg_date,
          rec_date = r_replen.rec_date,
          inv_date = r_replen.inv_date,
          cust_pref_vendor = io_cpv,
          lot_id = r_replen.lot_id
         WHERE  CURRENT OF c_updinv;

        l_msg := 'Case_Home_Repl : Before Update/Delete Inv Reserve, From = ' ||
          r_replen.logi_loc || ', Home = ' || i_dest_loc;
        pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);

        IF (r_replen.logi_loc = r_replen.plogi_loc) THEN
          UPDATE  inv
             SET  qoh = qoh - r_replen.qoh
           WHERE  logi_loc = r_replen.logi_loc;
        ELSE
          /* If the replenishment is from miniload to case home only the inventory
                needed is replenished to case home. In this case there is possibility of
             inventory remaining in the miniload pallet. We cannot delete a pallet
             if inventory exists in the pallet. */

          IF r_replen.qoh_remain <= 0 then
            DELETE  inv
             WHERE  logi_loc = r_replen.logi_loc;
          else
            UPDATE  inv
               SET  qoh = qoh - r_replen.qoh
             WHERE  logi_loc = r_replen.logi_loc;
          end if;
        END IF;
      END;
      ELSE
        L_NOROWS := TRUE;
      END IF;
      CLOSE c_replen;
    END LOOP;
    IF (c_replen%ISOPEN) THEN
      CLOSE c_replen;
    END IF;
    IF (c_updinv%ISOPEN) THEN
      CLOSE c_updinv;
    END IF;

    l_msg := 'create_case_home_repl : prod_id = ' || i_prod_id || ', dest_loc = ' || i_dest_loc ||
             ', io_qty_repld and deleted split replen = ' || to_char(io_qty_repld);
    pl_log.ins_msg ('DEBUG', 'create_case_home_repl', l_msg, NULL, SQLERRM);
    DBMS_OUTPUT.PUT_LINE (l_msg);

  END;


  PROCEDURE  create_split_home_repl (i_dest_loc  IN  replenlst.dest_loc%TYPE,
          i_qty_reqd  IN  replenlst.qty%TYPE,
          i_prod_id  IN  replenlst.prod_id%TYPE,
          i_route_no  IN  replenlst.route_no%TYPE,
          i_stop_no  IN  float_detail.stop_no%TYPE,
          i_uom    IN  replenlst.uom%TYPE,
          i_order_id  IN  float_detail.order_id%TYPE,
          i_ord_line_id  IN  float_detail.order_line_id%TYPE,
          io_cpv    IN OUT  replenlst.cust_pref_vendor%TYPE,
          io_qty_repld  IN OUT  replenlst.qty%TYPE) IS
    --
    -- Replenish Split home.
    -- Here is a brief note on how this procedure works. At this point, the order processing routine
    -- has already decided that it needs to drop inventory to the pick slot before it could continue
    -- the item selection process. The required quantity is passed to this procedure as a parameter.
    -- The calling program does not adjust the required quantity if some of it is already available
    -- in the home slot. So, this procedure does that adjustment to decide the replenishment quantity.

    --
    -- Split homes are replenished only from case homes and not directly from reserves. This procedure
    -- checks if there is enough quantity in the case home to replenish the split home. If it doesn't
    -- it first creates a replenishment to case home and then creates the replenishment from case home
    -- to split home.
    --

    --
    -- This procedure is invoked by order processing, depending on the unit of measure of the order item.
    -- In some situations, there might not be a separate split home. That means, although the item is
    -- splittable, the splits and cases are both selected from the same location. In such a situation,
    -- the unit of measure of the location is set to 0. In this situation, the system will fail to perform
    -- a split home replenishment. This condition is checked at the end of this procedure and if it did fail,
    -- it will issue a call to create_case_home_repl to perform the replenishment
    --

    --
    -- 1. Check if there is any non-demand replenishments that are being processed (status = 'PIK').
    --    If there is, acquire them. If there is one with NEW or PRE status, delete the replenishment.
    --
    -- 2. If any replenishment is acquired, adjust the quantity required.
    --
    -- 3. Transfer quantity to the split home location until the require quantity is filled.
    --
    --
    -- trunc (qoh / spc) * spc - Replenishments has to be done in cases.
    -- Adjust the qoh in such a way that it truncates to the maximum number of cases at the location.
    --
    CURSOR c_replen (p_prod_id VARCHAR2, p_cpv VARCHAR2,
         p_dest_loc VARCHAR2, p_spc NUMBER) IS
      SELECT  i.plogi_loc,
        trunc (qoh / p_spc) * p_spc qoh,
        qty_alloc,
        i.rec_id,
        i.lot_id,
        NVL (i.exp_date, SYSDATE) exp_date,
        i.exp_ind,
        i.inv_date,
        NVL (i.rec_date, SYSDATE) rec_date,
        i.mfg_date,
        i.logi_loc,
        i.min_qty,
        l.uom,
        l.pik_path
        FROM  loc l,
        inv i
       WHERE  i.prod_id = p_prod_id
         AND  i.cust_pref_vendor = p_cpv
         AND  i.status = 'AVL'
         AND  i.plogi_loc != p_dest_loc
         AND  l.logi_loc = i.plogi_loc
         AND  l.perm = 'Y'
         AND  uom IN (0, 2)
       ORDER  BY i.exp_date, i.qoh, i.logi_loc
         FOR  UPDATE OF qoh;

    CURSOR  c_updinv (p_prod_id VARCHAR2, p_dest_loc VARCHAR2) IS
      SELECT  qoh - qty_alloc qoh
        FROM  inv
       WHERE  prod_id = p_prod_id
         AND  plogi_loc = p_dest_loc
         FOR  UPDATE OF qoh;
         
    CURSOR  c_pm  (p_prod_id VARCHAR2, p_cpv VARCHAR2) IS
      SELECT  spc, NVL (case_qty_for_split_rpl, 1) * NVL (spc, 1) qty_to_repl
        FROM  pm
       WHERE  prod_id = p_prod_id
         AND  cust_pref_vendor = p_cpv;
    r_updinv  c_updinv%ROWTYPE;
    r_replen        c_replen%ROWTYPE;
    r_pm    c_pm%ROWTYPE;

    l_ndr_qty  replenlst.qty%TYPE := 0;
    l_rpl_qty  replenlst.qty%TYPE := i_qty_reqd;
    l_min_qty       NUMBER := 0;
    L_NOROWS        BOOLEAN;
    l_CLOSE_CURSOR  BOOLEAN;
    l_zone_id       zone.zone_id%TYPE;
    l_equip_id      sel_method.equip_id%TYPE;
    l_group_no      sel_method.group_no%TYPE;
    l_dest_loc  replenlst.dest_loc%TYPE;
    l_qty_repld   NUMBER := 0;
    l_case_home_rpl_qty   NUMBER := 0;
    l_float_no  floats.float_no%TYPE;
    l_msg    VARCHAR2 (2048);
    l_route_batch  NUMBER;
    l_truck_no  VARCHAR2 (10);
    l_bck_logi_loc  replenlst.inv_dest_loc%TYPE := NULL;
  BEGIN
    SELECT  route_batch_no, truck_no
      INTO  l_route_batch, l_truck_no
      FROM  route
     WHERE  route_no = i_route_no;

    io_qty_repld := 0;
    --
    -- check_for_ndr procedure will check is there is any non-demand
    -- replenishment to the destination location. If it finds any NDR's
    -- with 'PIK' status, it acquires them, others with status 'PRE' or 'NEW'
    -- are deleted. l_ndr_qty is returned from the procdure which will contain
    -- the total replenishment quantity acquired.
    --
    check_for_ndr (i_dest_loc, l_ndr_qty, i_prod_id, i_route_no);

    IF (pl_replenishments.g_home_slot_sort IS NULL) THEN
      pl_replenishments.g_home_slot_sort := pl_common.f_get_syspar ('SORT_DMD_REPL_BY_HOME_SLOT', 'N');
    END IF;
    l_msg := 'After home slot Selection, Home Slot Sort = ' || pl_replenishments.g_home_slot_sort;
      pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
    OPEN c_pm (i_prod_id, io_cpv);
    FETCH  c_pm INTO r_pm;
    l_rpl_qty := GREATEST (l_rpl_qty, i_qty_reqd, r_pm.qty_to_repl);
    IF (pl_replenishments.g_home_slot_sort = 'Y') THEN
    BEGIN
      SELECT  z.zone_id, s.equip_id, s.group_no
        INTO  l_zone_id, l_equip_id, l_group_no
        FROM  zone z, lzone l, sel_method s,
        sel_method_zone sz, route r
       WHERE  r.route_no = i_route_no
         AND  s.method_id = r.method_id
         AND  sz.group_no = s.group_no
         AND  sz.zone_id = l.zone_id
         AND  s.method_id = sz.method_id
         AND  l.logi_loc = i_dest_loc
         AND  l.zone_id = z.zone_id
         AND  z.zone_type = 'PIK'
         AND  s.sel_type = 'PAL';
      l_msg := 'After Home Zone Selection, Zone  = ' || l_zone_id;
      pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
        BEGIN
          SELECT  z.zone_id, s.equip_id, s.group_no
            INTO  l_zone_id, l_equip_id, l_group_no
            FROM  zone z, lzone l, loc_reference lr, sel_method s,
            sel_method_zone sz, route r
           WHERE  r.route_no = i_route_no
             AND  s.method_id = r.method_id
             AND  sz.group_no = s.group_no
             AND  sz.zone_id = l.zone_id
             AND  s.method_id = sz.method_id
             AND  lr.bck_logi_loc = i_dest_loc
             AND  l.logi_loc = lr.plogi_loc
             AND  l.zone_id = z.zone_id
             AND  z.zone_type = 'PIK'
             AND  s.sel_type = 'PAL';
          EXCEPTION
            WHEN OTHERS THEN
              l_msg := 'Split_Home_Repl : Error route_no = ' || i_route_no ||
                ', Back Loc = ' || i_dest_loc;
              pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg, NULL, SQLERRM);
              l_zone_id := 'UNKP';
              l_group_no := 0;
        END;
        WHEN OTHERS THEN
          l_msg := 'Split_Home_Repl : Error route_no = ' || i_route_no || ', Loc = ' || i_dest_loc;
          pl_log.ins_msg ('INFO', 'create_Split_home_repl', l_msg, NULL, SQLERRM);
          l_zone_id := 'UNKP';
          l_group_no := 0;
    END;
    END IF;

    l_qty_repld := l_rpl_qty - l_ndr_qty;
    io_qty_repld := l_ndr_qty;
    l_NOROWS := FALSE;
    OPEN c_replen (i_prod_id, io_cpv, i_dest_loc, r_pm.spc);
    OPEN  c_updinv (i_prod_id, i_dest_loc);
    FETCH  c_updinv INTO r_updinv;
    l_qty_repld := l_qty_repld - r_updinv.qoh;
    l_msg := 'After UPDINV Fetch, QOH at SPLIT HOME = ' || TO_CHAR (r_updinv.qoh);
      pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);

    --
    -- Here is what is happening in this loop. First it checks the first case home it can find.
    -- If it doesnot find enough quantity at this location to fill the replenishment request,
    -- it tries to create a replenishment to the case home and repeat the process. But, by chance,
    -- if it cannot find enough quantity to replenish the case home, then it will continue to
    -- the next case home.
    --
    WHILE (l_qty_repld > 0 AND l_NOROWS = FALSE)
    LOOP
    BEGIN
      FETCH c_replen INTO r_replen;
      IF (c_replen%FOUND) THEN
      BEGIN
        l_msg := 'After C_REPLEN Fetch,  QOH at CASE HOME = ' || TO_CHAR (r_replen.qoh);
        pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
        IF (pl_replenishments.g_home_slot_sort = 'N') THEN
        BEGIN
          SELECT  z.zone_id, s.equip_id, s.group_no
            INTO  l_zone_id, l_equip_id, l_group_no
            FROM  zone z, lzone l, sel_method s,
            sel_method_zone sz, route r
           WHERE  r.route_no = i_route_no
             AND  s.method_id = r.method_id
             AND  sz.group_no = s.group_no
             AND  sz.zone_id = l.zone_id
             AND  s.method_id = sz.method_id
             AND  l.logi_loc = r_replen.plogi_loc
             AND  l.zone_id = z.zone_id
             AND  z.zone_type = 'PIK'
             AND  s.sel_type = 'PAL';
          l_msg := 'After Reserve Zone Selection, Zone  = ' || l_zone_id;
          pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
            BEGIN
              SELECT  z.zone_id, s.equip_id, s.group_no
                INTO  l_zone_id, l_equip_id, l_group_no
                FROM  zone z, lzone l, loc_reference lr, sel_method s,
                sel_method_zone sz, route r
               WHERE  r.route_no = i_route_no
                 AND  s.method_id = r.method_id
                 AND  sz.group_no = s.group_no
                 AND  sz.zone_id = l.zone_id
                 AND  s.method_id = sz.method_id
                 AND  lr.bck_logi_loc = r_replen.plogi_loc
                 AND  l.logi_loc = lr.plogi_loc
                 AND  l.zone_id = z.zone_id
                 AND  z.zone_type = 'PIK'
                 AND  s.sel_type = 'PAL';
              EXCEPTION
                WHEN OTHERS THEN
                  l_msg := 'Split_Home_Repl : Error Home Slot Sort = N, ' ||
                     'route_no = ' || i_route_no || ', Back Loc = ' ||
                    r_replen.plogi_loc;
                  pl_log.ins_msg ('INFO', 'create_case_home_repl', l_msg,
                      NULL, SQLERRM);
                  l_zone_id := 'UNKP';
                  l_group_no := 0;
            END;
            WHEN OTHERS THEN
              l_msg := 'Case_Home_Repl : Error Home Slot Sort = N, ' ||
                 'route_no = ' || i_route_no || ', Loc = ' || r_replen.plogi_loc;
              pl_log.ins_msg ('INFO', 'create_Split_home_repl', l_msg, NULL, SQLERRM);
              l_zone_id := 'UNKP';
              l_group_no := 0;
        END;
        END IF;
        l_qty_repld := CEIL (l_qty_repld / r_pm.spc) * r_pm.spc;
        IF (r_replen.qoh < l_qty_repld) THEN
        BEGIN
          create_case_home_repl (r_replen.plogi_loc, l_rpl_qty, i_prod_id, i_route_no,
                i_stop_no, 2, i_order_id, i_ord_line_id,
                io_cpv, l_case_home_rpl_qty);
          IF (l_case_home_rpl_qty > 0) THEN
            --
            -- case home has been replenished. Adjust the selected value of
            -- qoh at case home.
            --
            r_replen.qoh := r_replen.qoh + l_case_home_rpl_qty;
          END IF;
        END;
        END IF;
        l_msg := 'Before updates, QOH = ' || TO_CHAR (r_replen.qoh);
        pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
        IF (r_replen.qoh > 0) THEN
        BEGIN
          SELECT float_no_seq.NEXTVAL
            INTO l_float_no
            FROM dual;
          INSERT INTO floats (batch_no, batch_seq, float_no, float_seq,
              route_no, b_stop_no, e_stop_no, group_no,
              equip_id, pallet_pull, pallet_id, home_slot,
              status, zone_id)
          VALUES (0, 0, l_float_no, 0, i_route_no, i_stop_no,
            i_stop_no, l_group_no, l_equip_id, 'R', r_replen.logi_loc,
            i_dest_loc, 'NEW', l_zone_id);
          INSERT INTO float_detail (float_no, seq_no, zone, stop_no, prod_id,
              cust_pref_vendor, src_loc, qty_order, qty_alloc,
              status, order_id, order_line_id, route_no)
          VALUES (l_float_no, 1, 1, i_stop_no, i_prod_id, io_cpv, r_replen.plogi_loc,
            LEAST (r_replen.qoh, l_qty_repld), LEAST (r_replen.qoh, l_qty_repld),
            'ALC', i_order_id, i_ord_line_id, i_route_no);
          Insert_Replenishment (l_float_no);
          UPDATE  inv
             SET  qoh = qoh +  LEAST (r_replen.qoh, l_qty_repld),
            exp_date = r_replen.exp_date,
            mfg_date = r_replen.mfg_date,
            rec_date = r_replen.rec_date,
            inv_date = r_replen.inv_date,
            lot_id = r_replen.lot_id
           WHERE  CURRENT OF c_updinv;
          IF (sql%NOTFOUND) THEN
          BEGIN
            l_msg := 'Could not update using CURRENT OF c_updinv ';
            pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
          END;
          END IF;
          UPDATE  inv
             SET  qoh = qoh -  LEAST (r_replen.qoh, l_qty_repld)
           WHERE  logi_loc = r_replen.logi_loc;
          IF (sql%NOTFOUND) THEN
          BEGIN
            l_msg := 'Could not update INV record using r_replen.logi_loc because no record found';
            pl_log.ins_msg ('DEBUG', 'create_split_home_repl', l_msg, NULL, NULL);
          END;
          END IF;
          io_qty_repld := io_qty_repld + LEAST (r_replen.qoh, l_qty_repld);
          l_qty_repld := l_qty_repld - LEAST (r_replen.qoh, l_qty_repld);
        END;
        END IF;
      END;
      ELSE
        IF (c_replen%ROWCOUNT = 0) THEN
        BEGIN
          create_case_home_repl (i_dest_loc, i_qty_reqd, i_prod_id, i_route_no, i_stop_no, i_uom,
                i_order_id, i_ord_line_id, io_cpv, io_qty_repld);
        END;
        END IF;
        L_NOROWS := TRUE;
      END IF;
    END;
    END LOOP;
    IF (c_replen%ISOPEN) THEN
      CLOSE c_replen;
    END IF;
    IF (c_updinv%ISOPEN) THEN
      CLOSE c_updinv;
    END IF;
    IF (c_pm%ISOPEN) THEN
      CLOSE c_pm;
    END IF;
  END;
  PROCEDURE acquire_ndm_repl (i_task_id  IN replenlst.task_id%TYPE,
                                      i_route_no IN route.route_no%TYPE,
          o_rpl_qty  OUT  NUMBER)
  IS
    -- This cursor selects info about the replenishment pallet.
    CURSOR repl_cur IS
      SELECT  r.prod_id, r.cust_pref_vendor, r.src_loc,
        NVL (r.inv_dest_loc, r.dest_loc) dest_loc,
        r.pallet_id, r.qty, r.status, r.uom,
        i.exp_date, i.mfg_date, i.rec_date, i.inv_date,
        i.rec_id, i.lot_id, i.exp_ind, i.logi_loc, i.plogi_loc
        FROM  inv i, replenlst r
       WHERE  r.task_id = i_task_id
         AND  i.logi_loc = r.pallet_id
         FOR  UPDATE OF i.qty_alloc;
    repl_rec  repl_cur%ROWTYPE;
  BEGIN
    o_rpl_qty := 0;
    OPEN repl_cur;
    FETCH repl_cur INTO repl_rec;
    IF (repl_cur%FOUND) THEN
      CLOSE repl_cur;
      -- Update the destination location inv record.
      UPDATE  inv
         SET  qoh    = qoh + repl_rec.qty,
        qty_planned  = qty_planned - repl_rec.qty,
        exp_date  = repl_rec.exp_date,
        mfg_date  = repl_rec.mfg_date,
        rec_date  = repl_rec.rec_date,
        inv_date  = repl_rec.inv_date
       WHERE plogi_loc        = repl_rec.dest_loc
         AND prod_id          = repl_rec.prod_id
         AND cust_pref_vendor = repl_rec.cust_pref_vendor;
      -- Delete the replenishment pallet from inventory
      -- if its from a reserve slot.  It is possible a case home
      -- is being replenished from a split home or a split home is
      -- being replenished from a case home in which case we do
      -- not want to delete the split home from inventory but
      -- we do need to update the qoh.
      IF (repl_rec.plogi_loc = repl_rec.logi_loc) THEN
        -- Replenishing a case home from a split home or a split
        -- home from a case home.  Update the qoh.
        UPDATE  inv
           SET  qoh = qoh - repl_rec.qty,
          qty_alloc = qty_alloc - repl_rec.qty
         WHERE logi_loc = repl_rec.logi_loc;
      ELSE
        -- Replenishing from a reserve slot.  Delete the reserve
        -- pallet from inventory.
        DELETE
          FROM inv
         WHERE logi_loc = repl_rec.logi_loc;
      END IF;
      -- Update trans IND record.
      -- route_no updated to indicate the repl acquired by order
      -- processing.
      UPDATE  trans
         SET  trans_type   = 'RPL',
        trans_date   = SYSDATE,
        cmt          = i_task_id,
        route_no     = i_route_no
       WHERE  trans_type = 'IND'
         AND  prod_id = repl_rec.prod_id
         AND  pallet_id  = repl_rec.pallet_id
         AND  cust_pref_vendor = repl_rec.cust_pref_vendor;
      -- Update replenlst record.
      UPDATE  replenlst
         SET  op_acquire_flag = 'Y',
        route_no = i_route_no
       WHERE  task_id = i_task_id;
      ------------------------------------------------------------
      --          Cycle Count Processing                        --
      ------------------------------------------------------------
      -- Process the cycle count for the replenishment destination
      -- location if one exists.
      -- Set a pending adjustment to 'N' if one exists.
      UPDATE trans
         SET adj_flag = 'N'
       WHERE pallet_id  = repl_rec.dest_loc
         AND trans_type = 'CYC'
         AND adj_flag   = 'Y';
      IF (SQL%FOUND) THEN
        -- A pending adjustment was set to 'N'.  Insert a CAR
        -- transaction to record this.
        INSERT INTO trans (trans_id,    trans_type,
            trans_date,    prod_id,
            cust_pref_vendor,  qty_expected,
            qty,       user_id,
            src_loc,     route_no,
            dest_loc,    pallet_id,
            uom,      rec_id,
            lot_id,      exp_date,
            adj_flag,    upload_time)
        VALUES    (trans_id_seq.NEXTVAL,  'CAR',
            SYSDATE,    repl_rec.prod_id,
            repl_rec.cust_pref_vendor,
            0,      0,
            'ORDER',    repl_rec.src_loc,
            i_route_no,    repl_rec.dest_loc,
            repl_rec.pallet_id,  repl_rec.uom,
            repl_rec.rec_id,  repl_rec.lot_id,
            repl_rec.exp_date,  repl_rec.exp_ind,
            NULL);
      END IF;
      -- If any cycle counts exist for the destination location
      -- insert a trans record then delete the cycle counts.
      INSERT INTO trans (trans_id, trans_type, trans_date, prod_id,
          user_id, reason_code, batch_no, src_loc, pallet_id)
      SELECT  trans_id_seq.NEXTVAL, 'DCC', SYSDATE, prod_id,
        USER, cc_reason_code, batch_no, phys_loc,
        logi_loc
        FROM  cc
       WHERE  logi_loc = repl_rec.dest_loc;
      IF (SQL%FOUND) THEN
        DELETE
          FROM cc
         WHERE logi_loc = repl_rec.dest_loc;
      END IF;
      o_rpl_qty := repl_rec.qty;
    ELSE
      CLOSE repl_cur;
    END IF;
  END acquire_ndm_repl;


  -----------------------------------------------------------------
  -- Procedure:
  --    delete_ndm_repl   (local module)
  --
  -- Description:
  --    This procedure deletes a single non-demand replenishment
  --    for an item.  If the status is PIK then the IND trans
  --    record is deleted.
  --
  -- Parameters:
  --    i_task_id  - Replenishmemt task id to delete.
  --
  -- Return values:
  --    None
  -----------------------------------------------------------------
  PROCEDURE delete_ndm_repl (i_task_id  IN replenlst.task_id%TYPE)
  IS
    CURSOR repl_cur IS
      SELECT  r.prod_id, r.cust_pref_vendor, r.src_loc,
        NVL(r.inv_dest_loc, r.dest_loc) dest_loc,
                                r.pallet_id, r.qty, r.status
        FROM  inv i, replenlst r
       WHERE  r.task_id = i_task_id
         AND  i.logi_loc = r.pallet_id
         FOR  UPDATE OF r.task_id, i.qty_planned;
    repl_rec  repl_cur%ROWTYPE;
  BEGIN
    OPEN repl_cur;
    FETCH repl_cur INTO repl_rec;
    IF (repl_cur%FOUND) THEN
      CLOSE repl_cur;
      -- Update the destination location qty_planned.
      UPDATE  inv
        SET qty_planned = qty_planned - repl_rec.qty
       WHERE  plogi_loc = repl_rec.dest_loc
         AND  prod_id   = repl_rec.prod_id
         AND  cust_pref_vendor = repl_rec.cust_pref_vendor;
      -- Update the source location qty_alloc and plogi_loc.
      -- Updating the plogi_loc handles the replenishment in
      -- PIK status which has changed the plogi_loc to the
      -- user id.
      UPDATE  inv
         SET  qty_alloc = qty_alloc - repl_rec.qty,
        plogi_loc = repl_rec.src_loc
       WHERE  logi_loc  = repl_rec.pallet_id
         AND  prod_id   = repl_rec.prod_id
         AND  cust_pref_vendor = repl_rec.cust_pref_vendor;
      -- Delete the IND trans record if the replenlst status
      -- is PIK.
      IF (repl_rec.status = 'PIK') THEN
        DELETE
          FROM trans
         WHERE trans_type = 'IND'
           AND pallet_id = repl_rec.pallet_id
           AND prod_id   = repl_rec.prod_id
           AND cust_pref_vendor = repl_rec.cust_pref_vendor;
      END IF;
      -- Delete the replenlst record.
      DELETE
        FROM replenlst
       WHERE task_id = i_task_id;
      DELETE
        FROM batch
       WHERE batch_no = 'FN' || TO_CHAR (i_task_id);
    ELSE
      CLOSE repl_cur;
    END IF;
  END delete_ndm_repl;

  PROCEDURE Insert_Replenishment (i_float_no  floats.float_no%TYPE) IS
    CURSOR  c_floats (iFloatNo NUMBER) IS
      SELECT  f.equip_id, f.pallet_pull,
        f.pallet_id, NVL (f.drop_qty, 0) drop_qty,
        f.home_slot dest_loc,
        DECODE (f.pallet_pull, 'R', NULL,
          DECODE (f.door_area,
            'C', r.c_door,
            'F', r.f_door,
            r.d_door)) door_no,
        f.route_no, f.float_no,
        r.route_batch_no, r.truck_no,
        fd.src_loc, fd.prod_id,
        SUM (fd.qty_order) qty_order,
        MAX (fd.order_id) order_id,
        MAX (fd.order_line_id) order_line_id,
        MAX (fd.uom) uom,
        i.exp_date, i.mfg_date, i.rec_date,
        i.rec_id, i.cust_pref_vendor,
        l.pik_path,
        p.spc,
        f.parent_pallet_id, p.area,
        f.site_from,
        f.site_to,
        f.cross_dock_type,
        f.xdock_pallet_id
   FROM  pm p, loc l, inv i, route r, float_detail fd, floats f
       WHERE  f.float_no = iFloatNo
         AND  fd.float_no = f.float_no
         AND  i.prod_id = fd.prod_id
         AND  i.cust_pref_vendor = fd.cust_pref_vendor
         AND  i.plogi_loc = fd.src_loc
         AND  i.logi_loc = f.pallet_id
         AND  r.route_no = f.route_no
         AND  l.logi_loc = i.plogi_loc
         AND  p.prod_id = fd.prod_id
         AND  p.cust_pref_vendor = fd.cust_pref_vendor
       GROUP  BY f.equip_id, f.pallet_pull,
        f.pallet_id, NVL (f.drop_qty, 0),
        f.home_slot,
        DECODE (f.door_area,
          'C', r.c_door,
          'F', r.f_door,
          r.d_door),
        f.route_no, f.float_no,
        r.route_batch_no, r.truck_no,
        fd.src_loc, fd.prod_id,
        i.exp_date, i.mfg_date, i.rec_date,
        i.rec_id, i.cust_pref_vendor,
        l.pik_path, p.spc,
        f.parent_pallet_id, area,
        f.site_from,
        f.site_to,
        f.cross_dock_type,
        f.xdock_pallet_id;

    CURSOR  c_loc_ref (sLogiLoc  VARCHAR2) IS
      SELECT  plogi_loc
        FROM  loc_reference
       WHERE  bck_logi_loc = sLogiLoc;

    r_floats  c_floats%ROWTYPE;
    r_plogi_loc  loc_reference.plogi_loc%TYPE;
    l_repl_type  replenlst.type%TYPE;
    l_qty_order  replenlst.qty%TYPE;
    l_drop_qty  replenlst.drop_qty%TYPE;
    l_dest_loc  replenlst.dest_loc%TYPE;
    l_door_no  replenlst.door_no%TYPE;
    l_inv_dest_loc  replenlst.inv_dest_loc%TYPE;
  BEGIN

    IF (pl_dmd_replenishment.g_enable_pallet_flow IS NULL) THEN
      g_enable_pallet_flow := pl_common.f_get_syspar ('ENABLE_PALLET_FLOW', 'N');
    END IF;

    OPEN  c_floats (i_float_no);
    FETCH  c_floats INTO r_floats;
    IF (c_floats%FOUND) THEN
      r_plogi_loc := NULL;

      -- CRQ49435-Fetch plogi_loc from loc_reference if Pallet flow is enabled.
      -- v_replen_bulk refers inv_dest_loc for DMD replenishment priority

      IF (pl_replenishments.g_enable_pallet_flow = 'Y' AND r_floats.pallet_pull = 'R') THEN
      BEGIN
        OPEN c_loc_ref (r_floats.dest_loc);
        FETCH c_loc_ref INTO r_plogi_loc;
        CLOSE  c_loc_ref;
      END;
      END IF;

      SELECT  DECODE (r_floats.pallet_pull, 'R', 'DMD', 'BLK'),
        DECODE (r_floats.pallet_pull, 'R', NULL, r_floats.door_no)
        INTO  l_repl_type, l_door_no
        FROM  DUAL;
      l_qty_order := r_floats.qty_order / r_floats.spc;
      l_drop_qty := r_floats.drop_qty / r_floats.spc;
      BEGIN
        INSERT  INTO replenlst (
          task_id,
          prod_id,
          uom,
          qty,
          type,
          status,
          src_loc,
          pallet_id,
          dest_loc,
          s_pikpath,
          d_pikpath,
          batch_no,
          equip_id,
          order_id,
          user_id,
          op_acquire_flag,
          cust_pref_vendor,
          gen_uid,
          gen_date,
          exp_date,
          mfg_date,
          route_no,
          float_no,
          seq_no,
          route_batch_no,
          truck_no,
          inv_dest_loc,
          drop_qty,
          door_no,
          parent_pallet_id,
          replen_type,
          replen_area,
          site_from,
          site_to,
          cross_dock_type,
          xdock_pallet_id)
        VALUES 
         (repl_id_seq.NEXTVAL,
          r_floats.prod_id,
          r_floats.uom,
          l_qty_order,
          l_repl_type,
          'NEW',
          r_floats.src_loc,
          r_floats.pallet_id,
          DECODE (l_repl_type, 'DMD', r_floats.dest_loc,
            DECODE (l_drop_qty, 0, NULL, r_floats.dest_loc)),
          r_floats.pik_path,
          NULL,
          0,
          r_floats.equip_id,
          r_floats.order_id,
          NULL,
          'Y',
          r_floats.cust_pref_vendor,
          REPLACE (USER, 'OPS$'),
          SYSDATE,
          r_floats.exp_date,
          r_floats.mfg_date,
          r_floats.route_no,
          r_floats.float_no,
          1,
          r_floats.route_batch_no,
          r_floats.truck_no,
          r_plogi_loc,
          l_drop_qty,
          l_door_no,
          r_floats.parent_pallet_id,
          'D',
          r_floats.area,
          r_floats.site_from,
          r_floats.site_to,
          r_floats.cross_dock_type,
          r_floats.xdock_pallet_id);
      END;
    END IF;
    CLOSE  c_floats;
  END Insert_Replenishment;


---------------------------------------------------------------------------
-- Procedure:
--    create_ML_repl
--
-- Description:
--    This procedure opens a ref cursor used when an ORDD record
--    is created.
--
-- Parameters:
--
-- Called by:
--
-- Exceptions raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/09/16 bben0556 Brian Bent
--                      Handle a case carrier that has splitss (for whatever
--                      reason).
--                      Add log messages.
---------------------------------------------------------------------------
PROCEDURE create_ML_repl
           (i_qty_reqd    IN     replenlst.qty%TYPE,
            i_prod_id     IN     replenlst.prod_id%TYPE,
            i_cpv         IN     replenlst.cust_pref_vendor%TYPE,
            i_priority    IN     replenlst.priority%TYPE,
            i_route_no    IN     replenlst.route_no%TYPE,
            i_order_id    IN     replenlst.order_id%TYPE,
            io_qty_repld  IN OUT replenlst.qty%TYPE,
            io_status     IN OUT VARCHAR2)
IS
   l_object_name   VARCHAR2(30) := 'create_ML_repl';
   l_message       VARCHAR2(1000);

   CURSOR  c_ML_Replen(cp_prod_id  VARCHAR2,
                      cp_cpv      VARCHAR2)
   IS
      SELECT i.logi_loc,
             i.plogi_loc,
             i.qoh,
             i.qty_alloc,
             i.exp_date,
             i.parent_pallet_id,
             z.induction_loc,
             l.pik_level,
             z.max_pick_level,
             p.spc,
             i.mfg_date,
             i.rec_id,
             i.lot_id,
             l.pik_path,
             i.inv_uom,
             p.spc * TRUNC(i.qoh / p.spc)        effective_qoh,
             p.spc * TRUNC(i.qty_alloc / p.spc)  effective_qty_alloc
        FROM loc l,
             zone z,
             pm p,
             inv i
       WHERE i.prod_id            = cp_prod_id
         AND i.cust_pref_vendor   = cp_cpv
         AND i.status             = 'AVL'
         AND p.prod_id            = i.prod_id
         AND p.cust_pref_vendor   = i.cust_pref_vendor
         AND l.logi_loc           = i.plogi_loc
         AND z.zone_id            = p.split_zone_id
         AND i.plogi_loc          != NVL(z.induction_loc, 'ZZ')
         AND i.qoh - i.qty_alloc  >= 0
         AND NVL(i.inv_uom, 2)    = 2
         AND (   l.logi_loc = i.plogi_loc
              OR NOT EXISTS (SELECT 0
                               FROM inv i1
                              WHERE i1.prod_id = i.prod_id
                                AND i1.logi_loc = i1.plogi_loc))
       ORDER BY i.exp_date, i.qoh - i.qty_alloc DESC     -- 02/10/2016  Brian Bent Added i.exp_date
         FOR UPDATE OF i.logi_loc NOWAIT;

   CURSOR  cInv (pLicense  VARCHAR2)
   IS
      SELECT  prod_id, exp_date, inv_date, abc, cust_pref_vendor, parent_pallet_id
        FROM  inv
       WHERE  logi_loc = pLicense;

   rInv           cInv%ROWTYPE;
   lTotReplen     NUMBER := 0;
   lReplenQty     NUMBER := 0;
   lAvailQty      NUMBER := 0;
   lTaskId        NUMBER := 0;
   lPalletId      NUMBER := 0;
   lLicensePlate  inv.logi_loc%TYPE;
   lStatus        NUMBER;
   lLoopCTR       NUMBER;
   lNoReplens     NUMBER;
   io_cpv         inv.cust_pref_vendor%TYPE := i_cpv;
BEGIN
   lStatus := pl_miniload_processing.ct_failure;

   pl_log.ins_msg (pl_log.ct_info_msg, l_object_name,
       'Starting procedure'
       ||'  (i_qty_reqd['   || TO_CHAR(i_qty_reqd) || '],'
       || 'i_prod_id['      || i_prod_id           || '],'
       || 'i_cpv['          || i_cpv               || '],'
       || 'i_priority['     || TO_CHAR(i_priority) || '],'
       || 'i_route_no['     || i_route_no          || '],'
       || 'i_order_id['     || i_order_id          || '],'
       || 'io_qty_repld['   || TO_CHAR(io_qty_repld) || '],'
       || 'io_status['      || TO_CHAR(io_status)    || '])'
       || ' NOTE: The quantities are in splits',
       null, null, ct_application_function, gl_pkg_name);

   FOR r_ML_Replen IN c_ML_Replen(i_prod_id, i_cpv)
   LOOP
      l_message := 'In "FOR r_ML_Replen IN c_ML_Replen(i_prod_id, i_cpv)"'
                    || '  prod_id['              || i_prod_id                                || ']'
                    || '  CPV['                  || i_cpv                                    || ']'
                    || '  SPC['                  || TO_CHAR(r_ML_Replen.spc)                 || ']'
                    || '  i_route_no['           || i_route_no                               || ']'
                    || '  i_order_id['           || i_order_id                               || ']'
                    || '  i_qty_reqd['           || TO_CHAR(i_qty_reqd)                      || ']'
                    || '  LP['                   || r_ML_Replen.logi_loc                     || ']'
                    || '  Location['             || r_ML_Replen.plogi_loc                    || ']'
                    || '  inv_uom['              || TO_CHAR(r_ML_Replen.inv_uom)             || ']'
                    || '  qoh['                  || TO_CHAR(r_ML_Replen.qoh)                 || ']'
                    || '  qty_alloc['            || TO_CHAR(r_ML_Replen.qty_alloc)           || ']'
                    || '  effective_qoh['        || TO_CHAR(r_ML_Replen.effective_qoh)       || ']'
                    || '  effective_qty_alloc['  || TO_CHAR(r_ML_Replen.effective_qty_alloc) || ']';

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, l_message,
                   NULL, NULL,
                   ct_application_function, gl_pkg_name);
      --
      -- Log message if the qty available and/or qoh
      -- are not the same as the effective qty available
      -- and effective qoh.  A difference means we have a
      -- case carrier with splits and/or a screwed up qty alloc.
      --
      IF (   r_ML_Replen.qoh       <> r_ML_Replen.effective_qoh
          OR r_ML_Replen.qty_alloc <> r_ML_Replen.effective_qty_alloc)
      THEN
         l_message := 'Inventory record has splits when there should be only cases.'
                    || '  The splits will be left in inventory.'
                    || '  The inventory needs to be cycle counted.'
                    || '  LP['                   || r_ML_Replen.logi_loc                     || ']'
                    || '  Location['             || r_ML_Replen.plogi_loc                    || ']'
                    || '  inv_uom['              || TO_CHAR(r_ML_Replen.inv_uom)             || ']'
                    || '  qoh['                  || TO_CHAR(r_ML_Replen.qoh)                 || ']'
                    || '  qty_alloc['            || TO_CHAR(r_ML_Replen.qty_alloc)           || ']'
                    || '  effective_qoh['        || TO_CHAR(r_ML_Replen.effective_qoh)       || ']'
                    || '  effective_qty_alloc['  || TO_CHAR(r_ML_Replen.effective_qty_alloc) || ']';

         pl_log.ins_msg(pl_log.ct_warn_msg, l_object_name, l_message,
                   NULL, NULL,
                   ct_application_function, gl_pkg_name);
      END IF;


      lAvailQty := r_ML_Replen.effective_qoh - r_ML_replen.effective_qty_alloc;

      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                     'LP['                || r_ML_Replen.logi_loc   || ']'
                     || '  Location['     || r_ML_Replen.plogi_loc  || ']'
                     || '  lAvailQty['    || TO_CHAR(lAvailQty)     || ']'
                     || '  i_qty_reqd['   || TO_CHAR(i_qty_reqd)    || ']',
                     NULL, NULL, ct_application_function, gl_pkg_name);

      --
      -- If this is a case home slot and there is not enough
      -- quantity in the case home, create demand replenishment
      -- to case home
      --
      IF (    (lAvailQty< i_qty_reqd)
          AND (r_ML_Replen.logi_loc = r_ML_Replen.plogi_loc))
      THEN
         pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'Calling create_case_home_repl',
                        NULL, NULL,
                        ct_application_function, gl_pkg_name);

         create_case_home_repl
                     (i_dest_loc     => r_ML_Replen.plogi_loc,
                      i_qty_reqd     => i_qty_reqd,
                      i_prod_id      => i_prod_id,
                      i_route_no     => i_route_no,
                      i_stop_no      => 0,
                      i_uom          => 2,
                      i_order_id     => i_order_id,
                      i_ord_line_id  => 1,
                      io_cpv         => io_cpv,
                      io_qty_repld   => io_qty_repld);

         lAvailQty := lAvailQty + io_qty_repld;
      END IF;

      --
      -- If available quantity is 0 then there is nothing you can do
      -- so just quit.
      --
      lReplenQty := r_ML_Replen.spc;

      lNoReplens := CEIL ((i_qty_reqd - lTotReplen) / lReplenQty);

      FOR lLoopCTR IN 1..lNoReplens
      LOOP
pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'xxxxx', NULL, NULL, ct_application_function, gl_pkg_name);
         IF (lAvailQty > 0) THEN
            BEGIN
pl_log.ins_msg(pl_log.ct_info_msg, l_object_name, 'yyyyy', NULL, NULL, ct_application_function, gl_pkg_name);
               -- SELECT repl_id_seq.NEXTVAL, ml_pallet_id_seq.NEXTVAL
               --   INTO lTaskID, lPalletId
               --   FROM dual;
               lTaskID := repl_id_seq.NEXTVAL;
               lPalletId := ml_pallet_id_seq.NEXTVAL;

               lLicensePlate := r_ML_Replen.plogi_loc || lPalletId;

               INSERT INTO replenlst(task_id,
                                     prod_id,
                                     uom,
                                     qty,
                                     type,
                                     status,
                                     src_loc,
                                     pallet_id,
                                     dest_loc,
                                     cust_pref_vendor,
                                     exp_date,
                                     parent_pallet_id,
                                     priority,
                                     route_no,
                                     order_id,
                                     rec_id,
                                     mfg_date,
                                     lot_id,
                                     orig_pallet_id,
                                     s_pikpath)
                             VALUES
                                    (lTaskId,
                                     i_prod_id,
                                     2,
                                     1,
                                     'MNL',
                                     'NEW',
                                     r_ML_Replen.plogi_loc,
                                     lLicensePlate,
                                     r_ML_Replen.induction_loc,
                                     i_cpv,
                                     r_ML_Replen.exp_date,
                                     r_ML_Replen.parent_pallet_id,
                                     i_priority,
                                     i_route_no,
                                     i_order_id,
                                     r_ML_Replen.rec_id,
                                     r_ML_Replen.mfg_date,
                                     r_ML_Replen.lot_id,
                                     r_ML_Replen.logi_loc,
                                     r_ML_Replen.pik_path);

               OPEN cInv (r_ML_Replen.logi_loc);

               FETCH cInv INTO rInv;

               INSERT INTO inv(prod_id,
                               exp_date,
                               inv_date,
                               logi_loc,
                               plogi_loc,
                               qoh,
                               qty_alloc,
                               qty_planned,
                               min_qty,
                               abc,
                               status,
                               cust_pref_vendor,
                               parent_pallet_id,
                               inv_uom)
                        VALUES
                              (rInv.prod_id,
                               rInv.exp_date,
                               rInv.inv_date,
                               lLicensePlate,
                               r_ML_Replen.induction_loc,
                               lReplenQty,
                               0,
                               0,
                               0,
                               rInv.abc,
                               'AVL',
                               rInv.cust_pref_vendor,
                               rInv.parent_pallet_id,
                               1);

               IF (    (lReplenQty = r_ML_Replen.qoh)
                   AND (r_ML_Replen.qty_alloc = 0)
                   AND (r_ML_Replen.logi_loc != r_ML_Replen.plogi_loc)
                   AND r_ML_Replen.qoh = r_ML_Replen.effective_qoh)   -- Do not delete if there are bogus splits
               THEN
                  DELETE inv
                   WHERE CURRENT OF c_ML_Replen;
               ELSE
                  UPDATE inv
                     SET qoh = qoh - lReplenQty
                   WHERE CURRENT OF c_ML_Replen;
               END IF;

               CLOSE cInv;

               lAvailQty := lAvailQty - lReplenQty;  -- 02/09/2016  Brian Bent  Added.
               lTotReplen := lTotReplen + lReplenQty;

               IF (lTotReplen >= i_qty_reqd) THEN
                  EXIT;
               END IF;
            END;
         ELSE
            EXIT;
         END IF;
      END LOOP;

      IF (lTotReplen >= i_qty_reqd) THEN
         EXIT;
      END IF;
   END LOOP;

   io_qty_repld  := lTotReplen;
   io_status  := lStatus;

   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
       'Ending procedure'
       || '  (i_qty_reqd['  || TO_CHAR(i_qty_reqd)   || '],'
       || 'i_prod_id['      || i_prod_id             || '],'
       || 'i_cpv['          || i_cpv                 || '],'
       || 'i_priority['     || TO_CHAR(i_priority)   || '],'
       || 'i_route_no['     || i_route_no            || '],'
       || 'i_order_id['     || i_order_id            || '],'
       || 'io_qty_repld['   || TO_CHAR(io_qty_repld) || '],'
       || 'io_status['      || TO_CHAR(io_status)    || '])',
       null, null, ct_application_function, gl_pkg_name);

END create_ML_repl;


---------------------------------------------------------------------------
-- Procedure:
--    set_replen_type
--
-- Description:
--    This procedure sets the type of NDM replenishment being created.
--    The replen type is used in view V_NDM_REPLEN_INFO which calls
--    function get_replen_type() to get the replen type.
--    The view needs to know what replenishment type is being created in order
--    to process CF and HS correctly when replenishing by min/max.
--    The rules for HS and CF when replenishing by min/max qty are:
--    - For historical orders:
--         - Create a replenishment if the quantity in the home slot
--           is < max qty.
--    - For planned orders(store orders):
--         - Create a replenishment if the quantity in the home slot
--           is < order qty and is < max qty.
--    - For everything else:
--         - Create a replenishment if the quantity in the home slot
--           is <= min qty.
--
--    The replenishment types are shown below and came from
--    create_ndm.pc
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--    create_ndm.pc was modified to call this procedure before
--    running the query that selects from V_NDM_REPLEN_INFO.
--
--    I changed the view 2 months ago per a request by
--    Distribution Services to create a NDM replenishment
--    if the qty in the home slot is less than the max qty
--    when processing historical orders.  The change I made
--    does it for all NDM replenishments when replenishing
--    by min/max qty--basically the min qty is ignored.
--
-- Parameters:
--    none  - Local global variable gl_replen_type is set.
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - create_ndm.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/18/13 prpbcb   Created
---------------------------------------------------------------------------
PROCEDURE set_replen_type(i_replen_type IN VARCHAR2)
IS
   l_message       VARCHAR2(1000);  -- Message buffer.
BEGIN
   pl_replenishments.gl_replen_type := i_replen_type;

   l_message := 'set_replen_type[' || i_replen_type || '](i_replen_type)'
      || '  Set pl_replenishments.gl_replen_type to [' || i_replen_type || '].'
      || '  This is used by view V_NDM_REPLEN_INFO to know what type of'
      || ' replenishments are being created for HS and CF home slots.'
      || '  The rules for HS and CF when replenishing by min/max qty for'
      || ' historical and planned orders are:'
      || '  For historical orders create a replenishment if the quantity in the'
      || ' home slot is < max qty.'
      || '  For planned orders(store orders) create a replenishment if the'
      || ' quantity in the home slot is < order qty and is < max qty.'
      || '  For everything else create a replenishment if the quantity in'
      || ' the home slot is <= min qty.'
      || '   The different types are:'
      || '  L - Created from RF using "Replen By Location" option'
      || '  H - Created from Screen using "Replen by Historical" option'
      || '  R - Created from screen with options other than "Replen by Historical"'
      || '  O - Created from cron when a store-order is received that requires a replenishment';

   pl_log.ins_msg(pl_lmc.ct_info_msg, 'set_replen_type', l_message,
                  SQLCODE, SQLERRM,
                  ct_application_function, gl_pkg_name);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := 'set_replen_type[' || i_replen_type || '](i_replen_type)'
           || '  Failed to set pl_replenishments.gl_replen_type.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'set_replen_type', l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            'set_replen_type' || ': ' || SQLERRM);
END set_replen_type;


---------------------------------------------------------------------------
-- Function:
--    get_replen_type
--
-- Description:
--    This function returns the value in pl_replenishments.gl_replen_type
--    which is the type of NDM replenishment being created.
--    The replen type is used in view V_NDM_REPLEN_INFO.
--    This view calls this function.
--    The view needs to know what replenishment type is being created in order
--    to process CF and HS correctly when replenishing by min/max.
--    The replenishment types are shown below and came from
--    create_ndm.pc
--       'L' - Created from RF using "Replen By Location" option
--       'H' - Created from Screen using "Replen by Historical" option
--       'R' - Created from screen with options other than "Replen by Historical"
--       'O' - Created from cron when a store-order is received that requires a replenishment
--
--    create_ndm.pc calls set_replen_type before running the query that
--    selects from V_NDM_REPLEN_INFO.
--
--    I changed the view 2 months ago per a request by
--    Distribution Services to create a NDM replenishment
--    if the qty in the home slot is less than the max qty
--    when processing historical orders.  The change I made
--    does it for all NDM replenishments when replenishing
--    by min/max qty--basically the min qty is ignored.
--    The view will call get_replen_type to know what type
--    is being processed.  The type will be set in
--    create_ndm.pc by calling function set_replen_type
--
-- Parameters:
--    none
--
-- Return Values:
--    pl_replenishments.gl_replen_type
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Called by:  (list may not be complete)
--    - view V_NDM_REPLEN_INFO
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    03/18/13 prpbcb   Created
---------------------------------------------------------------------------
FUNCTION get_replen_type
RETURN VARCHAR2
IS
   l_message       VARCHAR2(512);  -- Message buffer.
BEGIN
   --
   -- 3/18/21903  Don't log anything  It will be too many messages.
   -- pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_replen_type', l_message,
   --                 SQLCODE, SQLERRM,
   --                 ct_application_function, gl_pkg_name);
   --

   RETURN(pl_replenishments.gl_replen_type);
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      l_message := 'Failed to return pl_replenishments.gl_replen_type.';

      pl_log.ins_msg(pl_lmc.ct_fatal_msg, 'get_replen_type', l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
            'get_replen_type' || ': ' || SQLERRM);
END get_replen_type;

  PROCEDURE p_ndm_repl_inv_swap(i_loc_src_dest IN replenlst.dest_loc%TYPE,
                                 o_status OUT NUMBER) IS
  BEGIN
       /* Process for destination location */
       update inv i set i.QTY_ALLOC =
       (
          select i.QTY_ALLOC - r.qty
          from replenlst r
          where i.prod_id=r.prod_id and r.PALLET_ID=i.LOGI_LOC
          and nvl(r.INV_DEST_LOC, r.DEST_LOC) = i_loc_src_dest AND r.type = 'NDM' AND r.status in( 'NEW','PRE')
       )
       where exists
       (
          select 1
          from replenlst r
         where i.prod_id=r.prod_id and r.PALLET_ID=i.LOGI_LOC
         and nvl(r.INV_DEST_LOC, r.DEST_LOC) = i_loc_src_dest AND r.type = 'NDM' AND r.status in( 'NEW','PRE')
       );

       update inv set qty_planned=0 where plogi_loc= i_loc_src_dest;

       /* Process for source location */
       update inv i set i.QTY_PLANNED =
       (
          select i.QTY_PLANNED - r.qty
          from replenlst r
          where i.prod_id=r.prod_id and nvl(r.INV_DEST_LOC, r.DEST_LOC)=i.LOGI_LOC  and r.src_loc = i_loc_src_dest
          AND r.type = 'NDM' AND r.status in( 'NEW','PRE')
       )
       where exists
       (
          select 1
          from replenlst r
         where i.prod_id=r.prod_id and nvl(r.INV_DEST_LOC, r.DEST_LOC)=i.LOGI_LOC  and r.src_loc = i_loc_src_dest
         AND r.type = 'NDM' AND r.status in( 'NEW','PRE')
       );

       update inv set qty_alloc=0 where plogi_loc = i_loc_src_dest;

       /*Once above qty adjustment has been done then it will delete the batch and replenishment records */
       delete from batch where batch_no in
       (
           select b.batch_no from replenlst r, batch b
           where r.type = 'NDM' and r.status in( 'NEW','PRE') and b.batch_no='FN'||r.task_id
           and (nvl(r.INV_DEST_LOC, r.DEST_LOC)= i_loc_src_dest or r.src_loc= i_loc_src_dest)
       );

       delete from replenlst r where r.type = 'NDM' and r.status in( 'NEW','PRE')
       and (nvl(r.INV_DEST_LOC, r.DEST_LOC)= i_loc_src_dest or r.src_loc= i_loc_src_dest);

       o_status:=0;
  EXCEPTION
     WHEN OTHERS THEN
        o_status:=999;
        RAISE_APPLICATION_ERROR(-20001, 'p_ndm_repl_inv_swap' || ': ' || SQLERRM);
  END p_ndm_repl_inv_swap;


--------------------------------------------------
-- Function:  (Public)
--    get_task_priority
--
-- Description:
--    This functions returns the forklift task priority
--    from USER_DOWNLOADED_TASKS.PRIORITY for the replenishment
--    task id.
--
--    The we want to populate TRANS.FORKLIFT_TASK_PRIORITY with
--    this priority for the relevant transactions for reporting
--    purposes as requested by Distribution Services.
--
--    If the task id is not found in USER_DOWNLOADED_TASKS then
--    -1 is returned.
--    If an error occurs then a log message is created and
--    -1 is returned.
--    Not getting the priority is not a fatal error.
--
--    replen_drop.pc is also getting the priority and will
--    also use -1 if not found.
--
-- Parameters:
--    i_task_id
--    i_user_id - This needs to include the OPS$ since this is how
--                the user id is stored in USER_DOWNLOADED_TASKS.
--
-- Return Value:
--    forklift task priority
--    -1 if not found on an error occurs.
--
-- Exceptions raised:
--    None.  An error will be written to swms log.
--
-- Called by:  (list not complete)
--    - pl_insert_replen_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    08/05/16 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_task_priority
              (i_task_id  IN user_downloaded_tasks.task_id%TYPE,
               i_user_id  IN user_downloaded_tasks.user_id%TYPE)
RETURN NUMBER
IS
   l_priority  user_downloaded_tasks.priority%TYPE;
BEGIN
   --
   -- Create another block to trap errors.
   --
   BEGIN
      SELECT u.priority INTO l_priority
        FROM user_downloaded_tasks u
       WHERE u.task_id = i_task_id
         AND u.user_id = i_user_id   -- Need this since multiple users can download the same tasks.
         AND u.task_id =             -- If for some reason we have duplicates select the min task id.
                (SELECT MIN(u2.task_id)
                   FROM user_downloaded_tasks u2
                  WHERE u2.task_id = u.task_id
                    AND u2.user_id = u.user_id);
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_priority := -1;
      WHEN OTHERS THEN
         l_priority := -1;

         pl_log.ins_msg(pl_log.ct_warn_msg, 'get_task_priority',
            'TABLE=user_downloaded_tasks  KEY=[' || TO_CHAR(i_task_id) || ',' || i_user_id || '](i_task_id,user_id)'
               || '  ACTION=SELECT  MESSAGE="Error selecting the priority.  This will not stop processing.'
               || '  -1 will be returned for the priority."', SQLCODE, SQLERRM,
            'INV', 'pl_insert_replen_trans');
  END;

  RETURN l_priority;

EXCEPTION
   --
   -- Ideally should never reach this point.  Log a message and return -1.
   --
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_log.ct_warn_msg, 'get_task_priority',
            'i_task_id[' ||  TO_CHAR(i_task_id) || ']'
            || '  i_user_id[' ||  TO_CHAR(i_user_id) || ']'
            || '  An error occured attempting to get the forklift task priority.'
            || '  This will not stop processing.'
            || '  -1 will be returned for the priority', SQLCODE, SQLERRM,
            'INV', 'pl_insert_replen_trans');
      RETURN -1;
END get_task_priority;


--------------------------------------------------
-- Function:  (Public)
--    get_suggested_task_priority
--
-- Description:
--    This functions returns the forklift task priority
--    from USER_DOWNLOADED_TASKS.PRIORITY for the replenishment
--    task id.
--
--    The we want to populate TRANS.FORKLIFT_TASK_PRIORITY with
--    this priority for the relevant transactions for reporting
--    purposes as requested by Distribution Services.
--
--    If the task id is not found in USER_DOWNLOADED_TASKS then
--    -1 is returned.
--    If an error occurs then a log message is created and
--    -1 is returned.
--    Not getting the priority is not a fatal error.
--
--    replen_drop.pc is also getting the priority and will
--    also use -1 if not found.
--
-- Parameters:
--    i_user_id - This needs to include the OPS$ since this is how
--                the user id is stored in USER_DOWNLOADED_TASKS.
--
-- Return Value:
--    forklift task priority
--    -1 if not found on an error occurs.
--
-- Exceptions raised:
--    None.  An error will be written to swms log.
--
-- Called by:  (list not complete)
--    - pl_insert_replen_trans
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ------------------------------------------------
--    08/05/16 prpbcb   Created.
------------------------------------------------------------------------
FUNCTION get_suggested_task_priority
              (i_user_id  IN user_downloaded_tasks.user_id%TYPE)
RETURN NUMBER
IS
   l_priority  user_downloaded_tasks.priority%TYPE;
BEGIN
   --
   -- Create another block to trap errors.
   --
   BEGIN
      SELECT MIN(u.priority) INTO l_priority
        FROM user_downloaded_tasks u
       WHERE u.user_id = i_user_id;   -- Need this since multiple users can download the same tasks.
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_priority := -1;
      WHEN OTHERS THEN
         l_priority := -1;

         pl_log.ins_msg(pl_log.ct_warn_msg, 'get_suggested_task_priority',
            'TABLE=user_downloaded_tasks  KEY=[' || i_user_id || '](user_id)'
               || '  ACTION=SELECT  MESSAGE="Error selecting the priority.  This will not stop processing.'
               || '  -1 will be returned for the priority."', SQLCODE, SQLERRM,
            'INV', 'pl_insert_replen_trans');
  END;

  RETURN l_priority;

EXCEPTION
   --
   -- Ideally should never reach this point.  Log a message and return -1.
   --
   WHEN OTHERS THEN
      pl_log.ins_msg(pl_log.ct_warn_msg, 'get_suggested_task_priority',
            'i_user_id[' ||  TO_CHAR(i_user_id) || ']'
            || '  An error occured attempting to get the forklift task priority.'
            || '  This will not stop processing.'
            || '  -1 will be returned for the priority', SQLCODE, SQLERRM,
            'INV', 'pl_insert_replen_trans');
      RETURN -1;
END get_suggested_task_priority;


END pl_replenishments;
/

