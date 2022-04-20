CREATE OR REPLACE PACKAGE      PL_SPL_OUT IS
  /*============================================================================
  -- Package:     PL_SPL_OUT
  --
  -- Description: This package processes outbound messages from AQ to
  --              FoodPro.
  --
  -- Modification History:
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --                  mcha1213      Initial version
  --   9/17/18        pkab6563      Jira #589 - Remove info-only messages to
  --                                avoid filling up message table.
  --   9/06/18 	      sban3548      Added procedure to send LM interface to AF
  --   3/26/19        pkab6563      Made changes to a few fields in the data 
  --                                in SEND_OW_OUT to match APCOM data format. 
  --                                Jira card 745.
  --   4/4/19         mcha1213      Made changes to send_ia_out for linux/SUS  by adding 11
  --                                  columns
  --   4/9/19         xzhe5043      Added new procedure:MEAT_CL_OUT to send customer location 
  --   7/18/19        pkab6563      Jira card 2456 - Changed cursor in SEND_OW_OUT
  --                                to use sys_order_line_id instead of order_line_id
  --                                to match the order line id sent by the erp system.
  --   7/22/19        mcha1213      modify send_ow_out to add country_of_origin
  --                                and wild_farm_desc 
  --   10/01/19	      sban3548	    send out country_of_origin and wild_farm_desc
  --				    			if the syspar HOST_SAP_COOL is enabled 
  --
  ============================================================================*/
 PROCEDURE SEND_IA_OUT;

 PROCEDURE SEND_LM_OUT;
 
 PROCEDURE SEND_OW_OUT; 

 PROCEDURE SEND_PW_OUT;

 PROCEDURE SEND_WH_OUT;
 
 PROCEDURE SEND_RT_OUT;
 
 PROCEDURE MEAT_CL_OUT;
  
END PL_SPL_OUT;
/


