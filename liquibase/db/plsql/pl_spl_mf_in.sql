CREATE OR REPLACE PACKAGE pl_spl_mf_in 
IS
  /*===========================================================================================================
  -- Package
  -- pl_sap_mf_in
  --
  -- Description
  --  This package processes the manifest data from Asian Foods to sap_mf_in table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   6/14/18        mcha1213      Initial version            
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  PROCEDURE parse_mf(  i_message      IN   VARCHAR2
                     , i_sequence_no  IN   NUMBER );


END pl_spl_mf_in;
/


CREATE OR REPLACE PACKAGE BODY  pl_spl_mf_in
IS
  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_mf(   i_message     IN   VARCHAR2
                    , i_sequence_no IN   NUMBER 
					       )
 /*===========================================================================================================
  -- PROCEDURE
  -- parse_mf
  --
  -- Description
  --   This Procedure parses the manifest data and places it in the staging table(sap_mf_in).
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   6/14/18        mcha1213      Initial Creation
  --   8/29/18        pkab6563      Trimmed leading zeroes for invoice amount, invoice cube, 
  --                                and invoice weight.
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  process_error            EXCEPTION;
  l_sequence_number        NUMBER;


  CURSOR c_mf
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type   
          , to_char(Substr( i_message, 2,7))    manifest_no       
          --, to_char(Rtrim( Substr( i_message, 2,7), ' '))    manifest_no                   
          , to_char(Rtrim( Substr( i_message, 9,16), ' '))    obligation_no                  
          , to_char(ltrim( Substr( i_message, 25,9), ' '))    prod_id
          --, to_char(rtrim( Substr( i_message, 25,9), ' '))    prod_id
          , to_char(Rtrim( Substr( i_message, 34,10), ' '))    cust_pref_vendor
          , to_char(Substr( i_message, 44,3))   stop_no
          --, to_char(Rtrim( Substr( i_message, 44,3), ' '))   stop_no    
          , to_char(Rtrim( Substr( i_message, 47,10), ' '))   route_no       
          , to_char(Rtrim( Substr( i_message, 57,1), ' '))   shipped_split_cd
          , to_char(Substr( i_message, 58,5))   shipped_qty   
          --, to_char(Rtrim( Substr( i_message, 58,5), ' '))   shipped_qty  
          , to_char(Rtrim( Substr( i_message, 63,3), ' '))   reason_code
          , to_char(Rtrim( Substr( i_message, 66,3), ' '))  disposition
          , to_char(Rtrim( Substr( i_message, 69,16), ' '))    orig_invoice                  
          , to_char(Rtrim( Substr( i_message, 85,16), ' '))    invoice_no
	    FROM dual;


  CURSOR c_mf_stops
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type   
          , to_char(Substr( i_message, 2,7))    manifest_no       
          --, to_char(Rtrim( Substr( i_message, 2,7), ' '))    manifest_no
          , to_char(Substr( i_message, 9,3))    stop_no             
          , to_char(Rtrim( Substr( i_message, 12,16), ' '))    obligation_no                  
          , to_char(rtrim( Substr( i_message, 28,16), ' '))    invoice_no
          , to_char(ltrim( Substr( i_message, 44,14), ' '))    customer_id
          , to_char(Rtrim( Substr( i_message, 58,30), ' '))    customer
          , to_char(Rtrim( Substr( i_message, 88,30), ' '))    addr_line_1
          , to_char(Rtrim( Substr( i_message, 118,30), ' '))    addr_line_2          
          , to_char(Rtrim( Substr( i_message, 148,20), ' '))    addr_city
          , to_char(Rtrim( Substr( i_message, 168,3), ' '))    addr_state
          , to_char(Rtrim( Substr( i_message, 171,10), ' '))    addr_postal_code
          , to_char(Rtrim( Substr( i_message, 181,9), ' '))    salesperson_id
          , to_char(Rtrim( Substr( i_message, 190,30), ' '))    salesperson
          , to_char(Rtrim( Substr( i_message, 220,6), ' '))    time_in
          , to_char(Rtrim( Substr( i_message, 226,6), ' '))    time_out
          , to_char(Rtrim( Substr( i_message, 232,4), ' '))    business_hrs_from
          , to_char(Rtrim( Substr( i_message, 236,4), ' '))    business_hrs_to                            
          , to_char(Rtrim( Substr( i_message, 240,30), ' '))    terms
          , to_char(Substr( i_message, 270,5))    shipped_qty 
          , to_char(Ltrim(Substr( i_message, 275,9), '0'))    invoice_amt  
          , to_char(Ltrim(Substr( i_message, 284,13), '0'))    invoice_cube
          , to_char(Ltrim(Substr( i_message, 297,9), '0'))    invoice_wgt
          , to_char(Rtrim( Substr( i_message, 306,160), ' '))    notes
	    FROM dual;        

BEGIN

   l_sequence_number := i_sequence_no;

   if to_char(Rtrim( Substr( i_message, 1,1), ' ')) in ('I', 'P') then

	 FOR cmf_rec IN c_mf
	  LOOP

		    insert into sap_mf_in
			(rec_type, manifest_no, obligation_no, prod_id, cust_pref_vendor, stop_no, route_no,
			 shipped_split_cd, shipped_qty, reason_code, disposition, orig_invoice, invoice_no,
			 datetime, sequence_number, upd_date, upd_user, interface_type, record_status)
			values
			(cmf_rec.rec_type, cmf_rec.manifest_no, cmf_rec.obligation_no, cmf_rec.prod_id, cmf_rec.cust_pref_vendor,
			 cmf_rec.stop_no, cmf_rec.route_no, cmf_rec.shipped_split_cd, cmf_rec.shipped_qty, cmf_rec.reason_code,
			 cmf_rec.disposition, cmf_rec.orig_invoice, cmf_rec.invoice_no,
			 sysdate, l_sequence_number, sysdate, user, 'MF','N');			
	   end loop;	


       /*
       PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_mf_in.parse_mf'
                        , i_Msg_Text         => 'after the c_mf for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing MF In'
                        , i_Program_Name     => 'pl_spl_mf_in.parse_mf'
                        , i_Msg_Alert        => 'N'
                        );                                     
      */

   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'S' then  


   	 FOR cmfs_rec IN c_mf_stops
	  LOOP

		    insert into sap_mf_in
			(rec_type, manifest_no, stop_no, obligation_no, invoice_no, customer_id,
             customer, addr_line_1, addr_line_2, addr_city, addr_state, addr_postal_code,
             salesperson_id, salesperson, time_in, time_out, business_hrs_from, 
             business_hrs_to, terms, shipped_qty, invoice_amt, invoice_cube,
             invoice_wgt, notes,
			 datetime, sequence_number, upd_date, upd_user, interface_type, record_status)
			values
			(cmfs_rec.rec_type, cmfs_rec.manifest_no, cmfs_rec.stop_no, cmfs_rec.obligation_no, cmfs_rec.invoice_no, cmfs_rec.customer_id,
             cmfs_rec.customer, cmfs_rec.addr_line_1, cmfs_rec.addr_line_2, cmfs_rec.addr_city, cmfs_rec.addr_state, cmfs_rec.addr_postal_code,
             cmfs_rec.salesperson_id, cmfs_rec.salesperson, cmfs_rec.time_in, cmfs_rec.time_out, cmfs_rec.business_hrs_from, 
             cmfs_rec.business_hrs_to, cmfs_rec.terms, cmfs_rec.shipped_qty, cmfs_rec.invoice_amt, cmfs_rec.invoice_cube,
             cmfs_rec.invoice_wgt, cmfs_rec.notes,
			 sysdate, l_sequence_number, sysdate, user, 'MF','N');	

	   end loop;	


       /*
       PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_mf_in.parse_mf'
                        , i_Msg_Text         => 'after the c_mf_stops for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing MF In'
                        , i_Program_Name     => 'pl_spl_mf_in.parse_mf'
                        , i_Msg_Alert        => 'N'
                        );    
       */
   end if;                     


EXCEPTION
   WHEN OTHERS THEN
  --ROLLBACK; 
     l_error_msg:= 'Error: PL_SPL_MF_IN when others Exception';
     l_error_code:= SUBSTR(SQLERRM,1,100);   
     pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_cmf', l_error_msg,
                      SQLCODE, SQLERRM,
                      'mf',
                      'pl_spl_mf_in',
                      'u');

     UPDATE mq_queue_in
          SET record_status   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
        WHERE sequence_number = l_sequence_number;

     Commit;

END parse_mf;

END pl_spl_mf_in;
/
