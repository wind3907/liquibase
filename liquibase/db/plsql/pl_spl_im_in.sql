CREATE OR REPLACE PACKAGE pl_spl_im_in 
IS
  /*===========================================================================================================
  -- Package
  -- pl_spl_im_in
  --
  -- Description
  --  This package processes the item maintenance updates data from FoodPro to sap_cu_in table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   5/31/18        mcha1213      Initial version        
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  PROCEDURE parse_im(  i_message    IN   VARCHAR2
                             , i_sequence_no   IN   NUMBER );



END pl_spl_im_in;


/


CREATE OR REPLACE PACKAGE BODY  pl_spl_im_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_spl_im_in
  --
  -- Description
  --  
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   5/31/18        mcha1213      Initial version        
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  -- 
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_im(i_message IN  VARCHAR2,
                   i_sequence_no IN NUMBER 
                  )
  -------------------------------------------------------------------------------------------------------------
  -- PROCEDURE
  -- parse_im
  --
  -- Description
  --   This Procedure parses the data from the IM queue and places it in the 
  --   sap_im_in staging table.
  --
  -- Modification History
  --
  --  Date         User            Comment
  --  --------     ----------      -----------
  --  4/13/18      pkab6563        Initial version
  --  7/03/18      mcha1213        modify prod_id, length is 7
  --  9/14/18      pkab6563        Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ------------------------------------------------------------------------------------------------------------
IS
  process_error       EXCEPTION;
  l_sequence_number   sap_im_in.sequence_number%type;
  this_function       CONSTANT  VARCHAR2(30 CHAR) := 'PL_SPL_IM_IN.PARSE_IM';
  l_ti                sap_im_in.ti%type;
  l_hi                sap_im_in.hi%type;
  
  prod_id_length_err  exception;
  

  CURSOR c_im
  IS
     SELECT TO_CHAR(SUBSTR(i_message, 1, 1)) func_code,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 2, 9))) prod_id,                                
           TO_CHAR(SUBSTR(i_message, 11, 10)) cust_pref_vendor,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 21, 4), '0')) mfr_shelf_life,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 25, 4), '0')) sysco_shelf_life,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 29, 4), '0')) cust_shelf_life,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 33, 4))) container,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 37, 4))) pack,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 41, 6))) prod_size,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 47, 7))) brand,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 54, 30))) descrip,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 84, 14))) mfg_sku,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 98, 10))) vendor_id,                                
           TO_CHAR(SUBSTR(i_message, 108, 1)) catch_wt_trk,           
           TO_CHAR(LTRIM(SUBSTR(i_message, 109, 8), '0')) weight,            
           TO_CHAR(LTRIM(SUBSTR(i_message, 117, 9), '0')) g_weight,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 126, 4), '0')) master_case,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 130, 4), '0')) units_per_case,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 134, 11))) category,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 145, 6))) hazardous,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 151, 9))) replace,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 160, 3))) buyer,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 163, 3), '0')) min_qty,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 166, 7), '0')) case_cube,                                
           TO_CHAR(SUBSTR(i_message, 173, 1)) stage,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 174, 2))) pallet_type,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 176, 3), '0')) ti,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 179, 3), '0')) hi,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 182, 6))) last_rec_date,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 188, 6))) last_ship_date,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 194, 6), '0')) min_temp,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 200, 6), '0')) max_temp,                                
           TO_CHAR(SUBSTR(i_message, 206, 1)) lot_trk,                                
           TO_CHAR(SUBSTR(i_message, 207, 1)) fifo_trk,                                
           TO_CHAR(SUBSTR(i_message, 208, 1)) mfg_date_trk,                                
           TO_CHAR(SUBSTR(i_message, 209, 1)) exp_date_trk,                                
           TO_CHAR(SUBSTR(i_message, 210, 1)) temp_trk,                                
           TO_CHAR(SUBSTR(i_message, 211, 1)) abc,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 212, 9))) master_sku,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 221, 6), '0')) master_qty,                                
           TO_CHAR(SUBSTR(i_message, 227, 1)) repack_ind,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 228, 14))) external_upc,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 242, 14))) internal_upc,                                
           TO_CHAR(SUBSTR(i_message, 256, 1)) stock_type,                                
           TO_CHAR(SUBSTR(i_message, 257, 1)) filler1,                                
           NVL(TO_CHAR(LTRIM(SUBSTR(i_message, 258, 1))), 'N') cubitron,                                
           TO_CHAR(SUBSTR(i_message, 259, 1)) dmd_status,                                
           TO_CHAR(SUBSTR(i_message, 260, 1)) auto_ship_flag,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 261, 9), '0')) case_height,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 270, 9), '0')) case_length,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 279, 9), '0')) case_width,                                
           TO_CHAR(SUBSTR(i_message, 288, 1)) ims_status,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 289, 4), '0')) case_qty_per_carrier,                                
           TO_CHAR(RTRIM(SUBSTR(i_message, 293, 3))) prod_size_unit,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 296, 10), '0')) item_cost,                                
           TO_CHAR(LTRIM(SUBSTR(i_message, 306, 5), '0')) buying_multiple,                                
           TO_CHAR(SUBSTR(i_message, 311, 1)) finish_good_ind                       
    FROM dual;



BEGIN

   l_sequence_number := i_sequence_no;

   /*
   PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg,
                   i_Procedure_Name   => this_function,
                   i_Msg_Text         => 'before the for loop',
                   i_Msg_No           => NULL,
                   i_SQL_Err_Msg      => NULL,
                   i_Application_Func => 'Parsing IM In',
                   i_Program_Name     => this_function,
                   i_Msg_Alert        => 'N'
                        );                                            
   */

   FOR im_rec IN c_im
   LOOP
      IF (TO_NUMBER(NVL(im_rec.ti, '0')) = 0) THEN
         l_ti := '1';
      ELSE
         l_ti := im_rec.ti;
      END IF;

      IF (TO_NUMBER(NVL(im_rec.hi, '0')) = 0) THEN
         l_hi := '99';
      ELSE
         l_hi := im_rec.hi;
      END IF;
      
      INSERT INTO sap_im_in 
                   (sequence_number, interface_type, record_status, datetime, 
                    func_code, prod_id , cust_pref_vendor, mfr_shelf_life, 
                    sysco_shelf_life, cust_shelf_life, container, pack, 
                    prod_size, prod_size_unit, brand, descrip, mfg_sku, 
                    vendor_id, catch_wt_trk, weight, g_weight, 
                    master_case, units_per_case, category, hazardous, 
                    replace, buyer, min_qty, case_cube, stage, pallet_type, 
                    ti, hi, last_rec_date, last_ship_date, min_temp, 
                    max_temp, lot_trk, fifo_trk, mfg_date_trk, 
                    exp_date_trk, temp_trk, abc, master_sku, 
                    master_qty, repack_ind, external_upc, internal_upc,
                    stock_type, filler1, cubitron, dmd_status, auto_ship_flag, 
                    case_height, case_length, case_width, ims_status, 
                    case_qty_per_carrier, item_cost, upd_user, upd_date, 
                    buying_multiple, finish_good_ind 
                   )
      VALUES
                   (l_sequence_number, 'IM', 'N', sysdate,
                    im_rec.func_code, im_rec.prod_id, im_rec.cust_pref_vendor, im_rec.mfr_shelf_life,
                    im_rec.sysco_shelf_life, im_rec.cust_shelf_life, im_rec.container, im_rec.pack, 
                    im_rec.prod_size, im_rec.prod_size_unit, im_rec.brand, im_rec.descrip, im_rec.mfg_sku, 
                    im_rec.vendor_id, im_rec.catch_wt_trk, im_rec.weight, im_rec.g_weight, 
                    im_rec.master_case, im_rec.units_per_case, im_rec.category, im_rec.hazardous, 
                    im_rec.replace, im_rec.buyer, im_rec.min_qty, im_rec.case_cube, im_rec.stage, im_rec.pallet_type, 
                    l_ti, l_hi, im_rec.last_rec_date, im_rec.last_ship_date, im_rec.min_temp, 
                    im_rec.max_temp, im_rec.lot_trk, im_rec.fifo_trk, im_rec.mfg_date_trk, 
                    im_rec.exp_date_trk, im_rec.temp_trk, im_rec.abc, im_rec.master_sku, 
                    im_rec.master_qty, im_rec.repack_ind, im_rec.external_upc, im_rec.internal_upc,
                    im_rec.stock_type, im_rec.filler1, im_rec.cubitron, im_rec.dmd_status, im_rec.auto_ship_flag, 
                    im_rec.case_height, im_rec.case_length, im_rec.case_width, im_rec.ims_status, 
                    im_rec.case_qty_per_carrier, im_rec.item_cost, user, sysdate, 
                    im_rec.buying_multiple, im_rec.finish_good_ind 
                   );
        
      
      /*
      if length(im_rec.prod_id) > 7 then
         raise prod_id_length_err;
      else   
   
         INSERT INTO sap_im_in 
                   (sequence_number, interface_type, record_status, datetime, 
                    func_code, prod_id , cust_pref_vendor, mfr_shelf_life, 
                    sysco_shelf_life, cust_shelf_life, container, pack, 
                    prod_size, prod_size_unit, brand, descrip, mfg_sku, 
                    vendor_id, catch_wt_trk, weight, g_weight, 
                    master_case, units_per_case, category, hazardous, 
                    replace, buyer, min_qty, case_cube, stage, pallet_type, 
                    ti, hi, last_rec_date, last_ship_date, min_temp, 
                    max_temp, lot_trk, fifo_trk, mfg_date_trk, 
                    exp_date_trk, temp_trk, abc, master_sku, 
                    master_qty, repack_ind, external_upc, internal_upc,
                    stock_type, filler1, cubitron, dmd_status, auto_ship_flag, 
                    case_height, case_length, case_width, ims_status, 
                    case_qty_per_carrier, item_cost, upd_user, upd_date, 
                    buying_multiple, finish_good_ind 
                   )
             VALUES
                   (l_sequence_number, 'IM', 'N', sysdate,
                    im_rec.func_code, im_rec.prod_id, im_rec.cust_pref_vendor, im_rec.mfr_shelf_life,
                    im_rec.sysco_shelf_life, im_rec.cust_shelf_life, im_rec.container, im_rec.pack, 
                    im_rec.prod_size, im_rec.prod_size_unit, im_rec.brand, im_rec.descrip, im_rec.mfg_sku, 
                    im_rec.vendor_id, im_rec.catch_wt_trk, im_rec.weight, im_rec.g_weight, 
                    im_rec.master_case, im_rec.units_per_case, im_rec.category, im_rec.hazardous, 
                    im_rec.replace, im_rec.buyer, im_rec.min_qty, im_rec.case_cube, im_rec.stage, im_rec.pallet_type, 
                    l_ti, l_hi, im_rec.last_rec_date, im_rec.last_ship_date, im_rec.min_temp, 
                    im_rec.max_temp, im_rec.lot_trk, im_rec.fifo_trk, im_rec.mfg_date_trk, 
                    im_rec.exp_date_trk, im_rec.temp_trk, im_rec.abc, im_rec.master_sku, 
                    im_rec.master_qty, im_rec.repack_ind, im_rec.external_upc, im_rec.internal_upc,
                    im_rec.stock_type, im_rec.filler1, im_rec.cubitron, im_rec.dmd_status, im_rec.auto_ship_flag, 
                    im_rec.case_height, im_rec.case_length, im_rec.case_width, im_rec.ims_status, 
                    im_rec.case_qty_per_carrier, im_rec.item_cost, user, sysdate, 
                    im_rec.buying_multiple, im_rec.finish_good_ind 
                   );
        end if;
        
        */
                   
        

   END LOOP;

      --commit; 

   /*
   PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg,
                   i_Procedure_Name   => this_function, 
                   i_Msg_Text         => 'after the for loop',
                   i_Msg_No           => NULL,
                   i_SQL_Err_Msg      => NULL,
                   i_Application_Func => 'Parsing IM In',
                   i_Program_Name     => this_function,
                   i_Msg_Alert        => 'N'
                );                                     
   */


EXCEPTION
   /* when prod_id_length_err then

  l_error_msg:= 'Error: pl_spl_im_in when prod_id_length_err exception prod_id is > 7 char ';
  --l_error_code:= SUBSTR(SQLERRM,1,100);   
  pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_im', l_error_msg,
											SQLCODE, SQLERRM,
											'im',
											'pl_spl_im_in',
											'N');
  UPDATE mq_queue_in
     SET record_status   = 'F',
              error_msg       = l_error_msg
              --,error_code      = l_error_code
     WHERE sequence_number = l_sequence_number;

    Commit;

   */
WHEN OTHERS THEN

  l_error_msg:= 'Error: pl_spl_im_in when others Exception';
  l_error_code:= SUBSTR(SQLERRM,1,100);   
  pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_im', l_error_msg,
											SQLCODE, SQLERRM,
											'im',
											'pl_spl_im_in',
											'N');
  UPDATE mq_queue_in
     SET record_status   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
     WHERE sequence_number = l_sequence_number;

    Commit;

END parse_im;


END pl_spl_im_in;
/
