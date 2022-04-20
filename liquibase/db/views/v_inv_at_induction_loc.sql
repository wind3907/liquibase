------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_inv_at_induction_loc.sql, swms, swms.9, 10.1.1 3/23/07 1.1
--
-- View:
--    v_inv_at_induction_loc
--
-- Description:
--     View of the inventory at the miniloader induction location.
--     Inventory records with qty planned and qty allocated are not
--     selected because this indicates there is a pending task
--     for the inventory.
--
--     Used in form mm3sa.fmb when creating an expected receipt(ER).
--     The induct_qty and induct_uom are used in populating the qty and
--     uom fields in form mm3sa when selecting the item to induct from the
--     LOV when creating an ER.  If for some reason the inv uom is not 1
--     and the qoh divided by the spc is not a whole number then 0 is used
--     as the induct qty.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/20/06 prpbcb   DN: 12214
--                      Ticket: 326211
--                      Project: 326211-Miniload Induction Qty Incorrect
--
--                      Created.
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_inv_at_induction_loc
AS
SELECT i.prod_id,
       i.cust_pref_vendor,
       i.logi_loc,
       i.plogi_loc,
       i.qoh,
       i.exp_date,
       i.inv_uom,
       i.status,
       i.add_date,
       i.add_user,
       pm.split_trk,
       pm.auto_ship_flag,
       -- Calculate what needs to be inducted based on the INV UOM.
       -- If cases and not a whole number of cases then use 0--ideally
       -- this should never happen.
       DECODE(i.inv_uom,
              1, i.qoh,
              DECODE(MOD(i.qoh, pm.spc),
                     0, i.qoh / pm.spc,
                     0)) induct_qty,
       DECODE(i.inv_uom,
              1, 1,          -- splits
              2) induct_uom  -- anything else cases.
                             -- Note: If the item is ship split only
                             -- the then splits will always be
                             -- inducted.  This happens when the
                             -- ER message is procesessed
  FROM zone z,
       pm,
       inv i
 WHERE z.zone_id           IN (pm.zone_id, pm.split_zone_id)
   AND z.rule_id           = 3
   AND pm.prod_id          = i.prod_id
   AND pm.cust_pref_vendor = i.cust_pref_vendor
   AND i.plogi_loc         = z.induction_loc
   AND i.qty_planned       = 0
   AND i.qty_alloc         = 0
/


