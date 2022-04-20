
CREATE OR REPLACE PACKAGE swms.pl_xdock_op_merge
AS
-----------------------------------------------------------------------------
-- Package Name:
--    pl_xdock_op_merge
--
-- Description:
--    This package has the procedure/functions, etc to merge the orders sent
--    from Site 1 into the Site 2 tables.
--       Staging Table            Merged Into
--       ----------------------------------------
--       XDOCK_ORDM_IN            ORDM
--       XDOCK_ORDD_IN            ORDD
--       XDOCK_FLOATS_IN          FlOATS
--       XDOCK_FLOAT_DETAIL_IN    FlOAT_DETAIL
--       XDOCK_ORDCW_IN           ORDCW
--
-- Processing the OP "IN" staging tables:
--
-- Order merge process:
--    If ORDM and ORDD are sent to Site 2 before the route is generated at Site 2:
--       - If and item XDOCK_ORDD does not exist in the PM table then a mesag eis logged and
--         processing stops.  The XDOCK_ORDM_IN and XDOCK_ORDD_IN record status is left at 'N.
--
--       - Merge XDOCK_ORDM_IN into ORDM--actually there is nothing to do other than update
--          XDOCK_ORDM.RECORD_STATUS to 'N'
--          because SUS Site 2 sends the ORDM record to SWMS Site 2.
--       - Merge XDOCK_ORDD_IN into ORDD.  Status will be NEW.
--    If ORDM and ORDD are sent to Site 2 after the route is generated at Site 2:
--       - ORDM status would be PND.  Change ORDM status from PND to OPN.
--       - Merge XDOCK_ORDD_IN into ORDD.  ORDD status will be OPN.
--
-- Float merge process:
--    If the matching records are not in ORDM and ORDD:
--       - A message is logged.
--       - The XDOCK_FLOATS_IN.RECORD_STATUS will be left at 'N'.
--       - The XDOCK_FLOAT_DETAIL_IN.RECORD_STATUS will be left at 'N'.
--
--    If Floats info is sent to Site 2 before the route is generated at Site 2:
--       - The floats info stays in the staging table.
--    If Float info is sent to Site 2 after the route is generated at Site 2:
--       - Merge XDOCK_FLOATS_IN into FLOATS.
--       - Merge XDOCK_FLOAT_DETAIL_IN into FLOAT_DETAIL.
--       - Merge XDOCK_ORDCW_IN into ORDCW.
--       - Create SLS data.
--
-- Order generation process for the 'X' orders:
--    If ORDM and ORDD are sent to Site 2 before the route is generated at Site 2:
--       - At the start of order generation merge XDOCK_ORDM_IN into ORDM--actually there
--         is nothing to do because SUS Site 2 sends the ORDM record.  ORDM status will be NEW.
--       - At the start of order generation merge XDOCK_ORDD_IN into ORDD.  ORDM status will NEW.
--    If ORDM and ORDD have not been sent to Site 2:
--       - Update ORDM status to PND.
--       - Nothing is done with the floats even if for some reason the floats info exists in the staging tables.
--    If floats info is sent to Site 2 before the route is generated at Site 2:
--       - At the start of order generation merge:
--            - XDOCK_FLOATS_IN into FLOATS.  Set pallet_pull to 'B'.   Need new float_no among other columns.
--            - XDOCK_FLOAT_DETAIL_IN into FLOAT_DETAIL.  Need new float_no among other columns.
--            - XDOCK_ORDCW_IN into ORDCW.  Set the order_id to the delivery document id.
--            - Create bulk pulls replenlst records for the cross dock pallets.
--     
/***************************************************************************
****************************************************************************
Populating Site 2 Relevant OP tables for the 'X' cross dock orders
from the "IN" staging tables.

Tables OP will populate at start of order generation for the "X' cross dock orders.
But only if Site 1 has sent the data.
   ORDD            using XDOCK_ORDD_IN          -- If not aready populated and Site 1 has sent the data.
                                                -- The ORDM record needs to exist.
   FLOATS          using XDOCK_FLOATS_IN        -- If Site 1 has sent the data.
                                                   Dependent on the corresponding records existing
                                                   in ORDM and ORDD and XDOCK_FLOAT_DETAIL_IN.
   FLOAT_DETAIL    using XDOCK_FLOAT_DETAIL_IN  -- If Site 1 has sent the data.
                                                   Dependent on the corresponding records existing
                                                   in ORDM and ORDD and XDOCK_FLOATS_IN.
   ORDCW           using XDOCK_ORDCW_IN         -- If Site has sent the data.
                                                   Dependent on the corresponding records existing
                                                   in XDOCK_FLOATS_IN.
****************************************************************************
***************************************************************************/
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--    07/16/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Created.
--
--    09/03/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Populate XDK replenlst record:
--                         site_from
--                         site_to
--
--    09/10/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      XDOCK_ORDCW_IN was not getting merged.
--
--                      ORDM piece count columns were not updated after orders merged.
--                      Update these ORDM columns after ORDD merge:
--                          d_pieces
--                          c_pieces
--                          d_pieces
--
--                      Handle a door number for the source location for the
--                      XDK replenlst task.  This means the putawaylst.dest_loc
--                      is a door and so we have a XDK task from the inbound
--                      door to the route door.
--
--                      Save the Site 1 floats.pallet_pull to floats.site_from_pallet_pull.
--                      Site 2 STS needs to know if the cross dock pallet was
--                      a pallet pull or bulk pull at Site 1.
--
--                      Save the Site 1 floats.fl_sel_type to floats.site_from_fl_sel_type.
--                      Site 2 STS needs to know the Site 1 sel type--NOR, UNI, PAL, etc.
--                      
--    09/21/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_float_seq_duplicating
--
--                      The floats.float_seq (this is the C1, C2, F1, F2, D1, D2 etc.)
--                      is assigned to a float during order generation. 
--                      The issue is if Site 1 sends the route data to Site 2 after the
--                      route is generated at Site 2 a new float_seq is not getting assigned.
--
--                      If the route was generated before Site 1 has sent the 
--                      floats info then:
--                         - floats.float_seq is assigned the next in line value.
--                         - floats.batch_no assigned float_batch_no_seq.NEXTVAL.
--
--    09/27/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Update XDOCK_ORDER_XREF.ROUTE_NO_FROM with the Site 1 route number
--                      when merging the Site 1 order/floats info into Site 2.
--                      XDOCK_ORDER_XREF has the delivery_document_id so the update
--                      will be:
--                         UPDATE xdock_order_xref x
--                            SET x.route_no_from from = <Site 1 route number from xdock_ordm_in>
--                          WHERE x.delivery_document_id = xdock_ordm_in.delivery_document_id of the record being processed.
--                            AND x.cross_dock_type = 'X'
--
--    09/30/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3578_Site_2_Merging_after_route_gen_assign_float_seq_based_on_Site_1_comp_code
--
--                      I procedure "merge_floats" by mistake I was passing to function "get_xdock_pallet_loc_for_float"
--                      "r_xdock_floats_in.door_area" instead of "r_xdock_floats_in.comp_code".  We need to use the comp_code
--                      as this designates the compartment code in the trailer the pallet is to be loaded--D, C or F.
--                      The door_area is the area of the door where the trailer is at.
--                      For example a cooler pallet can we loaded on a trailer at a freezer door so the door_area would be F and
--                      the comp_code would be C.
--
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3714_OP_Site_2_floats_door_area_sometimes_incorrect
--
--                      Modified procedure "merge_floats".
--
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--
--                      PIK transactions were not created for Site 2 cross dock pallets.
--                      Create procedure "create_pik_transactions" and add call to it
--                      in procedure "merge_floats".
--
--    11/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF-3833_Site_2_Do_not_merge_floats_if_route_not_generated
--
--                      During test at Site 2 OpCo 004 on Saturday 11/6/2021 floats merged
--                      into the ROUTE but the route status was 'NEW'.
--                      Tried several times to duplicate the issue but not yet able.
--                      We went ahead and added this check to cursor "c_xdock_floats_in":
--       AND fx.site_to_route_status    IN ('WAT', 'SHT', 'OPN')
--                      as floats should not be merged with route with 'NEW' status.
--
--
--    11/16/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0_Xdock_OPCOF-3567_Site_2_Order_recovery_xdock_orders
--
--                      Column "site_from_float_no" was added to the FLOATS table.
--                      Modify procedure "insert_floats_rec" to populate it.
--                      Having the Site 1 float_no in the floats table simplifies the
--                      order recovery process when a route is recoved at Site 2
--                      as the site_from_float_no can be used to easily identify the
--                      records in staging tables XDOCK_FLOATS_IN, XDOCK_FLOAT_DETAIL_IN
--                      and XDOCK_ORDCW_IN that need the record status set back to 'N'.
--
--                      When the floats merged after the route generated FLOATS.FL_METHOD_ID was
--                      the Site 1 method id instead of the Site 2 method id,
--                      Modified procedure "insert_floats_rec":
--                      Changed
--                         i_r_xdock_floats_in.fl_method_id
--                      to
--                         i_r_xdock_floats_in.site_to_fl_method_id
--
--                      When testing on rs1210b1 with route 7657 see this error in the
--                      SWMS_LOG table from procedure "create_pik_transactions":
--        i_route_no[7657] Error creating PIK transactions.  This will not stop processing.
--        ORA-01427: single-row subquery returns more than one row
--                      Found this happens when the route was recoved 2 or more times.
--                      To fix changed:
--       NVL((SELECT t2.trans_date FROM TRANS t2 WHERE t2.route_no = f.route_no AND t2.trans_type = 'RVT'), SYSDATE - 100)
--                      to
--       NVL((SELECT MAX(t2.trans_date) FROM TRANS t2 WHERE t2.route_no = f.route_no AND t2.trans_type = 'RVT'), SYSDATE - 100)
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
--    merge_orders (public)
--
-- Description:
--    This procedure merges the 'S' cross dock orders from Site 1 and put in
--    XDOCK_ORDM_IN and XDOCK_ORDD_IN into the Site 2 ORDM and ORDD tables.
--
-- Process flow:
--    - Validate the XDOCK_ORDM_IN record.  Validation:
--       - Check the xdock_ordm_in.delivery_document_id exists in ORDM with
--         cross dock type 'X'.
--       - The route status is: NEW, RCV OPN or SHT.
--
-- Verify i_delivery_document_id is a valid delivery document id
--    -- The delivery document id in XDOCK_ORDM_IN exists in ORDM.
--    -- The ORDM status is 'NEW' or 'PND'.
--       If not 'NEW' or 'PND' then set XDOCK_ORDM_IN to 'F' and do the same for XDOCK_ORDD_IN and XDOCK_ORDCW_IN.
--    -- The ORDM.CROSS_DOCK_TYPE IS 'X'.
--    -- The Site 2 route status is NEW, RCV, OPN or SHT.
--    -- It has not already been processed at Site 2--meaning...08/09/21 not sure yet.
--    -- There are corresponding ORDD records.  If not then log a mesaage and leave XDOCK_ORDM_IN.RECORD_STATUS at 'N'.
--
-- Merging ORDM is not actually a merge but rather a verification as the ORDM
-- record at Site 2is sent from SUS to SWMS but SUS sends no order details.
---------------------------------------------------------------------------
PROCEDURE merge_orders
   (
      i_batch_id              IN  xdock_ordd_in.batch_id%TYPE              DEFAULT NULL,
      i_delivery_document_id  IN  xdock_ordd_in.delivery_document_id%TYPE  DEFAULT NULL,
      i_route_no              IN  xdock_ordd_in.route_NO%TYPE              DEFAULT NULL
   );

---------------------------------------------------------------------------
-- Procedure:
--    merge_floats (public)
--
-- Description:
--    This procedure merges the 'S' cross dock floats sent from Site 1 into
--    the Site 2 main tables.
--
--    Site 2 Staging Table        Site 2 Main Table
--    -----------------------------------------------
--    XDOCK_FLOATS_IN             FLOATS
--    XDOCK_FLOAT_DETAIL_IN       FLOAT_DETAIL_IN
--    XDOCK_ORDCW_IN              ORDCW
--
-- Process flow:
--    - Validate the XDOCK_FLOATS_IN record.
--      Validation:
--       - Check the corresponding ORDM and ORDD records exist.
--         If not then log a mesaage and leave XDOCK_FLOATS.RECORD_STATUS at 'N'.
--         The XDOCK_FLOAT_DEAIL_IN and XDOCK_ORDCW_IN left as is.
--       - The ORDM.CROSS_DOCK_TYPE IS 'X'.
--       - The Site 2 route status is: NEW, RCV, OPN or SHT.
--         If not that fail all the records in in XDOCK_FLOATS_IN, XDOCK_FLOAT_DETAIL_IN and XDOCK_ORDCW_IN
--         for the Site 2 route.
--       - The ORDM status is 'NEW' or 'PND'.
--         If not 'NEW' or 'PND' then set XDOCK_FLOATS_IN to 'F' and do the same for XDOCK_FLOAT_DEAIL_IN and XDOCK_ORDCW_IN.
--       - The ORDM.CROSS_DOCK_TYPE IS 'X'.
--       - XDOCK_FLOATS_IN has corresponding XDOCK_FLOAT_DETAIL_IN records.
--       - It has not already been processed at Site 2--meaning...08/09/21 not sure yet.
--    - Insert into FLOATS.
--    - Insert into FLOAT_DETAIL for the float.
--    - Insert into ORDCW for the float.
--    - Insert XDK task(s).
---------------------------------------------------------------------------
PROCEDURE merge_floats
   (
      i_batch_id              IN xdock_ordd_in.batch_id%TYPE     DEFAULT NULL,    --  I don't think we need to go by batch id ????
      i_route_no              IN xdock_ordd_in.route_no%TYPE     DEFAULT NULL,
      i_delivery_document_id  IN ordm.delivery_document_id%TYPE  DEFAULT NULL
   );

---------------------------------------------------------------------------
-- Procedure:
--    process_xdock_ordm_in (public)
--
-- Description:
--    This procedure processes the records in staging tables XDOCK_ORDM_IN
--    and XDOCK_ORDD_IN that are in 'N' status.
---------------------------------------------------------------------------
PROCEDURE process_xdock_ordm_in;

---------------------------------------------------------------------------
-- Procedure:
--    process_xdock_floats_in (public)
--
-- Description:
--    This procedure process the records in staging tables XDOCK_FLOATS_IN
--    and XDOCK_FLOAT_DETAIL_ID that are in 'N' status.
--
-- Process flow:
--    - Validate the XDOCK_FLOATS_IN record.  Validation:
--       - The corresponding ORDM record and ORDD record(s) need to exist.
--       - It needs to have XDOCK_FLOAT_DETAIL_IN records.
--       - The route status is: NEW, RCV OPN or SHT.
--    - Insert into FLOATS
--    - Insert into FLOAT_DETAIL for the float.
---------------------------------------------------------------------------
PROCEDURE process_xdock_floats_in;


---------------------------------------------------------------------------
-- Procedure:
--    create_bulk_pull_tasks (public)
--
-- Description:
--    This procedure create the XDK bulk pull tasks for the Site 2
--    cross dock pallets for the specified route or xdock LP.
--
--    Records are inserted into REPLENLSTt.
--
-- Process flow:
--    - Select from floats for the specified route or parent LP
--      and the float has cross dock type of 'X'.
--    - If the pallet not yet receieved then do not create a XDK task.
--    - Check if XDK task aleady exist for the floats parent LP.
--    - If task does not exist then insert a XDK task into REPLENLST.
---------------------------------------------------------------------------
PROCEDURE create_bulk_pull_tasks
   (
      i_route_no                  IN  floats.route_no%TYPE             DEFAULT NULL,
      i_xdock_pallet_id           IN  floats.parent_pallet_id%TYPE     DEFAULT NULL,
      i_src_loc                   IN  loc.logi_loc%TYPE                DEFAULT NULL
   );


----------------------------------------------
-- has_all_data_sent_from_site_1  (public)
----------------------------------------------
FUNCTION has_all_data_sent_from_site_1
   (
      i_delivery_document_id  IN ordm.delivery_document_id%TYPE
   )
RETURN BOOLEAN;


---------------------------------------------------------------------------
-- Procedure:
--    merge_X_orders (public)
---------------------------------------------------------------------------
PROCEDURE merge_X_orders
   (
      i_route_no              IN  xdock_ordd_in.route_NO%TYPE
   );


---------------------------------------------------------------------------
-- Function:
--    get_xdock_pallet_loc_for_float (public)
--
-- Description:
--    This function returns location to use for the Site 2 cross dock pallet.
--
--    The FLOAT_DETAIl.SRC_LOC is set this.
--    The location is also used to determine the pick zone and selection
--    method group#, door area, etc.
---------------------------------------------------------------------------
FUNCTION get_xdock_pallet_loc_for_float
   (
      i_pallet_id  IN  putawaylst.pallet_id%TYPE,
      i_area       IN  pm.area%TYPE
   )
RETURN VARCHAR2;

---------------------------------------------------------------------------
-- Function:
--    does_xdk_task_exist (public)
--
-- Description:
--    This function determines if an XDK task exists for a cross dock pallet.
--    Site 2 has XDK tasks to bring the cross dock pallet to the outbound door.
---------------------------------------------------------------------------
FUNCTION does_xdk_task_exist
   (
      i_xdock_pallet_id  IN floats.xdock_pallet_id%TYPE
   )
RETURN BOOLEAN;

---------------------------------------------------------------------------
-- Procedure:
--    update_floats_after_merge (public)  (public only so atht it can be tested standalone)
--
-- Description:
--    This procedure updates relevant columns for Site 2 Xdock floats after merging.
--
--    Some floats columns need a value assigned if merging happens after the route is 
--    generated at Site 2.
--
--    Columms udated:
--       - FLOATS.FLOAT_SEQ    if null
---------------------------------------------------------------------------
PROCEDURE update_floats_after_merge
   (
      i_route_no        IN  route.route_no%TYPE
   );

