------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/views/v_ml_replen_info, swms, swms.9, 11.1 04/15/10 1.5
--
-- View:
--	v_ml_replen_info
--
-- Description:
--	This is a view for mini replenishment screens

-- Modification History:
--    Date       Designer     Defect#   Comments
--    04/15/10   tsow0456     12554     Modified this view to append  
--                                      prod_size_unit along with prod_size
--    -------- -------- ---------------------------------------------------

CREATE OR REPLACE VIEW swms.v_ml_replen_info
	(task_id, type, prod_id, cust_pref_vendor, descrip, mfg_sku, pack, prod_size, spc, area,
	 stackable, mfg_date, exp_date, uom, num_pieces, src_loc, aisle, pallet_id, dest_loc,
	 r_cube, s_pikpath, priority, orig_pallet_id, user_id,
	 unpack_code, r_status, pick_status, putback_task_id, putback_qty, status)
AS
SELECT	r.task_id, r.type, r.prod_id, r.cust_pref_vendor, p.descrip, p.mfg_sku, p.pack,
	trim(p.prod_size)|| trim(p.prod_size_unit), p.spc, p.area, p.stackable, r.mfg_date, 
	r.exp_date, r.uom, r.qty,
	r.src_loc, ai.name, r.pallet_id, r.dest_loc,
	r.qty * DECODE (r.uom, 1, p.split_cube, p.case_cube),
	r.s_pikpath, r.priority,
	DECODE (l.slot_type, 'MLS', NULL, r.orig_pallet_id), r.user_id, pc.unpack_code, r.status,
	DECODE (r.status, 'PIK', 'Y', 'N') pick_status, pb.task_id,
	NVL (pb.qty, 0), r.status
  FROM	aisle_info ai, loc l, priority_code pc,
	pm p, replenlst r, replenlst pb
 WHERE	r.type = 'MNL'
   AND	(('NEW' IN (r.status, pb.status)) OR
	('PIK' IN (r.status, pb.status) AND r.user_id = REPLACE (USER, 'OPS$')))
   AND	r.type IN ('MNL', 'RLP')
   AND	NVL (pb.type, 'RLP') = 'RLP'
   AND	pb.pallet_id (+) = r.orig_pallet_id
   AND	p.prod_id = r.prod_id
   AND	p.cust_pref_vendor = r.cust_pref_vendor
   AND	pc.priority_value = r.priority
   AND	l.pik_path = r.s_pikpath
   AND	ai.pick_aisle (+) = l.pik_aisle
UNION
SELECT	r.task_id, r.type, r.prod_id, r.cust_pref_vendor, p.descrip, p.mfg_sku, p.pack,
	trim(p.prod_size)|| trim(p.prod_size_unit), p.spc, p.area, p.stackable, r.mfg_date, 
	r.exp_date, r.uom, 0,
	r.src_loc, ai.name, r.pallet_id, r.dest_loc, 0,
	r.s_pikpath, r.priority,
	DECODE (l.slot_type, 'MLS', NULL, r.orig_pallet_id), r.user_id, 'N', r.status,
	'Y', r.task_id, NVL (r.qty, 0), r.status
  FROM	aisle_info ai, loc l, priority_code pc,
	pm p, replenlst r
 WHERE	r.type = 'RLP'
   AND	r.status = 'PIK'
   AND	r.user_id = REPLACE (USER, 'OPS$')
   AND	p.prod_id = r.prod_id
   AND	p.cust_pref_vendor = r.cust_pref_vendor
   AND	pc.priority_value = r.priority
   AND	l.pik_path = r.s_pikpath
   AND	ai.pick_aisle (+) = l.pik_aisle
   AND	NOT EXISTS (
		SELECT	0
		  FROM	replenlst r1
		 WHERE	r1.orig_pallet_id = r.pallet_id
		   AND	r1.type = 'MNL'
		   AND	r1.status = 'PIK'
		   AND	r1.user_id = r.user_id)
/
COMMENT ON TABLE swms.v_ml_replen_info IS 'sccs_id=@(#) src/schema/views/v_ml_replen_info.sql, swms, swms.9, 11.2 4/9/10 1.6'
/

