
CREATE OR REPLACE PACKAGE SWMS.pl_cross_dock_order_processing
AS
---------------------------------------------------------------------------
--
-- NAME:       "SWMS.pl_cross_dock_order_processing"
-- PURPOSE:
--
-- This package is used for Processing Orders of European Imports type
-- Uses following SPs for
--        * f_find_crossdock_value - To check if the given sysco order
--          is of cross dock type or not
--        *
--        *
--        *
--        *
--        *
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    05/13/14 Infosys  1. Initial Version
--    07/16/19 bben0556 Brian Bent
--                      Project: R30.6.7-Jira OPCOF-2452-Run_case_pick_logic for_build_to_pallet
--
--                      Meat companies changes.
--                      Run through the case pick logic for build to pallet items.
--
--                      Modified procedure create_floats_multisku_bulk()
--                         Modified cursor c_ei_items_in_pallet:
--                         Changed
--                            (od.qty_ordered - NVL (od.qty_alloc, 0)) qty_on_pallet,
--                         to
--                            LEAST((od.qty_ordered - NVL (od.qty_alloc, 0)), cddc.qty) qty_on_pallet,
--                         Added selecting od.seq
--
--                         Populated FLOAT_DETAIL.ORDER_SEQ
--                               order_seq
--
--                      Modified procedure update_floats_ordcw()
--                        Modified cursor c_ordd_cw_records.  Added this to the where clause:
--                           AND m.cross_dock_type NOT IN ('BP') -- Don't update ordcw for the build to pallet cdk type.
--
--                      Modified procedure update_multisku_pallet_inv()
--                         Add updating of ORDD.QTY_ALLOC.
--
--    08/01/19 sban3548 Modified update_floats_ordcw to update catch weight for 
--                      Bulk Pull orders based on float_no and pallet pull type "B"
--
--    08/14/19 sban3548 Added new procedure to update sys_order_id for cross dock tables
--
--    08/14/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      CMU changes
--                      For CMU and order can have non-cross dock and cross dock which
--                      is different from the EI implemention which was one order was for
--                      one or more cross dock pallet.
--                      For CMU we are still using ORDM.CROSS_DOCK_TYPE.  We don't have
--                      CROSS_DOCK_TYPE at the ORDD level.
--                      Change queries, etc to account for orders have cross dock and
--                      non-cross dock pallets.
--
--                      For cross dock pallets picked at the RDC we need to retain
--                      the order seq from the RDC since that is what is on the pick labels.
--
--                      Changed names of cursors and record from "_ei_" to "_cd_".
--                      "cd" is short for cross dock.
--
--                      Add procedures:
--                         - ins_ordd_using_existing_rec
--                         - preprocess_cmu_order
--
--                      Modified:
--                         - recover_ei_order
--                           During order generation when ORDD.REMOTE_LOCAL_FLAG is 'B'
--                           an ORDD record for the OpCo pick for the qty to be filled from the OpCo
--                           is created.
--                           This ORDD record needs to be deleted.
--
--   09/09/19 sban3548   opcof_2537: Remove condition references to master_order_id
--
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    10/07/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      Procedure "create_floats_multisku_bulk" is duplicating the float detail
--                      records when the same item is on two different orders on the same parent LP.
--                      To fix modified cursor "c_cd_items_on_pallet" adding the follow to the
--                      where clause:
--                          AND od.seq  = cddc.order_seq
-- 
--    10/08/19 bben0556 Brian Bent
--                      Adding  AND od.seq  = cddc.order_seq to cursor "c_cd_items_on_pallet" was not
--                      the thing to do.  Remove that and added additional criteria to cursor "c_cd_items_on_pallet"
--                      to prevent duplicates.
--                   
--    11/04/19 bben0556 Brian Bent
--                      Project: R30.6.8--CMU-Jira-OPCOF-2632-Fix_incorrect_door_number_for_CMU_crossdock_bulkpull_to_the_door
--
--                      Found the loop that creates the replenishment task(s) was reference variable "l_door"
--                      that was set and used in a previous loop.  Changed cursor "c_all_floats" to join
--                      to the FLOATS table to get the door number as by this time the FLOATS door number
--                      has been updated to the correct door.
--
--                   
--    12/11/19 bben0556 Brian Bent
--                      Project: R30.6.9--CMU-Jira-OPCOF-2682-Allocation_shorting_and_inv_status_set_to_ERR
--
--                      CMU item shorting at the OpCo but the inventory is on the MSKU pallet.
--                      This is happening when the same item is on two different orders going to the same customer.
--                      Example from OpCo 037:
-- 
-- ORDD
--                                     QTY
-- CUST_ID    PROD_ID   QTY_ORDERED  ALLOC STA ORDER_ID       ORDER_LINE_ID SYS_ORDER_ID REMOTE_LOCAL_F REMOTE_QTY RDC_PO_NO
-- ---------- --------- ----------- ------ --- -------------- ------------- ------------ -------------- ---------- --------------
-- 477968     4707675            32     10 SHT 237894832                  2         5377 R                      32 23846790
-- 477968     4707675            10     10 OPN 237894833                 11         9171 R                      10 23858230
--
-- FLOAT_DETAIL
-- PROD_ID   PARENT_PALLET_ID   CARRIER_ID         ROUTE_NO     FLOAT_NO     SEQ_NO  QTY_ORDER  QTY_ALLOC STA ORDER_ID       ORDER_LINE_ID  ORDER_SEQ
-- --------- ------------------ ------------------ ---------- ---------- ---------- ---------- ---------- --- -------------- ------------- ----------
-- 4707675   184000000001802517 184000000001802531 1126          7324940         17         32         10 SHT 237894832                  2   11227509
-- 4707675   184000000001802517 184000000001802530 1126          7324940         16         10         10 ALC 237894833                 11   11227521
-- 
--
--                      Modified procedure "update_multisku_pallet_inv".
--                      Changed cursor "c_cd_orders_on_route".
--                      Changed cursor "c_cd_floats"
--                      Changed cursor "c_fd"
--                      Added criteria in other stmts as needed to match float_detail and ordd by item, order,
--                      and order line id. 
--
--    03/22/20 bben0556 Brian Bent
--                      Project: R30.6.9-Jira-OPCOF-2698-CMU-Project_delete_cross_dock_inv_at_op_allocation_time
--
--                      Modified:
--                         - Procedure "update_multisku_pallet_inv"
--                           Delete the inventory when allocated.  Before the inventory
--                           was deleted when the cross dock pallet was dropped
--                           at the door
--
--                      Added:
--                         - Procedure "recover_cross_dock_pallets"
--                         - Procedure "insert_rvp_transaction"
--
--    03/24/20 bben0556 Brian Bent
--                      Project: R30.6.9-Jira-OPCOF-2698-CMU-Project_delete_cross_dock_inv_at_op_allocation_time
--                      In the delete INV statement I added to procedure "update_multisku_pallet_inv"
--                      I forget to join ordm to ordd (though it still would have only deleted the correct records).
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    07/14/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Do not process 'S' or 'X' cross dock types.
-----------------------------------------------------------------------------

--                     
--
------------------------------------------------------------------------------------------------------

FUNCTION f_get_crossdock_value (i_id IN VARCHAR, i_type IN CHAR)
   RETURN CHAR;

PROCEDURE create_floats_multisku_bulk (i_route_no IN route.route_no%TYPE);

PROCEDURE update_ordm_cdk_for_btp_inv(i_route_no IN route.route_no%TYPE);

PROCEDURE create_lm_multisku_bulk_batch
                (i_route_no   IN   route.route_no%TYPE);

PROCEDURE update_multisku_pallet_inv 
               (i_route_no    IN   route.route_no%TYPE,
                i_method_id   IN   sel_method.method_id%TYPE);

PROCEDURE update_ordd_zone
               (i_order_id       IN   ordd.order_id%TYPE,
                i_sys_order_id   IN   ordd.sys_order_id%TYPE,
                i_prod_id        IN   ordd.prod_id%TYPE);

PROCEDURE update_ordm_cdk_type (i_route_no IN route.route_no%TYPE);

PROCEDURE update_floats_ordcw (i_route_batch_no IN route.route_batch_no%TYPE);
   
PROCEDURE recover_ei_order (i_route_no IN route.route_no%TYPE);

PROCEDURE update_cmu_sys_order_id (i_route_no IN route.route_no%TYPE);

PROCEDURE recover_cross_dock_pallets(i_route_no  IN  route.route_no%TYPE);     -- 03/22/2020 Brian Bent Added

END pl_cross_dock_order_processing;
/



CREATE OR REPLACE PACKAGE BODY swms.pl_cross_dock_order_processing
AS
--------------------------------------------------------------------------------------
--    NAME:       pl_cross_dock_order_processing
--    PURPOSE:
--          This package is used for processing orders of Cross Dock Type
--    REVISIONS:
--    Ver        Date        Author           Description
--    ---------  ----------  ---------------  ------------------------------------
--    1.0        5/13/2014   Infosys          1. Initial version.
--------------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------

--
-- This cursor selects the items on a specified cross dock pallet.
-- Two procedures use this cursor.
--
-- 08/22/19 Brian Bent CMU project
-- Made it private and modified so the two procedures can use it.
-- Some of the columms added:
--    od.seq
--    cddc.cmu_ind
--    cddc.order_seq
--    od.master_order_id
--    od.remote_local_flg
--    od.remote_qty
--    od.rdc_po_no
--    DECODE(od.remote_local_flg, 'B', 'Y', 'R', 'Y', 'N') upd_ordd_to_match_cd_plt_flag
--    DECODE(od.remote_local_flg, 'B', cddc.order_seq, 'R', cddc.order_seq, od.seq) order_seq_for_float_detail_rec
--
-- 10/08/19 Brian Bent CMU project
-- Same parent, LP, item and order selected twice.  Added additional criteria.
--
CURSOR c_cd_items_on_pallet
                 (cp_route_no           IN   route.route_no%TYPE,
                  cp_order_id           IN   ordd.order_id%TYPE,
                  cp_parent_pallet_id   IN   cross_dock_pallet_xref.parent_pallet_id%TYPE)
IS
SELECT od.stop_no,
       od.ROWID,
       ----- (od.qty_ordered - NVL (od.qty_alloc, 0)) qty_on_pallet,              -- 07/16/19 Brian Bent Change for meat opco.  Was this.
       LEAST((od.qty_ordered - NVL (od.qty_alloc, 0)), cddc.qty) qty_on_pallet,   -- 07/16/19 Brian Bent Change for meat opco.  Now this.
       od.prod_id,
       od.cust_pref_vendor,
       od.order_id,
       od.order_line_id,
       od.uom,
       od.seq,
       od.sys_order_id,
       od.qty_ordered,
       od.qty_alloc,
       od.status,
       cddc.cmu_ind,
       cddc.order_seq,
       cddc.parent_pallet_id,
       cddc.pallet_id,
       od.master_order_id,
       od.remote_local_flg,
       od.remote_qty,
       od.rdc_po_no,
       DECODE(od.remote_local_flg, 'B', 'Y', 'R', 'Y', 'N') upd_ordd_to_match_cd_plt_flag,
       DECODE(od.remote_local_flg, 'B', cddc.order_seq, 'R', cddc.order_seq, od.seq) order_seq_for_float_detail_rec
  FROM cross_dock_data_collect cddc,
       ordd od,
       ordm om,                             -- 08/20/19 Brian Bent  Added to get the cross dock type so we can
                                            -- exclude the same item on a regular order.
       pm p,
       cross_dock_pallet_xref x,            -- 09/17/19 Added
       cross_dock_xref x2                   -- 10/08/19 Added
 WHERE od.route_no                 = cp_route_no
   --
   AND x2.sys_order_id             = od.sys_order_id    -- 10/08/19 Added
   AND x2.erm_id                   = cddc.erm_id        -- 10/08/19 Added
   --
   AND od.rdc_po_no                = cddc.sys_order_id  -- 10/08/19 Added  At this time cddc.sys_order_id is the RDC PO#.
                                                        --  NOTE: Things will break if in the future cddc.sys_order_id gets to the  sys orrder id
   --
   AND om.order_id                 = NVL(cp_order_id, om.order_id)  -- This cursor is called by two different procedures where one procedure passes in null for cp_order_id
   AND od.order_id                 = om.order_id
   AND cddc.parent_pallet_id       = cp_parent_pallet_id
   AND od.prod_id                  = cddc.prod_id
   AND od.prod_id                  = p.prod_id
   AND od.cust_pref_vendor         = p.cust_pref_vendor
   AND p.prod_id                   = od.prod_id
   AND p.cust_pref_vendor          = od.cust_pref_vendor
   AND p.status                    = 'AVL'
   --
   AND cddc.parent_pallet_id       = x.parent_pallet_id     -- 09/17/19 Added
   AND x.sys_order_id              = od.sys_order_id        -- 09/17/19 Added
   AND x.erm_id                    = cddc.erm_id            -- 10/08/19 Added
   --
   AND NVL(od.qa_ticket_ind, 'N')  != 'Y'
   AND cddc.rec_type               = 'D'
   AND om.cross_dock_type          NOT IN ('S', 'X')
   AND (   om.cross_dock_type <> 'MU'
        OR (    om.cross_dock_type     = 'MU'
            AND od.remote_local_flg    IN ('B', 'R'))      -- Fail safe so we select only CMU cross dock details
       )
   AND cddc.parent_pallet_id in
              (select x.parent_pallet_id
                 from cross_dock_pallet_xref x, ordd
                WHERE x.sys_order_id = ordd.sys_order_id
                 AND ordd.route_no = cp_route_no);
              


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------
gl_pkg_name           VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.  Used in log messages.


gl_e_parameter_null   EXCEPTION; -- A required parameter to a procedure or function is null.


--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function   VARCHAR2 (30) := 'ORDER GENERATION';

---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Procedure:
--    insert_rvp_transaction (private)
--
-- Description:
--    This procedure inserts the RVP recovery transaction.
--    This is the recover pick transaction created when a route is recovered.
--
--    The info to create the transacton is taken from FLOAS and FLOAT_DETAIL.
--
--    03/18/20 Brian Bent  The procedure should probably be in an "order recovery"
--    package.  Currenly this procedure is only used for a cross dock pallet.
--
-- Parameters:
--    i_float_no  - The floata being recovered.
--    i_seq_no    - The sequence number of the float detail being recovered.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    None. Error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    03/16/20 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE insert_rvp_transaction (i_float_no  IN  floats.float_no%TYPE,
                                  i_seq_no    IN  float_detail.seq_no%TYPE)
IS
   l_object_name   VARCHAR2(30)   := 'insert_rvp_transaction';
   l_message       VARCHAR2(512);  -- Work area
