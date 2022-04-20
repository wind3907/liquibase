------------------------------------------------------------------------------
--
-- View swms.v_ML_reserve_info: Used by miniload case replenishment routine
--	to find items that have case selection from the miniload but
--	reserves in the main warehouse.
-- 
-- There are 3 sub-queries in the view.
-- First on aliased as "ml", finds all miniload items with uom = 2 that currently
-- has quantity in the miniload. It eliminates quantities in the main warehouse.
-- Second sub-query (res) returns total QOH outside of the miniload currently
-- available for replenishment.
-- The third subquery (rpl) returns the current replenishments into miniload.
-- 
-- Modification History:
--    Date     Designer Comments
--    -------- -------- -----------------------------------------------------
--  23-Apr-14	sray0453 Charm#6000001046-- TFS-WIB#396
--			  Changed AllocMiniloadItems procedure to allocate the 
--			  items in itduction location for orders. Earlier this was not
--			  considered for allocation which resulted in missing Shipment.
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_ML_reserve_info (
	area, prod_id, cust_pref_vendor, spc, split_trk, ship_split_only,
	case_per_carrier, max_tray_per_item, zone_id, induction_loc,
	max_ml_cases, curr_ml_cases, curr_ml_trays, curr_resv_cases,
	curr_repl_cases)
AS
SELECT	p.area, p.prod_id, p.cust_pref_vendor, spc, split_trk, auto_ship_flag,
	case_qty_per_carrier,
	NVL (max_miniload_case_carriers, 99), p.zone_id, z.induction_loc,
	p.case_qty_per_carrier * NVL (p.max_miniload_case_carriers, 99) max_ml_cases,
	NVL (ml.qty_avl, 0) / p.spc curr_ml_cases, num_trays,
	NVL (res.qty_resv, 0) / p.spc curr_resv_cases,
	NVL (rpl.qty_rpl, 0) repl_cases
  FROM	pm p, 
	zone z,
	(SELECT	i.prod_id,
		i.cust_pref_vendor,
		SUM (DECODE (z.induction_loc, i.plogi_loc, 0 , 1)) num_trays,
		SUM (DECODE (z.induction_loc, i.plogi_loc,
			DECODE (NVL (i.qty_planned, 0), 0, 0, 1), 0)) num_replen,
		SUM (i.qoh - NVL (i.qty_alloc, 0)) qty_avl
	  FROM	pm p, zone z, lzone lz, inv i
	 WHERE	z.zone_type = 'PUT'
	   AND	z.rule_id = 3
	   AND	z.induction_loc IS NOT NULL
	   AND	lz.zone_id = z.zone_id
	   AND	i.plogi_loc = lz.logi_loc
	   AND	i.status = 'AVL'
	   AND	i.inv_uom IN (0,2)
	   AND	p.prod_id = i.prod_id
	   AND	p.cust_pref_vendor = i.cust_pref_vendor
	   AND	((p.miniload_storage_ind = 'B' AND P.max_miniload_case_carriers IS NULL) OR
	   	P.max_miniload_case_carriers > 0)
	   -- AND	NVL (P.max_miniload_case_carriers, 0) > 0
	 GROUP	BY i.prod_id, i.cust_pref_vendor) ml,
	(SELECT	i.prod_id, i.cust_pref_vendor, SUM (i.qoh - NVL (i.qty_alloc, 0)) qty_resv
	  FROM	pm p, zone z, lzone lz, inv i
	 WHERE	z.zone_type = 'PUT'
	   AND	z.rule_id != 3
	   AND	z.induction_loc IS NULL
	   AND	lz.zone_id = z.zone_id
	   AND	i.plogi_loc = lz.logi_loc
	   AND	i.status = 'AVL'
	   AND	i.inv_uom IN (0, 2)
	   AND	p.prod_id = i.prod_id
	   AND	p.cust_pref_vendor = i.cust_pref_vendor
	   AND	((p.miniload_storage_ind = 'B' AND P.max_miniload_case_carriers IS NULL) OR
	   	P.max_miniload_case_carriers > 0)
	 GROUP	BY i.prod_id, i.cust_pref_vendor) res,
	(SELECT	r.prod_id, r.cust_pref_vendor, SUM (r.qty) qty_rpl
	   FROM	pm p, zone z, replenlst r
	 WHERE	z.zone_type = 'PUT'
	   AND	r.type = 'MNL'
	   AND	z.rule_id = 3
	   AND	z.induction_loc IS NOT NULL
	   AND	r.dest_loc = z.induction_loc
	   AND	r.uom IN (0, 2)
	   AND	r.priority in (18, 48)
	   AND	p.prod_id = r.prod_id
	   AND	p.cust_pref_vendor = r.cust_pref_vendor
	   AND	((p.miniload_storage_ind = 'B' AND P.max_miniload_case_carriers IS NULL) OR
	   	P.max_miniload_case_carriers > 0)
	   -- AND	NVL (P.max_miniload_case_carriers, 0) > 0
	 GROUP	BY r.prod_id, r.cust_pref_vendor) rpl
 WHERE	p.miniload_storage_ind = 'B'
   AND	z.zone_id = p.zone_id
   AND	z.zone_type = 'PUT'
   AND	z.rule_id = 3
   AND	p.prod_id = ml.prod_id (+)
   AND	p.cust_pref_vendor = ml.cust_pref_vendor (+)
   AND	p.prod_id = res.prod_id (+)
   AND	p.cust_pref_vendor = res.cust_pref_vendor (+)
   AND	p.prod_id = rpl.prod_id (+)
   AND	p.cust_pref_vendor = rpl.cust_pref_vendor (+)
   AND	( NVL (ml.qty_avl, 0) > 0 OR NVL (res.qty_resv, 0) > 0)
   AND	((p.miniload_storage_ind = 'B' AND P.max_miniload_case_carriers IS NULL) OR
	(p.max_miniload_case_carriers IS NOT NULL))
/
COMMENT ON TABLE swms.v_ML_reserve_info IS 'sccs_id=@(#) src/schema/views/v_ml_reserve_info.sql, swms, swms.9, 11.2 2/22/10 1.3'
/
