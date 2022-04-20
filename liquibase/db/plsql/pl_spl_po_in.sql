CREATE OR REPLACE PACKAGE pl_spl_po_in 
IS
  /*===========================================================================================================
  -- Package
  -- pl_spl_po_in
  --
  -- Description
  --  This package processes the PO data into the sap_po_in table.
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 5/17/18            mcha1213 			     1.0             
  -- 12/12/18           sban3548                                 Jira#640: Added last_fg_po flag for SUS/PRIME
  -- 04/01/10          xzhe5043                                  Jira#788: Added sort_ind 
  -- 03/17/20          pkab6563                                  Jira#2843: Added rec_type to staging table
  --                                                             insert statement for PO scheduling and 
  --                                                             unscheduling, as it was missing and so the 
  --                                                             rec_type was null in the staging table.
  ============================================================================================================*/

  PROCEDURE parse_po(  i_message    IN   VARCHAR2
                             , i_sequence_no   IN   NUMBER );



END pl_spl_po_in;


/


CREATE OR REPLACE PACKAGE BODY  pl_spl_po_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_spl_po_in
  --
  -- Description
  --  
  --
  -- Modification History
  --
  -- Date                User                  Version            Defect  Comment
  -- 
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_po(   i_message   IN   VARCHAR2
							, i_sequence_no      IN   NUMBER 
					       )
 /*===========================================================================================================
  -- PROCEDURE
  -- parse_po
  --
  -- Description
  --   This Procedure parses the po and places it in the staging table(sap_po_in).
  --
  -- Modification History
  --
  -- Date                User                  Version             Defect  Comment
  -- 5/17/18           mcha1213                1.0               Initial Creation
  -- 12/12/18          sban3548                                  Jira#640: Added last_fg_po flag for SUS/PRIME
  -- 04/01/10          xzhe5043                                  Jira#788: Added sort_ind 
  -- 03/17/20          pkab6563                                  Jira#2843: Added rec_type to staging table 
  --                                                             insert statement for PO scheduling and 
  --                                                             unscheduling, as it was missing and so the
  --                                                             rec_type was null in the staging table.
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  process_error            EXCEPTION;
  l_sequence_number        NUMBER;
  
  l_prd_weight             sap_po_in.prd_weight%type;
  l_item_seq               sap_po_in.item_seq%TYPE;



  CURSOR c_po_h
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type                               
          , to_char(Rtrim( Substr( i_message, 2,1), ' '))    func_code                   
          , to_char(ltrim( Substr( i_message, 3,16), ' '))    erm_id                   
          , to_char(Rtrim( Substr( i_message, 19,2), ' '))    erm_type
          , to_char(ltrim( Substr( i_message, 21,10), ' '))    source_id
          , to_char(Rtrim( Substr( i_message, 31,8), ' '))   sched_date    
          , to_char(Rtrim( Substr( i_message, 39,6), ' '))   sched_time       
          , to_char(Rtrim( Substr( i_message, 45,6), ' '))   ship_date
          , to_char(Rtrim( Substr( i_message, 51,14), ' '))   phone_no        
          , to_char(Rtrim( Substr( i_message, 65,30), ' '))   cmt
          , to_char(Rtrim( Substr( i_message, 95,3), ' '))  ship_via 
          , to_char(ltrim( Substr( i_message, 98,3), ' '))    line_no                   
          , to_char(Rtrim( Substr( i_message, 101,10), ' '))    carr_id
          , to_char(Rtrim( Substr( i_message, 111,25), ' '))    vend_name          
          , to_char(Rtrim( Substr( i_message, 136,25), ' '))    vend_addr          
          , to_char(Rtrim( Substr( i_message, 161,30), ' '))    vend_citystatezip          
          , to_char(Rtrim( Substr( i_message, 191,6), ' '))    exp_arriv_date
          , to_char(Rtrim( Substr( i_message, 197,3), ' '))   warehouse_id     
          , to_char(Rtrim( Substr( i_message, 200,12), ' '))   load_no
          , to_char(Rtrim( Substr( i_message, 212,9), ' '))   order_id          
          , to_char(Rtrim( Substr( i_message, 221,3), ' '))   from_warehouse_id
          , to_char(Rtrim( Substr( i_message, 224,3), ' '))   to_warehouse_id        
          , to_char(Rtrim( Substr( i_message, 227,1), ' '))   freight
		  , to_char(Rtrim( Substr( i_message, 228,1), ' '))   last_fg_po  
	      , to_char(Rtrim( Substr( i_message, 229,1), ' '))   sort_ind 
          , to_char(Rtrim( Substr( i_message, 230,36), ' '))   msg_id		  
	    FROM dual;


  CURSOR c_po_d
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type                                
          , to_char(ltrim( Substr( i_message, 2,16), ' '))    erm_id                    
          , to_char(Rtrim( Substr( i_message, 18,2), ' '))    erm_type                   
          , to_char(ltrim( Substr( i_message, 20,9), ' '))    prod_id
          , to_char(Rtrim( Substr( i_message, 29,10), ' '))    cust_pref_vendor
          , to_char(ltrim( Substr( i_message, 39,3), '0'))   item_seq    
          , to_char(Rtrim( Substr( i_message, 42,1), ' '))   func_code
          , to_char(Rtrim( Substr( i_message, 43,1), ' '))   master_case_ind          
          , to_char(Rtrim( Substr( i_message, 44,1), ' '))   ord_qty_sign        
          , to_char(ltrim( Substr( i_message, 45,4), '0'))   qty
          , to_char(ltrim( Substr( i_message, 49,10), ' '))   cust_id 
          , to_char(Rtrim( Substr( i_message, 59,17), ' '))    cust_name                  
          , to_char(ltrim( Substr( i_message, 76,9), ' '))    order_id  
          , to_char(Rtrim( Substr( i_message, 85,30), ' '))    cmt
         , to_char(Rtrim( Substr( i_message, 115,1), ' '))    saleable
         , to_char(Rtrim( Substr( i_message, 116,1), ' '))    mispick
         , to_char(Rtrim( Substr( i_message, 117,1), ' '))    uom
         , to_char(ltrim( Substr( i_message, 118,3), '0'))    erm_line_id         
         , to_char(ltrim( Substr( i_message, 121,9), '0'))    prd_weight
         , to_char(Rtrim( Substr( i_message, 130,8), ' '))    mfg_date
        , to_char(Rtrim( Substr( i_message, 138,8), ' '))    exp_date
        , to_char(Rtrim( Substr( i_message, 146,36), ' '))   msg_id
	    FROM dual;

  CURSOR c_po_pv
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  func_code                                
          , to_char(ltrim( Substr( i_message, 2,16), ' '))    erm_id
         , to_char(ltrim( Substr( i_message, 18,3), ' '))   item_seq  		  
          , to_char(ltrim( Substr( i_message, 21,2), ' '))    proc_line_no                   
          , to_char(Rtrim( Substr( i_message, 23,9), ' '))    prod_id
          , to_char(ltrim( Substr( i_message, 32,10), ' '))    cust_pref_vendor   
          , to_char(Rtrim( Substr( i_message, 42,3), ' '))   status
          , to_char(Rtrim( Substr( i_message, 45,36), ' '))   msg_id          
	    FROM dual;	

  CURSOR c_po_fv
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  func_code                                
          , to_char(ltrim( Substr( i_message, 2,16), ' '))    erm_id
          , to_char(Rtrim( Substr( i_message, 18,3), ' '))   status
          , to_char(Rtrim( Substr( i_message, 21,36), ' '))   msg_id
	    FROM dual;	
        
  CURSOR c_po_sch
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type   
          , to_char(Rtrim( Substr( i_message, 2,1), ' '))  func_code 
          , to_char(ltrim( Substr( i_message, 3,16), ' '))    erm_id                    
          , to_char(Rtrim( Substr( i_message, 19,2), ' '))    erm_type                   
          , to_char(rtrim( Substr( i_message, 21,8), ' '))    sched_date
          , to_char(Rtrim( Substr( i_message, 29,6), ' '))    sched_time
          , to_char(rtrim( Substr( i_message, 35,1), ' '))   sched_area   
          , to_char(Rtrim( Substr( i_message, 36,4), ' '))   door_no       
          , to_char(ltrim( Substr( i_message, 40,10), ' '))   carr_id
          , to_char(ltrim( Substr( i_message, 50,12), ' '))   load_no
          , to_char(Rtrim( Substr( i_message, 62,36), ' '))   msg_id
	    FROM dual;       
        
  CURSOR c_po_unsch
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))  rec_type   
          , to_char(Rtrim( Substr( i_message, 2,1), ' '))  func_code 
          , to_char(ltrim( Substr( i_message, 3,16), ' '))    erm_id 
          , to_char(Rtrim( Substr( i_message, 19,36), ' '))   msg_id          
	    FROM dual;                
        
    
    l_foodpro_flag char := pl_common.f_get_syspar('ENABLE_FOODPRO', 'N');

BEGIN

   l_sequence_number := i_sequence_no;


   if to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'H' then

	 FOR ch_rec IN c_po_h
	  LOOP

		    insert into sap_po_in
			(SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE
            ,rec_type, func_code,erm_id,erm_type,source_id,sched_date,sched_time,ship_date,phone_no,cmt
			,ship_via,line_no,carr_id, ship_addr1, ship_addr2, ship_addr3
            ,exp_arriv_date,warehouse_id,load_no, order_id, from_warehouse_id,to_warehouse_id
            ,freight, last_fg_po,sort_ind, msg_id) 
			values
			(l_sequence_number, SYSDATE, 'N', 'PO'
            ,ch_rec.rec_type, ch_rec.func_code,ch_rec.erm_id,ch_rec.erm_type,ch_rec.source_id,ch_rec.sched_date,ch_rec.sched_time
			,ch_rec.ship_date,ch_rec.phone_no,ch_rec.cmt,ch_rec.ship_via,ch_rec.line_no,ch_rec.carr_id
            , ch_rec.vend_name, ch_rec.vend_addr, ch_rec.vend_citystatezip 
            , ch_rec.exp_arriv_date
			,ch_rec.warehouse_id,ch_rec.load_no,ch_rec.order_id ,ch_rec.from_warehouse_id,ch_rec.to_warehouse_id
            ,ch_rec.freight,ch_rec.last_fg_po,ch_rec.sort_ind, ch_rec.msg_id);			


	   end loop;			 

   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'D' then

     FOR cd_rec IN c_po_d
	  LOOP
            
            if cd_rec.prd_weight is null then
                l_prd_weight := null;
            else
                l_prd_weight := substr(cd_rec.prd_weight, 1, length(cd_rec.prd_weight) -3 )||'.'||substr(cd_rec.prd_weight, -3);
            end if;

            -- Fix issue where Foodpro sends a blank for the item_seq. If it's blank, then use the erm_line_id.
            if l_foodpro_flag = 'Y' AND trim(cd_rec.item_seq) is null then
                l_item_seq := cd_rec.erm_line_id;
            else
                l_item_seq := cd_rec.item_seq;
            end if;

   		    insert into sap_po_in
            (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE
            ,rec_type,erm_id,erm_type,prod_id,cust_pref_vendor,item_seq,func_code
			,master_case_ind,ord_qty_sign,qty
            ,cust_id
            ,cust_name
			,order_id
            ,cmt,saleable,mispick, uom, erm_line_id, prd_weight
			,mfg_date,exp_date, msg_id)
			values
            (l_sequence_number, SYSDATE, 'N', 'PO'
            ,cd_rec.rec_type,cd_rec.erm_id,cd_rec.erm_type,cd_rec.prod_id,cd_rec.cust_pref_vendor,l_item_seq,cd_rec.func_code
			,cd_rec.master_case_ind,cd_rec.ord_qty_sign,cd_rec.qty
            ,DECODE(cd_rec.cust_id, '0', null, cd_rec.cust_id)
            ,cd_rec.cust_name
			,DECODE(cd_rec.order_id, '0', null, cd_rec.order_id)
            ,cd_rec.cmt,cd_rec.saleable,cd_rec.mispick,cd_rec.uom, cd_rec.erm_line_id, l_prd_weight  --cd_rec.prd_weight
			,cd_rec.mfg_date,cd_rec.exp_date, cd_rec.msg_id);
	   end loop; 

   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'P' then
    FOR cpv_rec IN c_po_pv
	  LOOP
   		    insert into sap_po_in
            (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE
             ,func_code,erm_id,item_seq,proc_line_no,prod_id,cust_pref_vendor
             , status, msg_id)
			values
            (l_sequence_number, SYSDATE, 'N', 'PO'
            ,cpv_rec.func_code,cpv_rec.erm_id,cpv_rec.item_seq,cpv_rec.proc_line_no,cpv_rec.prod_id,cpv_rec.cust_pref_vendor
            ,cpv_rec.status, cpv_rec.msg_id);	
      end loop;
   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'F' then      
   --else
    FOR cpfv_rec IN c_po_fv
	  LOOP
   		    insert into sap_po_in
            (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE
            ,func_code,erm_id, status, msg_id)
			values
            (l_sequence_number, SYSDATE, 'N', 'PO'
            ,cpfv_rec.func_code,cpfv_rec.erm_id,cpfv_rec.status,cpfv_rec.msg_id);	   

      end loop;
   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'S' then
    FOR cps_rec IN c_po_sch
	  LOOP
   		    insert into sap_po_in
            (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE, rec_type
            ,func_code, erm_id, erm_type, sched_date, sched_time, sched_area, door_no
            ,carr_id, load_no, msg_id)
			values
            (l_sequence_number, SYSDATE, 'N', 'PO', cps_rec.rec_type
            ,cps_rec.func_code, cps_rec.erm_id, cps_rec.erm_type, cps_rec.sched_date, cps_rec.sched_time, cps_rec.sched_area,
                 cps_rec.door_no, cps_rec.carr_id, cps_rec.load_no, cps_rec.msg_id);	
      end loop;  
   elsif to_char(Rtrim( Substr( i_message, 1,1), ' ')) = 'U' then
    FOR cpu_rec IN c_po_unsch
	  LOOP
   		    insert into sap_po_in
            (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE, rec_type
            ,func_code, erm_id, msg_id)
			values
            (l_sequence_number, SYSDATE, 'N', 'PO', cpu_rec.rec_type
            ,cpu_rec.func_code, cpu_rec.erm_id, cpu_rec.msg_id);	
      end loop;            
   end if;


EXCEPTION
   WHEN OTHERS THEN
  --ROLLBACK; 
     l_error_msg:= 'Error: Undefined Exception';
     l_error_code:= SUBSTR(SQLERRM,1,100);   
     pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_po', l_error_msg,
											SQLCODE, SQLERRM,
											'or',
											'pl_spl_po_in',
											'N');
     UPDATE mq_queue_in
          SET record_status   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
        WHERE sequence_number = l_sequence_number;
     Commit;

END parse_po;


END pl_spl_po_in;
/