BEGIN
return; ---------------------------------------------------
   --
   -- Create recovery transaction RVP.
   --
   INSERT INTO trans
          (trans_id,
           trans_type,
           trans_date,
           user_id,
           route_no,
           pallet_id,
           parent_pallet_id,
           prod_id,
           cust_pref_vendor,
           dest_loc,
           qty)
   SELECT
           trans_id_seq.NEXTVAL,
           'RVP',
           SYSDATE,
           USER,
           f.route_no,
           NVL(fd.carrier_id, f.pallet_id),
           f.parent_pallet_id,
           fd.prod_id,
           fd.cust_pref_vendor,
           fd.src_loc,
           fd.qty_alloc
     FROM floats f,
          float_detail fd
    WHERE f.float_no = fd.float_no
      AND f.float_no = i_float_no
      AND fd.seq_no  = i_seq_no;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Some oracle error occurred.  Log it but don't raise an error.
      -- Having the RVP transaction fail is not a fatal.
      --
      l_message := '(i_float_no,i_seq_no)'
         || '  i_float_no['  || TO_CHAR(i_float_no)  || ']'
         || '  i_seq_no['    || TO_CHAR(i_seq_no)    || ']'
         || '  Failed to create the RVP transaction.  This is not a fatal error.  Processing will continue.';

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
END insert_rvp_transaction;

---------------------------------------------------------------------------
-- Procedure:
--    ins_ordd_using_existing_rec (private)
--
-- Description:
--    This procedure creates an ORDD record for the OpCo pick when the
--    ORDD.REMOTE_LOCAL_FLAG is 'B.' and the qty ordered is greater than the remote qty.
--    A new ORDD record is created for the qty to be filled from the OpCo.
--    (We have seen in testing SUS setting the remote local flag to 'B' even though the
--     qty ordered is equal the remote qty in which case we do not create another ORDD record
--     since nothing is being picked from the OpCo).
--
--
--    NOTE:  The update is reversed and the ORDD record deleted if the route is recovered.
--
--   Example:
--    ORDD record initially:
--                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
--    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
--    --------------------------------------------------------------------------------------------------------------------------
--    1234567   908200001     1        10       84320000   1234568888888     B           6
--
--    ORDD after the new ORDD record is created:
--                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
--    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
--    --------------------------------------------------------------------------------------------------------------------------
--    1234567   908200001     1        6        10000001   1234568888888     B           6           10
--    1234567   908200001     2        4        84320000                                                              1
--
--
--    
--
-- Parameters:
--    i_order_id       - Order id to create the new record from.
--    i_order_line_id  - Order id to create the new record from. 
--    i_qty_ordered    - Qty ordered for the new record.
--
-- Called by:
--    preprocess_cmu_order
--
-- Exceptions raised:
--    pl_exc.ct_data_error     - Did not insert one record into ORDD.
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/19 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE ins_ordd_using_existing_rec
                  (i_order_id         IN  ordd.order_id%TYPE,
                   i_order_line_id    IN  ordd.order_line_id%TYPE,
                   i_qty_ordered      IN  PLS_INTEGER)
IS
   l_object_name   VARCHAR2(30)      := 'ins_ordd_using_existing_rec';

   l_parameters           VARCHAR2(128);  -- Parameter list.  Used in log messages.
   l_order_line_id        PLS_INTEGER;    -- New order line id for the record.
   l_num_recs_inserted    PLS_INTEGER;    -- Number of records insert.  Should always be 1.
BEGIN
return; ---------------------------------------------------
   l_parameters := '(i_order_id[' || i_order_id || '],i_order_line_id[' || TO_CHAR(i_order_line_id) || ']i_qty_ordered['
                   || TO_CHAR(i_qty_ordered) || '])';
   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                     || '  ' ||  l_parameters
                     || '  This procedure inserts a new ORDD record for the OpCo pick when the remote_local_flg is ''B'''
                     || ' and the qty ordered is > the remote qty.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- First get the next order line id.
   --
   SELECT NVL(MAX(order_line_id), 0) + 1
     INTO l_order_line_id
     FROM ordd 
    WHERE ordd.order_id = i_order_id;

   --
   -- Insert the ORDD record.
   --
   INSERT INTO ordd
         (
          order_id,
          order_line_id,
          prod_id,
          cust_pref_vendor,
          status,
          qty_ordered,
          qty_alloc,
          uom,
          partial,
          seq,
          area,
          route_no,
          stop_no,
          zone_id,
          sys_order_id,
          sys_order_line_id,
          qa_ticket_ind,
          pcl_flag,
          cw_type,
          master_order_id,
          remote_local_flg,
          remote_qty,
          rdc_po_no,
          original_order_line_id
         )
   SELECT
          order_id                      order_id,
          l_order_line_id               order_line_id,
          prod_id                       prod_id,
          cust_pref_vendor              cust_pref_vendor,
          'NEW'                         status,
          i_qty_ordered                 qty_ordered,
          0                             qty_alloc,
          uom                           uom,
          partial                       partial,
          ordd_seq.NEXTVAL              seq,
          area                          area,
          route_no                      route_no,
          stop_no                       stop_no,
          zone_id                       zone_id,
          sys_order_id                  sys_order_id,
          sys_order_line_id             sys_order_line_id,
          qa_ticket_ind                 qa_ticket_ind,
          pcl_flag                      pcl_flag,
          cw_type                       cw_type,
          NULL                          master_order_id,        -- We want this null
          NULL                          remote_local_flg,       -- We want this null
          NULL                          remote_qty,             -- We want this null
          NULL                          rdc_po_no,              -- We want this null
          order_line_id                 original_order_line_id  -- The original order line ID needs to be save so data sent back to SUS (PAW, etc)
                                                                -- can use this value.  SUS does not know about the new order line id.
     FROM ordd
    WHERE ordd.order_id      = i_order_id
      AND ordd.order_line_id = i_order_line_id;

   l_num_recs_inserted := SQL%ROWCOUNT;

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                      'TABLE=ordd'
                   || '  KEY=[' || i_order_id || ',' || TO_CHAR(i_order_line_id) || ']'
                   || '(i_order_id,i_order_line_id)'
                   || '  ACTION=INSERT'
                   || '  MESSAGE="After insert."'
                   || '  SQL%ROWCOUNT: ' || TO_CHAR(l_num_recs_inserted),
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   IF (NVL(l_num_recs_inserted, 0) <> 1) THEN
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_parameters
                    ||  'Failed to insert the record into ORDD.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name || ': One record not inserted into ORDD.');
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_parameters
                         || '  Error',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END ins_ordd_using_existing_rec;


---------------------------------------------------------------------------
-- Procedure:
--    preprocess_cmu_order (private)
--
-- Description:
--    This procedure:
--       - Update ORDD.SEQ to the RDC ORDD SEQ.  We need to do this because the
--         pick label barcode applied when picking the RDC is the RDC ORDD SEQ.
--         If this is not done then the driver cannot scan the barcode with STS.
--       - Creates an ORDD record for the OpCo pick when the ORDD.REMOTE_LOCAL_FLAG is 'B'
--         and the qty ordered is > the remote qty.
--         (We have seen in testing SUS setting the remote local flag to 'B' even though the
--          qty ordered is equal the remote qty in which case we do not create another ORDD record
--          since nothing is being picked from the OpCo).
--         A new ORDD record is created for the qty to be filled from the OpCo.
--
--    Example creating a new ORDD record when the ORDD.REMOTE_LOCAL_FLAG is 'B':
--    ORDD record initially:
--                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
--    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
--    --------------------------------------------------------------------------------------------------------------------------
--    1234567   908200001     1        10       84320000   1234568888888     B           6
--
--    ORDD after the new ORDD record is created:
--                          ORDER_    QTY_                 MASTER_        REMOTE_       REMOTE_   QTY_ORDERED_   ORIGINAL_
--    PROD_ID   ORDER_ID    LINE_ID   ORDERED   SEQ        ORDER_ID       LOCAL_FLG     QTY       ORIGINAL       ORDER_LINE_ID
--    --------------------------------------------------------------------------------------------------------------------------
--    1234567   908200001     1        6        10000001   1234568888888     B           6           10
--    1234567   908200001     2        4        84320000                                                              1
--
-- Parameters:
--    i_route_no          - The route that has the cross dock pallet.
--    i_parent_pallet_id  - The cross dock parent pallet
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    pl_exc.ct_database_error - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/19 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE preprocess_cmu_order
                    (i_route_no          IN route.route_no%TYPE,
                     i_parent_pallet_id  IN inv.parent_pallet_id%TYPE)
IS
   l_object_name   VARCHAR2(30)      := 'preprocess_cmu_order';
   l_message       VARCHAR2(1024);         -- Work area.

   l_parameters                   VARCHAR2(128);  -- Parameter list.  Used in log messages.
   l_tmp_qty_ordered_original     PLS_INTEGER;    -- Work area
   l_tmp_qty_ordered              PLS_INTEGER;    -- Work area
BEGIN
return; ---------------------------------------------------
   l_parameters := '(i_route_no[' || i_route_no || '],i_parent_pallet_id[' || i_parent_pallet_id || '])';

   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                     || '  ' ||  l_parameters
                     || ' This procedure: (1) Updates the ORDD.SEQ to the RDC ORDD SEQ.  We need to do this because the'
                     || ' barcode on the pick label applied when picked at the RDC is the RDC ORDD SEQ.'
                     || '  (2) Creates an ORDD record for the OpCo pick when the'
                     || ' ORDD.REMOTE_LOCAL_FLAG is ''B'' and the qty ordered is > the remote qty.'
                     || '  A new ORDD record is created for the qty to be filled from the OpCo.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');


   FOR r_cd_items_on_pallet IN c_cd_items_on_pallet(i_route_no, NULL, i_parent_pallet_id)
   LOOP
      dbms_output.put_line('============================================================================');

      l_message :=      'Item:'                     || r_cd_items_on_pallet.prod_id
                     || '  ordd.status:'            || r_cd_items_on_pallet.status
                     || '  ordd.seq:'               || TO_CHAR(r_cd_items_on_pallet.seq)
                     || '  ordd.order_id:'          || r_cd_items_on_pallet.order_id
                     || '  ordd.order_line_id:'     || TO_CHAR(r_cd_items_on_pallet.order_line_id)
                     || '  cddc order_seq:'         || TO_CHAR(r_cd_items_on_pallet.order_seq)
                     || '  master_order_id:'        || r_cd_items_on_pallet.master_order_id
                     || '  remote_local_flg:'       || r_cd_items_on_pallet.remote_local_flg
                     || '  remote_qty:'             || TO_CHAR(r_cd_items_on_pallet.remote_qty)
                     || '  qty_ordered:'            || TO_CHAR(r_cd_items_on_pallet.qty_ordered)
                     || '  qty_alloc:'              || TO_CHAR(r_cd_items_on_pallet.qty_alloc);

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      --
      -- Create an ORDD record for the OpCo pick when the ORDD.REMOTE_LOCAL_FLAG is 'B'
      -- and the qty ordered is > the remove qty.
      -- (We have seen in testing SUS setting the remote local flag to 'B' even though the
      -- qty ordered is equal the remote qty in which case we do not create another ORDD record
      -- since nothing is being picked from the OpCo).
      --
      IF (    r_cd_items_on_pallet.remote_local_flg = 'B'
          AND r_cd_items_on_pallet.qty_ordered > r_cd_items_on_pallet.remote_qty) THEN
         --
         -- Create a ORDD record for the OpCo pick.
         -- Update the current CMU ORDD record qty ordered to match the remote qty.
         --
         pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'CMU order had qty for the RDC and a qty from the OpCo.'
                       || '  Create a ORDD record for the OpCo pick.'
                       || ' Update the current CMU ORDD record qty ordered to match the remote qty.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

         --
         -- Create a ORDD record for the OpCo pick.
         --
         ins_ordd_using_existing_rec
                  (i_order_id         => r_cd_items_on_pallet.order_id,
                   i_order_line_id    => r_cd_items_on_pallet.order_line_id,
                   i_qty_ordered      => r_cd_items_on_pallet.qty_ordered - r_cd_items_on_pallet.remote_qty);

         --
         -- Update the current CMU ORDD record qty ordered to match the remote qty.
         --
         UPDATE ordd
            SET qty_ordered_original = qty_ordered,
                qty_ordered          = remote_qty
          WHERE order_id      = r_cd_items_on_pallet.order_id
            AND order_line_id = r_cd_items_on_pallet.order_line_id
         RETURNING qty_ordered_original, qty_ordered INTO l_tmp_qty_ordered_original, l_tmp_qty_ordered;

         pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                      'TABLE=ordd'
                   || '  KEY=[' || r_cd_items_on_pallet.order_id || ',' || r_cd_items_on_pallet.order_line_id || ']'
                   || '(order_id,order_line_id)'
                   || '  ACTION=UPDATE'
                   || '  MESSAGE="Updated the qty_ordered_original to ' || TO_CHAR(l_tmp_qty_ordered_original)
                   || ' and qty_ordered to ' || TO_CHAR(l_tmp_qty_ordered)
                   || '  SQL%ROWCOUNT: ' || SQL%ROWCOUNT,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
      END IF;

      --
      -- The CMU ORDD.SEQ needs to be what the RDC used since this is what is barcoded
      -- on the pick label applied at the RDC.
      --
      UPDATE ordd
         SET seq = r_cd_items_on_pallet.order_seq_for_float_detail_rec
       WHERE order_id      = r_cd_items_on_pallet.order_id
         AND order_line_id = r_cd_items_on_pallet.order_line_id
         AND sys_order_id  = r_cd_items_on_pallet.sys_order_id;

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         =>
                      'TABLE=ordd'
                   || '  KEY=[' || r_cd_items_on_pallet.order_id || ',' || r_cd_items_on_pallet.order_line_id || ',' || r_cd_items_on_pallet.sys_order_id || ']'
                   || '(order_id,order_line_id,sys_order_id)'
                   || ' ACTION=UPDATE'
                   || '  MESSAGE="Update ORDD.SEQ to the RDC seq of[' || TO_CHAR(r_cd_items_on_pallet.order_seq_for_float_detail_rec) || ']'
                   || ' as this is what is barcoded on the pick label applied at the RDC.'
                   || '  SQL%ROWCOUNT[' || SQL%ROWCOUNT || ']',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => 'YM',
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Got some oracle error.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_parameters
                         || '  Error',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END preprocess_cmu_order;


