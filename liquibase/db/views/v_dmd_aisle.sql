REM @(#) src/schema/views/v_dmd_aisle.sql, swms, swms.9, 10.1.1 9/13/06 1.5
REM File : @(#) src/schema/views/v_dmd_aisle.sql, swms, swms.9, 10.1.1
REM Usage: sqlplus USR/PWD @src/schema/views/v_dmd_aisle.sql, swms, swms.9, 10.1.1
REM
REM        AND	NVL (r.inv_dest_loc, r.dest_loc) = ss.location (+)
CREATE OR REPLACE VIEW SWMS.V_DMD_AISLE (route_batch_no, user_id, area_code, AISLE_NAME, qty_short_sort_fld, status_sort_fld, msku_sort_fld, NO_TASKS)
AS
	SELECT  r.route_batch_no, r.USER_ID, sa.area_code,
		SUBSTR (DECODE (NVL (sc.CONFIG_FLAG_VAL, 'N'), 'Y', r.dest_loc, r.src_loc), 1, 2),
                MIN (DECODE (NVL (ss.qty_short, 0), 0, 1, 0)),
                MIN (DECODE (NVL (b.status, '*'), 'F', 1, '*', 1, 0)),
                MIN (DECODE (r.parent_pallet_id, NULL, 1, 0)),
                COUNT(distinct r.pallet_id)
          FROM  ordd o, loc l, swms_sub_areas sa, aisle_info ai, replenlst r,
                sos_short ss, sys_config sc, floats f,
                float_detail fd, float_detail fd1, batch b
         WHERE r.type = 'DMD'
           AND r.status = 'NEW'
           AND l.logi_loc = r.src_loc
           AND ai.pick_aisle = l.pik_aisle
           AND sa.sub_area_code = ai.sub_area_code
           AND config_flag_name = 'SORT_DMD_REPL_BY_HOME_SLOT'
	   AND	r.order_id IS NOT NULL
           AND  fd.float_no = r.float_no
           AND  fd.seq_no = r.seq_no
           AND  fd1.order_id = fd.order_id
           AND  fd1.order_line_id = fd.order_line_id
           AND  o.order_id = fd.order_id
           AND  o.order_line_id = fd.order_line_id
	   AND	o.seq = ss.orderseq (+)
           AND  fd1.float_no != fd.float_no
           AND  f.float_no = fd1.float_no
           AND  f.pallet_pull != 'R'
           AND  b.batch_no (+) = 'S' || f.batch_no
         GROUP BY r.route_batch_no, R.USER_ID, sa.area_code, SUBSTR (DECODE (NVL (sc.CONFIG_FLAG_VAL, 'N'), 'Y', r.dest_loc, r.src_loc), 1, 2)
UNION
	SELECT  r.route_batch_no, r.USER_ID, sa.area_code,
		SUBSTR (DECODE (NVL (sc.CONFIG_FLAG_VAL, 'N'), 'Y', r.dest_loc, r.src_loc), 1, 2),
                MAX (0), MAX (0), MAX (0),
                COUNT (distinct r.pallet_id)
          FROM  loc l, swms_sub_areas sa, aisle_info ai, replenlst r,
                sys_config sc
         WHERE r.type = 'DMD'
	   AND r.order_id is NULL
           AND r.status = 'NEW'
           AND l.logi_loc = r.src_loc
           AND ai.pick_aisle = l.pik_aisle
           AND sa.sub_area_code = ai.sub_area_code
           AND config_flag_name = 'SORT_DMD_REPL_BY_HOME_SLOT'
         GROUP BY r.route_batch_no, R.USER_ID, sa.area_code, SUBSTR (DECODE (NVL (sc.CONFIG_FLAG_VAL, 'N'), 'Y', r.dest_loc, r.src_loc), 1, 2)
/

