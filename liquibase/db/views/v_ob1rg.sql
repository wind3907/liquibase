-- 	Modification History
--	------------------------------
--     04/01/10   sth0458     DN12554 - 212 Enh - SCE057 - 
--                            Add UOM field to SWMS. Expanded the length
--                            of prod size to accomodate for prod size
--                            unit.Changed queries to fetch 
--                            prod_size_unit along with prod_size
CREATE OR REPLACE VIEW "SWMS"."V_OB1RG" AS 
    select f.comp_code comp_code, 
       decode(fd2.float_no, NULL, f.float_no, fd2.float_no) float_no, 
       f.float_seq float_seq, 
       f.group_no group_no, 
       fd.zone zone, 
       nvl(f.batch_no,0) batch_no, 
       nvl(f.batch_seq,0) batch_seq, 
       chr(nvl(f.batch_seq,0)+ascii(sy.config_flag_val)-1) c, 
       r.truck_no truck_no, 
       r.route_no route_no, 
       r.route_batch_no route_batch_no, 
       r.sch_time sch_time, 
       r.status status, 
       r.method_id method_id, 
       fd.stop_no stop_no, 
       fd.src_loc src_loc, 
       fd.qty_order qty_order, 
       od.seq, 
       pm.container container, 
       pm.pack pack, 
       pm.prod_size prod_size, 
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
	   pm.prod_size_unit prod_size_unit,
	   /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - End*/
       l.pik_path pik_path, 
       om.cust_id cust_id, 
       om.order_id order_id, 
       om.order_type order_type, 
       om.cust_name cust_name, 
       om.cust_po cust_po, 
       om.cust_addr1 cust_addr1, 
       om.cust_addr2 cust_addr2, 
       om.cust_city cust_city, 
       om.cust_state cust_state, 
       om.cust_zip cust_zip, 
       floor(decode(fd.uom,1,nvl(fd.qty_alloc,0), 
                             nvl(fd.qty_alloc,0)/nvl(pm.spc,1))) cs_sp_qty, 
       decode(fd.uom,1,'SP','CS') cs_sp, 
       decode(fd.uom,1,'ONLY',
		/* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
         lpad(nvl(rtrim(nvl(pm.pack,' ')),' '),4))||'/'||trim(pm.prod_size)||trim(pm.prod_size_unit)
		 /* 04/01/10 - 12554 - sth0458 - Added for 212 Enh - SCE057 - Begin */
         pack_size, 
       pm.brand brand, 
       pm.descrip descrip, 
       ltrim(rtrim(pm.mfg_sku)) mfg_sku, 
       fd.prod_id prod_id, 
       round(decode(fd.uom,1,nvl(pm.case_cube,0)/nvl(pm.spc,1), 
       nvl(pm.case_cube,0)),2) cs_sp_cube, 
       fd.cust_pref_vendor cust_pref_vendor, 
       round(nvl(pm.g_weight,0)*(nvl(fd.qty_alloc,0)),2) weight 
from sel_method sm, ordd od, ordm om, route r, pm, 
      sys_config sy, float_detail fd, float_detail fd2, floats f, loc l 
where fd.float_no = f.float_no 
and fd.qty_alloc > 0 
and pm.prod_id = fd.prod_id 
and pm.cust_pref_vendor = fd.cust_pref_vendor 
and l.logi_loc = fd.src_loc 
and r.route_no = f.route_no 
and om.order_id = fd.order_id 
and od.order_id = fd.order_id 
and od.order_line_id = fd.order_line_id 
and sm.method_id = r.method_id 
and sm.group_no = f.group_no 
and fd.merge_alloc_flag <> 'M' 
and fd.prod_id = fd2.prod_id(+) 
and fd.order_id = fd2.order_id(+) 
and fd.order_line_id = fd2.order_line_id(+) 
and fd2.merge_alloc_flag(+) = 'M' 
and sy.config_flag_name = 'START_FLOAT_CH'
/