CREATE OR REPLACE PACKAGE BODY      PL_SPL_OUT IS
  /*============================================================================
  -- Package:     PL_SPL_OUT
  --

  -- Description: This package processes outbound messages from AQ to
  --              FoodPro.
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 

  ============================================================================*/

  This_Package          CONSTANT  VARCHAR2(30 CHAR)               := 'PL_SPL_OUT';
  This_Application      CONSTANT  swms_log.application_func%TYPE  := 'LM_INTERFACE';

  Q_Status_Success      CONSTANT  VARCHAR2(1 CHAR)  := 'S';
  Q_Status_Failure      CONSTANT  VARCHAR2(1 CHAR)  := 'F';
  Q_Status_Queued       CONSTANT  VARCHAR2(1 CHAR)  := 'Q';

  Queue_lm              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_LM_OUT';
  Queue_ia              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_IA_OUT'; --mq_queue_out.queue_name%type;
  Queue_ow              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_OW_OUT';
  Queue_pw              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_PW_OUT';
  Queue_wh              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_WH_OUT';
  Queue_rt              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_RT_OUT';
  Queue_cl              CONSTANT  mq_queue_out.queue_name%type :='Q_SPL_CL_OUT';



  /*
  Queue_Pallet           CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_PALLET_RECEIPT';
  Queue_ship_sum_sus     CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_SUMMARY_SUS';
  Queue_ship_sum_dpr     CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_SUMMARY_DPR';
  Queue_shipment_sus     CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_SUS_';
  Queue_shipment_swms    CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_SWMS_';
  Queue_RA_Close         CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_RA_CLOSE';
  Queue_shipment_rdc_sus CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_RDC_SUS';
  Queue_shipment_dpr     CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_SHIPMENT_DPR';
  Queue_inv_adj_sus      CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_INV_ADJ_RDC_SUS'; 
  Queue_item_update      CONSTANT  mq_queue_out.queue_name%TYPE := 'SEND_ITEM_UPDATE_RDC_SUS';
  */
  g_error_context                 VARCHAR2(4000 CHAR) ;
  g_saved_error_code              NUMBER;


  /*
  FUNCTION ACTIVE_QUEUE(i_swms_queue_name IN VARCHAR2 )
  RETURN BOOLEAN IS
  BEGIN
   RETURN (PL_RDC_IN.ACTIVE_QUEUE( i_swms_queue_name ));
  END ACTIVE_QUEUE;
  */

  FUNCTION ACTIVE_QUEUE(i_swms_queue_name IN VARCHAR2 )
  RETURN BOOLEAN IS
 /*===========================================================================================================
  -- Function
  -- ACTIVE_QUEUE
  --
  -- Description
  --   This Function returns the status of the Interface and the MQ name to process.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 04/19/18                1.0              Initial Creation
  ============================================================================================================*/
    This_Function     CONSTANT  VARCHAR2(30 CHAR) := 'ACTIVE_QUEUE';
    l_exist VARCHAR2(1);
  BEGIN
    SELECT 'Y'
      INTO l_exist
      FROM mq_interface_maint
     WHERE AQ_Queue_name = i_swms_queue_name
       AND ACTIVE_FLAG = 'Y';
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                    , i_Procedure_Name   => This_Function
                    , i_Msg_Text         => 'Error Occurred While Accessing MQ_INTERFACE_MAINT table. i_swms_queue_name is '|| i_swms_queue_name
                    , i_Msg_No           => SQLCODE
                    , i_SQL_Err_Msg      => SQLERRM
                    , i_Application_Func => This_Application
                    , i_Program_Name     => This_Package
                    , i_Msg_Alert        => 'N'
                    );
      RETURN FALSE;
  END ACTIVE_QUEUE;

 /*============================================================================
  --
  -- Module Name: SEND_LM_OUT
  --
  -- Description: This procedure send Item/Warehouse Parameters to Asian Foods
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 09/06/2018 sban3548    Added procedure to send LM interface to AF
  ============================================================================*/
  PROCEDURE SEND_LM_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_LM_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);

    cursor c_lm_item_wh_params is
      select add_date, sequence_number seq_no, 'U' record_type, rpad(nvl(prod_id,' '),9) prod_id, rpad(nvl(cust_pref_vendor,' '), 10) cust_pref_vendor, rpad(nvl(ti,' '), 4) ti, rpad(nvl(hi,' '),4) hi, rpad(nvl(abc,' '),1) abc
        , rpad(nvl(mfr_shelf_life,' '),4) mfr_shelf_life, rpad(nvl(pallet_type,' '),2) pallet_type, rpad(nvl(lot_trk,' '),1) lot_trk, rpad(nvl(sysco_shelf_life,' '),4) sysco_shelf_life
        , rpad(nvl(fifo_trk,' '),1) fifo_trk, rpad(nvl(cust_shelf_life,' '),4) cust_shelf_life, rpad(nvl(exp_date_trk,' '),1) exp_date_trk, rpad(nvl(mfg_date_trk,' '),1) mfg_date_trk
        , rpad(nvl(temp_trk,' '),1) temp_trk, rpad(nvl(min_temp,' '),7) min_temp, rpad(nvl(max_temp,' '),7) max_temp 
      from sap_lm_out
      where record_status = 'N' 
	  order by add_date, sequence_number
      --and add_date > to_date('25-FEB-2018', 'FXDD-MON-YYYY')
      FOR UPDATE OF record_status;

  BEGIN
    IF ACTIVE_QUEUE( Queue_lm ) THEN
    --IF true THEN
        -- For each item that has been changed parameters and not sent
        FOR rec_lm IN c_lm_item_wh_params
        LOOP
          BEGIN
            l_Queue_Data := rec_lm.record_type || rec_lm.prod_id || rec_lm.cust_pref_vendor || rec_lm.ti || rec_lm.hi || rec_lm.abc 
               || rec_lm.mfr_shelf_life || rec_lm.pallet_type || rec_lm.lot_trk || rec_lm.sysco_shelf_life || rec_lm.fifo_trk || rec_lm.cust_shelf_life || rec_lm.exp_date_trk
               || rec_lm.mfg_date_trk || rec_lm.temp_trk || rec_lm.min_temp || rec_lm.max_temp;

            -- Write the interface block to the output queue (going to RDC-SUS)
            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number  )
              VALUES ( Queue_lm, l_Queue_Data, rec_lm.seq_no );

            BEGIN
               UPDATE sap_lm_out
               SET record_status = 'S' --'Q'
               WHERE CURRENT OF c_lm_item_wh_params;
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_code := SQLCODE;
                  l_error_msg := SQLERRM;
                  This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Product = '   || rec_lm.prod_id
                           || ', Vendor = '    || rec_lm.cust_pref_vendor
                           || ', Sequence No = ' || rec_lm.seq_no;
                  PL_Log.Ins_Msg( i_Msg_Type     => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );

            END;

          EXCEPTION
            WHEN OTHERS THEN
			dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_lm_out Failed to send Item/Warehouse Parameters for sequence_number '|| rec_lm.seq_no||
			                  ' Item Number ' || rec_lm.prod_id || ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );

              UPDATE sap_lm_out
                 SET record_status = 'F',
                     upd_user = sys_context('USERENV', 'CURRENT_USER'),
                   upd_date = sysdate,
                   error_msg = this_message
                 WHERE CURRENT OF c_lm_item_wh_params;
              COMMIT;
          END;
        END LOOP;

    COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_LM_OUT;

  /*============================================================================
  --
  -- Module Name: SEND_IA_OUT
  --
  -- Description: This procedure send inv adjustment or status change messages to FoodPro
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 04/19/2018 mcha1213      initial version
  -- 4/4/19     mcha1213      adding 11 columns for linux/sus and modify trans_type
  ============================================================================*/
  PROCEDURE SEND_IA_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_INV_ADJ';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);




    cursor c_ia_rec_summary is  
      select sequence_number seq_no,
	  rpad(nvl(trans_type,' '),3) trans_type, rpad(nvl(erm_id,' '),16) erm_id, rpad(nvl(prod_id,' '),9) prod_id, rpad(nvl(cust_pref_vendor,' '), 10) cust_pref_vendor, rpad(nvl(reason_code,' '), 3) reason_code, rpad(nvl(item_seq,' '),3) item_seq, rpad(nvl(uom,' '),1) uom
        , rpad(nvl(qty_expected_sign,' '),1) qty_expected_sign, rpad(nvl(qty_expected,' '),8) qty_expected, rpad(nvl(qty_sign,' '),1) qty_sign, rpad(nvl(qty,' '),8) qty, rpad(nvl(weight_sign,' '),1) weight_sign, rpad(nvl(weight,' '),7) weight, rpad(nvl(order_id,' '),16) order_id
        , rpad(nvl(new_status,' '),3) new_status, rpad(nvl(warehouse_id,' '),3) warehouse_id 
		, rpad(nvl(to_char(mfg_date, 'YYYYMMDD'),' '),8) mfg_date, rpad(nvl(mfg_date_trk,' '),1) mfg_date_trk
		, rpad(nvl(to_char(exp_date, 'YYYYMMDD'),' '),8) exp_date, rpad(nvl(exp_date_trk,' '),1) exp_date_trk
		, rpad(nvl(pallet_id,' '),18) pallet_id, rpad(nvl(trans_id,' '),8) trans_id, rpad(nvl(trailer_temp,' '),6) trailer_temp
		, rpad(nvl(item_temp,' '),6) item_temp		
		-- 4/4/19, rpad(nvl(item_seq,' '),3) item_seq
      from sap_ia_out
      where trans_type in ('PUT', 'CLO', 'COR', 'COW','ADC','CSN','CSQ','CSW','TRP','TRC','TRR','TRW','TPI')
      and record_status = 'N'
	  order by add_date, sequence_number
      --and add_date > to_date('25-FEB-2018', 'FXDD-MON-YYYY')
      FOR UPDATE OF record_status;



    cursor c_ia_inv_trans is
      select sequence_number seq_no,
	  rpad(nvl(trans_type,' '),3) trans_type, rpad(nvl(erm_id,' '),16) erm_id, rpad(nvl(prod_id,' '),9) prod_id, rpad(nvl(cust_pref_vendor,' '), 10) cust_pref_vendor, rpad(nvl(reason_code,' '), 3) reason_code, rpad(nvl(uom,' '),1) uom, rpad(nvl(qty_expected_sign,' '),1) qty_expected_sign, rpad(nvl(qty_expected,' '),8) qty_expected, rpad(nvl(qty_sign,' '),1) qty_sign, 
       rpad(nvl(qty,' '),8) qty, rpad(nvl(user_id,' '),30) user_id, rpad(nvl(new_status,' '),3) new_status, rpad(nvl(warehouse_id,' '),3) warehouse_id
	   , rpad(nvl(to_char(exp_date, 'YYYYMMDD'),' '),8) exp_date, rpad(nvl(home_reserve_flag,' '),1) home_reserve_flag
      from sap_ia_out
      where trans_type in ('ADJ', 'DRP', 'RPK', 'RPC', 'STA')
      and record_status = 'N'
	  order by add_date, sequence_number
      --and add_date > to_date('25-FEB-2018', 'FXDD-MON-YYYY')
      FOR UPDATE OF record_status;    

     --rec_ia    c_ia%ROWTYPE;



  BEGIN


        /*
	PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                  , i_Procedure_Name   => This_Function
                  , i_Msg_Text         => 'pl_spl_out.send_ia_out que = '|| queue_ia
                  , i_Msg_No           => NULL
                  , i_SQL_Err_Msg      => NULL
                  , i_Application_Func => This_Application
                  , i_Program_Name     => This_Package
                  , i_Msg_Alert        => 'N'
                  );
        */


    IF ACTIVE_QUEUE( Queue_ia ) THEN
    --IF true THEN
        -- For each pallet that has been checked in since the last time we ran
        FOR rec_ia IN c_ia_rec_summary
        LOOP
          BEGIN

            l_Queue_Data := rec_ia.trans_type || rec_ia.erm_id || rec_ia.prod_id || rec_ia.cust_pref_vendor || rec_ia.reason_code || rec_ia.item_seq || rec_ia.uom
               || rec_ia.qty_expected_sign || rec_ia.qty_expected || rec_ia.qty_sign || rec_ia.qty || rec_ia.weight_sign || rec_ia.weight || rec_ia.order_id
               || rec_ia.new_status || rec_ia.warehouse_id || rec_ia.mfg_date || rec_ia.mfg_date_trk || rec_ia.exp_date
			   || rec_ia.exp_date_trk || rec_ia.pallet_id || rec_ia.trans_id || rec_ia.trailer_temp 
			   || rec_ia.item_temp;

			   -- 4/4/19 || rec_ia.item_seq;


            -- Write the interface block to the output queue (going to RDC-SUS)
            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number  )
              VALUES ( Queue_ia, l_Queue_Data, rec_ia.seq_no );
              
            
            BEGIN
               UPDATE sap_ia_out
               SET record_status = 'S' --'Q'
               WHERE CURRENT OF c_ia_rec_summary ;
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_code := SQLCODE;
                  l_error_msg := SQLERRM;
                  This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Product = '   || rec_ia.prod_id
                           || ', Vendor = '    || rec_ia.cust_pref_vendor
                           || ', PO = '        || rec_ia.erm_id;
                  PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
            END;              
            
          EXCEPTION
            WHEN OTHERS THEN
			dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_ia_out Failed to send Inventory Adjustment sequence_number '|| rec_ia.seq_no||
			                  ' Item Number ' || rec_ia.prod_id || ' for PO Number ' || rec_ia.erm_id || ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
              UPDATE sap_ia_out
                 SET record_status = 'F',
                     upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate,
                   error_msg = this_message
                 WHERE CURRENT OF c_ia_rec_summary ;
              COMMIT;
                   
          END;



        END LOOP;

        FOR rec_ia1 IN c_ia_inv_trans
        LOOP
          BEGIN
            l_Queue_Data := rec_ia1.trans_type || rec_ia1.erm_id || rec_ia1.prod_id || rec_ia1.cust_pref_vendor || rec_ia1.reason_code || rec_ia1.uom || rec_ia1.qty_expected_sign || rec_ia1.qty_expected || rec_ia1.qty_sign || 
       rec_ia1.qty || rec_ia1.user_id || rec_ia1.new_status || rec_ia1.warehouse_id
	   || rec_ia1.exp_date || rec_ia1.home_reserve_flag;

            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number   )
              VALUES ( Queue_ia, l_Queue_Data, rec_ia1.seq_no );
              
            BEGIN
               UPDATE sap_ia_out
                  SET record_status = 'S' --'Q'
                  WHERE CURRENT OF c_ia_inv_trans ;

            EXCEPTION
               WHEN OTHERS THEN
                  l_error_code := SQLCODE;
                  l_error_msg := SQLERRM;
                  This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Product = '   || rec_ia1.prod_id
                           || ', Vendor = '    || rec_ia1.cust_pref_vendor
                           || ', PO = '        || rec_ia1.erm_id;
                  PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
            END;
            

          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_ia_out Failed to send sap_ia_out sequence_number '|| rec_ia1.seq_no||
			     ' Item Number ' || rec_ia1.prod_id || ' for PO Number ' || rec_ia1.erm_id || ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );  
                            
              UPDATE sap_ia_out
              SET record_status = 'F',
                  upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate,
                   error_msg = this_message
                  WHERE CURRENT OF c_ia_inv_trans ;              
          END;

 
        END LOOP;  

        COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_IA_OUT;


  --
  -- Description: This procedure send Sales Order Processing or status change messages to FoodPro
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -------------------------------------------------------------
  -- 04/30/2018 
  -- 03/26/2019 pkab6563   For Jira card 745, fixed the following to match 
  --                       APCOM OW format:  
  --                       - trans_date format: changed from 'DD-MON-YY' to 'MMDDYY'. 
  --                       - trans_date size: changed from 9 to 6.
  --                       - truck_no size: changed from 10 to 4. 
  --                       - harvest_date format: changed from 'DD-MON-YY' to 'MMDDYY'.
  --                       - harvest_date size: changed from 9 to 6.
  -- 07/18/2019 pkab6563   For Jira card 2456, changed the cursor to use sys_order_line_id
  --                       instead of order_line_id. sys_order_line_id is the order line id
  --                       from the erp system. when sending the data back, the order line 
  --                       id needs to match what they sent to swms. therefore we need to 
  --                       use sys_order_line_id.
  -- 07/22/2019 	   add country_of_origin and wild_farm_desc
  -- 10/03/2019 	   send out country_of_origin and wild_farm_desc if the syspar HOST_SAP_COOL is enabled

  --
  PROCEDURE SEND_OW_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_OW_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);
    l_host_sap_cool_flag   VARCHAR2(1) := 'N';


    cursor c_ow (p_cool_flag varchar2) is  
      select sequence_number seq_no,
	  rpad(nvl(trans_type,' '),3) trans_type, rpad(nvl(to_char(trans_date, 'MMDDYY'),' '),6) trans_date,
	  rpad(nvl(order_id,' '),16) order_id, 
          case 
              when sys_order_line_id is null then rpad(nvl(sys_order_line_id, ' '), 3) 
              else lpad(to_char(to_number(sys_order_line_id)), 3, '0')
          end order_line_id,
	  rpad(nvl(prod_id,' '),9) prod_id, rpad(nvl(cust_pref_vendor,' '), 10) cust_pref_vendor, rpad(nvl(route_no,' '), 10) route_no,
	  rpad(nvl(truck_no,' '), 4) truck_no, rpad(nvl(stop_no,' '), 3) stop_no, rpad(nvl(reason_code,' '), 3) reason_code,
	  rpad(nvl(new_status,' '), 3) new_status, rpad(nvl(sys_order_id,' '), 7) sys_order_id, rpad(nvl(sys_order_line_id,' '), 5) sys_order_line_id,
	  rpad(nvl(uom,' '), 1) uom, rpad(nvl(qty_expected,' '), 8) qty_expected, rpad(nvl(qty,' '), 8) qty, rpad(nvl(weight,' '),9) weight,
	  rpad(nvl(clam_bed_no,' '),10) clam_bed_no, rpad(nvl(user_id,' '),20) user_id, rpad(nvl(to_char(harvest_date, 'MMDDYY'),' '),6) harvest_date,
	  rpad(nvl(sys_order_id_ext,' '),10) sys_order_id_ext, rpad(DECODE(p_cool_flag, 'Y', country_of_origin, ' '),50) country_of_origin,
	  rpad(DECODE(p_cool_flag, 'Y', wild_farm_desc, ' '),11) wild_farm_desc 
      from sap_ow_out
      where record_status = 'N'
	  order by add_date, sequence_number
      FOR UPDATE OF record_status;


  BEGIN

    IF ACTIVE_QUEUE( Queue_ow ) THEN
    --IF true THEN
	l_host_sap_cool_flag := pl_common.f_get_syspar ('HOST_SAP_COOL', 'N');
	-- For each pallet that has been checked in since the last time we ran
        FOR cr_ow IN c_ow (l_host_sap_cool_flag)
        LOOP
          BEGIN
            -- Convert to the interface format
            --l_Queue_Data := rec_ia.trans_type;
            l_Queue_Data := 
               cr_ow.trans_type||cr_ow.trans_date||cr_ow.order_id||cr_ow.order_line_id||cr_ow.prod_id||cr_ow.cust_pref_vendor||cr_ow.route_no||
	           cr_ow.truck_no||cr_ow.stop_no||cr_ow.reason_code||cr_ow.new_status||cr_ow.sys_order_id||cr_ow.sys_order_line_id||
	           cr_ow.uom||cr_ow.qty_expected||cr_ow.qty||cr_ow.weight||cr_ow.clam_bed_no||cr_ow.user_id||cr_ow.harvest_date||
	           cr_ow.sys_order_id_ext||cr_ow.country_of_origin||cr_ow.wild_farm_desc;			

            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number   )
              VALUES ( Queue_ow, l_Queue_Data, cr_ow.seq_no );
              
            BEGIN
               UPDATE sap_ow_out
               SET record_status = 'S'
               WHERE CURRENT OF c_ow;
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_code := SQLCODE;
                  l_error_msg := SQLERRM;
                  This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Order Number = '   || cr_ow.order_id
                           || ', Order Line Number = '    || cr_ow.order_line_id
                           || ', Sequence Number = '        || cr_ow.seq_no;
                  PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
            END;    
            

          EXCEPTION
            WHEN OTHERS THEN
			dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_ow_out Failed to send Order Processing Transaction Sequence Number '||cr_ow.seq_no||
                 			 ' Order Number ' || cr_ow.order_id || ' Order Line Number' || cr_ow.order_line_id||
                          			  ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
              UPDATE sap_ow_out
               SET record_status = 'F',
                  upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate,
                   error_msg = this_message
               WHERE CURRENT OF c_ow;                            
          END;


        END LOOP;  

        COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_OW_OUT;

    --
  -- Description: This procedure send Purchase Order Status Chang to FoodPro
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 05/22/2018 
  --
  PROCEDURE SEND_PW_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_PW_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);



    cursor c_pw is
      select
	  sequence_number seq_no,
	  rpad(nvl(erm_type,' '),3) erm_type,
	  rpad(nvl(erm_id,' '),16) erm_id,
	  rpad(nvl(status,' '), 3) status
      from sap_pw_out
      where record_status = 'N'
	  order by add_date, sequence_number
      --and status in ('VCH','CLO')
      FOR UPDATE OF record_status;


  BEGIN

    IF ACTIVE_QUEUE( Queue_PW ) THEN
    --IF true THEN
        -- For each pallet that has been checked in since the last time we ran
        FOR cr_pw IN c_pw
        LOOP
          BEGIN
            -- Convert to the interface format
            --l_Queue_Data := rec_ia.trans_type;
            l_Queue_Data := 
               cr_pw.erm_type||cr_pw.erm_id||cr_pw.status;		

            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number   )
              VALUES ( Queue_pw, l_Queue_Data, cr_pw.seq_no);
             
            BEGIN
               UPDATE sap_pw_out
               SET record_status = 'S',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate
               WHERE CURRENT OF c_pw;
            EXCEPTION
               WHEN OTHERS THEN
                  l_error_code := SQLCODE;
                  l_error_msg := SQLERRM;
                  This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Purchase Order Number = '   || cr_pw.erm_id
                           || ', Status = '    || cr_pw.status
                           || ', Sequence Number = '        || cr_pw.seq_no;
                  PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
            END;              
            
          EXCEPTION
            WHEN OTHERS THEN
			dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_pw_out Failed to send Purchase Order Status Change Sequence Number '||cr_pw.seq_no||
                 			 ' Purchase Order Number ' || cr_pw.erm_id || ' Status' || cr_pw.status||
                          			  ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
              UPDATE sap_pw_out
               SET record_status = 'F',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate,
                   error_msg = this_message
               WHERE CURRENT OF c_pw;                            
          END;



        END LOOP;  

        COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_PW_OUT;
  
 PROCEDURE SEND_WH_OUT
IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_WH_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);

    CURSOR c_wh IS
      SELECT sequence_number,
             rpad(nvl(rec_type, ' '), 3) rec_type,
             rpad(nvl(prod_id, ' '), 9) prod_id,
             lpad(to_char(nvl(case_on_hand, 0)), 5) case_on_hand,
             lpad(to_char(nvl(split_on_hand, 0)), 3) split_on_hand,
             lpad(to_char(nvl(case_on_hold, 0)), 5) case_on_hold,
             lpad(to_char(nvl(split_on_hold, 0)), 3) split_on_hold,
             rpad(nvl(brand, ' '), 7) brand,
             rpad(nvl(pack, ' '), 4) pack,
             rpad(nvl(prod_size, ' '), 6) prod_size,
             rpad(nvl(descrip, ' '), 30) descrip,
             rpad(nvl(buyer, ' '), 3) buyer,
             rpad(nvl(cust_pref_vendor, ' '), 10) cust_pref_vendor,
             lpad(nvl(upc, ' '), 4, '0') spc
      FROM sap_wh_out
      WHERE record_status = 'N'
	  order by add_date, sequence_number
      FOR UPDATE OF record_status;

  BEGIN

    IF ACTIVE_QUEUE( Queue_wh ) THEN
       FOR cr_wh IN c_wh
       LOOP
          BEGIN
              l_Queue_Data := cr_wh.rec_type || cr_wh.prod_id || cr_wh.case_on_hand || cr_wh.split_on_hand
                  || cr_wh.case_on_hold || cr_wh.split_on_hold || cr_wh.brand || cr_wh.pack || cr_wh.prod_size
                  || cr_wh.descrip || cr_wh.buyer || cr_wh.cust_pref_vendor || cr_wh.spc;

              INSERT INTO mq_queue_out
                     ( sequence_number, Queue_Name, Queue_Data )
                VALUES ( cr_wh.sequence_number, Queue_wh, l_Queue_Data );
              
              UPDATE sap_wh_out
              SET record_status = 'S' --'Q'
              WHERE CURRENT OF c_wh;    
              
          EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_wh_out Failed to send Item Recon data for item <' || TRIM(cr_wh.prod_id) || '>'
                              || ' to mq_queue_out.';

              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
              UPDATE sap_wh_out
              SET record_status = 'F',
                  upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate,
                   error_msg = this_message
              WHERE CURRENT OF c_wh;                                
          END;

        END LOOP;  

        COMMIT;

    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_WH_OUT;

 
  -- Description: This procedure send Purchase Order Status Chang to FoodPro
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 05/22/2018 
PROCEDURE SEND_RT_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_RT_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);


    cursor c_RT is
    select
    sequence_number seq_no,
    rpad(nvl(trans_type,' '),3) trans_type ,
    rpad(nvl(item,' '),9) item,
    rpad(nvl(CPV,' '),10) cpv,
    rpad(nvl(to_char(trans_date, 'MMDDYY'),' '),6) trans_date,
    rpad(nvl(to_char(Stop_no),' '),3 ) stop_no,
    rpad(nvl(Route_no,' '),10) route_no,
    rpad(nvl(Order_id,' '),16) order_id,
    rpad(nvl(Reason_code,' '),3) reason_code,
    rpad(nvl(New_status,' '),3) new_status,
    rpad(nvl(Adj_flag,' '),1) adj_flag,
    rpad(nvl(Order_type,' '),1) order_type,
    rpad(nvl(to_char(Split_ind),' '),1) split_ind,
    rpad(nvl(to_char(qty),' '),4) qty,
    rpad(nvl(to_char(weight),' '),9) weight,
    rpad(nvl(Returned_item,' '),9) returned_item,
    rpad(nvl(to_char(Manifest_no),' '),12) manifest_no
    from sap_rt_out
      where record_status = 'N'
	  order by add_date, sequence_number