---------------------------------------------------------------------------
-- Procedure:
--    create_floats_multisku_bulk
--
-- Description:
--
-- Parameters:
--
-- Called By:
--    
--
-- Exceptions Raised:
--    
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/18/19 bben0556 Brian Bent
--                      Changed how the cross dock pallets on a route
--                      are selected.
---------------------------------------------------------------------------
   PROCEDURE create_floats_multisku_bulk (i_route_no IN route.route_no%TYPE)
   IS
      l_object_name   VARCHAR2 (30 CHAR)        := 'create_floats_multisku_bulk';
      l_float_no      floats.float_no%TYPE;
      l_stop_no       ordd.stop_no%TYPE;
      l_seq_no        float_detail.seq_no%TYPE  := 1;
      l_floats_flag   BOOLEAN                   := FALSE;

      --
      -- This cursor gets all the orders on the route that have a cross dock pallet.
      --
      -- Note that that an order for a CMU customer can have cross dock pallets and
      -- regular picks from the OpCo.
      --
      CURSOR c_cd_orders_on_route (cp_route_no IN route.route_no%TYPE)
      IS
         SELECT order_id
           FROM ordm m,
                cross_dock_type cdt
          WHERE route_no          = cp_route_no
            AND m.cross_dock_type = cdt.cross_dock_type
            AND m.cross_dock_type NOT IN ('S', 'X');

      --
      -- This cursor gets all the cross dock parent pallet details for this route.
      --
      CURSOR c_cd_pallets 
                   (cp_route_no   IN   route.route_no%TYPE,
                    cp_order_id   IN   ordd.order_id%TYPE)
      IS
         SELECT parent_pallet_id,
                MIN(ordd.stop_no) stop_no    -- MIN as a failsafe though the pallet should be only for one stop
           FROM cross_dock_pallet_xref x, ordd
          WHERE x.sys_order_id = ordd.sys_order_id
            AND ordd.route_no  = cp_route_no
            AND float_no       IS NULL      -- If it has not already been processed.
          GROUP BY parent_pallet_id
          ORDER BY parent_pallet_id;

/***** xxxxxxxx old
      CURSOR c_cd_pallets 
                   (cp_route_no   IN   route.route_no%TYPE,
                    cp_order_id   IN   ordd.order_id%TYPE)
      IS
         SELECT DISTINCT parent_pallet_id
           FROM cross_dock_pallet_xref
          WHERE sys_order_id IN
                         (SELECT DISTINCT sys_order_id
                            FROM ordd
                           WHERE order_id = cp_order_id
                             AND route_no = cp_route_no)
            AND float_no IS NULL;      -- If it has not already been processed.
******/

   BEGIN
return; ---------------------------------------------------
      --
      -- Debug message.
      --
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                      'BEGIN OF BULK PULL GENERATION FOR CROSS DOCK PALLETS--Create float and float_detail records',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );


/***** xxxxxxxxx
      FOR r_cd_order_on_route IN c_cd_orders_on_route (i_route_no)
      LOOP
**********/
         --
         -- Processs the cross dock pallets.
         --
         -----FOR r_cd_pallet IN c_cd_pallets (i_route_no, r_cd_order_on_route.order_id)
         FOR r_cd_pallet IN c_cd_pallets (i_route_no, null)
         LOOP
            --
            -- Debug message
            --
            pl_log.ins_msg (pl_lmc.ct_info_msg,
                            l_object_name,
                               'CREATING FLOATS FOR PARENT_PALLET_ID'
                            || '[' || r_cd_pallet.parent_pallet_id || ']',
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name
                           );

            --
            -- Before processing the cross dock pallet do the following:
            --    - Update ORDD.SEQ to the RDC ORDD SEQ.
            --    - A CMU order with qty from the RDC and qty from the OpCo
            --      will need to be split into 2 ORDD records.
            -- Procedure "preprocess_cmu_order" does the work.
            --
            preprocess_cmu_order(i_route_no          => i_route_no,
                                 i_parent_pallet_id  => r_cd_pallet.parent_pallet_id);

            BEGIN
               BEGIN
                  --
                  -- Get the next float sequence number.
                  --

                  --
                  -- If the everything works fine as expected, then for a parent pallet we should have only 1 float_no.
                  --
                  SELECT DISTINCT float_no
                             INTO l_float_no
                             FROM cross_dock_pallet_xref
                            WHERE parent_pallet_id = r_cd_pallet.parent_pallet_id
                              AND float_no         IS NOT NULL;

                  --
                  --  Float has been already created for this parent pallet, avoid recreating floats for the same parent pallet id.
                  --
                  l_floats_flag := TRUE;

                  --
                  -- Debug message
                  --
                  pl_log.ins_msg (pl_lmc.ct_info_msg,
                                  l_object_name,
                                     'RETRIEVED THE EXISTING FLOAT NUMBER['
                                  || l_float_no || '] FOR PARENT PALLET ID['
                                  || r_cd_pallet.parent_pallet_id || ']',
                                  NULL,
                                  NULL,
                                  ct_application_function,
                                  gl_pkg_name
                                 );
               EXCEPTION
                  WHEN TOO_MANY_ROWS
                  THEN
                     --
                     -- Log the error message and raise application error.
                     --
                     pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                                     l_object_name,
                                     'SAME PARENT PALLET ID[' || r_cd_pallet.parent_pallet_id || ']'
                                     || '  HAS MULTIPLE FLOAT NO',
                                     NULL,
                                     NULL,
                                     ct_application_function,
                                     gl_pkg_name
                                    );
                     RAISE_APPLICATION_ERROR (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
                  WHEN OTHERS
                  THEN
                     --
                     -- This exception is more of a valid handle rather than an exception
                     -- we are controlling to see if we are using same float number or not for an existing pallet
                     -- No float number is associated with the current parent pallet id, retrieve a new one
                     --
                     l_float_no := float_no_seq.NEXTVAL;

                     --
                     -- Float has not been created for this parent pallet, create one.
                     --
                     l_floats_flag := FALSE;

                     --
                     -- Debug message
                     --
                     pl_log.ins_msg (pl_lmc.ct_info_msg,
                                     l_object_name,
                                        'GOT THE NEXT FLOAT NUMBER[' || l_float_no || ']'
                                     || '   FOR PARENT PALLET ID['
                                     || r_cd_pallet.parent_pallet_id
                                     || ']',
                                     NULL,
                                     NULL,
                                     ct_application_function,
                                     gl_pkg_name
                                    );
               END;

               --
               -- If floats has not been created, then create float for the parent pallet id that is being processed.
               --
               IF NOT l_floats_flag
               THEN
                  --
                  -- Insert the float data in floats table.
                  --
                  INSERT INTO floats
                              (batch_no,
                               batch_seq,
                               float_no,
                               route_no,
                               b_stop_no,
                               e_stop_no,
                               float_cube, 
                               split_ind,
                               pallet_pull,
                               status,
                               merge_loc,
                               parent_pallet_id)
                     SELECT 0                             batch_no,
                            0                             batch_seq,
                            l_float_no                    float_no,
                            i_route_no                    route_no,
                            r_cd_pallet.stop_no           b_stop_no,
                            r_cd_pallet.stop_no           e_stop_no,
                            0                             float_cube,
                            'N'                           split_ind,
                            'B'                           pallet_pull,
                            'NEW'                         status,
                            '???'                         merge_loc,
                            r_cd_pallet.parent_pallet_id  parent_pallet_id
                       FROM DUAL
                      WHERE NOT EXISTS
                                 (SELECT 1
                                    FROM cross_dock_pallet_xref xref
                                   WHERE xref.parent_pallet_id = r_cd_pallet.parent_pallet_id
                                     AND xref.float_no IS NOT NULL);
               ELSE
                  --
                  -- Get the last used sequence number to continue with float details creation.
                  --
                  SELECT MAX (seq_no) + 1
                    INTO l_seq_no
                    FROM float_detail
                   WHERE float_no = l_float_no;
               END IF;

               --
               -- Insert the float details data in float_detail table.
               --
               --
/***** xxxxx
               FOR r_cd_items_on_pallet IN c_cd_items_on_pallet(i_route_no,
                                                                r_cd_order_on_route.order_id,
                                                                r_cd_pallet.parent_pallet_id)
****/
               FOR r_cd_items_on_pallet IN c_cd_items_on_pallet(i_route_no,
                                                                null,
                                                                r_cd_pallet.parent_pallet_id)
               LOOP
                  --
                  -- Debug message.
                  --
                  pl_log.ins_msg
                         (pl_lmc.ct_info_msg,
                          l_object_name,
                          'CREATING FLOATS DETAILS FOR PARENT_PALLET_ID['
                            || r_cd_pallet.parent_pallet_id || ']'
                            || '  LP['                      || r_cd_items_on_pallet.pallet_id           || ']'
                            || '  Item['                    || r_cd_items_on_pallet.prod_id             || ']'
                            || '  CPV['                     || r_cd_items_on_pallet.cust_pref_vendor    || ']'
                            || '  ordd.seq['                || TO_CHAR(r_cd_items_on_pallet.seq)        || ']'
                            || '  cddc.order_seq['          || TO_CHAR(r_cd_items_on_pallet.order_seq)  || ']'
                            || '  cddc.cmu_ind['            || r_cd_items_on_pallet.cmu_ind             || ']'
                            || '  master_order_id['         || r_cd_items_on_pallet.master_order_id     || ']'
                            || '  remote_local_flg['        || r_cd_items_on_pallet.remote_local_flg    || ']'
                            || '  r_cd_pallet.remote_qty['  || r_cd_items_on_pallet.remote_qty          || ']'
                            || '  r_cd_pallet.rdc_po_no['   || r_cd_items_on_pallet.rdc_po_no           || ']',
                          NULL,
                          NULL,
                          ct_application_function,
                          gl_pkg_name
                         );

                  BEGIN
                     --
                     -- Create float detail records for all the items in the parent pallet.
                     --
                     -- CMU change
                     -- For the FLOAT_DETAIL.ORDER_SEQ use the cross dock data collect order_seq if it has a value
                     -- otherwise use the ORDD.SEQ.  For cross dock pallets picked at the RDC we need to retain
                     -- the order seq from the RDC since that is what is on the pick labels.
                     --
                     INSERT INTO float_detail
                                 (
                                  float_no,
                                  ZONE,
                                  stop_no,
                                  prod_id,
                                  cust_pref_vendor,
                                  qty_order,
                                  qty_alloc,
                                  seq_no,
                                  status,
                                  order_id,
                                  order_line_id, 
                                  cube,
                                  merge_alloc_flag,
                                  route_no,
                                  uom,
                                  order_seq,                                 -- 07/16/19 Brian Bent Added
                                  carrier_id                                 -- 07/16/19 Brian Bent Added
                                 )
                          SELECT
                                  l_float_no                                            float_no,
                                  0                                                     zone,
                                  r_cd_items_on_pallet.stop_no                          stop_no,
                                  r_cd_items_on_pallet.prod_id                          prod_id,
                                  r_cd_items_on_pallet.cust_pref_vendor                 cust_pref_vendor,
                                  r_cd_items_on_pallet.qty_on_pallet                    qty_order,
                                  0                                                     qty_alloc,
                                  l_seq_no                                              seq_no,
                                  'NEW'                                                 status,
                                  r_cd_items_on_pallet.order_id                         order_id,
                                  r_cd_items_on_pallet.order_line_id                    order_line_id,
                                  0                                                     cube,
                                  'X'                                                   merge_alloc_flag,
                                  i_route_no                                            route_no,
                                  r_cd_items_on_pallet.uom                              uom,
                                  r_cd_items_on_pallet.order_seq_for_float_detail_rec   order_seq,
                                  r_cd_items_on_pallet.pallet_id                        carrier_id
                            FROM DUAL;

                     --
                     -- Increment the sequence number to be used by the next item.
                     --
                     l_seq_no := l_seq_no + 1;

                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        --
                        -- Log the error message and raise application error.
                        --
                        pl_log.ins_msg
                           (pl_lmc.ct_fatal_msg,
                            l_object_name,
                               'ERROR OCCURRED WHILE CREATING FLOAT DETAILS FOR PARENT_PALLET_ID['
                            || r_cd_pallet.parent_pallet_id
                            || '] AND PROD_ID ['
                            || r_cd_items_on_pallet.prod_id
                            || ']'
                            || SQLERRM,
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name
                           );

                        RAISE_APPLICATION_ERROR (pl_exc.ct_data_error,
                                                    gl_pkg_name
                                                 || '.'
                                                 || l_object_name
                                                 || ': '
                                                 || SQLERRM
                                                );
                  END;

                  --
                  -- Debug messages.
                  --
                  pl_log.ins_msg
                     (pl_lmc.ct_info_msg,
                      l_object_name,
                         'FLOATS DETAILS CREATED SUCCESSFULLY FOR PARENT_PALLET_ID['
                      || r_cd_pallet.parent_pallet_id
                      || '] AND PROD_ID['
                      || r_cd_items_on_pallet.prod_id
                      || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );
               END LOOP;

               --
               -- Reset the sequence number and flags to be used for next iteration.
               --
               l_seq_no := 1;
               l_floats_flag := FALSE;

               --
               -- Update the cross dock reference for the parent pallet id.
               --
               UPDATE cross_dock_pallet_xref
                  SET float_no = l_float_no,
                      upd_user = USER,
                      upd_date = SYSDATE
                WHERE parent_pallet_id = r_cd_pallet.parent_pallet_id;
/**** xxxxx old
               UPDATE cross_dock_pallet_xref
                  SET float_no = l_float_no,
                      upd_user = USER,
                      upd_date = SYSDATE
                WHERE parent_pallet_id = r_cd_pallet.parent_pallet_id
                  AND sys_order_id IN
                                (SELECT DISTINCT sys_order_id
                                            FROM ordd
                                           WHERE order_id = r_cd_order_on_route.order_id);
****/
            EXCEPTION
               WHEN OTHERS
               THEN
                  --
                  -- Log the error message and raise application error.
                  --
                  pl_log.ins_msg
                     (pl_lmc.ct_fatal_msg,
                      l_object_name,
                         'ERROR OCCURRED WHILE CREATING FLOATS FOR PARENT_PALLET_ID['
                      || r_cd_pallet.parent_pallet_id
                      || ']'
                      || SQLERRM,
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );

                  RAISE_APPLICATION_ERROR (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM
                                          );
            END;

            --
            -- Debug message.
            --
            pl_log.ins_msg
               (pl_lmc.ct_info_msg,
                l_object_name,
                   'FLOATS CREATED AND CDK PALLET REFERENCE UPDATED FOR PARENT_PALLET_ID['
                || r_cd_pallet.parent_pallet_id
                || ']',
                NULL,
                NULL,
                ct_application_function,
                gl_pkg_name
               );
         END LOOP;
/***** xxxxx
      END LOOP;   -- orders on route loop
*******/

      --
      -- Debug message.
      --
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                      'END OF BULK PULL GENERATION FOR CROSS DOCK PALLETS',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );
   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Log the error message and raise application error.
         --
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         SQLERRM,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 );
   END create_floats_multisku_bulk;


---------------------------------------------------------------------------
-- Procedure:
--    update_ordm_cdk_for_btp_inv
--
-- Description:
--
--
-- Parameters:
---------------------------------------------------------------------------
   PROCEDURE update_ordm_cdk_for_btp_inv(
      i_route_no IN route.route_no%TYPE)
   IS
      l_object_name VARCHAR2(40 CHAR) := 'update_ordm_cdk_for_btp_inv';
   BEGIN
