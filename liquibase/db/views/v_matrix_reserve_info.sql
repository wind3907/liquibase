------------------------------------------------------------------------------
-- View:
--    v_matrix_reserve_info
--
-- Description:
--    This view provide information about matrix inventory, warehouse inventory and existing replenishment
--    to create new replenishment task
--
-- Used by:
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/17/14 ayad5195 Initial Creation
--    12/03/15 ayad5195 Added hist_case_order and hist_split_order 
--
--    01/22/16 bben0556 Brian Bent
--                      Project:
--               R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
--
--                      Add MXP slot type as available to pick from.
--                      The MXP slots are slots in the main warehouse with slot
--                      type MXP where matrix items are put because the case(s)
--                      could not be inducted onto the matrix because of
--                      tolerance issues.  The rule is these get allocated
--                      to orders first.
--                      There will be no replenishments from MXP slots to the
--                      mtarix for matrix items.
--                      If for whatever reason non matrix items have inventory
--                      in MXP slots then the MXP slots are treated like normal
--                      slots.
--
--                      "mx" inline view:
--                      Comment out:
--                         AND  z.rule_id = 5
--                         AND  z.induction_loc IS NOT NULL
--                         AND  l.slot_type IN ('MXF', 'MXC')
--                      Added:
--     AND  ((z.rule_id = 5 AND l.slot_type IN ('MXF', 'MXC') AND  z.induction_loc IS NOT NULL) OR l.slot_type in ('MXP'))
--
--
--                      Add to "res" inline view:
--                      "loc" table
--     AND  loc.logi_loc = lz.logi_loc
--     AND  loc.slot_type NOT IN ('MXP')
--
--                      Format the SQL to make it easier to read.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_matrix_reserve_info
(
   area,
   prod_id,
   cust_pref_vendor,
   spc,
   split_trk,
   ship_split_only,
   max_mx_cases,
   zone_id,
   --induction_loc,
   min_mx_cases,
   curr_mx_cases, 
   curr_resv_cases,
   curr_repl_cases,
   hist_case_order,
   hist_case_date,
   hist_split_order,
   hist_split_date,
   mx_item_assign_flag,
   mx_eligible,
   mx_throttle_flag
)
AS
SELECT p.area,
       p.prod_id,
       p.cust_pref_vendor,
       p.spc,
       p.split_trk,
       p.auto_ship_flag,  
       NVL(p.mx_max_case, 0)          max_mx_cases,
       p.zone_id,
       --z.induction_loc,
       p.mx_min_case                  min_mx_cases,
       NVL(mx.qty_avl, 0)   / p.spc   curr_mx_cases,   
       NVL(res.qty_resv, 0) / p.spc   curr_resv_cases,
       NVL(rpl.qty_rpl, 0)  / p.spc   repl_cases,
       NVL(p.hist_case_order, 0)      hist_case_order,
       p.hist_case_date,
       NVL(p.hist_split_order, 0)     hist_split_order,
       p.hist_split_date,
       p.mx_item_assign_flag,
       p.mx_eligible,
       p.mx_throttle_flag
  FROM  pm p, 
   --
   (SELECT  i.prod_id,
            i.cust_pref_vendor,     
            SUM(qoh) qoh,
            SUM(DECODE(z.induction_loc, i.plogi_loc, DECODE(NVL(i.qty_planned, 0), 0, 0, 1),
                                        0)) num_replen,
            SUM (i.qoh - NVL (i.qty_alloc, 0)) qty_avl
      FROM  pm p, zone z, lzone lz, inv i, loc l
     WHERE  z.zone_type         = 'PUT'
       AND  lz.zone_id          = z.zone_id
       AND  i.plogi_loc         = lz.logi_loc
       AND  l.logi_loc          = i.plogi_loc
       AND  i.status            = 'AVL'
       AND  i.inv_uom           IN (0, 2)
       AND  p.prod_id           = i.prod_id
       AND  p.cust_pref_vendor  = i.cust_pref_vendor
 --    AND  z.rule_id           = 5
 --    AND  z.induction_loc     IS NOT NULL
 --    AND  l.slot_type         IN ('MXF', 'MXC')
       AND  ((z.rule_id = 5 AND l.slot_type IN ('MXF', 'MXC') AND  z.induction_loc IS NOT NULL) OR l.slot_type in ('MXP'))
       AND  ((p.mx_item_assign_flag = 'Y' OR p.mx_throttle_flag = 'Y') AND  p.mx_eligible = 'Y')
     GROUP BY i.prod_id, i.cust_pref_vendor ) mx,             --Matrix Inventory
   --
   --
   (SELECT  i.prod_id,
            i.cust_pref_vendor,
            SUM(i.qoh - NVL (i.qty_alloc, 0)) qty_resv
      FROM  pm p, zone z, lzone lz, inv i, loc
     WHERE  z.zone_type            = 'PUT'
       AND  z.rule_id              IN (0, 1, 2) 
       AND  z.induction_loc        IS NULL
       AND  lz.zone_id             = z.zone_id
       AND  i.plogi_loc            = lz.logi_loc
       AND  i.logi_loc             != i.plogi_loc
       AND  i.status               = 'AVL'
       AND  i.inv_uom              IN (0, 2)
       AND  p.prod_id              = i.prod_id
       AND  p.cust_pref_vendor     = i.cust_pref_vendor
       AND  loc.logi_loc           = lz.logi_loc
       AND  loc.slot_type          NOT IN ('MXP')     -- 1/22/2015 Brian Bent  Added for MXP slot type changes.
       AND  ((p.mx_item_assign_flag = 'Y' OR p.mx_throttle_flag = 'Y') AND p.mx_eligible = 'Y')
     GROUP  BY i.prod_id, i.cust_pref_vendor) res,          --Reserve Inventory
   --
  (SELECT   r.prod_id,
            r.cust_pref_vendor,
            SUM(r.qty) qty_rpl
      FROM  pm p, zone z, replenlst r
     WHERE  z.zone_type          = 'PUT'
       AND  r.type               IN ('NXL', 'DXL', 'MXL')
       AND  z.rule_id            = 5
       AND  z.induction_loc      IS NOT NULL
       AND  r.dest_loc           = z.induction_loc
       AND  r.uom                IN (0, 2)        
       AND  p.prod_id            = r.prod_id
       AND  p.cust_pref_vendor   = r.cust_pref_vendor    
       AND  ((p.mx_item_assign_flag = 'Y' OR p.mx_throttle_flag = 'Y') AND p.mx_eligible = 'Y')        
     GROUP BY r.prod_id, r.cust_pref_vendor) rpl          --Existing Replenishment Quantity
   --
 WHERE ((p.mx_item_assign_flag  = 'Y' OR p.mx_throttle_flag = 'Y') AND p.mx_eligible = 'Y') 
   AND mx.prod_id           (+) = p.prod_id
   AND mx.cust_pref_vendor  (+) = p.cust_pref_vendor
   AND res.prod_id          (+) = p.prod_id
   AND res.cust_pref_vendor (+) = p.cust_pref_vendor
   AND rpl.prod_id          (+) = p.prod_id
   AND rpl.cust_pref_vendor (+) = p.cust_pref_vendor
   AND (NVL(mx.qty_avl, 0) > 0 OR NVL (res.qty_resv, 0) > 0) ; 


   
