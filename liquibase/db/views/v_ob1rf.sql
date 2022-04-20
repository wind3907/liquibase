-- 	Modification History
--	------------------------------
--     04/01/10   sth0458 	DN12554 - 212 Legacy Enhancements - SCE057 - 
--					Add UOM field to SWMS
--            		           	Expanded the length of prod size to accomodate 
--					for prod size unit.
--				  	Changed queries to fetch prod_size_unit along with prod_size
  CREATE OR REPLACE FORCE VIEW "SWMS"."V_OB1RF" ("COMP_CODE", "TRUCK_NO", "BATCH_NO", "SRC_LOC", "STOP_NO", "CUST_ID", "FLOAT_SEQ", "BATCH_SEQ", "ZONE", "PACK_SIZE", "BRAND", "DESCRIP", "MFG_SKU", "PROD_ID", "CUST_PREF_VENDOR", "CS_SP_QTY", "CS_SP", "SEQ", "STATUS", "ROUTE_NO", "SCH_TIME", "METHOD_ID", "ROUTE_BATCH_NO") AS 
  select f.comp_code comp_code,
       r.truck_no truck_no,
       nvl(f.batch_no,0) batch_no,
       fd.src_loc src_loc,
       fd.stop_no stop_no,
       om.cust_id cust_id,
       f.float_seq float_seq,
       nvl(f.batch_seq,0) batch_seq,
       fd.zone zone,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - Begin */
	   /* Concatenated prod size unit along with prod size */
       decode(fd.uom,1,'ONLY',lpad(nvl(rtrim(nvl(pm.pack,' ')),' '),4))
         ||'/'||trim(pm.prod_size)||trim(pm.prod_size_unit) pack_size,
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Legacy Enhancements - SCE057 - End */
       pm.brand brand,
       pm.descrip descrip,
       ltrim(rtrim(pm.mfg_sku)) mfg_sku,
       fd.prod_id prod_id,
       fd.cust_pref_vendor cust_pref_vendor,
       decode(fd.uom,1,nvl(fd.qty_alloc,0),nvl(fd.qty_alloc,0)/nvl(pm.spc,1))
         cs_sp_qty,
       decode(fd.uom,1,'SP','CS') cs_sp,
       od.seq seq,
       r.status status,
       r.route_no route_no,
       r.sch_time sch_time,
       r.method_id method_id,
       r.route_batch_no route_batch_no
 from  ordd od, ordm om, route r, pm, float_detail fd, floats f
 where f.merge_loc like '???%'
 and   fd.float_no = f.float_no
 and   fd.qty_alloc > 0
 and   fd.clam_bed_trk = 'Y'
 and   pm.prod_id = fd.prod_id
 and   pm.cust_pref_vendor = fd.cust_pref_vendor
 and   r.route_no = f.route_no
 and   om.order_id = fd.order_id
 and   od.order_id = fd.order_id
 and   od.order_line_id = fd.order_line_id
;