--      and status in ('VCH','CLO')
      FOR UPDATE OF record_status;


  BEGIN

    IF  ACTIVE_QUEUE( Queue_RT ) THEN
    --IF true THEN
        -- For each pallet that has been checked in since the last time we ran
        FOR cr_RT IN c_RT
        LOOP
          BEGIN
            -- Convert to the interface format
            --l_Queue_Data := rec_ia.trans_type;
            l_Queue_Data := 
                cr_rt.trans_type    ||
                cr_rt.item    ||
                cr_rt.CPV    ||
                cr_rt.Trans_Date    ||
                cr_rt.Stop_no    ||
                cr_rt.Route_no    ||
                cr_rt.Order_id    ||
                cr_rt.Reason_code    ||
                cr_rt.New_status    ||
                cr_rt.Adj_flag    ||
                cr_rt.Order_type    ||
                cr_rt.Split_ind    ||
                cr_rt.qty    ||
                cr_rt.weight    ||
                cr_rt.Returned_item    ||
                cr_rt.Manifest_no ;


            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number   )
              VALUES ( Queue_rt, l_Queue_Data, cr_rt.seq_no );
              
             
            BEGIN
            
               UPDATE sap_RT_out
               SET record_status = 'S', -- 'Q',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate
               WHERE CURRENT OF c_RT;
              
            EXCEPTION
            WHEN OTHERS THEN
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'Failed to mark transaction as confirmed for'
                           || ', Manifest Number = '   || cr_RT.manifest_no
                           || ', Trans Type = '        || cr_rt.trans_type ;
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
          END;  
          
          EXCEPTION
            WHEN OTHERS THEN
            dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'sap_rt_out Failed to send  Trans Type = ' || cr_rt.trans_type ||
                              ' Manifest No: ' || cr_rt.Manifest_no|| ' Item' || cr_RT.item||
                                        ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
               UPDATE sap_RT_out
               SET record_status = 'F',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate
                   -- FP not using Return need to add error_msg to sap_rt_out ,error_msg = this_message
               WHERE CURRENT OF c_RT;                            
                            
                            
          END;

        END LOOP;  

        COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END SEND_RT_OUT;
  
      -- Description: This procedure send Customer Location to Meat company
  --
  -- Modification History:
  -- Date       Developer  Description
  -- ---------- ---------- -----------------------------------------------------
  -- 04/01/2019  xzhe5043  
  ------------------------------------------------------------------------------
