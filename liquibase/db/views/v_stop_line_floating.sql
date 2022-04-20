------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_stop_line_floating
--
-- Description:
--    This view is used by order processing when building floats for
--    items with a home slot.
--
--
--    **********************************************************
--    ***** README    README    README    README    README *****
--    **********************************************************
--    Note:  Floats are built from selecting from these views.
--              v_stop_line_home
--              v_stop_line_floating
--              v_stop_line_miniload
--              v_stop_line_matrix   -- 06/20/21 As of about 2 years ago we
--                                      no longer have symbotic so this view
--                                      is not applicable any more.
--    Which means we need to be sure an ORDD record is selected from only one
--    of these views otherwise we will over pick and over allocate the item.
--
--
--    Below is an example of the records selected.  As can be seen each order id--order line id
--    is selected 3 times.  One for NOR, one for PAL and one for UNI.  A record will be
--    selected for each sel type(the standard ones are NOR, PAL and UNI) setup in the
--    selection method for the ordd.zone_id.  The "gen float" program selects from this view
--    for specified sel types.
--       SELECT route_no, order_id, order_line_id, stop_no, zone_id,
--              prod_id, uom, method_id, group_no,
--              sel_type,
--              cross_dock_type, site_from, site_to
--         FROM v_stop_line_floating
--        ORDER BY order_id, order_line_id, method_id, group_no, prod_id, uom
--       ROUTE_NO   ORDER_ID       ORDER_LINE_ID    STOP_NO ZONE_ID           PROD_ID          UOM METHOD_ID    GROUP_NO SEL CROSS_DOCK_TYPE SITE_ SITE_
--       ---------- -------------- ------------- ---------- ----------------- --------- ---------- ---------- ---------- --- --------------- ----- -----
--       I4231      299291702                  4        231 DAPIK             7128159            2 IMM                10 PAL
--       I4231      299291702                  4        231 DAPIK             7128159            2 IMM                20 NOR
--       I4231      299291702                  4        231 DAPIK             7128159            2 IMM                30 UNI
--       1025       299292173                  1          2 CEPIK             1691858            2 NSTD4              60 NOR
--       1025       299292173                  1          2 CEPIK             1691858            2 NSTD4             100 PAL
--       1025       299292173                  1          2 CEPIK             1691858            2 NSTD4             160 UNI
--
--
-- Modification History:
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/01/13 prpbcb   TFS
--                      Project:
--        R12.6--WIB#160--CRQ46812_SWMS_cases_up_split_order_for_miniloader_item
--
--                      SWMS is casing up an order for splits for a miniloader
--                      item.  This can end up shorting the case if there are
--                      only splits in inventory for the item.  For miniloader
--                      items SWMS should not cases up a split order.  For
--                      the time being we will change views
--                         V_STOP_LINE_FLOATING
--                         V_STOP_LINE_HOME
--                         V_STOP_LINE_MINILOAD
--                      to look at the miniload storage ind when determining
--                      the value to use for auto_ship_flag.  gen_float.pc
--                      looks at auto_ship_flag as part of the criteria in
--                      casing uyp a split order.  If auto_ship_flag is 'Y'
--                      then gen_float.pc will not case up a split order.
--
--                      README   README   README   README   README
--                      No changes were made to this view (other than to
--                      format the SQL) since it selects
--                      home slot items.  View V_STOP_LINE_MINILOAD is the
--                      view that needed to be changed.
--
--                      A more complete change would be to leave auto_ship_flag
--                      as is, add miniload_storage_ind to the views then
--                      change gen_float.pc to look at miniload_storage_ind.
--                      We will save this for a later date.
--
--                      Format the SQL to make it easier to read.
--
--    11/14/14 prpbcb   Symbotic project
--                      Add columns:
--                         - truck_no  from  route.truck_no
--                         - f_door    from  route.f_door
--                         - c_door    from  route.c_door
--                         - d_door    from  route.d_door
--                         - ordd_seq  from  ordd.seq
--                      The goal is to populate floats.truck_no,
--                      floats.door_no and float_detail.order_seq when creating
--                      the floats in gen_float.pc and not populate them
--                      in pl_sos.sql
--
--
--    01/09/15 prpbcb   Symbotic project
--                      Need to exclude matrix items.
--                      Added:
--                         AND NVL(p.mx_item_assign_flag, 'N') = 'N'
--
--    09/23/19 bben0556 Brian Bent
--                      Project: R30.6.8-Jira-OPCOF-2517-CMU-Project_cross_dock_picking
--
--                      For orders being picked at the RDC and the RDC does not send the full
--                      qty requested do not fall through to OpCo picking to pick the remaining qty.
--                      This is to resolve an issue were the STS barcode is duplicated if we fall through
--                      to OpCo picking.  Plus, this would not be a normal situation as SUS would
--                      first order the inventory at the OpCo before going to the RDC so ideally there
--                      would be no inventory left at the OpCo to cover what the RDC did not send.
--                      Example:
--                         REMOTE_LOCAL_FLG  QTY_ORDERED  REMOTE_QTY   OpCo Qty   RDC Sends This Qty     What we will do
--                         --------------------------------------------------------------------------------------------
--                                 R            5 CS        5 CS         2 CS          4 CS              Short 1 cases
--                                 B           10 CS        6 CS         4 CS          4 CS              Short 2 cases
--                          Remember if the ORDD.REMOTE_LOCAL_FLG is B we create another ORDD record for the qty
--                          to pick at the OpCo.
--
--                      Added this to the where clause:
--                         AND NVL(s.remote_qty, 0) = 0
--                          to pick at the OpCo.
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    06/29/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47-xdock-OPCOF3380_OP_Site_1_Build_pallets_by_number_of_stops_syspar
--
--                      Add columns to view: (not all may necessarily be used but added as "info" when
--                                            selecting directly from the view).
--                         - cross_dock_type    from ordm.cross_dock_type   See description below.
--                         - site_from          from ordm.site_from         Fulfillment site. (Site 1)
--                         - site_to            from ordm.site_to           Last mile site. (Site 2)
--                         - site_to_route_no   from ordm.site_to_route_no
--                         - site_to_stop_no    from ordm.site_to_route_no
--                         - site_to_truck_no   from ordm.site_to_route_no
--                         - site_to_door_no    from ordm.site_to_route_no
--                         - sel_type           from sel_method.sel_type    Having this column in the view helps to understand the records
--                                                                          when selecting from the view directly such as for debugging
--                                                                          and verifying the data in the view.
--                         - NVL(o.site_to_stop_no, s.stop_no) stop_no,
--                         - o.stop_no                         site_from_stop_no,
--
--                      Description:
--                         - cross_dock_type
--                           This column designates the type of cross dock.
--                           It is populated in the OR reader program with the document type sent by SUS.
--                           Valid values are 'S' or 'X'.
--                           Note: SUS folks will be calling this the document type.  On SWMS it is
--                                 the cross dock type.
--
--                           Column cross_dock_type was first created for European Imports cross docking and then used for CMU.
--                           Now we use it for R1 cross docking.
--                           As of 6/29/2021 these are the values of the cross dock type.
--                           Value Meaning
--                           ----- -------------------------------------------------------------
--                           S     Site 1 OpCo.  This is the fulfillment OpCo--the OpCo picking the order.
--                                 The picking process will be almost identical to a non-cross dock order
--                                 with the exception of how the floats are built.
--
--                           X     Site 2 OpCo.  This is the OpCo where the pallet will be cross
--                                 docked.  A shuttle will deliver the pallet(s) from Site 1 to
--                                 Site 2.  Site 2 will receive (special receiving for cross dock pallets)
--                                 the cross pallets via SN sent from Site 1 and then load the pallets
--                                 onto the truck going to the end customer.  The cross dock pallets
--                                 can first go to a staging area before loading onto the truck
--                                 depending on the timing of events.
--
--
--                      We do not want to select the orders with ordm.cross_dock_type = 'X'.  The 'X' orders do not run
--                      through the regular picking logic but rather have different processing.
--                      Modify where clause.
--                      Add:
--                         AND (o.cross_dock_type = 'S' OR o.cross_dock_type IS NULL)
--
--                      For this card changes made to (list my not be complete):
--                         - gen float package
--                         - v_stop_line_home.sql
--                         - v_stop_line_floating.sql 
--                         - v_stop_line_miniload.sql
--                         - v_stop_line_matrix.sql   -- Did not change since we no longer have symbotic
--                         - pl_common.sql
--                         - Move records from main table to backup table script
--
--                      Modify join adding table sel_method in order to get the sel_type.
--
-----------------------------------------------------------------------------
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_stop_line_floating
(
   route_no,
   order_id,
   order_line_id,
   ordd_seq,
   prod_id,
   cust_pref_vendor,
   qty_remaining,
   stop_no,
   site_from_stop_no,
   zone_id,
   seq_no_desc,
   seq_no_asc,
   uom,
   case_cube,
   spc,
   split_trk,
   auto_ship_flag,
   method_id,
   truck_no,
   f_door,
   c_door,
   d_door,
   group_no,
   sel_type,
   label_seq_pik_path,
   unitize_ind,
   cross_dock_type,
   site_from,
   site_to,
   site_to_route_no,
   site_to_stop_no,
   site_to_truck_no,
   site_to_door_no,
   pik_path,
   pik_path_desc,
   pik_path_asc
)
AS
SELECT fl_item.route_no,
       fl_item.order_id,
       fl_item.order_line_id,
       fl_item.ordd_seq,
       fl_item.prod_id,
       fl_item.cust_pref_vendor,
       fl_item.qty_remaining,
       fl_item.stop_no,
       fl_item.site_from_stop_no,
       LTRIM(SUBSTR(fl_item.loc_zone_id, INSTR(fl_item.loc_zone_id, ' ') + 1)) zone_id,
       DECODE(label_seq_pik_path, 'Y', sz.seq_no, NULL) seq_no_desc,
       DECODE(label_seq_pik_path, 'N', sz.seq_no, NULL) seq_no_asc,
       fl_item.uom,
       fl_item.case_cube,
       fl_item.spc,
       fl_item.split_trk,
       fl_item.auto_ship_flag,
       fl_item.method_id,
       fl_item.truck_no,
       fl_item.f_door,
       fl_item.c_door,
       fl_item.d_door,
       sz.group_no,
       sm.sel_type,
       label_seq_pik_path,
       fl_item.unitize_ind,
       fl_item.cross_dock_type,
       fl_item.site_from,
       fl_item.site_to,
       fl_item.site_to_route_no,
       fl_item.site_to_stop_no,
       fl_item.site_to_truck_no,
       fl_item.site_to_door_no,
       l.pik_path,
       DECODE (label_seq_pik_path, 'Y', l.pik_path, NULL) pik_path_desc,
       DECODE (label_seq_pik_path, 'N', l.pik_path, NULL) pik_path_asc
  FROM (  -- start inline view
        SELECT s.route_no,
               s.order_id,
               s.order_line_id,
               s.seq            ordd_seq,
               s.prod_id,
               s.cust_pref_vendor,
               (s.qty_ordered - NVL(s.qty_alloc,0))   qty_remaining,
               NVL(o.site_to_stop_no, s.stop_no)      stop_no,
               s.stop_no                              site_from_stop_no,
               s.uom,
               p.case_cube,
               p.spc,
               p.split_trk,
               p.auto_ship_flag,
               r.method_id,
               r.truck_no,
               r.f_door,
               r.c_door,
               r.d_door,
               o.unitize_ind,
               o.cross_dock_type,
               o.site_from,
               o.site_to,
               o.site_to_route_no,
               o.site_to_stop_no,
               o.site_to_truck_no,
               o.site_to_door_no,
               p.last_ship_slot,
               --
               (SELECT lz.logi_loc || '  ' || DECODE(s.zone_id, 'UNKP', lz.zone_id, s.zone_id)
                  FROM zone z,
                       lzone lz
                 WHERE (   lz.logi_loc = (SELECT i.plogi_loc
                                            FROM inv i
                                           WHERE i.prod_id (+) = p.prod_id
                                             AND i.cust_pref_vendor (+) = p.cust_pref_vendor
                                             AND i.status = 'AVL'
                                             AND ROWNUM = 1)
                        OR (lz.logi_loc = p.last_ship_slot)
                       )
                    AND z.zone_id = lz.zone_id
                    AND z.zone_type = 'PIK'
                    AND ROWNUM = 1) loc_zone_id
               --
          FROM route r,
               ordm o,
               ordd s,
               pm p
         WHERE p.miniload_storage_ind = 'N'
           AND NVL(p.mx_item_assign_flag, 'N') = 'N'   -- Leave out matrix items.
           AND NOT EXISTS
                     (SELECT 0
                        FROM loc l
                       WHERE l.prod_id          = p.prod_id
                         AND l.cust_pref_vendor = p.cust_pref_vendor
                         AND l.perm             = 'Y')
           AND s.prod_id            = p.prod_id
           AND s.cust_pref_vendor   = p.cust_pref_vendor
           AND s.qty_ordered        > nvl(s.qty_alloc,0)
           AND o.order_id           = s.order_id
           AND r.route_no           = s.route_no
           AND NVL(s.remote_qty, 0) = 0                                   -- 09/23/2019 Brian Bent Added
           AND (o.cross_dock_type = 'S' OR o.cross_dock_type IS NULL)     -- 06/29/2021 Brian Bent Added
       ) fl_item,  -- end inline view
       --
       (SELECT config_flag_val label_seq_pik_path FROM sys_config WHERE config_flag_name = 'LABEL_SEQ_PIK_PATH'),
       --
       loc l,
       sel_method_zone sz,
       sel_method sm         -- 06/30/2010 Brian Bent  Added for R1 Xdock to get the sel_type
 WHERE
       l.logi_loc   = RTRIM(SUBSTR(fl_item.loc_zone_id, 1, INSTR(fl_item.loc_zone_id, ' ') - 1))
   AND sz.method_id = fl_item.method_id
   AND sz.zone_id   = LTRIM(SUBSTR(fl_item.loc_zone_id, INSTR(fl_item.loc_zone_id, ' ') + 1))
   AND sm.method_id = sz.method_id
   AND sm.group_no  = sz.group_no
/

CREATE OR REPLACE PUBLIC SYNONYM v_stop_line_floating
FOR swms.v_stop_line_floating
/

