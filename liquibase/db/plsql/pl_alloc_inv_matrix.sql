
/**************************************************************************/
-- Package Specification
/**************************************************************************/

CREATE OR REPLACE PACKAGE swms.pl_alloc_inv_matrix
AS
-----------------------------------------------------------------------------
-- Package Name:
--   pl_alloc_inv_matrix
--
-- Description:
--    This packate allocates inventory for matrix items on an order.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    11/06/14 bben0556 Symbotic project.
--
--                      Created.  Instead of adding to pl_alloc_inv I
--                      created a new package for the matrix.
--
--                      Created record types:
--                         - t_r_alloc_matrix_cases
--                         - t_r_matrix_cases_inv
--
--                      Allocate inventory for matrix items.
--                      Create procedures:
--                         - alloc_matrix_cases()  It is based on procedure
--                                           pl_alloc_inv.AllocFloatingCases().
--                         - open_rc_alloc_matrix_cases()  It is based on procedure
--                                           pl_alloc_inv.open_rc_alloc_floating_cases().
--                         - open_rc_matrix_cases_inv()  It is based on procedure
--                                           pl_alloc_inv.open_rc_floating_cases_inv().
--
--    01/06/15 bben0556 Symbotic project.
--                      Demand replenishments to the matrix not created.
--
--                      Changed procedure "alloc_matrix_cases" to call
--                      procedure "pl_matrix_repl.create_matrix_dmd_rpl" to
--                      create the demand replenishmnents.
--
--    01/26/15 bben0556 Symbotic project.
--
--    09/17/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 543
--
--                      Bug fix--user getting "No LM batch" error message
--                      on RF when attempting to perform a DXL or DSP
--                      replenishment.
--
--                      FLOATS and FLOAT_DETAIL records not created for DXL
--                      and DSP replenishments (DXL-demand repl from the main
--                      warehouse to the matrix staging location; DSP-demand
--                      repl from the matrix to the split home) thus no
--                      forklift labor batch was created since the labor
--                      batch is created from the FLOATS and
--                      FLOAT_DETAIL records.
--
--                      Changed procedure alloc_matrix_cases() to call
--                      pl_matrix_repl.create_matrix_dmd_rpl() inside the
--                      "ordd alloc" loop for each order-item-uom.  Before
--                      it was called once before the loop at the route level.
--                      This was done so that pl_matrix_repl.create_matrix_dmd_rpl()
--                      has the necessary info to create the FLOATS and FLOAT_DETAIL
--                      records.
--                      Called changed from
--    pl_matrix_repl.create_matrix_dmd_rpl
--        (i_call_type                 => 'DXL',
--         i_route_batch_no            => l_route_batch_no,
--         i_route_no                  => i_route_no,
--         o_qty_replenished_in_splits => l_qty_replenished_in_splits,
--         o_status                    => o_status);
--                      to
--    pl_matrix_repl.create_matrix_dmd_rpl
--        (i_call_type                 => 'DXL',
--         i_prod_id                   => l_rec_cases.prod_id,
--         i_cust_pref_vendor          => l_rec_cases.cust_pref_vendor,
--         i_order_id                  => l_rec_cases.order_id,
--         i_order_line_id             => l_rec_cases.order_line_id,
--         i_route_batch_no            => l_route_batch_no,
--         i_route_no                  => i_route_no,
--         i_stop_no                   => l_rec_cases.stop_no,
--         o_qty_replenished_in_splits => l_qty_replenished_in_splits,
--         o_status                    => o_status);
--
--
--                      Changed name of variable qoh_in_matrix to qoh_avl_in_matrix.
--                      Add total_ordd_qty_ordered to record type t_r_alloc_matrix_cases.
--
--    10/02/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 543
--
--                      In the ORDER BY in procedure "open_rc_alloc_matrix_cases()"
--                      I had put l.logi_loc instead of i.logi_loc.
--                      So instead of allocating from the same pallet if
--                      we made it that deep ino the order by we could 
--                      allocate from different pallets if the item had
--                      multiple pallets in the same location.
--
--    10/02/15 bben0556 Brian Bent
--                      Symbotic project.  WIB 552
--
--                      Bug fix.  When selecting inventory to allocate
--                      against had l.logi_loc instead of inv.logi_loc 
--                      in the ORDER BY.  This resulted in the potential
--                      of allocating from different pallets for different
--                      orders instead of depleting from the same pallet.
--
--
--    11/12/15 bben0556 Brian Bent
--                      Project:
--               R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Throttling changes.
--                      Changes to allocate first from MXP slots for matrix items.
--
--                      Allocation Requirements:
--                      - An item cannot both be throttled and a matrix item.
--                      - Always allocate from matrix first for any item.
--                        alloc_inv.pc controls the allocation order so it
--                        need to allocate (attempt to) from the matrix first.
--                      - Throttled item will never have a DMD to the matrix.
--
--                      Change name of procedure "alloc_matrix_cases()" to
--                      "alloc_from_matrix()" so name is consistent with other
--                      procedure names.
--
--                      Add field to t_r_alloc_from_matrix:
--                      - mx_eligible              pm.mx_eligible%TYPE,
--                      - mx_item_assign_flag      pm.mx_item_assign_flag%TYPE,
--                      - mx_throttle_flag         pm.bcb_throttle_flag%TYPE,
--
--                     Change procedure "open_rc_alloc_from_matrix()".
--                     In the select statement add.
--                     - p.mx_eligible
--                     - p.mx_item_assign_flag 
--                     - p.mx_item_assign_flag
--                     - p.mx_throttle_flag
--                     In the select statement don't limit it to only matrix items.
--                     Basically check matrix for inventory for all items.
--
--                     Change procedure "open_rc_matrix_cases_inv()".
--                     - Select only inventory in a matrix location.
--                       Added lzone and zone in join and check for rule id = 5.
--                       I probably should have had this check since day one
--                       though before throttling when this point reached the
--                       inventory to allocate should have been in a matrix
--                       location--3/15/2016 (README) Changed this back to original logic
--                       of selecting from the main warehouse too since we want
--                       to allocate inv even if for same reason we allocate from
--                        main warehouse reserve. 
--                     - Changed to also select inventory in MXP slots.
--
--                     Change procedure "alloc_from_matrix()".
--                     Only create DXL for matrix items.
--                     DXL replenishments do not apply to throttled items.
--                     DXL replenishments do not apply to items unassigned
--                     from the matrix but still having inventory in the matrix.
--
--                     The MXP slots are slots in the main warehouse with slot
--                     type MXP where matrix items are put because the case(s)
--                     could not be inducted onto the matrix because of
--                     tolerance issues.  The rule is these get allocated first.
--                     There will be no replenishments from MXP slots to the
--                     mtarix for matrix items.
--                     If for whatever reason non matrix items have inventory
--                     in MXP slots then the MXP slots are treated like normal
--                     slots.
--
--    03/15/16 bben0556 Brian Bent
--                      Project:
--                R30.4--WIB#625--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Sometimes allocating from reserve for a matrix item.
--
--                      Changed  procedure "open_rc_alloc_from_matrix".
--                      - Variables "l_base_select_stmt and "l_select_stmt_with_wait"
--                        not large enough.  Changed from 2800 to 4000.
--                     - In the select that determines the qty in the matrix
--                       changed "SUM(inv.qoh)" to "NVL(SUM(inv.qoh), 0)" to
--                       handle when there is 0 qty in the matrix.  Before NULL
--                       was selected that caused a "if" to evaluate to false
--                       which then resulted in no DXL getting created thus
--                       the matrix item was picked from reserve (if there was
--                       any inventory in reserve).
--
--                      Changed procedure "alloc_from_matrix".
--                      - Log items that did not get fully allocated.
--
--
--    06/09/16 bben0556 Brian Bent
--                      Project:
--       R30.4.2--WIB#646--Charm6000013323_Symbotic_replenishment_fixes
--
--                      Save a little processing time.
--                      Change "open_rc_alloc_from_matrix" to only select float
--                      detail records for matrix items or if the item has
--                      inventory in the matrix.  Before it always selected
--                      all float detail records.
--
--                      Sometimes getting case picks from main warehouse reserve
--                      slots for matrix items.   Found my logic in deciding
--                      if a demand replenishment is required is flawed.
--                      Procedure "open_rc_alloc_from_matrix()" selects the
--                      float detail records to allocate inventory to.
--                      The select stmt has a field called "qoh_avl_in_matrix"
--                      which has the AVL qoh in the matrix (and MXP, MXT, MXO, MXI slots)
--                      for the order-item-uom.  (As a side note an order-item-uom can
--                      have more than one float detail record).
--                      In the processing of the float detail records
--                      "qoh_avl_in_matrix" is compared against the float detail
--                      qty ordered and if "qoh_avl_in_matrix" is less than
--                      the qty ordered then a demand replenishment.  The 
--                      problem is the qoh in the matrix goes down for each
--                      float detail record processed but "qoh_avl_in_matrix" 
--                      always has the initial qoh.
--                      Example of the isssue:
--                         An item is on two orders on a route.
--                         Float detail for order 123 has qty ordered of 5 cases
--                         Float detail for order 456 has qty ordered of 3 cases
--                         The item has 5 cases in the matrix and 20 cases in main
--                         warehouse reserve.
--                         "qoh_avl_in_matrix" is 5 cases.
--                         When processing the float detail record for order 123
--                         "qoh_avl_in_matrix" is >= qty ordered so no demand 
--                         replenishment needed
--                         When processing the 2st float detail record for order 456
--                         "qoh_avl_in_matrix" is >= qty ordered so no demand 
--                         replenishment needed.  But at this point the matrix
--                         has no inventory because order 123 took it all so
--                         a demand replenishment should have been created.
--                     To fix the issue I changed procedure "alloc_from_matrix()"
--                     to always select the qoh in the matrix for each float
--                     float detail record processed.  I renamed "qoh_avl_in_matrix"
--                     to "initial_qoh_avl_in_matrix" but don't use it for anything
--                     other than for logging.
--
--                     Change the case demand replenishment logic to include inventory
--                     in slot types MXT and MXO as pickable inventory.
--                     This means AVL inventory in the matrix structure and at
--                     the staging location and at the outbound location is
--                     pickable inventory and if the total qoh in these slots
--                     covers the order qty then a demand replenishment from
--                     main warehouse reserve to staging is not needed.
--                     If you are wondering why demand replenishment was
--                     working before it is because there is logic
--                     in pl_matrix_repl.sql for the demand replenishment
--                     processing that was also checking the slot types.
--                     So basically we have some dup logic. 
--                     Now what will happen is that the package will not
--                     call pl_matrix_repl.sql since no demand replenishment
--                     is not needed.
--                     Beware that inventory at the induction location and
--                     the spur is picked from if there is no other
--                     inventory.  We do not want induction location and
--                     spur inventory from preventing a demand replenishment
--                     from being created.
--                    
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


