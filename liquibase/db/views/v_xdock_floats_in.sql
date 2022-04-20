------------------------------------------------------------------------------
-- File:
--    v_xdock_floats_in.sql
--
-- View:
--    v_xdock_floats_in
--
-- Description:
--    Project: R1 Cross docking  (Xdock)
--             Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--    Script to create a view of the XDOCK_FLOATS_IN table.
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
--    08/18/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_float_seq_duplicating
--
--                      Select Site 2 route status
--
--
--    10/08/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3714_OP_Site_2_floats_door_area_sometimes_incorrect
--
--                      I was always using the door_area of Site 1 to determine the door number
--                      for the float.  View "v_xdock_floats_in.sql" was doing this.
--                      Modified procedure pl_xdock_op_merge.merge_floats" this procedure to look
--                      at the Site 2 door_area to determine the door number for the float.
--                      Example of the Issue:
--       ---------------- Site 1 --------------------------       ---------------- Site 2 ------------------------
--       Configured To Load Cooler Pallets at Freezer Doors       Configured To Load Cooler Pallets at Cooler Doors
--          ---------------- Float ---------------                ---------------- Float ---------------
--          door_area  comp_code  Door                            door_area  comp_code  Door
--          --------------------------------------                --------------------------------------
--              F         C       42(freezer door)                    C         C       22(freezer door) <-- Incorrect, Site 2 cooler door is 4.
--
--
--                      Modified view. Changed
--     DECODE(fx.door_area, 'C', r.c_door,    -- 08/22/21 Base Site 2 floats door no on Site 1 floats door_area, hmmmm, we will see..
--                          'D', r.d_door,
--                          'F', r.f_door,
--                               r.c_door)        site_to_door_no  
--                      to
--                      -1     site_to_door_no   -- The Site 2 door number is determined in
--                                               -- procedure "pl_xdock_op_merge.merge_floats".
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_xdock_floats_in
AS
SELECT
       fx.batch_id,
       fx.sequence_number,
       fx.batch_no,
       fx.batch_seq,
       fx.float_no,                   -- Remember this is the Site 1 float#.  When inserting into FLOATS at Site 2
                                      -- a new float# is used since the float# is unique only within the OpCo.
       fx.float_seq,
       fx.route_no,
       fx.b_stop_no,
       fx.e_stop_no,
       fx.record_status,
       fx.float_cube,
       fx.group_no,                   -- This is the Site 1 group#.  Site 2 will need to assign a group# valid at Site 2.
       fx.merge_group_no,
       fx.merge_seq_no,
       fx.merge_loc,
       fx.zone_id,
       fx.equip_id,                   -- This is the Site 1 equip id.  Site 2 will need to assign the equip id valid for the Site 2 route.
       fx.comp_code,                  -- This is the Site 1 comp code.  Site 2 will need to assign the comp code valid for the Site 2 route.
       fx.split_ind,
       fx.pallet_pull,
       fx.pallet_id,
       fx.home_slot,
       fx.drop_qty,
       fx.door_area,                   -- This is the Site 1 door area.  Site 2 will need to assign the door area valid for the Site 2 route.
       fx.single_stop_flag,
       fx.status,
       fx.ship_date,
       fx.parent_pallet_id,
       fx.fl_method_id,               -- This is the Site 1 method id.  Site 2 will need to assign the method id for the Site 2 route.
       fx.fl_sel_type,
       fx.fl_opt_pull,
       fx.truck_no,
       fx.door_no,                    -- This is the Site 1 door.  Site 2 will need to assign the door valid for the Site 2 route.
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
       ordm.route_no            site_to_route_no,
       ordm.cross_dock_type     cross_dock_type,
       r.truck_no               site_to_truck_no,
       r.method_id              site_to_method_id,
       r.status                 site_to_route_status,
       ordm.site_from           site_from,
       ordm.site_to             site_to,
       r.c_door                 site_to_c_door,
       r.d_door                 site_to_d_door,
       r.f_door                 site_to_f_door,
       --
       -1                       site_to_door_no   -- The Site 2 door number is determined in procedure "pl_xdock_op_merge.merge_floats".
       --
       --
       -- ordm.delivery_document_id   -- Do not select since a float can have multiple delivery_document_id's
                                      -- and since this view will pick a random one better to not show it.
  FROM
       xdock_floats_in fx,
       --
       xdock_float_detail_in  fdx,    -- to get the site 2 route and truck
       ordd                   ordd,   -- to get the site 2 route and truck
       ordm                   ordm,   -- to get the site 2 route and truck
       route                  r       -- to get the site 2 route and truck and doors
 WHERE
       fx.batch_id                    = fdx.batch_id
   AND fx.float_no                    = fdx.float_no
   AND fdx.order_seq                  = ordd.seq
   AND ordm.order_id                  = ordd.order_id
   AND r.route_no                     = ordm.route_no
   AND fdx.seq_no =                     -- need to limit joins to ordd and xdock_float_detail_in to return 1 record
             (SELECT MIN(fdx2.seq_no)
                FROM xdock_float_detail_in fdx2
               WHERE fdx2.batch_id = fdx.batch_id
                 AND fdx2.float_no = fdx.float_no)
/


CREATE OR REPLACE PUBLIC SYNONYM v_xdock_floats_in FOR swms.v_xdock_floats_in;

GRANT SELECT ON swms.v_xdock_floats_in TO swms_user;
GRANT SELECT ON swms.v_xdock_floats_in TO swms_viewer;