PROCEDURE MEAT_CL_OUT
   IS
    This_Function          CONSTANT  VARCHAR2(30 CHAR) := 'SEND_CL_OUT';
    This_Message           VARCHAR2(200);
    l_Queue_data           CLOB;
    l_error_code           NUMBER;
    l_error_msg            VARCHAR2(500);


    cursor cur_CL is
    select
    sequence_number seq_no,
	rpad(nvl(FUNC_CODE,' '), 1) FUNC_CODE,
    rpad(nvl(CUST_ID,' '),10) CUST_ID ,
	rpad(nvl(STAGING_LOC,' '),10) STAGING_LOC ,
	rpad(nvl(RACK_CUT_LOC,' '),10) RACK_CUT_LOC ,
	rpad(nvl(WILLCALL_LOC ,' '),10) WILLCALL_LOC 
    from meat_CL_out
       where record_status = 'N'
      FOR UPDATE OF record_status;
    

  BEGIN

    IF  ACTIVE_QUEUE( Queue_CL ) THEN
    --IF true THEN
        FOR cr_CL IN cur_CL
        LOOP
          BEGIN
            -- Convert to the interface format
            l_Queue_Data := 
			    cr_CL.FUNC_CODE	     ||
				cr_CL.CUST_ID		||
				cr_CL.STAGING_LOC		||
				cr_CL.RACK_CUT_LOC		||
				cr_CL.WILLCALL_LOC			;


            INSERT INTO mq_queue_out
                     ( Queue_Name    , Queue_Data, sequence_number   )
              VALUES ( Queue_CL, l_Queue_Data, cr_CL.seq_no );
              
             
            BEGIN
            
               UPDATE MEAT_CL_OUT
               SET record_status = 'S', -- 'Q',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate
               WHERE CURRENT OF cur_CL;
              
            EXCEPTION
            WHEN OTHERS THEN
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'meat_CL_out Failed to send  cust_id = ' || cr_CL.cust_id ||
                              ' RACK_CUT_LOC: ' || cr_CL.RACK_CUT_LOC|| ' STAGING_LOC: ' || cr_CL.STAGING_LOC||
							  ' WILLCALL_LOC: ' || cr_CL.WILLCALL_LOC ;
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
          END;  
          
          EXCEPTION
            WHEN OTHERS THEN
            dbms_output.put_line('error');
              l_error_code := SQLCODE;
              l_error_msg := SQLERRM;
              This_Message := 'meat_CL_out Failed to send  cust_id = ' || cr_CL.cust_id ||
                              ' RACK_CUT_LOC: ' || cr_CL.RACK_CUT_LOC|| ' STAGING_LOC: ' || cr_CL.STAGING_LOC||
							  ' WILLCALL_LOC: ' || cr_CL.WILLCALL_LOC ||
                                        ' to mq_queue_out';
              PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Warn_Msg
                            , i_Procedure_Name   => This_Function
                            , i_Msg_Text         => This_Message
                            , i_Msg_No           => l_error_code
                            , i_SQL_Err_Msg      => l_error_msg
                            , i_Application_Func => This_Application
                            , i_Program_Name     => This_Package
                            );
                            
               UPDATE meat_CL_out
               SET record_status = 'F',
                   upd_user = sys_context('USERENV', 'CURRENT_USER'),                   
                   upd_date = sysdate
                   -- FP not using Return need to add error_msg to meat_CL_out ,error_msg = this_message
               WHERE CURRENT OF cur_CL;                            
                            
                            
          END;

        END LOOP;  

        COMMIT;
    ELSE --Inactive queue
        g_error_context:= 'SWMS is Currently Under Maintanance, Interface is Turned Off.';
        PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                      , i_Procedure_Name   => This_Function
                      , i_Msg_Text         => g_error_context
                      , i_Msg_No           => NULL
                      , i_SQL_Err_Msg      => NULL
                      , i_Application_Func => This_Application
                      , i_Program_Name     => This_Package
                      , i_Msg_Alert        => 'N'
                      );
    END IF;
  END MEAT_CL_OUT;

END PL_SPL_OUT;
/
show errors