--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    alloc_from_matrix
--
-- Description:
--    This procedure allocates inventory for matrix items.
---------------------------------------------------------------------------
PROCEDURE alloc_from_matrix
             (i_route_no  IN   route.route_no%TYPE,
              o_status    OUT  NUMBER);

END pl_alloc_inv_matrix;
/


show errors


/**************************************************************************/
-- Package Body
/**************************************************************************/

CREATE OR REPLACE PACKAGE BODY swms.pl_alloc_inv_matrix
IS


---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.
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
-- This record is used by procedure alloc_from_matrix()
--
-- 11/12/215  Brian Bent  Throttling changes.
--            Add:
--               mx_eligible              pm.mx_eligible%TYPE,
--               mx_item_assign_flag      pm.mx_item_assign_flag%TYPE,
--               mx_throttle_flag         pm.bcb_throttle_flag%TYPE,
--
TYPE t_r_alloc_from_matrix IS RECORD
(
   prod_id                    float_detail.prod_id%TYPE,
   cust_pref_vendor           float_detail.cust_pref_vendor%TYPE,
   float_no                   floats.float_no%TYPE,
   seq_no                     float_detail.seq_no%TYPE,
   order_id                   float_detail.order_id%TYPE,
   stop_no                    float_detail.stop_no%TYPE,
   order_line_id              float_detail.order_line_id%TYPE,
   qty_order                  float_detail.qty_order%TYPE,
   qty_alloc                  float_detail.qty_alloc%TYPE,
   uom                        float_detail.uom%TYPE,
   split_cube                 pm.split_cube%TYPE,
   case_cube                  pm.case_cube%TYPE,
   spc                        pm.spc%TYPE,
   ml_ind                     pm.miniload_storage_ind%TYPE,
   split_trk                  pm.split_trk%TYPE,
   mx_eligible                pm.mx_eligible%TYPE,
   mx_item_assign_flag        pm.mx_item_assign_flag%TYPE,
   mx_throttle_flag           pm.mx_throttle_flag%TYPE,
   orig_uom                   ordd.original_uom%TYPE,
   initial_qoh_avl_in_matrix  NUMBER,
   total_ordd_qty_ordered     NUMBER
);