return; ---------------------------------------------------
      -- Update the ordm.cross_dock_type to BP if there is build to pallet inventory 
      -- for on this route only if this is a finish good company.
      IF pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N') = 'Y' THEN 
         pl_log.ins_msg(
            pl_lmc.ct_info_msg, l_object_name,
            'Updating ordm.cross_dock_type to BP if there is inventory for the specific order_id', 
            NULL, NULL, ct_application_function, gl_pkg_name);

         UPDATE ordm
         SET cross_dock_type = 'BP'
         WHERE order_id IN 
         (
            SELECT distinct m.order_id
            FROM ordm m, inv i, lzone lz, zone z
            WHERE m.route_no = i_route_no
            AND i.inv_order_id = m.order_id
            AND i.parent_pallet_id IS NOT NULL
            AND i.plogi_loc = lz.logi_loc
            AND z.zone_id = lz.zone_id
            AND z.zone_type = 'PUT'
            AND z.rule_id = '9'
         );
      END IF;
   
   END update_ordm_cdk_for_btp_inv;


---------------------------------------------------------------------------
-- Procedure:
--    create_lm_multisku_bulk_batch
--
-- Description:
--
--
-- Parameters:
---------------------------------------------------------------------------
   PROCEDURE create_lm_multisku_bulk_batch (i_route_no IN route.route_no%TYPE)
   IS
      l_object_name        VARCHAR2 (40 CHAR)
                                           := 'CREATE_LM_MULTISKU_BULK_BATCH';
      l_door_no            door.door_no%TYPE;
      l_route_door_no      NUMBER                         := 0;
      l_dummy              NUMBER                         := 0;
      l_total_cube         NUMBER                         := 0;
      l_total_weight       NUMBER                         := 0;
      l_src_loc            float_detail.src_loc%TYPE;
      l_parent_pallet_id   floats.parent_pallet_id%TYPE;
      l_batch_no           batch.batch_no%TYPE;
      l_job_code           job_code.jbcd_job_code%TYPE;

      CURSOR c_cd_floats_for_bulk_pull (l_route_no IN route.route_no%TYPE)
      IS
         SELECT DISTINCT float_no
                    FROM cross_dock_pallet_xref x, ordd od, ordm om, route r
                   WHERE x.sys_order_id = od.sys_order_id
                     AND od.order_id = om.order_id
                     AND r.route_no = l_route_no
                     AND om.route_no = r.route_no
                     AND x.batch_no IS NULL;
   BEGIN
return; ---------------------------------------------------
      FOR r_cd_floats_for_bulk_pull IN c_cd_floats_for_bulk_pull (i_route_no)
      LOOP

	 l_door_no := pl_lmc.f_get_destination_door_no(r_cd_floats_for_bulk_pull.float_no);

         pl_log.ins_msg (pl_lmc.ct_info_msg,
                         l_object_name,
                         'Door Number for Bulk Batch [' || l_door_no || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );

         BEGIN
            /* fetching total cube and weight of the float*/
            SELECT SUM ((fd.qty_alloc / p.spc) * p.case_cube),
                   SUM (fd.qty_alloc * NVL (p.g_weight, 0))
              INTO l_total_cube,
                   l_total_weight
              FROM float_detail fd, pm p
             WHERE fd.float_no = r_cd_floats_for_bulk_pull.float_no
               AND p.prod_id = fd.prod_id;

            /* src loc,parent pallet id  should be same for all the items in the float detail for a EI float */
            SELECT DISTINCT fd.src_loc, 'FU' || f.float_no,
                            fk.palpull_jobcode, f.parent_pallet_id
                       INTO l_src_loc, l_batch_no,
                            l_job_code, l_parent_pallet_id
                       FROM job_code j,
                            fk_area_jobcodes fk,
                            swms_sub_areas ssa,
                            aisle_info ai,
                            pm,
                            float_detail fd,
                            route r,
                            floats f
                      WHERE j.jbcd_job_code = fk.palpull_jobcode
                        AND fk.sub_area_code = ssa.sub_area_code
                        AND ssa.sub_area_code = ai.sub_area_code
                        AND ai.NAME = SUBSTR (fd.src_loc, 1, 2)
                        AND pm.prod_id = fd.prod_id
                        AND pm.cust_pref_vendor = fd.cust_pref_vendor
                        AND fd.float_no = f.float_no
                        AND r.route_no = f.route_no
                        AND f.pallet_pull IN ('D', 'B', 'Y')
                        AND f.float_no = r_cd_floats_for_bulk_pull.float_no;

            /* creating  bulk batch */
            INSERT INTO batch
                        (batch_no, jbcd_job_code, status, batch_date,
                         kvi_from_loc, kvi_to_loc, kvi_no_case, kvi_no_split,
                         kvi_no_pallet, kvi_no_item, kvi_no_po, kvi_cube,
                         kvi_wt, kvi_no_loc, total_count, total_piece,
                         total_pallet, ref_no, kvi_distance, goal_time,
                         target_time, no_breaks, no_lunches, kvi_doc_time,
                         kvi_no_piece, kvi_no_data_capture
                        )
                 VALUES (l_batch_no, l_job_code, 'F', TRUNC (SYSDATE),
                         l_src_loc, l_door_no, 0.0, 0.0,
                         1.0, 1.0, 0.0, l_total_cube,
                         l_total_weight, 1.0, 1.0, 0.0,
                         1.0, l_parent_pallet_id, 1.0, 0.0,
                         0.0, 0.0, 0.0, 1.0,
                         0.0, 2.0
                        );

            /* update batch no in cross_dock_pallet_xref */
            UPDATE cross_dock_pallet_xref
               SET batch_no = l_batch_no,
                   upd_user = USER,
                   upd_date = SYSDATE
             WHERE float_no = r_cd_floats_for_bulk_pull.float_no;
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               /* Log the error message and raise application error */
               pl_log.ins_msg
                  (pl_lmc.ct_fatal_msg,
                   l_object_name,
                      'Error occured while fetching float details for Float['
                   || r_cd_floats_for_bulk_pull.float_no
                   || ']',
                   NULL,
                   NULL,
                   ct_application_function,
                   gl_pkg_name
                  );
               raise_application_error (pl_exc.ct_data_error,
                                           gl_pkg_name
                                        || '.'
                                        || l_object_name
                                        || ': '
                                        || SQLERRM
                                       );
            WHEN OTHERS THEN
               /* Log the error message and raise application error */
               pl_log.ins_msg
                   (pl_lmc.ct_fatal_msg,
                    l_object_name,
                       'Error occured while inserting into batch for Float['
                    || r_cd_floats_for_bulk_pull.float_no
                    || '] Parent Pallet['
                    || l_parent_pallet_id
                    || ']',
                    NULL,
                    NULL,
                    ct_application_function,
                    gl_pkg_name
                   );
               raise_application_error (pl_exc.ct_data_error,
                                           gl_pkg_name
                                        || '.'
                                        || l_object_name
                                        || ': '
                                        || SQLERRM
                                       );
         END;
      END LOOP;

      RETURN;
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Log the error message and raise application error */
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         SQLERRM,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 );
   END;


---------------------------------------------------------------------------
-- Procedure:
--    update_multisku_pallet_inv
--
-- Description:
--
-- Parameters:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    03/22/20 bben0556 Brian Bent
--                      Delete the inventory when allocated.  Before the inventory
--                      was deleted when the cross dock pallet was dropped
--                      at the door
---------------------------------------------------------------------------
   PROCEDURE update_multisku_pallet_inv (
      i_route_no    IN   route.route_no%TYPE,
      i_method_id   IN   sel_method.method_id%TYPE
   )
   IS
      l_object_name          VARCHAR2 (30 CHAR) := 'update_multisku_pallet_inv';
      l_message              VARCHAR2 (512 CHAR);

      l_group_no             NUMBER;
      l_zone_id              ZONE.zone_id%TYPE;
      l_upd_qty              NUMBER;
      l_ordd_qty             NUMBER;
      l_equip_id             floats.equip_id%TYPE;
      l_comp_code            floats.comp_code%TYPE;
      l_merge_group_no       floats.merge_group_no%TYPE;
      l_door_area            floats.door_area%TYPE;
      l_qty_short            NUMBER                         := 0;
      dod_seq                NUMBER                         := 0;
      l_qty_order            NUMBER;
      l_total_qty            NUMBER;
      l_door_no              NUMBER                         := 0;
      l_replen_exist         CHAR                           := 'N';

      --
      -- Get all the orders that have cross docks on this route.
      --
      CURSOR c_cd_orders_on_route (cp_route_no IN route.route_no%TYPE)
      IS
      SELECT m.order_id,
             r.route_batch_no,
             r.route_no,
             m.truck_no,
             cdt.cross_dock_type
        FROM ordm m,
             cross_dock_type cdt,
             route r
       WHERE m.route_no        = cp_route_no
         AND r.route_no        = m.route_no
         AND m.cross_dock_type = cdt.cross_dock_type
         AND m.cross_dock_type NOT IN ('S', 'X');

      r_cd_orders_on_route   c_cd_orders_on_route%ROWTYPE;

      --
      -- Get all floats on this order for the cross dock pallets.
      --
      CURSOR c_cd_floats(cp_route_no   IN   route.route_no%TYPE,
                         cp_order_id   IN   ordd.order_id%TYPE)
      IS
      SELECT f.float_no,
             f.route_no,
             d.prod_id,
             d.cust_pref_vendor,
             d.stop_no,
             d.order_id,
             d.order_line_id,
             i.logi_loc,
             i.plogi_loc,
             i.inv_uom,
             i.rec_date,
             i.mfg_date,
             i.exp_date,
             x.parent_pallet_id,
             i.rec_id,
             i.qoh,
             i.lot_id,
             i.temperature,
             p.case_cube,
             l.pik_path,
             p.spc,
             f.door_area,
             p.area,
             ordd.sys_order_id
        FROM float_detail d,
             inv i,
             pm p,
             cross_dock_pallet_xref x,
             loc l,
             floats f,
             ordd
       WHERE d.order_id            = cp_order_id
         AND f.route_no            = cp_route_no
         AND (i.inv_order_id is NULL OR d.order_id = i.inv_order_id)
         AND NVL(d.qty_alloc, 0)   = 0
         AND NVL(i.status, 'AVL')  = 'CDK'
         AND i.parent_pallet_id    = x.parent_pallet_id
         AND x.float_no            = d.float_no
         AND i.prod_id             = d.prod_id
         AND i.cust_pref_vendor    = d.cust_pref_vendor
      -- AND x.erm_id              = i.rec_id                       -- 08/15/2019 Brian Bent Comment out
         AND p.prod_id             = i.prod_id
         AND p.cust_pref_vendor    = i.cust_pref_vendor
         AND f.float_no            = d.float_no
         AND l.logi_loc            = i.plogi_loc
         AND i.logi_loc            = NVL(d.carrier_id, i.logi_loc)  -- 09/18/19 Brian Bent Added.  For CMU we know what pallet in inventory float detail needs to allocate from
         AND ordd.order_id         = d.order_id                     -- 12/11/19 Brian Bent Added
         AND ordd.order_line_id    = d.order_line_id                -- 12/11/19 Brian Bent Added
         AND ordd.sys_order_id     = x.sys_order_id                 -- 12/11/19 Brian Bent Added
         FOR UPDATE OF d.qty_order
       ORDER BY d.float_no, d.prod_id;

      r_cd_floats            c_cd_floats%ROWTYPE;

      --
      -- Get all float_detail and inventory details on this float.
      --
      CURSOR c_fd (cp_route_no            floats.route_no%TYPE,
                   cp_float_no            floats.float_no%TYPE,
                   cp_prod_id             float_detail.prod_id%TYPE,
                   cp_cust_pref_vendor    float_detail.cust_pref_vendor%TYPE,
                   cp_order_id            float_detail.order_id%TYPE,
                   cp_order_line_id       float_detail.order_line_id%TYPE)
      IS
         SELECT f.float_no, f.route_no, fd.prod_id, fd.cust_pref_vendor, fd.qty_order, fd.qty_alloc, fd.status,
                fd.order_id, fd.order_line_id
           FROM float_detail fd,
                floats f
          WHERE f.route_no          = cp_route_no
            AND f.float_no          = cp_float_no
            AND fd.float_no         = f.float_no
            AND prod_id             = cp_prod_id
            AND cust_pref_vendor    = cp_cust_pref_vendor
            AND order_id            = cp_order_id
            AND order_line_id       = cp_order_line_id
            AND NVL(qty_alloc, 0)   = 0
          ORDER BY stop_no DESC
         FOR UPDATE OF qty_alloc;

      r_fd                   c_fd%ROWTYPE;

      --
      -- Fetch all floats per given route and order to create replenishments.
      --
      -- 07/16/19 Brian Bent Add CPV to joins where it was missing
      -- 11/04/19 Brian Bent Add join to FLOATS table to get the door number
      -- for the REPLENLST record.
      --
      CURSOR c_all_floats (cp_route_no VARCHAR2, cp_order_id VARCHAR2)
      IS
         SELECT DISTINCT d.float_no,
                         f.door_no,
                         i.inv_uom,
                         i.plogi_loc,
                         l.pik_path,
                         d.cust_pref_vendor,
                         MIN(i.exp_date) exp_date,
                         MIN(i.mfg_date) mfg_date, p.area,
                         x.parent_pallet_id
                    FROM float_detail d,
                         floats f,
                         inv i,
                         cross_dock_pallet_xref x,
                         loc l,
                         pm p
                   WHERE d.prod_id           = i.prod_id
                     AND d.cust_pref_vendor  = i.cust_pref_vendor
                     AND d.route_no          = cp_route_no
                     AND d.order_id          = cp_order_id
                     AND (i.inv_order_id IS NULL OR d.order_id = i.inv_order_id)
                     AND i.parent_pallet_id  = x.parent_pallet_id
                     AND i.plogi_loc         = l.logi_loc
                     AND p.prod_id           = i.prod_id
                     AND p.cust_pref_vendor  = i.cust_pref_vendor
                  -- AND p.prod_id           = d.prod_id      Redundant
                     AND d.float_no          = x.float_no
                     AND f.float_no          = d.float_no
                GROUP BY d.float_no,
                         f.door_no,
                         i.inv_uom,
                         i.plogi_loc,
                         l.pik_path,
                         d.cust_pref_vendor,
                         p.area,
                         x.parent_pallet_id;

      r_all_floats           c_all_floats%ROWTYPE;
   BEGIN
