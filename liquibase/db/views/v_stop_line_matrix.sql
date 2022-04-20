------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_stop_line_matrix
--
-- Description:
--    This view is used by order processing to to allocate inventory for
--    matrix items.
--
--    **********************************************************
--    ***** README    README    README    README    README *****
--    Note:  Floats are built from selecting from these views.
--              v_stop_line_home
--              v_stop_line_floating
--              v_stop_line_miniload 
--              v_stop_line_matrix  
--    Which means we need to be sure an ORDD record is selected from only one
--    of these views otherwise we will over pick and over allocate the item.
--
--
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/04/14 prpbcb   Symbotic project
--
--                      Created.  Patterned after V_STOP_LINE_MINILOAD.
--   
--                      Currently uses non-existent syspar
--                      CASE_UP_MATRIX_SPLIT_ORDER which can control to
--                      case up a split order if auto_ship_flag is N.
--                      When auto_ship_flag is N split orders and never cased
--                      up.  We will see if we need this syspar.
--
------------------------------------------------------------------------------
--                      ***** NOTE  NOTE  NOTE  NOTE  NOTE  NOTE  NOTE *****
--                      I carried over the below comments from
--                      "v_stop_line_miniload.sql" since they describe how
--                      the auto_ship_flag is used
--    07/01/13 prpbcb   TFS
--                      Project:
--       R12.6--WIB#160--CRQ46812_SWMS_cases_up_split_order_for_miniloader_item
--
--                      SWMS is casing up an order for splits for a miniloader
--                      item.  This can end up shorting the case if there are
--                      only splits in inventory for the item.  For miniloader
--                      items SWMS should not case up a split order.  For
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
--                      No changes were made to the other two views (other than
--                      to format the SQL) since they do not select miniloader
--                      items.  View V_STOP_LINE_MINILOAD is the view that
--                      needed to be changed.
--
--                      In the inline view changed
--                         p.auto_ship_flag,
--                      to
-- DECODE(p.miniload_storage_ind, 'B', 'Y', 'S', 'Y', p.auto_ship_flag) auto_ship_flag
--                      Thinking about this more I probably could have just used
--                         'Y' auto_ship_flag
--                      but I will leave the DECODE.
--
--                      A more complete change would be to leave auto_ship_flag
--                      as is, add miniload_storage_ind to the views then
--                      change gen_float.pc to look at miniload_storage_ind.
--                      We will save this for a later date.
--
--                      NOTE: I added selecting a syspar that does not exist
--                            so that if in the future we need to control to
--                            case up or not case up a split miniloader order
--                            for items with auto_ship_flag = N
--                            we just need to create the syspar.  The syspar
--                            name used is CASE_UP_MINILOAD_SPLIT_ORDER.
--                            The valid values for the syspar would be Y or N.
--                            Y - case up miniloader split order
--                            N - do not case up miniloader split order
--
--                            As a reminder if pm.auto_ship_flag is Y we never
--                            case up an split order.
------------------------------------------------------------------------------
--
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    11/04/14 prpbcb   Symbotic project
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
--    01/22/15 bben0556 Symbotic project
--                      Add ordd uom = 2 so only case orders are considered.
--
--    01/09/16 bben0556 Brian Bent
--                      Project:
--              R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--                      Throttling changes.
--
--                      Comment out:
--                         p.mx_item_assign_flag = 'Y'
--                      We want to allocate from the matrix first regardless
--                      if the item is flagged as a matrix item or not.
--                      The rule is to allocate from the matrix first if the 
--                      item has inventory in the matrix.
--
--                      Note that if the item is not a matrix item then no
--                      DMD will be created as we do not want to do that.
--                      Logic in the other programs changed for throttling
--                      will handle that.
--
--    05/02/16 bben0556 Brian Bent
--                      Project:
--                R30.4--WIB#625--Charm6000011676_Symbotic_Throttling_enhancement
--                      Throttling fixes.
--
--                      During testing before installing R30.4 at OpCo 001 I found
--                      items were being double allocated.  Float detail records were
--                      created twice for each ORDD line item because I had
--                      commented out "p.mx_item_assign_flag = 'Y'".  This needs
--                      to be there othewise the ORDD record is selected by this view
--                      and view V_STOP_LINE_FLOATING.  I uncommented it.
--                      A ORDD record be selected by one and only one of the
--                      V_STOP_LINE...  views.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_stop_line_matrix
(
   route_no,
   order_id,
   order_line_id,
   ordd_seq,
   prod_id,
   cust_pref_vendor,
   qty_remaining,
   stop_no,
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
   label_seq_pik_path,
   unitize_ind,
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
       label_seq_pik_path,
       fl_item.unitize_ind,
       l.pik_path,
       DECODE (label_seq_pik_path, 'Y', l.pik_path, NULL) pik_path_desc,
       DECODE (label_seq_pik_path, 'N', l.pik_path, NULL) pik_path_asc
  FROM (  -- start inline view
        SELECT s.route_no,
               s.order_id,
               s.order_line_id,
               s.seq             ordd_seq,
               s.prod_id,
               s.cust_pref_vendor,
               (s.qty_ordered - NVL(s.qty_alloc,0)) qty_remaining,
               s.stop_no, 
               s.uom,
               p.case_cube,
               p.spc,
               p.split_trk,
               --
               --
               (CASE p.auto_ship_flag
                   WHEN 'Y' THEN 'Y'
                   ELSE (CASE syspar.case_up_split_order
                            WHEN 'Y' THEN 'N'
                            ELSE 'Y'
                        END)
               END)   auto_ship_flag,
               r.method_id,
               r.truck_no,
               r.f_door,
               r.c_door,
               r.d_door,
               o.unitize_ind,
               p.last_ship_slot,
               (SELECT lz.logi_loc || '  ' || DECODE(s.zone_id, 'UNKP', lz.zone_id, s.zone_id)
                  FROM zone z,
                       lzone lz
                 WHERE (   lz.logi_loc =
                               (SELECT i.plogi_loc
                                  FROM inv i
                                 WHERE i.prod_id (+)          = p.prod_id
                                   AND i.cust_pref_vendor (+) = p.cust_pref_vendor
                                   AND i.status               = 'AVL'
                                   AND ROWNUM                 = 1)
                        OR (lz.logi_loc = p.last_ship_slot)
                       )
                   AND z.zone_id = lz.zone_id
                   AND z.zone_type = 'PIK'
                   AND ROWNUM = 1) loc_zone_id
          FROM route r,
               ordm o,
               ordd s,
               pm p,
               --
               -- 11/04/2014  Brian Bent  Inline view to select the syspar that controls
               -- casing up a split order.  To get the main query to returns records
               -- the inline view needs to return a record so I used a group function
               -- which assures one record will be selected even when the syspar
               -- does not exist.
               -- As a reminder if pm.auto_ship_flag is Y we never case up a
               -- split order.
               --
               (SELECT NVL(MIN(config_flag_val), 'Y') case_up_split_order
                  FROM sys_config 
                 WHERE config_flag_name = 'CASE_UP_MATRIX_SPLIT_ORDER') syspar
               --
         WHERE 1=1
           AND p.mx_item_assign_flag = 'Y'
           AND s.prod_id             = p.prod_id
           AND s.cust_pref_vendor    = p.cust_pref_vendor
           AND s.qty_ordered         > nvl(s.qty_alloc,0)
           AND o.order_id            = s.order_id
           AND r.route_no            = s.route_no
           AND s.uom                 = 2            -- Only cases are in the matrix.
       ) fl_item,   -- end inline view
       --
       (SELECT config_flag_val label_seq_pik_path FROM sys_config WHERE config_flag_name = 'LABEL_SEQ_PIK_PATH'),
       --
       loc l,
       sel_method_zone sz 
 WHERE
       l.logi_loc   = RTRIM(SUBSTR(fl_item.loc_zone_id, 1, INSTR(fl_item.loc_zone_id, ' ') - 1))
   AND sz.method_id = fl_item.method_id
   AND sz.zone_id   = LTRIM(SUBSTR(fl_item.loc_zone_id, INSTR(fl_item.loc_zone_id, ' ') + 1))
/

CREATE OR REPLACE PUBLIC SYNONYM v_stop_line_matrix
FOR swms.v_stop_line_matrix
/

GRANT SELECT ON v_stop_line_matrix TO swms_user;
GRANT SELECT ON v_stop_line_matrix TO swms_viewer;