--
-- This record is used by procedure alloc_from_matrix()
--
TYPE t_r_matrix_cases_inv IS RECORD
(
   logi_loc      inv.logi_loc%TYPE,
   plogi_loc     inv.plogi_loc%TYPE,
   qoh           inv.qoh%TYPE,
   qty_alloc     inv.qty_alloc%TYPE,
   qty_avail     NUMBER,
   rec_id        inv.rec_id%TYPE,
   exp_date      inv.exp_date%TYPE,
   mfg_date      inv.mfg_date%TYPE,
   lot_id        inv.lot_id%TYPE
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
--    open_rc_alloc_from_matrix
--
-- Description:
--
--    This procedure opens a ref cursor used when allocating cases
--    for a matrix item or from the matrix.  It selects the float detail
--    records to attempt to allocate inventory to for inventory in the
--    matrix.
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_alloc_from_matrix  - 
--    i_route_no                - route being generated
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
--    09/25/15 prpbcb   Added field "total_ordd_qty_ordered" to the select.
--                      It is used to determine if a demand replenishment
--                      from the main warehouse to staging is needed.
--    01/22/16 bben0556 Brian Bent
--                      Throttling changes.
--    03/15/16 bben0556 Brian Bent
--                      Throttling changes.
--                      Variables "l_base_select_stmt and "l_select_stmt_with_wait"
--                      not large enough.  Changed from 2800 to 4000.
--
--    06/09/16 bben0556 Brian Bent
--                      Save a little processing time.
--                      Change the main select stmt to only select float
--                      detail records for matrix items or if the item has
--                      inventory in the matrix.  Before it always selected
--                      all float detail records.
--
--                      I put comments inside the select stmt so I
--                      had to increase the size of l_base_select_stmt and
--                      l_select_stmt_with_wait from 4000 to 5500.
---------------------------------------------------------------------------
PROCEDURE open_rc_alloc_from_matrix
            (io_rc_alloc_from_matrix  IN OUT SYS_REFCURSOR,
             i_route_no               IN     floats.route_no%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_alloc_from_matrix';

   l_base_select_stmt       VARCHAR2(5500);
   l_select_stmt_with_wait  VARCHAR2(5500);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
             'Starting Procedure  i_route_no[' || i_route_no || ']'
             || '  This procedure opens a ref cursor that selects the float'
             || ' detail records to allocate inventory to for'
             || ' matrix items or the item has inventory in the matrix.',
             NULL, NULL,
             ct_application_function, gl_pkg_name);

   --
   -- This statement selects the order detail records on the route for
   -- orders for cases of matrix items that need qty allocated.
   --
   -- Note this is at the float detail level and an order-prod-uom can be split
   -- across zones and can be split across floats(depending on syspar BREAK_ITEM_ON_FLOAT)
   --
   -- 11/12/2015  Brian Bent Throttling changes.
   --             Add p.mx_eligible
   --                 p.mx_item_assign_flag 
   --                 p.mx_item_assign_flag
   --                 p.mx_throttle_flag
   --
   l_base_select_stmt :=
  'SELECT fd.prod_id,
          fd.cust_pref_vendor,
          f.float_no,
          fd.seq_no,
          fd.order_id,
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
          p.mx_eligible,
          NVL(p.mx_item_assign_flag, ''N'')  mx_item_assign_flag,  -- 06/13/2016 Brian Bent  Added NVL
          NVL(p.mx_throttle_flag, ''N'')     mx_throttle_flag,     -- NVL here so we do not need to do a NVL in other parts of the program.
          NVL(od.original_uom, -1) orig_uom,
          --
          -- AVL inventory QOH in the matrix.
          -- Used in log message.
          -- 01/22/2016  Brian Bent Throttling changes.  Add MXP slot type.
          -- MXP slots treated as another slot to pick from.  For matrix
          -- items inventory is allocated first from MXP slots then from
          -- the matrix.
          -- 03/15/2016  Brian Bent Changed "SUM(inv.qoh)" to "NVL(SUM(inv.qoh), 0)"
          -- 06/17/2016  Brian Bent Added MXT, MXO, MXI and MXS slot types.  For order generation
          --                        what we consider in the matrix is inventory in locations we
          --                        can pick directly from which includes inventory in the
          --                        structure, in staging, in outbound, in induction and at a spur.
          --                        But we treat inventory at the induction and spurs differently.
          --                        We will pick from induction or a spur but only if
          --                        that is the last inventory left.
          (SELECT NVL(SUM(inv.qoh), 0)
             FROM inv, loc
            WHERE inv.plogi_loc         = loc.logi_loc
              AND loc.slot_type         IN (''MXP'', ''MXC'', ''MXF'', ''MXT'', ''MXO'', ''MXI'', ''MXS'') 
              AND inv.status            = ''AVL''
              AND inv.prod_id           = p.prod_id
              AND inv.cust_pref_vendor  = p.cust_pref_vendor) initial_qoh_avl_in_matrix,
          --
          -- Total qty ordered for the item-order-uom.
          -- Used in determining if demand replenishment needed.
          (SELECT SUM(ordd_2.qty_ordered - NVL(ordd_2.qty_alloc, 0))
             FROM ordd ordd_2
            WHERE ordd_2.prod_id            = od.prod_id
              AND ordd_2.cust_pref_vendor   = od.cust_pref_vendor
              AND ordd_2.order_id           = od.order_id
              AND ordd_2.order_line_id      = od.order_line_id
              AND ordd_2.uom                = od.uom) total_ordd_qty_ordered
     FROM ordd od,
          pm p,
          float_detail fd,
          floats f
    WHERE f.route_no             = :route_no
      AND f.float_no             = fd.float_no
      AND f.pallet_pull          = ''N''
      --
      -- 11/12/2015  Brian Bent Throttling changes, do not limit just to matrix items.
      -- Basically if it is a matrix item or it is a non-matrix item with
      -- inventory in the matrix then we allocate from the matrix.  For non-matrix items
      -- with inventory in the matrix the inventory is allocated from the matrix 
      -- first then inventory allocated from the main warehouse.
      -- 06/17/2016  Brian Bent  As you can see below inventory at spurs is not being 
      --                         included for non-matrix items and I really do not know
      --                         what will happen if by the off chance we have a non-matrix
      --                         item that has inventory at a spur and we need that inventory
      --                         to fill and order--picking from a spur is a last resort.
      AND (   p.mx_item_assign_flag  = ''Y''   
           OR EXISTS
                (SELECT ''x''
                   FROM inv, loc
                  WHERE loc.logi_loc         = inv.plogi_loc
                    AND inv.status           = ''AVL''
                    AND inv.prod_id          = fd.prod_id
                    AND inv.cust_pref_vendor = fd.cust_pref_vendor
                    AND loc.slot_type        IN (''MXP'', ''MXC'', ''MXF'', ''MXT'', ''MXO'', ''MXI'')) )
      --
      AND fd.status               = ''NEW''
      AND fd.uom                  = 2                -- Only cases in the matrix so allocate only for a case order.
      AND fd.merge_alloc_flag     IN (''X'',''Y'')   -- Only the float detail records for the primary selector.
      AND fd.prod_id              = p.prod_id
      AND fd.cust_pref_vendor     = p.cust_pref_vendor
      AND p.status               = ''AVL''
      AND od.order_id            = fd.order_id
      AND od.order_line_id       = fd.order_line_id
      AND od.qty_ordered - NVL(od.qty_alloc, 0) > 0  -- Only if not already allocated.
    ORDER BY fd.stop_no desc, fd.prod_id, fd.cust_pref_vendor
      FOR UPDATE OF fd.qty_alloc';

/*********     -- 11/06/014 Brian Bent  This may need changing for throttling.
      AND NOT EXISTS 
                (SELECT 0
                   FROM inv
                  WHERE inv.prod_id          = d.prod_id
                    AND inv.cust_pref_vendor = d.cust_pref_vendor
                    AND inv.logi_loc         = inv.plogi_loc)
********/

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

      OPEN io_rc_alloc_from_matrix FOR l_select_stmt_with_wait
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
                     || ' when allocating inventory for cases ordered for matrix items'
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

         OPEN io_rc_alloc_from_matrix FOR l_base_select_stmt
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
         || '(io_rc_alloc_from_matrix,i_route_no)'
         || '  i_route_no[' || i_route_no || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_alloc_from_matrix;


---------------------------------------------------------------------------
-- Procedure:
--    open_rc_matrix_cases_inv
--
-- Description:
--
--    This procedure opens a ref cursor that selects the inventory to
--    allocate against.  It does not check if the item is a matrix item or
--    not since a throttled item can/will have inventory in the matrix
--    or the item was a matrix item then moved back to the
--    main warehouse and inventory still exists in the matrix.
--
--    alloc_inv.pc allocates inventory in this order:
--    1.  Matrix
--    2.  From home
--    3.  From floating
--    4.  From the miniloader
--
--    For matrix items inventory can be allocated from the 
--
--    It first attempts to open using FOR UPDATE WAIT ...
--    If that fails then FOR UPDATE is used.
--
-- Parameters:
--    io_rc_matrix_cases_inv  - 
--    i_prod_id               - 
--    i_cust_pref_vendor      - 
--    i_spc                   - 
--
-- Called by:
--    - alloc_from_matrix()
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/06/14 prpbcb   Created.
--    09/25/14 prpbcb   Add "l.logi_loc" last in the order by.
--    03/16/16 prpbcb   Increased size of "l_base_select_stmt" and
--                      "l_select_stmt_with_wait" to 4000.
---------------------------------------------------------------------------
PROCEDURE open_rc_matrix_cases_inv
            (io_rc_matrix_cases_inv    IN OUT SYS_REFCURSOR,
             i_prod_id                 IN     inv.prod_id%TYPE,
             i_cust_pref_vendor        IN     inv.cust_pref_vendor%TYPE,
             i_spc                     IN     pm.spc%TYPE)
IS
   l_message           VARCHAR2(512);    -- Message buffer
   l_message_2         VARCHAR2(512);    -- Message buffer
   l_object_name       VARCHAR2(30) := 'open_rc_matrix_cases_inv';

   l_base_select_stmt       VARCHAR2(4000); 
   l_select_stmt_with_wait  VARCHAR2(4000);  -- l_base_select_stmt with the
                                             -- WAIT clause
BEGIN
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Starting Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

   --
   -- This statement selects the inventory record(s) to allocate inventory
   -- against for case orders for matrix items.
   -- The inventory is allocated from locations in this order:
   --    - Inventory in locations with slot type MXP.
   --    - Matrix inventory location
   --    - Matrix staging location
   --    - Matrix outbound location
   --    - Matrix induction location
   --    - Matrix spur location.
   --    - From reserve.  Ideally picks from reserve should not happen as
   --      if there is no inventory in the matrix then a demand replenishment
   --      to the staging location then picking from the staging location
   --      should occur.
   --
   -- Note: 11/06/2014 Brian Bent  We need to come up with a way to avoid hardcoding in the ORDER BY
   --
   -- 11/12/2015 Brian Bent  Throttling changes.  Select only inventory in a matrix location.
   --            Added lzone and zone in join and check for rule id = 5.  I probably should have
   --            had this check since day one though before throttling when this point
   --            reached the inventory to allocate should have been in a matrix location.
   -- 01/20/2016 Brian Bent  Throttling changes.  rule_id needs to be 5 
   --            or (slot type MXP and matrix item)
   -- 03/15/2016 Brian Bent  For matrix items include main warehouse inventory if for
   --            whatever reason (bug, setup issue) we get to the point of allocating
   --            from the main warehouse.
   --           
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
          i.lot_id
     FROM loc l,
          inv i,
          lzone lz,
          zone z,
          pm
    WHERE i.prod_id           = :prod_id
      AND i.cust_pref_vendor  = :cust_pref_vendor
      AND pm.prod_id          = i.prod_id
      AND pm.cust_pref_vendor = i.cust_pref_vendor
      AND i.status            = ''AVL''
      AND l.logi_loc          = i.plogi_loc
      AND i.inv_uom           IN (0, 2)
      AND lz.logi_loc         = l.logi_loc
      AND z.zone_id           = lz.zone_id
      AND z.zone_type         = ''PUT''
      AND l.slot_type         <> ''MLS'' -- No miniloader location.
      AND l.perm              = ''N''    -- Failsafe.  At this point in the allocation process do not
                                         -- allocate from perm slots as this will create problems.
      --
      -- The location needs to be one of the matrix locations except if it is a matrix item
      -- then it could be a main warehouse location.
      AND (z.rule_id = 5          OR pm.mx_item_assign_flag = ''Y'')
      AND (l.slot_type <> ''MXP'' OR pm.mx_item_assign_flag = ''Y'')
      --
      AND TRUNC ((i.qoh - i.qty_alloc) / :spc) > 0
    ORDER BY DECODE(l.slot_type, ''MXP'', -1,  -- 01/20/2016 Allocate inventory from inventory in MXP slots first.
                                               -- These are slots in the main warehouse where matrix items are put
                                               -- because the case could not be inducted onto the matrix because 
                                               -- of tolerance issues.  The rule is these get allocated first.
                                               -- MXP slots for non-matrix items are treated like regular slots.
                                 ''MXC'', 0,
                                 ''MXF'', 0,
                                 ''MXT'', 1,
                                 ''MXO'', 2,
                                 ''MXI'', 3,
                                 ''MXS'', 4,
                                 50),
             i.exp_date,
             l.pik_level,
             l.pik_path,
             i.logi_loc
     FOR UPDATE OF i.qoh';

    --
    -- 4/24/2013 Brian Bent This was already commented out.  I left it.
    --
/*
         DECODE (SIGN ((i.qoh - i.qty_alloc) - pQtyReqd),
             -1, 999999, (i.qoh - i.qty_alloc)),
         (i.qoh - i.qty_alloc),
*/


   l_message_2 :=
            'ITEM['  || i_prod_id || ']'
         || '  CPV[' || i_cust_pref_vendor || ']'
         || '  SPC[' || TO_CHAR(i_spc) || ']';


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

      OPEN io_rc_matrix_cases_inv FOR l_select_stmt_with_wait
         USING i_prod_id,
               i_cust_pref_vendor,
               i_spc;

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

         OPEN io_rc_matrix_cases_inv FOR l_base_select_stmt
            USING i_prod_id,
                  i_cust_pref_vendor,
                  i_spc;

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
         || '(io_rc_matrix_cases_inv,i_prod_id,i_cust_pref_vendor,i_spc)'
         || '  i_prod_id'           || i_prod_id || ']'
         || '  i_cust_pref_vendor'  || i_cust_pref_vendor || ']'
         || '  i_spc'               || TO_CHAR(i_spc) || ']';

      pl_log.ins_msg(pl_log.ct_fatal_msg, l_object_name, l_message,
                     SQLCODE, SQLERRM,
                     ct_application_function, gl_pkg_name);

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error,
                              l_object_name || ': ' || SQLERRM);

