------------------------------------------------------------------------------
-- File:
--    v_replen_bulk.sql
--
-- View:
--    v_replen_bulk
--
-- Description:
--    View listing the available replenishments, bulk pull tasks and XDK tasks.
--    The view only selects XDK tasks with a slot location as the source location.
--    NOTE: View V_REPLEN_XDOCK selects the XDK tasks that have a door as the source location.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    08/30/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47-xdock-OPCOF3578_OP_Site_2_Merge_float_information_sent_from_Site_1
--
--                      Select replenlst:
--                         - site_from
--                         - site_to
--                         - cross_dock_type,
--                         - xdock_pallet_id
--
--    09/27/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47_0-xdock-OPCOF3611_Site_2_Bulk_pull_door_to_door_replen_shows_all_XDK_tasks
--
--                      Ths view should select the XDK tasks but only those from a slot location
--                      to a door.  What I did is any place that had 'BLK' I added 'XDK'.
--                      The selects always join to the the LOC table so this view will never
--                      select a XDK task with a door as a source location.
--
--    10/19/21 bben0556 Brian Bent
--                      R1 cross dock  (Xdock)
--                      Card: R47_0-xdock-OPCOF3715_XDK_task_with_multi_item_not_showing_on_RF
--
--                      XDK tasks with MULTI item not showing on the RF.  This started
--                      happening when we removed item 'MULTI" from the PM table.
--                      Add another union for XDK task with replenlst.prod_id = 'MULTI'.
--                      The item description wiill be 'MULTI'.
--                      The miniload storage indicator will be 'N'.
--                      The mfg_sku will be '*'.
--
--    10/25/21 bben0556 Brian Bent
--                      R1 cross dock.
--                      Card: R47_0-xdock-OPCOF3752_Site_1_put_site_2_truck_no_stop_no_on_RF_bulk_pull_label
--
--                      Columns site_to_route_no and site_to_truck_no were added to tables FLOATS and REPLENLST.
--                      Select from replenlst:
--                         - site_to_route_no
--                         - site_to_truck_no
--
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_replen_bulk AS
	SELECT	repls.*, last_stop.last_stop_no, last_stop.route_active, fltp.priority
	  FROM
	(SELECT	r.task_id, r.type, r.replen_type, r.replen_area, r.status, r.prod_id, r.cust_pref_vendor, r.pallet_id, r.src_loc, r.dest_loc,
			2 uom, dest.uom dest_uom, DECODE (r.type, 'NDM', CEIL (r.qty / p.spc), r.qty) qty, NVL (r.drop_qty, 0) drop_qty,
			r.route_no, r.truck_no, r.door_no, r.order_id, r.float_no, r.exp_date, r.mfg_date, p.descrip, NVL (p.mfg_sku, '*') mfg_sku,
			dest.pik_path d_pikpath, src.pik_path s_pikpath, p.miniload_storage_ind, sa.area_code,
			src.pik_aisle src_pik_aisle, dest.put_aisle dest_pik_aisle, src.put_aisle src_put_aisle, dest.put_aisle dest_put_aisle,
			src.put_slot src_put_slot, dest.put_slot dest_put_slot, ai.name, r.inv_dest_loc, NVL  (r1.route_batch_no, 0) route_batch_no,
			NVL (r1.seq_no, 0) seq_no,
                r.site_from,
                r.site_to,
                r.cross_dock_type,
                r.xdock_pallet_id,
                r.site_to_route_no,
                r.site_to_truck_no
	  FROM route r1, swms.swms_sub_areas sa, swms.aisle_info ai, swms.loc src, swms.loc dest, swms.pm p, swms.replenlst r
	 WHERE	r.type IN ('NDM', 'BLK', 'XDK')
	   AND	r.status = 'NEW'
	   AND	r.user_id IS NULL
	   AND	p.prod_id = r.prod_id
	   AND	p.cust_pref_vendor = r.cust_pref_vendor
	   AND	src.logi_loc = r.src_loc
	   AND	r.dest_loc IS NOT NULL
	   AND	NVL (r.inv_dest_loc, r.dest_loc) = dest.logi_loc
	   AND	dest.prod_id = r.prod_id
	   AND	ai.pick_aisle = DECODE (r.type, 'BLK', src.pik_aisle,
                                                'XDK', src.pik_aisle,
                                                dest.pik_aisle)
	   AND	r.route_no = r1.route_no (+)
	   AND	sa.sub_area_code = ai.sub_area_code
	UNION ALL
	SELECT	r.task_id, r.type, r.replen_type, r.replen_area, r.status, r.prod_id, r.cust_pref_vendor, r.pallet_id, r.src_loc, r.dest_loc,
			2 uom, dest.uom dest_uom, DECODE (r.type, 'NDM', CEIL (r.qty / p.spc), r.qty) qty, NVL (r.drop_qty, 0) drop_qty,
			r.route_no, r.truck_no, r.door_no, r.order_id, r.float_no, r.exp_date, r.mfg_date, p.descrip, NVL (p.mfg_sku, '*') mfg_sku,
			dest.pik_path d_pikpath, src.pik_path s_pikpath, p.miniload_storage_ind, sa.area_code,
			src.pik_aisle src_pik_aisle, dest.put_aisle dest_pik_aisle, src.put_aisle src_put_aisle, dest.put_aisle dest_put_aisle,
			src.put_slot src_put_slot, dest.put_slot dest_put_slot, ai.name, r.inv_dest_loc, r1.route_batch_no, r1.seq_no,
                r.site_from,
                r.site_to,
                r.cross_dock_type,
                r.xdock_pallet_id,
                r.site_to_route_no,
                r.site_to_truck_no
	  FROM	route r1, loc_reference lr, swms.swms_sub_areas sa, swms.aisle_info ai, swms.loc src, swms.loc dest, swms.pm p, swms.replenlst r
	 WHERE	r.type = 'DMD'
	   AND	r.status = 'NEW'
	   AND	r.user_id IS NULL
	   AND	p.prod_id = r.prod_id
	   AND	p.cust_pref_vendor = r.cust_pref_vendor
	   AND	src.logi_loc = r.src_loc
	   AND	r.dest_loc = lr.bck_logi_loc (+)
	   AND	NVL (lr.plogi_loc, r.dest_loc) = dest.logi_loc
	   AND	dest.prod_id = r.prod_id
	   AND	ai.pick_aisle = DECODE (r.type, 'BLK', src.pik_aisle,
                                                'XDK', src.pik_aisle,
                                                dest.pik_aisle)
	   AND	r.route_no = r1.route_no (+)
	   AND	sa.sub_area_code = ai.sub_area_code
	UNION ALL
	SELECT	r.task_id, r.type, r.replen_type, r.replen_area, r.status, r.prod_id, r.cust_pref_vendor, r.pallet_id, r.src_loc, r.dest_loc,
			2 uom, 2, qty, 0 drop_qty, r.route_no, r.truck_no, r.door_no, r.order_id, r.float_no, r.exp_date, r.mfg_date,
			p.descrip, NVL (p.mfg_sku, '*') mfg_sku, 0, src.pik_path, p.miniload_storage_ind, sa.area_code,
			src.pik_aisle, 0,  src.put_aisle, 0, src.put_slot, 0, ai.name, r.inv_dest_loc, r1.route_batch_no, r1.seq_no,
                r.site_from,
                r.site_to,
                r.cross_dock_type,
                r.xdock_pallet_id,
                r.site_to_route_no,
                r.site_to_truck_no
	  FROM	route r1, swms.swms_sub_areas sa, swms.aisle_info ai, swms.loc src, swms.pm p, swms.replenlst r
	 WHERE	r.type IN ('BLK', 'XDK')
	   AND	r.dest_loc IS NULL
	   AND	r.status = 'NEW'
	   AND	r.user_id IS NULL
	   AND	p.prod_id = r.prod_id
	   AND	p.cust_pref_vendor = r.cust_pref_vendor
	   AND	src.logi_loc = r.src_loc
	   AND	r.route_no = r1.route_no (+)
	   AND	ai.pick_aisle = src.pik_aisle
	   AND	sa.sub_area_code = ai.sub_area_code
	UNION ALL 
        --
        -- 10/19/21 Brian Bent Added  Select 'XDK' task with replenlst.prod_id = 'MULTI'.
        --
	SELECT	r.task_id, r.type, r.replen_type, r.replen_area, r.status, r.prod_id, r.cust_pref_vendor, r.pallet_id, r.src_loc, r.dest_loc,
			2 uom, 2, qty, 0 drop_qty, r.route_no, r.truck_no, r.door_no, r.order_id, r.float_no, r.exp_date, r.mfg_date,
			'MULTI' descrip, '*' mfg_sku, 0, src.pik_path, 'N' miniload_storage_ind, sa.area_code,
			src.pik_aisle, 0,  src.put_aisle, 0, src.put_slot, 0, ai.name, r.inv_dest_loc, r1.route_batch_no, r1.seq_no,
                r.site_from,
                r.site_to,
                r.cross_dock_type,
                r.xdock_pallet_id,
                r.site_to_route_no,
                r.site_to_truck_no
	  FROM	route r1, swms.swms_sub_areas sa, swms.aisle_info ai, swms.loc src, swms.replenlst r
	 WHERE	r.type            IN ('XDK')
	   AND	r.dest_loc        IS NULL
	   AND	r.status          = 'NEW'
	   AND	r.user_id         IS NULL
	   AND	r.prod_id         = 'MULTI'
	   AND	src.logi_loc      = r.src_loc
	   AND	r.route_no        = r1.route_no (+)
	   AND	ai.pick_aisle     = src.pik_aisle
	   AND	sa.sub_area_code  = ai.sub_area_code
/*********
   UNION ALL
	SELECT	r.task_id, r.type, r.replen_type, r.replen_area, r.status, r.prod_id, r.cust_pref_vendor, r.pallet_id, r.src_loc, r.dest_loc,
            2 uom, 2, qty, 0 drop_qty, r.route_no, r.truck_no, r.door_no, r.order_id, r.float_no, r.exp_date, r.mfg_date,
            c.description,'*' mfg_sku, 0,src.pik_path,'N',sa.area_code,
            src.pik_aisle, 0,  src.put_aisle, 0, src.put_slot, 0, ai.name, r.inv_dest_loc, r1.route_batch_no, r1.seq_no
       FROM route r1,
            swms.swms_sub_areas sa,
            swms.aisle_info ai,
            swms.cross_dock_type c,
            swms.loc src,
            swms.replenlst r,
            swms.ordm om
	  WHERE r.TYPE = 'BLK'
        AND r.dest_loc IS NULL
        AND r.status = 'NEW'
        AND r.user_id IS NULL
        AND src.logi_loc = r.src_loc
        AND r.route_no = r1.route_no
        AND ai.pick_aisle = src.pik_aisle
        AND sa.sub_area_code = ai.sub_area_code
		AND r.route_no = om.route_no
        AND om.cross_dock_type = c.cross_dock_type
        AND om.order_id = r.order_id 
***********/
	   ) repls,
	(SELECT DISTINCT rp.task_id, rp.prod_id, pl_replen_rf.f_last_selected_stop (blk.route_no, fd.stop_no) blk_stop,
			SUBSTR (LTRIM (RTRIM (pl_replen_rf.f_route_active (blk.route_no))), 1, 1) blk_rt_active
	   FROM swms.replenlst blk, swms.replenlst rp, swms.float_detail fd
	  WHERE rp.type = 'DMD'
		AND rp.status = 'NEW'
		AND	blk.order_id = rp.order_id
		AND	blk.prod_id = rp.prod_id
		AND	blk.type IN ('BLK', 'XDK')
		AND	blk.status IN ('NEW', 'PIK')
		AND fd.float_no = blk.float_no) dmd_4_blk,
	(SELECT	r4.task_id, pl_replen_rf.f_last_selected_stop (r4.route_no, MAX (fd.stop_no)) last_stop_no, /* latest */
			SUBSTR (LTRIM (RTRIM (pl_replen_rf.f_route_active (r4.route_no))), 1, 1) route_active
	   FROM	swms.replenlst r4, swms.float_detail fd
	  WHERE	r4.type IN ('BLK', 'XDK')
	    AND	r4.status = 'NEW'
	    AND	fd.float_no = r4.float_no
	  GROUP	BY r4.task_id, r4.route_no) last_stop,
	(SELECT	DISTINCT fd.order_id, fd.prod_id
	   FROM	swms.float_detail fd, swms.floats f, swms.sos_short s
	  WHERE	fd.order_seq = s.orderseq
	    AND	f.float_no = fd.float_no
	    AND	f.pallet_pull != 'R') shorts,
	(SELECT	DISTINCT r1.task_id, b.status
	   FROM	swms.floats f, swms.float_detail fd, swms.batch b, swms.replenlst r1
	  WHERE	r1.type = 'DMD'
		AND	fd.route_no = r1.route_no
		AND	fd.float_no != r1.float_no
		AND	fd.prod_id = r1.prod_id
		AND	fd.src_loc = NVL (r1.inv_dest_loc, r1.dest_loc)
		AND	f.float_no = fd.float_no
		AND	f.pallet_pull = 'N'
		AND	b.batch_no = 'S' || f.batch_no) selections,
	(SELECT	DISTINCT r2.task_id, r3.type
	   FROM	swms.replenlst r2, swms.replenlst r3
	  WHERE	r2.type = 'DMD'
	    AND	r3.type IN ('MNL', 'NDM')
		AND	r3.prod_id = r2.prod_id
		AND	r3.status = 'NEW'
		AND	r3.src_loc = NVL (r2.inv_dest_loc, r2.dest_loc)) otherreplens
	, forklift_task_priority fltp
 WHERE	repls.task_id = selections.task_id (+)
   AND	repls.task_id = otherreplens.task_id (+)
   AND	repls.task_id = dmd_4_blk.task_id (+)
   AND	repls.prod_id = dmd_4_blk.prod_id (+)
   AND	repls.order_id = shorts.order_id (+)
   AND	repls.prod_id = shorts.prod_id (+)
   AND	repls.task_id = last_stop.task_id (+)
   AND	fltp.forklift_task_type = repls.type
   AND	((repls.type in ('BLK', 'XDK')
			AND UPPER (fltp.severity) = 
					CASE NVL (last_stop_no, -1) 
						WHEN -1 THEN
							DECODE (route_active, 'Y', 'URGENT', 'NORMAL')
						ELSE
							'CRITICAL'
					END)
		OR (repls.type = 'DMD'
			AND UPPER (fltp.severity) =
					CASE
						WHEN shorts.order_id IS NOT NULL OR NVL (dmd_4_blk.blk_stop, -1) != -1 THEN 'CRITICAL'
						WHEN selections.status IN ('C', 'A') OR NVL (dmd_4_blk.blk_rt_active, 'N') = 'Y' THEN 'URGENT'
						WHEN otherreplens.type = 'MNL' THEN 'HIGH'
						WHEN otherreplens.type = 'NDM' THEN 'MEDIUM'
						ELSE 'NORMAL'
					END)
		OR (repls.type = 'NDM'
			AND UPPER (fltp.severity) = DECODE (repls.replen_type, 'S', 'CRITICAL', 'O', 'URGENT', 'H', 'HIGH', 'NORMAL'))
    OR repls.type = 'SWP'
  )
/



CREATE OR REPLACE PUBLIC SYNONYM v_replen_bulk FOR swms.v_replen_bulk;
GRANT SELECT ON v_replen_bulk TO SWMS_USER, SWMS_VIEWER;

