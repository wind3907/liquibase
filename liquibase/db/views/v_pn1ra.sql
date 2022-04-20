REM *************************************************************************
REM Date   :  07-APR-2010
REM File   :  v_pn1ra.sql
REM            
REM Date       User      Comments
REM  04/01/10   sth0458   DN12554 - 212 Legacy Enhancements - SCE057 - 
REM                       Add UOM field to SWMS
REM                       Expanded the length of prod size to accomodate 
REM                       for prod size unit.
REM                       Changed queries to fetch prod_size_unit 
REM                       along with prod_size
REM  12/08/15   apin4795  Symbotic Enhanceents - Corrected the reporting
REM                       of mini-load and symbotic replenishments.  Added
REM                       a UNION for each.
REM
REM *************************************************************************
CREATE OR REPLACE VIEW "SWMS"."V_PN1RA" AS 
SELECT r.dest_loc, 
       r.pallet_id, 
       r.src_loc, 
       r.prod_id, 
       r.task_id, 
       r.batch_no, 
       r.status, 
       r.gen_uid, 
       l.pik_path, 
       isrc.exp_date, 
       l.pik_aisle, 
       p.pack, 
       p.prod_size, 
       p.prod_size_unit, 
       p.cust_pref_vendor, 
       p.descrip, 
       p.split_cube, 
       p.case_cube, 
       idest.qoh, 
       r.qty, 
       l.cube, 
       l.slot_type, 
       nvl(l.uom,0) uom, 
       nvl(p.spc,1) spc, 
       pa.skid_cube, 
       r.type, 
       ssa.area_code, 
       ai.name
  FROM swms_sub_areas ssa, aisle_info ai, pallet_type pa, inv isrc, inv idest, loc l, pm p, replenlst r
 WHERE p.prod_id = r.prod_id 
   AND p.cust_pref_vendor = r.cust_pref_vendor 
   AND l.logi_loc = nvl(r.inv_dest_loc,r.dest_loc)
   AND l.slot_type NOT IN ('MLS','MXI','MXT')
   AND idest.plogi_loc(+) = nvl(r.inv_dest_loc,r.dest_loc)
   AND idest.logi_loc(+) = nvl(r.inv_dest_loc,r.dest_loc)
   AND isrc.plogi_loc(+) = r.src_loc
   AND isrc.logi_loc(+) = r.pallet_id
   AND pa.pallet_type(+) = l.pallet_type 
   AND ai.pick_aisle(+) = l.pik_aisle 
   AND ssa.sub_area_code(+) = ai.sub_area_code
   AND r.status != 'PRE' 
 UNION  -- Add mini-load replenishments
SELECT r.dest_loc, 
       r.pallet_id, 
       r.src_loc, 
       r.prod_id, 
       r.task_id, 
       r.batch_no, 
       r.status, 
       r.gen_uid, 
       l.pik_path, 
       isrc.exp_date, 
       l.pik_aisle, 
       p.pack, 
       p.prod_size, 
       p.prod_size_unit, 
       p.cust_pref_vendor, 
       p.descrip, 
       p.split_cube, 
       p.case_cube, 
       (select nvl(sum(i.qoh + i.qty_planned),0) from loc l2, inv i
         WHERE l2.logi_loc = i.plogi_loc
           AND i.prod_id = r.prod_id
           AND l2.slot_type = 'MLS'),
       r.qty, 
       l.cube, 
       l.slot_type, 
       nvl(l.uom,0) uom, 
       nvl(p.spc,1) spc, 
       pa.skid_cube, 
       r.type, 
       ssa.area_code, 
       ai.name
  FROM swms_sub_areas ssa, aisle_info ai, pallet_type pa, 
       inv isrc, loc l, pm p, replenlst r
 WHERE p.prod_id = r.prod_id 
   AND p.cust_pref_vendor = r.cust_pref_vendor 
   AND l.logi_loc = r.dest_loc
   AND l.slot_type = 'MLS'
   AND isrc.plogi_loc(+) = r.src_loc
   AND isrc.logi_loc(+) = r.pallet_id
   AND pa.pallet_type(+) = l.pallet_type 
   AND ai.pick_aisle(+) = l.pik_aisle 
   AND ssa.sub_area_code(+) = ai.sub_area_code
   AND r.status != 'PRE'
 UNION  -- Add matrix replenishments
SELECT r.dest_loc, 
       r.pallet_id, 
       r.src_loc, 
       r.prod_id, 
       r.task_id, 
       r.batch_no, 
       r.status, 
       r.gen_uid, 
       l.pik_path, 
       isrc.exp_date, 
       l.pik_aisle, 
       p.pack, 
       p.prod_size, 
       p.prod_size_unit, 
       p.cust_pref_vendor, 
       p.descrip, 
       p.split_cube, 
       p.case_cube, 
       (select nvl(sum(i.qoh + i.qty_planned),0) from loc l2, inv i
         where l2.logi_loc = i.plogi_loc
           AND i.prod_id = r.prod_id
           AND l2.slot_type in ('MXI','MXT','MXC','MXF')),
       r.qty, 
       l.cube, 
       l.slot_type, 
       nvl(l.uom,0) uom, 
       nvl(p.spc,1) spc, 
       pa.skid_cube, 
       r.type, 
       ssa.area_code, 
       ai.name
  FROM swms_sub_areas ssa, aisle_info ai, pallet_type pa, 
       inv isrc, loc l, pm p, replenlst r
 WHERE p.prod_id = r.prod_id 
   AND p.cust_pref_vendor = r.cust_pref_vendor 
   AND l.logi_loc = r.dest_loc
   AND l.slot_type IN ('MXI','MXT')
   AND isrc.plogi_loc(+) = r.src_loc
   AND isrc.logi_loc(+) = r.pallet_id
   AND pa.pallet_type(+) = l.pallet_type 
   AND ai.pick_aisle(+) = l.pik_aisle 
   AND ssa.sub_area_code(+) = ai.sub_area_code
   AND r.status != 'PRE';
