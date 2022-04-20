CREATE OR REPLACE PACKAGE pl_spl_cu_in 
IS
  /*===========================================================================================================
  -- Package
  -- pl_sap_cu_in
  --
  -- Description
  --  This package processes the customer master data from FoodPro to sap_cu_in table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/13/18        mcha1213      Initial version       
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  PROCEDURE parse_cu(  i_message    IN   VARCHAR2
                             , i_sequence_no   IN   NUMBER );



END pl_spl_cu_in;

/


CREATE OR REPLACE PACKAGE BODY  pl_spl_cu_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_spl_cu_in
  --
  -- Description
  --  
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/13/18        mcha1213      Initial version       
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_cu(   i_message   IN   VARCHAR2
							, i_sequence_no      IN   NUMBER 
					       )
 /*===========================================================================================================
  -- PROCEDURE
  -- parse_cu
  --
  -- Description
  --   This Procedure parses the cu and places it in the staging table(sap_cu_in).
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   4/13/18        mcha1213      Initial version       
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  process_error            EXCEPTION;
  l_sequence_number        sap_cu_in.sequence_number%type;



  CURSOR c_cu
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  cust_ind                                
          , to_char(Rtrim( Substr( i_message, 2,10), ' '))    cust_id                    
          , to_char(Rtrim( Substr( i_message, 12,10), ' '))    monday_route_no                    
          , to_char(Rtrim( Substr( i_message, 22,10), ' '))    tuesday_route_no  
          , to_char(Rtrim( Substr( i_message, 32,10), ' '))    wednesday_route_no
          , to_char(Rtrim( Substr( i_message, 42,10), ' '))   thursday_route_no     
          , to_char(Rtrim( Substr( i_message, 52,10), ' '))   friday_route_no        
          , to_char(Rtrim( Substr( i_message, 62,10), ' '))   saturday_route_no
          , to_char(Rtrim( Substr( i_message, 72,10), ' '))   sunday_route_no        
          , to_char(Rtrim( Substr( i_message, 82,30), ' '))   cust_name
          , to_char(Rtrim( Substr( i_message, 112,30), ' '))  cust_contact 
          , to_char(Rtrim( Substr( i_message, 142,40), ' '))    cust_addr1                   
          , to_char(Rtrim( Substr( i_message, 182,40), ' '))    cust_addr2  
          , to_char(Rtrim( Substr( i_message, 222,40), ' '))    cust_addr3
          , to_char(Rtrim( Substr( i_message, 262,20), ' '))   cust_city     
          , to_char(Rtrim( Substr( i_message, 282,2), ' '))   cust_state       
          , to_char(Rtrim( Substr( i_message, 284,10), ' '))   cust_zip
          , to_char(Rtrim( Substr( i_message, 294,10), ' '))   cust_cntry        
          , to_char(Rtrim( Substr( i_message, 304,30), ' '))   ship_name
          , to_char(Rtrim( Substr( i_message, 334,80), ' '))  ship_addr1	  
         , to_char(Rtrim( Substr( i_message, 414,40), ' '))  ship_addr2	 		  
         , to_char(Rtrim( Substr( i_message, 454,160), ' '))  ship_addr3	 
         , to_char(Rtrim( Substr( i_message, 614,20), ' '))  ship_city	 
         , to_char(Rtrim( Substr( i_message, 634,2), ' '))  ship_state
         , to_char(Rtrim( Substr( i_message, 636,10), ' '))  ship_zip
         , to_char(Rtrim( Substr( i_message, 646,10), ' '))  ship_cntry
         , to_char(Rtrim( Substr( i_message, 656,1), ' '))  status	
          , to_char(Rtrim( Substr( i_message, 657,10), ' '))    monday_stop_no                    
          , to_char(Rtrim( Substr( i_message, 687,10), ' '))    tuesday_stop_no  
          , to_char(Rtrim( Substr( i_message, 697,10), ' '))    wednesday_stop_no
          , to_char(Rtrim( Substr( i_message, 707,10), ' '))   thursday_stop_no     
          , to_char(Rtrim( Substr( i_message, 717,10), ' '))   friday_stop_no        
          , to_char(Rtrim( Substr( i_message, 727,10), ' '))   saturday_stop_no
          , to_char(Rtrim( Substr( i_message, 737,10), ' '))   sunday_stop_no 		 
	    FROM dual;


BEGIN

   l_sequence_number := i_sequence_no;
   
   /*                                            
   PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_cu_in.parse_cu'
                        , i_Msg_Text         => 'before the for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing CU In'
                        , i_Program_Name     => 'pl_spl_cu_in.parse_cu'
                        , i_Msg_Alert        => 'N'
                        );                                            
   */

	 FOR cu_rec IN c_cu
	  LOOP
      
      
		    insert into sap_cu_in
			  (cust_ind, cust_id, monday_route_no, tuesday_route_no, wednesday_route_no, thursday_route_no, friday_route_no, saturday_route_no,
		       sunday_route_no, cust_name, cust_contact, cust_addr1, cust_addr2, cust_addr3, cust_city, cust_state, cust_zip, cust_cntry,
			   ship_name, ship_addr1, ship_addr2, ship_addr3, ship_city, ship_state, ship_zip, ship_cntry, status, monday_stop_no,
			   tuesday_stop_no, wednesday_stop_no, thursday_stop_no, friday_stop_no, saturday_stop_no, sunday_stop_no,
				--add_date, --add_user,
				datetime, sequence_number, upd_date, upd_user, interface_type, record_status)
		    values
                (cu_rec.cust_ind, cu_rec.cust_id, cu_rec.monday_route_no, cu_rec.tuesday_route_no, cu_rec.wednesday_route_no,
				 cu_rec.thursday_route_no, cu_rec.friday_route_no, cu_rec.saturday_route_no, cu_rec.sunday_route_no, cu_rec.cust_name,
				 cu_rec.cust_contact, cu_rec.cust_addr1, cu_rec.cust_addr2, cu_rec.cust_addr3, cu_rec.cust_city, cu_rec.cust_state,
				 cu_rec.cust_zip, cu_rec.cust_cntry, cu_rec.ship_name, cu_rec.ship_addr1, cu_rec.ship_addr2, cu_rec.ship_addr3,
				 cu_rec.ship_city, cu_rec.ship_state, cu_rec.ship_zip, cu_rec.ship_cntry, cu_rec.status, cu_rec.monday_stop_no,
				 cu_rec.tuesday_stop_no, cu_rec.wednesday_stop_no, cu_rec.thursday_stop_no, cu_rec.friday_stop_no, cu_rec.saturday_stop_no,
                  cu_rec.sunday_stop_no, sysdate, l_sequence_number, sysdate, user, 'CU','N'
				-- cu_rec.sunday_stop_no, sysdate, sap_cu_seq.nextval, sysdate, user, 'CU','N'
				 );
                 
            /*
            PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_cu_in.parse_cu'
                        , i_Msg_Text         => 'in the for loop after insert to sap_cu_in'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing CU In'
                        , i_Program_Name     => 'pl_spl_cu_in.parse_cu'
                        , i_Msg_Alert        => 'N'
                        );                                                             
            */

	  END LOOP;
      
      --commit; -- do the commit in pl_spl_in package?
      
      /*
      PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_cu_in.parse_cu'
                        , i_Msg_Text         => 'after the for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing CU In'
                        , i_Program_Name     => 'pl_spl_cu_in.parse_cu'
                        , i_Msg_Alert        => 'N'
                        );                                     
      */


EXCEPTION

WHEN OTHERS THEN

  l_error_msg:= 'Error: pl_spl_cu_in when others Exception';
  l_error_code:= SUBSTR(SQLERRM,1,100);   
  pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_cu', l_error_msg,
											SQLCODE, SQLERRM,
											'cu',
											'pl_spl_cu_in',
											'N');
  UPDATE mq_queue_in
     SET record_status   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
     WHERE sequence_number = l_sequence_number;
		
    Commit;

END parse_cu;


END pl_spl_cu_in;
/
