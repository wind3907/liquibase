------------------------------------------------------------------------------
--
-- View:
--    v_sos_batch_info
--
-- Description:
--    This view select the order processing batch to send to SOS.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/28/07 prpnxk   D#12251 Created.
--    09/14/09 prplhj   D#12517 Replace item description length from 24 to 30.
--    02/10/15 ayad5195 Added Label_Max_Seq column to send it to client RF in sos_batchsel.pc
--                      to print text sequence of label ex. '2 OF 5'
--
--    12/14/15 prpbcb   Project
--                      TFS Project:
--  R30.4--FTP30.3.2--WIB#604--Charm6000010609_SOS_pick_label_max_qty_to_pick_doubled_for_merge_picks
--
--                      Bug fix.  Merge selection.
--                      Issue:
--                         FSLFHR and DSLDHR are printing wrong quantities, selector
--                         will need one case but label will print one sticker as
--                         1 of 2. If selector needs 4 cases, labels will print up thru
--                         4 of 8. It appears all quantities are being doubled as they
--                         get printed.
--                      This value is coming from view column "label_max_seq" which is
--                      the total qty allocated for the order-item.  The problem is
--                      the qty was doubled for merge picks because it was counting both
--                      the pick from the slot and the pick from the merge location.
--                      Changed
--     (SELECT sum(fdi.qty_alloc)
--        FROM float_detail fdi, floats fi
--       WHERE fdi.order_seq = fd.order_seq
--         AND fdi.float_no = fi.float_no
--         AND fi.pallet_pull = 'N') label_max_seq,
--                      to
--     (SELECT sum(fdi.qty_alloc)
--        FROM float_detail fdi, floats fi
--       WHERE fdi.order_seq                  = fd.order_seq
--         AND fdi.float_no                   = fi.float_no
--         AND fdi.merge_alloc_flag           = fd.merge_alloc_flag   -- 12/14/15  Brian Bent Added
--     --  AND NVL(fdi.merge_alloc_flag, 'x') <> 'M'                  -- 12/14/15  Brian Bent Added  don't do this.
--         AND fi.pallet_pull                 = 'N')   label_max_seq,
--
--                      NOTE: I am not sure the above query for label_max_seq will
--                            give the desired results if an order-item is broken
--                            across floats/batches.  We will need to check this out.
--
--                      Format the SQL to make it easier to read.
--
--    10/12/20 bben0556 Brian Bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                      Add:
--                         f.is_sleeve_selection      This designates if the batch is a sleeve selection batch:
--                         fd.sleeve_id
--
--    08/20/21 mche6435 Add OpcoNumber and ParentLP to Floats info Jira-3495
--
--    09/01/21 spin4795 Scott Pinchback
--             Chick-fil-A Project - OPCOF-3536
--             Added FLOAT_DETAIL.GS1_TRK to this view to indicate GS1 data collection required.
--    12/2/2021 kchi7065 Kiran Chimata Story 3880
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW SWMS.V_SOS_BATCH_INFO AS
SELECT v.carousel_flag,
       v.folding_bills,
       v.item_descrip_caps,
       v.label_same_slot_desc_seq,
       v.label_seq,
       v.print_box_contents,
       s.config_flag_val      lbr_mgmt_flag,
       CHR(ASCII(v.start_float_ch) + f.batch_seq - 1) float_char,
       f.route_no,
       sb.batch_no,
       sb.status              batch_status,
       sb.picked_by,
       f.float_no,
       j.whar_area            door_area,
       f.comp_code,
       f.zone_id,
       f.float_cube,
       f.pallet_pull,
       f.fl_opt_pull,
       DECODE(f.door_area, 'C', r.c_door,
                           'D', r.d_door,
                           'F', r.f_door) door_no,
       f.float_seq,
       r.method_id            fl_method_id,
       sm.sel_lift_job_code,
       sm.method_id,
       f.group_no,
       f.batch_seq,
       f.b_stop_no,
       f.e_stop_no,
       f.merge_loc,
       NVL(f.is_sleeve_selection, 'N')   is_sleeve_selection,   -- NVL in case it is null
       r.route_batch_no,
       r.seq_no               route_seq_no,
       fd.seq_no              fd_seq_no,
       fd.stop_no,
       fd.prod_id,
       fd.cust_pref_vendor,
       fd.src_loc,
       fd.uom,
       fd.qty_alloc,
       fd.merge_float_no,
       fd.merge_seq_no,
       fd.merge_loc           fd_merge_loc,
       DECODE(fd.merge_alloc_flag, 'M', 'Y', 'N') merge_alloc_flag,
       fd.order_id,
       fd.order_line_id,
       fd.sos_status,
       fd.clam_bed_trk,
       fd.cool_trk,
       fd.catch_wt_trk,
       fd.gs1_trk,
       fd.multi_home_seq,
       fd.order_seq,
       fd.exp_date,
       fd.mfg_date,
       --
       -- float zone as will print on the label.  It starts at 1 then
       -- increments by 1 though all zones on the batch.
       -- Example:  Batch has 3 floats. R, S, T.  Each float has 2 zones.
       --           All zones have product.  The zone will be 1, 2, 3, 4, 5, 6.
       --           The float zone on the pick labels will be:  R-1, R-2, S-3, S-4, T-5, T-6
       ((f.batch_seq - 1) * se.no_of_zones) + fd.zone   zone,
       --
       fd.cube,
       fd.item_seq,
       fd.st_piece_seq,
       fd.bc_st_piece_seq,
       fd.qty_short           fd_qty_short,
       l.pik_path,
       l.pik_aisle,
       l.pik_slot,
       DECODE(label_same_slot_desc_seq, 'Y', fd.stop_no, 1) desc_stop_no,
       DECODE(label_same_slot_desc_seq, 'Y', 1, fd.stop_no) asc_stop_no,
       SUBSTR(z.descrip, 1, 20)                             zone_descrip,
       DECODE(od.pcl_flag, 'Y', od.pcl_id, NULL)            pcl_id,
       DECODE(NVL(od.pcl_flag, 'N'), 'Y', NULL,
                                     DECODE(v.unit_cost_flag, 'Y', RTRIM(SUBSTR(LTRIM(od.pcl_id), 1, 7)),
                                                              NULL)) price,
       pl_sos.F_GetCustSplInstruction(fd.order_id, f.float_no)  cust_spl_instr,
       p.instruction       item_spl_instr,
       p.master_case,
       p.spc,
       p.avg_wt,
       p.auto_ship_flag,
       p.high_risk_flag,
       p.case_cube,
       p.split_cube,
       DECODE(v.item_descrip_caps, 'Y', UPPER(p.descrip),
                                   p.descrip)   item_descrip,
       p.pack || '/' || p.prod_size pack,
       p.prod_size    Measure,
       p.mfg_sku,
       p.brand,
       ssa.area_code,
       ss.short_batch_no,
       ss.batch_no orig_batch_no,
       ss.orderseq short_ord_seq,
       ss.qty_short,
       ss.sos_status short_status,
       ss.short_reason,
       DECODE(ss.short_batch_no, NULL, NULL,
                                 pl_sos.F_GetShortBatchStatus(ss.short_batch_no)) Short_Batch_Status,
       se.multi_no,
       se.multi_split_no,
       ai.direction,
       om.truck_no,
       om.cust_id,
       om.cust_name,
       om.cust_po,
       om.clr_special,
       om.dry_special,
       om.frz_special,
       om.ship_date,
       DECODE(v.print_cw_on_label, 'ALL', 'Y',
                                   'NONE', 'N',
                                   NVL(src.print_cw_on_label, 'N'))  print_cw_on_label,
       fd.carrier_id,
       fd.sleeve_id,
       om.order_type,
       sb.no_of_floats,
       --
       -- Get the total qty allocated for the order-item for the regular picks (pallet_pull = 'N)'.
       -- This value is the Y value on the "X of Y" that prints on the pick label.
       -- The order-item can be split across zones and if syspar BREAK_ITEM_ON_FLOAT is 1
       -- then the order-item it can be splits across floats and potentially batches.
       -- For the pick from the slot do not include the pick from the merge location
       -- and for the pick from the merge location do not include the pick from the slot otherwise the value
       -- will be doubled.
       -- FYI  float_detail.merge_alloc_flag values and what they mean:
       --           M - merge pick and this is the pick from the merge location.
       --           X - non-merge pick.
       --           Y - merge pick and this is the pick from the slot.
       --      There will be a pair of M and Y float detail records for each merge pick.
       (SELECT sum(fdi.qty_alloc)
          FROM float_detail fdi, floats fi
	 WHERE fdi.order_seq                  = fd.order_seq
	   AND fdi.float_no                   = fi.float_no
           AND fdi.merge_alloc_flag           = fd.merge_alloc_flag   -- 12/14/15  Brian Bent Added
       --  AND NVL(fdi.merge_alloc_flag, 'x') <> 'M'                  -- 12/14/15  Brian Bent Added  don't do this.
	   AND fi.pallet_pull                 = 'N')   label_max_seq,
       --
       om.immediate_ind,
       om.site_to_truck_no,
       f.parent_pallet_id,
       om.site_to
  FROM v_order_proc_syspars v,
       sys_config s,
       sos_short ss,
       spl_rqst_customer src,
       swms_sub_areas ssa,
       aisle_info ai,
       ordm om,
       ordd od,
       pm p,
       sel_equip se,
       sel_method sm,
       route r,
       loc l,
       float_detail fd,
       zone z,
       job_code j,
       floats f,
       sos_batch sb
 WHERE sb.batch_no         > '0'
   AND f.batch_no          = DECODE (SUBSTR (sb.batch_no, 1, 1), 'S', 0, TO_NUMBER (sb.batch_no))
   AND f.pallet_pull       = 'N'
   AND j.jbcd_job_code     = sb.job_code
   AND z.zone_id           = f.zone_id
   AND fd.float_no         = f.float_no
   AND fd.route_no         = f.route_no
   AND l.logi_loc          = fd.src_loc
   AND ai.name             = SUBSTR(l.logi_loc, 1, 2)
   AND ssa.sub_area_code   = ai.sub_area_code
   AND p.prod_id           = fd.prod_id
   AND p.cust_pref_vendor  = fd.cust_pref_vendor
   AND r.route_no          = f.route_no
   AND sm.method_id        = r.method_id
   AND sm.group_no         = f.group_no
   AND se.equip_id         = sm.equip_id
   AND od.seq              = fd.order_seq
   AND om.order_id         = od.order_id
   AND src.customer_id(+)  = om.cust_id
   AND ss.orderseq(+)      = fd.order_seq
   AND ss.location(+)      = fd.src_loc
   AND fd.qty_alloc        > 0
   AND s.config_flag_name  = 'LBR_MGMT_FLAG';

COMMENT ON TABLE swms.v_sos_batch_info IS 'VIEW sccs_id=@(#) src/schema/views/v_sos_batch_info.sql, swms, swms.9, 11.1 9/25/09 1.16';

