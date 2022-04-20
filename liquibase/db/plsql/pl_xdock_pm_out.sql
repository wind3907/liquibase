CREATE OR REPLACE PACKAGE SWMS.pl_xdock_pm_out IS
  /*===========================================================================================================
  -- Package
  -- pl_xdock_pm_out
  --
  -- Description
  --  This package processes the data from the MQ queue of SUS IM and sends to sus_im_in table.
  --
  -- Modification History
  --
  -- Date              User       Version         Comment
  -- 05/17/21        pdas8114        1.0          OPCOF - 3385 Interface from SWMS (site1) to SWMS (site2) for X-dock Product Attributes        
  ============================================================================================================*/

  PROCEDURE process_xdock_pm_out( i_route_batch_no IN VARCHAR2);
  PROCEDURE process_xdock_manifest_pm(i_manifest_no IN VARCHAR2);

END pl_xdock_pm_out;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_xdock_pm_out IS
  /*===========================================================================================================
  -- Package Body
  -- pl_xdock_pm_out
  --
  -- Description
  --  This package processes the data from the MQ queue of SUS Item and sends to sus_im_in table.
  --
  -- Modification History
  --
  -- Date                User                  Version      Defect   Comment
  -- 09/26/17           pdas8114       			 1.0                  OPCOF - 3385 Interface from SWMS (site1) to SWMS (site2) for X-dock Product Attributes 
  ============================================================================================================*/

  This_Package        CONSTANT  VARCHAR2(30 CHAR) := $$PLSQL_UNIT;
  This_Application    CONSTANT  VARCHAR2(30 CHAR) := 'MAINTENANCE';
  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);
 

  PROCEDURE process_xdock_pm_out( i_route_batch_no IN VARCHAR2 
                        ) IS
    /*===========================================================================================================
    -- PROCEDURE
    -- process_xdock_pm_out
    --
    -- Description
    --   This Procedure populated xdock_pm_out staging table 
    --
    -- Modification History
    --
    -- Date                User                  Version       Defect   Comment
    -- 09/26/17           pdas8114                1.0                   Initial Creation
	-- 09/09/21           pdas8114                1.1                   Added missing columns from pm
    ============================================================================================================*/
    --------------------------local variables-----------------------------
    process_error             EXCEPTION;
	bad_msg_hub_response      EXCEPTION;
    l_sequence_number         NUMBER;
	l_batch_id                VARCHAR2(14);
	l_site_from               VARCHAR2(5);
    l_site_to                 VARCHAR2(5);
	l_prod_exists             NUMBER;
	l_record_status           VARCHAR2(1);
	l_get_syspar              VARCHAR2(1) := UPPER( PL_Common.F_Get_SysPar( 'ENABLE_OPCO_TO_OPCO_XDOCK', 'N' ));
	l_msg_hub_response        PLS_INTEGER;
	This_Function          CONSTANT  VARCHAR2(30 CHAR) := UPPER( 'process_xdock_pm_out' );

    CURSOR c_pm_out IS                 
       SELECT max(om.order_id) order_id, om.route_no, om.site_from, om.site_to, om.delivery_document_id, od.prod_id, od.cust_pref_vendor,
		 pm.type, pm.container, pm.vendor_id, pm.mfg_sku, pm.descrip, pm.lot_trk, pm.weight, pm.g_weight, pm.status, pm.hazardous, pm.abc, 
		 pm.master_case, pm.category, pm.replace, pm.replace_ind, pm.buyer, pm.pack, pm.prod_size, pm.brand, pm.catch_wt_trk, pm.split_trk,
		 pm.exp_date_trk, pm.temp_trk, pm.repack_trk,pm.mfg_date_trk,pm.stackable, pm.master_sku, pm.master_qty, pm.repack_day, pm.repack_len,
		 pm.repack_ind, pm.repack_qty, pm.repack_sec, pm.spc, pm.ti, pm.mf_ti, pm.hi, pm.mf_hi, pm.pallet_type, pm.area, pm.stage, pm.case_cube,
		 pm.split_cube, pm.zone_id, pm.avg_wt, pm.case_pallet, pm.awm, pm.max_temp, pm.min_temp, pm.pick_freq, pm.last_rec_date,pm.last_shp_date,  
		 pm.pallet_stack, pm.max_slot, pm.max_slot_per, pm.fifo_trk, pm.last_ship_slot, pm.instruction, pm.min_qty, pm.item_cost, pm.mfr_shelf_life,
		 pm.sysco_shelf_life, pm.cust_shelf_life, maint_flag, pm.perm_item, pm.internal_upc, pm.external_upc, pm.cubitron, pm.dmd_status, pm.auto_ship_flag, 
		 pm.case_type, pm.stock_type, pm.case_height, pm.case_length, pm.case_width, pm.ims_status, pm.split_length, pm.split_width, pm.split_height, pm.max_qty, 
		 pm.rdc_vendor_id, pm.rdc_effective_date, pm.mf_sw_ti,pm.split_type, pm.miniload_storage_ind, pm.case_qty_per_carrier, pm.case_qty_for_split_rpl,pm.split_zone_id, 	   
		 pm.high_risk_flag, pm.max_miniload_case_carriers, pm.prod_size_unit, pm.buying_multiple, pm.max_dso, pm.mx_max_case, pm.mx_min_case, pm.mx_eligible,
		 pm.mx_item_assign_flag, pm.mx_stability_calc, pm.mx_stability_flag, pm.mx_food_type, pm.mx_upc_present_flag, pm.mx_master_case_flag, pm.mx_package_type, 
		 pm.mx_why_not_eligible, pm.mx_hazardous_type, pm.mx_stability_recalc, pm.mx_multi_upc_problem, pm.mx_designate_slot, pm.wsh_begin_date, pm.wsh_avg_invs,
		 pm.wsh_ship_movements, pm.wsh_hits,           pm.expected_case_on_po, pm.diagonal_measurement, pm.recalc_length, pm.recalc_width, pm.recalc_height,                  
		 pm.default_weight_unit, pm.wsh_begin_date_range, pm.mx_rotation_rules, pm.mx_throttle_flag,   pm.hist_case_order, pm.hist_case_date,        
		 pm.hist_split_order, pm.hist_split_date, pm.gs1_barcode_flag, pm.finish_good_ind,pm.read_only_flag
         from ordm om, ordd od, pm 
         where om.order_id = od.order_id
         and od.prod_id = pm.prod_id
         and od.cust_pref_vendor = od.cust_pref_vendor
         and om.cross_dock_type = 'S'
         and om.route_no in (select route_no from route where route_batch_no  = i_route_batch_no)
         group by om.route_no, om.site_from, om.site_to, om.delivery_document_id, od.prod_id, od.cust_pref_vendor,
		 pm.type, pm.container, pm.vendor_id, pm.mfg_sku, pm.descrip, pm.lot_trk, pm.weight, pm.g_weight, pm.status, pm.hazardous, pm.abc, 
		 pm.master_case, pm.category, pm.replace, pm.replace_ind, pm.buyer, pm.pack, pm.prod_size, pm.brand, pm.catch_wt_trk, pm.split_trk,
		 pm.exp_date_trk, pm.temp_trk, pm.repack_trk,pm.mfg_date_trk,pm.stackable, pm.master_sku, pm.master_qty, pm.repack_day, pm.repack_len,
		 pm.repack_ind, pm.repack_qty, pm.repack_sec, pm.spc, pm.ti, pm.mf_ti, pm.hi, pm.mf_hi, pm.pallet_type, pm.area, pm.stage, pm.case_cube,
		 pm.split_cube, pm.zone_id, pm.avg_wt, pm.case_pallet, pm.awm, pm.max_temp, pm.min_temp, pm.pick_freq, pm.last_rec_date,pm.last_shp_date,  
		 pm.pallet_stack, pm.max_slot, pm.max_slot_per, pm.fifo_trk, pm.last_ship_slot, pm.instruction, pm.min_qty, pm.item_cost, pm.mfr_shelf_life,
		 pm.sysco_shelf_life, pm.cust_shelf_life, maint_flag, pm.perm_item, pm.internal_upc, pm.external_upc, pm.cubitron, pm.dmd_status, pm.auto_ship_flag, 
		 pm.case_type, pm.stock_type, pm.case_height, pm.case_length, pm.case_width, pm.ims_status, pm.split_length, pm.split_width, pm.split_height, pm.max_qty, 
		 pm.rdc_vendor_id, pm.rdc_effective_date, pm.mf_sw_ti,pm.split_type, pm.miniload_storage_ind, pm.case_qty_per_carrier, pm.case_qty_for_split_rpl,pm.split_zone_id, 	   
		 pm.high_risk_flag, pm.max_miniload_case_carriers, pm.prod_size_unit, pm.buying_multiple, pm.max_dso, pm.mx_max_case, pm.mx_min_case, pm.mx_eligible,
		 pm.mx_item_assign_flag, pm.mx_stability_calc, pm.mx_stability_flag, pm.mx_food_type, pm.mx_upc_present_flag, pm.mx_master_case_flag, pm.mx_package_type, 
		 pm.mx_why_not_eligible, pm.mx_hazardous_type, pm.mx_stability_recalc, pm.mx_multi_upc_problem, pm.mx_designate_slot, pm.wsh_begin_date, pm.wsh_avg_invs,
		 pm.wsh_ship_movements, pm.wsh_hits,           pm.expected_case_on_po, pm.diagonal_measurement, pm.recalc_length, pm.recalc_width, pm.recalc_height,                  
		 pm.default_weight_unit, pm.wsh_begin_date_range, pm.mx_rotation_rules, pm.mx_throttle_flag,   pm.hist_case_order, pm.hist_case_date,        
		 pm.hist_split_order, pm.hist_split_date, pm.gs1_barcode_flag, pm.finish_good_ind,pm.read_only_flag  ;
 BEGIN
    /* process only if ENABLE_OPCO_TO_OPCO_XDOCK is set to Y*/
    IF l_get_syspar = 'Y' THEN
	   
	 BEGIN
      SELECT pl_xdock_common.get_batch_id
       INTO l_batch_id
      FROM dual;
     EXCEPTION
     WHEN OTHERS THEN
      PL_Log.Ins_Msg(pl_log.ct_fatal_msg, This_Function, 'Failed to get batch_id from pl_xdock_common.get_batch_id', SQLCODE, SUBSTR(SQLERRM, 1, 500), This_Application, This_Package);
     END;

	 PL_Log.Ins_Msg( pl_log.ct_info_msg, This_Function, 'Begin process_xdock_pm_out for route_batch_no:' || i_route_batch_no, '', '', This_Application, This_Package);
  
      FOR pm_out_rec IN c_pm_out LOOP
        BEGIN	  
		  BEGIN
		  SELECT 1 
		  INTO l_prod_exists
		  FROM xdock_pm_out 
		  WHERE prod_id||site_from||site_to = pm_out_rec.prod_id||pm_out_rec.site_from||pm_out_rec.site_to;
		  EXCEPTION
		    WHEN OTHERS THEN
		    l_prod_exists := NULL;
		  END;

		 IF l_prod_exists = 1 THEN
		    l_record_status := 'X';
		  ELSE
		    l_record_status := 'N';
		  END IF;
		  
		  l_sequence_number := xdock_seqno_seq.nextval;
	 
      INSERT INTO XDOCK_PM_OUT
			(sequence_number, batch_id, record_status, route_batch_no, route_no, site_from, site_to, 
			 order_id, delivery_document_id, prod_id,  cust_pref_vendor, 
			 type, container, vendor_id, mfg_sku, descrip, lot_trk, weight, g_weight, status, hazardous, abc, 
		     master_case, category, replace, replace_ind, buyer, pack, prod_size, brand, catch_wt_trk, split_trk,
		     exp_date_trk, temp_trk, repack_trk,mfg_date_trk,stackable, master_sku, master_qty, repack_day, repack_len,
		     repack_ind, repack_qty, repack_sec, spc, ti, mf_ti, hi, mf_hi, pallet_type, area, stage, case_cube,
		     split_cube, zone_id, avg_wt, case_pallet, awm, max_temp, min_temp, pick_freq, last_rec_date,last_shp_date,  
		     pallet_stack, max_slot, max_slot_per, fifo_trk, last_ship_slot, instruction, min_qty, item_cost, mfr_shelf_life,
		     sysco_shelf_life, cust_shelf_life, maint_flag, perm_item, internal_upc, external_upc, cubitron, dmd_status, auto_ship_flag, 
		     case_type, stock_type, case_height, case_length, case_width, ims_status, split_length, split_width, split_height, max_qty, 
		     rdc_vendor_id, rdc_effective_date, mf_sw_ti,split_type, miniload_storage_ind, case_qty_per_carrier, case_qty_for_split_rpl,split_zone_id, 	   
		     high_risk_flag, max_miniload_case_carriers, prod_size_unit, buying_multiple, max_dso, mx_max_case, mx_min_case, mx_eligible,
		     mx_item_assign_flag, mx_stability_calc, mx_stability_flag, mx_food_type, mx_upc_present_flag, mx_master_case_flag, mx_package_type, 
		     mx_why_not_eligible, mx_hazardous_type, mx_stability_recalc, mx_multi_upc_problem, mx_designate_slot, wsh_begin_date, wsh_avg_invs,
		     wsh_ship_movements, wsh_hits,           expected_case_on_po, diagonal_measurement, recalc_length, recalc_width, recalc_height,                  
		     default_weight_unit, wsh_begin_date_range, mx_rotation_rules, mx_throttle_flag,   hist_case_order, hist_case_date,        
		     hist_split_order, hist_split_date, gs1_barcode_flag, finish_good_ind,read_only_flag)
		  VALUES 
		    (l_sequence_number,        l_batch_id,           		    l_record_status,              i_route_batch_no,                  pm_out_rec.route_no,             pm_out_rec.site_from,            pm_out_rec.site_to,     
			 pm_out_rec.order_id,      pm_out_rec.delivery_document_id,  pm_out_rec.prod_id, 	      pm_out_rec.cust_pref_vendor,       pm_out_rec.type,    		      pm_out_rec.container, 	       pm_out_rec.vendor_id, 
			 pm_out_rec.mfg_sku,       pm_out_rec.descrip,               pm_out_rec.lot_trk,          pm_out_rec.weight,                 pm_out_rec.g_weight, 		      pm_out_rec.status,   		       pm_out_rec.hazardous, 
			 pm_out_rec.abc,           pm_out_rec.master_case,           pm_out_rec.category,         pm_out_rec.replace,                pm_out_rec.replace_ind, 	      pm_out_rec.buyer, 		       pm_out_rec.pack, 
			 pm_out_rec.prod_size,     pm_out_rec.brand,                 pm_out_rec.catch_wt_trk,     pm_out_rec.split_trk,              pm_out_rec.exp_date_trk,         pm_out_rec.temp_trk, 		       pm_out_rec.repack_trk,
			 pm_out_rec.mfg_date_trk,  pm_out_rec.stackable,             pm_out_rec.master_sku,       pm_out_rec.master_qty,             pm_out_rec.repack_day, 	      pm_out_rec.repack_len, 	       pm_out_rec.repack_ind,    
			 pm_out_rec.repack_qty,    pm_out_rec.repack_sec,            pm_out_rec.spc,              pm_out_rec.ti,                     pm_out_rec.mf_ti,      	      pm_out_rec.hi,         	       pm_out_rec.mf_hi, 
			 pm_out_rec.pallet_type,   pm_out_rec.area,                  pm_out_rec.stage,            pm_out_rec.case_cube,              pm_out_rec.split_cube, 	      pm_out_rec.zone_id,    	       pm_out_rec.avg_wt,    
			 pm_out_rec.case_pallet,   pm_out_rec.awm,                   pm_out_rec.max_temp,         pm_out_rec.min_temp,               pm_out_rec.pick_freq,  	      pm_out_rec.last_rec_date,	       pm_out_rec.last_shp_date,  
			 pm_out_rec.pallet_stack,  pm_out_rec.max_slot,              pm_out_rec.max_slot_per,     pm_out_rec.fifo_trk,               pm_out_rec.last_ship_slot,       pm_out_rec.instruction, 	       pm_out_rec.min_qty, 
			 pm_out_rec.item_cost,     pm_out_rec.mfr_shelf_life,        pm_out_rec.sysco_shelf_life, pm_out_rec.cust_shelf_life,        pm_out_rec.maint_flag,           pm_out_rec.perm_item,    	       pm_out_rec.internal_upc, 
			 pm_out_rec.external_upc,  pm_out_rec.cubitron, 		     pm_out_rec.dmd_status, 	  pm_out_rec.auto_ship_flag,  	     pm_out_rec.case_type,            pm_out_rec.stock_type,           pm_out_rec.case_height,
			 pm_out_rec.case_length,   pm_out_rec.case_width,  			 pm_out_rec.ims_status,       pm_out_rec.split_length,           pm_out_rec.split_width,          pm_out_rec.split_height, 	       pm_out_rec.max_qty, 
			 pm_out_rec.rdc_vendor_id, pm_out_rec.rdc_effective_date,    pm_out_rec.mf_sw_ti,         pm_out_rec.split_type,             pm_out_rec.miniload_storage_ind, pm_out_rec.case_qty_per_carrier, pm_out_rec.case_qty_for_split_rpl,
			 pm_out_rec.split_zone_id, pm_out_rec.high_risk_flag,        pm_out_rec.max_miniload_case_carriers,                          pm_out_rec.prod_size_unit,       pm_out_rec.buying_multiple,      pm_out_rec.max_dso, 
			 pm_out_rec.mx_max_case,   pm_out_rec.mx_min_case,           pm_out_rec.mx_eligible,             pm_out_rec.mx_item_assign_flag, pm_out_rec.mx_stability_calc,  pm_out_rec.mx_stability_flag,  pm_out_rec.mx_food_type, 
			 pm_out_rec.mx_upc_present_flag,  pm_out_rec.mx_master_case_flag,  pm_out_rec.mx_package_type,   pm_out_rec.mx_why_not_eligible, pm_out_rec.mx_hazardous_type,  pm_out_rec.mx_stability_recalc, 
			 pm_out_rec.mx_multi_upc_problem, pm_out_rec.mx_designate_slot,    pm_out_rec.wsh_begin_date,    pm_out_rec.wsh_avg_invs,        pm_out_rec.wsh_ship_movements, pm_out_rec.wsh_hits,           
			 pm_out_rec.expected_case_on_po,  pm_out_rec.diagonal_measurement, pm_out_rec.recalc_length,     pm_out_rec.recalc_width,        pm_out_rec.recalc_height,                  
			 pm_out_rec.default_weight_unit,  pm_out_rec.wsh_begin_date_range, pm_out_rec.mx_rotation_rules, pm_out_rec.mx_throttle_flag,    pm_out_rec.hist_case_order, pm_out_rec.hist_case_date,        
			 pm_out_rec.hist_split_order,     pm_out_rec.hist_split_date,      pm_out_rec.gs1_barcode_flag,  pm_out_rec.finish_good_ind, 'Y');
			 
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Error: Inserting the data into XDOCK_PM_OUT ';
            l_error_code:= SUBSTR(SQLERRM,1,100);
            PL_Log.Ins_Msg( pl_log.ct_fatal_msg, This_Function, l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package);
            RAISE process_error;
        END;		
		
		l_site_from := pm_out_rec.site_from;
		l_site_to := pm_out_rec.site_to;
	    
	   END LOOP;
	    COMMIT;
	   -- S4R- Jira 3688, dont need to call for null values/xdock X type
	   IF l_site_from IS NOT NULL THEN
		l_msg_hub_response := PL_MSG_HUB_UTLITY.insert_meta_header(l_batch_id, 'XDOCK_PM_OUT' , l_site_from, l_site_to);
	
		IF l_msg_hub_response != 0 THEN
		 RAISE bad_msg_hub_response;
		END IF;
	  END IF;
    COMMIT;
    END IF;
  EXCEPTION
    WHEN bad_msg_hub_response THEN
	  l_error_msg := 'Failed to notify PL_MSG_HUB_UTLITY, Response Code: ';
	  l_error_code:= SQLCODE;
      pl_log.ins_msg( pl_log.ct_fatal_msg, 'process_xdock_pm_out', l_error_msg || l_msg_hub_response, SQLCODE, SQLERRM, This_Application, This_Package);
	  
	  UPDATE xdock_pm_out
         SET record_status   = 'F'
           , error_msg       = l_error_msg
           , error_code      = l_error_code
       WHERE sequence_number = l_sequence_number;
      COMMIT;	  
    WHEN process_error THEN
      l_error_msg := 'error in processing sequence no: '||l_sequence_number||'route batch no: ' ||i_route_batch_no;
      l_error_code:= SUBSTR(SQLERRM,1,100);
      pl_log.ins_msg( pl_log.ct_fatal_msg, 'process_xdock_pm_out', l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package);
    WHEN OTHERS THEN
      l_error_msg:= SUBSTR(SQLERRM,1,100);
      l_error_code:= SQLCODE;
      pl_log.ins_msg( pl_log.ct_fatal_msg, 'process_xdock_pm_out', l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package );
  END process_xdock_pm_out;
  
  PROCEDURE process_xdock_manifest_pm( i_manifest_no IN VARCHAR2 
                        ) IS
    /*===========================================================================================================
    -- PROCEDURE
    -- process_xdock_manifest_pm
    --
    -- Description
    --   This Procedure populated xdock_pm_out staging table from xdock_manifest_dtls_out for P rec type
    --
    -- Modification History
    --
    -- Date                User                  Version       Defect   Comment
    -- 07-Oct-2021         pdas8114               1.0                    Jira# 3702 Site 2 Pickup request is not showing on STS
	--                                                                    added procedure to load prod details to xdock_pm_out for P record

    ============================================================================================================*/
    --------------------------local variables-----------------------------
    process_error             EXCEPTION;
	bad_msg_hub_response      EXCEPTION;
    l_sequence_number         NUMBER;
	l_batch_id                VARCHAR2(14);
	l_site_from               VARCHAR2(5);
    l_site_to                 VARCHAR2(5);
	l_prod_exists             NUMBER;
	l_record_status           VARCHAR2(1);
	l_get_syspar              VARCHAR2(1) := UPPER( PL_Common.F_Get_SysPar( 'ENABLE_OPCO_TO_OPCO_XDOCK', 'N' ));
	l_msg_hub_response        PLS_INTEGER;
	This_Function          CONSTANT  VARCHAR2(30 CHAR) := UPPER( 'process_xdock_manifest_pm' );

    CURSOR c_pm_out IS                 
 		SELECT xmd.route_no, xmd.site_from, xmd.site_to, xmd.delivery_document_id, xmd.prod_id, xmd.cust_pref_vendor,
         pm.type, pm.container, pm.vendor_id, pm.mfg_sku, pm.descrip, pm.lot_trk, pm.weight, pm.g_weight, pm.status, pm.hazardous, pm.abc, 
         pm.master_case, pm.category, pm.replace, pm.replace_ind, pm.buyer, pm.pack, pm.prod_size, pm.brand, pm.catch_wt_trk, pm.split_trk,
         pm.exp_date_trk, pm.temp_trk, pm.repack_trk,pm.mfg_date_trk,pm.stackable, pm.master_sku, pm.master_qty, pm.repack_day, pm.repack_len,
         pm.repack_ind, pm.repack_qty, pm.repack_sec, pm.spc, pm.ti, pm.mf_ti, pm.hi, pm.mf_hi, pm.pallet_type, pm.area, pm.stage, pm.case_cube,
         pm.split_cube, pm.zone_id, pm.avg_wt, pm.case_pallet, pm.awm, pm.max_temp, pm.min_temp, pm.pick_freq, pm.last_rec_date,pm.last_shp_date,  
         pm.pallet_stack, pm.max_slot, pm.max_slot_per, pm.fifo_trk, pm.last_ship_slot, pm.instruction, pm.min_qty, pm.item_cost, pm.mfr_shelf_life,
         pm.sysco_shelf_life, pm.cust_shelf_life, maint_flag, pm.perm_item, pm.internal_upc, pm.external_upc, pm.cubitron, pm.dmd_status, pm.auto_ship_flag, 
         pm.case_type, pm.stock_type, pm.case_height, pm.case_length, pm.case_width, pm.ims_status, pm.split_length, pm.split_width, pm.split_height, pm.max_qty, 
         pm.rdc_vendor_id, pm.rdc_effective_date, pm.mf_sw_ti,pm.split_type, pm.miniload_storage_ind, pm.case_qty_per_carrier, pm.case_qty_for_split_rpl,pm.split_zone_id,        
         pm.high_risk_flag, pm.max_miniload_case_carriers, pm.prod_size_unit, pm.buying_multiple, pm.max_dso, pm.mx_max_case, pm.mx_min_case, pm.mx_eligible,
         pm.mx_item_assign_flag, pm.mx_stability_calc, pm.mx_stability_flag, pm.mx_food_type, pm.mx_upc_present_flag, pm.mx_master_case_flag, pm.mx_package_type, 
         pm.mx_why_not_eligible, pm.mx_hazardous_type, pm.mx_stability_recalc, pm.mx_multi_upc_problem, pm.mx_designate_slot, pm.wsh_begin_date, pm.wsh_avg_invs,
         pm.wsh_ship_movements, pm.wsh_hits,           pm.expected_case_on_po, pm.diagonal_measurement, pm.recalc_length, pm.recalc_width, pm.recalc_height,                  
         pm.default_weight_unit, pm.wsh_begin_date_range, pm.mx_rotation_rules, pm.mx_throttle_flag,   pm.hist_case_order, pm.hist_case_date,        
         pm.hist_split_order, pm.hist_split_date, pm.gs1_barcode_flag, pm.finish_good_ind,pm.read_only_flag
         from xdock_manifest_dtls_out xmd, pm 
         where xmd.prod_id = pm.prod_id
         and xmd.cust_pref_vendor = pm.cust_pref_vendor
         and xmd.manifest_no = i_manifest_no
         And xmd.rec_type = 'P'
         group by xmd.route_no, xmd.site_from, xmd.site_to, xmd.delivery_document_id, xmd.prod_id, xmd.cust_pref_vendor,
         pm.type, pm.container, pm.vendor_id, pm.mfg_sku, pm.descrip, pm.lot_trk, pm.weight, pm.g_weight, pm.status, pm.hazardous, pm.abc, 
         pm.master_case, pm.category, pm.replace, pm.replace_ind, pm.buyer, pm.pack, pm.prod_size, pm.brand, pm.catch_wt_trk, pm.split_trk,
         pm.exp_date_trk, pm.temp_trk, pm.repack_trk,pm.mfg_date_trk,pm.stackable, pm.master_sku, pm.master_qty, pm.repack_day, pm.repack_len,
         pm.repack_ind, pm.repack_qty, pm.repack_sec, pm.spc, pm.ti, pm.mf_ti, pm.hi, pm.mf_hi, pm.pallet_type, pm.area, pm.stage, pm.case_cube,
         pm.split_cube, pm.zone_id, pm.avg_wt, pm.case_pallet, pm.awm, pm.max_temp, pm.min_temp, pm.pick_freq, pm.last_rec_date,pm.last_shp_date,  
         pm.pallet_stack, pm.max_slot, pm.max_slot_per, pm.fifo_trk, pm.last_ship_slot, pm.instruction, pm.min_qty, pm.item_cost, pm.mfr_shelf_life,
         pm.sysco_shelf_life, pm.cust_shelf_life, maint_flag, pm.perm_item, pm.internal_upc, pm.external_upc, pm.cubitron, pm.dmd_status, pm.auto_ship_flag, 
         pm.case_type, pm.stock_type, pm.case_height, pm.case_length, pm.case_width, pm.ims_status, pm.split_length, pm.split_width, pm.split_height, pm.max_qty, 
         pm.rdc_vendor_id, pm.rdc_effective_date, pm.mf_sw_ti,pm.split_type, pm.miniload_storage_ind, pm.case_qty_per_carrier, pm.case_qty_for_split_rpl,pm.split_zone_id,        
         pm.high_risk_flag, pm.max_miniload_case_carriers, pm.prod_size_unit, pm.buying_multiple, pm.max_dso, pm.mx_max_case, pm.mx_min_case, pm.mx_eligible,
         pm.mx_item_assign_flag, pm.mx_stability_calc, pm.mx_stability_flag, pm.mx_food_type, pm.mx_upc_present_flag, pm.mx_master_case_flag, pm.mx_package_type, 
         pm.mx_why_not_eligible, pm.mx_hazardous_type, pm.mx_stability_recalc, pm.mx_multi_upc_problem, pm.mx_designate_slot, pm.wsh_begin_date, pm.wsh_avg_invs,
         pm.wsh_ship_movements, pm.wsh_hits,           pm.expected_case_on_po, pm.diagonal_measurement, pm.recalc_length, pm.recalc_width, pm.recalc_height,                  
         pm.default_weight_unit, pm.wsh_begin_date_range, pm.mx_rotation_rules, pm.mx_throttle_flag,   pm.hist_case_order, pm.hist_case_date,        
         pm.hist_split_order, pm.hist_split_date, pm.gs1_barcode_flag, pm.finish_good_ind,pm.read_only_flag  ;
		 
 BEGIN
    /* process only if ENABLE_OPCO_TO_OPCO_XDOCK is set to Y*/
    IF l_get_syspar = 'Y' THEN
	   
	 BEGIN
      SELECT pl_xdock_common.get_batch_id
       INTO l_batch_id
      FROM dual;
     EXCEPTION
     WHEN OTHERS THEN
      PL_Log.Ins_Msg(pl_log.ct_fatal_msg, This_Function, 'Failed to get batch_id from pl_xdock_common.get_batch_id', SQLCODE, SUBSTR(SQLERRM, 1, 500), This_Application, This_Package);
     END;

	 PL_Log.Ins_Msg( pl_log.ct_info_msg, This_Function, 'Begin process_xdock_manifest_pm for manifest_no:' || i_manifest_no, '', '', This_Application, This_Package);
  
      FOR pm_out_rec IN c_pm_out LOOP
        BEGIN	  
		  BEGIN
		  SELECT 1 
		  INTO l_prod_exists
		  FROM xdock_pm_out 
		  WHERE prod_id||site_from||site_to = pm_out_rec.prod_id||pm_out_rec.site_from||pm_out_rec.site_to;
		  EXCEPTION
		    WHEN OTHERS THEN
		    l_prod_exists := NULL;
		  END;

		 IF l_prod_exists = 1 THEN
		    l_record_status := 'X';
		  ELSE
		    l_record_status := 'N';
		  END IF;
		  
		  l_sequence_number := xdock_seqno_seq.nextval;
	 
      INSERT INTO XDOCK_PM_OUT
            (sequence_number, batch_id, record_status, route_batch_no, route_no, site_from, site_to, 
              delivery_document_id, prod_id,  cust_pref_vendor, 
             type, container, vendor_id, mfg_sku, descrip, lot_trk, weight, g_weight, status, hazardous, abc, 
             master_case, category, replace, replace_ind, buyer, pack, prod_size, brand, catch_wt_trk, split_trk,
             exp_date_trk, temp_trk, repack_trk,mfg_date_trk,stackable, master_sku, master_qty, repack_day, repack_len,
             repack_ind, repack_qty, repack_sec, spc, ti, mf_ti, hi, mf_hi, pallet_type, area, stage, case_cube,
             split_cube, zone_id, avg_wt, case_pallet, awm, max_temp, min_temp, pick_freq, last_rec_date,last_shp_date,  
             pallet_stack, max_slot, max_slot_per, fifo_trk, last_ship_slot, instruction, min_qty, item_cost, mfr_shelf_life,
             sysco_shelf_life, cust_shelf_life, maint_flag, perm_item, internal_upc, external_upc, cubitron, dmd_status, auto_ship_flag, 
             case_type, stock_type, case_height, case_length, case_width, ims_status, split_length, split_width, split_height, max_qty, 
             rdc_vendor_id, rdc_effective_date, mf_sw_ti,split_type, miniload_storage_ind, case_qty_per_carrier, case_qty_for_split_rpl,split_zone_id,        
             high_risk_flag, max_miniload_case_carriers, prod_size_unit, buying_multiple, max_dso, mx_max_case, mx_min_case, mx_eligible,
             mx_item_assign_flag, mx_stability_calc, mx_stability_flag, mx_food_type, mx_upc_present_flag, mx_master_case_flag, mx_package_type, 
             mx_why_not_eligible, mx_hazardous_type, mx_stability_recalc, mx_multi_upc_problem, mx_designate_slot, wsh_begin_date, wsh_avg_invs,
             wsh_ship_movements, wsh_hits,           expected_case_on_po, diagonal_measurement, recalc_length, recalc_width, recalc_height,                  
             default_weight_unit, wsh_begin_date_range, mx_rotation_rules, mx_throttle_flag,   hist_case_order, hist_case_date,        
             hist_split_order, hist_split_date, gs1_barcode_flag, finish_good_ind,read_only_flag)
          VALUES 
            (l_sequence_number,        l_batch_id,           		     l_record_status,             i_manifest_no,                     pm_out_rec.route_no,             pm_out_rec.site_from,            pm_out_rec.site_to,     
             pm_out_rec.delivery_document_id,  pm_out_rec.prod_id,       pm_out_rec.cust_pref_vendor, pm_out_rec.type,                   pm_out_rec.container,            pm_out_rec.vendor_id, 
             pm_out_rec.mfg_sku,       pm_out_rec.descrip,               pm_out_rec.lot_trk,          pm_out_rec.weight,                 pm_out_rec.g_weight,             pm_out_rec.status,               pm_out_rec.hazardous, 
             pm_out_rec.abc,           pm_out_rec.master_case,           pm_out_rec.category,         pm_out_rec.replace,                pm_out_rec.replace_ind,          pm_out_rec.buyer,                pm_out_rec.pack, 
             pm_out_rec.prod_size,     pm_out_rec.brand,                 pm_out_rec.catch_wt_trk,     pm_out_rec.split_trk,              pm_out_rec.exp_date_trk,         pm_out_rec.temp_trk,             pm_out_rec.repack_trk,
             pm_out_rec.mfg_date_trk,  pm_out_rec.stackable,             pm_out_rec.master_sku,       pm_out_rec.master_qty,             pm_out_rec.repack_day,           pm_out_rec.repack_len,           pm_out_rec.repack_ind,    
             pm_out_rec.repack_qty,    pm_out_rec.repack_sec,            pm_out_rec.spc,              pm_out_rec.ti,                     pm_out_rec.mf_ti,                pm_out_rec.hi,                   pm_out_rec.mf_hi, 
             pm_out_rec.pallet_type,   pm_out_rec.area,                  pm_out_rec.stage,            pm_out_rec.case_cube,              pm_out_rec.split_cube,           pm_out_rec.zone_id,              pm_out_rec.avg_wt,    
             pm_out_rec.case_pallet,   pm_out_rec.awm,                   pm_out_rec.max_temp,         pm_out_rec.min_temp,               pm_out_rec.pick_freq,            pm_out_rec.last_rec_date,        pm_out_rec.last_shp_date,  
             pm_out_rec.pallet_stack,  pm_out_rec.max_slot,              pm_out_rec.max_slot_per,     pm_out_rec.fifo_trk,               pm_out_rec.last_ship_slot,       pm_out_rec.instruction,          pm_out_rec.min_qty, 
             pm_out_rec.item_cost,     pm_out_rec.mfr_shelf_life,        pm_out_rec.sysco_shelf_life, pm_out_rec.cust_shelf_life,        pm_out_rec.maint_flag,           pm_out_rec.perm_item,            pm_out_rec.internal_upc, 
             pm_out_rec.external_upc,  pm_out_rec.cubitron,              pm_out_rec.dmd_status,       pm_out_rec.auto_ship_flag,         pm_out_rec.case_type,            pm_out_rec.stock_type,           pm_out_rec.case_height,
             pm_out_rec.case_length,   pm_out_rec.case_width,            pm_out_rec.ims_status,       pm_out_rec.split_length,           pm_out_rec.split_width,          pm_out_rec.split_height,         pm_out_rec.max_qty, 
             pm_out_rec.rdc_vendor_id, pm_out_rec.rdc_effective_date,    pm_out_rec.mf_sw_ti,         pm_out_rec.split_type,             pm_out_rec.miniload_storage_ind, pm_out_rec.case_qty_per_carrier, pm_out_rec.case_qty_for_split_rpl,
             pm_out_rec.split_zone_id, pm_out_rec.high_risk_flag,        pm_out_rec.max_miniload_case_carriers,                          pm_out_rec.prod_size_unit,       pm_out_rec.buying_multiple,      pm_out_rec.max_dso, 
             pm_out_rec.mx_max_case,   pm_out_rec.mx_min_case,           pm_out_rec.mx_eligible,             pm_out_rec.mx_item_assign_flag, pm_out_rec.mx_stability_calc,  pm_out_rec.mx_stability_flag,  pm_out_rec.mx_food_type, 
             pm_out_rec.mx_upc_present_flag,  pm_out_rec.mx_master_case_flag,  pm_out_rec.mx_package_type,   pm_out_rec.mx_why_not_eligible, pm_out_rec.mx_hazardous_type,  pm_out_rec.mx_stability_recalc, 
             pm_out_rec.mx_multi_upc_problem, pm_out_rec.mx_designate_slot,    pm_out_rec.wsh_begin_date,    pm_out_rec.wsh_avg_invs,        pm_out_rec.wsh_ship_movements, pm_out_rec.wsh_hits,           
             pm_out_rec.expected_case_on_po,  pm_out_rec.diagonal_measurement, pm_out_rec.recalc_length,     pm_out_rec.recalc_width,        pm_out_rec.recalc_height,                  
             pm_out_rec.default_weight_unit,  pm_out_rec.wsh_begin_date_range, pm_out_rec.mx_rotation_rules, pm_out_rec.mx_throttle_flag,    pm_out_rec.hist_case_order, pm_out_rec.hist_case_date,        
             pm_out_rec.hist_split_order,     pm_out_rec.hist_split_date,      pm_out_rec.gs1_barcode_flag,  pm_out_rec.finish_good_ind, 'Y');

			 
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Error: Inserting the data into XDOCK_PM_OUT ';
            l_error_code:= SUBSTR(SQLERRM,1,100);
            PL_Log.Ins_Msg( pl_log.ct_fatal_msg, This_Function, l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package);
            RAISE process_error;
        END;		
	
		l_site_from := pm_out_rec.site_from;
		l_site_to := pm_out_rec.site_to;
	    
	   END LOOP;
	   COMMIT;
	   -- S4R- Jira 3688, dont need to call for null values/xdock X type
	   IF l_site_from IS NOT NULL THEN
		l_msg_hub_response := PL_MSG_HUB_UTLITY.insert_meta_header(l_batch_id, 'XDOCK_PM_OUT' , l_site_from, l_site_to);
	
		IF l_msg_hub_response != 0 THEN
		 RAISE bad_msg_hub_response;
		END IF;
	  END IF;
    COMMIT;
    END IF;
  EXCEPTION
    WHEN bad_msg_hub_response THEN
	  l_error_msg := 'Failed to notify PL_MSG_HUB_UTLITY, Response Code: ';
	  l_error_code:= SQLCODE;
      pl_log.ins_msg( pl_log.ct_fatal_msg, This_Function, l_error_msg || l_msg_hub_response, SQLCODE, SQLERRM, This_Application, This_Package);
	  
	  UPDATE xdock_pm_out
         SET record_status   = 'F'
           , error_msg       = l_error_msg
           , error_code      = l_error_code
       WHERE sequence_number = l_sequence_number;
      COMMIT;	  
    WHEN process_error THEN
      l_error_msg := 'error in processing sequence no: '||l_sequence_number||'manifest no: ' ||i_manifest_no;
      l_error_code:= SUBSTR(SQLERRM,1,100);
      pl_log.ins_msg( pl_log.ct_fatal_msg, This_Function, l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package);
    WHEN OTHERS THEN
      l_error_msg:= SUBSTR(SQLERRM,1,100);
      l_error_code:= SQLCODE;
      pl_log.ins_msg( pl_log.ct_fatal_msg, This_Function, l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package );
  END process_xdock_manifest_pm;
  
END pl_xdock_pm_out;
/
show errors

CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_pm_out FOR swms.pl_xdock_pm_out;

GRANT EXECUTE ON swms.pl_xdock_pm_out TO SWMS_USER;
