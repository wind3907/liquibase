CREATE OR REPLACE PACKAGE pl_spl_or_in 
IS
  /*===========================================================================================================
  -- Package
  -- 	pl_spl_or_in
  --
  -- Description
  --  	This package processes the Order Information from FoodPro to SAP_OR_IN table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/24/18        mcha1213      Initial version            
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --   12/20/18       xzhe5043      Jira #688 - Add Batch_record_count 
  --   06/14/19		  sban3548		Jira OPCOF-2268 - Do NOT consider Batch record count for FoodPro orders
  --
  ============================================================================================================*/

  PROCEDURE parse_or(i_message    	IN   VARCHAR2
                   , i_sequence_no  IN   NUMBER );

END pl_spl_or_in;
/

CREATE OR REPLACE PACKAGE BODY  pl_spl_or_in
IS
  /*===========================================================================================================
  -- Package Body
  -- 	pl_spl_or_in
  --
  -- Description
  --	This package processes the Order Information from FoodPro to SAP_OR_IN table
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/24/18        mcha1213      Initial version            
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --   12/20/18       xzhe5043      Jira #688 - Add Batch_record_count 
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_or(i_message   		IN   VARCHAR2
				 , i_sequence_no    IN   NUMBER ) 
 /*===========================================================================================================
  -- PROCEDURE
  -- parse_or
  --
  -- Description
  --   This Procedure parses the or and places it in the staging table(sap_or_in).
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/24/18        mcha1213      Initial version            
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --   06/14/19		  sban3548		Jira OPCOF-2268 - Do NOT consider Batch record count for FoodPro orders
  --
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  process_error            EXCEPTION;
  l_sequence_number        NUMBER;

  l_weight             sap_or_in.weight%type;

  CURSOR c_or_h
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_ind                                
          , to_char(Rtrim( Substr( i_message, 2,16), ' '))    order_id
          , to_char(Ltrim( Substr( i_message, 18,14), ' '))    cust_id     
          --, to_char(Rtrim( Substr( i_message, 18,14), ' '))    cust_id                   
          , to_char(Rtrim( Substr( i_message, 32,6), ' '))    ship_date
          , to_char(Rtrim( Substr( i_message, 38,6), ' '))    del_date
          , to_char(Rtrim( Substr( i_message, 44,4), ' '))   del_time  
          , to_char(Rtrim( Substr( i_message, 48,10), ' '))   route_no    
          , to_char(Rtrim( Substr( i_message, 58,8), ' '))   truck_no          
          , to_char(ltrim( Substr( i_message, 66,7), '0'))   stop_no     
          , to_char(Rtrim( Substr( i_message, 73,3), ' '))   truck_type
          , TO_CHAR(LTRIM(SUBSTR(i_message, 76, 9), '0')) weight  
         -- , to_char(Rtrim( Substr( i_message, 74,9), ' '))  weight 
          , to_char(Rtrim( Substr( i_message, 85,3), ' '))    order_type                   
          , to_char(Rtrim( Substr( i_message, 88,1), ' '))    immediate_ind  
          , to_char(Rtrim( Substr( i_message, 89,1), ' '))    delivery_method
          , to_char(Rtrim( Substr( i_message, 90,20), ' '))   cust_po     
          , to_char(Rtrim( Substr( i_message, 110,30), ' '))   cust_name       
          , to_char(Rtrim( Substr( i_message, 140,30), ' '))   cust_addr1
          , to_char(Rtrim( Substr( i_message, 170,30), ' '))   cust_addr2        
          , to_char(Rtrim( Substr( i_message, 200,20), ' '))   cust_city
          , to_char(Rtrim( Substr( i_message, 220,3), ' '))  cust_state	  
         , to_char(Rtrim( Substr( i_message, 223,10), ' '))  cust_zip	 		  
         , to_char(Rtrim( Substr( i_message, 233,5), ' '))  slsm	 
         , to_char(Rtrim( Substr( i_message, 238,1), ' '))  unitize_ind	 
         , to_char(Rtrim( Substr( i_message, 239,1), ' '))  frz_special
         , to_char(Rtrim( Substr( i_message, 240,1), ' '))  dry_special
         , to_char(Rtrim( Substr( i_message, 241,1), ' '))  clr_special 
         , To_Char(Rtrim( Substr( I_Message, 242,36), ' '))  Msg_Id 
         , DECODE(pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N'), 'Y', NULL, 
				to_char(ltrim (substr( i_message, 278,4), '0')))  batch_record_count
	    FROM dual;


  CURSOR c_or_d
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_ind                                
          , to_char(Rtrim( Substr( i_message, 2,16), ' '))    order_id   
           , to_char(Substr( i_message, 18,10))    sys_order_id                   
        -- , to_char(Rtrim( Substr( i_message, 18,10), ' '))    sys_order_id   
        --  , to_char(Substr( i_message, 28,5))    sys_order_line_id         
          , TO_CHAR(LTRIM(SUBSTR(i_message, 28, 5), '0')) sys_order_line_id             
        --  , to_char(Rtrim( Substr( i_message, 28,5), ' '))    sys_order_line_id
          , to_char(Rtrim( Substr( i_message, 33,9), ' '))    prod_id
          , to_char(Rtrim( Substr( i_message, 42,10), ' '))   cust_pref_vendor
          , TO_CHAR(LTRIM(SUBSTR(i_message, 52, 4), '0')) qty_ordered        
        --  , to_char(Rtrim( Substr( i_message, 52,4), ' '))   qty_ordered       
          , to_char(Rtrim( Substr( i_message, 56,1), ' '))   uom
          , to_char(Rtrim( Substr( i_message, 57,1), ' '))   area        
          , to_char(Rtrim( Substr( i_message, 58,1), ' '))   cw_type
          , to_char(Rtrim( Substr( i_message, 59,1), ' '))   qa_ticket_ind 
          , to_char(Rtrim( Substr( i_message, 60,1), ' '))    partial                  
          , to_char(Rtrim( Substr( i_message, 61,1), ' '))    pcl_flag  
          , to_char(Rtrim( Substr( i_message, 62,14), ' '))    pcl_id          
          , to_char(Rtrim( Substr( i_message, 76,10), ' '))  route_no
          , To_Char(Rtrim( Substr( I_Message, 86,36), ' '))  Msg_Id 
          , DECODE(pl_common.f_get_syspar('ENABLE_FINISH_GOODS', 'N'), 'Y', NULL, 
				to_char(ltrim (Substr( i_message, 122,4), '0')))  batch_record_count 
	    FROM dual;

BEGIN

   l_sequence_number := i_sequence_no;
   


   if to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'H' then
   
             -- DBMS_output.put_line('in pl_spl_im_in.parse_or header');
             /* 
            insert into sap_or_in
			(SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE)
			values
            (l_sequence_number, SYSDATE, 'N', 'OR');
            */
            
     
	 FOR ch_rec IN c_or_h
	  LOOP
           /*
           DBMS_output.put_line('in ch_rec loop');
           DBMS_output.put_line('ch_rec.REC_IND '||ch_rec.REC_IND);
           DBMS_output.put_line('ch_rec.ORDER_ID '||ch_rec.ORDER_ID); 
           DBMS_output.put_line('ch_rec.CUST_ID '||ch_rec.CUST_ID); 
           */
           
            if ch_rec.weight is not null then          
               l_weight := substr(ch_rec.weight, 1, length(ch_rec.weight) -3 )||'.'||substr(ch_rec.weight, -3);
            else
               l_weight := null;
            end if;   
           
		    insert into sap_or_in
			(SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE
             ,REC_IND, ORDER_ID, CUST_ID, SHIP_DATE, DEL_DATE, DEL_TIME, ROUTE_NO, TRUCK_NO, STOP_NO,
			 TRUCK_TYPE, WEIGHT, ORDER_TYPE, IMMEDIATE_IND, DELIVERY_METHOD, CUST_PO,
			 Cust_Name, Cust_Addr1 , Cust_Addr2, Cust_City , Cust_State,Cust_Zip,
			 SLSM, UNITIZE_IND, FRZ_SPECIAL, DRY_SPECIAL, CLR_SPECIAL, MSG_ID, batch_record_count) 
		     values
             (l_sequence_number, SYSDATE, 'N', 'OR',
              ch_rec.REC_IND, ch_rec.ORDER_ID, ch_rec.CUST_ID, ch_rec.SHIP_DATE, ch_rec.DEL_DATE, ch_rec.DEL_TIME, ch_rec.ROUTE_NO,
			 ch_rec.TRUCK_NO, ch_rec.STOP_NO,
			 ch_rec.TRUCK_TYPE, l_weight, ch_rec.ORDER_TYPE, ch_rec.IMMEDIATE_IND, ch_rec.DELIVERY_METHOD, ch_rec.CUST_PO,             
             Ch_Rec.Cust_Name, Ch_Rec.Cust_Addr1 , Ch_Rec.Cust_Addr2, Ch_Rec.Cust_City , Ch_Rec.Cust_State, Ch_Rec.Cust_Zip,
			 ch_rec.SLSM, ch_rec.UNITIZE_IND, ch_rec.FRZ_SPECIAL, ch_rec.DRY_SPECIAL, ch_rec.CLR_SPECIAL, ch_rec.MSG_ID, ch_rec.batch_record_count);	
             
	  end loop;
       
       --*/

   else

     FOR cd_rec IN c_or_d
	  LOOP
   		    insert into sap_or_in			
			(SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE,
            Rec_Ind, Order_Id, Order_Line_Id, Sys_Order_Id, Sys_Order_Line_Id, Prod_Id, Cust_Pref_Vendor, Qty_Ordered, Uom,
 			AREA, CW_TYPE, QA_TICKET_IND, PARTIAL,PCL_FLAG,PCL_ID, route_no, msg_id, batch_record_count )
			values
			(l_sequence_number, SYSDATE, 'N', 'OR',
            cd_rec.REC_IND, cd_rec.ORDER_ID, cd_rec.SYS_ORDER_LINE_ID , cd_rec.ORDER_ID, cd_rec.SYS_ORDER_LINE_ID, cd_rec.PROD_ID, cd_rec.CUST_PREF_VENDOR, 
			Cd_Rec.Qty_Ordered, Cd_Rec.Uom, Cd_Rec.Area, Cd_Rec.Cw_Type, Cd_Rec.Qa_Ticket_Ind, Cd_Rec.Partial,
 			cd_rec.PCL_FLAG, cd_rec.PCL_ID, cd_rec.route_no, cd_rec.msg_id,  cd_rec.batch_record_count);
	   end loop;   


   end if;
   
   
   /*
   l_error_msg := 'Processing CU for Queue Success ';
   l_error_code:= '';   
   pl_log.ins_msg(   pl_log.ct_info_msg
                   , 'parse_sus_vendor'
				   , 'Processing CU for Queue Success '
				   , SQLCODE
				   , SQLERRM
				   , 'INVENTORY'
				   , 'pl_spl_cu_in'
				   ,'N'
				   );


    UPDATE mq_queue_in											
          SET record_status   = 'S',
              error_msg       = l_error_msg,
              error_code      = l_error_code
        WHERE sequence_number = l_sequence_number;
	-- Commit;
    */
EXCEPTION
   WHEN OTHERS THEN
  --ROLLBACK; 
     l_error_msg:= 'Error: PL_SPL_OR_IN when others Exception';
     l_error_code:= SUBSTR(SQLERRM,1,100);   
     pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_or', l_error_msg,
											SQLCODE, SQLERRM,
											'or',
											'pl_spl_or_in',
											'N');
     UPDATE mq_queue_in
          SET record_status   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
        WHERE sequence_number = l_sequence_number;
     Commit;

END parse_or;


END pl_spl_or_in;
/