---------------------------------------------------------------------------
-- Procedure:
--    create_pik_transactions (public)  (public only so that it can be tested standalone)
--
-- Description:
--    Site 2 - This procedure creates the PIK transaction for a the 'X' cross
--    dock pallets on a route.  Only one PIK transaction is created per 'X'
--    cross dock pallet.
--
--    Called during order generation and when the floats were merged after
--    the route was generated.
--
--    The trans.qty is the number of pieces on the pallet.
--    The trans.uom will always be 0.
--
--    The summing of float details is similar to the the query in
--    procedure "pl_xdock_op_merge.create_bulk_pull_tasks".
---------------------------------------------------------------------------
PROCEDURE create_pik_transactions
   (
      i_route_no  IN  route.route_no%TYPE
   );

END pl_xdock_op_merge;   -- end package spec
/



CREATE OR REPLACE PACKAGE BODY swms.pl_xdock_op_merge
AS
---------------------------------------------------------------------------
-- Private Global Variables
---------------------------------------------------------------------------

gl_pkg_name   VARCHAR2(30) := $$PLSQL_UNIT;   -- Package name.  Used in messages.

gl_e_parameter_null  EXCEPTION;  -- A required parameter to a procedure or function is null.



--------------------------------------------------------------------------
-- Private Constants
--------------------------------------------------------------------------

ct_application_function CONSTANT  VARCHAR2(30) := 'ORDER PROCESSING';


---------------------------------------------------------------------------
-- Private Cursors
---------------------------------------------------------------------------

CURSOR c_xdock_floats_in(cp_route_no    route.route_no%TYPE)
IS
SELECT
       fx.batch_id,
       fx.sequence_number,
       fx.batch_no,
       fx.batch_seq,
       fx.float_no,
       fx.float_no            new_float_no,   -- Holding place.  A new float# is required since the float# is unique only within the OpCo.
       fx.float_seq,
       fx.route_no,
       fx.b_stop_no,
       fx.e_stop_no,
       fx.record_status,
       fx.float_cube,
       fx.group_no,
       fx.merge_group_no,
       fx.merge_seq_no,
       fx.merge_loc,
       fx.zone_id,
       fx.equip_id,
       fx.comp_code,
       fx.split_ind,
       fx.pallet_pull,
       fx.pallet_id,
       fx.home_slot,
       fx.drop_qty,
       fx.door_area,
       fx.single_stop_flag,
       fx.status,
       fx.ship_date,
       fx.parent_pallet_id,
       fx.fl_method_id,
       fx.fl_sel_type,
       fx.fl_opt_pull,
       fx.truck_no,
       fx.door_no,
       fx.cw_collect_status,
       fx.cw_collect_user,
       fx.fl_no_of_zones,
       fx.fl_multi_no,
       fx.fl_sel_lift_job_code,
       fx.mx_priority,
       fx.is_sleeve_selection,
       fx.add_date,
       fx.add_user,
       fx.upd_date,
       fx.upd_user,
       --
       fx.site_to_route_no,
       fx.cross_dock_type,
       fx.site_to_truck_no,
       fx.site_to_route_status,
       fx.site_to_method_id,
       fx.site_from,
       fx.site_to,
       fx.site_to_d_door,
       fx.site_to_c_door,
       fx.site_to_f_door,
       fx.site_to_door_no
  FROM
       v_xdock_floats_in fx
 WHERE
       fx.site_to_route_no        = cp_route_no       -- Process  the specified route.
   AND fx.record_status           = 'N'               -- Only unprocessed records.   08/26/21 xxxxxxx hhmmmm  about checking the status
   AND fx.site_to_route_status    IN ('WAT', 'SHT', 'OPN')  -- 11/07/21  Brian Bent Added this condition
 ORDER BY 
       fx.batch_id,
       fx.sequence_number;


CURSOR c_xdock_float_detail_in(cp_batch_id   xdock_float_detail_in.batch_id%TYPE,
                               cp_float_no   xdock_floats_in.float_no%TYPE)
IS
SELECT
       fdx.sequence_number,
       fdx.batch_id,
       fdx.float_no,
       fdx.float_no             new_float_no,   -- Holding place.  A new float# is required since the float# is unique only within the OpCo.
       fdx.seq_no,
       fdx.zone,
       fdx.stop_no,
       fdx.record_status,
       fdx.prod_id,
       fdx.src_loc,
       fdx.multi_home_seq,
       fdx.uom,
       fdx.qty_order,
       fdx.qty_alloc,
       fdx.merge_alloc_flag,
       fdx.merge_loc,
       fdx.status,
       fdx.order_id,
       fdx.site_to_order_id,
       fdx.order_line_id,
       fdx.cube,
       fdx.copy_no,
       fdx.merge_float_no,
       fdx.merge_seq_no,
       fdx.cust_pref_vendor,
       fdx.clam_bed_trk,
       fdx.route_no,
       fdx.site_to_route_no,
       fdx.route_batch_no,
       fdx.alloc_time,
       fdx.rec_id,
       fdx.mfg_date,
       fdx.exp_date,
       fdx.lot_id,
       fdx.carrier_id,
       fdx.order_seq,
       fdx.sos_status,
       fdx.cool_trk,
       fdx.catch_wt_trk,
       fdx.item_seq,
       fdx.qty_short,
       fdx.st_piece_seq,
       fdx.selector_id,
       fdx.bc_st_piece_seq,
       fdx.short_item_seq,
       fdx.sleeve_id,
       fdx.put_dest_loc
  FROM
       v_xdock_float_detail_in fdx
 WHERE
       fdx.batch_id                = cp_batch_id        -- Process specified batch id.
   AND fdx.float_no                = cp_float_no        -- Process specified float.
   AND fdx.record_status           = 'N'                -- Only unprocessed records.   08/26/21 xxxxxx  hmmmm about checking the status
 ORDER BY 
       fdx.seq_no;

CURSOR c_xdock_ordcw_in(cp_batch_id   xdock_float_detail_in.batch_id%TYPE,
                        cp_float_no   xdock_floats_in.float_no%TYPE)
IS
SELECT
       v_ordcw_x.sequence_number        sequence_number,
       v_ordcw_x.batch_id               batch_id,
       v_ordcw_x.record_status          record_status,
       v_ordcw_x.route_no               route_no,                  -- This is the Site 1 route number.
       v_ordcw_x.site_to_route_no       site_to_route_no,
       v_ordcw_x.order_id               order_id,                  -- This is the Site 1 order id. 
       v_ordcw_x.site_to_order_id       site_to_order_id,
       v_ordcw_x.order_line_id          order_line_id,
       v_ordcw_x.seq_no                 seq_no,
       v_ordcw_x.prod_id                prod_id,
       v_ordcw_x.cust_pref_vendor       cust_pref_vendor,
       v_ordcw_x.catch_weight           catch_weight,
       v_ordcw_x.cw_type                cw_type,
       v_ordcw_x.uom                    uom,
       v_ordcw_x.cw_float_no            cw_float_no,            -- This is the Site 1 float number.
       v_ordcw_x.cw_float_no            site_2_cw_float_no,     -- Holding place for the Site 2 float number.  A new float# is required since the float# is
                                                                -- unique only within an OpCo.
       v_ordcw_x.cw_scan_method         cw_scan_method,
       v_ordcw_x.order_seq              order_seq,
       v_ordcw_x.case_id                case_id,
       v_ordcw_x.cw_kg_lb               cw_kg_lb,
       v_ordcw_x.pkg_short_used         pkg_short_used
  FROM
       v_xdock_ordcw_in v_ordcw_x
 WHERE
       v_ordcw_x.batch_id                = cp_batch_id        -- Process specified batch id.
   AND v_ordcw_x.cw_float_no             = cp_float_no        -- Process specified float.
   AND v_ordcw_x.record_status           = 'N'                -- Only unprocessed records.   08/26/21 xxxxxx  hmmmm about checking the status
 ORDER BY 
       v_ordcw_x.order_id,
       v_ordcw_x.order_line_id,
       v_ordcw_x.seq_no;


---------------------------------------------------------------------------
-- Private Type Declarations
---------------------------------------------------------------------------


---------------------------------------------------------------------------
-- Private Modules
---------------------------------------------------------------------------

----------------------------------------------
-- is_valid_delivery_document_id  (private)
----------------------------------------------
FUNCTION is_valid_delivery_document_id
   (
      i_delivery_document_id  IN ordm.delivery_document_id%TYPE
   )
RETURN BOOLEAN
IS
   l_object_name        VARCHAR2(30) := 'is_valid_delivery_document_id';

   l_count              PLS_INTEGER;
BEGIN
   --
   -- The DDID must exist in ORDM at Site 2.
   --
   SELECT COUNT(*)
     INTO l_count
     FROM ordm
    WHERE ordm.delivery_document_id = i_delivery_document_id;

   IF (l_count = 0) THEN
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 
                         'TABLE=ordm  ACTION=SELECT'
                      || '  KEY=[' || i_delivery_document_id || '](i_delivery_document_id)'
                      || '  MESSAGE="DDID not found."',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END is_valid_delivery_document_id;


----------------------------------------------
-- is_valid_float (private)
----------------------------------------------
FUNCTION is_valid_float
   (
      i_float_no  IN xdock_floats_in.float_no%TYPE
   )
RETURN BOOLEAN
IS
BEGIN
   return true;
END is_valid_float;


---------------------------------------------------------------------------
-- Function:
--    does_xdk_task_exist (public)
--
-- Description:
--    This function determines if an XDK task exists for a cross dock pallet.
--    Site 2 has XDK tasks to bring the cross dock pallet to the outbound door.
--
-- Parameters:
--    i_xdock_pallet_id
--
-- Return Values:
--    TRUE  - XDK task exists for cross dock pallet.
--    TRUE  - XDK task does not exists for cross dock pallet.
--    
-- Called By:
--
-- Exceptions Raised:
--    None.  Error logged and FALSE returned.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION does_xdk_task_exist
   (
      i_xdock_pallet_id  IN floats.xdock_pallet_id%TYPE
   )
RETURN BOOLEAN
IS
   l_object_name        VARCHAR2(30) := 'does_xdk_task_exist';

   l_count  PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM replenlst
    WHERE type         = 'XDK'
      AND pallet_id    = i_xdock_pallet_id;

   IF (l_count = 0) THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
EXCEPTION
   --
   -- Oracle error.  Log a message and return FALSE.  Do not stop processing.
   --
   WHEN OTHERS THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred  i_xdock_pallet_id[' || i_xdock_pallet_id || ']'
                              || ' This will not stop processing.  Returning FALSE.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      RETURN FALSE;
END does_xdk_task_exist;

-- yyyyy
----------------------------------------------
-- is_cross_dock_pallet_rcv_on_xn
----------------------------------------------
FUNCTION is_cross_dock_pallet_rcv_on_xn
   (
      i_xdock_pallet_id  IN floats.xdock_pallet_id%TYPE
   )
RETURN BOOLEAN
IS
   l_count  PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM putawaylst p
    WHERE p.pallet_id    = i_xdock_pallet_id;

   IF (l_count = 0) THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END is_cross_dock_pallet_rcv_on_xn;


---------------------------------------------------------------------------
-- Procedure:
--    update_orders (private)
--
-- Description:
--    This procedure updates relevant ORDM and ORDD columns after the
--    Site 1 orders merged into Site 2.
--
--    Columms udated:
--       - ORDM.D_PIECES
--       - ORDM.C_PIECES
--       - ORDM.F_PIECES
--
-- Parameters:
--    i_route_no   - The route number to process.
--
-- Called by:
--    pl_xdock_op_merge.??????? xxxxxxxxx
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/20/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE update_orders
   (
      i_route_no    IN  route.route_no%TYPE
   )
IS
   l_object_name   VARCHAR2(30)   := 'update_orders';
   l_message       VARCHAR2(512);                  -- Message buffer

   l_update_count      PLS_INTEGER;                -- Work area

BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure (i_route_no[' || i_route_no || '])'
         || '  This procedure updates relevant columns in ORDM and ORDD for the specified route after Site 1 orders merged into Site 2.';

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
   -- Check the parameters.
   --
   IF (i_route_no IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Update ORDM piece counts for the specified route.
   --
   UPDATE ordm m
      SET (m.d_pieces, m.c_pieces, m.f_pieces) =
                (SELECT SUM(CASE pm.area
                            WHEN 'D' THEN TRUNC(d.qty_ordered / pm.spc) + MOD(d.qty_ordered, spc)
                            ELSE 0
                            END) dry_pieces,
                        --
                        SUM(CASE pm.area
                            WHEN 'C' THEN TRUNC(d.qty_ordered / pm.spc) + MOD(d.qty_ordered, spc)
                            ELSE 0
                            END) cooler_pieces,
                        --
                        SUM(CASE pm.area
                            WHEN 'F' THEN TRUNC(d.qty_ordered / pm.spc) + MOD(d.qty_ordered, spc)
                            ELSE 0
                            END) freezer_pieces
                   FROM
                        ordd d,
                        pm
                  WHERE
                        d.order_id           = m.order_id
                    AND pm.prod_id           = d.prod_id
                    AND pm.cust_pref_vendor  = d.cust_pref_vendor)
   WHERE
         m.route_no = i_route_no;

   --
   -- Log update count.
   --
   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'After update of ORDM d_pieces, c_pieces, f_pieces  Number of records updated: ' || SQL%ROWCOUNT,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');


   --
   -- Log ending procedure
   --
   l_message := 'Ending procedure (i_route_no[' || i_route_no || '])';

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
   WHEN gl_e_parameter_null THEN
      --
      -- Paramater is null.  Log a message but do not stop processing.
      --
      l_message := '(i_route_no[' || i_route_no || '])'
                   || '  Parameter is null.  This will not stop processing.';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      l_message := '(i_route_no[' || i_route_no || '])'
                   || '  Error in update of ORDM.  This will not stop processing.';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

END update_orders;


---------------------------------------------------------------------------
-- Procedure:
--    merge_order_details (private)
--
-- Description:
--    This procedure merges the 'S' cross dock order details sent from Site 1 
--    in XDOCK_ORDD_IN into the Site 2 ORDD.
--
-- Process flow:
--    - Validate the XDOCK_ORDD_IN record.  Validation:
--       - Check the xdock_ordm_in.delivery_document_id exists in ORDM with
--         cross dock type 'X'.
--       - The route status is: NEW, RCV OPN or SHT.
--    - If the ORDD record already exists and thee route status is NEW or RCV
--      then ORDD record is deleted then inserted.
--    - If the ORDD record already exists and thee route status is not NEW or RCV
--      then the xdock_ordd_in.order_id status is set to 'F'.  ORDD it left alone.
--
--
-- ORDD Table Column Mapping:
-- OP will need to create this record at start of order generation.
--
-- Name                                 Null?    Type
-- ------------------------------------ -------- -------------------------------------------------------------------------------------------------------------
-- ORDER_ID                             NOT NULL VARCHAR2(14 CHAR)             Set to ordm.order_id
-- ORDER_LINE_ID                        NOT NULL NUMBER(3)                     xdock_ordd_in.order_line_id           Site 1 value
-- PROD_ID                              NOT NULL VARCHAR2(9 CHAR)              xdock_ordd_in.prod_id                 Site 1 value
-- CUST_PREF_VENDOR                     NOT NULL VARCHAR2(10 CHAR)             xdock_ordd_in.cust_pref_vendor        Site 1 value
-- LOT_ID                                        VARCHAR2(30 CHAR)             xdock_ordd_in.lot_id                  Site 1 value
-- STATUS                                        VARCHAR2(3 CHAR)              xdock_ordd_in.status                  Site 1 value but if Site 1 is SHT use OPN at Site 2
-- QTY_ORDERED                          NOT NULL NUMBER(7)                     xdock_ordd_in.qty_ordered             Site 1 value
-- QTY_SHIPPED                                   NUMBER(7)                     xdock_ordd_in.qty_shipped             Site 1 value
-- UOM                                           NUMBER(2)                     xdock_ordd_in.order_line_id           Site 1 value
-- WEIGHT                                        NUMBER(9,2)                   xdock_ordd_in.order_line_id           Site 1 value
-- PARTIAL                                       VARCHAR2(1 CHAR)              xdock_ordd_in.order_line_id           Site 1 value
-- PAGE                                          VARCHAR2(4 CHAR)              xdock_ordd_in.order_line_id           Site 1 value
-- INCK_KEY                                      VARCHAR2(5 CHAR)              xdock_ordd_in.order_line_id           Site 1 value
-- SEQ                                           NUMBER(8)                     xdock_ordd_in.order_line_id           Site 1 value
-- AREA                                          VARCHAR2(1 CHAR)              xdock_ordd_in.order_line_id           Site 1 value
-- ROUTE_NO                                      VARCHAR2(10 CHAR)             Set to Site 2 route number.
-- STOP_NO                                       NUMBER(7,2)                   xdock_ordd_in.stop_no                 Site 1 value
-- QTY_ALLOC                                     NUMBER(7)                     xdock_ordd_in.qty_alloc               Site 1 value
-- ZONE_ID                                       VARCHAR2(5 CHAR)              Set to Site 2 pick zone for the default rule 14 location.
--
-- PALLET_PULL                                   VARCHAR2(1 CHAR)              xdock_ordd_in.pallet_pull             Site 1 value  This is null for 5 OpCos I checked.
--                                                                                                                                 Apparently this column is not used.
-- SYS_ORDER_ID                                  NUMBER(10)                    xdock_ordd_in.sys_order_id            Site 1 value
-- SYS_ORDER_LINE_ID                             NUMBER(5)                     xdock_ordd_in.sys_order_line_id       Site 1 value
-- WH_OUT_QTY                                    NUMBER(7)                     xdock_ordd_in.wh_out_qty              Site 1 value
-- REASON_CD                                     VARCHAR2(3 CHAR)              xdock_ordd_in.reason_cd               Site 1 value
-- PK_ADJ_TYPE                                   VARCHAR2(3 CHAR)              xdock_ordd_in.pk_adj_type             Site 1 value
-- PK_ADJ_DT                                     DATE                          xdock_ordd_in.pk_adj_dt               Site 1 value
-- USER_ID                                       VARCHAR2(30 CHAR)             xdock_ordd_in.user_id                 Site 1 value
-- CW_TYPE                                       VARCHAR2(1 CHAR)              xdock_ordd_in.cw_type                 Site 1 value
-- QA_TICKET_IND                                 VARCHAR2(1 CHAR)              xdock_ordd_in.qa_ticket_ind           Site 1 value
-- DELETED                                       VARCHAR2(3 CHAR)              xdock_ordd_in.deleted                 Site 1 value
-- PCL_FLAG                                      VARCHAR2(1 CHAR)              xdock_ordd_in.pcl_flag                Site 1 value
-- PCL_ID                                        VARCHAR2(14 CHAR)             xdock_ordd_in.pcl_id                  Site 1 value
-- ORIGINAL_UOM                                  NUMBER(2)                     xdock_ordd_in.original_uom            Site 1 value
-- DOD_CUST_ITEM_BARCODE                         VARCHAR2(13 CHAR)             xdock_ordd_in.dod_cust_item_barcode   Site 1 value
-- DOD_FIC                                       VARCHAR2(3 CHAR)              xdock_ordd_in.dod_fic                 Site 1 value
-- PRODUCT_OUT_QTY                               NUMBER                        xdock_ordd_in.product_out_qty         Site 1 value
-- MASTER_ORDER_ID                               VARCHAR2(25)                  xdock_ordd_in.master_order_id         Site 1 value
-- REMOTE_LOCAL_FLG                              VARCHAR2(1)                   xdock_ordd_in.remote_local_flg        Site 1 value
-- REMOTE_QTY                                    NUMBER(7)                     xdock_ordd_in.remote_qty              Site 1 value
-- RDC_PO_NO                                     VARCHAR2(16)                  xdock_ordd_in.rdc_po_no               Site 1 value
-- QTY_ORDERED_ORIGINAL                          NUMBER(7)                     xdock_ordd_in.qty_ordered_original    Site 1 value
-- ORIGINAL_ORDER_LINE_ID                        NUMBER(3)                     xdock_ordd_in.original_order_line_id  Site 1 value
-- ORIGINAL_SEQ                                  NUMBER(8)                     xdock_ordd_in.original_seq            Site 1 value
-- ADD_DATE                                      DATE                          Defaults to sysdate.
-- ADD_USER                                      VARCHAR2(30 CHAR)             Defaults to current user.
-- UPD_DATE                                      DATE                          Populated by DB trigger.
-- UPD_USER                                      VARCHAR2(30 CHAR)             Populated by DB trigger.
--
--
-- Parameters:
--    i_batch_id  - Site 1 batch id 
--    i_order_id  - Site 1 order id
--
-- Called by:
--    ???
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE merge_order_details
   (
      i_batch_id    IN xdock_ordd_in.batch_id%TYPE,
      i_order_id    IN xdock_ordd_in.order_id%TYPE
   )
IS
   l_object_name            VARCHAR2(30) := 'merge_order_details';

   l_cross_dock_pallet_location       loc.logi_loc%TYPE;        -- "default" location to use for the cross dock pallet used in determining the pick zone for ordd.zone_id
   l_first_record_bln                 BOOLEAN;                  -- Work area
   l_pick_zone                        zone.zone_id%TYPE;        -- Pick zone to use for ORDD.ZONE_ID.  We cannot use the Site 1 value.

   CURSOR c_xdock_ordd_in
                   (cp_batch_id    xdock_ordd_in.batch_id%TYPE,
                    cp_order_id    xdock_ordd_in.order_id%TYPE)
   IS
   SELECT
          d.sequence_number,
          d.batch_id,
          d.order_id,
          ordm.order_id            site_to_order_id,
          d.order_line_id,
          d.prod_id,
          d.cust_pref_vendor,
          d.lot_id,
          d.status,
          d.record_status,
          d.qty_ordered,
          d.qty_shipped,
          d.uom,
          d.weight,
          d.partial,
          d.page,
          d.inck_key,
          d.seq,
          d.area,
          d.route_no,
          ordm.route_no            site_to_route_no,
          d.stop_no,
          d.qty_alloc,
          d.zone_id,
          d.pallet_pull,
          d.sys_order_id,
          d.sys_order_line_id,
          d.wh_out_qty,
          d.reason_cd,
          d.pk_adj_type,
          d.pk_adj_dt,
          d.user_id,
          d.cw_type,
          d.qa_ticket_ind,
          d.deleted,
          d.pcl_flag,
          d.pcl_id,
          d.original_uom,
          d.dod_cust_item_barcode,
          d.dod_fic,
          d.product_out_qty,
          d.master_order_id,
          d.remote_local_flg,
          d.remote_qty,
          d.rdc_po_no,
          d.qty_ordered_original,
          d.original_order_line_id,
          d.original_seq,
          d.delivery_document_id
     FROM
          xdock_ordd_in d,
          ordm  ordm            -- At this point in proceessng the 'X' cross dock order will be in ORDM.
                                -- NOTE: The delivery_document_id needs to be unique in ORDM with 'X' cross dock type.
    WHERE
          ordm.delivery_document_id = d.delivery_document_id    -- Do not process w/o the ORDM record.
      AND ordm.cross_dock_type      = 'X'                       -- ordm.cross_dock_type needs to be 'X'.
      --
      AND d.batch_id                = cp_batch_id
      AND d.order_id                = cp_order_id
      --
      AND d.record_status           = 'N'                       -- Only unprocessed detail records.
      --
      AND EXISTS                                                -- Do not process w/o the xdock_ordm_in record.
              (SELECT 'x'
                 FROM xdock_ordm_in h
                WHERE h.batch_id             = d.batch_id
                  AND h.delivery_document_id = d.delivery_document_id)
    ORDER BY 
          d.batch_id,
          d.sequence_number;
  
   ---------------------------------------------------------
   -- Local function to return the pick zone for a location.
   -- Not sure if we have an existing function somewhere.
   ---------------------------------------------------------
   FUNCTION get_pick_zone(i_location  loc.logi_loc%TYPE)
   RETURN VARCHAR2
   IS
      l_pick_zone   zone.zone_id%TYPE;
   BEGIN
      BEGIN
         SELECT z.zone_id
           INTO l_pick_zone
           FROM lzone lz, zone z
          WHERE lz.logi_loc = i_location
            AND z.zone_id   = lz.zone_id
            AND z.zone_type = 'PIK'
            AND ROWNUM      <= 1;    -- Failsafe in case lzone is messed up.
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            l_pick_zone := NULL;   -- Calling program needs to decide what to do.
         WHEN OTHERS THEN
            RAISE;
      END;

      RETURN  l_pick_zone;
   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Oracle error. Log mesage and return null.
         -- The Calling program needs to decide what to do with a null value.
         --
         pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'TABLE=lzone,zone  ACTION=SELECT'
                      || '  KEY=[' || i_location || '](i_location)'
                      || '  MESSAGE="Did not find the location.  Return NULL.'
                      || '  The calling program needs to decide what to do with a null value.',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

         RETURN NULL;
   END get_pick_zone;

 
BEGIN
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || '(i_batch_id[' ||  i_batch_id || ']'
                      || ' i_order_id[' ||  i_order_id || '])',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   l_first_record_bln := TRUE;

   --
   -- Insert the ORDD record(s).
   --
   FOR r_xdock_ordd_in IN c_xdock_ordd_in(i_batch_id, i_order_id)
   LOOP
      dbms_output.put_line(l_object_name || ' in ordd insert loop');

      --
      -- Use the first record to get the pick zone to use for ordd.zone_id.  We cannot use the Site 1 pick zone.
      --
      IF (l_first_record_bln = TRUE) THEN
         --
         -- Need the "default" location for the area.   The area is the pm.area.
         --
         l_cross_dock_pallet_location := get_xdock_pallet_loc_for_float(NULL, r_xdock_ordd_in.area);

         -- 
         -- Call a location function to return the location pick zone--not sure if we have existing function somewhere
         -- 
         l_pick_zone := NVL(get_pick_zone(l_cross_dock_pallet_location), 'UNKP');

         l_first_record_bln := FALSE;

         dbms_output.put_line(l_object_name || '  l_cross_dock_pallet_location[' || l_cross_dock_pallet_location || ']'
                      || '  l_pick_zone[' || l_pick_zone || ']');
      END IF;

      --
      -- Log message if ordd.status from Site 1 is SHT.  At Site 2 the ordd.status cannot be SHT so it is switched to OPN.
      --
      IF (r_xdock_ordd_in.status = 'SHT') THEN
         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Site 1 route_no['   || r_xdock_ordd_in.route_no               || ']'
                               ||  '  Site 2 route_no['    || r_xdock_ordd_in.site_to_route_no       || ']'
                               ||  '  Site 1 order_id['    || r_xdock_ordd_in.order_id               || ']'
                               ||  '  Site 2 order_id['    || r_xdock_ordd_in.site_to_order_id       || ']'
                               ||  '  order_line_id['      || TO_CHAR(r_xdock_ordd_in.order_line_id) || ']'
                               ||  '  Site 1 ordd.status[' || r_xdock_ordd_in.status                 || ']'
                               || '   The ordd.status from Site 1 is SHT.  At Site 2 the ordd.status cannot be SHT'
                               || ' so it is switched to OPN.',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      END IF;

      BEGIN
         INSERT INTO ordd
                   (order_id,
                    order_line_id,
                    prod_id,
                    cust_pref_vendor,
                    lot_id,
                    status,
                    qty_ordered,
                    qty_shipped,
                    uom,
                    weight,
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
                    wh_out_qty,
                    reason_cd,
                    pk_adj_type,
                    pk_adj_dt,
                    user_id,
                    cw_type,
                    qa_ticket_ind,
                    deleted,
                    pcl_flag,
                    pcl_id,
                    original_uom,
                    dod_cust_item_barcode,
                    dod_fic,
                    product_out_qty,
                    master_order_id,
                    remote_local_flg,
                    remote_qty,
                    rdc_po_no,
                    qty_ordered_original,
                    original_order_line_id,
                    original_seq)
             SELECT  
                    r_xdock_ordd_in.site_to_order_id,
                    r_xdock_ordd_in.order_line_id,
                    r_xdock_ordd_in.prod_id,
                    r_xdock_ordd_in.cust_pref_vendor,
                    r_xdock_ordd_in.lot_id,
                    DECODE(r_xdock_ordd_in.status, 'SHT', 'OPN', r_xdock_ordd_in.status) status,   -- If SHT at Site 1 show OPN at Site 2.  Rule is Site 2 is never SHT.
                    r_xdock_ordd_in.qty_ordered,
                    r_xdock_ordd_in.qty_shipped,
                    r_xdock_ordd_in.uom,
                    r_xdock_ordd_in.weight,
                    r_xdock_ordd_in.partial,
                    r_xdock_ordd_in.page,
                    r_xdock_ordd_in.inck_key,
                    r_xdock_ordd_in.seq,
                    r_xdock_ordd_in.area,
                    r_xdock_ordd_in.site_to_route_no,
                    r_xdock_ordd_in.stop_no,
                    r_xdock_ordd_in.qty_alloc,
                    l_pick_zone,
                    r_xdock_ordd_in.pallet_pull,
                    r_xdock_ordd_in.sys_order_id,
                    r_xdock_ordd_in.sys_order_line_id,
                    r_xdock_ordd_in.wh_out_qty,
                    r_xdock_ordd_in.reason_cd,
                    r_xdock_ordd_in.pk_adj_type,
                    r_xdock_ordd_in.pk_adj_dt,
                    r_xdock_ordd_in.user_id,
                    r_xdock_ordd_in.cw_type,
                    r_xdock_ordd_in.qa_ticket_ind,
                    r_xdock_ordd_in.deleted,
                    r_xdock_ordd_in.pcl_flag,
                    r_xdock_ordd_in.pcl_id,
                    r_xdock_ordd_in.original_uom,
                    r_xdock_ordd_in.dod_cust_item_barcode,
                    r_xdock_ordd_in.dod_fic,
                    r_xdock_ordd_in.product_out_qty,
                    r_xdock_ordd_in.master_order_id,
                    r_xdock_ordd_in.remote_local_flg,
                    r_xdock_ordd_in.remote_qty,
                    r_xdock_ordd_in.rdc_po_no,
                    r_xdock_ordd_in.qty_ordered_original,
                    r_xdock_ordd_in.original_order_line_id,
                    r_xdock_ordd_in.original_seq
               FROM DUAL;

            dbms_output.put_line(l_object_name || ' after insert sql%rowcount: ' || SQL%ROWCOUNT);
      EXCEPTION
         WHEN OTHERS THEN
            pl_log.ins_msg
                (i_msg_type         => pl_log.ct_warn_msg,
                 i_procedure_name   => l_object_name,
                 i_msg_text         => 
                               'TABLE=ordd  ACTION=INSERT'
                            || '  r_xdock_ordd_in.site_to_order_id[' || r_xdock_ordd_in.site_to_order_id || ']'
                            || '  r_xdock_ordd_in.order_line_id['    || r_xdock_ordd_in.order_line_id    || ']'
                            || '  MESSAGE="Insert error inside loop. Going to next record."',
                 i_msg_no           => SQLCODE,
                 i_sql_err_msg      => SQLERRM,
                 i_application_func => ct_application_function,
                 i_program_name     => gl_pkg_name,
                 i_msg_alert        => 'N');
      END;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                           '(i_batch_id[' ||  i_batch_id || ']'
                        || ' i_order_id[' ||  i_order_id || '])'
                        || ' Oracle error. Raise exception',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);

END merge_order_details;


---------------------------------------------------------------------------
-- Procedure:
--    log_counts (private)
--
-- Description:
--     Log record counts for debug purposes
--
-- Parameters:
--    i_delivery_document_id
--
-- Called by:
--    ???
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      Card: R47-xdock-
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE log_counts
   (
      i_delivery_document_id  IN xdock_ordm_in.delivery_document_id%TYPE
   )
IS
   l_object_name      VARCHAR2(30) := 'log_counts';

   l_ordm_count       PLS_INTEGER;
   l_s_cdt_count      PLS_INTEGER;
   l_x_cdt_count      PLS_INTEGER;

   l_ordd_count       PLS_INTEGER;
BEGIN
   SELECT COUNT(*),
          NVL(SUM(DECODE(ordm.cross_dock_type, 'S', 1, 0)), 0) s_cdt_count,
          NVL(SUM(DECODE(ordm.cross_dock_type, 'X', 1, 0)), 0) x_cdt_count
     INTO l_ordm_count,
          l_s_cdt_count,
          l_x_cdt_count
     FROM ordm
    WHERE ordm.delivery_document_id = 'i_delivery_document_id';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                            'i_delivery_document_id['    || i_delivery_document_id || ']'
                         || '  ordm count['              || TO_CHAR(l_ordm_count)  || ']'
                         || '  ordm S cross dock count[' || TO_CHAR(l_s_cdt_count) || ']'
                         || '  ordm X cross dock count[' || TO_CHAR(l_x_cdt_count) || ']',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log message.  Do not stop processing.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                         'TABLE=ordm  ACTION=SELECT'
                      || '  KEY=[' || i_delivery_document_id || '](i_delivery_document_id)'
                      || '  MESSAGE="Error getting counts.  This is not a fatal error.  Continue processing."',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');
END log_counts;