END open_rc_matrix_cases_inv;




--------------------------------------------------------------------------
-- Public Modules
--------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    alloc_from_matrix
--
-- Description:
--    This procedure allocates cases from the matrix for the matrix items
--    on a route.
--
-- Parameters:
--   i_route_no  - route to process
--   i_status    - Indicates success or failure.
--
-- Called By:
--    - alloc_inv.pc
--
-- Exceptions raised:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/06/14 bben0556 Created.
--    01/08/15 bben0556 Added call to procedure
--                      "pl_matrix_repl.create_matrix_dmd_rpl" to create
--                      DMD replenishments from the main warehouse reserve
--                      to the default staging location if there is not
--                      enough qty in the matrix to cover the qty ordered
--                      for the matrix items on the route.
--    09/04/15 bben0556 Brian Bent
--                      Modified to call "pl_matrix_repl.create_matrix_dmd_rpl()"
--                      inside the "alloc" loop at the order-item-uom level
--                      instead of once at the route level before the loop.
--                      See the package Modification History on 09/04/2015 
--                      for more information.
--    01/12/16 bben0556 Brian Bent
--                      Throttling changes.
--                      Allocate from MXP slots.
--    06/09/16 bben0556 Brian Bent
--                      Bug fix.  Sometimes picking cases from main warehouse
--                      reserve instead of creating a demand replenishment.
--                      This was happening because the initial qoh in the
--                      matrix was being used in determining if the matrix had
--                      sufficient qoh to cover the float detail qty ordered.   
--                      I was not taking into acccout the matrix qoh goes down
--                      for each float detail record processed.
--                      To fix the issue the qoh in the matrix is selected for
--                      each float float detail record processed.
---------------------------------------------------------------------------
PROCEDURE alloc_from_matrix
             (i_route_no  IN   route.route_no%TYPE,
              o_status    OUT  NUMBER)
