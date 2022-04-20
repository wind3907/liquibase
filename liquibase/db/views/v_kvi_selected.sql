CREATE OR REPLACE VIEW swms.v_kvi_selected
AS
 	SELECT	f.batch_no, d.selector_id, COUNT(DISTINCT (d.float_no||d.stop_no)) v_kvi_stops,
                COUNT(DISTINCT (d.float_no||d.zone)) v_kvi_zones,
                COUNT(DISTINCT d.float_no) v_kvi_floats,
                COUNT(DISTINCT d.src_loc) v_kvi_locs,
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE(d.uom, 1, d.qty_alloc, 0) ) ) v_kvi_splits, 
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				2, d.qty_alloc / NVL (p.spc, 1),
				null, d.qty_alloc / NVL (p.spc, 1), 0) ) ) v_kvi_cases,
                SUM (DECODE (d.merge_alloc_flag,
			'M', DECODE (d.uom,
				2, ROUND (d.qty_alloc / NVL (p.spc, 1)),
				1, d.qty_alloc, 0), 'S', 0, 0) ) v_kvi_merges, 
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
                        ) v_kvi_data_capture,
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				1, ROUND (d.qty_alloc * (p.weight / NVL (p.spc, 1))),
				0)
		)) v_kvi_split_wt,
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				1, d.qty_alloc*p.split_cube, 0)
		) ) v_kvi_split_cube, 
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0,
			DECODE (d.uom,
				2, d.qty_alloc * p.weight,
				NULL, d.qty_alloc*p.weight, 0)
		) ) v_kvi_case_wt, 
                SUM (DECODE (d.merge_alloc_flag,
			'M', 0,
			'S', 0, 
			DECODE (d.uom,
				2, ROUND ( (d.qty_alloc / NVL (p.spc, 1)) * p.case_cube),
				NULL, ROUND ( (d.qty_alloc/nvl (p.spc, 1))*p.case_cube), 0)
		) ) v_case_cube, 
                COUNT (DISTINCT SUBSTR (d.src_loc, 1, 2) ) v_kvi_aisle,
                COUNT(DISTINCT d.prod_id||d.cust_pref_vendor) v_kvi_item,
                COUNT(DISTINCT f.route_no) v_kvi_route
            FROM  float_hist fh, pm p, float_detail d, floats f, sys_config sysp, haccp_codes ha
            WHERE p.prod_id = d.prod_id
            AND p.cust_pref_vendor = d.cust_pref_vendor
            AND d.float_no = f.float_no
            AND f.pallet_pull not in ('D','R')
	    AND sysp.config_flag_name = 'CLAM_BED_TRACKED'
	    AND p.category = ha.haccp_code (+)
            AND ha.haccp_type(+) = 'C'
	    AND	d.sos_status != 'N'
	    AND	fh.batch_no = TO_CHAR (f.batch_no)
	    AND	fh.fh_order_seq = d.order_seq
	  GROUP	BY f.batch_no, d.selector_id;
COMMENT ON TABLE swms.v_kvi_selected IS 'VIEW sccs_id=@(#) src/schema/views/v_kvi_selected.sql, swms, swms.9, 10.1.1 9/25/07 1.3'
/
