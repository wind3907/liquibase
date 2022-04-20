------------------------------------------------------------------------------
-- File:
--    v_xdock_float_detail_in.sql
--
-- View:
--    v_xdock_float_detail_in
--
-- Description:
--    Project: R1 Cross docking  (Xdock)
--             Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--    Script to create a view of the XDOCK_FLOAT_DETAIL_IN table.
--    This view is used at Site 2 to merge in the cross dock floats sent from Site 1.
--
--    These 'X' cross dock info needs to be in these tables:
--       ORDM
--       ORDD
--       XDOCK_FLOATS_IN
--       XDOCK_FLOAT_DETAIL_IN
--    otherwise nothing will be selected.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/18/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--                      Created.
--
--                      Main purpose of this view is to get the Site 2 route number
--                      and to select only the lastest float if the floats sent
--                      multiple times from Site 1 to Site 2.
--                      ***** 08/18/21  Brian Bent  Selecting latest float not done yet.
--
--
--    09/15/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3663_OP_Site_2_Merge_float_ordcw_sent_from_Site_1
--
--                      Select putawaylst.dest_loc for the xdock_pallet_id.
--                      If the pallet is received before the route is opened the put dest_loc
--                      is used for the float_detail.src_loc and the replenlst.src_loc.
--                      It the put dest_loc is a door and includes the dock numger
--                      The dock number is stripped off.  We want the physical door number
--                      in float_detail.src_loc and replenst.src_loc.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_xdock_float_detail_in
AS
SELECT
       fdx.sequence_number,
       fdx.batch_id,
       fdx.float_no,
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
       --
       -- Need the Site 2 order id.
       (SELECT ordd.order_id              
          FROM ordd
         WHERE ordd.seq = fdx.order_seq)    site_to_order_id,
       --
       fdx.order_line_id,
       fdx.cube,
       fdx.copy_no,
       fdx.merge_float_no,
       fdx.merge_seq_no,
       fdx.cust_pref_vendor,
       fdx.clam_bed_trk,
       fdx.route_no,
       --
       --
       -- Need the Site 2 route number
       (SELECT ordd.route_no              
          FROM ordd
         WHERE ordd.seq = fdx.order_seq)    site_to_route_no,
       --
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
       fdx.add_date,
       fdx.add_user,
       fdx.upd_date,
       fdx.upd_user,
       -- 
       -- If the pallet received at Site 2 get the put dest_loc.
       -- If the put dest_loc is a door do not include the dock.
       (SELECT NVL(door.physical_door_no, put.dest_loc)
          FROM putawaylst put,
               xdock_floats_in fx,
               door
         WHERE fx.float_no        = fdx.float_no
           AND fx.batch_id        = fdx.batch_id
           AND put.pallet_id      = fx.parent_pallet_id
           AND door.door_no  (+)  = put.dest_loc)  put_dest_loc
  FROM
       xdock_float_detail_in fdx
/



CREATE OR REPLACE PUBLIC SYNONYM v_xdock_float_detail_in FOR swms.v_xdock_float_detail_in;

GRANT SELECT ON swms.v_xdock_float_detail_in TO swms_user;
GRANT SELECT ON swms.v_xdock_float_detail_in TO swms_viewer;