return; ---------------------------------------------------
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                      'BEGIN OF ALLOCATE INVENTORY FOR CROSS DOCK PALLETS',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name);

      FOR r_cd_orders_on_route IN c_cd_orders_on_route (i_route_no)
      LOOP
         l_message := 'Cursor c_cd_orders_on_route start loop'
                        || ' BEGIN ALLOCATION FOR ORDER_ID[' || r_cd_orders_on_route.order_id || ']'
                        || ' ROUTE_NO['                      || r_cd_orders_on_route.route_no || ']'
                        || ' cross dock type['               || r_cd_orders_on_route.cross_dock_type|| ']';

         DBMS_OUTPUT.PUT_LINE(l_object_name || ': ' || l_message);

         pl_log.ins_msg (pl_lmc.ct_info_msg,
                         l_object_name,
                         l_message,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

         FOR r_cd_floats IN c_cd_floats (i_route_no,
                                         r_cd_orders_on_route.order_id
                                        )
         LOOP
            l_message := 'Cursor c_cd_floats start loop'
                            || ' Begin allocation for float[' || r_cd_floats.float_no || ']'
                            || ' route['                      || r_cd_floats.route_no || ']'
                            || ' item['                       || r_cd_floats.prod_id || ']'
                            || ' cpv['                        || r_cd_floats.cust_pref_vendor || ']'
                            || ' order id['                   || r_cd_floats.order_id || ']'
                            || ' order line id['              || TO_CHAR(r_cd_floats.order_line_id) || ']'
                            || ' parent LP['                  || r_cd_floats.parent_pallet_id || ']'
                            || ' inv qoh['                    || r_cd_floats.qoh || ']'
                            || ' sys order id['               || TO_CHAR(r_cd_floats.sys_order_id) || ']';

            DBMS_OUTPUT.PUT_LINE(l_object_name || ': ' || l_message);

            pl_log.ins_msg (pl_lmc.ct_info_msg,
                            l_object_name,
                            l_message,
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name);

            pl_alloc_inv.get_group_no (i_method_id,
                                       r_cd_floats.plogi_loc,
                                       l_group_no,
                                       l_zone_id,
                                       l_equip_id,
                                       l_door_area,
                                       l_comp_code,
                                       l_merge_group_no);


            FOR r_fd IN c_fd (i_route_no,
                              r_cd_floats.float_no,
                              r_cd_floats.prod_id,
                              r_cd_floats.cust_pref_vendor,
                              r_cd_floats.order_id,
                              r_cd_floats.order_line_id)
            LOOP
               pl_log.ins_msg (pl_lmc.ct_info_msg,
                               l_object_name,
                                  'BEGIN ALLOCATION FOR PROD IN FLOAT [' || r_cd_floats.float_no || ']'
                               || ' PROD [' || r_cd_floats.prod_id || ']',
                               NULL,
                               NULL,
                               ct_application_function,
                               gl_pkg_name
                              );
               l_upd_qty := LEAST (r_fd.qty_order, r_cd_floats.qoh);

               --
               -- Update Float/Float_detail
               --
               BEGIN
                  UPDATE float_detail
                     SET qty_alloc  = l_upd_qty,
                         status     = DECODE (r_fd.qty_order, l_upd_qty, 'ALC', 'SHT'),
                         src_loc    = r_cd_floats.plogi_loc,
                         rec_id     = r_cd_floats.rec_id,
                         exp_date   = r_cd_floats.exp_date,
                         CUBE       = (l_upd_qty / NVL (r_cd_floats.spc, 1)) * NVL (r_cd_floats.case_cube, 0),
                         alloc_time = SYSDATE
                   WHERE CURRENT OF c_fd;
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     pl_log.ins_msg
                        (pl_lmc.ct_fatal_msg,
                         l_object_name,
                            'Error occured while updating float detail for Route[' || i_route_no || ']'
                         || '  Float[' || r_cd_floats.float_no || ']'
                         || '  Prod[' || r_cd_floats.prod_id || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
                     raise_application_error (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
               END;

               /* Getting total qty ordered for this order id */
               BEGIN
                  SELECT sum(qty_ordered) 
                    INTO l_ordd_qty
                    FROM ordd
                   WHERE order_id          = r_fd.order_id
                     AND order_line_id     = r_fd.order_line_id
                     AND route_no          = r_fd.route_no
                     AND prod_id           = r_fd.prod_id
                     AND cust_pref_vendor  = r_fd.cust_pref_vendor;

                  DBMS_OUTPUT.PUT_LINE('l_ordd_qty: ' || TO_CHAR(l_ordd_qty));
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     /* Log the error message and raise application error */
                     pl_log.ins_msg
                                (pl_lmc.ct_fatal_msg,
                                 l_object_name,
                                    'Could not fetch Qty Ordered for Route['
                                 || i_route_no
                                 || '] Order['
                                 || r_cd_orders_on_route.order_id
                                 || '] Prod['
                                 || r_fd.prod_id
                                 || ']',
                                 NULL,
                                 NULL,
                                 ct_application_function,
                                 gl_pkg_name
                                );
                     raise_application_error (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
                  WHEN OTHERS
                  THEN
                     pl_log.ins_msg
                        (pl_lmc.ct_fatal_msg,
                         l_object_name,
                            'Error occured while fetching Qty Ordered for Route[' || i_route_no || ']'
                         || '  Order[' || r_cd_orders_on_route.order_id || ']'
                         || '  Prod[' || r_fd.prod_id || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

                     raise_application_error (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
               END;

               pl_log.ins_msg (pl_lmc.ct_info_msg,
                               l_object_name,
                                  ' DEBUG  ALLOCATE INV ROUTE [' || i_route_no || ']'
                               || '  ITEM['      || r_cd_floats.prod_id   || ']'
                               || '  FLOAT['     || r_cd_floats.float_no  || ']'
                               || '  QOH['       || r_cd_floats.qoh       || ']'
                               || '  QTY_ORDER[' || r_fd.qty_order        || ']'
                               || '  QTY_ALLOC[' || l_upd_qty             || ']'
                               || '  PLOGI_LOC[' || r_cd_floats.plogi_loc || ']',
                               NULL,
                               NULL,
                               ct_application_function,
                               gl_pkg_name
                              );

               IF l_ordd_qty != r_cd_floats.qoh
               THEN
                  /* Update INV with qty difference and status as 'ERR'
                     -- inv qty will be updated during replen pick and drop
                     -- qty_alloc = l_upd_qty, -- allocated qty
                     -- qoh = r_fd.qoh, --qty remaining after allocating */

                  /******************
                   UPDATE    inv
                      SET    qoh = qoh - l_upd_qty,
                               qty_alloc = l_upd_qty
                   WHERE prod_id = r_fd.prod_id
                     AND parent_pallet_id = r_cd_floats.parent_pallet_id
                     AND rec_id = r_cd_floats.rec_id;
                   ****************/

                  --
                  -- 03/22/2020 Uncommented this and add: AND logi_loc         = r_cd_floats.logi_loc
                  --
                  UPDATE inv
                     SET status = 'ERR'
                   WHERE prod_id          = r_fd.prod_id
                     AND parent_pallet_id = r_cd_floats.parent_pallet_id
                     AND logi_loc         = r_cd_floats.logi_loc
                     AND rec_id           = r_cd_floats.rec_id;

                  /* Get the difference quantity for which ERR needs to be created */
                  r_cd_floats.qoh := ABS (r_cd_floats.qoh - l_upd_qty);

                  --
                  -- Write a new TRANS record with type 'ERR' with CMT field with the details of QTY_ORD QTY_AVL
                  --
                  BEGIN
                     INSERT INTO trans
                                 (trans_id, trans_type, trans_date,
                                  prod_id, rec_id,
                                  lot_id, exp_date,
                                  weight, temp,
                                  mfg_date, qty_expected, uom_expected,
                                  qty, uom,
                                  src_loc, dest_loc, user_id,
                                  order_id, route_no,
                                  stop_no,
                                  truck_no,
                                  cmt,
                                  old_status, new_status, reason_code,
                                  adj_flag, pallet_id, upload_time,
                                  order_line_id, batch_no, sys_order_id,
                                  sys_order_line_id, order_type,
                                  returned_prod_id, diff_weight,
                                  ilr_upload_time, cust_pref_vendor,
                                  clam_bed_no, warehouse_id, float_no,
                                  bck_dest_loc, labor_batch_no, tti,
                                  cryovac, parent_pallet_id, po_line_id,
                                  sn_no, po_no, country_of_origin,
                                  wild_farm, scan_method1, scan_method2,
                                  ref_pallet_id, items_per_carrier,
                                  replen_task_id
                                 )
                          VALUES (trans_id_seq.NEXTVAL,             -- trans_id
                                  'ERR',    -- trans_type
                                  SYSDATE,
                                  r_cd_floats.prod_id,
                                  r_cd_floats.rec_id,
                                  r_cd_floats.lot_id,
                                  r_cd_floats.exp_date,
                                  '',
                                  r_cd_floats.temperature,
                                  r_cd_floats.mfg_date, 
                                  '',
                                  '',
                                  -- uom_expected
                                  r_cd_floats.qoh,                  -- qty
                                  r_cd_floats.inv_uom,              -- uom
                                  r_cd_floats.plogi_loc,            -- src_loc
                                  '',
                                  -- dest_loc
                                  USER,
                                  -- user_id
                                  r_cd_orders_on_route.order_id,
                                  --order_id
                                  i_route_no,
                                  -- route_no
                                  r_cd_floats.stop_no,              -- stop_no
                                  r_cd_orders_on_route.truck_no,
                                  -- truck_no,
                                  'Qty Ord'
                                  || l_ordd_qty
                                  || 'Qty Avl'
                                  || r_cd_floats.qoh,
                                  
                                  -- CMT
                                  '', 
                                      -- old_status
                                  '',                            -- new_status
                                     '',                        -- reason_code
                                  '',                              -- adj_flag
                                     '',                          -- pallet_id
                                        SYSDATE,                -- upload_time
                                  '',                         -- order_line_id
                                     '99',                         -- batch_no
                                          '',                  -- sys_order_id
                                  '',                     -- sys_order_line_id
                                     '',                         -- order_type
                                  '',                      -- returned_prod_id
                                     '',                        -- diff_weight
                                  '',                       -- ilr_upload_time
                                     '',                   -- cust_pref_vendor
                                  '',                           -- clam_bed_no
                                     '000',                    -- warehouse_id
                                           '',                     -- float_no
                                  '',                          -- bck_dest_loc
                                     '',                     -- labor_batch_no
                                        '',                             -- tti
                                  '',                               -- cryovac
                                     '',                   -- parent_pallet_id
                                        '',                      -- po_line_id
                                  '',                                 -- SN_no
                                     r_cd_floats.rec_id,              -- PO_no
                                                        '',
                                  
                                  -- country_of_origin
                                  '',                             -- wild_farm
                                     '',                       -- scan_method1
                                        '',                    -- scan_method2
                                  '',                         -- ref_pallet_id
                                     '',                  -- items_per_carrier
                                  ''
                                 );                          -- replen_task_id
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        pl_log.ins_msg
                                   (pl_lmc.ct_fatal_msg,
                                    l_object_name,
                                       'Insert into TRANS failed for Route[' || i_route_no || ']'
                                    || '  Order[' || r_cd_orders_on_route.order_id || ']'
                                    || '  Prod[' || r_cd_floats.prod_id || ']',
                                    NULL,
                                    NULL,
                                    ct_application_function,
                                    gl_pkg_name);

                        raise_application_error (pl_exc.ct_data_error,
                                                    gl_pkg_name
                                                 || '.'
                                                 || l_object_name
                                                 || ': '
                                                 || SQLERRM
                                                );
                  END;
               END IF;

               dod_seq := dod_seq + 1;
               l_qty_order := r_fd.qty_order / r_cd_floats.spc;

               /* Create Float History records */
               BEGIN
                  INSERT INTO float_hist
                              (batch_no, route_no, user_id,
                               prod_id, cust_pref_vendor,
                               order_id,
                               order_line_id, qty_order,
                               qty_alloc,
                               stop_no, src_loc,
                               uom, exp_date,
                               mfg_date, rec_date,
                               lot_id, container_temperature,
                               float_no, qty_short
                              )
                       VALUES ('DOD' || dod_seq, i_route_no, 'ORDER',
                               r_fd.prod_id, r_cd_floats.cust_pref_vendor,
                               r_cd_orders_on_route.order_id,
                               r_cd_floats.order_line_id, r_fd.qty_order,
                               r_fd.qty_order - l_qty_short,
                               r_cd_floats.stop_no, r_cd_floats.plogi_loc,
                               r_cd_floats.inv_uom, r_cd_floats.exp_date,
                               r_cd_floats.mfg_date, r_cd_floats.rec_date,
                               r_cd_floats.lot_id, r_cd_floats.temperature,
                               r_fd.float_no, l_qty_short
                              );
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     pl_log.ins_msg
                           (pl_lmc.ct_fatal_msg,
                            l_object_name,
                               'Insert into Float History Failed for Route[' || i_route_no || ']'
                            || '  Order[' || r_cd_orders_on_route.order_id || ']'
                            || '  Prod[' || r_fd.prod_id || ']',
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name);

                     raise_application_error (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
               END;

               /* Create PIK transaction into op_trans */
               BEGIN
                  INSERT INTO op_trans
                              (trans_id, trans_type, trans_date,
                               prod_id, cust_pref_vendor,
                               qty_expected, qty, user_id, order_id,
                               src_loc, route_no,
                               pallet_id,
                               parent_pallet_id,
                               uom, rec_id,
                               lot_id, exp_date,
                               upload_time, float_no, truck_no
                              )
                       VALUES (trans_id_seq.NEXTVAL, 'PIK', SYSDATE,
                               r_fd.prod_id, r_cd_floats.cust_pref_vendor,
                               0, l_upd_qty, 'ORDER', 'PP',
                               r_cd_floats.plogi_loc, i_route_no,
                               r_cd_floats.logi_loc,
                               r_cd_floats.parent_pallet_id,
                               r_cd_floats.inv_uom, r_cd_floats.rec_id,
                               r_cd_floats.lot_id, r_cd_floats.exp_date,
                               NULL, r_fd.float_no, SUBSTR (i_route_no, 2)
                              );

                  pl_log.ins_msg (pl_lmc.ct_info_msg,
                                  l_object_name,
                                     ' END ALLOCATING FOR PROD IN FLOAT [' || r_fd.float_no || ']'
                                  || ' PROD [' || r_fd.prod_id || ']',
                                  NULL,
                                  NULL,
                                  ct_application_function,
                                  gl_pkg_name);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     pl_log.ins_msg
                           (pl_lmc.ct_fatal_msg,
                            l_object_name,
                               'Insert into Float History Failed for Route[' || i_route_no || ']'
                            || '  Float[' || r_fd.float_no || ']'
                            || '  Prod[' || r_fd.prod_id || ']',
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name);

                     raise_application_error (pl_exc.ct_data_error,
                                                 gl_pkg_name
                                              || '.'
                                              || l_object_name
                                              || ': '
                                              || SQLERRM
                                             );
               END;
            END LOOP;                             -- end loop for float_detail


            /* Getting door number from route table for floats */
            BEGIN
               SELECT DECODE (l_door_area,
                              'C', r.c_door,
                              'F', r.f_door,
                              'D', r.d_door
                             )
                 INTO l_door_no
                 FROM floats f, route r
                WHERE f.float_no = r_cd_floats.float_no
                  AND r.route_no = i_route_no
                  AND r.route_no = f.route_no;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  /* Log the error message and raise application error */
                  pl_log.ins_msg
                                (pl_lmc.ct_fatal_msg,
                                 l_object_name,
                                    'Could not fetch door number for Route['
                                 || i_route_no
                                 || '] Float['
                                 || r_cd_floats.float_no
                                 || ']',
                                 NULL,
                                 NULL,
                                 ct_application_function,
                                 gl_pkg_name
                                );
                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM
                                          );
               WHEN OTHERS
               THEN
                  pl_log.ins_msg
                     (pl_lmc.ct_fatal_msg,
                      l_object_name,
                         'Error occured while fetching Door number for Route[' || i_route_no || ']'
                      || '  Float[' || r_cd_floats.float_no || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name);

                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM
                                          );
            END;

            BEGIN
               pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, 'xxxxxx fffff  before update inv qoh, qty alloc', NULL, NULL, ct_application_function, gl_pkg_name);

               UPDATE floats
                  SET drop_qty = '',
                      -- not populating as drop_qty is only for home slot drop ?
                      home_slot = '',
                      --not populating as EI locations are not home slot locations
                      pallet_id = r_cd_floats.parent_pallet_id,
                      parent_pallet_id = r_cd_floats.parent_pallet_id,
                      group_no = l_group_no,
                      zone_id = l_zone_id,
                      equip_id = l_equip_id,
                      door_area = l_door_area,
                      comp_code = l_comp_code,
                      merge_group_no = l_merge_group_no,
                      door_no = l_door_no
                WHERE float_no = r_cd_floats.float_no;

               pl_log.ins_msg (pl_lmc.ct_info_msg,
                               l_object_name,
                                  ' BEGIN ALLOCATION FOR FLOAT [' || r_cd_floats.float_no || ']',
                               NULL,
                               NULL,
                               ct_application_function,
                               gl_pkg_name);
            EXCEPTION
               WHEN OTHERS
               THEN
                  pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                                  l_object_name,
                                     'Updating floats failed for Route[' || i_route_no || ']'
                                  || '  Float[' || r_cd_floats.float_no || ']',
                                  NULL,
                                  NULL,
                                  ct_application_function,
                                  gl_pkg_name);
                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM
                                          );
            END;
         END LOOP;                                      -- end loop for floats

         --
         -- Update the order qty alloc to reflect the inventory picked from the "build to pallet" pallet.
         --
         -- SET d.qty_alloc = NVL(d.qty_alloc, 0) +    -- 12/16/19 Brian Bent  Was this
         UPDATE ordd d
            SET d.qty_alloc =
                        (SELECT SUM(NVL(fd.qty_alloc, 0))
                           FROM floats f,
                                float_detail fd
                          WHERE f.float_no          = fd.float_no
                            AND fd.order_id         = d.order_id
                            AND fd.order_line_id    = d.order_line_id
                            AND fd.prod_id          = d.prod_id
                            AND fd.cust_pref_vendor = d.cust_pref_vendor
                            AND ((fd.merge_alloc_flag in ('X', 'Y')) OR f.pallet_pull = 'D'))   -- Took from alloc_inv.pc
          WHERE d.route_no = i_route_no;

         --
         -- Debug stuff
         --
         pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, 'xxxxxx ggggg 11111  after update ordd.qty_alloc sql%rowcount: ' || SQL%ROWCOUNT, NULL, NULL, ct_application_function, gl_pkg_name);
         DECLARE
            l_total_qty_alloc  PLS_INTEGER;
         BEGIN
           SELECT SUM(d.qty_alloc) INTO l_total_qty_alloc FROM ordd d WHERE route_no = i_route_no;
           pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, 'xxxxxx ggggg 11111  l_total_qty_alloc: ' || to_char(l_total_qty_alloc), NULL, NULL, ct_application_function, gl_pkg_name);
         EXCEPTION
            WHEN OTHERS THEN NULL;
         END;


         pl_log.ins_msg (pl_lmc.ct_info_msg,
                         l_object_name,
                            ' BEGIN ALLOCATION FOR ORDER_ID [' || r_cd_orders_on_route.order_id || ']'
                         || ' ROUTE_NO [' || i_route_no || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

         --
         -- Create replenishments for each cross dock float on the order.
         --
         FOR r_all_floats IN c_all_floats (i_route_no,
                                           r_cd_orders_on_route.order_id)
         LOOP
            pl_log.ins_msg (pl_log.ct_info_msg, l_object_name, 'EEEEEEEEEEEEEEEEEEEEEE  before update inv qoh, qty alloc',
                      NULL, NULL, ct_application_function, gl_pkg_name);

            --
            -- Get total quantity of the items on the floats.
            --
            BEGIN
               SELECT ROUND (SUM (fd.qty_alloc / NVL (p.spc, 1)), 0)
                 INTO l_total_qty
                 FROM float_detail fd, pm p
                WHERE fd.float_no        = r_all_floats.float_no
                  AND p.prod_id          = fd.prod_id
                  AND p.cust_pref_vendor = fd.cust_pref_vendor;


            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  pl_log.ins_msg
                             (pl_lmc.ct_fatal_msg,
                              l_object_name,
                                 'Could not fetch total quantity for Float[' || r_all_floats.float_no || ']',
                              NULL,
                              NULL,
                              ct_application_function,
                              gl_pkg_name);

                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM);
               WHEN OTHERS
               THEN
                  pl_log.ins_msg
                     (pl_lmc.ct_fatal_msg,
                      l_object_name,
                         'Error occured while fetching total quantity for Float[' || r_all_floats.float_no || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name);

                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM);
            END;

            pl_log.ins_msg (pl_lmc.ct_info_msg,
                            l_object_name,
                               'Total Qty [' || l_total_qty || ']'
                            || ' Float [' || r_all_floats.float_no || ']',
                            NULL,
                            NULL,
                            ct_application_function,
                            gl_pkg_name);

            --
            -- Create replenishments for each cross dock float.
            --
            BEGIN
               --
               -- Check if replenishment has already been created.
               -- If not create it, else update the quantity.
               --
               BEGIN
                  SELECT 'Y'
                    INTO l_replen_exist
                    FROM replenlst
                   WHERE parent_pallet_id = r_all_floats.parent_pallet_id;
               EXCEPTION
               --
               -- We'll get an exception if no replen has been created for parent pallet.
               --
                  WHEN OTHERS
                  THEN
                     l_replen_exist := 'N';
               END;

               IF l_replen_exist = 'Y'
               THEN
                  --
                  -- If replenishment already exists, just update it with the latest quantity value.
                  --
                  UPDATE replenlst
                     SET qty = l_total_qty
                   WHERE parent_pallet_id = r_all_floats.parent_pallet_id;
               ELSE
                  --
                  -- No replenishment has been created for this float, create one.
                  --
                  INSERT INTO replenlst
                              (task_id,
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
                               replen_area)
                     SELECT repl_id_seq.NEXTVAL                  task_id,
                            '*MULTI*'                            prod_id,
                            r_all_floats.inv_uom                 uom,
                            l_total_qty                          qty,
                            'BLK'                                type,
                            'NEW'                                status,
                            r_all_floats.plogi_loc               src_loc,
                            r_all_floats.parent_pallet_id        pallet_id,
                            NULL                                 dest_loc,
                            r_all_floats.pik_path                s_pikpath,
                            NULL                                 d_pikpath,
                            0                                    batch_no,
                            l_equip_id                           equip_id,
                            r_cd_orders_on_route.order_id        order_id,
                            NULL                                 user_id,
                            'Y'                                  op_acquire_flag,
                            r_all_floats.cust_pref_vendor        cust_pref_vendor,
                            REPLACE(USER, 'OPS$')                gen_uid,
                            SYSDATE                              gen_date,
                            r_all_floats.exp_date                exp_date,
                            r_all_floats.mfg_date                mfg_date,
                            i_route_no                           route_no,
                            r_all_floats.float_no                float_no,
                            1                                    seq_no,
                            r_cd_orders_on_route.route_batch_no  route_batch_no,
                            r_cd_orders_on_route.truck_no        truck_no,
                            NULL                                 inv_dest_loc,
                            NULL                                 drop_qty,
                            r_all_floats.door_no                 door_no,
                            r_all_floats.parent_pallet_id        parent_pallet_id,
                            'D'                                  replen_type,
                            r_all_floats.area                    replen_area
                       FROM DUAL;
