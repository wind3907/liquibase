CREATE OR REPLACE PACKAGE SWMS.pl_xdock_pm_in IS
  /*===========================================================================================================
  -- Package
  -- pl_xdock_pm_in
  --
  -- Description
  --  This package processes the data from the  xdock_pm_in to pm table
  --
  -- Modification History
  --
  -- Date              User       Version         Comment
  -- 05/17/21        pdas8114        1.0       OPCOF - 3385 Interface from SWMS (site1) to SWMS (site2) for X-dock Product Attributes           
  ============================================================================================================*/

  PROCEDURE process_xdock_pm_in;

END pl_xdock_pm_in;
/

CREATE OR REPLACE PACKAGE BODY SWMS.pl_xdock_pm_in IS
  /*===========================================================================================================
  -- Package Body
  -- pl_xdock_pm_in
  --
  -- Description
  --  This package processes the data from the xdock_pm_in to pm table
  --
  -- Modification History
  --
  -- Date                User                  Version        Comment
  -- 05/21/21           pdas8114       			 1.0       OPCOF - 3385 Interface from SWMS (site1) to SWMS (site2) for X-dock Product Attributes 
  ============================================================================================================*/

  This_Package        CONSTANT  VARCHAR2(30 CHAR) := $$PLSQL_UNIT;
  This_Application    CONSTANT  VARCHAR2(30 CHAR) := 'MAINTENANCE';
  l_prod_cnt          NUMBER;
  l_read_only_flag    VARCHAR2(1);
  l_insert_record     NUMBER;
  l_get_syspar        VARCHAR2(1) := UPPER( PL_Common.F_Get_SysPar( 'ENABLE_OPCO_TO_OPCO_XDOCK', 'N' ));
  l_error_msg         VARCHAR2(400);
  l_error_code        VARCHAR2(100);
 

  PROCEDURE process_xdock_pm_in
  IS
    /*===========================================================================================================
    -- PROCEDURE
    -- process_xdock_pm_in
    --
    -- Description
    --   This Procedure populates pm table from xdock_pm_in staging table 
    --
    -- Modification History
    --
    -- Date                User                  Version             Defect  Comment
    -- 05/22/21           pdas8114                1.0               Initial Creation
	-- 09/09/21           pdas8114                1.1               Added missing columns from pm
    ============================================================================================================*/
    --------------------------local variables-----------------------------
    process_error             EXCEPTION;
    l_sequence_number         NUMBER;
    l_count                   NUMBER;
	This_Function          CONSTANT  VARCHAR2(30 CHAR) := UPPER( 'process_xdock_pm_in' );

    CURSOR c_pm_in IS
      SELECT sequence_number, batch_id, order_id, route_no, delivery_document_id, prod_id, cust_pref_vendor,
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
			 hist_split_order, hist_split_date, gs1_barcode_flag, finish_good_ind,read_only_flag  
			 FROM xdock_pm_in
			 WHERE record_status = 'N'
			 order by sequence_number;

 BEGIN
    /* process only if ENABLE_OPCO_TO_OPCO_XDOCK is set to Y*/
    IF l_get_syspar = 'Y' THEN
	
      FOR pm_in_rec IN c_pm_in LOOP
	    l_insert_record := 0;
	    -- verify if product exists in pm table	
		l_sequence_number := pm_in_rec.sequence_number;
		BEGIN
		  SELECT COUNT(*), read_only_flag
		  INTO l_prod_cnt, l_read_only_flag
		  FROM PM
		  WHERE prod_id = pm_in_rec.prod_id
		  GROUP BY read_only_flag;
		  EXCEPTION
		   WHEN OTHERS THEN
		    l_prod_cnt := 0;
			l_read_only_flag := NULL;
		END;        
		IF l_prod_cnt = 0 AND l_read_only_flag IS NULL THEN
		 -- insert
		 l_insert_record :=  1;
		ELSIF l_prod_cnt = 1 AND l_read_only_flag = 'Y' THEN
		 --delete and insert
		 l_insert_record :=  1;
		 delete from pm where prod_id = pm_in_rec.prod_id;
		ELSE
		 UPDATE xdock_pm_in
         SET record_status   = 'S'
           , error_msg       = 'Product exists'
           , error_code      = ''
         WHERE sequence_number = l_sequence_number;
		END IF; 
		IF l_insert_record = 1 THEN
        BEGIN
          INSERT INTO PM 
		   ( prod_id, cust_pref_vendor, type, container, vendor_id, mfg_sku, descrip, lot_trk, weight, g_weight, status, hazardous, abc, 
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
		    (pm_in_rec.prod_id,          pm_in_rec.cust_pref_vendor, pm_in_rec.type, 	                pm_in_rec.container,            pm_in_rec.vendor_id,              pm_in_rec.mfg_sku,             pm_in_rec.descrip, 
			 pm_in_rec.lot_trk,          pm_in_rec.weight, 			 pm_in_rec.g_weight,                pm_in_rec.status,               pm_in_rec.hazardous,              pm_in_rec.abc,                 pm_in_rec.master_case,      
			 pm_in_rec.category, 		 pm_in_rec.replace,          pm_in_rec.replace_ind,             pm_in_rec.buyer,                pm_in_rec.pack,                   pm_in_rec.prod_size,           pm_in_rec.brand, 
			 pm_in_rec.catch_wt_trk,     pm_in_rec.split_trk,        pm_in_rec.exp_date_trk,            pm_in_rec.temp_trk, 	        pm_in_rec.repack_trk,             pm_in_rec.mfg_date_trk,        pm_in_rec.stackable, 
			 pm_in_rec.master_sku,       pm_in_rec.master_qty,       pm_in_rec.repack_day,              pm_in_rec.repack_len,           pm_in_rec.repack_ind,             pm_in_rec.repack_qty,          pm_in_rec.repack_sec, 
			 pm_in_rec.spc,              pm_in_rec.ti,               pm_in_rec.mf_ti,                   pm_in_rec.hi,                   pm_in_rec.mf_hi,                  pm_in_rec.pallet_type,         pm_in_rec.area, 
			 pm_in_rec.stage,            pm_in_rec.case_cube,        pm_in_rec.split_cube,              pm_in_rec.zone_id,              pm_in_rec.avg_wt, 	              pm_in_rec.case_pallet,         pm_in_rec.awm, 
			 pm_in_rec.max_temp,         pm_in_rec.min_temp,         pm_in_rec.pick_freq,               pm_in_rec.last_rec_date,        pm_in_rec.last_shp_date,          pm_in_rec.pallet_stack,        pm_in_rec.max_slot,
			 pm_in_rec.max_slot_per,     pm_in_rec.fifo_trk,         pm_in_rec.last_ship_slot,          pm_in_rec.instruction,          pm_in_rec.min_qty,                pm_in_rec.item_cost,           pm_in_rec.mfr_shelf_life,
			 pm_in_rec.sysco_shelf_life, pm_in_rec.cust_shelf_life,  pm_in_rec.maint_flag,              pm_in_rec.perm_item,            pm_in_rec.internal_upc,           pm_in_rec.external_upc,        pm_in_rec.cubitron, 
			 pm_in_rec.dmd_status,       pm_in_rec.auto_ship_flag,   pm_in_rec.case_type, 	            pm_in_rec.stock_type,           pm_in_rec.case_height,            pm_in_rec.case_length,         pm_in_rec.case_width, 
			 pm_in_rec.ims_status, 		 pm_in_rec.split_length, 	 pm_in_rec.split_width,             pm_in_rec.split_height,         pm_in_rec.max_qty,                pm_in_rec.rdc_vendor_id,       pm_in_rec.rdc_effective_date, 
			 pm_in_rec.mf_sw_ti, 		 pm_in_rec.split_type,   	 pm_in_rec.miniload_storage_ind,    pm_in_rec.case_qty_per_carrier, pm_in_rec.case_qty_for_split_rpl, pm_in_rec.split_zone_id,       pm_in_rec.high_risk_flag,
			 pm_in_rec.max_miniload_case_carriers,                   pm_in_rec.prod_size_unit,          pm_in_rec.buying_multiple,      pm_in_rec.max_dso,                pm_in_rec.mx_max_case,         pm_in_rec.mx_min_case, 
			 pm_in_rec.mx_eligible,      pm_in_rec.mx_item_assign_flag, pm_in_rec.mx_stability_calc,    pm_in_rec.mx_stability_flag,    pm_in_rec.mx_food_type,           pm_in_rec.mx_upc_present_flag, pm_in_rec.mx_master_case_flag, 
			 pm_in_rec.mx_package_type,  pm_in_rec.mx_why_not_eligible, pm_in_rec.mx_hazardous_type,    pm_in_rec.mx_stability_recalc,  pm_in_rec.mx_multi_upc_problem,   pm_in_rec.mx_designate_slot,   pm_in_rec.wsh_begin_date, 
			 pm_in_rec.wsh_avg_invs,     pm_in_rec.wsh_ship_movements, pm_in_rec.wsh_hits,              pm_in_rec.expected_case_on_po,  pm_in_rec.diagonal_measurement,   pm_in_rec.recalc_length,       pm_in_rec.recalc_width, 
			 pm_in_rec.recalc_height,    pm_in_rec.default_weight_unit, pm_in_rec.wsh_begin_date_range, pm_in_rec.mx_rotation_rules,    pm_in_rec.mx_throttle_flag,       pm_in_rec.hist_case_order,     pm_in_rec.hist_case_date, 			 
			 pm_in_rec.hist_split_order, pm_in_rec.hist_split_date,     pm_in_rec.gs1_barcode_flag,     pm_in_rec.finish_good_ind, 'Y');
			 
        EXCEPTION
          WHEN OTHERS THEN
            l_error_msg := 'Error: Inserting the data into XDOCK_PM_IN ';
            l_error_code:= SUBSTR(SQLERRM,1,100);
            PL_Log.Ins_Msg( pl_log.ct_fatal_msg, This_Function, l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package);
            RAISE process_error;
        END;
		ELSE
		 UPDATE xdock_pm_in
         SET record_status   = 'S'
           , error_msg       = 'Product exists'
           , error_code      = ''
         WHERE sequence_number = l_sequence_number;
		END IF;
				
		UPDATE xdock_pm_in
         SET record_status   = 'S'
        WHERE sequence_number = l_sequence_number;
		
      END LOOP;
     END IF;
  EXCEPTION
    WHEN process_error THEN
      l_error_msg := 'error in processing';
      l_error_code:= SUBSTR(SQLERRM,1,100);
      pl_log.ins_msg( pl_log.ct_error_msg, 'process_xdock_pm_in', l_error_msg,
                      SQLCODE, SQLERRM, This_Application,This_Package);

      UPDATE xdock_pm_in
         SET record_status   = 'F'
           , error_msg       = l_error_msg
           , error_code      = l_error_code
       WHERE sequence_number = l_sequence_number;
      --COMMIT;
    WHEN OTHERS THEN
      l_error_msg:= SUBSTR(SQLERRM,1,100);
      l_error_code:= SQLCODE;
      pl_log.ins_msg( pl_log.ct_fatal_msg, 'process_xdock_pm_in', l_error_msg, SQLCODE, SQLERRM, This_Application, This_Package );
      
	  UPDATE xdock_pm_in
         SET record_status   = 'F'
           , error_msg       = l_error_msg
           , error_code      = l_error_code
       WHERE sequence_number = l_sequence_number;
  END process_xdock_pm_in;
END pl_xdock_pm_in;
/

show errors

CREATE OR REPLACE PUBLIC SYNONYM pl_xdock_pm_in FOR swms.pl_xdock_pm_in;

GRANT EXECUTE ON swms.pl_xdock_pm_in TO SWMS_USER;
