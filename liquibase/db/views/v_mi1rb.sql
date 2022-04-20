------------------------------------------------------------------------------
-- sccs_id=%Z% %W% %G% %I%
--
-- View:
--    v_mi1rb
--
-- Description:
--    This view is used in the mi1rb reports.
--
-- Used by:
--    Report mi1rb.pc
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/01/04 prplhj   D#11588 Replaced the original 5 views (v_mira_1,
--			v_mira_2, v_asoh, v_lst_rcvd_date and v_mi1rb_2) with
--			this view. No longer query the AWM, SWMS_SUB_AREAS,
--			and SWMS_AREAS tables. Don't delete the views.
--    12/31/04 prplhj   D#11850 Added RDC item attribute into the view.
--    04/01/10 sth0458  DN12554 - 212 Enh - SCE057 - 
--                      Add UOM field to SWMS. Expanded the length of 
--                      prod size to accomodate for prod size
--                      unit.Changed queries to fetch
--                      prod_size_unit along with prod_size
------------------------------------------------------------------------------

-- Rpt_type: O is for On Order, N is for Not On Order.
-- Only look for any inventory that have all quantities as 0s.
-- Last_rec_date in PM as 1/1/1980 is treated that the item is never received
--   before.

CREATE OR REPLACE VIEW swms.v_mi1rb AS
  SELECT 'O' rpt_type,
         i.prod_id prod_id,
         i.cust_pref_vendor cust_pref_vendor,
         p.container container,
         p.pack pack,
         p.prod_size prod_size,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		 /* declare prod size unit*/
		 p.prod_size_unit prod_size_unit,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
         p.brand brand,
         p.descrip descrip,
         p.mfg_sku mfg_sku,
         SUM(DECODE(NVL(d.uom, 0), 0, NVL(d.qty/p.spc, 0), 0)) cases_on_order,
         SUM(DECODE(d.uom, 1, NVL(d.qty, 0), 0)) splits_on_order,
         p.last_rec_date last_rec_date,
         DECODE(p.rdc_vendor_id, NULL, p.vendor_id, p.rdc_vendor_id) vendor_id,
         i.plogi_loc logi_loc,
         p.area area,
         p.spc spc,
	 p.rdc_vendor_id
  FROM inv i, pm p, erm m, erd d, loc l
  WHERE i.prod_id = p.prod_id
  AND   i.cust_pref_vendor = p.cust_pref_vendor
  AND   m.erm_id = d.erm_id
  AND   i.prod_id = d.prod_id
  AND   i.cust_pref_vendor = d.cust_pref_vendor
  AND   m.status IN ('NEW', 'SCH')
  AND   i.status <> 'HLD'
  AND   i.plogi_loc = l.logi_loc
  AND   l.perm = 'Y'
  AND   EXISTS (SELECT i2.prod_id
                FROM inv i2
                WHERE i2.prod_id = i.prod_id
                AND   i2.cust_pref_vendor = i.cust_pref_vendor
                AND   i2.status <> 'HLD'
                GROUP BY i2.prod_id
                HAVING SUM(i.qoh) = 0 AND
                       SUM(i.qty_planned) = 0 AND
                       SUM(i.qty_alloc) = 0)
  GROUP BY 'O',
           i.prod_id,
           i.cust_pref_vendor,
           p.container,
           p.pack,
           p.prod_size,
		   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		   p.prod_size_unit,
		   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
           p.brand,
           p.descrip,
           p.mfg_sku,
           p.last_rec_date,
           p.vendor_id,
           i.plogi_loc,
           p.area,
           p.spc,
	   p.rdc_vendor_id
  UNION
  SELECT 'N' rpt_type,
         i.prod_id prod_id,
         i.cust_pref_vendor cust_pref_vendor,
         p.container container,
         p.pack pack,
         p.prod_size prod_size,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		p.prod_size_unit,
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
         p.brand brand,
         p.descrip descrip,
         p.mfg_sku mfg_sku,
         0 cases_on_order,
         0 splits_on_order,
         p.last_rec_date last_rec_date,
         DECODE(p.rdc_vendor_id, NULL, p.vendor_id, p.rdc_vendor_id) vendor_id,
         i.plogi_loc logi_loc,
         p.area area,
         p.spc spc,
	 p.rdc_vendor_id
  FROM inv i, pm p, loc l
  WHERE i.prod_id = p.prod_id
  AND   i.cust_pref_vendor = p.cust_pref_vendor
  AND   i.status <> 'HLD'
  AND   i.plogi_loc = l.logi_loc
  AND   l.perm = 'Y'
  AND   NOT EXISTS (SELECT 1
                    FROM erm m, erd d
                    WHERE m.erm_id = d.erm_id
                    AND   d.prod_id = i.prod_id
                    AND   d.cust_pref_vendor = i.cust_pref_vendor
                    AND   m.status IN ('NEW', 'SCH'))
  AND   EXISTS (SELECT i2.prod_id
                FROM inv i2
                WHERE i2.prod_id = i.prod_id
                AND   i2.cust_pref_vendor = i.cust_pref_vendor
                AND   i2.status <> 'HLD'
                GROUP BY i2.prod_id
                HAVING SUM(i2.qoh) = 0 AND
                       SUM(i2.qty_planned) = 0 AND
                       SUM(i2.qty_alloc) = 0)
  GROUP BY 'N',
           i.prod_id,
           i.cust_pref_vendor,
           p.container,
           p.pack,
           p.prod_size,
		   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		   p.prod_size_unit,
		   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End */
           p.brand,
           p.descrip,
           p.mfg_sku,
           p.last_rec_date,
           p.vendor_id,
           i.plogi_loc,
           p.area,
           p.spc,
	   p.rdc_vendor_id
/

