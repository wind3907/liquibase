CREATE OR REPLACE VIEW swms.v_kvi_short (short_batch_no, short_user_id,
	v_kvi_cube, v_kvi_wt, v_kvi_pieces, v_kvi_items, v_kvi_data_captures, 
	v_kvi_locs, v_kvi_cases, v_kvi_splits, v_kvi_aisles, flag_picked)
AS
	SELECT	h.short_batch_no,  h.short_user_id, SUM (v.cube),
		SUM (DECODE (v.picktype, '04', v.case_weight/spc, '06', v.case_weight/v.spc, v.case_weight)*v.qty_short), 
		SUM (NVL (v.qty_short, 0)), 
		COUNT (DISTINCT v.item), 
		SUM (NVL (DECODE (v.picktype, '05', v.qty_short, '06', v.qty_short, '21', v.qty_short), 0)), 
		COUNT (DISTINCT v.location), 
		NVL (SUM (DECODE (v.picktype, '04', 0, '06', 0, v.qty_short)), 0), 
		NVL (SUM (DECODE (v.picktype, '04', v.qty_short, '06', v.qty_short)), 0), 
		COUNT (DISTINCT (SUBSTR (v.location, 1, 2))),
		DECODE (short_picktime, NULL, 'N', 'Y')
	  FROM	v_sos_short v, float_hist h
	 WHERE	v.short_batch_no = h.short_batch_no (+)
	   AND	v.invoiceno = h.order_id (+)
	   AND	v.order_line_id = h.order_line_id (+)
	   AND	v.item = h.prod_id (+)
	   AND  v.location = h.src_loc (+)
	 GROUP	BY h.short_batch_no, short_user_id,
		DECODE (short_picktime, NULL, 'N', 'Y')
/
COMMENT ON TABLE swms.v_kvi_short IS 'VIEW sccs_id=@(#) src/schema/views/v_kvi_short.sql, swms, swms.9, 11.1 9/4/09 1.5'
/