---------------------------------------------------------------------------
-- Procedure:
--    insert_floats_rec (private)
--
-- Description:
--    This procedure inserts the XDOCK_FLOATS_IN record into FLOATS.
--    Site 2 order generation will populate the xdock floats if Site 1
--    has sent the floats info to Site 2 before the route is generated at Site 2.
--
--    If the info is sent from Site 1 to Site 2 after the route is generated
--    at Site 2 then the a cron job will populate Site 2.
--
--
--    Column Mapping:
-- Name                            Null?     Type
-- ------------------------------- --------- ------------------------------------------------------------------------------------------------------------------------------
-- BATCH_NO                                 NUMBER(9)                     Set to 0 if the route not generated at Site 2.  The order generation process will populate it.
--                                                                        If the route was already generated then set to float_batch_no_seq.NEXTVAL.
--                                                                        Save original for debugging purposes ???
--
-- BATCH_SEQ                                NUMBER(2)                     Set to 1 since the cross dock pallets will be bulk pulls.
-- FLOAT_NO                        NOT NULL NUMBER(9)                     Set to float_no_seq.NEXTVAL.
--                                                                        Save original for debugging purposes ???
--
-- FLOAT_SEQ                                VARCHAR2(4 CHAR)              This is the C1, C2, etc.
--                                                                        If the route is not generated at Site 2 then the order generation process
--                                                                        will populated it.
--                                                                        If the route is already generated at Site 2 then use the next in line.
--
-- ROUTE_NO                                 VARCHAR2(10 CHAR)             Set to Site 2 route number.  Save original for debugging purposes ???
-- B_STOP_NO                                NUMBER(7,2)                   xdock_floats_in.b_stop_no             Site 1 value
-- E_STOP_NO                                NUMBER(7,2)                   xdock_floats_in.e_stop_no             Site 1 value
-- FLOAT_CUBE                               NUMBER(12,4)                  xdock_floats_in.float_cube            Site 1 value
-- GROUP_NO                                 NUMBER(3)                     Set to valid Site 2 group_no based on the location of the pallet and sel method at Site 2.
-- MERGE_GROUP_NO                           NUMBER(3)                     Set to NULL
-- MERGE_SEQ_NO                             NUMBER(3)                     Set to NULL
-- MERGE_LOC                                VARCHAR2(10 CHAR)             Always set to '???' at Site 2.
-- ZONE_ID                                  VARCHAR2(5 CHAR)              Set to valid Site 2 pick zone based on the location of the pallet and sel method at Site 2.
-- EQUIP_ID                                 VARCHAR2(10 CHAR)             Set to valid Site 2 equip_id based on the location of the pallet and sel method at Site 2.
-- COMP_CODE                                VARCHAR2(1 CHAR)              Comp code based on the location of the pallet and sel method at Site 2.
-- SPLIT_IND                                VARCHAR2(1 CHAR)              xdock_floats_in.split_ind             Site 1 value
-- PALLET_PULL                              VARCHAR2(1 CHAR)              Always set to 'B' at Site 2
-- PALLET_ID                                VARCHAR2(18 CHAR)             xdock_floats_in.pallet_id             Site 1 value
-- HOME_SLOT                                VARCHAR2(10 CHAR)             xdock_floats_in.home_slot             Site 1 value
-- DROP_QTY                                 NUMBER(9)                     xdock_floats_in.drop_qty              Site 1 value
-- DOOR_AREA                                VARCHAR2(1 CHAR)              xdock_floats_in.door_area             Site 1 value
-- SINGLE_STOP_FLAG                         VARCHAR2(1 CHAR)              xdock_floats_in.single_stop_flag      Site 1 value
-- STATUS                                   VARCHAR2(3 CHAR)              xdock_floats_in.status                Site 1 value
-- SHIP_DATE                                DATE                          xdock_floats_in.ship_date             Site 1 value
-- PARENT_PALLET_ID                         VARCHAR2(18 CHAR)             xdock_floats_in.parent_pallet_id      Site 1 value
-- FL_METHOD_ID                             VARCHAR2(10 CHAR)             Set to Site 2 route.method_id
-- FL_SEL_TYPE                              VARCHAR2(3)                   Always set to 'PAL' at Site 2
-- FL_OPT_PULL                              VARCHAR2(1 CHAR)              xdock_floats_in.fl_opt_pull           Site 1 value
-- TRUCK_NO                                 VARCHAR2(10 CHAR)             Set to Site 2 truck_no
-- DOOR_NO                                  NUMBER(3)                     Set to Site 2 door_no
-- CW_COLLECT_STATUS                        CHAR(1 CHAR)                  xdock_floats_in.cw_collect_status     Site 1 value
-- CW_COLLECT_USER                          VARCHAR2(30 CHAR)             xdock_floats_in.cw_collect_user       Site 1 value
-- FL_NO_OF_ZONES                           NUMBER(3)                     xdock_floats_in.fl_no_of_zones        Site 1 value
-- FL_MULTI_NO                              NUMBER(3)                     xdock_floats_in.fl_multi_no           Site 1 value
-- FL_SEL_LIFT_JOB_CODE                     VARCHAR2(6)                   xdock_floats_in.fl_sel_lift_job_code  Site 1 value
-- MX_PRIORITY                              NUMBER(2)                     xdock_floats_in.mx_priority           Site 1 value
-- IS_SLEEVE_SELECTION                      VARCHAR2(1 CHAR)              xdock_floats_in.is_sleeve_selection   Site 1 value
-- SITE_FROM                                VARCHAR2(5 CHAR)              xdock_floats_in.site_from             Site 1 value
-- SITE_TO                                  VARCHAR2(5 CHAR)              xdock_floats_in.site_to               Site 1 value
-- CROSS_DOCK_TYPE                          VARCHAR2(2 CHAR)              Set to 'X'
-- XDOCK_PALLET_ID                          VARCHAR2(18 CHAR)             xdock_float_in.parent_pallet_id       Site 1 value
-- SITE_FROM_PALLET_PULL                                                  xdock_floats_in.pallet_pull           Site 1 value.  We need to know the Site 1 value for STS.
-- SITE_FROM_FL_SEL_TYPE                                                  xdock_floats_in.sel_type              Site 1 value.  We need to know the Site 1 value for STS.
--
--
-- Parameters:
--    i_r_xdock_floats_in  - the XDOCK_FLOATS_IN record to insert into FLOATS.
--
--
-- Called by:
--    merge_floats
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE insert_floats_rec(i_r_xdock_floats_in  IN c_xdock_floats_in%ROWTYPE)
IS
   l_object_name  VARCHAR2(30) := 'insert_floats_rec';
BEGIN
   INSERT INTO floats
         (batch_no,
          batch_seq,
          float_no,
          float_seq,
          route_no,
          b_stop_no,
          e_stop_no,
          float_cube,
          group_no,
          merge_group_no,
          merge_seq_no,
          merge_loc,
          zone_id,
          equip_id,
          comp_code,
          split_ind,
          pallet_pull,
          pallet_id,
          home_slot,
          drop_qty,
          door_area,
          single_stop_flag,
          status,
          ship_date,
          parent_pallet_id,
          fl_method_id,
          fl_sel_type,
          fl_opt_pull,
          truck_no,
          door_no,
          cw_collect_status,
          cw_collect_user,
          fl_no_of_zones,
          fl_multi_no,
          fl_sel_lift_job_code,
          mx_priority,
          is_sleeve_selection,
          xdock_pallet_id,
          cross_dock_type,
          site_from,
          site_to,
          site_from_pallet_pull,
          site_from_fl_sel_type,
          site_from_float_no)
   SELECT
          DECODE(i_r_xdock_floats_in.site_to_route_status, 'NEW', 0, 'RCV', 0, float_batch_no_seq.NEXTVAL)   batch_no,
          1                                        batch_seq,
          i_r_xdock_floats_in.new_float_no         float_no,
          NULL                                     float_seq,       -- Site 2 Order generation will assign a new one if the Site 2 route not generated.
                                                                    -- If the Site 2 route already generated then the next one in line is used.
          i_r_xdock_floats_in.site_to_route_no     route_no,
          i_r_xdock_floats_in.b_stop_no,
          i_r_xdock_floats_in.e_stop_no,
          i_r_xdock_floats_in.float_cube,
          i_r_xdock_floats_in.group_no,
          NULL                                     merge_group_no,  -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          NULL                                     merge_seq_no,    -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          '???'                                    merge_loc,       -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          i_r_xdock_floats_in.zone_id,
          i_r_xdock_floats_in.equip_id,
          i_r_xdock_floats_in.comp_code,
          i_r_xdock_floats_in.split_ind,
          'B'                                      pallet_pull,     -- Site 2 cross dock pallets always a bulk pull
          i_r_xdock_floats_in.pallet_id,
          i_r_xdock_floats_in.home_slot,
          i_r_xdock_floats_in.drop_qty,
          i_r_xdock_floats_in.door_area,
          i_r_xdock_floats_in.single_stop_flag,
          i_r_xdock_floats_in.status,
          i_r_xdock_floats_in.ship_date,
          i_r_xdock_floats_in.parent_pallet_id,
          i_r_xdock_floats_in.site_to_method_id      fl_method_id,     -- 11/16/21 Brian Bent Was "i_r_xdock_floats_in.fl_method_id".  We want to use the Site 2 method id.
          'PAL'                                      fl_sel_type,      -- Site 2 cross dock pallets always a bulk pull
          i_r_xdock_floats_in.fl_opt_pull,
          i_r_xdock_floats_in.site_to_truck_no       truck_no,
          i_r_xdock_floats_in.site_to_door_no        door_no,
          i_r_xdock_floats_in.cw_collect_status,
          i_r_xdock_floats_in.cw_collect_user,
          i_r_xdock_floats_in.fl_no_of_zones,
          i_r_xdock_floats_in.fl_multi_no,
          i_r_xdock_floats_in.fl_sel_lift_job_code,
          i_r_xdock_floats_in.mx_priority,
          i_r_xdock_floats_in.is_sleeve_selection,
          i_r_xdock_floats_in.parent_pallet_id       xdock_pallet_id,   -- 09/02/21 because xdock_pallet_id is not in the staging table 
                                                                        -- but parent_pallet_id should have the same value.
          'X'                                        cross_dock_type,
          i_r_xdock_floats_in.site_from,
          i_r_xdock_floats_in.site_to,
          i_r_xdock_floats_in.pallet_pull            site_from_pallet_pull,
          i_r_xdock_floats_in.fl_sel_type            site_from_fl_sel_type,
          i_r_xdock_floats_in.float_no               site_from_float_no
     FROM DUAL;

   dbms_output.put_line(l_object_name || ' after insert sql%rowcount: ' || SQL%ROWCOUNT);

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error. Log message.  Raise exception.
      --
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 
                         'TABLE=floats  ACTION=INSERT'
                      || '  Site 2 float number[' || i_r_xdock_floats_in.new_float_no || ']'
                      || '  Site 1 float number[' || i_r_xdock_floats_in.float_no     || ']'
                      || '  MESSAGE="Insert error.  This is a fatal error."',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ' Error inserting');
END insert_floats_rec;


---------------------------------------------------------------------------
-- Procedure:
--    insert_float_detail_rec (private)
--
-- Description:
--    This procedure inserts the XDOCK_FLOAT_DETAIL_IN record into FLOAT_DETAIL.
--
--
--    Column Mapping:
-- Name                            Null?    Type
-- ------------------------------- --------- ----------------------------------------------------------------------------------------
-- FLOAT_NO                        NOT NULL NUMBER(9)                     Set to FLOATS float_no
--                                                                        Save original for debugging purposes ???
-- SEQ_NO                          NOT NULL NUMBER(3)                     xdock_float_detail_in.seq_no            Site 1 value
-- ZONE                            NOT NULL NUMBER(2)                     xdock_float_detail_in.zone              Site 1 value
-- STOP_NO                         NOT NULL NUMBER(7,2)                   xdock_float_detail_in.stop_no           Site 1 value
-- PROD_ID                         NOT NULL VARCHAR2(9 CHAR)              xdock_float_detail_in.prod_id           Site 1 value
--
-- SRC_LOC                                  VARCHAR2(10 CHAR)             Set to the location of the cross
--                                                                        dock pallet at Site 2.  If the cross dock pallet has not
--                                                                        been received at Site 2 then it will be set to a rule id 4 location.
--                                                                        Once the pallet is received then float_detail.src_loc is updated
--                                                                        to the location of the pallet.
--
-- MULTI_HOME_SEQ                           NUMBER(5)                     xdock_float_detail_in.multi_home_seq    Site 1 value
-- UOM                                      NUMBER(2)                     xdock_float_detail_in.uom               Site 1 value
-- QTY_ORDER                                NUMBER(9)                     xdock_float_detail_in.qty_order         Site 1 value
-- QTY_ALLOC                                NUMBER(9)                     xdock_float_detail_in.qty_alloc         Site 1 value
-- MERGE_ALLOC_FLAG                         VARCHAR2(1 CHAR)              Set to 'X'
-- MERGE_LOC                                VARCHAR2(10 CHAR)             Set to NULL
-- STATUS                          NOT NULL VARCHAR2(3 CHAR)              xdock_float_detail_in.status            Site 1 value
-- ORDER_ID                                 VARCHAR2(14 CHAR)             Set to ordm.order_id
-- ORDER_LINE_ID                            NUMBER(3)                     xdock_float_detail_in.order_line_id     Site 1 value
-- CUBE                                     NUMBER(12,4)                  xdock_float_detail_in.cube              Site 1 value
-- COPY_NO                                  NUMBER(3)                     xdock_float_detail_in.copy_no           Site 1 value
-- MERGE_FLOAT_NO                           NUMBER(9)                     Set to NULL
-- MERGE_SEQ_NO                             NUMBER(3)                     Set to NULL
-- CUST_PREF_VENDOR                NOT NULL VARCHAR2(10 CHAR)             xdock_float_detail_in.cust_pref_vendor  Site 1 value
-- CLAM_BED_TRK                             VARCHAR2(1 CHAR)              xdock_float_detail_in.clam_bed_trk      Site 1 value
-- ROUTE_NO                                 VARCHAR2(10 CHAR)             Site 2 route number
-- ROUTE_BATCH_NO                           NUMBER                        NULL    09/15/20 This column never populated
-- ALLOC_TIME                               DATE                          xdock_float_detail_in.alloc_time        Site 1 value
-- REC_ID                                   VARCHAR2(12 CHAR)             xdock_float_detail_in.rec_id            Site 1 value
-- MFG_DATE                                 DATE                          xdock_float_detail_in.mfg_date          Site 1 value
-- EXP_DATE                                 DATE                          xdock_float_detail_in.exp_date          Site 1 value
-- LOT_ID                                   VARCHAR2(30 CHAR)             xdock_float_detail_in.lot_id            Site 1 value
-- CARRIER_ID                               VARCHAR2(18 CHAR)             xdock_float_detail_in.carrier_id        Site 1 value
-- ORDER_SEQ                                NUMBER(8)                     xdock_float_detail_in.order_seq         Site 1 value
-- SOS_STATUS                               VARCHAR2(1 CHAR)              xdock_float_detail_in.sos_status        Site 1 value
-- COOL_TRK                                 VARCHAR2(1 CHAR)              xdock_float_detail_in.cool_trk          Site 1 value
-- CATCH_WT_TRK                             VARCHAR2(1 CHAR)              xdock_float_detail_in.catch_wt_trk      Site 1 value
-- ITEM_SEQ                                 NUMBER(3)                     xdock_float_detail_in.item_seq          Site 1 value
-- QTY_SHORT                                NUMBER(3)                     xdock_float_detail_in.qty_short         Site 1 value
-- ST_PIECE_SEQ                             NUMBER(3)                     xdock_float_detail_in.st_piece_seq      Site 1 value
-- SELECTOR_ID                              VARCHAR2(10 CHAR)             xdock_float_detail_in.selector_id       Site 1 value
-- BC_ST_PIECE_SEQ                          NUMBER(3)                     xdock_float_detail_in.bc_st_piece_seq   Site 1 value
-- SHORT_ITEM_SEQ                           NUMBER(4)                     xdock_float_detail_in.short_item_seq    Site 1 value
-- SLEEVE_ID                                VARCHAR2(11 CHAR)             xdock_float_detail_in.sleeve_id         Site 1 value
--
--
-- Parameters:
--    i_r_xdock_float_detail_in  - the float detail record to insert
--
-- Called by:
--    merge_floats
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE insert_float_detail_rec(i_r_xdock_float_detail_in  IN  c_xdock_float_detail_in%ROWTYPE)
IS
   l_object_name    VARCHAR2(30)  := 'insert_float_detail_rec';
   l_message        VARCHAR2(512);                               --  Message buffer
BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure'
                   || '  batch_id['         || i_r_xdock_float_detail_in.batch_id                || ']'
                   || '  Site 1 float_no['  || TO_CHAR(i_r_xdock_float_detail_in.float_no)       || ']'
                   || '  Site 2 float_no['  || TO_CHAR(i_r_xdock_float_detail_in.new_float_no)   || ']'
                   || '  fd src_loc['       ||  i_r_xdock_float_detail_in.src_loc                || ']'
                   || '  put_dest_loc['     ||  i_r_xdock_float_detail_in.put_dest_loc           || ']'
                   || '  This procedure inserts the float_detail record.';

   pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   INSERT INTO float_detail
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
          alloc_time,
          rec_id,
          mfg_date,
          exp_date,
          lot_id,
          carrier_id,
          order_seq,
          sos_status,
          cool_trk,
          catch_wt_trk,
          item_seq,
          qty_short,
          st_piece_seq,
          selector_id,
          bc_st_piece_seq,
          short_item_seq,
          sleeve_id)
   SELECT
          i_r_xdock_float_detail_in.new_float_no              float_no,
          i_r_xdock_float_detail_in.seq_no,
          i_r_xdock_float_detail_in.zone,
          i_r_xdock_float_detail_in.stop_no,
          i_r_xdock_float_detail_in.prod_id,
          NVL(i_r_xdock_float_detail_in.put_dest_loc, i_r_xdock_float_detail_in.src_loc)   src_loc,
          i_r_xdock_float_detail_in.multi_home_seq,
          i_r_xdock_float_detail_in.uom,
          i_r_xdock_float_detail_in.qty_order,
          i_r_xdock_float_detail_in.qty_alloc,
          'X'                                                 merge_alloc_flag,  -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          NULL                                                merge_loc,         -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          i_r_xdock_float_detail_in.status,
          i_r_xdock_float_detail_in.site_to_order_id,
          i_r_xdock_float_detail_in.order_line_id,
          i_r_xdock_float_detail_in.cube,
          i_r_xdock_float_detail_in.copy_no,
          NULL                                                merge_float_no,  -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          NULL                                                merge_seq_no,    -- Site 2 cross dock pallets never a merge pick regardless if they were a merge pick at Site 1
          i_r_xdock_float_detail_in.cust_pref_vendor,
          i_r_xdock_float_detail_in.clam_bed_trk,
          i_r_xdock_float_detail_in.site_to_route_no,
          NULL                                                route_batch_no,   -- This always null everywhere
          i_r_xdock_float_detail_in.alloc_time,
          i_r_xdock_float_detail_in.rec_id,
          i_r_xdock_float_detail_in.mfg_date,
          i_r_xdock_float_detail_in.exp_date,
          i_r_xdock_float_detail_in.lot_id,
          i_r_xdock_float_detail_in.carrier_id,
          i_r_xdock_float_detail_in.order_seq,
          i_r_xdock_float_detail_in.sos_status,
          i_r_xdock_float_detail_in.cool_trk,
          i_r_xdock_float_detail_in.catch_wt_trk,
          i_r_xdock_float_detail_in.item_seq,
          i_r_xdock_float_detail_in.qty_short,
          i_r_xdock_float_detail_in.st_piece_seq,
          i_r_xdock_float_detail_in.selector_id,
          i_r_xdock_float_detail_in.bc_st_piece_seq,
          i_r_xdock_float_detail_in.short_item_seq,
          i_r_xdock_float_detail_in.sleeve_id
    FROM DUAL;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_fatal_msg,
                i_procedure_name   => 'l_object_name',
                i_msg_text         => 'TABLE=float_detail  ACTION=INSERT'
                     || '  batch_id['         || i_r_xdock_float_detail_in.batch_id                || ']'
                     || '  Site 1 float_no['  || TO_CHAR(i_r_xdock_float_detail_in.float_no)       || ']'
                     || '  Site 2 float_no['  || TO_CHAR(i_r_xdock_float_detail_in.new_float_no)   || ']'
                     || '  Error inserting into FLOAT_DETAIL from XDOCK_FLOAT_DETAIL_IN'
                     || '  This is a fatal error.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

   RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ' Error inserting');