IS
   l_object_name      VARCHAR2 (24) := 'alloc_from_matrix';

   --
   -- Ref cursor pointing to the matrix items ordd,float_detail records that
   -- need inventory allocated.
   --
   l_rc_alloc_from_matrix  SYS_REFCURSOR; 
                                          
   l_rec_cases                t_r_alloc_from_matrix;

   --
   -- Ref cursor pointing to inventory records to allocate against.
   --
   l_rc_inv   SYS_REFCURSOR; 

   l_rec_inv        t_r_matrix_cases_inv;   -- Record for inventory to allocate against.

   l_qty_alloc      NUMBER := 0;
   l_float_no       NUMBER := 0;
   l_seq_no         NUMBER := 0;
   l_qty_req        NUMBER := 0;
   l_qty_order      NUMBER := 0;
   l_qty_remain     NUMBER := 0;
   l_next_seq       NUMBER := 0;
   l_new_ord_line   NUMBER := 0;
   l_route_batch_no  route.route_batch_no%TYPE;
   l_qty_replenished_in_splits  NUMBER;  -- Needed in call to pl_matrix_repl.create_matrix_dmd_rpl
                                         -- Other than that it is not used.
   l_qoh_avl_in_matrix   NUMBER;  -- The available qoh in the matrix, MXP, MXT and MXO slots.  Calculated
                                  -- for each float detail record processed.  For matrix items it
                                  -- is used to determine if a demand replenishment is needed.
                                  -- Note that there is special processing with MXP slots in that
                                  -- for "matrix" items we pick from MXP slots first and demands
                                  -- replenishments are never created from/to MXP slots.
                                  -- If a "non matrix" item has inventory in MXP slots then the
                                  -- MXP slot is treated like a regular slot.
             
