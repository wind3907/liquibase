------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_mi1ra_2
--
-- Description:
--    This view is used in the mi1ra reports.
--
-- Used by:
--    Report mi1ra.pc, mi1rd.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    12/31/04 prplhj   D#11850 Add pm.rdc_vendor_id logic to the vendor_id
--			field for RDC item attribute changes.
--    08/17/07 prpswp   D#12272 Added pm.miniload_storage_ind to view.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS Expanded the length
--                      of prod size to accomodate for prod size unit.                 
--                      Changed queries to fetch prod_size_unit             
--                      along with prod_size            
------------------------------------------------------------------------------

CREATE OR REPLACE VIEW swms.v_mi1ra_2 AS
  SELECT p.prod_id prod_id, p.cust_pref_vendor cust_pref_vendor,
         p.container container, p.pack pack, p.prod_size prod_size,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		 /*  Selected prod size unit */ 
		 p.prod_size_unit prod_size_unit,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
         p.brand brand, p.descrip descrip, p.mfg_sku mfg_sku, p.avg_wt avg_wt,
         DECODE(p.rdc_vendor_id, NULL, p.vendor_id, p.rdc_vendor_id) vendor_id,
         p.rdc_vendor_id,
         p.area area, p.spc spc, l.logi_loc logi_loc,
         p.ti ti, p.hi hi, a1.qty awm, a2.qty pick_freq, a.sort,
         v.cases_on_order cases_on_order, v.splits_on_order splits_on_order,
         p.pallet_type pallet_type, p.miniload_storage_ind miniload_storage_ind
  FROM swms_sub_areas sa, swms_areas a, loc l, pm p, v_mi1ra_1 v,
       awm a1, awm a2
  WHERE p.prod_id = l.prod_id(+)
  AND   p.prod_id = v.prod_id(+)
  AND   l.perm(+) = 'Y'
  AND   a1.awm_type(+) = 'W' and a1.freq(+) = 'M' and a1.prod_id(+) = p.prod_id
  AND   a1.uom(+) = 2
  AND   a2.awm_type(+) = 'F' and a2.freq(+) = 'M' and a2.prod_id(+) = p.prod_id
  AND   a2.uom(+) = 2
  AND   sa.area_code = a.area_code(+)
  AND   sa.sub_area_code(+) = substr(logi_loc,1,1)
  AND   a1.cust_pref_vendor(+) = p.cust_pref_vendor
  AND   a2.cust_pref_vendor(+) = p.cust_pref_vendor
  AND   l.cust_pref_vendor(+) = p.cust_pref_vendor
  AND   v.cust_pref_vendor(+) = p.cust_pref_vendor
/

