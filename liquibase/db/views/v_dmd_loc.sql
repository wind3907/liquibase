REM @(#) src/schema/views/v_dmd_loc.sql, swms, swms.9, 10.1.1 9/7/06 1.5
REM File : @(#) src/schema/views/v_dmd_loc.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_dmd_loc.sql, swms, swms.9, 10.1.1
REM
REM		   AND	NVL (r.inv_dest_loc, r.dest_loc) = ss.location (+)

CREATE OR REPLACE VIEW swms.v_dmd_loc (user_id, dest_loc, qty_short_sort_fld, status_sort_fld, msku_sort_fld, src_loc, pallet_id, qty,
				  truck_no, status, task_id, door_no, drop_qty, route_batch_no,
				  batch_no, route_no, prod_id, aisle_name, home_slot_sort, repl_status,
				  seq_no, parent_pallet_id)
AS
	SELECT  r.user_id, r.dest_loc,
		DECODE (NVL (ss.qty_short, 0), 0, 1, 0),
		DECODE (NVL (b.status, '*'), 'F', 1, '*', 1, 0),
		DECODE (r.parent_pallet_id, NULL, 1, 0),
		r.src_loc, r.pallet_id, r.qty, r.truck_no,
		NVL (b.status, '*'), r.task_id,
		to_char (r.door_no), r.drop_qty, r.route_batch_no, r.batch_no,
		r.route_no, r.prod_id, ai.name, sc.config_flag_val, r.status, ro.seq_no,
		r.parent_pallet_id
	  FROM	route ro, ordd o, aisle_info ai, loc l, sys_config sc, float_detail fd,
		float_detail fd1, batch b, sos_short ss, floats f, replenlst r
	 WHERE	r.status = 'NEW'
	   AND	r.order_id IS NOT NULL
	   AND	r.type = 'DMD'
	   AND	sc.config_flag_name = 'SORT_DMD_REPL_BY_HOME_SLOT'
	   AND	DECODE (sc.config_flag_val, 'Y', r.dest_loc, r.src_loc) = l.logi_loc
	   AND	ai.pick_aisle = l.pik_aisle
	   AND	fd.float_no = r.float_no
	   AND	fd.seq_no = r.seq_no
	   AND	fd1.order_id = fd.order_id
	   AND	fd1.order_line_id = fd.order_line_id
	   AND	o.order_id = fd.order_id
	   AND	o.order_line_id = fd.order_line_id
	   AND	o.seq = ss.orderseq (+)
	   AND	fd1.float_no != fd.float_no
	   AND	f.float_no = fd1.float_no
	   AND	(f.pallet_pull = 'N' OR
		 (f.pallet_pull IN ('B', 'Y') and
			NOT EXISTS (SELECT 0
				      FROM floats f1, float_detail fd2
				     WHERE fd2.order_id = fd.order_id
					AND fd2.order_line_id = fd.order_line_id
					AND f1.float_no = fd2.float_no
					AND f1.pallet_pull = 'N')))
	   AND	ro.route_no = r.route_no
	   AND	b.batch_no (+) = 'S' || f.batch_no
UNION
	SELECT  DISTINCT r.user_id, r.dest_loc, 0, 0, 0,
		r.src_loc, r.pallet_id, r.qty, r.truck_no, '*', r.task_id,
		to_char (r.door_no), r.drop_qty, r.route_batch_no, r.batch_no,
		r.route_no, r.prod_id, ai.name, sc.config_flag_val, r.status, ro.seq_no,
		r.parent_pallet_id
	  FROM	route ro, replenlst r, aisle_info ai, loc l, sys_config sc
	 WHERE	r.status = 'NEW'
	   AND	r.order_id IS NULL
	   AND	r.type = 'DMD'
	   AND	ro.route_no = r.route_no
	   AND	sc.config_flag_name = 'SORT_DMD_REPL_BY_HOME_SLOT'
	   AND	DECODE (sc.config_flag_val, 'Y', r.dest_loc, r.src_loc) = l.logi_loc
	   AND	ai.pick_aisle = l.pik_aisle
/

