CREATE OR REPLACE VIEW swms.v_calc_time_total (
	l_jbcd_job_code, l_status,
	batch_no, l_doc_time,
	l_no_order_time,
	l_user_id, l_supervsr_id,
	l_actl_time_spent,
	print_goal_flag,
	engr_std_flag,
	l_cart_time,
	l_cube_time, l_wt_time,
	l_no_piece_time, l_no_pallet_time,
	l_no_item_time, l_no_data_time,
	l_no_po_time, l_no_stop_time,
	l_no_zone_time, l_no_loc_time,
	l_no_case_time, l_no_split_time,
	l_no_merge_time, l_no_aisle_time,
	l_no_drop_time,
	l_no_cart_piece_time,
	l_no_pallet_piece_time, l_total_time)
AS
	SELECT	b.jbcd_job_code, b.status,
		DECODE (ref_no,
			'MULTI', DECODE(b.status,
					'M', NVL (parent_batch_no, batch_no),
					b.batch_no),
			batch_no),
		NVL (kvi_doc_time, 0),
		NVL (kvi_order_time, 0),
		user_id, user_supervsr_id,
		NVL (actl_time_spent, 0),
		print_goal_flag,
		engr_std_flag,
		ROUND (NVL (SUM (kvi_cube), 0) * NVL (tmu_cube, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_wt), 0) * NVL (tmu_wt, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_piece), 0) * NVL (tmu_no_piece, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_pallet), 0) * NVL (tmu_no_pallet, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_item), 0) * NVL (tmu_no_item, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_data_capture), 0) * NVL (tmu_no_data_capture, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_po), 0) * NVL (tmu_no_po, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_stop), 0) * NVL (tmu_no_stop, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_zone), 0) * NVL (tmu_no_zone, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_loc), 0) * NVL (tmu_no_loc, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_case), 0) * NVL (tmu_no_case, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_split), 0) * NVL (tmu_no_split, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_merge), 0) * NVL (tmu_no_merge, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_aisle), 0) * NVL (tmu_no_aisle, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_drop), 0) * NVL (tmu_no_drop, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_cart), 0) * NVL (tmu_no_cart, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_cart_piece), 0) * NVL (tmu_no_cart_piece, 0) / 1667, 2),
		ROUND (NVL (SUM (kvi_no_pallet_piece), 0) * NVL (tmu_no_pallet_piece, 0) / 1667, 2),
		ROUND (DECODE (print_goal_flag, 'Y',
			NVL (tmu_doc_time , 0) +
			NVL (tmu_order_time , 0) +
			NVL (SUM (kvi_cube), 0) * NVL (tmu_cube, 0) +
				NVL (SUM (kvi_wt), 0) * NVL (tmu_wt, 0) +
				NVL (SUM (kvi_no_piece), 0) * NVL (tmu_no_piece, 0) +
				NVL (SUM (kvi_no_pallet), 0) * NVL (tmu_no_pallet, 0) +
				NVL (SUM (kvi_no_item), 0) * NVL (tmu_no_item, 0) +
				NVL (SUM (kvi_no_data_capture), 0) *
					NVL (tmu_no_data_capture, 0) +
				NVL (SUM (kvi_no_po), 0) * NVL (tmu_no_po, 0) +
				NVL (SUM (kvi_no_stop), 0) * NVL (tmu_no_stop, 0) +
				NVL (SUM (kvi_no_zone), 0) * NVL (tmu_no_zone, 0) +
				NVL (SUM (kvi_no_loc), 0) * NVL (tmu_no_loc, 0) +
				NVL (SUM (kvi_no_case), 0) * NVL (tmu_no_case, 0) +
				NVL (SUM (kvi_no_split), 0) * NVL (tmu_no_split, 0) +
				NVL (SUM (kvi_no_merge), 0) * NVL (tmu_no_merge, 0) +
				NVL (SUM (kvi_no_aisle), 0) * NVL (tmu_no_aisle, 0) +
				NVL (SUM (kvi_no_drop), 0) * NVL (tmu_no_drop, 0) +
				NVL (SUM (kvi_no_cart), 0) * NVL (tmu_no_cart, 0) +
				NVL (SUM (kvi_no_cart_piece), 0) *
					NVL (tmu_no_cart_piece, 0) +
				NVL (SUM (kvi_no_pallet_piece), 0) *
					NVL (tmu_no_pallet_piece, 0) +
				NVL (kvi_doc_time, 0) + NVL (kvi_order_time, 0),
			0) / 1667, 2)
	  FROM	lbr_func lb, job_code jc, batch b
	 WHERE	jc.jbcd_job_code = b.jbcd_job_code
	   AND	lb.lfun_lbr_func = jc.lfun_lbr_func
	 GROUP	BY
		b.jbcd_job_code,
		b.status,
--		DECODE (ref_no, 'MULTI',
--			NVL (parent_batch_no, batch_no), batch_no),
		DECODE (ref_no,
			'MULTI', DECODE(b.status,
					'M', NVL (parent_batch_no, batch_no),
					b.batch_no),
			batch_no),
		NVL (kvi_doc_time, 0),
		NVL (kvi_order_time, 0),
		user_id, user_supervsr_id,
		NVL (actl_time_spent, 0),
		print_goal_flag,
		engr_std_flag,
 		NVL(tmu_doc_time,0),
		NVL(tmu_cube,0),
		NVL(tmu_wt,0),
		NVL(tmu_no_piece,0),
		NVL(tmu_no_pallet,0),
		NVL(tmu_no_item,0),
		NVL(tmu_no_data_capture,0),
		NVL(tmu_no_po,0),
		NVL(tmu_no_stop,0),
		NVL(tmu_no_zone,0),
		NVL(tmu_no_loc,0),
		NVL(tmu_no_case,0),
		NVL(tmu_no_split,0),
		NVL(tmu_no_merge,0),
		NVL(tmu_no_aisle,0),
		NVL(tmu_no_drop,0),
		NVL(tmu_order_time,0),
		NVL(tmu_no_cart,0),
		NVL(tmu_no_cart_piece,0),
		NVL(tmu_no_pallet_piece,0)

/
COMMENT ON TABLE swms.v_calc_time_total IS 'VIEW sccs_id=@(#) src/schema/views/v_calc_time_total.sql, swms, swms.9, 10.1.1 1/23/08 1.4'
/
