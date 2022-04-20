------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ml_rcv_dest_loc.sql, swms, swms.9, 11.2 4/9/10 1.1
--
-- View:
--    v_ml_rcv_dest_loc
--
-- Description:
--    This view selects the valid receiving destination locations for a
--    miniload item.
--
--   It was created to use in form rp1sc (SN/Purchase Order Detail) for a
--   miniload item's destination location LOV and validation when the
--   destination location "*" when the PO/SN is opened.  It selects the
--   current inventory in the slot which is displayed to the user in
--   the form LOV.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/09/10 prpbcb   DN 12571
--                      Project: CRQ15757-Miniload In Reserve Fixes
--                      Created.
--
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_ml_rcv_dest_loc
AS
SELECT -1                   order_by,
       pm.prod_id           prod_id,
       pm.cust_pref_vendor  cust_pref_vendor,
       z.induction_loc      logi_loc,
       loc.slot_type        slot_type,
       loc.pallet_type      pallet_type,
       loc.cube             cube,
       to_number(null)      qoh_cases,
       to_number(null)      qoh_splits,
       to_number(null)      qty_planned_cases,
       to_number(null)      qty_planned_splits
  FROM pm, zone z, loc
 WHERE z.rule_id           = 3
   AND pm.zone_id          = z.zone_id
   AND loc.logi_loc        = z.induction_loc
 UNION
SELECT nz.sort               order_by,
       pm.prod_id            prod_id,
       pm.cust_pref_vendor   cust_pref_vendor,
       lnz.logi_loc          logi_loc,
       lnz.slot_type         slot_type,
       lnz.pallet_type       pallet_type,
       lnz.cube              cube,
       NVL(SUM(DECODE(inv.inv_uom, 1, 0,
                      TRUNC(inv.qoh / inv_pm.spc))), 0)  qoh_cases,
       NVL(SUM(DECODE(inv.inv_uom, 1, inv.qoh,
                      MOD(inv.qoh, inv_pm.spc))), 0)     qoh_splits,
       NVL(SUM(DECODE(inv.inv_uom, 1, 0,
                   TRUNC(inv.qty_planned / inv_pm.spc))), 0) qty_planned_cases,
       NVL(SUM(DECODE(inv.inv_uom, 1, inv.qty_planned,
                      MOD(inv.qty_planned, inv_pm.spc))), 0) qty_planned_splits
  FROM pm,
       loc lnz,
       zone z,
       lzone lznz,
       next_zones nz,
       pm inv_pm,     -- To get the existing inventory in the slot
       inv            -- To get the existing inventory in the slot
 WHERE z.rule_id                   = 3
   AND pm.zone_id                  = z.zone_id
   AND nz.zone_id                  = pm.zone_id
   AND lznz.zone_id                = nz.next_zone_id 
   AND lnz.logi_loc                = lznz.logi_loc
   AND lnz.perm                    = 'N'
   AND lnz.status                  = 'AVL'
   AND inv.plogi_loc (+)           = lnz.logi_loc
   AND inv_pm.prod_id (+)          = inv.prod_id
   AND inv_pm.cust_pref_vendor (+) = inv.cust_pref_vendor
 GROUP BY nz.sort,
          pm.prod_id,
          pm.cust_pref_vendor,
          lnz.logi_loc,
          lnz.slot_type, 
          lnz.pallet_type,
          lnz.cube
/


--
-- Create public synonym.
--
CREATE OR REPLACE PUBLIC SYNONYM v_ml_rcv_dest_loc FOR swms.v_ml_rcv_dest_loc;



