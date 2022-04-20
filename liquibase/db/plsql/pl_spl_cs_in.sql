CREATE OR REPLACE PACKAGE pl_spl_cs_in 
IS
  /*===========================================================================================================
  -- Package
  -- pl_spl_cs_in
  --
  -- Description
  --  This package processes the item cost updates from Asian Foods into SWMS sap_cs_in table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   8/31/18        pkab6563      Initial version
  --   9/12/18        pkab6563      Removed avg weight from parsing. Asian Foods does not have it and it
  --                                is not in sap_cs_in table. 
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  PROCEDURE parse_cs( i_message       IN   VARCHAR2,
                      i_sequence_no   IN   NUMBER );

END pl_spl_cs_in;
/


CREATE OR REPLACE PACKAGE BODY  pl_spl_cs_in
IS
  /*===========================================================================================================
  -- Package Body
  -- pl_spl_cs_in
  --
  -- Description
  --  
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   8/31/18        pkab6563      Initial version
  --   9/12/18        pkab6563      Removed avg weight from parsing. Asian Foods does not have it and it
  --                                is not in sap_cs_in table. 
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message table.
  --
  ============================================================================================================*/

  l_error_msg  VARCHAR2(400);
  l_error_code VARCHAR2(100);


PROCEDURE parse_cs( i_message IN  VARCHAR2,
                    i_sequence_no IN NUMBER 
                  )
  -----------------------------------------------------------------------------------------------------------
  -- PROCEDURE
  -- parse_cs
  --
  -- Description
  --   This Procedure parses the data from the CS queue and places it in the 
  --   sap_cs_in staging table.
  --
  -- Modification History
  --
  --   Date           User          Comment
  --   ---------      ----------    -------------
  --   8/31/18        pkab6563      Initial version
  --   9/12/18        pkab6563      Removed avg weight from parsing. Asian Foods does not have it and it
  --                                is not in sap_cs_in table. 
  --   9/14/18        pkab6563      Jira #589 - Remove info-only messages to avoid filling up message 
  --                                table.
  ----------------------------------------------------------------------------------------------------------
IS
  process_error       EXCEPTION;
  l_sequence_number   sap_cs_in.sequence_number%TYPE;
  this_function       CONSTANT  VARCHAR2(30 CHAR) := 'PL_SPL_CS_IN.PARSE_CS';
  
  CURSOR c_cs
  IS
     SELECT TO_CHAR(LTRIM(SUBSTR(i_message, 1, 9))) prod_id,                                
            TO_CHAR(LTRIM(SUBSTR(i_message, 10, 10))) cust_pref_vendor,                                
            TO_CHAR(TRIM(SUBSTR(i_message, 20, 1))) catch_wt_flag,                                
            TO_CHAR(LTRIM(SUBSTR(i_message, 21, 9), '0')) item_cost,                                
            TO_CHAR(TRIM(SUBSTR(i_message, 30, 8))) last_ship_date
    FROM dual;

BEGIN

   l_sequence_number := i_sequence_no;

   /* commented out for Jira #589
   PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg,
                   i_Procedure_Name   => this_function,
                   i_Msg_Text         => 'before the for loop',
                   i_Msg_No           => NULL,
                   i_SQL_Err_Msg      => NULL,
                   i_Application_Func => 'Parsing CS In',
                   i_Program_Name     => this_function,
                   i_Msg_Alert        => 'N'
                 );                                            
   */ 

   FOR cs_rec IN c_cs
   LOOP
      INSERT INTO sap_cs_in 
                   (sequence_number, interface_type, record_status, datetime, func_code, 
                    prod_id, item_cost, add_user, add_date  
                   )
      VALUES
                   (l_sequence_number, 'CS', 'N', sysdate, 'P', 
                    cs_rec.prod_id, cs_rec.item_cost, user, sysdate
                   );
   END LOOP;

   /* commented out for Jira #589
   PL_Log.Ins_Msg( i_Msg_Type         => PL_Log.CT_Info_Msg,
                   i_Procedure_Name   => this_function, 
                   i_Msg_Text         => 'after the for loop',
                   i_Msg_No           => NULL,
                   i_SQL_Err_Msg      => NULL,
                   i_Application_Func => 'Parsing CS In',
                   i_Program_Name     => this_function,
                   i_Msg_Alert        => 'N'
                );                                     
   */


EXCEPTION
WHEN OTHERS THEN

  l_error_msg:= 'Error: pl_spl_cs_in.parse_cs when others Exception';
  l_error_code:= SUBSTR(SQLERRM, 1, 100);   
  pl_log.ins_msg(pl_log.ct_fatal_msg, 
                 this_function, 
                 l_error_msg,
                 SQLCODE, 
                 SQLERRM,
                 this_function,
                 'pl_spl_cs_in',
                 'N');
  UPDATE mq_queue_in
     SET record_status   = 'F',
         error_msg       = l_error_msg,
         error_code      = l_error_code
     WHERE sequence_number = l_sequence_number;

    Commit;

END parse_cs;


END pl_spl_cs_in;
/