END insert_float_detail_rec;


---------------------------------------------------------------------------
-- Procedure:
--    insert_ordcw_rec (private)
--
-- Description:
--    This procedure inserts the XDOCK_ORDCW_IN record(s) sent from Site 1 into Site 2 ORDCW.
--    for the specified batch and float.
--
--
--    Column Mapping:
-- Name                            Null?    Type
-- ------------------------------- --------- ----------------------------------------------------------------------------------------
--  ORDER_ID                       NOT NULL VARCHAR2(14 CHAR)         Set to ordm.order_id             Site 2 order id.
--  ORDER_LINE_ID                  NOT NULL NUMBER(3)                 xdock_ordcw_in.order_line_id     Site 1 value.
--  SEQ_NO                         NOT NULL NUMBER(4)                 xdock_ordcw_in.seq_no            Site 1 value.
--  PROD_ID                                 VARCHAR2(9 CHAR)          xdock_ordcw_in.prod_id           Site 1 value.
--  CUST_PREF_VENDOR                        VARCHAR2(10 CHAR)         xdock_ordcw_in.cust_pref_vendor  Site 1 value.
--  CATCH_WEIGHT                            NUMBER(9,3)               xdock_ordcw_in.seq_no            Site 1 value.
--  CW_TYPE                                 VARCHAR2(1 CHAR)          xdock_ordcw_in.seq_no            Site 1 value.
--  UOM                                     NUMBER(1)                 xdock_ordcw_in.seq_no            Site 1 value.
--  CW_FLOAT_NO                             NUMBER(7)                 Set to FLOATS float_no           Site 2 float number.
--                                                                    Save original for debugging purposes ???
--  CW_SCAN_METHOD                          CHAR(1 CHAR)              xdock_ordcw_in.cw_scan_method    Site 1 value.
--  ORDER_SEQ                               NUMBER(8)                 xdock_ordcw_in.order_seq         Site 1 value.
--  CASE_ID                                 NUMBER(13)                This is a virtual column based on order_seq and seq_no. 
--                                                                    So leave it out of the insert stmt.
--  CW_KG_LB                                NUMBER(9,3)               xdock_ordcw_in.cw_kg_lp          Site 1 value.
--  PKG_SHORT_USED                          CHAR(1 CHAR)              xdock_ordcw_in.pkg_short_used    Site 1 value.
--
-- Parameters:
--    i_r_xdock_ordcw_in  - the ORDCW record to insert
--
-- Called by:
--    merge_floats
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    09/06/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Created.
---------------------------------------------------------------------------
PROCEDURE insert_ordcw_rec(i_r_xdock_ordcw_in  IN  c_xdock_ordcw_in%ROWTYPE)
IS
   l_object_name  VARCHAR2(30) := 'insert_ordcw_rec';
BEGIN
   INSERT INTO ordcw
         (
          order_id,
          order_line_id,
          seq_no,
          prod_id,
          cust_pref_vendor,
          catch_weight,
          cw_type,
          uom,
          cw_float_no,
          cw_scan_method,
          order_seq,
          cw_kg_lb,
          pkg_short_used
         )
   SELECT
          i_r_xdock_ordcw_in.site_to_order_id         order_id,
          i_r_xdock_ordcw_in.order_line_id            order_line_id,
          i_r_xdock_ordcw_in.seq_no                   seq_no,
          i_r_xdock_ordcw_in.prod_id                  prod_id,
          i_r_xdock_ordcw_in.cust_pref_vendor         cust_pref_vendor,
          i_r_xdock_ordcw_in.catch_weight             catch_weight,
          i_r_xdock_ordcw_in.cw_type                  cw_type,
          i_r_xdock_ordcw_in.uom                      uom,
          i_r_xdock_ordcw_in.site_2_cw_float_no       cw_float_no,
          i_r_xdock_ordcw_in.cw_scan_method           cw_scan_method,
          i_r_xdock_ordcw_in.order_seq                order_seq,
          i_r_xdock_ordcw_in.cw_kg_lb                 cw_kg_lp,
          i_r_xdock_ordcw_in.pkg_short_used           pkg_short_used
    FROM DUAL;

EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => '  TABLE=ordcw  ACTION=INSERT'
                       || '  site_to_order_id[' || i_r_xdock_ordcw_in.site_to_order_id || ']'
                       || '  order_line_id['    || i_r_xdock_ordcw_in.order_line_id    || ']'
                       || '  seq_no['           || i_r_xdock_ordcw_in.seq_no           || ']'
                       || '  MESSAGE="Error inserting into ORDCW.  This is a fatal error."',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ' Error inserting');

END insert_ordcw_rec;


---------------------------------------------------------------------------
-- Public Modules
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Function:
--    has_all_data_sent_from_site_1 (public)
--
-- Description:
--    This function returns TRUE if all the OP data hase been sent from
--    Site 1 for the specified delivery document id.
--
-- Parameters:
--    i_delivery_document_id
--
-- Return Values:
--    TRUE    
--    FALSE
--    
-- Called By:
--    xxxx
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION has_all_data_sent_from_site_1
   (
      i_delivery_document_id  IN ordm.delivery_document_id%TYPE
   )
-- xxxxxxxxxx add more checks/logging
RETURN BOOLEAN
IS
   l_object_name                 VARCHAR2(30) := 'has_all_data_sent_from_site_1';

   l_ordm_in_count               PLS_INTEGER;
   l_ordd_in_count               PLS_INTEGER;
   l_ordd_in_seq_count           PLS_INTEGER;
   l_float_in_count              PLS_INTEGER;
   l_fd_in_order_seq_count       PLS_INTEGER;
BEGIN
   SELECT COUNT(DISTINCT ordm_in.delivery_document_id),
          COUNT(ordd_in.delivery_document_id),
          COUNT(DISTINCT ordd_in.seq),
          COUNT(DISTINCT f_in.float_no),
          COUNT(DISTINCT fd_in.order_seq)
     INTO
          l_ordm_in_count,
          l_ordd_in_count,
          l_ordd_in_seq_count,
          l_float_in_count,
          l_fd_in_order_seq_count
     FROM
          xdock_ordd_in           ordd_in,
          xdock_ordm_in           ordm_in,
          xdock_floats_in         f_in,
          xdock_float_detail_in   fd_in
    WHERE
          ordm_in.delivery_document_id         = i_delivery_document_id
      AND ordd_in.delivery_document_id     (+) = ordm_in.delivery_document_id
      AND fd_in.order_seq                  (+) = ordd_in.seq
      AND f_in.float_no                    (+) = fd_in.float_no;
      --
--    AND ordm_in.record_status    = 'N'
--    AND ordd_in.record_status    = 'N'
--    AND f_in.record_status   (+) = 'N'       -- xxxxx hmm about checking record status
--    AND fd_in.record_status  (+) = 'N';      -- xxxxx hmm about checking record status


   IF (    l_ordm_in_count         > 0
       AND l_ordd_in_count         > 0
       AND l_ordd_in_seq_count     > 0
       AND l_float_in_count        > 0
       AND l_fd_in_order_seq_count > 0)
   THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 
                    'i_delivery_document_id[' || i_delivery_document_id || ']',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, gl_pkg_name || '.' || l_object_name || ': ' || SQLERRM);

END has_all_data_sent_from_site_1;


---------------------------------------------------------------------------
-- Procedure:
--    merge_X_orders (public)
--
-- Description:
--    This procedure merges the 'X' cross dock orders onto the specified
--    Site 2 route for orders in NEW status.
--
--    Called at beginning of order generation.
--    This call is at the start of order generation to handle the situation where the
--    user generates the route before the cron job has a chance to do the merging.
--
--    The DDID (delivery document id) needs to exist in XDOCK_ORDD_IN.
--    If not then ORDM.STATUS is set to 'PND'.
--
--    Merging consists of taking the records from staging table XDOCK_ORDD_IN
--    For the Site 2 route and copying to ORDD.
--
--    Merging ORDM is not actually a merge but rather a verification as the ORDM
--    record at Site 2 is sent from SUS to SWMS but SUS sends no order details.
--
--    Example of what the XDOCK_ORDM_IN records can look like
--    batch_id  sequence_number  order_id  rote_no    site_to_route_no
  
--
-- Parameters:
--    i_route_no    -- Merge 'X' orders on this Site 2 route.
--
-- Called by:
--    pl_order_proc.sql
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/24/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE merge_X_orders
   (
      i_route_no              IN  xdock_ordd_in.route_NO%TYPE
   )
IS
   l_object_name  VARCHAR2(30) := 'merge_X_orders';

   --
   -- This cursor selects the 'X' cross dock orders on the Site 2 route.
   -- Procedssing is done by DDID (delivery document id).
   -- If the DDID is found in XDOCK_ORDM_IN in 'N' status and there are
   -- matching XDOCK_ORDD_IN records in 'N' status then ecords will be insert into ORDD.
   --
   CURSOR c_x_orders(cp_route_no   ordm.route_no%TYPE)
   IS
   SELECT
          m.route_no,
          m.order_id,
          m.cross_dock_type,
          m.delivery_document_id
     FROM
          ordm m
    WHERE
          m.route_no        = cp_route_no
      AND m.status          = 'NEW'
      AND m.cross_dock_type = 'X'        -- 08/2021 Brian Bent  Had left this out
    ORDER BY 
          m.delivery_document_id;
BEGIN
   FOR r_x_orders in c_x_orders(i_route_no)
   LOOP
      BEGIN
         SAVEPOINT sp_x_order;

         pl_log.ins_msg
             (i_msg_type         => pl_log.ct_info_msg,
              i_procedure_name   => l_object_name,
              i_msg_text         => 'In loop processing delivery document id[' || r_x_orders.delivery_document_id || ']...',
              i_msg_no           => NULL,
              i_sql_err_msg      => NULL,
              i_application_func => ct_application_function,
              i_program_name     => gl_pkg_name,
              i_msg_alert        => 'N');
   
         merge_orders(i_delivery_document_id  => r_x_orders.delivery_document_id);
      EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK TO sp_x_order;

            pl_log.ins_msg
                (i_msg_type         => pl_log.ct_info_msg,
                 i_procedure_name   => l_object_name,
                 i_msg_text         =>
                               'Error occurred processing delivery_document_id[' || r_x_orders.delivery_document_id || '].'
                            || '  Rollback to save point.',
                 i_msg_no           => NULL,
                 i_sql_err_msg      => NULL,
                 i_application_func => ct_application_function,
                 i_program_name     => gl_pkg_name,
                 i_msg_alert        => 'N');
      END;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log message.  Rollback to save point.
      -- Update ORDM.STATUS to 'PND' for the 'X' cross dock orders on the route if the status
      -- status is 'NEW'.
      --
      ROLLBACK;

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_warn_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         =>
                         'i_route_no[' || i_route_no || ']'
                      || '  MESSAGE="Error merging.  Rollback.'
                      || '  What will happen is the Site 2 cross dock orders ordm.status will be put in PND status."',
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

END merge_X_orders;

---------------------------------------------------------------------------
-- Procedure:
--    merge_orders (public)
--
-- Description:
--    This procedure merges the 'S' cross dock orders from Site 1 in
--    XDOCK_ORDM_IN and XDOCK_ORDD_IN tables into the Site 2 ORDM and ORDD tables.
--
-- Process flow:
--    - Validate the XDOCK_ORDM_IN record.  Validation:
--       - Check the xdock_ordm_in.delivery_document_id exists in ORDM with
--         cross dock type 'X'.
--       - The route status is: NEW, RCV OPN or SHT.
--
-- Verify i_delivery_document_id is a valid delivery document id
--    -- The delivery document id in XDOCK_ORDM_IN exists in ORDM.
--    -- The ORDM status is 'NEW' or 'PND'.
--       If not 'NEW' or 'PND' then set XDOCK_ORDM_IN to 'F' and do the same for XDOCK_ORDD_IN and XDOCK_ORDCW_IN.
--    -- The ORDM.CROSS_DOCK_TYPE IS 'X'.
--    -- The Site 2 route status is NEW, RCV, OPN or SHT.
--    -- It has not already been processed at Site 2--meaning...08/09/21 not sure yet.
--    -- There are corresponding ORDD records.  If not then log a mesaage and leave XDOCK_ORDM_IN.RECORD_STATUS at 'N'.
--
-- Merging ORDM is not actually a merge but rather a verification as the ORDM
-- record at Site 2is sent from SUS to SWMS but SUS sends no order details.
--
-- Parameters:
--    i_batch_id              
--    i_delivery_document_id
--    i_route_no                  -- Merge 'X' orders on this route.
--
-- Called by:
--    ???
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
----------------------------------------------------------------------------
PROCEDURE merge_orders
   (
      i_batch_id              IN  xdock_ordd_in.batch_id%TYPE              DEFAULT NULL,   -- xxxxx  don't have ths parameter
      i_delivery_document_id  IN  xdock_ordd_in.delivery_document_id%TYPE  DEFAULT NULL,
      i_route_no              IN  xdock_ordd_in.route_NO%TYPE              DEFAULT NULL     -- xxxxx  don't have ths parameter
   )
IS
   l_object_name  VARCHAR2(30) := 'merge_orders';
   l_message      VARCHAR2(512);                   -- Message buffer

   CURSOR c_xdock_ordm_in
                         (cp_batch_id              xdock_ordm_in.batch_id%TYPE,
                          cp_delivery_document_id  ordm.delivery_document_id%TYPE,
                          cp_route_no              ordm.route_no%TYPE)
   IS
   SELECT
          h.sequence_number,
          h.batch_id,
          h.route_no,
          h.order_id,
          h.delivery_document_id,
          h.cross_dock_type
     FROM
          xdock_ordm_in h            -- xxxxx hmmm add record locking ????
    WHERE
         (
            (    h.batch_id                = NVL(cp_batch_id, h.batch_id)                            -- Process by batch
              AND h.delivery_document_id   = NVL(cp_delivery_document_id, h.delivery_document_id))   -- Process by single DDID
          OR 
             h.delivery_document_id IN                                                               -- Process by route
                    (SELECT ordm.delivery_document_id
                       FROM ordm
                      WHERE ordm.route_no = cp_route_no)
         )
      --
      AND h.record_status   = 'N'      -- Only unprocessed records.
      AND h.cross_dock_type = 'S'      -- Should be 'S' as xdock_ordm_in came from Site 1.
      --
      -- The DDID must exist in ORDM at Site 2.
      AND EXISTS
              (SELECT 'x'
                 FROM ordm
                WHERE ordm.delivery_document_id = h.delivery_document_id)
      --
    ORDER BY 
          SUBSTR(h.batch_id, 1, INSTR(h.batch_id, '-')),
          LPAD(SUBSTR(h.batch_id, INSTR(h.batch_id, '-') + 1), 20, '0'),
          h.batch_id,
          h.sequence_number;
BEGIN
   dbms_output.put_line(l_object_name || '  i_delivery_document_id[' ||  i_delivery_document_id || ']'
                 || '  i_batch_id[' ||  i_batch_id || ']');

   IF (has_all_data_sent_from_site_1(i_delivery_document_id) = TRUE)
   THEN

      FOR r_xdock_ordm_in IN c_xdock_ordm_in
                                   (i_batch_id,
                                    i_delivery_document_id,
                                    i_route_no)
    LOOP
         IF (is_valid_delivery_document_id(r_xdock_ordm_in.delivery_document_id) = TRUE)
         THEN
               BEGIN
                  dbms_output.put_line(l_object_name || ' in loop'
                                 || '  ' || r_xdock_ordm_in.order_id
                                 || '  ' || r_xdock_ordm_in.delivery_document_id
                                 || '  ' || r_xdock_ordm_in.cross_dock_type);
      
                  merge_order_details(i_batch_id => r_xdock_ordm_in.batch_id,
                                      i_order_id => r_xdock_ordm_in.order_id);
               EXCEPTION
                  WHEN OTHERS THEN
                     dbms_output.put_line('error ' || l_object_name || ' in loop ' || SQLERRM);
               END;


               UPDATE xdock_ordd_in              -- xxxxxxxx change this to be more robust
                  SET record_status = 'S'
                WHERE batch_id = r_xdock_ordm_in.batch_id
                  AND order_id = r_xdock_ordm_in.order_id;

               UPDATE xdock_ordm_in              -- xxx change this to be more robust
                  SET record_status = 'S'
                WHERE batch_id = r_xdock_ordm_in.batch_id
                  AND order_id = r_xdock_ordm_in.order_id;

            --
            -- Update ORDM status to OPN if it was pending.  Pending indicates the route was open
            -- at Site 2 before Site 1 sent the information.
            --
            UPDATE ordm
               SET ordm.status = 'OPN'
             WHERE ordm.status = 'PND'
               AND ordm.delivery_document_id = i_delivery_document_id;

            --
            -- Update XDOCK_ORDER_XREF.ROUTE_NO_FROM with the Site 1 route number
            -- when merging the Site 1 order/floats info into Site 2.
            --
            UPDATE xdock_order_xref x
               SET x.route_no_from = r_xdock_ordm_in.route_no
             WHERE x.delivery_document_id = r_xdock_ordm_in.delivery_document_id
               AND x.cross_dock_type      = 'X';

            l_message := 'TABLE=xdock_order_xref'
                  || '  KEY=[' || r_xdock_ordm_in.delivery_document_id || ']'
                  || '(delivery_document_id)'
                  || ' Site 1 route number[' || r_xdock_ordm_in.route_no || ']'
                  || '  ACTION=UPDATE'
                  || '  MESSAGE="Update XDOCK_ORDER_XREF.ROUTE_NO_FROM with the Site 1 route number'
                  || ' when merging the Site 1 order/floats info into Site 2."'
                  || '  Number of records updated: ' || SQL%ROWCOUNT;

            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         ELSE
            --
            -- Not a valid delivery document
            --
            pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 
                           'ordm.xdock_in.batch_id[' || r_xdock_ordm_in.batch_id || ']'
                        || '  ordm.xdock_in.order_id[' || r_xdock_ordm_in.order_id || ']'
                        || '  Delivery document id['   || r_xdock_ordm_in.delivery_document_id   || '] is not valid.  Skip it.',
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
         END IF;
      END LOOP;
   ELSE
      --
      -- Not all the data has been sent from Site 1.
      -- Flag the ordm.status as 'PND' and do nothing else.
      -- The current ordm.status should be 'NEW'.
      -- xxxxx add additional checking/log messages.
      --
      l_message := 'Not all cross dock data sent from Site 1'
                  ||  ' for delivery document id[' || i_delivery_document_id || '].'
                  ||  '  Set ordm.status to PND.';
      DBMS_OUTPUT.PUT_LINE(l_object_name || ': ' || l_message);

      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

      UPDATE ordm
         SET ordm.status = 'PND'
       WHERE ordm.status = 'NEW'
        AND ordm.delivery_document_id = i_delivery_document_id;

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' Number of ordm records set to PND: ' || SQL%ROWCOUNT);
          
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('error l_object_name[' || l_object_name || '] ' || SQLERRM);
END merge_orders;


