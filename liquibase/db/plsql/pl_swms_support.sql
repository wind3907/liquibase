CREATE OR REPLACE PACKAGE swms.pl_swms_support AS
-- Function to restore a route from the SWMS backup tables.  The second parameter is optional and defaults to SYSDATE.
FUNCTION restore_route_from_bckup (i_route_no IN VARCHAR2, i_curr_date IN DATE := SYSDATE) 
  RETURN DATE;

PROCEDURE restore_route (i_route_no IN VARCHAR2, i_curr_date IN DATE := SYSDATE);

-- Procedure to send a route to STS.  The second parameter is optional and defaults to SYSDATE.
PROCEDURE resend_sts_route (i_route_no IN VARCHAR2, i_curr_date IN DATE := SYSDATE);

END pl_swms_support;
/

CREATE OR REPLACE PACKAGE BODY swms.pl_swms_support AS

FUNCTION restore_route_from_bckup (i_route_no IN VARCHAR2, i_curr_date IN DATE) 
  RETURN DATE
AS
------------------------------------------------------------------------------------
--
--  FILE
--   restore_route_from_bckup.sql 
--
--  DESCRIPTION
--              This script restores a route's data from the SWMS backup tables
--              to the main tables.
--
--
--  PARAMETERS
--
--  AUTHOR
--
--    SYSCO Corporation
--
--  MODIFICATION HISTORY
--
--  Change Date  Developer  Description
--  -----------  ---------  -------------------------------------------------
--  10/29/2017   spin4795   Initial Release
--
------------------------------------------------------------------------------------
l_route_date DATE;
l_row_count NUMBER;