--                   WHERE NOT EXISTS (
--                            SELECT 1
--                              FROM replenlst
--                             WHERE parent_pallet_id =
--                                                r_all_floats.parent_pallet_id);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  pl_log.ins_msg
                               (pl_lmc.ct_fatal_msg,
                                l_object_name,
                                   'Insert into Replenlst failed for Route['
                                || i_route_no
                                || '] Pallet['
                                || r_all_floats.parent_pallet_id
                                || '] Float['
                                || r_all_floats.float_no
                                || ']'
                                || SQLERRM,
                                NULL,
                                NULL,
                                ct_application_function,
                                gl_pkg_name
                               );
                  raise_application_error (pl_exc.ct_data_error,
                                              gl_pkg_name
                                           || '.'
                                           || l_object_name
                                           || ': '
                                           || SQLERRM
                                          );
            END;
         END LOOP;
      END LOOP;                                          -- end loop for order

      --
      -- Delete the CDK inventory but only if it was not flagged with ERR status.
      -- 03/22/20 Brian Bent Added the delete.
      --
      DELETE 
        FROM inv i
       WHERE i.status = 'CDK'
         AND i.logi_loc IN
              (SELECT fd.carrier_id
                 FROM floats f,
                      float_detail fd,
                      ordd,
                      ordm,
                      cross_dock_type cdt
                WHERE f.route_no             = i_route_no
                  AND f.float_no             = fd.float_no
                  AND ordd.order_id          = fd.order_id
                  AND ordd.order_line_id     = fd.order_line_id
                  AND ordd.remote_local_flg  IN ('B', 'R')       -- Fail safe so we select only CMU cross dock details
                  AND ordm.order_id          = ordd.order_id
                  AND ordm.cross_dock_type   NOT IN ('S', 'X')
                  AND ordm.cross_dock_type   = cdt.cross_dock_type);

      DBMS_OUTPUT.PUT_LINE(l_object_name || '  Number of INV records deleted: ' || SQL%ROWCOUNT);
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Log the error message and raise application error */
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                         SQLERRM,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name);

         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM);
   END update_multisku_pallet_inv;


   ---------------------------------------------------------------------------
-- Procedure:
--    update_floats_ordcw
--
-- Description:
--      Will update the catch weight records in ORDCW with the catch weight
--          that we receivef from EI for all the orders
--          on the route passed as an argument
--
-- Parameters:
--      i_route_no - Route number for which ORDCW records has to be populated
---------------------------------------------------------------------------
   PROCEDURE update_floats_ordcw
                   (i_route_batch_no   IN   route.route_batch_no%TYPE)
   IS
      l_object_name   VARCHAR2 (40 CHAR) := 'update_floats_ordcw';
      l_seq_no        NUMBER             := 1;
     l_count_ordcw    NUMBER             := 0;

      --
      -- For all the routes in a route batch.
      --
      CURSOR c_route_in_batch (l_route_batch_no IN route.route_batch_no%TYPE)
      IS
         SELECT route_no
           FROM route
          WHERE route_batch_no = l_route_batch_no;

      --
      -- Get all the EI products with CW track on the route.
      --
      CURSOR c_ordd_cw_records (l_route_no IN route.route_no%TYPE)
      IS
         SELECT d.prod_id, d.order_id, d.sys_order_id
           FROM ordd d, ordm m, cross_dock_type cdt
          WHERE m.order_id = d.order_id
            AND m.cross_dock_type = cdt.cross_dock_type
            AND d.route_no = l_route_no
            AND m.cross_dock_type NOT IN ('S', 'X')
            AND cw_type = 'I';

      --
      -- Get all the EI products with CW track on the cross dock data collect table.
      --
      CURSOR c_cddc_cw_records (
         l_prod_id        IN   pm.prod_id%TYPE,
         l_sys_order_id   IN   ordd.sys_order_id%TYPE
      )
      IS
         SELECT catch_wt
           FROM cross_dock_data_collect
          WHERE rec_type = 'C'
            AND prod_id = l_prod_id
            AND erm_id IN (SELECT erm_id
                             FROM cross_dock_xref
                            WHERE sys_order_id = l_sys_order_id);
   BEGIN
return; ---------------------------------------------------
      pl_log.ins_msg
                   (pl_lmc.ct_info_msg,
                    l_object_name,
                       'BEGIN OF UPDATE FLOATS ORDCW FOR CROSS DOCK ROUTE BATCH NO'
                    || '[' || i_route_batch_no || ']',
                    NULL,
                    NULL,
                    ct_application_function,
                    gl_pkg_name
                   );

      FOR r_route_in_batch IN c_route_in_batch (i_route_batch_no)
      LOOP
         /* Debug messages */
         pl_log.ins_msg (pl_lmc.ct_info_msg,
                         l_object_name,
                            'UPDATING ORDCW FOR ROUTE['
                         || r_route_in_batch.route_no
                         || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );

         /* FOR EACH ORDD RECORD WITH CATCH WEIGHT TRACK ON IT*/
         FOR r_ordd_cw_records IN c_ordd_cw_records (r_route_in_batch.route_no)
         LOOP
            /* Debug messages */
