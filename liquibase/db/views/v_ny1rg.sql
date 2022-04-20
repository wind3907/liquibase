------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_ny1rg
--
-- Description:
--    This view is used in the cycle count reports.
--
-- Used by:
--    Report NY1RG (Cycle Count Variance Report by Area, Aisle)
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/01/05 prplhj   D#12028 Change to use the CC_EDIT table instead of
--                      TRANS table.
--    11/06/06 prppxx   D#12182 Rename qty_expected, qty, src_loc, pallet_id
--                      to old_qty, new_qty, phys_loc, logi_loc in order to
--                      sync with STMT from form's last query.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS.Expanded the length 
--                      of prod size to accomodate for prod size 
--                      unit.Changed queries to fetch 
--                      prod_size_unit along with prod_size
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_ny1rg AS
  SELECT t.phys_loc phys_loc, 
         t.prod_id prod_id, 
         t.cust_pref_vendor cust_pref_vendor, 
         t.old_qty old_qty, 
         t.new_qty new_qty, 
         t.add_date add_date, 
         t.adj_flag adj_flag, 
         t.reason_code reason_code, 
         t.group_no group_no, 
         t.logi_loc logi_loc, 
         t.cc_gen_date mfg_date, 
         t.add_user add_user,
         t.upd_user upd_user,
         p.pack pack, 
         p.prod_size prod_size, 
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		 p.prod_size_unit prod_size_unit,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
         p.brand brand, 
         p.descrip descrip, 
         p.mfg_sku mfg_sku, 
         p.spc spc,
         p.split_trk split_trk,
         DECODE(z.rule_id, 3, 'Y', 'N') miniload,
         l.uom loc_uom 
  FROM pm p, zone z, lzone lz, loc l, cc_edit t 
  WHERE p.prod_id = t.prod_id 
  AND   p.cust_pref_vendor = t.cust_pref_vendor 
  AND   z.zone_id = lz.zone_id
  AND   z.zone_type = 'PUT'
  AND   lz.logi_loc = t.phys_loc
  AND   lz.logi_loc = l.logi_loc
  AND   NVL(t.adj_flag, 'N') = 'Y' 
  AND   (t.new_qty - t.old_qty) != 0
/

