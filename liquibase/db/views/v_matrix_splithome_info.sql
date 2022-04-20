------------------------------------------------------------------------------
-- View:
--    v_matrix_splithome_info
--
-- Description:
--    This view provide information about matrix inventory, warehouse inventory and existing replenishment
--    to create new replenishment task
--
-- Used by:
--    - pl_matrix_repl.sql
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/17/14 ayad5195 Initial Creation
--    06/14/16 bben0556 Brian Bent
--                      Project:
--       R30.4.2--WIB#646--Charm6000013323_Symbotic_replenishment_fixes
--
--                      DSP not getting created when there is qty planned to
--                      the split home for a putaway.  "pl_matrix_repl.sql"
--                      uses column "curr_resv_split_qty" from this view for
--                      the qty in the split home.  This column includes the
--                      qty planned to the split home so qty planned for a
--                      putaway to the split home is considered "pickable" 
--                      inventory which it is not.  Changed the inline view
--                      for the split home qty to  have separate columns for
--                      the split home qoh and qty planned.
--                      "pl_matrix_repl.sql" also changed to use the new column
--                      names.  Also changed this inline view to key off the LOC
--                      table for the split home.  Below is the before and after.
--                      This:
/**********
       (SELECT i.prod_id,
               i.cust_pref_vendor,
               SUM(i.qoh + NVL(i.qty_planned, 0)) qty_resv_split
          FROM pm p,
               zone z,
               lzone lz,
               inv i
         WHERE z.zone_type           = 'PUT'
           AND z.rule_id             IN (0, 1, 2) 
           AND z.induction_loc       IS NULL
           AND lz.zone_id            = z.zone_id
           AND i.plogi_loc           = lz.logi_loc
           AND i.status              = 'AVL'
           AND i.inv_uom             = 1
           AND p.prod_id             = i.prod_id
           AND i.logi_loc            = i.plogi_loc 
           AND p.cust_pref_vendor    = i.cust_pref_vendor
           AND p.mx_item_assign_flag = 'Y'
         GROUP BY i.prod_id, i.cust_pref_vendor) split_home,  --Split Home Inventory
**********/
--                      changed to:
/**********
       (SELECT i.prod_id,
               i.cust_pref_vendor,
               SUM(i.qty_planned)          split_home_qty_planned,
               SUM(i.qoh)                  split_home_qoh,
               SUM(i.qoh + i.qty_planned)  split_home_qoh_qty_planned
          FROM pm p,
               inv i,
               loc
         WHERE p.prod_id             = loc.prod_id
           AND p.cust_pref_vendor    = loc.cust_pref_vendor
           AND loc.uom               = 1
           AND loc.rank              = 1
           AND i.plogi_loc           = loc.logi_loc
           AND i.status              = 'AVL'
           AND i.logi_loc            = i.plogi_loc  -- Failsave for the inv home slot record
           AND i.prod_id             = p.prod_id
           AND i.cust_pref_vendor    = p.cust_pref_vendor
           AND p.mx_item_assign_flag = 'Y'
         GROUP BY i.prod_id, i.cust_pref_vendor) split_home,  --Split Home Inventory
**********/
--    
--    
--                      Format the SQL to make it easier to read.
--
--                      DSP not getting created when the only case inventory is in
--                      the staging, outduct, induction location or spur.  The split order
--                      shorts.  Added fields:
--                         - curr_mx_cases_mxi
--                         - curr_mx_cases_mxo
--                         - curr_mx_cases_mxs
--                         - curr_mx_cases_mxt
--                         - curr_mx_cases_mxp
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_matrix_splithome_info
      (area, 
       prod_id,
       cust_pref_vendor, 
       spc,
       split_trk,
       ship_split_only,
       max_mx_cases,
       zone_id, 
       min_mx_cases,
       curr_mx_cases,
       curr_mx_cases_mxi,
       curr_mx_cases_mxo,
       curr_mx_cases_mxs,
       curr_mx_cases_mxt,
       curr_mx_cases_mxp,
       split_home_qoh,
       split_home_qty_planned,
       split_home_qoh_qty_planned,
       case_qty_for_split_rpl,
       curr_repl_cases,
       case_cube)