BEGIN
   pl_log.ins_msg
        (pl_log.ct_debug_msg, l_object_name,
         'Starting Procedure  i_route_no[' || i_route_no || ']'
         || '  This procedure allocates inventory to the float detail'
         || ' records for matrix items and also for non-matrix items'
         || ' with inventory in the matrix.   For the non-matrix items'
         || ' inventory is allocated from the matrix first then another'
         || ' procedure will be called to allocate from the main warehouse.',
         NULL, NULL,
         ct_application_function, gl_pkg_name);

   o_status := 0;

   --
   -- We need the route batch number to pass to
   -- pl_matrix_repl.create_matrix_dmd_rpl because the route batch_no
   -- is populated in the REPLENLST record.
   --
   -- XXX  1/8/2014 Brian Bent Need to add error handing.
   SELECT r.route_batch_no INTO l_route_batch_no
     FROM route r
    WHERE r.route_no = i_route_no;
  
   --
   -- Open the ref cursor that selects the matrix items from float_detail
   -- that need inventory allocated.
   -- 11/12/2015  Brian Bent  Because of throttling changes "open_rc_alloc_from_matrix"
   --             modified to look at all items. It no longer is limited to matrix items.
   --
   open_rc_alloc_from_matrix
            (l_rc_alloc_from_matrix,
             i_route_no);

   --
   -- Allocate inventory to the order.
   --
   LOOP
      FETCH l_rc_alloc_from_matrix INTO l_rec_cases;
      EXIT WHEN l_rc_alloc_from_matrix%NOTFOUND;

      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'in loop', NULL, NULL, ct_application_function, gl_pkg_name);


      --
      -- 06/09/2016 Brian Bent
      -- Get the available "normal pickable" qoh in the matrix.  For matrix items it will be
      -- used to determine if a demand replenishment is needed.
      -- "normal pickable" qoh is inventory in a location we directly pick from.  This
      -- includes the two matrix locations--MXF amd MXC--, matrix staging, MXP slots,
      -- and matrix outbound.  Inventory at induction or a spur is not considered
      -- "normal pickable" at this stage in the processing but if it turns out the only inventory
      -- left is at induction or a spur then it will be picked from.
      -- We will create a demand replenishment from the main warehouse to staging before we pick
      -- from induction or a spur.
      --
      SELECT NVL(SUM(inv.qoh), 0)   -- qty_planned is not pickable inventory so do not include it.
        INTO l_qoh_avl_in_matrix
        FROM inv, loc
       WHERE inv.plogi_loc         = loc.logi_loc
         AND loc.slot_type         IN ('MXF', 'MXC', 'MXP', 'MXT', 'MXO')  -- Note we do not want to include MXI and MXS.
         AND inv.status            = 'AVL'
         AND inv.prod_id           = l_rec_cases.prod_id
         AND inv.cust_pref_vendor  = l_rec_cases.cust_pref_vendor;

      --
      -- 06/09/2016  Brian Bent
      -- Log a message so we know the inventory quantities.
      --
      pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 
           'prod_id['                      || l_rec_cases.prod_id                || ']'
        || '  CPV['                        || l_rec_cases.cust_pref_vendor       || ']'
        || '  order_id['                   || l_rec_cases.order_id               || ']'
        || '  order_line_id['              || TO_CHAR(l_rec_cases.order_line_id) || ']'
        || '  mx_item_assign_flag['        || l_rec_cases.mx_item_assign_flag    || ']'
        || '  mx_throttle_flag['           || l_rec_cases.mx_throttle_flag       || ']'
        || '  total_ordd_qty_ordered['     || TO_CHAR(l_rec_cases.total_ordd_qty_ordered)    || ']'
        || '  initial_qoh_avl_in_matrix['  || TO_CHAR(l_rec_cases.initial_qoh_avl_in_matrix) || ']'
        || '  l_qoh_avl_in_matrix['        || TO_CHAR(l_qoh_avl_in_matrix)       || ']'
        || '  "initial_qoh_avl_in_matrix" includes available inventory in slot types MXP, MXC, MXF, MXT, MXO, MXI and MXS.'
        || '  It is included in this message as a reference.'
        || '  "l_qoh_avl_in_matrix" includes slot types MXP, MXC, MXF, MXT and MXO and is used to determine if'
        || ' a demand replenishment from main warehouse reserve to staging is needed.'
        || '  Inventory in MXI and MXS do not control the demand replenishment processing.'
        || '  We will create a demand from the main warehouse to staging before we pick from induction or a spur.'
        || '  But if it turns out the only inventory left is at induction or a spur then it will be picked from.',
        NULL, NULL, ct_application_function, gl_pkg_name);

      -- 
      -- Create DXL replenishment if there is not sufficient AVL inventory
      -- in the matrix to cover the qty ordered.
      --
      -- NOTE:  9/25/2015  Brian Bent
      --        If and order-item-uom is broken across zones and/or floats and a demand replenishment
      --        is necessary then we could call "pl_matrix_repl.create_matrix_dmd_rpl()"
      --        unnecessarily as the first call would have created the necessary
      --        replenishment(s).   Because cursor l_rc_alloc_from_matrix has already 
      --        selected the records it won't see the inventory from a demand replenisment.
      --        But "pl_matrix_repl.create_matrix_dmd_rpl()" will see the inventory so it won't create
      --        extra replenishments.  The little extra time in calling
      --        "pl_matrix_repl.create_matrix_dmd_rpl()" should be of no consequence.
      --
      -- 11/12/2015  Brian Bent
      --             Throttling changes.  Only create DXL for matrix item.
      --
      IF (    l_rec_cases.mx_item_assign_flag = 'Y' 
          AND l_rec_cases.mx_throttle_flag = 'N'
          AND l_rec_cases.total_ordd_qty_ordered > l_qoh_avl_in_matrix)
      THEN
         pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 
                 'Matrix item and QOH available in the matrix is not enough'
                 || ' to cover the qty ordered for the item on the order being'
                 || ' processed.  Call the demand replenishment processing.',
                 NULL, NULL, ct_application_function, gl_pkg_name);

         pl_matrix_repl.create_matrix_dmd_rpl
             (i_call_type                 => 'DXL',
              i_prod_id                   => l_rec_cases.prod_id,
              i_cust_pref_vendor          => l_rec_cases.cust_pref_vendor,
              i_order_id                  => l_rec_cases.order_id,
              i_order_line_id             => l_rec_cases.order_line_id,
              i_route_batch_no            => l_route_batch_no,
              i_route_no                  => i_route_no,
              i_stop_no                   => l_rec_cases.stop_no,
              o_qty_replenished_in_splits => l_qty_replenished_in_splits,
              o_status                    => o_status);
      END IF;


      l_float_no  := l_rec_cases.float_no;
      l_seq_no    := l_rec_cases.seq_no;
      l_qty_req   := l_rec_cases.qty_order;
      l_qty_order := l_rec_cases.qty_order;

      --
      -- Open the ref cursor that selects the inventory to allocate against.
      --
      open_rc_matrix_cases_inv(l_rc_inv, 
                                l_rec_cases.prod_id,
                                l_rec_cases.cust_pref_vendor,
                                l_rec_cases.spc);

      --
      -- Allocate inventory to the float_detail record.
      --
      LOOP
         FETCH l_rc_inv INTO l_rec_inv;
         EXIT WHEN l_rc_inv%NOTFOUND;
   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'in inner loop', NULL, NULL, ct_application_function, gl_pkg_name);

         IF (l_rec_inv.qty_avail < l_qty_order)
         THEN
            l_qty_alloc := l_rec_inv.qty_avail - MOD (l_rec_inv.qty_avail, l_rec_cases.spc);
            l_qty_remain := l_qty_order - l_qty_alloc;
         ELSE
            l_qty_alloc := l_qty_order;
            l_qty_remain := 0;
         END IF;

         IF (l_qty_alloc != 0)
         THEN
            UPDATE float_detail
               SET qty_alloc  = l_qty_alloc,
                   qty_order  = l_qty_alloc,
                   status     = 'ALC',
                   cube = DECODE(uom, 1,
                             l_rec_cases.split_cube, l_rec_cases.case_cube) * l_qty_alloc /
                          DECODE (uom, 1, 1, l_rec_cases.spc),
                   src_loc      = l_rec_inv.plogi_loc,
                   alloc_time   = SYSDATE,
                   rec_id       = l_rec_inv.rec_id,
                   mfg_date     = l_rec_inv.mfg_date,
                   exp_date     = l_rec_inv.exp_date,
                   lot_id       = l_rec_inv.lot_id,
                   carrier_id   = l_rec_inv.logi_loc
             WHERE float_no = l_float_no
               AND seq_no   = l_seq_no;

            IF (    l_qty_alloc = l_rec_inv.qoh
                AND l_rec_inv.qty_alloc = 0) THEN
               DELETE inv
                WHERE inv.logi_loc = l_rec_inv.logi_loc;
                -- WHERE CURRENT OF l_rc_inv;
            ELSE
               UPDATE inv
                  SET qoh = qoh - l_qty_alloc
                WHERE inv.logi_loc = l_rec_inv.logi_loc;
                -- WHERE CURRENT OF l_rc_inv;
            END IF;

            UPDATE ordd
               SET qty_alloc = NVL (qty_alloc, 0) + l_qty_alloc
             WHERE order_id      = l_rec_cases.order_id
               AND order_line_id = l_rec_cases.order_line_id;

            UPDATE pm
               SET last_ship_slot = l_rec_inv.plogi_loc
             WHERE prod_id          = l_rec_cases.prod_id
               AND cust_pref_vendor = l_rec_cases.cust_pref_vendor;

            IF (l_qty_remain = 0)
            THEN
               EXIT;
            END IF;
         END IF;

         /*
         ** Didn't complete the pick. Try remaining from
         ** the next location
         */

         l_msg := 'Calling from alloc_from_matrix Loop 1: ' ||
             'CreateFloatDetailRecord ( ' || l_float_no|| ', ' ||
             l_seq_no || ', ' || l_qty_remain || ',2 , -1, ' ||
             l_next_seq || ')';
         pl_text_log.ins_msg ('W', l_object_name, l_msg, NULL, NULL);

         pl_alloc_inv.CreateFloatDetailRecord (l_float_no, l_seq_no, l_qty_remain, 2, -1, l_next_seq);

         l_seq_no := l_next_seq;
         l_qty_req := l_qty_req - l_qty_alloc;
         l_qty_order := l_qty_remain;

      END LOOP;  -- end FETCH l_rc_inv INTO l_rec_inv

      IF (l_rc_inv%ISOPEN) THEN
         CLOSE l_rc_inv;
      END IF;

      --
      -- If quantity was not fully allocated and the UOM is case,
      -- and if the original order was in splits, then see if the
      -- remaining quantity can be filled as splits.
      --
      IF (l_qty_remain != 0 AND l_rec_cases.split_trk = 'Y' AND l_rec_cases.orig_uom = 1)
      THEN
         l_msg := 'Calling from alloc_from_matrix: ' ||
             'pl_alloc_inv.CreateOrdd ( ' || l_rec_cases.order_id || ', ' ||
             l_rec_cases.order_line_id || ', ' || l_rec_cases.prod_id ||
             ', ' || l_rec_cases.cust_pref_vendor || ', ' ||
             l_qty_remain || ', ' || l_new_ord_line || ')';

         pl_text_log.ins_msg ('W', l_object_name, l_msg, NULL, NULL);

         pl_alloc_inv.CreateOrdd (
            l_rec_cases.order_id,
            l_rec_cases.order_line_id,
            l_rec_cases.prod_id,
            l_rec_cases.cust_pref_vendor,
            l_qty_remain, l_new_ord_line);

         l_msg := 'Calling from alloc_from_matrix Loop 2: ' ||
             'CreateFloatDetailRecord ( ' || l_float_no|| ', ' ||
             l_seq_no || ', ' || l_qty_remain || ', 1, ' ||
             l_new_ord_line || ', ' || l_next_seq || ')';
         pl_text_log.ins_msg ('W', l_object_name, l_msg, NULL, NULL);

         pl_alloc_inv.CreateFloatDetailRecord (l_float_no, l_seq_no, l_qty_remain, 1, l_new_ord_line, l_next_seq);

      END IF;
   END LOOP;  -- end FETCH l_rc_inv INTO recIn;

   IF (l_rc_inv%ISOPEN) THEN
      CLOSE l_rc_inv;
   END IF;

   --
   -- If there are any more matrix items for this route that are
   -- not still fully allocated, change all their statuses to SHT.
   --
   FOR r IN
     (SELECT f.batch_no, f.float_no, d.seq_no, d.prod_id, d.cust_pref_vendor, d.qty_order, d.qty_alloc, d.status, d.uom
        FROM pm p,
             float_detail d,
             floats f
       WHERE f.route_no            = i_route_no
         AND f.float_no            = d.float_no
         AND f.pallet_pull         = 'N'
         AND d.uom                 = 2
         AND p.mx_item_assign_flag = 'Y'
         AND d.status              IN ('NEW', 'ALC')
         AND d.merge_alloc_flag    IN ('X', 'Y')
         AND d.prod_id             = p.prod_id
         AND d.cust_pref_vendor    = p.cust_pref_vendor
         AND p.status              = 'AVL'
         AND NVL (d.qty_alloc, 0)  < d.qty_order)
   LOOP
      UPDATE float_detail
         SET status = 'SHT'
       WHERE float_no = r.float_no
         AND seq_no   = r.seq_no;

      -- 
      -- 03/15/2016  Brian Bent  Log a message.
      -- 
      pl_log.ins_msg(pl_log.ct_info_msg, l_object_name,
                  'FLOAT_DETAIL Info:'
                  || '  Route['        || i_route_no            || ']'
                  || '  Batch['        || TO_CHAR(r.batch_no)   || ']'
                  || '  Float['        || TO_CHAR(r.float_no)   || ']'
                  || '  Item['         || r.prod_id             || ']'
                  || '  CPV['          || r.cust_pref_vendor    || ']'
                  || '  uom['          || TO_CHAR(r.uom)        || ']'
                  || '  qty_order['    || TO_CHAR(r.qty_order)  || ']'
                  || '  qty_alloc['    || TO_CHAR(r.qty_alloc)  || ']'
                  || '  status['       || r.status              || ']'
                  || '  Full qty not allocated to the float detail record.'
                  || '  The FLOAT_DETAIL.STATUS set to SHT.',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);
  
   END LOOP;

   pl_log.ins_msg(pl_log.ct_debug_msg, l_object_name, 'Ending Procedure',
                  NULL, NULL,
                  ct_application_function, gl_pkg_name);

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      NULL;
   WHEN OTHERS THEN
      o_status := SQLCODE;

END alloc_from_matrix;

END pl_alloc_inv_matrix;
/

show errors

/***
CREATE OR REPLACE PUBLIC SYNONYM pl_alloc_inv_matrix FOR swms.pl_alloc_inv_matrix
/

GRANT EXECUTE ON pl_alloc_inv_matrix TO swms_user
/
****/

