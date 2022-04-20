------------------------------------------------------------------------------
--
-- View:
--    v_sos_short
--
-- Description:
--    This view is used in the SOS short processing.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    01/10/21 bben0556 Brian Bent
--                      Project: R44-Jira3222_Sleeve_selection
--
--                      Add:
--                         floats.is_sleeve_selection  This designates if the short is
--                                                     from a sleeve selection batch.
--                                                     "is_sleeve_selection" could also have been
--                                                     taken from SOS_BATCH table but I elected
--                                                     to use the FLOATS table.
--                                                     At this time we do not allow sleeve and non sleeve shorts
--                                                     to be grouped together.  Changes made to form sosss1.fmb
--                                                     to prevent it.
--                                                 
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW swms.v_sos_short AS
SELECT s.area,
       s.orderseq,
       decode(s.picktype,'08',decode(sign(s.qty_short - s.qty_total),-1,'03',s.picktype),s.picktype) picktype,
       s.batch_no,
       s.truck,
       s.location,
       s.dock_float_loc,
       s.qty_total,
       s.qty_short,
       s.sos_status,
       s.short_time,
       s.fork_status,
       s.resolution_time,
       s.short_group,
       s.user_id,
       s.short_batch_no,
       p.descrip description,
       p.prod_id item,
       decode(o.uom,1,p.split_cube,s.qty_short * p.case_cube) cube,
       decode(o.uom,1,p.avg_wt,p.avg_wt*p.spc) weight,
       r.sch_time departure_time,
       r.route_no,
       DECODE (SIGN (o.stop_no - TRUNC (o.stop_no)), 0, TO_CHAR (o.stop_no),
               DECODE (LENGTH (SUBSTR (TO_CHAR (o.stop_no), INSTR (TO_CHAR (o.stop_no), '.') + 1, 2)),
               1, RPAD (TO_CHAR (o.stop_no), LENGTH (TO_CHAR (o.stop_no)) + 1, '0'),
               TO_CHAR (o.stop_no))) stop,
       o.order_id invoiceno,
       decode(s.picktype,'04','1','06','1',p.pack) pack,
       p.container,
       p.prod_size,
       p.prod_size_unit,
       c.cust_id customer,
       c.cust_name custname,
       c.ship_date,
       substr((substr(to_char(nvl(r.f_door,decode(f.door_area,'D',r.d_door,'C',r.c_door,'F',r.f_door)),'B99'),2,2) || '/' ||
               substr(to_char(nvl(r.c_door,decode(f.door_area,'D',r.d_door,'C',r.c_door,'F',r.f_door)),'B99'),2,2) || '/' ||
               substr(to_char(nvl(r.d_door,decode(f.door_area,'D',r.d_door,'C',r.c_door,'F',r.f_door)),'B99'),2,2)),1,8) doors,
       nvl(p.internal_upc,'00000000000000') internal_upc,
       nvl(p.external_upc,'00000000000000') external_upc,
       p.weight case_weight,
       p.spc,
       p.catch_wt_trk,
       o.order_line_id,
       o.uom,
       s.wh_out_qty,
       s.short_on_short_status,
       s.whout_by,
       s.short_reason,
       s.qty_short_on_short,
       s.pik_status,
       s.float_no,
       s.float_detail_seq_no,
       decode(oc.order_id, NULL, 'N', 'Y') coo_trk,
       decode(cb.order_id, NULL, 'N', 'Y') clam_trk,
       su.nos_user,
       decode(rc.prod_id,NULL,'N','Y') pending_repl,
       nvl(rc.replen_cnt,0) replen_cnt,
       nvl(rc.replen_qty,0) replen_qty,
       l.slot_type,
       nvl(b.user_id,f_get_short_user(s.short_batch_no,s.location,o.prod_id,s.batch_no,o.order_id,o.order_line_id)) short_user,
       ai.avl_cases, ai.avl_splits,
       p.finish_good_ind,         --Jira529
       f.is_sleeve_selection      -- 01/11/2021 Brian Bent Added
  FROM v_available_inv ai,
       v_dmd_replen_cnt dr,
       v_new_ndm_replen_cnt rc,
       loc l,
       sos_usr_config su,
       sos_batch sb,
       batch b,
       ord_cool oc,
       ordcb cb,
       route r,
       pm p,
       ordm c,
       ordd o,
       floats f,
       float_detail fd,
       sos_short s
 WHERE fd.float_no                = s.float_no
   AND fd.seq_no                  = s.float_detail_seq_no
   AND f.float_no                 = fd.float_no
   AND o.order_id                 = fd.order_id
   AND o.order_line_id            = fd.order_line_id
   AND p.prod_id                  = o.prod_id
   AND p.cust_pref_vendor         = o.cust_pref_vendor
   AND c.order_id                 = o.order_id
   AND r.route_no                 = o.route_no
   AND substr(s.batch_no,1,1)     <> 'S'
   AND ai.prod_id                 = o.prod_id
   AND ai.cust_pref_vendor        = o.cust_pref_vendor
   AND oc.order_id         (+)    = o.order_id
   AND oc.order_line_id    (+)    = o.order_line_id
   AND oc.seq_no           (+)    = 1
   AND cb.order_id         (+)    = o.order_id
   AND cb.order_line_id    (+)    = o.order_line_id
   AND cb.seq_no           (+)    = 1
   AND b.batch_no          (+)    = 'S'|| s.short_batch_no
   AND sb.batch_no                = s.batch_no
   AND su.user_id          (+)    = sb.picked_by
   AND su.nos_user         (+)    = 'Y'
   AND l.logi_loc                 = s.location
   AND rc.prod_id          (+)    = o.prod_id
   AND dr.prod_id          (+)    = o.prod_id
   AND dr.route_no         (+)    = o.route_no;

CREATE OR REPLACE PUBLIC SYNONYM v_sos_short FOR swms.v_sos_short;

GRANT SELECT ON v_sos_short TO SWMS_VIEWER;
GRANT ALL ON v_sos_short TO SWMS_USER;