BEGIN
  dbms_output.enable(1000000);

  BEGIN
    SELECT DL_TIME
      INTO l_route_date
      FROM ROUTE_BCKUP
     WHERE ROUTE_NO = i_route_no
       AND DL_TIME > i_curr_date - 2;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbms_output.put_line('A recent route ' || i_route_no || ' was not found in backup tables.');
      RETURN(NULL);
  END;

  l_row_count := 0;

  INSERT INTO floats (batch_no,batch_seq,float_no,float_seq,route_no,b_stop_no,e_stop_no,
                      float_cube,group_no, merge_group_no,merge_seq_no,merge_loc,zone_id,
                      equip_id,comp_code,split_ind,pallet_pull,pallet_id,home_slot,drop_qty,
                      door_area,single_stop_flag ,status ,ship_date , parent_pallet_id,
                      fl_method_id,fl_sel_type,fl_opt_pull,truck_no,door_no,cw_collect_status,
                      cw_collect_user,fl_no_of_zones,fl_multi_no,fl_sel_lift_job_code,mx_priority)
  SELECT batch_no,batch_seq,float_no,float_seq,route_no,b_stop_no,e_stop_no,float_cube,group_no,
         merge_group_no,merge_seq_no,merge_loc,zone_id,equip_id,comp_code,split_ind,pallet_pull,
         pallet_id,home_slot,drop_qty,door_area,single_stop_flag,status,ship_date,parent_pallet_id,
         fl_method_id,fl_sel_type,fl_opt_pull,truck_no,door_no,cw_collect_status,cw_collect_user,
         fl_no_of_zones,fl_multi_no,fl_sel_lift_job_code,mx_priority
    FROM floats_bckup
   WHERE NOT EXISTS (SELECT 1 FROM floats
        	      WHERE float_no = floats_bckup.float_no)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO float_detail (float_no,seq_no,zone,stop_no,prod_id,src_loc,multi_home_seq,uom,
                            qty_order,qty_alloc,merge_alloc_flag,merge_loc,status,order_id,
                            order_line_id,cube,copy_no,merge_float_no,merge_seq_no,cust_pref_vendor,
                            clam_bed_trk,route_no, route_batch_no,alloc_time,rec_id,mfg_date,
                            exp_date,lot_id,carrier_id,order_seq,sos_status,cool_trk,catch_wt_trk,
                            item_seq,qty_short,st_piece_seq,selector_id,bc_st_piece_seq,short_item_seq) 
  SELECT float_no,seq_no,zone,stop_no,prod_id,src_loc,multi_home_seq,uom,qty_order,qty_alloc,
         merge_alloc_flag,merge_loc,status,order_id,order_line_id,cube,copy_no,merge_float_no,
         merge_seq_no,cust_pref_vendor,clam_bed_trk,route_no,route_batch_no,alloc_time,rec_id,
         mfg_date,exp_date,lot_id,carrier_id,order_seq,sos_status,cool_trk,catch_wt_trk,item_seq,
         qty_short,st_piece_seq,selector_id,bc_st_piece_seq,short_item_seq 
    FROM float_detail_bckup
   WHERE NOT EXISTS (SELECT 1 FROM float_detail
                      WHERE float_no = float_detail_bckup.float_no
                        AND seq_no = float_detail_bckup.seq_no)
     AND route_no = i_route_no;
  
  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO label_master (seq,batch_no,queue,print_group,print_flag)
  SELECT seq,batch_no,queue,print_group,print_flag 
    FROM label_master_bckup
   WHERE NOT EXISTS (SELECT 1 FROM label_master
                      WHERE seq = label_master_bckup.seq 
                        AND batch_no = label_master_bckup.batch_no
                        AND queue = label_master_bckup.queue
                        AND print_group = label_master_bckup.print_group
                        AND print_flag = label_master_bckup.print_flag)
     AND batch_no IN (SELECT batch_no FROM floats_bckup
                       WHERE route_no = i_route_no);
  
  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO route (route_no,seq_no,truck_no,sel_lock,route_batch_no,sch_time,dl_time,f_door,
                     c_door,d_door,method_id,stops,status,combine_pallet,freezer_fold,
                     cooler_fold,dry_fold,sts_status,add_on_route_seq,old_truck_no,mx_wave_number)
  SELECT route_no,seq_no,truck_no,sel_lock, route_batch_no,sch_time,dl_time,f_door,c_door,d_door,
         method_id,stops,status,combine_pallet,freezer_fold,cooler_fold,dry_fold,sts_status,
         add_on_route_seq,old_truck_no,mx_wave_number
    FROM route_bckup
   WHERE NOT EXISTS (SELECT 1 FROM route
                      WHERE route_no=route_bckup.route_no)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ordd (order_id,order_line_id,prod_id, cust_pref_vendor,lot_id,status,qty_ordered,
                    qty_shipped,uom,weight,partial,page,inck_key,seq,area,route_no,stop_no,
                    qty_alloc,zone_id,pallet_pull,sys_order_id,sys_order_line_id,wh_out_qty,
                    reason_cd,pk_adj_type,pk_adj_dt,user_id,cw_type,qa_ticket_ind,deleted,
                    pcl_flag,pcl_id,original_uom ,dod_cust_item_barcode,dod_fic)
  SELECT order_id,order_line_id,prod_id, cust_pref_vendor,lot_id,status,qty_ordered,qty_shipped,uom,
         weight,partial,page,inck_key,seq,area,route_no,stop_no,qty_alloc,zone_id,pallet_pull,
         sys_order_id,sys_order_line_id,wh_out_qty, reason_cd,pk_adj_type,pk_adj_dt,user_id,cw_type,
         qa_ticket_ind,deleted,pcl_flag,pcl_id,original_uom, dod_cust_item_barcode,dod_fic 
    FROM ordd_bckup
   WHERE NOT EXISTS (SELECT 1 FROM ordd
                      WHERE order_id = ordd_bckup.order_id
                        AND order_line_id = ordd_bckup.order_line_id)
     AND route_no = i_route_no;
 
  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ordm (order_id,route_no,stop_no,truck_no,trailer_no,priority,truck_type,ship_date,
                    status,cust_id,carr_id,wave_number,order_type,unitize_ind,cust_po,cust_name,
                    cust_contact, cust_addr1,cust_addr2,cust_addr3,cust_city,cust_state,cust_zip,
                    cust_cntry,ship_id,ship_name,ship_addr1,ship_addr2,ship_addr3,ship_city,
                    ship_state,ship_zip,ship_cntry,sales,grpm_id,grpm_seq,del_time,d_pieces,
                    c_pieces,f_pieces,weight,sys_order_id,sys_order_line_id,immediate_ind,
                    delivery_method, deleted,frz_special,clr_special,dry_special,old_stop_no,
                    dod_contract_no,cross_dock_type) 
  SELECT order_id,route_no,stop_no,truck_no,trailer_no,priority,truck_type,ship_date,status,cust_id,
         carr_id,wave_number ,order_type,unitize_ind,cust_po,cust_name,cust_contact,cust_addr1,
         cust_addr2,cust_addr3,cust_city,cust_state,cust_zip,cust_cntry,ship_id,ship_name,ship_addr1,
         ship_addr2,ship_addr3,ship_city,ship_state,ship_zip,ship_cntry,sales,grpm_id,grpm_seq,
         del_time,d_pieces,c_pieces,f_pieces,weight,sys_order_id,sys_order_line_id,immediate_ind,
         delivery_method, deleted,frz_special,clr_special,dry_special,old_stop_no,dod_contract_no,
         cross_dock_type
    FROM ordm_bckup
   WHERE NOT EXISTS (SELECT 1 FROM ordm
                      WHERE order_id = ordm_bckup.order_id)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ordcw (order_id,order_line_id,seq_no,prod_id,cust_pref_vendor,catch_weight,cw_type,uom,
                     add_date,add_user,upd_date,upd_user,cw_float_no,cw_scan_method,order_seq,
                     cw_kg_lb)
  SELECT order_id,order_line_id,seq_no,prod_id,cust_pref_vendor,catch_weight,cw_type,uom,add_date,
         add_user,upd_date,upd_user,cw_float_no,cw_scan_method,order_seq,cw_kg_lb
    FROM ordcw_bckup
   WHERE NOT EXISTS (SELECT 1 FROM ordcw
                      WHERE order_id = ordcw_bckup.order_id
                        AND order_line_id = ordcw_bckup.order_line_id
                        AND seq_no = ordcw_bckup.seq_no)
     AND order_id IN (SELECT order_id FROM ordm_bckup
                       WHERE route_no = i_route_no);

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ordmc (order_id,cmt_line_id,cmt) 
  SELECT order_id,cmt_line_id,cmt 
    FROM ordmc_bckup a
   WHERE NOT EXISTS (SELECT 1 FROM ordmc b
                      WHERE a.order_id = b.order_id
                        AND a.cmt_line_id = b.cmt_line_id)
     AND order_id IN (SELECT order_id FROM ordm_bckup
                       WHERE route_no = i_route_no);
  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ORDDC (order_id,order_line_id,cmt_line_id,cmt)
  SELECT order_id,order_line_id,cmt_line_id,cmt 
    FROM orddc_bckup
   WHERE NOT EXISTS (SELECT 1 FROM ORDDC
                      WHERE order_id = orddc_bckup.order_id
                        AND order_line_id = orddc_bckup.order_line_id
                        AND cmt_line_id = orddc_bckup.cmt_line_id)
     AND order_id IN (SELECT order_id FROM ordm_bckup
                       WHERE route_no = i_route_no);

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ord_cool (order_id,order_line_id,seq_no,prod_id,cust_pref_vendor,country_of_origin,wild_farm,
                        add_date,add_user,upd_date,upd_user) 
  SELECT order_id,order_line_id,seq_no, prod_id,cust_pref_vendor, country_of_origin, wild_farm,add_date,
         add_user,upd_date,upd_user 
    FROM ord_cool_bckup
   WHERE NOT EXISTS (SELECT 1 FROM ord_cool
                      WHERE order_id = ord_cool_bckup.order_id
                        AND order_line_id = ord_cool_bckup.order_line_id
                        AND seq_no = ord_cool_bckup.seq_no)
     AND order_id IN (SELECT order_id FROM ordm_bckup
                       WHERE route_no = i_route_no);

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO ordcb (order_id,order_line_id,seq_no,prod_id,cust_pref_vendor,clam_bed_no,harvest_date,
                     add_date,add_user,upd_date,upd_user,order_seq)
  SELECT order_id,order_line_id,seq_no,prod_id,cust_pref_vendor,clam_bed_no,harvest_date,add_date,
         add_user,upd_date,upd_user,order_seq
    FROM ordcb_bckup
   WHERE order_id IN (SELECT order_id FROM ordm_bckup
                       WHERE route_no = i_route_no);

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO sos_batch (batch_no,job_code,batch_date,status,route_no,truck_no,no_of_floats,no_of_stops,
                         no_of_cases,no_of_splits,no_of_merges,no_of_fdtls,no_of_fdqty,no_of_items,
                         no_of_aisles,no_of_zones,no_of_locns,is_unitized,is_optimum,prt_box_conts,
                         ship_date ,batch_cube,picked_by,picked_time,reserved_by,reassigned_by,
                         last_pik_loc,orig_batch_no,start_time,end_time,area,reserved_to,pooled_by,
                         door_no ,route_batch_no,add_date,add_user,upd_date,upd_user,priority)
  SELECT batch_no,job_code,batch_date,status,route_no,truck_no,no_of_floats,no_of_stops,no_of_cases,
         no_of_splits,no_of_merges,no_of_fdtls,no_of_fdqty,no_of_items,no_of_aisles,no_of_zones,no_of_locns,
         is_unitized,is_optimum,prt_box_conts,ship_date ,batch_cube,picked_by,picked_time,reserved_by,
         reassigned_by,last_pik_loc,orig_batch_no,start_time,end_time,area,reserved_to,pooled_by,door_no,
         route_batch_no,add_date,add_user,upd_date,upd_user,priority
    FROM sos_batch_bckup
   WHERE NOT EXISTS (SELECT 1 FROM sos_batch
                      WHERE batch_no = sos_batch_bckup.batch_no)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO dod_label_header (route_no,order_id,stop_no,truck_no,ship_date,status,cust_id,cust_name,
                                dod_contract_no,add_date,add_user,print_user,print_flag,print_date)
  SELECT route_no,order_id,stop_no,truck_no,ship_date,status,cust_id,cust_name,dod_contract_no,
         add_date,add_user,print_user,print_flag,print_date
    FROM dod_label_header_bckup
   WHERE NOT EXISTS (SELECT 1 FROM dod_label_header
                      WHERE order_id=dod_label_header_bckup.order_id)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO dod_label_detail (order_id,order_line_id,prod_id,route_no,src_loc,qty_alloc,
              pallet_id,batch_no,max_case_seq,start_seq,end_seq,pack_date,exp_date,lot_id,
              dod_cust_item_barcode,dod_fic,add_user,add_date,upd_user,upd_date)
  SELECT order_id,order_line_id,prod_id,route_no,src_loc,qty_alloc,
         pallet_id,batch_no,max_case_seq,start_seq,end_seq,pack_date,exp_date,lot_id,
         dod_cust_item_barcode,dod_fic,add_user,add_date,upd_user,upd_date
    FROM dod_label_detail_bckup
   WHERE NOT EXISTS (SELECT 1 FROM dod_label_detail
                      WHERE order_id=dod_label_detail_bckup.order_id
                        AND order_line_id=dod_label_detail_bckup.order_line_id)
     AND route_no = i_route_no;

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  INSERT INTO las_truck (truck, trailer, trailer_type, dry_status, cooler_status,
              freezer_status, loader, start_time, complete_time, last_pallet,
              dry_pallets, dry_cases, dry_stops, dry_cube, dry_remaining, dry_stackheight,
              cooler_pallets, cooler_cases, cooler_stops, cooler_cube, cooler_remaining,
              cooler_stackheight, freezer_pallets, freezer_cases, freezer_stops,
              freezer_cube, freezer_remaining, freezer_stackheight, note1, note2, note3,
              route_no, truck_status, dry_complete_time, dry_complete_user,
              cooler_complete_time, cooler_complete_user, freezer_complete_time,
              freezer_complete_user, complete_user)
  SELECT truck, trailer, trailer_type, dry_status, cooler_status,
         freezer_status, loader, start_time, complete_time, last_pallet,
         dry_pallets, dry_cases, dry_stops, dry_cube, dry_remaining, dry_stackheight,
         cooler_pallets, cooler_cases, cooler_stops, cooler_cube, cooler_remaining,
         cooler_stackheight, freezer_pallets, freezer_cases, freezer_stops,
         freezer_cube, freezer_remaining, freezer_stackheight, note1, note2, note3,
         route_no, truck_status, dry_complete_time, dry_complete_user,
         cooler_complete_time, cooler_complete_user, freezer_complete_time,
         freezer_complete_user, complete_user
    FROM las_truck_bckup
   WHERE NOT EXISTS (SELECT 1 FROM las_truck
                      WHERE truck=las_truck_bckup.truck)
     AND truck = (select truck_no FROM route WHERE route_no = i_route_no);

  l_row_count := l_row_count + SQL%ROWCOUNT;  
  COMMIT;

  dbms_output.put_line(TO_CHAR(l_row_count) || ' records restored from backup tables for route ' || i_route_no || '.');

  RETURN(l_route_date);
