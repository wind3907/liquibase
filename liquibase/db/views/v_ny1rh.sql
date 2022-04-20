------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_ny1rh
--
-- Description:
--    This view is used in the cycle count reports.
--
-- Used by:
--    Report NY1RH (Cycle Count Recount Variance Report)
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
CREATE OR REPLACE VIEW swms.v_ny1rh AS
  SELECT t.phys_loc         phys_loc, 
         t.logi_loc         logi_loc, 
         t.old_qty	    old_qty, 
         t.new_qty          new_qty, 
         t.add_date	    add_date, 
         t.prod_id          prod_id, 
         t.cust_pref_vendor cust_pref_vendor, 
         t.reason_code      reason_code, 
         t.adj_flag         adj_flag, 
         t.group_no	    group_no, 
         t.add_user         add_user,
         t.upd_user         upd_user,
         p.descrip          descrip, 
         p.pack             pack, 
         p.prod_size        prod_size,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		p.prod_size_unit    prod_size_unit,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */		 
         p.spc              spc,
         p.split_trk	    split_trk,
         DECODE(z.rule_id, 3, 'Y', 'N') miniload,
         l.uom		    loc_uom
  FROM pm p, zone z, lzone lz, loc l, cc_edit t
  WHERE z.zone_id = lz.zone_id
  AND   z.zone_type = 'PUT'
  AND   lz.logi_loc = t.phys_loc
  AND   lz.logi_loc = l.logi_loc
  AND   t.prod_id = p.prod_id 
  AND   t.cust_pref_vendor = p.cust_pref_vendor 
  AND   t.adj_flag in ('Y','R')
/

