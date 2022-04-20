--    	Modification History
--	--------------------------------
--     04/01/10   sth0458     DN12554 - 212 Enh - SCE057 - 
--                            Add UOM field to SWMS.Expanded the length
--                            of prod size to accomodate for prod size
--                            unit.Changed queries to fetch
--                            prod_size_unit along with prod_size


CREATE OR REPLACE VIEW swms.v_ob1rc
	(comp_code, truck_no, batch_no, src_loc, stop_no, float_no, cust_id, float_seq, batch_seq, zone,
	 pack_size, brand, descrip, mfg_sku, prod_id, cust_pref_vendor, cs_sp_qty, cs_sp, seq, status,
	 route_no, sch_time, method_id, route_batch_no, fd_seq_no)
AS
	SELECT	f.comp_code,
		r.truck_no,
		NVL (f.batch_no, 0),
		fd.src_loc,
		fd.stop_no,
		f.float_no,
		om.cust_id,
		f.float_seq,
		NVL (f.batch_seq, 0),
		fd.zone,
		DECODE (fd.uom, 1, 'ONLY', LPAD (NVL (RTRIM (NVL (pm.pack, ' ')), ' '), 4))
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
		/*  Concatenated prod_size_unit */ 
			|| '/' || trim(pm.prod_size)||trim(pm.prod_size_unit),
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
		pm.brand,
		pm.descrip,
		LTRIM(RTRIM (pm.mfg_sku)),
		fd.prod_id,
		fd.cust_pref_vendor,
		DECODE (fd.uom, 1, NVL (fd.qty_alloc, 0), NVL (fd.qty_alloc, 0) / NVL (pm.spc, 1)),
		DECODE (fd.uom, 1, 'SP', 'CS'),
		od.seq,
		r.status,
		r.route_no,
		r.sch_time,
		r.method_id,
		r.route_batch_no,
		fd.seq_no
	  FROM	ordd od, ordm om, route r, pm, float_detail fd, floats f
	 WHERE	f.merge_loc like '???%'
	   AND	fd.float_no = f.float_no
	   AND	fd.qty_alloc > 0
	   AND	pm.prod_id = fd.prod_id
	   AND	pm.cust_pref_vendor = fd.cust_pref_vendor
	   AND	pm.catch_wt_trk = 'Y'
	   AND	r.route_no = f.route_no
	   AND	om.order_id = fd.order_id
	   AND	od.order_id = fd.order_id
	   AND	od.order_line_id = fd.order_line_id
/

