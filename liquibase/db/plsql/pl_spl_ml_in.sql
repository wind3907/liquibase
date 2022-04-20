create or replace
PACKAGE pl_spl_ml_in
IS
  /*===========================================================================================================
  -- Package
  -- pl_sap_ml_in
  --
  -- Description
  --   This Procedure parses the ml and places it in the staging table(sap_ml_in).
  --
  -- Modification History
  --
  -- Date                User                  Version             Defect  Comment
  -- 8/24/18           xzhe5043                1.0               Initial Creation
  ============================================================================================================*/

  PROCEDURE parse_ml(  i_message    IN   VARCHAR2
                     , i_sequence_no   IN   NUMBER );



END pl_spl_ml_in;
/
create or replace
PACKAGE BODY  pl_spl_ml_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_spl_ml_in
  --
  -- Description
  --  
  --
  -- Modification Histmly
  --
  -- Date                User                  Version            Defect  Comment
  -- 
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_ml(   i_message      IN   VARCHAR2
							      , i_sequence_no  IN   NUMBER 
					       )
 /*===========================================================================================================
  -- PROCEDURE
  -- parse_ml
  --
  -- Description
  --   This Procedure parses the ml and places it in the staging table(sap_ml_in).
  --
  -- Modification History
  --
  -- Date                User                  Version             Defect  Comment
  -- 8/24/18           xzhe5043                1.0               Initial Creation
  ============================================================================================================*/
IS
  --------------------------local variables-----------------------------
  process_error            EXCEPTION;
  l_sequence_number        NUMBER;

  CURSOR c_ml_h
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))     rec_ind
          , to_char(Rtrim( Substr( i_message, 2,50), ' '))    MESSAGE_TYPE
          , to_char(Ltrim( Substr( i_message, 52,25), ' '))   order_id
          , to_char(Rtrim( Substr( i_message, 77,50), ' '))  description
          , to_char(Rtrim( Substr( i_message, 127,2), ' ')) order_priority
          , to_char(Rtrim( Substr( i_message, 129,10), ' ')) order_type
          , to_char(Rtrim( Substr( i_message, 139,10), ' ')) order_date
           ,TO_CHAR(LTRIM(SUBSTR(i_message, 149, 5), '0')) dtl_rec_count
	    FROM dual;

  CURSOR c_ml_d
  IS
    SELECT  to_char(Rtrim( Substr( i_message, 1,1), ' '))   rec_ind
           , to_char(Rtrim( Substr( i_message, 2,50), ' '))  MESSAGE_TYPE
          , to_char(Ltrim( Substr( i_message, 52,25), ' ')) order_id
          , to_char(Ltrim( Substr( i_message, 77,10), ' ')) order_item_id
          , to_char(Rtrim( Substr( i_message, 87,1), ' ')) uom
          , to_char(Rtrim( Substr( i_message, 88,9), ' ')) prod_id
          , to_char(Rtrim( Substr( i_message, 97,10), ' ')) CUST_PREF_VENDOR
          , TO_CHAR(Rtrim( SUBSTR( i_message, 107, 15), ' ')) QUANTITY_REQUESTED
         , to_char(Rtrim( SUBSTR( i_message, 122, 2), ' ')) SKU_PRIORITY
          , to_char(Rtrim( SUBSTR( i_message, 124, 10), ' ')) order_item_id_count
	    FROM dual;		

BEGIN
   l_sequence_number := i_sequence_no;
    IF ( to_char(rtrim( Substr( i_message, 1,1), ' ')) = 'H' ) THEN 
	  For ch_rec IN c_ml_h
	  LOOP
		  insert into swms.sap_ml_in
			(SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE,
       MESSAGE_TYPE,  order_id, description,  order_priority, order_type, order_date,dtl_rec_count )
		     values
             (l_sequence_number, SYSDATE, 'N', 'ML',
                ch_rec.MESSAGE_TYPE, ch_rec.order_id,  ch_rec.description, 
              ch_rec.order_priority, ch_rec.order_type, ch_rec.order_date, ch_rec.dtl_rec_count  );	

	  end loop;
      /*  PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_ml_in.parse_ml'
                        , i_Msg_Text         => 'after the c_ml_h for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing ML In'
                        , i_Program_Name     => 'pl_spl_ml_in.parse_ml'
                        , i_Msg_Alert        => 'N'
                        );*/
 ELSE 
     For cd_rec IN c_ml_d LOOP
           insert into swms.sap_ml_in			
          (SEQUENCE_NUMBER, DATETIME, RECORD_STATUS, INTERFACE_TYPE,
            MESSAGE_TYPE,  order_id, order_item_id, uom, prod_id, CUST_PREF_VENDOR ,QUANTITY_REQUESTED, SKU_PRIORITY, order_item_id_count)
          values
          (l_sequence_number, SYSDATE, 'N', 'ML' ,
           cd_rec.MESSAGE_TYPE, cd_rec.order_id, cd_rec.order_item_id, cd_rec.UOM, cd_rec.prod_id, cd_rec.CUST_PREF_VENDOR,
           cd_rec.QUANTITY_REQUESTED, cd_rec.SKU_PRIORITY, cd_rec.order_item_id_count);  
        END LOOP;  
              /* PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg
                        , i_Procedure_Name   =>  'pl_spl_mf_in.parse_mf'
                        , i_Msg_Text         => 'after the c_ml_d for loop'
                        , i_Msg_No           => NULL
                        , i_SQL_Err_Msg      => NULL
                        , i_Application_Func => 'Parsing MF In'
                        , i_Program_Name     => 'pl_spl_mf_in.parse_mf'
                        , i_Msg_Alert        => 'N'
                        );*/
  END IF;  

EXCEPTION
   WHEN OTHERS THEN
  --ROLLBACK; 
     l_error_msg:= 'error: PL_SPL_ML_IN when others Exception';
     l_error_code:= SUBSTR(SQLERRM,1,100);   
     pl_log.ins_msg(pl_log.ct_fatal_msg, 'parse_ml', l_error_msg,
											SQLCODE, SQLERRM,
											'ml',
											'pl_spl_ml_in',
											'N');
     UPDATE mq_queue_in
          SET RECORD_STATUS   = 'F',
              error_msg       = l_error_msg,
              error_code      = l_error_code
        WHERE sequence_number = l_sequence_number;
     Commit;

END parse_ml;


END pl_spl_ml_in;
/