---------------------------------------------------------------------------
-- Procedure:
--    process_xdock_ordm_in (public)
--
-- Description:
--    This procedure processes the records in staging tables XDOCK_ORDM_IN
--    and XDOCK_ORDD_IN that are in 'N' status.
--
-- Process flow:
--    - Validate the XDOCK_ORDM_IN record.  Validation:
--       - Check the xdock_ordm_in.delivery_document_id exists in ORDM with
--         cross dock type 'X'.
--       - The route status is: NEW, RCV OPN or SHT.
--
-- Parameters:
--    None
--
-- Called by:
--    cron job
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE process_xdock_ordm_in
IS
   l_object_name       VARCHAR2(30) := 'process_xdock_orders_in';

   l_rec_count         PLS_INTEGER;     -- work area

   --
   -- Process by batch id.
   --
   CURSOR c_orders
   IS
   SELECT DISTINCT
          o.batch_id,
          o.delivery_document_id,
          o.site_to_route_no
     FROM
          xdock_ordm_in o
    WHERE
          o.record_status     = 'N'      -- Select unprocessed records.
    ORDER BY
          SUBSTR(o.batch_id, 1, INSTR(o.batch_id, '-')),
          LPAD(SUBSTR(o.batch_id, INSTR(o.batch_id, '-') + 1), 20, '0'),
          o.batch_id,
          o.delivery_document_id;

BEGIN
   dbms_output.put_line(l_object_name || '  Starting...');

   FOR r_orders IN c_orders LOOP

      DBMS_OUTPUT.PUT_LINE(l_object_name || '=======================================================');

      DBMS_OUTPUT.PUT_LINE(l_object_name || ' in loop  Processing batch_id '
                       || RPAD( r_orders.batch_id, 12)
                       || '  delivery document_id ' || RPAD(r_orders.delivery_document_id, 30)
                       || '  site_to_route_no'      || r_orders.site_to_route_no);

      --
      -- If there is an order in PND status tied to the delivery document id then this indicates the route
      -- was generated so also merge the floats.
      -- xxxxxxxxxxxx add log messages
      BEGIN
         SELECT COUNT(*)
           INTO l_rec_count
           FROM ordm o
          WHERE o.delivery_document_id = r_orders.delivery_document_id
            AND o.status = 'PND';

         DBMS_OUTPUT.PUT_LINE(l_object_name || ' ordm status PND count: ' || TO_CHAR(l_rec_count));

         IF (l_rec_count = 0) THEN
            pl_xdock_op_merge.merge_orders
                                 (i_batch_id              => r_orders.batch_id,
                                  i_delivery_document_id  => r_orders.delivery_document_id);
         ELSE
            pl_xdock_op_merge.merge_orders
                                 (i_batch_id              => r_orders.batch_id,
                                  i_delivery_document_id  => r_orders.delivery_document_id);

            pl_xdock_op_merge.merge_floats
                                 (i_route_no => r_orders.site_to_route_no);
         END IF;
      END;


      --
      -- Update order piece counts.
      -- xxxxxx 09/13/21  Brian Bent FYI Look I will make multiple updates of the same data doing
      -- it by route number.
      --
      update_orders(i_route_no => r_orders.site_to_route_no);

   END LOOP;

    ----- process_xdock_floats_in;          -- 10/14/21 Added to handle situation when route recovered and xdock floats in record status changed to 'N' hmmmmmmmmm
                                      -- then routed generated again.
                                      -- What we should do is create new procedure call "process_xdock_op_in" and call this from the shell script
                                      -- and "process_xdock_op_in" will call "process_xdock_ordm_in" and "process_xdock_floats_in".

   dbms_output.put_line(l_object_name || '  Ending');
EXCEPTION
   WHEN OTHERS THEN
      dbms_output.put_line(l_object_name || ' ' || SQLERRM);
END process_xdock_ordm_in;


---------------------------------------------------------------------------
-- Procedure:
--    merge_floats (public)
--
-- Description:
--    This procedure merges the 'S' cross dock floats sent from Site 1 into
--    the Site 2 main tables.
--
--    Site 2 Staging Table        Site 2 Main Table
--    -----------------------------------------------
--    XDOCK_FLOATS_IN             FLOATS
--    XDOCK_FLOAT_DETAIL_IN       FLOAT_DETAIL_IN
--    XDOCK_ORDCW_IN              ORDCW
--
-- Process flow:
--    - Validate the XDOCK_FLOATS_IN record.
--      Validation:
--       - Check the corresponding ORDM and ORDD records exist.
--         If not then log a mesaage and leave XDOCK_FLOATS.RECORD_STATUS at 'N'.
--         The XDOCK_FLOAT_DEAIL_IN and XDOCK_ORDCW_IN left as is.
--       - The ORDM.CROSS_DOCK_TYPE IS 'X'.
--       - The Site 2 route status is: NEW, RCV, OPN or SHT.
--         If not that fail all the records in in XDOCK_FLOATS_IN, XDOCK_FLOAT_DETAIL_IN and XDOCK_ORDCW_IN
--         for the Site 2 route.
--       - The ORDM status is 'NEW' or 'PND'.
--         If not 'NEW' or 'PND' then set XDOCK_FLOATS_IN to 'F' and do the same for XDOCK_FLOAT_DEAIL_IN and XDOCK_ORDCW_IN.
--       - The ORDM.CROSS_DOCK_TYPE IS 'X'.
--       - XDOCK_FLOATS_IN has corresponding XDOCK_FLOAT_DETAIL_IN records.
--       - It has not already been processed at Site 2--meaning...08/09/21 not sure yet.
--    - Insert into FLOATS.
--    - Insert into FLOAT_DETAIL for the float.
--    - Create XDK bulk pull tasks--insert into REPLENLST.
--    - Insert FLOAT_HIST records.
--
-- Parameters:
--    i_batch_id              
--    i_route_no     -- Site 2 route number 
--
-- Called by:
--    ???
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-
--                      Created.
--
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3714_OP_Site_2_floats_door_area_sometimes_incorrect
--
--                      I was always using the door_area of Site 1 to determine the door number
--                      for the float.  View "v_xdock_floats_in.sql" was doing this.
--                      Modified this procedure to look at the Site 2 door_area to determine
--                      the door number for the float.
--                      Example of the Issue:
--       ---------------- Site 1 --------------------------       ---------------- Site 2 ------------------------
--       Configured To Load Cooler Pallets at Freezer Doors       Configured To Load Cooler Pallets at Cooler Doors
--          ---------------- Float ---------------                ---------------- Float ---------------
--          door_area  comp_code  Door                            door_area  comp_code  Door
--          --------------------------------------                --------------------------------------
--              F         C       42(freezer door)                    C         C       22(freezer door) <-- Incorrect, Site 2 cooler door is 4.
--              
--    
---------------------------------------------------------------------------
PROCEDURE merge_floats
   (
      i_batch_id              IN xdock_ordd_in.batch_id%TYPE     DEFAULT NULL,    --  I don't think we need to go by batch id ????
      i_route_no              IN xdock_ordd_in.route_no%TYPE     DEFAULT NULL,
      i_delivery_document_id  IN ordm.delivery_document_id%TYPE  DEFAULT NULL
   )
IS
   l_object_name   VARCHAR2(30) := 'merge_floats';
   l_message       VARCHAR2(512);                  -- Message buffer

   l_cross_dock_pallet_location  inv.plogi_loc%TYPE;     -- Location of the cross dock palet

   --
   -- Need Site 2 values for these:
   --
   l_group_no            floats.group_no%TYPE;
   l_zone_id             floats.zone_id%TYPE;
   l_equip_id            floats.equip_id%TYPE;
   l_door_area           floats.door_area%TYPE;
   l_comp_code           floats.comp_code%TYPE;
   l_merge_group_no      floats.merge_group_no%TYPE;

BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure (i_batch_id['          || i_batch_id             || '],'
                              || 'i_route_no['             || i_route_no             || '],'
                              || 'i_delivery_document_id[' || i_delivery_document_id || '])';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');


   FOR r_xdock_floats_in IN c_xdock_floats_in(i_route_no)
   LOOP
      dbms_output.put_line('===================================================================================');

      --
      -- Valildate float
      --
      IF (is_valid_float(r_xdock_floats_in.float_no) = TRUE)
      THEN
         BEGIN
            dbms_output.put_line(l_object_name || '  in loop'
                           || '  ' || r_xdock_floats_in.batch_id
                           || '  ' || r_xdock_floats_in.sequence_number
                           || '  ' || r_xdock_floats_in.float_no);
         EXCEPTION
            WHEN OTHERS THEN
               dbms_output.put_line('error  l_object_name[' || l_object_name || '] in loop ' || SQLERRM);
         END;

         --
         -- A new float# is required since the float# is unique only within the OpCo.
         --
         r_xdock_floats_in.new_float_no := float_no_seq.NEXTVAL;

         --
         -- Need a location for the pallet to use in getting the sel method group#, etc
         -- 09/30/21 Brian Bent  By mistake I was passing to function "get_xdock_pallet_loc_for_float" r_xdock_floats_in.door_area
         -- instead of r_xdock_floats_in.comp_code.  We need to use the comp_code as this designates the compartment code
         -- in the trailer the pallet is to be loaded--D, C or F.  The door_area is the area of the door where the trailer is at.
         -- For example a cooler pallet can we loaded on a trailer at a freezer door so the door_area would be F and
         -- the comp_code would be C.
         --
         l_cross_dock_pallet_location := get_xdock_pallet_loc_for_float(r_xdock_floats_in.parent_pallet_id, r_xdock_floats_in.comp_code);

         --
         -- These floats columns need to be valid at Site 2.
         -- The Site 1 values cannnot be used.
         --   - floats.group_no
         --   - floats.zone_id
         --   - floats.equip_id
         --   - floats.door_area
         --   - floats.comp_code
         --   - floats.door_no
         --
         -- Determine values for Site 2 float record.
         --
         pl_alloc_inv.get_group_no(i_method_id       => r_xdock_floats_in.site_to_method_id,
                                   i_logi_loc        => l_cross_dock_pallet_location,
                                   o_group_no        => l_group_no,
                                   o_zone_id         => l_zone_id,
                                   o_equip_id        => l_equip_id,
                                   o_door_area       => l_door_area,
                                   o_comp_code       => l_comp_code,
                                   o_merge_group_no  => l_merge_group_no);

         r_xdock_floats_in.group_no          := l_group_no;
         r_xdock_floats_in.zone_id           := l_zone_id;
         r_xdock_floats_in.equip_id          := l_equip_id;
         r_xdock_floats_in.door_area         := l_door_area;
         r_xdock_floats_in.comp_code         := l_comp_code;
         r_xdock_floats_in.merge_group_no    := l_merge_group_no;

         --
         -- 10/08/21 Brian Bent Added
         -- Site 2 door number depends on the Site 2 door_area 
         --
         r_xdock_floats_in.site_to_door_no :=
                     CASE r_xdock_floats_in.door_area
                        WHEN 'D' THEN r_xdock_floats_in.site_to_d_door
                        WHEN 'C' THEN r_xdock_floats_in.site_to_c_door
                        WHEN 'F' THEN r_xdock_floats_in.site_to_f_door
                        ELSE r_xdock_floats_in.site_to_c_door               -- Give up, use cooler door
                     END;

         --
         -- Insert floats record.
         --
         dbms_output.put_line(l_object_name || '   before call to insert_floats_rec');
         insert_floats_rec(r_xdock_floats_in);

         --
         -- Insert the float details rec(s).
         --
         FOR r_xdock_float_detail_in IN c_xdock_float_detail_in(r_xdock_floats_in.batch_id,
                                                                r_xdock_floats_in.float_no)
         LOOP
            --
            -- New values are necesary for some the float detail columns from Site 1.
            --
            r_xdock_float_detail_in.new_float_no     := r_xdock_floats_in.new_float_no;
            r_xdock_float_detail_in.site_to_route_no := r_xdock_floats_in.site_to_route_no;
            r_xdock_float_detail_in.src_loc          := l_cross_dock_pallet_location;

            insert_float_detail_rec(r_xdock_float_detail_in);
         END LOOP;


         --
         -- Insert the ORDCW rec(s).
         --
         FOR r_xdock_ordcw_in IN c_xdock_ordcw_in(r_xdock_floats_in.batch_id,
                                                  r_xdock_floats_in.float_no)
         LOOP
            DBMS_OUTPUT.PUT_LINE(l_object_name || ' in c_xdock_ordcw_in loop');

            --
            -- New values are necesary for some of the ORDCW columns from Site 1.
            --
            r_xdock_ordcw_in.site_2_cw_float_no     := r_xdock_floats_in.new_float_no;

            insert_ordcw_rec(r_xdock_ordcw_in);
         END LOOP;


         UPDATE xdock_floats_in              -- xxx change this to be more robust
            SET record_status = 'S'
          WHERE batch_id = r_xdock_floats_in.batch_id
            AND float_no = r_xdock_floats_in.float_no
            AND record_status = 'N';

         UPDATE xdock_float_detail_in        -- xxx change this to be more robust
            SET record_status = 'S'
          WHERE batch_id = r_xdock_floats_in.batch_id
            AND float_no = r_xdock_floats_in.float_no
            AND record_status = 'N';

         UPDATE xdock_ordcw_in               -- xxx change this to be more robust
            SET record_status = 'S'
          WHERE batch_id    = r_xdock_floats_in.batch_id
            AND cw_float_no = r_xdock_floats_in.float_no    -- FYI This float number is the Site 1 float number.
            AND record_status = 'N';
      ELSE
         dbms_output.put_line('l_object_name[' || l_object_name || ']  not valid delivery_document_id put in log message');
      END IF;
   END LOOP;

   UPDATE xdock_floats_in              -- xxx change this to be more robust
      SET record_status = 'S'
    WHERE batch_id = i_batch_id;

   --
   -- If floats merged after the route was generated at Site 2 then update
   -- floats columns normally updated during order generation.
   --
   update_floats_after_merge(i_route_no  => i_route_no);

   --
   -- Create PIK transactions for the cross dock pallets.
   --
   create_pik_transactions(i_route_no  => i_route_no);

   --
   -- Create XDK bulk pull tasks.
   --
   create_bulk_pull_tasks(i_route_no  => i_route_no);

EXCEPTION
   WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('error l_object_name[' || l_object_name || '] ' || SQLERRM);
END merge_floats;


/************************************************************
**************************************************************
************** 08/18/21  Don't think we need this procedure
************************************************************/
---------------------------------------------------------------------------
-- Procedure:
--    process_xdock_floats_in (public)
--
-- Description:
--    This procedure process the records in staging tables XDOCK_FLOATS_IN
--    and XDOCK_FLOAT_DETAIL_ID that are in 'N' status.
--
-- Process flow:
--    - Validate the XDOCK_FLOATS_IN record.  Validation:
--       - The corresponding ORDM record and ORDD record(s) need to exist.
--       - It needs to have XDOCK_FLOAT_DETAIL_IN records.
--       - The route status is: NEW, RCV OPN or SHT.
--    - Insert into FLOATS
--    - Insert into FLOAT_DETAIL for the float.
--
-- Parameters:
--    None
--
-- Called by:
--    pl_order_processing.post_float_processing
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/20/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE process_xdock_floats_in
IS
   l_object_name       VARCHAR2(30) := 'process_xdock_floats_in';

   --
   -- Process by batch id.
   --
   CURSOR c_xdock_floats_in_batch_id
   IS
   SELECT DISTINCT f.batch_id
     FROM xdock_floats_in f
    WHERE f.record_status     = 'N'      -- Select unprocessed records.
    ORDER BY
          SUBSTR(f.batch_id, 1, INSTR(f.batch_id, '-')),
          LPAD(SUBSTR(f.batch_id, INSTR(f.batch_id, '-') + 1), 20, '0'),
          f.batch_id;

BEGIN
   dbms_output.put_line(l_object_name || '  Starting...');

   FOR r_xdock_floats_in_batch_id IN c_xdock_floats_in_batch_id LOOP

      dbms_output.put_line(l_object_name || '=======================================================');

      dbms_output.put_line(l_object_name || 'in loop  Processing batch_id: ' || r_xdock_floats_in_batch_id.batch_id || '...');

      merge_floats(i_batch_id   => r_xdock_floats_in_batch_id.batch_id,
                   i_route_no   => NULL);

   END LOOP;

   dbms_output.put_line(l_object_name || '  Ending');
EXCEPTION
   WHEN OTHERS THEN
      dbms_output.put_line(l_object_name || ' ' || SQLERRM);
END process_xdock_floats_in;


---------------------------------------------------------------------------
-- Procedure:
--    create_bulk_pull_tasks (public)
--
-- Description:
--    This procedure creates the XDK bulk pull tasks for the Site 2
--    cross dock pallets for the specified route or parent LP.
--
--    Records are inserted into REPLENLST table--this is the task.
--
-- Process flow:
--    - Select from floats for the specified route or parent LP
--      and the float has cross dock type of 'X'.
--    - If the pallet not yet receieved then do not create a XDK task.
--    - Check if XDK task aleady exist for the floats parent LP.
--      If task does not exist then insert a XDK task into REPLENLST.
--
-- Mon Aug 23 -- As a reference this is a BLK task (REPLENLST record) from OpCo 056.
--    TASK_ID                       [9836422]
--    PROD_ID                       [7064418]
--    UOM                           [2]
--    QTY                           [4]
--    TYPE                          [BLK]
--    STATUS                        [NEW]
--    SRC_LOC                       [DN34C4]
--    PALLET_ID                     [1595577]
--    DEST_LOC                      []
--    S_PIKPATH                     [414343004]
--    D_PIKPATH                     []
--    BATCH_NO                      [0]
--    EQUIP_ID                      [P010199FRK]
--    ORDER_ID                      [556634549]
--    USER_ID                       []
--    OP_ACQUIRE_FLAG               [Y]
--    CUST_PREF_VENDOR              [-]
--    GEN_UID                       [USSDPV]
--    GEN_DATE                      [08/20/2021 10:01:29]
--    EXP_DATE                      [08/12/2021 00:00:00]
--    ROUTE_NO                      [12N]
--    FLOAT_NO                      [1590694]
--    SEQ_NO                        [1]
--    DOOR_NO                       [1]
--    DROP_QTY                      [0]
--    PICK_SEQ                      []
--    ROUTE_BATCH_NO                [5608108]
--    TRUCK_NO                      [12N]
--    INV_DEST_LOC                  []
--    ADD_DATE                      [08/20/2021 10:01:29]
--    ADD_USER                      [USSDPV]
--    UPD_DATE                      []
--    UPD_USER                      []
--    PARENT_PALLET_ID              []
--    DMD_REPL_ATTEMPTS             []
--    LABOR_BATCH_NO                []
--    PRIORITY                      []
--    REC_ID                        []
--    MFG_DATE                      []
--    LOT_ID                        []
--    ORIG_PALLET_ID                []
--    REPLEN_TYPE                   [D]
--    REPLEN_AISLE                  []
--    REPLEN_AREA                   [D]
--    MX_BATCH_NO                   []
--    CASE_NO                       []
--    PRINT_LPN                     []
--    MX_SHORT_CASES                []
--
--    Task can be created by route or for a specified xdock pallet.
-- Parameters:
--    i_route_no          - Site 2 route number 
--    i_xdock_pallet_id   - This is the pallet id assigned to the cross dock pallet and is unique across all OpCos.
--    i_src_loc           - Site 2 pallet locationlocation th edpallet.  Used if pallet is going from receiving door to outbound door
--
-- Called by:
--    ???
--
-- Exceptions raised:
--    None.  Error is logged.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/19/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
--    09/12/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Create the XDK task only when the pallet is recevied.
--                      Set the XDK task src_loc to the putaway dest_loc.
--
--
---------------------------------------------------------------------------
PROCEDURE create_bulk_pull_tasks
   (
      i_route_no                  IN  floats.route_no%TYPE             DEFAULT NULL,
      i_xdock_pallet_id           IN  floats.parent_pallet_id%TYPE     DEFAULT NULL,
      i_src_loc                   IN  loc.logi_loc%TYPE                DEFAULT NULL
   )
AS
   l_object_name     VARCHAR2(30) := 'create_bulk_pull_tasks';
   l_message         VARCHAR2(512);        -- Message buffer

   l_task_src_loc             replenlst.src_loc%TYPE;

   l_r_create_batch_stats     pl_lmf.t_create_putaway_stats_rec;    -- Used when creating the forklift labor batch

   --
   -- This cursor selects the Site 2 cross dock floats to create a XDK bulk pull task for.
   -- Tasks can be created for a route or for a specified parent pallet id.
   --
   CURSOR c_floats(cp_route_no           floats.route_no%TYPE,
                   cp_xdock_pallet_id    floats.xdock_pallet_id%TYPE)
   IS
   SELECT
          f.float_no,
          f.route_no,
          r.truck_no,
          r.route_batch_no,
          f.site_from,
          f.site_to,
          f.cross_dock_type,
          f.pallet_id,
          f.xdock_pallet_id,            -- This will be the replenlst.pallet_id
          f.equip_id,
          f.door_no,
          f.door_area,
          --
          DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.prod_id), 'MULTI')           prod_id,
          DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.cust_pref_vendor), '-')      cust_pref_vendor,  -- Just leave CPV at '-'
          SUM(DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc ))                                     qty,
          MIN(fd.src_loc)          src_loc,     -- FYI All the float detail records should have the same location.
          MIN(fd.exp_date)         exp_date,
          MIN(fd.mfg_date)         mfg_date,
          MIN(loc.pik_path)        src_loc_pik_path,
          MIN(fd.order_id)         order_id,
          COUNT(*)                 fd_rec_count,
          put.rec_id               put_rec_id,
          erm.erm_type             erm_type,
          erm.status               erm_status,
          put.dest_loc             put_dest_loc     -- This is will be the replenlst.src_loc
     FROM
          loc          loc,
          floats       f,
          float_detail fd,
          route        r,
          pm           pm,
          putawaylst   put,       -- To see if pallet received
          erm                     -- Info about the XN the pallet is on
    WHERE 
          (   f.route_no            = cp_route_no
           OR f.parent_pallet_id    = cp_xdock_pallet_id)
      --
      AND fd.float_no             = f.float_no
      AND f.pallet_pull           = 'B'           -- Site 2 cross dock pallets are always bulk pulls
      AND f.cross_dock_type       = 'X'           -- Site 2 has 'X' for the cross dock type
      AND loc.logi_loc (+)        = fd.src_loc
      AND pm.prod_id              = fd.prod_id
      AND pm.cust_pref_vendor     = fd.cust_pref_vendor
      AND r.route_no              = f.route_no
      AND put.pallet_id       (+) = f.xdock_pallet_id     -- Outer join to putawaylst because the pallet may not have been received yet.
      AND erm.erm_id          (+) = put.rec_id
    GROUP BY
          f.float_no,
          f.route_no,
          r.truck_no,
          r.route_batch_no,
          f.site_from,
          f.site_to,
          f.cross_dock_type,
          f.pallet_id,
          f.xdock_pallet_id,
          f.equip_id,
          f.door_no,
          f.door_area,
          put.rec_id,
          erm.erm_type,
          erm.status,
          put.dest_loc;
BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure (i_route_no[' || i_route_no || ']'
                   || '  i_xdock_pallet_id[' || i_xdock_pallet_id || ']'
                   || '  i_src_loc['         || i_src_loc         || '])'
                   || '  This procedure creates XDK tasks for the Site 2 cross dock pallets.';

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   FOR r_floats IN c_floats(i_route_no, i_xdock_pallet_id)
   LOOP
      --
      -- Do not create a task if one already exists.
      -- Do not create a task if the pallet is not received.
      --
      IF (does_xdk_task_exist(i_xdock_pallet_id => r_floats.xdock_pallet_id) = TRUE)
      THEN
         --
         -- XDK task already exists for the cross dock pallet at Site 2
         -- xxxxxxxxxxxxx
         --
         DBMS_OUTPUT.PUT_LINE(l_object_name
                       || ' float#:' || TO_CHAR(r_floats.float_no)
                       || ' xdock LP:' || r_floats.xdock_pallet_id
                       || ' XDK task already exists.');
      ELSIF (r_floats.put_dest_loc IS NULL)
      THEN
         --
         -- If the putaway task for the cross dock pallet does not exist or the put dest_loc is
         -- null then this indicates the cross dock pallet not yet received at Site 2.
         -- A XDK task will not be created.  The XDK task will be created when the cross dock pallet
         -- is received.
         --
         l_message :=     'float#['         || TO_CHAR(r_floats.float_no) || ']'
                   || '  xdock LP['     || r_floats.xdock_pallet_id   || ']'
                   || '  erm_id['       || r_floats.put_rec_id        || ']'
                   || '  erm_status'    || r_floats.put_rec_id        || ']'
                   || '  erm_type['     || r_floats.erm_type          || ']'
                   || '  No put dest loc found for the cross dock pallet indicating the pallet not yet received.  Do not create XDK task.';

         DBMS_OUTPUT.PUT_LINE(l_object_name || ' ' || l_message);

         pl_log.ins_msg
               (i_msg_type         => pl_log.ct_info_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => l_message,
                i_msg_no           => NULL,
                i_sql_err_msg      => NULL,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');
      ELSE
         DBMS_OUTPUT.PUT_LINE(l_object_name
                       || ' float#:' || TO_CHAR(r_floats.float_no)
                       || ' xdock LP:' || r_floats.xdock_pallet_id
                       || ' before insert of XDK task.');

         --
         -- The src loc of the XDK task is the putaway location which could be a
         -- location or a door.  When it is door the dock--if it exists in the
         -- put dest_loc--is stripped off and then any leading zeroes stripped.
         -- The task src loc needs to be the true door number.
         --
         IF (pl_lmf.f_valid_fk_door_no(r_floats.put_dest_loc) = TRUE)
         THEN
            DBMS_OUTPUT.PUT_LINE('xxxxxxxx ' || r_floats.put_dest_loc || ' is a forklift labor door.'
                || '    remove dock: ' || ltrim(substr(r_floats.put_dest_loc, 3), '0'));

            l_task_src_loc := LTRIM(SUBSTR(r_floats.put_dest_loc, 3), '0');
         ELSE
            l_task_src_loc := r_floats.put_dest_loc;
         END IF;

         INSERT INTO replenlst
             (task_id,
              prod_id,
              cust_pref_vendor,
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
              gen_uid,
              gen_date,
              exp_date,
              route_no,
              float_no,
              seq_no,
              door_no,
              drop_qty,
              pick_seq,
              route_batch_no,
              truck_no,
              inv_dest_loc,
              parent_pallet_id,
              dmd_repl_attempts,
              labor_batch_no,
              priority,
              rec_id,
              mfg_date,
              lot_id,
              orig_pallet_id,
              replen_type,
              replen_aisle,
              replen_area,
              mx_batch_no,
              case_no,
              print_lpn,
              mx_short_cases,
              site_from,
              site_to,
              cross_dock_type,
              xdock_pallet_id)
         SELECT
              repl_id_seq.NEXTVAL            task_id,
              r_floats.prod_id               prod_id,
              r_floats.cust_pref_vendor      cust_pref_vendor,
              2                              uom,                  -- Always 2
              r_floats.qty                   qty,                  -- Total number cases and splits on the float
              'XDK'                          type,
              'NEW'                          status,
              l_task_src_loc                 src_loc,
              --
              r_floats.xdock_pallet_id       pallet_id,            -- For Site 2 the replenlst pallet_id is set to the floats xdock_pallet_id
                                                                   -- which is the unique across all OpCos LP that Site 1 assigned to the
                                                                   -- cross dock pallet.  The replenlst table also has column xdock_pallet_id
                                                                   -- which also set to float.xdock_pallet_id.  So the cross dock pallet LP
                                                                   -- is stored in two columns in replenlst.
              --
              NULL                           dest_loc,             -- XDK task has no dest_loc.  The logic looks at the replenlst.door_no
              r_floats.src_loc_pik_path      s_pikpath,
              NULL                           d_pikpath,
              0                              batch_no,
              r_floats.equip_id              equip_id,
              r_floats.order_id              order_id,
              NULl                           user_id,
              'Y'                            op_acquire_flag,
              REPLACE(USER, 'OPS$', NULL)    gen_uid,
              SYSDATE                        gen_date,
              r_floats.exp_date              exp_date,
              r_floats.route_no              route_no,
              r_floats.float_no              float_no,
              1                              seq_no,
              r_floats.door_no               door_no,
              0                              drop_qty,              -- never a drop qty
              NULL                           pick_seq,             
              r_floats.route_batch_no        route_batch_no,
              r_floats.truck_no              truck_no,
              NULL                           inv_dest_loc,
              NULL                           parent_pallet_id,         -- For Site 2 the replenlst parent pallet id needs to be null
              NULL                           dmd_repl_attempts,
              NULL                           labor_batch_no,
              NULL                           priority,
              NULL                           rec_id,
              r_floats.mfg_date              mfg_date,
              NULL                           lot_id,
              NULL                           orig_pallet_id,
              'D'                            replen_type,
              NULL                           replen_aisle,
              r_floats.door_area             replen_area,
              NULL                           mx_batch_no,
              NULL                           case_no,
              NULL                           print_lpn,
              NULL                           mx_short_cases,
              r_floats.site_from             site_from,
              r_floats.site_to               site_to,
              r_floats.cross_dock_type       cross_dock_type,           -- For Site 2 this should be 'X'
              r_floats.xdock_pallet_id       xdock_pallet_id
         FROM DUAL;

         --
         -- Now we need to upate the floats_detail.src_loc to match the task.
         -- If the route was generated before before the cross dock pallet received then
         -- the float detail src_loc was set to a random rule 4 location.  It now needs to be
         -- updated to the putaway location of the pallet.
         --
         UPDATE float_detail fd
            SET fd.src_loc = l_task_src_loc
          WHERE fd.float_no = r_floats.float_no
            AND fd.src_loc <> l_task_src_loc;

         --
         -- If forkfift labor is active then create the XDK bulk pull labor batch.
         --
         IF (pl_lmf.f_forklift_active = TRUE)
         THEN
            pl_lmf.create_xdk_pallet_pull_batch
                                (i_float_no             => r_floats.float_no,
                                 o_r_create_batch_stats => l_r_create_batch_stats);
         END IF;
      END IF;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log a message but do not stop processing.
      --
      pl_log.ins_msg
               (i_msg_type         => pl_log.ct_warn_msg,
                i_procedure_name   => l_object_name,
                i_msg_text         => 'Error occurred'
                            || '  i_route_no['        || i_xdock_pallet_id || ']'
                            || '  i_xdock_pallet_id[' || i_xdock_pallet_id || ']'
                            || '  i_src_loc['         || i_src_loc         || ']'
                            || ' This will not stop processing.',
                i_msg_no           => SQLCODE,
                i_sql_err_msg      => SQLERRM,
                i_application_func => ct_application_function,
                i_program_name     => gl_pkg_name,
                i_msg_alert        => 'N');

END create_bulk_pull_tasks;


---------------------------------------------------------------------------
-- Function:
--    get_xdock_pallet_loc_for_float (public)
--
-- Description:
--    This function returns location to use for the Site 2 cross dock pallet.
--
--    The FLOAT_DETAIl.SRC_LOC is set this.
--    The location is also used to determine the pick zone and selection
--    method group#, door area, etc.
--
-- Parameters:
--    i_pallet_id
--    i_area
--
-- Return Values:
--    
--    
-- Called By:
--
-- Exceptions Raised:
--    pl_exc.e_database_error  - Got an oracle error.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/22/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
---------------------------------------------------------------------------
FUNCTION get_xdock_pallet_loc_for_float
   (
      i_pallet_id  IN  putawaylst.pallet_id%TYPE,
      i_area       IN  pm.area%TYPE
   )
RETURN VARCHAR2
IS
   l_object_name       VARCHAR2(30) := 'get_xdock_pallet_loc_for_float';

   l_found_bln        BOOLEAN;
   l_location         inv.plogi_loc%TYPE;
   l_slot_type        loc.slot_type%TYPE;   -- Used in determining if the putawaylst.dest_loc is a slot or a door.

   CURSOR c_check_put
   IS
   SELECT p.dest_loc,
          loc.slot_type
     FROM putawaylst p,
          loc
    WHERE p.pallet_id      = i_pallet_id
      AND loc.logi_loc (+) = p.dest_loc;     -- Used to check if the putawauylst dest_loc is a slot and not a door.

   --
   -- Used when the pallet is not in putawaylst--which indicates the pallet not yet received--
   -- or the putawaylst location is a door.
   --
   CURSOR c_xdock_locations
   IS
   SELECT loc.logi_loc    logi_loc,
          ssa.area_code   area_code
     FROM loc,
          lzone lz,
          zone z,
          aisle_info ai,
          swms_sub_areas ssa
    WHERE loc.logi_loc     = lz.logi_loc
      AND lz.zone_id       = z.zone_id
      AND z.zone_type      = 'PUT'
      AND z.rule_id        = 14
      AND ai.name          = SUBSTR(lz.logi_loc, 1, 2)
      AND ai.sub_area_code = ssa.sub_area_code
      AND z.zone_type      = 'PUT'
    ORDER BY ssa.area_code, lz.logi_loc;

BEGIN
   l_location   := NULL;
   l_slot_type  := NULL;

   OPEN c_check_put;
   FETCH c_check_put into l_location, l_slot_type;

   l_found_bln := c_check_put%FOUND;

   CLOSE c_check_put;

   ---- xxxxxxxx add log msgs
   dbms_output.put_line(l_object_name ||  '  l_location[' || l_location || ']  l_slot_type[' || l_slot_type || ']');

   IF (l_found_bln AND l_slot_type IS NOT NULL) THEN
      --
      -- The putawaylst.dest_loc is a slot.  Use it.
      --
      NULL;
   ELSE

      ------ xxxxxx add log msgs
      dbms_output.put_line('i_pallet_id not found in putawaylst...pick a rule 14 location for the area');

      FOR r_xdock_locations IN c_xdock_locations LOOP
         dbms_output.put_line('xxxx ' || r_xdock_locations.logi_loc || ' ' || r_xdock_locations.area_code);

         IF (l_location IS NULL) THEN
            l_location := r_xdock_locations.logi_loc;  -- failsafe so we got some location.
         END IF;

         IF (r_xdock_locations.area_code = i_area) THEN
            l_location := r_xdock_locations.logi_loc;
            EXIT;  -- done, found a location
         END IF;

      END LOOP;

   END IF;

   dbms_output.put_line('l_location: ' || l_location);


   RETURN l_location;
EXCEPTION
   WHEN OTHERS THEN
      dbms_output.put_line(l_object_name || ' ' || SQLERRM);
END get_xdock_pallet_loc_for_float;


---------------------------------------------------------------------------
-- Procedure:
--    update_floats_after_merge (public)
--
-- Description:
--    This procedure updates relevant columns for Site 2 Xdock floats after merging.
--
--    Some floats columns need a value assigned if merging happens after the route is 
--    generated at Site 2.
--
--    Columms udated:
--       - FLOATS.FLOAT_SEQ    if null
--
-- Parameters:
--    i_route_no         - The route number to process.
--
-- Called by:
--    pl_xdock_op_merge.xxxx
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/20/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--                      Created.
--
---------------------------------------------------------------------------
PROCEDURE update_floats_after_merge
   (
      i_route_no        IN  route.route_no%TYPE
   )
IS
   l_object_name   VARCHAR2(30)   := 'update_floats_after_merge';
   l_message       VARCHAR2(512);                     -- Work area

   l_seq          PLS_INTEGER;     -- Work area


   --
   -- This cursor is used to update the floats.float_seq if is is null.
   -- floats.float_seq will be null if floats merged after route generated.
   -- This logic taken from gen_float.pc
   --
   CURSOR c_floats(cp_route_no  route.route_no%TYPE)
   IS
   SELECT f.float_no,
          r.truck_no,
          f.comp_code,
          f.route_no
     FROM
          floats f,
          route r
    WHERE
          r.route_no          = cp_route_no
      AND f.route_no          = r.route_no
      AND f.merge_loc         LIKE '???%'
      AND f.cross_dock_type   = 'X'
      AND r.status            IN ('OPN', 'SHT')
      AND f.float_seq         IS NULL          -- Null indicates floats merged after route generated at Site 2.
    ORDER BY
          f.comp_code,
          e_stop_no    DESC,
          b_stop_no    DESC,
          float_cube   DESC
    FOR UPDATE OF
          float_seq;

BEGIN
   --
   -- Log starting procedure
   --
   l_message := 'Starting procedure (i_route_no[' || i_route_no || '])'
         || '  This procedure updates relevant columns in FLOATS table for Site 2 Xdock floats'
         || ' after floats merged.'
         || '  Columns updated: floats.float_seq(if null)--null indicates floats merged after the route generated.';

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
   -- Check the parameters.
   -- i_route_no needs a value.
   --
   IF (i_route_no IS NULL) THEN
      RAISE gl_e_parameter_null;
   END IF;

   --
   -- Update floats.float_seq if null.  A null value indicates the floats merged
   -- after the route was generated at Site 2.
   --
   BEGIN
      FOR r_floats IN c_floats(i_route_no)
      LOOP
         dbms_output.put_line(r_floats.float_no || ' ' || r_floats.truck_no || ' ' || r_floats.comp_code);

         --
         -- Get the number of the last seq used.  
         -- Example: Comp code is D.  Current floats are D1, D2, D3.
         --          This select returns 3.
         --
         SELECT NVL(MAX(TO_NUMBER(SUBSTR(f2.float_seq, 2))), 0)
           INTO l_seq
           FROM floats f2
          WHERE f2.truck_no  = r_floats.truck_no
            AND f2.comp_code = r_floats.comp_code;  
	
         l_seq := l_seq + 1;    -- Advance to next sequence.

         UPDATE floats f3
            SET float_seq = r_floats.comp_code || TO_CHAR(l_seq)
          WHERE f3.float_no = r_floats.float_no;

         pl_log.ins_msg
            (i_msg_type         => pl_log.ct_warn_msg,
             i_procedure_name   => l_object_name,
             i_msg_text         => 'TABLE=floats  ACTION=UPDATE'
                        || '  KEY=[' || r_floats.float_no || '](float_no)'
                        || '  MESSAGE="route_no[' || r_floats.route_no || '].'
                        || '  Update float_seq from null to['  || r_floats.comp_code || TO_CHAR(l_seq) || ']'
                        || '  Null float_seq indicates floats merged after the route generated at Site 2."',
             i_msg_no           => NULL,
             i_sql_err_msg      => NULL,
             i_application_func => ct_application_function,
             i_program_name     => gl_pkg_name,
             i_msg_alert        => 'N');



      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         --
         -- Got an oracle error.
         --
         l_message := '(i_route_no[' || i_route_no || '])  Error updating floats, Processing will continue.';

         pl_log.ins_msg
             (i_msg_type         => pl_log.ct_fatal_msg,
              i_procedure_name   => l_object_name,
              i_msg_text         => l_message,
              i_msg_no           => SQLCODE,
              i_sql_err_msg      => SQLERRM,
              i_application_func => ct_application_function,
              i_program_name     => gl_pkg_name,
              i_msg_alert        => 'N');
   END;


   --
   -- Log ending procedure
   --
   l_message := 'Ending procedure ' || '(i_route_no[' || i_route_no || '])';

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
   WHEN gl_e_parameter_null THEN
      --
      -- i_route_no null.
      --
      l_message := '(i_route_no[' || i_route_no || '])' || '  Parameter null.';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_data_error,  l_message);
   WHEN OTHERS THEN
      --
      -- Got an oracle error.
      --
      l_message := '(i_route_no[' || i_route_no || '])';

      pl_log.ins_msg
          (i_msg_type         => pl_log.ct_fatal_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => l_message,
           i_msg_no           => SQLCODE,
           i_sql_err_msg      => SQLERRM,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

      RAISE_APPLICATION_ERROR(pl_exc.ct_database_error, l_object_name || ': ' || SQLERRM);
END update_floats_after_merge;


---------------------------------------------------------------------------
-- Procedure:
--    create_pik_transactions (public)
--
-- Description:
--    Site 2 - This procedure creates the PIK transaction for a the 'X' cross
--    dock pallets on a route.  Only one PIK transaction is created per 'X'
--    cross dock pallet.
--
--    Called during order generation and when the floats were merged after
--    the route was generated.
--
--    The trans.qty is the number of pieces on the pallet.
--    The trans.uom will always be 0.
--
--    The summing of float details is similar to the the query in
--    procedure "pl_xdock_op_merge.create_bulk_pull_tasks".
--
--    TRANS Table Column Mapping
--    Column                       Value
--    --------------------------------------------------------------------
--    trans_id                     trans_id_seq.NEXTVAL trans_id,
--    trans_type                   'PIK'
--    trans_date                   SYSDATE
--    prod_id                      float_detail.prod_id if only one item on the pallet.
--                                 'MULTI' if different items on the pallet.
--    cust_pref_vendor             '-'
--    qty_expected                 0
--    qty                          The number of pieces on the pallet.
--    user_id                      USER
--    order_id                     MIN(float_detail.order_id)
--    src_loc                      MIN(float_detail.src_loc)          All the float detail records should have the same location.
--    route_no                     floats.route_no
--    truck_no                     route.truck_no
--    stop_no                      MIN(float_detail.stop_no           The pallet can have multiple stops.
--    dest_loc                     floats.door_no
--    pallet_id                    floats.xdock_pallet_id
--    uom                          Always 0
--    rec_id                       MIN(float_detail.rec_id)           The pallet can have multiple PO's
--    lot_id                       MIN(float_detail.lot_id)           The pallet can have multiple lots.
--    exp_date                     MIN(float_detail.exp_date)         The pallet can have multiple exp dates.
--    mfg_date                     MIN(float_detail.mfg_date)         The pallet can have multiple mfg dates.
--    float_no                     floats.float_no
--    order_line_id                MIN(float_detail.order_line_id)    The pallet can have multiple order lines.
--    sys_order_id                 MIN(ordd.sys_order_id)             The pallet can have multiple sys orders.
--    sys_order_line_id            MIN(ordd.sys_order_line_id)        The pallet can have multiple sys order lines.
--    float_detail_seq_no          MIN(float_detail.seq_no)           The pallet can have multiple float detail seq_no's.
--    cross_dock_type              floats.cross_dock_type
--
-- Parameters:
--    i_route_no           -- Route to process
--
-- Called by:
--    merge_floats
--
-- Exceptions raised:
--    RAISE_APPLICATION_ERROR pl_exc.ct_data_error
--    RAISE_APPLICATION_ERROR pl_exc.ct_database_error
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    10/12/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3725_Site_2_Create_PIK_transaction_for_cross_dock_pallet
--                      Created.
--
--                      This procedure is similar to procedure "createpiktrans" but is
--                      specific to "X" cross dock orders.
--
--    11/16/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0_Xdock_OPCOF-3567_Site_2_Order_recovery_xdock_orders
--
--                      When testing on rs1210b1 with route 7657 see this error in the
--                      SWMS_LOG table from procedure "create_pik_transactions":
--        i_route_no[7657] Error creating PIK transactions.  This will not stop processing.
--        ORA-01427: single-row subquery returns more than one row
--                      Found this happens when the route was recoved 2 or more times.
--                      To fix changed:
--       NVL((SELECT t2.trans_date FROM TRANS t2 WHERE t2.route_no = f.route_no AND t2.trans_type = 'RVT'), SYSDATE - 100)
--                      to
--       NVL((SELECT MAX(t2.trans_date) FROM TRANS t2 WHERE t2.route_no = f.route_no AND t2.trans_type = 'RVT'), SYSDATE - 100)
---------------------------------------------------------------------------
PROCEDURE create_pik_transactions
   (
      i_route_no  IN  route.route_no%TYPE
   )
IS
   l_object_name       VARCHAR2(50) := 'create_pik_transactions';

   l_num_piks_created    PLS_INTEGER;      -- Count of PIK transactions created.  Used in log message.
   l_num_piks_existing   PLS_INTEGER;      -- Count of PIK transactions already existing for rhe pallet.  Used in log message.

   --
   -- This cursor selects the 'X' cross dock pallets for the specified route to create PIK transctions for.
   -- If a PIK already exists for the pallet then another one is not created.
   --
   CURSOR c_pik(cp_route_no  route.route_no%TYPE)
   IS
   SELECT
          'PIK'                         trans_type,
          SYSDATE                       trans_date,
          --
          DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.prod_id), 'MULTI')           prod_id,
          DECODE(COUNT(DISTINCT fd.prod_id || fd.cust_pref_vendor), 1, MIN(fd.cust_pref_vendor), '-')      cust_pref_vendor,  -- Just leave CPV at '-'
          --
          0                             qty_expected,
          --
          SUM(DECODE(fd.uom, 1, fd.qty_alloc, fd.qty_alloc / pm.spc ))    qty,
          --
          USER                          user_id,
          MIN(fd.order_id)              order_id,       
          MIN(fd.src_loc)               src_loc,       -- FYI All the float detail records should have the same location.
          f.route_no                    route_no,
          r.truck_no                    truck_no,
          --
          DECODE(COUNT(DISTINCT fd.stop_no), 1, MIN(fd.stop_no), 999)    stop_no,
          --
          f.door_no                     dest_loc,
          f.xdock_pallet_id             pallet_id,
          0                             uom,
          MIN(fd.rec_id)                rec_id,
          MIN(fd.lot_id)                lot_id,
          MIN(fd.exp_date)              exp_date,
          MIN(fd.mfg_date)              mfg_date,
          f.float_no                    float_no,
          MIN(fd.order_line_id)         order_line_id,       
          MIN(ordd.sys_order_id)        sys_order_id,
          MIN(ordd.sys_order_line_id)   sys_order_line_id,
          MIN(fd.seq_no)                float_detail_seq_no,
          f.cross_dock_type             cross_dock_type,
          'SITE 2 CROSS DOCK PALLET.  THE TRANSACTION QTY IS THE NUMBER OF PIECES ON THE PALLET.'   cmt,
          --
          -- Get count PIKs already exting for the for tha pallet.  If one exists we do not create another
          -- except if the PIK exists before route recovered--if recovered.
          (SELECT count(*)
             FROM trans t
            WHERE t.pallet_id        = f.xdock_pallet_id
              AND t.trans_type || '' = 'PIK'                 -- Make it use the index on trans.pallet_id
              AND t.trans_date       >
                                        NVL((SELECT MAX(t2.trans_date) FROM TRANS t2 WHERE t2.route_no = f.route_no AND t2.trans_type = 'RVT'), SYSDATE - 100)
              AND t.route_no         = f.route_no) pik_count
     FROM
          floats       f,
          float_detail fd,
          route        r,
          pm           pm,
          ordd         ordd
    WHERE 
          f.route_no              = cp_route_no
      AND fd.float_no             = f.float_no
      AND f.pallet_pull           = 'B'           -- Site 2 cross dock pallets are always bulk pulls
      AND f.cross_dock_type       = 'X'           -- Site 2 has 'X' for the cross dock type
      AND pm.prod_id              = fd.prod_id
      AND pm.cust_pref_vendor     = fd.cust_pref_vendor
      AND r.route_no              = f.route_no
      AND ordd.order_id           = fd.order_id
      AND ordd.order_line_id      = fd.order_line_id
    GROUP BY
          f.float_no,
          f.route_no,
          r.truck_no,
          f.cross_dock_type,
          f.door_no,
          f.xdock_pallet_id,
          f.cross_dock_type
    ORDER BY
          f.float_no;

BEGIN
   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Starting procedure'
                      || ' i_route_no[' ||  i_route_no || ']'
                      || '  Site 2 - This procedure creates one PIK transaction for each "X" cross'
                      || ' dock pallet on the route.'
                      || '  The trans.qty is the number of pieces on the pallet.'
                      || '  The trans.uom will always be 0.',
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

   --
   -- Initialization
   --
   l_num_piks_created   := 0;
   l_num_piks_existing  := 0;

   FOR r_pik IN c_pik(i_route_no)
   LOOP
      --
      -- Create the PIK for the pallet if there is not already one.
      --
      IF (r_pik.pik_count = 0) THEN
         BEGIN
            INSERT INTO trans
                  (trans_id,
                   trans_type,
                   trans_date,
                   prod_id,
                   cust_pref_vendor,
                   qty_expected,
                   qty,
                   user_id,
                   order_id,
                   src_loc,
                   route_no,
                   truck_no,
                   stop_no,
                   dest_loc,
                   pallet_id,
                   uom,
                   rec_id,
                   lot_id,
                   exp_date,
                   mfg_date,
                   float_no,
                   order_line_id,
                   sys_order_id,
                   sys_order_line_id,
                   float_detail_seq_no,
                   cross_dock_type,
                   cmt)
            VALUES
                  (trans_id_seq.NEXTVAL,         --  trans_id
                   r_pik.trans_type,
                   r_pik.trans_date,
                   r_pik.prod_id,
                   r_pik.cust_pref_vendor,
                   r_pik.qty_expected,
                   r_pik.qty,
                   r_pik.user_id,
                   r_pik.order_id,       
                   r_pik.src_loc,
                   r_pik.route_no,
                   r_pik.truck_no,
                   r_pik.stop_no,
                   r_pik.dest_loc,
                   r_pik.pallet_id,
                   r_pik.uom,
                   r_pik.rec_id,
                   r_pik.lot_id,
                   r_pik.exp_date,
                   r_pik.mfg_date,
                   r_pik.float_no,
                   r_pik.order_line_id,       
                   r_pik.sys_order_id,
                   r_pik.sys_order_line_id,
                   r_pik.float_detail_seq_no,
                   r_pik.cross_dock_type,
                   r_pik.cmt);

            l_num_piks_created := l_num_piks_created + 1;
         EXCEPTION
            WHEN OTHERS THEN
               --
               -- There was problem with the insertrst.  Log message but do not stop processing.
               -- Not creating a PIK transaction is not a show stopper.
               --
               pl_log.ins_msg
                   (i_msg_type         => pl_log.ct_warn_msg,
                    i_procedure_name   => l_object_name,
                    i_msg_text         => 'TABLE=trans  ACTION=INSERT'
                               || '  i_route_no['      || i_route_no              || ']'
                               || '  r_pik.float_no['  || TO_CHAR(r_pik.float_no) || ']'
                               || '  r_pik.pallet_id[' || r_pik.pallet_id         || ']'
                               || '  MESSAGE="Site 2 Failed to create PIK transaction for the cross dock pallet.  This is not a fatal error."',
                    i_msg_no           => SQLCODE,
                    i_sql_err_msg      => SQLERRM,
                    i_application_func => ct_application_function,
                    i_program_name     => gl_pkg_name,
                    i_msg_alert        => 'N');
         END;
      ELSE
         l_num_piks_existing  := l_num_piks_existing + 1;
      END IF;
   END LOOP;

   pl_log.ins_msg
          (i_msg_type         => pl_log.ct_info_msg,
           i_procedure_name   => l_object_name,
           i_msg_text         => 'Ending procedure'
                      || ' i_route_no[' ||  i_route_no || ']'
                      || '  Number of PIK transactions created: '          || TO_CHAR(l_num_piks_created)
                      || '  Number of PIK transactions already existing: ' || TO_CHAR(l_num_piks_existing),
           i_msg_no           => NULL,
           i_sql_err_msg      => NULL,
           i_application_func => ct_application_function,
           i_program_name     => gl_pkg_name,
           i_msg_alert        => 'N');

EXCEPTION
   WHEN OTHERS THEN
      --
      -- Oracle error.  Log message but do not stop processing.
      -- Not creating a PIK transaction is not a show stopper.
      --
      pl_log.ins_msg
                (i_msg_type         => pl_log.ct_warn_msg,
                 i_procedure_name   => l_object_name,
                 i_msg_text         => 'i_route_no['      || i_route_no              || ']'
                            || ' Error creating PIK transactions.  This will not stop processing.',
                 i_msg_no           => SQLCODE,
                 i_sql_err_msg      => SQLERRM,
                 i_application_func => ct_application_function,
                 i_program_name     => gl_pkg_name,
                 i_msg_alert        => 'N');
END create_pik_transactions;


END pl_xdock_op_merge;    -- end package body
/



CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_op_merge FOR swms.pl_xdock_op_merge;
GRANT EXECUTE ON swms.pl_xdock_op_merge TO SWMS_USER;

