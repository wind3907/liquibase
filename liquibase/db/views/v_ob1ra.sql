--  Modification History
--  ---------------------------------------------------------------------
--     04/01/10   sth0458   DN12554 - 212 Legacy Enhancements - SCE057 - 
--                          Add UOM field to SWMS
--                          Expanded the length of prod size to accomodate 
--                          for prod size unit.
--                          Changed queries to fetch prod_size_unit 
--                          along with prod_size

  CREATE OR REPLACE FORCE VIEW "SWMS"."V_OB1RA" ("COMP_CODE", "TRUCK_NO", "STOP_NO", "CUST_ID", "CUST_NAME", "BATCH_NO", "FLOAT_SEQ", "BATCH_SEQ", "ZONE", "CS_SP_QTY", "CS_SP", "PACK_SIZE", "BRAND", "DESCRIP", "MFG_SKU", "PROD_ID", "CUST_PREF_VENDOR", "SRC_LOC", "CS_SP_CUBE", "PAGE", "SEQ", "CATCH_WT_TRK", "MERGE_ALLOC_FLAG", "PALLET_PULL", "SEL_TYPE", "WEIGHT", "STATUS", "ROUTE_NO", "SCH_TIME", "METHOD_ID", "GROUP_NO", "FLOAT_NO", "ROUTE_BATCH_NO") AS 
  select f.comp_code comp_code,
       r.truck_no  truck_no,
       fd.stop_no  stop_no,
       om.cust_id  cust_id,
       ltrim(rtrim(om.cust_name)) cust_name,
       nvl(f.batch_no,0) batch_no,
       f.float_seq float_seq,
       nvl(f.batch_seq,0) batch_seq,
       fd.zone zone,
       floor(decode(fd.uom,1,nvl(fd.qty_alloc,0),
                     nvl(fd.qty_alloc,0)/nvl(pm.spc,1))) cs_sp_qty,
       decode(fd.uom,1,'SP','CS') cs_sp,
    /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
    /* concatenated prod_size_unit along with prod_size */
       decode(fd.uom,1,'ONLY',
         lpad(nvl(rtrim(nvl(pm.pack,' ')),' '),4))||'/'||trim(pm.prod_size)||trim(prod_size_unit)
         pack_size,
    /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
       pm.brand brand,
       pm.descrip descrip,
       ltrim(rtrim(pm.mfg_sku)) mfg_sku,
       fd.prod_id prod_id,
       fd.cust_pref_vendor cust_pref_vendor,
       fd.src_loc src_loc,
       round(decode(fd.uom,1,nvl(pm.case_cube,0)/nvl(pm.spc,1),
                             nvl(pm.case_cube,0)),2) cs_sp_cube,
       od.page,
       od.seq,
       pm.catch_wt_trk catch_wt_trk,
       fd.merge_alloc_flag merge_alloc_flag,
       f.pallet_pull   pallet_pull,
       sm.sel_type     sel_type,
       round(nvl(pm.g_weight,0)*(nvl(fd.qty_alloc,0)),2)
                       weight,
       r.status        status,
       r.route_no      route_no,
       r.sch_time      sch_time,
       r.method_id     method_id,
       f.group_no      group_no,
       f.float_no      float_no,
       r.route_batch_no   route_batch_no
  from sel_method sm, ordd od, ordm om, route r, pm,
       float_detail fd, floats f
 where f.merge_loc like '???%'
   and fd.float_no = f.float_no
   and fd.qty_alloc > 0
   and pm.prod_id = fd.prod_id
   and pm.cust_pref_vendor = fd.cust_pref_vendor
   and r.route_no = f.route_no
   and om.order_id = fd.order_id
   and od.order_id = fd.order_id
   and od.order_line_id = fd.order_line_id
   and sm.method_id = r.method_id
   and sm.group_no = f.group_no
;


