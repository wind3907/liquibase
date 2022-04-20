CREATE OR REPLACE VIEW swms.v_kvi_new
	(batch_no, v_kvi_stops, v_kvi_zones, v_kvi_floats, v_kvi_locs, v_kvi_splits,
	 v_kvi_cases, v_kvi_merges, v_kvi_data_capture, v_kvi_split_wt,
	 v_kvi_split_cube, v_kvi_case_wt,  v_kvi_case_cube, v_kvi_aisle, v_kvi_item, v_kvi_route,
	 v_kvi_float_dtls, v_kvi_fd_qty)
AS
 	SELECT	f.batch_no, COUNT(DISTINCT (d.float_no||d.stop_no)),
                COUNT(DISTINCT (d.float_no||d.zone)),
                COUNT(DISTINCT d.float_no),
                COUNT(DISTINCT d.src_loc),
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE(d.uom, 1, d.qty_alloc, 0) ) ),
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				2, d.qty_alloc / NVL (p.spc, 1),
				null, d.qty_alloc / NVL (p.spc, 1), 0) ) ),
                SUM (DECODE (d.merge_alloc_flag,
			'M', DECODE (d.uom,
				2, ROUND (d.qty_alloc / NVL (p.spc, 1)),
				1, d.qty_alloc, 0), 'S', 0, 0) ),
                SUM (DECODE (p.catch_wt_trk,
			'Y', DECODE (d.uom,
				1, d.qty_alloc,
				d.qty_alloc / nvl (spc, 1)),
			0) ) +
		SUM (DECODE (NVL (sysp.config_flag_val, 'N'), 'Y',
                                DECODE (NVL (ha.clambed_trk, 'N'),
                                        'Y', DECODE (d.uom, 1, d.qty_alloc, d.qty_alloc / nvl (spc, 1)),
                                        0),
                                 0)
                        ),
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				1, ROUND (d.qty_alloc * (p.weight / NVL (p.spc, 1))),
				0)
		)),
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				1, d.qty_alloc*p.split_cube, 0)
		) ),
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				2, d.qty_alloc * p.weight,
				NULL, d.qty_alloc*p.weight, 0)
		) ) ,
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0, 
			DECODE (d.uom,
				2, ROUND ( (d.qty_alloc / NVL (p.spc, 1)) * p.case_cube),
				NULL, ROUND ( (d.qty_alloc/nvl (p.spc, 1))*p.case_cube), 0)
		) ),
                COUNT (DISTINCT SUBSTR (d.src_loc, 1, 2) ),
                COUNT(DISTINCT d.prod_id||d.cust_pref_vendor),
                COUNT(DISTINCT f.route_no),
		COUNT (DISTINCT d.float_no || d.order_seq),
		COUNT (d.float_no || d.seq_no)
            FROM  pm p, float_detail d, floats f, sys_config sysp, haccp_codes ha
            WHERE p.prod_id = d.prod_id
            AND p.cust_pref_vendor = d.cust_pref_vendor
            AND d.float_no = f.float_no
            AND f.pallet_pull not in ('D','R')
	    AND sysp.config_flag_name = 'CLAM_BED_TRACKED'
	    AND p.category = ha.haccp_code (+)
            AND ha.haccp_type(+) = 'C'
	    AND	d.sos_status = 'N'
	  GROUP	BY f.batch_no;
COMMENT ON TABLE swms.v_kvi_new IS 'VIEW sccs_id=@(#) src/schema/views/v_kvi_new.sql, swms, swms.9, 10.1.1 9/25/07 1.2'
/