END restore_route_from_bckup;


PROCEDURE restore_route (i_route_no IN VARCHAR2, i_curr_date IN DATE) AS
  l_route_date DATE;
BEGIN
  l_route_date := pl_swms_support.restore_route_from_bckup(i_route_no, i_curr_date);
END restore_route;


PROCEDURE resend_sts_route (i_route_no IN VARCHAR2, i_curr_date IN DATE) AS
  l_route_date    DATE;
  l_sts_status    ROUTE.STS_STATUS%TYPE;
  l_manifest_no   MANIFESTS.MANIFEST_NO%TYPE;
  l_row_count     NUMBER;
BEGIN
  dbms_output.enable(1000000);

-- Check for an open manifest less than two days old.
  SELECT COUNT(*)
    INTO l_row_count
    FROM MANIFESTS
   WHERE ROUTE_NO = i_route_no
     AND MANIFEST_STATUS = 'OPN'
     AND MANIFEST_CREATE_DT > i_curr_date - 2;
  IF l_row_count = 0 THEN
-- If no open manifest, we have a problem; either the manifest is already closed or the manifest was not sent by SUS/IDS/AX.
    BEGIN
      SELECT MANIFEST_NO
        INTO l_manifest_no
        FROM MANIFESTS
       WHERE ROUTE_NO = i_route_no
         AND MANIFEST_STATUS = 'CLS'
         AND MANIFEST_CREATE_DT > i_curr_date - 2;

      dbms_output.put_line('Manifest ' || l_manifest_no ||' is already closed for route ' || i_route_no || '.');
      RETURN;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN									
        dbms_output.put_line('No manifest found for route ' || i_route_no || '.  Notify SUS-OP of missing manifest.');
        RETURN;
    END;
  END IF;