-- xxx
            pl_log.ins_msg
               (pl_log.ct_info_msg,
                l_object_name,
                   'UPDATING ORDCW FOR [PROD_ID,SYS_ORDER_ID] COMBINATION ['
                || r_ordd_cw_records.prod_id
                || ','
                || r_ordd_cw_records.sys_order_id
                || ']',
                NULL,
                NULL,
                ct_application_function,
                gl_pkg_name
               );

            FOR r_cddc_cw_records IN c_cddc_cw_records(r_ordd_cw_records.prod_id,
                                                       r_ordd_cw_records.sys_order_id)
            LOOP
               -- Count record in ORDCW
               SELECT count(*) INTO l_count_ordcw
                FROM ordcw
                WHERE order_id = r_ordd_cw_records.order_id
                  AND prod_id = r_ordd_cw_records.prod_id
                  AND seq_no = l_seq_no;

               -- Update ORDCW with the Catch weight from EI.
               UPDATE ordcw cw1
                  SET catch_weight = r_cddc_cw_records.catch_wt, 
                                     cw_type = 'A' 
                WHERE order_id = r_ordd_cw_records.order_id
                  AND prod_id = r_ordd_cw_records.prod_id
                  AND seq_no = (SELECT MIN(seq_no)
                                  FROM ordcw cw2 
                                 WHERE order_id     = cw1.order_id
                                   AND prod_id      = cw1.prod_id
                                   AND cw_float_no  = cw1.cw_float_no 
                                   AND cw_type      = 'I'
                                   AND catch_weight IS NULL)
                  AND EXISTS
                           (SELECT float_no 
                              FROM floats 
                              WHERE float_no  = cw1.cw_float_no 
                              AND pallet_pull ='B');
							
            pl_log.ins_msg
               (pl_lmc.ct_info_msg,
                l_object_name,
                   'UPDATING ORDCW FOR [PROD_ID,SYS_ORDER_ID,ORDER_ID,L_SEQ,CATCH_WT,COUNT_ORDCW] COMBINATION ['
                || r_ordd_cw_records.prod_id
                || ','
                || r_ordd_cw_records.sys_order_id
                || ','
                || r_ordd_cw_records.order_id
                || ','
                || to_char(l_seq_no)
                || ','
                || to_char(r_cddc_cw_records.catch_wt)
                || ','
                || to_char(l_count_ordcw)
                || ']',
                NULL,
                NULL,
                ct_application_function,
                gl_pkg_name
               );
							
               /* Increment the sequence number */
               l_seq_no := l_seq_no + 1;
            END LOOP;

               /* Update floats with required status */
               UPDATE floats
                  SET cw_collect_status = 'C',
                      cw_collect_user = USER
                WHERE pallet_pull = 'B' 
                  AND float_no IN
                           (SELECT DISTINCT cw_float_no
                              FROM ordcw
                             WHERE order_id = r_ordd_cw_records.order_id
                               AND prod_id = r_ordd_cw_records.prod_id
                               AND cw_type = 'A'
                               AND catch_weight IS NOT NULL);
			
            -- Reset the sequence.
            l_seq_no := 1;
            /* Debug messages */
            pl_log.ins_msg
               (pl_lmc.ct_info_msg,
                l_object_name,
                   'ORDCW RECORDS UPDATED SUCCESSFULLY FOR [PROD_ID,SYS_ORDER_ID] COMBINATION ['
                || r_ordd_cw_records.prod_id
                || ','
                || r_ordd_cw_records.sys_order_id
                || ']',
                NULL,
                NULL,
                ct_application_function,
                gl_pkg_name
               );
         END LOOP;

         /* Debug messages */
         pl_log.ins_msg (pl_lmc.ct_info_msg,
                         l_object_name,
                            'ORDCW UPDATED SUCCESSFULLY FOR ROUTE['
                         || r_route_in_batch.route_no
                         || ']',
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
      END LOOP;

      /* Debug messages */
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                         'END OF UPDATE FLOATS ORDCW FOR  CROSS DOCK ROUTE BATCH NO['
                      || i_route_batch_no
                      || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Log the error message and raise application error */
         pl_log.ins_msg
                  (pl_lmc.ct_fatal_msg,
                   l_object_name,
                      'ERROR OCCURRED WHILE UPDATING CATCH WEIGHT FOR CROSS DOCK PALLET - '
                   || SQLERRM,
                   NULL,
                   NULL,
                   ct_application_function,
                   gl_pkg_name
                  );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 );
   END;


---------------------------------------------------------------------------
-- Procedure:
--    update_ordm_cdk_type
--
-- Description:
--    This SP will update the cross dock type field in ORDM
--          table with EI for EI Orders
--
-- Parameters:
--          i_route_no - Route number for which the cross dock value
--                          has to be populated
---------------------------------------------------------------------------
   PROCEDURE update_ordm_cdk_type (i_route_no IN route.route_no%TYPE)
   IS
      l_object_name   VARCHAR2 (25 CHAR) := 'update_ordm_cdk_type';
   BEGIN
return; ---------------------------------------------------
      /* Log Begin message */
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                         'BEGIN OF ORDM CDK TYPE UPDATE FOR ROUTE['
                      || i_route_no
                      || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );

      /* Update the cross_dock_type field in ORDM for all the cross dock orders */
    /* comment by knha8378-kiet on 10-17-2019 because we are not using EI and this is affecting MU cross dock */
    /*
      UPDATE ordm
         SET cross_dock_type = 'EI'
       WHERE route_no = i_route_no
         AND order_id IN
                   (SELECT DISTINCT order_id
                      FROM ordd
                     WHERE sys_order_id IN (
                                   SELECT DISTINCT d.sys_order_id
                                              FROM ordd d,
                                                   cross_dock_xref cdx
                                             WHERE cdx.sys_order_id =
                                                                d.sys_order_id
                                               AND d.status = 'NEW'));
     */
											   
      /* Log Begin message */
     /*
      pl_log.ins_msg (pl_lmc.ct_info_msg,
                      l_object_name,
                         'END OF ORDM CDK TYPE UPDATE FOR ROUTE['
                      || i_route_no
                      || ']',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );
     */					 

		-- Update ORDM.CROSS_DOCK_TYPE = MU for CMU if remote_local_flg has (B, R)
		BEGIN
		  UPDATE ordm
			 SET cross_dock_type = 'MU' 
		   WHERE route_no = i_route_no
                     AND ordm.cross_dock_type  NOT IN ('S', 'X')
			 AND order_id IN (
					SELECT DISTINCT order_id
							   FROM ordd
							  WHERE remote_local_flg IN ('B', 'R') 
							 );				  
		EXCEPTION
		  WHEN OTHERS
		  THEN 	
		
			 /* Log the error message and raise application error */
			 pl_text_log.ins_msg
						  ('FATAL',
						   l_object_name,
							  'ERROR OCCURRED WHILE UPDATING ordm.cross_dock_type FOR ROUTE_NO['
						   || i_route_no
						   || ']',
						   SQLCODE,
						   SQLERRM
						  );
		
		END;	

   EXCEPTION
      WHEN OTHERS
      THEN
         /* Log the error message and raise application error */
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                            'UPDATE FOR ROUTE['
                         || i_route_no
                         || '] FAILED WITH ERROR - '
                         || SQLERRM,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 );
   END update_ordm_cdk_type;


   ---------------------------------------------------------------------------
-- Procedure:
--    update_ordd_zone
--
-- Description:
--    This SP will update the zone for the current order line item in ORDD table
--
-- Parameters:
--      i_order_id - Order ID from ORDD
--      i_prod_id  - Prod ID from ORDD
---------------------------------------------------------------------------
   PROCEDURE update_ordd_zone (
      i_order_id       IN   ordd.order_id%TYPE,
      i_sys_order_id   IN   ordd.sys_order_id%TYPE,
      i_prod_id        IN   ordd.prod_id%TYPE
   )
   IS
      l_object_name        VARCHAR2 (25 CHAR)           := 'update_ordd_zone';
      l_pallet_id          cross_dock_data_collect.pallet_id%TYPE;
      l_parent_pallet_id   cross_dock_data_collect.parent_pallet_id%TYPE;
      l_zone_id            ZONE.zone_id%TYPE;
   BEGIN
return; ---------------------------------------------------
      /* Log Begin message */
      pl_text_log.ins_msg ('DEBUG',
                           l_object_name,
                           'Updating Zone for Order ID [' || i_order_id || ']',
                           SQLCODE,
                           SQLERRM
                          );

      /* Get the pallet id associated with current
                Sysco Order ID and Prod ID combination */
      SELECT pallet_id, parent_pallet_id
        INTO l_pallet_id, l_parent_pallet_id
        FROM cross_dock_xref cx, cross_dock_data_collect cd
       WHERE cx.sys_order_id = i_sys_order_id
         AND cd.erm_id = cx.erm_id
         AND cd.prod_id = i_prod_id
         AND cd.rec_type = 'D'
         AND ROWNUM = 1;

      /* Get the zone ID associated with current
                Order ID and prod ID combination */
      SELECT z.zone_id
        INTO l_zone_id
        FROM lzone lz,
             ZONE z,
             loc l,
             inv i,
             aisle_info ai,
             cross_dock_xref cx,
             cross_dock_data_collect cd
       WHERE     /*cx.sys_order_id = i_sys_order_id
             AND */ cd.erm_id = cx.erm_id
         AND cd.rec_type = 'H'
         AND cd.parent_pallet_id = l_parent_pallet_id
         AND i.logi_loc = l_pallet_id
         AND l.logi_loc = i.plogi_loc
         AND lz.logi_loc = l.logi_loc
         AND lz.zone_id = z.zone_id
         AND ai.NAME = SUBSTR (l.logi_loc, 1, 2)
         AND ai.sub_area_code = cd.area
         AND z.zone_type = 'PIK'
         AND ROWNUM = 1;

      /* Now that we have the required data, update the ORDD
                with the required zone details */
      UPDATE ordd
         SET zone_id = l_zone_id
       WHERE order_id = i_order_id AND prod_id = i_prod_id;

      pl_text_log.ins_msg ('DEBUG',
                           l_object_name,
                              'Order ID ['
                           || i_order_id
                           || '] updated with zone ['
                           || l_zone_id
                           || ']',
                           SQLCODE,
                           SQLERRM
                          );
   EXCEPTION
      WHEN OTHERS
      THEN
         /* Log the error message and raise application error */
         pl_text_log.ins_msg
                      ('FATAL',
                       l_object_name,
                          'ERROR OCCURRED WHILE RETRIEVEING DATA FOR ORDER['
                       || i_order_id
                       || '] PROD['
                       || i_prod_id
                       || ']'
                       || ' SYS_ORDER['
                       || i_sys_order_id
                       || ']',
                       SQLCODE,
                       SQLERRM
                      );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 );
   END;

---------------------------------------------------------------------------
-- Procedure:
--    recover_ei_order
--
-- Description:
--    This SP will revert the chamges made specifically during
--                  route generate for EI order
--
-- Parameters:
--    i_route_no - Route number that us being recovered
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/26/19 bben0556 Brian Bent
--                      CMU project.
--                      During order generation when ORDD.REMOTE_LOCAL_FLAG is 'B'
--                      an ORDD record for the OpCo pick for the qty to be filled from the OpCo.
--                      This ORDD record needs to be deleted.
---------------------------------------------------------------------------
PROCEDURE recover_ei_order (i_route_no IN route.route_no%TYPE)
IS
   l_object_name   VARCHAR2 (40 CHAR) := 'recover_ei_order';
BEGIN
return; ---------------------------------------------------
   --
   -- Update the status of cross dock inventory to CDK.
   --
   UPDATE inv
      SET status = 'CDK',
          upd_user = 'SWMS',
          upd_date = SYSDATE
    WHERE rec_id IN
            (SELECT DISTINCT erm_id
                        FROM cross_dock_xref cdx, ordd d
                       WHERE cdx.sys_order_id = d.sys_order_id
                         AND d.route_no = i_route_no)
      AND status <> 'CDK';

   --
   -- Update the float and batch number for all the EI orders to null */
   --
   UPDATE cross_dock_pallet_xref
      SET float_no = NULL,
          batch_no = NULL,
          upd_user = 'SWMS',
          upd_date = SYSDATE
    WHERE sys_order_id IN (
                SELECT DISTINCT d.sys_order_id
                           FROM ordm m, ordd d, cross_dock_type cdk
                          WHERE m.route_no = i_route_no
                            AND m.order_id = d.order_id
                            AND m.cross_dock_type NOT IN ('S', 'X')
                            AND m.cross_dock_type = cdk.cross_dock_type);

   --
   -- Update the order status to RCV in cross dock reference table.
   --
   UPDATE cross_dock_xref
      SET status = 'RCV',
          upd_date = SYSDATE
    WHERE sys_order_id IN
               (SELECT DISTINCT d.sys_order_id
                           FROM ordm m, ordd d, cross_dock_type cdk
                          WHERE m.route_no = i_route_no
                            AND m.order_id = d.order_id
                            AND m.cross_dock_type NOT IN ('S', 'X')
                            AND m.cross_dock_type = cdk.cross_dock_type);
   --
   -- Delete the CMU ORDD record.
   -- During order generation when ORDD.REMOTE_LOCAL_FLAG is 'B'
   -- an ORDD record for the OpCo pick for the qty to be filled from the OpCo.
   -- This ORDD record needs to be deleted.
   --
   DELETE FROM ordd od
    WHERE od.route_no               = i_route_no
      AND od.original_order_line_id IS NOT NULL
      AND EXISTS                                -- Plus this extra criteria.
           (SELECT 'x'
              FROM ordd od2
             WHERE od2.route_no      = od.route_no
               AND od2.order_id      = od.order_id
               AND od2.order_line_id = od.original_order_line_id);
           
EXCEPTION
   WHEN OTHERS
   THEN
      --
      -- Log the error message and raise application error.
      --
      pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                      l_object_name,
                      SQLERRM,
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                      );
      raise_application_error (pl_exc.ct_data_error,
                               gl_pkg_name
                               || '.'
                               || l_object_name
                               || ': '
                               || SQLERRM
                               );
END recover_ei_order;

---------------------------------------------------------------------------
-- Function:
--    f_get_crossdock_value
--
-- Description:
--    This function checks whether the parameter order id is a cross dock order or not.
--    If it is a cross dock order, then it return EI else it return empty string

   -- Parameters:
--          i_order_id  - Order Id from ORDD
---------------------------------------------------------------------------
   FUNCTION f_get_crossdock_value (i_id IN VARCHAR, i_type IN CHAR)
      RETURN CHAR
   IS
      l_ret_val       CHAR;
      l_count         NUMBER;
      l_object_name   VARCHAR2 (30 CHAR) := 'f_get_crossdock_value';
   BEGIN
      --
      -- 12/12/19 Brian Bent Changed message level from info to debug.
      -- info level created too many messages and slowed processing.
      --
      pl_log.ins_msg (pl_lmc.ct_debug_msg, 
                      l_object_name,
                      'CHECKING CDK TYPE FOR ID[' || i_id || ']'
                         || '  i_type[' || i_type || '] ',
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );

      CASE UPPER (i_type)
         /* when a sysco order id is passed as an argument*/
      WHEN 'O'
         THEN
            SELECT COUNT (1)
              INTO l_count
              FROM erm e, cross_dock_type cdt
             WHERE to_number(sys_order_id) = i_id
               AND e.cross_dock_type  NOT IN ('S', 'X')
               AND cdt.cross_dock_type = e.cross_dock_type;
         /* when a Route number is passed as an argument*/
      WHEN 'R'
         THEN
            SELECT COUNT (1)
              INTO l_count
              FROM ordm m, cross_dock_type cdt
             WHERE route_no = i_id
               AND m.cross_dock_type  NOT IN ('S', 'X')
               AND m.cross_dock_type = cdt.cross_dock_type;
         /* when a Batch number is passed as an argument*/
      WHEN 'B'
         THEN
            SELECT COUNT (1)
              INTO l_count
              FROM cross_dock_pallet_xref
             WHERE float_no IN (SELECT float_no
                                  FROM cross_dock_pallet_xref
                                 WHERE batch_no = i_id);
         WHEN 'P'
         THEN
            SELECT COUNT (1)
              INTO l_count
              FROM cross_dock_pallet_xref
             WHERE parent_pallet_id = i_id;
      END CASE;

      IF l_count > 0
      THEN
         l_ret_val := 'Y';
      ELSE
         l_ret_val := 'N';
      END IF;

      --
      -- 12/12/19 Brian Bent Changed message level from info to debug.
      -- info level created too many messages and slowed processing.
      --
      pl_log.ins_msg (pl_lmc.ct_debug_msg,
                      l_object_name,
                      'CDK TYPE FOR ID[' || i_id || '] IS ' || l_ret_val,
                      NULL,
                      NULL,
                      ct_application_function,
                      gl_pkg_name
                     );
      RETURN l_ret_val;
   EXCEPTION
      WHEN OTHERS
      THEN
         pl_log.ins_msg (pl_lmc.ct_fatal_msg,
                         l_object_name,
                            'ERROR OCCURRED WHILE RETRIEVING USING ID ['
                         || i_id
                         || '] '
                         || SQLERRM,
                         NULL,
                         NULL,
                         ct_application_function,
                         gl_pkg_name
                        );
         l_ret_val := 'N';
   END;

 
