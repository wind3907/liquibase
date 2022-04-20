------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_mn1rd
--
-- Description:
--    This view is used in the mn1rd reports.
--
-- Used by:
--    Report mn1rd.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/31/04 prplhj   D#11xxx Added RDC item attribute into the view.
--    05/18/06 prppxx   D#12078 Remove conn swms/swms.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS.Expanded the length
--                      of prod size to accomodate for prod size 
--                      unit.Changed queries to fetch
--                      prod_size_unit along with prod_size
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_mn1rd AS
  SELECT p.buyer buyer,
	 i.plogi_loc plogi_loc,
	 i.logi_loc  logi_loc,
	 p.pack      pack,
	 p.prod_size prod_size,
	 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	 /* select prod size unit */
	 p.prod_size_unit prod_size_unit,
	 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
	 p.brand     brand,
	 p.mfg_sku   mfg_sku,
	 p.descrip   descrip,
	 DECODE(p.rdc_vendor_id, NULL, p.vendor_id, p.rdc_vendor_id) vendor_id,
	 i.prod_id   prod_id,
	 i.qoh       qoh,
	 p.spc       spc,
	 p.ti        ti,
	 p.pallet_type pallet_type,
	 p.hi        hi,
	 i.exp_date  exp_date,
	 i.mfg_date  mfg_date,
	 i.rec_date  rec_date,
	 p.mfr_shelf_life shelf_life,
	 p.mfg_date_trk mfg_date_trk,
	 p.exp_date_trk exp_date_trk,
	 i.inv_date  inv_date,
	 i.lst_cycle_date lst_cycle_date,
	 p.split_trk split_trk,
	 p.repack_trk repack_trk,
	 i.qty_planned qty_planned,
	 i.qty_alloc qty_alloc,
	 NVL(a1.qty,0) awm,
	 NVL(a2.qty,0) pick_freq,
	 p.rdc_vendor_id
  FROM sys_config s, inv i, pm p, awm a1, awm a2
  WHERE ((p.exp_date_trk = 'Y' AND
	 TRUNC(i.exp_date) <= TRUNC(sysdate) + to_number(s.config_flag_val)) OR
	          (p.mfg_date_trk = 'Y' AND
	 TRUNC(i.mfg_date+p.mfr_shelf_life) <= TRUNC(sysdate)
		+ to_number(s.config_flag_val)))
  AND    p.prod_id = i.prod_id
  AND    s.config_flag_name = 'EXPIR_WARN_DAYS'
  AND    a1.awm_type(+) = 'W'
  AND    i.qoh != 0
  AND    a1.uom(+) = 2
  AND    a1.freq(+) = 'M'
  AND    a1.prod_id(+) = i.prod_id
  AND    a2.awm_type(+) = 'F'
  AND    a2.uom(+) = 2
  AND    a2.freq(+) = 'M'
  AND    a2.prod_id(+) = i.prod_id
  AND    p.cust_pref_vendor = i.cust_pref_vendor
  AND    a1.cust_pref_vendor(+) = i.cust_pref_vendor
  AND    a2.cust_pref_vendor(+) = i.cust_pref_vendor
/

CREATE OR REPLACE PUBLIC SYNONYM v_mn1rd FOR swms.v_mn1rd;