AS
SELECT p.area,
       p.prod_id,
       p.cust_pref_vendor,
       p.spc,
       p.split_trk,
       p.auto_ship_flag,  
       NVL(p.mx_max_case, 0) max_mx_cases,
       p.zone_id,
       p.mx_min_case                                       min_mx_cases,
       TRUNC(NVL(mx.qty_avl, 0) / p.spc)                   curr_mx_cases,          
       TRUNC(NVL(mx.qty_avl_mxi, 0) / p.spc)               curr_mx_cases_mxi,
       TRUNC(NVL(mx.qty_avl_mxo, 0) / p.spc)               curr_mx_cases_mxo,
       TRUNC(NVL(mx.qty_avl_mxs, 0) / p.spc)               curr_mx_cases_mxs,
       TRUNC(NVL(mx.qty_avl_mxt, 0) / p.spc)               curr_mx_cases_mxt,
       TRUNC(NVL(mx.qty_avl_mxp, 0) / p.spc)               curr_mx_cases_mxp,
       NVL(split_home_qoh, 0)                              split_home_qoh,
       NVL(split_home_qty_planned, 0)                      split_home_qty_planned,
       NVL(split_home.split_home_qoh_qty_planned, 0)       split_home_qoh_qty_planned,
       NVL(p.case_qty_for_split_rpl, 0)                    case_qty_for_split_rpl,
       NVL(rpl.qty_rpl, 0)                                 repl_cases,
       p.case_cube
  FROM pm p, 
       --
       -- Inline view for the qty in the matrix.  Including staging, outduct, induction and spurs.
       --
       (SELECT i.prod_id,
               i.cust_pref_vendor,     
               SUM(qoh) qoh,
               SUM(DECODE(z.induction_loc, i.plogi_loc, DECODE(i.qty_planned, 0, 0, 1),
                                           0)) num_replen,
               SUM(i.qoh - i.qty_alloc) qty_avl,
               SUM((CASE
                       WHEN loc.slot_type IN ('MXI') THEN (i.qoh - i.qty_alloc) 
                       ELSE 0
                   END)) qty_avl_mxi,
               SUM((CASE
                       WHEN loc.slot_type IN ('MXO') THEN (i.qoh - i.qty_alloc) 
                       ELSE 0
                   END)) qty_avl_mxo,
               SUM((CASE
                       WHEN loc.slot_type IN ('MXS') THEN (i.qoh - i.qty_alloc) 
                       ELSE 0
                   END)) qty_avl_mxs,
               SUM((CASE
                       WHEN loc.slot_type IN ('MXT') THEN (i.qoh - i.qty_alloc) 
                       ELSE 0
                   END)) qty_avl_mxt,
               SUM((CASE
                       WHEN loc.slot_type IN ('MXP') THEN (i.qoh - i.qty_alloc) 
                       ELSE 0
                   END)) qty_avl_mxp
          FROM pm p,
               zone z,
               lzone lz,
               inv i,
               loc
         WHERE z.zone_type           = 'PUT'
           AND z.rule_id             = 5
           AND z.induction_loc       IS NOT NULL
           AND lz.zone_id            = z.zone_id
           AND i.plogi_loc           = lz.logi_loc
           AND i.status              = 'AVL'
           AND i.inv_uom             IN (0, 2)
           AND p.prod_id             = i.prod_id
           AND p.cust_pref_vendor    = i.cust_pref_vendor
           AND p.mx_item_assign_flag = 'Y'     
           AND loc.logi_loc          = i.plogi_loc
         GROUP BY i.prod_id, i.cust_pref_vendor ) mx,     --Matrix Inventory 
       --
       --
       -- Inline view for the qty in the split home.
       -- Note: If the item has multiple split homes (though should not) then
       -- creating the DSP(s) will probably not work as desired.
       --
       (SELECT i.prod_id,
               i.cust_pref_vendor,
               SUM(i.qty_planned)          split_home_qty_planned,
               SUM(i.qoh)                  split_home_qoh,
               SUM(i.qoh + i.qty_planned)  split_home_qoh_qty_planned
          FROM pm p,
               inv i,
               loc
         WHERE p.prod_id             = loc.prod_id
           AND p.cust_pref_vendor    = loc.cust_pref_vendor
           AND loc.uom               = 1
           AND loc.rank              = 1
           AND i.plogi_loc           = loc.logi_loc
           AND i.status              = 'AVL'
           AND i.logi_loc            = i.plogi_loc  -- Failsave for the inv home slot record
           AND i.prod_id             = p.prod_id
           AND i.cust_pref_vendor    = p.cust_pref_vendor
           AND p.mx_item_assign_flag = 'Y'
         GROUP BY i.prod_id, i.cust_pref_vendor) split_home,  --Split Home Inventory
       --
       --
       -- Inline view for existing replenishments for the item.
       --
       (SELECT r.prod_id,
               r.cust_pref_vendor,
               SUM(r.qty) qty_rpl
          FROM pm p,
               zone z,
               lzone lz,
               replenlst r
         WHERE z.zone_type           = 'PUT'
           AND r.type                IN ('NSP', 'DSP', 'UNA')
           AND z.rule_id             IN (0, 1, 2)
           AND lz.zone_id            = z.zone_id
           AND r.dest_loc            = lz.logi_loc
           AND r.uom                 = 2        
           AND p.prod_id             = r.prod_id
           AND p.cust_pref_vendor    = r.cust_pref_vendor    
           AND p.mx_item_assign_flag = 'Y'    
         GROUP BY r.prod_id, r.cust_pref_vendor) rpl     --Existing replenishment Quantity
 WHERE p.mx_item_assign_flag = 'Y'
   AND p.prod_id             = mx.prod_id (+)
   AND p.cust_pref_vendor    = mx.cust_pref_vendor (+)
   AND p.prod_id             = split_home.prod_id --(+)
   AND p.cust_pref_vendor    = split_home.cust_pref_vendor --(+)
   AND p.prod_id             = rpl.prod_id (+)
   AND p.cust_pref_vendor    = rpl.cust_pref_vendor (+);