---------------------------------------------------------------------------
-- Procedure:
--    update_cmu_sys_order_id
--
-- Description:
--    This SP will update sys_order_id for the current rdc_po_no to sync up with ORDD 
--
-- Parameters:
--      i_route_no	  - Route_No 
--      
--
---------------------------------------------------------------------------
PROCEDURE update_cmu_sys_order_id (i_route_no IN route.route_no%TYPE)
IS
    CURSOR c_route (l_route_no IN route.route_no%TYPE)
      IS
         SELECT sys_order_id, rdc_po_no 
           FROM ordd 
          WHERE route_no = l_route_no 
		    AND remote_local_flg in ('B', 'R') 
		  GROUP BY sys_order_id, rdc_po_no;

      l_object_name        	VARCHAR2 (30 CHAR) := 'UPDATE_CMU_SYS_ORDER_ID';
	  l_cross_dock_count	NUMBER 	:= 0;

BEGIN
return; ---------------------------------------------------
	
	SELECT COUNT(*) 
	  INTO l_cross_dock_count 
	  FROM ORDM 
	 WHERE cross_dock_type = 'MU'
	   AND route_no = i_route_no;
	 
	IF l_cross_dock_count>0 THEN
		--Process each sys_order_id, rdc_po_no for given Route#
		FOR c_rec IN c_route (i_route_no) 
		LOOP
			  UPDATE CROSS_DOCK_PALLET_XREF 
				 SET sys_order_id = c_rec.sys_order_id,
					 upd_user = 'SWMS',
					 upd_date = SYSDATE 
			   WHERE sys_order_id = c_rec.rdc_po_no;
								  
			  UPDATE CROSS_DOCK_XREF 
				 SET sys_order_id = c_rec.sys_order_id,
					 upd_date = SYSDATE 
			   WHERE sys_order_id = c_rec.rdc_po_no;
				 
		END LOOP;
	END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Log the error message and raise application error 
         pl_text_log.ins_msg
                      ('FATAL',
                       l_object_name,
                          'ERROR OCCURRED WHILE UPDATING SYS_ORDER_ID FOR ROUT_NO['
                       || i_route_no
                       || ']',
                       SQLCODE,
                       SQLERRM
                      );
         raise_application_error (pl_exc.ct_data_error,
                                     gl_pkg_name
                                  || '.'
                                  || l_object_name
                                  || ': '
                                  || SQLERRM
                                 ); 
END update_cmu_sys_order_id;


---------------------------------------------------------------------------
-- Procedure:
--    recover_cross_dock_pallets
--
-- Description:
--    This procedure recovers the cross dock pallets on a route.
--
--    Processing:
--       - Select the cross dock pallet(s) on the route.
--       - For each LP on the cross dock pallet insert back the inventory.
--       - Delete the float details.
--       - Delete the floats.
--       order_recovery.pc handles updating ORDD and ORDM.
--
-- Parameters:
--    i_route_no         - The route number to process.
--
-- Called by:
--    xxx
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- --------------------------------------------------
--    03/22/20 bben0556 Brian Bent
--                      Created.
---------------------------------------------------------------------------
PROCEDURE recover_cross_dock_pallets (i_route_no  IN  route.route_no%TYPE)
IS
   l_object_name   VARCHAR2(30)   := 'recover_cross_dock_pallets';
   l_message       VARCHAR2(512);  -- Work area

   l_parameters    VARCHAR2(80);  -- Work area

   --
   -- This cursor selects the cross dock pallets route to recover.
   -- Note that cross dock pallets are treated as bulk pulls.
   --
   CURSOR c_cd_pallets_to_recover(cp_route_no  route.route_no%TYPE)
   IS
   SELECT f.float_no               float_no,
          f.route_no               route_no,
          f.pallet_pull            pallet_pull,
          f.pallet_id              pallet_id,
          f.parent_pallet_id       parent_pallet_id,
          f.status                 f_status
     FROM floats f
    WHERE f.route_no = cp_route_no
      --
      -- NOTE: Table CROSS_DOCK_PALLET_XFEF needs to have been populated for
      --       function "f_get_crossdock_value" to return the correct results.
      --
      AND pl_cross_dock_order_processing.f_get_crossdock_value(f.parent_pallet_id, 'P') = 'Y'
    ORDER BY f.parent_pallet_id;


   --
   -- This cursor selects the cross dock pallet details on the route to recover.
   -- Note that cross dock pallets are treated as bulk pulls.
   --
   -- It also selects the inventory deleted that was physically on the pallet but not
   -- ordered (ideally this should not happen).  This needs to get back into invenory too.
   --  During OP allocation all the inventory on the cross edoc pallet is delete including
   -- what was not ordered.  There will be no float detail record(s) for what was not ordered.
   --
   CURSOR c_cd_pallet_dtls_to_recover(cp_float_no  IN floats.float_no%TYPE)
   IS
   SELECT f.float_no               float_no,
          f.route_no               route_no,
          f.pallet_pull            pallet_pull,
          f.pallet_id              pallet_id,
          f.parent_pallet_id       parent_pallet_id,
          f.status                 f_status,
          fd.seq_no                seq_no,
          fd.prod_id               prod_id,
          fd.cust_pref_vendor      cust_pref_vendor,
          fd.src_loc               src_loc,
          fd.qty_order             qty_order,
          fd.qty_alloc             qty_alloc,
          fd.carrier_id            carrier_id,
          fd.status                fd_status,
          fd.rec_id                rec_id,
          fd.exp_date              exp_date,
          fd.mfg_date              mfg_date,
          fd.lot_id                lot_id,
          inv_hist.rec_date        rec_date,
          inv_hist.inv_date        inv_date,
          inv_hist.qty_planned     inv_qty_planned,
          inv_hist.qty_alloc       inv_qty_alloc,
          inv_hist.abc             abc,
          inv_hist.exp_ind         exp_ind
     FROM floats f,
          float_detail fd,
          -- inline view of INV_HIST as some info is needed from it.  Get the last entry for the LP.
          (SELECT logi_loc, prod_id, cust_pref_vendor, inv_del_date, my_rank, rec_date, inv_date,
                  qty_planned, qty_alloc, abc, exp_ind
             FROM
                (SELECT logi_loc, prod_id, cust_pref_vendor, inv_del_date, rec_date, inv_date, qty_alloc,
                        qty_planned, abc, exp_ind,
                        RANK () OVER (PARTITION BY logi_loc, prod_id, cust_pref_vendor order by inv_del_date desc) my_rank
                   FROM inv_hist)
             WHERE my_rank = 1) inv_hist
          --
    WHERE f.float_no = fd.float_no
      AND f.float_no = cp_float_no
      --
      AND inv_hist.logi_loc         (+) = fd.carrier_id
      AND inv_hist.prod_id          (+) = fd.prod_id
      AND inv_hist.cust_pref_vendor (+) = fd.cust_pref_vendor
      AND pl_cross_dock_order_processing.f_get_crossdock_value(f.parent_pallet_id, 'P') = 'Y'
    ORDER BY fd.seq_no,
             fd.prod_id,
             fd.cust_pref_vendor,
             fd.src_loc,
             fd.carrier_id;
BEGIN
return; ---------------------------------------------------
   l_parameters := '(i_route_no[' || i_route_no || '])';

   --
   -- Log starting the procedure.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Starting procedure' || l_parameters,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   FOR r_cd_pallet_to_recover IN c_cd_pallets_to_recover(i_route_no)
   LOOP
      DBMS_OUTPUT.PUT_LINE('==============================================================================');

      FOR r_cd_pallet_dtls_to_recover IN c_cd_pallet_dtls_to_recover(r_cd_pallet_to_recover.float_no)
      LOOP
         DBMS_OUTPUT.PUT_LINE(r_cd_pallet_dtls_to_recover.parent_pallet_id
                     || ' '  || r_cd_pallet_dtls_to_recover.pallet_id
                     || ' '  || r_cd_pallet_dtls_to_recover.prod_id
                     || ' '  || r_cd_pallet_dtls_to_recover.cust_pref_vendor
                     || ' '  || r_cd_pallet_dtls_to_recover.src_loc
                     || ' '  || r_cd_pallet_dtls_to_recover.carrier_id
                     || ' '  || r_cd_pallet_dtls_to_recover.qty_order
                     || ' '  || r_cd_pallet_dtls_to_recover.qty_alloc);

         BEGIN
            --
            -- Restore the inventory.
            --
            INSERT INTO inv
               (prod_id,
                cust_pref_vendor,
                rec_id,
                rec_date,
                inv_date,
                mfg_date,
                exp_date,
                logi_loc,
                plogi_loc,
                qoh,
                qty_alloc,
                qty_planned,
                min_qty,
                status,
                abc,
                lot_id,
                exp_ind,
                abc_gen_date,
                lst_cycle_date,
                parent_pallet_id)
            VALUES
               (r_cd_pallet_dtls_to_recover.prod_id,             -- prod_id
                r_cd_pallet_dtls_to_recover.cust_pref_vendor,    -- cust_pref_vendor,
                r_cd_pallet_dtls_to_recover.rec_id,              -- rec_id
                r_cd_pallet_dtls_to_recover.rec_date,            -- rec_date        -- from INV_HIST
                r_cd_pallet_dtls_to_recover.inv_date,            -- inv_date        -- from INV_HIST
                r_cd_pallet_dtls_to_recover.mfg_date,            -- mfg_date
                r_cd_pallet_dtls_to_recover.exp_date,            -- exp_date
                r_cd_pallet_dtls_to_recover.carrier_id,          -- logi_loc,
                r_cd_pallet_dtls_to_recover.src_loc,             -- plogi_loc
                r_cd_pallet_dtls_to_recover.qty_alloc,           -- qoh
                r_cd_pallet_dtls_to_recover.inv_qty_alloc,       -- qty_alloc,      -- from INV_HIST
                r_cd_pallet_dtls_to_recover.inv_qty_planned,     -- qty_planned     -- from INV_HIST
                0,                                               -- min_qty
                'CDK',                                           -- status,
                r_cd_pallet_dtls_to_recover.abc,                 -- abc             -- from INV_HIST
                r_cd_pallet_dtls_to_recover.lot_id,              -- lot_id
                r_cd_pallet_dtls_to_recover.exp_ind,             -- exp_ind         -- from INV_HIST
                SYSDATE,                                         -- abc_gen_date
                SYSDATE,                                         -- lst_cycle_date
                r_cd_pallet_dtls_to_recover.parent_pallet_id);   -- parent_pallet_id

         --
         -- Create the RVP transaction.
         --
         insert_rvp_transaction(i_float_no => r_cd_pallet_dtls_to_recover.float_no,
                                i_seq_no   => r_cd_pallet_dtls_to_recover.seq_no);


         EXCEPTION                     --xxxxxxxxx finish error handling
            WHEN DUP_VAL_ON_INDEX THEN
               DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
               DBMS_OUTPUT.PUT_LINE(SQLERRM);
         END;
      END LOOP;  -- end float details loop

      --
      -- Delete the float details.    xxxx add log message
      --
      DELETE
        FROM float_detail fd
       WHERE fd.float_no = r_cd_pallet_to_recover.float_no;

      --
      -- Delete the floats.    xxxx add log message
      --
      DELETE
        FROM floats f
       WHERE f.float_no = r_cd_pallet_to_recover.float_no;

   END LOOP;     -- end float loop

   --
   -- Update the float and batch number for all the EI orders to null */
   --
   UPDATE cross_dock_pallet_xref
      SET float_no = NULL,
          batch_no = NULL,
          upd_user = 'SWMS',
          upd_date = SYSDATE
    WHERE sys_order_id IN (
                SELECT DISTINCT d.sys_order_id
                           FROM ordm m, ordd d, cross_dock_type cdk
                          WHERE m.route_no = i_route_no
                            AND m.order_id = d.order_id
                            AND m.cross_dock_type NOT IN ('S', 'X')
                            AND m.cross_dock_type = cdk.cross_dock_type);

   --
   -- Update the order status to RCV in cross dock reference table.
   --
   UPDATE cross_dock_xref
      SET status   = 'RCV',
          upd_date = SYSDATE
    WHERE sys_order_id IN
               (SELECT DISTINCT d.sys_order_id
                           FROM ordm m, ordd d, cross_dock_type cdk
                          WHERE m.route_no = i_route_no
                            AND m.order_id = d.order_id
                            AND m.cross_dock_type NOT IN ('S', 'X')
                            AND m.cross_dock_type = cdk.cross_dock_type);
   --
   -- Delete the CMU ORDD record.
   -- During order generation when ORDD.REMOTE_LOCAL_FLAG is 'B'
   -- an ORDD record for the OpCo pick for the qty to be filled from the OpCo.
   -- This ORDD record needs to be deleted.
   --
   DELETE FROM ordd od
    WHERE od.route_no               = i_route_no
      AND od.original_order_line_id IS NOT NULL
      AND EXISTS                                -- Plus this extra criteria.
           (SELECT 'x'
              FROM ordd od2
             WHERE od2.route_no      = od.route_no
               AND od2.order_id      = od.order_id
               AND od2.order_line_id = od.original_order_line_id);



   --
   -- Log ending the procedure.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Ending procedure' || l_parameters,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');


EXCEPTION
   WHEN gl_e_parameter_null THEN
      --
      -- i_route_no null
      --
      l_message := l_parameters || '  Parameter is null';
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => pl_exc.ct_data_error,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error, l_object_name || ': ' || l_message);
   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      l_message := l_parameters || '  Error';
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || l_message);
END recover_cross_dock_pallets;


END pl_cross_dock_order_processing;
/

show errors


CREATE OR REPLACE PUBLIC SYNONYM pl_cross_dock_order_processing FOR swms.pl_cross_dock_order_processing;
GRANT EXECUTE ON swms.pl_cross_dock_order_processing TO SWMS_USER;