-- Check for route in the route table.  If not there, restore it from the route backup tables.
  BEGIN
    SELECT DL_TIME
      INTO l_route_date
      FROM ROUTE
     WHERE ROUTE_NO = i_route_no
       AND DL_TIME > i_curr_date - 2;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_route_date := pl_swms_support.restore_route_from_bckup(i_route_no, i_curr_date);
      IF l_route_date IS NULL THEN
        RETURN;
      END IF;
  END;

-- Remove any records for the route from the STS staging table.
--  SELECT STS_STATUS
--    INTO l_sts_status
--    FROM ROUTE
--   WHERE ROUTE_NO = i_route_no
--     AND DL_TIME = l_route_date;

-- IF l_sts_status IN ('P','B') THEN
    DELETE FROM STS_ROUTE_OUT
     WHERE ROUTE_NO = i_route_no
       AND ROUTE_DATE = TRUNC(l_route_date+.5);

    dbms_output.put_line(TO_CHAR(SQL%ROWCOUNT) || ' rows deleted from the STS_ROUTE_OUT table for route ' || i_route_no || '.' );
    COMMIT;
--  END IF;    

-- Re-send the route's data to the STS staging table.
  dbms_output.put_line ('Retrying route ' || i_route_no || ' from ' || TO_CHAR(TRUNC(l_route_date+.5),'DD-MON-YY'));
  pl_sts_interfaces_new.snd_sts_route_details(i_route_no, TRUNC(l_route_date+.5));

-- Display the route's new record count in the STS_ROUTE_OUT table.
  SELECT COUNT(*) INTO l_row_count
    FROM STS_ROUTE_OUT
     WHERE ROUTE_NO = i_route_no
       AND ROUTE_DATE = TRUNC(l_route_date+.5);
  dbms_output.put_line(TO_CHAR(l_row_count) || ' rows added to the STS_ROUTE_OUT table for route ' || i_route_no || '.' );
  
END resend_sts_route;

END pl_swms_support;
/

CREATE OR REPLACE PUBLIC SYNONYM PL_SWMS_SUPPORT FOR SWMS.PL_SWMS_SUPPORT;
GRANT EXECUTE ON SWMS.PL_SWMS_SUPPORT TO SWMS_VIEWER;
GRANT EXECUTE ON SWMS.PL_SWMS_SUPPORT TO SWMS_USER;
