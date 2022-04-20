CREATE OR REPLACE VIEW swms.v_ML_spl_rpl_info (
	route_no, prod_id, cpv, uom, d_order, q_avail, q_0_avail)
AS
SELECT	f.route_no, d.prod_id, d.cust_pref_vendor, d.uom,
	SUM (d.qty_order) d_order,
	NVL (UOM_Inv.qty_avail, 0) q_avail, SUM (0) q_0_avail
  FROM	pm p, float_detail d, floats f,
	(
	SELECT	i.prod_id, i.cust_pref_vendor,
		i.inv_uom, SUM (i.qoh - i.qty_alloc) qty_avail
	  FROM	pm p1, zone z, lzone lz, inv i
	 WHERE	lz.logi_loc = i.plogi_loc
	   AND	p1.prod_id = i.prod_id
	   AND	p1.cust_pref_vendor = i.cust_pref_vendor
	   AND	lz.zone_id = NVL (p1.split_zone_id, p1.zone_id)
	   AND	i.status = 'AVL'
	   AND	z.zone_id = lz.zone_id
	   AND	z.induction_loc IS NOT NULL
	   AND	((z.induction_loc = i.plogi_loc) OR
		 (z.induction_loc != i.plogi_loc AND i.inv_uom = 1))
	 GROUP	BY i.prod_id, i.cust_pref_vendor, i.inv_uom
	) UOM_Inv
 WHERE	f.float_no = d.float_no
   AND	d.uom = 1
   AND	f.pallet_pull = 'N'
   AND	NVL (p.miniload_storage_ind, 'N') != 'N'
   AND	d.status = 'NEW'
   AND	d.merge_alloc_flag in ('X','Y')
   AND	d.prod_id = p.prod_id
   AND	d.cust_pref_vendor = p.cust_pref_vendor
   AND	p.status = 'AVL'
   AND	d.prod_id = UOM_Inv.prod_id (+)
   AND	d.cust_pref_vendor = UOM_Inv.cust_pref_vendor (+)
   AND	d.qty_alloc != d.qty_order
 GROUP	BY f.route_no, d.prod_id, d.cust_pref_vendor, d.uom,
	NVL (UOM_Inv.qty_avail, 0)
HAVING	SUM (d.qty_order) > NVL (UOM_Inv.qty_avail, 0)
/
COMMENT ON TABLE swms.v_ML_spl_rpl_info IS 'sccs_id=@(#) src/schema/views/v_ml_spl_rpl_info.sql, swms, swms.9, 11.2 2/10/10 1.2'
/
