CREATE OR REPLACE VIEW swms.v_route_close
AS
	SELECT	r.route_no, t_cw.num_wh_outs tot_wh_outs, t_cw.num_prd_outs tot_prd_outs, t_cw.tot_pads, t_cw.tot_pals, t_cool.num_coo_cust,
		t_cw.num_cw tot_num_cw, t_cw.num_cw_ent num_cw_entered, t_cw.num_cw_not_ent num_cw_missing
	  FROM	route r,
	(
	SELECT	o.route_no, SUM (wh_out_qty) num_wh_outs, SUM (product_out_qty) num_prd_outs,
		SUM (DECODE (SIGN (NVL (num_cw_by_seq - num_cw_by_seq_ent, 0) - (NVL (wh_out_qty, 0)+ NVL (product_out_qty, 0))), -1, 0,
			NVL (num_cw_by_seq - num_cw_by_seq_ent, 0) - (NVL (wh_out_qty, 0)+ NVL (product_out_qty, 0)))) num_cw_not_ent,
		/* CRQ42406 - PAW count is not reduced from Catchweight count
			SUM (DECODE (o.cw_type, 'I', (NVL (num_cw_by_seq, 0) - NVL (wh_out_qty, 0)), 0)) num_cw, */
		SUM (NVL (num_cw_by_seq, 0)) num_cw,
		SUM (num_cw_by_seq_ent) num_cw_ent,
		SUM (DECODE (o.deleted, 'PAD', 1, 0)) tot_pads,
		SUM (DECODE (o.deleted, 'PAL', 1, 0)) tot_pals
	  FROM	ordd o,
		(SELECT	order_id, order_line_id,
			COUNT (0) num_cw_by_seq,
			COUNT (catch_weight) num_cw_by_seq_ent
		   FROM	ordcw
		  GROUP	BY order_id, order_line_id) cwt
	WHERE	o.order_id = cwt.order_id (+)
	  AND	o.order_line_id = cwt.order_line_id (+)
	GROUP	BY o.route_no) t_cw,
	(SELECT	m.route_no, COUNT (DISTINCT (s.customer_id)) num_coo_cust
	   FROM ordm m, spl_rqst_customer s, ordd d, cool_item i
	  WHERE	m.cust_id = s.customer_id
	    AND	m.route_no = d.route_no
	    AND	m.order_id = d.order_id
	    AND	d.prod_id = i.prod_id
	    AND	d.cust_pref_vendor = i.cust_pref_vendor
	    AND	s.cool_trk = 'Y'
	    AND	NVL (d.deleted, 'OK') NOT IN ('PAD', 'PAL')
	  GROUP BY m.route_no) t_cool
	WHERE r.route_no = t_cw.route_no (+)
	  AND r.route_no = t_cool.route_no (+)
   AND	r.status IN ('OPN', 'SHT')
/
CREATE OR REPLACE PUBLIC SYNONYM v_route_close FOR swms.v_route_close
/
GRANT SELECT ON v_route_close TO swms_user, swms_viewer
/
